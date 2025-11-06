output "namespace" {
  description = "The namespace where the application is deployed"
  value       = kubernetes_namespace.app_namespace.metadata[0].name
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "release_name" {
  description = "The Helm release name"
  value       = helm_release.microservices_app.name
}

output "ingress_host" {
  description = "The ingress hostname"
  value       = var.ingress_host
}

output "ingress_nginx_status" {
  description = "Status of ingress-nginx installation"
  value       = var.install_ingress ? "Installed" : "Skipped"
}

output "application_url" {
  description = "Application URL"
  value       = "http://${var.ingress_host}"
}

output "kubectl_commands" {
  description = "Useful kubectl commands"
  value = <<-EOT
    # View all resources
    kubectl get all -n ${var.namespace}
    
    # View pods
    kubectl get pods -n ${var.namespace}
    
    # View services
    kubectl get svc -n ${var.namespace}
    
    # View ingress
    kubectl get ingress -n ${var.namespace}
    
    # View logs (frontend)
    kubectl logs -n ${var.namespace} -l app=frontend -f
    
    # View logs (backend)
    kubectl logs -n ${var.namespace} -l app=backend -f
  EOT
}
