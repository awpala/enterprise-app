# Observability & Logging -- Deployed Environment Summary

This document catalogs every logging call-site, auto-instrumented telemetry source, and platform diagnostic feed across the deployed Enterprise App environment. It is intended for operators and demo audiences who need to understand exactly what visibility the system provides.

---

## 1. Architecture Overview

All three application services -- the ASP.NET Core API, the Python data-engine, and the Angular SPA -- feed telemetry into a single shared Azure Application Insights instance. Application Insights is backed by a Log Analytics Workspace (LAW), which also receives platform-level diagnostics from Azure-managed resources.

```
Angular SPA                 ASP.NET Core API               Python Data Engine
(App Insights JS SDK)       (Azure Monitor OTel distro)    (azure-monitor-opentelemetry)
       |                           |                              |
       |  cloud_RoleName=ea-ui     |  cloud_RoleName=ea-api       |  cloud_RoleName=ea-data-engine
       +---------------------------+------------------------------+
                                   |
                           Application Insights
                                   |
                        Log Analytics Workspace
                                   |
                    +------- Platform Diagnostics -------+
                    |              |              |       |
                 Postgres     Static Web App    ACR    Container App Env
```

**Service discrimination.** Each service sets a distinct `cloud_RoleName` via the `OTEL_SERVICE_NAME` environment variable (API: `ea-api`, data-engine: `ea-data-engine`) or via a telemetry initializer (UI: `ea-ui`). This value appears in the Application Map and is the primary filter in KQL queries.

**Trace-context propagation.** The API uses the Azure Monitor OpenTelemetry distro for .NET, which propagates W3C `traceparent` / `tracestate` headers on outbound HTTP requests and MassTransit message headers. The data-engine uses `PikaInstrumentor` from the OpenTelemetry pika instrumentation package, which reads and propagates trace context across RabbitMQ message boundaries. The SPA enables `enableCorsCorrelation`, `enableRequestHeaderTracking`, and `enableResponseHeaderTracking` to correlate browser-originated fetch calls with backend traces.

**Sampling.**
- API: 100% in Development, 20% in Production (set via `SamplingRatio` in `UseAzureMonitor`).
- Data-engine: `parentbased_traceidratio` sampler at 0.2 (20%), configured via `OTEL_TRACES_SAMPLER` and `OTEL_TRACES_SAMPLER_ARG` environment variables. The `parentbased` prefix means that if the API sampled a trace, the data-engine will also sample the downstream spans, keeping correlated traces intact.
- UI: No explicit sampling override (uses the App Insights JS SDK defaults).

---

## 2. Per-Service Telemetry

### 2.1 ASP.NET Core API (`ea-api`)

The Azure Monitor OpenTelemetry distro (`Azure.Monitor.OpenTelemetry.AspNetCore`) auto-instruments the following without any per-span code:

| Auto-instrumented source | App Insights table | Notes |
|---|---|---|
| ASP.NET Core HTTP request handling | `requests` | Every inbound HTTP request including path, status code, duration |
| HttpClient outbound calls | `dependencies` | Any outbound HTTP call from `HttpClient` |
| EF Core / Npgsql database commands | `dependencies` | SQL queries to Postgres with duration and statement text |
| MassTransit publish/send/consume | `dependencies` / `requests` | Publish appears as a dependency; consume appears as a request span |
| ILogger structured log messages | `traces` | All `ILogger<T>` output bridged to App Insights |
| Unhandled exceptions | `exceptions` | Exceptions captured by the ASP.NET Core exception handler |
| Runtime metrics (GC, thread pool) | `customMetrics` | .NET runtime performance counters |
| Custom `EA.Api.Facade` ActivitySource spans | `dependencies` | Facade methods create spans via `ActivitySource.StartActivity` |

Additionally, a custom `ActivitySource` named `EA.Api.Facade` is registered in `Program.cs` and used in `ModelFacade` to create spans around every facade method (`GetModelsAsync`, `GetModelByIdAsync`, `CreateModelAsync`, `UpdateModelAsync`, `ArchiveModelAsync`, `RequestModelRunAsync`, `GetModelRunsAsync`, `GetModelRunByIdAsync`).

