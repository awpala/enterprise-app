resource "aws_secretsmanager_secret" "postgres_connection_string" {
  name                    = "${var.name_prefix}/postgres/connection-string"
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "postgres_connection_string" {
  secret_id = aws_secretsmanager_secret.postgres_connection_string.id
  secret_string = join(";", [
    "Host=${var.postgres_host}",
    "Port=${var.postgres_port}",
    "Database=${var.postgres_database}",
    "Username=${var.postgres_username}",
    "Password=${var.postgres_password}",
    "SSL Mode=Require",
    "Trust Server Certificate=true",
  ])
}

resource "aws_secretsmanager_secret" "rabbitmq_password" {
  name                    = "${var.name_prefix}/rabbitmq/password"
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "rabbitmq_password" {
  secret_id     = aws_secretsmanager_secret.rabbitmq_password.id
  secret_string = var.rabbitmq_password
}
