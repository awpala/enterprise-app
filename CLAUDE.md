# CLAUDE.md — Enterprise App

**Read [`AGENTS.md`](./AGENTS.md) first — it is the canonical project reference.** It covers the architecture and interaction flow, repository structure, technology stack and versions, development workflow, coding standards, API design, observability, cloud-neutral delivery contract, and Azure/AWS resource mapping.

Those conventions are binding for all work in this repository. Do not duplicate them here; if a convention changes, edit `AGENTS.md`.

This file covers only what is specific to Claude Code.

## Agents

Specialized agents are available in `.claude/agents/` for focused work:

| Agent | File | Scope |
|---|---|---|
| Documentation | `docs.md` | Architecture docs, ADRs, runbooks, README updates |
| Testing | `testing.md` | Unit, integration, contract, and E2E tests |
| Frontend | `frontend.md` | Next.js UI components, routes, API clients, and auth |
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
| Add Terraform Module | `add-terraform-module/` | New Terraform module for an Azure or AWS resource concern |
| Scaffold API Endpoint | `scaffold-api-endpoint/` | New REST endpoint with domain entity, EF config, DTOs, and migration |
| Scaffold Next.js Feature | `scaffold-nextjs-feature/` | New App Router feature with components, API client, and tests |
| Scaffold Data Engine Worker | `scaffold-data-engine-worker/` | Python RabbitMQ lifecycle handling, Pydantic contracts, workflows, and tests |

## Local settings

Claude Code may generate `.claude/settings.local.json` for machine-specific permissions. That file is ignored and must never be committed because command history can contain user identifiers, deployment URLs, or environment-specific resource IDs. No tracked Claude hooks are currently defined.
