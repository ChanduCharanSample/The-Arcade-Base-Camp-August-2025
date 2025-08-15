#!/bin/bash
set -e

# ==========================
# Auto-detect PROJECT_ID
# ==========================
echo "🔍 Detecting Project ID..."
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
    PROJECT_ID=$(gcloud projects list --format="value(projectId)" | head -n 1)
    if [[ -z "$PROJECT_ID" ]]; then
        echo "❌ No project found. Please create/select a project first."
        exit 1
    fi
    gcloud config set project "$PROJECT_ID"
fi
echo "✅ Using Project ID: $PROJECT_ID"

# ==========================
# Variables
# ==========================
ZONE_A="us-central1-c"
ZONE_B="us-west1-b"
SUBNET_A="vpc-a-sub1-use4"
SUBNET_B="vpc-b-sub1-usw2"
NETWORK_A="vpc-a"
NETWORK_B="vpc-b"

# ==========================
# Step 0: Clean up old resources
# ==========================
echo "🧹 Cleaning up old resources..."
gcloud compute instances delete vpc-a-vm-1 --zone=$ZONE_A --quiet || true
gcloud compute instances delete vpc-b-vm-1 --zone=$ZONE_B --quiet || true
gcloud compute firewall-rules delete fw-a --quiet || true
gcloud compute firewall-rules delete fw-b --quiet || true

# ==========================
# Step 1: Create firewall rules
# ==========================
echo "🚀 Creating firewall rules..."
gcloud compute firewall-rules create fw-a \
  --network=$NETWORK_A \
  --allow=tcp:22,icmp \
  --direction=INGRESS \
  --priority=1000

gcloud compute firewall-rules create fw-b \
  --network=$NETWORK_B \
  --allow=tcp:22,icmp \
  --direction=INGRESS \
  --priority=1000

# ==========================
# Step 2: Create VM in vpc-a
# ==========================
echo "🚀 Creating VM vpc-a-vm-1..."
gcloud compute instances create vpc-a-vm-1 \
  --zone=$ZONE_A \
  --machine-type=e2-medium \
  --subnet=$SUBNET_A \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --boot-disk-type=pd-balanced \
  --boot-disk-size=10GB

# ==========================
# Step 3: Create VM in vpc-b
# ==========================
echo "🚀 Creating VM vpc-b-vm-1..."
gcloud compute instances create vpc-b-vm-1 \
  --zone=$ZONE_B \
  --machine-type=e2-medium \
  --subnet=$SUBNET_B \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --boot-disk-type=pd-balanced \
  --boot-disk-size=10GB

# ==========================
# Step 4: Output Internal IPs
# ==========================
echo "📡 VM Internal IPs:"
gcloud compute instances list \
  --filter="name=('vpc-a-vm-1','vpc-b-vm-1')" \
  --format="table(name, networkInterfaces[0].networkIP, zone)"

echo "✅ All resources created successfully."
