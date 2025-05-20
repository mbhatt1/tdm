#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking why flintlock pod is crash looping ===${NC}"

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

echo -e "${BLUE}=== Checking flintlock pod inside Lima VM ===${NC}"

# Get the flintlock pod name
FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')
echo -e "${YELLOW}Flintlock pod name: ${FLINTLOCK_POD}${NC}"

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Describe the pod to get more details
echo -e "${YELLOW}Describing flintlock pod...${NC}"
kubectl describe pod -n vvm-system $FLINTLOCK_POD

# Get logs from the current container
echo -e "${YELLOW}Getting logs from current container...${NC}"
kubectl logs -n vvm-system $FLINTLOCK_POD || true

# Get logs from the previous container
echo -e "${YELLOW}Getting logs from previous container...${NC}"
kubectl logs -n vvm-system $FLINTLOCK_POD --previous || true

# Check PV and PVC status
echo -e "${YELLOW}Checking PV and PVC status...${NC}"
kubectl get pv
kubectl get pvc -n vvm-system

# Check if the directory exists and has proper permissions
echo -e "${YELLOW}Checking directory permissions...${NC}"
ls -la /tmp/flintlock-data

# Fix directory permissions if needed
echo -e "${YELLOW}Fixing directory permissions...${NC}"
sudo chmod -R 777 /tmp/flintlock-data
sudo chown -R 1000:1000 /tmp/flintlock-data

echo -e "${GREEN}Check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"