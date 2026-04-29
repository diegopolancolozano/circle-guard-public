#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

function svc_url() {
  minikube service "$1" -n "$ENVIRONMENT" --url | head -n 1
}

export IDENTITY_BASE_URL="$(svc_url circleguard-identity-service)"
export GATEWAY_BASE_URL="$(svc_url circleguard-gateway-service)"
export QR_SECRET="$(kubectl -n "$ENVIRONMENT" get secret qr-secret -o jsonpath='{.data.qr_secret}' | base64 --decode)"

USERS="${USERS:-50}"
SPAWN_RATE="${SPAWN_RATE:-5}"
RUN_TIME="${RUN_TIME:-1m}"

docker run --rm \
  -e IDENTITY_BASE_URL="$IDENTITY_BASE_URL" \
  -e GATEWAY_BASE_URL="$GATEWAY_BASE_URL" \
  -e QR_SECRET="$QR_SECRET" \
  -v "$PWD/tests/performance:/mnt/performance" \
  locustio/locust:2.24.1 \
  -f /mnt/performance/locustfile.py \
  --headless \
  --users "$USERS" \
  --spawn-rate "$SPAWN_RATE" \
  --run-time "$RUN_TIME" \
  --host "$GATEWAY_BASE_URL"
