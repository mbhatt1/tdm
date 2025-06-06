#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Creating MicroVM in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Creating MicroVM inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Create a MicroVM custom resource
echo -e "${YELLOW}Creating MicroVM custom resource...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MicroVM
metadata:
  name: test-microvm
spec:
  image: ubuntu:20.04
  command: ["sleep", "infinity"]
  cpu: 1
  memory: 512
  mcpMode: true
EOL

# Wait for the MicroVM to be created
echo -e "${YELLOW}Waiting for MicroVM to be created...${NC}"
sleep 5

# Check the status of the MicroVM
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms

echo -e "${GREEN}MicroVM creation completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"