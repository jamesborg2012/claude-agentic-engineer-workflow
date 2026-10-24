#!/usr/bin/env bats
# Tests for scripts/detect-stack.sh: stack detection, and (task A4) fingerprints.
# Committed trees: tests/fixtures/stacks/<name>/ with <name>.expected.json beside them.
# Every other tree is built under $BATS_TEST_TMPDIR, so pruned dirs are never committed.

load helpers/common

setup() {
  common_setup
  STACKS="$REPO_ROOT/tests/fixtures/stacks"
  FIXTURE_NAMES="nextjs-tailwind react-vite laravel wordpress-theme woocommerce-plugin dotnet-api monorepo"
  DS="$SCRIPTS/detect-stack.sh"
  T="$BATS_TEST_TMPDIR/t"
  mkdir -p "$T"
}

ds() { run --separate-stderr "$DS" "$@"; }

# put <path under $T> <content>: write a file, creating its directories.
put() {
  mkdir -p "$(dirname "$T/$1")"
  printf '%s\n' "$2" > "$T/$1"
}

# shape / ids: compact views of $output.
shape() { printf '%s' "$output" | jq -c 'map({profile, path, version})'; }
ids() { printf '%s' "$output" | jq -c 'map(.profile + "@" + .path)'; }

# assert_match <string> <ERE>: a function, because a failing [[ ]] on a
# non-last line does not fail a bats test under bash 3.2.
assert_match() {
  if ! [[ $1 =~ $2 ]]; then
    printf 'expected to match: %s\nactual: %s\n' "$2" "$1" >&2
    return 1
  fi
}

@test "every stack fixture gives its expected profiles, paths and versions" {
  local name want got bad=""
  for name in $FIXTURE_NAMES; do
    if [ ! -d "$STACKS/$name" ] || [ ! -f "$STACKS/$name.expected.json" ]; then
      bad="$bad  $name: fixture or expected file missing"$'\n'
      continue
    fi
    ds "$STACKS/$name"
    want=$(jq -c . "$STACKS/$name.expected.json")
    got=$(shape)
    if [ "$status" -ne 0 ] || [ "$got" != "$want" ]; then
      bad="$bad  $name: status=$status got=$got want=$want"$'\n'
    fi
  done
  if [ -n "$bad" ]; then printf 'fixture mismatches:\n%s' "$bad" >&2; return 1; fi
}

@test "entries have exactly profile, path, version and evidence; evidence starts with a real path" {
  local name e p bad=""
  for name in $FIXTURE_NAMES; do
    ds "$STACKS/$name"
    if ! printf '%s' "$output" | jq -e 'type == "array" and all(.[];
        (keys_unsorted == ["profile", "path", "version", "evidence"])
        and (.profile | test("^[a-z0-9-]+$"))
        and (.path | type == "string" and length > 0)
        and (.version | type == "string" and length > 0)
        and (.evidence | type == "array" and length > 0 and all(type == "string" and length > 0)))' > /dev/null; then
      bad="$bad  $name: bad shape: $output"$'\n'
    fi
    while IFS= read -r e; do
      p=${e%%: *}
      if [ ! -e "$STACKS/$name/$p" ]; then bad="$bad  $name: evidence path missing: $e"$'\n'; fi
    done < <(printf '%s' "$output" | jq -r '.[].evidence[]')
  done
  if [ -n "$bad" ]; then printf '%s' "$bad" >&2; return 1; fi
}

@test "stdout is one compact JSON line and identical across runs" {
  ds "$STACKS/monorepo"
  assert_success
  local first=$output
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
  ds "$STACKS/monorepo"
  assert_equal "$output" "$first"
}

@test "with no argument it scans the current directory" {
  ds "$STACKS/nextjs-tailwind"
  local explicit=$output
  cd "$STACKS/nextjs-tailwind"
  ds
  assert_success
  assert_equal "$output" "$explicit"
}

@test "an empty directory prints [] and exits 0" {
  ds "$T"
  assert_success
  assert_equal "$output" "[]"
  assert_equal "$stderr" ""
}

@test "a missing path, an empty path, a file, or extra arguments exit 1 with error: and empty stdout" {
  put "file.txt" "x"
  ds "$T/missing"
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
  ds ''
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
  ds "$T/file.txt"
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
  ds "$T" "$T"
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
}

