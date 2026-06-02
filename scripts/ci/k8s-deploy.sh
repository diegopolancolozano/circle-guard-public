#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
FORCE_REDEPLOY="${FORCE_REDEPLOY:-false}"

export KUBECONFIG="${KUBECONFIG:-/var/jenkins_home/.kube/config}"

echo "Using kube context: $(kubectl config current-context 2>/dev/null || true)"
echo "Using kube server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"

K8S_READY=false
for attempt in $(seq 1 12); do
  if kubectl version --request-timeout=10s >/dev/null 2>&1; then
    K8S_READY=true
    break
  fi
  echo "Kubernetes API not ready (attempt ${attempt}/12). Retrying in 5s..."
  sleep 5
done

if [ "$K8S_READY" != "true" ]; then
  echo "ERROR: Kubernetes is not reachable from this machine/container."
  echo "ERROR: Start Docker Desktop Kubernetes or fix the kube context before deploying ${ENVIRONMENT}."
  exit 1
fi

kubectl apply -f k8s/namespaces.yaml --validate=false

# Scale down heavy infra immediately to free RAM before anything else
echo "=== Scaling down heavy infra (neo4j, openldap) to free RAM ==="
kubectl -n "$ENVIRONMENT" scale deployment neo4j openldap --replicas=0 --ignore-not-found 2>/dev/null || true

# Delete any Pending infra pods — stale pods from previous runs with old resource
# requests block scheduling even after kubectl apply updates the Deployment spec.
echo "=== Deleting Pending infra pods so new resource limits apply cleanly ==="
for infra_dep in kafka zookeeper postgres redis; do
  kubectl -n "$ENVIRONMENT" delete pods \
    -l "app=${infra_dep}" \
    --field-selector=status.phase==Pending \
    --ignore-not-found 2>/dev/null || true
done

# Force redeploy if requested
if [ "$FORCE_REDEPLOY" = "true" ]; then
  echo "=== FORCE_REDEPLOY=true, cleaning up existing deployments ==="
  scripts/ci/k8s-force-redeploy.sh "$ENVIRONMENT"
fi

# Clean up failed/unknown pods
echo "=== Cleaning up failed pods in ${ENVIRONMENT} ==="
kubectl -n "$ENVIRONMENT" delete pods --field-selector=status.phase==Failed --ignore-not-found || true
kubectl -n "$ENVIRONMENT" delete pods --field-selector=status.phase==Unknown --ignore-not-found || true

# Delete pods in Error state (stale from previous runs)
kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null \
  | awk '$3 == "Error" || $3 == "CrashLoopBackOff" || $3 == "OOMKilled" {print $1}' \
  | xargs -r kubectl -n "$ENVIRONMENT" delete pod --grace-period=0 --force --ignore-not-found 2>/dev/null || true

# Delete pods with excessive restarts (more than 10)
for pod in $(kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null | awk '$4 > 10 {print $1}' || true); do
  if [ -n "$pod" ]; then
    echo "Deleting pod with excessive restarts: $pod"
    kubectl -n "$ENVIRONMENT" delete pod "$pod" --grace-period=0 --force --ignore-not-found || true
  fi
done

kubectl apply -k "k8s/overlays/${ENVIRONMENT}" --validate=false

# Restart infra deployments ONLY if their pod is stuck in Pending.
# Running infra pods are NOT restarted — RollingUpdate would try to schedule
# a second pod before terminating the first, which fails on memory-constrained clusters.
echo "=== Restarting infra deployments stuck in Pending ==="
for infra_dep in kafka zookeeper postgres redis; do
  pending=$(kubectl -n "$ENVIRONMENT" get pods -l "app=${infra_dep}" \
    --field-selector=status.phase==Pending --no-headers 2>/dev/null | wc -l || echo 0)
  running=$(kubectl -n "$ENVIRONMENT" get pods -l "app=${infra_dep}" \
    --field-selector=status.phase==Running --no-headers 2>/dev/null | wc -l || echo 0)
  if [ "$pending" -gt 0 ] && [ "$running" -eq 0 ]; then
    echo "  ${infra_dep}: stuck in Pending, forcing restart"
    kubectl -n "$ENVIRONMENT" rollout restart "deployment/${infra_dep}" 2>/dev/null || true
  else
    echo "  ${infra_dep}: skipping restart (running=${running}, pending=${pending})"
  fi
done

# Force-restart app services so pods pick up any Secret/ConfigMap changes.
# kubectl apply only updates the Secret object; running pods keep the old env
# vars until they restart. imagePullPolicy:Always also only pulls on pod start.
echo "=== Restarting app services to pick up config changes ==="
for svc in \
  circleguard-auth-service \
  circleguard-identity-service \
  circleguard-promotion-service \
  circleguard-gateway-service \
  circleguard-dashboard-service \
  circleguard-file-service; do
  kubectl -n "$ENVIRONMENT" rollout restart "deployment/${svc}" 2>/dev/null || true
done

scripts/ci/k8s-wait-ready.sh "$ENVIRONMENT"
