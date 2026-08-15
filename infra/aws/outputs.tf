output "aws_account_id" {
  description = "AWS account receiving the deployment."
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs used by the build pipeline."
  value       = module.container_registry.repository_urls
}

output "application_url" {
  description = "AWS-generated CloudFront HTTPS application origin."
  value       = module.cloudfront.application_url
}

output "api_url" {
  description = "Public API origin routed through CloudFront and the shared load balancer."
  value       = module.cloudfront.application_url
}

output "load_balancer_dns_name" {
  description = "AWS-generated ALB origin DNS name."
  value       = module.load_balancer.dns_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution serving the application."
  value       = module.cloudfront.distribution_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name used by AWS CLI operational commands."
  value       = module.ecs_cluster.cluster_name
}

output "migration_task_definition_arn" {
  description = "Task definition to run for EF Core migrations."
  value       = module.container_services.migration_task_definition_arn
}

output "private_subnet_ids" {
  description = "Private subnets in which one-off migration tasks run."
  value       = module.networking.private_subnet_ids
}

output "ecs_task_security_group_id" {
  description = "Security group for one-off ECS migration tasks."
  value       = module.ecs_cluster.task_security_group_id
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID."
  value       = module.cognito.user_pool_id
}

output "auth_authority" {
  description = "Cloud-neutral OIDC authority consumed by the UI and API."
  value       = module.cognito.authority
}

output "auth_client_id" {
  description = "Public Cognito app-client ID consumed by the UI."
  value       = module.cognito.client_id
}

output "auth_api_scope" {
  description = "OAuth scope requested by the UI for API access."
  value       = module.cognito.api_scope
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard used as the AWS operator workbook."
  value       = module.observability.dashboard_name
}

output "container_registry" {
  description = "ECR registry hostname for cloud-neutral build tooling."
  value       = split("/", values(module.container_registry.repository_urls)[0])[0]
}

output "migration_workload" {
  description = "Provider-native identifier of the one-off migration workload."
  value       = module.container_services.migration_task_definition_arn
}
