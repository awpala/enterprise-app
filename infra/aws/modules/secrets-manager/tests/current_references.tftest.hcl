mock_provider "aws" {}

variables {
  name_prefix             = "ea-test"
  recovery_window_in_days = 0
  postgres_host           = "database.internal"
  postgres_port           = 5432
  postgres_database       = "ea"
  postgres_username       = "postgres"
  postgres_password       = "test-postgres-password"
  rabbitmq_password       = "test-rabbitmq-password"
  tags                    = { environment = "test" }
}

run "secret_references_select_current_versions" {
  command = apply

  assert {
    condition     = endswith(output.postgres_connection_string_current_reference, "::AWSCURRENT:")
    error_message = "The PostgreSQL ECS reference must explicitly select AWSCURRENT."
  }

  assert {
    condition     = endswith(output.rabbitmq_password_current_reference, "::AWSCURRENT:")
    error_message = "The RabbitMQ ECS reference must explicitly select AWSCURRENT."
  }
}
