---
name: add-integration-test
description: Creates a Testcontainers-based integration test for an API endpoint or consumer.
disable-model-invocation: false
---

## Inputs

- **Target** (for example, `POST /api/v1/models/{id}/runs` or `ModelRunCompletedConsumer`)
- **Dependencies needed** (PostgreSQL Testcontainer, MassTransit test harness, or an explicitly justified live RabbitMQ fixture)
- **Scenario description** (e.g., "creating a job persists to DB and publishes message")

## What It Produces

1. **Test class** in `api/tests/EA.Api.IntegrationTests/{Target}Tests.cs`
2. **Shared factory** usage through `Infrastructure/ApiWebApplicationFactory.cs`
3. **WebApplicationFactory** setup with PostgreSQL Testcontainer configuration and the MassTransit test harness
4. **Test methods** following `MethodName_Scenario_ExpectedResult` naming
5. **Assertions** using FluentAssertions

## Conventions Applied

- Use NUnit `[OneTimeSetUp]` and `[OneTimeTearDown]` for factory and container lifecycle.
- Extend `ApiWebApplicationFactory.ConfigureWebHost` only when shared test wiring must change.
- Preserve the factory's current database initialization policy; do not mix `EnsureCreated` and migrations casually.
- Use `HttpClient` from `WebApplicationFactory` for HTTP tests
- Use `AddMassTransitTestHarness` unless the test specifically verifies RabbitMQ transport behavior.
- Clean up test data between tests (transaction rollback or database reset)
- No `Thread.Sleep` — use async polling with timeout
