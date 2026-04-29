#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

function svc_url() {
  minikube service "$1" -n "$ENVIRONMENT" --url | head -n 1
}

export IDENTITY_BASE_URL="$(svc_url circleguard-identity-service)"
export PROMOTION_BASE_URL="$(svc_url circleguard-promotion-service)"
export GATEWAY_BASE_URL="$(svc_url circleguard-gateway-service)"
export FILE_BASE_URL="$(svc_url circleguard-file-service)"
export DASHBOARD_BASE_URL="$(svc_url circleguard-dashboard-service)"

export QR_SECRET="$(kubectl -n "$ENVIRONMENT" get secret qr-secret -o jsonpath='{.data.qr_secret}' | base64 --decode)"

./gradlew :tests:circleguard-e2e-tests:test
