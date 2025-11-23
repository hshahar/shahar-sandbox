# ELK Stack Guide - SHA Kubernetes Blog Platform

## Overview

The ELK (Elasticsearch, Logstash, Kibana) stack provides centralized logging and log analysis for the SHA Kubernetes Blog Platform.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Frontend   │  │   Backend    │  │  PostgreSQL  │      │
│  │   (nginx)    │  │  (FastAPI)   │  │              │      │
│  └───────┬──────┘  └───────┬──────┘  └───────┬──────┘      │
│          │                  │                  │              │
│          │ Container Logs   │ JSON Logs        │ Logs        │
│          └──────────┬───────┴──────────────────┘             │
│                     ▼                                         │
│          ┌─────────────────────┐                             │
│          │  Filebeat DaemonSet │  (Collects logs from all   │
│          │   (Log Collector)   │   containers on each node) │
│          └──────────┬──────────┘                             │
│                     │                                         │
│                     ▼                                         │
│          ┌─────────────────────┐                             │
│          │      Logstash       │  (Parses, enriches,        │
│          │   (Log Processor)   │   transforms logs)         │
│          └──────────┬──────────┘                             │
│                     │                                         │
│                     ▼                                         │
│          ┌─────────────────────┐                             │
│          │   Elasticsearch     │  (Stores and indexes       │
│          │  (Search Engine)    │   logs)                    │
│          └──────────┬──────────┘                             │
│                     │                                         │
│                     ▼                                         │
│          ┌─────────────────────┐                             │
│          │      Kibana         │  (Visualization and        │
│          │  (Web Dashboard)    │   analysis)                │
│          └─────────────────────┘                             │
│                     │                                         │
└─────────────────────┼─────────────────────────────────────────┘
                      │
                      ▼
              ┌──────────────┐
              │   Ingress    │
              │  (External   │
              │   Access)    │
              └──────────────┘
                      │
                      ▼
          http://sha-kibana.blog.local
```

## Components

### 1. Elasticsearch
- **Purpose**: Distributed search and analytics engine
- **Replicas**: 1 (dev), 3 (production)
- **Storage**: 10Gi persistent volume
- **Port**: 9200 (HTTP), 9300 (Transport)
- **Heap Size**: 1g (configurable)

### 2. Logstash
- **Purpose**: Log processing pipeline
- **Replicas**: 1
- **Inputs**:
  - Beats (port 5044) - receives logs from Filebeat
  - HTTP (port 8080) - direct log shipping
- **Processing**:
  - JSON parsing
  - Kubernetes metadata enrichment
  - FastAPI log parsing
  - Nginx access log parsing
  - Status code conversion
  - Timestamp normalization

### 3. Kibana
- **Purpose**: Data visualization and exploration
- **Replicas**: 1
- **Port**: 5601
- **Access**: http://sha-kibana.blog.local

### 4. Filebeat
- **Purpose**: Lightweight log shipper
- **Deployment**: DaemonSet (runs on every node)
- **Collection**: Automatically discovers and ships container logs
- **Output**: Sends logs to Logstash

## Installation

### Prerequisites

1. Kubernetes cluster with storage provisioner
2. Nginx Ingress Controller installed
3. At least 4Gi of available memory
4. At least 20Gi of available storage

### Install via Helm

```bash
# Install ELK stack
helm install elk-stack ./helm/elk-stack \
  --namespace logging \
  --create-namespace

# Verify installation
kubectl get pods -n logging

# Expected output:
# NAME                         READY   STATUS    RESTARTS   AGE
# elasticsearch-0              1/1     Running   0          2m
# kibana-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
# logstash-xxxxxxxxxx-xxxxx    1/1     Running   0          2m
# filebeat-xxxxx               1/1     Running   0          2m
# filebeat-xxxxx               1/1     Running   0          2m
```

### Install via ArgoCD

The ELK stack is already configured as an ArgoCD application:

```bash
# Apply the ArgoCD application
kubectl apply -f argocd/applications/elk-stack.yaml

# Check sync status
argocd app get elk-stack

# Sync manually if needed
argocd app sync elk-stack
```

## Configuration

### Customizing Values

Create a custom values file:

```yaml
# custom-elk-values.yaml
elasticsearch:
  replicas: 3
  heapSize: "2g"
  resources:
    limits:
      memory: 4Gi
    requests:
      memory: 2Gi
  persistence:
    size: 50Gi

logstash:
  replicas: 2
  heapSize: "1g"

