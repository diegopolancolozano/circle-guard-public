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

SERVICE_NAME="circleguard-gateway-service"
LOCAL_PORT=18083
REMOTE_PORT=8080
LOCAL_URL="http://127.0.0.1:${LOCAL_PORT}"
PF_LOG="/tmp/zap-pf-${LOCAL_PORT}.log"

cleanup() {
  pkill -f "port-forward.*${LOCAL_PORT}:" >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_health() {
  local max_attempts=45
  local sleep_secs=2
  local attempt

  for attempt in $(seq 1 "$max_attempts"); do
    if curl -fsS "${LOCAL_URL}/actuator/health" >/dev/null 2>&1; then
      echo "[zap] ${LOCAL_URL} UP (attempt ${attempt})" >&2
      return 0
    fi
    sleep "$sleep_secs"
  done

  echo "ERROR: port-forward at ${LOCAL_URL} did not become ready" >&2
  if [ -f "${PF_LOG}" ]; then
    echo "=== Port-forward log ===" >&2
    cat "${PF_LOG}" >&2 || true
  fi
  return 1
}

# Kill any stale port-forward on this port
pkill -f "port-forward.*${LOCAL_PORT}:" >/dev/null 2>&1 || true
sleep 2

echo "[zap] Starting port-forward: ${SERVICE_NAME} -> ${LOCAL_URL}" >&2
kubectl -n "${ENVIRONMENT}" port-forward "svc/${SERVICE_NAME}" "${LOCAL_PORT}:${REMOTE_PORT}" --address 127.0.0.1 >"${PF_LOG}" 2>&1 &

wait_for_health

REPORT_HTML="zap-${ENVIRONMENT}-${TIMESTAMP}.html"
REPORT_JSON="zap-${ENVIRONMENT}-${TIMESTAMP}.json"
REPORT_MD="zap-${ENVIRONMENT}-${TIMESTAMP}.md"

echo "[zap] Running baseline scan against ${LOCAL_URL}" >&2

docker run --rm \
  --network=host \
  -v "${RESULTS_DIR}:/zap/wrk:rw" \
  owasp/zap2docker-stable \
  zap-baseline.py -t "${LOCAL_URL}" -r "${REPORT_HTML}" -J "${REPORT_JSON}" -w "${REPORT_MD}" -I

echo "[zap] Reports saved in ${RESULTS_DIR}"