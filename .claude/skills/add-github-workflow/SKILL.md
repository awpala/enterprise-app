---
name: add-github-workflow
description: Creates or extends a CI/CD workflow for this project.
disable-model-invocation: true
---

## Inputs

- **Workflow purpose** (for example, `ci`, `deploy`, or `cleanup-images`)
- **Triggers** (`push`, `pull_request`, or `workflow_dispatch`)
- **Jobs needed** (for example, unit checks, portable container builds, provider validation, or deployment adapters)

## What It Produces

1. **Workflow file** at `.github/workflows/{name}.yml`
2. **Least-privilege permissions**; deployment jobs that authenticate to a provider include `id-token: write` and `contents: read`
3. **Provider login step**, when needed, using Azure workload identity or an AWS role assumed through GitHub OIDC
4. **Job definitions** with proper `needs` dependencies and matrix strategies where applicable

## Conventions Applied

- Follow the action-version policy already used by neighboring workflows and update related workflows consistently.
- Use the repository's provider build scripts and immutable image-tag convention instead of creating an independent image path.
- Non-`main` deployment pushes target `dev`; `main` targets `production`; documentation-only paths do not deploy.
- Deployment workflows use protected logical GitHub Environments and explicit provider selection.
- Build the same four portable images: API, migrations, data engine, and standalone Next.js UI.
- Keep `terraform fmt -check` and `terraform validate` symmetric across both provider roots and bootstraps.
- Keep provider credentials and state coordinates in environment-scoped variables/secrets
- Preserve `.github/workflows/deploy.yml` as the only deployment entry point; provider workflows remain reusable adapters.
