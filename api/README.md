# EA.Api — ASP.NET Core .NET 10 REST API

System of record for the model domain. Owns the PostgreSQL schema via EF Core, authenticates callers through the deployment-selected OIDC provider, and drives asynchronous workflows by publishing versioned messages to RabbitMQ through MassTransit.

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
| `MassTransit.RabbitMQ` | Messaging | Publishes run requests and consumes worker lifecycle events through durable RabbitMQ exchanges and queues. |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | EF Core provider | First-class Postgres support including `JsonDocument` columns (used for `audit_events.details`). |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | OIDC access-token validation | Validates Entra or Cognito tokens through one normalized configuration contract. |
| `Scalar.AspNetCore` | OpenAPI UI | Modern replacement for Swagger UI; renders the spec produced by `Microsoft.AspNetCore.OpenApi`. |
| OpenTelemetry exporters | Telemetry | Selects Azure Monitor, standard OTLP, or no exporter at deployment time. |
| `AspNetCore.HealthChecks.NpgSql` | Readiness | Backs `/health/ready` with a real DB probe — Container Apps uses this to gate traffic. |

## Architectural Patterns

- **Facade + Repository.** Controllers stay thin; domain orchestration lives in facades (`EA.Infrastructure/Facades/`) that coordinate repositories (`Repositories/`). Keeps EF out of controllers and makes cross-aggregate operations (e.g. model + run + audit) testable.
- **Persist, then publish.** A run is saved before `IPublishEndpoint` publishes its command. The current code does not configure a transactional outbox, so persistence and broker publication are separate operations.
- **Audit via `SaveChanges` interceptor.** `AuditStampingInterceptor` (see `EA.Infrastructure/Data/Interceptors/`) intercepts every `SaveChanges`, extracts the acting user from `ClaimsPrincipal`, and writes `audit_events` rows (`model.created`, `model.updated`, `model.archived`, `modelrun.requested`). Auditing is impossible to bypass from controllers because it's wired into the EF pipeline.
- **User-context propagation across RabbitMQ.** `UserContextPublishFilter` stamps outgoing messages with identity headers so consumers (and downstream services) can attribute actions without a second auth round-trip.
- **Minimal APIs vs controllers.** Project standard is minimal APIs; controllers (`Controllers/ModelsController.cs`, `RunsController.cs`, `AuditEventsController.cs`) are used where model binding and filter pipelines pay their way. Both return `ProblemDetails` per RFC 9457.
- **Synthetic auth fallbacks.** `Auth/DevAuthHandler.cs` supplies the local identity when OIDC is disabled and can be explicitly enabled beside OIDC in a deployed development environment. `Auth/GuestAuthHandler.cs` provides the separately configured guest path. Any deployed use requires explicit risk acceptance and must not substitute for SSO verification.
- **EF Core, no lazy loading.** All navigations loaded explicitly with `Include` or projection.

## Messaging Contracts

Logical contracts are versioned (for example, `model.run.requested.v1`). Every message carries `messageId`, `correlationId`, and `occurredAtUtc`. The source of truth is `/schemas/*.json` (JSON Schema Draft 2020-12); C# records in `EA.Contracts/` mirror those schemas. The current transport uses MassTransit CLR-type fanout exchanges and per-consumer queues rather than dotted AMQP routing keys. Consumers live in `EA.Infrastructure/Consumers/` (`ModelRunStartedConsumer`, `ModelRunCompletedConsumer`, `ModelRunFailedConsumer`).

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
- Health endpoints: `/health/live`, `/health/ready`, `/health/startup` — wired to the selected cloud runtime's probes. Readiness currently checks PostgreSQL; RabbitMQ readiness is not yet registered.

## Running locally

The API requires PostgreSQL and RabbitMQ. Inside `ea-dev-env`, those dependencies are provided by the enclosing environment; run `run-api` and start `run-data-engine` separately so run commands are consumed. The API is available at `http://localhost:8000` with Scalar at `/scalar/v1`. The aliases capture process output and lifecycle metadata under `__logs/local/`.

On a Docker-capable host, use the full Compose stack described in [`../deploy/README.md`](../deploy/README.md). Do not invoke Docker inside `ea-dev-env`.

## Testing

| Suite | Project | Command |
|---|---|---|
| Unit | `EA.Api.Tests` | `dotnet test api/tests/EA.Api.Tests/` |
| Integration (PostgreSQL Testcontainer + MassTransit in-memory harness) | `EA.Api.IntegrationTests` | `dotnet test api/tests/EA.Api.IntegrationTests/` |

Integration tests spin up a real PostgreSQL container and replace RabbitMQ transport with the MassTransit in-memory test harness. They require a working Docker socket for PostgreSQL and run automatically for pull requests and `main` pushes via `ci.yml`; do not run them inside `ea-dev-env`.

## Gotchas

- **Run creation is not transactionally coupled to publication.** A broker publish failure after the database save can leave a pending run without a delivered command. Do not claim outbox guarantees unless the EF outbox is configured, migrated, and covered by recovery tests.
- **`audit_events.details` is `jsonb`.** Migration `20260417182133_ChangeAuditDetailsToJsonDocument` moved this from text to `JsonDocument`; serialize with `JsonSerializer.SerializeToDocument` to avoid double-encoding.
- **Seed data runs via `SeedHostedService`.** It's idempotent but only executes in `Development`.
