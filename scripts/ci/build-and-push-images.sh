#!/usr/bin/env bash
set -euo pipefail

TAGS_RAW="${1:?tags required}"
IMAGE_PREFIX="${2:?image prefix required}"
DOCKERHUB_USERNAME="${3:?docker username required}"
DOCKERHUB_PASSWORD="${4:?docker password required}"

IFS="," read -r -a TAGS <<< "$TAGS_RAW"

SERVICES=(
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-promotion-service"
  "circleguard-gateway-service"
  "circleguard-dashboard-service"
  "circleguard-file-service"
)

echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

for service_dir in "${SERVICES[@]}"; do
  service_suffix="${service_dir#circleguard-}"
  image_base="${IMAGE_PREFIX}-${service_suffix}"

  build_tags=()
  for tag in "${TAGS[@]}"; do
    build_tags+=("-t" "${image_base}:${tag}")
  done

  echo "Building ${image_base} (${TAGS_RAW})"
  docker build -f "services/${service_dir}/Dockerfile" "${build_tags[@]}" .

  for tag in "${TAGS[@]}"; do
    echo "Pushing ${image_base}:${tag}"
    docker push "${image_base}:${tag}"
  done

done
