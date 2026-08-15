# CLAUDE.md — Enterprise App

**Read [`AGENTS.md`](./AGENTS.md) first — it is the canonical project reference.** It covers the architecture and interaction flow, repository structure, technology stack and versions, development workflow (local stack, tests, migrations), coding standards for every language in the repo, API design, observability, the deployment pipeline, and the Azure resource mapping.

Those conventions are binding for all work in this repository. Do not duplicate them here; if a convention changes, edit `AGENTS.md`.

This file covers only what is specific to Claude Code.

## Agents

Specialized agents are available in `.claude/agents/` for focused work:

| Agent | File | Scope |
|---|---|---|
| Documentation | `docs.md` | Architecture docs, ADRs, runbooks, README updates |
| Testing | `testing.md` | Unit, integration, contract, and E2E tests |
| Frontend | `frontend.md` | Angular UI components, services, routing, auth |
| Backend | `backend.md` | ASP.NET Core API, EF Core, MassTransit, domain logic |
| Data Engine | `data-engine.md` | Python data engine, RabbitMQ consumers/producers, computation workflows |
| Database | `database.md` | EF Core migrations, schema design, query optimization |
| Infrastructure | `infrastructure.md` | Terraform, Docker, Compose, CI/CD workflows |
| Review | `review.md` | Code review, PR feedback, standards enforcement |

## Skills

Reusable workflow skills are available in `.claude/skills/` for focused scaffolding:

| Skill | Folder | Scope |
|---|---|---|
| Add EF Migration | `add-ef-migration/` | New EF Core migration with review artifacts |
| Add Integration Test | `add-integration-test/` | Testcontainers-based integration test for an endpoint or consumer |
| Add Message Contract | `add-message-contract/` | RabbitMQ message schema, .NET record, and MassTransit consumer |
| Add GitHub Workflow | `add-github-workflow/` | New GitHub Actions CI/CD workflow |
| Add Docker Service | `add-docker-service/` | New service in Docker Compose |
| Add Terraform Module | `add-terraform-module/` | New Terraform module for an Azure resource concern |
| Scaffold API Endpoint | `scaffold-api-endpoint/` | New REST endpoint with domain entity, EF config, DTOs, and migration |
| Scaffold Angular Feature | `scaffold-angular-feature/` | New Angular feature with component, service, and route |
| Scaffold Data Engine Worker | `scaffold-data-engine-worker/` | New Python RabbitMQ consumer, Pydantic model, workflow, and test stubs |

## Hooks

Session and tool hooks live in `.claude/hooks/`; local permission and environment settings live in `.claude/settings.local.json`.
