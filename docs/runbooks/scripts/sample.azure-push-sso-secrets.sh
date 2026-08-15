#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# sample.azure-push-sso-secrets.sh
#
# Purpose:
#   One-shot push of the four External-ID SSO values into a GitHub Environment
#   (`azure-dev` or `azure-production`, selected from a logical `dev` or
#   `production` argument). Replaces the inline `gh secret set` /
#   `gh variable set` commands from Part D (Section 6) of
#   docs/runbooks/azure-sso-manual-bootstrap.md.
#
#   The four values are:
#     - EXTERNAL_TENANT_ID             (secret)
#     - TENANT_SUBDOMAIN               (variable; not sensitive)
#     - EXTERNAL_TENANT_CLIENT_ID      (secret)
#     - EXTERNAL_TENANT_CLIENT_SECRET  (secret)
#
#   The Google OAuth client ID / client secret are NOT pushed here: the user
#   flow and the Google identity provider moved from Terraform-managed to
#   portal-managed (see Part G of the runbook). The Google credentials live in
#   the operator's password manager and are pasted directly into the External
#   ID portal's Google IDP config.
#
# Workflow:
#   1. Copy this file:
#        cp docs/runbooks/scripts/sample.azure-push-sso-secrets.sh \
#           docs/runbooks/scripts/azure-push-sso-secrets.sh
#   2. Open the copy and replace every `<PASTE ...>` placeholder with the real
#      value captured during the manual bootstrap.
#   3. Run it:
#        bash docs/runbooks/scripts/azure-push-sso-secrets.sh dev
#        bash docs/runbooks/scripts/azure-push-sso-secrets.sh production
#
# IMPORTANT:
#   The populated copy (`azure-push-sso-secrets.sh`) is gitignored and MUST NEVER be
#   committed. It contains live tenant secrets. Only this `sample.*` template
#   (with placeholders) is tracked.
#
# Prerequisites:
#   - `gh auth status` shows an authenticated session.
#   - The authenticated principal has write access to the repo's Environments
#     (to create/update env-scoped secrets and variables).
# -----------------------------------------------------------------------------

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <dev|production>" >&2
  exit 1
fi

ENV="$1"
GITHUB_ENVIRONMENT="azure-${ENV}"

case "$ENV" in
  dev)
    EXTERNAL_TENANT_ID="<PASTE DEV EXTERNAL_TENANT_ID>"
    TENANT_SUBDOMAIN="eacustomerdev"
    EXTERNAL_TENANT_CLIENT_ID="<PASTE DEV EXTERNAL_TENANT_CLIENT_ID>"
    EXTERNAL_TENANT_CLIENT_SECRET="<PASTE DEV EXTERNAL_TENANT_CLIENT_SECRET>"
    ;;
  production)
    EXTERNAL_TENANT_ID="<PASTE PRODUCTION EXTERNAL_TENANT_ID>"
    TENANT_SUBDOMAIN="eacustomerprod"
    EXTERNAL_TENANT_CLIENT_ID="<PASTE PRODUCTION EXTERNAL_TENANT_CLIENT_ID>"
    EXTERNAL_TENANT_CLIENT_SECRET="<PASTE PRODUCTION EXTERNAL_TENANT_CLIENT_SECRET>"
    ;;
  *)
    echo "Usage: $0 <dev|production>" >&2
    echo "Error: unknown environment '$ENV' (expected 'dev' or 'production')." >&2
    exit 1
    ;;
esac

# Guard: refuse to run if any sensitive value is still a placeholder.
for name in \
  EXTERNAL_TENANT_ID \
  EXTERNAL_TENANT_CLIENT_ID \
  EXTERNAL_TENANT_CLIENT_SECRET
do
  value="${!name}"
  if [[ "$value" == "<PASTE"* ]]; then
    echo "Unpopulated placeholder for ${name} — edit the script and retry." >&2
    exit 1
  fi
done

echo "Pushing SSO values to GitHub Environment: $GITHUB_ENVIRONMENT"

gh secret   set EXTERNAL_TENANT_ID            --env "$GITHUB_ENVIRONMENT" --body "$EXTERNAL_TENANT_ID"
gh variable set TENANT_SUBDOMAIN              --env "$GITHUB_ENVIRONMENT" --body "$TENANT_SUBDOMAIN"
gh secret   set EXTERNAL_TENANT_CLIENT_ID     --env "$GITHUB_ENVIRONMENT" --body "$EXTERNAL_TENANT_CLIENT_ID"
gh secret   set EXTERNAL_TENANT_CLIENT_SECRET --env "$GITHUB_ENVIRONMENT" --body "$EXTERNAL_TENANT_CLIENT_SECRET"

echo "Done — verify with: gh secret list --env $GITHUB_ENVIRONMENT && gh variable list --env $GITHUB_ENVIRONMENT"
