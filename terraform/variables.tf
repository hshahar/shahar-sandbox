variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "rancher-desktop"
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "release_name" {
  description = "Helm release name with SHA custom prefix"
  type        = string
  default     = "sha-k8s-blog"
}

variable "install_ingress" {
  description = "Whether to install ingress-nginx controller"
  type        = bool
  default     = true
}

variable "frontend_replicas" {
  description = "Number of frontend replicas"
  type        = number
  default     = 1
}

variable "backend_replicas" {
  description = "Number of backend replicas"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable horizontal pod autoscaling for backend"
  type        = bool
  default     = false
}

variable "enable_database" {
  description = "Enable PostgreSQL database"
  type        = bool
  default     = true
}

variable "database_storage_size" {
  description = "PostgreSQL persistent volume size"
  type        = string
  default     = "1Gi"
}

variable "ingress_host" {
  description = "Ingress hostname for SHA's blog platform"
  type        = string
}

variable "pod_security_standard" {
  description = "Pod Security Standard level (privileged, baseline, restricted)"
  type        = string
  default     = "baseline"
  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.pod_security_standard)
    error_message = "Pod security standard must be privileged, baseline, or restricted."
  }
}

variable "install_argocd" {
  description = "Whether to install ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_host" {
  description = "ArgoCD server hostname"
  type        = string
  default     = "argocd.local"
}

variable "install_calico" {
  description = "Whether to install Calico CNI for NetworkPolicy support"
  type        = bool
  default     = true
}

variable "calico_cidr" {
  description = "CIDR for Calico pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "install_vault" {
  description = "Whether to install HashiCorp Vault for secrets management"
  type        = bool
  default     = true
}

variable "vault_host" {
  description = "Vault server hostname"
  type        = string
  default     = "vault.local"
}

variable "vault_storage_size" {
  description = "Vault persistent storage size"
  type        = string
  default     = "1Gi"
}

variable "install_external_secrets" {
  description = "Whether to install External Secrets Operator"
  type        = bool
  default     = true
}

# Argo Rollouts variables
variable "install_argo_rollouts" {
  description = "Whether to install Argo Rollouts for progressive delivery"
  type        = bool
  default     = true
}

variable "install_keda" {
  description = "Whether to install KEDA for event-driven autoscaling"
  type        = bool
  default     = true
}

variable "install_karpenter" {
  description = "Whether to install Karpenter for node autoscaling"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name for Karpenter"
  type        = string
  default     = "sha-blog-eks"
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint for Karpenter"
  type        = string
  default     = ""
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for Karpenter IAM role"
  type        = string
  default     = ""
}

variable "oidc_provider" {
  description = "OIDC provider URL for Karpenter IAM role"
  type        = string
  default     = ""
}

variable "node_role_arn" {
  description = "Node IAM role ARN for Karpenter"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Project     = "SHA-K8s-Blog"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

# Monitoring variables
variable "install_prometheus" {
  description = "Whether to install Prometheus + Grafana stack"
  type        = bool
  default     = true
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "5Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "1Gi"
}

variable "grafana_host" {
  description = "Hostname for Grafana ingress"
  type        = string
  default     = "grafana.local"
}
