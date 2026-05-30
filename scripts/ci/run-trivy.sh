#!/usr/bin/env bash
set -euo pipefail

TAGS_RAW="${1:?tags required}"
IMAGE_PREFIX="${2:?image prefix required}"

IFS="," read -r -a TAGS <<< "$TAGS_RAW"

SERVICES=(
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-promotion-service"
  "circleguard-gateway-service"
  "circleguard-dashboard-service"
  "circleguard-file-service"
)

RESULTS_DIR="${WORKSPACE:-${PWD}}/tests/security/results"
mkdir -p "${RESULTS_DIR}"

TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.52.2}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
TRIVY_EXIT_CODE="${TRIVY_EXIT_CODE:-0}"

scan_image() {
  local image_ref="$1"
  local safe_name="$2"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${RESULTS_DIR}:/output" \
    "${TRIVY_IMAGE}" \
    image --severity "${TRIVY_SEVERITY}" --ignore-unfixed \
    --exit-code "${TRIVY_EXIT_CODE}" \
    --format json --output "/output/trivy-${safe_name}.json" \
    "${image_ref}"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${RESULTS_DIR}:/output" \
    "${TRIVY_IMAGE}" \
    image --severity "${TRIVY_SEVERITY}" --ignore-unfixed \
    --exit-code 0 \
    --format table --output "/output/trivy-${safe_name}.txt" \
    "${image_ref}"
}

for service_dir in "${SERVICES[@]}"; do
  service_suffix="${service_dir#circleguard-}"
  image_base="${IMAGE_PREFIX}-${service_suffix}"

  for tag in "${TAGS[@]}"; do
    image_ref="${image_base}:${tag}"
    safe_name="${image_base//\//_}-${tag}"
    echo "[trivy] Scanning ${image_ref}"
    scan_image "${image_ref}" "${safe_name}"
  done
done

printf "[trivy] Reports written to %s\n" "${RESULTS_DIR}"
