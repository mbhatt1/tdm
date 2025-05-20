#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking code execution in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking code execution inside Lima VM ===${NC}"

# Check the shared directory
echo -e "${YELLOW}Checking shared directory...${NC}"
ls -la /tmp/flintlock-data/

# Check the Python script
echo -e "${YELLOW}Checking Python script...${NC}"
cat /tmp/flintlock-data/sample_script.py

# Check the execution request
echo -e "${YELLOW}Checking execution request...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_request.txt ]; then
    cat /tmp/flintlock-data/microvms/execute_request.txt
else
    echo "No execution request found"
fi

# Check the execution response
echo -e "${YELLOW}Checking execution response...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.txt ]; then
    cat /tmp/flintlock-data/microvms/execute_response.txt
else
    echo "No execution response found"
fi

# Check the execution response JSON
echo -e "${YELLOW}Checking execution response JSON...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.json ]; then
    cat /tmp/flintlock-data/microvms/execute_response.json
else
    echo "No execution response JSON found"
fi

echo -e "${GREEN}Execution check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"