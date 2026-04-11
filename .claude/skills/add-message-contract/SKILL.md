---
name: add-message-contract
description: Creates a new RabbitMQ message contract with schema, .NET record, and MassTransit consumer.
disable-model-invocation: false
---

## Inputs

- **Message name** (e.g., `AnalysisJobRequested`)
- **Version** (e.g., `v1`)
- **Type** (`command` or `event`)
- **Payload properties** (e.g., `JobId: Guid, DatasetId: Guid, Parameters: object?`)

## What It Produces

1. **JSON Schema** at `schemas/{message.name.dotted}.{version}.json` — Draft 2020-12, includes `messageId`, `correlationId`, `occurredAtUtc` plus payload
2. **C# record** in `api/src/Demo.Contracts/Messages/{MessageName}{Version}.cs`
3. **MassTransit consumer** (if event/command is consumed by API) in `api/src/Demo.Infrastructure/Consumers/{MessageName}{Version}Consumer.cs`
4. **Consumer registration** added to MassTransit config in `Program.cs`
5. **Receive endpoint** with retry policy and in-memory outbox

## Conventions Applied

- Routing key: `{domain}.{entity}.{action}.{version}` in lowercase dotted format
- All messages include `MessageId` (Guid), `CorrelationId` (Guid), `OccurredAtUtc` (DateTimeOffset)
- Consumer must be idempotent (check for duplicate `MessageId`)
- Use `UseMessageRetry(r => r.Interval(3, TimeSpan.FromSeconds(5)))` by default
- Use `UseInMemoryOutbox()` on receive endpoints
- JSON Schema and C# record must stay in sync — validate in contract tests
