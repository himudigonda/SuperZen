#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib/release.sh

VERSION="${1:-}"
REMOTE="${RELEASE_REMOTE:-origin}"
BRANCH="${RELEASE_BRANCH:-main}"
DMG_BUILDER="${RELEASE_DMG_BUILDER:-scripts/create_dmg.sh}"

[ -n "$VERSION" ] || { release_die "usage: scripts/ship.sh <version>"; exit 64; }
TAG="v$VERSION"

release_log "preflight for $TAG"
release_check "$VERSION"
release_require_clean_tree
release_require_synced_branch "$REMOTE" "$BRANCH"
release_require_tag_absent "$TAG" "$REMOTE"

release_log "building release artifacts"
"$DMG_BUILDER" "$VERSION"

DMG="$(release_dmg_path "$VERSION")"
release_verify_checksum "$DMG"
release_require_clean_tree

release_log "tagging $TAG at $(git rev-parse --short HEAD)"
git tag -a "$TAG" -m "$RELEASE_APP_NAME $TAG"
if ! git push "$REMOTE" "refs/tags/$TAG"; then
  git tag -d "$TAG" >/dev/null
  release_die "could not push $TAG; the local tag was removed so you can retry"
  exit 1
fi

release_log "pushed $TAG; the Release workflow will build, sign when configured, and publish it"
release_log "local artifacts: $DMG and $DMG.sha256"
