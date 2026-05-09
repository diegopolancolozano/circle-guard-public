#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

# Option A: delete namespace (removes all resources)
# Usage: scripts/ci/k8s-teardown.sh dev --delete-namespace

if [[ "${2:-}" == "--delete-namespace" ]]; then
  echo "Deleting namespace ${ENVIRONMENT} (this will remove all resources)"
  kubectl delete namespace "${ENVIRONMENT}" || true
  exit 0
fi

# Option B: scale down deployments to 0 replicas (keeps namespace/configs)
SERVICES=(
  circleguard-auth-service
  circleguard-identity-service
  circleguard-promotion-service
  circleguard-gateway-service
  circleguard-form-service
  circleguard-notification-service
  postgres
  redis
  neo4j
  zookeeper
  kafka
  openldap
)

for svc in "${SERVICES[@]}"; do
  echo "Scaling ${svc} to 0 replicas in ${ENVIRONMENT}"
  kubectl -n "${ENVIRONMENT}" scale deployment "${svc}" --replicas=0 || true
done

echo "All specified deployments scaled to 0 in ${ENVIRONMENT}. To fully delete resources, run with --delete-namespace."
