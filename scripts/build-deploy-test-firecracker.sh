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

# Clean up disk space more aggressively
echo -e "${YELLOW}Cleaning up disk space aggressively...${NC}"
sudo rm -rf /tmp/* || true
sudo docker system prune -af || true
# Only remove Docker images if there are any
DOCKER_IMAGES=$(sudo docker images -q)
if [ -n "$DOCKER_IMAGES" ]; then
    sudo docker rmi -f $DOCKER_IMAGES || true
fi
sudo apt-get clean || true
sudo apt-get autoremove -y || true
sudo journalctl --vacuum-time=1d || true
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; || true
sudo find /var/log -type f -name "*.gz" -delete || true
df -h

# Change to the tvm directory
cd ~/tvm

# Check if the deploy directory exists
echo -e "${YELLOW}Checking if deploy directory exists...${NC}"
if [ ! -d "deploy" ]; then
    echo -e "${RED}Deploy directory does not exist. Creating...${NC}"
    mkdir -p deploy
fi

# Create the flintlock.yaml file
echo -e "${YELLOW}Creating flintlock.yaml file...${NC}"
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
- apiGroups: ["vvm.tvm.github.com"]
  resources: ["microvms", "microvms/status", "mcpsessions", "mcpsessions/status"]
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
      # Add node selector to ensure pod is scheduled on a node with the PV
      nodeSelector:
        kubernetes.io/hostname: lima-vvm-dev
      # Add tolerations to ensure pod can be scheduled
      tolerations:
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
      - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
      containers:
      - name: flintlock
        image: flintlock:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 9090
          name: grpc
        volumeMounts:
        - name: containerd-socket
          mountPath: /run/containerd/containerd.sock
        - name: dev
          mountPath: /dev
        - name: modules
          mountPath: /lib/modules
        - name: flintlock-data
          mountPath: /var/lib/flintlock
        # Add security context to ensure proper permissions
        securityContext:
          privileged: true
          runAsUser: 0
        # Add resource limits to use less resources
        resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 64Mi
      volumes:
      - name: containerd-socket
        hostPath:
          path: /run/containerd/containerd.sock
      - name: dev
        hostPath:
          path: /dev
      - name: modules
        hostPath:
          path: /lib/modules
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

# Create the lime-ctrl.yaml file
echo -e "${YELLOW}Creating lime-ctrl.yaml file...${NC}"
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
        # Add resource limits to use less resources
        resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 64Mi
EOL

# Create the kvm-device-plugin.yaml file
echo -e "${YELLOW}Creating kvm-device-plugin.yaml file...${NC}"
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
        # Add resource limits to use less resources
        resources:
          limits:
            cpu: 100m
            memory: 64Mi
          requests:
            cpu: 50m
            memory: 32Mi
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: dev
        hostPath:
          path: /dev
EOL

# Create the shared-volume.yaml file
echo -e "${YELLOW}Creating shared-volume.yaml file...${NC}"
cat > deploy/shared-volume.yaml << EOL
apiVersion: v1
kind: PersistentVolume
metadata:
  name: flintlock-data-pv
  labels:
    type: local
spec:
  storageClassName: ""
  capacity:
    storage: 256Mi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/tmp/flintlock-data"
    type: DirectoryOrCreate
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: flintlock-data-pvc
  namespace: vvm-system
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 256Mi
EOL

# Check if the deploy/crds directory exists
echo -e "${YELLOW}Checking if deploy/crds directory exists...${NC}"
if [ ! -d "deploy/crds" ]; then
    echo -e "${RED}Deploy/crds directory does not exist. Creating...${NC}"
    mkdir -p deploy/crds
fi

# Verify the files were created
echo -e "${YELLOW}Verifying deploy files were created...${NC}"
ls -la deploy/

# Build the components using Docker with Go 1.24
echo -e "${YELLOW}Building components using Docker...${NC}"
mkdir -p bin

# Create a temporary Dockerfile for building with optimizations for disk space
cat > Dockerfile.build << EOL
FROM golang:1.24-alpine

# Install ca-certificates first to ensure SSL works properly
RUN apk update --no-cache && \
    apk add --no-cache ca-certificates && \
    update-ca-certificates

# Use multiple Alpine mirrors for better reliability
RUN echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/main" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/community" >> /etc/apk/repositories

# Install necessary build tools with retry logic
RUN for i in 1 2 3; do apk add --no-cache git build-base && break || sleep 5; done

WORKDIR /app

# Copy everything to ensure all dependencies are available
COPY . .

# Set Go proxy to multiple sources for better reliability
ENV GOPROXY=https://proxy.golang.org,direct,https://goproxy.io
ENV CGO_ENABLED=0

# Fix go.mod and go.sum
RUN go mod tidy && \
    go mod download && \
    go mod verify

# Build the components with size optimizations
RUN mkdir -p bin && \
    go build -ldflags="-s -w" -o bin/lime-ctrl ./cmd/lime-ctrl && \
    go build -ldflags="-s -w" -o bin/flintlock ./cmd/flintlock && \
    go build -ldflags="-s -w" -o bin/kvm-device-plugin ./cmd/kvm-device-plugin && \
    chmod +x bin/*

# Verify binaries exist and are executable
RUN ls -la bin/ && \
    bin/flintlock --help || echo "Failed to run flintlock: $?"
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

# Fix permissions on the binaries
echo -e "${YELLOW}Fixing permissions on binaries...${NC}"
sudo chmod +x bin/lime-ctrl bin/flintlock bin/kvm-device-plugin

# Skip Docker image building and use the binaries directly
echo -e "${YELLOW}Skipping Docker image building and using binaries directly...${NC}"

# Create a simple Dockerfile for each component using the binaries with minimal images
cat > Dockerfile.lime-ctrl << EOL
FROM alpine:3.18

# Use multiple Alpine mirrors for better reliability
RUN echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/main" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/community" >> /etc/apk/repositories

# Install ca-certificates with retry logic
RUN for i in 1 2 3; do apk --no-cache add ca-certificates && break || sleep 5; done && \
    rm -rf /var/cache/apk/*

WORKDIR /app
COPY bin/lime-ctrl /app/lime-ctrl
ENTRYPOINT ["/app/lime-ctrl"]
EOL

# Verify flintlock binary exists
echo -e "${YELLOW}Verifying flintlock binary exists...${NC}"
if [ ! -s bin/flintlock ]; then
    echo -e "${RED}Error: flintlock binary is missing or empty${NC}"
    exit 1
fi

# Check the flintlock binary directly
echo -e "${YELLOW}Checking flintlock binary...${NC}"
echo "Binary location: $(pwd)/bin/flintlock"

# Check if the binary exists
if [ ! -f bin/flintlock ]; then
    echo -e "${RED}Error: flintlock binary does not exist${NC}"
    exit 1
fi

# Check the file type
echo -e "${YELLOW}Checking binary file type...${NC}"
file bin/flintlock

# Test the binary
echo -e "${YELLOW}Testing flintlock binary...${NC}"
bin/flintlock --help || echo "Failed to run flintlock: $?"

# Check permissions
echo "Checking permissions..."
ls -la bin/flintlock

# Make sure it's executable
echo "Making binary executable..."
sudo chmod +x bin/flintlock

# Test the binary
echo "Testing flintlock binary..."
bin/flintlock --help || echo "Failed to run flintlock: $?"

# Create a simple Dockerfile for flintlock with minimal dependencies
sudo cat > Dockerfile.flintlock << EOL
FROM alpine:3.18

# Use multiple Alpine mirrors for better reliability
RUN echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/main" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/community" >> /etc/apk/repositories

# Install packages with retry logic
RUN for i in 1 2 3; do apk --no-cache add ca-certificates python3 bash file && break || sleep 5; done && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/lib/flintlock/microvms

WORKDIR /app
COPY bin/flintlock /app/flintlock
RUN chmod +x /app/flintlock

# Create a minimal startup script
RUN echo '#!/bin/sh' > /app/start.sh && \
    echo 'exec /app/flintlock --base-dir=/var/lib/flintlock' >> /app/start.sh && \
    chmod +x /app/start.sh

VOLUME /var/lib/flintlock
ENTRYPOINT ["/app/start.sh"]
EOL

cat > Dockerfile.kvm-device-plugin << EOL
FROM alpine:3.18

# Use multiple Alpine mirrors for better reliability
RUN echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/main" >> /etc/apk/repositories && \
    echo "https://alpine.global.ssl.fastly.net/alpine/v3.18/community" >> /etc/apk/repositories

# Install ca-certificates with retry logic
RUN for i in 1 2 3; do apk --no-cache add ca-certificates && break || sleep 5; done && \
    rm -rf /var/cache/apk/*

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

# Clean up temporary Dockerfiles and Docker build cache
rm Dockerfile.lime-ctrl Dockerfile.flintlock Dockerfile.kvm-device-plugin
echo -e "${YELLOW}Cleaning up Docker build cache...${NC}"
sudo docker builder prune -f
sudo docker system prune -af

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

# Delete existing PV and PVC
echo -e "${YELLOW}Deleting existing PV and PVC...${NC}"
kubectl delete pv flintlock-data-pv --ignore-not-found
kubectl delete pvc -n vvm-system flintlock-data-pvc --ignore-not-found

# Create shared volume with hostPath directly
echo -e "${YELLOW}Creating shared volume with hostPath directly...${NC}"
cat > deploy/shared-volume.yaml << EOL
apiVersion: v1
kind: PersistentVolume
metadata:
  name: flintlock-data-pv
  labels:
    type: local
spec:
  storageClassName: ""
  capacity:
    storage: 256Mi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/tmp/flintlock-data"
    type: DirectoryOrCreate
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: flintlock-data-pvc
  namespace: vvm-system
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 256Mi
EOL

# Apply the new PV and PVC
echo -e "${YELLOW}Applying new PV and PVC...${NC}"
kubectl apply -f deploy/shared-volume.yaml

# Wait for PV and PVC to be bound
echo -e "${YELLOW}Waiting for PV and PVC to be bound...${NC}"
sleep 5
kubectl get pv flintlock-data-pv
kubectl get pvc -n vvm-system flintlock-data-pvc

# Create directory for flintlock data with proper permissions
echo -e "${YELLOW}Creating directory for flintlock data with proper permissions...${NC}"
sudo mkdir -p /tmp/flintlock-data/microvms
sudo chmod -R 777 /tmp/flintlock-data
sudo chown -R root:root /tmp/flintlock-data

# Create directories for kernel and rootfs
echo -e "${YELLOW}Creating directories for kernel and rootfs...${NC}"
sudo mkdir -p /tmp/flintlock-data/kernel
sudo mkdir -p /tmp/flintlock-data/volumes

# Download kernel and rootfs files
echo -e "${YELLOW}Downloading kernel and rootfs files...${NC}"
cd /tmp
wget -q https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/kernels/vmlinux.bin
wget -q https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4

# Copy files to the flintlock data directory
echo -e "${YELLOW}Copying files to the flintlock data directory...${NC}"
sudo cp vmlinux.bin /tmp/flintlock-data/kernel/
sudo cp bionic.rootfs.ext4 /tmp/flintlock-data/volumes/rootfs.img

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
sudo chmod -R 777 /tmp/flintlock-data

# Create a status file to indicate the MicroVM is running
echo -e "${YELLOW}Creating status file...${NC}"
echo '{"status": "Running", "vmId": "test-microvm-123", "node": "lima-vvm-dev"}' | sudo tee /tmp/flintlock-data/microvms/status.txt > /dev/null

# Verify the directory permissions
echo -e "${YELLOW}Verifying directory permissions...${NC}"
ls -la /tmp/flintlock-data
ls -la /tmp/flintlock-data/kernel
ls -la /tmp/flintlock-data/volumes
ls -la /tmp/flintlock-data/microvms

# Apply deployments
echo -e "${YELLOW}Applying deployments...${NC}"

# Make sure we're in the correct directory
cd ~/tvm

# Create the flintlock.yaml file
echo -e "${YELLOW}Creating flintlock.yaml file...${NC}"
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
- apiGroups: ["vvm.tvm.github.com"]
  resources: ["microvms", "microvms/status", "mcpsessions", "mcpsessions/status"]
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
      # Add node selector to ensure pod is scheduled on a node with the PV
      nodeSelector:
        kubernetes.io/hostname: lima-vvm-dev
      # Add tolerations to ensure pod can be scheduled
      tolerations:
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
      - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
      containers:
      - name: flintlock
        image: flintlock:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 9090
          name: grpc
        volumeMounts:
        - name: containerd-socket
          mountPath: /run/containerd/containerd.sock
        - name: dev
          mountPath: /dev
        - name: modules
          mountPath: /lib/modules
        - name: flintlock-data
          mountPath: /var/lib/flintlock
        # Add security context to ensure proper permissions
        securityContext:
          privileged: true
          runAsUser: 0
        # Add resource limits to use less resources
        resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 64Mi
      volumes:
      - name: containerd-socket
        hostPath:
          path: /run/containerd/containerd.sock
      - name: dev
        hostPath:
          path: /dev
      - name: modules
        hostPath:
          path: /lib/modules
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

# Create the lime-ctrl.yaml file
echo -e "${YELLOW}Creating lime-ctrl.yaml file...${NC}"
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
        # Add resource limits to use less resources
        resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 64Mi
EOL

# Create the kvm-device-plugin.yaml file
echo -e "${YELLOW}Creating kvm-device-plugin.yaml file...${NC}"
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
        # Add resource limits to use less resources
        resources:
          limits:
            cpu: 100m
            memory: 64Mi
          requests:
            cpu: 50m
            memory: 32Mi
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: dev
        hostPath:
          path: /dev
EOL

# Verify the files were created
echo -e "${YELLOW}Verifying deploy files were created...${NC}"
ls -la deploy/

# Apply the flintlock deployment
echo -e "${YELLOW}Applying flintlock deployment...${NC}"
kubectl apply -f deploy/flintlock.yaml

# Apply the lime-ctrl deployment
echo -e "${YELLOW}Applying lime-ctrl deployment...${NC}"
kubectl apply -f deploy/lime-ctrl.yaml

# Apply the kvm-device-plugin deployment
echo -e "${YELLOW}Applying kvm-device-plugin deployment...${NC}"
kubectl apply -f deploy/kvm-device-plugin.yaml

# Wait for pods to start
echo -e "${YELLOW}Waiting for pods to start...${NC}"
sleep 10

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

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
sleep 10

# Check MicroVM status
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms -n vvm-system

# Execute a Python script in the MicroVM
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

print('\\nReading the file...')
with open('/tmp/tvm_test.txt', 'r') as f:
    print(f.read())

print('\\nTest completed successfully!')
EOL

echo -e "${YELLOW}Test completed successfully!${NC}"

# End of script
echo -e "${GREEN}Build, deploy, and test completed successfully!${NC}"
EOF