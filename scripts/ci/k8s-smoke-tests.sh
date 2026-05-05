#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

POD_NAME="smoke-curl"
IMAGE="curlimages/curl:8.5.0"

kubectl -n "$ENVIRONMENT" delete pod "$POD_NAME" --ignore-not-found
kubectl -n "$ENVIRONMENT" run "$POD_NAME" --image="$IMAGE" --restart=Never --command -- sleep 300
kubectl -n "$ENVIRONMENT" wait --for=condition=Ready "pod/${POD_NAME}" --timeout=60s

function curl_json() {
  local url="$1"
  local data="$2"

  kubectl -n "$ENVIRONMENT" exec "$POD_NAME" -- sh -c "curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d '${data}' '${url}'"
}

function curl_get() {
  local url="$1"
  kubectl -n "$ENVIRONMENT" exec "$POD_NAME" -- sh -c "curl -sS -o /dev/null -w '%{http_code}' '${url}'"
}

IDENTITY_CODE=$(curl_json "http://circleguard-identity-service:8080/api/v1/identities/map" '{"realIdentity":"smoke@circleguard.edu"}')
PROMOTION_CODE=$(curl_json "http://circleguard-promotion-service:8081/api/v1/health/report" '{"anonymousId":"smoke-user","status":"CLEAR"}')
GATEWAY_CODE=$(curl_json "http://circleguard-gateway-service:8080/api/v1/gate/validate" '{"token":"invalid"}')
FORM_CODE=$(curl_json "http://circleguard-form-service:8080/api/v1/surveys" '{"anonymousId":"550e8400-e29b-41d4-a716-446655440000","symptoms":["COUGH","FEVER"]}')

kubectl -n "$ENVIRONMENT" delete pod "$POD_NAME" --ignore-not-found

if [[ "$IDENTITY_CODE" != "200" || "$PROMOTION_CODE" != "200" || "$GATEWAY_CODE" != "200" || "$FORM_CODE" != "200" ]]; then
  echo "Smoke tests failed: identity=${IDENTITY_CODE}, promotion=${PROMOTION_CODE}, gateway=${GATEWAY_CODE}, form=${FORM_CODE}"
  exit 1
fi

echo "Smoke tests passed"
