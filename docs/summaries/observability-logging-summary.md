# Multi-cloud observability and logging

## Contract

Application services instrument standard OpenTelemetry APIs. Deployment selects the exporter; business code does not reference a cloud telemetry service.

| Runtime | Setting | Azure | AWS | Local/test |
|---|---|---|---|---|
| .NET API | `Observability__Exporter` | `azuremonitor` | `otlp` | `none` |
| Python data engine | `OBSERVABILITY_EXPORTER` | `azuremonitor` | `otlp` | `none` |
| Next.js server | standard `OTEL_*` variables | OpenTelemetry registration | OpenTelemetry registration | no collector required |

Every runtime sets `OTEL_SERVICE_NAME` (`ea-ui`, `ea-api`, or `ea-data-engine`). HTTP and message boundaries propagate W3C trace context and correlation IDs. Structured logs go to stdout/stderr; infrastructure captures them in Log Analytics on Azure or CloudWatch Logs on AWS.

## Azure adapter

The API and worker use their Azure Monitor exporters and one Application Insights/Log Analytics pair. Azure Monitor workbooks under `infra/azure/modules/observability/workbooks` remain the Azure-native operator surface. Azure resource diagnostics cover PostgreSQL and ACR; Container Apps environment logs already route through its Log Analytics configuration.

See the [Azure observability runbook](../runbooks/azure-observability.md) for KQL and day-two procedures. ADR 0001 remains the historical rationale for this adapter, while ADR 0003 supersedes its Azure-only application scope.

## AWS adapter

API and worker tasks send OTLP/gRPC to an AWS Distro for OpenTelemetry sidecar. ADOT exports traces to X-Ray and metrics to CloudWatch using the ECS task role. ECS `awslogs` drivers send service logs to per-service CloudWatch log groups with environment-configured retention. The Terraform observability module creates the baseline dashboard and alarms.

The [AWS deployment workbook](../workbooks/aws-deployment-workbook.md) requires evidence of a correlated API-to-worker trace, alarm state, log retention, and secret redaction before production approval.

## Known gap

The previous provider-specific browser telemetry adapter was removed with the Next.js migration. Next.js server telemetry is registered, but provider-neutral browser real-user monitoring is not yet implemented. Do not interpret the `ea-ui` server signal as complete client-side page-view or exception coverage.

## Operational invariants

- Never log connection strings, tokens, passwords, provider client secrets, or raw secret payloads.
- Keep service names and correlation fields stable across clouds.
- Validate exporter configuration at startup and fail on unsupported values.
- Treat dashboard/query artifacts as provider adapters; keep instrumentation semantic conventions portable.
- Test trace propagation through RabbitMQ whenever message headers or libraries change.
