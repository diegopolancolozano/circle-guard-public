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

# Determine repository root and locust directory in a way that works inside Jenkins
if [ -n "${WORKSPACE:-}" ]; then
  LOCUST_DIR="${WORKSPACE}/tests/performance"
elif [ -d "${PWD}/tests/performance" ]; then
  LOCUST_DIR="${PWD}/tests/performance"
else
  # fallback: script location (when executed directly)
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  LOCUST_DIR="${REPO_ROOT}/tests/performance"
fi

PORT_FORWARD_PIDS=()
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

cleanup() {
  for pid in "${PORT_FORWARD_PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

wait_for_health() {
  local local_url="$1"
  for attempt in $(seq 1 30); do
    if curl -fsS "$local_url/actuator/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: port-forward at ${local_url} did not become ready" >&2
  return 1
}

svc_url() {
  local service_name="$1"
  local local_port="$2"
  local remote_port="${3:-$2}"

  kubectl -n "$ENVIRONMENT" port-forward "svc/${service_name}" "${local_port}:${remote_port}" --address 127.0.0.1 >/tmp/${service_name}-${local_port}.log 2>&1 &
  PORT_FORWARD_PIDS+=("$!")
  wait_for_health "http://127.0.0.1:${local_port}"
  echo "http://127.0.0.1:${local_port}"
}

run_locust_in_k8s() {
  local id="locust-$(date +%s)"
  local cm_name="${id}-cm"
  local result_log="${RESULTS_DIR}/locust-${ENVIRONMENT}-${TIMESTAMP}.log"
  echo "[K8S Locust] Creating ConfigMap ${cm_name} in namespace ${ENVIRONMENT}"
  kubectl -n "$ENVIRONMENT" create configmap "$cm_name" --from-file=locustfile.py="${LOCUST_DIR}/locustfile.py" --dry-run=client -o yaml | kubectl apply -f -
  echo "[K8S Locust] ConfigMap created"

  echo "[K8S Locust] Creating Pod ${id}"
  cat <<EOF | kubectl -n "$ENVIRONMENT" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${id}
spec:
  restartPolicy: Never
  containers:
    - name: locust
      image: locustio/locust:2.24.1
      env:
        - name: IDENTITY_BASE_URL
          value: "${IDENTITY_BASE_URL}"
        - name: GATEWAY_BASE_URL
          value: "${GATEWAY_BASE_URL}"
        - name: QR_SECRET
          value: "${QR_SECRET}"
        - name: USERS
          value: "${USERS}"
        - name: SPAWN_RATE
          value: "${SPAWN_RATE}"
        - name: RUN_TIME
          value: "${RUN_TIME}"
      command: ["/bin/sh", "-c"]
      args:
        - |
          locust -f /mnt/performance/locustfile.py --headless --users \${USERS} --spawn-rate \${SPAWN_RATE} --run-time \${RUN_TIME} --host \${GATEWAY_BASE_URL}
      volumeMounts:
        - name: locustfile
          mountPath: /mnt/performance
  volumes:
    - name: locustfile
      configMap:
        name: ${cm_name}
EOF

  echo "[K8S Locust] Pod created, waiting to start..."
  kubectl -n "$ENVIRONMENT" wait --for=condition=Ready pod/${id} --timeout=60s || echo "[K8S Locust] Pod start timeout"
  echo "[K8S Locust] Streaming logs..."
  kubectl -n "$ENVIRONMENT" logs -f pod/${id} | tee "$result_log" || true
  echo "[K8S Locust] Waiting for completion..."
  kubectl -n "$ENVIRONMENT" wait --for=condition=Succeeded pod/${id} --timeout=600s || echo "[K8S Locust] Pod completion timeout"
  echo "[K8S Locust] Cleaning up..."
  kubectl -n "$ENVIRONMENT" delete pod/${id} --ignore-not-found
  kubectl -n "$ENVIRONMENT" delete configmap/${cm_name} --ignore-not-found
  echo "[K8S Locust] Cleanup complete"
}

# === Main execution ===

export IDENTITY_BASE_URL="$(svc_url circleguard-identity-service 18180)"
export GATEWAY_BASE_URL="$(svc_url circleguard-gateway-service 18181)"
export QR_SECRET="$(kubectl -n "$ENVIRONMENT" get secret qr-secret -o jsonpath='{.data.qr_secret}' | base64 --decode)"

USERS="${USERS:-15}"
SPAWN_RATE="${SPAWN_RATE:-2}"
RUN_TIME="${RUN_TIME:-30s}"

RESULTS_DIR="${LOCUST_DIR}/results"
mkdir -p "$RESULTS_DIR"
RESULT_LOG="${RESULTS_DIR}/locust-${ENVIRONMENT}-${TIMESTAMP}.log"

echo "[Locust] LOCUST_DIR=${LOCUST_DIR}"
echo "[Locust] RESULTS_DIR=${RESULTS_DIR}"
echo "[Locust] USERS=${USERS} SPAWN_RATE=${SPAWN_RATE} RUN_TIME=${RUN_TIME}"
echo "[Locust] Listing LOCUST_DIR:"
ls -la "${LOCUST_DIR}" || true

echo "[Locust] Testing docker mount for ${LOCUST_DIR}"
if docker run --rm -v "${LOCUST_DIR}:/mnt/performance" busybox ls /mnt/performance/locustfile.py >/dev/null 2>&1; then
  echo "[Locust] Docker mount succeeded - running via docker run"
  docker run --rm \
    -e IDENTITY_BASE_URL="$IDENTITY_BASE_URL" \
    -e GATEWAY_BASE_URL="$GATEWAY_BASE_URL" \
    -e QR_SECRET="$QR_SECRET" \
    -v "${LOCUST_DIR}:/mnt/performance" \
    locustio/locust:2.24.1 \
    -f /mnt/performance/locustfile.py \
    --headless \
    --users "$USERS" \
    --spawn-rate "$SPAWN_RATE" \
    --run-time "$RUN_TIME" \
    --host "$GATEWAY_BASE_URL" | tee "$RESULT_LOG"
else
  echo "[Locust] Docker mount test failed - using K8s fallback"
  IDENTITY_BASE_URL="http://circleguard-identity-service:8080"
  GATEWAY_BASE_URL="http://circleguard-gateway-service:8080"
  run_locust_in_k8s
fi

echo "[Locust] Run log saved to ${RESULT_LOG}"
