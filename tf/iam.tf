data "aws_iam_policy_document" "github_actions_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # This restricts the role to a specific GitHub repository and environment.
      values = ["repo:${replace(var.github_repository_url, "https://github.com/", "")}:environment:dev"]
    }
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-${var.environment}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

resource "aws_iam_policy" "github_actions" {
  name   = "${var.project_name}-${var.environment}-github-actions-policy"
  policy = data.aws_iam_policy_document.github_actions_policy.json
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

data "aws_iam_policy_document" "github_actions_policy" {
  statement {
    sid    = "AllowS3Sync"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.static_site.arn,
      "${aws_s3_bucket.static_site.arn}/*"
    ]
  }

  statement {
    sid    = "AllowCloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation"
    ]
    resources = [
      aws_cloudfront_distribution.s3_distribution.arn
    ]
  }
}
