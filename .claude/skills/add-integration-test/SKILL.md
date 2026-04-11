---
name: add-integration-test
description: Creates a Testcontainers-based integration test for an API endpoint or consumer.
disable-model-invocation: false
---

## Inputs

- **Target** (e.g., `POST /api/v1/analysis-jobs` or `AnalysisJobRequestedV1Consumer`)
- **Dependencies needed** (`postgres`, `rabbitmq`, or both)
- **Scenario description** (e.g., "creating a job persists to DB and publishes message")

## What It Produces

1. **Test class** in `api/tests/Demo.Api.IntegrationTests/{Target}Tests.cs`
2. **Shared fixture** usage (`IntegrationFixture` with Testcontainers for Postgres + RabbitMQ)
3. **WebApplicationFactory** setup with overridden connection strings pointing to containers
4. **Test methods** following `MethodName_Scenario_ExpectedResult` naming
5. **Assertions** using FluentAssertions

## Conventions Applied

- Use `IClassFixture<IntegrationFixture>` for container lifecycle
- Override `ConfigureWebHost` to point connection strings at Testcontainers
- Apply EF migrations in test setup (`context.Database.Migrate()`)
- Use `HttpClient` from `WebApplicationFactory` for HTTP tests
- For MassTransit tests, use the test harness (`AddMassTransitTestHarness`)
- Clean up test data between tests (transaction rollback or database reset)
- No `Thread.Sleep` — use async polling with timeout