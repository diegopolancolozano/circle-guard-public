#!/usr/bin/env bash
# Configura kubectl para apuntar a un cluster GKE usando gcloud.
# Lee credenciales del .env en la raíz del repo (si existe), o de variables
# de entorno ya exportadas (útil en Jenkins con credenciales inyectadas).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/load-env.sh"

# Jenkins puede pasar GCP_SA_FILE como variable propia; soportar ambos nombres.
GCP_SA_FILE="${GCP_SA_FILE:-${GOOGLE_APPLICATION_CREDENTIALS:-}}"
GCP_PROJECT="${GCP_PROJECT:-}"
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-}"
GKE_CLUSTER_LOCATION="${GKE_CLUSTER_LOCATION:-us-central1}"

# ── Validaciones ──────────────────────────────────────────────────────────────
: "${GCP_SA_FILE:?Falta GCP_SA_FILE en .env}"
: "${GCP_PROJECT:?Falta GCP_PROJECT en .env}"
: "${GKE_CLUSTER_NAME:?Falta GKE_CLUSTER_NAME en .env}"
command -v gcloud  &>/dev/null || { echo "ERROR: gcloud no instalado"; exit 1; }
command -v kubectl &>/dev/null || { echo "ERROR: kubectl no instalado"; exit 1; }

# ── Asegurar gke-gcloud-auth-plugin ──────────────────────────────────────────
ensure_plugin() {
  command -v gke-gcloud-auth-plugin &>/dev/null && return 0
  echo "Instalando gke-gcloud-auth-plugin..."
  if command -v apt-get &>/dev/null; then
    local sudo_cmd=""; [ "$(id -u)" -ne 0 ] && sudo_cmd="sudo -n"
    ${sudo_cmd} apt-get update -y
    ${sudo_cmd} apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
  elif command -v gcloud &>/dev/null; then
    gcloud components install gke-gcloud-auth-plugin --quiet
  fi
  command -v gke-gcloud-auth-plugin &>/dev/null || { echo "ERROR: plugin aún faltante"; exit 1; }
}

ensure_plugin

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

gcloud auth activate-service-account --key-file "${GCP_SA_FILE}"
gcloud config set project "${GCP_PROJECT}" >/dev/null
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" \
  --region "${GKE_CLUSTER_LOCATION}" --project "${GCP_PROJECT}"

echo "GKE listo: $(kubectl config current-context)"
