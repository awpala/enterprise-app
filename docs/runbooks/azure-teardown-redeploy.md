# Azure Teardown and Redeploy Runbook

> **Scope note:** this runbook covers the **Azure** delivery path only. The AWS
> path is independent and is documented in [`aws-deployment.md`](./aws-deployment.md);
> nothing here applies to it.

## Current state (as of 2026-08-15)

**Azure cost teardown is complete. Expected run-rate is ~$0/mo.**

Both Container Registries (`eadevacreadev1`, `eaprodacreaprd1`) were deleted on
2026-08-15 via [`scripts/az-delete-acr.sh`](./scripts/az-delete-acr.sh). They were
the *only* billing line on the subscription, so their removal is the full cost
teardown. Everything else was deliberately retained and still exists.

Measured from the Cost Management API immediately before deletion:

| Period | Total | Breakdown |
|---|---|---|
| July 2026 | **$5.16** | prod ACR $5.16; every other service line $0.00 |
| Aug 1–15 2026 | **$2.43** | prod ACR $2.42, dev ACR $0.01; all else $0.00 |

Retained and confirmed present after teardown (all $0):

- Both resource groups, `ea-dev-rg` and `ea-prod-rg`
- Both CIAM directories, `eacustomerdev` / `eacustomerprod` — **these live inside the resource groups**
- Entra app registrations and service principals (`module.entra_external_id.*`)
- Both Key Vaults, both Postgres flexible servers, all six Container Apps and
  two jobs, both Container Apps environments, Log Analytics, App Insights,
  workbooks, Static Web Apps (Free SKU), managed identities
- The bootstrap tfstate storage account `eatfstateeaboot`, with both
  `dev.tfstate` and `production.tfstate` blobs intact

### Latent costs to watch

1. **Postgres free-tier expiry.** Both flexible servers (`Standard_B1ms`, 32 GB)
   were created 2026-04-12. The 12-month free allowance lapses ~2026-04-12, after
   which both begin billing. Delete them before then if the project is still dormant.
2. **Cost-reporting lag on dev.** The dev stack was created 2026-08-15 ~10:30 UTC
   and Cost Management lags 24–48h, so dev's steady-state was not observable at
   teardown time. Re-check that dev Container Apps hold at $0.

## Purpose

This document describes two distinct workflows:

- **Full cost teardown** (`az-delete-acr.sh`) — take Azure spend to ~$0 while
  preserving every identity, config, and state artifact needed for a later relaunch.
- **Cost suspension + fast redeploy** (`az-teardown.sh`, `az-teardown-check.sh`) —
  the older hot-redeploy-oriented flow.

## Scope

- Remove or suspend resources that incur charges, and prepare for redeploy.
- This flow intentionally does NOT perform Terraform destroys, Key Vault purges,
  or Owner-level RBAC changes.

> **Never run `az group delete` on `ea-dev-rg` or `ea-prod-rg`.** The CIAM
> directories are resources *inside* those groups; deleting a group destroys the
> customer identity tenants. For the same reason, do not run a plain
> `terraform destroy` — state includes `module.entra_external_id.*` (app
> registrations and service principals) and `azurerm_resource_group.this`.
> Use targeted deletes, as `az-delete-acr.sh` does.

## Choosing a script

| Script | Does | Use when |
|---|---|---|
| `az-delete-acr.sh` | Deletes both container registries. This is the **complete cost teardown** — registries were the only billing line. | Going dormant; want $0 spend and don't need instant redeploy. |
| `az-teardown.sh` | Stops Postgres, deletes Container Apps and App Insights, deletes ACR **repositories**. | Legacy flow — see the caveat below before relying on it. |
| `az-teardown-check.sh` | Read-only verifier for redeploy readiness (tfstate blobs, Key Vault soft-delete, deploy identities). | Before any redeploy. |

> **Caveat on `az-teardown.sh`:** it deletes ACR *repositories* but not the
> *registry*. ACR Basic charges a flat SKU fee independent of stored size, and
> both registries sat at ~0.28 GiB against a 10 GiB included allowance — so that
> path deleted the hot-redeploy images while saving $0/mo. It also stops Postgres
> and deletes Container Apps and App Insights, none of which were billing anything.
> Prefer `az-delete-acr.sh` when the goal is cost. Note that `az postgres` and
> `az monitor` command modules fail to load on some CLI builds (including the
> project devcontainer), which silently no-ops those steps.

## Prerequisites

- `az` CLI authenticated with an account that can read subscription resources.
- `gh` CLI authenticated (optional) to inspect repository environment secrets.

## General Usage

### Commands

