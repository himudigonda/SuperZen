#!/usr/bin/env bash

RELEASE_APP_NAME="SuperZen"
RELEASE_PBXPROJ="SuperZen.xcodeproj/project.pbxproj"
RELEASE_CHANGELOG="CHANGELOG.md"

release_log() {
  printf '==> %s\n' "$*" >&2
}

release_die() {
  printf 'error: %s\n' "$*" >&2
  return 1
}

release_is_semver() {
  [[ "${1:-}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

release_version_gt() {
  local candidate="$1" baseline="$2"
  local c1 c2 c3 b1 b2 b3
  IFS=. read -r c1 c2 c3 <<<"$candidate"
  IFS=. read -r b1 b2 b3 <<<"$baseline"
  if [ "$c1" -ne "$b1" ]; then [ "$c1" -gt "$b1" ]; return; fi
  if [ "$c2" -ne "$b2" ]; then [ "$c2" -gt "$b2" ]; return; fi
  [ "$c3" -gt "$b3" ]
}

release_project_value() {
  local key="$1" file="${2:-$RELEASE_PBXPROJ}"
  [ -f "$file" ] || { release_die "project file not found: $file"; return 1; }
  local values
  values="$(sed -n -E "s/^[[:space:]]*${key} = \"?([^\";]*)\"?;.*/\1/p" "$file" | sort -u)"
  if [ -z "$values" ]; then
    release_die "$key is not set in $file"
    return 1
  fi
  if [ "$(printf '%s\n' "$values" | wc -l | tr -d ' ')" -ne 1 ]; then
    release_die "$key differs across targets in $file: $(printf '%s' "$values" | tr '\n' ' ')"
    return 1
  fi
  printf '%s\n' "$values"
}

release_bump() {
  local version="$1" file="${2:-$RELEASE_PBXPROJ}"
  release_is_semver "$version" || { release_die "not a semantic version: '$version'"; return 1; }
  local current_version current_build
  current_version="$(release_project_value MARKETING_VERSION "$file")" || return 1
  current_build="$(release_project_value CURRENT_PROJECT_VERSION "$file")" || return 1
  release_is_semver "$current_version" || { release_die "project version is not semantic: $current_version"; return 1; }
  [[ "$current_build" =~ ^[0-9]+$ ]] || { release_die "build number is not an integer: $current_build"; return 1; }
  release_version_gt "$version" "$current_version" || {
    release_die "$version must be greater than the current version $current_version"
    return 1
  }
  local next_build=$((current_build + 1))
  local tmp
  tmp="$(mktemp)"
  sed -E \
    -e "s/^([[:space:]]*MARKETING_VERSION = )[^;]+;/\1${version};/" \
    -e "s/^([[:space:]]*CURRENT_PROJECT_VERSION = )[^;]+;/\1${next_build};/" \
    "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  printf '%s (%s)\n' "$version" "$next_build"
}

release_changelog_section() {
  local version="$1" file="${2:-$RELEASE_CHANGELOG}"
  [ -f "$file" ] || { release_die "changelog not found: $file"; return 1; }
  local section
  section="$(awk -v header="## [${version}]" '
    index($0, header) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
  ' "$file" | awk '
    { lines[NR] = $0 }
    END {
      first = 1
      while (first <= NR && lines[first] ~ /^[[:space:]]*$/) first++
      last = NR
      while (last >= first && (lines[last] ~ /^[[:space:]]*$/ || lines[last] ~ /^-{3,}[[:space:]]*$/)) last--
      for (i = first; i <= last; i++) print lines[i]
    }
  ')"
  if [ -z "$section" ]; then
    release_die "no notes for $version in $file (expected a '## [$version]' section)"
    return 1
  fi
  printf '%s\n' "$section"
}

release_signing_mode() {
  if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
    printf 'adhoc\n'
    return 0
  fi
  if [ -z "${APPLE_TEAM_ID:-}" ]; then
    release_die "DEVELOPER_ID_APPLICATION is set but APPLE_TEAM_ID is not"
    return 1
  fi
  printf 'developer-id\n'
}

release_notarization_mode() {
  local signing
  signing="$(release_signing_mode)" || return 1
  if [ -z "${NOTARY_APPLE_ID:-}" ] && [ -z "${NOTARY_PASSWORD:-}" ]; then
    printf 'skip\n'
    return 0
  fi
  if [ -z "${NOTARY_APPLE_ID:-}" ] || [ -z "${NOTARY_PASSWORD:-}" ]; then
    release_die "set both NOTARY_APPLE_ID and NOTARY_PASSWORD, or neither"
    return 1
  fi
  if [ "$signing" != "developer-id" ]; then
    release_die "notarization needs DEVELOPER_ID_APPLICATION and APPLE_TEAM_ID"
    return 1
  fi
  printf 'notarize\n'
}

release_notes() {
  local version="$1" changelog="${2:-$RELEASE_CHANGELOG}"
  local section notarization
  section="$(release_changelog_section "$version" "$changelog")" || return 1
  notarization="$(release_notarization_mode)" || return 1
  printf '%s\n' "$section"
  if [ "$notarization" != "notarize" ]; then
    cat <<'EOF'

## Installation note

This build is not notarized by Apple, so macOS may say SuperZen "is damaged" or "cannot be opened". Drag SuperZen into Applications, then run:

```bash
xattr -cr /Applications/SuperZen.app
```

Or open System Settings, Privacy & Security, and choose Open Anyway.
EOF
  fi
}

release_check() {
  local version="$1" pbxproj="${2:-$RELEASE_PBXPROJ}" changelog="${3:-$RELEASE_CHANGELOG}"
  release_is_semver "$version" || { release_die "not a semantic version: '$version'"; return 1; }
  local project_version
  project_version="$(release_project_value MARKETING_VERSION "$pbxproj")" || return 1
  if [ "$project_version" != "$version" ]; then
    release_die "project is at $project_version, not $version. Run 'just bump $version' and merge it first"
    return 1
  fi
  release_project_value CURRENT_PROJECT_VERSION "$pbxproj" >/dev/null || return 1
  release_changelog_section "$version" "$changelog" >/dev/null || return 1
  release_notarization_mode >/dev/null || return 1
}

release_require_clean_tree() {
  local status
  status="$(git status --porcelain --untracked-files=normal)" || return 1
  if [ -n "$status" ]; then
    release_die "working tree is not clean:
$status"
    return 1
  fi
}

release_require_synced_branch() {
  local remote="$1" branch="$2"
  local current
  current="$(git symbolic-ref --quiet --short HEAD)" || { release_die "HEAD is detached; check out $branch"; return 1; }
  if [ "$current" != "$branch" ]; then
    release_die "releases are cut from $branch, but you are on $current"
    return 1
  fi
  git fetch --quiet "$remote" "$branch" || { release_die "could not fetch $remote/$branch"; return 1; }
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse FETCH_HEAD)" ]; then
    release_die "$branch is not in sync with $remote/$branch; pull or push through a PR first"
    return 1
  fi
}

release_require_tag_absent() {
  local tag="$1" remote="${2:-}"
  if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
    release_die "tag $tag already exists locally"
    return 1
  fi
  if [ -n "$remote" ] && [ -n "$(git ls-remote --tags "$remote" "refs/tags/$tag")" ]; then
    release_die "tag $tag already exists on $remote"
    return 1
  fi
}

release_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file"
  else
    sha256sum "$file"
  fi
}

release_write_checksum() {
  local artifact="$1"
  (cd "$(dirname "$artifact")" && release_sha256 "$(basename "$artifact")") >"${artifact}.sha256"
}

release_verify_checksum() {
  local artifact="$1"
  [ -s "$artifact" ] || { release_die "artifact missing or empty: $artifact"; return 1; }
  [ -s "${artifact}.sha256" ] || { release_die "checksum missing: ${artifact}.sha256"; return 1; }
  local expected actual
  expected="$(awk '{ print $1 }' "${artifact}.sha256")"
  actual="$(release_sha256 "$artifact" | awk '{ print $1 }')"
  if [ "$expected" != "$actual" ]; then
    release_die "checksum mismatch for $artifact"
    return 1
  fi
}

release_dmg_path() {
  printf 'build/%s-%s.dmg\n' "$RELEASE_APP_NAME" "$1"
}
