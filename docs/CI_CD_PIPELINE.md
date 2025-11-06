# CI/CD Pipeline Documentation

## Overview

This project implements a **Golden CI/CD Pipeline** with enterprise-grade security, automated testing, and progressive delivery capabilities.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GOLDEN CI/CD PIPELINE                         │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Stage 1     │    │  Stage 2     │    │  Stage 3     │    │  Stage 4     │
│  Lint & Test │───▶│  Security    │───▶│  Build       │───▶│  Container   │
│              │    │  Scan        │    │  Images      │    │  Scan        │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
     │                    │                    │                    │
     │ Python/Node        │ Trivy FS           │ Docker Buildx      │ Trivy Image
     │ Unit Tests         │ Safety/npm audit   │ SBOM Generation    │ SARIF Upload
     │ Helm Lint          │ SARIF Upload       │ Multi-arch         │ Security Tab
     └────────────────────┴────────────────────┴────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Stage 5     │    │  Stage 6     │    │  Stage 7     │    │  Stage 8     │
│  Sign        │───▶│  SBOM        │───▶│  Policy      │───▶│  Deploy      │
│  Images      │    │  Generation  │    │  Check       │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
     │                    │                    │                    │
     │ Cosign             │ Syft               │ Kyverno CLI        │ Update Values
     │ Keyless signing    │ SPDX format        │ Policy validation  │ GitOps Commit
     │ Verification       │ Artifact upload    │ Compliance check   │ ArgoCD Sync
     └────────────────────┴────────────────────┴────────────────────┘
```

---

## Pipeline Stages

### Stage 1: Lint and Test

**Purpose**: Validate code quality and correctness before building artifacts.

**Actions**:
- **Python Backend**:
  - Install dependencies from `requirements.txt`
  - Run `pylint` for code quality checks
  - Execute `pytest` with coverage reporting
  
- **Node.js Frontend**:
  - Install dependencies via `npm ci`
  - Run ESLint for JavaScript/TypeScript linting
  - Build production bundle with Vite
  
- **Helm Charts**:
  - Lint all Helm charts
  - Validate with environment-specific values
  - Test template generation

**Success Criteria**: All tests pass, no critical lint errors, Helm charts valid.

---

### Stage 2: Security Scanning (SCA)

**Purpose**: Identify vulnerabilities in source code and dependencies.

**Tools**:
- **Trivy**: Filesystem scanning for code vulnerabilities
- **Safety**: Python dependency security checks
- **npm audit**: Node.js dependency vulnerabilities

**Actions**:
```yaml
- Scan entire repository filesystem
- Generate SARIF reports for GitHub Security tab
- Check Python packages against vulnerability database
- Audit npm packages for known CVEs
```

**Outputs**: SARIF files uploaded to GitHub Security, visible in Security tab.

---

### Stage 3: Build Docker Images

**Purpose**: Create optimized, multi-architecture container images.

**Features**:
- **Docker Buildx**: Multi-platform builds (linux/amd64, linux/arm64)
- **Layer Caching**: GitHub Actions cache for faster builds
- **Provenance**: Attach build provenance metadata
- **SBOM**: Automatically generate Software Bill of Materials
- **Tagging Strategy**: `{branch}-{short-sha}` + `latest`

**Images Built**:
```
ghcr.io/{org}/{repo}/backend:{tag}
ghcr.io/{org}/{repo}/frontend:{tag}
```

**Outputs**: Image digests for signing, pushed to GitHub Container Registry.

---

### Stage 4: Container Image Scanning

**Purpose**: Scan built container images for vulnerabilities.

**Tool**: Trivy

**Actions**:
```bash
# Scan backend image
trivy image --severity CRITICAL,HIGH \
  ghcr.io/{org}/{repo}/backend:{tag}

# Scan frontend image
trivy image --severity CRITICAL,HIGH \
  ghcr.io/{org}/{repo}/frontend:{tag}
```

**Outputs**: 
- SARIF reports uploaded to GitHub Security
- Separate categories for backend and frontend
- Vulnerability alerts in Security tab

---

### Stage 5: Image Signing with Cosign

**Purpose**: Cryptographically sign container images for supply chain security.

**Tool**: Sigstore Cosign

**Method**: Keyless signing using GitHub OIDC tokens

**Actions**:
```bash
# Sign images using GitHub's identity
cosign sign --yes ghcr.io/{org}/{repo}/backend@{digest}
cosign sign --yes ghcr.io/{org}/{repo}/frontend@{digest}

