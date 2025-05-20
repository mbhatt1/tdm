#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking flintlock in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking flintlock inside Lima VM ===${NC}"

# Get the flintlock pod name
FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')

# Check if the flintlock pod is running
echo -e "${YELLOW}Checking flintlock pod...${NC}"
kubectl get pods -n vvm-system -l app=flintlock

# Check if the request files exist
echo -e "${YELLOW}Checking request files...${NC}"
kubectl exec -n vvm-system $FLINTLOCK_POD -- ls -la /var/lib/flintlock/microvms/ || echo "Failed to list files"

# Check the content of the request files
echo -e "${YELLOW}Checking request file content...${NC}"
kubectl exec -n vvm-system $FLINTLOCK_POD -- cat /var/lib/flintlock/microvms/requests.txt || echo "File not found"
kubectl exec -n vvm-system $FLINTLOCK_POD -- cat /var/lib/flintlock/microvms/mcp_requests.txt || echo "File not found"

# Check if the response files exist
echo -e "${YELLOW}Checking response files...${NC}"
kubectl exec -n vvm-system $FLINTLOCK_POD -- cat /var/lib/flintlock/microvms/response.txt || echo "File not found"
kubectl exec -n vvm-system $FLINTLOCK_POD -- cat /var/lib/flintlock/microvms/mcp_response.txt || echo "File not found"

# Check the MicroVM status
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms

# Check the MCPSession status
echo -e "${YELLOW}Checking MCPSession status...${NC}"
kubectl get mcpsessions

echo -e "${GREEN}Flintlock check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"