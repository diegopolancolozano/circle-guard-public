#!/usr/bin/env bash
set -euo pipefail

STATUS="${1:-unknown}"
WEBHOOK_URL="${PIPELINE_WEBHOOK_URL:-}"

if [ -z "$WEBHOOK_URL" ]; then
  echo "[notify] PIPELINE_WEBHOOK_URL not set; skipping notification."
  exit 0
fi

JOB_NAME_VAL="${JOB_NAME:-circleguard}"
BUILD_NUMBER_VAL="${BUILD_NUMBER:-0}"
BUILD_URL_VAL="${BUILD_URL:-}"
BRANCH_VAL="${BRANCH_NAME:-}"

payload=$(cat <<EOF
{"status":"${STATUS}","job":"${JOB_NAME_VAL}","build":"${BUILD_NUMBER_VAL}","branch":"${BRANCH_VAL}","url":"${BUILD_URL_VAL}"}
EOF
)

if command -v curl >/dev/null 2>&1; then
  curl -fsS -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" >/dev/null || true
  echo "[notify] sent status=${STATUS}"
else
  echo "[notify] curl not found; unable to send webhook."
fi
