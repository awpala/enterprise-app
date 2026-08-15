# docs — Documentation Index

Architectural decisions, operational runbooks, and cross-cutting references for the Enterprise App. Co-located service docs live in each subproject's own `README.md`; this folder holds everything that isn't tied to a single service.

## Layout

| Folder / File | Purpose |
|---|---|
| `adrs/` | Architecture Decision Records. One file per decision, numbered (`NNNN-slug.md`). |
| `runbooks/` | Operator-facing procedures (bootstrap, verification, rollback) plus the scripts that back them. |
| `summaries/` | Cross-cutting architecture summaries that span multiple services (observability, etc.). |
| `diagrams/` | Reviewable Mermaid sources and exported diagrams shared by more than one document. |

## Current Contents

### ADRs (`adrs/`)

| ADR | Subject |
|---|---|
| `0001-azure-native-observability.md` | Historical Azure Monitor observability decision, superseded in application scope by ADR 0003. |
| `0002-aws-peer-architecture.md` | AWS service mapping and account-backed production gates. |
| `0003-multicloud-application-generalization.md` | Peer infrastructure layout, Next.js runtime, normalized auth, and telemetry contracts. |
| `0004-aws-generated-https-origin.md` | CloudFront generated hostname and the explicit no-custom-domain decision. |

### Runbooks (`runbooks/`)

| File | Type | Purpose |
|---|---|---|
| `sso-bootstrap.md` | Markdown | Provider-selection entry point for customer SSO bootstrap. |
| `observability.md` | Markdown | Provider-neutral signals and adapter selection. |
| `teardown-redeploy.md` | Markdown | Provider-selection entry point for teardown and recovery. |
| `azure-sso-manual-bootstrap.md` | Markdown | Step-by-step Entra External ID bootstrap procedure (click-by-click portal steps plus CLI). |
| `azure-observability.md` | Markdown | Azure Monitor/App Insights adapter operations and KQL queries. |
| `aws-deployment.md` | Markdown | Short AWS operational sequence and rollback entry point. |
| `azure-teardown-redeploy.md` | Markdown | Azure-specific safe suspension, redeploy, and recovery boundaries. |
| `scripts/az-delete-acr.sh` | Script | Subscription-verified deletion of explicitly configured Azure registries. |
| `scripts/az-teardown.sh` | Script | Legacy runtime-suspension helper for explicitly configured Azure resource groups. |
| `scripts/az-teardown-check.sh` | Script | Read-only Azure suspension/state readiness verifier. |
| `scripts/azure-plan-infra.sh` | Script | Wraps an Azure Terraform plan with its backend and var-file conventions. |
| `scripts/sample.azure-push-sso-secrets.sh` | Script | Example Azure environment values—copy to the ignored provider-named file and populate locally. |
| `scripts/azure-source-sso-env.sh` | Script | Sourceable Azure helper that exports External ID Terraform values. |
| `scripts/azure-validate-sso-snapshot.sh` | Script | Verifies an Azure SSO configuration against a captured snapshot. |
| `scripts/azure-verify-deployer-sp.sh` | Script | Confirms the Azure deployer service principal permissions. |

### Summaries (`summaries/`)

| File | Purpose |
|---|---|
| `observability-logging-summary.md` | Summary of log sinks, correlation strategy, and retention choices. |

### Workbooks (`workbooks/`)

| File | Purpose |
|---|---|
| `aws-deployment-workbook.md` | Comprehensive AWS prerequisites, service parity, CLI deployment, evidence, recovery, and production-readiness gates. |

### Diagrams (`diagrams/`)

| File | Purpose |
|---|---|
| `application-architecture.mmd` | Source copy of the cloud-neutral runtime and delivery diagram rendered in the root README. |

## Where to Add New Docs

| If the doc is... | Put it in... |
|---|---|
| A decision that constrains future work | `docs/adrs/NNNN-slug.md` (next number; Title / Status / Context / Decision / Consequences) |
| A procedure an operator will follow | `docs/runbooks/<name>.md` plus any supporting `<name>.sh` beside it |
| A cross-service architecture summary (not a decision, not a procedure) | `docs/summaries/<name>.md` |
| Tied to one service (API, UI, data-engine, infra, deploy) | That service's own `README.md` — not here |
| A diagram | Prefer inline Mermaid in the document that explains it; keep a `.mmd` source under `docs/diagrams/` when the diagram is reused or independently rendered |

## Conventions

- ADR format: **Title, Status, Context, Decision, Consequences.**
- Runbook scripts that involve 2+ CLI commands or 5+ shell lines must be tracked here rather than pasted ad-hoc into chat or tickets.
- Keep CLI-amenable operations in tracked, idempotent scripts. Reserve portal/UI steps for one-time provider operations with no supported CLI equivalent.
- Portal/UI exceptions are explicit about the tenant/account, navigation path, field purpose, and safe capture destination.
- Verification steps use Graph / CLI queries, not "confirm visually in the portal."
- Present tense, active voice. Define jargon on first use.
- Never commit account IDs, subscription IDs, tenant IDs, application IDs, generated deployment URLs, personal email addresses, tokens, or populated secret templates. Use named placeholders and query commands.
