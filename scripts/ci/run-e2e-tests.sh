#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

export KUBECONFIG="${KUBECONFIG:-/var/jenkins_home/.kube/config}"

PORT_FORWARD_PIDS=()

cleanup() {
  for pid in "${PORT_FORWARD_PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

wait_for_health() {
  local local_url="$1"
  for attempt in $(seq 1 150); do
    if curl -fsS "$local_url/actuator/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  echo "ERROR: port-forward at ${local_url} did not become ready"
  exit 1
}

svc_url() {
  local service_name="$1"
  local local_port="$2"
  local remote_port="${3:-$2}"

  # Kill any existing port-forward on this port
  fuser -k "${local_port}/tcp" >/dev/null 2>&1 || true

  kubectl -n "$ENVIRONMENT" port-forward "svc/${service_name}" "${local_port}:${remote_port}" --address 127.0.0.1 >/tmp/${service_name}-${local_port}.log 2>&1 &
  PORT_FORWARD_PIDS+=("$!")
  wait_for_health "http://127.0.0.1:${local_port}"
  echo "http://127.0.0.1:${local_port}"
}

export AUTH_BASE_URL="$(svc_url circleguard-auth-service 18080)"
export IDENTITY_BASE_URL="$(svc_url circleguard-identity-service 18081)"
export PROMOTION_BASE_URL="$(svc_url circleguard-promotion-service 18082 8081)"
export GATEWAY_BASE_URL="$(svc_url circleguard-gateway-service 18083)"
export DASHBOARD_BASE_URL="$(svc_url circleguard-dashboard-service 18084)"
export FILE_BASE_URL="$(svc_url circleguard-file-service 18085)"

export QR_SECRET="$(kubectl -n "$ENVIRONMENT" get secret qr-secret -o jsonpath='{.data.qr_secret}' | base64 --decode)"

# Verify all port-forwards are still alive before running tests
echo "=== Verifying port-forwards are active ==="
for url in "$IDENTITY_BASE_URL" "$PROMOTION_BASE_URL" "$GATEWAY_BASE_URL" "$FILE_BASE_URL"; do
  if ! curl -fsS "${url}/actuator/health" >/dev/null 2>&1; then
    echo "ERROR: port-forward to ${url} is not responding"
    exit 1
  fi
done
echo "All port-forwards active"

./gradlew :tests:circleguard-e2e-tests:test \
  -DIDENTITY_BASE_URL="$IDENTITY_BASE_URL" \
  -DPROMOTION_BASE_URL="$PROMOTION_BASE_URL" \
  -DGATEWAY_BASE_URL="$GATEWAY_BASE_URL" \
  -DFILE_BASE_URL="$FILE_BASE_URL"
