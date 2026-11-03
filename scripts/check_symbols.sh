#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib/release.sh

[ $# -ge 1 ] || { release_die "usage: $0 <mach-o binary>..."; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/resolve.c" <<'C'
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
  for (int i = 1; i < argc; i++) dlopen(argv[i], RTLD_LAZY | RTLD_GLOBAL);
  char line[8192];
  int missing = 0;
  while (fgets(line, sizeof line, stdin)) {
    line[strcspn(line, "\n")] = 0;
    if (!line[0]) continue;
    if (!dlsym(RTLD_DEFAULT, line[0] == '_' ? line + 1 : line)) {
      printf("%s\n", line);
      missing++;
    }
  }
  return missing ? 1 : 0;
}
C
xcrun clang -o "$WORK/resolve" "$WORK/resolve.c"

status=0
for binary in "$@"; do
  [ -f "$binary" ] || { release_die "no binary at $binary"; exit 1; }
  read -ra libs <<<"$(otool -L "$binary" | tail -n +2 | awk '{print $1}' | grep -v '^@' | tr '\n' ' ')"
  if missing="$(nm -m -u "$binary" | awk '/\(undefined\) external/ { print $3 }' | "$WORK/resolve" "${libs[@]}")"; then
    release_log "all imported symbols of $(basename "$binary") resolve on $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  else
    printf 'error: %s imports symbols this macOS does not export; it crashes when they are called:\n' "$(basename "$binary")" >&2
    while read -r symbol; do
      printf '  %s  %s\n' "$symbol" "$(xcrun swift-demangle --compact "$symbol")" >&2
    done <<<"$missing"
    status=1
  fi
done
exit "$status"
