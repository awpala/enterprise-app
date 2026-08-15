#!/usr/bin/env bash
# AWS adapter: builds changed application images and pushes them to the ECR
# repositories created by the AWS registry phase. Unchanged images are copied
# to the immutable deployment tag through an ECR manifest put.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

REPO_ROOT=${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}
TF_ROOT="${REPO_ROOT}/infra/aws"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

image_exists() {
  local repository_name=$1

  aws ecr describe-images \
    --repository-name "$repository_name" \
    --region "$AWS_REGION" \
    --image-ids imageTag="$IMAGE_TAG" >/dev/null 2>&1
}

build_and_push() {
  local repository=$1
  local dockerfile=$2
  local context=$3
  local image
  image=$(terraform -chdir="$TF_ROOT" output -json ecr_repository_urls \
    | jq -r --arg repository "$repository" '.[$repository]')

  if image_exists "${image##*/}"; then
    echo "Reusing immutable image ${image}:${IMAGE_TAG}."
    return
  fi

  image="${image}:${IMAGE_TAG}"

  docker build --file "${REPO_ROOT}/${dockerfile}" --tag "$image" "${REPO_ROOT}/${context}"
  docker push "$image"
}

retag_latest() {
  local repository=$1
  local repository_uri
  local repository_name
  local source_tag
  local manifest

  repository_uri=$(terraform -chdir="$TF_ROOT" output -json ecr_repository_urls \
    | jq -r --arg repository "$repository" '.[$repository]')
  repository_name=${repository_uri##*/}

  if image_exists "$repository_name"; then
    echo "Reusing immutable image ${repository_uri}:${IMAGE_TAG}."
    return
  fi

  source_tag=$(aws ecr describe-images \
    --repository-name "$repository_name" \
    --region "$AWS_REGION" \
    --query 'reverse(sort_by(imageDetails[?imageTags!=null], &imagePushedAt))[0].imageTags[0]' \
    --output text 2>/dev/null || true)

  if [[ -z "$source_tag" || "$source_tag" == "None" ]]; then
    return 1
  fi

  manifest=$(aws ecr batch-get-image \
    --repository-name "$repository_name" \
    --region "$AWS_REGION" \
    --image-ids imageTag="$source_tag" \
    --query 'images[0].imageManifest' \
    --output text)
  aws ecr put-image \
    --repository-name "$repository_name" \
    --region "$AWS_REGION" \
    --image-tag "$IMAGE_TAG" \
    --image-manifest "$manifest" >/dev/null
  echo "Copied ${repository_uri}:${source_tag} to immutable tag ${IMAGE_TAG}."
}

build_or_retag() {
  local changed=$1
  local repository=$2
  local dockerfile=$3
  local context=$4

  if [[ "$changed" == "true" ]]; then
    build_and_push "$repository" "$dockerfile" "$context"
  elif ! retag_latest "$repository"; then
    echo "No existing image found for $repository; building it."
    build_and_push "$repository" "$dockerfile" "$context"
  fi
}

build_or_retag "${API_CHANGED:-true}" ea-api api/Dockerfile api
build_or_retag "${API_CHANGED:-true}" ea-migrations api/Dockerfile.migrations api
build_or_retag "${DATA_ENGINE_CHANGED:-true}" ea-data-engine data-engine/Dockerfile data-engine
build_or_retag "${UI_CHANGED:-true}" ea-ui ui/Dockerfile ui
