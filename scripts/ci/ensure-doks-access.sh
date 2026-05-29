#!/usr/bin/env bash
# Configura kubectl para apuntar a un cluster DOKS usando doctl.
# Lee credenciales del .env en la raíz del repo (si existe), o de variables
# de entorno ya exportadas (útil en Jenkins con credenciales inyectadas).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/load-env.sh"

DOCTL_VERSION="${DOCTL_VERSION:-1.110.0}"

# ── Asegurar que doctl está instalado ─────────────────────────────────────────
ensure_doctl() {
  command -v doctl &>/dev/null && return 0

  echo "doctl no encontrado. Instalando v${DOCTL_VERSION}..."
  local arch; arch="$(uname -m)"
  case "$arch" in x86_64) arch="amd64";; aarch64) arch="arm64";;
    *) echo "ERROR: arquitectura no soportada: $arch"; exit 1;; esac
  local os; os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-${os}-${arch}.tar.gz" \
    | tar xz -C /usr/local/bin
  chmod +x /usr/local/bin/doctl
}

# ── Validaciones ──────────────────────────────────────────────────────────────
: "${DIGITALOCEAN_TOKEN:?Falta DIGITALOCEAN_TOKEN en .env}"
: "${DOKS_CLUSTER_NAME:?Falta DOKS_CLUSTER_NAME en .env}"
command -v kubectl &>/dev/null || { echo "ERROR: kubectl no instalado"; exit 1; }

ensure_doctl

doctl auth init --access-token "${DIGITALOCEAN_TOKEN}"
doctl kubernetes cluster kubeconfig save "${DOKS_CLUSTER_NAME}"

echo "DOKS listo: $(kubectl config current-context)"
