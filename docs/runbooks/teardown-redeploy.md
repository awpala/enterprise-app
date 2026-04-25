# Teardown & Redeploy Runbook

## Purpose

This document describes the supported, non-destructive workflow to suspend large-line-item billable resources and prepare the project for a fast redeploy in both `dev` and `prod` environments.

## Scope

- Stop or remove runtime resources that incur continuous charges (Postgres compute, Container Apps, App Insights ingestion, ACR image storage).
- This flow intentionally does NOT perform Terraform destroys, Key Vault purges, or Owner-level RBAC changes.

## Prerequisites

- `az` CLI authenticated with an account that can read subscription resources.
- `gh` CLI authenticated (optional) to inspect repository environment secrets.

## General Usage

### Commands

- Initiate cost-suspension (non-destructive, both envs):

```bash
./docs/runbooks/scripts/az-teardown.sh
```

- Verify readiness for redeploy:

```bash
./docs/runbooks/scripts/az-teardown-check.sh
```

### Hot Redeployment

If you need to redeploy quickly after a teardown, follow these minimal steps in order:

- Run the verifier and confirm it exits 0:

```bash
./docs/runbooks/scripts/az-teardown-check.sh
```

- Confirm `dev.tfstate`/`production.tfstate` blobs exist in the bootstrap `tfstate` container and that Key Vault names you expect to reuse are not soft-deleted.

- If the verifier is clean, trigger the deploy by pushing the prepared `main` branch (or trigger the repo's deploy workflow):

```bash
git push origin main
# or: gh workflow run deploy.yml --ref main
```

- Monitor the GitHub Actions deploy job for Terraform apply, image builds, and the migrations job. Redeploy typically completes in ~20–30 minutes.

Notes:
- If a Key Vault name is soft-deleted and you must reuse it immediately, either purge it (Owner) or change the Key Vault name in `infra/envs/*` before running the pipeline.
- If RBAC prevents the pipeline from applying, run the apply using an account with Contributor or Owner on the target subscription or assign the deploy clientId the required role.

#### Dev-specific hot-redeploy

When performing a hot redeploy for **dev** (frequent, low-risk), follow these targeted steps to minimize friction:

- Run the verifier and confirm it exits 0 for `dev`.

	```bash
	./docs/runbooks/scripts/az-teardown-check.sh
	```

- Confirm `dev.tfstate` is present in the bootstrap `tfstate` container. If missing, restore the `dev.tfstate` blob before proceeding.

- Verify the dev Key Vault name `ea-dev-kv-eadev1` is not soft-deleted. If it is and you must reuse the name immediately, either:
	- Purge (Owner):

		```bash
		az keyvault purge --name ea-dev-kv-eadev1 --location <region>
		```

	- Or edit `infra/envs/dev.tfvars` to a temporary vault name and run the deploy.

- Confirm CI deploy identity for dev (with appropriate clientId) has Contributor on `ea-dev-rg`, or run the deploy with an account that does.

- Ensure GitHub Environment `dev` contains the required External-ID SSO secrets. Use `docs/runbooks/scripts/push-sso-secrets.sh dev` if you have the values and `gh` authenticated.

- Trigger the deploy (push `main` or run the workflow for dev), and watch the Actions job for Terraform apply and the migrations job. If anything fails, collect the latest `__logs/az-teardown-check__*.log` and Action logs for troubleshooting.

This dev-focused checklist is intentionally prescriptive so you can run a fast redeploy with minimal escalation.

## Miscellany

### What is retained

- `infra/bootstrap/` (remote state backend and OIDC SP) — required for redeploy; do not delete.
- Resource groups, Key Vault metadata, CIAM identities, and integration settings are preserved by the teardown flow.

### Verifier checks (summary)

- Key Vault soft-delete: detects soft-deleted vaults that block name reuse. To purge (Owner):

```bash
az keyvault purge --name ea-dev-kv-eadev1 --location <region>
```

- TFState & storage: confirms bootstrap storage account, `tfstate` container, and presence of `dev.tfstate` and `production.tfstate` blobs.

- Deploy identities (informational): lists role assignments for the CI deploy client IDs and reports whether Owner/Contributor roles appear. Role-read operations may require Owner privileges; missing role reads are informational and do not block the verifier.

- GitHub/OIDC: checks `gh` authentication and reports repository remote; it does not change secrets.

### Dev hot-redeploy checklist

- Confirm `dev.tfstate` exists in the bootstrap `tfstate` container.
- Ensure the dev deploy clientId has Contributor role on `ea-dev-rg` or the subscription, or run the deploy with an account that does.
- Verify GitHub Environment `dev` contains the External-ID SSO secrets required by the pipeline (use `docs/runbooks/scripts/push-sso-secrets.sh` if you have the values and `gh` authenticated).

### Recovery actions

- Key Vault name collision: purge the soft-deleted vault (Owner) or change the Key Vault name in `infra/envs/dev.tfvars` and re-run.
- Missing tfstate: restore the blob to the `tfstate` container before running CI apply.
- Permission errors: assign Contributor to the deploy clientId or run the pipeline with an Owner account to capture detailed logs.

### Destructive commands (Owner only)

Use with caution and Owner privileges:

```bash
az postgres flexible-server delete --name <name> --resource-group <rg> --yes
az monitor app-insights component delete --app <name> -g <rg> --yes
az acr repository delete -n <registry> --repository <repo> --yes
az acr delete --name <registry> --resource-group <rg> --yes
```

### Logs

- Scripts write timestamped logs to `/workspace/__logs/`.
