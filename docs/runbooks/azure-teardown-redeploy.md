# Azure teardown and redeploy runbook

This procedure applies only to the Azure Terraform root. AWS state and resources are independent.

## Safety boundary

Do not use `az group delete` or an unreviewed full `terraform destroy` as a cost-control shortcut. The Azure root owns the application resource group plus Entra External ID application objects. A blanket destroy can remove customer identity configuration along with runtime resources.

This runbook does not claim that any resource is currently present, absent, free, or billable. Query the active subscription and Cost Management immediately before acting. Historical spend and free-tier dates are not reliable operating inputs.

Before a destructive command:

1. Verify the active tenant and subscription with `az account show`.
2. Resolve every target from Terraform output, the Azure control plane, or an ignored operator configuration—never from an identifier committed to a public script.
3. Capture a redacted Terraform plan and the current application outputs.
4. Confirm the exact environment and whether its PostgreSQL data, container images, telemetry, and customer identity configuration must be retained.
5. Confirm the remote state container and selected state blob are intact.

## Required operator configuration

The tracked helpers fail fast unless their target identifiers are supplied by the current process. Load these from a password manager, the bootstrap outputs, or another approved ignored configuration source:

```bash
export AZURE_SUBSCRIPTION_ID='<selected subscription>'
export AZURE_DEV_RESOURCE_GROUP='<dev resource group>'
export AZURE_PRODUCTION_RESOURCE_GROUP='<production resource group>'
export AZURE_DEV_KEY_VAULT='<dev Key Vault name>'
export AZURE_PRODUCTION_KEY_VAULT='<production Key Vault name>'
export TFSTATE_RESOURCE_GROUP='<bootstrap output>'
export TFSTATE_STORAGE_ACCOUNT='<bootstrap output>'
export TFSTATE_CONTAINER='<bootstrap output>'

# Only when intentionally deleting registries:
export AZURE_ACR_TARGETS='<registry>:<resource-group> [<registry>:<resource-group> ...]'
```

Do not place populated exports in a tracked file or paste them into documentation.

## Inventory and cost evidence

Use current control-plane evidence rather than the existence of a resource as a proxy for cost:

```bash
az account show --query '{tenant:tenantId,subscription:id,name:name}' --output table
az resource list --query '[].{name:name,type:type,group:resourceGroup,location:location}' --output table
az consumption usage list --start-date <yyyy-mm-dd> --end-date <yyyy-mm-dd> --output table
```

Azure Cost Management data may lag. Record the query window and timestamp with the change record. An empty ACR still has a registry SKU; deleting repositories alone does not remove the registry resource.

## Supported maintenance helpers

| Helper | Mutation | Important limits |
|---|---|---|
| `scripts/az-delete-acr.sh --dry-run` | None | Resolves only the configured registry/resource-group pairs and verifies the active subscription. |
| `scripts/az-delete-acr.sh` | Deletes only the configured ACR resources | Destructive; removes all images in those registries. It does not establish that the remaining Azure run rate is zero. |
| `scripts/az-teardown.sh` | Stops PostgreSQL, asynchronously deletes Container Apps and Application Insights, and deletes ACR repositories in both configured groups | Legacy suspension helper. It does not delete ACR itself, Container Apps Jobs, the Container Apps Environment, Log Analytics, Key Vault, PostgreSQL, state, or identity objects. Some command failures are non-blocking; verify every result. |
| `scripts/az-teardown-check.sh` | None | Checks configured resource groups, selected runtime resources, soft-deleted Key Vault names, state blobs, and current-principal RBAC. It is a targeted verifier, not an exhaustive billing or security audit. |

Every script writes a timestamped log under ignored `/workspace/__logs/`.

## Registry-only suspension

Use this only after current Cost Management evidence shows that deleting the selected registries is the intended action and losing all contained images is accepted.

