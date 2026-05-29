#!/usr/bin/env bash
# =============================================================================
# CircleGuard — Terraform deploy a DigitalOcean
#
# Uso:
#   bash scripts/ci/terraform-deploy-do.sh [stage|prod] [plan|apply|destroy]
#
# Requisito previo:
#   cp .env.example .env   # y rellena tus credenciales
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/load-env.sh"

ENV="${1:-stage}"
ACTION="${2:-apply}"
TF_DIR="${REPO_ROOT}/infra/terraform-do/environments/${ENV}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[TF-DO]${NC} $*"; }
warn() { echo -e "${YELLOW}[TF-DO]${NC} $*"; }
err()  { echo -e "${RED}[TF-DO] ERROR:${NC} $*" >&2; exit 1; }

# ── Validaciones ──────────────────────────────────────────────────────────────
[[ "${ENV}" =~ ^(dev|stage|prod)$ ]] || err "ENV debe ser dev, stage o prod."
[[ "${ACTION}" =~ ^(plan|apply|destroy)$ ]] || err "ACTION debe ser plan, apply o destroy."
: "${DIGITALOCEAN_TOKEN:?Falta DIGITALOCEAN_TOKEN en .env}"
: "${SPACES_ACCESS_KEY_ID:?Falta SPACES_ACCESS_KEY_ID en .env}"
: "${SPACES_SECRET_ACCESS_KEY:?Falta SPACES_SECRET_ACCESS_KEY en .env}"
command -v terraform &>/dev/null || err "terraform no está instalado"
[[ -d "${TF_DIR}" ]] || err "Directorio no encontrado: ${TF_DIR}"

# ── backend.hcl ───────────────────────────────────────────────────────────────
BACKEND_HCL="${TF_DIR}/backend.hcl"
if [[ ! -f "${BACKEND_HCL}" ]]; then
  cp "${TF_DIR}/backend.hcl.example" "${BACKEND_HCL}"
  warn "Creado backend.hcl desde el ejemplo."
fi

# ── SSH key ───────────────────────────────────────────────────────────────────
if [[ -z "${TF_VAR_jenkins_ssh_public_key:-}" ]]; then
  SSH_KEY="${HOME}/.ssh/id_rsa"
  if [[ ! -f "${SSH_KEY}" ]]; then
    log "Generando clave SSH en ${SSH_KEY}..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "circleguard-jenkins"
  fi
  export TF_VAR_jenkins_ssh_public_key
  TF_VAR_jenkins_ssh_public_key="$(cat "${SSH_KEY}.pub")"
fi

# ── terraform init ────────────────────────────────────────────────────────────
log "=== terraform init ==="
( cd "${TF_DIR}" && terraform init -input=false -reconfigure -backend-config="${BACKEND_HCL}" )

# ── terraform plan / apply / destroy ─────────────────────────────────────────
log "=== terraform ${ACTION} (env=${ENV}) ==="
(
  cd "${TF_DIR}"
  case "${ACTION}" in
    plan)    terraform plan -input=false ;;
    apply)   terraform apply -auto-approve -input=false ;;
    destroy) warn "Destruyendo infraestructura DO (${ENV})..."
             terraform destroy -auto-approve -input=false
             exit 0 ;;
  esac
)

# ── Guardar kubeconfig ────────────────────────────────────────────────────────
if [[ "${ACTION}" == "apply" ]]; then
  CLUSTER="${DOKS_CLUSTER_NAME:-$(cd "${TF_DIR}" && terraform output -raw cluster_name 2>/dev/null || true)}"
  if [[ -n "${CLUSTER}" ]] && command -v doctl &>/dev/null; then
    log "Guardando kubeconfig para '${CLUSTER}'..."
    doctl auth init --access-token "${DIGITALOCEAN_TOKEN}"
    doctl kubernetes cluster kubeconfig save "${CLUSTER}"
    log "kubectl context: $(kubectl config current-context)"
  fi
fi

# ── Outputs ───────────────────────────────────────────────────────────────────
if [[ "${ACTION}" == "apply" ]]; then
  cd "${TF_DIR}"
  JENKINS_URL="$(terraform output -raw jenkins_url 2>/dev/null || echo 'N/A')"
  JENKINS_SSH="$(terraform output -raw jenkins_ssh_command 2>/dev/null || echo 'N/A')"
  log ""
  log "========================================================"
  log " Deploy completo — DigitalOcean ${ENV}"
  log "========================================================"
  log " Jenkins URL : ${JENKINS_URL}"
  log " SSH         : ${JENKINS_SSH}"
  log " Contraseña inicial (~3 min):"
  log "   ${JENKINS_SSH} cat /var/lib/jenkins/secrets/initialAdminPassword"
  log "========================================================"
fi
