output "authority" {
  description = "OIDC authority URL for MSAL (SPA) and Microsoft.Identity.Web (API). Format: https://<subdomain>.ciamlogin.com/<tenant-id>. MSAL / Microsoft.Identity.Web both append /v2.0/.well-known/openid-configuration internally — do NOT pre-append /v2.0 here (causes .../v2.0/v2.0/.well-known/... 404 and silent metadata failure)."
  value       = "https://${lower(var.tenant_subdomain)}.ciamlogin.com/${var.external_tenant_id}"
}

output "tenant_id" {
  description = "External ID tenant ID (passthrough from input)."
  value       = var.external_tenant_id
}

output "api_client_id" {
  description = "Client (application) ID of the API app registration (ea-api-<env>)."
  value       = azuread_application.api.client_id
}

output "api_audience" {
  description = "JwtBearer audience for the API. Identical to api_client_id for v2 tokens."
  value       = azuread_application.api.client_id
}

output "api_scope_uri" {
  description = "Fully-qualified URI of the API's delegated scope — pass to MSAL.loginRedirect({ scopes: [...] })."
  value       = "api://${azuread_application.api.client_id}/access_as_user"
}

output "spa_client_id" {
  description = "Client (application) ID of the SPA app registration (ea-spa-<env>). The UI bundle embeds this as AAD_CLIENT_ID."
  value       = azuread_application.spa.client_id
}
