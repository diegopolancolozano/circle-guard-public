#!/usr/bin/env bash
# =============================================================================
# promote-to-prod.sh — promueve imágenes stage → prod y despliega al cluster
#
# Uso:
#   bash scripts/ci/promote-to-prod.sh <dockerhub_user> <dockerhub_pass>
#
# Qué hace:
#   1. docker pull  diegoapolancol/circleguard-*:stage
#   2. docker tag   :stage → :prod
#   3. docker push  :prod
#   4. k8s-deploy.sh prod
# =============================================================================
set -euo pipefail

DOCKERHUB_USER="${1:?dockerhub user required}"
DOCKERHUB_PASS="${2:?dockerhub password required}"
IMAGE_PREFIX="diegoapolancol/circleguard"

SERVICES=(
  auth-service
  identity-service
  promotion-service
  gateway-service
  dashboard-service
  file-service
)

# ── Login ────────────────────────────────────────────────────────────────────
echo "[promote] Docker login..."
echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin

# ── Pull stage, retag prod, push ─────────────────────────────────────────────
for svc in "${SERVICES[@]}"; do
  stage_img="${IMAGE_PREFIX}-${svc}:stage"
  prod_img="${IMAGE_PREFIX}-${svc}:prod"

  echo "[promote] ${stage_img} → ${prod_img}"
  docker pull "$stage_img"
  docker tag  "$stage_img" "$prod_img"
  docker push "$prod_img"
done

echo "[promote] Todas las imágenes promovidas a :prod"

# ── Deploy al namespace prod ─────────────────────────────────────────────────
echo "[promote] Desplegando en namespace prod..."
bash scripts/ci/k8s-deploy.sh prod

echo "[promote] PROD desplegado."
