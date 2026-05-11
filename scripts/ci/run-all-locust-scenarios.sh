#!/usr/bin/env bash
set -euo pipefail

# Este script ejecuta múltiples escenarios de Locust con diferentes cargas
# para capturar métricas de degradación de performance bajo carga

ENVIRONMENT="${1:-dev}"
LOCUST_DIR="tests/performance"
RESULTS_DIR="${LOCUST_DIR}/results"
mkdir -p "$RESULTS_DIR"

echo "=========================================="
echo "Locust Multi-Scenario Performance Testing"
echo "=========================================="
echo ""

# Escenario 1: gateway_validate con 15 usuarios
echo "[Escenario 1/4] gateway_validate — 15 usuarios"
echo "-------------------------------------------"
export USERS=15
export SPAWN_RATE=2
export RUN_TIME="45s"
bash scripts/ci/run-locust.sh "$ENVIRONMENT" | tee "${RESULTS_DIR}/scenario-1-gateway-15u.log"
echo ""

# Escenario 2: gateway_validate con 50 usuarios (degradación)
echo "[Escenario 2/4] gateway_validate — 50 usuarios (DEGRADACIÓN)"
echo "-------------------------------------------"
export USERS=50
export SPAWN_RATE=5
export RUN_TIME="60s"
bash scripts/ci/run-locust.sh "$ENVIRONMENT" | tee "${RESULTS_DIR}/scenario-2-gateway-50u.log"
echo ""

# Escenario 3: mix_flow con 15 usuarios
echo "[Escenario 3/4] mix_flow — 15 usuarios"
echo "-------------------------------------------"
export USERS=15
export SPAWN_RATE=2
export RUN_TIME="45s"
bash scripts/ci/run-locust.sh "$ENVIRONMENT" | tee "${RESULTS_DIR}/scenario-3-mix-15u.log"
echo ""

# Escenario 4: mix_flow con 50 usuarios
echo "[Escenario 4/4] mix_flow — 50 usuarios (CARGA MIXTA)"
echo "-------------------------------------------"
export USERS=50
export SPAWN_RATE=5
export RUN_TIME="60s"
bash scripts/ci/run-locust.sh "$ENVIRONMENT" | tee "${RESULTS_DIR}/scenario-4-mix-50u.log"
echo ""

echo "=========================================="
echo "Resumen de resultados guardados en:"
ls -lh "${RESULTS_DIR}/scenario-*.log"
echo "=========================================="
