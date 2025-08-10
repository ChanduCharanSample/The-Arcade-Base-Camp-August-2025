
#!/bin/bash
set -e

# ====== Styles ======
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# ====== Detect Project ID and Number ======
echo "${YELLOW}${BOLD}Detecting Project Information...${RESET}"
MPC_PROJECT_ID=$(gcloud config get-value core/project 2>/dev/null)
if [ -z "$MPC_PROJECT_ID" ]; then
    echo "${YELLOW}No active gcloud project found! Please set one.${RESET}"
    exit 1
fi
MPC_PROJECT_NUMBER=$(gcloud projects describe "$MPC_PROJECT_ID" --format="value(projectNumber)")

# ====== Detect Zone ======
ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
if [ -z "$ZONE" ]; then
    read -p "${YELLOW}${BOLD}Enter the ZONE: ${RESET}" ZONE
fi

REGION=${ZONE%-*}

export ZONE REGION MPC_PROJECT_ID MPC_PROJECT_NUMBER

echo "Project ID: $MPC_PROJECT_ID"
echo "Project Number: $MPC_PROJECT_NUMBER"
echo "Zone: $ZONE"
echo "Region: $REGION"

# ====== Enable required services ======
gcloud services enable cloudkms.googleapis.com compute.googleapis.com confidentialcomputing.googleapis.com iamcredentials.googleapis.com artifactregistry.googleapis.com

# ====== Create KMS Keyring and Keys ======
gcloud kms keyrings create mpc-keys --location=global || echo "Keyring exists"
gcloud kms keys create mpc-key --location=global --keyring=mpc-keys --purpose=encryption --protection-level=hsm || echo "Key exists"

# ====== Grant encryption role to current user ======
gcloud kms keys add-iam-policy-binding \
  projects/$MPC_PROJECT_ID/locations/global/keyRings/mpc-keys/cryptoKeys/mpc-key \
  --member="user:$(gcloud config get-value account)" \
  --role='roles/cloudkms.cryptoKeyEncrypter'

# ====== Create key shares ======
echo -n "00000000000000000000000000000000" > alice-key-share
echo -n "00000000000000000000000000000001" > bob-key-share

# ====== Encrypt key shares ======
gcloud kms encrypt --key mpc-key --keyring mpc-keys --location global --plaintext-file alice-key-share --ciphertext-file alice-encrypted-key-share
gcloud kms encrypt --key mpc-key --keyring mpc-keys --location global --plaintext-file bob-key-share --ciphertext-file bob-encrypted-key-share

# ====== Create and upload to storage bucket ======
gcloud storage buckets create gs://$MPC_PROJECT_ID-mpc-encrypted-keys --location=$REGION || echo "Bucket exists"
gcloud storage cp alice-encrypted-key-share gs://$MPC_PROJECT_ID-mpc-encrypted-keys/
gcloud storage cp bob-encrypted-key-share gs://$MPC_PROJECT_ID-mpc-encrypted-keys/

# ====== Create service accounts and bindings ======
gcloud iam service-accounts create trusted-mpc-account || echo "Service account exists"
gcloud kms keys add-iam-policy-binding mpc-key --keyring='mpc-keys' --location='global' --member="serviceAccount:trusted-mpc-account@$MPC_PROJECT_ID.iam.gserviceaccount.com" --role='roles/cloudkms.cryptoKeyDecrypter'

gcloud iam workload-identity-pools create trusted-workload-pool --location="global" || echo "Pool exists"
gcloud iam workload-identity-pools providers create-oidc attestation-verifier \
  --location="global" \
  --workload-identity-pool="trusted-workload-pool" \
  --issuer-uri="https://confidentialcomputing.googleapis.com/" \
  --allowed-audiences="https://sts.googleapis.com" \
  --attribute-mapping="google.subject='assertion.sub'" \
  --attribute-condition="assertion.swname == 'CONFIDENTIAL_SPACE' &&
    'STABLE' in assertion.submods.confidential_space.support_attributes &&
    assertion.submods.container.image_reference ==
    '$REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest'
    && 'run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com' in
    assertion.google_service_accounts" || echo "Provider exists"

gcloud iam service-accounts add-iam-policy-binding trusted-mpc-account@$MPC_PROJECT_ID.iam.gserviceaccount.com \
--role=roles/iam.workloadIdentityUser \
--member="principalSet://iam.googleapis.com/projects/$MPC_PROJECT_NUMBER/locations/global/workloadIdentityPools/trusted-workload-pool/*"

gcloud iam service-accounts create run-confidential-vm || echo "Service account exists"
gcloud iam service-accounts add-iam-policy-binding run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com --member="user:$(gcloud config get-value account)" --role='roles/iam.serviceAccountUser'