@test "an unreadable directory exits 1" {
  if [ "$(id -u)" -eq 0 ]; then skip "root can read anything"; fi
  mkdir "$T/locked"
  chmod 000 "$T/locked"
  ds "$T/locked"
  chmod 755 "$T/locked"
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
}

@test "an unreadable subdirectory is skipped with a warning; the rest is still reported" {
  if [ "$(id -u)" -eq 0 ]; then skip "root can read anything"; fi
  put "good/package.json" '{"dependencies":{"react":"^19.2.0"}}'
  mkdir -p "$T/docker/data"
  chmod 000 "$T/docker/data"
  ds "$T"
  chmod 755 "$T/docker/data"
  assert_success
  assert_equal "$(ids)" '["react@good"]'
  assert_contains "$stderr" "warning:"
  assert_contains "$stderr" "docker/data"
}

@test "next in dependencies or devDependencies is nextjs; react without next is react" {
  put "a/package.json" '{"dependencies":{"next":"^16.0.1","react":"^19.2.0"}}'
  put "b/package.json" '{"devDependencies":{"next":"^15.3.0"}}'
  put "c/package.json" '{"dependencies":{"react":"^18.3.1"}}'
  put "d/package.json" '{"peerDependencies":{"react":"^19.0.0"},"dependencies":{"lodash":"^4.0.0"}}'
  ds "$T"
  assert_success
  assert_equal "$(shape)" '[{"profile":"nextjs","path":"a","version":"16.0.1"},{"profile":"nextjs","path":"b","version":"15.3.0"},{"profile":"react","path":"c","version":"18.3.1"}]'
}

@test "tailwind comes from a dependency, a config file or a CSS @import, at the nearest package root" {
  put "dep/package.json" '{"devDependencies":{"tailwindcss":"^4.1.0"}}'
  put "cfg/tailwind.config.js" 'module.exports = {}'
  put "css/package.json" '{"name":"plain"}'
  put "css/styles/app.css" "@import 'tailwindcss';"
  put "bare/site.css" '@import "tailwindcss" source(none);'
  put "plain/app.css" '@import "./base.css";'
  put "sub/app.css" '@import "tailwindcss/preflight.css";'
  put "plugin/app.css" '@import "tailwindcss-animate";'
  ds "$T"
  assert_success
  assert_equal "$(shape)" '[{"profile":"tailwind","path":"bare","version":"unknown"},{"profile":"tailwind","path":"cfg","version":"unknown"},{"profile":"tailwind","path":"css","version":"unknown"},{"profile":"tailwind","path":"dep","version":"4.1.0"},{"profile":"tailwind","path":"sub","version":"unknown"}]'
}

@test "evidence for one profile and path is merged into one entry" {
  put "package.json" '{"devDependencies":{"tailwindcss":"^4.1.0"}}'
  put "tailwind.config.ts" 'export default {}'
  put "src/app.css" '@import "tailwindcss";'
  ds "$T"
  assert_success
  assert_equal "$(ids)" '["tailwind@."]'
  assert_equal "$(printf '%s' "$output" | jq '.[0].evidence | length')" "3"
}

@test "laravel needs laravel/framework in composer.json require" {
  put "app/composer.json" '{"require":{"php":"^8.3","laravel/framework":"^12.0"}}'
  put "dev/composer.json" '{"require-dev":{"laravel/framework":"^12.0"}}'
  ds "$T"
  assert_success
  assert_equal "$(shape)" '[{"profile":"laravel","path":"app","version":"12.0"}]'
}

@test "wordpress comes from Theme Name, Plugin Name, wp-config.php or wp-content/" {
  put "theme/style.css" $'/*\nTheme Name: T\nRequires at least: 6.4\n*/'
  put "plugin/p.php" $'<?php\n/**\n * Plugin Name: P\n */'
  put "site/wp-config.php" '<?php'
  put "site/wp-includes/version.php" $'<?php\n$wp_version = \'6.7.1\';'
  mkdir -p "$T/content/wp-content"
  put "notheme/style.css" 'body { margin: 0; }'
  put "notplugin/x.php" '<?php // the words Plugin Name in prose: not a header'
  ds "$T"
  assert_success
  assert_equal "$(shape)" '[{"profile":"wordpress","path":"content","version":"unknown"},{"profile":"wordpress","path":"plugin","version":"unknown"},{"profile":"wordpress","path":"site","version":"6.7.1"},{"profile":"wordpress","path":"theme","version":"6.4"}]'
}

