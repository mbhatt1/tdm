#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Updating deployments in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Updating deployments inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Get the image IDs
LIME_CTRL_IMAGE=$(sudo docker images lime-ctrl:latest --format "{{.ID}}")
KVM_DEVICE_PLUGIN_IMAGE=$(sudo docker images kvm-device-plugin:latest --format "{{.ID}}")

echo -e "${YELLOW}lime-ctrl image ID: ${LIME_CTRL_IMAGE}${NC}"
echo -e "${YELLOW}kvm-device-plugin image ID: ${KVM_DEVICE_PLUGIN_IMAGE}${NC}"

# Tag the images with the correct names for Kubernetes
echo -e "${YELLOW}Tagging images for Kubernetes...${NC}"
sudo docker tag ${LIME_CTRL_IMAGE} lime-ctrl:latest
sudo docker tag ${KVM_DEVICE_PLUGIN_IMAGE} kvm-device-plugin:latest

# Import the images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
TEMP_DIR=$(mktemp -d)
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo docker save kvm-device-plugin:latest -o "${TEMP_DIR}/kvm-device-plugin.tar"
sudo ctr -n k8s.io images import "${TEMP_DIR}/lime-ctrl.tar"
sudo ctr -n k8s.io images import "${TEMP_DIR}/kvm-device-plugin.tar"
rm -rf "${TEMP_DIR}"

# Delete the pods to force a restart
echo -e "${YELLOW}Deleting pods to force a restart...${NC}"
kubectl delete pod -n vvm-system -l app=lime-ctrl
kubectl delete pod -n vvm-system -l app=kvm-device-plugin

# Wait for the pods to restart
echo -e "${YELLOW}Waiting for pods to restart...${NC}"
sleep 10

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Update completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"