#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

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

kubectl apply -k "k8s/overlays/${ENVIRONMENT}"

scripts/ci/k8s-wait-ready.sh "$ENVIRONMENT"
