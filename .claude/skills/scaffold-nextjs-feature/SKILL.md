---
name: scaffold-nextjs-feature
description: Creates a typed Next.js App Router feature backed by the enterprise API.
disable-model-invocation: false
---

## Inputs

- **Feature name** (for example, `model-runs`)
- **Views needed** (for example, `list`, `detail`, `create`)
- **API endpoints it consumes** (for example, `GET /api/v1/models/{id}/runs`)

## What It Produces

1. **Routes** under `ui/app/{feature-name}/`, using dynamic segments where needed.
2. **Feature components** under `ui/components/{feature-name}/` when a page has reusable UI.
3. **Typed API operations** in `ui/lib/api.ts` and domain types in `ui/lib/types.ts`.
4. **Hooks** under `ui/hooks/` and framework-independent helpers under `ui/utils/` when extraction is needed.
5. **Vitest coverage** for route, component, and state behavior.

## Conventions Applied

- Default to React Server Components; add `'use client'` only for browser state or events.
- Use the shared `ApiClient` so bearer tokens and API errors are handled consistently.
- Read deployment-specific public settings from `/api/runtime-config`; do not bake them into the image.
- Handle loading, error, empty, and unauthorized states explicitly.
- Use `next/link` or `useRouter()` for internal navigation.
- Keep route segments in kebab-case. Name component files in PascalCase to match the primary export; keep TypeScript strict.
- Use Tailwind utilities and reuse primitives under `ui/components/ui/`; do not add feature styling to the global stylesheet.
- Use canonical port 3000 for local and container execution.
