---
name: add-github-workflow
description: Creates or extends a CI/CD workflow for this project.
disable-model-invocation: true
---

## Inputs

- **Workflow purpose** (e.g., `ci`, `deploy-azure`, `deploy-aws`, `pr-validation`)
- **Triggers** (e.g., `push to main`, `pull_request`, `tag v*.*.*`)
- **Jobs needed** (e.g., `build-api`, `build-ui`, `terraform-plan`, `terraform-apply`)

## What It Produces

1. **Workflow file** at `.github/workflows/{name}.yml`
2. **OIDC permissions** block (`id-token: write`, `contents: read`)
3. **Provider login step** using Azure workload identity or an AWS role assumed through GitHub OIDC
4. **Job definitions** with proper `needs` dependencies and matrix strategies where applicable

## Conventions Applied

- Pin all third-party actions to a full commit SHA (not just a tag)
- Use `docker/build-push-action@v6` with Buildx and GHA cache (`cache-from: type=gha`)
- Use `docker/metadata-action@v6` for tag/label generation
- Push images only on `main` or tag events (`push: ${{ github.event_name != 'pull_request' }}`)
- Terraform: separate `plan` and `apply` jobs; `apply` requires manual approval via GitHub Environments
- Build the Next.js standalone image with the other application containers
- Add Trivy scan step for container images before push
- Include `terraform fmt -check` and `terraform validate` in PR validation
- Keep provider credentials and state coordinates in environment-scoped variables/secrets
