#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-unknown}"

if [ -n "${WORKSPACE:-}" ]; then
  RESULTS_DIR="${WORKSPACE}/tests/performance/results"
elif [ -d "${PWD}/tests/performance/results" ]; then
  RESULTS_DIR="${PWD}/tests/performance/results"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  RESULTS_DIR="${REPO_ROOT}/tests/performance/results"
fi

mkdir -p "${RESULTS_DIR}/metrics"

LATEST_STATS="$(ls -1t "${RESULTS_DIR}"/locust-*_stats.csv 2>/dev/null | head -1 || true)"
if [ -z "${LATEST_STATS}" ]; then
  echo "ERROR: No Locust stats CSV found in ${RESULTS_DIR}" >&2
  exit 1
fi

TMP_METRICS="$(mktemp)"

awk -F',' '
function strip(v) { gsub(/^"|"$/, "", v); return v }
NR == 1 {
  for (i = 1; i <= NF; i++) {
    key = strip($i)
    idx[key] = i
  }
  next
}
{
  type = strip($1)
  name = strip($2)
  if (type == "Aggregated" || name == "Aggregated") {
    req = strip($(idx["Request Count"]))
    fail = strip($(idx["Failure Count"]))
    avg = strip($(idx["Average Response Time"]))
    p95 = strip($(idx["95%"])); if (p95 == "") p95 = strip($(idx["95%ile"]))
    rps = strip($(idx["Requests/s"]))
    print req "\t" fail "\t" avg "\t" p95 "\t" rps
    found = 1
    exit
  }
}
END {
  if (!found) exit 2
}
' "${LATEST_STATS}" > "${TMP_METRICS}"

if [ ! -s "${TMP_METRICS}" ]; then
  echo "ERROR: Could not extract aggregated metrics from ${LATEST_STATS}" >&2
  rm -f "${TMP_METRICS}"
  exit 1
fi

IFS=$'\t' read -r REQUEST_COUNT FAILURE_COUNT AVG_MS P95_MS THROUGHPUT_RPS < "${TMP_METRICS}"
rm -f "${TMP_METRICS}"

if [ -z "${REQUEST_COUNT}" ] || [ "${REQUEST_COUNT}" = "0" ]; then
  ERROR_RATE="0"
else
  ERROR_RATE="$(awk -v f="${FAILURE_COUNT:-0}" -v r="${REQUEST_COUNT}" 'BEGIN { printf "%.4f", (f/r)*100 }')"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_MD="${RESULTS_DIR}/metrics/performance-summary-${ENVIRONMENT}-${TIMESTAMP}.md"
OUT_JSON="${RESULTS_DIR}/metrics/performance-summary-${ENVIRONMENT}-${TIMESTAMP}.json"

cat > "${OUT_MD}" <<EOF
# Performance Summary (${ENVIRONMENT})

- Source CSV: $(basename "${LATEST_STATS}")
- Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

| Metric | Value |
|---|---|
| Average response time (ms) | ${AVG_MS} |
| P95 response time (ms) | ${P95_MS} |
| Throughput (req/s) | ${THROUGHPUT_RPS} |
| Error rate (%) | ${ERROR_RATE} |
| Total requests | ${REQUEST_COUNT} |
| Total failures | ${FAILURE_COUNT} |
EOF

cat > "${OUT_JSON}" <<EOF
{
  "environment": "${ENVIRONMENT}",
  "source_csv": "$(basename "${LATEST_STATS}")",
  "generated_at_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "average_response_time_ms": "${AVG_MS}",
  "p95_response_time_ms": "${P95_MS}",
  "throughput_rps": "${THROUGHPUT_RPS}",
  "error_rate_percent": "${ERROR_RATE}",
  "total_requests": "${REQUEST_COUNT}",
  "total_failures": "${FAILURE_COUNT}"
}
EOF

echo "Performance metrics summary created: ${OUT_MD}"
echo "Performance metrics JSON created: ${OUT_JSON}"
echo "Key metrics => avg_ms=${AVG_MS}, p95_ms=${P95_MS}, throughput_rps=${THROUGHPUT_RPS}, error_rate_pct=${ERROR_RATE}"
