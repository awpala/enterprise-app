# EA.Api — ASP.NET Core .NET 10 REST API

System-of-record for the model domain. Owns the PostgreSQL schema via EF Core, authenticates callers through the deployment-selected OIDC provider, and drives async workflows by publishing versioned messages to RabbitMQ through MassTransit's transactional outbox.

## Solution Layout

| Project | Responsibility |
|---|---|
| `EA.Api` | Web host: controllers, auth wiring, Scalar/OpenAPI, health checks, OpenTelemetry bootstrap |
| `EA.Domain` | Pure domain types and interfaces — no framework or EF references |
| `EA.Infrastructure` | `AppDbContext`, EF configurations + migrations, MassTransit consumers, facades, repositories, audit interceptor, seeding |
| `EA.Contracts` | Shared DTOs and message record types (mirror of `/schemas/` JSON Schemas) |

## Notable Libraries and Their Usage

| Package | Role | Rationale |
|---|---|---|
| `MassTransit.RabbitMQ` + `MassTransit.EntityFrameworkCore` | Messaging + outbox | Transactional consistency between `SaveChanges` and message publish. Avoids dual-write bugs when a DB commit succeeds but the broker publish fails. |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | EF Core provider | First-class Postgres support including `JsonDocument` columns (used for `audit_events.details`). |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | OIDC access-token validation | Validates Entra or Cognito tokens through one normalized configuration contract. |
| `Scalar.AspNetCore` | OpenAPI UI | Modern replacement for Swagger UI; renders the spec produced by `Microsoft.AspNetCore.OpenApi`. |
| OpenTelemetry exporters | Telemetry | Selects Azure Monitor, standard OTLP, or no exporter at deployment time. |
| `AspNetCore.HealthChecks.NpgSql` | Readiness | Backs `/health/ready` with a real DB probe — Container Apps uses this to gate traffic. |

## Architectural Patterns

- **Facade + Repository.** Controllers stay thin; domain orchestration lives in facades (`EA.Infrastructure/Facades/`) that coordinate repositories (`Repositories/`). Keeps EF out of controllers and makes cross-aggregate operations (e.g. model + run + audit) testable.
- **MassTransit outbox.** Message publishes are written to the outbox inside the same EF transaction as domain writes. A background dispatcher drains the outbox — guarantees at-least-once publish after a successful commit.
- **Audit via `SaveChanges` interceptor.** `AuditStampingInterceptor` (see `EA.Infrastructure/Data/Interceptors/`) intercepts every `SaveChanges`, extracts the acting user from `ClaimsPrincipal`, and writes `audit_events` rows (`model.created`, `model.updated`, `model.archived`, `modelrun.requested`). Auditing is impossible to bypass from controllers because it's wired into the EF pipeline.
- **User-context propagation across RabbitMQ.** `UserContextPublishFilter` stamps outgoing messages with identity headers so consumers (and downstream services) can attribute actions without a second auth round-trip.
- **Minimal APIs vs controllers.** Project standard is minimal APIs; controllers (`Controllers/ModelsController.cs`, `RunsController.cs`, `AuditEventsController.cs`) are used where model binding and filter pipelines pay their way. Both return `ProblemDetails` per RFC 9457.
- **Dev auth fallback.** `Auth/DevAuthHandler.cs` and `Auth/GuestAuthHandler.cs` allow unauthenticated local development without turning off the authorisation pipeline. Never enabled outside `Development`.
- **EF Core, no lazy loading.** All navigations loaded explicitly with `Include` or projection.

## Messaging Contracts

Routing keys are versioned (e.g. `model.run.requested.v1`). Every message carries `messageId`, `correlationId`, `occurredAtUtc`. Source of truth is `/schemas/*.json` (JSON Schema Draft 2020-12); the C# record types in `EA.Contracts/` mirror the schema. Consumers live in `EA.Infrastructure/Consumers/` (`ModelRunStartedConsumer`, `ModelRunCompletedConsumer`, `ModelRunFailedConsumer`).

## Migrations

```bash
cd api/src/EA.Infrastructure
dotnet ef migrations add <Name> -s ../EA.Api
dotnet ef migrations script --idempotent -s ../EA.Api -o Migrations/Scripts/{timestamp}_{Name}.sql
```

The `.sql` artifact is committed alongside the `.cs` migration for PR review. The migration bundle runs as an Azure Container Apps Job or AWS ECS one-off task.

## Authentication and observability

- `Authentication:Provider` selects `entra` or `cognito`; authority, audience/client ID, and required scope use the same keys for both.
- `CurrentUser` normalizes `oid`/`sub`, tenant/issuer, and provider claims before domain code sees them.
- `Observability:Exporter` selects `azuremonitor`, `otlp`, or `none`; structured logs use `ILogger<T>` message templates.
- Correlation IDs flow across HTTP and RabbitMQ via OTel context propagation.
- Health endpoints: `/health/live`, `/health/ready`, `/health/startup` — wired to Container Apps or ECS/ALB probes.

## Running Locally

The API is not intended to be run standalone — the outbox requires RabbitMQ and Postgres. Use the full Compose stack (see [`../deploy/README.md`](../deploy/README.md)); the API will be available at `http://localhost:8000` with Scalar at `/scalar/v1`.

## Testing

| Suite | Project | Command |
|---|---|---|
| Unit | `EA.Api.Tests` | `dotnet test api/tests/EA.Api.Tests/` |
| Integration (Testcontainers Postgres + RabbitMQ) | `EA.Api.IntegrationTests` | `dotnet test api/tests/EA.Api.IntegrationTests/` |

Integration tests spin up real Postgres and RabbitMQ containers per run — requires a working Docker socket. They run automatically on PRs and merges to `main` via `ci.yml`.

## Gotchas

- **Don't skip the outbox.** Calling `IBus.Publish` outside an EF transaction bypasses the outbox guarantees. Use `IPublishEndpoint` within a UoW.
- **`audit_events.details` is `jsonb`.** Migration `20260417182133_ChangeAuditDetailsToJsonDocument` moved this from text to `JsonDocument`; serialize with `JsonSerializer.SerializeToDocument` to avoid double-encoding.
- **Seed data runs via `SeedHostedService`.** It's idempotent but only executes in `Development`.
