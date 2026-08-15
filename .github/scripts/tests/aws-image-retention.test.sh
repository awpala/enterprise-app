#!/usr/bin/env bash
# Black-box regression tests for active-image-aware AWS ECR retention.
set -euo pipefail

readonly REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
readonly TEST_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly FIXTURE_ROOT="${TEST_ROOT}/fixtures"
readonly EXPECTED_ACTIVE_REFERENCES=$'ea-api\tactive-api\nea-data-engine\t@sha256:data-active\nea-migrations\tactive-migrations\nea-ui\tactive-ui-current\nea-ui\tactive-ui-draining'
readonly EXPECTED_DELETIONS=$'ea-api\tstale-api-a\nea-api\tstale-api-b\nea-data-engine\tstale-data\nea-migrations\tstale-migrations\nea-ui\tstale-ui'

temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT

export AWS_REGION=test-region
export GITHUB_WORKSPACE="$REPO_ROOT"
export IMAGE_TAG=release-under-test
export MOCK_AWS_STATE="${FIXTURE_ROOT}/aws-image-retention-state.json"
export MOCK_DELETE_LOG="${temporary_root}/deleted-tags.tsv"
export PATH="${FIXTURE_ROOT}:${PATH}"
export TF_ROOT="${REPO_ROOT}/infra/aws"

touch "$MOCK_DELETE_LOG"

assert_equal() {
  local expected=$1
  local actual=$2
  local message=$3
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $message" >&2
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >&2 || true
    exit 1
  fi
}

assert_cleanup_before_verifier() {
  local workflow=$1
  local cleanup_line
  local verifier_line
  cleanup_line=$(grep -nF '.github/scripts/aws-clean-images.sh' "$workflow" | tail -n 1 | cut -d: -f1)
  verifier_line=$(grep -nF '.github/scripts/aws-verify-active-images.sh' "$workflow" | tail -n 1 | cut -d: -f1)
  if [[ -z "$cleanup_line" || -z "$verifier_line" || "$verifier_line" -le "$cleanup_line" ]]; then
    echo "FAIL: $workflow must invoke the active-image verifier after cleanup." >&2
    exit 1
  fi
}

assert_manual_cleanup_uses_logical_environments() {
  local workflow=$1
  local logical_environment_count
  logical_environment_count=$(grep -cF 'environment: ${{ inputs.environment }}' "$workflow")
  if [[ "$logical_environment_count" -ne 2 ]]; then
    echo "FAIL: both manual cleanup jobs must use the shared dev/production GitHub Environment." >&2
    exit 1
  fi
  if grep -Eq 'environment: (aws|azure)-' "$workflow"; then
    echo "FAIL: manual cleanup must not recreate provider-prefixed GitHub Environments." >&2
    exit 1
  fi
}

actual_active_references=$("${REPO_ROOT}/.github/scripts/aws-list-active-images.sh")
assert_equal "$EXPECTED_ACTIVE_REFERENCES" "$actual_active_references" \
  'current, draining, digest-pinned, and migration task references must all be discovered'

"${REPO_ROOT}/.github/scripts/aws-clean-images.sh" >/dev/null
actual_deletions=$(sort "$MOCK_DELETE_LOG")
assert_equal "$EXPECTED_DELETIONS" "$actual_deletions" \
  'only tags on stale, unprotected digests may be deleted'

"${REPO_ROOT}/.github/scripts/aws-verify-active-images.sh" >/dev/null

export MOCK_MISSING_REFERENCE='ea-ui|active-ui-draining'
if "${REPO_ROOT}/.github/scripts/aws-verify-active-images.sh" >/dev/null 2>&1; then
  echo 'FAIL: verifier must fail when a draining deployment image is missing.' >&2
  exit 1
fi
unset MOCK_MISSING_REFERENCE

assert_cleanup_before_verifier "${REPO_ROOT}/.github/workflows/deploy-aws.yml"
assert_cleanup_before_verifier "${REPO_ROOT}/.github/workflows/cleanup-images.yml"
assert_manual_cleanup_uses_logical_environments "${REPO_ROOT}/.github/workflows/cleanup-images.yml"

echo 'AWS image-retention regression tests passed.'
