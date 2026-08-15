# ADR 0003 - Multi-cloud application and deployment contract

## Status

Accepted. 2026-08-15.

## Context

Adding `infra/aws` beside an Azure-shaped root would preserve Azure coupling in directory layout, runtime settings, authentication claims, telemetry exporters, CI, and the browser build. That would create two nominal deployment targets but only one first-class architecture.

Authentication is the most sensitive boundary. Entra External ID and Cognito issue different claim shapes and have different federation controls, yet the API, audit records, message headers, and UI need one stable user contract. The Angular UI also embedded Entra and Application Insights settings at build time and depended on Static Web Apps, preventing promotion of the same artifact to AWS.

## Decision

Adopt a provider-neutral application contract and two provider-specific adapters.

1. Keep common orchestration at `infra/` and provider implementations at the peer paths `infra/azure` and `infra/aws`. Never place AWS underneath an Azure root or make one provider's state own the other provider.
2. Select `azure` or `aws` at deployment time through `infra/scripts/deploy.sh` and provider-specific CI jobs. Both Terraform roots expose normalized outputs: `application_url`, `api_url`, `container_registry`, `migration_workload`, `auth_authority`, `auth_client_id`, and `auth_api_scope`.
3. Replace Angular with a Next.js 16 standalone server on port 3000. Run that same container on Azure Container Apps, AWS ECS, and local Compose. Read public configuration at request time from `/api/runtime-config`; never bake cloud or environment values into the image.
4. Define normalized authentication settings for the API (`Authentication:*`) and UI (`AUTH_*`). Deployment selects `entra` or `cognito`. The API uses generic JWT bearer validation and enforces provider-specific token semantics only inside the adapter boundary. Domain code consumes stable `SubjectId`, `TenantId`, and `IdentityProvider` values.
5. Preserve the synthetic development and guest modes as explicit environment flags. They are disabled unless deployment configuration opts in and are never substitutes for production SSO.
6. Instrument API and worker code with OpenTelemetry. Select `azuremonitor`, `otlp`, or `none` at runtime. Azure Monitor and AWS ADOT are exporter adapters, not domain dependencies.
7. Treat provider identity feature sets as analogous, not identical. Every enabled client type must have a parity row, an owner, and evidence in the AWS workbook before production approval.

This ADR supersedes the Azure-only scope of ADR 0001 for future architecture. ADR 0001 remains an immutable record of the original observability decision; Azure Monitor remains the Azure adapter, while OTLP/ADOT is the AWS adapter.

## Consequences

### Positive

- The same API, worker, UI image, message contracts, and local stack run for either target.
- A browser artifact can be promoted without recompiling secrets or provider identifiers into JavaScript.
- Authentication differences are contained and testable.
- Azure is now visibly a provider implementation rather than the repository default.
- A future provider can implement the normalized contract without changing domain services.

### Negative and follow-up work

- Provider modules intentionally differ internally; forcing one Terraform module abstraction across unrelated resource APIs would hide important behavior.
- Legacy database column and transport-header names containing `oid`, `tid`, or `idp` remain for data compatibility. Their values are now normalized and must be renamed only through an explicit data migration/versioned message change.
- Next.js server hosting costs more than static-file hosting. It is required for runtime configuration and identical artifacts; scale-to-zero or edge caching can be evaluated later.
- Entra and Cognito logout/federation edge cases require provider-specific integration tests.
- Azure browser telemetry from the former Angular SDK is removed. Server telemetry is retained; browser real-user monitoring needs a provider-neutral follow-up decision.

## Rejected alternatives

- **Keep Azure Terraform at `infra/` and add `infra/aws`:** rejected because it encodes Azure as the privileged default.
- **Build one UI bundle per cloud:** rejected because configuration drift and artifact provenance become harder to control.
- **Use provider SDK types in domain interfaces:** rejected because token and telemetry claim shapes would leak into persistence and messages.
- **Build a single cross-cloud Terraform root:** rejected because provider state lifecycles, credentials, failure modes, and rollbacks must remain independent.
