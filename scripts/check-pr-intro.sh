#!/usr/bin/env bash
# Usage: check-pr-intro.sh <pr-body.md> [--issues <n>]
#
# Check that a PR body opens with a plain-English introduction. Pure text
# check: no gh, no run state, no network. The orchestrator runs it before a PR
# is created or updated and may re-dispatch the doc-writer once on failure.
#
# The introduction is the text under the first "## In plain English" line, up
# to the next line starting "## " (or the end of the file). HTML comments are
# stripped from the whole body first. Only that section is checked; the
# technical sections after it may use backticks, paths and AC ids freely.
#
# Checks (every violation prints one "FAIL: <reason>" line on stdout):
#   - "## In plain English" is the first "##" heading (else nothing else is checked)
#   - word count: 100-250 for one issue; with --issues n > 1 the minimum is
#     100 and the maximum 80 x n + 80
#   - no backticks, no file paths, no AC-/TC-/WP- identifiers, no tables,
#     no headings inside the section
#
# Options:
#   --issues <n>   number of issues the PR closes (default 1)
#   -h, --help
#
# Exit status: 0 pass; 1 a check failed (or no argument / unknown option, as
# for every aew script); 2 unreadable file or invalid --issues value (message
# on stderr).

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

require_cmd awk grep wc mktemp

# usage_error <msg>: exit 2, message on stderr (die would exit 1).
usage_error() {
  printf '%s: error: %s\n' "${0##*/}" "$*" >&2
  exit 2
}

FILE=""
ISSUES=1
while [ $# -gt 0 ]; do
  case "$1" in
    --issues)
      [ $# -ge 2 ] || usage_error "--issues needs a value"
      ISSUES=$2
      shift 2
      ;;
    -*) die "unknown option: $1" ;;
    *)
      [ -z "$FILE" ] || die "unexpected argument: $1"
      FILE=$1
      shift
      ;;
  esac
done
[ -n "$FILE" ] || die "missing <pr-body.md> (see --help)"
[ -f "$FILE" ] && [ -r "$FILE" ] || usage_error "no such file: $FILE"
case "$ISSUES" in
  '' | *[!0-9]* | 0*) usage_error "invalid --issues value: $ISSUES (want a positive integer)" ;;
esac

TMP=$(mktemp -d) || die "cannot create a temporary directory"
trap 'rm -rf "$TMP"' EXIT
BODY=$TMP/body
SECTION=$TMP/section

# Strip HTML comments (single or multi-line) from the whole body.
awk '
  {
    line = $0; out = ""
    while (1) {
      if (inc) {
        p = index(line, "-->")
        if (!p) { line = ""; break }
        line = substr(line, p + 3); inc = 0
      } else {
        p = index(line, "<!--")
        if (!p) { out = out line; break }
        out = out substr(line, 1, p - 1); line = substr(line, p + 4); inc = 1
      }
    }
    print out
  }' "$FILE" > "$BODY" || die "cannot read $FILE"

FAILED=0
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILED=1
}

# The first "##" heading must be the introduction.
FIRST=$(grep -m 1 '^## ' "$BODY" || true)
FIRST_TRIMMED=$(printf '%s' "$FIRST" | sed 's/[[:space:]]*$//')
if [ "$FIRST_TRIMMED" != "## In plain English" ]; then
  if grep -q '^## In plain English[[:space:]]*$' "$BODY"; then
    fail "'## In plain English' must be the first ## section (found '$FIRST_TRIMMED' first)"
  else
    fail "no '## In plain English' section found"
  fi
  exit 1
fi

# Section text: after the first heading, up to the next "## " line.
awk '
  !seen && /^## / { seen = 1; next }
  seen && /^## / { exit }
  seen { print }' "$BODY" > "$SECTION"

WORDS=$(wc -w < "$SECTION" | tr -d '[:space:]')
MAX=250
if [ "$ISSUES" -gt 1 ]; then MAX=$((80 * ISSUES + 80)); fi
if [ "$WORDS" -lt 100 ]; then
  fail "introduction is $WORDS words, minimum is 100"
elif [ "$WORDS" -gt "$MAX" ]; then
  fail "introduction is $WORDS words, maximum is $MAX"
fi

if grep -q '`' "$SECTION"; then
  fail "introduction contains a backtick"
fi

PATH_TOKEN='[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*\.[A-Za-z0-9]{1,5}'
PATH_DIR='(^|[^A-Za-z0-9])(src|docs|app|lib|tests?|scripts|templates|skills|agents|hooks|node_modules|\.aew|\.claude)/'
HIT=$(grep -oE "$PATH_TOKEN" "$SECTION" | head -n 1 || true)
if [ -z "$HIT" ]; then
  HIT=$(grep -oE "${PATH_DIR}[A-Za-z0-9_./-]*" "$SECTION" | head -n 1 | sed 's/^[^A-Za-z.]//' || true)
fi
if [ -n "$HIT" ]; then
  fail "introduction contains a file path: $HIT"
fi

HIT=$(grep -oE '(AC|TC|WP)-[0-9]+' "$SECTION" | head -n 1 || true)
if [ -n "$HIT" ]; then
  fail "introduction contains an AC/TC/WP identifier: $HIT"
fi

if grep -qE '^[[:space:]]*\|' "$SECTION" ||
  grep -E '\|' "$SECTION" | grep -qE '^[[:space:]]*[-|:[:space:]]*-[-|:[:space:]]*$'; then
  fail "introduction contains a table"
fi

HIT=$(grep -m 1 -E '^#{1,6}[[:space:]]' "$SECTION" || true)
if [ -n "$HIT" ]; then
  fail "introduction contains a heading: $HIT"
fi

[ "$FAILED" -eq 0 ] || exit 1
exit 0