@test "a Plugin Name header after the first 8 KB is not read" {
  { printf '<?php\n'; head -c 9000 /dev/zero | tr '\0' 'x'; printf '\n/* Plugin Name: Late */\n'; } > "$T/late.php"
  ds "$T"
  assert_success
  assert_equal "$output" "[]"
}

@test "woocommerce comes from WC headers, a composer or @woocommerce dependency, or a woocommerce_ hook in a plugin" {
  put "hdr/p.php" $'<?php\n/*\n * Plugin Name: H\n * WC requires at least: 8.5\n */'
  put "tested/p.php" $'<?php\n/*\n * Plugin Name: T\n * WC tested up to: 9.4\n */'
  put "comp/p.php" $'<?php\n/* Plugin Name: C */'
  put "comp/composer.json" '{"require":{"wpackagist-plugin/woocommerce":"^9.1"}}'
  put "npm/p.php" $'<?php\n/* Plugin Name: N */'
  put "npm/package.json" '{"devDependencies":{"@woocommerce/dependency-extraction-webpack-plugin":"^3.0.0"}}'
  put "hook/p.php" $'<?php\n/* Plugin Name: K */'
  put "hook/inc/h.php" "<?php add_filter( 'woocommerce_order_note_added', 'k_note' );"
  ds "$T"
  assert_success
  assert_equal "$(ids)" '["wordpress@comp","woocommerce@comp","wordpress@hdr","woocommerce@hdr","wordpress@hook","woocommerce@hook","wordpress@npm","woocommerce@npm","wordpress@tested","woocommerce@tested"]'
  assert_equal "$(printf '%s' "$output" | jq -c 'map(select(.profile == "woocommerce") | .version)')" '["9.1","8.5","unknown","unknown","unknown"]'
}

@test "woocommerce never appears without wordpress at or below its path" {
  put "lib/composer.json" '{"require":{"woocommerce/woocommerce":"^9.0"}}'
  put "loose/h.php" "<?php add_action( 'woocommerce_init', 'f' );"
  ds "$T"
  assert_success
  assert_equal "$output" "[]"
  # Bedrock: WooCommerce in the root composer.json, WordPress core under web/.
  put "bedrock/composer.json" '{"require":{"wpackagist-plugin/woocommerce":"^9.1"}}'
  put "bedrock/web/wp-config.php" '<?php'
  ds "$T/bedrock"
  assert_success
  assert_equal "$(ids)" '["woocommerce@.","wordpress@web"]'
  assert_equal "$(printf '%s' "$output" | jq -r '.[] | select(.profile == "woocommerce") | .version')" "9.1"
}

@test "dotnet comes from a .sln or a .csproj; projects under a .sln belong to its dir" {
  put "a/App.sln" 'Microsoft Visual Studio Solution File, Format Version 12.00'
  put "a/src/App/App.csproj" '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFrameworks>net8.0;net9.0</TargetFrameworks></PropertyGroup></Project>'
  ds "$T/a"
  assert_success
  assert_equal "$(shape)" '[{"profile":"dotnet","path":".","version":"8.0"}]'
  put "b/lone/Api.csproj" '<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup></Project>'
  put "b/slnonly/Only.sln" 'Microsoft Visual Studio Solution File, Format Version 12.00'
  ds "$T/b"
  assert_success
  assert_equal "$(shape)" '[{"profile":"dotnet","path":"lone","version":"9.0"},{"profile":"dotnet","path":"slnonly","version":"unknown"}]'
}

@test "scanning goes to depth 3 and no deeper" {
  put "a/b/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  put "c/d/e/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  put "f/g/h/i.csproj" '<Project/>'
  ds "$T"
  assert_success
  assert_equal "$(ids)" '["nextjs@a/b"]'
}

