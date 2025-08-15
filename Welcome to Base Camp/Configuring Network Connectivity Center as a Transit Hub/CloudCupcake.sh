#!/bin/bash
# cloudcupcake_ha_vpn.sh
# Automates HA VPN + BGP setup between two VPCs
# Author: CloudCupcake 🍰

set -e

# --- Auto-detect Project and Zone ---
PROJECT_ID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)

if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ ERROR: No project set. Run: gcloud config set project PROJECT_ID"
  exit 1
fi
if [[ -z "$ZONE" ]]; then
  echo "❌ ERROR: No zone set. Run: gcloud config set compute/zone ZONE"
  exit 1
fi

echo "✅ Using Project: $PROJECT_ID"
echo "✅ Using Zone: $ZONE"

REGION=$(echo "$ZONE" | sed 's/-[a-z]$//')
echo "✅ Using Region: $REGION"

# --- Variables ---
VPC1="vpc-a"
VPC2="vpc-b"
VPN_GATEWAY1="vpn-gw-a"
VPN_GATEWAY2="vpn-gw-b"
ROUTER1="cr-a"
ROUTER2="cr-b"
ASN1=65001
ASN2=65002

# --- Create VPCs ---
echo "🚀 Creating VPCs..."
gcloud compute networks create $VPC1 --subnet-mode=custom
gcloud compute networks create $VPC2 --subnet-mode=custom

gcloud compute networks subnets create subnet-a --network=$VPC1 --region=$REGION --range=10.0.1.0/24
gcloud compute networks subnets create subnet-b --network=$VPC2 --region=$REGION --range=10.0.2.0/24

# --- Create HA VPN Gateways ---
echo "🚀 Creating HA VPN Gateways..."
gcloud compute vpn-gateways create $VPN_GATEWAY1 --network=$VPC1 --region=$REGION
gcloud compute vpn-gateways create $VPN_GATEWAY2 --network=$VPC2 --region=$REGION

# --- Create Cloud Routers ---
echo "🚀 Creating Cloud Routers..."
gcloud compute routers create $ROUTER1 \
    --network=$VPC1 \
    --asn=$ASN1 \
    --region=$REGION

gcloud compute routers create $ROUTER2 \
    --network=$VPC2 \
    --asn=$ASN2 \
    --region=$REGION

# --- Get Gateway IPs ---
IP1=$(gcloud compute vpn-gateways describe $VPN_GATEWAY1 --region=$REGION --format="value(ip_address)")
IP2=$(gcloud compute vpn-gateways describe $VPN_GATEWAY2 --region=$REGION --format="value(ip_address)")

echo "📡 Gateway A IP: $IP1"
echo "📡 Gateway B IP: $IP2"

# --- Create VPN Tunnels ---
echo "🚀 Creating VPN Tunnels..."
gcloud compute vpn-tunnels create tunnel-a-to-b \
    --peer-gcp-gateway=$VPN_GATEWAY2 \
    --region=$REGION \
    --ike-version=2 \
    --shared-secret=cloudcupcake \
    --router=$ROUTER1 \
    --vpn-gateway=$VPN_GATEWAY1

gcloud compute vpn-tunnels create tunnel-b-to-a \
    --peer-gcp-gateway=$VPN_GATEWAY1 \
    --region=$REGION \
    --ike-version=2 \
    --shared-secret=cloudcupcake \
    --router=$ROUTER2 \
    --vpn-gateway=$VPN_GATEWAY2

# --- Create BGP Interfaces ---
echo "🚀 Configuring BGP..."
gcloud compute routers add-interface $ROUTER1 \
    --interface-name=if-a \
    --ip-address=169.254.0.1 \
    --mask-length=30 \
    --vpn-tunnel=tunnel-a-to-b \
    --region=$REGION

gcloud compute routers add-interface $ROUTER2 \
    --interface-name=if-b \
    --ip-address=169.254.0.2 \
    --mask-length=30 \
    --vpn-tunnel=tunnel-b-to-a \
    --region=$REGION

# --- Add BGP Peers ---
gcloud compute routers add-bgp-peer $ROUTER1 \
    --peer-name=peer-to-b \
    --interface-name=if-a \
    --peer-ip-address=169.254.0.2 \
    --peer-asn=$ASN2 \
    --region=$REGION

gcloud compute routers add-bgp-peer $ROUTER2 \
    --peer-name=peer-to-a \
    --interface-name=if-b \
    --peer-ip-address=169.254.0.1 \
    --peer-asn=$ASN1 \
    --region=$REGION

echo "🎉 HA VPN with BGP setup complete!"
