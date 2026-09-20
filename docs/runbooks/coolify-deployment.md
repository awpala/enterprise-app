# Coolify portfolio deployment runbook

## Deployment contract and current checkpoint

Coolify is the evergreen home for this disposable portfolio demo. Every push to `main` deploys through Coolify's native GitHub App integration. AWS and Azure are independent, optional demonstrations, selected explicitly. Coolify requires no Terraform execution, state, cloud hosting credentials, GitHub Actions deployment workflow, or deployment enablement flag.

**Current checkpoint:** the operator has created the Coolify Compose application with `/compose.prod.yaml`. DNS for all four domains is verified. The stack and application changes are implemented locally. Provider credentials are available locally. The feature branch and draft PR are published; the full production stack and API integration checks passed in CI. The first live deployment remains to be completed.

All deployments own separate databases and queues. Complete loss of demo data and local identities is acceptable on all targets. Named volumes preserve state during routine redeploys; backups, replication, restoration exercises, and high availability are outside scope. Recovery recreates this application and seeds fresh data.

| Setting | Value |
|---|---|
| Coolify host | Existing Hetzner CX33, x64/amd64, 8 GB RAM, shared with other projects |
| Coolify / proxy | 4.3.23 / Traefik |
| GitHub App/source | `enterprise-app-coolify` |
| Repository / branch | `awpala/enterprise-app` / `main` |
| Build pack / base directory / Compose location | Docker Compose / `/` / `/compose.prod.yaml` |
| Environment | Production only |
| Application | `https://ent-app.portfolio-projects.dev` |
| Identity broker | `https://ent-app-auth.portfolio-projects.dev` |
| RabbitMQ Management | `https://ent-app-mq.portfolio-projects.dev` |
| pgAdmin 4 | `https://ent-app-db.portfolio-projects.dev` |
| Visitor authentication | Google or Microsoft through self-hosted Keycloak, plus guest access |
| Operator authentication | Separate passwords for Keycloak, RabbitMQ, and pgAdmin |
| Telemetry | Coolify container logs, health probes, RabbitMQ Management, and pgAdmin |

Guest visitors share the same read/write demo dataset as signed-in users. Sign-in provides audit identity, not private workspaces. Developer impersonation is disabled. Guest access does not apply to the administrative interfaces.

The domains above are public portfolio addresses. Keep deployment server addresses, provider-generated IDs, and secrets out of tracked configuration. No additional hosting or paid identity subscription is required by this stack; provider account eligibility is checked during setup.

## 1. DNS and Coolify resource

In Porkbun, create four `A` records under `portfolio-projects.dev`, all pointing to the existing deployment server: `ent-app`, `ent-app-auth`, `ent-app-mq`, and `ent-app-db`. Only add `AAAA` records if that server already serves IPv6 correctly. Leave other projects' DNS records unchanged. [Porkbun subdomain instructions](https://kb.porkbun.com/article/200-how-to-create-a-subdomain)

The operator has already installed the dedicated GitHub App using Coolify's automated setup and initialized the Compose resource. Once this implementation is published to `main`, use these resource settings:

| Coolify setting | Value |
|---|---|
| Source | `enterprise-app-coolify` |
| Repository | `awpala/enterprise-app` |
| Branch / commit | `main` / `HEAD` |
| Build pack | Docker Compose |
| Base directory | `/` |
| Docker Compose location | `/compose.prod.yaml` |
| Auto Deploy | Enabled |
| Watch Paths | Empty, so every push to `main` deploys |
| Preview deployments | Disabled |
| Strip Prefix | **Disabled**; API paths must reach ASP.NET Core intact |
| HTTPS | Enabled for every public domain |