#### Explicit log points -- Controllers

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `api/src/EA.Api/Controllers/ModelsController.cs` | Creating model with name | Information | `{ModelName}` | `traces` |
| `api/src/EA.Api/Controllers/ModelsController.cs` | Updating model with status | Information | `{ModelId}`, `{Status}` | `traces` |
| `api/src/EA.Api/Controllers/ModelsController.cs` | Update failed: model not found or archived | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Api/Controllers/ModelsController.cs` | Archiving model | Information | `{ModelId}` | `traces` |
| `api/src/EA.Api/Controllers/ModelsController.cs` | Archive failed: model not found | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Api/Controllers/ModelsController.cs` | Requesting run for model | Information | `{ModelId}` | `traces` |
| `api/src/EA.Api/Controllers/ModelsController.cs` | Run request failed: model not found or archived | Warning | `{ModelId}` | `traces` |

#### Explicit log points -- ModelFacade

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Retrieving models page | Information | `{Page}`, `{PageSize}`, `{Status}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Retrieving model | Information | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Created model with name | Information | `{ModelId}`, `{ModelName}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Model not found for update | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Cannot update archived model | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Updated model to version | Information | `{ModelId}`, `{Version}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Model not found for archival | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Model is already archived | Information | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Archived model | Information | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Model not found for run request | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Cannot request run for archived model | Warning | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Requested model run, published message | Information | `{ModelRunId}`, `{ModelId}`, `{CorrelationId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Retrieving runs for model | Information | `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Retrieving run for model | Information | `{ModelRunId}`, `{ModelId}` | `traces` |
| `api/src/EA.Infrastructure/Facades/ModelFacade.cs` | Run not found or does not belong to model | Warning | `{ModelRunId}`, `{ModelId}` | `traces` |

#### Explicit log points -- MassTransit Consumers

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `api/src/EA.Infrastructure/Consumers/ModelRunStartedConsumer.cs` | Received ModelRunStarted | Information | `{ModelRunId}`, `{ModelId}`, `{MessageId}`, `{CorrelationId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunStartedConsumer.cs` | Model run not found, skipping | Warning | `{ModelRunId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunStartedConsumer.cs` | Model run marked as Running | Information | `{ModelRunId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunCompletedConsumer.cs` | Received ModelRunCompleted | Information | `{ModelRunId}`, `{ModelId}`, `{MessageId}`, `{CorrelationId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunCompletedConsumer.cs` | Model run not found, skipping | Warning | `{ModelRunId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunCompletedConsumer.cs` | Model run completed with N metrics | Information | `{ModelRunId}`, `{MetricCount}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunFailedConsumer.cs` | Received ModelRunFailed | Information | `{ModelRunId}`, `{ModelId}`, `{MessageId}`, `{CorrelationId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunFailedConsumer.cs` | Model run not found, skipping | Warning | `{ModelRunId}` | `traces` |
| `api/src/EA.Infrastructure/Consumers/ModelRunFailedConsumer.cs` | Model run failed | Warning | `{ModelRunId}`, `{ErrorMessage}` | `traces` |

#### Explicit log points -- Seeding

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `api/src/EA.Infrastructure/Seeding/SeedHostedService.cs` | Seeding disabled; skipping startup seed | Information | (none) | `traces` |
| `api/src/EA.Infrastructure/Seeding/SeedHostedService.cs` | Startup seeding enabled; using seed path | Information | `{SeedPath}` | `traces` |
| `api/src/EA.Infrastructure/Seeding/SeedHostedService.cs` | Startup seeding failed; application will continue | Error | (exception attached) | `traces` + `exceptions` |

#### Log level configuration (`appsettings.json`)

| Logger category | Minimum level |
|---|---|
| Default | Information |
| Microsoft.AspNetCore | Warning |
| Microsoft.EntityFrameworkCore | Warning |
| Microsoft.EntityFrameworkCore.Database.Command | Warning |
| MassTransit | Information |

#### Health probes

| Endpoint | Probe type | Check |
|---|---|---|
| `/health/live` | Liveness | Always healthy (process up) |
| `/health/ready` | Readiness | Postgres connectivity |
| `/health/startup` | Startup | Always healthy (process up) |

Container Apps polls these via HTTP. Failed probes appear in the Container App Environment system logs in LAW.

---

### 2.2 Python Data Engine (`ea-data-engine`)

The data-engine calls `configure_azure_monitor()` from `azure-monitor-opentelemetry` when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set. It also instruments pika via `PikaInstrumentor().instrument()` to create spans for RabbitMQ consume and publish operations.

| Auto-instrumented source | App Insights table | Notes |
|---|---|---|
| Pika RabbitMQ consume spans | `requests` | Each message delivery creates a span |
| Pika RabbitMQ publish spans | `dependencies` | Each `basic_publish` call creates a span |
| Python logging bridge | `traces` | All `logging.*` calls routed to App Insights |
| Unhandled exceptions | `exceptions` | Captured by the OTel SDK |

#### Explicit log points -- Configuration

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `data-engine/src/data_engine/config.py` | Configuration loaded (resolved values) | INFO | `rabbitmq_host`, `rabbitmq_port`, `rabbitmq_vhost`, `log_level`, `reconnect_delay_initial`, `reconnect_delay_max`, `reconnect_delay_multiplier` (positional) | `traces` |

#### Explicit log points -- main.py

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `data-engine/src/data_engine/main.py` | Starting EA Data Engine | INFO | (none) | `traces` |
| `data-engine/src/data_engine/main.py` | RabbitMQ host and port | INFO | `host`, `port` (positional) | `traces` |
| `data-engine/src/data_engine/main.py` | Received shutdown signal | INFO | `sig_name` (positional) | `traces` |
| `data-engine/src/data_engine/main.py` | Interrupted, exiting | INFO | (none) | `traces` |
| `data-engine/src/data_engine/main.py` | Consumer crashed, reconnecting | ERROR | `delay` (positional); full traceback | `traces` + `exceptions` |
| `data-engine/src/data_engine/main.py` | EA Data Engine stopped | INFO | (none) | `traces` |

#### Explicit log points -- ModelRunConsumer

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Connecting to RabbitMQ at host:port (vhost) | INFO | `rabbitmq_host`, `rabbitmq_port`, `rabbitmq_vhost` (positional) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | RabbitMQ connection established, channel opened | INFO | (none) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Consuming from queue (exchange) | INFO | queue name, exchange name (positional) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Consumer stop requested | INFO | (none) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Received message: processing run for model | INFO | `messageId`, `correlationId`, `modelRunId`, `modelId`, `modelName` (positional) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Run completed with N metrics | INFO | `modelRunId`, metric count, `correlationId` (positional) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Unsupported distribution | WARNING | `modelRunId` or "unknown", `correlationId` or "unknown", exception message (positional) | `traces` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Unexpected error processing message | ERROR | `modelRunId` or "unknown", `correlationId` or "unknown" (positional); full traceback via `logger.exception` | `traces` + `exceptions` |
| `data-engine/src/data_engine/consumers/model_run_consumer.py` | Failed to publish failure event | ERROR | `modelRunId` (positional); full traceback via `logger.exception` | `traces` + `exceptions` |

#### Explicit log points -- ModelRunProducer

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `data-engine/src/data_engine/producers/model_run_producer.py` | Published ModelRunStarted | INFO | `model_run_id` (positional) | `traces` |
| `data-engine/src/data_engine/producers/model_run_producer.py` | Published ModelRunCompleted | INFO | `model_run_id` (positional) | `traces` |
| `data-engine/src/data_engine/producers/model_run_producer.py` | Published ModelRunFailed | WARNING | `model_run_id`, `error_message` (positional) | `traces` |

#### Explicit log points -- model_metrics workflow

| Source file | Log point | Level | Structured properties | AI table |
|---|---|---|---|---|
| `data-engine/src/data_engine/workflows/model_metrics.py` | Generating samples from distribution | INFO | `sample_size`, `distribution`, `mean`, `std_dev` (positional) | `traces` |
| `data-engine/src/data_engine/workflows/model_metrics.py` | Metrics computation complete | INFO | `distribution`, `sample_size`, `computed_mean` (positional) | `traces` |

---

### 2.3 Angular SPA (`ea-ui`)

The SPA uses the Application Insights JavaScript SDK (`@microsoft/applicationinsights-web`) with the Angular plugin (`@microsoft/applicationinsights-angularplugin-js`). It is initialized in `AppInsightsService` only when `environment.applicationInsightsConnectionString` is set.

| Auto-instrumented source | App Insights table | Notes |
|---|---|---|
| Angular route navigations | `pageViews` | AngularPlugin tracks route changes as page views |
| Fetch/XHR dependency tracking | `dependencies` | `disableFetchTracking: false` enables automatic tracking of all outbound HTTP calls |
| Initial page view | `pageViews` | `trackPageView()` called on initialization |
| Unhandled exceptions (global ErrorHandler) | `exceptions` | `AppInsightsErrorHandler` catches all Angular errors and calls `trackException` |

The `AppInsightsErrorHandler` is registered as Angular's global `ErrorHandler`. Every unhandled error in any component, service, or Observable chain is normalized to an `Error` object and sent to App Insights as a `SeverityLevel.Error` exception.

#### Console-level log points (visible in browser DevTools; not sent to App Insights)

The following log points use `console.warn` / `console.error`. They appear in the browser's developer console but do NOT flow to App Insights unless they trigger the global `ErrorHandler` (which only catches thrown exceptions, not console calls).

| Source file | Log point | Level | Context |
|---|---|---|---|
| `ui/src/app/auth/auth.service.ts` | loginRedirect suppressed -- AAD not configured | console.warn | MSAL config missing |
| `ui/src/app/auth/auth.service.ts` | loginAsDev suppressed -- dev auth disabled | console.warn | Build flag off |
| `ui/src/app/auth/auth.service.ts` | loginAsGuest suppressed -- guest auth disabled | console.warn | Build flag off |
| `ui/src/app/auth/auth.service.ts` | Failed to read/persist dev session from localStorage | console.warn | localStorage unavailable |
| `ui/src/app/auth/auth.service.ts` | Failed to read/persist guest session from localStorage | console.warn | localStorage unavailable |
| `ui/src/app/auth/bearer-auth.interceptor.ts` | No cached MSAL account -- request proceeds without Bearer | console.warn | Token acquisition skipped |
| `ui/src/app/auth/bearer-auth.interceptor.ts` | Silent token acquisition requires interaction -- redirecting | console.warn | `InteractionRequiredAuthError` |
| `ui/src/app/auth/bearer-auth.interceptor.ts` | Token acquisition failed | console.error | Non-interactive token error |
| `ui/src/app/auth/auth.guard.ts` | No active session and MSAL not configured -- redirecting to landing | console.warn | Guard redirect |
| `ui/src/app/auth/msal.config.ts` | MSAL logger callback (non-production only) | console.debug | MSAL internal logging |
| `ui/src/app/auth/msal.config.ts` | Failed to parse authority URL | console.warn | Invalid authority config |
| `ui/src/app/auth/login-failed.component.ts` | User landed on sign-in failure page | console.warn | MsalGuard rejection |
| `ui/src/app/features/models/model-list/model-list.component.ts` | Failed to archive model | console.error | HTTP error |
| `ui/src/app/features/models/model-list/model-list.component.ts` | Failed to load models | console.error | HTTP error |
| `ui/src/app/features/models/model-detail/model-detail.component.ts` | Failed to request run for model | console.error | HTTP error |
| `ui/src/app/features/models/model-detail/model-detail.component.ts` | Failed to load model | console.error | HTTP error |
| `ui/src/app/features/models/model-detail/model-detail.component.ts` | Failed to load runs for model | console.error | HTTP error |
| `ui/src/app/features/models/model-form/model-form.component.ts` | Invalid JSON in Parameters field | console.warn | JSON parse failure |
| `ui/src/app/features/models/model-form/model-form.component.ts` | Failed to update model | console.error | HTTP error |
| `ui/src/app/features/models/model-form/model-form.component.ts` | Failed to create model | console.error | HTTP error |
| `ui/src/app/features/models/model-form/model-form.component.ts` | Failed to load model for editing | console.error | HTTP error |
| `ui/src/app/features/models/model-runs/model-runs.component.ts` | Failed to request run for model | console.error | HTTP error |
| `ui/src/app/features/models/model-runs/model-runs.component.ts` | Failed to load runs for model | console.error | HTTP error |
| `ui/src/app/features/models/model-runs/run-detail/run-detail.component.ts` | Failed to load run | console.error | HTTP error |
| `ui/src/app/features/dashboard/dashboard.component.ts` | Failed to load recent models | console.error | HTTP error |
| `ui/src/app/features/dashboard/dashboard.component.ts` | Failed to load active model count | console.error | HTTP error |

Note: The HTTP errors that reach the `error` callbacks in component subscriptions do NOT automatically get sent to App Insights because they are caught in `subscribe({ error: ... })` handlers. They appear in the browser console but are swallowed from the global `ErrorHandler` perspective. The failed HTTP calls themselves DO appear as failed `dependencies` in App Insights because the fetch instrumentation tracks them automatically.

---

## 3. Platform Diagnostics

Azure resource-level logs and metrics are routed to the shared Log Analytics Workspace via Terraform-managed diagnostic settings (`infra/modules/diagnostics/main.tf`).

| Azure resource | Log categories | Metrics | LAW table(s) |
|---|---|---|---|
| PostgreSQL Flexible Server | `PostgreSQLLogs`, `PostgreSQLFlexSessions` | AllMetrics | `AzureDiagnostics` (category-filtered) |
| Static Web App (SPA host) | `allLogs` (category group) | AllMetrics | `AzureDiagnostics` |
| Container Registry (ACR) | `ContainerRegistryLoginEvents`, `ContainerRegistryRepositoryEvents` | AllMetrics | `AzureDiagnostics` |
| Container App Environment | Console logs (stdout/stderr from all containers) | -- | `ContainerAppConsoleLogs_CL` |

The Container App Environment routes console logs to LAW via the `log_analytics_workspace_id` argument on `azurerm_container_app_environment` (set in `infra/modules/container-apps/main.tf`). This is separate from the diagnostic settings module and is NOT duplicated there.

---

## 4. Workbooks

Two custom Azure Monitor Workbooks are deployed via Terraform (`infra/modules/observability/main.tf`) and bound to the Application Insights instance.

### Overview Workbook (`{name_prefix} -- Overview`)

Provides golden-signal visibility across all services.

| Panel | KQL summary | Purpose |
|---|---|---|
| Requests per minute, per role | `requests \| summarize count() by bin(timestamp, 1m), cloud_RoleName` | Throughput by service |
| Latency -- avg + p95 (ms) | `requests \| summarize avg(duration), percentile(duration, 95) by bin(timestamp, 5m), cloud_RoleName` | Latency distribution |
| Dependencies -- RabbitMQ + Postgres | `dependencies \| where type in ("Queue", "postgresql", "SQL") \| summarize count(), avg(duration) by type, target` | Downstream health |
| Warning-or-above log volume per role | `traces \| where severityLevel >= 3 \| summarize count() by bin(timestamp, 5m), cloud_RoleName` | Error/warning rate trend |

### Errors Workbook (`{name_prefix} -- Errors`)

Drill-down into failure modes across all services.

| Panel | KQL summary | Purpose |
|---|---|---|
| Top exceptions | `exceptions \| summarize count() by outerMessage, cloud_RoleName \| top 20` | Most frequent exceptions by service |
| Failed dependencies | `dependencies \| where success == false \| summarize count() by target, resultCode \| top 20` | Failing downstream calls |
| Top error traces | `traces \| where severityLevel == 3 \| summarize count() by cloud_RoleName, message \| top 20` | Most frequent error-level log messages |

---

## 5. Sampling Configuration

| Service | Environment | Sampler | Ratio | Config source |
|---|---|---|---|---|
| API (`ea-api`) | Development | Azure Monitor distro built-in | 1.0 (100%) | `Program.cs` -- `builder.Environment.IsDevelopment()` check |
| API (`ea-api`) | Production | Azure Monitor distro built-in | 0.2 (20%) | `Program.cs` -- `SamplingRatio` parameter |
| Data-engine (`ea-data-engine`) | All (deployed) | `parentbased_traceidratio` | 0.2 (20%) | `OTEL_TRACES_SAMPLER` + `OTEL_TRACES_SAMPLER_ARG` env vars |
| UI (`ea-ui`) | All | App Insights JS SDK default | Adaptive | No explicit override |

The `parentbased` prefix on the data-engine sampler is critical: when the API publishes a `ModelRunRequested` message and that trace was sampled, the data-engine will honor the parent's sampling decision and also sample the downstream spans. This keeps correlated end-to-end traces intact rather than randomly dropping half of them.

---

## 6. Where to Look -- Quick Reference

| I want to see... | Where to go |
|---|---|
| API request latency | App Insights > Performance blade, or `requests \| where cloud_RoleName == 'ea-api'` |
| End-to-end trace for a model run | App Insights > Transaction search > filter by `CorrelationId` or use the End-to-end transaction details view from any request/dependency |
| Data-engine exceptions | `exceptions \| where cloud_RoleName == 'ea-data-engine'` |
| SPA page views and navigation timing | `pageViews \| where cloud_RoleName == 'ea-ui'` |
| Failed API calls from the browser | `dependencies \| where cloud_RoleName == 'ea-ui' and success == false` |
| Unhandled Angular errors | `exceptions \| where cloud_RoleName == 'ea-ui'` |
| All warnings/errors from the API | `traces \| where cloud_RoleName == 'ea-api' and severityLevel >= 3` |
| MassTransit consumer processing times | `requests \| where cloud_RoleName == 'ea-api' and name contains 'Consumer'` |
| EF Core / Postgres query performance | `dependencies \| where cloud_RoleName == 'ea-api' and type == 'postgresql'` |
| RabbitMQ publish latency | `dependencies \| where type == 'Queue'` |
| Postgres server logs (platform) | LAW > `AzureDiagnostics \| where Category == 'PostgreSQLLogs'` |
| Postgres session activity | LAW > `AzureDiagnostics \| where Category == 'PostgreSQLFlexSessions'` |
| Container App console output | LAW > `ContainerAppConsoleLogs_CL` |
| ACR image push/pull events | LAW > `AzureDiagnostics \| where Category == 'ContainerRegistryRepositoryEvents'` |
| ACR login events | LAW > `AzureDiagnostics \| where Category == 'ContainerRegistryLoginEvents'` |
| Static Web App access logs | LAW > `AzureDiagnostics` filtered to SWA resource |
| Golden signals at a glance | App Insights > Workbooks > "{name_prefix} -- Overview" |
| Failure drill-down | App Insights > Workbooks > "{name_prefix} -- Errors" |
| Application topology map | App Insights > Application Map (nodes: `ea-ui`, `ea-api`, `ea-data-engine`, Postgres, RabbitMQ) |
| Health probe failures | LAW > `ContainerAppConsoleLogs_CL` or Container App > Health blade in the Azure portal |
| Seeding failures at startup | `traces \| where cloud_RoleName == 'ea-api' and message contains 'seeding'` or `exceptions \| where cloud_RoleName == 'ea-api' and outerMessage contains 'seeding'` |
| Model run lifecycle (end to end) | Search `traces` for `ModelRunId` across both `ea-api` and `ea-data-engine` roles |
