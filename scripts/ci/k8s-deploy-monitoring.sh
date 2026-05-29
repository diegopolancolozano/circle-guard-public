#!/usr/bin/env bash
# Deploys the monitoring namespace (Prometheus + Grafana + Jaeger).
# Idempotent: safe to run on every pipeline execution.
set -euo pipefail

if [ -n "${KUBECONFIG:-}" ]; then
  export KUBECONFIG
fi

echo "[monitoring] Applying monitoring stack (k8s/monitoring/)..."
kubectl apply -k k8s/monitoring/

echo "[monitoring] Waiting for Prometheus rollout..."
kubectl -n monitoring rollout status deployment/prometheus --timeout=120s || true

echo "[monitoring] Waiting for Grafana rollout..."
kubectl -n monitoring rollout status deployment/grafana --timeout=120s || true

echo "[monitoring] Waiting for Jaeger rollout..."
kubectl -n monitoring rollout status deployment/jaeger --timeout=90s || true

echo "[monitoring] Stack ready."
echo ""
echo "  Port-forwards to access dashboards locally:"
echo "    kubectl -n monitoring port-forward svc/grafana 3000:3000    -> http://localhost:3000  (admin/circleguard)"
echo "    kubectl -n monitoring port-forward svc/prometheus 9090:9090 -> http://localhost:9090"
echo "    kubectl -n monitoring port-forward svc/jaeger 16686:16686   -> http://localhost:16686"
