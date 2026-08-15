resource "aws_cognito_user_pool" "this" {
  name                     = "${var.name_prefix}-users"
  user_pool_tier           = "ESSENTIALS"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  sign_in_policy {
    allowed_first_auth_factors = ["EMAIL_OTP"]
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  tags = var.tags
}

resource "aws_cognito_resource_server" "api" {
  identifier   = "api://${var.name_prefix}"
  name         = "${var.name_prefix}-api"
  user_pool_id = aws_cognito_user_pool.this.id

  scope {
    scope_name        = "access_as_user"
    scope_description = "Access the enterprise application API as the signed-in user"
  }
}

resource "aws_cognito_identity_provider" "google" {
  count = var.enable_google_identity_provider ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes = "openid profile email"
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

resource "aws_cognito_identity_provider" "oidc" {
  count = var.upstream_oidc == null ? 0 : 1

  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = var.upstream_oidc.name
  provider_type = "OIDC"

  provider_details = {
    attributes_request_method = "GET"
    authorize_scopes          = var.upstream_oidc.scopes
    client_id                 = var.upstream_oidc.client_id
    client_secret             = var.upstream_oidc.client_secret
    oidc_issuer               = var.upstream_oidc.issuer
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

resource "aws_cognito_identity_provider" "saml" {
  count = var.upstream_saml == null ? 0 : 1

  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = var.upstream_saml.name
  provider_type = "SAML"

  provider_details = {
    IDPSignout  = tostring(var.upstream_saml.idp_sign_out)
    MetadataURL = var.upstream_saml.metadata_url
  }

  attribute_mapping = {
    email    = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
    username = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"
  }
}

locals {
  callback_urls = distinct(compact([
    "http://localhost:3000/auth/callback",
    var.application_url == null ? null : "${trimsuffix(var.application_url, "/")}/auth/callback",
  ]))
  logout_urls = distinct(compact([
    "http://localhost:3000",
    var.application_url == null ? null : trimsuffix(var.application_url, "/"),
  ]))
  supported_identity_providers = concat(
    ["COGNITO"],
    var.enable_google_identity_provider ? ["Google"] : [],
    var.upstream_oidc == null ? [] : [var.upstream_oidc.name],
    var.upstream_saml == null ? [] : [var.upstream_saml.name],
  )
}

resource "aws_cognito_user_pool_client" "ui" {
  name         = "${var.name_prefix}-ui"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_USER_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes = [
    "openid",
    "profile",
    "email",
    "${aws_cognito_resource_server.api.identifier}/access_as_user",
  ]
  callback_urls                 = local.callback_urls
  logout_urls                   = local.logout_urls
  supported_identity_providers  = local.supported_identity_providers
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  access_token_validity         = 60
  id_token_validity             = 60
  refresh_token_validity        = 30
  auth_session_validity         = 3

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  depends_on = [
    aws_cognito_identity_provider.google,
    aws_cognito_identity_provider.oidc,
    aws_cognito_identity_provider.saml,
  ]
}

resource "aws_cognito_user_pool_domain" "this" {
  domain                = var.domain_prefix
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 2
}

resource "aws_cognito_managed_login_branding" "this" {
  user_pool_id                = aws_cognito_user_pool.this.id
  client_id                   = aws_cognito_user_pool_client.ui.id
  use_cognito_provided_values = true
}
