terraform {
  required_version = ">= 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67.0"
    }
  }
  backend "s3" {
    bucket         = "tim-hardy-terraform"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    use_lockfile   = true
    workspace_key_prefix = "aws-static-site"
  }
}

provider "aws" {
  region = var.aws_region
}
