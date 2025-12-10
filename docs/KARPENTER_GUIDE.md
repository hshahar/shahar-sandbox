# Karpenter Integration

## Overview
Karpenter is a Kubernetes node autoscaler that automatically provisions right-sized nodes based on pod requirements. It replaces manual node group management and cluster autoscaler.

## Benefits
- **Cost Optimization**: Automatically uses SPOT instances with on-demand fallback
- **Right-Sizing**: Provisions nodes that exactly match pod requirements
- **Fast Scaling**: Provisions new nodes in ~2 minutes vs 5-10 minutes with cluster autoscaler
- **Intelligent Consolidation**: Removes underutilized nodes after 30 seconds
- **Workload-Specific Nodes**: Separate node pools for general and AI workloads

## Architecture

### NodePools
1. **Default Pool** (General Workloads)
   - Instance Types: t3.medium, t3.large, t3.xlarge, t3.2xlarge
   - Capacity: SPOT with on-demand fallback
   - Consolidation: 30s after empty/underutilized
   - Use Case: Backend, Frontend, PostgreSQL, monitoring

2. **AI Workloads Pool**
   - Instance Types: t3.xlarge, t3.2xlarge, m5.xlarge, m5.2xlarge
   - Capacity: On-demand (stable for long-running AI tasks)
   - Consolidation: 300s after empty
   - Use Case: AI Agent, Ollama (requires 8GB+ RAM)
   - Taint: `workload=ai:NoSchedule`

## Files Structure
```
terraform/
  └── karpenter.tf              # Karpenter Helm release + IAM roles
  
helm/
  └── karpenter-nodepool/
      └── nodepool.yaml         # NodePool and EC2NodeClass configs
  
  └── microservices-app/
      ├── values.yaml           # AI agent Karpenter config
      └── templates/
          └── aiagent-deployment.yaml  # Tolerations and nodeSelector

scripts/
  └── setup-karpenter.ps1       # Automated setup script
```

## Setup

### Prerequisites
- EKS cluster running (v1.29+)
- kubectl configured
- Terraform installed
- AWS CLI configured

### Installation
```powershell
# Run the automated setup script
.\scripts\setup-karpenter.ps1

# Or manually:
# 1. Tag resources for Karpenter discovery
aws ec2 create-tags --resources <subnet-id> --tags "Key=karpenter.sh/discovery,Value=sha-blog-eks"
aws ec2 create-tags --resources <security-group-id> --tags "Key=karpenter.sh/discovery,Value=sha-blog-eks"

# 2. Apply Terraform
cd terraform
terraform apply -var="install_karpenter=true"

# 3. Apply NodePool configuration
kubectl apply -f ../helm/karpenter-nodepool/nodepool.yaml

# 4. Delete existing node group (optional)
aws eks delete-nodegroup --cluster-name sha-blog-eks --nodegroup-name sha-blog-eks-general
```

## Configuration

### AI Agent with Karpenter
The AI agent is configured to use Karpenter AI workload nodes:

**values.yaml:**
```yaml
aiAgent:
  useKarpenter: true  # Enable Karpenter scheduling
  resources:
    limits:
      cpu: 2000m
      memory: 12Gi    # Requires xlarge+ instances
    requests:
      cpu: 1000m
      memory: 8Gi
```

**Deployment tolerations:**
```yaml
tolerations:
- key: workload
  operator: Equal
  value: ai
  effect: NoSchedule
nodeSelector:
  workload: ai
```

### Startup Probe Added
The AI agent now has a startup probe to handle slow initialization:
```yaml
startupProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 30  # 5 minutes total
```

## Monitoring

### Watch Karpenter Provisioning
```powershell
# Watch Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Watch nodes
kubectl get nodes -w

# Watch pods
kubectl get pods -A -w
```

### Check NodePool Status
```powershell
kubectl get nodepool -A
kubectl describe nodepool default
kubectl describe nodepool ai-workloads
```

### Check Provisioned Nodes
```powershell
kubectl get nodes -L karpenter.sh/capacity-type,node-type,workload
```

## Troubleshooting

### Pods Not Scheduling
```powershell
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# Check NodePool events
kubectl describe nodepool default
```

### Nodes Not Provisioning
1. Check subnet tags: `karpenter.sh/discovery=sha-blog-eks`
2. Check security group tags
3. Verify IAM role permissions
4. Check Karpenter controller logs

### AI Pods Pending
```powershell
# Verify AI NodePool exists
kubectl get nodepool ai-workloads

# Check if pod has correct tolerations
kubectl get pod <ai-pod-name> -o yaml | grep -A 5 tolerations

# Manually trigger AI node provisioning
kubectl scale deployment ollama --replicas=1 -n sha-dev
```

## Cost Optimization

### Estimated Monthly Costs (SPOT instances)
- **Default Pool (t3.medium)**: ~$9/instance/month
- **AI Pool (t3.xlarge)**: ~$36/instance/month
- **Karpenter Controller**: ~$0 (runs on existing nodes)

### Savings vs. Fixed Node Groups
- 70-90% savings from SPOT instances
- Additional 20-30% from right-sizing
- Additional 10-20% from consolidation

**Example:**
- Before: 3 x t3.xlarge on-demand = ~$150/month
- After: 2 x t3.medium SPOT + 1 x t3.xlarge SPOT = ~$54/month
- **Savings: ~$96/month (64%)**

## Migration from Node Groups

### Option 1: Gradual (Zero Downtime)
1. Install Karpenter
2. Karpenter provisions new nodes
3. Pods migrate to Karpenter nodes
4. Delete old node group

### Option 2: Quick (Brief Downtime)
1. Install Karpenter
2. Delete node group immediately
3. Karpenter provisions new nodes
4. Pods restart on new nodes

## Best Practices

1. **Always tag resources** for Karpenter discovery
2. **Use taints** for specialized workloads (GPU, AI, etc.)
3. **Set limits** on NodePools to prevent runaway costs
4. **Monitor costs** using AWS Cost Explorer
5. **Test SPOT interruptions** with chaos engineering
6. **Use on-demand** for critical workloads
7. **Consolidation** should be tuned per workload

## References
- [Karpenter Documentation](https://karpenter.sh/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Karpenter GitHub](https://github.com/aws/karpenter)
