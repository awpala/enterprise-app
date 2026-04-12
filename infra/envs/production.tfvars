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
