#!/usr/bin/env bash
set -euo pipefail

BASE_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
if [ -z "$BASE_TAG" ]; then
  BASE_VERSION="0.1.0"
  COMMITS="$(git log --pretty=%s || true)"
else
  BASE_VERSION="${BASE_TAG#v}"
  COMMITS="$(git log "${BASE_TAG}..HEAD" --pretty=%s || true)"
fi

if [ -z "${COMMITS// }" ]; then
  echo "$BASE_VERSION"
  exit 0
fi

bump="patch"
if echo "$COMMITS" | grep -Eqi 'BREAKING CHANGE|!:'; then
  bump="major"
elif echo "$COMMITS" | grep -Eqi '^feat'; then
  bump="minor"
elif echo "$COMMITS" | grep -Eqi '^(fix|perf|refactor)'; then
  bump="patch"
fi

IFS='.' read -r major minor patch <<< "$BASE_VERSION"
major=${major:-0}
minor=${minor:-0}
patch=${patch:-0}

case "$bump" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
esac

echo "${major}.${minor}.${patch}"
