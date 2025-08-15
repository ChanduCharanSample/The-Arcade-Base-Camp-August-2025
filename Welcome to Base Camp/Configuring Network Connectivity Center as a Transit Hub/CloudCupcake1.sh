#!/bin/bash
# create_or_replace_fw_rules.sh
set -euo pipefail

NETWORK_A="vpc-a"
NETWORK_B="vpc-b"

# Function to recreate a firewall rule
create_firewall_rule () {
  local RULE_NAME=$1
  local NETWORK_NAME=$2

  # Delete if exists
  if gcloud compute firewall-rules describe "$RULE_NAME" --quiet &>/dev/null; then
    echo "Deleting existing firewall rule $RULE_NAME..."
    gcloud compute firewall-rules delete "$RULE_NAME" --quiet
  fi

  # Create fresh rule
  echo "Creating firewall rule $RULE_NAME for network $NETWORK_NAME..."
  gcloud compute firewall-rules create "$RULE_NAME" \
    --network="$NETWORK_NAME" \
    --priority=1000 \
    --direction=INGRESS \
    --allow=tcp:22,icmp \
    --source-ranges=0.0.0.0/0 \
    --quiet
}

create_firewall_rule fw-a "$NETWORK_A"
create_firewall_rule fw-b "$NETWORK_B"

echo "✅ Firewall rules fw-a and fw-b created successfully."
