# ADR 0001 - Azure-native observability via Azure Monitor OpenTelemetry Distro

## Status

Accepted. 2026-04-13.

This is the first ADR recorded for this project; numbering starts at `0001`. Subsequent ADRs increment the four-digit prefix.

## Context

The platform ships three independently deployed runtimes - the ASP.NET Core API (`api/`), the Python data engine (`data-engine/`), and the Angular SPA (`ui/`) - plus a managed Postgres Flexible Server, a RabbitMQ Container App, an Azure Container Registry, and a Static Web App. Until this branch landed, none of those runtimes published telemetry. Operationally that meant:

- No way to observe a request as it crossed the SPA -> API -> RabbitMQ -> data engine boundary. A failure in any hop surfaced as "the page errored" with no correlated server-side trace.
- No baseline for request rate, latency, or error rate per service. Sampling, capacity, and alerting decisions had nothing to anchor on.
- No infrastructure-side log routing. Postgres, SWA, and ACR were emitting platform diagnostics that nothing was capturing; Container Apps environment logs already routed to Log Analytics via `log_analytics_workspace_id` but the surrounding resources did not.
- No portal-native dashboard. Operators were inspecting failures by tailing container logs through `az containerapp logs show`.

The deployment target is Azure end-to-end (Container Apps, Static Web Apps, Flexible Server, ACR, Key Vault), and a Log Analytics Workspace + Application Insights pair were already provisioned in [`infra/modules/observability/`](../../infra/modules/observability/). The choice was: wire the existing Azure-native stack, or stand up a parallel OSS stack (Grafana + Prometheus + Loki) alongside it.

## Decision

Adopt the **Azure Monitor OpenTelemetry Distro** as the single observability path for all three runtimes, ingesting into **one shared Application Insights instance** that fronts the existing Log Analytics Workspace. Discriminate the three services in queries and the Application Map via `cloud_RoleName` (set through `OTEL_SERVICE_NAME` = `ea-api` | `ea-data-engine` | `ea-ui`). Capture platform-resource diagnostics through a new `infra/modules/diagnostics/` Terraform module that attaches `azurerm_monitor_diagnostic_setting` to each non-Container-Apps resource. Provide two portal-native Azure Monitor Workbooks (`overview`, `errors`) deployed as `azurerm_application_insights_workbook` resources for the day-one operator view.

Concretely:

- **API** ([`api/src/EA.Api/Program.cs`](../../api/src/EA.Api/Program.cs)): `builder.Services.AddOpenTelemetry().UseAzureMonitor(opts => opts.SamplingRatio = IsDevelopment ? 1.0f : 0.2f).WithTracing(t => t.AddSource("EA.Api.Facade"))`. Custom `ActivitySource` spans wrap all eight public methods of [`ModelFacade.cs`](../../api/src/EA.Infrastructure/Facades/ModelFacade.cs). Appsettings narrows `Microsoft.EntityFrameworkCore.Database.Command` to `Warning` and `MassTransit` to `Information` to keep ingestion bounded.
- **Data engine** ([`data-engine/src/data_engine/main.py`](../../data-engine/src/data_engine/main.py)): conditional `configure_azure_monitor(logger_name="data_engine", enable_live_metrics=False)` plus `PikaInstrumentor().instrument()`, both gated on `APPLICATIONINSIGHTS_CONNECTION_STRING` being present. Container env: `OTEL_SERVICE_NAME=ea-data-engine`, `OTEL_TRACES_SAMPLER=parentbased_traceidratio`, `OTEL_TRACES_SAMPLER_ARG=0.2`.
- **UI** ([`ui/src/app/core/app-insights.service.ts`](../../ui/src/app/core/app-insights.service.ts), [`ui/src/app/core/app-insights-error-handler.ts`](../../ui/src/app/core/app-insights-error-handler.ts), [`ui/src/app/app.config.ts`](../../ui/src/app/app.config.ts)): `@microsoft/applicationinsights-web ^3.4.0` and `@microsoft/applicationinsights-angularplugin-js ^15.4.0`. `cloudRoleName='ea-ui'`, the Angular plugin is wired to the router for automatic page-view tracking, and a custom `ErrorHandler` forwards uncaught errors via `trackException`. The connection string is injected at build time by [`ui/scripts/generate-environment.mjs`](../../ui/scripts/generate-environment.mjs) and [`.github/scripts/build-ui.sh`](../../.github/scripts/build-ui.sh), sourced from the new `application_insights_connection_string` output in [`infra/outputs.tf`](../../infra/outputs.tf).
- **Platform diagnostics** ([`infra/modules/diagnostics/main.tf`](../../infra/modules/diagnostics/main.tf)): `azurerm_monitor_diagnostic_setting` for Postgres (`PostgreSQLLogs`, `PostgreSQLFlexSessions`, `PostgreSQLFlexQueryStoreRuntime`, `PostgreSQLFlexQueryStoreWaitStatistics` + `AllMetrics`), Static Web Apps (`category_group=allLogs` + `AllMetrics`), and ACR (`ContainerRegistryLoginEvents`, `ContainerRegistryRepositoryEvents` + `AllMetrics`). All settings use the current `enabled_log` + `enabled_metric` blocks, not the deprecated `log` / `metric` blocks. Container Apps environment logs are intentionally *not* duplicated through this module - the environment already routes to LAW via `log_analytics_workspace_id`.
- **Workbooks** ([`infra/modules/observability/workbooks/overview.workbook.json`](../../infra/modules/observability/workbooks/overview.workbook.json), [`errors.workbook.json`](../../infra/modules/observability/workbooks/errors.workbook.json)): two Azure Monitor Workbooks deployed as `azurerm_application_insights_workbook` resources.

