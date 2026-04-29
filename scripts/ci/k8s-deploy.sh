#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?environment required}"

kubectl apply -f k8s/namespaces.yaml
kubectl apply -k "k8s/overlays/${ENVIRONMENT}"

scripts/ci/k8s-wait-ready.sh "$ENVIRONMENT"
