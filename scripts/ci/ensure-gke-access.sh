#!/usr/bin/env bash
set -euo pipefail

: "${GCP_SA_FILE:?GCP_SA_FILE is required}"
: "${GCP_PROJECT:?GCP_PROJECT is required}"
: "${GKE_CLUSTER_NAME:?GKE_CLUSTER_NAME is required}"
: "${GKE_CLUSTER_LOCATION:?GKE_CLUSTER_LOCATION is required}"

ensure_plugin() {
  if command -v gke-gcloud-auth-plugin >/dev/null 2>&1; then
    return 0
  fi

  echo "gke-gcloud-auth-plugin not found. Attempting installation..."

  if command -v apt-get >/dev/null 2>&1; then
    local sudo_cmd=""
    if [ "$(id -u)" -eq 0 ]; then
      sudo_cmd=""
    elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      sudo_cmd="sudo -n"
    else
      echo "ERROR: cannot install plugin automatically (sudo without password is not available)."
      echo "Install manually: sudo apt-get update && sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin"
      exit 1
    fi

    ${sudo_cmd} apt-get update -y
    ${sudo_cmd} apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
  elif command -v gcloud >/dev/null 2>&1; then
    gcloud components install gke-gcloud-auth-plugin --quiet
  fi

  if ! command -v gke-gcloud-auth-plugin >/dev/null 2>&1; then
    echo "ERROR: gke-gcloud-auth-plugin is still missing after attempted install."
    exit 1
  fi
}

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud is required but not installed on this Jenkins agent."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is required but not installed on this Jenkins agent."
  exit 1
fi

ensure_plugin

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

gcloud auth activate-service-account --key-file "$GCP_SA_FILE"
gcloud config set project "$GCP_PROJECT" >/dev/null
gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --region "$GKE_CLUSTER_LOCATION" --project "$GCP_PROJECT"

echo "GKE access ready: $(kubectl config current-context)"
