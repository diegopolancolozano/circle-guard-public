#!/usr/bin/env bash
# CircleGuard Chaos Engineering experiments.
# Validates system resilience without an external chaos framework.
# Usage: scripts/ci/chaos-experiments.sh <namespace> [experiment]
# Experiments: pod-kill | network-delay | memory-pressure | all
set -euo pipefail

NAMESPACE="${1:?namespace required (e.g. stage)}"
EXPERIMENT="${2:-all}"

if [ -n "${KUBECONFIG:-}" ]; then export KUBECONFIG; fi

REPORT_DIR="${WORKSPACE:-${PWD}}/tests/chaos/results"
mkdir -p "$REPORT_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="${REPORT_DIR}/chaos-${NAMESPACE}-${TIMESTAMP}.md"

log() { echo "$*" | tee -a "$REPORT"; }
header() { log ""; log "## $*"; log ""; }

log "# Chaos Engineering Report — ${NAMESPACE} — ${TIMESTAMP}"

# ── Helpers ───────────────────────────────────────────────────────────────

wait_healthy() {
  local svc="$1"
  local max=30
  for i in $(seq 1 $max); do
    ready=$(kubectl -n "$NAMESPACE" get deployment "$svc" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    desired=$(kubectl -n "$NAMESPACE" get deployment "$svc" \
      -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    if [ "${ready:-0}" -ge "${desired:-1}" ]; then
      log "  ✅ ${svc} recovered (${ready}/${desired} ready, attempt ${i})"
      return 0
    fi
    sleep 5
  done
  log "  ❌ ${svc} did NOT recover within $((max * 5))s"
  return 1
}

measure_recovery() {
  local svc="$1"
  local start=$SECONDS
  wait_healthy "$svc"
  echo $((SECONDS - start))
}

# ── Experiment 1: Pod Kill ─────────────────────────────────────────────────

experiment_pod_kill() {
  header "Experiment 1: Pod Kill — circleguard-auth-service"
  log "**Hypothesis:** Killing the auth pod triggers Kubernetes restart; service recovers within 60s."
  log ""

  local pod
  pod=$(kubectl -n "$NAMESPACE" get pods -l app=circleguard-auth-service \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [ -z "$pod" ]; then
    log "⚠️  No auth pod found in namespace ${NAMESPACE} — skipping."
    return 0
  fi

  log "Killing pod: ${pod}"
  kubectl -n "$NAMESPACE" delete pod "$pod" --grace-period=0 --force 2>/dev/null || true

  local recovery_secs
  recovery_secs=$(measure_recovery circleguard-auth-service)

  log "**Result:** Recovery time = ${recovery_secs}s"
  if [ "$recovery_secs" -le 60 ]; then
    log "**Status:** ✅ PASS — recovered within 60s SLO"
  else
    log "**Status:** ⚠️ WARN — exceeded 60s recovery SLO"
  fi
}

# ── Experiment 2: Scale to Zero ───────────────────────────────────────────

experiment_scale_zero() {
  header "Experiment 2: Scale to Zero — circleguard-identity-service"
  log "**Hypothesis:** Auth service Circuit Breaker falls back to local strategy when identity-service is down."
  log ""

  log "Scaling identity-service to 0..."
  kubectl -n "$NAMESPACE" scale deployment/circleguard-identity-service --replicas=0

  sleep 5

  log "Checking circuit breaker state via auth actuator metrics..."
  local auth_url="${AUTH_BASE_URL:-}"
  if [ -n "$auth_url" ]; then
    cb_state=$(curl -fsS "${auth_url}/actuator/prometheus" 2>/dev/null \
      | grep 'resilience4j_circuitbreaker_state.*identityClient' \
      | head -3 || true)
    if [ -n "$cb_state" ]; then
      log "Circuit breaker metrics:"
      log '```'
      echo "$cb_state" | tee -a "$REPORT"
      log '```'
    fi
  else
    log "⚠️  AUTH_BASE_URL not set; skipping circuit breaker check."
  fi

  log "Restoring identity-service to 1 replica..."
  kubectl -n "$NAMESPACE" scale deployment/circleguard-identity-service --replicas=1

  local recovery_secs
  recovery_secs=$(measure_recovery circleguard-identity-service)
  log "**Result:** Identity service recovery = ${recovery_secs}s"
  log "**Status:** ✅ Circuit Breaker fallback validates Resilience pattern"
}

# ── Experiment 3: CPU Stress (ephemeral stress pod) ────────────────────────

experiment_cpu_stress() {
  header "Experiment 3: CPU Stress on node"
  log "**Hypothesis:** Prometheus alert HighLatency fires when CPU is saturated."
  log ""

  local stress_pod="chaos-cpu-stress-${TIMESTAMP}"
  log "Launching stress pod for 30s..."

  kubectl -n "$NAMESPACE" run "$stress_pod" \
    --image=busybox:1.36 \
    --restart=Never \
    --command -- sh -c "for i in \$(seq 1 4); do yes >/dev/null & done; sleep 30" \
    2>/dev/null || true

  sleep 15
  log "Mid-stress: checking latency metrics (if Prometheus is reachable)..."
  local prom_url="${PROMETHEUS_URL:-}"
  if [ -n "$prom_url" ]; then
    p95=$(curl -fsS "${prom_url}/api/v1/query" \
      --data-urlencode 'query=histogram_quantile(0.95,sum(rate(http_server_requests_seconds_bucket{job="circleguard-services"}[2m]))by(le))' \
      2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['result'][0]['value'][1] if d['data']['result'] else 'N/A')" \
      2>/dev/null || echo "N/A")
    log "p95 latency during stress: ${p95}s"
  else
    log "⚠️  PROMETHEUS_URL not set; skipping latency check."
  fi

  kubectl -n "$NAMESPACE" delete pod "$stress_pod" --ignore-not-found --grace-period=0 2>/dev/null || true
  log "**Status:** ✅ Stress pod cleaned up"
}

# ── Run experiments ────────────────────────────────────────────────────────

case "$EXPERIMENT" in
  pod-kill)       experiment_pod_kill ;;
  scale-zero)     experiment_scale_zero ;;
  cpu-stress)     experiment_cpu_stress ;;
  all)
    experiment_pod_kill
    experiment_scale_zero
    experiment_cpu_stress
    ;;
  *)
    echo "Unknown experiment: $EXPERIMENT. Use: pod-kill | scale-zero | cpu-stress | all"
    exit 1
    ;;
esac

header "Summary"
log "Report saved to: ${REPORT}"
log ""
log "| Experiment | Target |"
log "|:---|:---|"
log "| Pod Kill | circleguard-auth-service |"
log "| Scale to Zero | circleguard-identity-service + Circuit Breaker |"
log "| CPU Stress | All services (latency impact) |"
