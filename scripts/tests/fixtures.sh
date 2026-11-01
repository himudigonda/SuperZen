#!/usr/bin/env bash

write_changelog() {
  cat >"$1" <<'CHANGELOG'
# SuperZen Changelog

## [1.4.0] - 2026-11-01

### Changes

* Release pipeline hardened.

---

## [1.3.0] - 2026-07-20

### Fixes

* Settings save explicitly.
* Shortcuts apply immediately.

---

## [1.2.0] - 2026-07-19

* Older entry.
CHANGELOG
}

copy_project() {
  mkdir -p "$1/SuperZen.xcodeproj"
  cp "$REPO_ROOT/SuperZen.xcodeproj/project.pbxproj" "$1/SuperZen.xcodeproj/project.pbxproj"
}

set_project_version() {
  local file="$1/SuperZen.xcodeproj/project.pbxproj" tmp
  tmp="$(mktemp)"
  sed -E \
    -e "s/^([[:space:]]*MARKETING_VERSION = )[^;]+;/\\1$2;/" \
    -e "s/^([[:space:]]*CURRENT_PROJECT_VERSION = )[^;]+;/\\1$3;/" \
    "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}
