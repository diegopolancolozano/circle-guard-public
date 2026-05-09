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
  
  return 0
}

echo "=== Deploying infrastructure components ==="
INFRA_DEPLOYMENTS=(
  "postgres"
  "redis"
  "neo4j"
  "zookeeper"
  "kafka"
  "openldap"
)

for deploy in "${INFRA_DEPLOYMENTS[@]}"; do
  if ! wait_for_rollout "$deploy" "$INFRA_TIMEOUT"; then
    exit 1
  fi
done

echo "=== Deploying application services ==="
SERVICE_DEPLOYMENTS=(
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-promotion-service"
  "circleguard-gateway-service"
  "circleguard-dashboard-service"
  "circleguard-file-service"
)

for deploy in "${SERVICE_DEPLOYMENTS[@]}"; do
  if ! wait_for_rollout "$deploy" "$SERVICE_TIMEOUT"; then
    exit 1
  fi
done

echo "=== All deployments ready ==="
