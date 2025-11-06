# KEDA (Kubernetes Event Driven Autoscaling)

## Overview

KEDA (Kubernetes Event Driven Autoscaling) is an advanced autoscaling solution that extends Kubernetes HPA (Horizontal Pod Autoscaler) with event-driven capabilities. Unlike traditional HPA which only scales based on CPU/Memory, KEDA can scale based on:

- **Prometheus metrics** (HTTP requests, custom application metrics)
- **Queue length** (RabbitMQ, Azure Service Bus, AWS SQS, Kafka)
- **Database connections** (PostgreSQL, MySQL, MongoDB)
- **Cron schedules** (scale up before peak hours)
- **External metrics** (Datadog, New Relic, CloudWatch)
- And **80+ scalers** for various event sources

## Why KEDA Instead of Standard HPA?

### Standard Kubernetes HPA Limitations:
- ❌ Only CPU and Memory metrics
- ❌ Cannot scale to zero
- ❌ No event-driven scaling
- ❌ Limited metric sources
- ❌ No cron-based scaling

### KEDA Advantages:
- ✅ **Multiple metric sources** (Prometheus, queues, databases, cron)
- ✅ **Scale to zero** (save costs when no load)
- ✅ **Event-driven** (scale based on queue depth, HTTP requests)
- ✅ **Advanced scaling policies** (custom stabilization windows)
- ✅ **Built-in support for 80+ event sources**
- ✅ **Works alongside standard HPA** (can use both)

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    KEDA Architecture                     │
└──────────────────────────────────────────────────────────┘

┌─────────────┐        ┌─────────────┐       ┌──────────────┐
│   Metrics   │───────▶│    KEDA     │──────▶│  ScaledObject│
│   Sources   │        │  Operator   │       │              │
└─────────────┘        └─────────────┘       └──────────────┘
      │                       │                      │
      │                       ▼                      ▼
      │              ┌─────────────────┐    ┌──────────────┐
      │              │ Metrics Server  │    │     HPA      │
      │              └─────────────────┘    └──────────────┘
      │                       │                      │
      ▼                       ▼                      ▼
┌─────────────────────────────────────────────────────────┐
│  Prometheus  │  Queues  │  Databases  │  Cron  │  Other │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │   Deployment     │
                 │  (Scale Target)  │
                 └──────────────────┘
```

## Installation

KEDA is installed automatically via Terraform when `install_keda = true`:

```hcl
# terraform/environments/dev.tfvars
install_keda = true
```

The Terraform module installs:
- KEDA Operator (manages ScaledObjects)
- KEDA Metrics Server (provides metrics to HPA)
- KEDA Webhooks (validates ScaledObjects)
- ServiceMonitor (Prometheus integration)

**Verify installation:**
```powershell
# Check KEDA pods
kubectl get pods -n keda

# Check KEDA version
kubectl get deployment -n keda keda-operator -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check CRDs
kubectl get crd | Select-String "keda"
```

Expected output:
```
scaledobjects.keda.sh
scaledjobs.keda.sh
triggerauthentications.keda.sh
```

## Configuration

### Enable KEDA in Helm Values

**File:** `helm/microservices-app/values-dev.yaml`

```yaml
# Enable autoscaling with KEDA
autoscaling:
  enabled: true
  type: keda  # Use KEDA instead of standard HPA

backend:
  autoscaling:
    minReplicas: 2
    maxReplicas: 10
    pollingInterval: 30      # Check metrics every 30 seconds
    cooldownPeriod: 300      # Wait 5 minutes before scaling down
    
    # CPU-based scaling
    cpu:
      enabled: true
      targetUtilization: "70"  # Scale when CPU > 70%
    
    # Memory-based scaling (optional)
    memory:
      enabled: false
      targetUtilization: "80"
    
    # Prometheus-based scaling (advanced)
    prometheus:
      enabled: false
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring:9090
      threshold: "100"  # Scale when requests/sec > 100
