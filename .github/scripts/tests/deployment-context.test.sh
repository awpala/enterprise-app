#!/usr/bin/env bash
# Exercises push opt-out, manual provider selection, change detection, and AWS
# onboarding preflight with disposable Git history and no remote operations.
set -euo pipefail

readonly REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
readonly RESOLVER="${REPO_ROOT}/.github/scripts/resolve-deployment-context.sh"
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT

export GITHUB_OUTPUT="${temporary_root}/outputs"
export GITHUB_EVENT_NAME=push
export GITHUB_REF=refs/heads/main
export CONFIGURED_TARGETS=none
export MANUAL_TARGET=
export MANUAL_ENVIRONMENT=
export PUSH_BEFORE=missing-commit
export GITHUB_SHA=missing-commit

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

resolve() {
  : > "$GITHUB_OUTPUT"
  bash "$RESOLVER" > "${temporary_root}/resolver.log" 2>&1 || {
    cat "${temporary_root}/resolver.log" >&2
    fail 'deployment context unexpectedly failed'
  }
}

expect_output() {
  grep -Fxq "$1=$2" "$GITHUB_OUTPUT" || fail "expected $1=$2"
}

expect_rejected() {
  : > "$GITHUB_OUTPUT"
  if bash "$RESOLVER" > "${temporary_root}/resolver.log" 2>&1; then
    fail 'invalid deployment input was accepted'
  fi
  [[ ! -s "$GITHUB_OUTPUT" ]] || fail 'invalid input emitted deployment outputs'
}

# Opt-out works without a Git repository, commit history, or cloud credentials.
cd "$temporary_root"
resolve
expect_output environment production
expect_output azure_enabled false
expect_output aws_enabled false
expect_output api_changed false
expect_output data_engine_changed false
expect_output ui_changed false
GITHUB_REF=refs/heads/feature
CONFIGURED_TARGETS=NONE
resolve
expect_output environment dev
expect_output azure_enabled false
expect_output aws_enabled false

for CONFIGURED_TARGETS in '' typo 'none,aws'; do
  expect_rejected
done

# Manual dispatch ignores push policy and requests complete provider builds.
GITHUB_EVENT_NAME=workflow_dispatch
CONFIGURED_TARGETS=none
MANUAL_ENVIRONMENT=production
for MANUAL_TARGET in aws azure both azure,aws aws,azure; do
  resolve
  expect_output environment production
  expect_output api_changed true
  expect_output data_engine_changed true
  expect_output ui_changed true
  if [[ "$MANUAL_TARGET" == aws ]]; then
    expect_output azure_enabled false
    expect_output aws_enabled true
  elif [[ "$MANUAL_TARGET" == azure ]]; then
    expect_output azure_enabled true
    expect_output aws_enabled false
  else
    expect_output azure_enabled true
    expect_output aws_enabled true
  fi
done
MANUAL_TARGET=aws
MANUAL_ENVIRONMENT=dev
CONFIGURED_TARGETS=azure
resolve
expect_output environment dev
expect_output azure_enabled false
expect_output aws_enabled true
MANUAL_ENVIRONMENT=invalid
expect_rejected
MANUAL_ENVIRONMENT=production
for MANUAL_TARGET in '' none invalid; do
  expect_rejected
done

# Enabled pushes retain service change detection against real Git revisions.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
git init --quiet --initial-branch=main history
cd history
git config user.name 'Deployment test'
git config user.email 'deployment-test@example.invalid'
mkdir api ui data-engine
touch api/example ui/example data-engine/example
git add .
git -c core.hooksPath=/dev/null commit --quiet -m 'Initial fixture'
PUSH_BEFORE=$(git rev-parse HEAD)
git update-ref refs/remotes/origin/main "$PUSH_BEFORE"
echo changed > ui/example
git add ui/example
git -c core.hooksPath=/dev/null commit --quiet -m 'UI fixture change'
GITHUB_SHA=$(git rev-parse HEAD)
GITHUB_EVENT_NAME=push
GITHUB_REF=refs/heads/main
CONFIGURED_TARGETS=aws
resolve
expect_output environment production
expect_output aws_enabled true
expect_output azure_enabled false
expect_output api_changed false
expect_output data_engine_changed false
expect_output ui_changed true

# A zero before-SHA uses the existing main/feature fallback semantics.
PUSH_BEFORE=0000000000000000000000000000000000000000
CONFIGURED_TARGETS=both
resolve
expect_output azure_enabled true
expect_output aws_enabled true
expect_output ui_changed true
GITHUB_REF=refs/heads/feature
CONFIGURED_TARGETS=azure
resolve
expect_output environment dev
expect_output azure_enabled true
expect_output aws_enabled false
expect_output api_changed false
expect_output ui_changed true

# Legacy onboarding configs must not require AWS-inclusive push policy.
# Stop at the first AWS call, before any authenticated or remote operation.
mkdir "${temporary_root}/bin"
cat > "${temporary_root}/bin/aws" <<'MOCK'
#!/usr/bin/env bash
echo 'Stopped at mocked AWS identity preflight.' >&2
exit 77
MOCK
cp "${temporary_root}/bin/aws" "${temporary_root}/bin/terraform"
cp "${temporary_root}/bin/aws" "${temporary_root}/bin/gh"
cp "${temporary_root}/bin/aws" "${temporary_root}/bin/rg"
chmod +x "${temporary_root}/bin/"*
cat > "${temporary_root}/onboard.env" <<'CONFIG'
AWS_PROFILE=fixture
AWS_REGION=us-east-1
AWS_NAME_SUFFIX=test01
GITHUB_OWNER=fixture
GITHUB_REPO=fixture
COGNITO_DOMAIN_PREFIX=fixture
AWS_MONTHLY_BUDGET_USD=1
DEPLOY_REF=main
CONFIG
for policy in absent none aws azure; do
  cp "${temporary_root}/onboard.env" "${temporary_root}/case.env"
  if [[ "$policy" != absent ]]; then
    printf 'DEPLOYMENT_TARGETS=%s\n' "$policy" >> "${temporary_root}/case.env"
  fi
  status=0
  env -u DEPLOYMENT_TARGETS PATH="${temporary_root}/bin:${PATH}" \
    bash "${REPO_ROOT}/infra/scripts/aws-onboard.sh" dev \
    --config "${temporary_root}/case.env" \
    > "${temporary_root}/onboard.log" 2>&1 || status=$?
  if [[ "$status" -ne 77 ]]; then
    cat "${temporary_root}/onboard.log" >&2
    fail "onboarding rejected push policy $policy before AWS preflight"
  fi
done

echo 'Deployment context and onboarding preflight regression tests passed.'
