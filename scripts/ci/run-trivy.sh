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

TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
TRIVY_EXIT_CODE="${TRIVY_EXIT_CODE:-0}"
<<<<<<< HEAD
=======

# Verify trivy is available
if ! command -v trivy &>/dev/null; then
  echo "ERROR: trivy binary not found in PATH. Install it in the Jenkins image." >&2
  exit 1
fi
>>>>>>> 592fff0fd61db2e7d7a088e30a55876516a9f768

scan_image() {
  local image_ref="$1"
  local safe_name="$2"
  local json_out="${RESULTS_DIR}/trivy-${safe_name}.json"
  local txt_out="${RESULTS_DIR}/trivy-${safe_name}.txt"

<<<<<<< HEAD
  # trivy-cache persists the vuln DB across builds — avoids re-downloading on every run
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache/trivy \
    -v "${RESULTS_DIR}:/output" \
    "${TRIVY_IMAGE}" \
    image --severity "${TRIVY_SEVERITY}" --ignore-unfixed \
=======
  # Scan to JSON
  trivy image \
    --severity "${TRIVY_SEVERITY}" \
    --ignore-unfixed \
>>>>>>> 592fff0fd61db2e7d7a088e30a55876516a9f768
    --exit-code "${TRIVY_EXIT_CODE}" \
    --format json \
    --output "${json_out}" \
    "${image_ref}"

<<<<<<< HEAD
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache/trivy \
    -v "${RESULTS_DIR}:/output" \
    "${TRIVY_IMAGE}" \
    image --severity "${TRIVY_SEVERITY}" --ignore-unfixed \
    --exit-code 0 \
    --format table --output "/output/trivy-${safe_name}.txt" \
    "${image_ref}"
=======
  # Convert JSON to table (no re-scan)
  trivy convert \
    --format table \
    --output "${txt_out}" \
    "${json_out}"
>>>>>>> 592fff0fd61db2e7d7a088e30a55876516a9f768
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
