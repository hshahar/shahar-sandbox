# Development Environment Configuration

namespace             = "sha-dev"
environment           = "dev"
release_name          = "sha-k8s-blog-dev"
install_ingress       = true
ingress_host          = "sha-dev.blog.local"
pod_security_standard = "baseline"  # Less strict for development

# ArgoCD Configuration
install_argocd        = true
argocd_host           = "sha-argocd-dev.local"

# Calico CNI for NetworkPolicy
install_calico        = true
calico_cidr           = "10.244.0.0/16"

# Vault for Secrets Management
install_vault         = true
vault_host            = "sha-vault-dev.local"
vault_storage_size    = "1Gi"
install_external_secrets = true

# Argo Rollouts
install_argo_rollouts = true

# Monitoring
install_prometheus        = true
prometheus_storage_size   = "2Gi"
grafana_storage_size      = "500Mi"
grafana_host              = "sha-grafana-dev.local"

# Small footprint for development
frontend_replicas     = 1
backend_replicas      = 1
enable_autoscaling    = false
enable_database       = true
database_storage_size = "1Gi"

# Use default kubeconfig
kubeconfig_path       = "~/.kube/config"
kube_context          = "docker-desktop"
