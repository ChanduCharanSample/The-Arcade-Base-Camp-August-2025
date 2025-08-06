#!/bin/bash

# ==========================
# 💬 ASCII SUBSCRIBE MESSAGE
# ==========================
YELLOW='\033[0;33m'
NC='\033[0m' 

pattern=(
"**********************************************************"
"**                 S U B S C R I B E  TO                **"
"**                 C L O U D C U P C A K E              **"
"**********************************************************"
)
for line in "${pattern[@]}"
do
    echo -e "${YELLOW}${line}${NC}"
done
#!/bin/bash

# Detect Project ID
PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

# Set variables
REGION1="us-east4"
REGION2="us-central1"

# Step 1: Delete default network (if exists)
gcloud compute networks delete default --quiet || true

# Step 2: Create vpc-transit (hub)
gcloud compute networks create vpc-transit \
  --subnet-mode=custom \
  --bgp-routing-mode=global

# Step 3: Create vpc-a
gcloud compute networks create vpc-a \
  --subnet-mode=custom \
  --bgp-routing-mode=regional
gcloud compute networks subnets create vpc-a-sub1-use4 \
  --network=vpc-a \
  --region=$REGION1 \
  --range=10.20.10.0/24

# Step 4: Create vpc-b
gcloud compute networks create vpc-b \
  --subnet-mode=custom \
  --bgp-routing-mode=regional
gcloud compute networks subnets create vpc-b-sub1-usw2 \
  --network=vpc-b \
  --region=$REGION2 \
  --range=10.20.20.0/24

# Step 5: Create Cloud Routers
gcloud compute routers create cr-vpc-transit-use4-1 \
  --network=vpc-transit \
  --region=$REGION1 \
  --asn=65000
gcloud compute routers create cr-vpc-transit-usw2-1 \
  --network=vpc-transit \
  --region=$REGION2 \
  --asn=65000
gcloud compute routers create cr-vpc-a-use4-1 \
  --network=vpc-a \
  --region=$REGION1 \
  --asn=65001
gcloud compute routers create cr-vpc-b-usw2-1 \
  --network=vpc-b \
  --region=$REGION2 \
  --asn=65002

# Step 6: Create Cloud VPN Gateways
gcloud compute vpn-gateways create vpc-transit-gw1-use4 \
  --network=vpc-transit \
  --region=$REGION1
gcloud compute vpn-gateways create vpc-transit-gw1-usw2 \
  --network=vpc-transit \
  --region=$REGION2
gcloud compute vpn-gateways create vpc-a-gw1-use4 \
  --network=vpc-a \
  --region=$REGION1
gcloud compute vpn-gateways create vpc-b-gw1-usw2 \
  --network=vpc-b \
  --region=$REGION2

# ⚠️ At this point, you need to manually:
# - Create HA VPN tunnels between gateways
# - Configure BGP sessions using correct IPs and ASNs
# The CLI doesn't fully automate this yet because tunnel interfaces require auto-assigned IPs.

# Step 7: Enable Network Connectivity API
gcloud services enable networkconnectivity.googleapis.com

# Step 8: Create NCC hub
gcloud alpha network-connectivity hubs create transit-hub \
  --description="Transit_hub"

# Step 9: Create spokes (bo1 and bo2)
gcloud alpha network-connectivity spokes create bo1 \
  --hub=transit-hub \
  --description=branch_office1 \
  --vpn-tunnel=transit-to-vpc-a-tu1,transit-to-vpc-a-tu2 \
  --region=$REGION1
gcloud alpha network-connectivity spokes create bo2 \
  --hub=transit-hub \
  --description=branch_office2 \
  --vpn-tunnel=transit-to-vpc-b-tu1,transit-to-vpc-b-tu2 \
  --region=$REGION2

# Step 10: Create firewall rules
gcloud compute firewall-rules create fw-a \
  --network=vpc-a \
  --allow=tcp:22,icmp
gcloud compute firewall-rules create fw-b \
  --network=vpc-b \
  --allow=tcp:22,icmp

# Step 11: Create VM in vpc-a
gcloud compute instances create vpc-a-vm-1 \
  --zone=us-east4-a \
  --machine-type=e2-medium \
  --subnet=vpc-a-sub1-use4 \
  --image-family=debian-11 \
  --image-project=debian-cloud

# Step 12: Create VM in vpc-b
gcloud compute instances create vpc-b-vm-1 \
  --zone=us-central1-c \
  --machine-type=e2-medium \
  --subnet=vpc-b-sub1-usw2 \
  --image-family=debian-11 \
  --image-project=debian-cloud

echo "GO TO NEXT CODE!:"
