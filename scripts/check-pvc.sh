#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking PVC in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking PVC inside Lima VM ===${NC}"

# Check the status of the PVC
echo -e "${YELLOW}Checking PVC status...${NC}"
kubectl get pvc -n vvm-system

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Describe the pods to see why they're pending
echo -e "${YELLOW}Describing pods...${NC}"
kubectl describe pods -n vvm-system

echo -e "${GREEN}PVC check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"