# Setup S3 Backend for Terraform State
# 
# This script automates the creation of AWS S3 bucket and DynamoDB table
# required for Terraform remote state management.
#
# Usage: .\setup-s3-backend.ps1 -BucketName "sha-k8s-terraform-state" -Region "us-east-1"

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$DynamoDBTableName = "sha-k8s-terraform-locks",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipConfirmation
)

# Check if AWS CLI is installed
Write-Host "Checking AWS CLI installation..." -ForegroundColor Cyan
try {
    $awsVersion = aws --version 2>&1
    Write-Host "✓ AWS CLI found: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "  winget install Amazon.AWSCLI" -ForegroundColor Yellow
    exit 1
}

# Check AWS credentials
Write-Host "`nChecking AWS credentials..." -ForegroundColor Cyan
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "✓ AWS credentials configured" -ForegroundColor Green
    Write-Host "  Account: $($identity.Account)" -ForegroundColor Gray
    Write-Host "  User: $($identity.Arn)" -ForegroundColor Gray
} catch {
    Write-Host "✗ AWS credentials not configured. Run:" -ForegroundColor Red
    Write-Host "  aws configure" -ForegroundColor Yellow
    exit 1
}

# Confirm setup
if (-not $SkipConfirmation) {
    Write-Host "`nThis script will create the following AWS resources:" -ForegroundColor Cyan
    Write-Host "  • S3 Bucket: $BucketName" -ForegroundColor White
    Write-Host "  • DynamoDB Table: $DynamoDBTableName" -ForegroundColor White
    Write-Host "  • Region: $Region" -ForegroundColor White
    Write-Host "`nEstimated cost: < $2/month for small projects" -ForegroundColor Yellow
    
    $confirm = Read-Host "`nDo you want to continue? (y/n)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Creating S3 Backend Infrastructure" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Create S3 Bucket
Write-Host "[1/6] Creating S3 bucket: $BucketName..." -ForegroundColor Cyan
try {
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $BucketName --region $Region 2>&1 | Out-Null
    } else {
        aws s3api create-bucket --bucket $BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region 2>&1 | Out-Null
    }
    Write-Host "✓ S3 bucket created successfully" -ForegroundColor Green
} catch {
    if ($_ -match "BucketAlreadyOwnedByYou") {
        Write-Host "✓ S3 bucket already exists (owned by you)" -ForegroundColor Green
    } elseif ($_ -match "BucketAlreadyExists") {
        Write-Host "✗ Bucket name already taken by another account" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✗ Failed to create S3 bucket: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Enable Versioning
Write-Host "[2/6] Enabling S3 versioning..." -ForegroundColor Cyan
try {
    aws s3api put-bucket-versioning `
        --bucket $BucketName `
        --versioning-configuration Status=Enabled 2>&1 | Out-Null
    Write-Host "✓ S3 versioning enabled" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to enable versioning: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Enable Encryption
Write-Host "[3/6] Enabling server-side encryption..." -ForegroundColor Cyan
try {
    $encryptionConfig = @"
{
  "Rules": [{
    "ApplyServerSideEncryptionByDefault": {
      "SSEAlgorithm": "AES256"
    },
    "BucketKeyEnabled": true
  }]
}
"@
    $encryptionConfig | Out-File -FilePath "encryption-config.json" -Encoding UTF8
    aws s3api put-bucket-encryption `
        --bucket $BucketName `
        --server-side-encryption-configuration file://encryption-config.json 2>&1 | Out-Null
    Remove-Item "encryption-config.json" -Force
    Write-Host "✓ Server-side encryption enabled" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to enable encryption: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Block Public Access
Write-Host "[4/6] Blocking public access..." -ForegroundColor Cyan
try {
    aws s3api put-public-access-block `
        --bucket $BucketName `
        --public-access-block-configuration `
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true 2>&1 | Out-Null
    Write-Host "✓ Public access blocked" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to block public access: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Create DynamoDB Table
Write-Host "[5/6] Creating DynamoDB table: $DynamoDBTableName..." -ForegroundColor Cyan
try {
    aws dynamodb create-table `
        --table-name $DynamoDBTableName `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $Region 2>&1 | Out-Null
    Write-Host "✓ DynamoDB table created successfully" -ForegroundColor Green
} catch {
    if ($_ -match "ResourceInUseException") {
        Write-Host "✓ DynamoDB table already exists" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create DynamoDB table: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 6: Wait for table to become active
Write-Host "[6/6] Waiting for DynamoDB table to become active..." -ForegroundColor Cyan
$maxWait = 60
$waited = 0
while ($waited -lt $maxWait) {
    try {
        $tableStatus = aws dynamodb describe-table --table-name $DynamoDBTableName --region $Region --query 'Table.TableStatus' --output text 2>&1
        if ($tableStatus -eq "ACTIVE") {
            Write-Host "✓ DynamoDB table is active" -ForegroundColor Green
            break
        }
        Write-Host "  Waiting... ($waited/$maxWait seconds)" -ForegroundColor Gray
        Start-Sleep -Seconds 5
        $waited += 5
    } catch {
        Write-Host "✗ Failed to check table status: $_" -ForegroundColor Red
        exit 1
    }
}

if ($waited -ge $maxWait) {
    Write-Host "✗ Timeout waiting for table to become active" -ForegroundColor Red
    exit 1
}

# Success message
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "S3 Backend Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Resources created:" -ForegroundColor Cyan
Write-Host "  • S3 Bucket: s3://$BucketName" -ForegroundColor White
Write-Host "  • DynamoDB Table: $DynamoDBTableName" -ForegroundColor White
Write-Host "  • Region: $Region" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Copy backend configuration:" -ForegroundColor White
Write-Host "     Copy-Item backend-s3.tf.example backend-s3.tf" -ForegroundColor Gray
Write-Host "`n  2. Edit backend-s3.tf with these values:" -ForegroundColor White
Write-Host "     bucket = `"$BucketName`"" -ForegroundColor Gray
Write-Host "     region = `"$Region`"" -ForegroundColor Gray
Write-Host "     dynamodb_table = `"$DynamoDBTableName`"" -ForegroundColor Gray
Write-Host "`n  3. Backup current state:" -ForegroundColor White
Write-Host "     Copy-Item terraform.tfstate terraform.tfstate.backup" -ForegroundColor Gray
Write-Host "`n  4. Initialize with migration:" -ForegroundColor White
Write-Host "     terraform init -migrate-state" -ForegroundColor Gray
Write-Host "`n  5. Verify migration:" -ForegroundColor White
Write-Host "     aws s3 ls s3://$BucketName/" -ForegroundColor Gray
Write-Host "     terraform state list" -ForegroundColor Gray

Write-Host "`nDocumentation: docs\TERRAFORM_S3_BACKEND.md" -ForegroundColor Yellow
