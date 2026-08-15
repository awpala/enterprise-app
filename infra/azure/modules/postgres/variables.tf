variable "name" {
  description = "Postgres Flexible Server name. 3-63 lowercase alphanumerics + hyphens."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "administrator_login" {
  description = "Admin login name."
  type        = string
}

variable "administrator_password" {
  description = "Admin password."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Application database to create on the server."
  type        = string
}

variable "sku_name" {
  description = "Compute SKU (e.g. B_Standard_B1ms for burstable 1 vCPU / 2GiB)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage in MB. Minimum 32768 (32 GiB)."
  type        = number
  default     = 32768
}

variable "postgres_version" {
  description = "Postgres major version."
  type        = string
  default     = "16"
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