gcloud projects add-iam-policy-binding $MPC_PROJECT_ID --member=serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com --role=roles/logging.logWriter

# ====== Create Ethereum node ======
gcloud compute instances create-with-container mpc-lab-ethereum-node --zone=$ZONE --tags=http-server --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring \
  --container-image=docker.io/trufflesuite/ganache:v7.7.3 \
  --container-arg=--wallet.accounts="0x0000000000000000000000000000000000000000000000000000000000000001,0x21E19E0C9BAB2400000" \
  --container-arg=--port=80 || echo "Ethereum node exists"

# ====== Create results bucket ======
gcloud storage buckets create gs://$MPC_PROJECT_ID-mpc-results-storage --location=$REGION || echo "Results bucket exists"

gsutil iam ch serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com:objectCreator gs://$MPC_PROJECT_ID-mpc-results-storage
gsutil iam ch serviceAccount:trusted-mpc-account@$MPC_PROJECT_ID.iam.gserviceaccount.com:objectViewer gs://$MPC_PROJECT_ID-mpc-encrypted-keys

# ====== Download MPC Ethereum Demo ======
mkdir -p mpc-ethereum-demo
cd mpc-ethereum-demo
curl -LO https://raw.githubusercontent.com/Techcps/GSP-Short-Trick/master/Transacting%20Digital%20Assets%20with%20Multi-Party%20Computation%20and%20Confidential%20Space/mpc-ethereum-demo/package.json
curl -LO https://raw.githubusercontent.com/Techcps/GSP-Short-Trick/master/Transacting%20Digital%20Assets%20with%20Multi-Party%20Computation%20and%20Confidential%20Space/mpc-ethereum-demo/index.js
curl -LO https://raw.githubusercontent.com/Techcps/GSP-Short-Trick/master/Transacting%20Digital%20Assets%20with%20Multi-Party%20Computation%20and%20Confidential%20Space/mpc-ethereum-demo/mpc.js
curl -LO https://raw.githubusercontent.com/Techcps/GSP-Short-Trick/master/Transacting%20Digital%20Assets%20with%20Multi-Party%20Computation%20and%20Confidential%20Space/mpc-ethereum-demo/kms-decrypt.js
curl -LO https://raw.githubusercontent.com/Techcps/GSP-Short-Trick/master/Transacting%20Digital%20Assets%20with%20Multi-Party%20Computation%20and%20Confidential%20Space/mpc-ethereum-demo/credential-config.js
curl -LO https://raw.githubusercontent.com/Techcps/GSP-Short-Trick/master/Transacting%20Digital%20Assets%20with%20Multi-Party%20Computation%20and%20Confidential%20Space/mpc-ethereum-demo/Dockerfile
cd ..

# ====== Artifact Registry & Push ======
gcloud artifacts repositories create mpc-workloads --repository-format=docker --location=$REGION || echo "Repo exists"
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet
docker build -t $REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest mpc-ethereum-demo
docker push $REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest

gcloud artifacts repositories add-iam-policy-binding mpc-workloads --location=$REGION --member=serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com --role=roles/artifactregistry.reader
gcloud projects add-iam-policy-binding $MPC_PROJECT_ID --member=serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com --role=roles/confidentialcomputing.workloadUser

# ====== Create Confidential VM ======
NODE_IP=$(gcloud compute instances describe mpc-lab-ethereum-node --format='get(networkInterfaces[0].networkIP)' --zone=$ZONE)
gcloud compute instances create mpc-cvm --confidential-compute --shielded-secure-boot --maintenance-policy=TERMINATE --scopes=cloud-platform --zone=$ZONE \
  --image-project=confidential-space-images --image-family=confidential-space \
  --service-account=run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com \
  --metadata ^~^tee-image-reference=$REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest~tee-restart-policy=Never~tee-env-NODE_URL=$NODE_IP~tee-env-RESULTS_BUCKET=$MPC_PROJECT_ID-mpc-results-storage~tee-env-KEY_BUCKET=$MPC_PROJECT_ID-mpc-encrypted-keys~tee-env-MPC_PROJECT_ID=$MPC_PROJECT_ID~tee-env-MPC_PROJECT_NUMBER=$MPC_PROJECT_NUMBER

# ====== Completion Message ======
echo ""
echo "############################################"
echo "#                                          #"
echo "#   🎉 Lab Completed Successfully! 🎉 #"
echo "#                                          #"
echo "#     Subscribe to CloudCupcake ❤️         #"
echo "#                                          #"
echo "############################################"
