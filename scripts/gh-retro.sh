#!/usr/bin/env bash
# Usage: gh-retro.sh file <retro.md> <source-repo> <run-id>
#
# Files the items of a run's retro.md to the retro repo (config retro.repo,
# required; label from retro.label, default "retro"). Never touches the
# project repo: every gh call carries --repo <retro.repo>.
#
# Each "###" heading under the "##" sections is one item; the heading is the
# issue title. Template placeholders ("### <short title>") are skipped, as are
# headings inside fenced code blocks.
#
# For each item the open issues carrying the label are searched for a title
# match (case, punctuation and whitespace ignored; lowest number wins). A match
# gets a "Seen again in <source-repo> run <run-id>" comment plus the item body;
# otherwise an issue is created with the label.
#
# Arguments:
#   <retro.md>      path to the run's retro file
#   <source-repo>   the project the run belongs to, as <owner>/<repo>
#   <run-id>        run id (N or m-N)
#
# Output (stdout), one line per item in file order:
#   commented #<n>
#   created #<n>
#
# The label is created best-effort (no --force); a failure only warns. A gh
# failure on any item stops with a non-zero exit; lines already printed stand.
#
# Exit status: 0 on success (including "no items"), 1 on error.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# Split retro.md into $1/<n>.title and $1/<n>.body; prints the item count.
parse_items() {
  local file=$1 dir=$2
  awk -v dir="$dir" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function flush(   i, a, b, t, out) {
      if (!inItem) return
      inItem = 0
      t = title
      if (t == "" || t ~ /^<.*>$/) return
      a = 1; b = nb
      while (a <= b && body[a] ~ /^[ \t]*$/) a++
      while (b >= a && body[b] ~ /^[ \t]*$/) b--
      count++
      printf "%s\n", t > (dir "/" count ".title"); close(dir "/" count ".title")
      out = dir "/" count ".body"
      printf "" > out
      for (i = a; i <= b; i++) print body[i] >> out
      close(out)
    }
    {
      sub(/\r$/, "")
      if ($0 ~ /^ ? ? ?(```|~~~)/) {
        fence = !fence
        if (inItem) body[++nb] = $0
        next
      }
      if (!fence && $0 ~ /^(#|##|###)([ \t]|$)/) {
        flush()
        if ($0 ~ /^###([ \t]|$)/) {
          inItem = 1; nb = 0
          title = trim(substr($0, 4))
        }
        next
      }
      if (inItem) body[++nb] = $0
    }
    END { flush(); print count + 0 }
  ' "$file"
}

# Normalised-title match against the issue list; prints the lowest number or nothing.
find_match() {
  jq -r --arg t "$1" '
    def norm: ascii_downcase | gsub("[[:punct:]]"; " ") | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");
    ($t | norm) as $k
    | if $k == "" then empty
      else ([.[] | select((.title | norm) == $k) | .number] | sort | .[0] // empty) end
  ' "$2"
}

cmd_file() {
  [ $# -eq 3 ] || die "usage: gh-retro.sh file <retro.md> <source-repo> <run-id>"
  local file=$1 src=$2 run=$3
  local repo_re='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
  [ -f "$file" ] || die "retro file not found: $file"
  [[ $src =~ $repo_re ]] || die "invalid source repo '$src' (expected <owner>/<repo>)"
  is_run_id "$run" || die "invalid run id: $run"

  local repo label
  repo=$(config_get retro.repo) || exit 1
  label=$(config_get retro.label) || exit 1
  [[ $repo =~ $repo_re ]] || die "invalid retro.repo '$repo' (expected <owner>/<repo>)"

  local tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/aew-retro.XXXXXX") || die "cannot create a temp directory"
  # shellcheck disable=SC2064  # expand now: the path is fixed
  trap "rm -rf '$tmp'" EXIT

  local count
  count=$(parse_items "$file" "$tmp") || die "cannot parse $file"
  if [ "$count" -eq 0 ]; then
    info "no retro items to file in $file"
    return 0
  fi

  local out
  if ! out=$(gh label create "$label" --repo "$repo" --color 0E8A16 --description "Retro item filed by aew" 2>&1); then
    warn "could not create label '$label' in $repo (continuing): $out"
  fi

  gh issue list --repo "$repo" --label "$label" --state open --limit 500 --json number,title > "$tmp/open.json" || die "gh issue list failed"

  local i title n url num next
  i=1
  while [ "$i" -le "$count" ]; do
    title=$(cat "$tmp/$i.title") || exit 1
    n=$(find_match "$title" "$tmp/open.json") || die "cannot match titles"
    {
      if [ -n "$n" ]; then
        printf 'Seen again in %s run %s\n' "$src" "$run"
        if [ -s "$tmp/$i.body" ]; then printf '\n'; cat "$tmp/$i.body"; fi
      else
        if [ -s "$tmp/$i.body" ]; then cat "$tmp/$i.body"; printf '\n'; fi
        printf 'Filed by aew from %s run %s.\n' "$src" "$run"
      fi
    } > "$tmp/$i.msg" || die "cannot write temp file"
    if [ -n "$n" ]; then
      gh issue comment "$n" --repo "$repo" --body-file "$tmp/$i.msg" > /dev/null || die "gh issue comment failed for #$n"
      printf 'commented #%s\n' "$n"
    else
      url=$(gh issue create --repo "$repo" --title "$title" --label "$label" --body-file "$tmp/$i.msg") || die "gh issue create failed for '$title'"
      num=${url##*/issues/}
      [[ $num =~ ^[0-9]+$ ]] || die "cannot parse an issue number from: $url"
      next=$(jq --argjson n "$num" --arg t "$title" '. + [{number: $n, title: $t}]' "$tmp/open.json") || die "cannot update the issue list"
      printf '%s\n' "$next" > "$tmp/open.json"
      printf 'created #%s\n' "$num"
    fi
    i=$((i + 1))
  done
}

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
  "") die "missing subcommand (see --help)" ;;
esac

require_cmd gh jq awk

case "$1" in
  file)
    shift
    cmd_file "$@"
    ;;
  -*) die "unknown option: $1 (see --help)" ;;
  *) die "unknown subcommand: $1 (see --help)" ;;
esac
