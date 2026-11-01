#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib/release.sh

usage() {
  cat >&2 <<'USAGE'
usage: scripts/release.sh <command> [version]

  version          print the project's marketing version and build number
  bump <version>   set the marketing version and increment the build number
  check <version>  verify the project, changelog and signing config are ready
  notes <version>  print GitHub release notes for a version
USAGE
  exit 64
}

require_version_arg() {
  [ -n "${1:-}" ] || usage
}

command="${1:-}"
case "$command" in
  version)
    printf '%s (%s)\n' \
      "$(release_project_value MARKETING_VERSION)" \
      "$(release_project_value CURRENT_PROJECT_VERSION)"
    ;;
  bump)
    require_version_arg "${2:-}"
    result="$(release_bump "$2")"
    release_log "project bumped to $result"
    release_log "add a '## [$2]' section to $RELEASE_CHANGELOG, then merge both through a PR"
    ;;
  check)
    require_version_arg "${2:-}"
    release_check "$2"
    release_log "$2 is ready: signing $(release_signing_mode), notarization $(release_notarization_mode)"
    ;;
  notes)
    require_version_arg "${2:-}"
    release_notes "$2"
    ;;
  *)
    usage
    ;;
esac
