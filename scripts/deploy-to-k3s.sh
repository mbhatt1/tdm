#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Deploying to k3s in Lima VM ===${NC}"

# Copy the updated YAML files to the Lima VM
echo -e "${YELLOW}Copying YAML files to Lima VM...${NC}"
limactl copy deploy/lime-ctrl.yaml vvm-dev:/tmp/trashfire-dispenser-machine/deploy/lime-ctrl.yaml
limactl copy deploy/kvm-device-plugin.yaml vvm-dev:/tmp/trashfire-dispenser-machine/deploy/kvm-device-plugin.yaml

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

echo -e "${BLUE}=== Deploying to k3s inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Delete any existing deployments
echo -e "${YELLOW}Deleting any existing deployments...${NC}"
kubectl delete -f deploy/ --ignore-not-found || true

# Create the namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system --dry-run=client -o yaml | kubectl apply -f -

# Apply the CRDs
echo -e "${YELLOW}Applying CRDs...${NC}"
kubectl apply -f deploy/crds/ --validate=false

# Apply the deployments
echo -e "${YELLOW}Applying deployments...${NC}"
kubectl apply -f deploy/lime-ctrl.yaml --validate=false
kubectl apply -f deploy/kvm-device-plugin.yaml --validate=false
kubectl apply -f deploy/flintlock.yaml --validate=false

# Wait for deployments to start
echo -e "${YELLOW}Waiting for deployments to start...${NC}"
sleep 30

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Describe any pods that are not running
for pod in $(kubectl get pods -n vvm-system -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}'); do
    echo -e "${YELLOW}Describing pod ${pod}...${NC}"
    kubectl describe pod $pod -n vvm-system
done

echo -e "${GREEN}Deployment completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"