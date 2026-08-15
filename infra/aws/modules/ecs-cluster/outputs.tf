output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "task_security_group_id" {
  description = "Shared security group attached to application tasks."
  value       = aws_security_group.tasks.id
}

output "namespace_id" {
  description = "Cloud Map private DNS namespace ID."
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "namespace_name" {
  description = "Cloud Map private DNS namespace name."
  value       = aws_service_discovery_private_dns_namespace.this.name
}
