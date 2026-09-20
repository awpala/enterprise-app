# Coolify portfolio deployment runbook

## Deployment contract and current checkpoint

Coolify is the evergreen home for this disposable portfolio demo. Every push to `main` deploys through Coolify's native GitHub App integration. AWS and Azure are independent, optional demonstrations, selected explicitly. Coolify requires no Terraform execution, state, cloud hosting credentials, GitHub Actions deployment workflow, or deployment enablement flag.

**Current checkpoint:** the evergreen Coolify deployment is live. The operator's push of `c245d92` to `main` automatically deployed successfully, and all six [CI checks passed](https://github.com/awpala/enterprise-app/actions/runs/35542960516). The full live smoke test passed again after that deployment on September 20, 2026: valid HTTPS on all four domains, UI/API health, runtime configuration, Keycloak discovery and provider buttons, administrative endpoint reachability, invalid-bearer rejection, and a guest job completing with computed metrics. The operator confirms Google and personal Microsoft sign-in both work. RabbitMQ operator authentication and queue visibility, plus pgAdmin operator authentication and server-group listing, are verified. AWS/Azure hosting remains inactive and `DEPLOYMENT_TARGETS=none`.

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
| Advanced → Proxy → Path prefixes | **Keep paths as-is** (Strip Prefix disabled); API paths must reach ASP.NET Core intact |
| HTTPS | Enabled for every public domain |
| Use Docker Build Secrets | Enabled; required when making credentials available to Compose's build-phase parsing |
| Advanced → Build → Build arguments | **Managed manually in Dockerfile**; avoids the Dockerfile rewriting defect in Coolify 4.3.23 |

