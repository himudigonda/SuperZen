#!/usr/bin/env bash

source "$(dirname "$0")/harness.sh"
source "$(dirname "$0")/fixtures.sh"

export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

setup_release_repo() {
  git init --quiet --bare -b main remote.git
  git init --quiet -b main work
  mkdir -p work/scripts/lib
  cp "$REPO_ROOT/scripts/ship.sh" "$REPO_ROOT/scripts/release.sh" work/scripts/
  cp "$REPO_ROOT/scripts/lib/release.sh" work/scripts/lib/
  cat >work/scripts/fake_dmg.sh <<'BUILDER'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib/release.sh
printf '%s\n' "$1" >>build/builder-calls
[ -z "${FAKE_BUILDER_FAILS:-}" ] || exit 3
printf 'dmg %s' "$1" >"$(release_dmg_path "$1")"
release_write_checksum "$(release_dmg_path "$1")"
[ -z "${FAKE_BUILDER_DIRTIES_TREE:-}" ] || touch stray.txt
BUILDER
  chmod +x work/scripts/fake_dmg.sh
  copy_project work
  set_project_version work 1.4.0 15
  write_changelog work/CHANGELOG.md
  printf 'build/\n' >work/.gitignore
  mkdir -p work/build
  git -C work add -A
  git -C work commit --quiet -m init
  git -C work remote add origin "$PWD/remote.git"
  git -C work push --quiet origin main
  export RELEASE_DMG_BUILDER=scripts/fake_dmg.sh
}

ship() {
  work/scripts/ship.sh "$@" 2>&1
}

remote_tags() {
  git --git-dir=remote.git tag --list
}

test_ship_builds_then_pushes_only_the_tag() {
  setup_release_repo
  local main_before
  main_before="$(git --git-dir=remote.git rev-parse main)"
  ship 1.4.0 >log
  assert_eq "$(remote_tags)" v1.4.0
  assert_eq "$(git --git-dir=remote.git rev-parse main)" "$main_before"
  assert_eq "$(git --git-dir=remote.git rev-parse 'v1.4.0^{commit}')" "$main_before"
  assert_eq "$(git --git-dir=remote.git cat-file -t v1.4.0)" tag
  assert_eq "$(cat work/build/builder-calls)" 1.4.0
  assert_eq "$(git -C work status --porcelain)" ""
}

test_ship_requires_a_version() {
  setup_release_repo
  assert_fails ship
  assert_eq "$(remote_tags)" ""
}

test_ship_refuses_a_version_the_project_is_not_at() {
  setup_release_repo
  assert_fails ship 1.5.0
  assert_eq "$(remote_tags)" ""
  [ ! -f work/build/builder-calls ]
}

test_ship_refuses_without_changelog_notes() {
  setup_release_repo
  set_project_version work 1.5.0 16
  git -C work commit --quiet -am "bump"
  git -C work push --quiet origin main
  assert_fails ship 1.5.0
  assert_eq "$(remote_tags)" ""
}

test_ship_refuses_a_dirty_tree() {
  setup_release_repo
  printf 'wip' >work/notes.txt
  assert_fails ship 1.4.0
  assert_eq "$(remote_tags)" ""
  [ ! -f work/build/builder-calls ]
}

test_ship_refuses_branches_other_than_main() {
  setup_release_repo
  git -C work checkout --quiet -b feature
  assert_fails ship 1.4.0
  assert_eq "$(remote_tags)" ""
}

test_ship_refuses_when_main_is_ahead_of_remote() {
  setup_release_repo
  git -C work commit --quiet --allow-empty -m "local only"
  assert_fails ship 1.4.0
  assert_eq "$(remote_tags)" ""
}

test_ship_refuses_an_existing_remote_tag() {
  setup_release_repo
  git -C work tag v1.4.0
  git -C work push --quiet origin v1.4.0
  git -C work tag -d v1.4.0 >/dev/null
  assert_fails ship 1.4.0
  [ ! -f work/build/builder-calls ]
}

test_ship_does_not_tag_when_the_build_fails() {
  setup_release_repo
  export FAKE_BUILDER_FAILS=1
  assert_fails ship 1.4.0
  assert_eq "$(remote_tags)" ""
  assert_eq "$(git -C work tag --list)" ""
}

test_ship_does_not_tag_when_the_build_dirties_the_tree() {
  setup_release_repo
  export FAKE_BUILDER_DIRTIES_TREE=1
  assert_fails ship 1.4.0
  assert_eq "$(remote_tags)" ""
}

test_ship_rejects_broken_signing_config_before_building() {
  setup_release_repo
  export NOTARY_APPLE_ID=dev@example.com
  assert_fails ship 1.4.0
  [ ! -f work/build/builder-calls ]
}

test_ship_drops_the_local_tag_when_push_fails() {
  setup_release_repo
  printf '#!/bin/sh\nexit 1\n' >remote.git/hooks/pre-receive
  chmod +x remote.git/hooks/pre-receive
  assert_fails ship 1.4.0
  assert_eq "$(git -C work tag --list)" ""
}

test_release_cli_bumps_and_reports_version() {
  setup_release_repo
  assert_eq "$(work/scripts/release.sh version)" "1.4.0 (15)"
  work/scripts/release.sh bump 1.4.1 2>/dev/null
  assert_eq "$(work/scripts/release.sh version)" "1.4.1 (16)"
  assert_fails work/scripts/release.sh bump 1.4.1
  assert_fails work/scripts/release.sh
}

test_release_cli_check_and_notes() {
  setup_release_repo
  work/scripts/release.sh check 1.4.0 2>/dev/null
  assert_fails work/scripts/release.sh check 1.3.0
  assert_contains "$(work/scripts/release.sh notes 1.4.0)" "Release pipeline hardened."
}

run_suite ship
