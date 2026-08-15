terraform {
  required_version = ">= 1.9"

  # aws-onboard.sh supplies the bucket, region, and key after creating the
  # hardened state bucket. Native S3 lock files avoid a DynamoDB dependency.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}
