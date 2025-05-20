#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking logs in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking logs inside Lima VM ===${NC}"

# Check the logs of the lime-ctrl pod
echo -e "${YELLOW}Checking logs of lime-ctrl pod...${NC}"
kubectl logs -n vvm-system -l app=lime-ctrl

# Check the logs of the kvm-device-plugin pod
echo -e "${YELLOW}Checking logs of kvm-device-plugin pod...${NC}"
kubectl logs -n vvm-system -l app=kvm-device-plugin

# Check the logs of the flintlock pod
echo -e "${YELLOW}Checking logs of flintlock pod...${NC}"
kubectl logs -n vvm-system -l app=flintlock

echo -e "${GREEN}Log check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"