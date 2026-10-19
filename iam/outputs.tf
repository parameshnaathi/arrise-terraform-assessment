output "role_a_arn" {
  description = "ARN of Account A roleA."
  value       = aws_iam_role.role_a.arn
}

output "role_b_arn" {
  description = "ARN of Account A roleB."
  value       = aws_iam_role.role_b.arn
}

output "role_c_arn" {
  description = "ARN of Account B roleC."
  value       = aws_iam_role.role_c.arn
}

output "ci_policy_arn" {
  description = "ARN of the least-privilege CI policy attached to the ci user."
  value       = aws_iam_policy.ci.arn
}

output "iam_user_names" {
  description = "IAM users created in Account A; credentials are provisioned outside Terraform."
  value = {
    engine           = aws_iam_user.engine.name
    ci               = aws_iam_user.ci.name
    operations_admin = aws_iam_user.operations_admin.name
    platform_admin   = aws_iam_user.platform_admin.name
  }
}
