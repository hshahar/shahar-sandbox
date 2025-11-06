# Progressive Delivery with Argo Rollouts

## Overview

**Progressive Delivery** is an advanced deployment strategy that gradually rolls out changes while continuously validating application health. This project implements automated **Canary Deployments** with health checks and automatic rollback capabilities.

---

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                    PROGRESSIVE DELIVERY FLOW                       │
└───────────────────────────────────────────────────────────────────┘

                        ┌─────────────┐
                        │  New Image  │
                        │   Tagged    │
                        └──────┬──────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  Argo Rollout    │
                    │  Triggered       │
                    └──────┬───────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ Step 1: 10%   │  │ Step 2: 25%   │  │ Step 3: 50%   │
│ Traffic       │  │ Traffic       │  │ Traffic       │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        │ Analysis         │ Analysis         │ Analysis
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ Health Check  │  │ Health Check  │  │ Health Check  │
│ - Success     │  │ - Success     │  │ - Success     │
│   Rate ≥ 95%  │  │   Rate ≥ 95%  │  │   Rate ≥ 95%  │
│ - Latency     │  │ - Latency     │  │ - Latency     │
│   P95 ≤ 500ms │  │   P95 ≤ 500ms │  │   P95 ≤ 500ms │
│               │  │ - CPU ≤ 80%   │  │ - CPU ≤ 80%   │
│               │  │ - Mem ≤ 85%   │  │ - Mem ≤ 85%   │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        │ ✅ PASS          │ ✅ PASS          │ ✅ PASS
        ▼                  ▼                  ▼
        ├─────────────────►├─────────────────►│
                                              │
                                              ▼
                                    ┌───────────────────┐
                                    │ Step 4: 100%      │
                                    │ Full Rollout      │
                                    └───────────────────┘

        ❌ FAIL = AUTOMATIC ROLLBACK
```

---

## Canary Deployment Strategy

### Traffic Splitting Timeline

| Step | Traffic % | Duration | Metrics Analyzed |
|------|-----------|----------|------------------|
| **1** | 10% → Canary | 2-5 min | Success Rate |
| **2** | 25% → Canary | 3-10 min | Success Rate, Latency |
| **3** | 50% → Canary | 5-15 min | Success Rate, Latency, Resources |
| **4** | 100% → Canary | - | Full rollout (old version removed) |

### Environment-Specific Timing

#### Development
- **Enabled**: No (uses regular Deployments)
- **Reason**: Faster iteration, no need for progressive delivery

#### Staging
```yaml
argoRollouts:
  enabled: true
  canary:
    pauseDuration:
      step1: "3m"   # 10% for 3 minutes
      step2: "5m"   # 25% for 5 minutes
      step3: "10m"  # 50% for 10 minutes
```

#### Production
```yaml
argoRollouts:
  enabled: true
  canary:
    pauseDuration:
      step1: "5m"   # 10% for 5 minutes
      step2: "10m"  # 25% for 10 minutes
      step3: "15m"  # 50% for 15 minutes
```

---

## Analysis Templates

### 1. Success Rate Analysis

**Metric**: HTTP request success rate (non-5xx responses)

**Query**:
```promql
sum(rate(http_requests_total{status!~"5.."}[2m])) 
/ 
sum(rate(http_requests_total[2m])) * 100
```

**Thresholds**:
- **Dev**: N/A (disabled)
- **Staging**: ≥ 97%
- **Production**: ≥ 99%

**Failure Limit**: 2 consecutive failures → rollback

---

### 2. Latency Analysis (P95)

**Metric**: 95th percentile latency in milliseconds

**Query**:
```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[2m])) by (le)
) * 1000
```

**Thresholds**:
- **Dev**: N/A (disabled)
- **Staging**: ≤ 300ms
- **Production**: ≤ 200ms

**Failure Limit**: 2 consecutive failures → rollback

---

### 3. Resource Usage Analysis

**Metrics**: CPU and Memory utilization percentage

**CPU Query**:
```promql
sum(rate(container_cpu_usage_seconds_total{pod=~"backend-canary.*"}[2m])) 
/ 
sum(kube_pod_container_resource_limits{pod=~"backend-canary.*",resource="cpu"}) * 100
```

**Memory Query**:
```promql
sum(container_memory_working_set_bytes{pod=~"backend-canary.*"}) 
/ 
sum(kube_pod_container_resource_limits{pod=~"backend-canary.*",resource="memory"}) * 100
```

**Thresholds**:
- **Staging**: CPU ≤ 75%, Memory ≤ 80%
- **Production**: CPU ≤ 70%, Memory ≤ 75%

**Failure Limit**: 1 failure → rollback (resource exhaustion is critical)

---

### 4. Uptime Analysis

**Metric**: Pod ready ratio

**Query**:
```promql
sum(kube_pod_status_ready{pod=~"backend-canary.*",condition="true"}) 
/ 
sum(kube_pod_status_ready{pod=~"backend-canary.*"}) * 100
```

**Thresholds**:
- **Staging**: ≥ 99%
- **Production**: ≥ 99.9%

**Failure Limit**: 1 failure → rollback

---

## Automatic Rollback

### Rollback Triggers

Automatic rollback occurs when:

1. **Analysis Failure**: Metrics exceed failure threshold
2. **Pod Crash**: Canary pods enter CrashLoopBackOff
3. **Health Check Failure**: Readiness/liveness probes fail
4. **Manual Abort**: User clicks "Abort" in Argo Rollouts dashboard

### Rollback Process

```
1. Detect failure (analysis or pod health)
2. Pause rollout immediately
3. Scale canary ReplicaSet to 0
4. Route all traffic back to stable version
5. Mark rollout as "Degraded"
6. Send alert notifications
```

### Rollback Time

- **Detection**: 30 seconds (analysis interval)
- **Execution**: 10-30 seconds (depends on cluster)
- **Total**: < 1 minute from failure to full rollback

---

## Monitoring Rollouts

### Argo Rollouts Dashboard

Access the dashboard:

```powershell
# Port-forward to Argo Rollouts dashboard
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100

