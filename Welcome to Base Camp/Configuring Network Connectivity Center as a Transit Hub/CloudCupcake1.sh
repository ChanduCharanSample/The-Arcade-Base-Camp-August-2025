#!/bin/bash
# Auto-create firewall rules and VMs for GCP lab

echo "🔍 Detecting Project ID..."
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gcloud projects list --format="value(projectId)" | head -n 1)
    gcloud config set project "$PROJECT_ID"
fi
echo "✅ Project: $PROJECT_ID"

echo "🔍 Detecting default compute zone..."
DEFAULT_ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
if [[ -z "$DEFAULT_ZONE" ]]; then
    DEFAULT_ZONE="us-central1-c"
    gcloud config set compute/zone "$DEFAULT_ZONE"
fi
echo "✅ Zone: $DEFAULT_ZONE"

# -------------------------
# Step 1: Firewall Rules
# -------------------------
create_firewall_rule() {
    local RULE_NAME=$1
    local NETWORK=$2
    if ! gcloud compute firewall-rules describe "$RULE_NAME" --project "$PROJECT_ID" &>/dev/null; then
        echo "🚀 Creating firewall rule: $RULE_NAME"
        gcloud compute firewall-rules create "$RULE_NAME" \
            --network="$NETWORK" \
            --allow tcp:22,icmp \
            --direction=INGRESS \
            --priority=1000
    else
        echo "⚠️ Firewall rule $RULE_NAME already exists."
    fi
}

create_firewall_rule "fw-a" "vpc-a"
create_firewall_rule "fw-b" "vpc-b"

# -------------------------
# Step 2: VM Creation
# -------------------------
create_vm() {
    local VM_NAME=$1
    local ZONE=$2
    local NETWORK=$3
    local SUBNET=$4

    if ! gcloud compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" &>/dev/null; then
        echo "🚀 Creating VM: $VM_NAME in $ZONE"
        gcloud compute instances create "$VM_NAME" \
            --zone="$ZONE" \
            --machine-type=e2-medium \
            --subnet="$SUBNET" \
            --network="$NETWORK" \
            --image-family=debian-11 \
            --image-project=debian-cloud \
            --boot-disk-size=10GB \
            --boot-disk-type=pd-balanced
    else
        echo "⚠️ VM $VM_NAME already exists."
    fi
}

create_vm "vpc-a-vm-1" "us-central1-c" "vpc-a" "vpc-a-sub1-use4"
create_vm "vpc-b-vm-1" "us-west1-b" "vpc-b" "vpc-b-sub1-usw2"

echo "🎉 All resources created successfully!"