```

### ScaledObject Custom Resource

KEDA uses `ScaledObject` CRDs to define scaling rules. These are automatically created by the Helm chart.

**Example ScaledObject (generated):**
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sha-k8s-blog-dev-backend-scaledobject
  namespace: sha-dev
spec:
  scaleTargetRef:
    name: sha-k8s-blog-dev-backend
  minReplicaCount: 2
  maxReplicaCount: 10
  pollingInterval: 30
  cooldownPeriod: 300
  
  triggers:
  # CPU trigger
  - type: cpu
    metricType: Utilization
    metadata:
      value: "70"
  
  # Memory trigger (if enabled)
  - type: memory
    metricType: Utilization
    metadata:
      value: "80"
  
  # Prometheus trigger (if enabled)
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring:9090
      metricName: http_requests_per_second
      query: |
        sum(rate(http_requests_total{
          namespace="sha-dev",
          service="sha-k8s-blog-dev-backend"
        }[2m]))
      threshold: "100"
```

## Scaling Strategies

### 1. CPU/Memory Based (Basic)

Best for: CPU/memory-intensive workloads

```yaml
backend:
  autoscaling:
    cpu:
      enabled: true
      targetUtilization: "70"
    memory:
      enabled: true
      targetUtilization: "80"
```

**Behavior:**
- Scales UP when CPU > 70% OR memory > 80%
- Scales DOWN when both are below threshold for cooldownPeriod

### 2. HTTP Requests Based (Prometheus)

Best for: Web applications, APIs

```yaml
backend:
  autoscaling:
    prometheus:
      enabled: true
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring:9090
      threshold: "100"  # Scale at 100 req/sec
```

**Query used:**
```promql
sum(rate(http_requests_total{
  namespace="sha-dev",
  service="sha-k8s-blog-dev-backend"
}[2m]))
```

**Behavior:**
- Scales UP when requests/sec > threshold
- Scales DOWN when requests/sec < threshold for cooldownPeriod

### 3. Queue Length Based (Advanced)

Best for: Background workers, job processors

```yaml
backend:
  autoscaling:
    custom:
    - type: rabbitmq
      metadata:
        host: amqp://rabbitmq.messaging:5672
        queueName: blog-jobs
        queueLength: "10"  # Scale when queue > 10 messages
```

### 4. Cron Schedule Based

Best for: Predictable traffic patterns

```yaml
backend:
  autoscaling:
    custom:
    - type: cron
      metadata:
        timezone: America/New_York
        start: 0 8 * * *    # Scale up at 8 AM
        end: 0 18 * * *      # Scale down at 6 PM
        desiredReplicas: "5"
```

### 5. Composite (Multiple Triggers)

Use multiple triggers together:

```yaml
backend:
  autoscaling:
    cpu:
      enabled: true
      targetUtilization: "70"
    prometheus:
      enabled: true
      threshold: "100"
    custom:
    - type: cron
      metadata:
        timezone: UTC
        start: 0 8 * * 1-5   # Weekdays 8 AM
        end: 0 18 * * 1-5    # Weekdays 6 PM
        desiredReplicas: "5"
```

**Behavior:**
- Cron ensures 5 replicas during business hours
- CPU and Prometheus can scale beyond 5 if needed
- Scales down to minReplicas outside business hours

## Scaling Behavior Configuration

### Scale Up Policy

```yaml
backend:
  autoscaling:
    scaleUp:
      stabilizationWindowSeconds: 0     # Scale up immediately
      percentagePolicyValue: 100        # Max 100% increase per period
      percentagePolicyPeriod: 30        # Every 30 seconds
      podsPolicyValue: 4                # Or add 4 pods per period
      podsPolicyPeriod: 30
      selectPolicy: "Max"               # Use max of percent/pods
```

