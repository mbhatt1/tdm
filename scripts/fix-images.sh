#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing images in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Fixing images inside Lima VM ===${NC}"

# Create a temporary directory for the images
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Save the Docker images to tar files
echo -e "${YELLOW}Saving Docker images to tar files...${NC}"
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo docker save kvm-device-plugin:latest -o "${TEMP_DIR}/kvm-device-plugin.tar"

# Find the containerd socket
echo -e "${YELLOW}Finding containerd socket...${NC}"
CONTAINERD_SOCK=$(find /run -name containerd.sock 2>/dev/null | head -n 1)
if [ -z "$CONTAINERD_SOCK" ]; then
    echo -e "${RED}containerd socket not found${NC}"
    exit 1
else
    echo -e "${GREEN}containerd socket found at ${CONTAINERD_SOCK}${NC}"
fi

# Import the images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
sudo ctr -a "$CONTAINERD_SOCK" -n k8s.io images import "${TEMP_DIR}/lime-ctrl.tar"
sudo ctr -a "$CONTAINERD_SOCK" -n k8s.io images import "${TEMP_DIR}/kvm-device-plugin.tar"

# List the imported images
echo -e "${YELLOW}Listing imported images in containerd...${NC}"
sudo ctr -a "$CONTAINERD_SOCK" -n k8s.io images ls | grep -E 'lime-ctrl|kvm-device-plugin'

# Clean up
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"

# Update the deployment YAML files
echo -e "${YELLOW}Updating deployment YAML files...${NC}"
cd /tmp/trashfire-dispenser-machine

# Update lime-ctrl.yaml to use the correct image name
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

# Update kvm-device-plugin.yaml to use the correct image name
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

echo -e "${GREEN}Fix completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"