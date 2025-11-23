# Variables for Self-Managed Kubernetes on EC2

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2" # Oregon
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "sha-blog-k8s"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Network Configuration
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "pod_network_cidr" {
  description = "Pod network CIDR for Calico/Flannel"
  type        = string
  default     = "192.168.0.0/16"
}

# Master Node Configuration
variable "master_count" {
  description = "Number of master nodes (1 for dev, 3 for HA prod)"
  type        = number
  default     = 1 # COST OPTIMIZATION: 1 master for dev
}

variable "master_instance_type" {
  description = "EC2 instance type for master nodes"
  type        = string
  default     = "t3.small" # COST OPTIMIZATION: 2 vCPU, 2GB RAM - $15.20/month
  # For production: t3.medium ($30.40/month)
}

variable "master_disk_size" {
  description = "Disk size for master nodes in GB"
  type        = number
  default     = 20
}

# Worker Node Configuration
variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2 # COST OPTIMIZATION: 2 workers for basic HA
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small" # COST OPTIMIZATION: $15.20/month each
  # Options:
  # - t3.small: 2 vCPU, 2GB RAM - $15.20/month (minimal)
  # - t3.medium: 2 vCPU, 4GB RAM - $30.40/month (recommended)
  # - t3.large: 2 vCPU, 8GB RAM - $60.80/month (production)
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes in GB"
  type        = number
  default     = 30
}

# SSH Configuration
variable "ssh_public_key" {
  description = "SSH public key for EC2 instances (leave empty to use ~/.ssh/id_rsa.pub)"
  type        = string
  default     = ""
  sensitive   = true
}

# Tags
variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
