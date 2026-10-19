variable "aws_region" {
  description = "Region for the Account A deployment resources and Account B target bucket."
  type        = string
  default     = "us-east-1"
}

variable "account_a_profile" {
  description = "AWS CLI profile authenticated to Account A."
  type        = string
  default     = "default"
}

variable "account_b_profile" {
  description = "AWS CLI profile authenticated to Account B."
  type        = string
  default     = "account-b"
}

variable "account_a_id" {
  description = "Account A ID."
  type        = string
  default     = "593602868022"
}

variable "account_b_id" {
  description = "Account B ID."
  type        = string
  default     = "795346865572"
}

variable "artifact_bucket" {
  description = "Account A S3 bucket readable by the CI user."
  type        = string
  default     = "arrise-ci-artifacts-593602868022-us-east-1"
}

variable "target_s3_bucket" {
  description = "Account B S3 bucket accessible to roleC."
  type        = string
  default     = "arrise-rolec-data-795346865572-us-east-1"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository to which CI pushes images."
  type        = string
  default     = "arrise-application"
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
  default     = "arrise-cluster"
}

variable "ecs_service_name" {
  description = "Name of the ECS service deployed by CI."
  type        = string
  default     = "arrise-service"
}

variable "ecs_task_definition_family" {
  description = "Task definition family for the ECS service."
  type        = string
  default     = "arrise-task"
}

variable "ecs_subnet_ids" {
  description = "Public subnets used by the Fargate service."
  type        = list(string)
  default = [
    "subnet-0e846069c814008b5",
    "subnet-09f75b5d061bcc7fe",
  ]

  validation {
    condition     = length(var.ecs_subnet_ids) >= 2
    error_message = "Provide at least two public subnet IDs in different availability zones."
  }
}

variable "ecs_security_group_id" {
  description = "Security group used by the initial zero-task ECS service."
  type        = string
  default     = "sg-0875ec716d7eca1e7"
}
