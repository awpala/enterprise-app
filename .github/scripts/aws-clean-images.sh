#!/usr/bin/env bash
# AWS adapter: removes stale tagged images while retaining the newest image and
# an optional `latest` tag in each application ECR repository.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
REPO_ROOT=${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}
TF_ROOT="${REPO_ROOT}/infra/aws"

mapfile -t REPOSITORY_URLS < <(
  terraform -chdir="$TF_ROOT" output -json ecr_repository_urls | jq -r '.[]'
)

for repository_url in "${REPOSITORY_URLS[@]}"; do
  repository=${repository_url##*/}
  mapfile -t tags < <(
    aws ecr describe-images \
      --repository-name "$repository" \
      --region "$AWS_REGION" \
      --query 'reverse(sort_by(imageDetails[?imageTags!=null], &imagePushedAt))[].imageTags[]' \
      --output text | tr '\t' '\n'
  )

  if (( ${#tags[@]} <= 1 )); then
    echo "$repository has no stale tags."
    continue
  fi

  newest=${tags[0]}
  for tag in "${tags[@]}"; do
    if [[ "$tag" == "$newest" || "$tag" == "latest" ]]; then
      echo "Keeping ${repository}:${tag}."
      continue
    fi
    echo "Deleting ${repository}:${tag}."
    aws ecr batch-delete-image \
      --repository-name "$repository" \
      --region "$AWS_REGION" \
      --image-ids imageTag="$tag" >/dev/null
  done
done
