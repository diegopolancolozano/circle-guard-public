#!/usr/bin/env bash
# =============================================================================
# gcp-provision.sh — Provisiona el cluster GKE en GCP usando variables del .env
#
# Uso:
#   scripts/infra/gcp-provision.sh [--destroy]
#
# Requiere:
#   - .env en la raíz del repo con GCP_PROJECT, GCP_SA_FILE, SSH_PUBLIC_KEY, etc.
#   - gcloud CLI instalado y autenticado
#   - terraform >= 1.6.0
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DESTROY="${1:-}"

# ── Cargar .env ───────────────────────────────────────────────────────────────
source "${REPO_ROOT}/scripts/ci/load-env.sh"

# ── Validar variables requeridas ──────────────────────────────────────────────
: "${GCP_PROJECT:?Falta GCP_PROJECT en .env}"
: "${GCP_SA_FILE:?Falta GCP_SA_FILE en .env}"
: "${SSH_PUBLIC_KEY:?Falta SSH_PUBLIC_KEY en .env}"

GCP_SA_FILE_EXPANDED="${GCP_SA_FILE/#\~/$HOME}"

if [[ ! -f "${GCP_SA_FILE_EXPANDED}" ]]; then
  echo "ERROR: Service Account JSON no encontrado en: ${GCP_SA_FILE_EXPANDED}"
  echo "Descárgalo desde GCP Console → IAM → Service Accounts → Keys"
  exit 1
fi

GCP_REGION="${GCP_REGION:-us-central1}"
GCP_ZONE="${GCP_ZONE:-us-central1-a}"
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-circleguard-prod}"
STATE_BUCKET="circleguard-tfstate-${GCP_PROJECT}"

GLOBAL_DIR="${REPO_ROOT}/infra/terraform-gcp/global"
PROD_DIR="${REPO_ROOT}/infra/terraform-gcp/environments/prod"

# ── Autenticar gcloud ─────────────────────────────────────────────────────────
echo ""
echo "=== [1/5] Autenticando con GCP ==="
gcloud auth activate-service-account --key-file="${GCP_SA_FILE_EXPANDED}" --quiet
gcloud config set project "${GCP_PROJECT}" --quiet
export GOOGLE_APPLICATION_CREDENTIALS="${GCP_SA_FILE_EXPANDED}"

# Habilitar APIs necesarias
echo "=== [2/5] Habilitando APIs de GCP ==="
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  --project="${GCP_PROJECT}" --quiet

# ── DESTROY ───────────────────────────────────────────────────────────────────
if [[ "${DESTROY}" == "--destroy" ]]; then
  echo ""
  echo "=== DESTRUYENDO infraestructura GCP ==="
  read -r -p "¿Seguro? Esto elimina el cluster GKE (s/N): " confirm
  [[ "${confirm}" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

  cd "${PROD_DIR}"
  terraform init -reconfigure \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="prefix=terraform-gcp/prod"
  terraform destroy -auto-approve \
    -var="project_id=${GCP_PROJECT}" \
    -var="region=${GCP_REGION}" \
    -var="zone=${GCP_ZONE}" \
    -var="ssh_public_key=${SSH_PUBLIC_KEY}" \
    -var="ssh_user=${GCP_SSH_USER:-deployer}" \
    -var="gke_cluster_name=${GKE_CLUSTER_NAME}"
  echo "Infraestructura destruida."
  exit 0
fi

# ── Paso 1: Bucket de estado remoto ──────────────────────────────────────────
echo ""
echo "=== [3/5] Creando bucket de estado remoto ==="

# Crear el bucket directamente con gsutil si no existe (evita dependencia circular)
if ! gsutil ls -p "${GCP_PROJECT}" "gs://${STATE_BUCKET}" &>/dev/null; then
  gsutil mb -p "${GCP_PROJECT}" -l "${GCP_REGION}" "gs://${STATE_BUCKET}"
  gsutil versioning set on "gs://${STATE_BUCKET}"
  echo "Bucket creado: gs://${STATE_BUCKET}"
else
  echo "Bucket ya existe: gs://${STATE_BUCKET}"
fi

# ── Paso 2: Cluster GKE + VPC + compute ──────────────────────────────────────
echo ""
echo "=== [4/5] Provisionando VPC + GKE cluster + compute ==="

cd "${PROD_DIR}"

# Actualizar el backend con el bucket real
cat > backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${STATE_BUCKET}"
    prefix = "terraform-gcp/prod"
  }
}
EOF

terraform init -reconfigure
terraform apply -auto-approve \
  -var="project_id=${GCP_PROJECT}" \
  -var="region=${GCP_REGION}" \
  -var="zone=${GCP_ZONE}" \
  -var="ssh_public_key=${SSH_PUBLIC_KEY}" \
  -var="ssh_user=${GCP_SSH_USER:-deployer}" \
  -var="gke_cluster_name=${GKE_CLUSTER_NAME}" \
  -var="gke_node_count=2" \
  -var="gke_min_nodes=2" \
  -var="gke_max_nodes=4" \
  -var="gke_machine_type=e2-standard-2" \
  -var="gke_disk_size_gb=50"

# ── Paso 3: Obtener kubeconfig ────────────────────────────────────────────────
echo ""
echo "=== [5/5] Obteniendo kubeconfig de GKE ==="

gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" \
  --region "${GKE_CLUSTER_LOCATION:-${GCP_REGION}}" \
  --project "${GCP_PROJECT}"

KUBECONFIG_OUT="${REPO_ROOT}/infra/terraform-gcp/kubeconfig-gke-prod.yaml"
kubectl config view --raw > "${KUBECONFIG_OUT}"
chmod 600 "${KUBECONFIG_OUT}"

echo ""
echo "============================================================"
echo " GKE cluster listo: ${GKE_CLUSTER_NAME}"
echo " Region:            ${GCP_REGION}"
echo " Proyecto:          ${GCP_PROJECT}"
echo " kubeconfig:        ${KUBECONFIG_OUT}"
echo ""
echo " Próximo paso — subir el kubeconfig a Jenkins:"
echo "   Jenkins → Manage Credentials → Add → Secret file"
echo "   ID: gcp-sa-credentials   File: ${GCP_SA_FILE_EXPANDED}"
echo "   ID: kubeconfig-gcp-credentials   File: ${KUBECONFIG_OUT}"
echo ""
echo " Luego lanza el pipeline con:"
echo "   CLOUD_TARGET=gcp"
echo "   GCP_PROJECT=${GCP_PROJECT}"
echo "   GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME}"
echo "   GKE_CLUSTER_LOCATION=${GCP_REGION}"
echo "============================================================"
