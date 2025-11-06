# Monitoring Access - SHA K8s Blog Platform

## Grafana

### Login Credentials

- **URL**: http://sha-grafana-dev.local
- **Username**: `admin`
- **Default Password**: `admin`

### Get Current Password

If the password has been changed, retrieve it from Kubernetes:

```powershell
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### First Login

1. Navigate to http://sha-grafana-dev.local
2. Enter username: `admin`
3. Enter password: `admin`
4. You'll be prompted to change the password (you can skip this for development)

### Change Password

**Via UI:**
1. Login to Grafana
2. Click on your profile icon (bottom left)
3. Click "Change Password"
4. Enter current password and new password
5. Click "Change Password"

**Via kubectl:**
```powershell
# Set a custom password
$newPassword = "YourNewPassword123"
$encodedPassword = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($newPassword))

kubectl patch secret kube-prometheus-stack-grafana -n monitoring -p "{`"data`":{`"admin-password`":`"$encodedPassword`"}}"

# Restart Grafana pod
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring
```

### Import Dashboards

#### Why Dashboards Aren't Visible

The dashboard ConfigMap exists in the `sha-dev` namespace, but Grafana is deployed in the `monitoring` namespace and isn't configured to automatically load dashboards from other namespaces.

**Check if dashboard exists:**
```powershell
kubectl get configmap grafana-dashboards -n sha-dev
```

#### Option 1: Manual Import (Quick Method)

**Step 1: Export dashboard JSON**
```powershell
# Export the dashboard to a file
kubectl get configmap grafana-dashboards -n sha-dev -o jsonpath="{.data.sha-blog-dashboard\.json}" | Out-File -FilePath dashboard.json -Encoding UTF8
```

**Step 2: Import in Grafana UI**
1. Login to Grafana at http://sha-grafana-dev.local
2. Click the "+" icon in the left sidebar
3. Select "Import"
4. Click "Upload JSON file" and select `dashboard.json`
5. Select "Prometheus" as the data source
6. Click "Import"

#### Option 2: Move Dashboard to Monitoring Namespace

```powershell
# Copy the dashboard ConfigMap to the monitoring namespace
kubectl get configmap grafana-dashboards -n sha-dev -o yaml | `
  Select-String -Pattern 'namespace: sha-dev' -NotMatch | `
  kubectl apply -n monitoring -f -

# Add the required label for Grafana to detect it
kubectl label configmap grafana-dashboards -n monitoring grafana_dashboard=1

# Restart Grafana to pick up the new dashboard
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring
```

#### Option 3: Configure Grafana Sidecar (Persistent Solution)

Update Grafana Helm values to watch multiple namespaces:

```yaml
# Add to terraform/modules/monitoring/values.yaml
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      labelValue: "1"
      searchNamespace: "monitoring,sha-dev,sha-staging,sha-production"
```

Then reapply Terraform:
```powershell
cd C:\Users\ILPETSHHA.old\dev\testshahar\terraform
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

#### Dashboard Content

The SHA Blog Platform dashboard includes:

1. **Deployment Status** - Current rollout state (Stable, Progressing, Paused)
2. **Pod Health** - Number of running pods per deployment
3. **HTTP Request Rate** - Requests per second by service
4. **Response Time** - P50, P95, P99 latencies
5. **Error Rate** - HTTP 4xx and 5xx errors
6. **CPU Usage** - Per pod and service
7. **Memory Usage** - Per pod and service
8. **Database Connections** - PostgreSQL connection pool status
9. **Canary Analysis** - Success rate during canary deployments

#### Verify Metrics Are Being Scraped

