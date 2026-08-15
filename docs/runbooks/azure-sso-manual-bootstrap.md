# Azure Customer SSO Manual Bootstrap (Entra External ID)

## 1. Overview

This runbook stands up the one-time resources that Terraform **cannot** create for our customer SSO slice (Microsoft Entra External ID + Google federation). It covers both environments: `dev` and `production`. Run every step once per environment unless noted.

These steps are manual because:

- **External ID tenants** are provisioned through a dedicated Azure Portal experience, not the AzureRM provider. The tenant must exist before any `azuread`/`azapi` provider can authenticate against it.
- **Google Cloud OAuth 2.0 clients** live in Google Cloud Console and cannot be managed by Terraform.
- **Admin consent** for Microsoft Graph permissions is a portal-only action (Terraform can assign the permission; it cannot click "Grant admin consent").
- **The External ID user flow and its attached identity providers** (Google social IDP and Email one-time passcode) are configured through the External ID portal as a one-time bootstrap per tenant - see [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers). Terraform no longer manages these objects. Microsoft work/personal-account federation is **not** implemented in this project; see the [Known limitations](#known-limitations) callout at the end of Part G for the rationale.

**Who runs this**: a single operator who holds both

- Entra **Global Administrator** in the workforce tenant (for cross-tenant federation + CI SP consent), and
- **Owner** of the Google Cloud project used for OAuth client registration,
- plus **Contributor** on the Azure subscription that will bill the External ID tenant.

Once this runbook is complete, the infra agent's Terraform work ([`infra/azure/modules/entra-external-id/`](../../infra/azure/modules/entra-external-id/)) can apply cleanly.

---

## 2. Prerequisites checklist

Before starting, confirm:

- [ ] You can sign in to [https://portal.azure.com](https://portal.azure.com) with an account that is **Global Admin** on the workforce tenant and **Contributor** on the target Azure subscription.
- [ ] You can sign in to [https://console.cloud.google.com](https://console.cloud.google.com) and create new projects + OAuth clients.
- [ ] GitHub CLI is authenticated with write access to the repo:

  ```bash
  gh auth status
  ```

- [ ] The GitHub repo already has Environments named `dev` and `production` (Settings -> Environments).
- [ ] You have decided on unique tenant display names and subdomains for dev and production; keep populated identifiers in approved environment configuration rather than this runbook.
- [ ] You have a terminal open in `/workspace` so you can run `gh` commands.
- [ ] You are aware that [`docs/runbooks/scripts/azure-source-sso-env.sh`](./scripts/azure-source-sso-env.sh) is a tracked companion helper that exports `TF_VAR_*` values from the populated `azure-push-sso-secrets.sh` (no secrets baked in; DRY with Part D).
- [ ] You are aware that [`docs/runbooks/scripts/azure-plan-infra.sh`](./scripts/azure-plan-infra.sh) is a tracked companion helper that wraps the full local-plan workflow (source env + `az account show` + `terraform init/plan`) into a single command, used in [Part F](#8-part-f---verification). It passes `-refresh=false` to `terraform plan` by default so the local preview is advisory and does not require the operator's `az login` identity to hold every data-source read permission (notably Key Vault Secrets); the full-refresh plan is done by CI under the platform SP.
- [ ] As the final step of [Part A](#3-part-a---create-the-entra-external-id-tenant-one-per-env), the captured tenant GUID + subdomain must be pasted into the committed `infra/azure/envs/<env>.tfvars` file for that environment. `-var-file` beats `TF_VAR_*`, so without this step `terraform plan` silently uses the placeholder strings. Tenant GUIDs and subdomains are public identifiers, not secrets.
- [ ] You are aware that [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) is a separate one-time portal step that runs **after** Part F's first successful `terraform apply` (same out-of-band pattern as Part A's tenant creation). The end-to-end sign-in smoke test in Part F Step 3 will not pass until Part G is complete.

---

## 3. Part A - Create the Entra External ID tenant (one per env)

Repeat this section twice: once for `dev`, once for `production`.

1. Sign in to [https://portal.azure.com](https://portal.azure.com) with your Global Admin account.
2. In the top search bar, type **"Microsoft Entra External ID"** and select the service.
3. Click **Create a tenant**.
4. On the **Basics** step, choose **Configure a customer tenant**. Do **not** pick "Extend workforce tenant" - that produces a workforce Entra tenant, which is the wrong product for CIAM.
5. On the **Configuration** step, fill in:
   - **Tenant name** (display): an environment-specific customer identity name.
   - **Domain name**: a unique alphanumeric subdomain for the selected environment. The portal rejects hyphens.
   - **Location**: pick the same region used for the rest of the platform (e.g. `United States`).
6. On the **Billing** step, link the existing Azure subscription and resource group.
7. Click **Review + create**, then **Create**. Provisioning takes approximately 5 minutes.
8. When provisioning completes, use the top-right **tenant switcher** to switch into the new External ID tenant, then open **Entra ID -> Overview** and record:
   - **Tenant ID** (GUID) -> goes into `EXTERNAL_TENANT_ID` secret below.
   - **Primary domain** (`<tenant-subdomain>.onmicrosoft.com`).
   - **CIAM login subdomain** (`<tenant-subdomain>.ciamlogin.com`) -> this forms the OIDC authority `https://<tenant-subdomain>.ciamlogin.com/<tenant-id>/v2.0`. The prefix goes into the `TENANT_SUBDOMAIN` variable.
9. **Paste the captured values into the committed tfvars file for this environment.** These are tenant-level identifiers, **not secrets** - tenant GUIDs and subdomains are public (the subdomain is literally part of the sign-in URL). They belong in the committed tfvars alongside other non-secret tenant config, *not* in GitHub Environment secrets. Concretely:
   - For `dev`, edit [`infra/azure/envs/dev.tfvars`](../../infra/azure/envs/dev.tfvars) and set:

     ```hcl
     external_tenant_id = "<paste tenant GUID here>"
     tenant_subdomain   = "<paste tenant subdomain prefix here>"
     ```

   - For `production`, make the equivalent edit in [`infra/azure/envs/production.tfvars`](../../infra/azure/envs/production.tfvars).
   - Commit these changes on the same feature branch as the infra module work and include them in the PR.

   Why committed tfvars and not a GitHub Environment secret: Terraform's `-var-file=envs/<env>.tfvars` has **higher precedence than `TF_VAR_*` environment variables**. If the tfvars file still holds a `<PLACEHOLDER: ...>` string, `terraform plan` silently uses the placeholder even when the operator populated `azure-push-sso-secrets.sh` correctly, and the `azuread.external` provider fails with an opaque unmarshal error.

Reference: [What is Microsoft Entra External ID?](https://learn.microsoft.com/en-us/entra/external-id/customers/overview-customers-ciam)

---

## 4. Part B - Create the Terraform service principal inside the External ID tenant

Terraform needs credentials **inside** the External ID tenant to manage app registrations and user flows. The workforce-tenant CI service principal cannot reach in; this is the standard "dedicated deployment SP" pattern.

Run this twice - once in each External ID tenant.

1. In the Azure Portal, use the top-right tenant switcher to switch into the **External ID tenant** just created.
2. Open **Entra ID -> App registrations -> New registration**.
3. Fill in:
   - **Name**: `ea-terraform-deployer`
   - **Supported account types**: *Accounts in this organizational directory only (single tenant)*
   - Leave redirect URI blank.
4. Click **Register**.
5. From the new app's blade, open **API permissions -> Add a permission -> Microsoft Graph -> Application permissions** and add each of the following:
   - `Application.ReadWrite.All`
   - `IdentityProvider.ReadWrite.All`
   - `Policy.ReadWrite.AuthenticationFlows`

   **Why `Application.ReadWrite.All` and not `.OwnedBy`**: `Application.ReadWrite.OwnedBy` reads as sufficient in the Microsoft Graph permission docs (it creates app registrations the SP owns), but in practice it cannot patch `identifierUris` on an app post-create and cannot create a service principal for a just-created app registration even when the app is single-tenant - both operations return `403 Authorization_RequestDenied`. This is a known Graph quirk, not a bug in the module. `Application.ReadWrite.All` (application permission, tenant-wide) is the CIAM-safe choice and the one the module expects.
6. Click **Grant admin consent for \<tenant\>** and confirm. All three permissions should show a green check.
7. Open **Certificates & secrets -> Client secrets -> New client secret**.
   - **Description**: `terraform-ci`
   - **Expires**: 24 months (track expiry; see [Section 11](#11-secret-rotation)).
   - Click **Add**, then immediately copy the secret **Value** (not the Secret ID). It is only shown once.
8. Open **Overview** and record:
   - **Application (client) ID** -> `EXTERNAL_TENANT_CLIENT_ID`
   - Client secret value -> `EXTERNAL_TENANT_CLIENT_SECRET`

> **True-up for operators who already ran Part B**
>
> If you previously followed this runbook when it prescribed `Application.ReadWrite.OwnedBy`, the `ea-terraform-deployer` SP needs a one-time permission upgrade. Terraform apply will fail on `authentication_application_identifier_uri` and `authentication_service_principal` under the old permission - see the new rows in [Section 10](#10-troubleshooting). To true up:
>
> 1. Switch to the External ID tenant in the Azure Portal and open **Entra ID -> App registrations -> `ea-terraform-deployer` -> API permissions**.
> 2. Remove the existing `Application.ReadWrite.OwnedBy` row.
> 3. Click **+ Add a permission -> Microsoft Graph -> Application permissions** and add `Application.ReadWrite.All`.
> 4. Click **Grant admin consent for \<tenant\>** and confirm all three rows (`Application.ReadWrite.All`, `IdentityProvider.ReadWrite.All`, `Policy.ReadWrite.AuthenticationFlows`) show green checkmarks under **Status**.
>
> No other Part B artifacts need to change - the client secret, any federated credential, and the captured tenant ID / client ID stay as-is. Run this true-up once per External ID tenant (dev and production).

> **Existing-environment check:** the deployer application must be single tenant (`AzureADMyOrg`). If a prior bootstrap used a broader sign-in audience, correct it before production approval rather than copying that setting to another environment.

> **Verify Part B** - after creating the deployer SP in each tenant (and after any secret rotation, per [Section 11](#11-secret-rotation)), run the companion health check:
>
> ```bash
> az login --tenant <external-tenant-id> --allow-no-subscriptions
> bash docs/runbooks/scripts/azure-verify-deployer-sp.sh <dev|production>
> ```
>
> The script asserts the SP is single-tenant (`AzureADMyOrg`), has at least one unexpired client secret, and holds admin-consent on all three required Graph application roles (`Application.ReadWrite.All`, `IdentityProvider.ReadWrite.All`, `Policy.ReadWrite.AuthenticationFlows`). Non-zero exit on any failure - safe to chain into CI or pre-apply gating.

---

## 5. Part C - Register the Google OAuth 2.0 client (one per env)

Repeat twice (dev project + prod project). Keeping dev and prod in **separate Google Cloud projects** is required for independent consent screens and secret rotation.

> **Start Part C for production before you need it.** If the production Google consent screen is External, provider verification can take time. For an isolated demonstration, [Guest Mode](#optional-guest-mode-temporary-demo-failsafe) is separate from real SSO acceptance and must never be used to claim federation works. Decide the Google publishing posture before the production merge.

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com).
2. In the top project selector, click **New Project**:
   - **Project name**: an environment-specific OAuth project name; keep the actual project identifier outside this runbook.
   - Leave organization/billing defaults.
3. After creation, select the new project.
4. Open **APIs & Services -> OAuth consent screen**.
   - **User Type**:
     - Choose **External** if your Google account is not part of a Google Workspace org.
     - Choose **Internal** if you are in a Google Workspace org and want to restrict to internal accounts (not useful for this demo - leave **External**).
   - Click **Create**.
5. On the **App information** step:
   - **App name**: `EA Customer (Dev)` or `EA Customer (Prod)`
   - **User support email**: your email.
   - **Developer contact email**: your email.
   - Leave logo, homepage, and privacy policy blank for dev.
6. On the **Scopes** step, click **Add or Remove Scopes** and select `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`. Save and continue.
7. On the **Test users** step (dev only): add the Gmail addresses that will sign in during smoke tests. Publish status stays **Testing**.
8. **Production only**: click **Publish app** and submit for verification. Verification can take several weeks - plan ahead.
9. Open **APIs & Services -> Credentials -> Create Credentials -> OAuth client ID**.
   - **Application type**: *Web application*
   - **Name**: `EA Dev External ID` or `EA Prod External ID`
   - **Authorized redirect URIs**: add the External ID federation callback URL. The format is:

     ```
     https://<tenant-subdomain>.ciamlogin.com/<external-tenant-id>/federation/oauth2
     ```

     Confirm the exact URL by switching to the External ID tenant in Azure Portal -> **External Identities -> All identity providers -> + Google** - the wizard shows the callback URL that must be registered.
10. Click **Create**. Copy the **Client ID** and **Client Secret** immediately. Store both in your password manager; the portal-side [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) paste and all future rotations read from there.

Reference: [Add Google as an identity provider](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-google-federation-customers).

---

## 6. Part D - Push secrets and variables to GitHub

Set secrets/variables into each GitHub Environment. Tenant subdomain is **not sensitive** and goes in as a variable; everything else is a secret.

Rather than running the `gh` commands by hand per environment, use the companion script at [`docs/runbooks/scripts/sample.azure-push-sso-secrets.sh`](./scripts/sample.azure-push-sso-secrets.sh). It takes a single positional argument (`dev` or `production`) and runs the same `gh secret set` / `gh variable set` calls under the hood.

1. Copy the sample to a local, populated copy (the destination filename drops the `sample.` prefix):

   ```bash
   cd docs/runbooks/scripts
   cp sample.azure-push-sso-secrets.sh azure-push-sso-secrets.sh
   ```

   The repo's `.gitignore` excludes `docs/runbooks/scripts/azure-push-sso-secrets.sh` as belt-and-suspenders - the populated copy must **never** be committed.

2. Open `azure-push-sso-secrets.sh` in an editor and replace every `<PASTE ...>` placeholder, including the tenant subdomains, with values from the approved secret/configuration source.

3. Run the script once per environment:

   ```bash
   cd docs/runbooks/scripts
   chmod +x azure-push-sso-secrets.sh   # if needed
   ./azure-push-sso-secrets.sh dev
   ./azure-push-sso-secrets.sh production
   ```

Verify with:

```bash
gh secret list   --env dev
gh variable list --env dev
gh secret list   --env production
gh variable list --env production
```

Once verification passes, delete your local populated copy - the values now live in GitHub Environment storage:

```bash
rm docs/runbooks/scripts/azure-push-sso-secrets.sh
```

> **Note on inert GitHub objects**: the `EXTERNAL_TENANT_ID` secret and the `TENANT_SUBDOMAIN` variable pushed by `azure-push-sso-secrets.sh` are now **functionally inert** - Terraform / CI reads both of these values from the committed `infra/azure/envs/<env>.tfvars` file (populated per the final step of [Part A](#3-part-a---create-the-entra-external-id-tenant-one-per-env)) because `-var-file` beats `TF_VAR_*`. They remain in `azure-push-sso-secrets.sh` for reference and so the script keeps a complete picture of what Parts A/B capture; you do not need to remove them. This is the same pattern as the existing "orphaned in GitHub Environment secrets" callout for `GOOGLE_OIDC_CLIENT_ID` / `GOOGLE_OIDC_CLIENT_SECRET` in [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers).
>
> Correspondingly, [`docs/runbooks/scripts/azure-source-sso-env.sh`](./scripts/azure-source-sso-env.sh) now exports just the **two** external-tenant SP credentials as `TF_VAR_*` values (`TF_VAR_external_tenant_client_id`, `TF_VAR_external_tenant_client_secret`). The `external_tenant_id` and `tenant_subdomain` values used to be exported here as well; they have been dropped because the tfvars file is authoritative.

> **Note to infrastructure agents**: [`.github/workflows/deploy-azure.yml`](../../.github/workflows/deploy-azure.yml) supplies `TF_VAR_external_tenant_client_id` and `TF_VAR_external_tenant_client_secret` from the selected logical `dev` or `production` GitHub Environment. `external_tenant_id` and `tenant_subdomain` come from the committed tfvars and no longer need `TF_VAR_*` wiring. Google credentials are portal-managed for the Azure user flow rather than Terraform inputs.

---

## 7. Part E - Grant workforce-tenant Graph permissions (one-time)

Once the infra agent ships the updated bootstrap ([`infra/azure/bootstrap/main.tf`](../../infra/azure/bootstrap/main.tf)), the existing CI service principal in the **workforce** tenant needs two new Graph permissions:

- `Application.ReadWrite.OwnedBy`
- `IdentityProvider.ReadWrite.All`

Steps:

1. Pull the bootstrap change and apply it locally:

   ```bash
   cd /workspace/infra/azure/bootstrap
   terraform init
   terraform apply
   ```

   The bootstrap uses `authentication_app_role_assignment` resources to attach each Graph app role directly to the CI SP via the Microsoft Graph `appRoleAssignedTo` endpoint - which **is** the admin-consent operation. As a result, both permissions appear immediately as *Granted for \<tenant\>* on the SP as soon as `terraform apply` completes; no separate portal "Grant admin consent" click is required. The portal steps below are verification-only.

2. In the Azure Portal, switch to the **workforce** tenant and open **Entra ID -> Enterprise applications**. Search for `ea-github-oidc`.

   If the SP does not appear, the Enterprise applications blade's default **Application Type** filter hides custom app-registration SPs. Change the filter to **All Applications**, or use the **App registrations** blade instead. (This was discovered during a real bootstrap run.)

3. Open the `ea-github-oidc` SP and navigate to **Permissions**. Confirm both `Application.ReadWrite.OwnedBy` and `IdentityProvider.ReadWrite.All` show a green *Granted for \<tenant\>*. Do **not** click **Grant admin consent** - the Terraform apply has already performed that operation, and clicking it is unnecessary.

4. While on the SP, note that the portal exposes three distinct GUIDs, all of which are legitimate and refer to different objects:
   - **Application (client) ID** on the SP's Overview -> the OIDC `client_id` the workflow uses to authenticate. This matches `authentication_application.github_oidc.client_id`.
   - **Object ID** shown on the **Enterprise applications** blade -> the **service principal's** object ID. This is what `authentication_service_principal.github_oidc.object_id` emits and what the `authentication_app_role_assignment` resources target as `principal_object_id`.
   - **Object ID** shown on the **App registrations** blade -> the **application** object's object ID, which is different from the SP's object ID.

   Every app registration has two object IDs in Microsoft Graph (one on the application object, one on its service principal). An operator comparing Terraform output to the portal will see what looks like a mismatch; it is not.

---

## 8. Part F - Verification

After Parts A through E, and after the infra agent's Terraform lands:

### Optional: local-plan preview (recommended for the first apply)

**Rationale**: [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) runs `terraform apply -auto-approve` - CI never pauses on the plan. On the **first** deployment of the External ID module against a new tenant, a dry-run plan executed locally is the only safety net before CI commits to the apply. Once the module has successfully applied once and the resource shape is known-good, subsequent runs can skip this preview and rely on CI. Treat this subsection as a one-time / first-deployment safety check, not a routine operation.

**Prerequisites** for this preview:

- You have completed [Parts A-E](#3-part-a---create-the-entra-external-id-tenant-one-per-env).
- `infra/azure/envs/<env>.tfvars` has been populated with the real `external_tenant_id` (GUID) and `tenant_subdomain` values captured in [Part A](#3-part-a---create-the-entra-external-id-tenant-one-per-env). **This is the key gating step** - if the tfvars still holds `<PLACEHOLDER: ...>` strings, `-var-file` beats `TF_VAR_*` and the plan silently uses the placeholder, which then blows up inside the `azuread.external` provider.
- You have populated `docs/runbooks/scripts/azure-push-sso-secrets.sh` (from [Part D](#6-part-d---push-secrets-and-variables-to-github)) and pushed the values into the GitHub Environment secrets. (The local file is the DRY source that `azure-source-sso-env.sh` reuses; if you already deleted it after Part D, restore it from your password manager or re-copy from `sample.azure-push-sso-secrets.sh` and repopulate.)
- You have authenticated against the **workforce** tenant with `az login` so the AzureRM and AzureAD providers can initialize. Note: `azure-plan-infra.sh` passes `-refresh=false` to `terraform plan` by default, so the local preview is advisory and does **not** require your `az login` identity to hold every data-source read permission (notably Key Vault Secrets - those typically require the `deployer_officer` role). The full-refresh plan is done by CI under the platform SP.

**Command**:

Run the tracked wrapper [`docs/runbooks/scripts/azure-plan-infra.sh`](./scripts/azure-plan-infra.sh) with the target environment:

```bash
bash docs/runbooks/scripts/azure-plan-infra.sh dev
```

To save the plan binary for a later apply, pass `--out`:

```bash
bash docs/runbooks/scripts/azure-plan-infra.sh dev --out /tmp/dev.tfplan
```

`azure-plan-infra.sh` is a tracked wrapper over `eval "$(azure-source-sso-env.sh <env>)"` + `az account show --query id -o tsv` + `terraform init`/`terraform plan`, so the operator does not have to assemble those steps by hand. It resolves its own location and can be invoked from any working directory, sources `TF_VAR_*` via [`docs/runbooks/scripts/azure-source-sso-env.sh`](./scripts/azure-source-sso-env.sh) (no duplication), fetches the current subscription ID from `az account show`, runs `terraform init -upgrade` against the env-specific backend key (`dev.tfstate` / `production.tfstate`) with the fixed backend config (resource group `ea-tfstate-rg`, storage account `eatfstateeaboot`, container `tfstate`), and runs `terraform plan -var-file=envs/<env>.tfvars -var subscription_id="<resolved>" -refresh=false`. Omit `--out` for a read-only preview.

**What to expect in a clean first-run plan**:

- `module.entra_external_id.authentication_application.api` and `module.entra_external_id.authentication_application.spa` - the two app registrations - appearing as **additions**.
- The matching `authentication_service_principal` resources for each app registration - also **additions**.
- The API app registration's **identifier URI** (`api://<client-id>`) and the **SPA pre-authorization** entry on the API app's exposed scope - **additions** on the API app reg.
- `module.container_apps.*` updates where the API container app gets new `Authentication__*` environment variables populated from `module.entra_external_id` outputs.
- **Zero destroys of unrelated resources.** If the plan shows destroys outside `module.entra_external_id`, **stop** and investigate - that indicates state drift, not expected change.

Note: the user flow, Google IDP, and Email one-time passcode method are **not** in the plan - those are portal-managed via [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers).

**If the plan is clean**: commit and push the branch. CI picks up the GitHub Environment secrets (wired through `deploy.yml` into the same `TF_VAR_*` names) and runs the identical apply.

**If the plan is NOT clean**: stop. Capture the full plan output, investigate before pushing. Likely causes include stale remote state, a missing or mistyped `TF_VAR_*` export, an un-populated `infra/azure/envs/<env>.tfvars` (placeholder strings still in place - see the prerequisites above), provider drift against the External ID tenant, a `400 InvalidAccessTokenVersion` on an `authentication_application.*` resource (missing `api { requested_access_token_version = 2 }` - see [Section 10](#10-troubleshooting)), or a `403 Authorization_RequestDenied` on `authentication_application_identifier_uri` / `authentication_service_principal` (deployer SP still on `Application.ReadWrite.OwnedBy` instead of `.All` - see the Part B true-up callout and the matching rows in [Section 10](#10-troubleshooting)). Do **not** push the branch until the plan is clean - CI will auto-apply whatever it sees.

> **First-apply reminder**: On the very first `terraform apply` against a new tenant, the app registrations land but the tenant still has no user flow and no identity providers configured. [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) (portal-configure user flow + IDPs) must run immediately after this apply succeeds and before Step 3's end-to-end sign-in smoke test. On subsequent applies Part G is already in place and nothing more is required.

### Step 1. Confirm the CI apply

1. After pushing the branch (with a clean local plan, or directly if this is not the first apply), the normal deploy pipeline ([`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml)) runs `terraform apply -auto-approve` against the dev backend. Confirm the workflow run succeeds and the apply log matches what the local preview showed.

   For the **first** apply, this is the step that commits to the change you previewed above. For subsequent applies, this is the routine path - no local preview required.

### Step 2. Verify External ID tenant resources

2. Switch to the External ID tenant in the Azure Portal and verify:
   - **Entra ID -> App registrations**: `ea-api-dev` and `ea-spa-dev` exist (and the prod pair after prod apply).
   - **Entra ID -> Enterprise applications**: matching SPs exist for both.
   - The API app reg's **Expose an API** blade shows the identifier URI `api://<api-client-id>` and lists `ea-spa-<env>` under **Authorized client applications** (SPA pre-authorization).

   If this is the first apply on this tenant, the user flow and identity providers are **not** expected yet - those arrive in [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers).

### Step 3. Smoke test end-to-end sign-in

3. Smoke test the end-to-end sign-in flow. **Prerequisite**: on the first apply, [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) must be complete - without the user flow and IDPs configured in the portal, the Next.js sign-in will surface a tenant-level error (no user flow attached) rather than the IDP picker.
   - Browse to the Next.js Container App URL from `terraform -chdir=infra/azure output -raw application_url`.
   - Click **Sign in**.
   - Confirm the Microsoft-hosted sign-in page renders two IDP options: **Google** and **Email one-time passcode**.
   - Sign in with each option in turn and confirm a round-trip to the Next.js UI with a valid session.

### Step 4. Optional temporary guest-mode smoke test

4. Guest mode is disabled in both committed Azure environments. If a temporary isolated demo has an explicit approval to set `allow_guest_auth = true`, verify the guest failsafe on top of real SSO before restoring it to false:
   - Confirm the production landing page renders the **Log in as Guest** button alongside **Log in**. If it is missing, inspect `ENABLE_GUEST_AUTH` on the UI Container App; Next.js reads it at request time.
   - Click **Log in as Guest**. Expect immediate navigation to `/dashboard` with **no** External ID redirect.
   - Open browser devtools Network tab, trigger any API action (e.g. open the Models list), and confirm the outbound request to `/api/...` carries **no** `Authorization` header and returns `200`.
   - In Postgres, the resulting audit row must carry `actor_subject_id = 00000000-0000-0000-0000-000000000003`, `actor_tenant_id = 00000000-0000-0000-0000-000000000004`, and `actor_identity_provider = "guest"`. The corresponding RabbitMQ message must carry `x-user-subject` and `x-user-identity-provider` headers with the same sentinel values.
   - Regression check: a real Google / Email-OTP sign-in from Step 3 still works - the `JwtOrGuest` policy scheme routes any `Authorization: Bearer ...` request through the unchanged `JwtBearer` path; guest intent is signalled by the header's absence.

   The dev sentinel (`subject = ...-0001`, `tenant = ...-0002`, `identity provider = "dev"`) is distinct from the guest sentinel - do not conflate them when auditing.

### Step 5. Full snapshot validation (closed-loop)

5. Run the tracked validator [`docs/runbooks/scripts/azure-validate-sso-snapshot.sh`](./scripts/azure-validate-sso-snapshot.sh) as the closing loop on Parts B, F, and G. It consolidates ~20 minutes of ad-hoc CLI (switching between the workforce subscription and the two External ID tenants, spot-checking Container App env vars, app registrations, and Graph-managed IDPs) into one invocation with uniform `PASS:` / `FAIL:` lines, genericized `expected:` / `actual:` echo pairs for side-by-side visual comparison, and a single non-zero process exit on any failure.

   **Prerequisites**: `az login` completed against the intended workforce tenant and subscription (verify with `az account show`); the four identifier environment variables listed by the validator loaded from approved configuration; and `docs/runbooks/scripts/azure-push-sso-secrets.sh` populated locally from [Part D](#6-part-d---push-secrets-and-variables-to-github). The deployer-SP credentials used to read `/beta/identity/identityProviders` come from that ignored local file through [`azure-source-sso-env.sh`](./scripts/azure-source-sso-env.sh).

   ```bash
   bash docs/runbooks/scripts/azure-validate-sso-snapshot.sh
   ```

   **What it checks**:
   - Section 1 (workforce subscription): both dev + production API Container Apps expose the expected `Authentication__Enabled`, `Authentication__Provider`, `Authentication__AllowDev`, `Authentication__AllowGuest`, `Authentication__Authority`, `Authentication__Audience`, and `Authentication__ClientId` values. Committed dev enables only dev auth; committed production enables neither synthetic mode.
   - Section 2 (dev External ID tenant): runs [`azure-verify-deployer-sp.sh dev`](./scripts/azure-verify-deployer-sp.sh) (Part B rollup), asserts `ea-api-dev` + `ea-spa-dev` app registrations exist (Part F), and authenticates as the deployer SP to read Microsoft Graph `/beta/identity/identityProviders` — expects `EmailOtpSignup-OAUTH`, `EmailPassword-OAUTH`, `Google-OAUTH` (Part G).
   - Section 3 (production External ID tenant): same shape against the prod tenant.

   The script will `az login --tenant <external-tenant-id> --allow-no-subscriptions` interactively for Sections 2 and 3 if the current session is not already on that tenant. It does **not** short-circuit on the first failure — every section runs to completion so the operator sees the full snapshot in one pass.

   Exit 0 = all checks pass (safe to gate CI / merges on). Exit 1 = one or more checks failed; the `FAIL:` lines point at the specific assertion, and the `expected:` / `actual:` pair immediately above it shows the drift.

---

## 9. Part G - Portal-configure the user flow and identity providers

Run this **once per tenant**, immediately after the first successful `terraform apply` in [Part F](#8-part-f---verification) - that apply is what creates the `ea-spa-<env>` app registration and its redirect URIs, which the user flow needs to exist before it can be attached. Repeat once for `dev`, once for `production`.

> **Scope of built-in IDPs on External ID self-service sign-up flows (read first)**: on `externalUsersSelfServiceSignUpEventsFlow`, the flow's **Identity providers** blade exposes only one Email radio (`Email with password` | `Email one-time passcode`) plus checkboxes for configured social IDPs. Social IDPs (Google in this project) are attached at the **tenant** level under **External Identities -> All identity providers** and then opted in per flow. Microsoft federation via custom OIDC is **not pursued in this project** - see the [Known limitations](#known-limitations) callout at the end of this section for the rationale. This runbook covers **Google + Email OTP** only.

> **True-up for operators who already ran Parts A-E**
>
> The move from Terraform-managed user flow / IDPs to portal-managed user flow / IDPs does **not** invalidate prior bootstrap work. Specifically:
>
> - **Still valid, no action**:
>   - **Part A** - the External ID tenant itself. Keep.
>   - **Part B** - the `ea-terraform-deployer` SP and its client secret. Terraform still uses these to manage the `ea-api-<env>` / `ea-spa-<env>` app registrations, SPs, identifier URI, and SPA pre-authorization.
>   - **Part C** - the Google Cloud OAuth client and its client ID / client secret. These are now consumed by the portal paste in [G.2](#g2---configure-the-tenant-level-identity-providers) below rather than by Terraform. Keep them in your password manager; all future rotations go portal-side (see [Section 11](#11-secret-rotation)).
>   - **Part E** - workforce-tenant Graph consent (`Application.ReadWrite.OwnedBy`, `IdentityProvider.ReadWrite.All`). Still required for `azuread` app-registration management in CI.
> - **You likely have NOT yet populated `infra/azure/envs/dev.tfvars` (and/or `production.tfvars`) with real `external_tenant_id` + `tenant_subdomain`.** The runbook previously did not instruct this. Do it now - see the extended final step of [Part A](#3-part-a---create-the-entra-external-id-tenant-one-per-env) - before re-running `bash docs/runbooks/scripts/azure-plan-infra.sh <env>`. Without this, `-var-file` wins over `TF_VAR_*` and the plan blows up inside the `azuread.external` provider with an opaque unmarshal error.
> - **`azure-source-sso-env.sh` no longer exports `TF_VAR_external_tenant_id` or `TF_VAR_tenant_subdomain`.** Those two values now live in the committed tfvars (see above). `azure-push-sso-secrets.sh` still contains them for reference and for the (now-inert) GitHub secret / variable push; those GitHub objects are harmless and may be left in place.
> - **Azure no longer consumes** `GOOGLE_OIDC_CLIENT_ID` and `GOOGLE_OIDC_CLIENT_SECRET` from GitHub. The AWS adapter may consume values with the same names in the shared logical environments, so do not remove them without checking the selected deployment targets and AWS federation configuration.
> - Keep the Azure portal's Google client secret in the password manager even when the shared GitHub secrets are retained for the AWS adapter. The tracked Azure sample contains no Google credential fields.

### G.1 - Create the user flow

1. Switch into the **External ID tenant** (top-right tenant switcher).
2. Open **External Identities -> User flows -> + New user flow**.
3. Configure:
   - **Name**: `ea-<env>-signup-signin` (e.g. `ea-dev-signup-signin`). The `B2C_1_` prefix is prepended automatically by the portal in some UIs - match whichever label the current portal version shows; the resulting flow name is the same.
   - **Type**: *Sign up and sign in*.
   - Attributes collected at sign-up: pick the minimum set that the SPA consumes (typically email + display name).
4. Click **Create**.
5. On the new flow's **Applications** blade, click **+ Add application** and attach `ea-spa-<env>` as the sole application. This is the binding that tells the Microsoft-hosted sign-in page to render this flow when the SPA initiates auth.

### G.2 - Configure the tenant-level identity providers

Under **External Identities -> All identity providers**, configure the following entries. These are **tenant-level** providers; enabling them here makes them *available* to user flows, but each flow still has to opt in ([G.3](#g3---attach-identity-providers-to-the-user-flow)).

As a sanity check: running `GET /beta/identity/identityProviders` against this tenant should return `EmailOtpSignup-OAUTH`, `EmailPassword-OAUTH`, and `Google`.

#### Google

1. Click **+ Google**.
2. **Name**: `Google`.
3. **Client ID**: paste the Google OAuth client ID captured in [Part C](#5-part-c---register-the-google-oauth-20-client-one-per-env) (from your password manager).
4. **Client secret**: paste the Google OAuth client secret from the same password-manager entry.
5. Save.

#### Email one-time passcode

In the current External ID portal, Email OTP tenant-level enablement is surfaced as a **green check** on the **Email one-time passcode** row under **External Identities -> All identity providers** - the same blade just used to configure Google above. To verify (and, if needed, enable):

1. Open **External Identities -> All identity providers**.
2. Locate the **Email one-time passcode** entry under **Built-in identity providers**.
3. Confirm the row shows a **green check** / "enabled" status in the status column. If yes, tenant-level enablement is complete and you can proceed to [G.3](#g3---attach-identity-providers-to-the-user-flow). If no, click the row, toggle the method on, and click **Save** - then re-check the row for the green check.

Older portal versions exposed this same toggle under **External Identities -> Email and phone signup** or **External Identities -> Authentication methods**; if your current tenant still renders one of those blades instead of a green-check row on **All identity providers**, use it as a fallback - but the **All identity providers** path above is the current-UI truth.

Do not assume OTP is on by default - it must be toggled on by the operator.

### G.3 - Attach identity providers to the user flow

1. Return to **External Identities -> User flows -> `ea-<env>-signup-signin`**.
2. Open the **Identity providers** blade. You will see:
   - An **Email** radio with two options: **Email with password** and **Email one-time passcode**. On flow creation the radio defaults to **Email with password**; **flip it to Email one-time passcode**.
   - A **Google** checkbox (because [G.2](#g2---configure-the-tenant-level-identity-providers) enabled it at the tenant level).
3. Check the **Google** checkbox.
4. Click **Save**.

This is the step that makes the Microsoft-hosted sign-in page actually render the two-option picker (Google, Email one-time passcode). Without it, the tenant-level providers from G.2 exist but will not appear on the flow.

### G.4 - Picker smoke test

1. Still on the user flow blade, click **Run user flow**. In the preview pane, select the `ea-spa-<env>` application and the SPA's reply URL, then click **Run user flow**.
2. Alternatively, hit the real SPA sign-in (the same URL used in [Part F Step 3](#step-3-smoke-test-end-to-end-sign-in)).
3. Confirm that the Microsoft-hosted sign-in page renders **two** picker options - **Google** and **Email one-time passcode**.
4. Complete a sign-in through each option to confirm the round-trip:
   - **Google** - any Gmail account on the test-users list (see [Part C](#5-part-c---register-the-google-oauth-20-client-one-per-env)).
   - **Email one-time passcode** - any email; expect the OTP challenge.

     > **First-time users must click the "Create account" / "Sign up" link on the CIAM sign-in page.** Typing an email and clicking the default **Next** button performs a sign-IN, which fails with *"We couldn't find an account with this email address"* for brand-new addresses. The correct first-time flow is: click **Create account** (or **Sign up** / **No account? Create one** — the label varies by CIAM portal version), enter the email, receive the OTP, enter the code, complete attribute collection (`displayName`). Returning users sign in via the default Next path.

Repeat G.1 through G.4 for the `production` tenant after its first `terraform apply`, producing a separate `ea-prod-signup-signin` user flow.

### Known limitations

> - **Microsoft federation not implemented.** Entra External ID supports Microsoft **work-account** federation via custom OIDC pointing at `/organizations/v2.0` with a **concrete** tenant-ID issuer (see [Microsoft Learn](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-entra-id-federation-customers)). That path is not pursued here because the original goal was a single button covering work + personal, which External ID's custom OIDC feature does not support.
> - **MSA (Outlook/Hotmail/Live) federation is undocumented** in External ID's custom OIDC feature. Outlook users sign in via **Email OTP** in this project; their Outlook inbox just receives the one-time code.
> - **Email OTP deliverability to vanity / third-party-forwarded domains.** Entra External ID OTP emails originate from a Microsoft sender and can be silently dropped by upstream mail providers (e.g. Porkbun vanity forwarders → Gmail/iCloud/etc.) before reaching the inbox or junk folder. Recipient-side DMARC/SPF policies and provider-specific spam rules are outside this project's control. Verified working in the dev smoke test: Gmail, Outlook.com. If a specific recipient domain silently drops OTPs, treat it as an external mail-routing issue at that recipient, not a tenant misconfiguration.

---

## Optional Guest Mode (temporary demo failsafe)

An explicitly enabled **Log in as Guest** button exists for isolated demonstrations. It mirrors the **Log in as Dev** affordance used locally and in the deployed dev environment. It is disabled by default in every cloud and must not be used with customer data. Guests get full read/write access equivalent to a real signed-in user.

Dev and Guest are independent, mutually exclusive flags. Committed development configuration enables Dev only; committed production configuration enables neither.

### How it's wired

- **API.** A policy-scheme `JwtOrGuest` is registered as the default authentication scheme when `Authentication:Enabled=true` AND `Authentication:AllowGuest=true`. Its selector routes Bearer requests into generic `JwtBearer` validation and everything else into `GuestAuthHandler`. When `AllowGuest=false`, unauthenticated calls get a 401.
- **UI.** An independent `enableGuestAuth` environment flag exposes a **Log in as Guest** button on the landing page alongside the existing Log in / Log in as Dev buttons. Guest sessions intentionally send **no** `Authorization` header — the API's policy-scheme selector recognizes a missing header as guest intent.
- **Infra.** A Terraform bool `allow_guest_auth` flows to `Authentication__AllowGuest` on the API and `ENABLE_GUEST_AUTH` on the Next.js runtime. Both values are injected at deployment time.

### Sentinel identity

| Claim | Value |
|---|---|
| `oid` | `00000000-0000-0000-0000-000000000003` |
| `tid` | `00000000-0000-0000-0000-000000000004` |
| `idp` | `guest` |
| `name` | `Guest User` |
| `preferred_username` | `guest@demo` |

The dev sentinel remains `...-0001` / `...-0002` / `idp=dev` and is distinct — do not conflate the two.

### Auditing implication

Every guest action stamps the same normalized sentinel subject into audit columns and RabbitMQ `x-user-subject` headers. You cannot distinguish between two prospects demoing simultaneously—that is by design for demo mode. **Do not enable guest mode once the app carries real customer data.**

### How to enable temporarily

> **Prerequisite for the first-ever merge to `main`**: the merge that activates guest mode is *also* the first prod apply of the entire SSO slice. [Parts A-E](#3-part-a---create-the-entra-external-id-tenant-one-per-env) must be complete for the **prod** tenant before the merge (otherwise CI's `terraform apply -auto-approve` fails on the prod `module.entra_external_id` apply), and [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) must be completed immediately after the merge (before sign-in smoke tests can pass). Guest mode itself is a flag-flip, but the flag rides on infrastructure that must exist first. On subsequent merges (prod already bootstrapped) only Steps 1-3 below apply.

1. Obtain explicit approval for an isolated environment with no customer data, then change `allow_guest_auth` to `true` in that Azure environment's tfvars.
2. Run the cloud-neutral deployment workflow with `target=azure` and the selected environment. Terraform redeploys the API and UI Container Apps with matching runtime flags.
3. Verify (same checklist as [Part F Step 4](#step-4-optional-temporary-guest-mode-smoke-test)):
   - Production Next.js landing page renders the **Log in as Guest** button.
   - Clicking it navigates to `/dashboard` without an External ID redirect.
   - A subsequent API call succeeds with no `Authorization` header, and the resulting audit row carries `actor_subject_id = 00000000-0000-0000-0000-000000000003` and `actor_identity_provider = "guest"`.

### How to disable

Immediately restore `allow_guest_auth = false` and redeploy. No data cleanup is required—guest-authored rows remain tagged by the sentinel subject/provider and can be filtered or purged later.

### Scope boundary

- Local and committed dev configuration use **Dev** mode and not Guest mode.
- Committed production configuration uses neither synthetic mode.
- `ENABLE_DEV_AUTH` / `Authentication:AllowDev` and `ENABLE_GUEST_AUTH` / `Authentication:AllowGuest` are wired independently and rejected when both are true.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `AADSTS50011: Reply URL mismatch` | Browser redirect URI not registered | Confirm the Container App origin, `<origin>/auth/callback`, `http://localhost:3000/`, and `http://localhost:3000/auth/callback` match the Terraform-managed registration. |
| Microsoft-hosted sign-in page errors out with "no user flow" or "application is not configured" | Part G has not been run on this tenant, or the user flow is not attached to `ea-spa-<env>` | Complete [Part G.1](#g1---create-the-user-flow) (create flow + attach the SPA app). |
| Sign-in page renders fewer IDP options than expected | The tenant-level provider is enabled but the user flow is not opted in, or vice versa | Check both [G.2](#g2---configure-the-tenant-level-identity-providers) (tenant-level) and [G.3](#g3---attach-identity-providers-to-the-user-flow) (flow-level). Both are required. |
| Google sign-in returns `Error 403: access_denied` for non-test users | Google consent screen still in **Testing** mode | Add the account to the test user list, or submit the app for verification (see [Part C](#5-part-c---register-the-google-oauth-20-client-one-per-env)). |
| Google sign-in returns `invalid_client` or `unauthorized_client` | Google OAuth client ID/secret in the External ID Google IDP config is wrong or rotated out-of-band | Re-paste the current client ID and secret into **External Identities -> All identity providers -> Google** ([G.2](#g2---configure-the-tenant-level-identity-providers)). |
| API returns `401 invalid_token` with `aud` claim mismatch | `accessTokenAcceptedVersion` on the API app reg is not `2` | Confirm `accessTokenAcceptedVersion = 2` in the API app reg manifest. Terraform's `api` block should set this; if set to `null` or `1`, tokens are v1 and will not match the v2 authority. |
| `Insufficient privileges to complete the operation` during `terraform apply` | Terraform deployer SP (Part B) missing admin consent | Return to [Part B](#4-part-b---create-the-terraform-service-principal-inside-the-external-id-tenant) step 6 and click **Grant admin consent**. |
| CI pipeline fails with `AADSTS700016` when touching External ID | CI SP missing Graph permissions or admin consent in workforce tenant | Rerun [Part E](#7-part-e---grant-workforce-tenant-graph-permissions-one-time). |
| `idp` claim absent on an ID token | User signed in via email OTP (local account) - this is expected | Backend defaults `ICurrentUser.Idp` to `"email"` for absent claims - see the [SSO plan](../../) phase 2A notes. |
| `Log in as Guest` does not open `/dashboard` | Runtime configuration and API flags differ | Compare `/api/runtime-config` with `Authentication__AllowGuest` on the API Container App, then redeploy both from the same tfvars. |
| `azuread.external` provider fails with `cannot unmarshal response: invalid character '<' looking for beginning of value` | `infra/azure/envs/<env>.tfvars` still has `<PLACEHOLDER: ...>` for `external_tenant_id` (and/or `tenant_subdomain`). `-var-file` beats `TF_VAR_*`, so Terraform is trying to authenticate against the literal placeholder string instead of the real GUID. | Paste the real values per the final step of [Part A](#3-part-a---create-the-entra-external-id-tenant-one-per-env), commit the tfvars change, then re-run `bash docs/runbooks/scripts/azure-plan-infra.sh <env>`. |
| `terraform plan` aborts during refresh with `ForbiddenByRbac` reading a Key Vault secret | Your `az login` identity does not currently hold the `deployer_officer` role, so data-source refresh cannot read Key Vault Secrets. | Use [`docs/runbooks/scripts/azure-plan-infra.sh`](./scripts/azure-plan-infra.sh) (which passes `-refresh=false`) for a local preview - refresh-free plans are advisory and sufficient for the safety check. Full-refresh plans are performed by CI under the platform SP. **Do not** attempt to grant yourself `deployer_officer` manually just to run a preview. |
| `400 InvalidAccessTokenVersion: Unable to create application. Access Token Accepted Version may not be 1 or null` on `authentication_application.*` | The app registration is missing `api { requested_access_token_version = 2 }`. External ID tenants reject v1 tokens, so every app reg - including public-client SPAs that do not themselves issue access tokens - must declare v2 up front, or the create call is rejected. | Verify the module's SPA app reg has the `api {}` block with `requested_access_token_version = 2`. This is resolved in the infra module as of the [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) pivot; if you are still seeing it, pull the latest module and re-plan. |
| `403 Authorization_RequestDenied: Insufficient privileges to complete the operation` on `authentication_application_identifier_uri` | The `ea-terraform-deployer` SP has `Application.ReadWrite.OwnedBy` rather than `Application.ReadWrite.All`. `.OwnedBy` can create an app registration but cannot patch `identifierUris` on it post-create - a known Graph quirk. | Upgrade the permission per the true-up callout at the end of [Part B](#4-part-b---create-the-terraform-service-principal-inside-the-external-id-tenant), then re-run the apply. |
| `403 Authorization_RequestDenied: When using this permission, the backing application of the service principal being created must in the local tenant` on `authentication_service_principal` | Same `.OwnedBy` vs `.All` gap - creating a service principal for a just-created app registration is gated behind `Application.ReadWrite.All` even when the app is single-tenant. | Upgrade the permission per the true-up callout at the end of [Part B](#4-part-b---create-the-terraform-service-principal-inside-the-external-id-tenant), then re-run the apply. |

---

## 11. Secret rotation

Secrets to rotate, and how:

### External ID tenant SP client secret (from Part B)

1. In the External ID tenant portal: **Entra ID -> App registrations -> `ea-terraform-deployer` -> Certificates & secrets -> New client secret**.
2. Copy the new secret value immediately.
3. Push to GitHub:

   ```bash
   gh secret set EXTERNAL_TENANT_CLIENT_SECRET --env dev        --body "<new-value>"
   gh secret set EXTERNAL_TENANT_CLIENT_SECRET --env production --body "<new-value>"
   ```

4. Re-run the deploy workflow to confirm Terraform still authenticates.
5. Delete the old secret from the app reg **Certificates & secrets** blade.

### Google OAuth client secret (from Part C)

Rotation is now **portal-only** - Terraform does not consume the Google secret, so there is no GitHub secret push and no re-apply.

1. In Google Cloud Console: **APIs & Services -> Credentials -> \<the OAuth client\> -> Reset secret**. Copy the new client secret.
2. Switch to the External ID tenant in the Azure Portal and open **External Identities -> All identity providers -> Google**.
3. Paste the new client secret into the **Client secret** field (the client ID stays the same unless you also rotated that). Save.
4. Update the entry in your password manager so future rotations read the current value.
5. Confirm sign-in still works end-to-end via the SPA. Google invalidates the old secret automatically after reset.

> If stale `GOOGLE_OIDC_CLIENT_ID` / `GOOGLE_OIDC_CLIENT_SECRET` entries still exist in GitHub Environment secrets from the pre-portal era, they are inert - no consumer reads them. See the true-up callout at the top of [Part G](#9-part-g---portal-configure-the-user-flow-and-identity-providers) for optional removal.

### Cadence

- Rotate both secrets (Part B deployer, Part C Google) **annually** at minimum, or immediately on suspected compromise or operator departure.
- Track expiry of the External ID SP secret (24 months from creation) - set a calendar reminder.
