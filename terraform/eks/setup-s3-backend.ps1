# Setup S3 Backend for Terraform State
# This script creates S3 bucket and DynamoDB table for remote state storage

param(
    [string]$BucketName = "sha-blog-terraform-state-us-west-2",
    [string]$Region = "us-west-2",
    [string]$Profile = "default"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Terraform S3 Backend Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This will create:" -ForegroundColor Yellow
Write-Host "  • S3 Bucket: $BucketName" -ForegroundColor White
Write-Host "  • DynamoDB Table: sha-blog-terraform-locks" -ForegroundColor White
Write-Host "  • Region: $Region" -ForegroundColor White
Write-Host ""

# Check if bucket name is available
Write-Host "Step 1: Checking if bucket name is available..." -ForegroundColor Green

$bucketExists = aws s3api head-bucket --bucket $BucketName --region $Region --profile $Profile 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ⚠ Bucket '$BucketName' already exists!" -ForegroundColor Yellow
    Write-Host "  Using existing bucket..." -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Bucket name is available" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 2: Creating S3 backend resources with Terraform..." -ForegroundColor Green

# Create a temporary Terraform configuration for S3 backend
$tempDir = "temp-backend-setup"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Create minimal main.tf for backend setup
@"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "$Region"
  profile = "$Profile"
}

# S3 Bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket = "$BucketName"

  tags = {
    Name    = "Terraform State"
    Purpose = "Store Terraform state files"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "sha-blog-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "Terraform State Locks"
    Purpose = "Prevent concurrent Terraform runs"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table" {
  value = aws_dynamodb_table.terraform_locks.id
}
"@ | Out-File -FilePath "$tempDir\main.tf" -Encoding UTF8

# Initialize and apply
Push-Location $tempDir

Write-Host "  Initializing Terraform..." -ForegroundColor Cyan
terraform init

Write-Host "  Creating resources..." -ForegroundColor Cyan
terraform apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ S3 backend resources created successfully!" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create S3 backend resources" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "Step 3: Creating backend configuration file..." -ForegroundColor Green

# Create backend.tf file in main terraform directory
$backendConfig = @"
# Terraform S3 Backend Configuration
# This stores Terraform state in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "$BucketName"
    key            = "eks/terraform.tfstate"
    region         = "$Region"
    encrypt        = true
    dynamodb_table = "sha-blog-terraform-locks"
    profile        = "$Profile"
  }
}
"@

$backendConfig | Out-File -FilePath "backend.tf" -Encoding UTF8

Write-Host "  ✓ Created backend.tf" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "S3 Backend Setup Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resources Created:" -ForegroundColor Yellow
Write-Host "  • S3 Bucket: $BucketName" -ForegroundColor White
Write-Host "  • DynamoDB Table: sha-blog-terraform-locks" -ForegroundColor White
Write-Host "  • Backend Config: backend.tf" -ForegroundColor White
Write-Host ""
Write-Host "Monthly Costs:" -ForegroundColor Yellow
Write-Host "  • S3 Storage: ~`$0.023/GB (~`$0.50/month for state files)" -ForegroundColor White
Write-Host "  • DynamoDB: ~`$0.25/million requests (~`$0.10/month)" -ForegroundColor White
Write-Host "  • Total: ~`$0.60/month" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Migrate existing state to S3:" -ForegroundColor White
Write-Host "     terraform init -migrate-state" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Verify state is in S3:" -ForegroundColor White
Write-Host "     aws s3 ls s3://$BucketName/eks/" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Check DynamoDB locks (during apply):" -ForegroundColor White
Write-Host "     aws dynamodb scan --table-name sha-blog-terraform-locks" -ForegroundColor Gray
Write-Host ""
Write-Host "Benefits of S3 Backend:" -ForegroundColor Cyan
Write-Host "  ✓ Team collaboration - shared state" -ForegroundColor Green
Write-Host "  ✓ State locking - prevents conflicts" -ForegroundColor Green
Write-Host "  ✓ Versioning - rollback capability" -ForegroundColor Green
Write-Host "  ✓ Encryption - secure storage" -ForegroundColor Green
Write-Host ""

# Cleanup temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
