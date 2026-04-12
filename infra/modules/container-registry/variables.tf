variable "name" {
  description = "ACR name. Must be globally unique, 5-50 lowercase alphanumerics."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy the ACR into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku" {
  description = "ACR SKU (Basic|Standard|Premium)."
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
