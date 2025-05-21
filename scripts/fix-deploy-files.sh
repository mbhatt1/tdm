#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing Deploy Files in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Fixing Deploy Files inside Lima VM ===${NC}"

# Check if the deploy directory exists
echo -e "${YELLOW}Checking if deploy directory exists...${NC}"
cd ~/tvm
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
echo -e "${YELLOW}Verifying files were created...${NC}"
ls -la deploy/
ls -la deploy/crds/

echo -e "${GREEN}Deploy files fixed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"