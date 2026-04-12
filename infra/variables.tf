variable "subscription_id" {
  description = "Azure subscription ID to deploy into. Required."
  type        = string
}

variable "project" {
  description = "Short project name used in resource names and tags."
  type        = string
  default     = "ea"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod). Used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "name_suffix" {
  description = "Random-ish suffix to make globally-unique resource names (ACR, Key Vault, SWA). 4-6 lowercase alphanumerics."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,6}$", var.name_suffix))
    error_message = "name_suffix must be 4-6 lowercase alphanumeric characters."
  }
}

variable "image_tag" {
  description = "Docker image tag for API, data-engine, and migrations images (e.g. 'latest', 'sha-abc123')."
  type        = string
  default     = "latest"
}

variable "postgres_admin_username" {
  description = "Administrator username for the PostgreSQL Flexible Server."
  type        = string
  default     = "eaadmin"
}

variable "postgres_database_name" {
  description = "Application database name created on the PostgreSQL server."
  type        = string
  default     = "ea"
}

variable "rabbitmq_username" {
  description = "RabbitMQ default username injected into the broker container."
  type        = string
  default     = "ea"
}

variable "api_target_port" {
  description = "Port the API container listens on (as defined by the Dockerfile EXPOSE / Kestrel default)."
  type        = number
  default     = 8000
}

variable "tags" {
  description = "Extra tags merged onto every resource (project/environment/managed-by are added automatically)."
  type        = map(string)
  default     = {}
}
