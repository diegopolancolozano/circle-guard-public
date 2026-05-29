#!/usr/bin/env bash
# =============================================================================
# CircleGuard — Terraform deploy a GCP
#
# Uso:
#   bash scripts/ci/terraform-deploy.sh [stage|prod] [plan|apply|destroy]
#
# Requisito previo:
#   cp .env.example .env   # y rellena tus credenciales GCP
#
# Secuencia:
#   1. (primera vez) bootstrap del bucket GCS de estado
#   2. terraform-gcp/<env>  — VPC + GKE + Jenkins VM
#   3. Esperar a que el cluster esté RUNNING
#   4. terraform-k8s/<env>  — namespaces + Docker pull secret + QR secret
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/load-env.sh"

ENV="${1:-stage}"
ACTION="${2:-apply}"

TF_GCP_DIR="${REPO_ROOT}/infra/terraform-gcp/environments/${ENV}"
TF_K8S_DIR="${REPO_ROOT}/infra/terraform/environments/${ENV}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[TF-GCP]${NC} $*"; }
warn() { echo -e "${YELLOW}[TF-GCP]${NC} $*"; }
err()  { echo -e "${RED}[TF-GCP] ERROR:${NC} $*" >&2; exit 1; }

# ── Validaciones ──────────────────────────────────────────────────────────────
[[ "${ENV}" =~ ^(dev|stage|prod)$ ]] || err "ENV debe ser dev, stage o prod."
[[ "${ACTION}" =~ ^(plan|apply|destroy)$ ]] || err "ACTION debe ser plan, apply o destroy."
: "${GCP_PROJECT:?Falta GCP_PROJECT en .env}"
: "${GOOGLE_APPLICATION_CREDENTIALS:?Falta GCP_SA_FILE en .env}"
[[ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]] || err "El archivo GCP_SA_FILE no existe: ${GOOGLE_APPLICATION_CREDENTIALS}"
command -v terraform &>/dev/null || err "terraform no está instalado"
command -v gcloud    &>/dev/null || err "gcloud no está instalado"

# Terraform lee TF_VAR_* automáticamente — exportar los que vienen del .env
export TF_VAR_project_id="${GCP_PROJECT}"
export TF_VAR_ssh_user="${GCP_SSH_USER:-deployer}"
# TF_VAR_ssh_public_key ya fue exportado por load-env.sh si SSH_PUBLIC_KEY estaba seteado

# Si SSH_PUBLIC_KEY estaba vacío en .env, leer del sistema
if [[ -z "${TF_VAR_ssh_public_key:-}" ]]; then
  SSH_KEY="${HOME}/.ssh/id_rsa"
  if [[ ! -f "${SSH_KEY}" ]]; then
    log "Generando clave SSH en ${SSH_KEY}..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "circleguard-gcp"
  fi
  export TF_VAR_ssh_public_key
  TF_VAR_ssh_public_key="$(cat "${SSH_KEY}.pub")"
fi

# K8s secrets terraform también usa TF_VAR_
export TF_VAR_dockerhub_username="${DOCKERHUB_USERNAME:-}"
export TF_VAR_dockerhub_password="${DOCKERHUB_PASSWORD:-}"
export TF_VAR_dockerhub_email="${DOCKERHUB_EMAIL:-devops@circleguard.local}"
export TF_VAR_qr_secret="${QR_SECRET:-}"
export TF_VAR_use_gke="true"
export TF_VAR_gcp_project="${GCP_PROJECT}"
export TF_VAR_gke_cluster_name="${GKE_CLUSTER_NAME:-circleguard-${ENV}}"
export TF_VAR_gke_cluster_location="${GKE_CLUSTER_LOCATION:-us-central1}"

# ── Validar vars sensibles requeridas ─────────────────────────────────────────
if [[ "${ACTION}" == "apply" ]]; then
  : "${DOCKERHUB_USERNAME:?Falta DOCKERHUB_USERNAME en .env}"
  : "${DOCKERHUB_PASSWORD:?Falta DOCKERHUB_PASSWORD en .env}"
  : "${QR_SECRET:?Falta QR_SECRET en .env}"
fi

