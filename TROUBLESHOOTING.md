# Troubleshooting Guide – Common Issues

A guide for resolving common problems during application deployment.

## Table of Contents

1. [Startup Issues](#startup-issues)
2. [Pod Issues](#pod-issues)
3. [Networking Issues](#networking-issues)
4. [Storage Issues](#storage-issues)
5. [Helm Issues](#helm-issues)
6. [Terraform Issues](#terraform-issues)
7. [Performance Issues](#performance-issues)

---

## Startup Issues

### ❌ “kubectl: command not found”

**Cause:** `kubectl` isn’t installed.

**Fix:**

```powershell
winget install Kubernetes.kubectl
```

Verify:

```powershell
kubectl version --client
```

---

### ❌ “The connection to the server localhost:8080 was refused”

**Cause:** The Kubernetes cluster isn’t running.

**Fix:**

1. Open Rancher Desktop / Docker Desktop.
2. Make sure the Kubernetes option is enabled.
3. Wait until the status shows “Running”.

Verify:

```powershell
kubectl cluster-info
kubectl get nodes
```

---

### ❌ “error: no context exists with the name”

**Cause:** `kubectl` context isn’t set.

**Fix:**

```powershell
# Show available contexts
kubectl config get-contexts

# Set context
kubectl config use-context rancher-desktop

# Or for Docker Desktop
kubectl config use-context docker-desktop
```

---

## Pod Issues

### ❌ Pod is in “Pending” status

**Possible cause 1:** Not enough cluster resources.

**Check:**

```powershell
kubectl describe pod <pod-name> -n dev
kubectl top nodes
```

**Fix:**

* Reduce resource requests in `values.yaml`.
* Close other applications.
* Allocate more resources to the cluster.

**Possible cause 2:** PVC can’t be created.

**Check:**

```powershell
kubectl get pvc -n dev
kubectl describe pvc <pvc-name> -n dev
```

**Fix:**

```powershell
# Check storage class
kubectl get storageclass

# If none is default, set one
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

### ❌ Pod is in “CrashLoopBackOff”

**Check:**

```powershell
# Check logs
kubectl logs <pod-name> -n dev

# Previous run logs
kubectl logs <pod-name> -n dev --previous

# Events
kubectl describe pod <pod-name> -n dev
```

**Common fixes:**

1. **Configuration error:**

   ```powershell
   kubectl get configmap -n dev
   kubectl describe configmap <name> -n dev
   ```

2. **Secrets error:**

   ```powershell
   kubectl get secrets -n dev
   kubectl describe secret <name> -n dev
   ```

3. **Health check failing:**

   * Increase `initialDelaySeconds` in probes.
   * Ensure the endpoint exists.

---

### ❌ “ImagePullBackOff”

**Cause:** The image can’t be pulled.

**Check:**

```powershell
kubectl describe pod <pod-name> -n dev | Select-String "Failed"
```

**Fixes:**

1. **Incorrect image name:**

   ```yaml
   # Ensure the name is correct
   image: nginx:1.25-alpine  # ✅
   image: ngnix:1.25-alpine  # ❌ typo
   ```

2. **Image doesn’t exist:**

   ```powershell
   # Check on Docker Hub
   # Or switch to an image that exists
   ```

3. **Network issues:**

   ```powershell
   # Check internet connectivity
   # Check proxy settings if applicable
   ```

---

### ❌ Pod is “Ready” but not working

**Check:**

```powershell
# Live logs
kubectl logs -n dev -l app=backend -f

# Exec into the pod
kubectl exec -it <pod-name> -n dev -- /bin/sh

# Check ports
kubectl exec -it <pod-name> -n dev -- netstat -tlnp
```

**Fix:**

* Verify the application is listening on the correct port.
* Check environment variables.
* Verify connectivity to other services.

---

## Networking Issues

### ❌ Can’t access the app via Ingress

**Step 1 – Ingress Controller:**

```powershell
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

**If not installed:**

```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=300s
```

**Step 2 – Ingress Resource:**

```powershell
kubectl get ingress -n dev
kubectl describe ingress -n dev
```

**Fix:**

```yaml
# Ensure the className is correct
spec:
  ingressClassName: nginx  # Must match the controller
```

**Step 3 – Hosts file:**

```powershell
# Windows: C:\Windows\System32\drivers\etc\hosts
# Should contain:
127.0.0.1 dev.myapp.local
```

**Add as Administrator:**

```powershell
.\scripts\add-hosts.ps1
```

**Step 4 – Port Forwarding (alternative):**

```powershell
kubectl port-forward -n dev service/myapp-dev-frontend 8080:80
# Go to: http://localhost:8080
```

---

### ❌ Backend can’t connect to the Database

**Check:**

```powershell
# Verify the service exists
kubectl get svc -n dev

# Verify the pod is running
kubectl get pods -n dev -l app=postgresql

# Try connecting from the backend
kubectl exec -it <backend-pod> -n dev -- sh
# Inside:
nc -zv myapp-dev-postgresql 5432
```

**Fix:**

```yaml
# Ensure environment variables are correct
env:
- name: DATABASE_HOST
  value: "myapp-dev-postgresql"  # Service name
- name: DATABASE_PORT
  value: "5432"
```

---

### ❌ “dial tcp: lookup ... no such host”

**Cause:** Service name is wrong or doesn’t exist.

**Fix:**

```powershell
# List services
kubectl get svc -n dev

# Correct format:
<service-name>.<namespace>.svc.cluster.local

# Example:
myapp-dev-postgresql.dev.svc.cluster.local
```

---

## Storage Issues

### ❌ PVC is in “Pending” status

**Check:**

```powershell
kubectl get pvc -n dev
kubectl describe pvc <pvc-name> -n dev
kubectl get storageclass
```

**Common causes:**

1. **No default StorageClass:**

   ```powershell
   kubectl get storageclass
   # If none shows "(default)"

   # Set a default
   kubectl patch storageclass local-path `
     -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

2. **Requested size unavailable:**

   ```yaml
   # Reduce the size
   persistence:
     size: 1Gi  # instead of 20Gi
   ```

---

### ❌ PostgreSQL pod fails with “could not create directory”

**Cause:** Volume permission issues.

**Fix:**

```yaml
# Add securityContext to the StatefulSet
securityContext:
  fsGroup: 999
  runAsUser: 999
```

Or:

```powershell
# Delete the PVC and restart
kubectl delete pvc postgresql-data-myapp-dev-postgresql-0 -n dev
kubectl delete pod myapp-dev-postgresql-0 -n dev
```

---

### ❌ Data loss after deleting a Pod

**Check:**

```powershell
kubectl get pvc -n dev
kubectl get pv
```

**Fix:**

* Ensure `persistence.enabled: true`.
* Ensure a PVC is mounted to the pod.
* Use a StatefulSet (not a Deployment) for the database.

---

## Helm Issues

### ❌ “Error: INSTALLATION FAILED: chart not found”

**Cause:** Wrong path.

**Fix:**

```powershell
# Ensure you're in the correct folder
cd helm\microservices-app

# Or specify a full path
helm install myapp-dev .\helm\microservices-app -f values-dev.yaml
```

---

### ❌ “Error: YAML parse error”

**Cause:** YAML syntax error.

**Fix:**

```powershell
# Lint for syntax
helm lint . -f values-dev.yaml

# Check template rendering
helm template myapp-dev . -f values-dev.yaml

# Inspect a specific file
helm template myapp-dev . -f values-dev.yaml --show-only templates/backend-deployment.yaml
```

---

### ❌ “Error: release already exists”

**Fix:**

```powershell
# Use upgrade instead of install
helm upgrade myapp-dev . -f values-dev.yaml -n dev

# Or uninstall the existing release
helm uninstall myapp-dev -n dev
# then install again
```

---

### ❌ “Error: timed out waiting for the condition”

**Cause:** Pods take longer to become ready.

**Fix:**

```powershell
# Increase timeout
helm install myapp-dev . -f values-dev.yaml -n dev --timeout 10m

# Or disable waiting
helm install myapp-dev . -f values-dev.yaml -n dev --wait=false
```

---

## Terraform Issues

### ❌ “Error: Failed to query available provider packages”

**Cause:** Network issue or providers not defined.

**Fix:**

```powershell
cd terraform
terraform init

# Or force re-download
terraform init -upgrade
```

---

### ❌ “Error: context deadline exceeded”

**Cause:** Terraform can’t connect to the cluster.

**Fix:**

```powershell
# Check kubeconfig
kubectl cluster-info

# Ensure the correct context
kubectl config current-context

# Update in tfvars
kube_context = "rancher-desktop"  # or docker-desktop
```

---

### ❌ “Error: Kubernetes cluster unreachable”

**Fix:**

```powershell
# Check that the cluster is running
kubectl get nodes

# Ensure kubeconfig path is correct
kubeconfig_path = "~/.kube/config"
```

---

### ❌ State Lock

**Cause:** Another Terraform process is running or was interrupted.

**Fix:**

```powershell
# Force unlock (only if you're sure nothing else is running!)
terraform force-unlock <lock-id>
```

---

## Performance Issues

### ❌ Pods are being killed and restarted (OOMKilled)

**Cause:** The pod exceeds its memory limit.

**Check:**

```powershell
kubectl describe pod <pod-name> -n dev | Select-String "OOMKilled"
kubectl top pods -n dev
```

**Fix:**

```yaml
# Increase memory limits
resources:
  limits:
    memory: 1Gi  # instead of 512Mi
  requests:
    memory: 512Mi  # instead of 256Mi
```

---

### ❌ HPA not working

**Check:**

```powershell
kubectl get hpa -n staging
kubectl describe hpa <hpa-name> -n staging
```

**Common causes:**

1. **Metrics Server not installed:**

   ```powershell
   kubectl top nodes
   # If you see an error:

   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

2. **Resource requests not set:**

   ```yaml
   # Must be defined
   resources:
     requests:
       cpu: 200m  # HPA requires this!
   ```

---

### ❌ Application is slow

**Checks:**

```powershell
# Resource usage
kubectl top pods -n dev
kubectl top nodes

# Check limits
kubectl describe pod <pod-name> -n dev | Select-String "Limits"

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp' | Select-Object -Last 20
```

**Fixes:**

1. Increase resources.
2. Add replicas.
3. Enable HPA.
4. Check network latency.

---

## General Debug Commands

### Quick system check:

```powershell
# Overall status
kubectl get all -n dev

# Health checks
kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev
kubectl get pvc -n dev

# Logs
kubectl logs -n dev -l app=backend --tail=50

# Events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Exec into a pod:

```powershell
kubectl exec -it <pod-name> -n dev -- /bin/sh

# Inside the pod:
env | grep -i db        # Check environment variables
ps aux                  # Running processes
netstat -tlnp           # Listening ports
curl localhost:8080     # Check a local endpoint
```

### Connectivity checks:

```powershell
# Run a temporary pod
kubectl run debug --image=curlimages/curl -it --rm --restart=Never -n dev -- sh

# Inside:
curl http://myapp-dev-frontend
curl http://myapp-dev-backend:8080/health
nslookup myapp-dev-postgresql
```

---

## Still need help?

1. Check the logs: `.\scripts\view-logs.ps1 -Environment dev -Follow`
2. Run a status check: `.\scripts\status.ps1 -Environment dev`
3. See [USAGE.md](USAGE.md) for detailed information
4. See [README.md](README.md) for installation instructions

## Tips to Prevent Issues

✅ Always run `terraform plan` before `apply`
✅ Always run `helm lint` before install
✅ Use `--dry-run` for validation
✅ Keep your kubeconfig up to date
✅ Ensure your machine has enough resources
✅ Keep backups of state and values files
✅ Review logs regularly
