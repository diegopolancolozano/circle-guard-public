#!/usr/bin/env bash
# =============================================================================
# setup-mesh.sh — instala Istio + Kiali y configura el service mesh
#                 para CircleGuard (mTLS, circuit breakers, canary routing).
#
# Uso:
#   bash scripts/ci/setup-mesh.sh [namespace]
#   bash scripts/ci/setup-mesh.sh stage   # por defecto
#
# Pre-requisitos:
#   - kubectl apuntando al cluster
#   - curl disponible (para descargar istioctl)
# =============================================================================
set -euo pipefail

NAMESPACE="${1:-stage}"
ISTIO_VERSION="1.21.2"

# ── 1. Descargar istioctl ────────────────────────────────────────────────────
if ! command -v istioctl &>/dev/null; then
  echo "[mesh] Descargando istioctl ${ISTIO_VERSION}..."
  curl -sL https://istio.io/downloadIstio | ISTIO_VERSION="${ISTIO_VERSION}" sh -
  export PATH="$PWD/istio-${ISTIO_VERSION}/bin:$PATH"
  echo "[mesh] istioctl instalado: $(istioctl version --remote=false 2>/dev/null || true)"
else
  echo "[mesh] istioctl ya disponible: $(istioctl version --remote=false 2>/dev/null || true)"
fi

# ── 2. Instalar Istio (minimal profile para reducir recursos) ────────────────
echo "[mesh] Instalando Istio con perfil minimal..."
istioctl install --set profile=minimal -y

echo "[mesh] Esperando que istiod esté listo..."
kubectl -n istio-system wait --for=condition=Available deployment/istiod --timeout=180s

# ── 3. Habilitar inyección de sidecars en los namespaces ────────────────────
echo "[mesh] Habilitando sidecar injection en dev, stage, prod..."
for ns in dev stage prod; do
  kubectl label namespace "$ns" istio-injection=enabled --overwrite 2>/dev/null || true
done

# ── 4. Aplicar mTLS STRICT ──────────────────────────────────────────────────
echo "[mesh] Aplicando PeerAuthentication (mTLS STRICT)..."
kubectl apply -f k8s/mesh/peer-authentication.yaml

# ── 5. Aplicar DestinationRules y VirtualServices ───────────────────────────
echo "[mesh] Aplicando DestinationRules (circuit breakers)..."
kubectl apply -f k8s/mesh/destination-rules.yaml

echo "[mesh] Aplicando VirtualServices (retry + canary routing)..."
kubectl apply -f k8s/mesh/virtual-services.yaml

# ── 6. Instalar Kiali ────────────────────────────────────────────────────────
echo "[mesh] Instalando Kiali..."
kubectl apply -f k8s/mesh/kiali.yaml

echo "[mesh] Esperando que Kiali esté listo..."
kubectl -n istio-system wait --for=condition=Available deployment/kiali --timeout=120s || true

# ── 7. Reiniciar pods para inyectar sidecars ─────────────────────────────────
echo "[mesh] Reiniciando pods en ${NAMESPACE} para inyectar sidecars Envoy..."
for svc in \
  circleguard-auth-service \
  circleguard-identity-service \
  circleguard-promotion-service \
  circleguard-gateway-service \
  circleguard-dashboard-service \
  circleguard-file-service; do
  kubectl -n "$NAMESPACE" rollout restart "deployment/${svc}" 2>/dev/null || true
done

# ── 8. Verificar ────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo " Service Mesh setup completo"
echo "======================================================"
echo " Istio:       $(istioctl version --remote=false 2>/dev/null || echo 'ver arriba')"
echo " Namespace:   ${NAMESPACE}"
echo ""
echo " Ver sidecars:"
echo "   kubectl -n ${NAMESPACE} get pods -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.containers[*].name}{\"\n\"}{end}'"
echo ""
echo " Ver estado mTLS:"
echo "   istioctl -n ${NAMESPACE} x describe pod \$(kubectl -n ${NAMESPACE} get pod -l app=circleguard-auth-service -o name | head -1 | cut -d/ -f2)"
echo ""
echo " Abrir Kiali:"
echo "   kubectl -n istio-system port-forward svc/kiali 20001:20001"
echo "   http://localhost:20001/kiali"
echo ""
echo " Canary gateway (90% stable / 10% canary):"
echo "   kubectl -n ${NAMESPACE} get virtualservice circleguard-gateway-service -o yaml"
echo "======================================================"
