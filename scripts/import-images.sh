#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Importing Docker images to containerd in Lima VM ===${NC}"

# Connect to the Lima VM and run commands
limactl shell vvm-dev << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Importing Docker images to containerd ===${NC}"

# Create a temporary directory for the images
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Save the Docker images to tar files
echo -e "${YELLOW}Saving Docker images to tar files...${NC}"
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo docker save kvm-device-plugin:latest -o "${TEMP_DIR}/kvm-device-plugin.tar"

# Import the images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
sudo k3s ctr images import "${TEMP_DIR}/lime-ctrl.tar"
sudo k3s ctr images import "${TEMP_DIR}/kvm-device-plugin.tar"

# List the imported images
echo -e "${YELLOW}Listing imported images in containerd...${NC}"
sudo k3s ctr images ls | grep -E 'lime-ctrl|kvm-device-plugin'

# Clean up
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"

echo -e "${GREEN}Docker images have been imported into containerd!${NC}"

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Import completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"