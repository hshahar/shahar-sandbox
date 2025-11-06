# Documentation Directory

This directory contains detailed technical documentation for the SHA Kubernetes Blog Platform.

## 📚 Documents in This Directory

### Infrastructure & Operations

1. **[TERRAFORM_S3_BACKEND.md](TERRAFORM_S3_BACKEND.md)** - Remote state management
   - S3 bucket setup for Terraform state
   - State locking with DynamoDB
   - Team collaboration with remote state
   - Migration from local to remote state

2. **[KEDA_AUTOSCALING.md](KEDA_AUTOSCALING.md)** - Event-driven autoscaling
   - KEDA installation and configuration
   - CPU-based scaling
   - Prometheus metrics scaling
   - Cron-based scaling
   - Queue-based scaling (RabbitMQ, AWS SQS)

3. **[MONITORING_ACCESS.md](MONITORING_ACCESS.md)** - Monitoring stack access
   - Grafana dashboard access and credentials
   - Prometheus access
   - ArgoCD UI access
   - Vault UI access
   - Service URLs and ports

### Security

4. **[SECURITY.md](SECURITY.md)** - Complete security implementation
   - Network security with Calico and NetworkPolicies
   - Pod Security Admission (PSA)
   - Vault secrets management
   - Kyverno policy enforcement
   - Container security best practices
   - Supply chain security (Cosign, SBOM)

5. **[VAULT_GUIDE.md](VAULT_GUIDE.md)** - HashiCorp Vault guide
   - Vault installation (dev and HA modes)
   - Vault unsealing and initialization
   - External Secrets Operator integration
   - Dynamic secrets
   - Secret rotation
   - Kubernetes authentication

### GitOps & Deployment

6. **[ARGOCD_SETUP.md](ARGOCD_SETUP.md)** - ArgoCD installation and setup
   - ArgoCD installation via Terraform/Helm
   - App-of-Apps pattern
   - Project and application configuration
   - Sync policies (auto-sync, manual, self-heal)
   - RBAC configuration
   - CLI usage

7. **[GITOPS_WORKFLOW.md](GITOPS_WORKFLOW.md)** - GitOps development workflow
   - Branch strategy (develop → staging → main)
   - Environment promotion workflow
   - Pull request process
   - Rollback procedures
   - Best practices

8. **[CI_CD_PIPELINE.md](CI_CD_PIPELINE.md)** - Golden CI/CD pipeline
   - GitHub Actions workflow
   - Multi-stage pipeline (lint, test, build, scan, sign, deploy)
   - Trivy vulnerability scanning
   - Cosign image signing (keyless)
   - Syft SBOM generation
   - Kyverno policy validation
   - Automated Helm values updates

9. **[PROGRESSIVE_DELIVERY.md](PROGRESSIVE_DELIVERY.md)** - Canary deployments
   - Argo Rollouts installation
   - Rollout strategies (canary, blue-green)
   - Automated analysis (success rate, latency, resources)
   - Automated rollback
   - Integration with Prometheus

10. **[APPLICATION_DEPLOYMENT.md](APPLICATION_DEPLOYMENT.md)** - Application deployment guide
    - Building Docker images
    - Pushing to container registry
    - Deploying with Helm
    - Deploying with ArgoCD
    - Testing deployments

## 🎯 Quick Navigation by Topic

### Getting Started
- Start with [ARGOCD_SETUP.md](ARGOCD_SETUP.md) for GitOps
- Then read [GITOPS_WORKFLOW.md](GITOPS_WORKFLOW.md) for workflows
- Finally check [APPLICATION_DEPLOYMENT.md](APPLICATION_DEPLOYMENT.md) for deployments

### Security Setup
- Begin with [SECURITY.md](SECURITY.md) for overview
- Then configure [VAULT_GUIDE.md](VAULT_GUIDE.md) for secrets

### Monitoring & Scaling
- Start with [MONITORING_ACCESS.md](MONITORING_ACCESS.md) for dashboards
- Then configure [KEDA_AUTOSCALING.md](KEDA_AUTOSCALING.md) for scaling

### Advanced Features
- [PROGRESSIVE_DELIVERY.md](PROGRESSIVE_DELIVERY.md) for canary deployments
- [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md) for automation

### Team Collaboration
- [TERRAFORM_S3_BACKEND.md](TERRAFORM_S3_BACKEND.md) for shared state

## 📖 Related Documentation

**Root Directory Documents:**
- [../README.md](../README.md) - Project overview
- [../GETTING_STARTED.md](../GETTING_STARTED.md) - Quick start guide
- [../ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - Common issues
- [../CHEATSHEET.md](../CHEATSHEET.md) - Command reference

**Complete Index:**
- [../DOCUMENTATION_INDEX.md](../DOCUMENTATION_INDEX.md) - Master documentation index

## 🔗 External Resources

### Official Documentation
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [KEDA Documentation](https://keda.sh/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs/)
- [Calico Documentation](https://docs.tigera.io/calico/)
- [Kyverno Documentation](https://kyverno.io/docs/)

### Tools & Utilities
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [GitOps Principles](https://opengitops.dev/)

## 📊 Documentation Metrics

| Category | Documents | Total Pages |
|----------|-----------|-------------|
| Infrastructure | 3 | ~45 pages |
| Security | 2 | ~40 pages |
| GitOps & Deployment | 5 | ~85 pages |
| **Total** | **10** | **~170 pages** |

## 🤝 Contributing to Documentation

When adding or updating documentation:

1. Follow the existing structure and format
2. Include practical examples and commands
3. Add troubleshooting sections
4. Update this README with new documents
5. Update [../DOCUMENTATION_INDEX.md](../DOCUMENTATION_INDEX.md)

## 📞 Need Help?

- **Quick Questions:** Check [../CHEATSHEET.md](../CHEATSHEET.md)
- **Problems:** See [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- **Architecture:** Review [../ARCHITECTURE.md](../ARCHITECTURE.md)
- **Complete Index:** [../DOCUMENTATION_INDEX.md](../DOCUMENTATION_INDEX.md)

---

**Last Updated:** 2025-01-06
**Maintained By:** Platform Engineering Team
