# Dev environment variables. Consumed via `terraform apply -var-file=envs/dev.tfvars`.
# subscription_id is NOT set here — it comes from TF_VAR_subscription_id (CI)
# or terraform.tfvars (local-only, gitignored).

project     = "ea"
environment = "dev"
location    = "eastus"
name_suffix = "eadev1"
image_tag   = "latest"

# --- Entra External ID (CIAM) tenant, customer SSO -----------------------
# Populated by a human after the manual tenant-creation step in the Azure
# Portal. Neither value is secret — they identify the tenant but don't
# authenticate anything.
#
# Note: external_tenant_id and tenant_subdomain are NOT secrets. A tenant
# GUID and a tenant subdomain are tenant-level identifiers, not credentials;
# committing them to this file is intentional. They used to flow via
# TF_VAR_* envvars, but -var-file has higher precedence than env vars so
# keeping them here (rather than env vars) is both correct and simpler.
#
# The two related SECRET values — external_tenant_client_id and
# external_tenant_client_secret — are NOT in this file. They flow through
# TF_VAR_* envvars in CI (set via `gh secret set` on the dev Environment)
# and locally via `eval "$(bash docs/runbooks/source-sso-env.sh dev)"`.
external_tenant_id = "a400a39c-97cf-4459-932e-6dfccf2adf1c"
tenant_subdomain   = "eacustomerdev"

# --- Guest-mode failsafe -------------------------------------------------
# Prod-only. Explicit false here so dev deploys never surface the synthetic
# sentinel principal. The paired UI flag ENABLE_GUEST_AUTH is likewise
# forced false for dev in .github/workflows/deploy.yml.
allow_guest_auth = false
