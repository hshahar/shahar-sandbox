terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

# AWS Provider
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

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC for EKS (cost-optimized: 2 AZs instead of 3)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Use only 2 AZs to save on NAT Gateway costs
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private subnets for worker nodes
  private_subnets = [
    for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)
  ]

  # Public subnets for load balancers
  public_subnets = [
    for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + var.az_count)
  ]

  # COST OPTIMIZATION: Single NAT Gateway instead of one per AZ
  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway # true for dev, false for prod
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# EKS Cluster (cost-optimized configuration)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # COST OPTIMIZATION: Disable logging for dev (can enable for prod)
  cluster_enabled_log_types = var.enable_cluster_logging ? [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ] : []

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # OIDC Provider for IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Managed Node Groups (cost-optimized)
  eks_managed_node_groups = {
    # General purpose node group - COST OPTIMIZED
    general = {
      name = "${var.cluster_name}-general"

      # Use Spot Instances for 70% cost savings (can fall back to On-Demand)
      capacity_type = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

      # Minimal instance type for development
      instance_types = var.node_instance_types

      # Scaling configuration
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Disk size
      disk_size = var.node_disk_size # 20GB is minimum, sufficient for dev

      # Labels
      labels = {
        Environment = var.environment
        NodeGroup   = "general"
      }

      # Taints (optional - for production workloads)
      taints = []

      # Use latest Amazon Linux 2 EKS optimized AMI
      ami_type = "AL2_x86_64"

      # Tags
      tags = {
        Name = "${var.cluster_name}-general-node"
      }
    }
  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = var.cluster_name
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

# AWS Load Balancer Controller (required for Ingress)
module "aws_load_balancer_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name = "${var.cluster_name}-lb-controller-role"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller.iam_role_arn
  }

  depends_on = [module.eks]
}

# EBS CSI Driver (for persistent volumes)
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Name = "${var.cluster_name}-ebs-csi-role"
  }
}

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.28.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.ebs_csi_driver_irsa.iam_role_arn
  }

  depends_on = [module.eks]
}

# Storage Class for EBS volumes (gp3 is cheaper than gp2)
resource "kubernetes_storage_class_v1" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    # COST OPTIMIZATION: Lower IOPS for dev
    iops       = var.ebs_iops
    throughput = var.ebs_throughput
  }

  depends_on = [helm_release.ebs_csi_driver]
}

# Optional: Cluster Autoscaler (for auto-scaling nodes)
module "cluster_autoscaler_irsa" {
  count   = var.enable_cluster_autoscaler ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-cluster-autoscaler"

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = {
    Name = "${var.cluster_name}-autoscaler-role"
  }
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.34.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa[0].iam_role_arn
  }

  depends_on = [module.eks]
}