```powershell
# Check if ServiceMonitors are created
kubectl get servicemonitor -n sha-dev

# Check Prometheus targets
# Port-forward Prometheus and navigate to Status > Targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Expected targets:
- `sha-k8s-blog-dev-sha-microservices-app-backend`
- `sha-k8s-blog-dev-sha-microservices-app-frontend`

## ArgoCD

### Login Credentials

- **URL**: http://sha-argocd-dev.local
- **Username**: `admin`
- **Password**: Get it with:
  ```powershell
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
  ```

**Example Output:**
```
BYp4qek7BGmNidv6
```

### Change ArgoCD Password

```powershell
# Via CLI
argocd login sha-argocd-dev.local --username admin --password <current-password>
argocd account update-password
```

## Prometheus

### Access Prometheus UI

Prometheus doesn't have authentication by default.

- **Direct Access (Port Forward)**:
  ```powershell
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  ```
  Then navigate to: http://localhost:9090

### Query Examples

Once in Prometheus:

**CPU Usage:**
```promql
rate(container_cpu_usage_seconds_total{namespace="sha-dev"}[5m])
```

**Memory Usage:**
```promql
container_memory_usage_bytes{namespace="sha-dev"}
```

**HTTP Request Rate:**
```promql
rate(http_requests_total{namespace="sha-dev"}[5m])
```

## Vault

### Access Vault UI

- **URL**: http://sha-vault-dev.local
- **Authentication**: Token-based

### Get Root Token

```powershell
# The root token is typically in Vault's initialization output
# For development, you can get it from the pod logs
kubectl logs -n vault vault-0 | Select-String "Root Token"
```

### Initialize Vault (First Time)

If Vault is not initialized:

```powershell
# Port forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200

# In another terminal, initialize
$env:VAULT_ADDR="http://localhost:8200"
vault operator init

# Save the unseal keys and root token!
```

## Summary of All Credentials

| Service | URL | Username | Password/Token |
|---------|-----|----------|----------------|
| **Grafana** | http://sha-grafana-dev.local | `admin` | `admin` (default) |
| **ArgoCD** | http://sha-argocd-dev.local | `admin` | From Kubernetes secret |
| **Prometheus** | Port forward 9090 | N/A | No auth |
| **Vault** | http://sha-vault-dev.local | N/A | Root token |
| **Frontend** | http://sha-dev.blog.local | N/A | No auth |

## Quick Access Commands

```powershell
# Get all monitoring credentials at once
Write-Host "=== SHA K8s Blog Platform - Access Info ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Grafana:" -ForegroundColor Yellow
Write-Host "  URL: http://sha-grafana-dev.local"
Write-Host "  User: admin"
Write-Host "  Pass: admin (default)"
Write-Host ""
Write-Host "ArgoCD:" -ForegroundColor Yellow
Write-Host "  URL: http://sha-argocd-dev.local"
Write-Host "  User: admin"
Write-Host "  Pass: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) })"
Write-Host ""
Write-Host "Frontend:" -ForegroundColor Yellow
Write-Host "  URL: http://sha-dev.blog.local"
Write-Host ""
Write-Host "Vault:" -ForegroundColor Yellow
Write-Host "  URL: http://sha-vault-dev.local"
Write-Host ""
```

Save this as `scripts/get-credentials.ps1` for easy access!

## Troubleshooting Access Issues

### Can't Access Grafana

```powershell
# Check if Grafana pod is running
kubectl get pods -n monitoring | Select-String "grafana"

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Check ingress
kubectl get ingress -n monitoring

# Port forward if ingress not working
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Then go to http://localhost:3000
```

### Can't Access ArgoCD

```powershell
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Port forward
kubectl port-forward -n argocd svc/argocd-server 8080:80
# Then go to http://localhost:8080
```

### Forgot Password

**Grafana:**
- Use the kubectl command above to get/reset password

**ArgoCD:**
- Delete and regenerate the initial admin secret
- Or use `argocd account update-password` if you're logged in

## Security Best Practices

For production environments:

1. **Change all default passwords immediately**
2. **Enable HTTPS/TLS** for all services
3. **Set up RBAC** in ArgoCD and Grafana
4. **Enable authentication** for Prometheus
5. **Use proper secrets management** (Vault, External Secrets)
6. **Rotate passwords regularly**
7. **Enable audit logging**
8. **Restrict network access** with NetworkPolicies

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)

