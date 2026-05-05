#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
# default timeout per deployment (can override with DEPLOY_TIMEOUT env var)
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-600s}"

DEPLOYMENTS=(
  "postgres"
  "redis"
  "neo4j"
  "zookeeper"
  "kafka"
  "openldap"
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-promotion-service"
  "circleguard-gateway-service"
  "circleguard-form-service"
  "circleguard-notification-service"
)

for deploy in "${DEPLOYMENTS[@]}"; do
  echo "Waiting for deployment ${deploy} in ${ENVIRONMENT} (timeout=${DEPLOY_TIMEOUT})"
  if ! kubectl -n "$ENVIRONMENT" rollout status "deployment/${deploy}" --timeout="${DEPLOY_TIMEOUT}"; then
    echo "ERROR: rollout failed or timed out for deployment ${deploy} in ${ENVIRONMENT}"
    echo "Gathering diagnostics for ${deploy}..."

    echo "== Pods (all) in namespace ${ENVIRONMENT} =="
    kubectl -n "$ENVIRONMENT" get pods -o wide || true

    echo "== Pods matching '${deploy}' =="
    pod_names=$(kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null | awk '/'"${deploy}"'/ {print $1}' || true)
    if [ -n "${pod_names}" ]; then
      for p in ${pod_names}; do
        echo "-- Logs for pod ${p} --"
        kubectl -n "$ENVIRONMENT" logs "${p}" --tail=200 || true
        echo "-- Describe pod ${p} --"
        kubectl -n "$ENVIRONMENT" describe pod "${p}" || true
      done
    else
      echo "No pods found matching ${deploy}"
    fi

    echo "== Events in namespace ${ENVIRONMENT} (last 200) =="
    kubectl -n "$ENVIRONMENT" get events --sort-by='.metadata.creationTimestamp' | tail -n 200 || true

    exit 1
  fi

done
