---
name: add-github-workflow
description: Creates or extends a CI/CD workflow for this project.
disable-model-invocation: true
---

## Inputs

- **Workflow purpose** (e.g., `ci`, `deploy`, `swa-deploy`, `pr-validation`)
- **Triggers** (e.g., `push to main`, `pull_request`, `tag v*.*.*`)
- **Jobs needed** (e.g., `build-api`, `build-ui`, `terraform-plan`, `terraform-apply`)

## What It Produces

1. **Workflow file** at `.github/workflows/{name}.yml`
2. **OIDC permissions** block (`id-token: write`, `contents: read`)
3. **Azure login step** using `azure/login@v2` with OIDC (client-id, tenant-id, subscription-id from secrets)
4. **Job definitions** with proper `needs` dependencies and matrix strategies where applicable

## Conventions Applied

- Pin all third-party actions to a full commit SHA (not just a tag)
- Use `docker/build-push-action@v6` with Buildx and GHA cache (`cache-from: type=gha`)
- Use `docker/metadata-action@v6` for tag/label generation
- Push images only on `main` or tag events (`push: ${{ github.event_name != 'pull_request' }}`)
- Terraform: separate `plan` and `apply` jobs; `apply` requires manual approval via GitHub Environments
- SWA deploy uses `Azure/static-web-apps-deploy` with deployment token
- Add Trivy scan step for container images before push
- Include `terraform fmt -check` and `terraform validate` in PR validation
- Secrets referenced: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_NAME`, `ACR_LOGIN_SERVER`
