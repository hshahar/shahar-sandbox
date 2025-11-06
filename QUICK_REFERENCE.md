# Quick Reference Guide - Kubernetes Blog Platform

## 🚀 Common Commands

### Deployment

```powershell
# Deploy infrastructure
cd terraform
terraform apply -var-file="environments/dev.tfvars"

# Deploy application with ArgoCD
.\scripts\deploy-argocd.ps1 -Environment dev

# Verify full stack
.\scripts\verify-stack.ps1 -Environment dev
```

### Monitoring Rollouts

```powershell
# Watch canary deployment
kubectl argo rollouts get rollout backend -n staging --watch

# Check analysis results
kubectl get analysisrun -n staging

# Abort and rollback
kubectl argo rollouts abort backend -n staging

# Manually promote
kubectl argo rollouts promote backend -n staging
```

### Accessing Dashboards

```powershell
# Grafana
Start-Process "http://grafana-dev.local"
# Credentials: admin/admin

# ArgoCD
Start-Process "http://argocd-dev.local"
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Argo Rollouts
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
Start-Process "http://localhost:3100"

# Vault
Start-Process "http://vault-dev.local"
# Token: root (dev mode)

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
Start-Process "http://localhost:9090"
```

### Debugging

```powershell
# Check pod status
kubectl get pods -n dev

# View logs
kubectl logs -n dev -l app=backend -f

# Describe rollout
kubectl describe rollout backend -n staging

# Check events
kubectl get events -n staging --sort-by='.lastTimestamp'

# Test connectivity
kubectl exec -n dev deployment/backend -- wget -qO- http://postgresql:5432

# Check NetworkPolicy
kubectl get networkpolicy -n dev
kubectl describe networkpolicy default-deny-ingress -n dev
```

### ArgoCD Management

```powershell
# Sync application
.\scripts\sync-app.ps1 -Environment dev -Force

# List applications
kubectl get applications -n argocd

# Get sync status
kubectl get application dev-microservices-app -n argocd -o jsonpath='{.status.sync.status}'

# View application details
kubectl describe application dev-microservices-app -n argocd
```

### Vault Operations

```powershell
# Setup Vault
.\scripts\setup-vault.ps1 -Environment dev

# Read secret
kubectl exec -n vault vault-0 -- env VAULT_TOKEN=root vault kv get secret/dev/database

# Update secret
kubectl exec -n vault vault-0 -- env VAULT_TOKEN=root vault kv put secret/dev/database password="new-password"

# Check external secret sync
kubectl get externalsecret -n staging
kubectl describe externalsecret database-credentials -n staging
```

### Security Verification

```powershell
# Verify Calico
.\scripts\verify-calico.ps1 -Namespace dev

# Check pod security
kubectl get pod -n staging -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

# Verify image signatures
cosign verify --certificate-identity-regexp='.*' --certificate-oidc-issuer='https://token.actions.githubusercontent.com' ghcr.io/{org}/{repo}/backend:tag

# Check Kyverno policies
kubectl get clusterpolicy
kubectl describe clusterpolicy require-image-signature
```

---

## 📊 Key URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Blog App (Dev)** | http://dev.myapp.local | - |
| **Blog App (Staging)** | http://staging.myapp.local | - |
| **Blog App (Prod)** | http://prod.myapp.local | - |
| **Grafana (Dev)** | http://grafana-dev.local | admin/admin |
| **Grafana (Staging)** | http://grafana-staging.local | admin/admin |
| **Grafana (Prod)** | http://grafana.local | admin/admin |
| **ArgoCD** | http://argocd-dev.local | admin/[get password] |
| **Vault (Dev)** | http://vault-dev.local | root |
| **Argo Rollouts** | http://localhost:3100 | (after port-forward) |
| **Prometheus** | http://localhost:9090 | (after port-forward) |

---

## 🔧 Troubleshooting Quick Fixes

### Rollout Stuck

```powershell
# Check analysis status
kubectl get analysisrun -n staging

# Check metrics availability
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/graph
# Query: http_requests_total

# Manually promote if metrics unavailable
kubectl argo rollouts promote backend -n staging
```

### ArgoCD Out of Sync

```powershell
# Force sync
.\scripts\sync-app.ps1 -Environment dev -Force -Prune

# Or via kubectl
kubectl patch application dev-microservices-app -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'
```

### Pod CrashLoopBackOff

