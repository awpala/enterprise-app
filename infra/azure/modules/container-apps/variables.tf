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

variable "container_app_environment_id" {
  description = "Resource ID of the shared Container Apps Environment."
  type        = string
}

variable "apps_identity_id" {
  description = "Resource ID of the user-assigned identity used for registry pulls."
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

variable "ui_image" {
  description = "Fully-qualified standalone Next.js UI image."
  type        = string
}

variable "api_target_port" {
  description = "Port the API container listens on."
  type        = number
  default     = 8000
}

variable "ui_target_port" {
  description = "Port the Next.js server listens on."
  type        = number
  default     = 3000
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

#-------------------------------------------------------------------------
# Entra External ID adapter values for the normalized Authentication section.
# None of these are secrets (tenant/client IDs are public identifiers);
# the API validates bearer tokens against JWKS it fetches from authority.
#-------------------------------------------------------------------------
variable "aad_authority" {
  description = "Entra OIDC v2 authority surfaced as Authentication__Authority."
  type        = string
}

variable "aad_audience" {
  description = "JWT audience surfaced as Authentication__Audience."
  type        = string
}

variable "aad_client_id" {
  description = "Client ID of the API app registration, surfaced as Authentication__ClientId."
  type        = string
}

variable "ui_auth_authority" {
  description = "OIDC authority exposed to the Next.js runtime configuration endpoint."
  type        = string
}

variable "ui_auth_client_id" {
  description = "Public OIDC client ID exposed to the Next.js runtime configuration endpoint."
  type        = string
}

variable "ui_auth_api_scope" {
  description = "Delegated API scope requested by the Next.js OIDC client."
  type        = string
}

#-------------------------------------------------------------------------
# Dev-mode synthetic session — surfaced as Authentication__AllowDev.
# When true, the API registers a JwtOrDev policy scheme that routes
# header-free requests to DevAuthHandler. Deployed-dev only; must be
# false in production. Paired with runtime UI and API authentication settings.
#-------------------------------------------------------------------------
variable "allow_dev_auth" {
  description = "Deployed-development synthetic session. Must be false in production."
  type        = bool
  default     = false
}

#-------------------------------------------------------------------------
# Guest-mode failsafe — surfaced as Authentication__AllowGuest. When
# true, the API honors a synthetic sentinel guest principal (full r/w,
# no CIAM, no scope-down). Prod-only demo/prospecting affordance.
#-------------------------------------------------------------------------
variable "allow_guest_auth" {
  description = "Production demo failsafe. Keep false unless the environment has explicitly accepted the synthetic guest risk."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
