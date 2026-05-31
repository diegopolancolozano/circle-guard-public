#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
# Keep generous defaults because Spring services can take several minutes on cold start.
INFRA_TIMEOUT="${INFRA_TIMEOUT:-420s}"
SERVICE_TIMEOUT="${SERVICE_TIMEOUT:-420s}"

wait_for_rollout() {
  local deploy="$1"
  local timeout="$2"

  echo "Waiting for deployment ${deploy} in ${ENVIRONMENT} (timeout=${timeout})"

  # First check if deployment exists
  if ! kubectl -n "$ENVIRONMENT" get deployment "$deploy" >/dev/null 2>&1; then
    echo "ERROR: deployment ${deploy} does not exist in ${ENVIRONMENT}"
    return 1
  fi

  # Try rollout status with timeout
  if ! timeout "${timeout%s}" kubectl -n "$ENVIRONMENT" rollout status "deployment/${deploy}" --timeout="${timeout}"; then
    echo "ERROR: rollout failed or timed out for deployment ${deploy} in ${ENVIRONMENT}"

    echo "== Deployment status =="
    kubectl -n "$ENVIRONMENT" get deployment "$deploy" -o wide || true

    echo "== ReplicaSets for ${deploy} =="
    kubectl -n "$ENVIRONMENT" get rs -l "app=${deploy}" -o wide || true

    echo "== Pods for ${deploy} =="
    kubectl -n "$ENVIRONMENT" get pods -l "app=${deploy}" -o wide || true

    # Get pod names with a timeout
    local pod_names
    pod_names=$(timeout 30 kubectl -n "$ENVIRONMENT" get pods -l "app=${deploy}" --no-headers 2>/dev/null | awk '{print $1}' || true)

    if [ -n "${pod_names}" ]; then
      for p in ${pod_names}; do
        echo "-- Logs for pod ${p} (last 100 lines) --"
        kubectl -n "$ENVIRONMENT" logs "${p}" --tail=100 --ignore-errors || true
        echo "-- Previous logs for pod ${p} (if crashed) --"
        kubectl -n "$ENVIRONMENT" logs "${p}" --previous --tail=50 --ignore-errors || true
        echo "-- Describe pod ${p} --"
        kubectl -n "$ENVIRONMENT" describe pod "${p}" || true
      done
    else
      echo "No pods found for deployment ${deploy}"
      echo "This usually means:"
      echo "  1. Image pull is failing"
      echo "  2. Resource constraints preventing pod creation"
      echo "  3. Deployment selector doesn't match pod labels"
    fi

    echo "== Recent events in namespace ${ENVIRONMENT} =="
    kubectl -n "$ENVIRONMENT" get events --sort-by='.metadata.creationTimestamp' --field-selector involvedObject.name="${deploy}" 2>/dev/null | tail -n 50 || true

    return 1
  fi

  echo "OK: ${deploy} is ready"
  return 0
}

# Wait for a set of deployments IN PARALLEL.
# All rollouts are launched as background jobs; we collect exit codes at the end.
# Returns non-zero if ANY deployment fails.
wait_parallel() {
  local timeout="$1"; shift
  local pids=()
  local names=()

  for deploy in "$@"; do
    wait_for_rollout "$deploy" "$timeout" &
    pids+=($!)
    names+=("$deploy")
  done

  local failed=0
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      echo "FAILED: ${names[$i]}"
      failed=1
    fi
  done
  return $failed
}

# ── 1. Infrastructure — ordered to respect dependencies ───────────────────────
# postgres and redis are independent: wait in parallel.
echo "=== Waiting for postgres + redis (parallel) ==="
wait_parallel "$INFRA_TIMEOUT" postgres redis

# zookeeper must be ready before kafka can connect. Wait sequentially.
echo "=== Waiting for zookeeper ==="
wait_for_rollout zookeeper "$INFRA_TIMEOUT"

# kafka connects to zookeeper on start; waiting after zookeeper is ready
# avoids crash-loop back-off from early connection failures.
echo "=== Waiting for kafka ==="
wait_for_rollout kafka "$INFRA_TIMEOUT"

# ── 2. Application services — all in parallel once infra is ready ─────────────
# Each Spring service starts independently; the longest one bounds the wait.
echo "=== Waiting for application services (parallel) ==="
wait_parallel "$SERVICE_TIMEOUT" \
  circleguard-auth-service \
  circleguard-identity-service \
  circleguard-promotion-service \
  circleguard-gateway-service \
  circleguard-dashboard-service \
  circleguard-file-service

echo "=== All deployments ready ==="
