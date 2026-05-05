#!/usr/bin/env bash
set -euo pipefail

TAGS_RAW="${1:?tags required}"
IMAGE_PREFIX_TEMPLATE="${2:?image prefix required}"
DOCKERHUB_USERNAME="${3:?docker username required}"
DOCKERHUB_PASSWORD="${4:?docker password required}"

IFS="," read -r -a TAGS <<< "$TAGS_RAW"

SERVICES=(
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-promotion-service"
  "circleguard-gateway-service"
  "circleguard-form-service"
  "circleguard-notification-service"
)

# Keep the repository suffix from the configured prefix, but always push to the
# authenticated DockerHub namespace. That avoids mismatches when Jenkins uses a
# credential whose username differs from the hardcoded prefix in the pipeline.
image_repository_suffix="${IMAGE_PREFIX_TEMPLATE#*/}"
if [ -z "$image_repository_suffix" ] || [ "$image_repository_suffix" = "$IMAGE_PREFIX_TEMPLATE" ]; then
  image_repository_suffix="circleguard"
fi

IMAGE_PREFIX="${DOCKERHUB_USERNAME}/${image_repository_suffix}"

echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# Build all jars once to avoid recompiling inside each image build
echo "Building all service jars..."
./gradlew \
  :services:circleguard-auth-service:bootJar \
  :services:circleguard-identity-service:bootJar \
  :services:circleguard-promotion-service:bootJar \
  :services:circleguard-gateway-service:bootJar \
  :services:circleguard-form-service:bootJar \
  :services:circleguard-notification-service:bootJar -x test

for service_dir in "${SERVICES[@]}"; do
  service_suffix="${service_dir#circleguard-}"
  image_base="${IMAGE_PREFIX}-${service_suffix}"

  build_tags=()
  for tag in "${TAGS[@]}"; do
    build_tags+=("-t" "${image_base}:${tag}")
  done

  echo "Building ${image_base} (${TAGS_RAW})"
  # Build with service directory as context so docker only sends needed files
  docker build -f "services/${service_dir}/Dockerfile" "${build_tags[@]}" "services/${service_dir}"

  for tag in "${TAGS[@]}"; do
    echo "Pushing ${image_base}:${tag}"
    docker push "${image_base}:${tag}"
  done

done
