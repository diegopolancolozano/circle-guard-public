#!/usr/bin/env bash
# =============================================================================
# demo-start.sh — Levanta port-forwards para la demo y los mata después de N min
#
# Uso:
#   bash scripts/demo/demo-start.sh          # mantiene todo corriendo (Ctrl+C para parar)
#   bash scripts/demo/demo-start.sh 30       # para automáticamente en 30 minutos
# =============================================================================
set -euo pipefail

MINUTES="${1:-0}"
SERVER="root@104.248.109.57"
REMOTE_SCRIPT="/tmp/demo-pf.sh"

echo "========================================================"
echo "  CircleGuard Demo Setup"
echo "========================================================"

# ── Verificar pods stage ──────────────────────────────────────────────────────
echo "[1/3] Verificando pods en stage..."
ssh "$SERVER" "kubectl get pods -n stage --no-headers | grep -v Running | grep -v Completed" 2>/dev/null | \
  grep . && echo "  ⚠  Algunos pods no están Running — espera 30s e intenta de nuevo" || \
  echo "  ✓  Todos los pods Running"

# ── Matar port-forwards viejos ────────────────────────────────────────────────
echo "[2/3] Limpiando port-forwards anteriores..."
ssh "$SERVER" "pkill -f 'kubectl.*port-forward' 2>/dev/null || true; sleep 1"

# ── Levantar port-forwards ────────────────────────────────────────────────────
echo "[3/3] Levantando port-forwards..."
ssh "$SERVER" "
  nohup kubectl -n stage port-forward --address 0.0.0.0 svc/circleguard-gateway-service 8082:8080 > /tmp/pf-app.log 2>&1 &
  nohup kubectl -n monitoring port-forward --address 0.0.0.0 svc/grafana 3000:3000 > /tmp/pf-grafana.log 2>&1 &
  nohup kubectl -n monitoring port-forward --address 0.0.0.0 svc/prometheus 9090:9090 > /tmp/pf-prom.log 2>&1 &
  sleep 2
  echo 'Port-forwards activos:'
  ps aux | grep 'kubectl.*port-forward' | grep -v grep | awk '{print \"  \" \$NF}'
"

echo ""
echo "========================================================"
echo "  URLs listas — abre SSH tunnel en otra terminal:"
echo ""
echo "  ssh -L 8082:localhost:8082 -L 3000:localhost:3000 \\"
echo "      -L 9090:localhost:9090 -N $SERVER"
echo ""
echo "  App      → http://localhost:8082/actuator/health"
echo "  Grafana  → http://localhost:3000  (admin/admin)"
echo "  Prom.    → http://localhost:9090/targets"
echo "  Jenkins  → http://104.248.109.57:8080"
echo "========================================================"

# ── Teardown automático ───────────────────────────────────────────────────────
if [ "$MINUTES" -gt 0 ] 2>/dev/null; then
  echo ""
  echo "  ⏱  Se detendrá automáticamente en $MINUTES minutos."
  echo "  Ctrl+C para cancelar el teardown."
  sleep "${MINUTES}m"
  echo ""
  echo "Parando port-forwards..."
  ssh "$SERVER" "pkill -f 'kubectl.*port-forward' 2>/dev/null || true"
  echo "Demo finalizada."
else
  echo ""
  echo "  Sin límite de tiempo. Ejecuta demo-stop.sh para parar."
fi
