#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building and Deploying Trashfire Vending Machine to Kubernetes in Lima VM ===${NC}"

# Create a temporary directory for the code without .git
echo -e "${YELLOW}Creating temporary directory...${NC}"
TEMP_DIR=$(mktemp -d)
rsync -av --exclude='.git' --exclude='node_modules' . $TEMP_DIR/

# Create the directory in Lima VM
echo -e "${YELLOW}Creating directory in Lima VM...${NC}"
limactl shell vvm-dev mkdir -p /home/mbhatt.linux/tvm/

# Copy the code to Lima VM
echo -e "${YELLOW}Copying code to Lima VM...${NC}"
limactl copy --recursive $TEMP_DIR/ vvm-dev:/home/mbhatt.linux/tvm/

# Clean up temporary directory
rm -rf $TEMP_DIR

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

# Change to the tvm directory
cd ~/tvm

# Build the components using Docker with Go 1.24
echo -e "${YELLOW}Building components using Docker...${NC}"
mkdir -p bin

# Create a temporary Dockerfile for building
cat > Dockerfile.build << EOL
FROM golang:1.24

WORKDIR /app
COPY . .

# Fix go.mod and go.sum with all required dependencies
RUN go mod tidy
RUN go get github.com/sirupsen/logrus
RUN go get google.golang.org/genproto/googleapis/api/httpbody
RUN go get google.golang.org/genproto/googleapis/rpc/status
RUN go get google.golang.org/genproto/googleapis/api/annotations
RUN go get github.com/liquidmetal-dev/flintlock/api/services/microvm/v1alpha1@v0.0.0-20250411143952-ceecbca3c193
RUN go mod download
RUN go mod verify

# Build the components
RUN go build -o bin/lime-ctrl ./cmd/lime-ctrl
RUN go build -o bin/flintlock ./cmd/flintlock
RUN go build -o bin/kvm-device-plugin ./cmd/kvm-device-plugin
EOL

# Build the Docker image
echo -e "${YELLOW}Building Docker image for Go 1.24 build environment...${NC}"
sudo docker build -t tvm-builder:latest -f Dockerfile.build .

# Extract the binaries from the container
echo -e "${YELLOW}Extracting built binaries...${NC}"
sudo docker create --name tvm-builder-container tvm-builder:latest
sudo docker cp tvm-builder-container:/app/bin/lime-ctrl bin/
sudo docker cp tvm-builder-container:/app/bin/flintlock bin/
sudo docker cp tvm-builder-container:/app/bin/kvm-device-plugin bin/
sudo docker rm tvm-builder-container

# Clean up
rm Dockerfile.build

echo -e "${GREEN}Components built successfully using Docker with Go 1.24${NC}"

# Skip Docker image building and use the binaries directly
echo -e "${YELLOW}Skipping Docker image building and using binaries directly...${NC}"

# Create a simple Dockerfile for each component using the binaries
cat > Dockerfile.lime-ctrl << EOL
FROM alpine:3.18
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY bin/lime-ctrl /app/lime-ctrl
ENTRYPOINT ["/app/lime-ctrl"]
EOL

cat > Dockerfile.flintlock << EOL
FROM alpine:3.18
RUN apk --no-cache add ca-certificates python3 bash
WORKDIR /app
COPY bin/flintlock /app/flintlock
RUN mkdir -p /var/lib/flintlock/microvms
VOLUME /var/lib/flintlock
ENTRYPOINT ["/app/flintlock"]
EOL

cat > Dockerfile.kvm-device-plugin << EOL
FROM alpine:3.18
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY bin/kvm-device-plugin /app/kvm-device-plugin
ENTRYPOINT ["/app/kvm-device-plugin"]
EOL

# Build Docker images with the simple Dockerfiles
echo -e "${YELLOW}Building Docker images with the simple Dockerfiles...${NC}"
sudo docker build -t lime-ctrl:latest -f Dockerfile.lime-ctrl .
sudo docker build -t flintlock:latest -f Dockerfile.flintlock .
sudo docker build -t kvm-device-plugin:latest -f Dockerfile.kvm-device-plugin .

# Import images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
sudo docker save lime-ctrl:latest | sudo ctr -n=k8s.io images import -
sudo docker save flintlock:latest | sudo ctr -n=k8s.io images import -
sudo docker save kvm-device-plugin:latest | sudo ctr -n=k8s.io images import -

# Clean up temporary Dockerfiles
rm Dockerfile.lime-ctrl Dockerfile.flintlock Dockerfile.kvm-device-plugin

# Delete existing deployments
echo -e "${YELLOW}Deleting existing deployments...${NC}"
kubectl delete namespace vvm-system || true
kubectl delete clusterrole lime-ctrl || true
kubectl delete clusterrolebinding lime-ctrl || true
kubectl delete clusterrole flintlock || true
kubectl delete clusterrolebinding flintlock || true

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system

# Apply CRDs
echo -e "${YELLOW}Applying CRDs...${NC}"
kubectl apply -f deploy/crds/

# Wait for CRDs to be established
echo -e "${YELLOW}Waiting for CRDs to be established...${NC}"
sleep 10
kubectl get crds | grep vvm.tvm.github.com

