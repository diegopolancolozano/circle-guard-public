#!/usr/bin/env bash
# =============================================================================
# setup-tls.sh — instala ingress-nginx + cert-manager y configura TLS
#                para circleguard-gateway-service en stage y prod.
#
# Uso:
#   bash scripts/ci/setup-tls.sh                   # usa nip.io (sin dominio)
#   bash scripts/ci/setup-tls.sh mydomain.com      # usa dominio propio
#
# Pre-requisitos:
#   - kubectl apuntando al cluster de destino
#   - helm instalado
# =============================================================================
set -euo pipefail

CUSTOM_DOMAIN="${1:-}"

# ── 1. ingress-nginx controller ─────────────────────────────────────────────
echo "[tls] Instalando ingress-nginx..."
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/do/deploy.yaml
else
  echo "[tls] ingress-nginx ya existe, actualizando..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/do/deploy.yaml
fi

echo "[tls] Esperando LoadBalancer IP (puede tardar 1-2 min)..."
LB_IP=""
for i in $(seq 1 30); do
  LB_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -n "$LB_IP" ]]; then
    echo "[tls] LoadBalancer IP: ${LB_IP}"
    break
  fi
  echo "[tls] Esperando... (intento ${i}/30)"
  sleep 10
done

if [[ -z "$LB_IP" ]]; then
  echo "ERROR: No se pudo obtener la IP del LoadBalancer. Verifica el estado de ingress-nginx."
  exit 1
fi

# ── 2. Determinar dominio ────────────────────────────────────────────────────
if [[ -n "$CUSTOM_DOMAIN" ]]; then
  GATEWAY_DOMAIN="$CUSTOM_DOMAIN"
  echo "[tls] Usando dominio personalizado: ${GATEWAY_DOMAIN}"
  echo "[tls] Asegúrate de que el DNS de ${GATEWAY_DOMAIN} apunte a ${LB_IP}"
else
  GATEWAY_DOMAIN="gateway.${LB_IP}.nip.io"
  echo "[tls] Usando nip.io (sin dominio propio): ${GATEWAY_DOMAIN}"
fi

export GATEWAY_DOMAIN
export LB_IP

# ── 3. cert-manager ──────────────────────────────────────────────────────────
CERT_MANAGER_VERSION="v1.14.5"
echo "[tls] Instalando cert-manager ${CERT_MANAGER_VERSION}..."
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

echo "[tls] Esperando que cert-manager esté listo..."
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager --timeout=120s
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-webhook --timeout=120s
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-cainjector --timeout=120s
sleep 10  # give webhook time to register

# ── 4. ClusterIssuers ─────────────────────────────────────────────────────────
echo "[tls] Aplicando ClusterIssuers (Let's Encrypt)..."
kubectl apply -f k8s/tls/cluster-issuer.yaml

# ── 5. Ingress con TLS ──────────────────────────────────────────────────────
echo "[tls] Aplicando Ingress para gateway (stage + prod)..."
envsubst < k8s/tls/ingress.yaml | kubectl apply -f -

# ── 6. Resumen ──────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo " TLS setup completo"
echo "======================================================"
echo " LoadBalancer IP : ${LB_IP}"
echo " Gateway HTTPS   : https://${GATEWAY_DOMAIN}"
echo ""
echo " Verificar certificado:"
echo "   kubectl -n stage get certificate"
echo "   kubectl -n stage describe certificaterequest"
echo ""
echo " Una vez que el certificado de staging funcione, cambiar"
echo " la anotación en k8s/tls/ingress.yaml a letsencrypt-prod"
echo " y volver a aplicar:"
echo "   envsubst < k8s/tls/ingress.yaml | kubectl apply -f -"
echo "======================================================"
