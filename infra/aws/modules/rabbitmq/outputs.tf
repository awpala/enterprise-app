output "host" {
  description = "Private service-discovery hostname used by API and worker tasks."
  value       = "${aws_service_discovery_service.this.name}.${var.namespace_name}"
}

output "service_name" {
  description = "RabbitMQ ECS service name."
  value       = aws_ecs_service.this.name
}

output "file_system_id" {
  description = "EFS file-system ID storing RabbitMQ data."
  value       = aws_efs_file_system.this.id
}