# Verify signatures
cosign verify \
  --certificate-identity-regexp='https://github.com/{org}/{repo}' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/{org}/{repo}/backend@{digest}
```

**Benefits**:
- Verifiable image provenance
- Supply chain attack prevention
- Compliance with SLSA Level 2+
- No secret management (keyless)

---

### Stage 6: SBOM Generation

**Purpose**: Generate Software Bill of Materials for dependency tracking.

**Tool**: Syft (Anchore)

**Format**: SPDX JSON

**Actions**:
```bash
# Generate SBOM for each image
syft ghcr.io/{org}/{repo}/backend:{tag} \
  -o spdx-json=backend-sbom.spdx.json

syft ghcr.io/{org}/{repo}/frontend:{tag} \
  -o spdx-json=frontend-sbom.spdx.json
```

**Outputs**: 
- SBOM artifacts stored for 90 days
- Complete dependency inventory
- License compliance tracking

---

### Stage 7: Policy Validation

**Purpose**: Enforce security and compliance policies before deployment.

**Tool**: Kyverno CLI

**Policies Checked**:
- Image signature verification
- Security context requirements
- Resource limits defined
- Non-root user enforcement
- Read-only root filesystem
- Network policy enforcement

**Actions**:
```bash
# Generate Kubernetes manifests
helm template k8s-blog ./helm/microservices-app \
  --values values-{env}.yaml \
  > manifests.yaml

# Run policy checks
kyverno apply ./templates/kyverno-policies.yaml \
  --resource manifests.yaml
```

**Failure Behavior**: Pipeline stops if policies violated.

---

### Stage 8: Update Manifests and Deploy

**Purpose**: Update Helm values with new image tags and trigger GitOps deployment.

**GitOps Flow**:
```
1. Determine environment from branch (develop→dev, staging→staging, main→prod)
2. Update image tags in values-{env}.yaml
3. Commit changes with [skip ci] to avoid loop
4. Push to repository
5. ArgoCD detects changes and syncs
```

**Commit Message Format**:
```
chore: update image tags to {branch}-{sha} [skip ci]
```

**ArgoCD Behavior**:
- **Dev**: Auto-sync enabled (immediate deployment)
- **Staging**: Auto-sync enabled (immediate deployment)
- **Production**: Manual sync required (via promotion workflow)

---

## Branch Strategy

```
┌─────────────┐
│   develop   │  →  Dev Environment (auto-deploy)
└─────────────┘
       │
       │ PR + Review
       ▼
┌─────────────┐
│   staging   │  →  Staging Environment (auto-deploy)
└─────────────┘
       │
       │ PR + Approval
       ▼
┌─────────────┐
│    main     │  →  Production Environment (manual promote)
└─────────────┘
```

### Branch Protection Rules

#### `develop` Branch
- ✅ Require pull request reviews: 1
- ✅ Require status checks to pass: lint-and-test, security-scan
- ✅ Require branches to be up to date
- ❌ Include administrators: No

#### `staging` Branch
- ✅ Require pull request reviews: 2
- ✅ Require status checks to pass: All stages up to policy-check
- ✅ Require branches to be up to date
- ✅ Dismiss stale reviews
- ❌ Include administrators: No

#### `main` Branch
- ✅ Require pull request reviews: 2
- ✅ Require review from code owners
- ✅ Require status checks to pass: All stages
- ✅ Require signed commits
- ✅ Require linear history
- ✅ Include administrators: Yes

---

## Environment Promotion Workflow

### Manual Promotion Process

For controlled deployments to staging/production:

```bash
# Navigate to Actions → Environment Promotion → Run workflow

# Inputs:
Source Environment: dev | staging
Target Environment: staging | prod
Image Tag: develop-abc1234
```

### Promotion Flow

```
┌────────────────────┐
│ Validate Promotion │  →  Ensure valid path (dev→staging, staging→prod)
└────────────────────┘
         │
         ▼
┌────────────────────┐
│ Request Approval   │  →  Manual approval via GitHub Environments
└────────────────────┘
         │
         ▼
┌────────────────────┐
│ Run Tests          │  →  Health checks, smoke tests, performance
└────────────────────┘
         │
         ▼
┌────────────────────┐
│ Promote            │  →  Update values-{env}.yaml, commit, tag
└────────────────────┘
         │
         ▼
