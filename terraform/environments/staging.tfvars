# Staging Environment Configuration

namespace             = "sha-staging"
environment           = "staging"
release_name          = "sha-k8s-blog-staging"
install_ingress       = false  # Reuse ingress from dev
ingress_host          = "sha-staging.blog.local"
pod_security_standard = "restricted"  # Test strict policies before production

# Calico CNI for NetworkPolicy
install_calico        = true
calico_cidr           = "10.244.0.0/16"

# Vault for Secrets Management
install_vault         = true
vault_host            = "sha-vault-staging.local"
vault_storage_size    = "5Gi"
install_external_secrets = true

# Argo Rollouts
install_argo_rollouts = true

# Monitoring
install_prometheus        = true
prometheus_storage_size   = "10Gi"
grafana_storage_size      = "2Gi"
grafana_host              = "sha-grafana-staging.local"

# Medium footprint for staging
frontend_replicas     = 2
backend_replicas      = 2
enable_autoscaling    = true
enable_database       = true
database_storage_size = "5Gi"

# Use default kubeconfig
kubeconfig_path       = "~/.kube/config"
kube_context          = "rancher-desktop"
