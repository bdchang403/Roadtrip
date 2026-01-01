#!/bin/bash
# build-image.sh: Automates Golden Image creation for Roadtrip
# Usage: ./build-image.sh
set -e

PROJECT_ID="myhackeryouproject"
ZONE="us-central1-a"
INSTANCE_NAME="roadtrip-runner-builder"
IMAGE_NAME="roadtrip-runner-golden-image"
IMAGE_FAMILY="roadtrip-runner-image"

echo "Building Golden Image in project $PROJECT_ID..."

# 0. Cleanup stale resources
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID &>/dev/null; then
    echo "Deleting stale builder instance..."
    gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID --quiet
fi

# 1. Create temporary instance
echo "Creating temporary builder instance..."
gcloud compute instances create $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-balanced \
    --metadata-from-file=startup-script=./scripts/setup-image.sh

echo "Waiting for setup to complete (approx 5-10 mins)..."
# Simple wait loop checking serial port output for "Golden Image Setup Complete"
while true; do
    STATUS=$(gcloud compute instances get-serial-port-output $INSTANCE_NAME --zone=$ZONE 2>&1)
    if echo "$STATUS" | grep -q "Golden Image Setup Complete"; then
        echo "Setup finished successfully."
        break
    fi
    echo -n "."
    sleep 20
done

# 2. Stop Instance
echo "Stopping instance..."
gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE

# 3. Create Image
echo "Creating image $IMAGE_NAME..."
# Delete image if exists
if gcloud compute images describe $IMAGE_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "Deleting existing image..."
    gcloud compute images delete $IMAGE_NAME --project=$PROJECT_ID --quiet
fi

gcloud compute images create $IMAGE_NAME \
    --project=$PROJECT_ID \
    --source-disk=$INSTANCE_NAME \
    --source-disk-zone=$ZONE \
    --family=$IMAGE_FAMILY

# 4. Cleanup
echo "Cleaning up builder instance..."
gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet

echo "Golden Image $IMAGE_NAME created successfully."