**Example:** Current replicas = 2
- After 30s: Can scale to max(4 pods [+100%], 6 pods [+4]) = **6 pods**
- After 60s: Can scale to max(12 pods [+100%], 10 pods [+4]) = **12 pods**

### Scale Down Policy

```yaml
backend:
  autoscaling:
    scaleDown:
      stabilizationWindowSeconds: 300   # Wait 5 minutes
      percentagePolicyValue: 50         # Max 50% decrease per period
      percentagePolicyPeriod: 60        # Every 60 seconds
      podsPolicyValue: 2                # Or remove 2 pods per period
      podsPolicyPeriod: 60
      selectPolicy: "Min"               # Use min of percent/pods
```

**Example:** Current replicas = 10
- After stabilization + 60s: Can scale to min(5 pods [-50%], 8 pods [-2]) = **8 pods**
- After stabilization + 120s: Can scale to min(4 pods [-50%], 6 pods [-2]) = **6 pods**

## Operations

### Check ScaledObjects

```powershell
# List all ScaledObjects
kubectl get scaledobject -n sha-dev

# Get details
kubectl describe scaledobject sha-k8s-blog-dev-backend-scaledobject -n sha-dev

# Check HPA created by KEDA
kubectl get hpa -n sha-dev
```

### Monitor Scaling Activity

```powershell
# Watch ScaledObject status
kubectl get scaledobject -n sha-dev -w

# Check HPA metrics
kubectl describe hpa -n sha-dev

# View KEDA operator logs
kubectl logs -n keda deployment/keda-operator -f
```

### Test Autoscaling

**CPU load test:**
```powershell
# Generate CPU load
kubectl run -it --rm load-generator --image=busybox --restart=Never -n sha-dev -- /bin/sh -c "while true; do wget -q -O- http://sha-k8s-blog-dev-backend:8000/api/posts; done"

# Watch scaling
kubectl get scaledobject -n sha-dev -w
kubectl get pods -n sha-dev -w
```

**Prometheus metrics test:**
```powershell
# Generate HTTP requests using Apache Bench
kubectl run -it --rm apache-bench --image=httpd:alpine --restart=Never -n sha-dev -- ab -n 100000 -c 100 http://sha-k8s-blog-dev-backend:8000/

# Watch scaling based on request rate
kubectl get scaledobject -n sha-dev -w
```

### Pause Autoscaling

```powershell
# Pause scaling (keeps current replicas)
kubectl patch scaledobject sha-k8s-blog-dev-backend-scaledobject -n sha-dev --type=merge -p '{"spec":{"pausedReplicaCount":3}}'

# Resume scaling
kubectl patch scaledobject sha-k8s-blog-dev-backend-scaledobject -n sha-dev --type=json -p '[{"op":"remove","path":"/spec/pausedReplicaCount"}]'
```

### Scale to Zero (Optional)

KEDA supports scaling to zero when no load:

```yaml
backend:
  autoscaling:
    minReplicaCount: 0  # Allow scale to zero
    pollingInterval: 30
    cooldownPeriod: 300
```

**Note:** Scale to zero works best with:
- Queue-based workloads (no active connections lost)
- Cron-based scaling (scheduled restarts)
- Background jobs (not user-facing APIs)

## Troubleshooting

### ScaledObject Not Working

**Check KEDA installation:**
```powershell
kubectl get pods -n keda
kubectl logs -n keda deployment/keda-operator
```

**Check ScaledObject status:**
```powershell
kubectl describe scaledobject -n sha-dev
```

Common issues:
- ❌ Prometheus serverAddress wrong
- ❌ Metrics query returns no data
- ❌ Target deployment doesn't exist
- ❌ KEDA operator not running

### HPA Shows Unknown Metrics

**Check KEDA metrics server:**
```powershell
kubectl get deployment -n keda keda-metrics-apiserver
kubectl logs -n keda deployment/keda-metrics-apiserver
```

**Test metrics endpoint:**
```powershell
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1
```

### Scaling Too Aggressive

