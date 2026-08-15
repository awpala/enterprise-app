data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "ea-tfstate-${var.name_suffix}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.existing_github_oidc_provider_arn == null ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

locals {
  github_oidc_provider_arn = coalesce(
    var.existing_github_oidc_provider_arn,
    try(aws_iam_openid_connect_provider.github[0].arn, null)
  )
}

resource "aws_iam_role" "github_deployer" {
  name = "ea-github-deployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            for environment in var.github_environments :
            "repo:${var.github_owner}/${var.github_repo}:environment:${environment}"
          ]
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "github_deployer" {
  name = "ea-terraform-deployer"
  role = aws_iam_role.github_deployer.id

  # Prototype policy: resource creation APIs cannot all be scoped before the
  # resources exist. Tighten with permissions boundaries before production.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*",
        ]
      },
      {
        Sid    = "ApplicationInfrastructure"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecr:*",
          "ecs:*",
          "elasticloadbalancing:*",
          "cloudfront:*",
          "rds:*",
          "cognito-idp:*",
          "secretsmanager:*",
          "logs:*",
          "cloudwatch:*",
          "servicediscovery:*",
          "elasticfilesystem:*",
          "application-autoscaling:*",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = "*"
      },
      {
        Sid      = "CreatePrivateServiceDiscoveryDns"
        Effect   = "Allow"
        Action   = "route53:CreateHostedZone"
        Resource = "*"
        Condition = {
          Null = {
            "route53:VPCs" = "false"
          }
          "ForAllValues:StringLike" = {
            "route53:VPCs" = "VPCId=vpc-*,VPCRegion=${var.aws_region}"
          }
        }
      },
      {
        Sid    = "ReadPrivateServiceDiscoveryDns"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}
