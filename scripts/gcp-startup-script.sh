#!/bin/bash
# GCP Free Tier GitHub Runner Startup Script
# Optimized for e2-micro (2 vCPU, 1 GB RAM) or larger

set -e

# --- 1. Swap Configuration (Critical for 1GB RAM) ---
echo "Setting up Swap..."
# Create 4GB swap file (standard HDD is slow but necessary)
fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
# Tweak swappiness to prefer swap over OOM kill
sysctl vm.swappiness=60
echo 'vm.swappiness=60' >> /etc/sysctl.conf

# --- 2. Install Dependencies ---
echo "Installing Docker and Git..."
apt-get update
apt-get install -y docker.io git jq curl maven

echo "Installing Google Chrome..."
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install -y google-chrome-stable

echo "Installing GitHub CLI (gh)..."
# Create keyring directory if it doesn't exist
mkdir -p -m 755 /etc/apt/keyrings
# Download and install GitHub CLI keyring
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
# Add GitHub CLI repo
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
# Update and install gh
apt-get update
apt-get install -y gh

systemctl enable --now docker
# Allow default user to run docker if needed (though runner runs as root usually in this script)

# --- 3. Install GitHub Runner ---
echo "Installing GitHub Runner..."
mkdir /actions-runner && cd /actions-runner
# ARM64 or x64? e2-micro/standard are x64.
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# --- 4. Configuration Variables ---
# INJECTED_PAT will be replaced by the deploy script or passed via metadata
GITHUB_REPO="bdchang403/Roadtrip"
REPO_URL="https://github.com/${GITHUB_REPO}"
# Metadata server is available on GCP VMs
PAT=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/github_pat")

if [ -z "$PAT" ]; then
  echo "Error: github_pat metadata not found."
  exit 1
fi

# --- 5. Get Registration Token ---
echo "Fetching Registration Token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${PAT}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token | jq -r .token)

if [ "$REG_TOKEN" == "null" ]; then
    echo "Failed to get registration token. Check PAT permissions."
    exit 1
fi

# --- 6. Configure & Run (Persistent with Idle Timeout) ---
echo "Configuring Runner..."
# Removed --ephemeral to allow multiple jobs
export RUNNER_ALLOW_RUNASROOT=1
./config.sh --url ${REPO_URL} --token ${REG_TOKEN} --unattended --name "$(hostname)" --labels "gcp-micro"

echo "Installing Runner as Service..."
./svc.sh install
./svc.sh start

# --- 7. Idle Shutdown Monitor ---
# Monitor for 'Runner.Worker' process which indicates an active job.
# If no job runs for IDLE_TIMEOUT seconds, shut down.
IDLE_TIMEOUT=600 # 10 minutes
CHECK_INTERVAL=30
IDLE_TIMER=0

echo "Starting Idle Monitor (Timeout: ${IDLE_TIMEOUT}s)..."

while true; do
  sleep $CHECK_INTERVAL
  
  # Check if Runner.Worker is running (indicates active job)
  if pgrep -f "Runner.Worker" > /dev/null; then
    echo "Job in progress. Resetting idle timer."
    IDLE_TIMER=0
  else
    IDLE_TIMER=$((IDLE_TIMER + CHECK_INTERVAL))
    echo "Runner idle for ${IDLE_TIMER}s..."
  fi

  if [ $IDLE_TIMER -ge $IDLE_TIMEOUT ]; then
    echo "Idle timeout reached (${IDLE_TIMEOUT}s). Shutting down..."
    # Deregister runner before shutdown (optional but clean)
    # We can't easily deregister without the token, but the MIG replacement handles it eventually.
    # Just shutdown.
    shutdown -h now
    break
  fi
done
