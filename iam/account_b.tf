data "aws_iam_policy_document" "role_c_trust" {
  statement {
    sid     = "TrustOnlyRoleBFromAccountA"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.role_b.arn]
    }
  }
}

resource "aws_iam_role" "role_c" {
  provider           = aws.account_b
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.role_c_trust.json
}

data "aws_iam_policy_document" "role_c_s3" {
  statement {
    sid       = "FullAccessToTargetBucketAndObjects"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${var.target_s3_bucket}", "arn:aws:s3:::${var.target_s3_bucket}/*"]
  }
}

resource "aws_iam_role_policy" "role_c_s3" {
  provider = aws.account_b
  name     = "roleC-target-bucket-only"
  role     = aws_iam_role.role_c.id
  policy   = data.aws_iam_policy_document.role_c_s3.json
}
