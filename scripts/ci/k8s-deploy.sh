#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
FORCE_REDEPLOY="${FORCE_REDEPLOY:-false}"

kubectl apply -f k8s/namespaces.yaml

# Create app-config secret with database connection strings
kubectl create secret generic app-config \
  --namespace="$ENVIRONMENT" \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:postgresql://postgres:5432/circleguard" \
  --from-literal=SPRING_DATASOURCE_USERNAME="admin" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="password" \
  --from-literal=SPRING_NEO4J_URI="bolt://neo4j:7687" \
  --from-literal=SPRING_NEO4J_AUTHENTICATION_USERNAME="neo4j" \
  --from-literal=SPRING_NEO4J_AUTHENTICATION_PASSWORD="password" \
  --from-literal=SPRING_DATA_REDIS_HOST="redis" \
  --from-literal=SPRING_DATA_REDIS_PORT="6379" \
  --from-literal=SPRING_KAFKA_BOOTSTRAP_SERVERS="kafka:9092" \
  --from-literal=LDAP_URL="ldap://openldap:389" \
  --from-literal=LDAP_BASE="dc=circleguard,dc=edu" \
  --from-literal=LDAP_USER_DN="cn=admin,dc=circleguard,dc=edu" \
  --from-literal=LDAP_PASSWORD="admin" \
  --dry-run=client -o yaml | kubectl apply -f -

# Force redeploy if requested
if [ "$FORCE_REDEPLOY" = "true" ]; then
  echo "=== FORCE_REDEPLOY=true, cleaning up existing deployments ==="
  scripts/ci/k8s-force-redeploy.sh "$ENVIRONMENT"
fi

# Clean up failed/unknown pods
echo "=== Cleaning up failed pods in ${ENVIRONMENT} ==="
kubectl -n "$ENVIRONMENT" delete pods --field-selector=status.phase==Failed --ignore-not-found || true
kubectl -n "$ENVIRONMENT" delete pods --field-selector=status.phase==Unknown --ignore-not-found || true

# Delete pods with excessive restarts (more than 10)
for pod in $(kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null | awk '$4 > 10 {print $1}' || true); do
  if [ -n "$pod" ]; then
    echo "Deleting pod with excessive restarts: $pod"
    kubectl -n "$ENVIRONMENT" delete pod "$pod" --grace-period=0 --force --ignore-not-found || true
  fi
done

kubectl apply -k "k8s/overlays/${ENVIRONMENT}"

scripts/ci/k8s-wait-ready.sh "$ENVIRONMENT"
