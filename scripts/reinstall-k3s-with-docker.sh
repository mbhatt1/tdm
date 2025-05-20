#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Reinstalling k3s with Docker support ===${NC}"

# Stop and uninstall k3s
echo -e "${YELLOW}Stopping and uninstalling k3s...${NC}"
sudo /usr/local/bin/k3s-uninstall.sh || true

# Wait for k3s to be fully uninstalled
echo -e "${YELLOW}Waiting for k3s to be fully uninstalled...${NC}"
sleep 10

# Install k3s with Docker support
echo -e "${YELLOW}Installing k3s with Docker support...${NC}"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--docker" sh -

# Wait for k3s to be ready
echo -e "${YELLOW}Waiting for k3s to be ready...${NC}"
sudo k3s kubectl wait --for=condition=Ready node/$(hostname) --timeout=60s || true

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl...${NC}"
mkdir -p ~/.kube
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
chmod 600 ~/.kube/config

# Verify k3s is running with Docker
echo -e "${YELLOW}Verifying k3s is running with Docker...${NC}"
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A

echo -e "${GREEN}k3s has been reinstalled with Docker support!${NC}"
echo -e "${GREEN}You can now deploy your applications using Docker images.${NC}"