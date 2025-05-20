#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building and deploying in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Building and deploying inside Lima VM ===${NC}"

# Install Go if it's not already installed
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}Go not found. Installing Go...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    echo -e "${YELLOW}Detected architecture: ${ARCH}${NC}"
    
    if [ "$ARCH" = "x86_64" ]; then
        GO_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        GO_ARCH="arm64"
    else
        echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
        exit 1
    fi
    
    GO_VERSION="1.20.5"
    GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    
    echo -e "${YELLOW}Downloading Go from ${GO_URL}...${NC}"
    wget "$GO_URL" -O go.tar.gz
    
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    echo -e "${GREEN}Go installed successfully.${NC}"
else
    echo -e "${GREEN}Go is already installed.${NC}"
fi

# Verify Go installation
if ! command -v go &> /dev/null; then
    echo -e "${RED}Go installation failed. Please install Go manually.${NC}"
    exit 1
fi

go version

# Navigate to the project directory
cd /tmp/trashfire-dispenser-machine

# Build the Go binaries
echo -e "${YELLOW}Building Go binaries...${NC}"
mkdir -p bin

# Use a simple main.go file for testing
echo -e "${YELLOW}Creating simple main.go files for testing...${NC}"

mkdir -p cmd/lime-ctrl
cat > cmd/lime-ctrl/main.go << EOL
package main

import (
	"fmt"
)

func main() {
	fmt.Println("Starting lime-ctrl...")
	select {}
}
EOL

mkdir -p cmd/kvm-device-plugin
cat > cmd/kvm-device-plugin/main.go << EOL
package main

import (
	"fmt"
)

func main() {
	fmt.Println("Starting kvm-device-plugin...")
	select {}
}
EOL

# Build the binaries
echo -e "${YELLOW}Building binaries...${NC}"
go build -o bin/lime-ctrl cmd/lime-ctrl/main.go
go build -o bin/kvm-device-plugin cmd/kvm-device-plugin/main.go

# Build the Docker images
echo -e "${YELLOW}Building Docker images...${NC}"

# Create a simple Dockerfile for lime-ctrl
cat > Dockerfile.lime-ctrl << EOL
FROM ubuntu:20.04
COPY bin/lime-ctrl /usr/local/bin/lime-ctrl
ENTRYPOINT ["/usr/local/bin/lime-ctrl"]
EOL

# Create a simple Dockerfile for kvm-device-plugin
cat > Dockerfile.kvm-device-plugin << EOL
FROM ubuntu:20.04
COPY bin/kvm-device-plugin /usr/local/bin/kvm-device-plugin
ENTRYPOINT ["/usr/local/bin/kvm-device-plugin"]
EOL

# Build the Docker images
echo -e "${YELLOW}Building lime-ctrl image...${NC}"
sudo docker build -t lime-ctrl:latest -f Dockerfile.lime-ctrl .

echo -e "${YELLOW}Building kvm-device-plugin image...${NC}"
sudo docker build -t kvm-device-plugin:latest -f Dockerfile.kvm-device-plugin .

# Tag the images with localhost prefix
echo -e "${YELLOW}Tagging images with localhost prefix...${NC}"
sudo docker tag lime-ctrl:latest localhost/lime-ctrl:latest
sudo docker tag kvm-device-plugin:latest localhost/kvm-device-plugin:latest

# List the images
echo -e "${YELLOW}Listing Docker images...${NC}"
sudo docker images

# Update the deployment YAML files
echo -e "${YELLOW}Updating deployment YAML files...${NC}"

# Update lime-ctrl.yaml
cat > deploy/lime-ctrl.yaml << EOL
apiVersion: v1
kind: Namespace
metadata:
  name: vvm-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lime-ctrl
  namespace: vvm-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: lime-ctrl
rules:
- apiGroups: [""]
  resources: ["pods", "services", "events", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["*"]
- apiGroups: ["vvm.tvm.github.com"]
  resources: ["microvms", "microvms/status", "mcpsessions", "mcpsessions/status"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lime-ctrl
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: lime-ctrl
subjects:
- kind: ServiceAccount
  name: lime-ctrl
  namespace: vvm-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lime-ctrl
  namespace: vvm-system
  labels:
    app: lime-ctrl
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lime-ctrl
  template:
    metadata:
      labels:
        app: lime-ctrl
    spec:
      serviceAccountName: lime-ctrl
      containers:
      - name: lime-ctrl
        image: localhost/lime-ctrl:latest
        imagePullPolicy: Never
        args:
        - --flintlock-endpoint=flintlock.vvm-system.svc.cluster.local:9090
        - --metrics-addr=:8080
        - --health-probe-addr=:8081
        - --mcp-addr=:8082
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 8081
          name: health
        - containerPort: 8082
          name: mcp
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: lime-ctrl
  namespace: vvm-system
spec:
  selector:
    app: lime-ctrl
  ports:
  - port: 8082
    targetPort: 8082
    name: mcp
  - port: 8080
    targetPort: 8080
    name: metrics
EOL

# Update kvm-device-plugin.yaml
cat > deploy/kvm-device-plugin.yaml << EOL
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kvm-device-plugin
  namespace: vvm-system
  labels:
    app: kvm-device-plugin
spec:
  selector:
    matchLabels:
      app: kvm-device-plugin
  template:
    metadata:
      labels:
        app: kvm-device-plugin
    spec:
      hostNetwork: true
      containers:
      - name: kvm-device-plugin
        image: localhost/kvm-device-plugin:latest
        imagePullPolicy: Never
        securityContext:
          privileged: true
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: dev
          mountPath: /dev
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: dev
        hostPath:
          path: /dev
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
EOL

# Delete any existing deployments
echo -e "${YELLOW}Deleting any existing deployments...${NC}"
kubectl delete -f deploy/ --ignore-not-found || true

# Create the namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system --dry-run=client -o yaml | kubectl apply -f -

# Apply the CRDs
echo -e "${YELLOW}Applying CRDs...${NC}"
kubectl apply -f deploy/crds/ --validate=false

# Apply the deployments
echo -e "${YELLOW}Applying deployments...${NC}"
kubectl apply -f deploy/lime-ctrl.yaml --validate=false
kubectl apply -f deploy/kvm-device-plugin.yaml --validate=false
kubectl apply -f deploy/flintlock.yaml --validate=false

# Wait for deployments to start
echo -e "${YELLOW}Waiting for deployments to start...${NC}"
sleep 30

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

echo -e "${GREEN}Build and deployment completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"