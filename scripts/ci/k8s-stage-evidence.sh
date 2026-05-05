#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
OUTPUT_FILE="${2:-stage-evidence.txt}"

{
  echo "=== Stage Evidence ==="
  echo "Environment: ${ENVIRONMENT}"
  echo
  echo "--- Deployments ---"
  kubectl -n "$ENVIRONMENT" get deployments
  echo
  echo "--- Pods ---"
  kubectl -n "$ENVIRONMENT" get pods -o wide
  echo
  echo "--- Services ---"
  kubectl -n "$ENVIRONMENT" get svc
  echo
  echo "--- Rollout Status ---"
  for deploy in \
    postgres redis neo4j zookeeper kafka openldap \
    circleguard-auth-service circleguard-identity-service circleguard-promotion-service \
    circleguard-gateway-service circleguard-dashboard-service circleguard-file-service; do
    echo "deployment/${deploy}"
    kubectl -n "$ENVIRONMENT" rollout status "deployment/${deploy}" --timeout=180s
    echo
  done
} > "$OUTPUT_FILE"

echo "Stage evidence written to ${OUTPUT_FILE}"
