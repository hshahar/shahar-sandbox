# AWS Configuration
variable "aws_region" {
  description = "AWS region for EKS cluster"
  type        = string
  default     = "us-west-2" # Oregon
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "sha-blog-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (2 for cost savings, 3 for HA)"
  type        = number
  default     = 2 # COST OPTIMIZATION: Use 2 AZs instead of 3
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all AZs (true for cost savings)"
  type        = bool
  default     = true # COST OPTIMIZATION: Single NAT gateway saves ~$32/month per AZ
}

# Node Group Configuration - COST OPTIMIZED
variable "node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default = [
    "t3.medium",  # 2 vCPU, 4GB RAM - $0.0416/hour (~$30/month)
    "t3a.medium"  # AMD variant, cheaper alternative
  ]
}

variable "use_spot_instances" {
  description = "Use Spot instances for 70% cost savings (recommended for dev)"
  type        = bool
  default     = true # COST OPTIMIZATION: Spot instances save ~70%
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1 # COST OPTIMIZATION: Start with 1 node
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2 # COST OPTIMIZATION: 2 nodes for basic HA
}

variable "node_disk_size" {
  description = "Disk size for nodes in GB"
  type        = number
  default     = 30 # COST OPTIMIZATION: 30GB is sufficient for dev
}

# EBS Configuration
variable "ebs_iops" {
  description = "IOPS for gp3 volumes"
  type        = string
  default     = "3000" # Minimum for gp3
}

variable "ebs_throughput" {
  description = "Throughput for gp3 volumes in MB/s"
  type        = string
  default     = "125" # Minimum for gp3
}

# Feature Flags
variable "enable_cluster_logging" {
  description = "Enable EKS control plane logging (costs extra)"
  type        = bool
  default     = false # COST OPTIMIZATION: Disable for dev, enable for prod
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
