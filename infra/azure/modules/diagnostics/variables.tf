variable "log_analytics_workspace_id" {
  type        = string
  description = "Target LAW resource ID for all diagnostic settings."
}

variable "postgres_server_id" {
  type        = string
  description = "Postgres Flexible Server resource ID."
}

variable "container_registry_id" {
  type        = string
  description = "Container Registry resource ID."
}
