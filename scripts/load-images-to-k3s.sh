#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Loading Docker images to k3s ===${NC}"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if we're running in the Lima VM
if [ ! -f /etc/lima/lima.env ]; then
  echo -e "${RED}This script must be run inside the Lima VM${NC}"
  exit 1
fi

# Check for required commands
if ! command_exists docker; then
  echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
  exit 1
fi

if ! command_exists k3s; then
  echo -e "${RED}k3s is not installed. Please install k3s first.${NC}"
  exit 1
fi

# Create a temporary directory for the images
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Save the Docker images to tar files
echo -e "${YELLOW}Saving Docker images to tar files...${NC}"
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo docker save kvm-device-plugin:latest -o "${TEMP_DIR}/kvm-device-plugin.tar"

# Create a containerd namespace for k3s if it doesn't exist
echo -e "${YELLOW}Creating containerd namespace for k3s...${NC}"
sudo mkdir -p /var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content

# Import the images into k3s
echo -e "${YELLOW}Importing images into k3s...${NC}"
sudo k3s ctr images import "${TEMP_DIR}/lime-ctrl.tar"
sudo k3s ctr images import "${TEMP_DIR}/kvm-device-plugin.tar"

# List the imported images
echo -e "${YELLOW}Listing imported images...${NC}"
sudo k3s ctr images ls | grep -E 'lime-ctrl|kvm-device-plugin'

# Clean up
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"

echo -e "${GREEN}Docker images have been loaded into k3s!${NC}"
echo -e "${GREEN}You can now deploy your applications using these images.${NC}"

# Update the deployment YAML files to use the correct image names
echo -e "${YELLOW}Updating deployment YAML files...${NC}"
cd /tmp/trashfire-dispenser-machine

# Update lime-ctrl.yaml
sed -i 's|image: lime-ctrl:latest|image: docker.io/library/lime-ctrl:latest|g' deploy/lime-ctrl.yaml
sed -i 's|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g' deploy/lime-ctrl.yaml

# Update kvm-device-plugin.yaml
sed -i 's|image: kvm-device-plugin:latest|image: docker.io/library/kvm-device-plugin:latest|g' deploy/kvm-device-plugin.yaml
sed -i 's|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g' deploy/kvm-device-plugin.yaml

echo -e "${GREEN}Deployment YAML files have been updated!${NC}"
echo -e "${GREEN}You can now deploy your applications using the following commands:${NC}"
echo -e "${YELLOW}kubectl apply -f deploy/lime-ctrl.yaml${NC}"
echo -e "${YELLOW}kubectl apply -f deploy/kvm-device-plugin.yaml${NC}"
echo -e "${YELLOW}kubectl apply -f deploy/flintlock.yaml${NC}"