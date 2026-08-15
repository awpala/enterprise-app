# Observability Runbook

Application instrumentation is provider-neutral OpenTelemetry. Select the operational adapter that matches the explicit deployment target:

| Target | Export path | Operator procedure |
|---|---|---|
| Azure | `azuremonitor` exporter to Application Insights and Log Analytics | [Azure observability adapter](./azure-observability.md) |
| AWS | OTLP to the colocated ADOT collector, then CloudWatch and X-Ray | [AWS verification evidence](../workbooks/aws-deployment-workbook.md#9-verification-evidence) |
| Local | `none` by default; structured stdout/stderr remains enabled | [Local Compose guide](../../deploy/README.md) |

Every deployment must verify the same provider-independent signals: health endpoints, structured service logs, W3C trace propagation, correlation IDs across RabbitMQ, migration outcome, and alert delivery. Provider-specific dashboards and query languages are adapters over that common contract.
