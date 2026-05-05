#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG is required}"
: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}"
: "${DOCKERHUB_PASSWORD:?DOCKERHUB_PASSWORD is required}"
: "${DOCKERHUB_EMAIL:?DOCKERHUB_EMAIL is required}"
: "${QR_SECRET:?QR_SECRET is required}"

# Optional GCP service account JSON. Can be provided as the content in GCP_SA_JSON
# or as a path in GCP_SA_FILE. When present and GCP_PROJECT/GKE_CLUSTER_NAME
# are set, the script will enable use_gke and instruct Terraform to obtain
# cluster data from GKE.
GCP_SA_JSON=${GCP_SA_JSON:-}
GCP_SA_FILE=${GCP_SA_FILE:-}
GCP_PROJECT=${GCP_PROJECT:-}
GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME:-}
GKE_CLUSTER_LOCATION=${GKE_CLUSTER_LOCATION:-}

TF_DIR="infra/terraform"

cp "$KUBECONFIG" "$TF_DIR/kubeconfig-credentials.yaml"

# If GCP service account provided, write it into the terraform dir so the
# container can access it via the mounted workspace.
GCP_SA_PATH=""
if [ -n "$GCP_SA_JSON" ]; then
  echo "$GCP_SA_JSON" > "$TF_DIR/gcp-sa.json"
  GCP_SA_PATH="$TF_DIR/gcp-sa.json"
elif [ -n "$GCP_SA_FILE" ] && [ -f "$GCP_SA_FILE" ]; then
  cp "$GCP_SA_FILE" "$TF_DIR/gcp-sa.json"
  GCP_SA_PATH="$TF_DIR/gcp-sa.json"
fi

# Run Terraform from an isolated container so the Jenkins agent does not require local Terraform installation.
DOCKER_ENV_ARGS=()
if [ -n "$GCP_SA_PATH" ]; then
  # Tell the container where the credentials file will be inside the mounted workspace
  DOCKER_ENV_ARGS+=( -e "GOOGLE_APPLICATION_CREDENTIALS=/workspace/$GCP_SA_PATH" )
fi

docker run --rm \
  "${DOCKER_ENV_ARGS[@]}" \
  -v "$PWD:/workspace" \
  -w "/workspace/$TF_DIR" \
  hashicorp/terraform:1.9.8 \
  init

TF_VARS=( -var "kubeconfig_path=/workspace/$TF_DIR/kubeconfig-credentials.yaml" \
          -var "dockerhub_username=${DOCKERHUB_USERNAME}" \
          -var "dockerhub_password=${DOCKERHUB_PASSWORD}" \
          -var "dockerhub_email=${DOCKERHUB_EMAIL}" \
          -var "qr_secret=${QR_SECRET}" )

# If GCP info provided enable use_gke and pass cluster details to Terraform
if [ -n "$GCP_SA_PATH" ] && [ -n "$GCP_PROJECT" ] && [ -n "$GKE_CLUSTER_NAME" ] && [ -n "$GKE_CLUSTER_LOCATION" ]; then
  TF_VARS+=( -var "use_gke=true" )
  TF_VARS+=( -var "gcp_project=${GCP_PROJECT}" )
  TF_VARS+=( -var "gke_cluster_name=${GKE_CLUSTER_NAME}" )
  TF_VARS+=( -var "gke_cluster_location=${GKE_CLUSTER_LOCATION}" )
  # Ensure container has GOOGLE_APPLICATION_CREDENTIALS set
  DOCKER_ENV_ARGS+=( -e "GOOGLE_APPLICATION_CREDENTIALS=/workspace/$GCP_SA_PATH" )
fi

docker run --rm \
  "${DOCKER_ENV_ARGS[@]}" \
  -v "$PWD:/workspace" \
  -w "/workspace/$TF_DIR" \
  hashicorp/terraform:1.9.8 \
  apply -auto-approve "${TF_VARS[@]}"

rm -f "$TF_DIR/kubeconfig-credentials.yaml"
if [ -n "$GCP_SA_PATH" ]; then
  rm -f "$TF_DIR/gcp-sa.json"
fi

echo "Terraform bootstrap completed"
