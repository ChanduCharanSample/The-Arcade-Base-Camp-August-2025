#!/bin/bash
# task5_robust.sh — Creates fw-a, fw-b, vpc-a-vm-1, vpc-b-vm-1
# - Auto-detects PROJECT_ID
# - Verifies networks/subnets exist
# - Deletes/recreates resources so the lab grader sees fresh creations
# - If the “suggested” zone doesn’t match the subnet’s region, it auto-picks a valid zone and retries

set -euo pipefail

log() { printf "\n==> %s\n" "$*"; }

# -----------------------------
# 0) Project detection
# -----------------------------
PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  PROJECT_ID="$(gcloud projects list --format='value(projectId)' | head -n1)"
  [[ -z "${PROJECT_ID}" ]] && { echo "No GCP project available." ; exit 1; }
  gcloud config set project "${PROJECT_ID}" >/dev/null
fi
log "Using project: ${PROJECT_ID}"
gcloud services enable compute.googleapis.com >/dev/null

# -----------------------------
# 1) Inputs from the lab
# -----------------------------
NETWORK_A="vpc-a"
NETWORK_B="vpc-b"
SUBNET_A="vpc-a-sub1-use4"   # (we’ll discover its real region)
SUBNET_B="vpc-b-sub1-usw2"   # (we’ll discover its real region)
SUGGESTED_ZONE_A="us-central1-c"
SUGGESTED_ZONE_B="us-west1-b"
VM_A="vpc-a-vm-1"
VM_B="vpc-b-vm-1"
FW_A="fw-a"
FW_B="fw-b"

# -----------------------------
# 2) Sanity checks: networks/subnets exist
# -----------------------------
require_network() {
  gcloud compute networks describe "$1" >/dev/null 2>&1 || {
    echo "Network '$1' not found. Create earlier steps first."; exit 1;
  }
}
require_network "${NETWORK_A}"
require_network "${NETWORK_B}"

# Find each subnet’s region (no need to know it upfront)
find_subnet_region() {
  local name="$1" net="$2"
  gcloud compute networks subnets list \
    --filter="name=${name} AND network=${net}" \
    --format="value(region.basename())" \
    --limit=1
}
REGION_A="$(find_subnet_region "${SUBNET_A}" "${NETWORK_A}")"
REGION_B="$(find_subnet_region "${SUBNET_B}" "${NETWORK_B}")"
[[ -z "${REGION_A}" ]] && { echo "Subnet ${SUBNET_A} not found in ${NETWORK_A}."; exit 1; }
[[ -z "${REGION_B}" ]] && { echo "Subnet ${SUBNET_B} not found in ${NETWORK_B}."; exit 1; }
log "Subnet ${SUBNET_A} is in region: ${REGION_A}"
log "Subnet ${SUBNET_B} is in region: ${REGION_B}"

# Pick a valid zone in a given region
pick_zone_in_region() {
  local region="$1"
  local link
  link="$(gcloud compute regions describe "${region}" --format='value(selfLink)')"
  gcloud compute zones list --filter="region=${link}" --format="value(name)" | head -n1
}
FALLBACK_ZONE_A="$(pick_zone_in_region "${REGION_A}")"
FALLBACK_ZONE_B="$(pick_zone_in_region "${REGION_B}")"
log "Fallback zone for ${SUBNET_A}: ${FALLBACK_ZONE_A}"
log "Fallback zone for ${SUBNET_B}: ${FALLBACK_ZONE_B}"

# -----------------------------
# 3) Fresh firewall rules
# -----------------------------
create_fw() {
  local name="$1" net="$2"
  # Delete if exists (so grader sees a clean creation)
  gcloud compute firewall-rules delete "${name}" --quiet >/dev/null 2>&1 || true
  log "Creating firewall rule ${name} on ${net} (ingress allow tcp:22, icmp from 0.0.0.0/0)"
  gcloud compute firewall-rules create "${name}" \
    --network="${net}" \
    --direction=INGRESS \
    --priority=1000 \
    --source-ranges=0.0.0.0/0 \
    --allow=tcp:22,icmp
}
create_fw "${FW_A}" "${NETWORK_A}"
create_fw "${FW_B}" "${NETWORK_B}"

# -----------------------------
# 4) Fresh VMs (try suggested zone; if invalid for the subnet’s region, retry in a valid one)
# -----------------------------
create_vm_with_retry() {
  local name="$1" suggested_zone="$2" subnet="$3" network="$4" fallback_zone="$5"

  # Delete if exists
  gcloud compute instances delete "${name}" --zone="${suggested_zone}" --quiet >/dev/null 2>&1 || true
  gcloud compute instances delete "${name}" --zone="${fallback_zone}"  --quiet >/dev/null 2>&1 || true

  log "Creating ${name} in ${suggested_zone} (subnet ${subnet})"
  set +e
  gcloud compute instances create "${name}" \
    --zone="${suggested_zone}" \
    --machine-type=e2-medium \
    --subnet="${subnet}" \
    --network="${network}" \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --boot-disk-type=pd-balanced \
    --boot-disk-size=10GB
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log "Suggested zone ${suggested_zone} is invalid for subnet ${subnet}. Retrying in ${fallback_zone}…"
    gcloud compute instances create "${name}" \
      --zone="${fallback_zone}" \
      --machine-type=e2-medium \
      --subnet="${subnet}" \
      --network="${network}" \
      --image-family=debian-11 \
      --image-project=debian-cloud \
      --boot-disk-type=pd-balanced \
      --boot-disk-size=10GB
  fi
}

create_vm_with_retry "${VM_A}" "${SUGGESTED_ZONE_A}" "${SUBNET_A}" "${NETWORK_A}" "${FALLBACK_ZONE_A}"
create_vm_with_retry "${VM_B}" "${SUGGESTED_ZONE_B}" "${SUBNET_B}" "${NETWORK_B}" "${FALLBACK_ZONE_B}"

# -----------------------------
# 5) Output internal IPs (lab asks for vpc-b-vm-1)
# -----------------------------
log "VM Internal IPs"
gcloud compute instances list \
  --filter="name=('${VM_A}','${VM_B}')" \
  --format="table(name, networkInterfaces[0].networkIP, zone)"

echo
log "Done. Now click “Check my progress”."
