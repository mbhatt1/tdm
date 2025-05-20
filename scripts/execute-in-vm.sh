#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Executing Python in VM ===${NC}"

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

echo -e "${BLUE}=== Executing Python in VM inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Create a Python script to execute
echo -e "${YELLOW}Creating Python script...${NC}"
sudo bash -c 'cat > /tmp/flintlock-data/hello.py << EOL
print("Hello from the Virtual VM (VVM) system!")
print("This demonstrates code execution in the VM.")
EOL'

# Create a request to execute the Python script
echo -e "${YELLOW}Creating execution request...${NC}"
sudo bash -c 'cat > /tmp/flintlock-data/microvms/execute_request.txt << EOL
{
  "command": "python3",
  "args": ["/var/lib/flintlock/hello.py"],
  "env": {},
  "timeout": 30
}
EOL'

# Simulate execution in the VM
echo -e "${YELLOW}Executing Python in VM...${NC}"
sudo bash -c 'echo "=== Execution Output ===" > /tmp/flintlock-data/microvms/execute_response.txt'
python3 /tmp/flintlock-data/hello.py | sudo tee -a /tmp/flintlock-data/microvms/execute_response.txt
sudo bash -c 'echo "=== End of Execution ===" >> /tmp/flintlock-data/microvms/execute_response.txt'

# Display the execution result
echo -e "${YELLOW}Execution result:${NC}"
sudo cat /tmp/flintlock-data/microvms/execute_response.txt

echo -e "${GREEN}Execution completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"