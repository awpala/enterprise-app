# Teardown and Redeploy Runbook

Select the provider explicitly before changing infrastructure. There is no default teardown target.

| Target | Procedure |
|---|---|
| Azure | [Azure teardown and redeploy](./azure-teardown-redeploy.md) |
| AWS | [AWS workbook: rollback, restore, and teardown](../workbooks/aws-deployment-workbook.md#12-rollback-restore-and-teardown) |

For either provider, capture Terraform outputs and backups first, run a reviewed destroy plan against `infra/{provider}`, preserve the provider bootstrap/state backend, and confirm that the other provider state is untouched.

> **Azure exception — do not blanket-destroy.** On Azure, a full `terraform destroy`
> or `az group delete` also removes the CIAM directories (which are resources
> inside `ea-dev-rg` / `ea-prod-rg`) and the Entra app registrations in
> `module.entra_external_id.*`. Azure teardown must use targeted deletes; see the
> [Azure runbook](./azure-teardown-redeploy.md). As of 2026-08-15 the Azure cost
> teardown is already complete and the subscription runs at ~$0/mo.
