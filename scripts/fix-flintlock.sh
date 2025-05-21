#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing Flintlock Deployment in Lima VM ===${NC}"

# Copy the flintlock.yaml file to the Lima VM
echo -e "${YELLOW}Copying flintlock.yaml to Lima VM...${NC}"
limactl copy deploy/flintlock.yaml vvm-dev:/tmp/flintlock.yaml

# Connect to the Lima VM and apply the fixed flintlock.yaml
limactl shell vvm-dev << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Applying Fixed Flintlock Deployment in Lima VM ===${NC}"

# Apply the fixed flintlock.yaml
echo -e "${YELLOW}Applying fixed flintlock.yaml...${NC}"
kubectl apply -f /tmp/flintlock.yaml

# Delete the flintlock pod to force a restart with the new configuration
echo -e "${YELLOW}Restarting flintlock pod...${NC}"
kubectl delete pod -n vvm-system -l app=flintlock

# Wait for the new pod to start
echo -e "${YELLOW}Waiting for new flintlock pod to start...${NC}"
sleep 10

# Check the status of the flintlock pod
echo -e "${YELLOW}Checking flintlock pod status...${NC}"
kubectl get pods -n vvm-system -l app=flintlock

# Check if the flintlock pod has the correct volume mounts
echo -e "${YELLOW}Checking flintlock pod volume mounts...${NC}"
POD_NAME=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod -n vvm-system $POD_NAME | grep -A 20 "Volumes:"

echo -e "${GREEN}Flintlock deployment fixed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"