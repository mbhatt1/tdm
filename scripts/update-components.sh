#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Updating VVM components in Lima VM ===${NC}"

# Build flintlock in Lima VM
echo -e "${YELLOW}Building flintlock in Lima VM...${NC}"
./scripts/build-flintlock-in-lima.sh

# Copy updated files to Lima VM
echo -e "${YELLOW}Copying updated files to Lima VM...${NC}"
limactl copy --recursive pkg vvm-dev:/home/mbhatt/tvm/
limactl copy --recursive cmd vvm-dev:/home/mbhatt/tvm/
limactl copy --recursive deploy vvm-dev:/home/mbhatt/tvm/
limactl copy --recursive build vvm-dev:/home/mbhatt/tvm/
limactl copy --recursive scripts vvm-dev:/home/mbhatt/tvm/
limactl copy go.mod vvm-dev:/home/mbhatt/tvm/
limactl copy go.sum vvm-dev:/home/mbhatt/tvm/

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

echo -e "${BLUE}=== Updating VVM components inside Lima VM ===${NC}"

# Change to the tvm directory
cd ~/tvm

# Rebuild lime-ctrl binary
echo -e "${YELLOW}Rebuilding lime-ctrl binary...${NC}"
mkdir -p bin
go build -o bin/lime-ctrl ./cmd/lime-ctrl

# Rebuild lime-ctrl Docker image
echo -e "${YELLOW}Rebuilding lime-ctrl Docker image...${NC}"
docker build -t lime-ctrl:latest -f build/lime-ctrl/Dockerfile .

# Import lime-ctrl image into containerd
echo -e "${YELLOW}Importing lime-ctrl image into containerd...${NC}"
docker save lime-ctrl:latest | sudo ctr -n=k8s.io images import -

# Delete existing deployments
echo -e "${YELLOW}Deleting existing deployments...${NC}"
kubectl delete namespace vvm-system || true
kubectl delete clusterrole lime-ctrl || true
kubectl delete clusterrolebinding lime-ctrl || true
kubectl delete clusterrole flintlock || true
kubectl delete clusterrolebinding flintlock || true

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system

# Apply updated deployments
echo -e "${YELLOW}Applying updated deployments...${NC}"
kubectl apply -f deploy/flintlock.yaml
kubectl apply -f deploy/lime-ctrl.yaml

# Wait for pods to start
echo -e "${YELLOW}Waiting for pods to start...${NC}"
sleep 30

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Update completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"