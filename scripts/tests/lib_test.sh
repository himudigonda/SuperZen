#!/usr/bin/env bash

source "$(dirname "$0")/harness.sh"
source "$(dirname "$0")/fixtures.sh"
source "$REPO_ROOT/scripts/lib/release.sh"

PBX="SuperZen.xcodeproj/project.pbxproj"

test_semver_accepts_plain_versions() {
  release_is_semver 1.4.0
  release_is_semver 0.0.1
  release_is_semver 10.20.30
}

test_semver_rejects_malformed_versions() {
  assert_fails release_is_semver ""
  assert_fails release_is_semver v1.4.0
  assert_fails release_is_semver 1.4
  assert_fails release_is_semver 1.4.0-beta
  assert_fails release_is_semver 01.4.0
  assert_fails release_is_semver "1.4.0; rm -rf /"
}

test_version_comparison_is_numeric() {
  release_version_gt 1.10.0 1.9.9
  release_version_gt 2.0.0 1.99.99
  release_version_gt 1.3.1 1.3.0
  assert_fails release_version_gt 1.3.0 1.3.0
  assert_fails release_version_gt 1.2.9 1.3.0
  assert_fails release_version_gt 1.9.0 1.10.0
}

test_project_values_are_read_from_the_real_project() {
  copy_project .
  set_project_version . 1.3.0 14
  assert_eq "$(release_project_value MARKETING_VERSION "$PBX")" 1.3.0
  assert_eq "$(release_project_value CURRENT_PROJECT_VERSION "$PBX")" 14
}

test_project_value_rejects_drift_between_targets() {
  copy_project .
  set_project_version . 1.3.0 14
  awk 'done == 0 && /MARKETING_VERSION = 1.3.0;/ { sub(/1.3.0/, "1.2.0"); done = 1 } { print }' "$PBX" >drifted
  assert_fails release_project_value MARKETING_VERSION drifted
  assert_fails release_project_value MARKETING_VERSION missing.pbxproj
}

test_bump_sets_version_and_increments_build_everywhere() {
  copy_project .
  set_project_version . 1.3.0 14
  assert_eq "$(release_bump 1.4.0 "$PBX")" "1.4.0 (15)"
  assert_eq "$(grep -c 'MARKETING_VERSION = 1.4.0;' "$PBX")" 6
  assert_eq "$(grep -c 'CURRENT_PROJECT_VERSION = 15;' "$PBX")" 6
  assert_eq "$(grep -c 'MARKETING_VERSION = 1.3.0;' "$PBX")" 0
}

test_bump_only_touches_version_lines() {
  copy_project .
  set_project_version . 1.3.0 14
  cp "$PBX" before
  release_bump 1.3.1 "$PBX" >/dev/null
  assert_eq "$(diff before "$PBX" | grep -c '^[<>]')" 24
  assert_eq "$(diff before "$PBX" | grep '^>' | grep -vcE 'MARKETING_VERSION = 1.3.1;|CURRENT_PROJECT_VERSION = 15;')" 0
}

test_bump_refuses_same_older_or_malformed_versions() {
  copy_project .
  set_project_version . 1.3.0 14
  cp "$PBX" before
  assert_fails release_bump 1.3.0 "$PBX"
  assert_fails release_bump 1.2.9 "$PBX"
  assert_fails release_bump v1.4.0 "$PBX"
  assert_eq "$(cmp before "$PBX" && echo same)" same
}

test_changelog_section_is_trimmed_to_one_version() {
  write_changelog CHANGELOG.md
  local notes
  notes="$(release_changelog_section 1.3.0 CHANGELOG.md)"
  assert_eq "$(printf '%s\n' "$notes" | head -n1)" "### Fixes"
  assert_eq "$(printf '%s\n' "$notes" | tail -n1)" "* Shortcuts apply immediately."
  assert_not_contains "$notes" "1.2.0"
  assert_not_contains "$notes" "---"
}

