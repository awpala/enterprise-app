output "aws_account_id" {
  description = "AWS account containing bootstrap resources."
  value       = data.aws_caller_identity.current.account_id
}

output "tfstate_bucket" {
  description = "S3 bucket used by the AWS Terraform backend."
  value       = aws_s3_bucket.tfstate.id
}

output "github_deployer_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC."
  value       = aws_iam_role.github_deployer.arn
}

output "backend_config_dev" {
  description = "Backend arguments for the AWS dev state."
  value       = "-backend-config=bucket=${aws_s3_bucket.tfstate.id} -backend-config=region=${var.aws_region} -backend-config=key=aws/dev.tfstate -backend-config=use_lockfile=true"
}

output "backend_config_production" {
  description = "Backend arguments for the AWS production state."
  value       = "-backend-config=bucket=${aws_s3_bucket.tfstate.id} -backend-config=region=${var.aws_region} -backend-config=key=aws/production.tfstate -backend-config=use_lockfile=true"
}

output "gh_setup_commands" {
  description = "Commands that create AWS GitHub Environments and configure their deployment role and state coordinates."
  value = templatefile("${path.module}/templates/gh_setup.sh.tftpl", {
    repo         = "${var.github_owner}/${var.github_repo}"
    environments = var.github_environments
    role_arn     = aws_iam_role.github_deployer.arn
    region       = var.aws_region
    bucket       = aws_s3_bucket.tfstate.id
  })
}
