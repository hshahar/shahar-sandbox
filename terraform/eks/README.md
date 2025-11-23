# SHA Blog Platform - AWS EKS Deployment Guide

## 🎯 Overview

This guide will help you deploy the SHA Kubernetes Blog Platform on **AWS EKS (Elastic Kubernetes Service)** in the **Oregon (us-west-2)** region with **cost-optimized** configurations.

### 💰 Cost Estimate

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| EKS Control Plane | $72.00 | Fixed cost, always running |
| NAT Gateway (1x) | $32.85 | Fixed cost for internet access |
| Worker Nodes (2x t3.medium Spot) | $18-22 | ~70% cheaper than On-Demand |
| EBS Storage (60GB total) | $4.80 | gp3 volumes |
| Load Balancer | $16.20 | Application Load Balancer |
| Data Transfer | $5-10 | Varies by usage |
| **TOTAL (Running)** | **$150-160/month** | When cluster is active |
| **TOTAL (Shutdown)** | **$105/month** | Control plane + NAT only |

**💡 Cost Saving Tip**: Use the shutdown script when not using the cluster to save ~$50-60/month!

---

## 📋 Prerequisites

Before starting, you need:

1. **AWS Account** - [Sign up here](https://aws.amazon.com/free/)
2. **AWS CLI** - [Installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. **kubectl** - [Installation guide](https://kubernetes.io/docs/tasks/tools/)
4. **Terraform** - Version 1.0+ [Download](https://www.terraform.io/downloads)
5. **PowerShell 7+** or **Bash**

---

## 🔑 Step 1: Create AWS Access Keys

### Option A: Using AWS Console (Recommended for Beginners)

1. **Sign in to AWS Console**: https://console.aws.amazon.com/

2. **Go to IAM**:
   - Click on your username (top right)
   - Select "Security credentials"

3. **Create Access Key**:
   - Scroll down to "Access keys"
   - Click "Create access key"
   - Choose "Command Line Interface (CLI)"
   - Check the confirmation box
   - Click "Create access key"

4. **Save Your Credentials**:
   ```
   Access Key ID: AKIAIOSFODNN7EXAMPLE
   Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   ```

   ⚠️ **IMPORTANT**: Save these immediately! You won't be able to see the Secret Access Key again.

### Option B: Create IAM User with Programmatic Access

If you don't have an IAM user yet:

1. Go to IAM → Users → Add users
2. Username: `terraform-deployer`
3. Select: **Access key - Programmatic access**
4. Attach policies:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2FullAccess`
   - `AmazonVPCFullAccess`
   - `IAMFullAccess`
5. Create user and save access keys

---

## 🛠️ Step 2: Configure AWS CLI

### Configure credentials:

```powershell
# Interactive configuration
aws configure

# You'll be prompted for:
AWS Access Key ID: [paste your access key]
AWS Secret Access Key: [paste your secret key]
Default region name: us-west-2
Default output format: json
```

### Verify configuration:

```powershell
# Check AWS identity
aws sts get-caller-identity

# Should return something like:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/terraform-deployer"
# }
```

---

## 🚀 Step 3: Deploy EKS Cluster

### Initialize Terraform:

```powershell
cd terraform/eks

# Download required providers
terraform init
```

### Review the plan:

```powershell
# See what will be created
terraform plan

# You should see:
# - VPC with 2 availability zones
# - EKS cluster
# - 2 worker nodes (t3.medium Spot instances)
# - AWS Load Balancer Controller
# - EBS CSI Driver
# - Storage classes
```

### Deploy the cluster:

```powershell
# Deploy everything (takes ~15-20 minutes)
terraform apply

# Type 'yes' when prompted
```

**☕ Take a break! This takes 15-20 minutes.**

---

## 📝 Step 4: Configure kubectl

After Terraform completes, configure kubectl to access your cluster:

```powershell
# Update kubeconfig (output from terraform)
aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks --profile default

# Verify connection
kubectl get nodes

# You should see 2 nodes:
# NAME                                       STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xx.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-2-xx.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
```

---

## 📦 Step 5: Deploy Application

### Update Helm values for EKS:

The application needs a few tweaks for AWS:

```powershell
cd ../../helm/microservices-app

# Create EKS-specific values file
cp values-dev.yaml values-eks.yaml
```

Edit `values-eks.yaml`:

```yaml
# Change ingress class from nginx to alb
ingress:
  enabled: true
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
  host: "" # Leave empty, we'll use ALB DNS

# Use AWS EBS storage
postgresql:
  persistence:
    storageClass: "ebs-gp3"

# Increase resources slightly for production
backend:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
```

### Deploy via Helm:

```powershell
# Install the application
helm install sha-blog . \
  --namespace sha-dev \
  --create-namespace \
  --values values-eks.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment --all -n sha-dev
```

### Get Load Balancer URL:

```powershell
# Wait for ALB to be provisioned (2-3 minutes)
kubectl get ingress -n sha-dev

# Output will show:
# NAME                     CLASS   HOSTS   ADDRESS                                              PORTS   AGE
# sha-blog-dev-ingress     alb     *       k8s-shadev-xxxxx-xxxxxxxxxx.us-west-2.elb.amazonaws.com   80      2m

# Copy the ADDRESS and access it in your browser:
# http://k8s-shadev-xxxxx-xxxxxxxxxx.us-west-2.elb.amazonaws.com
```

---

## 💸 Step 6: Manage Costs - Shutdown When Not Needed

### Shutdown cluster (saves ~$50-60/month):

```powershell
cd ../../terraform/eks

# Scales nodes to 0
.\shutdown-cluster.ps1
```

**What happens:**
- Worker nodes are terminated
- Control plane stays running (required to startup again)
- NAT Gateway stays running
- **Savings**: ~$50-60/month

### Startup cluster:

```powershell
# Scales nodes back to 2
.\startup-cluster.ps1

# Wait 3-5 minutes for nodes to be ready
```

### Completely destroy cluster (saves 100%):

```powershell
# WARNING: This deletes everything!
terraform destroy

# Type 'yes' to confirm

# This removes:
# - All worker nodes
# - EKS control plane
# - VPC and networking
# - Load balancers
# - Everything deployed by Terraform
```

**⚠️ Important**: Before destroying, make sure to backup any data in PostgreSQL!

---

## 🔍 Troubleshooting

### Issue: Terraform apply fails with "UnauthorizedOperation"

**Solution**: Your IAM user needs more permissions. Add these policies:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2FullAccess`
- `AmazonVPCFullAccess`
- `IAMFullAccess`

### Issue: kubectl can't connect to cluster

**Solution**: Update kubeconfig again:
```powershell
aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks
```

### Issue: Nodes not joining the cluster

**Solution**: Check node group status:
```powershell
aws eks describe-nodegroup \
  --cluster-name sha-blog-eks \
  --nodegroup-name sha-blog-eks-general \
  --region us-west-2
```

### Issue: Load Balancer not created

**Solution**: Check AWS Load Balancer Controller logs:
```powershell
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Issue: Spot instances terminated unexpectedly

**Solution**: This is normal for Spot instances. The cluster will automatically replace them. For production, set `use_spot_instances = false` in `variables.tf`.

---

## 📊 Monitoring Costs

### View current costs:

1. Go to **AWS Cost Explorer**: https://console.aws.amazon.com/cost-management/home
2. Select "Cost Explorer"
3. Filter by:
   - Service: "Elastic Kubernetes Service", "EC2", "VPC"
   - Tag: "Project: SHA-K8s-Blog"

### Set up billing alerts:

1. Go to **AWS Budgets**: https://console.aws.amazon.com/billing/home#/budgets
2. Create budget:
   - Budget type: Cost budget
   - Amount: $200/month (adjust as needed)
   - Alert threshold: 80% ($160)
   - Email notifications

---

## 🎯 Cost Optimization Tips

1. **Use Shutdown Scripts**: Always shutdown when not using (~$50-60/month savings)

2. **Use Spot Instances**: Already configured (70% savings vs On-Demand)

3. **Right-size Nodes**: Monitor usage and adjust instance types:
   ```powershell
   # Check current usage
   kubectl top nodes

   # If usage is low, consider smaller instances:
   # Edit variables.tf → node_instance_types = ["t3.small"]
   ```

4. **Delete Unused Load Balancers**: Check periodically:
   ```powershell
   aws elbv2 describe-load-balancers --region us-west-2
   ```

5. **Use gp3 instead of gp2**: Already configured (20% cheaper)

6. **Disable Cluster Logging in Dev**: Already configured
   - Enable only for production debugging

7. **Use Single NAT Gateway**: Already configured (saves $32/month per AZ)

8. **Schedule Shutdown**: Use AWS Lambda to automatically shutdown nights/weekends

9. **Clean Up Regularly**:
   ```powershell
   # List all PVCs (they cost money!)
   kubectl get pvc --all-namespaces

   # Delete unused PVCs
   kubectl delete pvc <pvc-name> -n <namespace>
   ```

10. **Monitor Reserved Instance Opportunities**: If running 24/7, consider Reserved Instances (40-60% savings)

---

## 📈 Scaling

### Scale nodes manually:

```powershell
# Scale up
.\startup-cluster.ps1 -DesiredNodes 3

# Scale down
.\shutdown-cluster.ps1
```

### Enable auto-scaling:

Auto-scaling is already enabled! The Cluster Autoscaler will:
- Scale up when pods can't be scheduled
- Scale down when nodes are underutilized

```powershell
# Check autoscaler status
kubectl logs -n kube-system deployment/cluster-autoscaler
```

---

## 🔒 Security Best Practices

1. **Rotate Access Keys Regularly**: Every 90 days
   ```powershell
   aws iam create-access-key --user-name terraform-deployer
   ```

2. **Enable MFA**: On your AWS root and IAM accounts

3. **Use IAM Roles**: Instead of access keys when possible

4. **Enable EKS Audit Logging**: For production
   ```hcl
   # In variables.tf
   enable_cluster_logging = true
   ```

5. **Network Security**: Network policies are already configured via Calico

6. **Secrets Management**: Use AWS Secrets Manager or Vault (already configured)

---

## 📚 Additional Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **AWS Pricing Calculator**: https://calculator.aws/
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws

---

## 🆘 Support

If you encounter issues:

1. Check Terraform state: `terraform show`
2. Check AWS CloudWatch logs
3. Review this guide's troubleshooting section
4. Check [main project README](../../README.md)

---

**Built with ❤️ for AWS EKS deployment**

*Cost-optimized, production-ready Kubernetes on AWS*
