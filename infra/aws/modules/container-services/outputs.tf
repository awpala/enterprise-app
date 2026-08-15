output "api_service_name" {
  description = "API ECS service name."
  value       = aws_ecs_service.api.name
}

output "ui_service_name" {
  description = "UI ECS service name."
  value       = aws_ecs_service.ui.name
}

output "data_engine_service_name" {
  description = "Data-engine ECS service name."
  value       = aws_ecs_service.data_engine.name
}

output "migration_task_definition_arn" {
  description = "One-off EF Core migration task-definition ARN."
  value       = aws_ecs_task_definition.migrations.arn
}
