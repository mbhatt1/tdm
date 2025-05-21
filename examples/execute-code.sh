#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Executing Code in MicroVM ===${NC}"

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

echo -e "${BLUE}=== Executing Code in MicroVM inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Create a more complex Python script to execute
echo -e "${YELLOW}Creating Python script...${NC}"
sudo bash -c 'cat > /tmp/flintlock-data/complex_example.py << EOL
import os
import sys
import json
import time
from datetime import datetime

def main():
    print("=== Virtual VM (VVM) System Demo ===")
    print("Current time:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("Python version:", sys.version)
    print("Process ID:", os.getpid())
    
    # Simulate some computation
    print("\nPerforming computation...")
    result = 0
    for i in range(1000000):
        result += i
    print("Sum of numbers from 0 to 999999:", result)
    
    # Simulate file operations
    print("\nPerforming file operations...")
    with open("/tmp/vvm_test_file.txt", "w") as f:
        f.write("This file was created by the VVM system\n")
        f.write("Current time: " + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "\n")
    
    print("File created successfully")
    with open("/tmp/vvm_test_file.txt", "r") as f:
        content = f.read()
    print("File content:\n" + content)
    
    # Return a JSON result
    result_dict = {
        "status": "success",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "computation_result": result,
        "file_created": "/tmp/vvm_test_file.txt"
    }
    
    print("\nJSON result:")
    print(json.dumps(result_dict, indent=2))
    return result_dict

if __name__ == "__main__":
    main()
EOL'

# Create a request to execute the Python script
echo -e "${YELLOW}Creating execution request...${NC}"
sudo bash -c 'cat > /tmp/flintlock-data/microvms/execute_request.txt << EOL
{
  "command": "python3",
  "args": ["/var/lib/flintlock/complex_example.py"],
  "env": {
    "VVM_EXECUTION_ID": "test-123",
    "VVM_USER": "user123"
  },
  "timeout": 60
}
EOL'

# Execute in the VM (let flintlock handle it)
echo -e "${YELLOW}Executing Python in MicroVM...${NC}"
echo "Waiting for flintlock to process the request..."
sleep 10

# Display the execution result
echo -e "${YELLOW}Execution result:${NC}"
sudo cat /tmp/flintlock-data/microvms/execute_response.txt

echo -e "${GREEN}Execution completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"