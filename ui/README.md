# UI — Next.js 16

Next.js App Router application for managing models and runs. It uses a server-side runtime-configuration endpoint so the same container image can target Azure or AWS without a rebuild.

## Runtime configuration

| Variable | Purpose |
|---|---|
| `DEPLOYMENT_TARGET` | `local`, `azure`, or `aws`; displayed in the shell and available to diagnostics. |
| `API_URL` | Public API origin. |
| `AUTH_PROVIDER` | `none`, `entra`, or `cognito`. |
| `AUTH_AUTHORITY` | OIDC issuer/authority. |
| `AUTH_CLIENT_ID` | Public browser client ID. |
| `AUTH_API_SCOPE` | API access scope requested during Authorization Code + PKCE. |
| `AUTH_LOGOUT_ENDPOINT` | Optional provider-managed logout origin; required for Cognito cookie logout. |
| `ENABLE_DEV_AUTH` | Enables the local/deployed-development synthetic session. |
| `ENABLE_GUEST_AUTH` | Enables an explicit temporary demo guest; false by default for every cloud. |

The browser reads these values from `/api/runtime-config`; secrets must never be exposed through that route. Provider-specific behavior is contained in the authentication adapter in `components/AuthProvider.tsx` and `utils/oidcManager.ts`.

## Structure and styling

- Route components live under `app/`; reusable components use matching PascalCase filenames under `components/`.
- Shared primitives such as buttons, cards, tables, pagination, filters, and page layouts live under `components/ui/`.
- React/browser hooks live under `hooks/`; framework-independent helpers live under `utils/`; API contracts and clients live under `lib/`.
- Tailwind utilities style components. `app/globals.css` is limited to the Tailwind import and shared semantic theme tokens.

## Commands

```bash
npm ci
npm run dev       # http://localhost:3000
npm run lint
npm test
npm run build
npm start         # Next.js production server on :3000 after npm run build
```

Inside `ea-dev-env`, prefer the `run-ui` alias so application output and process lifecycle metadata are captured under `__logs/local/ui-latest.log`.

The production Docker image uses Next.js standalone output, listens on port 3000, and runs as a non-root user. OpenTelemetry is registered through `instrumentation.ts`; exporters are selected by the deployment environment.
