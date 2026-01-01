#!/bin/bash
# GCP Free Tier GitHub Runner Startup Script
# Optimized for "Golden Image" (Pre-installed dependencies)

set -e

# --- 1. Runtime Config ---
# Enable swap if not already on (it should be on from fstab, but verify)
if ! swapon --show | grep -q "/swapfile"; then
    swapon /swapfile || true
fi

# Ensure Docker is running
systemctl start docker

# --- 2. Configuration Variables ---
GITHUB_REPO="bdchang403/Roadtrip"
REPO_URL="https://github.com/${GITHUB_REPO}"
# Metadata server
PAT=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/github_pat")

if [ -z "$PAT" ]; then
  echo "Error: github_pat metadata not found."
  exit 1
fi

cd /actions-runner

# --- 3. Registration Cleanliness Check ---
# If .runner exists, we might be restarting.
if [ -f .runner ]; then
    echo "Existing runner configuration found. Checking status..."
fi

# --- 4. Get Registration Token ---
echo "Fetching Registration Token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${PAT}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token | jq -r .token)

if [ "$REG_TOKEN" == "null" ]; then
    echo "Failed to get registration token. Check PAT permissions."
    exit 1
fi

# --- 5. Configure & Run (Persistent with Idle Timeout) ---
echo "Configuring Runner..."
export RUNNER_ALLOW_RUNASROOT=1
# Unattended config - using hostname as name
./config.sh --url ${REPO_URL} --token ${REG_TOKEN} --unattended --name "$(hostname)" --labels "gcp-runner" --replace

echo "Installing Runner as Service..."
# Check if service is already installed
if [ ! -f /etc/systemd/system/actions.runner.* ]; then
    ./svc.sh install || true
fi
./svc.sh start

# --- 6. Shutdown / Cleanup Function ---
cleanup() {
    echo "Caught signal! Cleaning up..."
    # 1. Stop service
    ./svc.sh stop
    
    # 2. Get Removal Token
    REM_TOKEN=$(curl -s -X POST -H "Authorization: token ${PAT}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${GITHUB_REPO}/actions/runners/remove-token | jq -r .token)
    
    if [ "$REM_TOKEN" != "null" ]; then
        echo "Deregistering runner..."
        ./config.sh remove --token "$REM_TOKEN"
    fi
    
    # 3. Clean files for next boot (if image is reused, though unlikely for MIG)
    rm -f .runner .credentials
}

# Trap signals for graceful shutdown
trap cleanup EXIT SIGINT SIGTERM

# --- 7. Idle Shutdown Monitor ---
# Monitor for 'Runner.Worker' process which indicates an active job.
# If no job runs for IDLE_TIMEOUT seconds, shut down.
IDLE_TIMEOUT=600 # 10 minutes
CHECK_INTERVAL=30
IDLE_TIMER=0

echo "Starting Idle Monitor (Timeout: ${IDLE_TIMEOUT}s)..."

while true; do
  sleep $CHECK_INTERVAL
  
  if pgrep -f "Runner.Worker" > /dev/null; then
    echo "Job in progress. Resetting idle timer."
    IDLE_TIMER=0
  else
    IDLE_TIMER=$((IDLE_TIMER + CHECK_INTERVAL))
    echo "Runner idle for ${IDLE_TIMER}s..."
  fi

  if [ $IDLE_TIMER -ge $IDLE_TIMEOUT ]; then
    echo "Idle timeout reached (${IDLE_TIMEOUT}s). Shutting down..."
    cleanup # Run cleanup explicitly
    
    # Trigger instance shutdown
    trap - EXIT
    shutdown -h now
    break
  fi
done
