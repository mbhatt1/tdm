#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing Lime Controller in Lima VM ===${NC}"

# Connect to the Lima VM and restart the lime-ctrl pod
limactl shell vvm-dev << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Restarting Lime Controller in Lima VM ===${NC}"

# Delete the lime-ctrl pod to force a restart
echo -e "${YELLOW}Restarting lime-ctrl pod...${NC}"
kubectl delete pod -n vvm-system -l app=lime-ctrl

# Wait for the new pod to start
echo -e "${YELLOW}Waiting for new lime-ctrl pod to start...${NC}"
sleep 10

# Check the status of the lime-ctrl pod
echo -e "${YELLOW}Checking lime-ctrl pod status...${NC}"
kubectl get pods -n vvm-system -l app=lime-ctrl

echo -e "${GREEN}Lime controller restarted!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"