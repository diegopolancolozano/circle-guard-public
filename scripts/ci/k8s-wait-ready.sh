#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
# Reduced timeout: fail fast to detect issues earlier
INFRA_TIMEOUT="${INFRA_TIMEOUT:-180s}"
SERVICE_TIMEOUT="${SERVICE_TIMEOUT:-120s}"

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
  echo "Waiting for deployment ${deploy} in ${ENVIRONMENT} (timeout=${INFRA_TIMEOUT})"
  if ! kubectl -n "$ENVIRONMENT" rollout status "deployment/${deploy}" --timeout="${INFRA_TIMEOUT}"; then
    echo "ERROR: rollout failed or timed out for deployment ${deploy} in ${ENVIRONMENT}"
    echo "Gathering diagnostics for ${deploy}..."

    echo "== Pods (all) in namespace ${ENVIRONMENT} =="
    kubectl -n "$ENVIRONMENT" get pods -o wide || true

    echo "== Pods matching '${deploy}' =="
    pod_names=$(kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null | awk '/'"${deploy}"'/ {print $1}' || true)
    if [ -n "${pod_names}" ]; then
      for p in ${pod_names}; do
        echo "-- Logs for pod ${p} (last 100 lines) --"
        kubectl -n "$ENVIRONMENT" logs "${p}" --tail=100 || true
        echo "-- Describe pod ${p} --"
        kubectl -n "$ENVIRONMENT" describe pod "${p}" || true
      done
    else
      echo "No pods found matching ${deploy}"
    fi

    echo "== Events in namespace ${ENVIRONMENT} (last 100) =="
    kubectl -n "$ENVIRONMENT" get events --sort-by='.metadata.creationTimestamp' | tail -n 100 || true

    exit 1
  fi
done

echo "=== Deploying application services ==="
SERVICE_DEPLOYMENTS=(
  "circleguard-identity-service"
  "circleguard-auth-service"
  "circleguard-promotion-service"
  "circleguard-gateway-service"
  "circleguard-form-service"
  "circleguard-notification-service"
)

for deploy in "${SERVICE_DEPLOYMENTS[@]}"; do
  echo "Waiting for deployment ${deploy} in ${ENVIRONMENT} (timeout=${SERVICE_TIMEOUT})"
  if ! kubectl -n "$ENVIRONMENT" rollout status "deployment/${deploy}" --timeout="${SERVICE_TIMEOUT}"; then
    echo "ERROR: rollout failed or timed out for deployment ${deploy} in ${ENVIRONMENT}"
    echo "Gathering diagnostics for ${deploy}..."

    echo "== Pods matching '${deploy}' =="
    pod_names=$(kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null | awk '/'"${deploy}"'/ {print $1}' || true)
    if [ -n "${pod_names}" ]; then
      for p in ${pod_names}; do
        echo "-- Logs for pod ${p} (last 100 lines) --"
        kubectl -n "$ENVIRONMENT" logs "${p}" --tail=100 || true
        echo "-- Describe pod ${p} --"
        kubectl -n "$ENVIRONMENT" describe pod "${p}" || true
      done
    else
      echo "No pods found matching ${deploy}"
    fi

    echo "== Events in namespace ${ENVIRONMENT} (last 100) =="
    kubectl -n "$ENVIRONMENT" get events --sort-by='.metadata.creationTimestamp' | tail -n 100 || true

    exit 1
  fi
done

echo "=== All deployments ready ==="
