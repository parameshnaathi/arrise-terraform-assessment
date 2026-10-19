output "artifact_bucket_name" {
  description = "Account A artifacts bucket name."
  value       = aws_s3_bucket.artifacts.id
}

output "role_c_target_bucket_name" {
  description = "Account B bucket configured for roleC."
  value       = aws_s3_bucket.role_c_target.id
}

output "ecr_repository_url" {
  description = "Account A ECR URL for CI image pushes."
  value       = aws_ecr_repository.application.repository_url
}

output "ecs_cluster_arn" {
  description = "Account A ECS cluster ARN."
  value       = aws_ecs_cluster.application.arn
}

output "ecs_service_arn" {
  description = "Account A ECS service ARN."
  value       = aws_ecs_service.application.id
}

output "task_definition_arn" {
  description = "Account A ECS task definition ARN."
  value       = aws_ecs_task_definition.application.arn
}

output "ecs_task_execution_role_arn" {
  description = "Exact task execution role ARN to allow CI to pass to ECS tasks."
  value       = aws_iam_role.ecs_task_execution.arn
}
