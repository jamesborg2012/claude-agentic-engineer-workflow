#!/usr/bin/env bash
# Usage: tests/run-script-tests.sh [bats-path…]
#
# Runs shellcheck over every script, library, hook, helper and the shim, then
# the bats suite (default: tests/scripts). Both always run; the exit status is
# non-zero if either fails. shellcheck is taken from PATH, else `npx --yes shellcheck`.
set -euo pipefail

die() { echo "run-script-tests.sh: error: $*" >&2; exit 1; }

case "${1:-}" in
  -h|--help)
    sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p;}' "$0"
    exit 0 ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/.." || die "cannot find repo root"

command -v bats > /dev/null 2>&1 || die "bats not found (brew install bats-core)"
for c in jq git npx perl; do
  command -v "$c" > /dev/null 2>&1 || die "required command not found: $c"
done

if command -v shellcheck > /dev/null 2>&1 && shellcheck --version > /dev/null 2>&1; then
  sc=(shellcheck)
elif npx --yes shellcheck --version > /dev/null 2>&1; then
  sc=(npx --yes shellcheck)
else
  die "shellcheck not available (brew install shellcheck)"
fi

echo "bash: $(bash --version | head -n 1)"

shopt -s nullglob
files=(scripts/*.sh scripts/lib/*.sh scripts/hooks/*.sh tests/run-script-tests.sh tests/scripts/helpers/*.bash tests/scripts/helpers/bin/*)

rc=0
"${sc[@]}" --shell=bash -x -P SCRIPTDIR "${files[@]}" || rc=1
bats "${@:-tests/scripts}" || rc=1
exit "$rc"
