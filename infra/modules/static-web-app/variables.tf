variable "name" {
  description = "Static Web App name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group."
  type        = string
}

variable "location" {
  description = "Azure region. SWA is GA only in a subset of regions (e.g. eastus2, westus2, centralus, westeurope, eastasia)."
  type        = string
  default     = "eastus2"
}

variable "sku_tier" {
  description = "SKU tier (Free|Standard)."
  type        = string
  default     = "Free"
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
