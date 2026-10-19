locals {
  ecr_repository_arn  = "arn:aws:ecr:${var.aws_region}:${var.account_a_id}:repository/${var.ecr_repository_name}"
  ecs_service_arn     = "arn:aws:ecs:${var.aws_region}:${var.account_a_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  ecs_task_family_arn = "arn:aws:ecs:${var.aws_region}:${var.account_a_id}:task-definition/${var.ecs_task_definition_family}:*"
  artifact_bucket_arn = "arn:aws:s3:::${var.artifact_bucket}"
}

data "aws_iam_policy_document" "ci" {
  statement {
    sid       = "ECRAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushToSingleECRRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [local.ecr_repository_arn]
  }

  statement {
    sid       = "RegisterTaskDefinition"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "DeploySingleECSService"
    effect    = "Allow"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [local.ecs_service_arn]
  }

  statement {
    sid       = "DescribeConfiguredTaskDefinitionFamily"
    effect    = "Allow"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = [local.ecs_task_family_arn]
  }

  statement {
    sid       = "ReadArtifactsBucketLocation"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = [local.artifact_bucket_arn]
  }

  statement {
    sid       = "ListArtifactsBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.artifact_bucket_arn]
  }

  statement {
    sid       = "ReadArtifactsObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${local.artifact_bucket_arn}/*"]
  }

  dynamic "statement" {
    for_each = length(var.ecs_task_role_arns) == 0 ? [] : [var.ecs_task_role_arns]

    content {
      sid       = "PassOnlyConfiguredECSTaskRoles"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = statement.value

      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["ecs-tasks.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "ci" {
  provider    = aws.account_a
  name        = "ci-ecr-ecs-artifacts-least-privilege"
  description = "Push to one ECR repo, deploy one ECS service, and read one artifacts bucket."
  policy      = data.aws_iam_policy_document.ci.json
}

resource "aws_iam_user_policy_attachment" "ci" {
  provider   = aws.account_a
  user       = aws_iam_user.ci.name
  policy_arn = aws_iam_policy.ci.arn
}
