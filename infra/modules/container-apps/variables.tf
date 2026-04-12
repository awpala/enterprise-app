variable "name_prefix" {
  description = "Prefix for the Container Apps Environment and apps."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for the CAE."
  type        = string
}

variable "acr_id" {
  description = "Container Registry resource ID (for AcrPull role assignment)."
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server (e.g. myacr.azurecr.io)."
  type        = string
}

variable "api_image" {
  description = "Fully-qualified API image (login_server/repo:tag)."
  type        = string
}

variable "data_engine_image" {
  description = "Fully-qualified data-engine image."
  type        = string
}

variable "migrations_image" {
  description = "Fully-qualified migrations image."
  type        = string
}

variable "api_target_port" {
  description = "Port the API container listens on."
  type        = number
  default     = 8000
}

variable "postgres_connection_string" {
  description = "Npgsql connection string for the API (ConnectionStrings__DefaultConnection)."
  type        = string
  sensitive   = true
}

variable "migrations_connection_string" {
  description = "Connection string used by the EF Core migration bundle (accepts `--connection`)."
  type        = string
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ default user."
  type        = string
}

variable "rabbitmq_password" {
  description = "RabbitMQ default password."
  type        = string
  sensitive   = true
}

variable "application_insights_connection_string" {
  description = "App Insights connection string for OTel export."
  type        = string
  sensitive   = true
}

variable "api_allowed_origins" {
  description = "Origins permitted by the API CORS policy (mapped to `Cors__AllowedOrigins__<i>` env vars)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
