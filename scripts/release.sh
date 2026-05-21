#!/usr/bin/env bash
# Tag and ship a release.
#
# Reads the version from Sources/clipslots/main.swift, validates that
# CHANGELOG.md has a matching section, then tags vX.Y.Z, pushes, and
# watches the release workflow.
#
# Assumes the feature PR is already squash-merged and you have pulled
# the latest main. Run from anywhere inside the repo.

set -euo pipefail

# --- Locate repo root ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: not inside a git repository" >&2
    exit 1
}
cd "$REPO_ROOT"

# --- Preflight ---
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ]; then
    echo "error: must be on 'main' (currently on '$BRANCH')" >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: working tree has uncommitted changes" >&2
    git status --short >&2
    exit 1
fi

echo "Fetching origin..."
git fetch origin --quiet

LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse @{u})"
if [ "$LOCAL" != "$REMOTE" ]; then
    echo "error: local main is not in sync with origin/main" >&2
    echo "  local : $LOCAL" >&2
    echo "  remote: $REMOTE" >&2
    echo "Run: git pull --ff-only" >&2
    exit 1
fi

# --- Extract version from main.swift ---
VERSION_LINE="$(grep -E '^\s*version: "[0-9]+\.[0-9]+\.[0-9]+"' Sources/clipslots/main.swift || true)"
if [ -z "$VERSION_LINE" ]; then
    echo "error: could not find version line in Sources/clipslots/main.swift" >&2
    exit 1
fi
VERSION="$(echo "$VERSION_LINE" | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')"
TAG="v$VERSION"
echo "Version: $VERSION"

# --- Validate CHANGELOG section ---
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
    echo "error: CHANGELOG.md has no '## [$VERSION]' section" >&2
    echo "Add the section + a link reference at the bottom, commit, push, then retry." >&2
    exit 1
fi
if ! grep -q "^\[$VERSION\]: " CHANGELOG.md; then
    echo "error: CHANGELOG.md has no '[$VERSION]: <url>' link reference at the bottom" >&2
    exit 1
fi

# --- Tag collision check ---
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG already exists locally" >&2
    exit 1
fi
if git ls-remote --tags origin "refs/tags/$TAG" | grep -q "$TAG"; then
    echo "error: tag $TAG already exists on origin" >&2
    exit 1
fi

# --- Confirm ---
echo
read -r -p "Release $TAG? [y/N] " REPLY
case "$REPLY" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
esac

# --- Tag, push, watch ---
echo "Tagging $TAG..."
git tag "$TAG"

echo "Pushing tag..."
git push origin "$TAG"

echo "Waiting for release workflow to register..."
sleep 3

RUN_ID="$(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
    echo "warning: could not find workflow run; check manually with 'gh run list'" >&2
    exit 0
fi

echo "Watching run $RUN_ID..."
gh run watch "$RUN_ID" --exit-status

echo
echo "Released $TAG. View it: gh release view $TAG --web"
