# UI — Angular 20 SPA

Single-page app for managing models and visualising runs. Authenticates users against Microsoft Entra ID via MSAL, calls the API with bearer tokens, and streams telemetry to Application Insights.

## Notable Libraries and Their Usage

| Package | Role | Rationale |
|---|---|---|
| `@angular/core` 20 | Framework | Standalone components + signals as the state primitive — no NgModules in feature code. |
| `@angular/material` 20 + `@angular/cdk` | UI kit | Consistent enterprise look without bespoke CSS; paired with custom theme tokens. |
| `@azure/msal-angular` + `@azure/msal-browser` 4 | Auth | Authorization Code flow with PKCE against Entra ID (see `auth/msal.config.ts`). |
| `@microsoft/applicationinsights-web` + `applicationinsights-angularplugin-js` | Client telemetry | Page view + route change tracking; correlates to API traces for full request stitching. |
| `@analogjs/vitest-angular` + `vitest` | Tests | Faster and simpler than Karma/Jasmine for a standalone-component-first codebase. |
| `rxjs` | Async glue | Kept narrow — HTTP and MSAL observables only; app state lives in signals. |

## Architectural Patterns

- **Standalone components + signals everywhere.** Feature components (`features/models/`, `features/runs/`, `features/dashboard/`, `features/landing/`) are standalone. Local state is `signal()`, derived state is `computed()`; `readonly` signals are exposed from services.
- **Runtime environment injection (non-obvious).** `scripts/generate-environment.mjs` runs on `postinstall` and before `build:prod`, emitting `src/app/environments/environment*.ts` from env vars. This is what lets the same codebase run in dev and prod SWA environments without hardcoded URLs — the SWA deploy step in `deploy.yml` passes the API URL at build time.
- **Bearer interceptor.** `auth/bearer-auth.interceptor.ts` attaches MSAL-acquired tokens to outbound HTTP requests bound for the API origin. Non-API requests are left untouched.
- **Route guards.** `auth/auth.guard.ts` blocks authenticated routes; unauthenticated users are redirected to login and failure funnels into `auth/login-failed.component.ts`.
- **Core services pattern.** All HTTP lives in `core/services/` (`model.service.ts`, `model-run.service.ts`), never in components. Services expose signals or observables; components consume via `toSignal` or templates.
- **Custom `UiStateService` with localStorage persistence.** Persists per-user UI preferences (sort, filters, theme) across sessions. Backed by signals plus a storage sync effect — see `core/services/ui-state.service.ts` and its test spec.
- **Theming.** `core/services/theme.service.ts` drives a Material custom theme; `shared/components/theme-toggle/` surfaces the control.
- **Error handling.** `core/app-insights-error-handler.ts` replaces the default `ErrorHandler` and pipes uncaught errors to App Insights with context.

## Project Structure (non-exhaustive)

| Path | Purpose |
|---|---|
| `src/app/auth/` | MSAL config, guard, bearer interceptor, login failure component |
| `src/app/core/` | Cross-cutting services (HTTP, App Insights, UI state, theme) |
| `src/app/features/` | Feature areas: `dashboard/`, `landing/`, `models/`, `runs/` |
| `src/app/shared/` | Reusable components (`layout`, `histogram`, `status-badge`, `confirm-dialog`, `theme-toggle`) and TS interfaces |
| `src/app/environments/` | Generated at build time by `scripts/generate-environment.mjs` |
| `scripts/generate-environment.mjs` | Env-to-TS generator — see note above |

## TypeScript Standards

- `strict: true`. No `any` without justification.
- `inject()` over constructor injection.
- JSDoc on exported APIs.

## Running Locally

Use the Compose stack (see [`../deploy/README.md`](../deploy/README.md)) for integrated testing. For UI-only iteration:

```bash
cd ui && npm install && npm start   # ng serve at :4200
```

`npm install`'s `postinstall` hook generates `environment.ts` from env vars; a missing API URL falls back to the dev default.

## Testing

| Suite | Command |
|---|---|
| Unit (vitest + jsdom) | `cd ui && npm test` |
| Lint | `cd ui && npm run lint` |

No E2E runner is wired up currently in the UI project; end-to-end coverage lives in the API's Testcontainers suite.

## Gotchas

- **Never edit `environment.ts` by hand.** It is overwritten by `generate-environment.mjs`. Change the generator or the env vars that feed it.
- **MSAL redirect URIs must match the Entra app registration exactly.** Configured in `auth/msal.config.ts`; in the cloud these are kept in sync by the `entra-external-id` Terraform module.
- **Zone.js is still present** (`zone.js ~0.15`) — some Angular internals still rely on it even in a signals-first codebase.