- Full cost teardown — delete both registries, take spend to ~$0 (both envs):

```bash
./docs/runbooks/scripts/az-delete-acr.sh --dry-run   # preview, changes nothing
./docs/runbooks/scripts/az-delete-acr.sh             # execute
```

  The script verifies the active subscription before acting, skips registries
  that are already gone (safe to re-run, exits 0), and verifies afterward that
  no registries remain.

- Initiate cost-suspension, legacy flow (see caveat above):

```bash
./docs/runbooks/scripts/az-teardown.sh
```

- Verify readiness for redeploy:

```bash
./docs/runbooks/scripts/az-teardown-check.sh
```

### Redeploying after a full cost teardown

Because `az-delete-acr.sh` deletes the registries, redeploy is **not** a hot
restart — the registry must be recreated and images rebuilt and pushed. Terraform
handles the registry itself: both registries remain in state as
`module.acr.azurerm_container_registry.this`, and no `terraform state rm` was
performed, so the next `terraform apply` refreshes, observes the registry is
gone, and plans to recreate it.

Sequence:

1. Run `az-teardown-check.sh` and confirm it exits 0.
2. `terraform apply` for the target env — recreates the ACR.
3. Build and push `ea-api`, `ea-data-engine`, and `ea-migrations` images to the
   new registry. The Container Apps and jobs still exist and reference these
   image names; they cannot pull until the images are back.
4. Run the migrations job, then restart the Container Apps so they pull fresh images.

Existing Container App replicas kept running after registry deletion, but any
restart or scale event will fail to pull until step 3 completes.

### Hot Redeployment (after `az-teardown.sh` only)

If you need to redeploy quickly after a legacy cost-suspension, follow these minimal steps in order:

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
- If a Key Vault name is soft-deleted and you must reuse it immediately, either purge it (Owner) or change the Key Vault name in `infra/azure/envs/*` before running the pipeline.
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

	- Or edit `infra/azure/envs/dev.tfvars` to a temporary vault name and run the deploy.

- Confirm CI deploy identity for dev (with appropriate clientId) has Contributor on `ea-dev-rg`, or run the deploy with an account that does.

- Ensure GitHub Environment `azure-dev` contains the required External-ID SSO secrets. Use `docs/runbooks/scripts/azure-push-sso-secrets.sh dev` if you have the values and `gh` authenticated.

- Trigger the deploy (push `main` or run the workflow for dev), and watch the Actions job for Terraform apply and the migrations job. If anything fails, collect the latest `__logs/az-teardown-check__*.log` and Action logs for troubleshooting.

This dev-focused checklist is intentionally prescriptive so you can run a fast redeploy with minimal escalation.

## Miscellany

### What is retained

- `infra/azure/bootstrap/` (remote state backend and OIDC SP) — required for redeploy; do not delete.
- Resource groups, Key Vault metadata, CIAM identities, and integration settings are preserved by both teardown flows.
- After the full cost teardown, the only thing actually removed is the two
  registries and the container images they held. See
  [Current state](#current-state-as-of-2026-08-15) for the verified inventory.

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
- Verify GitHub Environment `azure-dev` contains the External-ID SSO secrets required by the pipeline (use `docs/runbooks/scripts/azure-push-sso-secrets.sh` if you have the values and `gh` authenticated).

### Recovery actions

- Key Vault name collision: purge the soft-deleted vault (Owner) or change the Key Vault name in `infra/azure/envs/dev.tfvars` and re-run.
- Missing tfstate: restore the blob to the `tfstate` container before running CI apply.
- Permission errors: assign Contributor to the deploy clientId or run the pipeline with an Owner account to capture detailed logs.

### Destructive commands (Owner only)

Use with caution and Owner privileges. Prefer `az-delete-acr.sh` over the raw
`az acr delete` calls — it does subscription verification, preview, and post-checks.

```bash
az acr delete --name <registry> --resource-group <rg> --yes          # stops ACR billing
az acr repository delete -n <registry> --repository <repo> --yes     # images only, saves $0
az postgres flexible-server delete --name <name> --resource-group <rg> --yes
az monitor app-insights component delete --app <name> -g <rg> --yes
```

**Never** run these against `ea-dev-rg` / `ea-prod-rg` — both destroy the CIAM
directories and Entra app registrations:

```bash
az group delete --name <rg> --yes     # DESTROYS the CIAM directory in that group
terraform destroy                     # DESTROYS module.entra_external_id.* + the RG
```

If Postgres is later deleted at free-tier expiry, delete only the two flexible
servers by name; do not widen it to the resource group.

### Logs

- Scripts write timestamped logs to `/workspace/__logs/`.
