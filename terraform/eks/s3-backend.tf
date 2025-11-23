# S3 Backend for Terraform State Storage
# This creates S3 bucket for storing Terraform state remotely
# Includes versioning, encryption, and DynamoDB for state locking

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true in production!
  }

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "Store Terraform state files"
    Environment = var.environment
  }
}

# Enable Versioning (required for state rollback)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access (security best practice)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Bucket Lifecycle (delete old versions after 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# DynamoDB Table for State Locking (prevents concurrent modifications)
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = var.terraform_state_lock_table_name
  billing_mode   = "PAY_PER_REQUEST" # COST OPTIMIZATION: Pay only for what you use
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Purpose     = "Prevent concurrent Terraform runs"
    Environment = var.environment
  }
}

# Outputs
output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_lock_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.id
}

output "backend_configuration" {
  description = "Backend configuration to add to your Terraform files"
  value = <<-EOT
    Add this to your terraform block:

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "eks/terraform.tfstate"
        region         = "${var.aws_region}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.id}"
      }
    }

    Then run:
      terraform init -migrate-state
  EOT
}