# Create shared volume with proper binding
echo -e "${YELLOW}Creating shared volume with proper binding...${NC}"
cat > deploy/shared-volume.yaml << EOL
apiVersion: v1
kind: PersistentVolume
metadata:
  name: flintlock-data-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/tmp/flintlock-data"
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    name: flintlock-data-pvc
    namespace: vvm-system
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: flintlock-data-pvc
  namespace: vvm-system
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: flintlock-data-pv
EOL

kubectl apply -f deploy/shared-volume.yaml

# Create directory for flintlock data
sudo mkdir -p /tmp/flintlock-data/microvms

# Apply deployments
echo -e "${YELLOW}Applying deployments...${NC}"

# Create flintlock deployment
cat > deploy/flintlock.yaml << EOL
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flintlock
  namespace: vvm-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: flintlock
rules:
- apiGroups: [""]
  resources: ["pods", "services", "events", "configmaps", "secrets"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flintlock
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flintlock
subjects:
- kind: ServiceAccount
  name: flintlock
  namespace: vvm-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flintlock
  namespace: vvm-system
  labels:
    app: flintlock
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flintlock
  template:
    metadata:
      labels:
        app: flintlock
    spec:
      serviceAccountName: flintlock
      containers:
      - name: flintlock
        image: flintlock:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 9090
          name: grpc
        volumeMounts:
        - name: flintlock-data
          mountPath: /var/lib/flintlock
      volumes:
      - name: flintlock-data
        persistentVolumeClaim:
          claimName: flintlock-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: flintlock
  namespace: vvm-system
spec:
  selector:
    app: flintlock
  ports:
  - port: 9090
    targetPort: 9090
    name: grpc
EOL

kubectl apply -f deploy/flintlock.yaml

# Create lime-ctrl deployment
cat > deploy/lime-ctrl.yaml << EOL
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
        image: lime-ctrl:latest
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
EOL

kubectl apply -f deploy/lime-ctrl.yaml

# Create kvm-device-plugin deployment
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
        image: kvm-device-plugin:latest
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
EOL

kubectl apply -f deploy/kvm-device-plugin.yaml

# Wait for pods to start
echo -e "${YELLOW}Waiting for pods to start...${NC}"
sleep 10

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Check why flintlock pod might be pending
echo -e "${YELLOW}Checking why flintlock pod might be pending...${NC}"
FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod -n vvm-system $FLINTLOCK_POD

# Wait a bit more for other pods
echo -e "${YELLOW}Waiting for remaining pods to stabilize...${NC}"
sleep 30

# Check pod status again
echo -e "${YELLOW}Checking pod status again...${NC}"
kubectl get pods -n vvm-system

# Try to get logs if pod is running
echo -e "${YELLOW}Trying to get flintlock pod logs if available...${NC}"
kubectl logs -n vvm-system $FLINTLOCK_POD || true

# Wait longer before creating a MicroVM to ensure controllers are ready
echo -e "${YELLOW}Waiting for controllers to be fully ready...${NC}"
sleep 30

# Create a MicroVM
echo -e "${YELLOW}Creating a MicroVM...${NC}"
cat > test-microvm.yaml << EOL
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MicroVM
metadata:
  name: test-microvm
  namespace: vvm-system
spec:
  image: ubuntu:20.04
  cpu: 1
  memory: 512
  mcpMode: true
EOL

kubectl apply -f test-microvm.yaml

# Wait for MicroVM to be ready
echo -e "${YELLOW}Waiting for MicroVM to be ready...${NC}"
sleep 30

# Check MicroVM status with retry
echo -e "${YELLOW}Checking MicroVM status with retry...${NC}"
for i in {1..5}; do
  echo -e "${YELLOW}Attempt $i to get MicroVM status...${NC}"
  if kubectl get microvms -n vvm-system; then
    break
  else
    echo -e "${YELLOW}MicroVM resource not available yet, waiting...${NC}"
    sleep 10
  fi
done

# Execute a Python script
echo -e "${YELLOW}Creating a Python script to execute in the MicroVM...${NC}"
cat > test-script.py << EOL
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

# Copy the script to the shared volume
sudo cp test-script.py /tmp/flintlock-data/custom_script.py

# Create execution request
echo -e "${YELLOW}Creating execution request...${NC}"
sudo bash -c 'cat > /tmp/flintlock-data/microvms/execute_request.txt << EOL
{
  "command": "python3",
  "args": ["/var/lib/flintlock/custom_script.py"],
  "env": {
    "VVM_EXECUTION_ID": "test-123",
    "VVM_USER": "user123"
  },
  "timeout": 60
}
EOL'

# Wait for execution to complete
echo -e "${YELLOW}Waiting for execution to complete...${NC}"
sleep 10

# Check execution response
echo -e "${YELLOW}Checking execution response...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.txt ]; then
    echo -e "${GREEN}=== Execution Output ===${NC}"
    sudo cat /tmp/flintlock-data/microvms/execute_response.txt
else
    echo -e "${RED}No execution response found${NC}"
    
    # Check logs from flintlock pod
    echo -e "${YELLOW}Checking logs from flintlock pod...${NC}"
    FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}')
    kubectl logs -n vvm-system $FLINTLOCK_POD
fi

echo -e "${GREEN}Deployment and test completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"
echo -e "${GREEN}Build and deployment script completed successfully!${NC}"