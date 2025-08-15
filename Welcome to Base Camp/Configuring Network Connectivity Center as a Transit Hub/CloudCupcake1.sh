# --- Step 1: Create Firewall Rule 'fw-a' for vpc-a ---
# This rule allows all incoming TCP, UDP, and ICMP traffic from any source
# to instances in vpc-a. This is a common rule for initial lab setup.
gcloud compute firewall-rules create fw-a \
    --network=vpc-a \
    --action=ALLOW \
    --rules=tcp,udp,icmp \
    --source-ranges=0.0.0.0/0 \
    --direction=INGRESS \
    --priority=1000 # Default priority, can be adjusted if needed

# Similarly, create firewall rule 'fw-b' for vpc-b.
# Assuming similar requirements for fw-b, this will allow common traffic.
gcloud compute firewall-rules create fw-b \
    --network=vpc-b \
    --action=ALLOW \
    --rules=tcp,udp,icmp \
    --source-ranges=0.0.0.0/0 \
    --direction=INGRESS \
    --priority=1000

# --- Step 2: Create VM in vpc-a ---
gcloud compute instances create vpc-a-vm-1 \
    --project=$(gcloud config get-value project) \
    --zone=us-central1-c \
    --machine-type=e2-medium \
    --network-interface=network=vpc-a,subnet=vpc-a-sub1-use4 \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=vpc-a-vm-1-disk \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --no-address # Do not assign an external IP address for internal-only communication

# --- Similarly, create another VM in vpc-b ---
gcloud compute instances create vpc-b-vm-1 \
    --project=$(gcloud config get-value project) \
    --zone=us-west1-b \
    --machine-type=e2-medium \
    --network-interface=network=vpc-b,subnet=vpc-b-sub1-usw2 \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=vpc-b-vm-1-disk \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --no-address # Do not assign an external IP address for internal-only communication

# --- Optional: Get Internal IP of vpc-b-vm-1 ---
# This command will output the internal IP address of vpc-b-vm-1
gcloud compute instances describe vpc-b-vm-1 \
    --zone=us-west1-b \
    --format='value(networkInterfaces[0].networkIp)'
