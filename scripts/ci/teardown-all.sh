#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/var/jenkins_home/.kube/config}"

echo "=== CircleGuard Local Kubernetes Teardown ==="
echo "This removes the local dev, stage, and master namespaces."

kubectl delete namespace dev stage master --ignore-not-found=true || true

echo "=== Teardown complete. Local namespaces removed. ==="
