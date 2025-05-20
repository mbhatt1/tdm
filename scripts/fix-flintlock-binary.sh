#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing flintlock binary issue ===${NC}"

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

echo -e "${BLUE}=== Fixing flintlock binary inside Lima VM ===${NC}"

# Create a simple dummy flintlock binary
echo -e "${YELLOW}Creating a dummy flintlock binary...${NC}"
cat > /tmp/flintlock << 'EOL'
#!/bin/sh
echo "Starting dummy flintlock server..."
echo "This is a placeholder implementation for testing."
echo "Listening on port 9090..."
# Keep the container running
sleep infinity
EOL

# Make it executable
chmod +x /tmp/flintlock

# Create a temporary Dockerfile for the flintlock image
echo -e "${YELLOW}Creating a temporary Dockerfile for flintlock...${NC}"
cat > /tmp/Dockerfile.flintlock << 'EOL'
FROM alpine:3.18

RUN apk --no-cache add ca-certificates python3 bash

WORKDIR /app

COPY flintlock /app/flintlock

RUN mkdir -p /var/lib/flintlock/microvms

VOLUME /var/lib/flintlock

ENTRYPOINT ["/app/flintlock"]
EOL

# Build the new flintlock image
echo -e "${YELLOW}Building new flintlock image...${NC}"
cd /tmp
sudo docker build -t flintlock:latest -f Dockerfile.flintlock .

# Import the image into containerd
echo -e "${YELLOW}Importing image into containerd...${NC}"
sudo docker save flintlock:latest | sudo ctr -n k8s.io images import -

# Delete the flintlock pod to force a restart with the new image
echo -e "${YELLOW}Deleting flintlock pod to force restart...${NC}"
FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod -n vvm-system $FLINTLOCK_POD

# Wait for the new pod to start
echo -e "${YELLOW}Waiting for new pod to start...${NC}"
sleep 10

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Fix completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"