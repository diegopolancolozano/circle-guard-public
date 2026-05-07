#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
FORCE_REDEPLOY="${FORCE_REDEPLOY:-false}"

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
CURRENT_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"

echo "Using kube context: ${CURRENT_CONTEXT}"
echo "Using kube server: ${CURRENT_SERVER}"

if [[ "${CURRENT_CONTEXT}" == *"minikube"* ]] || [[ "${CURRENT_SERVER}" == *"192.168.49.2"* ]]; then
  echo "ERROR: kubeconfig points to minikube. Update Jenkins credential 'kubeconfig-credentials' to the GKE kubeconfig."
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