Increase stabilization windows:

```yaml
backend:
  autoscaling:
    scaleUp:
      stabilizationWindowSeconds: 60   # Wait 1 minute
    scaleDown:
      stabilizationWindowSeconds: 600  # Wait 10 minutes
```

### Not Scaling Fast Enough

Reduce cooldown and increase policies:

```yaml
backend:
  autoscaling:
    cooldownPeriod: 60  # Reduce from 300
    scaleUp:
      podsPolicyValue: 10  # Add more pods per period
```

## Environment-Specific Configuration

### Development
```yaml
autoscaling:
  enabled: false  # Manual scaling for debugging
```

### Staging
```yaml
autoscaling:
  enabled: true
  type: keda
backend:
  autoscaling:
    minReplicas: 1
    maxReplicas: 5
    cpu:
      enabled: true
      targetUtilization: "70"
```

### Production
```yaml
autoscaling:
  enabled: true
  type: keda
backend:
  autoscaling:
    minReplicas: 3
    maxReplicas: 20
    cpu:
      enabled: true
      targetUtilization: "70"
    prometheus:
      enabled: true
      threshold: "500"  # Higher threshold for prod
    custom:
    - type: cron
      metadata:
        start: 0 8 * * 1-5
        end: 0 18 * * 1-5
        desiredReplicas: "10"
```

## Cost Optimization

### Scale to Zero (Non-Critical Services)

```yaml
# Background workers, non-critical services
backend:
  autoscaling:
    minReplicaCount: 0
    cooldownPeriod: 600  # Wait 10 minutes before scaling to zero
```

**Savings:** ~$100-500/month for idle services

### Cron-Based Scaling

```yaml
# Scale up during business hours only
backend:
  autoscaling:
    custom:
    - type: cron
      metadata:
        timezone: America/New_York
        start: 0 8 * * 1-5    # Mon-Fri 8 AM
        end: 0 18 * * 1-5      # Mon-Fri 6 PM
        desiredReplicas: "10"
    minReplicas: 2  # Off-hours minimum
```

**Savings:** ~30-50% reduction in off-hours compute costs

## Best Practices

1. **Start Simple**: Begin with CPU/Memory scaling, then add advanced triggers
2. **Monitor First**: Collect metrics for 1-2 weeks before enabling autoscaling
3. **Set Realistic Limits**: `maxReplicas` should account for cluster capacity
4. **Use Stabilization Windows**: Prevent flapping (rapid scale up/down)
5. **Test Scaling**: Use load testing tools to verify behavior
6. **Combine Triggers**: Use multiple scalers for comprehensive coverage
7. **Set Resource Requests**: Required for CPU/Memory-based scaling
8. **Monitor KEDA Operator**: Check logs for errors and warnings
9. **Use Prometheus Recording Rules**: Pre-calculate complex queries
10. **Document Scaling Decisions**: Comment your thresholds and reasons

## Migration from Standard HPA

If you have existing HPAs:

1. **Backup existing HPA:**
   ```powershell
   kubectl get hpa -n sha-dev -o yaml > hpa-backup.yaml
   ```

2. **Enable KEDA in values:**
   ```yaml
   autoscaling:
     enabled: true
     type: keda
   ```

3. **Deploy with Terraform:**
   ```powershell
   terraform apply -var-file="environments/dev.tfvars"
   ```

4. **Verify ScaledObject created:**
   ```powershell
   kubectl get scaledobject -n sha-dev
   ```

5. **Old HPA will be replaced automatically by KEDA**

## Additional Resources

- [KEDA Documentation](https://keda.sh/docs/)
- [KEDA Scalers](https://keda.sh/docs/scalers/) - Full list of 80+ event sources
- [KEDA GitHub](https://github.com/kedacore/keda)
- [Prometheus Scaler](https://keda.sh/docs/scalers/prometheus/)
- [Cron Scaler](https://keda.sh/docs/scalers/cron/)
