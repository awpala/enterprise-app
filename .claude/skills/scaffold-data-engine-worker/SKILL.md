---
name: scaffold-data-engine-worker
description: Scaffolds a RabbitMQ lifecycle consumer or producer in the synchronous Python data-engine service with Pydantic contracts, workflow separation, and pytest coverage.
disable-model-invocation: false
---

## Inputs

- **Logical contract name** (for example, `model.run.requested.v1`)
- **MassTransit CLR message type and URN**
- **Direction** (`consume`, `produce`, or `both`)
- **Payload properties**
- **Workflow behavior**

## What It Produces

1. **Pydantic message model** in `data-engine/src/data_engine/models/messages.py` that mirrors the corresponding schema under `schemas/`.
2. **Transport constants** in `data-engine/src/data_engine/topology.py` for the MassTransit fanout exchange, message URN, and consumer queue.
3. **Consumer behavior** under `data-engine/src/data_engine/consumers/` when consuming:
   - validates the MassTransit envelope and payload with Pydantic;
   - delegates numerical work to `workflows/`;
   - uses explicit acknowledgment and bounded prefetch;
   - logs message, correlation, model, and run identifiers;
   - publishes a failure lifecycle event when a validated run cannot complete.
4. **Producer behavior** under `data-engine/src/data_engine/producers/` when producing:
   - emits a MassTransit-compatible JSON envelope;
   - sets the matching message URN;
   - propagates the workflow correlation ID and trace headers;
   - preserves the versioned schema contract.
5. **Pure workflow code** under `data-engine/src/data_engine/workflows/`, with no RabbitMQ or database access.
6. **pytest coverage** under `data-engine/tests/` for valid processing, validation failure, workflow failure, and message acknowledgment behavior.

## Conventions Applied

- Logical contract names use `{domain}.{entity}.{action}.{version}`, such as `model.run.completed.v1`.
- RabbitMQ transport uses the existing MassTransit CLR-type fanout exchange pattern; do not invent routing-key dispatch alongside it.
- Every message carries `messageId`, `correlationId`, and `occurredAtUtc` plus its domain payload.
- Field names stay wire-compatible with the JSON Schemas and .NET records.
- The data engine remains stateless and never accesses PostgreSQL directly.
- OpenTelemetry context is propagated across message headers.
- Use Python 3.11+ typing, standard `logging`, pika, and Pydantic v2; do not convert the service to an unrelated async framework as part of scaffolding.

## Verification

```bash
cd data-engine
.venv/bin/pytest
.venv/bin/ruff check src tests
.venv/bin/pyright
```

Do not invoke Docker inside `ea-dev-env`. Cross-service Testcontainers coverage runs on a Docker-capable host or in GitHub Actions.