Sampling: dev keeps 100% of traces (`SamplingRatio = 1.0`); prod samples at 20% (`SamplingRatio = 0.2` on the API, `OTEL_TRACES_SAMPLER_ARG=0.2` on the data engine). The SPA is not sampled - browser telemetry volume is already low and per-user-session lookup is the primary use case.

## Consequences

### Positive

- **Native cross-service correlation.** Because all three runtimes use OpenTelemetry and write to one Application Insights instance, W3C `traceparent` propagates cleanly across the SPA -> API -> RabbitMQ -> data engine boundary. The Application Map "just works" - it draws nodes per `cloud_RoleName` and the dependency edges between them without any manual wiring.
- **Portal-native dashboards with no separate hosting.** The two workbooks render inside the Application Insights blade. There is no Grafana to keep alive, no dashboard auth to manage, and no second URL for operators to bookmark.
- **Cost on a freemium curve.** The first 5 GB / month of ingestion per subscription is free under Azure Monitor pricing. With prod sampling at 20%, baseline ingestion sits comfortably inside the free tier for the current traffic shape.
- **Same instrumentation layer if we ever leave Azure.** OTel is the abstraction; `UseAzureMonitor` and `configure_azure_monitor` are exporter shims. Re-pointing to an OTLP collector is a configuration change, not a re-instrumentation.

### Negative / accepted trade-offs

- **Vendor lock-in on the dashboard / KQL surface.** Workbooks and KQL queries are Azure-Monitor-specific; if we leave Azure, those artifacts are thrown away even though the instrumentation survives. Mitigation: the two workbooks are checked into the repo as JSON, and the KQL queries that matter are documented in the runbook (see [`docs/runbooks/observability.md`](../runbooks/observability.md)) so they can be re-implemented elsewhere.
- **Application Insights connection string ships in the SPA bundle.** It is a write-only ingestion key (per Microsoft's published guidance for client-side App Insights), so the exposure is bounded to anonymous telemetry write. Accepted.
- **Prod sampling at 20% changes single-request triage.** Looking up "what did request X do?" requires awareness that a kept span carries `itemCount = 5` (one of five was retained); the missing four are not recoverable. The runbook documents this behaviour and provides a starter query that surfaces `itemCount` so operators learn the convention on first use.
- **No infrastructure metric scraping.** Container-level CPU / memory metrics come from Container Apps' built-in metric pipeline, not from a Prometheus scrape. This is a feature loss only if we want non-Azure-shaped metrics; for the current scope we don't.

### Alternatives considered and rejected

- **Grafana + Prometheus + Loki on a side Container App.** Rejected. Doubles the operational surface (a second stack to deploy, alert on, and rotate credentials for), produces a second set of dashboards that drift from the Azure-native ones, and offers no equivalent to the Application Map. The team is one operator deep; a parallel observability stack is overhead we cannot justify.
- **One Application Insights instance per service** (three instances total). Rejected. Splits the trace store, which means the Application Map cannot draw cross-service edges and KQL `join` across runtimes becomes a cross-resource query. The whole reason to adopt OTel here is end-to-end correlation; per-app instances actively defeat that goal. `cloud_RoleName` is the supported discriminator inside a shared instance, and it is sufficient for our query and dashboard needs.
- **Self-hosted OpenTelemetry Collector in front of Azure Monitor.** Rejected for now. A collector buys batching, redaction, and multi-exporter fan-out, but introduces a hop that has to be HA'd. The Azure Monitor SDKs already batch on the client; we will revisit if we need to fan telemetry to a second backend or enforce field-level redaction policies that the SDKs cannot express.

### Constraint note - RabbitMQ management UI

`AzureRM` provider version **4.68** does not expose `additional_port_mappings` on `azurerm_container_app.ingress`. RabbitMQ's management UI on port `15672` therefore cannot be published as a second external ingress on the existing RabbitMQ Container App; the app's ingress remains internal-only AMQP TCP on `5672`. Operators reach the management surface via `az containerapp exec` and the `rabbitmqctl` CLI inside the running container - see [`docs/runbooks/observability.md`](../runbooks/observability.md) section 3 for the recipe. Revisit when the AzureRM provider exposes `additional_port_mappings` on the Container App ingress block; at that point the management UI can be re-published as a separately-authenticated external ingress and the runbook section can be deleted.
