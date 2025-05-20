#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Deploying shared volume in Lima VM ===${NC}"

# Copy the updated files to the Lima VM
echo -e "${YELLOW}Copying updated files to Lima VM...${NC}"
limactl copy deploy/shared-volume.yaml vvm-dev:/tmp/trashfire-dispenser-machine/deploy/shared-volume.yaml
limactl copy deploy/flintlock.yaml vvm-dev:/tmp/trashfire-dispenser-machine/deploy/flintlock.yaml
limactl copy deploy/lime-ctrl.yaml vvm-dev:/tmp/trashfire-dispenser-machine/deploy/lime-ctrl.yaml

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

echo -e "${BLUE}=== Deploying shared volume inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Delete the existing deployments
echo -e "${YELLOW}Deleting existing deployments...${NC}"
kubectl delete -f deploy/lime-ctrl.yaml --ignore-not-found
kubectl delete -f deploy/flintlock.yaml --ignore-not-found

# Create the namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system

# Apply the shared volume
echo -e "${YELLOW}Applying shared volume...${NC}"
kubectl apply -f deploy/shared-volume.yaml

# Apply the updated deployments
echo -e "${YELLOW}Applying updated deployments...${NC}"
kubectl apply -f deploy/flintlock.yaml
kubectl apply -f deploy/lime-ctrl.yaml

# Wait for the pods to start
echo -e "${YELLOW}Waiting for pods to start...${NC}"
sleep 30

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Deployment completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"