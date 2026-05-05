#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG is required}"
: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}"
: "${DOCKERHUB_PASSWORD:?DOCKERHUB_PASSWORD is required}"
: "${DOCKERHUB_EMAIL:?DOCKERHUB_EMAIL is required}"
: "${QR_SECRET:?QR_SECRET is required}"

TF_DIR="infra/terraform"

cp "$KUBECONFIG" "$TF_DIR/kubeconfig-credentials.yaml"

# Run Terraform from an isolated container so the Jenkins agent does not require local Terraform installation.
docker run --rm \
  -v "$PWD:/workspace" \
  -w "/workspace/$TF_DIR" \
  hashicorp/terraform:1.9.8 \
  init

docker run --rm \
  -v "$PWD:/workspace" \
  -w "/workspace/$TF_DIR" \
  hashicorp/terraform:1.9.8 \
  apply -auto-approve \
  -var "kubeconfig_path=/workspace/$TF_DIR/kubeconfig-credentials.yaml" \
  -var "dockerhub_username=${DOCKERHUB_USERNAME}" \
  -var "dockerhub_password=${DOCKERHUB_PASSWORD}" \
  -var "dockerhub_email=${DOCKERHUB_EMAIL}" \
  -var "qr_secret=${QR_SECRET}"

rm -f "$TF_DIR/kubeconfig-credentials.yaml"

echo "Terraform bootstrap completed"
