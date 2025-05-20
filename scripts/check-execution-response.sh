#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking execution response in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking execution response inside Lima VM ===${NC}"

# Check the execution response file
echo -e "${YELLOW}Checking execution response file...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.txt ]; then
    sudo cat /tmp/flintlock-data/microvms/execute_response.txt
else
    echo "No execution response file found"
fi

# Check the execution response JSON file
echo -e "${YELLOW}Checking execution response JSON file...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.json ]; then
    sudo cat /tmp/flintlock-data/microvms/execute_response.json
else
    echo "No execution response JSON file found"
fi

echo -e "${GREEN}Check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"