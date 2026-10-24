#!/usr/bin/env bash
# Usage: detect-stack.sh [path]
#        detect-stack.sh fingerprint <profile> [path]
#
# Detects the stacks in a project tree (default: the current directory) and
# prints one JSON array of {profile, path, version, evidence} on one line:
# one entry per (profile, path), path relative to the scanned root ("." for
# the root), ordered by path ("." first), base profiles before overlays, then
# profile name. No stacks prints [].
#
# Profiles: nextjs, react, laravel, wordpress, dotnet; overlays tailwind and
# woocommerce (woocommerce only where wordpress is at its path or below it).
# Scans to depth 3 and skips node_modules, vendor, .git, dist, build, out,
# .next, .turbo, coverage, bin and obj. version is the declared version with
# range operators stripped, or "unknown". Each evidence string starts with the
# path that triggered the rule.
#
# fingerprint: scans [path] the same way, takes the first <profile> entry and
# prints "<profile> <dep>@<major>... cfg:<hash12>". cfg is the first 12 hex
# characters of SHA-256 over the profile's tool configs in that entry's dir
# and the scanned root (sorted relative path NUL content NUL). Manifests are
# not hashed; tracked majors are listed instead.
#
# Exit 1 with error: on stderr for a missing or unreadable directory, an
# unknown option, extra arguments, or a fingerprint profile not detected.
# Limits: heuristic; nothing deeper than depth 3 is seen; paths containing a
# tab or newline are not supported.
# Options: -h, --help

# The jq and awk programs are single-quoted on purpose: their $ is not the shell's.
# shellcheck disable=SC2016
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

# --- arguments -------------------------------------------------------------
MODE=detect
PROFILE=
if [ "${1:-}" = fingerprint ]; then
  MODE=fingerprint
  shift
  [ "$#" -gt 0 ] || die "fingerprint needs a profile"
  case "$1" in
    -?*) die "unknown option: $1" ;;
  esac
  PROFILE=$1
  shift
fi
NPOS=0
ROOT=.
for a in "$@"; do
  case "$a" in
    -?*) die "unknown option: $a" ;;
  esac
  NPOS=$((NPOS + 1))
  [ "$NPOS" -le 1 ] || die "too many arguments"
  ROOT=$a