@test "pruned directories are never reported, at any level" {
  local d
  for d in node_modules vendor .git dist build out .next .turbo coverage bin obj; do
    put "$d/x/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  done
  put "vendor/composer.json" '{"require":{"laravel/framework":"^12.0"}}'
  put "obj/A.csproj" '<Project/>'
  put "bin/B.sln" ''
  put "node_modules/t/style.css" $'/*\nTheme Name: N\n*/'
  put "apps/node_modules/next/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  put "dist/app.css" '@import "tailwindcss";'
  ds "$T"
  assert_success
  assert_equal "$output" "[]"
}

@test "a node_modules created inside a fixture copy changes nothing" {
  cp -R "$STACKS/nextjs-tailwind" "$T/app"
  put "app/node_modules/next/package.json" '{"name":"next","dependencies":{"react":"^19.2.0"}}'
  put "app/node_modules/legacy/package.json" '{"dependencies":{"next":"^13.0.0"}}'
  ds "$T/app"
  assert_success
  assert_equal "$(shape)" "$(jq -c . "$STACKS/nextjs-tailwind.expected.json")"
}

@test "order is by path (root first), then base before overlay, then profile name" {
  put "composer.json" '{"require":{"laravel/framework":"^12.0"}}'
  put "package.json" '{"dependencies":{"next":"^16.0.1"},"devDependencies":{"tailwindcss":"^4.1.0"}}'
  put "apps/b/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  put "apps/a/package.json" '{"dependencies":{"react":"^19.2.0"}}'
  put ".hidden/package.json" '{"dependencies":{"react":"^19.2.0"}}'
  ds "$T"
  assert_success
  assert_equal "$(ids)" '["laravel@.","nextjs@.","tailwind@.","react@.hidden","react@apps/a","nextjs@apps/b"]'
}

@test "declared versions are normalised to their lowest concrete version" {
  local spec want got bad=""
  while IFS='|' read -r spec want; do
    rm -rf "$T/p"
    put "p/package.json" "{\"dependencies\":{\"next\":\"$spec\"}}"
    ds "$T/p"
    got=$(printf '%s' "$output" | jq -r '.[0].version')
    if [ "$got" != "$want" ]; then bad="$bad  [$spec] got $got want $want"$'\n'; fi
  done <<'EOF'
^16.0.1|16.0.1
~16.0.1|16.0.1
>=15.1 <17|15.1
>= 15.1|15.1
v16.2.0|16.2.0
16.x|16
16|16
latest|unknown
*|unknown
workspace:*|unknown
EOF
  if [ -n "$bad" ]; then printf '%s' "$bad" >&2; return 1; fi
}

@test "an invalid manifest is skipped with a warning; the rest is still reported" {
  put "bad/package.json" '{"dependencies":'
  put "good/package.json" '{"dependencies":{"react":"^19.2.0"}}'
  ds "$T"
  assert_success
  assert_equal "$(ids)" '["react@good"]'
  assert_contains "$stderr" "warning:"
  assert_contains "$stderr" "bad/package.json"
}

@test "paths with spaces are reported intact" {
  put "my app/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  ds "$T"
  assert_success
  assert_equal "$(ids)" '["nextjs@my app"]'
}

@test "a relative path ignores CDPATH, and a directory named - is scanned, not \$OLDPWD" {
  put "app/package.json" '{"dependencies":{"react":"^19.2.0"}}'
  put "other/app/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  put "-/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  cd "$T"
  export CDPATH="$T/other" OLDPWD="$T/app"
  ds app
  assert_success
  assert_equal "$(ids)" '["react@."]'
  ds -
  assert_success
  assert_equal "$(ids)" '["nextjs@."]'
}

@test "a tab inside a header value does not shift the headers after it" {
  put "p/p.php" $'<?php\n/*\n * Plugin Name: P\n * Requires at least: 6.4\tbeta\n * Requires PHP: 7.4\n */'
  ds "$T"
  assert_success
  assert_equal "$(shape)" '[{"profile":"wordpress","path":"p","version":"6.4"}]'
}

# --- fingerprint (task A4) -----------------------------------------------------

# fp <args…>: run the fingerprint subcommand; assert success; the line is in $FP.
fp() {
  run --separate-stderr "$DS" fingerprint "$@"
  assert_success
  FP=$output
}

