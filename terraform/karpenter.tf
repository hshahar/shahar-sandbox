# Karpenter - Kubernetes Autoscaler
# Dynamically provisions nodes based on pod requirements

locals {
  karpenter_namespace = "karpenter"
}

# Karpenter Helm Release
resource "helm_release" "karpenter" {
  count = var.install_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.8.0"
  namespace  = local.karpenter_namespace

  create_namespace = true

  values = [
    yamlencode({
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = try(aws_sqs_queue.karpenter_interruption[0].name, "")
        featureGates      = {
          spotToSpotConsolidation = true
        }
      }
      controller = {
        env = [
          {
            name  = "FEATURE_GATES"
            value = "SpotToSpotConsolidation=true"
          }
        ]
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = try(aws_iam_role.karpenter_controller[0].arn, "")
        }
      }
      replicas = 2
      resources = {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller
  ]
}

# Karpenter IAM Role
resource "aws_iam_role" "karpenter_controller" {
  count = var.install_karpenter ? 1 : 0

  name = "${var.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:${local.karpenter_namespace}:karpenter"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Karpenter Controller Policy
resource "aws_iam_policy" "karpenter_controller" {
  count = var.install_karpenter ? 1 : 0

  name        = "${var.cluster_name}-karpenter-controller"
  description = "Karpenter controller policy for ${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}::image/*",
          "arn:aws:ec2:${var.region}::snapshot/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:security-group/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:spot-instances-request/*",
        ]
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:fleet/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedResourceCreationTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:fleet/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateFleet",
              "CreateLaunchTemplate"
            ]
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowMachineMigrationTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
            "ec2:CreateAction"    = "RunInstances"
          }
        }
      },
      {
        Sid    = "AllowKarpenterInstanceTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:launch-template/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowRegionalReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
        }
      },
      {
        Sid    = "AllowSSMReadActions"
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.region}::parameter/aws/service/*"
      },
      {
        Sid    = "AllowPricingReadActions"
        Effect = "Allow"
        Action = "pricing:GetProducts"
        Resource = "*"
      },
      {
        Sid    = "AllowPassingInstanceRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = var.node_role_arn
      },
      {
        Sid    = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"
        Action = "iam:CreateInstanceProfile"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/*"
      },
      {
        Sid    = "AllowScopedInstanceProfileTagActions"
        Effect = "Allow"
        Action = "iam:TagInstanceProfile"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/*"
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/*"
      },
      {
        Sid    = "AllowInstanceProfileReadActions"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAPIServerEndpointDiscovery"
        Effect = "Allow"
        Action = "eks:DescribeCluster"
        Resource = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  count = var.install_karpenter ? 1 : 0

  role       = aws_iam_role.karpenter_controller[0].name
  policy_arn = aws_iam_policy.karpenter_controller[0].arn
}

# SQS Queue for Spot Interruption Handling
resource "aws_sqs_queue" "karpenter_interruption" {
  count = var.install_karpenter ? 1 : 0

  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = var.common_tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  count = var.install_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.karpenter_interruption[0].url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption[0].arn
      }
    ]
  })
}

# EventBridge Rules for Spot Interruptions
resource "aws_cloudwatch_event_rule" "karpenter_interruption_spot" {
  count = var.install_karpenter ? 1 : 0

  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Karpenter spot instance interruption warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "karpenter_interruption_spot" {
  count = var.install_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_interruption_spot[0].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_interruption_rebalance" {
  count = var.install_karpenter ? 1 : 0

  name        = "${var.cluster_name}-karpenter-rebalance"
  description = "Karpenter EC2 instance rebalance recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "karpenter_interruption_rebalance" {
  count = var.install_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_interruption_rebalance[0].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_interruption_state_change" {
  count = var.install_karpenter ? 1 : 0

  name        = "${var.cluster_name}-karpenter-state-change"
  description = "Karpenter EC2 instance state change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "karpenter_interruption_state_change" {
  count = var.install_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_interruption_state_change[0].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
