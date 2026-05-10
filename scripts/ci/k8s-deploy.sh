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

kubectl apply -k "k8s/overlays/${ENVIRONMENT}" --validate=false

scripts/ci/k8s-wait-ready.sh "$ENVIRONMENT"