# ── Auth GCP ──────────────────────────────────────────────────────────────────
log "Activando Service Account GCP..."
gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"
gcloud config set project "${GCP_PROJECT}" >/dev/null

# ── Paso 0: bootstrap del bucket GCS (solo primera vez) ──────────────────────
bootstrap_bucket() {
  local BUCKET="circleguard-tfstate"
  if gcloud storage buckets describe "gs://${BUCKET}" &>/dev/null; then
    log "Bucket GCS '${BUCKET}' ya existe."
    return 0
  fi
  warn "Bucket '${BUCKET}' no encontrado. Ejecutando bootstrap (env dev)..."
  local DEV_DIR="${REPO_ROOT}/infra/terraform-gcp/environments/dev"
  ( cd "${DEV_DIR}" && terraform init -input=false && terraform apply -auto-approve -input=false )
  log "Bootstrap completo."
}

# ── Paso 1: GCP infra (VPC + GKE + Jenkins VM) ───────────────────────────────
deploy_gcp_infra() {
  log "=== terraform-gcp/${ENV} ==="
  (
    cd "${TF_GCP_DIR}"
    terraform init -input=false -upgrade -reconfigure
    case "${ACTION}" in
      plan)    terraform plan -input=false ;;
      apply)   terraform apply -auto-approve -input=false
               log "=== Outputs ===" && terraform output ;;
      destroy) warn "Destruyendo GCP infra (${ENV})..."
               terraform destroy -auto-approve -input=false ;;
    esac
  )
}

# ── Paso 2: Esperar al cluster GKE ───────────────────────────────────────────
wait_for_gke() {
  log "Esperando que el cluster '${TF_VAR_gke_cluster_name}' esté RUNNING..."
  local MAX=600 ELAPSED=0 STATUS=""
  while [[ "${STATUS}" != "RUNNING" && ${ELAPSED} -lt ${MAX} ]]; do
    STATUS=$(gcloud container clusters describe "${TF_VAR_gke_cluster_name}" \
      --region="${TF_VAR_gke_cluster_location}" \
      --project="${GCP_PROJECT}" \
      --format="value(status)" 2>/dev/null || echo "PENDING")
    [[ "${STATUS}" == "RUNNING" ]] && break
    warn "Estado: ${STATUS}. Esperando 20s... (${ELAPSED}s/${MAX}s)"
    sleep 20; ELAPSED=$((ELAPSED + 20))
  done
  [[ "${STATUS}" == "RUNNING" ]] || err "El cluster no llegó a RUNNING en ${MAX}s"
  gcloud container clusters get-credentials "${TF_VAR_gke_cluster_name}" \
    --region="${TF_VAR_gke_cluster_location}" --project="${GCP_PROJECT}"
  log "kubeconfig: $(kubectl config current-context)"
}

# ── Paso 3: K8s secrets (namespaces + docker pull secret + QR secret) ────────
deploy_k8s_secrets() {
  log "=== terraform-k8s/${ENV} ==="
  (
    cd "${TF_K8S_DIR}"
    terraform init -input=false -upgrade -reconfigure
    case "${ACTION}" in
      plan)    terraform plan -input=false ;;
      apply)   terraform apply -auto-approve -input=false ;;
      destroy) terraform destroy -auto-approve -input=false ;;
    esac
  )
}

# ── Main ──────────────────────────────────────────────────────────────────────
log "CircleGuard GCP deploy — env=${ENV}, action=${ACTION}"

if [[ "${ACTION}" == "apply" ]]; then
  bootstrap_bucket
  deploy_gcp_infra
  wait_for_gke
  deploy_k8s_secrets
  log ""
  log "========================================================"
  log " Deploy completo — GCP ${ENV}"
  log "========================================================"
  log " Siguientes pasos:"
  log "   kubectl apply -k k8s/overlays/${ENV}"
  log "   kubectl get pods -n ${ENV}"
  log "========================================================"
elif [[ "${ACTION}" == "plan" ]]; then
  deploy_gcp_infra
  deploy_k8s_secrets
elif [[ "${ACTION}" == "destroy" ]]; then
  deploy_k8s_secrets
  deploy_gcp_infra
  log "Destroy completo para ${ENV}"
fi
