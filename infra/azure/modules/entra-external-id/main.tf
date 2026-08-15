#-------------------------------------------------------------------------
# Entra External ID (CIAM) — app registrations, pre-authorization,
# user flow, identity providers.
#
# All resources in this module live in the External ID tenant. The caller
# wires this module up with the `.external` aliased azuread provider (see
# providers = { ... } on the `module` block in the root).
#
# The tenant itself is created out-of-band in the Azure Portal (no
# Terraform / ARM resource exists for creating an External ID tenant).
#-------------------------------------------------------------------------

# Random stable UUIDs for the API's exposed OAuth2 scope + the pre-authorized
# SPA's use of it. Using random_uuid with ignore_changes keeps the IDs stable
# across plans but lets us generate them declaratively.
resource "random_uuid" "access_as_user_scope" {}

#-------------------------------------------------------------------------
# API app registration
#
# - Exposes a single delegated scope `access_as_user` against an
#   api://<client-id> identifier URI (set post-create via
#   identifier_uris + a lifecycle block because the client_id isn't
#   knowable until the resource exists).
# - requested_access_token_version = 2 ⇒ v2.0 access tokens, which is what
#   MSAL emits and what the External ID (ciamlogin.com) authority signs.
#-------------------------------------------------------------------------
resource "azuread_application" "api" {
  display_name     = "ea-api-${var.environment}"
  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      id                         = random_uuid.access_as_user_scope.result
      value                      = "access_as_user"
      type                       = "User"
      enabled                    = true
      admin_consent_display_name = "Access the EA API as the signed-in user"
      admin_consent_description  = "Allows the EA SPA to call the EA API on behalf of the signed-in user."
      user_consent_display_name  = "Access the EA API"
      user_consent_description   = "Allow the EA SPA to call the EA API on your behalf."
    }
  }
}

# identifier_uris must reference the app's own client_id; it can only be set
# after the azuread_application exists, so we update it via a second write.
resource "azuread_application_identifier_uri" "api" {
  application_id = azuread_application.api.id
  identifier_uri = "api://${azuread_application.api.client_id}"
}

resource "azuread_service_principal" "api" {
  client_id = azuread_application.api.client_id
}

#-------------------------------------------------------------------------
# SPA app registration
#
# - Single-page-application platform enables Authorization Code + PKCE for
#   the public Next.js browser client.
# - The callback path and origin root cover login and post-logout redirects
#   for the Container Apps origin and canonical localhost port 3000.
# - required_resource_access wires the SPA up with the API's
#   access_as_user delegated scope so the OIDC client can request it.
#-------------------------------------------------------------------------
resource "azuread_application" "spa" {
  display_name     = "ea-spa-${var.environment}"
  sign_in_audience = "AzureADMyOrg"

  # External ID tenants reject v1 tokens — every app reg must declare v2,
  # including public-client SPAs that don't expose their own scopes.
  api {
    requested_access_token_version = 2
  }

  # NOTE: the azuread provider requires a trailing slash on any redirect URI
  # that has no path segment. Origin-root entries therefore include `/`.
  single_page_application {
    redirect_uris = [
      "${var.application_url}/",
      "${var.application_url}/auth/callback",
      "http://localhost:3000/",
      "http://localhost:3000/auth/callback",
    ]
  }

  # web{} is retained only to explicitly disable implicit-grant flows; all
  # redirect URIs (login + logout) live on the single_page_application{}
  # block above.
  web {
    redirect_uris = []
    logout_url    = null

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }

  required_resource_access {
    # Points at the API app registration and its access_as_user scope.
    resource_app_id = azuread_application.api.client_id

    resource_access {
      id   = random_uuid.access_as_user_scope.result
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "spa" {
  client_id = azuread_application.spa.client_id
}

#-------------------------------------------------------------------------
# Pre-authorize the SPA on the API's access_as_user scope so end users
# don't see a consent prompt at sign-in.
#-------------------------------------------------------------------------
resource "azuread_application_pre_authorized" "spa_on_api" {
  application_id       = azuread_application.api.id
  authorized_client_id = azuread_application.spa.client_id
  permission_ids       = [random_uuid.access_as_user_scope.result]
}

# User flow, Google IDP, Email OTP, and the Microsoft Account / Entra ID
# multi-tenant social providers are configured once in the Azure Portal
# (same out-of-band model as tenant creation itself). See
# docs/runbooks/azure-sso-manual-bootstrap.md.