┌────────────────────┐
│ Notify             │  →  Success/failure notifications
└────────────────────┘
```

### Setting Up Approvers

1. Go to **Settings** → **Environments**
2. Create environments: `staging`, `prod`
3. Add **Required reviewers** for each
4. Configure **Wait timer** if needed (e.g., 5 minutes)

---

## Security Features

### 🔒 Supply Chain Security

| Feature | Implementation | Purpose |
|---------|---------------|---------|
| **Image Signing** | Cosign with keyless signing | Verify image authenticity |
| **SBOM** | Syft generating SPDX format | Dependency transparency |
| **Vulnerability Scanning** | Trivy (filesystem + images) | Identify CVEs |
| **Policy Enforcement** | Kyverno CLI validation | Compliance checks |
| **Provenance** | Docker Buildx attestations | Build metadata |

### 🛡️ Runtime Security

Enforced via Kyverno policies:
- All images must be signed
- Containers run as non-root
- Read-only root filesystem
- Capabilities dropped
- Seccomp profiles applied
- Network policies enforced

---

## Monitoring and Observability

### Pipeline Metrics

Track these metrics for pipeline health:

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Pipeline Success Rate | > 95% | < 90% |
| Average Build Time | < 10 min | > 15 min |
| Security Scan Failures | 0 | > 0 critical |
| Policy Violations | 0 | > 0 |

### GitHub Actions Insights

View metrics at: **Insights** → **Actions**
- Workflow runs over time
- Success rate by workflow
- Billable time usage

---

## Troubleshooting

### Common Issues

#### ❌ Image Signing Fails

**Error**: `cosign sign: permission denied`

**Solution**: Ensure `id-token: write` permission in workflow:
```yaml
permissions:
  id-token: write
  packages: write
```

#### ❌ SBOM Generation Times Out

**Error**: `Syft failed to complete within timeout`

**Solution**: Increase timeout or use cache:
```yaml
- name: Generate SBOM
  timeout-minutes: 10
```

#### ❌ Kyverno Policy Check Fails

**Error**: `Policy violation: require-non-root-user`

**Solution**: Update Deployment to include `securityContext`:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

#### ❌ ArgoCD Not Syncing

**Error**: Manifests updated but no deployment

**Solution**: 
1. Check ArgoCD sync policy
2. Verify branch matches source
3. Manual sync: `.\scripts\sync-app.ps1 -Environment dev`

---

## Best Practices

### 1. Small, Frequent Commits

✅ **DO**: Commit and test frequently
❌ **DON'T**: Batch many changes into one PR

### 2. Test Before Merging

✅ **DO**: Wait for all checks to pass
❌ **DON'T**: Force merge failing builds

### 3. Use Semantic Commit Messages

```
feat: add user authentication endpoint
fix: resolve database connection timeout
docs: update API documentation
chore: update dependencies
```

### 4. Review Security Scan Results

Before merging, review:
- Trivy scan results in Security tab
- npm audit / Safety warnings
- Policy check failures

### 5. Monitor Deployments

After promotion:
- Check ArgoCD dashboard
- Verify Grafana metrics
- Monitor Argo Rollouts progress (staging/prod)

---

## Advanced Configuration

### Custom Security Policies

Add custom Kyverno policies in `helm/microservices-app/templates/kyverno-policies.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: custom-policy
spec:
  validationFailureAction: enforce
  rules:
  - name: my-custom-rule
    match:
      resources:
        kinds:
        - Deployment
    validate:
      message: "Custom validation message"
      pattern:
        spec:
          template:
            metadata:
              labels:
                custom-label: "required-value"
```

### Custom SBOM Formats

Generate additional SBOM formats:

```bash
# CycloneDX JSON
syft image -o cyclonedx-json=sbom.cyclonedx.json

# SPDX Tag-Value
syft image -o spdx-tag-value=sbom.spdx
```

### Notification Integration

Add Slack/Teams notifications to workflows:

```yaml
- name: Notify on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Pipeline failed: ${{ github.workflow }}"
      }
```

---

## Additional Resources

- **Sigstore Cosign**: https://docs.sigstore.dev/cosign/overview/
- **Trivy Documentation**: https://aquasecurity.github.io/trivy/
- **Syft SBOM Tool**: https://github.com/anchore/syft
- **Kyverno Policies**: https://kyverno.io/policies/
- **GitHub Actions**: https://docs.github.com/en/actions

---

**Next Steps**: See [PROGRESSIVE_DELIVERY.md](./PROGRESSIVE_DELIVERY.md) for Canary deployment strategies.
