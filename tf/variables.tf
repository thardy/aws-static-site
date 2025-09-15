variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "project_name" {
  description = "The name of the project, used to prefix resource names."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, test, prod)."
  type        = string
}

variable "deploy_bucket_name" {
  description = "The name of the S3 bucket for the static website."
  type        = string
}

variable "github_repository_url" {
  description = "The URL of the GitHub repository."
  type        = string
  # Replace this with the URL of your GitHub repository
  # e.g., "https://github.com/your-username/your-repo-name"
}
