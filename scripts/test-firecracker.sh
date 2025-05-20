#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Firecracker Implementation ===${NC}"

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

echo -e "${BLUE}=== Testing Firecracker inside Lima VM ===${NC}"

# Create a test VM
echo -e "${YELLOW}Creating a test VM...${NC}"
fc-vm test-vm create
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to create VM${NC}"
  exit 1
fi

# Start the VM
echo -e "${YELLOW}Starting the VM...${NC}"
fc-vm test-vm start
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to start VM${NC}"
  exit 1
fi

# Create a test script
echo -e "${YELLOW}Creating a test script...${NC}"
cat > test-script.py << EOL
#!/usr/bin/env python3
import os
import sys
import datetime
import platform

print('=== Trashfire Dispensing Machine Test ===')
print('Current time:', datetime.datetime.now())
print('Python version:', sys.version)
print('Process ID:', os.getpid())
print('Platform:', platform.platform())
print('Hostname:', platform.node())

# Create a file
print('\\nCreating a file...')
with open('/tmp/tvm_test.txt', 'w') as f:
    f.write('This file was created inside a Firecracker microVM\\n')
    f.write(f'Current time: {datetime.datetime.now()}\\n')

# Read the file
print('Reading the file:')
with open('/tmp/tvm_test.txt', 'r') as f:
    print(f.read())

print('\\nExecution completed successfully!')
EOL

# Execute the script in the VM
echo -e "${YELLOW}Executing the script in the VM...${NC}"
fc-vm test-vm execute test-script.py
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to execute script in VM${NC}"
  exit 1
fi

# Get the output
echo -e "${YELLOW}Getting the output...${NC}"
fc-vm test-vm output
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to get output from VM${NC}"
  exit 1
fi

# Stop the VM
echo -e "${YELLOW}Stopping the VM...${NC}"
fc-vm test-vm stop
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to stop VM${NC}"
  exit 1
fi

# Delete the VM
echo -e "${YELLOW}Deleting the VM...${NC}"
fc-vm test-vm delete
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to delete VM${NC}"
  exit 1
fi

echo -e "${GREEN}Firecracker test completed successfully!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"