```powershell
# Check logs
kubectl logs -n dev pod-name --previous

# Check events
kubectl describe pod -n dev pod-name

# Check resource limits
kubectl top pod -n dev pod-name

# Check secrets
kubectl get secret database-secret -n dev -o yaml
```

### NetworkPolicy Blocking Traffic

```powershell
# Verify Calico
.\scripts\verify-calico.ps1 -Namespace dev

# Check policies
kubectl get networkpolicy -n dev

# Test connectivity
kubectl run test-pod --image=busybox --rm -it -n dev -- wget -T 5 http://backend:8000/health

# Temporarily disable (TESTING ONLY)
kubectl delete networkpolicy -n dev --all
```

### Vault Secrets Not Syncing

```powershell
# Check ExternalSecret status
kubectl get externalsecret -n staging
kubectl describe externalsecret database-credentials -n staging

# Check External Secrets Operator logs
kubectl logs -n external-secrets-system deployment/external-secrets -f

# Force refresh
kubectl annotate externalsecret database-credentials -n staging force-sync=$(date +%s) --overwrite
```

### Grafana Dashboard Not Loading

```powershell
# Check ConfigMap exists
kubectl get configmap grafana-dashboards -n dev

# Check Grafana pod logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana -f

# Restart Grafana
kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring
```

---

## 📈 Health Check Queries

### Prometheus Queries

```promql
# Request rate
sum(rate(http_requests_total{namespace="dev"}[5m])) by (service)

# Error rate
sum(rate(http_requests_total{namespace="dev",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="dev"}[5m])) * 100

# Latency P95
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="dev"}[5m])) by (le, service)) * 1000

# CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="dev",container!=""}[5m])) by (pod) * 100

# Memory usage
sum(container_memory_working_set_bytes{namespace="dev",container!=""}) by (pod) / 1024 / 1024

# Pod ready ratio
sum(kube_pod_status_ready{namespace="dev",condition="true"}) / sum(kube_pod_status_ready{namespace="dev"}) * 100
```

---

## 🎯 Environment-Specific Settings

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| **Replicas** | 1 | 2 | 3 |
| **Disk** | 1Gi | 5Gi | 10Gi |
| **Prometheus Storage** | 2Gi | 10Gi | 50Gi |
| **Grafana Storage** | 500Mi | 2Gi | 5Gi |
| **Auto-Sync** | ✅ Yes | ✅ Yes | ❌ Manual |
| **Canary** | ❌ No | ✅ Yes | ✅ Yes |
| **Vault** | ❌ Basic Secrets | ✅ Yes | ✅ Yes |
| **PSA** | Baseline | Restricted | Restricted |
| **Error Rate Alert** | 10% | 3% | 1% |
| **Latency Alert** | 2000ms | 500ms | 300ms |

---

## 🔄 CI/CD Pipeline Triggers

| Branch | Environment | Trigger | Actions |
|--------|-------------|---------|---------|
| **develop** | Dev | Auto on push | Full pipeline → Auto-deploy |
| **staging** | Staging | Auto on push | Full pipeline → Canary deploy |
| **main** | Production | Manual promotion | Full pipeline → Canary deploy |

---

## 🛡️ Security Checklist

Before production deployment:

- [ ] Change Grafana admin password
- [ ] Configure Vault production mode (not dev mode)
- [ ] Enable AlertManager notifications
- [ ] Set up GitHub Environment approvers
- [ ] Configure branch protection rules
- [ ] Review Kyverno policies (enforce mode)
- [ ] Verify image signing working
- [ ] Check SBOM generation
- [ ] Review NetworkPolicies
- [ ] Enable audit logging in Vault
- [ ] Backup Vault unseal keys (production)
- [ ] Configure TLS for Ingress (production)

---

## 📞 Quick Links

- **Full Documentation**: [README.md](README.md)
- **CI/CD Pipeline**: [docs/CI_CD_PIPELINE.md](docs/CI_CD_PIPELINE.md)
- **Progressive Delivery**: [docs/PROGRESSIVE_DELIVERY.md](docs/PROGRESSIVE_DELIVERY.md)
- **Security Guide**: [docs/SECURITY.md](docs/SECURITY.md)
- **Vault Guide**: [docs/VAULT_GUIDE.md](docs/VAULT_GUIDE.md)
- **ArgoCD Setup**: [docs/ARGOCD_SETUP.md](docs/ARGOCD_SETUP.md)
- **GitOps Workflow**: [docs/GITOPS_WORKFLOW.md](docs/GITOPS_WORKFLOW.md)

---

**Keep this guide handy for quick reference! 🚀**
