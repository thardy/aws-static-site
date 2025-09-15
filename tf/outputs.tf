output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for static content."
  value       = aws_s3_bucket.static_site.bucket
}

output "github_actions_iam_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}
