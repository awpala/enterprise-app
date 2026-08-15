---
name: scaffold-nextjs-feature
description: Creates a typed Next.js App Router feature backed by the enterprise API.
disable-model-invocation: false
---

## Inputs

- **Feature name** (for example, `analysis-jobs`)
- **Views needed** (for example, `list`, `detail`, `create`)
- **API endpoints it consumes** (for example, `GET /api/v1/analysis-jobs`)

## What It Produces

1. **Routes** under `ui/app/{feature-name}/`, using dynamic segments where needed.
2. **Feature components** under `ui/components/{feature-name}/` when a page has reusable UI.
3. **Typed API operations** in `ui/lib/api.ts` and domain types in `ui/lib/types.ts`.
4. **Vitest coverage** for configuration or behavior that can be tested without a browser.

## Conventions Applied

- Default to React Server Components; add `'use client'` only for browser state or events.
- Use the shared `ApiClient` so bearer tokens and API errors are handled consistently.
- Read deployment-specific public settings from `/api/runtime-config`; do not bake them into the image.
- Handle loading, error, empty, and unauthorized states explicitly.
- Use `next/link` or `useRouter()` for internal navigation.
- Keep routes and filenames in kebab-case and TypeScript strict.
- Use canonical port 3000 for local and container execution.
