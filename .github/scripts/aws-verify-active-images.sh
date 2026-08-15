#!/usr/bin/env bash
# Fails when ECR cannot resolve an image used by a current/draining ECS
# deployment or by the configured migration task definition.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

reference_count=0
missing_count=0
active_references=$("${SCRIPT_DIR}/aws-list-active-images.sh")
while IFS=$'\t' read -r repository reference; do
  [[ -n "$repository" && -n "$reference" ]] || continue
  ((reference_count += 1))

  if [[ "$reference" == @* ]]; then
    image_id="imageDigest=${reference#@}"
  else
    image_id="imageTag=${reference}"
  fi

  if aws ecr describe-images \
    --repository-name "$repository" \
    --region "$AWS_REGION" \
    --image-ids "$image_id" >/dev/null 2>&1; then
    echo "Verified active image ${repository}:${reference}."
  else
    echo "::error::Active ECS image is missing from ECR: ${repository}:${reference}." >&2
    ((missing_count += 1))
  fi
done <<<"$active_references"

if ((reference_count == 0)); then
  echo "No active AWS ECR image references were discovered." >&2
  exit 1
fi
if ((missing_count > 0)); then
  echo "$missing_count active AWS ECR image reference(s) are missing." >&2
  exit 1
fi

echo "Verified $reference_count active AWS ECR image reference(s)."