test_changelog_last_section_reads_to_end_of_file() {
  write_changelog CHANGELOG.md
  assert_eq "$(release_changelog_section 1.2.0 CHANGELOG.md)" "* Older entry."
}

test_changelog_missing_or_prefix_versions_fail() {
  write_changelog CHANGELOG.md
  assert_fails release_changelog_section 1.5.0 CHANGELOG.md
  assert_fails release_changelog_section 1.3 CHANGELOG.md
  assert_fails release_changelog_section 1.3.0 missing.md
  printf '## [1.6.0] - 2026-12-01\n\n---\n' >empty.md
  assert_fails release_changelog_section 1.6.0 empty.md
}

test_signing_defaults_to_adhoc() {
  assert_eq "$(release_signing_mode)" adhoc
  assert_eq "$(release_notarization_mode)" skip
}

test_signing_uses_developer_id_when_configured() {
  export DEVELOPER_ID_APPLICATION="Developer ID Application: Test (ABCDE12345)" APPLE_TEAM_ID=ABCDE12345
  assert_eq "$(release_signing_mode)" developer-id
  assert_eq "$(release_notarization_mode)" skip
  export NOTARY_APPLE_ID=dev@example.com NOTARY_PASSWORD=secret
  assert_eq "$(release_notarization_mode)" notarize
}

test_partial_signing_config_is_an_error() {
  export DEVELOPER_ID_APPLICATION="Developer ID Application: Test (ABCDE12345)"
  assert_fails release_signing_mode
  unset DEVELOPER_ID_APPLICATION
  export NOTARY_APPLE_ID=dev@example.com
  assert_fails release_notarization_mode
  export NOTARY_PASSWORD=secret
  assert_fails release_notarization_mode
}

test_notes_add_install_note_only_when_not_notarized() {
  write_changelog CHANGELOG.md
  local notes
  notes="$(release_notes 1.4.0 CHANGELOG.md)"
  assert_contains "$notes" "Release pipeline hardened."
  assert_contains "$notes" "xattr -cr /Applications/SuperZen.app"
  export DEVELOPER_ID_APPLICATION="Developer ID Application: Test (ABCDE12345)" APPLE_TEAM_ID=ABCDE12345
  export NOTARY_APPLE_ID=dev@example.com NOTARY_PASSWORD=secret
  notes="$(release_notes 1.4.0 CHANGELOG.md)"
  assert_contains "$notes" "Release pipeline hardened."
  assert_not_contains "$notes" "xattr"
}

test_check_requires_matching_project_and_changelog() {
  copy_project .
  set_project_version . 1.4.0 15
  write_changelog CHANGELOG.md
  release_check 1.4.0 "$PBX" CHANGELOG.md
  assert_fails release_check 1.5.0 "$PBX" CHANGELOG.md
  set_project_version . 1.5.0 16
  assert_fails release_check 1.5.0 "$PBX" CHANGELOG.md
}

test_check_rejects_broken_signing_config() {
  copy_project .
  set_project_version . 1.4.0 15
  write_changelog CHANGELOG.md
  export NOTARY_APPLE_ID=dev@example.com NOTARY_PASSWORD=secret
  assert_fails release_check 1.4.0 "$PBX" CHANGELOG.md
}

test_checksum_round_trip_and_tamper_detection() {
  mkdir build
  printf 'dmg-bytes' >build/SuperZen-1.4.0.dmg
  release_write_checksum build/SuperZen-1.4.0.dmg
  assert_contains "$(cat build/SuperZen-1.4.0.dmg.sha256)" "  SuperZen-1.4.0.dmg"
  release_verify_checksum build/SuperZen-1.4.0.dmg
  printf 'tampered' >build/SuperZen-1.4.0.dmg
  assert_fails release_verify_checksum build/SuperZen-1.4.0.dmg
  assert_fails release_verify_checksum build/missing.dmg
}

test_dmg_path_matches_release_asset_name() {
  assert_eq "$(release_dmg_path 1.4.0)" build/SuperZen-1.4.0.dmg
}

run_suite lib