```bash
./docs/runbooks/scripts/az-delete-acr.sh --dry-run
./docs/runbooks/scripts/az-delete-acr.sh
```

The helper requires the operator to provide the subscription and exact registry targets, skips already-absent registries, and verifies the post-delete subscription inventory. Terraform state is not edited. A later apply refreshes state, recreates the missing ACR, and requires all four images to be rebuilt.

## Legacy runtime suspension

`az-teardown.sh` is retained for the older suspend-and-rebuild workflow. Review its narrow behavior above before use:

```bash
./docs/runbooks/scripts/az-teardown.sh
./docs/runbooks/scripts/az-teardown-check.sh
```

Because deletions are submitted asynchronously and several Azure CLI extension failures are treated as warnings, completion of `az-teardown.sh` is not completion evidence. Use Azure CLI inventory and the verifier log to establish the final state. The verifier returns nonzero while targeted runtime resources remain or bootstrap checks fail.

## Redeploy

The supported redeploy path is the tracked GitHub workflow, not a hand-assembled sequence of `az containerapp update` commands:

1. Run `az-teardown-check.sh` and resolve missing state, soft-delete collisions, or identity failures.
2. Review an authenticated Terraform plan against the exact backend key:

   ```bash
   infra/scripts/deploy.sh plan azure <dev|production>
   ```

3. Confirm that the plan recreates only the intentionally removed resources and does not replace retained PostgreSQL, state, or Entra objects unexpectedly.
4. Push the reviewed application/infrastructure commit or explicitly dispatch `deploy.yml` with `target=azure` and the required environment.
5. Let the Azure adapter recreate ACR first, build all four images through ACR, apply the full stack, run the migrations job, smoke-test the generated origins, and enforce retention.
6. Verify real SSO and a complete model-run lifecycle in the browser. A synthetic dev or guest path is not a substitute for federation acceptance.

Non-`main` pushes target `dev`; `main` targets `production`. The user owns the merge and commit checkpoints.

## Recovery cases

### Missing or wrong state

Stop before apply. Restore the intended version of `dev.tfstate` or `production.tfstate` in the configured Blob container, then rerun the plan. Never import resources opportunistically into an uncertain state key.

### Soft-deleted Key Vault collision

Prefer recovery of the intended vault. Purging is irreversible and requires explicit approval plus exact-name verification:

```bash
az keyvault list-deleted --query '[].{name:name,location:properties.location}' --output table
az keyvault recover --name '<verified-vault-name>'
```

Do not paste the resolved name into this runbook or a tracked script.

### Missing registry or images

Run the normal Azure deployment workflow. Its registry-first phase recreates ACR before ACR remote builds publish the API, migrations, worker, and UI images. Existing Container App revisions may continue temporarily, but any restart or scale event can fail until the images exist again.

### PostgreSQL recovery

Do not delete or replace the server without an approved backup/restore decision. Validate a restore into a separate server before changing the application connection secret. Database migrations are forward-fix by default; do not deploy an older application image blindly after a successful schema migration.

### Identity or OIDC failure

Verify the logical GitHub Environment name (`dev` or `production`), its exact federated credential subject, the repository-level Azure OIDC secrets/backend variables, and the environment-scoped External ID credentials. Use the [Azure SSO runbook](./azure-sso-manual-bootstrap.md); do not create parallel ad hoc app registrations.

## Post-redeploy verification

- GitHub deployment job completed, including migration and smoke-test gates.
- `application_url` serves the Next.js UI over its Azure-generated HTTPS origin.
- `api_url` returns HTTP 200 from `/health/ready`.
- `/api/runtime-config` contains the intended `entra` provider and no secret.
- Google and Email OTP complete real callback, authenticated API, refresh, and logout flows.
- A model run progresses through requested, started, and completed/failed states with timestamps.
- Application Insights and Log Analytics receive the expected backend/platform signals.
- Current Cost Management and resource inventory match the approved post-change state.
