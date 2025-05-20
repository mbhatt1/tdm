#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running inside Lima, but allow override with environment variable
if [ ! -f /etc/lima-release ] && [ -z "$SKIP_LIMA_CHECK" ]; then
    echo -e "${RED}ERROR: This script must be run inside the Lima VM, not directly on macOS.${NC}"
    echo -e "${YELLOW}Please follow these steps:${NC}"
    echo -e "1. Run the setup script first: ${GREEN}./scripts/setup-lima.sh${NC}"
    echo -e "2. Enter the Lima VM: ${GREEN}limactl shell vvm-dev${NC}"
    echo -e "3. Navigate to the project directory: ${GREEN}cd /tmp/trashfire-dispenser-machine${NC}"
    echo -e "4. Run this script again: ${GREEN}./examples/execute-code.sh${NC}"
    exit 1
fi

# Default values
VM_ID="example-vm"
NAMESPACE="default"
CODE="print('Hello from Python in MicroVM!')"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --vm-id)
      VM_ID="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --code)
      CODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "${YELLOW}Executing code in MicroVM ${VM_ID} in namespace ${NAMESPACE}...${NC}"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}jq is not installed. Please install it first:${NC}"
    echo "sudo apt-get install -y jq"
    exit 1
fi

# Get the lime-ctrl service endpoint
LIME_CTRL_ENDPOINT=$(kubectl get svc -n vvm-system lime-ctrl -o jsonpath='{.spec.clusterIP}')

if [ -z "$LIME_CTRL_ENDPOINT" ]; then
  echo -e "${RED}Failed to get lime-ctrl service endpoint.${NC}"
  echo -e "${YELLOW}Make sure the lime-ctrl service is running:${NC}"
  echo "kubectl get svc -n vvm-system"
  exit 1
fi

# Execute the code
echo -e "${YELLOW}Sending request to lime-ctrl...${NC}"
RESPONSE=$(curl -s -X POST "http://${LIME_CTRL_ENDPOINT}:8082/api/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"vmId\": \"${VM_ID}\",
    \"namespace\": \"${NAMESPACE}\",
    \"command\": [\"python\", \"-c\", \"${CODE}\"]
  }")

echo -e "${GREEN}Response:${NC}"
echo "$RESPONSE" | jq . || echo "$RESPONSE"

echo -e "${GREEN}Code execution complete.${NC}"