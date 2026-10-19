output "state_bucket_name" {
  description = "S3 bucket name to use in the remote backend configuration."
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "DynamoDB table name to use for Terraform state locking."
  value       = aws_dynamodb_table.terraform_lock.name
}

output "backend_region" {
  description = "AWS region containing the state bucket and lock table."
  value       = var.aws_region
}
