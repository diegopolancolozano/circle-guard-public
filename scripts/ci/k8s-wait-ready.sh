#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

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
  "circleguard-dashboard-service"
  "circleguard-file-service"
)

for deploy in "${DEPLOYMENTS[@]}"; do
  echo "Waiting for deployment ${deploy} in ${ENVIRONMENT}"
  kubectl -n "$ENVIRONMENT" rollout status "deployment/${deploy}" --timeout=180s

done
