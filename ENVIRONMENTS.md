# Environment Differences – Development, Staging, Production

## Overview

This project includes three separate environments, each with configuration tailored to its needs.

## Detailed Comparison Table

| Attribute                 | Development                | Staging             | Production      |
| ------------------------- | -------------------------- | ------------------- | --------------- |
| **Namespace**             | `dev`                      | `staging`           | `production`    |
| **Purpose**               | Fast development & testing | Integration testing | Live production |
| **Stability**             | Low (frequent changes)     | Medium              | High            |
| **Required Availability** | 50%                        | 80%                 | 99.9%           |

## Frontend (Web Server)

| Attribute             | Development  | Staging      | Production   |
| --------------------- | ------------ | ------------ | ------------ |
| **Replicas**          | 1            | 2            | 3            |
| **CPU Request**       | 100m         | 200m         | 500m         |
| **CPU Limit**         | 200m         | 500m         | 1000m        |
| **Memory Request**    | 128Mi        | 256Mi        | 512Mi        |
| **Memory Limit**      | 256Mi        | 512Mi        | 1Gi          |
| **Image Pull Policy** | IfNotPresent | IfNotPresent | IfNotPresent |

### Explanation

* **Dev**: A single replica is enough—saves resources and allows quick iteration.
* **Staging**: 2 replicas—lightweight production simulation.
* **Production**: 3 replicas—High Availability and better load handling.

## Backend (API Service)

| Attribute              | Development | Staging | Production |
| ---------------------- | ----------- | ------- | ---------- |
| **Replicas**           | 1           | 2       | 3          |
| **CPU Request**        | 200m        | 500m    | 1000m      |
| **CPU Limit**          | 500m        | 1000m   | 2000m      |
| **Memory Request**     | 256Mi       | 512Mi   | 1Gi        |
| **Memory Limit**       | 512Mi       | 1Gi     | 2Gi        |
| **Auto Scaling**       | ❌ No        | ✅ Yes   | ✅ Yes      |
| **Min Replicas (HPA)** | N/A         | 2       | 3          |
| **Max Replicas (HPA)** | N/A         | 5       | 10         |
| **CPU Threshold**      | N/A         | 70%     | 70%        |
| **Memory Threshold**   | N/A         | 80%     | 80%        |

### Auto Scaling Explanation

* **Dev**: No scaling—meant for local dev with minimal load.
* **Staging**: Scale from 2 to 5—supports load tests.
* **Production**: Scale from 3 to 10—handles peak traffic.

### Example Response to Load

```
Development (no HPA):
[Pod] → always 1 pod only

Staging (with HPA):
[Pod] [Pod] → normal (2 pods)
↓ CPU load rises to 80%
[Pod] [Pod] [Pod] [Pod] → autoscale to 4 pods
↓ load drops
[Pod] [Pod] → back to 2 pods

Production (with HPA):
[Pod] [Pod] [Pod] → normal (3 pods)
↓ CPU load rises to 75%
[Pod] [Pod] [Pod] [Pod] [Pod] [Pod] → autoscale to 6 pods
↓ load keeps rising
[Pod] x10 → max 10 pods
```

## PostgreSQL Database

| Attribute          | Development  | Staging       | Production                          |
| ------------------ | ------------ | ------------- | ----------------------------------- |
| **Enabled**        | ✅ (optional) | ✅ Yes         | ✅ Yes                               |
| **Replicas**       | 1            | 1             | 1                                   |
| **CPU Request**    | 250m         | 500m          | 1000m                               |
| **CPU Limit**      | 500m         | 1000m         | 2000m                               |
| **Memory Request** | 256Mi        | 512Mi         | 1Gi                                 |
| **Memory Limit**   | 512Mi        | 1Gi           | 2Gi                                 |
| **Storage (PVC)**  | 1Gi          | 5Gi           | 20Gi                                |
| **Storage Class**  | default      | default       | default (or SSD in real production) |
| **Database Name**  | myapp_dev    | myapp_staging | myapp_production                    |

### Explanation

* **Dev**: Small storage (1Gi)—sufficient for test data.
* **Staging**: Medium storage (5Gi)—partial production-like data.
* **Production**: Large storage (20Gi)—for real datasets.

### Optional in Development

You can disable the database and use an external DB or a mock:

```yaml
postgresql:
  enabled: false
```

## Ingress Configuration

| Attribute         | Development     | Staging             | Production          |
| ----------------- | --------------- | ------------------- | ------------------- |
| **Hostname**      | dev.myapp.local | staging.myapp.local | prod.myapp.local    |
| **TLS/SSL**       | ❌ No            | ❌ No                | ✅ Yes (recommended) |
| **Rate Limiting** | ❌ No            | ✅ 100 req/s         | ✅ 1000 req/s        |
| **SSL Redirect**  | ❌ No            | ❌ No                | ✅ Yes               |

### Explanation

* **Dev**: No restrictions—free-form testing.
* **Staging**: Basic rate limiting—mimics production protections.
* **Production**: Full protections—DDoS mitigation, full SSL.

## Secrets Management

