# Remote State Management with S3

## Overview

This project supports storing Terraform state in AWS S3 with DynamoDB locking for team collaboration and enhanced state protection. By default, state is stored locally in `terraform.tfstate`.

## Why Use Remote State?

**Benefits:**
- **Team Collaboration**: Multiple team members can work on infrastructure
- **State Locking**: Prevents concurrent modifications and corruption
- **Versioning**: S3 versioning enables state recovery
- **Encryption**: State is encrypted at rest
- **Backup**: Automatic state backup with S3 versioning
- **Audit Trail**: Track who made changes and when

**When to Use:**
- ✅ Multi-person teams
- ✅ CI/CD pipelines
- ✅ Production environments
- ✅ Cross-region deployments
- ❌ Local development (single developer)

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Terraform v1.0 or later

## Quick Setup

### 1. Install AWS CLI (if not already installed)

**Windows (PowerShell):**
```powershell
winget install Amazon.AWSCLI
```

**Verify installation:**
```powershell
aws --version
```

### 2. Configure AWS Credentials

```powershell
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

**Test credentials:**
```powershell
aws sts get-caller-identity
```

### 3. Create S3 Bucket and DynamoDB Table

**Option A: Use the provided script:**
```powershell
cd C:\Users\ILPETSHHA.old\dev\testshahar\terraform
.\scripts\setup-s3-backend.ps1 -BucketName "sha-k8s-terraform-state" -Region "us-east-1"
```

**Option B: Manual setup:**
```powershell
# Create S3 bucket
aws s3api create-bucket `
  --bucket sha-k8s-terraform-state `
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket sha-k8s-terraform-state `
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption `
  --bucket sha-k8s-terraform-state `
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block `
  --bucket sha-k8s-terraform-state `
  --public-access-block-configuration `
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table
aws dynamodb create-table `
  --table-name sha-k8s-terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region us-east-1
```

### 4. Configure Terraform Backend

```powershell
# Copy the example backend configuration
Copy-Item backend-s3.tf.example backend-s3.tf

# Edit backend-s3.tf with your values:
# - bucket name
# - region
# - DynamoDB table name
```

Edit `backend-s3.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "sha-k8s-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "sha-k8s-terraform-locks"
    encrypt        = true
  }
}
```

### 5. Migrate State to S3

```powershell
# Backup current state
Copy-Item terraform.tfstate terraform.tfstate.backup

# Initialize with migration
terraform init -migrate-state

# Confirm migration when prompted

# Verify state is in S3
aws s3 ls s3://sha-k8s-terraform-state/dev/
terraform state list
```

## Environment-Specific Configuration

### Using Different State Files per Environment

Edit `backend-s3.tf` for each environment:

**Development:**
```hcl
key = "dev/terraform.tfstate"
```

**Staging:**
```hcl
key = "staging/terraform.tfstate"
```

**Production:**
```hcl
key = "prod/terraform.tfstate"
```

### Using Terraform Workspaces

Alternative approach using workspaces:

```powershell
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch between environments
terraform workspace select dev
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"

terraform workspace select staging
terraform plan -var-file="environments/staging.tfvars"
```

## IAM Configuration

### Minimal IAM Policy for Terraform

Create an IAM user or role with this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::sha-k8s-terraform-state"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::sha-k8s-terraform-state/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/sha-k8s-terraform-locks"
    }
  ]
}
```

### Using IAM Roles (Recommended for EC2/ECS)

If running Terraform from AWS EC2 or ECS:

```hcl
terraform {
  backend "s3" {
    bucket         = "sha-k8s-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "sha-k8s-terraform-locks"
    encrypt        = true
    role_arn       = "arn:aws:iam::ACCOUNT_ID:role/TerraformRole"
  }
}
```

## Operations

### View Current State

```powershell
# List all resources in state
terraform state list

# Show specific resource
terraform state show kubernetes_namespace.dev
```

### Download State from S3

```powershell
# Download current state
aws s3 cp s3://sha-k8s-terraform-state/dev/terraform.tfstate ./state-backup.json

# List all state versions
aws s3api list-object-versions `
  --bucket sha-k8s-terraform-state `
  --prefix dev/terraform.tfstate
```

### Recover Previous State Version

```powershell
# List versions
aws s3api list-object-versions `
  --bucket sha-k8s-terraform-state `
  --prefix dev/terraform.tfstate `
  --query 'Versions[*].[VersionId,LastModified]' `
  --output table

