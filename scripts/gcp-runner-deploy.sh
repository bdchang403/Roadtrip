#!/bin/bash
# Deploy GCP Runner Infrastructure for Roadtrip

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ZONE="us-central1-a"
TEMPLATE_NAME="roadtrip-runner-template"
MIG_NAME="roadtrip-runner-mig"
REPO_OWNER="bdchang403"
REPO_NAME="Roadtrip"
# Load from .env if it exists
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# Check if GITHUB_PAT is set, otherwise prompt
if [ -z "$GITHUB_PAT" ]; then
    read -s -p "Enter GitHub PAT: " GITHUB_PAT
    echo ""
fi

echo "Deploying to Project: $PROJECT_ID"
echo "Region: $REGION"

# 0. Cleanup Existing Resources (to allow upgrades/re-runs)
echo "Cleaning up existing resources..."
# Delete MIG if it exists
if gcloud compute instance-groups managed describe $MIG_NAME --zone=$ZONE --project=$PROJECT_ID &>/dev/null; then
    echo "Deleting existing MIG: $MIG_NAME"
    gcloud compute instance-groups managed delete $MIG_NAME --zone=$ZONE --project=$PROJECT_ID --quiet
fi

# Delete Instance Template if it exists (Global)
if gcloud compute instance-templates describe $TEMPLATE_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "Deleting existing Instance Template: $TEMPLATE_NAME"
    gcloud compute instance-templates delete $TEMPLATE_NAME --project=$PROJECT_ID --quiet
fi

# 1. Create Instance Template
echo "Creating Instance Template..."
gcloud compute instance-templates create $TEMPLATE_NAME \
    --project=$PROJECT_ID \
    --machine-type=e2-standard-4 \
    --network-interface=network-tier=PREMIUM,network=default,address= \
    --metadata-from-file=startup-script=./scripts/gcp-startup-script.sh \
    --metadata=github_pat=$GITHUB_PAT \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=default \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=100GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=$TEMPLATE_NAME

# 2. Create Managed Instance Group (MIG)
echo "Creating Managed Instance Group..."
gcloud compute instance-groups managed create $MIG_NAME \
    --project=$PROJECT_ID \
    --base-instance-name=roadtrip-runner \
    --template=$TEMPLATE_NAME \
    --size=2 \
    --zone=$ZONE

# 3. Configure Auto-healing (Optional but recommended)
# We rely on the "shutdown -h now" in the startup script to terminate the instance.
# The MIG will see the instance as not RUNNING and should restart/recreate it.

echo "Deployment Complete."
echo "Monitor the instance: gcloud compute instances list"
