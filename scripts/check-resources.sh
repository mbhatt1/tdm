#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking resources in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking resources inside Lima VM ===${NC}"

# Check the status of the MicroVM resource
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms -o yaml

# Check the status of the MCPSession resource
echo -e "${YELLOW}Checking MCPSession status...${NC}"
kubectl get mcpsessions -o yaml

# Check the shared directory
echo -e "${YELLOW}Checking shared directory...${NC}"
ls -la /tmp/flintlock-data/microvms/

# Check the content of the status files
echo -e "${YELLOW}Checking status files...${NC}"
cat /tmp/flintlock-data/microvms/microvm-status.json
cat /tmp/flintlock-data/microvms/mcpsession-status.json

echo -e "${GREEN}Resource check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"