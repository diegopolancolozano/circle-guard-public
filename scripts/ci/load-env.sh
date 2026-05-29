#!/usr/bin/env bash
# =============================================================================
# load-env.sh — helper que sourcean todos los scripts de CI
#
# Uso (al inicio de cualquier script):
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "${SCRIPT_DIR}/load-env.sh"
#
# Busca .env en la raíz del repo (dos niveles arriba de scripts/ci/).
# Si no existe, continúa con las variables ya exportadas en el entorno
# (útil en Jenkins donde las credenciales se inyectan como env vars).
# =============================================================================

_LOAD_ENV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_LOAD_ENV_SCRIPT_DIR}/../.." && pwd)"
_ENV_FILE="${_REPO_ROOT}/.env"

if [[ -f "${_ENV_FILE}" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "${_ENV_FILE}"
  set +o allexport

  # Derivar TF_VAR_ssh_public_key de SSH_PUBLIC_KEY si no está puesto
  if [[ -z "${TF_VAR_ssh_public_key:-}" && -n "${SSH_PUBLIC_KEY:-}" ]]; then
    export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY}"
  fi

  # Derivar TF_VAR_jenkins_ssh_public_key de SSH_PUBLIC_KEY si no está puesto
  if [[ -z "${TF_VAR_jenkins_ssh_public_key:-}" && -n "${SSH_PUBLIC_KEY:-}" ]]; then
    export TF_VAR_jenkins_ssh_public_key="${SSH_PUBLIC_KEY}"
  fi

  # GOOGLE_APPLICATION_CREDENTIALS para terraform-gcp y gcloud
  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -n "${GCP_SA_FILE:-}" ]]; then
    # Expandir ~ manualmente (no lo hace 'source' en todas las shells)
    export GOOGLE_APPLICATION_CREDENTIALS="${GCP_SA_FILE/#\~/$HOME}"
  fi

  # AWS_* aliases para el backend S3 de DO Spaces
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -n "${SPACES_ACCESS_KEY_ID:-}" ]]; then
    export AWS_ACCESS_KEY_ID="${SPACES_ACCESS_KEY_ID}"
    export AWS_SECRET_ACCESS_KEY="${SPACES_SECRET_ACCESS_KEY}"
  fi

  # DO_TOKEN alias (para scripts que usen DO_TOKEN en lugar de DIGITALOCEAN_TOKEN)
  if [[ -z "${DO_TOKEN:-}" && -n "${DIGITALOCEAN_TOKEN:-}" ]]; then
    export DO_TOKEN="${DIGITALOCEAN_TOKEN}"
  fi
else
  echo "[load-env] .env no encontrado en ${_REPO_ROOT} — usando variables del entorno" >&2

  # Mismos aliases aunque no haya .env
  [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -n "${GCP_SA_FILE:-}" ]] && \
    export GOOGLE_APPLICATION_CREDENTIALS="${GCP_SA_FILE/#\~/$HOME}"
  [[ -z "${AWS_ACCESS_KEY_ID:-}" && -n "${SPACES_ACCESS_KEY_ID:-}" ]] && \
    export AWS_ACCESS_KEY_ID="${SPACES_ACCESS_KEY_ID}" && \
    export AWS_SECRET_ACCESS_KEY="${SPACES_SECRET_ACCESS_KEY}"
  [[ -z "${DO_TOKEN:-}" && -n "${DIGITALOCEAN_TOKEN:-}" ]] && \
    export DO_TOKEN="${DIGITALOCEAN_TOKEN}"
  [[ -z "${TF_VAR_ssh_public_key:-}" && -n "${SSH_PUBLIC_KEY:-}" ]] && \
    export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY}"
  [[ -z "${TF_VAR_jenkins_ssh_public_key:-}" && -n "${SSH_PUBLIC_KEY:-}" ]] && \
    export TF_VAR_jenkins_ssh_public_key="${SSH_PUBLIC_KEY}"
fi

# Exportar REPO_ROOT para que los scripts sepan dónde están
export REPO_ROOT="${_REPO_ROOT}"
