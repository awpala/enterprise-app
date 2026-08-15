# Teardown and Redeploy Runbook

Select the provider explicitly before changing infrastructure. There is no default teardown target.

| Target | Procedure |
|---|---|
| Azure | [Azure teardown and redeploy](./azure-teardown-redeploy.md) |
| AWS | [AWS workbook: rollback, restore, and teardown](../workbooks/aws-deployment-workbook.md#12-rollback-restore-and-teardown) |

For either provider, capture Terraform outputs and backups first, run a reviewed destroy plan against `infra/{provider}`, preserve the provider bootstrap/state backend, and confirm that the other provider state is untouched.
