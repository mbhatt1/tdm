#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Updating lime-ctrl in Lima VM ===${NC}"

# Copy the updated files to the Lima VM
echo -e "${YELLOW}Copying updated files to Lima VM...${NC}"
limactl copy cmd/lime-ctrl/main.go vvm-dev:/tmp/trashfire-dispenser-machine/cmd/lime-ctrl/main.go

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

echo -e "${BLUE}=== Updating lime-ctrl inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Set the PATH to include Go
export PATH=$PATH:/usr/local/go/bin

# Check if Go is available
if ! command -v go &> /dev/null; then
    echo -e "${RED}Go is not available. Please install Go first.${NC}"
    exit 1
fi

# Rebuild the lime-ctrl binary
echo -e "${YELLOW}Rebuilding lime-ctrl binary...${NC}"
mkdir -p bin
go build -o bin/lime-ctrl cmd/lime-ctrl/main.go

# Rebuild the lime-ctrl Docker image
echo -e "${YELLOW}Rebuilding lime-ctrl Docker image...${NC}"
sudo docker build -t lime-ctrl:latest -f Dockerfile.lime-ctrl .

# Import the image into containerd
echo -e "${YELLOW}Importing lime-ctrl image into containerd...${NC}"
TEMP_DIR=$(mktemp -d)
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo ctr -n k8s.io images import "${TEMP_DIR}/lime-ctrl.tar"
rm -rf "${TEMP_DIR}"

# Delete the existing lime-ctrl pod
echo -e "${YELLOW}Deleting existing lime-ctrl pod...${NC}"
kubectl delete pod -n vvm-system -l app=lime-ctrl

# Wait for the pod to restart
echo -e "${YELLOW}Waiting for pod to restart...${NC}"
sleep 30

# Check the status of the pod
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Update completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"