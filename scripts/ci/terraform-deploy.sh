#!/usr/bin/env bash
# =============================================================================
# CircleGuard — Full Terraform deploy to GCP
#
# Usage:
#   ./scripts/ci/terraform-deploy.sh [stage|prod] [plan|apply|destroy]
#
# Prerequisites:
#   - GOOGLE_APPLICATION_CREDENTIALS pointing to a SA key JSON OR gcloud ADC
#   - Terraform >= 1.6 installed
#   - gcloud CLI installed and configured
#
# Sequence:
#   1. (first run only) terraform-gcp/dev — creates the GCS tfstate bucket
#   2. terraform-gcp/<env>             — creates VPC + GKE + Jenkins VM
#   3. (wait for GKE)                  — poll until cluster is RUNNING
#   4. terraform (k8s)/<env>           — creates namespaces + K8s secrets
# =============================================================================
set -euo pipefail

ENV="${1:-stage}"
ACTION="${2:-apply}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF_GCP_DIR="${REPO_ROOT}/infra/terraform-gcp/environments/${ENV}"
TF_K8S_DIR="${REPO_ROOT}/infra/terraform/environments/${ENV}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[TF-DEPLOY]${NC} $*"; }
warn() { echo -e "${YELLOW}[TF-DEPLOY]${NC} $*"; }
err()  { echo -e "${RED}[TF-DEPLOY] ERROR:${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
[[ "${ENV}" =~ ^(dev|stage|prod)$ ]] || err "ENV must be dev, stage, or prod. Got: ${ENV}"
[[ "${ACTION}" =~ ^(plan|apply|destroy)$ ]] || err "ACTION must be plan, apply, or destroy. Got: ${ACTION}"

command -v terraform &>/dev/null || err "terraform not found in PATH"
command -v gcloud    &>/dev/null || err "gcloud not found in PATH"

[[ -d "${TF_GCP_DIR}" ]] || err "Directory not found: ${TF_GCP_DIR}"
[[ -d "${TF_K8S_DIR}" ]] || err "Directory not found: ${TF_K8S_DIR}"

[[ -f "${TF_GCP_DIR}/terraform.tfvars" ]] || \
  err "Missing ${TF_GCP_DIR}/terraform.tfvars — copy and fill in terraform.tfvars.example"

[[ -f "${TF_K8S_DIR}/terraform.tfvars" ]] || \
  err "Missing ${TF_K8S_DIR}/terraform.tfvars — copy and fill in terraform.tfvars"

# ---------------------------------------------------------------------------
# Step 0: Bootstrap GCS bucket (only needed once; dev env creates it)
# ---------------------------------------------------------------------------
bootstrap_bucket() {
  local BUCKET_NAME="circleguard-tfstate"

  if gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
    log "GCS bucket '${BUCKET_NAME}' already exists — skipping bootstrap."
    return 0
  fi

  warn "GCS bucket '${BUCKET_NAME}' not found. Running dev bootstrap..."
  local DEV_DIR="${REPO_ROOT}/infra/terraform-gcp/environments/dev"
  [[ -f "${DEV_DIR}/terraform.tfvars" ]] || \
    err "Please fill in ${DEV_DIR}/terraform.tfvars before first run."

  (
    cd "${DEV_DIR}"
    terraform init -input=false
    terraform apply -auto-approve -input=false
  )
  log "Bootstrap complete."
}

# ---------------------------------------------------------------------------
# Step 1: GCP infrastructure (VPC + GKE + VMs)
# ---------------------------------------------------------------------------
deploy_gcp_infra() {
  log "=== Step 1: terraform-gcp/${ENV} ==="
  (
    cd "${TF_GCP_DIR}"
    terraform init -input=false -upgrade
    if [[ "${ACTION}" == "plan" ]]; then
      terraform plan -input=false
    elif [[ "${ACTION}" == "apply" ]]; then
      terraform apply -auto-approve -input=false
    elif [[ "${ACTION}" == "destroy" ]]; then
      warn "Destroying GCP infrastructure for ${ENV}..."
      terraform destroy -auto-approve -input=false
      return 0
    fi
  )
}

# ---------------------------------------------------------------------------
# Step 2: Wait for GKE cluster to be RUNNING
# ---------------------------------------------------------------------------
wait_for_gke() {
  # Extract project_id and cluster_name from tfvars (rough parse)
  local PROJECT_ID
  PROJECT_ID=$(grep 'project_id' "${TF_GCP_DIR}/terraform.tfvars" | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/')

  local CLUSTER_NAME
  CLUSTER_NAME=$(grep 'gke_cluster_name' "${TF_GCP_DIR}/terraform.tfvars" | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/')

  local REGION
  REGION=$(grep 'region' "${TF_GCP_DIR}/terraform.tfvars" | grep -v '#' | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/')
  REGION="${REGION:-us-central1}"

  # Defaults from variables.tf if not set in tfvars
  CLUSTER_NAME="${CLUSTER_NAME:-circleguard-${ENV}}"

  log "=== Step 2: Waiting for GKE cluster '${CLUSTER_NAME}' to be RUNNING ==="
  local MAX_WAIT=600  # 10 minutes
  local ELAPSED=0
  local STATUS=""

  while [[ "${STATUS}" != "RUNNING" && ${ELAPSED} -lt ${MAX_WAIT} ]]; do
    STATUS=$(gcloud container clusters describe "${CLUSTER_NAME}" \
      --region="${REGION}" \
      --project="${PROJECT_ID}" \
      --format="value(status)" 2>/dev/null || echo "PENDING")

    if [[ "${STATUS}" == "RUNNING" ]]; then
      log "Cluster is RUNNING."
      break
    fi

    warn "Cluster status: ${STATUS}. Waiting 20s... (${ELAPSED}s elapsed)"
    sleep 20
    ELAPSED=$((ELAPSED + 20))
  done

  [[ "${STATUS}" == "RUNNING" ]] || err "Cluster did not reach RUNNING state within ${MAX_WAIT}s"

  # Configure kubeconfig
  gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}"
  log "kubeconfig updated for cluster '${CLUSTER_NAME}'."
}

# ---------------------------------------------------------------------------
# Step 3: K8s secrets (namespaces + Docker pull secret + QR secret)
# ---------------------------------------------------------------------------
deploy_k8s_secrets() {
  log "=== Step 3: terraform (k8s)/${ENV} ==="
  (
    cd "${TF_K8S_DIR}"
    terraform init -input=false -upgrade
    if [[ "${ACTION}" == "plan" ]]; then
      terraform plan -input=false
    elif [[ "${ACTION}" == "apply" ]]; then
      terraform apply -auto-approve -input=false
    elif [[ "${ACTION}" == "destroy" ]]; then
      warn "Destroying K8s secrets for ${ENV}..."
      terraform destroy -auto-approve -input=false
    fi
  )
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "CircleGuard Terraform Deploy — env=${ENV}, action=${ACTION}"

if [[ "${ACTION}" == "apply" ]]; then
  bootstrap_bucket
  deploy_gcp_infra
  wait_for_gke
  deploy_k8s_secrets
  log ""
  log "====================================================="
  log " Deploy complete for environment: ${ENV}"
  log "====================================================="
  log " Next steps:"
  log "   kubectl apply -k k8s/overlays/${ENV}"
  log "   kubectl apply -k k8s/monitoring"
  log "   kubectl get pods -n ${ENV}"
elif [[ "${ACTION}" == "plan" ]]; then
  deploy_gcp_infra
  deploy_k8s_secrets
elif [[ "${ACTION}" == "destroy" ]]; then
  deploy_k8s_secrets
  deploy_gcp_infra
  log "Destroy complete for environment: ${ENV}"
fi
