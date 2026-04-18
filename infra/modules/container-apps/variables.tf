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

#-------------------------------------------------------------------------
# Entra External ID wiring — plain envvars on the API container,
# consumed by Microsoft.Identity.Web's AzureAd:* configuration section.
# None of these are secrets (tenant/client IDs are public identifiers);
# the API validates bearer tokens against JWKS it fetches from authority.
#-------------------------------------------------------------------------
variable "aad_authority" {
  description = "OIDC authority URL surfaced to the API as AzureAd__Authority. Format: https://<subdomain>.ciamlogin.com/<tenant-id>. Microsoft.Identity.Web appends /v2.0/.well-known/openid-configuration internally — do NOT pre-append /v2.0 here (causes .../v2.0/v2.0/.well-known/... 404 and silent metadata failure)."
  type        = string
}

variable "aad_audience" {
  description = "JwtBearer audience surfaced to the API as AzureAd__Audience. For v2 tokens this equals the API app's client ID."
  type        = string
}

variable "aad_client_id" {
  description = "Client ID of the API app registration, surfaced to the API as AzureAd__ClientId."
  type        = string
}

variable "aad_tenant_id" {
  description = "External ID tenant ID, surfaced to the API as AzureAd__TenantId."
  type        = string
}

#-------------------------------------------------------------------------
# Dev-mode synthetic session — surfaced to the API as AzureAd__AllowDev.
# When true, the API registers a JwtOrDev policy scheme that routes
# header-free requests to DevAuthHandler. Deployed-dev only; must be
# false in prod. Paired with ENABLE_DEV_AUTH=true on the SPA build.
#-------------------------------------------------------------------------
variable "allow_dev_auth" {
  description = "Deployed-dev synthetic session. When true, surfaces AzureAd__AllowDev=true on the API container so the JwtOrDev policy scheme accepts no-Bearer requests as the dev sentinel principal. Must be false in prod."
  type        = bool
  default     = false
}

#-------------------------------------------------------------------------
# Guest-mode failsafe — surfaced to the API as AzureAd__AllowGuest. When
# true, the API honors a synthetic sentinel guest principal (full r/w,
# no CIAM, no scope-down). Prod-only demo/prospecting affordance.
#-------------------------------------------------------------------------
variable "allow_guest_auth" {
  description = "Prod-only demo/prospecting failsafe. When true, surfaces AzureAd__AllowGuest=true on the API container so it accepts a synthetic sentinel guest principal. Leave false for dev and local."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
