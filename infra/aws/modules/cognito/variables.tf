variable "name_prefix" {
  description = "Prefix applied to Cognito resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region used to construct Cognito issuer and managed-login URLs."
  type        = string
}

variable "domain_prefix" {
  description = "Globally unique Cognito managed-login domain prefix."
  type        = string
}

variable "application_url" {
  description = "Optional HTTPS application origin registered for callbacks and logout. Localhost remains registered for prototype access."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_google_identity_provider" {
  description = "Whether the Google identity provider is configured."
  type        = bool
}

variable "google_client_id" {
  description = "Google OAuth client ID."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = !var.enable_google_identity_provider || var.google_client_id != null
    error_message = "google_client_id is required when Google federation is enabled."
  }
}

variable "google_client_secret" {
  description = "Google OAuth client secret."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = !var.enable_google_identity_provider || var.google_client_secret != null
    error_message = "google_client_secret is required when Google federation is enabled."
  }
}

variable "upstream_oidc" {
  description = "Optional upstream OIDC provider."
  type = object({
    name          = string
    issuer        = string
    client_id     = string
    client_secret = string
    scopes        = optional(string, "openid profile email")
  })
  default   = null
  nullable  = true
  sensitive = true
}

variable "upstream_saml" {
  description = "Optional metadata-driven SAML provider."
  type = object({
    name         = string
    metadata_url = string
    idp_sign_out = optional(bool, true)
  })
  default  = null
  nullable = true
}

variable "tags" {
  description = "Tags applied to Cognito resources."
  type        = map(string)
}
