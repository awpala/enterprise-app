# Dev environment variables. Consumed via `terraform apply -var-file=envs/dev.tfvars`.
# subscription_id is NOT set here — it comes from TF_VAR_subscription_id (CI)
# or terraform.tfvars (local-only, gitignored).

project     = "ea"
environment = "dev"
location    = "eastus"
name_suffix = "eadev1"
image_tag   = "latest"