The GitHub App supplies repository access and push webhooks. No additional Coolify API token or GitHub Actions deployment secret is needed. Native Coolify behavior skips commits containing `[skip ci]` or `[skip cd]`; avoid those markers when a deployment is wanted. CI runs independently and does not gate Coolify. [GitHub App setup](https://coolify.io/docs/applications/sources/github/app), [native auto-deploy](https://coolify.io/docs/applications/sources/github/auto-deploy)

## 2. Local credentials and Coolify environment

Run from the repository root:

```bash
python3 deploy/coolify/init-env.py
```

This creates the ignored `deploy/coolify/.env` with randomly generated service passwords and owner-only file permissions. An existing file is preserved. The file has already been generated in the current workspace, including the pgAdmin password. Enter provider credentials there as setup progresses; do not paste them into chat. Copy its values into the application's **production** environment variables in Coolify before deployment. For every variable, enable **Runtime** and disable **Build time**. None of these values is a Docker build argument. [Coolify variable scopes](https://coolify.io/docs/applications/configuration/environment-variables)

| Variable | Purpose |
|---|---|
| `APP_ORIGIN` | Application HTTPS origin, without trailing slash |
| `AUTH_ORIGIN` | Keycloak HTTPS origin, without trailing slash |
| `POSTGRES_PASSWORD` | PostgreSQL operator account `ea_admin`; also used when connecting from pgAdmin |
| `APP_DB_PASSWORD` | Internal application database user `ea_app` |
| `KEYCLOAK_DB_PASSWORD` | Internal Keycloak database user `ea_keycloak` |
| `RABBITMQ_PASSWORD` | Broker account `ea_app`, including Management UI login |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak administrator `admin` in the `master` realm |
| `PGADMIN_EMAIL` | pgAdmin login name; default `admin@portfolio-projects.dev`, editable before initialization |
| `PGADMIN_PASSWORD` | pgAdmin login password, separate from the database password |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Google Web OAuth client for the broker |
| `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET` | Microsoft application ID and client secret **Value** |

Use the generated hex database passwords to avoid connection-string and Compose interpolation delimiters. Store secrets in Coolify and the ignored file or a password manager. Only public URLs and client configuration reach `/api/runtime-config`.

The Microsoft registration can also be created with `python3 deploy/coolify/setup-microsoft.py` after `az login` in Default Directory. The helper creates only the dedicated provider registration, appends a credential, and writes its values into the ignored file without printing them; existing local Microsoft values are preserved.

Initial database users, Keycloak imports, and the pgAdmin login are created once. Changing a bootstrap password in Coolify alone does not rotate an existing account. Update the actual account too, or reset this demo's affected state intentionally. pgAdmin email delivery is disabled; its login name need not be a new mailbox.

## 3. Google and Microsoft provider setup

Keycloak is free, self-hosted software. The existing UI uses Authorization Code + PKCE against its `enterprise-app` realm. The browser client is `ea-ui`; access tokens carry audience `ea-api` and scope `access_as_user`. Google and Microsoft redirect to Keycloak, which redirects to the UI. [Keycloak project](https://www.keycloak.org/), [realm import behavior](https://www.keycloak.org/server/importExport)

### Google

1. Sign into [Google Cloud project creation](https://console.cloud.google.com/projectcreate), create `enterprise-app-coolify`, and choose **No organization** if offered. An existing suitable project also works.
2. Open **Google Auth platform → Branding → Get started**. Set the name to **Enterprise App**, supply your support/contact email, and choose **External** audience.
3. Add `portfolio-projects.dev` as an authorized domain and complete the requested branding/domain information. Under **Data Access**, request only `openid`, `profile`, and `email`.
4. Under **Clients**, create a **Web application** named **Enterprise App Keycloak**. Add this exact authorized redirect URI:

   ```text
   https://ent-app-auth.portfolio-projects.dev/realms/enterprise-app/broker/google/endpoint
   ```

5. Save the client ID and secret in the corresponding `.env` fields, then in Coolify.
6. Under **Audience**, set publishing status to **In production** for the public demo and complete any provider-requested checks. Google's testing restrictions have an exception for basic identity scopes; do not assume a test-user list is always required for this scope set.

No Gmail API access or Google-hosted runtime is involved. [Project creation](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects), [OAuth setup](https://developers.google.com/workspace/guides/configure-oauth-consent), [OIDC](https://developers.google.com/identity/openid-connect/openid-connect), [audience settings](https://support.google.com/cloud/answer/15549945?hl=en)

### Microsoft

Start at [Entra](https://entra.microsoft.com) using the account from the earlier Azure setup. Prefer its existing **Default/workforce directory**, where **Entra ID → App registrations** is available. This registration does not require restoring Azure application hosting. A prior External ID customer directory is a different directory type.

If no usable workforce directory is available, check account eligibility before creating one: Microsoft currently restricts additional workforce-tenant creation to paid customers and directs users without an initial tenant to its free-account signup path. Do not create paid infrastructure merely to obtain sign-in. [Tenant creation](https://learn.microsoft.com/en-us/entra/fundamentals/create-new-tenant)

Once the directory is available:

1. Create **Enterprise App Coolify** under **App registrations → New registration**.
2. Select **Accounts in any organizational directory and personal Microsoft accounts**. This covers work/school accounts and personal Outlook/Hotmail/Microsoft accounts, subject to organizational consent policies.
3. Add a **Web** redirect URI:

   ```text
   https://ent-app-auth.portfolio-projects.dev/realms/enterprise-app/broker/microsoft/endpoint
   ```

4. Retain delegated Microsoft Graph `User.Read`, which the Microsoft broker uses for the profile.
5. Under **Certificates & secrets**, create a client secret. Save its **Value**, not its secret ID, as `MICROSOFT_CLIENT_SECRET`, and the Application client ID as `MICROSOFT_CLIENT_ID`. Record the expiration in your password manager for later rotation.

[Microsoft application registration](https://learn.microsoft.com/en-us/graph/auth-register-app-v2), [supported accounts](https://learn.microsoft.com/en-us/entra/identity-platform/v2-supported-account-types)

Existing AWS/Azure provider registrations can remain in their projects. These dedicated clients use only the Coolify broker callbacks. The UI callback is separately fixed at `https://ent-app.portfolio-projects.dev/auth/callback`.

## 4. Domain routing and first deployment

The root [compose.prod.yaml](../../compose.prod.yaml) builds the existing UI, API, worker, and EF migration images plus small PostgreSQL, Keycloak, and pgAdmin image wrappers. RabbitMQ uses its Management image. Bootstrap configuration is packaged into images; there are no runtime repository bind mounts.

In Coolify, attach these domain values to the corresponding Compose services. The port in each setting selects the **internal destination port**; visitors use ordinary HTTPS without a port suffix.

| Compose service | Coolify domain field |
|---|---|
| `ea-ui` | `https://ent-app.portfolio-projects.dev:3000` |
| `ea-api` | `https://ent-app.portfolio-projects.dev:8000/api/v1,https://ent-app.portfolio-projects.dev:8000/health` |
| `ea-keycloak` | `https://ent-app-auth.portfolio-projects.dev:8080` |
| `ea-rabbitmq` | `https://ent-app-mq.portfolio-projects.dev:15672` |
| `ea-pgadmin` | `https://ent-app-db.portfolio-projects.dev:8080` |

Disable **Strip Prefix**. Coolify generates Traefik routing for the longer API paths while `/api/runtime-config`, `/api/health`, and all pages remain with Next.js. Use managed domains without adding competing custom Traefik labels. PostgreSQL port 5432 and RabbitMQ AMQP port 5672 remain private to the application network. [Coolify Compose routing](https://coolify.io/docs/applications/builds/docker-compose)

Deploy once the selected revision and all credentials are available. PostgreSQL initializes separate application and Keycloak databases/users. EF migrations must finish before API/worker startup; the API then seeds demo data. The completed migration container is excluded from Coolify's aggregate health with `exclude_from_hc`, while a failure still blocks its dependents. RabbitMQ retains a stable node hostname and named volume.

The services have initial memory limits suited to this small demo; actual available memory depends on the other projects on the shared 8 GB server. Build-time memory is additional. Inspect Coolify logs and host utilization if a build or service is killed. Do not add Docker inside the development container; image/Compose execution belongs in CI or on a Docker-capable host.

### Operator visibility

- **RabbitMQ:** open `https://ent-app-mq.portfolio-projects.dev`, sign in as `ea_app` with `RABBITMQ_PASSWORD`, and inspect **Queues and Streams**, consumers, unacknowledged/ready messages, and message rates. The initial broker account has administrator permissions. Queue depth often returns to zero immediately for this small workload. [RabbitMQ management](https://www.rabbitmq.com/docs/management)
- **pgAdmin:** open `https://ent-app-db.portfolio-projects.dev`, sign in with `PGADMIN_EMAIL` / `PGADMIN_PASSWORD`, then expand the preconfigured **Coolify → Enterprise App** server. Enter `POSTGRES_PASSWORD` for database user `ea_admin`. Browse `ea_app → Schemas → public → Tables` for models and runs. The same server also contains `ea_keycloak`. The database password is not embedded in the tracked server definition. [pgAdmin container configuration](https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html)
- **Keycloak:** open `https://ent-app-auth.portfolio-projects.dev/admin/`, sign in as `admin`, and select realm `enterprise-app` to inspect identity providers, sessions, and users.
- **Application/worker logs:** use the corresponding Coolify service logs. These are operational visibility tools; no cloud telemetry exporter is required.

### Acceptance checks

After deployment, run from the repository root:

```bash
python3 deploy/coolify/smoke.py
```

This uses no Terraform or cloud credentials. It checks HTTPS endpoints, runtime configuration, the Keycloak login page, administrative UI reachability, invalid-bearer rejection, and a real guest run through the queue. It adds one run to the seeded demo data. CI builds the same stack with synthetic credentials and loopback ports using `.github/scripts/check-coolify-stack.py`; external provider sign-in and public HTTPS routing still require the live browser checks below.

| Check | Expected result |
|---|---|
| HTTPS/routing | Valid HTTPS on all four domains; UI and API health endpoints respond |
| Public runtime config | Target `coolify`, provider `oidc`, correct URLs, guest enabled and dev disabled, no secrets |
| Guest workflow | Browse/create a model, request a run, observe completion and computed metrics |
| Provider sign-in | Google and personal Microsoft sign-in return to the UI and allow an API action; work/school where tenant consent allows |
| Session lifecycle | Renewed tokens update UI state; local/Keycloak logout succeeds |
| Invalid bearer | Rejected even with header-free guest access enabled |
| Administrative UIs | Password login works; pgAdmin displays seeded tables; RabbitMQ displays worker/consumer activity |
| Redeploy | Migration succeeds again; application remains usable; named-volume data remains available |
| Independence | Application runs while AWS and Azure hosting are absent |

A running worker without a health check is not proof of successful processing: verify a completed run. API readiness currently checks PostgreSQL only. Publication is not a transactional outbox; this deployment does not change that guarantee. Actual upstream login and browser renewal remain manual acceptance checks.

## 5. Routine delivery, cloud demonstrations, and resets

Push to `main` to deploy Coolify through the existing GitHub App webhook. Every push is eligible; there are no watch-path filters, special enablement flags, CI dependency, or Terraform invocation in this path. Keep native **Auto Deploy** enabled. The first live deployment and the next push-triggered deployment are separate verification steps.

The independent [cloud workflow](../../.github/workflows/deploy.yml) uses `DEPLOYMENT_TARGETS=none` to skip both cloud adapters successfully. The repository variable has already been set to `none`. Older workflow revisions reject this value until the new resolver is published, so they fail validation without deploying. Missing/invalid selection never defaults to a provider.

For a cloud-specific prospect, leave `DEPLOYMENT_TARGETS=none` and manually dispatch `deploy.yml`, choosing `aws`, `azure`, or `both` and the existing cloud environment. AWS onboarding preserves push policy. If automatic cloud pushes are wanted temporarily, set the repository variable explicitly and return it to `none` afterward. These choices never affect Coolify. CI may validate Terraform without provisioning anything.

The operator confirms both cloud deployments are currently torn down. No teardown is needed for this setup. End later cloud demonstrations using the selected provider's teardown procedure; disabling push deployment itself does not delete resources. All demo data is disposable on every target.

For a failed Coolify release, inspect the service logs and push a fix. PostgreSQL initialization and Keycloak realm import happen on empty state only. Updating the realm JSON does not overwrite an existing realm; apply later client/provider changes in Keycloak's admin console as well as the tracked bootstrap configuration. Rotate provider secrets in both Coolify and the established identity-provider configuration.

For a fresh demo, stop only this Coolify application, remove its selected persistent storage volumes through Coolify, and redeploy. Removing the database volume recreates both databases and Keycloak identities; sessions are invalidated. Remove the RabbitMQ and pgAdmin volumes too when a completely fresh stack is intended. Keep the environment values so bootstrap can run again. Do not use host-wide prune commands on this shared server. There is no backup gate.

## Progress log

| Item | Evidence / status |
|---|---|
| DNS | All four names resolve to the intended server |
| Source/resource | Operator confirms GitHub App baseline setup and Compose resource at `/compose.prod.yaml` |
| Cloud selection | `DEPLOYMENT_TARGETS=none` read back through GitHub CLI; both clouds inactive per operator |
| Local implementation | Compose, realm/database bootstrap, admin UIs, OIDC adapter, cloud opt-out, and runbook present |
| Local secrets | Ignored `.env` contains service passwords and provider credentials; no values tracked |
| Provider setup | Operator supplied Google client credentials; dedicated Microsoft app created and verified through Azure CLI (credential expires September 20, 2027) |
| Publication and container validation | Feature branch / PR 24 published; Compose build, startup, guest run, repeat migrations, and API integration tests passed in CI |
| Live deployment / browser verification / push auto-deploy | Pending |
