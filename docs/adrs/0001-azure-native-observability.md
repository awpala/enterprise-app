# ADR 0001 - Azure-native observability via Azure Monitor OpenTelemetry Distro

## Status

Accepted historically. 2026-04-13. Superseded in application-wide scope by [ADR 0003](./0003-multicloud-application-generalization.md); retained as the rationale for the Azure observability adapter.

This is the first ADR recorded for this project; numbering starts at `0001`. Subsequent ADRs increment the four-digit prefix.

## Context

The platform ships three independently deployed runtimes - the ASP.NET Core API (`api/`), the Python data engine (`data-engine/`), and the Angular SPA (`ui/`) - plus a managed Postgres Flexible Server, a RabbitMQ Container App, an Azure Container Registry, and a Static Web App. Until this branch landed, none of those runtimes published telemetry. Operationally that meant:

- No way to observe a request as it crossed the SPA -> API -> RabbitMQ -> data engine boundary. A failure in any hop surfaced as "the page errored" with no correlated server-side trace.
- No baseline for request rate, latency, or error rate per service. Sampling, capacity, and alerting decisions had nothing to anchor on.
- No infrastructure-side log routing. Postgres, SWA, and ACR were emitting platform diagnostics that nothing was capturing; Container Apps environment logs already routed to Log Analytics via `log_analytics_workspace_id` but the surrounding resources did not.
- No portal-native dashboard. Operators were inspecting failures by tailing container logs through `az containerapp logs show`.

The deployment target was Azure end-to-end (Container Apps, Static Web Apps, Flexible Server, ACR, Key Vault), and a Log Analytics Workspace plus Application Insights pair were already provisioned in what is now [`infra/azure/modules/observability/`](../../infra/azure/modules/observability/). The choice was: wire the existing Azure-native stack, or stand up a parallel OSS stack (Grafana + Prometheus + Loki) alongside it.

## Decision

Adopt the **Azure Monitor OpenTelemetry Distro** as the single observability path for all three runtimes, ingesting into **one shared Application Insights instance** that fronts the existing Log Analytics Workspace. Discriminate the three services in queries and the Application Map via `cloud_RoleName` (set through `OTEL_SERVICE_NAME` = `ea-api` | `ea-data-engine` | `ea-ui`). Capture platform-resource diagnostics through the Azure diagnostics module, now under `infra/azure/modules/diagnostics/`. Provide two portal-native Azure Monitor Workbooks (`overview`, `errors`) deployed as `azurerm_application_insights_workbook` resources for the day-one operator view.

Concretely:

- **API** ([`api/src/EA.Api/Program.cs`](../../api/src/EA.Api/Program.cs)): `builder.Services.AddOpenTelemetry().UseAzureMonitor(opts => opts.SamplingRatio = IsDevelopment ? 1.0f : 0.2f).WithTracing(t => t.AddSource("EA.Api.Facade"))`. Custom `ActivitySource` spans wrap all eight public methods of [`ModelFacade.cs`](../../api/src/EA.Infrastructure/Facades/ModelFacade.cs). Appsettings narrows `Microsoft.EntityFrameworkCore.Database.Command` to `Warning` and `MassTransit` to `Information` to keep ingestion bounded.
- **Data engine** ([`data-engine/src/data_engine/main.py`](../../data-engine/src/data_engine/main.py)): conditional `configure_azure_monitor(logger_name="data_engine", enable_live_metrics=False)` plus `PikaInstrumentor().instrument()`, both gated on `APPLICATIONINSIGHTS_CONNECTION_STRING` being present. Container env: `OTEL_SERVICE_NAME=ea-data-engine`, `OTEL_TRACES_SAMPLER=parentbased_traceidratio`, `OTEL_TRACES_SAMPLER_ARG=0.2`.
- **UI (historical):** the Angular UI used Application Insights browser packages, router page-view tracking, and build-time environment generation. ADR 0003 replaced this UI with the current Next.js runtime-config model; provider-neutral browser telemetry remains a documented gap.
- **Platform diagnostics** ([`infra/azure/modules/diagnostics/main.tf`](../../infra/azure/modules/diagnostics/main.tf)): `azurerm_monitor_diagnostic_setting` resources cover the selected Azure services. Container Apps environment logs are intentionally not duplicated because the environment already routes to Log Analytics.
- **Workbooks** ([`infra/azure/modules/observability/workbooks/overview.workbook.json`](../../infra/azure/modules/observability/workbooks/overview.workbook.json), [`errors.workbook.json`](../../infra/azure/modules/observability/workbooks/errors.workbook.json)): two Azure Monitor Workbooks deployed as `azurerm_application_insights_workbook` resources.

