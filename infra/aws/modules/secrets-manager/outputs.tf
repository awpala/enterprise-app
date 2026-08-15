output "postgres_connection_string_arn" {
  description = "ARN of the PostgreSQL connection-string secret."
  value       = aws_secretsmanager_secret.postgres_connection_string.arn
}

output "rabbitmq_password_arn" {
  description = "ARN of the RabbitMQ password secret."
  value       = aws_secretsmanager_secret.rabbitmq_password.arn
}
