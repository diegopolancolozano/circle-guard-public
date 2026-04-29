#!/usr/bin/env bash
set -euo pipefail

LAST_TAG=""
if git describe --tags --abbrev=0 > /dev/null 2>&1; then
  LAST_TAG="$(git describe --tags --abbrev=0)"
fi

if [[ -n "$LAST_TAG" ]]; then
  RANGE="${LAST_TAG}..HEAD"
else
  RANGE="HEAD"
fi

TITLE="Release Notes"
DATE_STR="$(date -u +%Y-%m-%d)"

FEATURES=""
FIXES=""
DOCS=""
CHORE=""
REFACTOR=""
TESTS=""
PERF=""
CI=""
BUILD=""
OTHER=""

while IFS= read -r line; do
  if [[ "$line" =~ ^([a-z]+)(\([^\)]+\))?:\ (.+)$ ]]; then
    type="${BASH_REMATCH[1]}"
    scope="${BASH_REMATCH[2]}"
    msg="${BASH_REMATCH[3]}"
    entry="- ${type}${scope}: ${msg}"

    case "$type" in
      feat) FEATURES+="$entry\n" ;;
      fix) FIXES+="$entry\n" ;;
      docs) DOCS+="$entry\n" ;;
      chore) CHORE+="$entry\n" ;;
      refactor) REFACTOR+="$entry\n" ;;
      test) TESTS+="$entry\n" ;;
      perf) PERF+="$entry\n" ;;
      ci) CI+="$entry\n" ;;
      build) BUILD+="$entry\n" ;;
      *) OTHER+="- ${line}\n" ;;
    esac
  else
    OTHER+="- ${line}\n"
  fi

done < <(git log "$RANGE" --pretty=format:'%s')

{
  echo "# ${TITLE} (${DATE_STR})"
  echo ""
  if [[ -n "$LAST_TAG" ]]; then
    echo "Base tag: ${LAST_TAG}"
    echo ""
  fi

  if [[ -n "$FEATURES" ]]; then
    echo "## Features"
    echo -e "$FEATURES"
  fi
  if [[ -n "$FIXES" ]]; then
    echo "## Fixes"
    echo -e "$FIXES"
  fi
  if [[ -n "$DOCS" ]]; then
    echo "## Docs"
    echo -e "$DOCS"
  fi
  if [[ -n "$REFACTOR" ]]; then
    echo "## Refactor"
    echo -e "$REFACTOR"
  fi
  if [[ -n "$PERF" ]]; then
    echo "## Performance"
    echo -e "$PERF"
  fi
  if [[ -n "$TESTS" ]]; then
    echo "## Tests"
    echo -e "$TESTS"
  fi
  if [[ -n "$CI" ]]; then
    echo "## CI"
    echo -e "$CI"
  fi
  if [[ -n "$BUILD" ]]; then
    echo "## Build"
    echo -e "$BUILD"
  fi
  if [[ -n "$CHORE" ]]; then
    echo "## Chore"
    echo -e "$CHORE"
  fi
  if [[ -n "$OTHER" ]]; then
    echo "## Other"
    echo -e "$OTHER"
  fi
} > release-notes.md

echo "Generated release-notes.md"
