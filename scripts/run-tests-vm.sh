#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.test.yml"

echo "Starting test environment via Docker Compose..."
docker compose -f "$COMPOSE_FILE" up --abort-on-container-exit --remove-orphans --build

# Find test-runner container exit code
CONTAINER_NAME=$(docker compose -f "$COMPOSE_FILE" ps -q test-runner)
if [ -n "$CONTAINER_NAME" ]; then
  EXIT_CODE=$(docker inspect "$CONTAINER_NAME" --format='{{.State.ExitCode}}')
  echo "test-runner exit code: $EXIT_CODE"
else
  echo "test-runner container not found"
  EXIT_CODE=1
fi

# Copy reports from container if available
REPORT_DIR="build/reports"
mkdir -p "$REPORT_DIR"
echo "Attempting to copy Gradle test reports from test-runner (if present)..."
if [ -n "$CONTAINER_NAME" ]; then
  docker cp "$CONTAINER_NAME":/workspace/build/reports/. "$REPORT_DIR" || true
fi

docker compose -f "$COMPOSE_FILE" down

exit ${EXIT_CODE:-1}
