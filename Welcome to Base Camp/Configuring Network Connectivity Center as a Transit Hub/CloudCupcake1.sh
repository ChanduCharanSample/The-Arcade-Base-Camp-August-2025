#!/bin/bash
# Delete and recreate fw-a for vpc-a
gcloud compute firewall-rules delete fw-a --quiet || true
gcloud compute firewall-rules create fw-a \
  --network=vpc-a \
  --priority=1000 \
  --direction=INGRESS \
  --allow=tcp:22,icmp \
  --source-ranges=0.0.0.0/0 \
  --quiet

# Delete and recreate fw-b for vpc-b
gcloud compute firewall-rules delete fw-b --quiet || true
gcloud compute firewall-rules create fw-b \
  --network=vpc-b \
  --priority=1000 \
  --direction=INGRESS \
  --allow=tcp:22,icmp \
  --source-ranges=0.0.0.0/0 \
  --quiet
echo "${YELLOW}${BOLD}LAB COMPLETED SUCCESFULLY ! SUBSCRIBE TO CLOUDCUPCAKE!"${RESET}

echo ""
