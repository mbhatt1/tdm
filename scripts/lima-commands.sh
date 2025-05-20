#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Running commands in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Running deployment inside Lima VM ===${NC}"

# Tag the Docker images with the correct names
echo -e "${YELLOW}Tagging Docker images...${NC}"
sudo docker tag lime-ctrl:latest docker.io/library/lime-ctrl:latest
sudo docker tag kvm-device-plugin:latest docker.io/library/kvm-device-plugin:latest

# Verify the tagged images
echo -e "${YELLOW}Verifying tagged images...${NC}"
sudo docker images | grep -E 'lime-ctrl|kvm-device-plugin'

# Delete any existing deployments
echo -e "${YELLOW}Deleting any existing deployments...${NC}"
cd /tmp/trashfire-dispenser-machine && kubectl delete -f deploy/ --ignore-not-found || true

# Create the namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system --dry-run=client -o yaml | kubectl apply -f -

# Apply the CRDs
echo -e "${YELLOW}Applying CRDs...${NC}"
cd /tmp/trashfire-dispenser-machine && kubectl apply -f deploy/crds/ --validate=false

# Apply the deployments
echo -e "${YELLOW}Applying deployments...${NC}"
cd /tmp/trashfire-dispenser-machine && kubectl apply -f deploy/lime-ctrl.yaml --validate=false
cd /tmp/trashfire-dispenser-machine && kubectl apply -f deploy/kvm-device-plugin.yaml --validate=false
cd /tmp/trashfire-dispenser-machine && kubectl apply -f deploy/flintlock.yaml --validate=false

# Wait for deployments to start
echo -e "${YELLOW}Waiting for deployments to start...${NC}"
sleep 30

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Deployment completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"