| Attribute       | Development        | Staging                 | Production                 |
| --------------- | ------------------ | ----------------------- | -------------------------- |
| **DB Username** | devuser            | staginguser             | produser                   |
| **DB Password** | devpass123         | staging-secure-pass-456 | **CHANGE-ME!**             |
| **API Key**     | dev-api-key-12345  | staging-api-key-67890   | **USE VAULT!**             |
| **Management**  | Kubernetes Secrets | Kubernetes Secrets      | External (Vault/Key Vault) |

### ⚠️ Security Warning

In real production, **do not** store passwords in `values.yaml`!

Recommended approaches:

1. **HashiCorp Vault** — centralized secrets management
2. **Azure Key Vault** — for Azure environments
3. **AWS Secrets Manager** — for AWS environments
4. **Sealed Secrets** — encrypted secrets in Git

## Rolling Update Strategy

All environments use the same update strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # one extra pod at a time
    maxUnavailable: 0  # no pod is removed before the new one is ready
```

### Update Process (example with 3 replicas)

```
Start:
[Pod v1.0] [Pod v1.0] [Pod v1.0]

Step 1 – create a new pod:
[Pod v1.0] [Pod v1.0] [Pod v1.0] [Pod v2.0 - Starting]

Step 2 – new pod is ready:
[Pod v1.0] [Pod v1.0] [Pod v1.0] [Pod v2.0 ✓]

Step 3 – remove an old pod:
[Pod v1.0] [Pod v1.0] [Pod v2.0] [Pod v2.0 - Starting]

...and so on until:
[Pod v2.0] [Pod v2.0] [Pod v2.0]
```

**Advantage:** Zero downtime—the application remains available throughout.

## Health Checks (Probes)

Same across all environments—they all include:

### Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

* If it fails 3 times in a row → Kubernetes restarts the pod.

### Readiness Probe

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

* If it fails → The pod won’t receive traffic until it’s ready.

## Resource Utilization – Consumption Comparison

### Typical (Idle) Scenario

| Environment |               Pods | CPU Total | Memory Total |
| ----------- | -----------------: | --------: | -----------: |
| Dev         | 3 (F:1, B:1, DB:1) |     ~550m |       ~896Mi |
| Staging     | 5 (F:2, B:2, DB:1) |    ~1700m |       ~2.5Gi |
| Production  | 7 (F:3, B:3, DB:1) |    ~3500m |       ~5.5Gi |

### High-Load Scenario (with HPA)

| Environment |                 Pods | CPU Total | Memory Total |
| ----------- | -------------------: | --------: | -----------: |
| Dev         |                    3 |     ~550m |       ~896Mi |
| Staging     |   8 (F:2, B:5, DB:1) |    ~4000m |         ~6Gi |
| Production  | 14 (F:3, B:10, DB:1) |   ~12000m |        ~17Gi |

## Deployment Process

### Development

```
Code Change → Push to 'develop' branch
↓
GitHub Actions runs
↓
Auto-deploy to dev namespace
↓
Immediate testing
```

### Staging

```
Merge to 'staging' branch
↓
GitHub Actions runs
↓
Auto-deploy to staging namespace
↓
QA Testing + Smoke Tests
↓
Approval for production
```

### Production

```
Merge to 'main' OR create tag v*
↓
GitHub Actions runs
↓
Auto-deploy to production namespace
↓
Smoke tests
↓
Monitoring & Alerts
```

## When to Use Each Environment?

### Development (dev)

✅ New code
✅ Local testing
✅ Quick debugging
✅ Experiments
❌ Load testing
❌ Full integration tests

### Staging

✅ Integration tests
✅ QA testing
✅ Load testing
✅ Deployment process testing
✅ UAT (User Acceptance Testing)
❌ Active development
❌ Real customer data

### Production

✅ Live app for customers
✅ Real data
✅ High availability
✅ Full monitoring & logging
❌ Testing
❌ Experiments

## Recommended Additional Differences Between Environments

### In real production, consider adding:

1. **Monitoring & Observability**

   ```yaml
   # Production
   monitoring:
     prometheus: enabled
     grafana: enabled
     alertmanager: enabled

   # Dev
   monitoring:
     prometheus: disabled
   ```

2. **Logging**

   ```yaml
   # Production
   logging:
     level: INFO
     aggregation: elasticsearch
     retention: 30d

   # Dev
   logging:
     level: DEBUG
     aggregation: none
     retention: 7d
   ```

3. **Backups**

   ```yaml
   # Production
   backup:
     enabled: true
     schedule: "0 2 * * *"  # Daily at 2 AM
     retention: 30

   # Dev
   backup:
     enabled: false
   ```

4. **Network Policies**

   ```yaml
   # Production
   networkPolicies:
     enabled: true
     egress: restricted
     ingress: restricted

   # Dev
   networkPolicies:
     enabled: false
   ```

## Summary

Key differences between environments:

| Category         | Dev     | Staging | Production |
| ---------------- | ------- | ------- | ---------- |
| **Resources**    | Minimal | Medium  | High       |
| **Replicas**     | 1       | 2       | 3          |
| **Auto Scaling** | No      | Yes     | Yes        |
| **Storage**      | 1Gi     | 5Gi     | 20Gi       |
| **Security**     | Low     | Medium  | High       |
| **Availability** | 50%     | 80%     | 99.9%      |
| **Cost**         | Low     | Medium  | High       |

Each environment is purpose-built, enabling a safe and efficient development and deployment process! 🚀
