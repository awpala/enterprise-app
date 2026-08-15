output "postgres_connection_string_arn" {
  description = "ARN of the PostgreSQL connection-string secret."
  value       = aws_secretsmanager_secret.postgres_connection_string.arn
}

output "postgres_connection_string_current_reference" {
  description = "AWSCURRENT-qualified PostgreSQL connection-string reference for ECS secret injection."
  value       = "${aws_secretsmanager_secret.postgres_connection_string.arn}::AWSCURRENT:"

  depends_on = [aws_secretsmanager_secret_version.postgres_connection_string]
}

output "rabbitmq_password_arn" {
  description = "ARN of the RabbitMQ password secret."
  value       = aws_secretsmanager_secret.rabbitmq_password.arn
}

output "rabbitmq_password_current_reference" {
  description = "AWSCURRENT-qualified RabbitMQ-password reference for ECS secret injection."
  value       = "${aws_secretsmanager_secret.rabbitmq_password.arn}::AWSCURRENT:"

  depends_on = [aws_secretsmanager_secret_version.rabbitmq_password]
}