done
[ -n "$ROOT" ] || die "empty path"
[ -d "$ROOT" ] || die "not a directory: $ROOT"
{ [ -r "$ROOT" ] && [ -x "$ROOT" ]; } || die "cannot read directory: $ROOT"
require_cmd jq find
# A relative path gets "./" so cd neither searches CDPATH nor reads "-" as
# $OLDPWD; either would scan another tree and print its name to stdout.
case "$ROOT" in
  /*) cd "$ROOT" || die "cannot enter directory: $ROOT" ;;
  *) cd "./$ROOT" || die "cannot enter directory: $ROOT" ;;
esac

TMP=$(mktemp -d) || die "cannot create a temporary directory"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/rec"
for f in plugins headers hdrin php css twcss; do : > "$TMP/$f"; done

# --- helpers ---------------------------------------------------------------

# norm_version <spec>: "^16.0.1" -> 16.0.1, ">=15.1 <17" -> 15.1, "latest" -> unknown.
norm_version() {
  local v=$1 re='^[0-9]+(\.[0-9]+)*'
  while :; do
    case "$v" in
      [[:space:]]* | '^'* | '~'* | '>'* | '='* | '<'* | v*) v=${v#?} ;;
      *) break ;;
    esac
  done
  if [[ $v =~ $re ]]; then printf '%s' "${BASH_REMATCH[0]}"; else printf 'unknown'; fi
  return 0
}

# nearest_root <dir>: first dir upward (to the root) holding package.json or
# composer.json, else <dir> itself.
nearest_root() {
  local d=$1
  while :; do
    if [ -f "./$d/package.json" ] || [ -f "./$d/composer.json" ]; then
      printf '%s' "$d"
      return 0
    fi
    [ "$d" != "." ] || break
    case "$d" in
      */*) d=${d%/*} ;;
      *) d=. ;;
    esac
  done
  printf '%s' "$1"
  return 0
}

# sln_dir <dir>: first dir upward (to the root) holding a *.sln, else <dir>.
sln_dir() {
  local d=$1 m
  shopt -s nullglob
  while :; do
    m=(./"$d"/*.sln)
    if [ "${#m[@]}" -gt 0 ]; then
      shopt -u nullglob
      printf '%s' "$d"
      return 0
    fi
    [ "$d" != "." ] || break
    case "$d" in
      */*) d=${d%/*} ;;
      *) d=. ;;
    esac
  done
  shopt -u nullglob
  printf '%s' "$1"
  return 0
}

# add <rank> <profile> <path> <version> <evidence>: a lower rank wins the version.
add() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$TMP/rec"
  return 0
}

# wp_core_version <dir>: $wp_version from <dir>/wp-includes/version.php, else unknown.
wp_core_version() {
  local f="./$1/wp-includes/version.php" line re
  re="^[[:space:]]*[\$]wp_version[[:space:]]*=[[:space:]]*['\"]([^'\"]*)['\"]"
  if [ -f "$f" ] && [ -r "$f" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ $line =~ $re ]]; then
        norm_version "${BASH_REMATCH[1]}"
        return 0
      fi
    done < "$f"
  fi
  printf 'unknown'
  return 0
}

# --- scan ------------------------------------------------------------------
# find runs on its own: an unreadable subdirectory makes it exit non-zero, which
# must warn and carry on rather than abort through set -e / pipefail.
find . -mindepth 1 -maxdepth 3 \
  \( -type d \( -name node_modules -o -name vendor -o -name .git -o -name dist \
  -o -name build -o -name out -o -name .next -o -name .turbo -o -name coverage \
  -o -name bin -o -name obj \) -prune \) -o -print > "$TMP/find.out" 2> "$TMP/find.err" || true
sed 's|^\./||' "$TMP/find.out" | LC_ALL=C sort > "$TMP/files"
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] || warn "$line"
done < "$TMP/find.err"

JQ_PKG='((.devDependencies // {}) + (.dependencies // {})) | to_entries[]
  | select(.key == "next" or .key == "react" or .key == "tailwindcss" or (.key | startswith("@woocommerce/")))
  | [.key, (.value | tostring)] | @tsv'
JQ_COMPOSER='(((.require // {}) | to_entries | map(select(.key == "laravel/framework" or .key == "woocommerce/woocommerce" or .key == "wpackagist-plugin/woocommerce")))
  + ((."require-dev" // {}) | to_entries | map(select(.key == "woocommerce/woocommerce" or .key == "wpackagist-plugin/woocommerce"))))[]
  | [.key, (.value | tostring)] | @tsv'

# manifest <rel> <jq filter>: prints the filter's output, or warns and returns 1.
manifest() {
  local out
  if out=$(jq -r "$2" "$1" 2> /dev/null); then
    [ -z "$out" ] || printf '%s\n' "$out"
    return 0
  fi
  warn "skipping $1: invalid JSON"
  return 1
}

while IFS= read -r rel || [ -n "$rel" ]; do
  [ -n "$rel" ] || continue
  base=${rel##*/}
  case "$rel" in */*) dir=${rel%/*} ;; *) dir=. ;; esac
  if [ -d "$rel" ]; then
    if [ "$base" = "wp-content" ]; then
      add 1 wordpress "$dir" "$(wp_core_version "$dir")" "$rel/"
    fi
    continue
  fi
  [ -f "$rel" ] && [ -r "$rel" ] || continue

  case "$base" in
    package.json)
      if out=$(manifest "$rel" "$JQ_PKG"); then
        has_next=0
        deps=""
        while IFS=$'\t' read -r k v; do
          [ -n "$k" ] || continue
          deps="$deps$k"$'\t'"$v"$'\n'
          [ "$k" != next ] || has_next=1
        done <<< "$out"
        while IFS=$'\t' read -r k v; do
          [ -n "$k" ] || continue
          case "$k" in
            next) add 1 nextjs "$dir" "$(norm_version "$v")" "$rel: next $v" ;;
            react) [ "$has_next" -eq 1 ] || add 1 react "$dir" "$(norm_version "$v")" "$rel: react $v" ;;
            tailwindcss) add 1 tailwind "$dir" "$(norm_version "$v")" "$rel: tailwindcss $v" ;;
            *) add 1 woocommerce "$dir" unknown "$rel: $k $v" ;;
          esac
        done <<< "$deps"
      fi
      ;;
    composer.json)
      if out=$(manifest "$rel" "$JQ_COMPOSER"); then
        while IFS=$'\t' read -r k v; do
          [ -n "$k" ] || continue
          case "$k" in
            laravel/framework) add 1 laravel "$dir" "$(norm_version "$v")" "$rel: $k $v" ;;
            *) add 2 woocommerce "$dir" "$(norm_version "$v")" "$rel: $k $v" ;;
          esac
        done <<< "$out"
      fi
      ;;
    tailwind.config.*) add 1 tailwind "$(nearest_root "$dir")" unknown "$rel" ;;
    wp-config.php) add 1 wordpress "$dir" "$(wp_core_version "$dir")" "$rel" ;;
    *.sln) add 1 dotnet "$dir" unknown "$rel" ;;
    *.csproj)
      tf=$(grep -E -o '<TargetFrameworks?>[^<]*<' "$rel" | head -n 1 || true)
      ver=unknown
      re='(^|[>;])net([0-9]+(\.[0-9]+)*)'
      if [[ $tf =~ $re ]]; then ver=${BASH_REMATCH[2]}; fi
      add 1 dotnet "$(sln_dir "$dir")" "$ver" "$rel"
      ;;
  esac

  case "$base" in
    *.php)
      printf '%s\n' "$rel" >> "$TMP/hdrin"
      printf '%s\n' "$rel" >> "$TMP/php"
      ;;
    style.css)
      printf '%s\n' "$rel" >> "$TMP/hdrin"
      printf '%s\n' "$rel" >> "$TMP/css"
      ;;
    *.css) printf '%s\n' "$rel" >> "$TMP/css" ;;
  esac
done < "$TMP/files"

# --- second pass: a fixed number of forks, whatever the tree size -------------
HDR_AWK='BEGIN { pre = "^([[:space:]]*<[?]php)?[[:space:]/*#@]*"
        nk = split("plugin name|theme name|requires at least|requires php|wc requires at least|wc tested up to", k, "|") }
function flush(  i, o) {
  if (cur == "" || !(((cur ~ /\.php$/) ? 1 : 2) in v)) return
  o = cur; for (i = 3; i <= nk; i++) o = o "\t" ((i in v) ? v[i] : "-"); print o }
FNR == 1 { flush(); cur = FILENAME; sub(/^\.\//, "", cur); off = 0; split("", v) }
off >= 8192 { nextfile }
{ off += length($0) + 1; l = tolower($0)
  for (i = 1; i <= nk; i++) if (!(i in v) && match(l, pre k[i] ":")) {
    s = substr($0, RSTART + RLENGTH); gsub(/\t/, " ", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); if (s != "") v[i] = s } }
END { flush() }'
TW_RE='@import[[:space:]]+["'"'"']tailwindcss(/[^"'"'"']*)?["'"'"']'
HOOK_RE='add_(action|filter)[[:space:]]*\([[:space:]]*["'"'"']woocommerce_'

# Header pass: Plugin Name / Theme Name files, with their version headers.
if [ -s "$TMP/hdrin" ]; then
  sed 's|^|./|' "$TMP/hdrin" | tr '\n' '\0' | LC_ALL=C xargs -0 awk "$HDR_AWK" > "$TMP/hdrs" || true
  # rp (Requires PHP) is read for the field count; the fingerprint uses it later.
  # shellcheck disable=SC2034
  while IFS=$'\t' read -r f ra rp wr wt; do
    [ -n "$f" ] || continue
    case "$f" in */*) d=${f%/*} ;; *) d=. ;; esac
    case "$f" in
      *.php)
        what="Plugin Name"
        printf '%s\n' "$d" >> "$TMP/plugins"
        ;;
      *) what="Theme Name" ;;
    esac
    add 1 wordpress "$d" "$(norm_version "$ra")" "$f: $what"
    printf '%s\t%s\n' "$d" "$f" >> "$TMP/headers"
    if [ "$wr" != "-" ]; then
      add 1 woocommerce "$d" "$(norm_version "$wr")" "$f: WC requires at least"
    elif [ "$wt" != "-" ]; then
      add 1 woocommerce "$d" unknown "$f: WC tested up to"
    fi
  done < "$TMP/hdrs"
fi

# Tailwind CSS: files that import tailwindcss, at their nearest package root.
if [ -s "$TMP/css" ]; then
  sed 's|^|./|' "$TMP/css" | tr '\n' '\0' | xargs -0 grep -l -E -- "$TW_RE" > "$TMP/twcss.raw" || true
  sed 's|^\./||' "$TMP/twcss.raw" > "$TMP/twcss"
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    case "$f" in */*) d=${f%/*} ;; *) d=. ;; esac
    add 1 tailwind "$(nearest_root "$d")" unknown "$f: @import \"tailwindcss\""
  done < "$TMP/twcss"
fi

# woocommerce_ hooks in PHP files under a plugin path.
if [ -s "$TMP/plugins" ] && [ -s "$TMP/php" ]; then
  : > "$TMP/plphp"
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    while IFS= read -r p || [ -n "$p" ]; do
      if [ "$p" = "." ]; then under=1; else
        case "$f" in "$p"/*) under=1 ;; *) under=0 ;; esac
      fi
      if [ "$under" -eq 1 ]; then
        printf '%s\n' "$f" >> "$TMP/plphp"
        break
      fi
    done < "$TMP/plugins"
  done < "$TMP/php"
  if [ -s "$TMP/plphp" ]; then
    sed 's|^|./|' "$TMP/plphp" | tr '\n' '\0' | xargs -0 grep -l -E -- "$HOOK_RE" > "$TMP/hooked.raw" || true
    sed 's|^\./||' "$TMP/hooked.raw" > "$TMP/hooked"
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      while IFS= read -r p || [ -n "$p" ]; do
        if [ "$p" = "." ]; then under=1; else
          case "$f" in "$p"/*) under=1 ;; *) under=0 ;; esac
        fi
        if [ "$under" -eq 1 ]; then add 2 woocommerce "$p" unknown "$f: woocommerce_ hook"; fi
      done < "$TMP/plugins"
    done < "$TMP/hooked"
  fi
fi

# --- merge and print ---------------------------------------------------------
# detect_json: the merged records as one compact JSON array on stdout.
detect_json() {
  jq -n -c --rawfile rec "$TMP/rec" '
  ($rec | split("\n") | map(select(length > 0) | split("\t")
    | {rank: (.[0] | tonumber), profile: .[1], path: .[2], version: .[3], evidence: .[4]})) as $r
  | ($r | group_by([.path, .profile]) | map({
      profile: .[0].profile,
      path: .[0].path,
      version: ((map(select(.version != "unknown")) | sort_by(.rank) | first | .version) // "unknown"),
      evidence: (map(.evidence) | unique)})) as $all
  | ($all | map(select(.profile == "wordpress") | .path)) as $wp
  | $all
  | map(select(.profile != "woocommerce"
      or (.path as $p | any($wp[]; . == $p or $p == "." or startswith($p + "/")))))
  | sort_by([(.path != "."), .path, (if .profile == "tailwind" or .profile == "woocommerce" then 1 else 0 end), .profile])
  | map({profile, path, version, evidence})'
}

if [ "$MODE" = detect ]; then
  detect_json
  exit 0
fi

# --- fingerprint -------------------------------------------------------------
# major <version>: the leading digit run, or unknown.
major() {
  case $1 in
    unknown) printf 'unknown' ;;
    *) printf '%s' "${1%%.*}" ;;
  esac
  return 0
}

# pkg_dep <dir> <dep>: the declared spec from <dir>/package.json, or nothing.
pkg_dep() {
  jq -r --arg k "$2" '(.dependencies // {})[$k] // (.devDependencies // {})[$k] // empty | tostring' \
    "./$1/package.json" 2> /dev/null || true
  return 0
}

JSON=$(detect_json) || die "detection failed"
FIRST=$(printf '%s' "$JSON" | jq -r --arg p "$PROFILE" \
  'map(select(.profile == $p)) | first // empty | [.path, .version] | @tsv') || die "detection failed"
[ -n "$FIRST" ] || die "profile not detected: $PROFILE"
IFS=$'\t' read -r EPATH EVER <<< "$FIRST"

# Tracked deps: the primary comes from the entry version, the rest from manifests.
LINE="$PROFILE"
dep() { LINE="$LINE $1@$2"; return 0; }
secondary() { # <name> <spec>: omitted when undeclared
  [ -z "$2" ] || dep "$1" "$(major "$(norm_version "$2")")"
  return 0
}
php_spec() {
  local spec="" f rp
  if [ -f "./$EPATH/composer.json" ]; then
    spec=$(jq -r '(.require // {}).php // empty | tostring' "./$EPATH/composer.json" 2> /dev/null || true)
  fi
  if [ -z "$spec" ] && [ "$PROFILE" = wordpress ]; then
    f=$(awk -F'\t' -v d="$EPATH" '$1 == d { print $2; exit }' "$TMP/headers")
    if [ -n "$f" ]; then
      rp=$(awk -F'\t' -v f="$f" '$1 == f { print $3; exit }' "$TMP/hdrs")
      if [ "$rp" != "-" ]; then spec=$rp; fi
    fi
  fi
  printf '%s' "$spec"
  return 0
}
case "$PROFILE" in
  nextjs)
    dep next "$(major "$EVER")"
    secondary react "$(pkg_dep "$EPATH" react)"
    secondary typescript "$(pkg_dep "$EPATH" typescript)"
    CFGS='eslint.config.* .eslintrc* .prettierrc* prettier.config.* tsconfig.json .editorconfig'
    ;;
  react)
    dep react "$(major "$EVER")"
    secondary typescript "$(pkg_dep "$EPATH" typescript)"
    CFGS='eslint.config.* .eslintrc* .prettierrc* prettier.config.* tsconfig.json .editorconfig'
    ;;
  tailwind)
    dep tailwindcss "$(major "$EVER")"
    CFGS='tailwind.config.* .stylelintrc* stylelint.config.* .editorconfig'
    ;;
  laravel)
    dep laravel/framework "$(major "$EVER")"
    secondary php "$(php_spec)"
    CFGS='pint.json phpstan.neon phpstan.neon.dist phpcs.xml phpcs.xml.dist .editorconfig'
    ;;
  wordpress)
    dep wordpress "$(major "$EVER")"
    secondary php "$(php_spec)"
    CFGS='phpcs.xml phpcs.xml.dist .phpcs.xml .phpcs.xml.dist phpstan.neon phpstan.neon.dist eslint.config.* .eslintrc* .stylelintrc* stylelint.config.* .editorconfig'
    ;;
  woocommerce)
    dep woocommerce "$(major "$EVER")"
    CFGS='phpcs.xml phpcs.xml.dist .phpcs.xml .phpcs.xml.dist phpstan.neon phpstan.neon.dist .editorconfig'
    ;;
  dotnet)
    dep dotnet "$(major "$EVER")"
    CFGS='Directory.Build.props .csharpierrc* .editorconfig'
    ;;
  *) die "profile not detected: $PROFILE" ;;
esac

# Config files: the set's matches in the entry dir and the scanned root.
: > "$TMP/cfgs.raw"
shopt -s nullglob
for d in "$EPATH" .; do
  for pat in $CFGS; do
    # shellcheck disable=SC2206  # the glob is the point
    m=(./"$d"/$pat)
    for f in ${m[@]+"${m[@]}"}; do
      [ -f "$f" ] && [ -r "$f" ] || continue
      if [ "$d" = . ]; then printf '%s\n' "${f##*/}"; else printf '%s/%s\n' "$d" "${f##*/}"; fi
    done >> "$TMP/cfgs.raw"
  done
done
shopt -u nullglob
if [ "$PROFILE" = tailwind ]; then
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    if [ "$EPATH" = . ]; then under=1; else
      case "$f" in "$EPATH"/*) under=1 ;; *) under=0 ;; esac
    fi
    if [ "$under" -eq 1 ] && [ -f "$f" ] && [ -r "$f" ]; then printf '%s\n' "$f" >> "$TMP/cfgs.raw"; fi
  done < "$TMP/twcss"
fi
LC_ALL=C sort -u "$TMP/cfgs.raw" > "$TMP/cfgs"

if command -v shasum > /dev/null 2>&1; then SHA='shasum -a 256'
elif command -v sha256sum > /dev/null 2>&1; then SHA=sha256sum
else die "need shasum or sha256sum"; fi
# shellcheck disable=SC2086  # SHA is a command plus its fixed argument
HASH=$({ while IFS= read -r rel; do printf '%s\0' "$rel"; cat -- "$rel"; printf '\0'; done < "$TMP/cfgs"; } | $SHA | cut -c1-12)
printf '%s cfg:%s\n' "$LINE" "$HASH"