kibana:
  replicas: 2

ingress:
  kibana:
    host: logs.mycompany.com
  tls:
    enabled: true
```

Apply the custom values:

```bash
helm upgrade elk-stack ./helm/elk-stack \
  -f custom-elk-values.yaml \
  --namespace logging
```

### Log Retention

By default, logs are stored indefinitely. To configure retention:

1. Create an Index Lifecycle Management (ILM) policy in Kibana:
   - Go to **Management → Stack Management → Index Lifecycle Policies**
   - Create new policy with deletion phase (e.g., delete after 30 days)

2. Apply the policy to index templates

## Log Structure

### JSON Log Format

The backend outputs structured JSON logs:

```json
{
  "timestamp": "2025-11-09T10:30:45.123456",
  "level": "INFO",
  "logger": "__main__",
  "message": "HTTP request completed",
  "module": "main",
  "function": "logging_middleware",
  "line": 205,
  "request_id": "1699527045123",
  "http_method": "GET",
  "path": "/api/posts",
  "status_code": 200,
  "duration": 45.23
}
```

### Enriched Log Fields

Logstash adds Kubernetes metadata:

```json
{
  "k8s_namespace": "sha-dev",
  "k8s_pod": "sha-k8s-blog-dev-sha-microservices-app-backend-xyz",
  "k8s_container": "backend",
  "k8s_node": "docker-desktop",
  "@timestamp": "2025-11-09T10:30:45.123Z"
}
```

## Using Kibana

### First-Time Setup

1. **Access Kibana**:
   ```bash
   # Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts on Windows)
   127.0.0.1 sha-kibana.blog.local

   # Open browser
   http://sha-kibana.blog.local
   ```

2. **Create Index Pattern**:
   - Go to **Management → Stack Management → Index Patterns**
   - Click **Create index pattern**
   - Index pattern: `k8s-sha-dev-*`
   - Time field: `@timestamp`
   - Click **Create index pattern**

3. **Discover Logs**:
   - Go to **Discover** (left menu)
   - Select your index pattern
   - You should see logs flowing in

### Common Queries

#### View Backend Errors
```
k8s_container: "backend" AND level: "ERROR"
```

#### HTTP 500 Errors
```
status_code: 500
```

#### Slow Requests (>500ms)
```
duration > 500
```

#### Specific Endpoint
```
path: "/api/posts" AND http_method: "POST"
```

#### Graceful Shutdown Events
```
message: "graceful shutdown" OR message: "SIGTERM"
```

### Creating Dashboards

See [elk/dashboards/README.md](../elk/dashboards/README.md) for detailed dashboard creation guide.

## Monitoring

### Check Elasticsearch Health

```bash
# Cluster health
kubectl exec -n logging elasticsearch-0 -- \
  curl -s http://localhost:9200/_cluster/health?pretty

# Index statistics
kubectl exec -n logging elasticsearch-0 -- \
  curl -s http://localhost:9200/_cat/indices?v

# Node statistics
kubectl exec -n logging elasticsearch-0 -- \
  curl -s http://localhost:9200/_cat/nodes?v
```

### Check Logstash Pipeline

```bash
# View Logstash stats
kubectl exec -n logging deployment/logstash -- \
  curl -s http://localhost:9600/_node/stats?pretty

# View pipeline stats
kubectl exec -n logging deployment/logstash -- \
  curl -s http://localhost:9600/_node/stats/pipelines?pretty
```

### Check Filebeat Status

```bash
# List all Filebeat pods
kubectl get pods -n logging -l app=filebeat

# View logs from specific Filebeat pod
kubectl logs -n logging filebeat-xxxxx

