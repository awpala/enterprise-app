variable "environment" {
  description = "Environment name (dev, prod). Used in app-registration display names and tags."
  type        = string
}

variable "swa_url" {
  description = "Public HTTPS URL of the Static Web App hosting the Angular SPA (e.g. https://polite-tree-123.azurestaticapps.net). Used to derive SPA redirect + post-logout URIs."
  type        = string
}

variable "external_tenant_id" {
  description = "Tenant ID (GUID) of the Entra External ID tenant that owns the app registrations, user flow, and identity providers."
  type        = string
}

variable "tenant_subdomain" {
  description = "Subdomain of the Entra External ID tenant (the prefix in <subdomain>.ciamlogin.com). Used to compute the OIDC authority URL."
  type        = string
}

variable "tags" {
  description = "Tags to apply to taggable resources in this module (most Graph-level resources do not accept tags)."
  type        = map(string)
  default     = {}
}
