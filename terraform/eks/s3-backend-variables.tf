# Variables for S3 Backend Configuration

variable "terraform_state_bucket_name" {
  description = "Name of S3 bucket for Terraform state (must be globally unique)"
  type        = string
  default     = "sha-blog-terraform-state-us-west-2"
  # NOTE: S3 bucket names must be globally unique
  # Change this if the default is already taken
}

variable "terraform_state_lock_table_name" {
  description = "Name of DynamoDB table for state locking"
  type        = string
  default     = "sha-blog-terraform-locks"
}

variable "enable_s3_backend" {
  description = "Whether to create S3 backend resources"
  type        = bool
  default     = true
}