# Check which files are being monitored
kubectl exec -n logging filebeat-xxxxx -- filebeat export template
```

## Troubleshooting

### No Logs in Kibana

1. **Check if Elasticsearch is receiving data**:
   ```bash
   kubectl exec -n logging elasticsearch-0 -- \
     curl -s http://localhost:9200/_cat/indices?v | grep k8s
   ```

2. **Check Filebeat logs**:
   ```bash
   kubectl logs -n logging -l app=filebeat --tail=100
   ```

3. **Check Logstash logs**:
   ```bash
   kubectl logs -n logging -l app=logstash --tail=100
   ```

4. **Verify application is producing logs**:
   ```bash
   kubectl logs -n sha-dev -l app=backend --tail=20
   ```

### Elasticsearch Pod Crashing

**Symptom**: `elasticsearch-0` pod in `CrashLoopBackOff`

**Common causes**:

1. **Insufficient vm.max_map_count**:
   ```bash
   # On Docker Desktop, this is handled by init container
   # On other systems, you may need to set it on the host:
   sudo sysctl -w vm.max_map_count=262144
   ```

2. **Insufficient memory**:
   - Increase heap size in values.yaml
   - Ensure node has enough memory

3. **Permission issues**:
   ```bash
   # Check pod events
   kubectl describe pod -n logging elasticsearch-0
   ```

### High Disk Usage

1. **Check index sizes**:
   ```bash
   kubectl exec -n logging elasticsearch-0 -- \
     curl -s http://localhost:9200/_cat/indices?v\&s=store.size:desc
   ```

2. **Delete old indices**:
   ```bash
   # Delete indices older than 30 days
   kubectl exec -n logging elasticsearch-0 -- \
     curl -X DELETE "localhost:9200/k8s-*-$(date -d '30 days ago' +%Y.%m.%d)"
   ```

3. **Set up ILM policy** (recommended):
   - See Log Retention section above

### Logstash Not Processing Logs

1. **Check Logstash configuration**:
   ```bash
   kubectl get configmap -n logging logstash-config -o yaml
   ```

2. **Test Logstash pipeline locally**:
   ```bash
   # Port-forward to Logstash
   kubectl port-forward -n logging svc/logstash 9600:9600

   # Check pipeline stats
   curl http://localhost:9600/_node/stats/pipelines?pretty
   ```

3. **Verify Logstash can connect to Elasticsearch**:
   ```bash
   kubectl exec -n logging deployment/logstash -- \
     curl -s http://elasticsearch:9200
   ```

## Performance Tuning

### Elasticsearch

```yaml
# values.yaml
elasticsearch:
  # Increase heap for better performance (max 50% of memory limit)
  heapSize: "2g"

  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi

  # Add more replicas for high availability
  replicas: 3
```

### Logstash

```yaml
# values.yaml
logstash:
  # Increase workers for parallel processing
  config:
    pipelineWorkers: 4
    pipelineBatchSize: 250

  heapSize: "1g"

  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
```

### Filebeat

```yaml
# values.yaml
filebeat:
  config:
    # Increase queue size
    queueMemEvents: 8192
    queueMemFlushMinEvents: 1024
```

## Security (Production Considerations)

### Enable Elasticsearch Security

```yaml
# values.yaml
elasticsearch:
  config:
    xpackSecurityEnabled: true
```

Then configure users and passwords.

### Enable TLS

```yaml
# values.yaml
ingress:
  tls:
    enabled: true

# Create TLS secret
kubectl create secret tls kibana-tls \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key \
  -n logging
```

### Network Policies

Apply network policies to restrict traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: elasticsearch-netpol
  namespace: logging
spec:
  podSelector:
    matchLabels:
      app: elasticsearch
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: logstash
    - podSelector:
        matchLabels:
          app: kibana
    ports:
    - protocol: TCP
      port: 9200
```

## Backup and Restore

### Snapshot Repository

```bash
# Create snapshot repository
kubectl exec -n logging elasticsearch-0 -- curl -X PUT \
  "localhost:9200/_snapshot/my_backup" \
  -H 'Content-Type: application/json' \
  -d'{
    "type": "fs",
    "settings": {
      "location": "/usr/share/elasticsearch/backup"
    }
  }'
```

### Create Snapshot

```bash
kubectl exec -n logging elasticsearch-0 -- curl -X PUT \
  "localhost:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true"
```

### Restore Snapshot

```bash
kubectl exec -n logging elasticsearch-0 -- curl -X POST \
  "localhost:9200/_snapshot/my_backup/snapshot_1/_restore"
```

## Best Practices

1. **Log Levels**: Use appropriate log levels (DEBUG for dev, INFO for prod)
2. **Structured Logging**: Always use JSON format for machine parsing
3. **Index Rotation**: Use daily indices (`k8s-*-YYYY.MM.DD`)
4. **Retention Policy**: Set up ILM to delete old logs automatically
5. **Monitoring**: Set up alerts for Elasticsearch cluster health
6. **Resource Limits**: Always set memory limits to prevent OOM
7. **Backups**: Regularly backup Elasticsearch snapshots
8. **Security**: Enable authentication and TLS in production

## Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Logstash Documentation](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Filebeat Documentation](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
- [Dashboard Examples](../elk/dashboards/README.md)
