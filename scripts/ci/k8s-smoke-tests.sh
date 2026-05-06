#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-300s}"
SMOKE_RETRIES="${SMOKE_RETRIES:-20}"
SMOKE_RETRY_SLEEP="${SMOKE_RETRY_SLEEP:-5}"

POD_NAME="smoke-curl"
IMAGE="curlimages/curl:8.5.0"

cleanup() {
  kubectl -n "$ENVIRONMENT" delete pod "$POD_NAME" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

print_diagnostics() {
  local deploy="$1"
  echo "== Diagnostics for ${deploy} in ${ENVIRONMENT} =="
  kubectl -n "$ENVIRONMENT" get pods -o wide || true
  kubectl -n "$ENVIRONMENT" get events --sort-by='.metadata.creationTimestamp' | tail -n 200 || true

  local pod_names
  pod_names=$(kubectl -n "$ENVIRONMENT" get pods --no-headers 2>/dev/null | awk -v d="$deploy" '$1 ~ d {print $1}' || true)
  if [[ -n "${pod_names}" ]]; then
    for p in ${pod_names}; do
      echo "-- Describe pod ${p} --"
      kubectl -n "$ENVIRONMENT" describe pod "$p" || true
      echo "-- Logs for pod ${p} --"
      kubectl -n "$ENVIRONMENT" logs "$p" --tail=200 || true
    done
  fi
}

wait_deployment_available() {
  local deploy="$1"
  echo "Waiting for deployment ${deploy} to be available in ${ENVIRONMENT} (timeout=${SMOKE_TIMEOUT})"
  if ! kubectl -n "$ENVIRONMENT" wait --for=condition=Available "deployment/${deploy}" --timeout="${SMOKE_TIMEOUT}"; then
    echo "ERROR: deployment ${deploy} is not Available"
    print_diagnostics "$deploy"
    exit 1
  fi
}

curl_json_code() {
  local url="$1"
  local data="$2"
  kubectl -n "$ENVIRONMENT" exec "$POD_NAME" -- sh -c "curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d '${data}' '${url}'"
}

assert_http_200_with_retry() {
  local name="$1"
  local url="$2"
  local payload="$3"
  local deploy="$4"

  local attempt
  local code
  code="000"

  for attempt in $(seq 1 "$SMOKE_RETRIES"); do
    if code=$(curl_json_code "$url" "$payload" 2>/dev/null); then
      if [[ "$code" == "200" ]]; then
        echo "${name}: HTTP 200"
        return 0
      fi
    fi
    echo "${name}: attempt ${attempt}/${SMOKE_RETRIES} failed (code=${code}), retrying in ${SMOKE_RETRY_SLEEP}s"
    sleep "$SMOKE_RETRY_SLEEP"
  done

  echo "ERROR: ${name} did not return HTTP 200 after ${SMOKE_RETRIES} attempts"
  print_diagnostics "$deploy"
  exit 1
}

kubectl -n "$ENVIRONMENT" delete pod "$POD_NAME" --ignore-not-found
kubectl -n "$ENVIRONMENT" run "$POD_NAME" --image="$IMAGE" --restart=Never --command -- sleep 300
kubectl -n "$ENVIRONMENT" wait --for=condition=Ready "pod/${POD_NAME}" --timeout=60s

wait_deployment_available "circleguard-identity-service"
wait_deployment_available "circleguard-promotion-service"
wait_deployment_available "circleguard-gateway-service"
wait_deployment_available "circleguard-form-service"

assert_http_200_with_retry \
  "identity" \
  "http://circleguard-identity-service:8080/api/v1/identities/map" \
  '{"realIdentity":"smoke@circleguard.edu"}' \
  "circleguard-identity-service"

assert_http_200_with_retry \
  "promotion" \
  "http://circleguard-promotion-service:8081/api/v1/health/report" \
  '{"anonymousId":"smoke-user","status":"CLEAR"}' \
  "circleguard-promotion-service"

assert_http_200_with_retry \
  "gateway" \
  "http://circleguard-gateway-service:8080/api/v1/gate/validate" \
  '{"token":"invalid"}' \
  "circleguard-gateway-service"

assert_http_200_with_retry \
  "form" \
  "http://circleguard-form-service:8080/api/v1/surveys" \
  '{"anonymousId":"550e8400-e29b-41d4-a716-446655440000","symptoms":["COUGH","FEVER"]}' \
  "circleguard-form-service"

echo "Smoke tests passed"