#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Executing custom script in Firecracker microVM ===${NC}"

# Get the script content from the user
if [ $# -eq 0 ]; then
  echo -e "${RED}Please provide a Python script as an argument${NC}"
  echo -e "Usage: $0 \"print('Hello, World!')\"" 
  exit 1
fi

SCRIPT_CONTENT="$1"

# Write the script to a temporary file
TMP_SCRIPT=$(mktemp)
echo "$SCRIPT_CONTENT" > "$TMP_SCRIPT"

# Copy the script to the Lima VM
echo -e "${YELLOW}Copying script to Lima VM...${NC}"
limactl copy "$TMP_SCRIPT" vvm-dev:/tmp/custom_script.py

# Remove the temporary file
rm "$TMP_SCRIPT"

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

echo -e "${BLUE}=== Executing custom script in Firecracker microVM inside Lima VM ===${NC}"

# Copy the script to the flintlock data directory
echo -e "${YELLOW}Copying script to flintlock data directory...${NC}"
sudo cp /tmp/custom_script.py /tmp/flintlock-data/custom_script.py

# Display the script content
echo -e "${YELLOW}Script content:${NC}"
cat /tmp/flintlock-data/custom_script.py

# Create a request to execute the Python script
echo -e "${YELLOW}Creating execution request...${NC}"
sudo bash -c 'cat > /tmp/flintlock-data/microvms/execute_request.txt << EOL
{
  "command": "python3",
  "args": ["/var/lib/flintlock/custom_script.py"],
  "env": {
    "VVM_EXECUTION_ID": "custom-123",
    "VVM_USER": "user123"
  },
  "timeout": 60
}
EOL'

# Wait for the execution to complete
echo -e "${YELLOW}Waiting for execution to complete...${NC}"
sleep 5

# Check if the execution response exists
echo -e "${YELLOW}Checking execution response...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.txt ]; then
    sudo cat /tmp/flintlock-data/microvms/execute_response.txt
else
    echo "No execution response found"
fi

echo -e "${GREEN}Execution completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"