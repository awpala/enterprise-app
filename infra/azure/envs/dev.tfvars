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
# TF_VAR_* envvars in CI (set via `gh secret set` on `azure-dev`)
# and locally via `eval "$(bash docs/runbooks/scripts/azure-source-sso-env.sh dev)"`.
external_tenant_id = "a400a39c-97cf-4459-932e-6dfccf2adf1c"
tenant_subdomain   = "eacustomerdev"

# --- Dev synthetic session -----------------------------------------------
# Enables the "Log in as Dev" affordance in deployed dev. The API registers
# a JwtOrDev policy scheme that routes no-Bearer requests to DevAuthHandler.
# Terraform passes the same flag to the API and Next.js runtime. It must be
# false in production.
allow_dev_auth = true

# --- Guest-mode failsafe -------------------------------------------------
# Prod-only. Explicit false here so dev deploys never surface the synthetic
# guest sentinel principal. Terraform passes the same false value to the UI.
allow_guest_auth = false
