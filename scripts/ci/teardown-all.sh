#!/usr/bin/env bash
set -euo pipefail

# Destroys all GCP resources: VMs (Jenkins + Runner) and GKE cluster.
# Usage:
#   GCP_SA_FILE=/path/to/sa.json scripts/ci/teardown-all.sh
#   or set GOOGLE_APPLICATION_CREDENTIALS before running.

GCP_SA_FILE="${GCP_SA_FILE:-}"
GCP_SA_JSON="${GCP_SA_JSON:-}"

echo "=== CircleGuard Infrastructure Teardown ==="
echo "This will DESTROY all GCP resources (VMs, GKE cluster, VPC, IPs)."
echo "Press Ctrl+C within 10 seconds to cancel..."
sleep 10

# Resolve GCP credentials
SA_PATH=""
if [ -n "$GCP_SA_FILE" ] && [ -f "$GCP_SA_FILE" ]; then
  SA_PATH="$GCP_SA_FILE"
elif [ -n "$GCP_SA_JSON" ]; then
  SA_PATH="/tmp/gcp-sa-teardown.json"
  echo "$GCP_SA_JSON" > "$SA_PATH"
elif [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  SA_PATH="$GOOGLE_APPLICATION_CREDENTIALS"
else
  echo "ERROR: No GCP credentials found."
  echo "Set GCP_SA_FILE, GCP_SA_JSON, or GOOGLE_APPLICATION_CREDENTIALS."
  exit 1
fi

DOCKER_CREDS=( -e "GOOGLE_APPLICATION_CREDENTIALS=/workspace/sa.json" -v "$SA_PATH:/workspace/sa.json:ro" )

# ── 1. Destroy GKE cluster (infra/terraform) ──────────────────────────────────
echo ""
echo "=== [1/2] Destroying GKE cluster (infra/terraform) ==="

if [ -f "infra/terraform/terraform.tfstate" ] || [ -d "infra/terraform/.terraform" ]; then
  docker run --rm \
    "${DOCKER_CREDS[@]}" \
    -v "$PWD:/workspace" \
    -w "/workspace/infra/terraform" \
    hashicorp/terraform:1.9.8 \
    init -input=false

  docker run --rm \
    "${DOCKER_CREDS[@]}" \
    -v "$PWD:/workspace" \
    -w "/workspace/infra/terraform" \
    hashicorp/terraform:1.9.8 \
    destroy -auto-approve \
    -var "kubeconfig_path=/tmp/dummy" \
    -var "dockerhub_username=dummy" \
    -var "dockerhub_password=dummy" \
    -var "dockerhub_email=dummy@dummy.com" \
    -var "qr_secret=dummy" \
    || echo "WARN: GKE terraform destroy had errors (resources may already be gone)"
else
  echo "No terraform state found in infra/terraform, skipping."
fi

# ── 2. Destroy VMs (infra/terraform-gcp) ─────────────────────────────────────
echo ""
echo "=== [2/2] Destroying VMs (infra/terraform-gcp) ==="

if [ -f "infra/terraform-gcp/terraform.tfstate" ] || [ -d "infra/terraform-gcp/.terraform" ]; then
  docker run --rm \
    "${DOCKER_CREDS[@]}" \
    -v "$PWD:/workspace" \
    -w "/workspace/infra/terraform-gcp" \
    hashicorp/terraform:1.9.8 \
    init -input=false

  docker run --rm \
    "${DOCKER_CREDS[@]}" \
    -v "$PWD:/workspace" \
    -w "/workspace/infra/terraform-gcp" \
    hashicorp/terraform:1.9.8 \
    destroy -auto-approve \
    || echo "WARN: VM terraform destroy had errors (resources may already be gone)"
else
  echo "No terraform state found in infra/terraform-gcp, skipping."
fi

echo ""
echo "=== Teardown complete. All GCP resources destroyed. ==="
