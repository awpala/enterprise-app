# Runbook: Observability - Verify, Query, and Operate

## 1. Overview

This runbook covers post-deploy verification and day-2 operation of the Azure-native observability stack adopted in [ADR 0001](../adrs/0001-azure-native-observability.md). Scope: one Application Insights instance shared by the API (`ea-api`), data engine (`ea-data-engine`), and SPA (`ea-ui`); platform diagnostics for Postgres / SWA / ACR routed to Log Analytics; and two portal-native workbooks (`overview`, `errors`).

**Who runs this**: any operator with **Reader** on the resource group plus **Monitoring Reader** on the Application Insights instance. Sections that exec into the RabbitMQ container additionally require **Container Apps Contributor** (for `az containerapp exec`); section 4 (Postgres Query Editor) requires the Postgres admin password from Key Vault.

**Naming convention used below**: replace `{env}` with `dev` or `production`, and `{suffix}` with the random suffix Terraform appends (visible in the resource group). Example resource names: `ea-dev-appi-a1b2c3`, `ea-production-pgsql-a1b2c3`, `ea-production-rg`.

**Prerequisites**:

- [ ] `az` CLI installed and authenticated against the workforce subscription (`az login`).
- [ ] Default subscription set: `az account set --subscription <subscription-id>`.
- [ ] Browser session signed in to [https://portal.azure.com](https://portal.azure.com) with the same identity.

---

## 2. Post-deploy verification checklist

Run this every time after `terraform apply` + image rebuild + `az containerapp update --image ...` lands a new revision. The whole pass takes about 10 minutes.

### Step 1. Live Metrics tick

1. In the portal, top search bar -> type the App Insights name (`ea-{env}-appi-{suffix}`) -> click the resource.
2. Left nav -> **Investigate** group -> **Live metrics**.
3. In a separate terminal, hit the API health endpoint a few times:

   ```bash
   for i in 1 2 3 4 5; do
     curl -s -o /dev/null -w "%{http_code}\n" https://<api-fqdn>/health/ready
     sleep 1
   done
   ```

   The API FQDN is the `ingress` URL on the `ea-{env}-api` Container App (Container App overview blade -> **Application Url**).

4. Confirm the Live Metrics **Incoming Requests** chart ticks within 5-10 seconds. The **Servers** column on the right should list at least one entry whose **Role Name** is `ea-api`. If the chart stays at zero, jump to [Section 7 - Troubleshooting "no telemetry"](#7-troubleshooting-no-telemetry).

### Step 2. Application Map shows all five nodes

1. From the same Application Insights blade, left nav -> **Investigate** group -> **Application map**.
2. In another terminal, drive one end-to-end flow that exercises the whole stack. The minimum is a single create-model call from the SPA, which produces: SPA page-view -> API HTTP request -> Postgres write -> RabbitMQ publish -> data engine consume.

   If you do not have a UI session handy, the equivalent CLI path is:

   ```bash
   curl -X POST https://<api-fqdn>/api/v1/models \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"name":"smoke-test"}'
   ```

3. Wait 60-90 seconds for telemetry to flush, then click **Update map components** in the Application Map toolbar.
4. Expect five nodes connected by directed edges:
   - `ea-ui` (only present after a real SPA page-view)
   - `ea-api`
   - `ea-data-engine`
   - `postgres` (drawn as a dependency of `ea-api`)
   - `rabbitmq` (drawn as a dependency of `ea-api`, with the consume edge into `ea-data-engine`)

   If a service node is missing, the corresponding runtime is not exporting - go to [Section 7](#7-troubleshooting-no-telemetry).

### Step 3. KQL starter queries

From the App Insights blade, left nav -> **Monitoring** group -> **Logs**. Dismiss the example queries dialog if it appears. Paste each query below into the editor and click **Run**.

**A. Recent traces from all three services** - confirms the `cloud_RoleName` discriminator works:

```kql
traces
| where cloud_RoleName in ("ea-api", "ea-data-engine", "ea-ui")
| take 50
| project timestamp, cloud_RoleName, message
```

Expect a mix of all three role names. If only one or two appear, the missing service is not exporting.

**B. Request rate per minute** - quick capacity sanity check:

```kql
requests
| summarize count() by bin(timestamp, 1m)
| render timechart
```

**C. Exceptions grouped by service and type** - the first query to run when a deploy looks unhealthy:

```kql
exceptions
| summarize count() by cloud_RoleName, type
| order by count_ desc
```

**D. Dependency latency for Postgres and RabbitMQ** - tracks the two external dependencies that matter:

```kql
dependencies
| where type in ("postgresql", "Queue")
| summarize avg(duration), percentile(duration, 95) by name
```

**E. Confirm sampling is doing its job in prod** - on the prod App Insights instance only:

```kql
requests
| take 10
| project timestamp, name, itemCount
```

`itemCount` should be approximately `5` (one of every five spans was kept at the `0.2` sampling rate). On dev the same query returns `itemCount = 1` because dev keeps 100% of traces.

---

## 3. Workbooks

Two custom workbooks ship as Terraform-managed `azurerm_application_insights_workbook` resources.

1. From the App Insights blade, left nav -> **Monitoring** group -> **Workbooks**.
2. Click the **Workbooks** tab (portal versions may label this **Shared reports** instead — either way, it is the tab that lists custom workbooks, not the **Quick start** / Microsoft templates tab).
3. The two custom workbooks are listed as `ea-{env} — Overview` and `ea-{env} — Errors`:
   - **Overview** - golden-signals view across all three services. Tiles for request rate, P50 / P95 / P99 latency, success rate, and a request-count breakdown by `cloud_RoleName`. Use this for "is the system healthy?" at a glance.
   - **Errors** - failure-focused view. Top exceptions grouped by `cloud_RoleName` and `type`, failed-request waterfall, and a recent failures table with `traceId` for click-through into end-to-end transaction view. Use this when investigating an alert.
4. Click into either to open it. Time range defaults to the last 24 hours - change via the **Time Range** pill at the top of the workbook.

---

## 4. RabbitMQ management UI access (AzureRM 4.68 workaround)

The RabbitMQ Container App's ingress is internal-only AMQP TCP on `5672`. The management UI on port `15672` is not externally reachable because `azurerm_container_app.ingress` in **AzureRM 4.68** does not expose `additional_port_mappings`. Until the provider gains that field (tracked in [ADR 0001](../adrs/0001-azure-native-observability.md) "Constraint note"), the operator path is `az containerapp exec` plus the in-container `rabbitmqctl` CLI.

### Inspect queues, connections, and consumers

```bash
az login
az account set --subscription <subscription-id>

# Quick peek - one-shot list_queues
az containerapp exec \
  --name ea-{env}-rabbitmq \
  --resource-group ea-{env}-rg \
  --command "rabbitmqctl list_queues name messages consumers"

# Connection inventory
az containerapp exec \
  --name ea-{env}-rabbitmq \
  --resource-group ea-{env}-rg \
  --command "rabbitmqctl list_connections user peer_host state"

# Consumer inventory
az containerapp exec \
  --name ea-{env}-rabbitmq \
  --resource-group ea-{env}-rg \
  --command "rabbitmqctl list_consumers"
```

### Interactive shell (for ad-hoc exploration)

```bash
az containerapp exec \
  --name ea-{env}-rabbitmq \
  --resource-group ea-{env}-rg \
  --command /bin/bash
```

Inside the container, useful commands:

```bash
rabbitmqctl status
rabbitmqctl list_queues name messages_ready messages_unacknowledged consumers
rabbitmqctl list_exchanges name type
rabbitmqctl list_bindings source destination routing_key
```

Type `exit` to leave the container.

> Port-forwarding the management UI from a Container App is not first-class on Container Apps Environments today. Stick to the exec-based CLI recipes above. Revisit the proper port-forward / second-ingress pattern when AzureRM 4.x exposes `additional_port_mappings`.

### Credentials (for tooling that must speak AMQP from a workstation - rare)

- **Username**: from the `rabbitmq_username` tfvar (committed in `infra/envs/{env}.tfvars`).
- **Password**: secret name `rabbitmq-password` in Key Vault `ea-{env}-kv-{suffix}`. To retrieve:

  ```bash
  az keyvault secret show \
    --vault-name ea-{env}-kv-{suffix} \
    --name rabbitmq-password \
    --query value -o tsv
  ```

  Requires **Key Vault Secrets User** on the vault.

---

## 5. Postgres Query Editor (zero-deploy Postgres UI)

For ad-hoc reads against the live database. Two paths depending on your Flexible Server SKU.

### Path A — Portal Query Editor (General Purpose / Memory Optimized SKUs only)

The **Query editor (preview)** blade is only available on General Purpose and Memory Optimized tier Flexible Servers. It does **not** appear on Burstable-tier SKUs (e.g. `B_Standard_B1ms`, the current dev default).

If your server is on an eligible SKU:

1. In the portal top search bar, type **PostgreSQL flexible server** and select the matching service.
2. From the result list, click the server `ea-{env}-pgsql-{suffix}`.
3. Left nav -> **Settings** group -> **Query editor (preview)**.
4. On the login pane:
   - **Authentication type**: *PostgreSQL authentication*.
   - **Login**: value of the `postgres_admin_username` tfvar (committed in `infra/envs/{env}.tfvars`).
   - **Password**: value of the `postgres-admin-password` secret in Key Vault `ea-{env}-kv-{suffix}`. Retrieve with:

     ```bash
     az keyvault secret show \
       --vault-name ea-{env}-kv-{suffix} \
       --name postgres-admin-password \
       --query value -o tsv
     ```

   - **Database**: `ea` (value of the `postgres_database_name` tfvar).
5. Click **OK**.

### Path B — psql from Cloud Shell or devcontainer (all SKUs)

Use this path when the server is on the Burstable tier, or when you prefer a CLI workflow. Azure Cloud Shell has network access via the "Allow Azure services" firewall rule; connecting from a local machine requires adding your IP to the server's firewall first.

```bash
# Retrieve the admin password from Key Vault
PG_PASS=$(az keyvault secret show \
  --vault-name ea-{env}-kv-{suffix} \
  --name postgres-admin-password \
  --query value -o tsv)

# Connect and run a query
psql "host=ea-{env}-pgsql-{suffix}.postgres.database.azure.com \
      port=5432 dbname=ea sslmode=require \
      user=eaadmin password=${PG_PASS}" \
  -c 'select count(*) from models;'
```

### Useful read-only queries

```sql
-- How many models are in the system?
select count(*) from models;

-- Twenty most recent models
select id, name, created_at_utc
from models
order by created_at_utc desc
limit 20;

-- Recent audit rows (cross-check guest vs. real-user flows, verify actor identity)
select action, entity_type, entity_id, actor_name, actor_oid, actor_idp, occurred_at_utc
from audit_events
order by occurred_at_utc desc
limit 20;

-- Audit trail for a specific entity
select action, actor_name, actor_email, occurred_at_utc
from audit_events
where entity_type = 'Model' and entity_id = '<guid>'
order by occurred_at_utc desc;
```

The Query Editor enforces a per-statement timeout (~5 minutes) and is read-or-write capable - **be careful** running anything beyond `select` from this surface in production.

---

## 5a. Audit events

The `audit_events` table records every domain mutation made through the API. Rows are emitted automatically by the `AuditStampingInterceptor`, which hooks into EF Core's `SaveChanges` pipeline. No application code needs to call audit explicitly - the interceptor detects added or modified domain entities and writes an `AuditEvent` row in the same transaction.

### Audited actions

| Action | Trigger |
|---|---|
| `model.created` | A new `Model` entity is inserted |
| `model.updated` | An existing `Model` entity is modified |
| `model.archived` | A `Model` is soft-deleted (archived) |
| `modelrun.requested` | A new `ModelRun` entity is inserted (run request) |

### Actor identity

Each audit row captures the authenticated user's identity from the Entra ID JWT claims:

- `actor_oid` - Entra object ID (`oid` claim)
- `actor_tid` - Entra tenant ID (`tid` claim)
- `actor_idp` - identity provider (`idp` claim; values include `"google.com"`, `"EmailOTP"`, `"guest"`, `"dev"`)
- `actor_name` - display name (`name` claim)
- `actor_email` - email address (`emails` claim)

Seed operations and background consumers (data-engine messages processed by MassTransit) do **not** generate audit rows. This is correct by design - `HttpContext.User.Identity.IsAuthenticated` is `false` in those contexts, so the interceptor skips audit emission.

### API endpoint

Audit events are queryable through the API:

```
GET /api/v1/audit-events?page=1&pageSize=20&entityType=Model&entityId={guid}&actorOid={guid}
```

All query parameters are optional. The response is a paginated list of audit event records.

### psql quick-check

```sql
-- Twenty most recent audit events
SELECT action, entity_type, entity_id, actor_name, occurred_at_utc
FROM audit_events
ORDER BY occurred_at_utc DESC
LIMIT 20;

-- All mutations by a specific user
SELECT action, entity_type, entity_id, occurred_at_utc
FROM audit_events
WHERE actor_oid = '<entra-oid>'
ORDER BY occurred_at_utc DESC;
```

---

## 6. Cost guardrails

### Check Application Insights ingestion

1. Portal top search bar -> **Cost Management + Billing** -> **Cost analysis**.
2. **Scope**: select the subscription that owns the App Insights instance.
3. Top-left filter pill -> **Add filter** -> **Service name** = *Azure Monitor*.
4. Group by **Resource** to see per-instance ingestion cost. Look for `ea-{env}-appi-{suffix}`.
5. Time range: **Last 30 days** for trend, or **This month** for budget tracking.

The first 5 GB / month / subscription is free under Azure Monitor pricing. With prod sampling at 20%, you should see ingestion comfortably inside that threshold for the current traffic shape.

### Confirm prod sampling is actually working

The cheapest sanity check is the `itemCount` query from [Section 2 query E](#step-3-kql-starter-queries) - if `itemCount` is consistently `1` in the prod App Insights instance, sampling is silently disabled and ingestion will balloon. Expected value is approximately `5` (one of every five spans was kept at the `0.2` sampling rate). If you see `1`:

- Confirm the API container is running with the prod build (sampling is gated on `IsDevelopment` in [`api/src/EA.Api/Program.cs`](../../api/src/EA.Api/Program.cs)).
- Confirm the data engine container has `OTEL_TRACES_SAMPLER=parentbased_traceidratio` and `OTEL_TRACES_SAMPLER_ARG=0.2` set:

  ```bash
  az containerapp show \
    --name ea-production-data-engine \
    --resource-group ea-production-rg \
    --query "properties.template.containers[0].env[?name=='OTEL_TRACES_SAMPLER' || name=='OTEL_TRACES_SAMPLER_ARG']"
  ```

### Per-table ingestion breakdown (when the bill spikes)

If ingestion exceeds expectation, run this against the App Insights instance to find the offender table:

```kql
union withsource = SourceTable *
| where TimeGenerated > ago(24h)
| summarize SizeMB = sum(_BilledSize) / 1024 / 1024 by SourceTable
| order by SizeMB desc
```

Common offenders: `traces` (lower a noisy logger from `Information` to `Warning`), `dependencies` (turn off SQL command-text capture), or platform diagnostic categories you do not actually use - prune those at the diagnostic-setting level in [`infra/modules/diagnostics/main.tf`](../../infra/modules/diagnostics/main.tf).

---

## 7. Negative-path sanity checks

These confirm the pipeline catches the failures it is supposed to catch. Run on the **dev** environment only.

### Kill the API briefly, confirm UI errors land under `ea-ui`

1. Stop the API revision:

   ```bash
   az containerapp update \
     --name ea-dev-api \
     --resource-group ea-dev-rg \
     --min-replicas 0 --max-replicas 0
   ```

2. From a browser, drive any SPA action that hits the API (e.g. open the Models list).
3. Restore the API:

   ```bash
   az containerapp update \
     --name ea-dev-api \
     --resource-group ea-dev-rg \
     --min-replicas 1 --max-replicas 3
   ```

4. In the App Insights blade, left nav -> **Investigate** group -> **Failures**. Top filter -> **Role** -> *ea-ui*. Expect `XHR` / `fetch` failures from the SPA captured during the outage window. Drill into one and confirm the stack trace points at the SPA code path that issued the call.

### Publish a malformed message, confirm data engine exception correlates

1. Publish a malformed message via the API (use a known-bad payload your contract validation rejects downstream of the publish):

   ```bash
   curl -X POST https://<api-fqdn>/api/v1/models/<id>/analyze \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"intentionally":"broken"}'
   ```

2. Capture the request's `traceId` from the response correlation header (`request-id`) or from the `requests` table:

   ```kql
   requests
   | where cloud_RoleName == "ea-api"
   | where url endswith "/analyze"
   | top 1 by timestamp desc
   | project timestamp, operation_Id, name
   ```

3. Use that `operation_Id` to pull the correlated exception on the data engine:

   ```kql
   exceptions
   | where operation_Id == "<paste operation_Id>"
   | project timestamp, cloud_RoleName, type, outerMessage
   ```

   Expect an exception row with `cloud_RoleName == "ea-data-engine"` and the same `operation_Id`. This proves W3C trace-context propagated across the RabbitMQ hop.

---

## 8. Troubleshooting "no telemetry"

Walk this list top-to-bottom; each step rules out one cause.

### Is the connection string wired?

For each running container, confirm the env var is present:

```bash
az containerapp show \
  --name ea-{env}-api \
  --resource-group ea-{env}-rg \
  --query "properties.template.containers[0].env[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"

az containerapp show \
  --name ea-{env}-data-engine \
  --resource-group ea-{env}-rg \
  --query "properties.template.containers[0].env[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"
```

If empty, the latest `terraform apply` did not wire the App Insights output through to the Container App env. Re-check [`infra/outputs.tf`](../../infra/outputs.tf) for `application_insights_connection_string` and the consuming Container App module wiring.

### Did the UI build pick up the connection string?

The SPA injects the connection string at **build time** via [`ui/scripts/generate-environment.mjs`](../../ui/scripts/generate-environment.mjs), driven by [`.github/scripts/build-ui.sh`](../../.github/scripts/build-ui.sh). To confirm a deployed bundle has it:

```bash
# From a workstation, fetch the deployed SPA's main bundle
curl -s https://<swa-hostname>/main-<hash>.js | grep -o 'InstrumentationKey=[a-f0-9-]*' | head -1
```

(The bundle filename is hashed - inspect the SWA's served `index.html` to find the actual `main-*.js` filename.)

If `InstrumentationKey=` does not appear, CI built the SPA without the App Insights connection string. Confirm the `application_insights_connection_string` Terraform output is being passed into the SWA build environment in [`.github/workflows/swa-deploy.yml`](../../.github/workflows/swa-deploy.yml).

### Is the SDK initialize call guarded behind that env var?

The data engine's `configure_azure_monitor(...)` call in [`data-engine/src/data_engine/main.py`](../../data-engine/src/data_engine/main.py) is conditional on `APPLICATIONINSIGHTS_CONNECTION_STRING` being set. If the env var is present but no telemetry lands, the next likely culprit is an exception thrown during initialization that the conditional swallows. Tail container logs and look for SDK-level errors:

```bash
az containerapp logs show \
  --name ea-{env}-data-engine \
  --resource-group ea-{env}-rg \
  --tail 200 --follow
```

For the API, the equivalent check is that `UseAzureMonitor(...)` is reached; it pulls the connection string from `APPLICATIONINSIGHTS_CONNECTION_STRING` automatically. Container logs will show a one-line confirmation at startup; absence of any Azure Monitor log line is the symptom.

### Is the role name right?

If telemetry lands but the Application Map shows everything as `<unknown>`, `OTEL_SERVICE_NAME` (or the equivalent SDK-side `cloudRoleName`) is not set:

```bash
az containerapp show \
  --name ea-{env}-data-engine \
  --resource-group ea-{env}-rg \
  --query "properties.template.containers[0].env[?name=='OTEL_SERVICE_NAME']"
```

For the SPA, confirm `cloudRoleName: 'ea-ui'` is present in [`ui/src/app/core/app-insights.service.ts`](../../ui/src/app/core/app-insights.service.ts) and that the build picked up that file.

### Is the LAW receiving platform diagnostics?

If app telemetry works but Postgres / SWA / ACR diagnostic categories are missing in Log Analytics, confirm the diagnostic settings actually applied:

```bash
az monitor diagnostic-settings list \
  --resource <full-resource-id-of-postgres-or-swa-or-acr> \
  --query "[].{name:name, logs:logs[].category, metrics:metrics[].category}"
```

Expect to see a setting whose categories match what [`infra/modules/diagnostics/main.tf`](../../infra/modules/diagnostics/main.tf) declares for that resource type. If the list is empty, re-run `terraform apply` and check for errors on the diagnostics module - a common cause is a stale resource ID after a resource was recreated.
