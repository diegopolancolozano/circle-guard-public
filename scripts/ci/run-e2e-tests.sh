#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

export KUBECONFIG="${KUBECONFIG:-/var/jenkins_home/.kube/config}"

PF_PID_FILE="/tmp/e2e-pf-pids-$$"
: > "$PF_PID_FILE"

cleanup() {
  echo "=== Cleaning up port-forwards ==="
  if [[ -f "$PF_PID_FILE" ]]; then
    while IFS= read -r pid; do
      kill "$pid" >/dev/null 2>&1 || true
    done < "$PF_PID_FILE"
    rm -f "$PF_PID_FILE"
  fi
}
trap cleanup EXIT

# Wait up to 7.5 minutes for a health endpoint to respond
wait_for_health() {
  local local_url="$1"
  local max_attempts=150
  local sleep_secs=3
  local attempt

  for attempt in $(seq 1 "$max_attempts"); do
    if curl -fsS "${local_url}/actuator/health" >/dev/null 2>&1; then
      echo "[health] ${local_url} UP (attempt ${attempt})" >&2
      return 0
    fi
    echo "[health] ${local_url} not ready (attempt ${attempt}/${max_attempts}), waiting ${sleep_secs}s..." >&2
    sleep "$sleep_secs"
  done

  echo "ERROR: port-forward at ${local_url} did not become ready after $((max_attempts * sleep_secs))s" >&2
  return 1
}

# Start a port-forward, register its PID in the PID file, wait for health.
# Prints the local URL to stdout (safe to use in $() without losing the PID).
start_port_forward() {
  local service_name="$1"
  local local_port="$2"
  local remote_port="${3:-$2}"
  local log_file="/tmp/pf-${service_name}-${local_port}.log"
  local local_url="http://127.0.0.1:${local_port}"

  # Kill any stale port-forward on this port
  pkill -f "port-forward.*${local_port}:" >/dev/null 2>&1 || true
  sleep 2

  echo "=== Starting port-forward: ${service_name} -> ${local_url} ===" >&2
  kubectl -n "$ENVIRONMENT" port-forward \
    "svc/${service_name}" "${local_port}:${remote_port}" \
    --address 127.0.0.1 \
    >"$log_file" 2>&1 &

  local pid=$!
  # Write PID to file so the parent process can clean it up
  echo "$pid" >> "$PF_PID_FILE"

  # Give the port-forward process time to establish the tunnel
  sleep 3

  if ! wait_for_health "$local_url"; then
    echo "=== Port-forward log for ${service_name} ===" >&2
    cat "$log_file" >&2 || true
    exit 1
  fi

  # Only stdout: the URL (captured by $() callers)
  echo "$local_url"
}

AUTH_BASE_URL="$(start_port_forward circleguard-auth-service 18080)"
IDENTITY_BASE_URL="$(start_port_forward circleguard-identity-service 18081)"
PROMOTION_BASE_URL="$(start_port_forward circleguard-promotion-service 18082 8081)"
GATEWAY_BASE_URL="$(start_port_forward circleguard-gateway-service 18083)"
DASHBOARD_BASE_URL="$(start_port_forward circleguard-dashboard-service 18084)"
FILE_BASE_URL="$(start_port_forward circleguard-file-service 18085)"

export AUTH_BASE_URL IDENTITY_BASE_URL PROMOTION_BASE_URL GATEWAY_BASE_URL DASHBOARD_BASE_URL FILE_BASE_URL

# Sanity-check: all required URLs must be non-empty
echo "=== Port-forward URLs ==="
for var in IDENTITY_BASE_URL PROMOTION_BASE_URL GATEWAY_BASE_URL FILE_BASE_URL; do
  val="${!var}"
  if [[ -z "$val" ]]; then
    echo "ERROR: ${var} is empty — port-forward failed silently"
    exit 1
  fi
  echo "  ${var}=${val}"
done

# Final liveness check: verify each port-forward is still responding
echo "=== Verifying port-forwards are still active ==="
for var in IDENTITY_BASE_URL PROMOTION_BASE_URL GATEWAY_BASE_URL FILE_BASE_URL; do
  url="${!var}"
  if ! curl -fsS "${url}/actuator/health" >/dev/null 2>&1; then
    echo "ERROR: port-forward to ${url} dropped — cannot run tests"
    exit 1
  fi
  echo "  OK: ${url}"
done

export QR_SECRET
QR_SECRET="$(kubectl -n "$ENVIRONMENT" get secret qr-secret -o jsonpath='{.data.qr_secret}' | base64 --decode)"

echo "=== All port-forwards active — running E2E tests ==="

./gradlew :tests:circleguard-e2e-tests:test \
  -DIDENTITY_BASE_URL="$IDENTITY_BASE_URL" \
  -DPROMOTION_BASE_URL="$PROMOTION_BASE_URL" \
  -DGATEWAY_BASE_URL="$GATEWAY_BASE_URL" \
  -DFILE_BASE_URL="$FILE_BASE_URL"