# copy <fixture> <name>: a fresh copy of a stack fixture under $T.
copy() {
  rm -rf "${T:?}/$2"
  cp -R "$STACKS/$1" "$T/$2"
}

# setjson <file> <jq filter>: rewrite a JSON file.
setjson() { jq "$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

refute_equal() {
  if [ "$1" = "$2" ]; then printf 'expected a change; both: %s\n' "$1" >&2; return 1; fi
}

@test "every fixture profile fingerprints in the documented format" {
  local name profile re bad=""
  while IFS='|' read -r name profile re; do
    run --separate-stderr "$DS" fingerprint "$profile" "$STACKS/$name"
    if [ "$status" -ne 0 ] || ! [[ $output =~ $re ]]; then bad="$bad  $name $profile: [$output] status=$status"$'\n'; fi
  done <<'FIXTURES'
nextjs-tailwind|nextjs|^nextjs next@16 react@19 typescript@5 cfg:[0-9a-f]{12}$
nextjs-tailwind|tailwind|^tailwind tailwindcss@4 cfg:[0-9a-f]{12}$
react-vite|react|^react react@19 typescript@5 cfg:[0-9a-f]{12}$
laravel|laravel|^laravel laravel/framework@12 php@8 cfg:[0-9a-f]{12}$
wordpress-theme|wordpress|^wordpress wordpress@6 php@8 cfg:[0-9a-f]{12}$
woocommerce-plugin|wordpress|^wordpress wordpress@6 php@8 cfg:[0-9a-f]{12}$
woocommerce-plugin|woocommerce|^woocommerce woocommerce@9 cfg:[0-9a-f]{12}$
dotnet-api|dotnet|^dotnet dotnet@9 cfg:[0-9a-f]{12}$
monorepo|nextjs|^nextjs next@16 react@19 typescript@5 cfg:[0-9a-f]{12}$
monorepo|laravel|^laravel laravel/framework@12 php@8 cfg:[0-9a-f]{12}$
FIXTURES
  if [ -n "$bad" ]; then printf '%s' "$bad" >&2; return 1; fi
}

@test "cfg is the first 12 hex of SHA-256 over sorted relative-path NUL content NUL" {
  local want
  want=$(cd "$STACKS/react-vite" && for f in eslint.config.js tsconfig.json; do printf '%s\0' "$f"; cat "$f"; printf '\0'; done | shasum -a 256 | cut -c1-12)
  fp react "$STACKS/react-vite"
  assert_equal "${FP##*cfg:}" "$want"
}

@test "a fingerprint is stable across runs, copies and the calling directory" {
  fp nextjs "$STACKS/nextjs-tailwind"
  local a=$FP
  fp nextjs "$STACKS/nextjs-tailwind"
  assert_equal "$FP" "$a"
  copy nextjs-tailwind app
  fp nextjs "$T/app"
  assert_equal "$FP" "$a"
  cd "$T/app"
  fp nextjs
  assert_equal "$FP" "$a"
}

@test "changing or adding a relevant config changes cfg for that profile only" {
  copy nextjs-tailwind app
  fp nextjs "$T/app"; local n0=$FP
  fp tailwind "$T/app"; local t0=$FP
  printf '\n' >> "$T/app/tsconfig.json"
  fp nextjs "$T/app"; local n1=$FP
  refute_equal "$n1" "$n0"
  assert_equal "${n1% cfg:*}" "${n0% cfg:*}"
  fp tailwind "$T/app"
  assert_equal "$FP" "$t0"
  printf '{}\n' > "$T/app/.prettierrc"
  fp nextjs "$T/app"; local n2=$FP
  refute_equal "$n2" "$n1"
  printf '@theme { --color-accent: #a50; }\n' >> "$T/app/app/globals.css"
  fp tailwind "$T/app"
  refute_equal "$FP" "$t0"
  fp nextjs "$T/app"
  assert_equal "$FP" "$n2"
}

@test "repo-root configs count for a nested stack, and so do the stack's own" {
  copy monorepo mono
  fp nextjs "$T/mono"; local n0=$FP
  fp laravel "$T/mono"; local l0=$FP
  printf 'indent_size = 4\n' >> "$T/mono/.editorconfig"
  fp nextjs "$T/mono"
  refute_equal "$FP" "$n0"
  fp laravel "$T/mono"; local l1=$FP
  refute_equal "$l1" "$l0"
  printf '{"preset":"psr12"}\n' > "$T/mono/apps/api/pint.json"
  fp laravel "$T/mono"
  refute_equal "$FP" "$l1"
}

@test "a nested stack's wildcard configs count even when the root has none" {
  copy monorepo mono
  fp nextjs "$T/mono"; local n0=$FP
  printf 'export default [];\n' > "$T/mono/apps/web/eslint.config.mjs"
  fp nextjs "$T/mono"; local n1=$FP
  refute_equal "$n1" "$n0"
  printf 'export default [];\n' > "$T/mono/eslint.config.js"
  fp nextjs "$T/mono"; local n2=$FP
  printf '// edit\n' >> "$T/mono/apps/web/eslint.config.mjs"
  fp nextjs "$T/mono"
  refute_equal "$FP" "$n2"
}

@test "a major bump changes the line; a minor bump does not" {
  copy nextjs-tailwind app
  fp nextjs "$T/app"; local n0=$FP
  setjson "$T/app/package.json" '.dependencies.next = "^16.2.0"'
  fp nextjs "$T/app"
  assert_equal "$FP" "$n0"
  setjson "$T/app/package.json" '.dependencies.next = "^17.0.0"'
  fp nextjs "$T/app"
  assert_equal "$FP" "${n0/next@16/next@17}"
}

@test "unrelated changes leave the fingerprint unchanged" {
  copy nextjs-tailwind app
  fp nextjs "$T/app"; local n0=$FP
  fp tailwind "$T/app"; local t0=$FP
  printf '// edit\n' >> "$T/app/app/page.tsx"
  printf '# Readme\n' > "$T/app/README.md"
  setjson "$T/app/package.json" '.scripts.dev = "next dev --turbopack"'
  put "app/dist/out.css" '@import "tailwindcss";'
  put "app/node_modules/x/tsconfig.json" '{}'
  fp nextjs "$T/app"
  assert_equal "$FP" "$n0"
  fp tailwind "$T/app"
  assert_equal "$FP" "$t0"
}

@test "an undeclared tracked dependency is omitted; an unparseable version is unknown" {
  copy react-vite r
  setjson "$T/r/package.json" 'del(.devDependencies.typescript)'
  fp react "$T/r"
  assert_match "$FP" '^react react@19 cfg:[0-9a-f]{12}$'
  setjson "$T/r/package.json" '.dependencies.react = "latest"'
  fp react "$T/r"
  assert_match "$FP" '^react react@unknown cfg:[0-9a-f]{12}$'
}

@test "php comes from composer.json require.php before the Requires PHP header" {
  copy wordpress-theme th
  printf '%s\n' '{"require":{"php":">=7.4"}}' > "$T/th/composer.json"
  fp wordpress "$T/th"
  assert_match "$FP" '^wordpress wordpress@6 php@7 cfg:[0-9a-f]{12}$'
}

@test "a profile at several paths is fingerprinted from the first in detection order" {
  put "apps/a/package.json" '{"dependencies":{"next":"^15.3.0"}}'
  put "apps/b/package.json" '{"dependencies":{"next":"^16.0.1"}}'
  fp nextjs "$T"
  assert_match "$FP" '^nextjs next@15 cfg:[0-9a-f]{12}$'
}

@test "a profile that is not detected exits 1 with error: and empty stdout" {
  local p
  for p in laravel cobol; do
    run --separate-stderr "$DS" fingerprint "$p" "$STACKS/nextjs-tailwind"
    assert_failure 1
    assert_equal "$output" ""
    assert_contains "$stderr" "error:"
  done
}

@test "fingerprint with no profile, a bad path or extra arguments exits 1" {
  run --separate-stderr "$DS" fingerprint
  assert_failure 1
  assert_contains "$stderr" "error:"
  run --separate-stderr "$DS" fingerprint nextjs "$T/missing"
  assert_failure 1
  assert_contains "$stderr" "error:"
  run --separate-stderr "$DS" fingerprint nextjs "$STACKS/nextjs-tailwind" extra
  assert_failure 1
  assert_contains "$stderr" "error:"
}
