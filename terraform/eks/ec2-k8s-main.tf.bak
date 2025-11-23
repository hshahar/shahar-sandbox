# Self-Managed Kubernetes on EC2 (No EKS - Maximum Cost Savings!)
# This creates a Kubernetes cluster using EC2 instances directly
# Cost: ~$30-40/month (vs $150+ with EKS)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "SHA-K8s-Blog"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Development"
    }
  }
}

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for Master Node
resource "aws_security_group" "master" {
  name        = "${var.cluster_name}-master-sg"
  description = "Security group for Kubernetes master node"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # Kubernetes API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API"
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
    description = "etcd"
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    description = "Kubelet API"
  }

  # All traffic within cluster
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # HTTP/HTTPS from anywhere (for apps)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # NodePort range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-master-sg"
  }
}

# Security Group for Worker Nodes
resource "aws_security_group" "worker" {
  name        = "${var.cluster_name}-worker-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # Kubelet API
  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.master.id]
    description     = "Kubelet API from master"
  }

  # All traffic within cluster
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.master.id]
  }

  # HTTP/HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-worker-sg"
  }
}

# SSH Key Pair
resource "aws_key_pair" "k8s" {
  key_name   = "${var.cluster_name}-key"
  public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")

  tags = {
    Name = "${var.cluster_name}-key"
  }
}

# Master Node(s)
resource "aws_instance" "master" {
  count                  = var.master_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.master.id]
  subnet_id              = aws_subnet.public[count.index % var.az_count].id

  root_block_device {
    volume_size = var.master_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/master-init.sh", {
    cluster_name   = var.cluster_name
    pod_network_cidr = var.pod_network_cidr
    is_first_master = count.index == 0
  })

  tags = {
    Name = "${var.cluster_name}-master-${count.index + 1}"
    Role = "master"
  }
}

# Worker Nodes
resource "aws_instance" "worker" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.worker.id]
  subnet_id              = aws_subnet.public[count.index % var.az_count].id

  root_block_device {
    volume_size = var.worker_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/worker-init.sh", {
    master_ip = aws_instance.master[0].private_ip
  })

  depends_on = [aws_instance.master]

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }
}

# Outputs
output "master_public_ips" {
  description = "Public IP addresses of master nodes"
  value       = aws_instance.master[*].public_ip
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "master_private_ips" {
  description = "Private IP addresses of master nodes"
  value       = aws_instance.master[*].private_ip
}

output "ssh_command_master" {
  description = "SSH command to connect to master"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.master[0].public_ip}"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from master"
  value       = "scp -i ~/.ssh/id_rsa ubuntu@${aws_instance.master[0].public_ip}:/home/ubuntu/.kube/config ~/.kube/config"
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost (USD)"
  value = {
    master_nodes    = "$${var.master_count * (var.master_instance_type == "t3.small" ? 15.20 : 30.40)}"
    worker_nodes    = "$${var.worker_count * (var.worker_instance_type == "t3.small" ? 15.20 : var.worker_instance_type == "t3.medium" ? 30.40 : 60.80)}"
    storage         = "$${(var.master_count * var.master_disk_size + var.worker_count * var.worker_disk_size) * 0.08}"
    data_transfer   = "~$5-10"
    total_minimum   = "~$30-50/month (vs $150+ with EKS!)"
    savings         = "Save $100-120/month compared to EKS"
  }
}
