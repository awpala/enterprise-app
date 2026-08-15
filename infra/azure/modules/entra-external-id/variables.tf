variable "environment" {
  description = "Environment name (dev, prod). Used in app-registration display names and tags."
  type        = string
}

variable "application_url" {
  description = "Public HTTPS origin of the Next.js application. Used to derive login and post-logout redirect URIs."
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
