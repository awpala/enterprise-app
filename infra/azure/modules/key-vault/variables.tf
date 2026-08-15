variable "name" {
  description = "Key Vault name. Must be globally unique, 3-24 alphanumerics + hyphens."
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

variable "tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
}

variable "deployer_object_id" {
  description = "Object ID of the identity running Terraform (gets Secret Officer role for seeding secrets)."
  type        = string
}

variable "reader_object_ids" {
  description = "Object IDs that get Secrets User role (e.g. Container App managed identities)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
