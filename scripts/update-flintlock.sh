#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Updating flintlock in Lima VM ===${NC}"

# Copy the updated files to the Lima VM
echo -e "${YELLOW}Copying updated files to Lima VM...${NC}"
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

echo -e "${BLUE}=== Updating flintlock inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Delete the existing flintlock deployment
echo -e "${YELLOW}Deleting existing flintlock deployment...${NC}"
kubectl delete -f deploy/flintlock.yaml --ignore-not-found

# Apply the updated flintlock deployment
echo -e "${YELLOW}Applying updated flintlock deployment...${NC}"
kubectl apply -f deploy/flintlock.yaml

# Wait for the pod to start
echo -e "${YELLOW}Waiting for pod to start...${NC}"
sleep 30

# Check the status of the pod
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Update completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"