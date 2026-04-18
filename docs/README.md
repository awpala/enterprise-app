# docs — Documentation Index

Architectural decisions, operational runbooks, and cross-cutting references for the Enterprise App. Co-located service docs live in each subproject's own `README.md`; this folder holds everything that isn't tied to a single service.

## Layout

| Folder / File | Purpose |
|---|---|
| `adrs/` | Architecture Decision Records. One file per decision, numbered (`NNNN-slug.md`). |
| `runbooks/` | Operator-facing procedures (bootstrap, verification, rollback) plus the scripts that back them. |
| `summaries/` | Cross-cutting architecture summaries that span multiple services (observability, etc.). |
| `diagrams/` | Exported architecture diagrams when Mermaid isn't expressive enough (png/svg/drawio). |

## Current Contents

### ADRs (`adrs/`)

| ADR | Subject |
|---|---|
| `0001-azure-native-observability.md` | Why Azure Monitor + App Insights (OTel distro) over a vendor-neutral collector stack. |

### Runbooks (`runbooks/`)

| File | Type | Purpose |
|---|---|---|
| `sso-manual-bootstrap.md` | Markdown | Step-by-step Entra External ID bootstrap procedure (click-by-click portal steps plus CLI). |
| `observability.md` | Markdown | How to read App Insights / Log Analytics for this app; common KQL queries. |
| `plan-infra.sh` | Script | Wraps `terraform plan` with the right backend and var-file conventions. |
| `push-sso-secrets.sh` | Script | Pushes bootstrapped SSO client secrets into Key Vault. |
| `sample.push-sso-secrets.sh` | Script | Example values — copy, edit, do not commit the real one. |
| `source-sso-env.sh` | Script | Sourceable helper that exports SSO env vars for the current shell. |
| `validate-sso-snapshot.sh` | Script | Verifies the SSO configuration matches a captured snapshot (Graph query, not portal eyeballing). |
| `verify-deployer-sp.sh` | Script | Confirms the CI deployer service principal has the expected role assignments. |

### Summaries (`summaries/`)

| File | Purpose |
|---|---|
| `observability-logging-summary.md` | Summary of log sinks, correlation strategy, and retention choices. |

## Where to Add New Docs

| If the doc is... | Put it in... |
|---|---|
| A decision that constrains future work | `docs/adrs/NNNN-slug.md` (next number; Title / Status / Context / Decision / Consequences) |
| A procedure an operator will follow | `docs/runbooks/<name>.md` plus any supporting `<name>.sh` beside it |
| A cross-service architecture summary (not a decision, not a procedure) | `docs/summaries/<name>.md` |
| Tied to one service (API, UI, data-engine, infra, deploy) | That service's own `README.md` — not here |
| A diagram | Prefer inline Mermaid in the doc that references it; raster diagrams under `docs/diagrams/` only if Mermaid can't express it |

## Conventions

- ADR format: **Title, Status, Context, Decision, Consequences.**
- Runbook scripts that involve 2+ CLI commands or 5+ shell lines must be tracked here rather than pasted ad-hoc into chat or tickets.
- Portal/UI steps in runbooks are click-by-click explicit: tenant, blade, left-nav, tab, button label, field values, capture destination.
- Verification steps use Graph / CLI queries, not "confirm visually in the portal."
- Present tense, active voice. Define jargon on first use.
