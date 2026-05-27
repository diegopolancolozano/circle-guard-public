#!/usr/bin/env bash
# Opens port-forwards for the monitoring stack. Run this locally before a demo.
# Usage: scripts/ci/port-forward-monitoring.sh [kubeconfig-path]
set -euo pipefail

if [ -n "${1:-}" ]; then
  export KUBECONFIG="$1"
elif [ -n "${KUBECONFIG:-}" ]; then
  export KUBECONFIG
fi

cleanup() {
  echo ""
  echo "Stopping port-forwards..."
  kill 0
}
trap cleanup INT TERM

echo "Starting port-forwards for monitoring stack..."
echo "  Grafana  -> http://localhost:3000  (admin / circleguard)"
echo "  Prometheus -> http://localhost:9090"
echo "  Jaeger   -> http://localhost:16686"
echo ""
echo "Press Ctrl+C to stop."
echo ""

kubectl -n monitoring port-forward svc/grafana    3000:3000 &
kubectl -n monitoring port-forward svc/prometheus 9090:9090 &
kubectl -n monitoring port-forward svc/jaeger    16686:16686 &

wait
