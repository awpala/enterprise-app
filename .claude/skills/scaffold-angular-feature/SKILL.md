---
name: scaffold-angular-feature
description: Creates a new Terraform module for an Azure resource concern.
disable-model-invocation: false
---

## Inputs

- **Feature name** (e.g., `analysis-jobs`)
- **Views needed** (e.g., `list`, `detail`, `create`)
- **API endpoints it consumes** (e.g., `GET /api/v1/analysis-jobs`, `POST /api/v1/analysis-jobs`)

## What It Produces

1. **Feature directory** at `ui/src/app/features/{feature-name}/`
2. **Route configuration** with lazy loading in `app.routes.ts`
3. **Service class** at `ui/src/app/core/services/{feature-name}.service.ts` — typed HTTP calls
4. **TypeScript interfaces** at `ui/src/app/core/models/{feature-name}.model.ts` — matching API DTOs
5. **Standalone components** for each view: `{feature-name}-list.component.ts`, `{feature-name}-detail.component.ts`, etc.
6. **SignalStore** (if shared state needed) at `features/{feature-name}/{feature-name}.store.ts`

## Conventions Applied

- All components are standalone (`standalone: true`)
- Use `inject()` for DI, not constructor injection
- Service uses `HttpClient` with typed responses
- Components use `async` pipe or `toSignal()` — no manual `.subscribe()`
- Loading / error / empty states handled in templates
- Route path matches feature name in kebab-case
