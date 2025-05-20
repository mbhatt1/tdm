#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Updating main.go files in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Updating main.go files inside Lima VM ===${NC}"

# Set the PATH to include Go
export PATH=$PATH:/usr/local/go/bin

# Check if Go is available
if ! command -v go &> /dev/null; then
    echo -e "${RED}Go is not available. Please install Go first.${NC}"
    exit 1
fi

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Update the lime-ctrl main.go file
echo -e "${YELLOW}Updating lime-ctrl main.go file...${NC}"
cat > cmd/lime-ctrl/main.go << EOL
package main

import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("Starting lime-ctrl...")
	
	// Instead of a deadlock, use a timer
	for {
		fmt.Println("Lime controller running...")
		time.Sleep(60 * time.Second)
	}
}
EOL

# Update the kvm-device-plugin main.go file
echo -e "${YELLOW}Updating kvm-device-plugin main.go file...${NC}"
cat > cmd/kvm-device-plugin/main.go << EOL
package main

import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("Starting kvm-device-plugin...")
	
	// Instead of a deadlock, use a timer
	for {
		fmt.Println("KVM device plugin running...")
		time.Sleep(60 * time.Second)
	}
}
EOL

# Rebuild the binaries
echo -e "${YELLOW}Rebuilding binaries...${NC}"
mkdir -p bin
go build -o bin/lime-ctrl cmd/lime-ctrl/main.go
go build -o bin/kvm-device-plugin cmd/kvm-device-plugin/main.go

# Rebuild the Docker images
echo -e "${YELLOW}Rebuilding Docker images...${NC}"
sudo docker build -t lime-ctrl:latest -f Dockerfile.lime-ctrl .
sudo docker build -t kvm-device-plugin:latest -f Dockerfile.kvm-device-plugin .

# Delete the pods to force a restart
echo -e "${YELLOW}Deleting pods to force a restart...${NC}"
kubectl delete pod -n vvm-system -l app=lime-ctrl
kubectl delete pod -n vvm-system -l app=kvm-device-plugin

# Wait for the pods to restart
echo -e "${YELLOW}Waiting for pods to restart...${NC}"
sleep 10

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Update completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"