#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Creating MCPSession in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Creating MCPSession inside Lima VM ===${NC}"

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Create an MCPSession custom resource
echo -e "${YELLOW}Creating MCPSession custom resource...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MCPSession
metadata:
  name: test-mcpsession
spec:
  userId: "user123"
  groupId: "group123"
  vmId: "test-microvm"
  sessionType: "interactive"
EOL

# Wait for the MCPSession to be created
echo -e "${YELLOW}Waiting for MCPSession to be created...${NC}"
sleep 5

# Check the status of the MCPSession
echo -e "${YELLOW}Checking MCPSession status...${NC}"
kubectl get mcpsessions

echo -e "${GREEN}MCPSession creation completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"