# Open browser
Start-Process "http://localhost:3100"
```

**Dashboard Features**:
- Real-time rollout status
- Traffic splitting visualization
- Analysis results
- Manual controls (promote, abort, restart)

### CLI Monitoring

```powershell
# Install Argo Rollouts plugin
kubectl krew install argo-rollouts

# Watch rollout progress
kubectl argo rollouts get rollout backend -n staging --watch

# View analysis runs
kubectl argo rollouts get rollout backend -n staging --analysis

# Manually promote (skip remaining steps)
kubectl argo rollouts promote backend -n staging

# Abort and rollback
kubectl argo rollouts abort backend -n staging
```

---

## Grafana Dashboards

### Blog Platform Dashboard

**URL**: http://grafana-{env}.local

**Panels**:

1. **Request Rate** (req/s)
   - Shows traffic distribution between stable and canary
   - Useful for verifying traffic splitting

2. **Error Rate** (%)
   - Alerts if error rate > threshold
   - Separate lines for stable vs canary

3. **Latency P95** (ms)
   - Compare stable vs canary latency
   - Alert at 1000ms (dev), 500ms (staging), 300ms (prod)

4. **CPU Usage** (%)
   - Per-pod CPU consumption
   - Alert at 80% (staging), 70% (prod)

5. **Memory Usage** (MB)
   - Per-pod memory consumption
   - Alert at 85% (staging), 75% (prod)

6. **Pod Uptime** (%)
   - Ready pods / total pods
   - Alert below 95%

7. **Active Rollouts**
   - Shows number of canary pods
   - 0 = stable, >0 = rollout in progress

8. **Database Connections**
   - Track connection pool usage
   - Useful for detecting connection leaks

9. **Network I/O**
   - RX/TX bytes per second
   - Identify network bottlenecks

### Dashboard JSON

The dashboard is automatically created via ConfigMap:
- File: `helm/microservices-app/templates/grafana-dashboard.yaml`
- Label: `grafana_dashboard: "1"`
- Auto-imported by Grafana sidecar

---

## Traffic Management

### NGINX Ingress Integration

Argo Rollouts uses NGINX Ingress annotations for traffic splitting:

```yaml
trafficRouting:
  nginx:
    stableIngress: backend-ingress
    annotationPrefix: nginx.ingress.kubernetes.io
    additionalIngressAnnotations:
      canary-by-header: X-Canary
      canary-by-header-value: "true"
```

### Testing Canary with Header

Force traffic to canary version:

```bash
# Route to canary
curl -H "X-Canary: true" http://backend-staging.local/api/posts

# Route to stable
curl http://backend-staging.local/api/posts
```

### Verifying Traffic Split

```powershell
# Check NGINX Ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f | Select-String "backend"