The GitHub App supplies repository access and push webhooks. No additional Coolify API token or GitHub Actions deployment secret is needed. Native Coolify behavior skips commits containing `[skip ci]` or `[skip cd]`; avoid those markers when a deployment is wanted. CI runs independently and does not gate Coolify. [GitHub App setup](https://coolify.io/docs/applications/sources/github/app), [native auto-deploy](https://coolify.io/docs/applications/sources/github/auto-deploy)

## 2. Local credentials and Coolify environment

Run from the repository root:

```bash
python3 deploy/coolify/init-env.py
```

This creates the ignored `deploy/coolify/.env` with randomly generated service passwords and owner-only file permissions. An existing file is preserved. The file has already been generated in the current workspace, including the pgAdmin password. Enter provider credentials there as setup progresses; do not paste them into chat. Copy its values into the application's **production** environment variables in Coolify before deployment. No duplicate application credentials are needed in GitHub: native Coolify deployment owns them, and CI uses synthetic values.

When copying an individual value into Coolify, omit any surrounding dotenv quotes: they are file syntax, not part of the credential. The Microsoft setup helper emits unquoted values when their characters allow it; values that require dotenv escaping remain quoted in the file.

For this Compose stack on Coolify **4.3.23**, enable both **Build time** and **Runtime** for these variables, enable **Use Docker Build Secrets**, and select **Advanced → Build → Build arguments → Managed manually in Dockerfile**. The Dockerfiles do not consume application credentials, but Coolify invokes `docker compose build` with a separate build-time environment file. Compose parses the required `${VAR:?}` expressions during that command, so runtime-only values are insufficient. The secrets setting prevents Coolify from passing ordinary credential build arguments; the manual setting prevents automatic Dockerfile rewriting. No credential `ARG` declarations or secret mounts need to be added to our Dockerfiles. Verify that deployment logs report build-secret support and skipped Docker Compose Dockerfile ARG injection. [Versioned build implementation](https://github.com/coollabsio/coolify/blob/v4.3.23/app/Jobs/ApplicationDeploymentJob.php#L737), [rewrite bypass](https://github.com/coollabsio/coolify/blob/v4.3.23/app/Jobs/ApplicationDeploymentJob.php#L4687), [Coolify variable scopes and build secrets](https://coolify.io/docs/applications/configuration/environment-variables)

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

If Microsoft reports `unauthorized_client` or says the client is not enabled for consumers, verify both the registration audience and the exact `client_id` in a fresh authorization request. During first setup, the audience was correct but literal quotes copied into Coolify reached Keycloak's stored provider configuration. Correct both Microsoft values in Coolify and the existing **enterprise-app → Identity providers → Microsoft** configuration; changing bootstrap environment variables alone does not overwrite an imported realm. Retry from the application's sign-in flow, since the previous Microsoft error URL retains the old client ID.

## 4. Domain routing and first deployment

The root [compose.prod.yaml](../../compose.prod.yaml) builds the existing UI, API, worker, and EF migration images plus small PostgreSQL, Keycloak, and pgAdmin image wrappers. RabbitMQ uses its Management image. Bootstrap configuration is packaged into images; there are no runtime repository bind mounts.

In Coolify 4.3.23, open **Domains** (also linked from **General → Manage domains**), select **Add domain**, and choose the corresponding Compose service. DNS records and the `APP_ORIGIN` / `AUTH_ORIGIN` environment variables do not create these proxy routes. The port in each setting selects the **internal destination port**; visitors use ordinary HTTPS without a port suffix. In a form with separate fields, use scheme `https`, the hostname, the internal port, and the path shown below. Save the domain settings and redeploy to apply them to the containers.

| Compose service | Coolify domain field |
|---|---|
| `ea-ui` | `https://ent-app.portfolio-projects.dev:3000` |
| `ea-api` | `https://ent-app.portfolio-projects.dev:8000/api/v1` |
| `ea-api` | `https://ent-app.portfolio-projects.dev:8000/health` |
| `ea-keycloak` | `https://ent-app-auth.portfolio-projects.dev:8080` |
| `ea-rabbitmq` | `https://ent-app-mq.portfolio-projects.dev:15672` |
| `ea-pgadmin` | `https://ent-app-db.portfolio-projects.dev:8080` |

The API needs two domain entries, one for each path. The Service dropdown scrolls internally; `ea-ui` is the last entry, below `ea-data-engine`.

Set **Advanced → Proxy → Path prefixes → Keep paths as-is**. This is the Coolify 4.3.23 control for disabling **Strip Prefix**. Coolify generates Traefik routing for the longer API paths while `/api/runtime-config`, `/api/health`, and all pages remain with Next.js. Use managed domains without adding competing custom Traefik labels. PostgreSQL port 5432 and RabbitMQ AMQP port 5672 remain private to the application network. [Coolify Compose routing](https://coolify.io/docs/applications/builds/docker-compose), [versioned proxy controls](https://github.com/coollabsio/coolify/blob/v4.3.23/resources/views/livewire/project/application/advanced.blade.php#L124)

If the UI loads but guest API calls return 404, verify this prefix setting and redeploy after changing it. During first deployment, `/api/v1/models` and `/health/ready` returned API 404 responses while `/api/v1/api/v1/models` and `/health/health/ready` succeeded, confirming that the proxy was stripping the required prefixes.

Deploy once the selected revision and all credentials are available. PostgreSQL initializes separate application and Keycloak databases/users. EF migrations must finish before API/worker startup; the API then seeds demo data. The completed migration container is excluded from Coolify's aggregate health with `exclude_from_hc`, while a failure still blocks its dependents. RabbitMQ retains a stable node hostname and named volume.

The services have initial memory limits suited to this small demo; actual available memory depends on the other projects on the shared 8 GB server. Build-time memory is additional. Inspect Coolify logs and host utilization if a build or service is killed. Do not add Docker inside the development container; image/Compose execution belongs in CI or on a Docker-capable host.

### Coolify 4.3.23 build-stage failure

If a build fails pulling `docker.io/library/build:latest` at `COPY --from=build`, check **Advanced → Build → Build arguments**. Select **Managed manually in Dockerfile**, keep **Use Docker Build Secrets** enabled and variables enabled for both **Build time** and **Runtime**, then redeploy the same revision. This recovery requires no repository change or registry credentials.

Source inspection and a local reproduction traced the first deployment failure to Coolify's secret injector: it reuses the `dockerfile_content` output buffer across Compose services, while command output appends by default. The preceding ARG rewrite removes the final newline, so successive Dockerfiles concatenate and swallow later `FROM ... AS build` declarations. The reproduction matched the logged API failure at line 196. The manual build-argument setting skips this rewrite path while preserving Compose environment parsing. [Secret injector](https://github.com/coollabsio/coolify/blob/v4.3.23/app/Jobs/ApplicationDeploymentJob.php#L4590), [command output accumulation](https://github.com/coollabsio/coolify/blob/v4.3.23/app/Traits/ExecuteRemoteCommand.php#L238)

CI builds the repository Dockerfiles directly and therefore does not exercise Coolify's rewriting. A passing Compose smoke check still requires the Coolify settings above for live deployment.

### Operator visibility

| Service | Login URL | Username / email |
|---|---|---|
| Keycloak Admin | [ent-app-auth.portfolio-projects.dev/admin/](https://ent-app-auth.portfolio-projects.dev/admin/) | `admin` — authenticate in the **master** realm |
| RabbitMQ Management | [ent-app-mq.portfolio-projects.dev](https://ent-app-mq.portfolio-projects.dev/) | `ea_app` |
| pgAdmin 4 | [ent-app-db.portfolio-projects.dev](https://ent-app-db.portfolio-projects.dev/) | `admin@portfolio-projects.dev` (`PGADMIN_EMAIL`) |

Inside pgAdmin, the PostgreSQL connection uses database username **`ea_admin`**, separately from the UI login.

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

Push to `main` to deploy Coolify through the existing GitHub App webhook. Every push is eligible; there are no watch-path filters, special enablement flags, CI dependency, or Terraform invocation in this path. Keep native **Auto Deploy** enabled. The initial live deployment and a subsequent push-triggered deployment at `c245d92` have both been verified.

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
| Publication and container validation | Operator merged PR 24 at `bbf9503`, then pushed helper/runbook updates at `c245d92`; all six CI checks passed for the latter, including container builds, Compose smoke, and API integration tests. The completion/metrics transaction fix is included |
| Coolify variables | Operator confirms values copied and Build time restored; deployment log confirms Docker 29.8.1 with BuildKit secrets enabled |
| Git review | Further staging, commits, pushes, merges, and PR changes require explicit operator approval; final runbook verification notes are left unstaged for operator review |
| First live deployment | Running after the Dockerfile rewrite workaround and service-domain setup; valid HTTPS verified on all four domains |
| Live endpoints | UI health/configuration, Keycloak discovery/PKCE and both provider buttons, RabbitMQ Management, and pgAdmin ping passed |
| API routing | Operator selected Keep paths as-is and redeployed; normal API routes and readiness now pass |
| Guest workflow | `python3 deploy/coolify/smoke.py` passed against the public domains before and after the automatic `c245d92` deployment: invalid bearer rejected and a guest model run completed with computed metrics through the live API, queue, and worker |
| Google browser workflow | Operator confirms it works without issue |
| Microsoft browser workflow | Personal-account audience verified through Azure CLI; literal client-ID quotes diagnosed and removed from live Keycloak, local `.env`, and Coolify. Corrected authorization redirect verified; operator confirms personal Microsoft sign-in now works |
| Operator access | RabbitMQ accepts the configured operator and lists four queues. pgAdmin accepts its configured login and returns two server groups. Keycloak administrator access was verified during the provider correction |
| Native push auto-deploy | Operator confirms `c245d92` automatically triggered and completed in Coolify; subsequent live smoke passed |
