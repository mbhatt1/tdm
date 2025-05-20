#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking lime-ctrl in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking lime-ctrl inside Lima VM ===${NC}"

# Get the lime-ctrl pod name
LIME_CTRL_POD=$(kubectl get pods -n vvm-system -l app=lime-ctrl -o jsonpath='{.items[0].metadata.name}')

# Check if the lime-ctrl pod is running
echo -e "${YELLOW}Checking lime-ctrl pod...${NC}"
kubectl get pods -n vvm-system -l app=lime-ctrl

# Check the logs of the lime-ctrl pod
echo -e "${YELLOW}Checking lime-ctrl logs...${NC}"
kubectl logs -n vvm-system $LIME_CTRL_POD

# Check if the lime-ctrl pod has access to the flintlock directory
echo -e "${YELLOW}Checking if lime-ctrl has access to flintlock directory...${NC}"
kubectl exec -n vvm-system $LIME_CTRL_POD -- ls -la /var/lib/flintlock/ || echo "Directory not found or not accessible"

# Check if the lime-ctrl pod has created the request files
echo -e "${YELLOW}Checking if lime-ctrl has created request files...${NC}"
kubectl exec -n vvm-system $LIME_CTRL_POD -- ls -la /var/lib/flintlock/microvms/ || echo "Directory not found or not accessible"

echo -e "${GREEN}Lime-ctrl check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"