# Check service endpoints
kubectl get endpoints backend -n staging
kubectl get endpoints backend-canary -n staging
```

---

## Best Practices

### 1. Start with Conservative Thresholds

✅ **DO**: Set stricter thresholds initially (e.g., 99% success rate)
❌ **DON'T**: Set lenient thresholds that miss real issues

### 2. Monitor First Rollout Closely

✅ **DO**: Watch Argo Rollouts dashboard during first deployment
❌ **DON'T**: Assume it works and walk away

### 3. Use Canary Header for Testing

✅ **DO**: Test canary version with `X-Canary: true` header
❌ **DON'T**: Wait for traffic split to test manually

### 4. Review Rollback Reasons

✅ **DO**: Check Grafana to understand why rollback occurred
❌ **DON'T**: Immediately retry without investigating

### 5. Gradual Threshold Tuning

✅ **DO**: Adjust thresholds based on real metrics over time
❌ **DON'T**: Change thresholds drastically without data

---

## Troubleshooting

### ❌ Rollout Stuck at "Paused"

**Symptom**: Rollout doesn't progress past 10%

**Possible Causes**:
1. Analysis failing but not reaching failure limit
2. Prometheus metrics not available
3. Manual pause (user intervention needed)

**Solution**:
```powershell
# Check analysis status
kubectl describe analysisrun -n staging

# Check Prometheus connectivity
kubectl exec -n staging backend-xxx -- curl http://kube-prometheus-stack-prometheus.monitoring:9090/-/healthy

# Manually promote if metrics unavailable
kubectl argo rollouts promote backend -n staging
```

---

### ❌ Immediate Rollback on Every Deploy

**Symptom**: Rollout always rolls back at 10%

**Possible Causes**:
1. Application bug causing errors
2. Thresholds too strict
3. Metrics not exposed properly

**Solution**:
```powershell
# Check application logs
kubectl logs -n staging deployment/backend --tail=50

# Check metrics endpoint
kubectl exec -n staging backend-xxx -- curl http://localhost:8000/metrics

# Temporarily disable analysis
kubectl edit rollout backend -n staging
# Comment out analysis section
```

---

### ❌ Metrics Not Found Error

**Symptom**: `AnalysisRun` shows "metric query returned no data"

**Possible Causes**:
1. ServiceMonitor not created
2. Prometheus not scraping pods
3. Application not exposing metrics

**Solution**:
```powershell
# Check ServiceMonitor exists
kubectl get servicemonitor -n staging

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets

# Verify metrics endpoint
kubectl exec -n staging backend-xxx -- curl localhost:8000/metrics
```

---

### ❌ Traffic Not Splitting

**Symptom**: All traffic goes to stable, canary receives 0%

**Possible Causes**:
1. Canary service not created
2. NGINX Ingress annotations missing
3. Rollout not using correct services

**Solution**:
```powershell
# Check services exist
kubectl get svc backend backend-canary -n staging

# Check Ingress annotations
kubectl get ingress backend-ingress -n staging -o yaml | Select-String "canary"

# Verify Rollout configuration
kubectl get rollout backend -n staging -o yaml | Select-String "canaryService"
```

---

## Advanced Scenarios

### Blue-Green Deployments

While we use Canary by default, you can switch to Blue-Green:

```yaml
strategy:
  blueGreen:
    activeService: backend
    previewService: backend-preview
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 300
```

### A/B Testing

Route traffic based on user attributes:

```yaml
trafficRouting:
  nginx:
    stableIngress: backend-ingress
    additionalIngressAnnotations:
      canary-by-header: X-User-Type
      canary-by-header-value: "beta-tester"
```

### Webhook Notifications

Get notified on rollout events:

```yaml
spec:
  analysis:
    templates:
    - templateName: backend-success-rate
    args:
    - name: webhook-url
      value: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

---

## Performance Considerations

### Resource Overhead

During canary deployments:
- **CPU**: +20-30% (both versions running)
- **Memory**: +20-30% (both versions running)
- **Network**: +10% (duplicated health checks)

Ensure cluster has sufficient resources:
```yaml
# Recommended minimum per environment
staging:
  nodes: 2
  cpu: 4 cores
  memory: 8 GB

production:
  nodes: 3
  cpu: 8 cores
  memory: 16 GB
```

---

## Metrics and SLIs

### Key Metrics to Track

| Metric | Description | Target |
|--------|-------------|--------|
| **Deployment Frequency** | How often you deploy | > 1/day |
| **Lead Time** | Commit to production | < 1 hour |
| **Rollback Rate** | % of deployments rolled back | < 5% |
| **MTTR** | Mean time to recovery | < 5 min |
| **Success Rate** | % of successful deployments | > 95% |

---

## Additional Resources

- **Argo Rollouts Docs**: https://argo-rollouts.readthedocs.io/
- **Progressive Delivery**: https://www.weave.works/blog/what-is-progressive-delivery-all-about
- **Canary Releases**: https://martinfowler.com/bliki/CanaryRelease.html
- **Prometheus Queries**: https://prometheus.io/docs/prometheus/latest/querying/basics/

---

**Next Steps**: See [CI_CD_PIPELINE.md](./CI_CD_PIPELINE.md) for complete pipeline documentation.
