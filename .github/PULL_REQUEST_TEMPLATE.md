# Description

Please include a summary of the changes and the related issue. List any dependencies that are required for this change.

Fixes # (issue)

## Type of change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure/Configuration change
- [ ] Performance improvement
- [ ] Code refactoring

## How Has This Been Tested?

Please describe the tests that you ran to verify your changes. Provide instructions so we can reproduce.

- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing
- [ ] Load testing (if applicable)

**Test Configuration**:
* Kubernetes version:
* Environment (dev/staging/prod):
* Helm version:

## Checklist:

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings or errors
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## Kubernetes/Helm Specific:

- [ ] Helm chart changes have been tested with `helm lint`
- [ ] Kubernetes manifests are valid (`kubectl apply --dry-run`)
- [ ] Resource limits and requests are appropriately set
- [ ] SecurityContext and Pod Security Standards are properly configured
- [ ] NetworkPolicies have been updated if needed
- [ ] Monitoring/ServiceMonitors have been added/updated if needed
- [ ] Secrets handling follows security best practices

## ArgoCD/GitOps:

- [ ] Changes are compatible with GitOps workflow
- [ ] ArgoCD sync has been tested in dev environment
- [ ] Rollback procedure has been considered

## Security:

- [ ] No sensitive information (passwords, API keys) in code or commits
- [ ] Images are from trusted registries
- [ ] Vulnerability scanning passed (if images changed)
- [ ] RBAC permissions are least-privilege

## Screenshots (if applicable):

Add screenshots to help explain your changes.

## Additional context:

Add any other context about the pull request here.
