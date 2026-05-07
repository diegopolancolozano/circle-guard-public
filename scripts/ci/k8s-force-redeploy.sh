#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

echo "=== Force redeploying ${ENVIRONMENT} namespace ==="

# Delete all application deployments (not infrastructure)
echo "Deleting application deployments..."
kubectl -n "$ENVIRONMENT" delete deployment \
  circleguard-identity-service \
  circleguard-auth-service \
  circleguard-promotion-service \
  circleguard-gateway-service \
  circleguard-form-service \
  circleguard-notification-service \
  --ignore-not-found --wait=false || true

# Wait a bit for termination to start
sleep 5

# Force delete any remaining pods
echo "Force deleting stuck pods..."
kubectl -n "$ENVIRONMENT" delete pods -l 'app in (circleguard-identity-service,circleguard-auth-service,circleguard-promotion-service,circleguard-gateway-service,circleguard-form-service,circleguard-notification-service)' \
  --grace-period=0 --force --ignore-not-found || true

# Wait for pods to be gone
echo "Waiting for pods to terminate..."
for i in {1..30}; do
  remaining=$(kubectl -n "$ENVIRONMENT" get pods -l 'app in (circleguard-identity-service,circleguard-auth-service,circleguard-promotion-service,circleguard-gateway-service,circleguard-form-service,circleguard-notification-service)' --no-headers 2>/dev/null | wc -l || echo "0")
  if [ "$remaining" -eq 0 ]; then
    echo "All pods terminated"
    break
  fi
  echo "Waiting for $remaining pods to terminate... (attempt $i/30)"
  sleep 2
done

echo "=== Ready for fresh deployment ==="
