# Production Environment Configuration

namespace             = "sha-production"
environment           = "prod"
release_name          = "sha-k8s-blog-prod"
install_ingress       = false  # Reuse ingress from dev
ingress_host          = "sha.blog.local"
pod_security_standard = "restricted"  # STRICT security in production

# Calico CNI for NetworkPolicy
install_calico        = true
calico_cidr           = "10.244.0.0/16"

# Vault for Secrets Management
install_vault         = true
vault_host            = "sha-vault.local"
vault_storage_size    = "10Gi"
install_external_secrets = true

# Argo Rollouts
install_argo_rollouts = true

# Monitoring
install_prometheus        = true
prometheus_storage_size   = "50Gi"
grafana_storage_size      = "5Gi"
grafana_host              = "sha-grafana.local"

# Large footprint for production
frontend_replicas     = 3
backend_replicas      = 3
enable_autoscaling    = true
enable_database       = true
database_storage_size = "20Gi"

# Use default kubeconfig
kubeconfig_path       = "~/.kube/config"
kube_context          = "rancher-desktop"
