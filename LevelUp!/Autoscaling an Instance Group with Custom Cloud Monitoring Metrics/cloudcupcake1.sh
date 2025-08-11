
#!/bin/bash

# ==============================
#  Task 7 - Configure Autoscaling
# ==============================

# Prompt for Zone
read -p "Enter the ZONE (e.g., us-central1-c): " ZONE
REGION=${ZONE%-*}
PROJECT_ID=$(gcloud config get-value project)
INSTANCE_GROUP_NAME="autoscaling-instance-group-1"
CUSTOM_METRIC="custom.googleapis.com/appdemo_queue_depth_01"

# Set config
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# Enable autoscaling with custom metric
gcloud beta compute instance-groups managed set-autoscaling $INSTANCE_GROUP_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --cool-down-period=60 \
    --max-num-replicas=3 \
    --min-num-replicas=1 \
    --mode=on \
    --stackdriver-metric-filter="resource.type = \"gce_instance\"" \
    --update-stackdriver-metric=$CUSTOM_METRIC \
    --stackdriver-metric-utilization-target=150.0 \
    --stackdriver-metric-utilization-target-type=gauge

# ==============================
#  Fancy Success Box
# ==============================
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo
echo "${YELLOW}${BOLD}############################################${RESET}"
echo "${YELLOW}${BOLD}#     📢 Subscribe to cloudcupcake 📢      #${RESET}"
echo "${YELLOW}${BOLD}############################################${RESET}"
echo
echo "${BOLD}✅ Lab Completed Successfully!${RESET}"
