# Security Implementation Guide

This document describes the comprehensive security features implemented in this Kubernetes microservices infrastructure, following 2025 best practices.

## Table of Contents

1. [Security Architecture Overview](#security-architecture-overview)
2. [Pod Security Admission (PSA)](#pod-security-admission-psa)
3. [NetworkPolicy Implementation](#networkpolicy-implementation)
4. [SecurityContext Hardening](#securitycontext-hardening)
5. [Kyverno Policy Engine](#kyverno-policy-engine)
6. [User Namespaces](#user-namespaces)
7. [Image Security](#image-security)
8. [Secrets Management](#secrets-management)
9. [Security Checklist](#security-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Security Architecture Overview

Our security implementation follows a **defense-in-depth** approach with multiple layers:

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Admission Control (Kyverno + PSA)             │
│  - Image verification, policy enforcement               │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Network Isolation (NetworkPolicy)             │
│  - Default-deny baseline, least-privilege rules         │
├─────────────────────────────────────────────────────────┤
│ Layer 3: Container Security (SecurityContext)          │
│  - Non-root, read-only filesystem, seccomp, no caps    │
├─────────────────────────────────────────────────────────┤
│ Layer 4: Runtime Protection (User Namespaces)          │
│  - Host namespace isolation, privilege separation      │
├─────────────────────────────────────────────────────────┤
│ Layer 5: Secrets Protection (External Secrets)         │
│  - Vault/AWS integration, no secrets in git            │
└─────────────────────────────────────────────────────────┘
```

### Security Features by Environment

| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| PSA Level | `baseline` | `restricted` | `restricted` |
| NetworkPolicy | ✅ Enabled | ✅ Enabled | ✅ Enabled |
| User Namespaces | ❌ Disabled | ✅ Enabled | ✅ Enabled |
| Kyverno | ❌ Disabled | ✅ Audit Mode | ✅ Enforce Mode |
| Seccomp | ✅ RuntimeDefault | ✅ RuntimeDefault | ✅ RuntimeDefault |
| Read-Only Rootfs | ✅ Enabled | ✅ Enabled | ✅ Enabled |

---

## Pod Security Admission (PSA)

**Pod Security Admission** replaces the deprecated PodSecurityPolicy (PSP) and enforces security standards at the namespace level.

### PSA Standards

- **Privileged**: Unrestricted (dev/testing only)
- **Baseline**: Minimal restrictions, prevents known privilege escalations
- **Restricted**: Hardened, follows pod hardening best practices

### Implementation

PSA labels are applied to namespaces via Terraform:

```hcl
metadata {
  labels = {
    "pod-security.kubernetes.io/enforce" = var.pod_security_standard
    "pod-security.kubernetes.io/audit"   = var.pod_security_standard
    "pod-security.kubernetes.io/warn"    = var.pod_security_standard
  }
}
```

### Configuration

Set in `terraform/environments/*.tfvars`:

```hcl
pod_security_standard = "restricted"  # dev: baseline, staging/prod: restricted
```

### Restricted Standard Requirements

To pass `restricted` PSA level, pods must:
- Run as non-root user (`runAsNonRoot: true`)
- Use restricted seccomp profile (`seccompProfile.type: RuntimeDefault`)
- Drop all capabilities (`capabilities.drop: ["ALL"]`)
- Disallow privilege escalation (`allowPrivilegeEscalation: false`)
- Use restricted volume types (no `hostPath`)

---

## NetworkPolicy Implementation

**Default-deny** baseline with explicit allow rules following **least-privilege** principle.

### CNI Requirement

NetworkPolicy requires a CNI plugin that supports it. This project uses **Calico**.

**Calico Installation**: Automatically installed via Terraform when `install_calico = true`

```powershell
# Verify Calico is running
kubectl get pods -n calico-system

# Check NetworkPolicy support
.\scripts\verify-calico.ps1
```

### Architecture

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Ingress    │         │   Frontend   │         │   Backend    │
│  Controller  │────────▶│    (Nginx)   │────────▶│  (http-echo) │
└──────────────┘         └──────────────┘         └──────────────┘
                                                           │
                                                           ▼
                                                   ┌──────────────┐
                                                   │  PostgreSQL  │
                                                   │   Database   │
                                                   └──────────────┘

All connections explicitly allowed by NetworkPolicy.
Default: DENY ALL ingress and egress.
```

### Policies Implemented

1. **default-deny-all**: Baseline deny for all pods
2. **allow-dns**: Allow DNS queries (kube-dns/coredns)
3. **frontend-ingress**: Allow traffic from ingress-nginx
4. **frontend-to-backend**: Allow frontend → backend communication
5. **backend-to-database**: Allow backend → PostgreSQL
6. **backend-egress**: Allow backend → external APIs (optional)

### Configuration

Enable/disable in `values.yaml`:

```yaml
networkPolicy:
  enabled: true
  allowExternalEgress: false  # Strict mode for production
```

### Testing NetworkPolicy

```powershell
# Deploy application
helm install myapp ./helm/microservices-app -f helm/microservices-app/values-staging.yaml

# Run automated tests
.\scripts\verify-calico.ps1 -Namespace staging

# Manual tests
# Test frontend → backend (should succeed)
kubectl exec -n staging deployment/frontend -- wget -O- http://backend:8080/health

# Test frontend → database (should FAIL - blocked by policy)
kubectl exec -n staging deployment/frontend -- nc -zv postgresql 5432
```

### Calico-Specific Features

#### Network Policy Ordering

Calico evaluates policies in this order:
1. Deny policies (higher precedence)
2. Allow policies
3. Default deny (if no match)

#### Calico CLI Tools

```powershell
# Install calicoctl (optional)
kubectl apply -f https://docs.tigera.io/calico/latest/manifests/calicoctl.yaml

# View Calico node status
kubectl exec -n calico-system calicoctl -- node status

# View detailed NetworkPolicy
kubectl exec -n calico-system calicoctl -- get networkpolicy -o wide
```

---

## SecurityContext Hardening

All pods implement **strict SecurityContext** settings aligned with CIS Kubernetes Benchmark.

### Pod-Level Security Context

```yaml
securityContext:
  runAsNonRoot: true        # Prevent root execution
  runAsUser: 1000           # Explicit UID
  fsGroup: 1000             # File ownership
  seccompProfile:
    type: RuntimeDefault    # Seccomp filtering
```

### Container-Level Security Context

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]           # Drop all Linux capabilities
```

### Read-Only Filesystem Workarounds

Applications requiring write access get **emptyDir** volumes:

```yaml
# Frontend (Nginx)
volumeMounts:
  - name: cache
    mountPath: /var/cache/nginx
  - name: run
    mountPath: /var/run

volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

### User/Group IDs

| Component | User ID | Notes |
|-----------|---------|-------|
| Frontend (Nginx) | 101 | Official nginx user |
| Backend | 1000 | Standard non-root |
| PostgreSQL | 999 | postgres user |

---

## Kyverno Policy Engine

**Kyverno** provides declarative admission policies for advanced security enforcement.

### Prerequisites

Install Kyverno (not included in automation):

```powershell
# Install Kyverno via Helm
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno `
  --namespace kyverno `
  --create-namespace `
  --set admissionController.replicas=3 `
  --set backgroundController.replicas=2

# Wait for deployment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=300s
```

### Policies Implemented

#### 1. Image Signature Verification (Cosign)

```yaml
spec:
  verifyImages:
    - imageReferences:
        - "ghcr.io/yourusername/*"
      attestors:
        - entries:
            - keyless:
                issuer: "https://token.actions.githubusercontent.com"
                subject: "https://github.com/yourusername/yourrepo/*"
```

**Purpose**: Only allow signed container images from trusted sources.

#### 2. Disallow Privileged Containers

```yaml
validate:
  pattern:
    spec:
      containers:
        - securityContext:
            privileged: false
```

**Purpose**: Prevent privileged containers that can access host resources.

#### 3. Require Read-Only Root Filesystem

```yaml
validate:
  pattern:
    spec:
      containers:
        - securityContext:
            readOnlyRootFilesystem: true
```

**Purpose**: Enforce immutable container filesystems.

#### 4. Disallow Latest Tag

```yaml
validate:
  pattern:
    spec:
      containers:
        - image: "!*:latest"
```

**Purpose**: Prevent non-reproducible deployments with `:latest` tag.

#### 5. Require Resource Limits

```yaml
validate:
  pattern:
    spec:
      containers:
        - resources:
            limits:
              memory: "?*"
              cpu: "?*"
```

**Purpose**: Prevent resource exhaustion attacks.

### Configuration

Enable/configure in `values.yaml`:

```yaml
security:
  kyverno:
    enabled: true
    validationFailureAction: enforce  # or "audit" for testing
    trustedRegistries:
      - "ghcr.io"
      - "your-registry.io"
    cosign:
      keyless: true
      issuer: "https://token.actions.githubusercontent.com"
      subject: "https://github.com/yourusername/yourrepo/*"
```

### Testing Kyverno Policies

```powershell
# Try to deploy privileged container (should FAIL)
kubectl run privileged-test --image=nginx --privileged

# Try to deploy with :latest tag (should FAIL)
kubectl run latest-test --image=nginx:latest

# Check policy reports
kubectl get polr -A  # Policy Reports
kubectl get clusterpolicyreport
```

---

## User Namespaces

**User Namespaces** provide host-level privilege isolation by mapping container UIDs to different host UIDs.

### Requirements

- Kubernetes 1.33+ (released January 2025)
- Feature gate enabled: `UserNamespacesSupport=true`
- cgroupv2 on host OS
- Container runtime support (containerd 1.7+)

### Implementation

Enabled per-pod with `hostUsers: false`:

```yaml
spec:
  hostUsers: false  # Enable User Namespaces
  securityContext:
    runAsUser: 1000
```

**Effect**: Container UID 1000 maps to host UID 231072 (example), isolating from host processes.

### Configuration

Enable in values files:

```yaml
security:
  userNamespaces:
    enabled: true  # Disabled in dev, enabled in staging/prod
```

### Verification

```powershell
# Check if User Namespaces are active
kubectl exec -n staging deployment/backend -- cat /proc/self/uid_map
# Output: 0   231072   65536 (if enabled)
# Output: 0        0   65536 (if disabled)
```

### Limitations

- Incompatible with some volume types (hostPath, nfs with certain configs)
- Requires host OS support (Linux 4.15+)
- May not work with all CNI plugins

---

## Image Security

### Image Signing with Cosign

**Cosign** signs container images to ensure integrity and provenance.

#### Setup (GitHub Actions Example)

```yaml
- name: Sign Image
  run: |
    cosign sign --yes \
      -a "repo=${{ github.repository }}" \
      -a "ref=${{ github.ref }}" \
      ghcr.io/yourusername/yourimage:${{ github.sha }}
  env:
    COSIGN_EXPERIMENTAL: "true"  # Keyless signing
```

#### Verification (via Kyverno)

Automatically enforced when `security.kyverno.enabled: true`.

### Image Scanning

Integrate vulnerability scanning in CI/CD:

```yaml
# GitHub Actions
- name: Scan Image
  uses: anchore/scan-action@v3
  with:
    image: "ghcr.io/yourusername/yourimage:${{ github.sha }}"
    fail-build: true
    severity-cutoff: high
```

### Trusted Registries

Configure allowed registries:

```yaml
security:
  kyverno:
    trustedRegistries:
      - "ghcr.io"
      - "docker.io/library"  # Official images only
      - "your-registry.io"
```

---

## Secrets Management

### Current Implementation

Basic Kubernetes Secrets (encoded, not encrypted at rest by default):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
type: Opaque
data:
  username: {{ .Values.secrets.database.username | b64enc }}
  password: {{ .Values.secrets.database.password | b64enc }}
```

⚠️ **WARNING**: Default secrets are placeholders. **CHANGE IN PRODUCTION!**

### Production Recommendations

#### Option 1: External Secrets Operator (ESO)

Sync secrets from external vaults:

```powershell
# Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-operator --create-namespace

# Create SecretStore (Vault example)
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: production
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp-role"
EOF

# Create ExternalSecret
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secret
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-secret
  data:
    - secretKey: username
      remoteRef:
        key: database/production
        property: username
    - secretKey: password
      remoteRef:
        key: database/production
        property: password
EOF
```

#### Option 2: Sealed Secrets

Encrypt secrets for storage in Git:

```powershell
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
choco install kubeseal  # or download from GitHub releases

# Create sealed secret
kubectl create secret generic database-secret `
  --from-literal=username=produser `
  --from-literal=password=secretpass123 `
  --dry-run=client -o yaml | kubeseal -o yaml > sealed-database-secret.yaml

# Commit sealed-database-secret.yaml to git (safe!)
```

#### Option 3: KMS Encryption at Rest

Enable Kubernetes encryption with AWS KMS/Azure KeyVault:

```yaml
# encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - kms:
          name: aws-kms
          endpoint: unix:///var/run/kmsplugin/socket.sock
          cachesize: 1000
      - identity: {}
```

---

## Security Checklist

### Pre-Deployment

- [ ] Change all default passwords in values files
- [ ] Configure trusted container registries
- [ ] Set up image scanning in CI/CD
- [ ] Install Kyverno policy engine
- [ ] Configure External Secrets Operator (or similar)
- [ ] Enable User Namespaces on Kubernetes cluster
- [ ] Set appropriate PSA standard per environment
- [ ] Review NetworkPolicy rules for your architecture

### Post-Deployment

- [ ] Verify pods run as non-root: `kubectl get pods -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}'`
- [ ] Check NetworkPolicy is active: `kubectl get netpol -A`
- [ ] Validate Kyverno policies: `kubectl get clusterpolicy`
- [ ] Test network isolation: Try unauthorized connections
- [ ] Review policy reports: `kubectl get polr -A`
- [ ] Audit logs for security events
- [ ] Scan running images for vulnerabilities
- [ ] Verify secrets rotation schedule

### Ongoing Operations

- [ ] Regularly update container images
- [ ] Monitor Kyverno policy violations
- [ ] Review and update NetworkPolicies as app evolves
- [ ] Rotate secrets quarterly
- [ ] Update PSA standards as Kubernetes releases new versions
- [ ] Conduct security audits quarterly
- [ ] Keep Kyverno policies updated
- [ ] Review and remediate CVEs within SLA

---

## Troubleshooting

### Pod Fails PSA Admission

**Symptom**: `Error creating: pods "myapp-xxx" is forbidden: violates PodSecurity "restricted:latest"`

**Solutions**:
1. Ensure `runAsNonRoot: true` in SecurityContext
2. Set `seccompProfile.type: RuntimeDefault`
3. Add `allowPrivilegeEscalation: false`
4. Drop all capabilities: `capabilities.drop: ["ALL"]`

### NetworkPolicy Blocks Legitimate Traffic

**Symptom**: Application can't connect to backend/database

**Debug**:
```powershell
# Check NetworkPolicies
kubectl get netpol -n <namespace>
kubectl describe netpol <policy-name> -n <namespace>

# Test connectivity
kubectl run test --rm -it --image=nicolaka/netshoot -n <namespace> -- /bin/bash
# Inside pod:
nslookup backend
curl http://backend:8080/health
telnet postgresql 5432
```

**Solutions**:
- Verify `networkPolicy.enabled: true` in values
- Check pod labels match policy selectors
- Ensure DNS egress is allowed
- Review `allowExternalEgress` setting

### Read-Only Filesystem Errors

**Symptom**: Application crashes with "read-only file system" error

**Solution**: Add emptyDir volumes for writable paths:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

### Kyverno Policy Blocks Deployment

**Symptom**: `admission webhook "validate.kyverno.svc" denied the request`

**Debug**:
```powershell
# Get policy reports
kubectl get polr -n <namespace>
kubectl describe polr <report-name> -n <namespace>

# Check policy details
kubectl get clusterpolicy <policy-name> -o yaml
```

**Solutions**:
- Set `validationFailureAction: audit` temporarily to identify issues
- Review policy requirements in this document
- Add exemptions if needed:
  ```yaml
  spec:
    validationFailureActionOverrides:
      - action: audit
        namespaces: ["dev"]
  ```

### User Namespaces Not Working

**Symptom**: `uid_map` shows `0 0 65536` instead of remapped UIDs

**Check**:
```powershell
# Verify feature gate
kubectl get --raw /metrics | Select-String "user_namespaces"

# Check Kubernetes version
kubectl version --short
# Must be 1.33+

# Check node OS
kubectl get nodes -o wide
# Linux kernel 4.15+
```

**Solutions**:
- Upgrade Kubernetes to 1.33+
- Enable feature gate in kubelet config
- Ensure cgroupv2 is active: `mount | grep cgroup2`

### Image Signature Verification Fails

**Symptom**: Kyverno blocks unsigned images

**Debug**:
```powershell
# Manually verify signature
cosign verify --certificate-identity-regexp=".*" `
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" `
  ghcr.io/yourusername/yourimage:tag
```

**Solutions**:
- Ensure images are signed in CI/CD
- Verify `cosign.issuer` and `cosign.subject` match your GitHub setup
- Use `validationFailureAction: audit` during testing
- Add temporary exemptions:
  ```yaml
  security:
    kyverno:
      trustedRegistries:
        - "docker.io"  # Allow Docker Hub during migration
  ```

---

## Additional Resources

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kyverno Policy Library](https://kyverno.io/policies/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [User Namespaces KEP](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/127-user-namespaces)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)

---

**Last Updated**: January 2025  
**Kubernetes Version**: 1.33-1.34  
**Maintainer**: DevOps Team
