---
name: add-message-contract
description: Creates a new RabbitMQ message contract with schema, .NET record, and MassTransit consumer.
disable-model-invocation: false
---

## Inputs

- **Message name** (for example, `ModelRunRequested`)
- **Version** (e.g., `v1`)
- **Type** (`command` or `event`)
- **Payload properties** (for example, `ModelRunId: Guid`, `ModelId: Guid`, and lifecycle-specific data)

## What It Produces

1. **JSON Schema** at `schemas/{message-name-kebab}.{version}.schema.json` — Draft 2020-12, includes `messageId`, `correlationId`, `occurredAtUtc` plus payload
2. **C# record** in `api/src/EA.Contracts/Messages/{MessageName}.cs`
3. **API consumer**, when the API consumes the event, in `api/src/EA.Infrastructure/Consumers/{MessageName}Consumer.cs`
4. **Python model, topology constants, and handler changes**, when the data engine consumes or produces the contract
5. **Transport wiring** synchronized between `Program.cs` and `data-engine/src/data_engine/topology.py`

## Conventions Applied

- Logical contract key: `{domain}.{entity}.{action}.{version}` in lowercase dotted format; the current MassTransit/pika bridge transports CLR-type fanout exchanges.
- All messages include `MessageId` (Guid), `CorrelationId` (Guid), `OccurredAtUtc` (DateTimeOffset)
- Consumer state transitions must tolerate duplicate and out-of-order lifecycle delivery.
- Configure retry and outbox behavior explicitly when the handler's side effects require them; do not document nonexistent middleware as already wired.
- JSON Schema and C# record must stay in sync — validate in contract tests
