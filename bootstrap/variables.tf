variable "aws_region" {
  description = "AWS region where the Terraform state bucket and lock table are created."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile for the bootstrap stack."
  type        = string
  default     = null
  nullable    = true
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a 3-63 character lowercase S3 bucket name."
  }
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
  default     = "arrise-terraform-locks"
}

variable "environment" {
  description = "Environment tag for bootstrap resources."
  type        = string
  default     = "shared"
}
