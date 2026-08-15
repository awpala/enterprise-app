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

The browser reads these values from `/api/runtime-config`; secrets must never be exposed through that route. Provider-specific behavior is contained in the authentication adapter in `components/auth-provider.tsx`.

## Commands

```bash
npm ci
npm run dev       # http://localhost:3000
npm run lint
npm test
npm run build
npm start         # standalone production server on :3000
```

The production Docker image uses Next.js standalone output, listens on port 3000, and runs as a non-root user. OpenTelemetry is registered through `instrumentation.ts`; exporters are selected by the deployment environment.
