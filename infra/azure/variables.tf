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

#-------------------------------------------------------------------------
# Entra External ID (CIAM) tenant — customer SSO.
#
# The External ID tenant itself is created manually in the Azure Portal
# (there is no Terraform/ARM resource for it). Once it exists, a human
# records the tenant ID + tenant subdomain in the env tfvars files, and
# creates a client-secret-based app registration inside the External ID
# tenant for Terraform itself to authenticate as; that app's client ID +
# secret flow in via TF_VAR_external_tenant_client_id and
# TF_VAR_external_tenant_client_secret (set via `gh secret set`).
#-------------------------------------------------------------------------
variable "external_tenant_id" {
  description = "Tenant ID (GUID) of the Entra External ID (CIAM) tenant used for customer SSO. Created manually via the Azure Portal; recorded in envs/*.tfvars."
  type        = string
}

variable "tenant_subdomain" {
  description = "Subdomain of the Entra External ID tenant (the prefix in <subdomain>.ciamlogin.com, e.g. 'eacustomerdev' or 'eacustomerprod'). Chosen at tenant creation time; recorded in envs/*.tfvars. Azure's tenant-creation UI restricts this to alphanumerics only (no hyphens)."
  type        = string
}

variable "external_tenant_client_id" {
  description = "Client ID of the app registration inside the External ID tenant that Terraform authenticates as (used by the azuread.external provider). Flows in via TF_VAR_external_tenant_client_id."
  type        = string
}

variable "external_tenant_client_secret" {
  description = "Client secret paired with external_tenant_client_id. Flows in via TF_VAR_external_tenant_client_secret from GitHub Environment secrets."
  type        = string
  sensitive   = true
}

#-------------------------------------------------------------------------
# Dev-mode synthetic session (deployed-dev only).
#
# When true, the API registers a JwtOrDev policy scheme that routes
# no-Bearer requests to DevAuthHandler. Enables the "Log in as Dev"
# button in deployed dev without requiring a real Entra External ID
# account. Terraform passes the same flag to the Next.js runtime.
# MUST be false in prod.
#-------------------------------------------------------------------------
variable "allow_dev_auth" {
  description = "Deployed-dev synthetic session. When true the API's JwtOrDev policy scheme accepts no-Bearer requests as the dev sentinel principal. Terraform passes the same value to Next.js. Must be false in production."
  type        = bool
  default     = false
}

#-------------------------------------------------------------------------
# Guest-mode failsafe (explicit temporary demo affordance).
#
# When true, the API accepts a synthetic sentinel guest principal with full
# read/write access. This is a CIAM-free, scope-down-free escape hatch
# intended solely for isolated demos and MUST NOT be enabled for customer
# data. Terraform passes the same flag to Next.js. Independent of dev auth.
#-------------------------------------------------------------------------
variable "allow_guest_auth" {
  description = "Explicit temporary demo failsafe. When true, surfaces a synthetic guest principal with full read/write access. Disabled by default; never enable for customer data."
  type        = bool
  default     = false
}
