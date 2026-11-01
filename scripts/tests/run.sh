#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")" || exit 1
status=0
for suite in ./*_test.sh; do
  bash "$suite" || status=1
done
exit "$status"
