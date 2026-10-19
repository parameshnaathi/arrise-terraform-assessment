locals {
  role_b_arn = "arn:aws:iam::${var.account_a_id}:role/roleB"
}

resource "aws_iam_group" "group1" {
  provider = aws.account_a
  name     = "group1"
}

resource "aws_iam_user" "engine" {
  provider = aws.account_a
  name     = "engine"
}

resource "aws_iam_user" "ci" {
  provider = aws.account_a
  name     = "ci"
}

resource "aws_iam_group_membership" "group1" {
  provider = aws.account_a
  name     = "group1-membership"
  users    = [aws_iam_user.engine.name, aws_iam_user.ci.name]
  group    = aws_iam_group.group1.name
}

resource "aws_iam_group" "group2" {
  provider = aws.account_a
  name     = "group2"
}

resource "aws_iam_user" "operations_admin" {
  provider = aws.account_a
  name     = "operations.admin"
}

resource "aws_iam_user" "platform_admin" {
  provider = aws.account_a
  name     = "platform.admin"
}

resource "aws_iam_group_membership" "group2" {
  provider = aws.account_a
  name     = "group2-membership"
  users    = [aws_iam_user.operations_admin.name, aws_iam_user.platform_admin.name]
  group    = aws_iam_group.group2.name
}

data "aws_iam_policy_document" "group2_self_service_password" {
  statement {
    sid       = "ChangeOwnConsolePassword"
    effect    = "Allow"
    actions   = ["iam:ChangePassword"]
    resources = [aws_iam_user.operations_admin.arn, aws_iam_user.platform_admin.arn]
  }

  statement {
    sid       = "ReadAccountPasswordPolicy"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy"]
    resources = ["*"]
  }
}

resource "aws_iam_group_policy" "group2_self_service_password" {
  provider = aws.account_a
  name     = "group2-self-service-password-change"
  group    = aws_iam_group.group2.name
  policy   = data.aws_iam_policy_document.group2_self_service_password.json
}

data "aws_iam_policy_document" "engine_assume_role_b" {
  statement {
    sid       = "AssumeRoleB"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.role_b_arn]
  }
}

resource "aws_iam_user_policy" "engine_assume_role_b" {
  provider = aws.account_a
  name     = "assume-roleB"
  user     = aws_iam_user.engine.name
  policy   = data.aws_iam_policy_document.engine_assume_role_b.json
}

data "aws_iam_policy_document" "role_a_admin_except_iam" {
  statement {
    sid         = "AllActionsExceptIAM"
    effect      = "Allow"
    not_actions = ["iam:*"]
    resources   = ["*"]
  }
}

resource "aws_iam_policy" "role_a_admin_except_iam" {
  provider    = aws.account_a
  name        = "roleA-admin-except-iam"
  description = "Administrative actions across AWS services except IAM."
  policy      = data.aws_iam_policy_document.role_a_admin_except_iam.json
}

data "aws_iam_policy_document" "role_a_trust" {
  statement {
    sid     = "AccountADelegatedAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:root"]
    }
  }
}

resource "aws_iam_role" "role_a" {
  provider           = aws.account_a
  name               = "roleA"
  assume_role_policy = data.aws_iam_policy_document.role_a_trust.json
}

resource "aws_iam_role_policy_attachment" "role_a_admin_except_iam" {
  provider   = aws.account_a
  role       = aws_iam_role.role_a.name
  policy_arn = aws_iam_policy.role_a_admin_except_iam.arn
}

data "aws_iam_policy_document" "role_b_trust" {
  statement {
    sid     = "EngineUserOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.engine.arn]
    }
  }
}

resource "aws_iam_role" "role_b" {
  provider           = aws.account_a
  name               = "roleB"
  assume_role_policy = data.aws_iam_policy_document.role_b_trust.json
}

data "aws_iam_policy_document" "role_b_assume_role_c" {
  statement {
    sid       = "AssumeOnlyRoleC"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${var.account_b_id}:role/roleC"]
  }
}

resource "aws_iam_role_policy" "role_b_assume_role_c" {
  provider = aws.account_a
  name     = "assume-roleC-only"
  role     = aws_iam_role.role_b.id
  policy   = data.aws_iam_policy_document.role_b_assume_role_c.json
}
