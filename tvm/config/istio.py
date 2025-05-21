"""
Istio configuration generator for the TVM system.
"""

from typing import Dict, Optional

def generate_istio_config() -> str:
    """
    Generate Istio configuration for TVM system.
    
    Returns:
        Istio configuration as a string
    """
    config = """
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
spec:
  profile: minimal
  components:
    egressGateways:
    - name: istio-egressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 128Mi
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          ports:
            - port: 80
              targetPort: 80
              name: http
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 128Mi
  values:
    global:
      proxy:
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 128Mi
    pilot:
      resources:
        requests:
          cpu: 10m
          memory: 128Mi
        limits:
          cpu: 100m
          memory: 256Mi
    telemetry:
      enabled: true
      v2:
        enabled: true
        prometheus:
          enabled: true
        stackdriver:
          enabled: false
"""
    return config

def generate_istio_telemetry_config(namespace: str = "tvm") -> str:
    """
    Generate Istio telemetry configuration.
    
    Args:
        namespace: The namespace to apply the configuration to
        
    Returns:
        Istio telemetry configuration as a string
    """
    config = f"""
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tvm-telemetry
  namespace: {namespace}
spec:
  metrics:
    - providers:
        - name: prometheus
      overrides:
        - match:
            metric: REQUEST_COUNT
            mode: CLIENT_AND_SERVER
          tagOverrides:
            request_id:
              value: REQUEST_HEADER[X-Request-ID]
            language:
              value: REQUEST_HEADER[X-Language]
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100
      useRequestIdForTraceSampling: true
---
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: tvm-circuit-breaker
  namespace: {namespace}
spec:
  configPatches:
  - applyTo: CLUSTER
    match:
      context: SIDECAR_OUTBOUND
      cluster:
        name: "outbound|80||pyrovm.tvm.svc.cluster.local"
    patch:
      operation: MERGE
      value:
        circuit_breakers:
          thresholds:
          - max_connections: 100
            max_pending_requests: 100
            max_requests: 100
            max_retries: 3
"""
    return config

def generate_prometheus_config(namespace: str = "tvm") -> str:
    """
    Generate Prometheus configuration for TVM system.
    
    Args:
        namespace: The namespace to apply the configuration to
        
    Returns:
        Prometheus configuration as a string
    """
    config = f"""
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: {namespace}
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\\d+)?;(\\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
      - job_name: 'istio-mesh'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: istiod
          - source_labels: [__meta_kubernetes_pod_container_port_name]
            action: keep
            regex: http-monitoring
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod_name
    storage:
      tsdb:
        # Only keep 2 hours of metrics to avoid persistence
        retention: 2h
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: {namespace}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.42.0
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus"
            - "--storage.tsdb.retention.time=2h"
            - "--web.console.libraries=/etc/prometheus/console_libraries"
            - "--web.console.templates=/etc/prometheus/consoles"
            - "--web.enable-lifecycle"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config-volume
              mountPath: /etc/prometheus
            - name: prometheus-data
              mountPath: /prometheus
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              cpu: 200m
              memory: 512Mi
      volumes:
        - name: config-volume
          configMap:
            name: prometheus-config
        - name: prometheus-data
          # Use emptyDir for ephemeral storage
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: {namespace}
spec:
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
"""
    return config

def generate_istio_gateway_config(namespace: str = "tvm") -> str:
    """
    Generate Istio Gateway and VirtualService configuration.
    
    Args:
        namespace: The namespace to apply the configuration to
        
    Returns:
        Istio Gateway and VirtualService configuration as a string
    """
    config = f"""
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: tvm-gateway
  namespace: {namespace}
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: tvm-vs
  namespace: {namespace}
spec:
  hosts:
  - "*"
  gateways:
  - tvm-gateway
  http:
  - match:
    - uri:
        prefix: "/api/execute"
    route:
    - destination:
        host: pyrovm
        port:
          number: 80
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "gateway-error,connect-failure,refused-stream,unavailable,cancelled,resource-exhausted"
  - match:
    - uri:
        prefix: "/metrics"
    route:
    - destination:
        host: prometheus
        port:
          number: 9090
  - match:
    - uri:
        prefix: "/health"
    route:
    - destination:
        host: pyrovm
        port:
          number: 80
        subset: health
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: pyrovm
  namespace: {namespace}
spec:
  host: pyrovm
  subsets:
  - name: default
    labels:
      version: v1
  - name: health
    labels:
      version: v1
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
    loadBalancer:
      simple: ROUND_ROBIN
"""
    return config

def generate_security_config(namespace: str = "tvm") -> str:
    """
    Generate security configuration for Istio.
    
    Args:
        namespace: The namespace to apply the configuration to
        
    Returns:
        Security configuration as a string
    """
    config = f"""
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: {namespace}
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: pyrovm-policy
  namespace: {namespace}
spec:
  selector:
    matchLabels:
      app: pyrovm
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/execute"]
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: external-block
  namespace: {namespace}
spec:
  hosts:
  - "*"
  location: MESH_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
---
apiVersion: networking.istio.io/v1alpha3
kind: Sidecar
metadata:
  name: pyrovm-sidecar
  namespace: {namespace}
spec:
  workloadSelector:
    labels:
      app: pyrovm
  egress:
  - hosts:
    # Only allow internal communication
    - "./{namespace}/*"
    - "./istio-system/*"
"""
    return config