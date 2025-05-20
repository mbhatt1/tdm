#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking flintlock logs in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking flintlock logs inside Lima VM ===${NC}"

# Get the flintlock pod name
FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')

# Check the logs of the flintlock pod
echo -e "${YELLOW}Checking flintlock logs...${NC}"
kubectl logs -n vvm-system $FLINTLOCK_POD --tail=50

echo -e "${GREEN}Log check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"