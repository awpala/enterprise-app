---
name: scaffold-data-engine-worker
description: Scaffolds a new RabbitMQ consumer worker in the Python data-engine service, including Pydantic message model, consumer handler, producer helper, and pytest test stubs.
disable-model-invocation: false
---

## Inputs

- **Message name** (e.g., `AnalysisJobRequested`)
- **Version** (e.g., `v1`)
- **Direction** (`consume`, `produce`, or `both`)
- **Payload properties** (e.g., `job_id: UUID, dataset_id: UUID, parameters: dict | None`)
- **Workflow description** (brief description of the computation or processing the worker performs)

## What It Produces

1. **Pydantic message model** at `data-engine/src/data_engine/models/{message_name_snake}_{version}.py`
   - Mirrors the JSON Schema in `schemas/`
   - Includes `message_id`, `correlation_id`, `occurred_at_utc` plus payload fields
   - Uses `model_validate_json()` for deserialization

2. **Consumer handler** at `data-engine/src/data_engine/consumers/{message_name_snake}_{version}_consumer.py` (if `consume` or `both`)
   - Async `handle(body: bytes, correlation_id: str) -> None` function
   - Validates message via Pydantic before processing
   - Delegates to a workflow function in `workflows/`
   - Structured log entries at start, completion, and on error
   - OpenTelemetry span wrapping the handler body

3. **Workflow module** at `data-engine/src/data_engine/workflows/{message_name_snake}_{version}_workflow.py`
   - Pure computation / processing function, no I/O side-effects
   - Type-annotated inputs and output
   - Docstring describing what the workflow computes

4. **Producer helper** at `data-engine/src/data_engine/producers/{result_message_name_snake}_{version}_producer.py` (if `produce` or `both`)
   - `async def publish(channel, payload, correlation_id: str) -> None`
   - Sets routing key, content-type `application/json`, and propagates trace headers
   - Derives result message name from convention: `{Entity}Job{Action}` → result is `{Entity}JobCompleted`

5. **Consumer registration** — snippet to wire the new consumer into `data-engine/src/data_engine/main.py`

6. **Unit test stubs** at `data-engine/tests/unit/test_{message_name_snake}_{version}_consumer.py`
   - One test for the happy path (valid message, expected workflow call)
   - One test for validation failure (malformed body raises `ValidationError`)
   - One test for idempotency (duplicate `messageId` is handled gracefully)

## Conventions Applied

- Routing key format: `{domain}.{entity}.{action}.{version}` in lowercase dotted notation
  - e.g., `analysis.job.requested.v1` → result `analysis.job.completed.v1`
- All message models use snake_case field names with Pydantic `model_config = ConfigDict(populate_by_name=True)`
- `message_id` is `UUID` (validated as uuid4)
- `occurred_at_utc` is `datetime` with `timezone=True` enforced via Pydantic validator
- Consumer must ack after successful processing; nack (without requeue) on `ValidationError`; nack (with requeue) on transient errors
- Span name convention: `data-engine.{domain}.{action}` (e.g., `data-engine.analysis.process`)
- `correlation_id` is extracted from the AMQP message property and attached to all log records and the OTel span

## Output Checklist

Before finalising, verify:
- [ ] Pydantic model field names and types match the JSON Schema in `schemas/`
- [ ] Consumer properly validates before processing (no raw `json.loads` without validation)
- [ ] Workflow is tested independently from the consumer (pure function, no RabbitMQ dependency)
- [ ] Producer sets `correlation_id` AMQP property and propagates W3C trace headers
- [ ] All new modules are importable (no circular imports)
- [ ] `pyproject.toml` updated if a new third-party dependency was introduced
