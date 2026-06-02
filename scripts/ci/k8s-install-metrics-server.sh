#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Installing metrics-server for HPA..."

# Check if metrics-server is already installed
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "✓ metrics-server already installed, checking status..."
else
  echo "Applying metrics-server manifest..."
  kubectl apply -f "$PROJECT_ROOT/k8s/base/metrics-server.yaml"
  echo "✓ metrics-server manifest applied"
fi

# Wait for metrics-server pods to be ready
echo "Waiting for metrics-server pods to be ready (up to 120s)..."
for i in {1..60}; do
  if kubectl get pods -n kube-system -l k8s-app=metrics-server --field-selector=status.phase=Running 2>/dev/null | grep -q metrics-server; then
    echo "✓ metrics-server pod is running"
    break
  fi
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Still waiting... ($((i*2))s elapsed)"
  fi
  sleep 2
done

# Wait for deployment to be fully ready
echo "Waiting for metrics-server deployment readiness..."
kubectl wait --for=condition=available --timeout=120s deployment/metrics-server -n kube-system 2>/dev/null || {
  echo "⚠ Deployment wait timed out, continuing anyway..."
}

# Give it extra time for metrics collection to begin
echo "Waiting for metrics collection to initialize..."
sleep 15

# Verify installation and metrics availability
echo ""
echo "Verification:"
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "✓ metrics-server deployment exists"
  kubectl get deployment metrics-server -n kube-system
  echo ""
fi

if kubectl get pods -n kube-system -l k8s-app=metrics-server &>/dev/null; then
  echo "✓ metrics-server pods:"
  kubectl get pods -n kube-system -l k8s-app=metrics-server
  echo ""
fi

# Check if metrics API is responding
if kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/default/pods &>/dev/null 2>&1; then
  echo "✓ metrics API is responding"
else
  echo "⚠ metrics API may need more time to respond, but metrics-server is installed"
fi

echo "✓ metrics-server installation complete"


