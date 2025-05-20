#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Rebuilding and redeploying in Lima VM ===${NC}"

# Copy the updated files to the Lima VM
echo -e "${YELLOW}Copying updated files to Lima VM...${NC}"
limactl copy cmd/lime-ctrl/main.go vvm-dev:/tmp/trashfire-dispenser-machine/cmd/lime-ctrl/main.go
limactl copy cmd/kvm-device-plugin/main.go vvm-dev:/tmp/trashfire-dispenser-machine/cmd/kvm-device-plugin/main.go
limactl copy deploy/flintlock.yaml vvm-dev:/tmp/trashfire-dispenser-machine/deploy/flintlock.yaml

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

echo -e "${BLUE}=== Rebuilding and redeploying inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Set the PATH to include Go
export PATH=$PATH:/usr/local/go/bin

# Check if Go is available
if ! command -v go &> /dev/null; then
    echo -e "${RED}Go is not available. Please install Go first.${NC}"
    exit 1
fi

# Rebuild the binaries
echo -e "${YELLOW}Rebuilding binaries...${NC}"
mkdir -p bin
go build -o bin/lime-ctrl cmd/lime-ctrl/main.go
go build -o bin/kvm-device-plugin cmd/kvm-device-plugin/main.go

# Rebuild the Docker images
echo -e "${YELLOW}Rebuilding Docker images...${NC}"
sudo docker build -t lime-ctrl:latest -f Dockerfile.lime-ctrl .
sudo docker build -t kvm-device-plugin:latest -f Dockerfile.kvm-device-plugin .

# Import the images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
TEMP_DIR=$(mktemp -d)
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo docker save kvm-device-plugin:latest -o "${TEMP_DIR}/kvm-device-plugin.tar"
sudo ctr -n k8s.io images import "${TEMP_DIR}/lime-ctrl.tar"
sudo ctr -n k8s.io images import "${TEMP_DIR}/kvm-device-plugin.tar"
rm -rf "${TEMP_DIR}"

# Delete the existing deployments
echo -e "${YELLOW}Deleting existing deployments...${NC}"
kubectl delete -f deploy/lime-ctrl.yaml --ignore-not-found
kubectl delete -f deploy/kvm-device-plugin.yaml --ignore-not-found
kubectl delete -f deploy/flintlock.yaml --ignore-not-found

# Apply the updated deployments
echo -e "${YELLOW}Applying updated deployments...${NC}"
kubectl apply -f deploy/lime-ctrl.yaml
kubectl apply -f deploy/kvm-device-plugin.yaml
kubectl apply -f deploy/flintlock.yaml

# Wait for the pods to start
echo -e "${YELLOW}Waiting for pods to start...${NC}"
sleep 30

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Rebuild and redeploy completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"