# Download specific version
aws s3api get-object `
  --bucket sha-k8s-terraform-state `
  --key dev/terraform.tfstate `
  --version-id VERSION_ID `
  state-recovered.json

# Copy back to S3
aws s3 cp state-recovered.json s3://sha-k8s-terraform-state/dev/terraform.tfstate
```

### Force Unlock State

If state is locked due to a failed operation:

```powershell
# Get lock ID from error message
terraform force-unlock LOCK_ID
```

Or manually remove from DynamoDB:

```powershell
# Scan for locks
aws dynamodb scan --table-name sha-k8s-terraform-locks

# Delete specific lock
aws dynamodb delete-item `
  --table-name sha-k8s-terraform-locks `
  --key '{\"LockID\":{\"S\":\"sha-k8s-terraform-state/dev/terraform.tfstate\"}}'
```

## Troubleshooting

### Error: "Access Denied"

**Problem:** AWS credentials don't have permission

**Solution:**
```powershell
# Check current identity
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://sha-k8s-terraform-state/

# Test DynamoDB access
aws dynamodb describe-table --table-name sha-k8s-terraform-locks
```

### Error: "NoSuchBucket"

**Problem:** S3 bucket doesn't exist

**Solution:**
```powershell
aws s3api create-bucket `
  --bucket sha-k8s-terraform-state `
  --region us-east-1
```

### Error: "ResourceNotFoundException" (DynamoDB)

**Problem:** DynamoDB table doesn't exist

**Solution:**
```powershell
aws dynamodb create-table `
  --table-name sha-k8s-terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST
```

### Error: "Error acquiring the state lock"

**Problem:** Previous operation didn't release lock

**Solution:**
```powershell
# Force unlock (get LOCK_ID from error message)
terraform force-unlock LOCK_ID

# Or check DynamoDB for stale locks
aws dynamodb scan --table-name sha-k8s-terraform-locks
```

### Migrate Back to Local State

If you need to switch back to local state:

```powershell
# Remove or rename backend configuration
Move-Item backend-s3.tf backend-s3.tf.disabled

# Reinitialize with migration
terraform init -migrate-state

# Confirm migration when prompted
```

## Cost Considerations

### S3 Costs
- **Storage**: ~$0.023 per GB/month (Standard)
- **Requests**: Minimal (PUT/GET on state changes)
- **Versioning**: Adds storage cost for old versions

**Typical monthly cost**: < $1 for small projects

### DynamoDB Costs
- **PAY_PER_REQUEST**: $0.25 per million requests
- **State locking**: 2 requests per terraform operation

**Typical monthly cost**: < $0.50 for small teams

### Cost Optimization

**Set lifecycle policy to delete old versions:**
```powershell
# Create lifecycle policy file
@"
{
  "Rules": [{
    "Id": "DeleteOldVersions",
    "Status": "Enabled",
    "NoncurrentVersionExpiration": {
      "NoncurrentDays": 90
    }
  }]
}
"@ | Out-File -FilePath lifecycle.json -Encoding UTF8

# Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration `
  --bucket sha-k8s-terraform-state `
  --lifecycle-configuration file://lifecycle.json
```

## Security Best Practices

1. **Enable MFA Delete** (prevents accidental state deletion):
   ```powershell
   aws s3api put-bucket-versioning `
     --bucket sha-k8s-terraform-state `
     --versioning-configuration Status=Enabled,MFADelete=Enabled `
     --mfa "SERIAL_NUMBER TOKEN"
   ```

2. **Enable S3 access logging**:
   ```powershell
   aws s3api put-bucket-logging `
     --bucket sha-k8s-terraform-state `
     --bucket-logging-status file://logging.json
   ```

3. **Use least privilege IAM policies** (see IAM section above)

4. **Enable CloudTrail** for audit logging

5. **Never commit AWS credentials** to Git:
   ```gitignore
   # .gitignore
   *.tfvars
   terraform.tfstate*
   .terraform/
   backend-s3.tf  # If it contains sensitive values
   ```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Apply
on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.13.5
      
      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform
      
      - name: Terraform Apply
        run: terraform apply -auto-approve -var-file="environments/dev.tfvars"
        working-directory: ./terraform
```

## Alternative Backends

### Azure Backend

See `backend-azure.tf.example` (if created) or use:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "sha-k8s-terraform-state"
    storage_account_name = "shak8sterraformstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

### Google Cloud Storage Backend

```hcl
terraform {
  backend "gcs" {
    bucket  = "sha-k8s-terraform-state"
    prefix  = "dev"
  }
}
```

## Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
