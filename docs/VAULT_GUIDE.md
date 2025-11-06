# HashiCorp Vault Integration Guide

Complete guide for using HashiCorp Vault for secrets management in the Kubernetes Blog Platform.

## Table of Contents

1. [What is Vault?](#what-is-vault)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Initial Setup](#initial-setup)
5. [Secrets Management](#secrets-management)
6. [Integration with Kubernetes](#integration-with-kubernetes)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## What is Vault?

HashiCorp Vault is a secrets management tool that provides:

- **Centralized Secrets Storage**: Single source for all secrets
- **Dynamic Secrets**: Generate credentials on-demand
- **Encryption as a Service**: Encrypt/decrypt data without storing it
- **Audit Logging**: Complete audit trail of secret access
- **Access Control**: Fine-grained policies for secret access
- **Secret Rotation**: Automatic rotation of credentials

### Why Vault for Kubernetes?

❌ **Without Vault**:
- Secrets hardcoded in YAML files
- Secrets stored in Git (security risk)
- Manual secret rotation
- No audit trail
- Difficult multi-environment management

✅ **With Vault**:
- Secrets stored securely in Vault
- Dynamic secrets generation
- Automatic rotation
- Complete audit logs
- Centralized management across environments

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    HashiCorp Vault                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │         KV v2 Secrets Engine (secret/)             │ │
│  │  ├── dev/                                          │ │
│  │  │   ├── database (username, password, database)  │ │
│  │  │   └── backend (api_key, jwt_secret)            │ │
│  │  ├── staging/                                      │ │
│  │  │   ├── database                                  │ │
│  │  │   └── backend                                   │ │
│  │  └── production/                                   │ │
│  │      ├── database                                  │ │
│  │      └── backend                                   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │    Kubernetes Auth (auth/kubernetes/)              │ │
│  │  - Authenticates pods via ServiceAccount           │ │
│  │  - Maps to Vault policies                          │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│          External Secrets Operator (ESO)                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │  SecretStore (connects to Vault)                   │ │
│  │  ExternalSecret (defines which secrets to sync)    │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│               Kubernetes Secrets                          │
│  - database-secret                                       │
│  - backend-secret                                        │
│  (Automatically synced from Vault every 1 hour)          │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│              Application Pods                             │
│  - Frontend, Backend, Database                           │
│  - Mount secrets as environment variables or files       │
└──────────────────────────────────────────────────────────┘
```

---

## Installation

### Via Terraform (Recommended)

Vault is automatically installed when you deploy infrastructure:

```powershell
cd terraform
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

This installs:
- **HashiCorp Vault** (dev mode for dev environment, standalone for staging/prod)
- **External Secrets Operator** (syncs Vault secrets to K8s Secrets)
- **Vault Ingress** (access UI at http://vault-dev.local)

### Manual Installation

```powershell
# Add Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault in dev mode
helm install vault hashicorp/vault `
  --namespace vault `
  --create-namespace `
  --set "server.dev.enabled=true"

# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets `
  --namespace external-secrets-system `
  --create-namespace `
  --set installCRDs=true
```

---

## Initial Setup

### 1. Run Setup Script

```powershell
# Initialize Vault for dev environment
.\scripts\setup-vault.ps1 -Environment dev

# For staging/production (requires initialization)
.\scripts\setup-vault.ps1 -Environment staging
```

The script:
1. Checks Vault installation
2. Initializes Vault (if needed)
3. Unseals Vault (if needed)
4. Enables Kubernetes authentication
5. Creates policies and roles
6. Creates sample secrets

### 2. Access Vault UI

```powershell
# Add to hosts file
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 vault-dev.local"

# Open browser
Start-Process "http://vault-dev.local"
```

**Login**:
- **Dev Environment**: Token = `root`
- **Staging/Prod**: Use root token from initialization output

### 3. Verify Installation

```powershell
# Check Vault pods
kubectl get pods -n vault

# Check External Secrets Operator
kubectl get pods -n external-secrets-system

# Test Vault access
$vaultPod = kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n vault $vaultPod -- vault status
```

---

## Secrets Management

### Creating Secrets

#### Via Vault CLI

```powershell
# Get Vault pod name
$vaultPod = kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}'

# Set environment (dev/staging/prod)
$env = "dev"
$token = "root"  # Use your root token

# Create database secret
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv put "secret/$env/database" `
    username="bloguser" `
    password="supersecret123" `
    database="blogdb"

# Create backend API secret
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv put "secret/$env/backend" `
    api_key="my-secure-api-key" `
    jwt_secret="my-jwt-signing-key"
```

#### Via Vault UI

1. Navigate to http://vault-dev.local
2. Login with token
3. Go to **Secrets** → **secret/**
4. Click **Create secret**
5. Path: `dev/database`
6. Add key-value pairs:
   - `username` = `bloguser`
   - `password` = `supersecret123`
   - `database` = `blogdb`
7. Click **Save**

### Reading Secrets

```powershell
# Read database secret
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv get secret/dev/database

# Read specific field
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv get -field=password secret/dev/database
```

### Updating Secrets

```powershell
# Update password only
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv patch secret/dev/database `
    password="new-password-456"

# Replace entire secret
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv put secret/dev/database `
    username="newuser" `
    password="newpass" `
    database="newdb"
```

### Deleting Secrets

```powershell
# Soft delete (can be undeleted)
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv delete secret/dev/database

# Undelete
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv undelete -versions=1 secret/dev/database

# Permanently destroy
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv destroy -versions=1 secret/dev/database
```

---

## Integration with Kubernetes

### External Secrets Operator Flow

1. **SecretStore** CRD defines connection to Vault
2. **ExternalSecret** CRD defines which Vault secrets to sync
3. **ESO** reads from Vault and creates Kubernetes Secrets
4. **Pods** mount Kubernetes Secrets as usual

### SecretStore Configuration

Located in `helm/microservices-app/templates/external-secrets.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: dev
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "dev-vault-role"
```

### ExternalSecret Configuration

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: dev
spec:
  refreshInterval: 1h  # Sync every hour
  secretStoreRef:
    name: vault-backend
  target:
    name: database-secret  # K8s Secret name
  data:
    - secretKey: username
      remoteRef:
        key: dev/database
        property: username
    - secretKey: password
      remoteRef:
        key: dev/database
        property: password
```

### Enabling Vault in Helm Values

```yaml
# values-staging.yaml
vault:
  enabled: true
  refreshInterval: "30m"
```

### Verifying Sync

```powershell
# Check ExternalSecrets status
kubectl get externalsecret -n dev

# Expected output:
# NAME                     STORE           REFRESH INTERVAL   STATUS
# database-credentials     vault-backend   1h                 SecretSynced
# backend-api-credentials  vault-backend   1h                 SecretSynced

# Check if K8s Secrets were created
kubectl get secret database-secret -n dev
kubectl get secret backend-secret -n dev

# View secret contents
kubectl get secret database-secret -n dev -o jsonpath='{.data.username}' | base64 -d
```

---

## Best Practices

### 1. Environment Separation

✅ **DO**:
- Use separate Vault paths for each environment: `secret/dev/`, `secret/staging/`, `secret/prod/`
- Create environment-specific policies and roles
- Never share production secrets with dev/staging

### 2. Secret Rotation

```powershell
# Rotate database password
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv put secret/prod/database `
    password="new-rotated-password-$(Get-Date -Format 'yyyyMMddHHmm')"

# External Secrets Operator will sync within refreshInterval (default 1 hour)
# Or force immediate sync:
kubectl annotate externalsecret database-credentials -n production force-sync=true
```

### 3. Access Control

```powershell
# Create read-only policy for specific paths
$policy = @"
path "secret/data/prod/database" {
  capabilities = ["read"]
}
"@

kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault policy write prod-db-readonly - <<< $policy

# Create role with limited access
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault write auth/kubernetes/role/prod-db-role `
    bound_service_account_names=database-sa `
    bound_service_account_namespaces=production `
    policies=prod-db-readonly
```

### 4. Audit Logging

```powershell
# Enable audit logging
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault audit enable file file_path=/vault/logs/audit.log

# View audit logs
kubectl logs -n vault vault-0 -c vault -f | grep audit
```

### 5. Backup and Disaster Recovery

```powershell
# Export all secrets (for backup)
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault kv list -format=json secret/ > vault-backup.json

# Take snapshot (Enterprise feature)
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault operator raft snapshot save backup.snap
```

---

## Troubleshooting

### Vault Pod Not Starting

```powershell
# Check pod status
kubectl get pods -n vault
kubectl describe pod vault-0 -n vault

# Check logs
kubectl logs -n vault vault-0 -c vault

# Common issues:
# - Insufficient resources
# - PVC not bound
# - Configuration errors
```

### ExternalSecret Not Syncing

```powershell
# Check ExternalSecret status
kubectl describe externalsecret database-credentials -n dev

# Check External Secrets Operator logs
kubectl logs -n external-secrets-system deployment/external-secrets -f

# Common issues:
# - Vault authentication failed (check role/policy)
# - Secret path incorrect
# - Vault unsealed
# - Network connectivity
```

### Vault Sealed

```powershell
# Check if sealed
kubectl exec -n vault vault-0 -- vault status

# Unseal (use unseal key from initialization)
kubectl exec -n vault vault-0 -- vault operator unseal <UNSEAL_KEY>
```

### Permission Denied Errors

```powershell
# Check policy
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault policy read dev-readonly

# Check role configuration
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault read auth/kubernetes/role/dev-vault-role

# Test authentication
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault token lookup
```

### Secrets Not Updating in Pods

```powershell
# Force ExternalSecret sync
kubectl annotate externalsecret database-credentials -n dev force-sync=$(date +%s) --overwrite

# Restart pods to pick up new secrets
kubectl rollout restart deployment/backend -n dev

# Check secret content
kubectl get secret database-secret -n dev -o yaml
```

---

## Advanced Topics

### Dynamic Database Credentials

Vault can generate database credentials on-demand:

```powershell
# Enable database secrets engine
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault secrets enable database

# Configure PostgreSQL connection
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault write database/config/postgresql `
    plugin_name=postgresql-database-plugin `
    allowed_roles="dev-db-role" `
    connection_url="postgresql://{{username}}:{{password}}@postgresql.dev.svc.cluster.local:5432/blogdb" `
    username="postgres" `
    password="postgres"

# Create role for dynamic credentials
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault write database/roles/dev-db-role `
    db_name=postgresql `
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" `
    default_ttl="1h" `
    max_ttl="24h"
```

### Encryption as a Service

```powershell
# Enable transit engine
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault secrets enable transit

# Create encryption key
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault write -f transit/keys/blog-encryption

# Encrypt data
$encrypted = kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault write -field=ciphertext transit/encrypt/blog-encryption plaintext=$(echo -n "sensitive data" | base64)

# Decrypt data
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$token vault write -field=plaintext transit/decrypt/blog-encryption ciphertext=$encrypted | base64 -d
```

---

## Additional Resources

- **Vault Documentation**: https://www.vaultproject.io/docs
- **Vault Learn Tutorials**: https://learn.hashicorp.com/vault
- **External Secrets Operator**: https://external-secrets.io/
- **Kubernetes Auth Method**: https://www.vaultproject.io/docs/auth/kubernetes

---

**Next Steps**: See [SECURITY.md](./SECURITY.md) for comprehensive security implementation.
