#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking pods in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking pods inside Lima VM ===${NC}"

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Describe any pods that are not running
for pod in $(kubectl get pods -n vvm-system | grep -v Running | grep -v NAME | awk '{print $1}'); do
    echo -e "${YELLOW}Describing pod ${pod}...${NC}"
    kubectl describe pod $pod -n vvm-system
    
    echo -e "${YELLOW}Checking logs of pod ${pod}...${NC}"
    kubectl logs $pod -n vvm-system || echo -e "${RED}Failed to get logs for ${pod}${NC}"
done

echo -e "${GREEN}Pod check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"