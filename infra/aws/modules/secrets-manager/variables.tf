variable "name_prefix" {
  description = "Prefix applied to secret names."
  type        = string
}

variable "recovery_window_in_days" {
  description = "Recovery window applied when a secret is deleted."
  type        = number
}

variable "postgres_host" {
  description = "PostgreSQL hostname embedded in the connection string."
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port embedded in the connection string."
  type        = number
}

variable "postgres_database" {
  description = "PostgreSQL database name embedded in the connection string."
  type        = string
}

variable "postgres_username" {
  description = "PostgreSQL username embedded in the connection string."
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL password embedded in the connection string."
  type        = string
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "RabbitMQ password stored for ECS secret injection."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to every secret."
  type        = map(string)
}
