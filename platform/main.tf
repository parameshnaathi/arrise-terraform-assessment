locals {
  tags = {
    Project     = "arrise-devops-assignment"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket" "artifacts" {
  provider = aws.account_a
  bucket   = var.artifact_bucket
  tags     = merge(local.tags, { Purpose = "CI read-only deployment artifacts" })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  provider = aws.account_a
  bucket   = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  provider = aws.account_a
  bucket   = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  provider                = aws.account_a
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "role_c_target" {
  provider = aws.account_b
  bucket   = var.target_s3_bucket
  tags     = merge(local.tags, { Purpose = "roleC scoped S3 target" })
}

resource "aws_s3_bucket_versioning" "role_c_target" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c_target.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "role_c_target" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c_target.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "role_c_target" {
  provider                = aws.account_b
  bucket                  = aws_s3_bucket.role_c_target.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "application" {
  provider             = aws.account_a
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.tags, { Purpose = "CI application image repository" })
}

resource "aws_ecs_cluster" "application" {
  provider = aws.account_a
  name     = var.ecs_cluster_name
  tags     = merge(local.tags, { Purpose = "CI deployed service cluster" })
}

data "aws_iam_policy_document" "ecs_task_execution_trust" {
  statement {
    sid     = "EcsTasksAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  provider           = aws.account_a
  name               = "arrise-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_trust.json
  tags               = merge(local.tags, { Purpose = "ECS task execution role" })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  provider   = aws.account_a
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "application" {
  provider          = aws.account_a
  name              = "/ecs/${var.ecs_task_definition_family}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_ecs_task_definition" "application" {
  provider                 = aws.account_a
  family                   = var.ecs_task_definition_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "application"
      image     = "public.ecr.aws/docker/library/nginx:stable-alpine"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.application.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "application"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "application" {
  provider        = aws.account_a
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.application.id
  task_definition = aws_ecs_task_definition.application.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.ecs_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = true
  }

  tags = local.tags
}
