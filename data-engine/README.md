# Data Engine — Python 3.11+ Async Worker

Companion service to the API. Consumes `model.run.*` commands from RabbitMQ, executes numerical workflows, and publishes lifecycle events (`started`, `completed`, `failed`) back to the broker. Has no direct database access — it is deliberately stateless and driven entirely by messages.

## Notable Libraries and Their Usage

| Package | Role | Rationale |
|---|---|---|
| `pika` | RabbitMQ client | Low-level AMQP 0-9-1 client; explicit about channels, acks, and prefetch — no magic, easy to reason about at-least-once semantics. |
| `pydantic` 2 | Message models | Validates inbound payloads against the shared JSON Schema contracts. Rejects malformed messages at the edge. |
| `pydantic-settings` | Config | `RABBITMQ_*` / app env vars parsed and typed on startup — fails fast on misconfiguration. |
| `numpy` 2 + `scipy` 1.14+ | Numerical core | Workflow computations (histograms, metrics) live in `workflows/`. |
| `azure-monitor-opentelemetry` | Telemetry | Same App Insights sink as the .NET API — preserves correlation across the MQ boundary. |
| `opentelemetry-instrumentation-pika` | Trace propagation | Extracts the `traceparent` header from AMQP properties so a single run shows up as one distributed trace spanning API → broker → engine → broker → API. |

Dev-only: `pytest` + `pytest-cov` for tests, `ruff` for lint, `pyright` (standard mode) for types.

## Architectural Patterns

- **Topology-first wiring.** `topology.py` declares exchanges, queues, routing keys, and DLQ bindings in one place; `main.py` constructs the runtime from it. Adding a new message type is a localised edit, not a scavenger hunt.
- **Consumer / workflow / producer split.**
  - `consumers/` — pika plumbing (ack, nack, retry, DLQ).
  - `workflows/` — pure functions over validated Pydantic models. Easy to unit-test without a broker.
  - `producers/` — outbound publish helpers that stamp `messageId`, `correlationId`, `occurredAtUtc`.
- **Pydantic-validated contracts.** `models/messages.py` mirrors `/schemas/*.json` (JSON Schema Draft 2020-12). Schemas in the repo are the source of truth; Python models are kept in lockstep.
- **Standard typing mode, not strict.** `pyright` runs in `standard` mode — scientific libraries don't always have clean stubs, so strict mode produces more noise than signal.
- **Python 3.11+ typing syntax.** `list[T]`, `dict[K, V]`, and PEP 604 unions (`X | None`) are used directly. Do **not** add `from __future__ import annotations`.

## Project Structure

| Path | Purpose |
|---|---|
| `src/data_engine/main.py` | Entry point — constructs the consumer loop from `topology.py` |
| `src/data_engine/topology.py` | Exchange / queue / routing-key declarations |
| `src/data_engine/config.py` | `pydantic-settings` configuration object |
| `src/data_engine/consumers/` | pika consumers (e.g. `model_run_consumer.py`) |
| `src/data_engine/producers/` | Outbound publish helpers (e.g. `model_run_producer.py`) |
| `src/data_engine/workflows/` | Pure computation (e.g. `model_metrics.py`) |
| `src/data_engine/models/` | Pydantic message models |

## Running Locally

The engine requires RabbitMQ — run the full stack via [`../deploy/README.md`](../deploy/README.md). For isolated iteration:

```bash
cd data-engine
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
RABBITMQ_HOST=localhost python -m data_engine.main
```

## Testing

```bash
cd data-engine && pytest
```

Tests under `tests/` target the `workflows/` layer directly without a broker. Consumer-level contract tests are covered by the API's Testcontainers integration suite.

## Gotchas

- **Prefetch matters.** pika consumers set a bounded prefetch so a single slow run doesn't starve the other queues. Don't raise it without thinking about DLQ behaviour.
- **At-least-once, not exactly-once.** Workflows must be idempotent with respect to `messageId` / `correlationId`. The API side reconciles by run ID.
- **Azure Monitor exporter needs `APPLICATIONINSIGHTS_CONNECTION_STRING`.** Absent in local dev — the engine falls back to stdout logging.
