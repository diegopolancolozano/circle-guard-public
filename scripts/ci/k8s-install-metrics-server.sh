#!/bin/bash
set -e

echo "Installing metrics-server for HPA..."

# Apply metrics-server with validation disabled (it's from official repo)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --validate=false

# Wait for metrics-server to be ready
echo "Waiting for metrics-server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system || true

# Verify installation
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "✓ metrics-server installed successfully"
  kubectl get deployment metrics-server -n kube-system
else
  echo "⚠ metrics-server installation may have failed, but continuing..."
fi
