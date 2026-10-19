variable "aws_region" {
  description = "AWS region used for regional IAM policy resource ARNs."
  type        = string
  default     = "us-east-1"
}

variable "account_a_profile" {
  description = "Optional AWS CLI profile authenticated to Account A."
  type        = string
  default     = null
  nullable    = true
}

variable "account_b_profile" {
  description = "Optional AWS CLI profile authenticated to Account B."
  type        = string
  default     = null
  nullable    = true
}

variable "account_a_id" {
  description = "AWS Account A ID associated with account_a_profile."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_a_id))
    error_message = "account_a_id must be a 12-digit AWS account ID."
  }
}

variable "account_b_id" {
  description = "AWS Account B ID associated with account_b_profile."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_b_id))
    error_message = "account_b_id must be a 12-digit AWS account ID."
  }
}

variable "target_s3_bucket" {
  description = "One Account B bucket to which roleC receives full S3 access."
  type        = string

  validation {
    condition     = length(trimspace(var.target_s3_bucket)) > 0 && !strcontains(var.target_s3_bucket, "/")
    error_message = "target_s3_bucket must be a bucket name without a path."
  }
}

variable "artifact_bucket" {
  description = "One Account A artifacts bucket readable by the ci user."
  type        = string

  validation {
    condition     = length(trimspace(var.artifact_bucket)) > 0 && !strcontains(var.artifact_bucket, "/")
    error_message = "artifact_bucket must be a bucket name without a path."
  }
}

variable "ecr_repository_name" {
  description = "The single ECR repository to which CI can push."
  type        = string
  default     = "arrise-application"
}

variable "ecs_cluster_name" {
  description = "Cluster containing the one ECS service deployed by CI."
  type        = string
}

variable "ecs_service_name" {
  description = "The single ECS service deployed by CI."
  type        = string
}

variable "ecs_task_definition_family" {
  description = "Task definition family registered and described by CI."
  type        = string
}

variable "ecs_task_role_arns" {
  description = "Exact ECS task and execution role ARNs referenced by task definitions; leave empty if neither is used."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.ecs_task_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", arn))])
    error_message = "Every ECS task role must be a valid IAM role ARN."
  }
}
