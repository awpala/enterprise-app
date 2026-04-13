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
# - Single-page-application platform (triggers PKCE + implicit-less auth
#   code flow in MSAL.js v3).
# - Each entry in single_page_application.redirect_uris does double duty:
#     1. As an MSAL `redirectUri` target at login. In practice only the
#        `/auth/redirect` variants are navigated to on the return leg of
#        loginRedirect() (that's the path MSAL is configured with in the
#        SPA's auth config).
#     2. As a valid `postLogoutRedirectUri` target at sign-out. External
#        ID validates the `post_logout_redirect_uri` query param against
#        the same registered redirect URI list — so the origin root MUST
#        be registered here for logoutRedirect() to return cleanly.
#        MSAL.js sets postLogoutRedirectUri = window.location.origin
#        (i.e. no path), which is why the bare SWA FQDN and
#        http://localhost:4200 appear alongside their `/auth/redirect`
#        siblings. Omitting the origin root is what caused the sign-out
#        redirect loop.
# - required_resource_access wires the SPA up with the API's
#   access_as_user delegated scope so MSAL can request it at sign-in.
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
  # that has no path segment. The origin-root entries below are written as
  # `<origin>/` for that reason. MSAL's `postLogoutRedirectUri` must match
  # exactly, so the SPA auth config uses `window.location.origin + '/'` to
  # align with the registered value.
  single_page_application {
    redirect_uris = [
      "${var.swa_url}/",
      "${var.swa_url}/auth/redirect",
      "http://localhost:4200/",
      "http://localhost:4200/auth/redirect",
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
# docs/runbooks/sso-manual-bootstrap.md.
