#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  printf '    %s\n' "$*" >&2
  return 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "expected [$2] but got [$1]"
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "expected output to contain [$2], got: $1" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "expected output not to contain [$2], got: $1" ;;
    *) ;;
  esac
}

assert_fails() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure from: $*"
  fi
}

clear_signing_env() {
  unset DEVELOPER_ID_APPLICATION APPLE_TEAM_ID NOTARY_APPLE_ID NOTARY_PASSWORD
}

run_suite() {
  local suite="$1" passed=0 failed=0 name rc
  for name in $(declare -F | awk '{ print $3 }' | grep '^test_'); do
    (
      set -eu
      TEST_TMP="$(mktemp -d)"
      trap 'rm -rf "$TEST_TMP"' EXIT
      clear_signing_env
      cd "$TEST_TMP"
      "$name"
    )
    rc=$?
    if [ "$rc" -eq 0 ]; then
      passed=$((passed + 1))
      printf 'ok   %s\n' "$name"
    else
      failed=$((failed + 1))
      printf 'FAIL %s\n' "$name"
    fi
  done
  printf '%s: %d passed, %d failed\n' "$suite" "$passed" "$failed"
  [ "$failed" -eq 0 ]
}