The original decision intended 100% development sampling and 20% production sampling. The current Azure Container Apps module sets the API runtime environment to `Production` and configures the data engine sampler to `0.2` for both committed Azure environments, so deployed dev and production currently sample at 20%. Local Development runs retain 100% on the API. The current Next.js UI has no browser real-user monitoring adapter.

## Consequences

### Positive

- **Native cross-service correlation.** Because all three runtimes use OpenTelemetry and write to one Application Insights instance, W3C `traceparent` propagates cleanly across the SPA -> API -> RabbitMQ -> data engine boundary. The Application Map "just works" - it draws nodes per `cloud_RoleName` and the dependency edges between them without any manual wiring.
- **Portal-native dashboards with no separate hosting.** The two workbooks render inside the Application Insights blade. There is no Grafana to keep alive, no dashboard auth to manage, and no second URL for operators to bookmark.
- **Cost on a freemium curve.** The first 5 GB / month of ingestion per subscription is free under Azure Monitor pricing. With prod sampling at 20%, baseline ingestion sits comfortably inside the free tier for the current traffic shape.
- **Same instrumentation layer if we ever leave Azure.** OTel is the abstraction; `UseAzureMonitor` and `configure_azure_monitor` are exporter shims. Re-pointing to an OTLP collector is a configuration change, not a re-instrumentation.

### Negative / accepted trade-offs

- **Vendor lock-in on the dashboard / KQL surface.** Workbooks and KQL queries are Azure-Monitor-specific; another provider needs its own adapter even though the instrumentation survives. Mitigation: the workbooks are checked into the repository as JSON, and the relevant queries are documented in the [observability runbook](../runbooks/observability.md).
- **Application Insights connection string ships in the SPA bundle.** It is a write-only ingestion key (per Microsoft's published guidance for client-side App Insights), so the exposure is bounded to anonymous telemetry write. Accepted.
- **Prod sampling at 20% changes single-request triage.** Looking up "what did request X do?" requires awareness that a kept span carries `itemCount = 5` (one of five was retained); the missing four are not recoverable. The runbook documents this behavior and provides a starter query that surfaces `itemCount` so operators learn the convention on first use.
- **No infrastructure metric scraping.** Container-level CPU / memory metrics come from Container Apps' built-in metric pipeline, not from a Prometheus scrape. This is a feature loss only if we want non-Azure-shaped metrics; for the current scope we don't.

### Alternatives considered and rejected

- **Grafana + Prometheus + Loki on a side Container App.** Rejected. Doubles the operational surface (a second stack to deploy, alert on, and rotate credentials for), produces a second set of dashboards that drift from the Azure-native ones, and offers no equivalent to the Application Map. The team is one operator deep; a parallel observability stack is overhead we cannot justify.
- **One Application Insights instance per service** (three instances total). Rejected. Splits the trace store, which means the Application Map cannot draw cross-service edges and KQL `join` across runtimes becomes a cross-resource query. The whole reason to adopt OTel here is end-to-end correlation; per-app instances actively defeat that goal. `cloud_RoleName` is the supported discriminator inside a shared instance, and it is sufficient for our query and dashboard needs.
- **Self-hosted OpenTelemetry Collector in front of Azure Monitor.** Rejected for now. A collector buys batching, redaction, and multi-exporter fan-out, but introduces a hop that has to be HA'd. The Azure Monitor SDKs already batch on the client; we will revisit if we need to fan telemetry to a second backend or enforce field-level redaction policies that the SDKs cannot express.

### Constraint note - RabbitMQ management UI

At the time of this decision, the AzureRM provider did not expose the required secondary Container Apps port mapping. RabbitMQ management therefore remained internal, with operators using `az containerapp exec` and `rabbitmqctl`; see the [Azure observability runbook](../runbooks/azure-observability.md). Re-evaluate against the currently pinned provider before changing ingress.
