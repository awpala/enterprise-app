#!/usr/bin/env bash
# Removes stale AWS ECR tags without deleting any image referenced by an ECS
# deployment. Retagged images share imagePushedAt, so retention is evaluated by
# image digest and never by the arbitrary order of tags on a digest.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
readonly REPO_ROOT=${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}
readonly TF_ROOT=${TF_ROOT:-"${REPO_ROOT}/infra/aws"}
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

declare -A protected_tags=()
declare -A protected_digests=()

active_references=$("${SCRIPT_DIR}/aws-list-active-images.sh")
while IFS=$'\t' read -r repository reference; do
  [[ -n "$repository" && -n "$reference" ]] || continue
  if [[ "$reference" == @* ]]; then
    protected_digests["${repository}|${reference#@}"]=1
  else
    protected_tags["${repository}|${reference}"]=1
  fi
done <<<"$active_references"

repository_output=$(terraform -chdir="$TF_ROOT" output -json ecr_repository_urls)
repository_lines=$(jq -r '.[]' <<<"$repository_output")
repository_urls=()
while IFS= read -r repository_url; do
  [[ -n "$repository_url" ]] && repository_urls+=("$repository_url")
done <<<"$repository_lines"

for repository_url in "${repository_urls[@]}"; do
  repository=${repository_url##*/}
  images=$(aws ecr describe-images \
    --repository-name "$repository" \
    --region "$AWS_REGION" \
    --output json)
  newest_digest=$(jq -r '
    [.imageDetails[] | select((.imageTags // []) | length > 0)]
    | sort_by(.imagePushedAt, .imageDigest)
    | last
    | .imageDigest // empty
  ' <<<"$images")

  if [[ -z "$newest_digest" ]]; then
    echo "$repository has no tagged images."
    continue
  fi

  tag_rows=$(jq -r '
    [.imageDetails[]
      | .imageDigest as $digest
      | (.imageTags // [])[]
      | { digest: $digest, tag: . }]
    | sort_by(.digest, .tag)
    | .[]
    | [.digest, .tag]
    | @tsv
  ' <<<"$images")
  while IFS=$'\t' read -r digest tag; do
    [[ -n "$digest" && -n "$tag" ]] || continue

    if [[ "$digest" == "$newest_digest" ]]; then
      echo "Keeping ${repository}:${tag} because it is on the newest digest."
      continue
    fi
    if [[ "$tag" == "latest" ]]; then
      echo "Keeping ${repository}:${tag}."
      continue
    fi
    if [[ -n "${IMAGE_TAG:-}" && "$tag" == "$IMAGE_TAG" ]]; then
      echo "Keeping ${repository}:${tag} because it is the current deployment tag."
      continue
    fi
    if [[ -n "${protected_tags["${repository}|${tag}"]+x}" ]]; then
      echo "Keeping ${repository}:${tag} because an ECS task definition references it."
      continue
    fi
    if [[ -n "${protected_digests["${repository}|${digest}"]+x}" ]]; then
      echo "Keeping ${repository}:${tag} because ECS references its digest."
      continue
    fi

    echo "Deleting stale tag ${repository}:${tag}."
    aws ecr batch-delete-image \
      --repository-name "$repository" \
      --region "$AWS_REGION" \
      --image-ids imageTag="$tag" >/dev/null
  done <<<"$tag_rows"
done
