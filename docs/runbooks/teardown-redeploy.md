# Teardown and Redeploy Runbook

Select the provider explicitly before changing infrastructure. There is no default teardown target.

| Target | Procedure |
|---|---|
| Azure | [Azure teardown and redeploy](./azure-teardown-redeploy.md) |
| AWS | [AWS workbook: failure, rollback, and teardown](../workbooks/aws-deployment-workbook.md#10-failure-rollback-and-teardown) |

For either provider, identify the target resources and state first, review the provider-specific teardown procedure, preserve the bootstrap/state needed to deploy again, and confirm that the other provider state is untouched. This portfolio application accepts complete demo data loss; backups and retention are optional, not teardown gates.

> **Azure exception — do not blanket-destroy.** On Azure, a full `terraform destroy`
> or `az group delete` also removes the CIAM directories (which are resources
> inside `ea-dev-rg` / `ea-prod-rg`) and the Entra app registrations in
> `module.entra_external_id.*`. Azure teardown must use targeted deletes; see the
> [Azure runbook](./azure-teardown-redeploy.md). Verify current inventory and
> cost state with its tracked scripts; do not rely on a historical cost claim.
