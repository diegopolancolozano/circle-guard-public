#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

if [ -n "${KUBECONFIG:-}" ]; then
  export KUBECONFIG
elif [ -f /var/jenkins_home/.kube/config ]; then
  export KUBECONFIG="/var/jenkins_home/.kube/config"
else
  export KUBECONFIG="${HOME}/.kube/config"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESULTS_DIR="${WORKSPACE:-${PWD}}/tests/security/results"
mkdir -p "${RESULTS_DIR}"

TARGET_URL="http://circleguard-gateway-service:8080"
ZAP_POD="zap-${TIMESTAMP}"

cleanup() {
  kubectl -n "${ENVIRONMENT}" delete pod "${ZAP_POD}" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for gateway to be available before scanning
echo "[zap] Waiting for gateway deployment..." >&2
kubectl -n "${ENVIRONMENT}" wait --for=condition=Available \
  "deployment/circleguard-gateway-service" --timeout=180s

# Run ZAP as an in-cluster pod so it can reach services via cluster DNS.
# Docker-outside-of-Docker makes --network=host unreliable for port-forwards:
# the port-forward lives in the Jenkins container network, but docker run
# --network=host binds to the HOST network — two different namespaces.
echo "[zap] Running baseline scan in-cluster against ${TARGET_URL}" >&2
kubectl -n "${ENVIRONMENT}" run "${ZAP_POD}" \
  --image=ghcr.io/zaproxy/zaproxy:stable \
  --restart=Never \
  --command -- zap-baseline.py \
    -t "${TARGET_URL}" \
    -I

# Wait up to 10 minutes for scan to finish
kubectl -n "${ENVIRONMENT}" wait --for=condition=Ready \
  "pod/${ZAP_POD}" --timeout=120s 2>/dev/null || true

kubectl -n "${ENVIRONMENT}" wait "pod/${ZAP_POD}" \
  --for=jsonpath='{.status.phase}'=Succeeded --timeout=600s 2>/dev/null || \
  kubectl -n "${ENVIRONMENT}" wait "pod/${ZAP_POD}" \
    --for=jsonpath='{.status.phase}'=Failed --timeout=30s 2>/dev/null || \
  echo "[zap] Timeout waiting for pod completion" >&2

# Capture logs as the scan report artifact
LOG_FILE="${RESULTS_DIR}/zap-${ENVIRONMENT}-${TIMESTAMP}.txt"
kubectl -n "${ENVIRONMENT}" logs "${ZAP_POD}" 2>/dev/null | tee "${LOG_FILE}" || true

echo "[zap] Report saved to ${LOG_FILE}" >&2
