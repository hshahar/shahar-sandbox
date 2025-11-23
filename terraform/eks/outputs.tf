# EKS Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

# Node Group Outputs
output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# kubectl Configuration Command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    eks_control_plane = "72.00" # $0.10/hour * 730 hours
    nat_gateway       = var.single_nat_gateway ? "32.85" : "${32.85 * var.az_count}"
    nodes_spot        = var.use_spot_instances ? "~${var.node_group_desired_size * 0.0125 * 730}" : "N/A"
    nodes_on_demand   = !var.use_spot_instances ? "~${var.node_group_desired_size * 0.0416 * 730}" : "N/A"
    ebs_storage       = "~${var.node_group_desired_size * var.node_disk_size * 0.08}"
    load_balancer     = "~16.20"
    total_minimum     = var.use_spot_instances ? "~$130-150" : "~$180-200"
    note              = "Costs are estimates. Use AWS Cost Explorer for accurate tracking. Shutdown nodes when not in use to save ~70% of costs."
  }
}
