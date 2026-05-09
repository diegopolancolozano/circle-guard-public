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
  # dump recent port-forward log if available
  if [ -f "/tmp/portforward-$(echo ${local_url} | sed -E 's@https?://127.0.0.1:@@') .log" ]; then
    echo "--- recent port-forward log ---" >&2
    tail -n 200 "/tmp/portforward-$(echo ${local_url} | sed -E 's@https?://127.0.0.1:@@') .log" >&2 || true
    echo "--- end port-forward log ---" >&2
  fi
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

export IDENTITY_BASE_URL="$(svc_url circleguard-identity-service 18180)"
export GATEWAY_BASE_URL="$(svc_url circleguard-gateway-service 18181)"
export QR_SECRET="$(kubectl -n "$ENVIRONMENT" get secret qr-secret -o jsonpath='{.data.qr_secret}' | base64 --decode)"

USERS="${USERS:-50}"
SPAWN_RATE="${SPAWN_RATE:-5}"
RUN_TIME="${RUN_TIME:-1m}"

echo "LOCUST_DIR=${LOCUST_DIR}"
echo "Listing LOCUST_DIR contents:"
ls -la "${LOCUST_DIR}" || true

# Try running with docker-mounted locustfile; if it fails because the host cannot see the Jenkins workspace, fall back to running inside k8s
echo "Testing docker mount visibility for ${LOCUST_DIR}"
if docker run --rm -v "${LOCUST_DIR}:/mnt/performance" busybox ls /mnt/performance/locustfile.py >/dev/null 2>&1; then
  echo "Docker mount test succeeded: running Locust via docker run with mounted locustfile"
  echo "Running: docker run -e IDENTITY_BASE_URL=... -v ${LOCUST_DIR}:/mnt/performance locustio/locust:2.24.1 -f /mnt/performance/locustfile.py ..."
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
    --host "$GATEWAY_BASE_URL"
else
  echo "Docker mount test failed — showing ${LOCUST_DIR} listing from host and continuing to k8s fallback"
  ls -la "${LOCUST_DIR}" || true
  echo "Running Locust as a Kubernetes Pod inside namespace ${ENVIRONMENT}"
  # For in-cluster run, use cluster DNS names for services
  IDENTITY_BASE_URL="http://circleguard-identity-service:8080"
  GATEWAY_BASE_URL="http://circleguard-gateway-service:8080"
  run_locust_in_k8s
fi

run_locust_in_k8s() {
  local id="locust-$(date +%s)"
  local cm_name="${id}-cm"
  echo "Creating ConfigMap ${cm_name} in namespace ${ENVIRONMENT}"
  kubectl -n "$ENVIRONMENT" create configmap "$cm_name" --from-file=locustfile.py="${LOCUST_DIR}/locustfile.py" --dry-run=client -o yaml | kubectl apply -f -

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
          locust -f /mnt/performance/locustfile.py --headless --users ${USERS} --spawn-rate ${SPAWN_RATE} --run-time ${RUN_TIME} --host ${GATEWAY_BASE_URL}
      volumeMounts:
        - name: locustfile
          mountPath: /mnt/performance
  volumes:
    - name: locustfile
      configMap:
        name: ${cm_name}
EOF

  echo "Waiting for locust pod ${id} to start..."
  kubectl -n "$ENVIRONMENT" wait --for=condition=Ready pod/${id} --timeout=60s || true
  echo "Streaming logs from pod ${id} (CTRL+C to stop)..."
  kubectl -n "$ENVIRONMENT" logs -f pod/${id} || true
  echo "Waiting for pod ${id} to finish..."
  kubectl -n "$ENVIRONMENT" wait --for=condition=Succeeded pod/${id} --timeout=600s || true
  echo "Cleaning up pod and configmap ${id}, ${cm_name}"
  kubectl -n "$ENVIRONMENT" delete pod/${id} --ignore-not-found
  kubectl -n "$ENVIRONMENT" delete configmap/${cm_name} --ignore-not-found
}

# Try running with docker-mounted locustfile; if it fails because the host cannot see the Jenkins workspace, fall back to running inside k8s
if docker run --rm -v "${LOCUST_DIR}:/mnt/performance" busybox ls /mnt/performance/locustfile.py >/dev/null 2>&1; then
  echo "Running Locust via docker run with mounted locustfile"
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
    --host "$GATEWAY_BASE_URL"
else
  echo "Docker mount test failed — running Locust as a Kubernetes Pod inside namespace ${ENVIRONMENT}"
  # For in-cluster run, use cluster DNS names for services
  IDENTITY_BASE_URL="http://circleguard-identity-service:8080"
  GATEWAY_BASE_URL="http://circleguard-gateway-service:8080"
  run_locust_in_k8s
fi
