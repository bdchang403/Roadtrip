#!/bin/bash
# setup-image.sh: Pre-install dependencies for Golden Image (Roadtrip)
set -e

echo "Starting Golden Image Setup..."

# 1. Swap Setup (Persistent in fstab)
echo "Setting up Swap..."
fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
chmod 600 /swapfile
mkswap /swapfile
# Only append if not already present
grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
# sysctl persistence
grep -q 'vm.swappiness=60' /etc/sysctl.conf || echo 'vm.swappiness=60' >> /etc/sysctl.conf

# 2. Install Dependencies
echo "Installing Docker, Git, JQ, GH, Curl, Wget..."
apt-get update
apt-get install -y docker.io git jq curl wget maven

# Ensure Docker is running for pulls
systemctl start docker
systemctl enable docker

# Install Google Chrome (Required for Roadtrip UI tests)
echo "Installing Google Chrome..."
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install -y google-chrome-stable

# Install GitHub CLI
mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install -y gh

# 3. Pre-download GitHub Runner
echo "Downloading GitHub Runner..."
mkdir -p /actions-runner && cd /actions-runner
# Using specific version from original script
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
# Dependencies for runner
./bin/installdependencies.sh

# 4. Pre-pull Common Base Images (Optional, adjust based on Roadtrip needs)
echo "Pre-pulling Docker images..."
docker pull node:20-alpine
docker pull maven:3.8-openjdk-17-slim 
# (Add other images commonly used in Roadtrip workflows if known)

# 5. Cleanup Unique Identifiers
# Ensure no runner config exists
if [ -f .runner ]; then
    echo "Warning: .runner file found. Removing to ensure clean image."
    rm .runner
fi
if [ -f .credentials ]; then
    rm .credentials
fi
# Clear machine-id
truncate -s 0 /etc/machine-id

echo "Golden Image Setup Complete. Ready for snapshot."
