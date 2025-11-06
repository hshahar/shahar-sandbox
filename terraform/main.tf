terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Configure Kubernetes provider to use local kubeconfig
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

# Install Calico CNI for NetworkPolicy support
resource "helm_release" "calico" {
  count = var.install_calico ? 1 : 0

  name       = "calico"
  repository = "https://docs.tigera.io/calico/charts"
  chart      = "tigera-operator"
  version    = "v3.28.2"
  namespace  = "tigera-operator"

  create_namespace = true

  set {
    name  = "installation.kubernetesProvider"
    value = ""
  }

  set {
    name  = "installation.cni.type"
    value = "Calico"
  }

  set {
    name  = "installation.calicoNetwork.ipPools[0].cidr"
    value = var.calico_cidr
  }

  set {
    name  = "installation.calicoNetwork.ipPools[0].encapsulation"
    value = "VXLAN"
  }

  # Wait for Calico to be ready
  wait    = true
  timeout = 600
}

# Create namespace for the environment
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
    labels = {
      environment = var.environment
      managed-by  = "terraform"
      # Pod Security Standards (PSA)
      "pod-security.kubernetes.io/enforce" = var.pod_security_standard
      "pod-security.kubernetes.io/audit"   = var.pod_security_standard
      "pod-security.kubernetes.io/warn"    = var.pod_security_standard
    }
  }

  depends_on = [helm_release.calico]
}

# Install Ingress NGINX using Helm
resource "helm_release" "ingress_nginx" {
  count = var.install_ingress ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.9.0"
  namespace  = "ingress-nginx"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }
}

# Install ArgoCD using Helm
resource "helm_release" "argocd" {
  count = var.install_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.6.12"  # Latest stable as of Nov 2025
  namespace  = "argocd"

  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = var.argocd_host
      }
      
      server = {
        ingress = {
          enabled = true
          ingressClassName = "nginx"
          hosts = [var.argocd_host]
          tls = []
        }
        
        # Disable TLS for local development
        extraArgs = [
          "--insecure"
        ]
      }
      
      # Minimal resources for local deployment
      controller = {
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }
      
      repoServer = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      
      applicationSet = {
        enabled = true
      }
    })
  ]

  depends_on = [
    helm_release.ingress_nginx
  ]
}

# Install HashiCorp Vault using Helm
resource "helm_release" "vault" {
  count = var.install_vault ? 1 : 0

  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.28.1"
  namespace  = "vault"

  create_namespace = true

  values = [
    yamlencode({
      server = {
        # Dev mode for local development (NOT for production)
        dev = {
          enabled = var.environment == "dev" ? true : false
        }
        
        # Standalone mode with persistent storage
        standalone = {
          enabled = var.environment != "dev" ? true : false
          config = <<-EOT
            ui = true
            
            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }
            
            storage "file" {
              path = "/vault/data"
            }
          EOT
        }
        
        # Data storage
        dataStorage = {
          enabled = var.environment != "dev" ? true : false
          size = var.vault_storage_size
          storageClass = null
        }
        
        # Resources
        resources = {
          requests = {
            memory = "256Mi"
            cpu = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu = "500m"
          }
        }
        
        # Ingress
        ingress = {
          enabled = true
          ingressClassName = "nginx"
          hosts = [{
            host = var.vault_host
            paths = ["/"]
          }]
        }
      }
      
      # UI enabled
      ui = {
        enabled = true
        serviceType = "ClusterIP"
      }
      
      # Injector for automatic secret injection
      injector = {
        enabled = true
        resources = {
          requests = {
            memory = "128Mi"
            cpu = "100m"
          }
          limits = {
            memory = "256Mi"
            cpu = "200m"
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.ingress_nginx
  ]
}

# Install Argo Rollouts for Progressive Delivery (Canary Deployments)
resource "helm_release" "argo_rollouts" {
  count = var.install_argo_rollouts ? 1 : 0

  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = "2.37.7"
  namespace  = "argo-rollouts"
  create_namespace = true

  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  set {
    name  = "dashboard.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.replicas"
    value = var.environment == "prod" ? 2 : 1
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = var.install_prometheus
  }

  depends_on = [
    kubernetes_namespace.app_namespace,
    helm_release.kube_prometheus_stack
  ]
}

# Install KEDA (Kubernetes Event Driven Autoscaling)
resource "helm_release" "keda" {
  count = var.install_keda ? 1 : 0

  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.14.2"
  namespace  = "keda"
  create_namespace = true

  set {
    name  = "operator.replicaCount"
    value = var.environment == "prod" ? 2 : 1
  }

  set {
    name  = "metricsServer.replicaCount"
    value = var.environment == "prod" ? 2 : 1
  }

  set {
    name  = "webhooks.replicaCount"
    value = var.environment == "prod" ? 2 : 1
  }

  set {
    name  = "prometheus.metricServer.enabled"
    value = var.install_prometheus
  }

  set {
    name  = "prometheus.operator.enabled"
    value = var.install_prometheus
  }

  set {
    name  = "serviceMonitor.enabled"
    value = var.install_prometheus
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# Install Prometheus Stack (Prometheus + Grafana + AlertManager)
resource "helm_release" "kube_prometheus_stack" {
  count = var.install_prometheus ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.1.1"
  namespace  = "monitoring"
  create_namespace = true
  timeout    = 600

  # Prometheus configuration
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.environment == "prod" ? "30d" : "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Grafana configuration
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin"  # Change in production!
  }

  set {
    name  = "grafana.persistence.enabled"
    value = var.environment != "dev"
  }

  set {
    name  = "grafana.persistence.size"
    value = var.grafana_storage_size
  }

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "grafana.ingress.hosts[0]"
    value = var.grafana_host
  }

  # AlertManager configuration
  set {
    name  = "alertmanager.enabled"
    value = var.environment == "prod"
  }

  depends_on = [helm_release.ingress_nginx]
}

# Install External Secrets Operator (integrates Vault with K8s Secrets)
resource "helm_release" "external_secrets" {
  count = var.install_external_secrets ? 1 : 0

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.10.4"
  namespace  = "external-secrets-system"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "webhook.port"
    value = "9443"
  }

  depends_on = [
    helm_release.vault
  ]
}

# Deploy the microservices application using Helm
resource "helm_release" "microservices_app" {
  name       = var.release_name
  chart      = "${path.module}/../helm/microservices-app"
  namespace  = kubernetes_namespace.app_namespace.metadata[0].name
  
  values = [
    file("${path.module}/../helm/microservices-app/values-${var.environment}.yaml")
  ]

  # Override specific values based on variables
  set {
    name  = "environment"
    value = var.environment
  }

  set {
    name  = "frontend.replicas"
    value = var.frontend_replicas
  }

  set {
    name  = "backend.replicas"
    value = var.backend_replicas
  }

  set {
    name  = "backend.autoscaling.enabled"
    value = var.enable_autoscaling
  }

  set {
    name  = "postgresql.enabled"
    value = var.enable_database
  }

  set {
    name  = "postgresql.persistence.size"
    value = var.database_storage_size
  }

  set {
    name  = "ingress.host"
    value = var.ingress_host
  }

  depends_on = [
    kubernetes_namespace.app_namespace,
    helm_release.ingress_nginx,
    helm_release.kube_prometheus_stack
  ]
}
