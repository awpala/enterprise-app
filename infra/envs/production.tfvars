# Production environment variables. Consumed via `terraform apply -var-file=envs/production.tfvars`.
# subscription_id is NOT set here — it comes from TF_VAR_subscription_id (CI)
# or terraform.tfvars (local-only, gitignored).
#
# NOTE: environment is "prod" (not "production") to keep generated resource
# names under Azure length limits. The GitHub Environment is still
# named "production" (that's how the OIDC federated credential matches).

project     = "ea"
environment = "prod"
location    = "eastus"
name_suffix = "eaprd1"
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
# TF_VAR_* envvars in CI (set via `gh secret set` on the production Environment)
# and locally via `eval "$(bash docs/runbooks/source-sso-env.sh production)"`.
external_tenant_id = "8ce01097-ed0b-4425-a49a-2f42c41a1119"
tenant_subdomain   = "eacustomerprod"

# --- Dev synthetic session -----------------------------------------------
# Deployed-dev only. Explicit false in prod so the dev sentinel principal
# is never reachable in production.
allow_dev_auth = false

# --- Guest-mode failsafe -------------------------------------------------
# Prod-only demo/prospecting affordance. Surfaces AzureAd__AllowGuest=true
# on the API container so a synthetic sentinel guest principal (full r/w,
# no CIAM, no scope-down) is honored. Paired with ENABLE_GUEST_AUTH=true
# on the UI build (set in .github/workflows/deploy.yml on main).
allow_guest_auth = true
