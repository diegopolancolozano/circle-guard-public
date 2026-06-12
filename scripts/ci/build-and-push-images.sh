#!/usr/bin/env bash
# =============================================================================
# build-and-push-images.sh
#
# Builds bootJars (reusing classes compiled in the test stage — no clean) and
# pushes Docker images for all CircleGuard services.
#
# Usage:
#   build-and-push-images.sh <tags> <image-prefix> <docker-user> <docker-pass>
#
# Arguments:
#   tags          Comma-separated list of image tags, e.g. "stage,0.2.1"
#   image-prefix  DockerHub prefix, e.g. "diegoapolancol/circleguard"
#   docker-user   DockerHub username
#   docker-pass   DockerHub access token / password
# =============================================================================
set -euo pipefail

TAGS_RAW="${1:?tags required (comma-separated, e.g. stage,0.2.1)}"
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
  "circleguard-form-service"
  "circleguard-notification-service"
)

echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# Build bootJars WITHOUT 'clean' — reuses compiled classes from the test stage.
# '-x test' skips re-running tests (already ran in Build & Test stage).
echo "=== Building bootJars (reusing test-stage compilation) ==="
./gradlew \
  :services:circleguard-auth-service:bootJar \
  :services:circleguard-identity-service:bootJar \
  :services:circleguard-promotion-service:bootJar \
  :services:circleguard-gateway-service:bootJar \
  :services:circleguard-dashboard-service:bootJar \
  :services:circleguard-file-service:bootJar \
  :services:circleguard-form-service:bootJar \
  :services:circleguard-notification-service:bootJar \
  -x test --no-daemon --parallel

echo "=== Building and pushing Docker images ==="
for service_dir in "${SERVICES[@]}"; do
  dockerfile="services/${service_dir}/Dockerfile"
  if [ ! -f "$dockerfile" ]; then
    echo "WARN: ${dockerfile} not found — skipping ${service_dir}"
    continue
  fi

  service_suffix="${service_dir#circleguard-}"
  image_base="${IMAGE_PREFIX}-${service_suffix}"

  build_tags=()
  for tag in "${TAGS[@]}"; do
    build_tags+=("-t" "${image_base}:${tag}")
  done

  echo "--- Building ${image_base} [${TAGS_RAW}] ---"
  docker build -f "${dockerfile}" "${build_tags[@]}" "services/${service_dir}"

  for tag in "${TAGS[@]}"; do
    echo "Pushing ${image_base}:${tag}"
    docker push "${image_base}:${tag}"
  done
done

echo "=== All images pushed successfully ==="
