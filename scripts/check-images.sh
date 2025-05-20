#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking images in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking images inside Lima VM ===${NC}"

# Check Docker images
echo -e "${YELLOW}Checking Docker images...${NC}"
sudo docker images

# Check if the images are being used by the pods
echo -e "${YELLOW}Checking image IDs used by pods...${NC}"
kubectl get pods -n vvm-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}'

echo -e "${GREEN}Image check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"