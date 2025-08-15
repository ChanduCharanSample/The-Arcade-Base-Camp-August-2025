#!/bin/bash
# create_fw_a_and_fw_b.sh
# Creates fw-a and fw-b with identical settings except network.

set -euo pipefail

# Variables
NETWORK_A="vpc-a"
NETWORK_B="vpc-b"

# Create fw-a
echo "Creating firewall rule fw-a for network ${NETWORK_A}..."
gcloud compute firewall-rules create fw-a \
  --network="${NETWORK_A}" \
  --priority=1000 \
  --direction=INGRESS \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --quiet

# Create fw-b
echo "Creating firewall rule fw-b for network ${NETWORK_B}..."
gcloud compute firewall-rules create fw-b \
  --network="${NETWORK_B}" \
  --priority=1000 \
  --direction=INGRESS \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --quiet

echo "✅ Firewall rules fw-a and fw-b created successfully."
