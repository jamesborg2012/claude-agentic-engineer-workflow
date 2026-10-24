# Phase A plan — Deterministic layer changes (detection, fingerprint, conventions, agent `gh` guard)

- **Spec:** `docs/superpowers/specs/2026-10-24-standards-and-planning-agents.md` (hash `d41b2001…99c1`)
- **Phase:** A of the EPIC. `depends_on: []`. Phases D and E consume its contract (below); B documents it.
- **Depth:** full
- **ACs covered:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-12 (the hook-enforcement half only; the prompt and frontmatter half is in Phases C and D), AC-14
- **Risk:** reopens a prompt-02 safety hook (`scripts/hooks/guard-bash.sh`) and a prompt-02 convention test (`tests/scripts/conventions.bats`). One rule each, plus tests; the full suite is re-run.
- **Date:** 2026-10-24
- **Naming note:** "Assumption 2" and "Assumption 11" below are the spec's assumptions (the CTO notes call them A2 and A11). Task ids in this phase are `A1`–`A4` and are unrelated to those numbers.

> **For agentic workers:** implement task by task with `superpowers:test-driven-development`. Every task records its RED output before implementing and its GREEN output after.

**Goal:** add `scripts/detect-stack.sh` (detection and `fingerprint`) with fixtures and a bats suite, narrow one convention rule so a script with only optional arguments is allowed, and make the Bash guard deny `gh` for every `aew:*` agent.

**Architecture:** one new bash script built on the `scripts/state.sh` pattern (line-2 `Usage:` header as `--help`, sources `lib/common.sh`, `die`, `require_cmd`). Detection is a single pruned `find` to depth 3, with per-file rules writing tab-separated records, merged and ordered by one `jq` program. The fingerprint reuses that detection, then hashes a fixed per-profile set of config files. The guard change reuses the existing `guard_gh()` and `hook_field`.

**Tech stack:** bash 3.2 (macOS `/bin/bash`), BSD `find`, jq 1.7.1, `shasum -a 256` (falling back to `sha256sum`), bats-core 1.14, shellcheck through `tests/run-script-tests.sh`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `scripts/state.sh` (lines 1–35) | Script pattern: Usage header, sourcing `lib/common.sh`, `-h/--help` case, temp-file trap |
| `scripts/lib/common.sh` | `die`, `warn`, `require_cmd`, `print_usage` (prints from line 2 up to the first non-comment line) |
| `tests/scripts/helpers/common.bash` | `common_setup`, `run --separate-stderr`, `assert_success`, `assert_failure [n]`, `assert_equal`, `assert_contains`, `setup_project`, `run_hook`, `$SCRIPTS`, `$REPO_ROOT`, `$BATS_TEST_TMPDIR` |
| `tests/scripts/conventions.bats` | `script_files subcommand` (the rule to narrow); bash 3.2 lint patterns that `detect-stack.sh` must avoid (`sed -i`, `grep -P`, `readlink -f`, `stat -c/-f`, `mapfile`, `declare -A`) |
| `scripts/hooks/guard-bash.sh` | header (Rules, Limits), globals, `guard_gh()` (~line 288), main block (`cmd=$(hook_field .tool_input.command)`, ~line 652) |
| `scripts/lib/hooks.sh` | `hook_field <jq path>` → `jq -r "<path> // empty"` over `$HOOK_PAYLOAD` |
| `tests/scripts/hooks-guard-bash.bats` | `setup_guard_project`, `bash_payload`, `is_deny` |
| `tests/scripts/fixtures/hooks/pretooluse-bash.json` | The base payload has **no** `agent_type`, so the existing table row `allow feat . gh issue view 3` already exercises the main thread |
| `docs/DESIGN.md` §11 | The guard's "Blocks" list, which gets one bullet |

Gotchas that apply (from `docs/superpowers/project-map.md`): bash 3.2 (`set -e` does not fire inside `$(...)` assignments, so check the status explicitly; empty arrays need `${a[@]+"${a[@]}"}`); `jq -Rs` corrupts multi-byte characters at 4096-byte boundaries, so use `--rawfile`; `grep -P` is unavailable; in bats, a bare `! cmd` or a failing `[[ … ]]` on a non-last line does **not** fail the test under bash 3.2, so use `[ … ]` or a helper function that returns 1.

## Interface contract (Phases B, D and E rely on this)

### CLI

```
detect-stack.sh [path]
detect-stack.sh fingerprint <profile> [path]
detect-stack.sh -h | --help
```

- `path` (default `.`) is the **project root to scan**, in both forms. It must be a readable directory.
- `fingerprint <profile> [path]` scans `path` exactly as the first form does, takes the **first** entry of `<profile>` in detection order (spec Assumption 7: one doc per profile, fingerprinted from its first path) and fingerprints it. Callers **must** pass the same project root they passed to detection, never an entry's `path`: the scan root decides which root-level configs are hashed and the relative paths inside the hash, so a different root gives a different line. The "first entry" choice lives only in this script, so callers never pick a path themselves. **Cross-phase contract (required micro-revision of Phase D, standards-setter step 4):** replace `fingerprint <profile> <path>` with `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" fingerprint <profile> .`, run from the project root, the same `.` as step 2's detection call. Phase E's `fingerprint nextjs $P` already matches (`$P` is the project root).
- A directory literally named `fingerprint` is scanned as `./fingerprint`.

### Exit codes and streams

| Case | Exit | stdout | stderr |
|---|---|---|---|
| Detection succeeded (including no stacks) | 0 | one JSON array on one line, then `\n` | empty, or `detect-stack.sh: warning: …` lines |
| Fingerprint succeeded | 0 | one fingerprint line, then `\n` | as above |
| `-h` / `--help` | 0 | the Usage header block | empty |
| Missing or empty path, not a directory, unreadable directory, unknown option, too many arguments, `fingerprint` with no profile, profile not detected, `jq`/`find`/SHA-256 tool missing | 1 | empty | `detect-stack.sh: error: <reason>` |

Warnings never change the exit code. An invalid `package.json` or `composer.json` is skipped with `warning: skipping <rel>: invalid JSON`. An unreadable directory **below** the root is skipped with a warning that names it (`find`'s own message, prefixed `warning:`); only an unreadable root is an error.

### JSON output (detection)

```json
[{"profile":"nextjs","path":".","version":"16.0.1","evidence":["package.json: next ^16.0.1"]},{"profile":"tailwind","path":".","version":"4.1.0","evidence":["app/globals.css: @import \"tailwindcss\"","package.json: tailwindcss ^4.1.0"]}]
```

- Each element has exactly the keys `profile`, `path`, `version` and `evidence`, in that order.
- `profile` is one of these. Base profiles: `nextjs`, `react`, `laravel`, `wordpress`, `dotnet`. Overlays: `tailwind`, `woocommerce`. All match `^[a-z0-9-]+$` (config schema).
- `path` is relative to the scanned root, without `./`; the root itself is `.`.
- `version` is a non-empty string: the normalised declared version, or `"unknown"`.
- `evidence` is a non-empty array of unique strings, sorted by codepoint. **Each string starts with the triggering file or directory path, relative to the scanned root** (a directory keeps its trailing `/`, as in `wp-content/`), optionally followed by `: <detail>`. Consumers may show it but must not parse anything beyond that prefix.
- Order: by `path` with `.` first, then by codepoint; then base profiles before overlays; then profile name.
- No stacks: `[]`.
- **Prompt 05 note:** drop `evidence` before writing config `stacks` (`additionalProperties: false`). `{profile, path, version}` is exactly the `stacks[]` item shape.

### Fingerprint line

`<profile> <dep>@<major>[ <dep>@<major>…] cfg:<hash12>`, with single spaces and no trailing space. Examples: `nextjs next@16 react@19 typescript@5 cfg:1a2b3c4d5e6f`, `laravel laravel/framework@12 php@8 cfg:…`.

| Profile | Tracked deps, in this order (primary first) | Config set (basenames, looked up non-recursively in the entry dir **and** the scanned root) |
|---|---|---|
| `nextjs` | `next`, `react`, `typescript` | `eslint.config.*`, `.eslintrc*`, `.prettierrc*`, `prettier.config.*`, `tsconfig.json`, `.editorconfig` |
| `react` | `react`, `typescript` | same as `nextjs` |
| `tailwind` | `tailwindcss` | `tailwind.config.*`, `.stylelintrc*`, `stylelint.config.*`, `.editorconfig`, **plus** every scanned CSS file under the entry path that holds a Tailwind `@import` |
| `laravel` | `laravel/framework`, `php` | `pint.json`, `phpstan.neon`, `phpstan.neon.dist`, `phpcs.xml`, `phpcs.xml.dist`, `.editorconfig` |
| `wordpress` | `wordpress`, `php` | `phpcs.xml`, `phpcs.xml.dist`, `.phpcs.xml`, `.phpcs.xml.dist`, `phpstan.neon`, `phpstan.neon.dist`, `eslint.config.*`, `.eslintrc*`, `.stylelintrc*`, `stylelint.config.*`, `.editorconfig` |
| `woocommerce` | `woocommerce` | `phpcs.xml`, `phpcs.xml.dist`, `.phpcs.xml`, `.phpcs.xml.dist`, `phpstan.neon`, `phpstan.neon.dist`, `.editorconfig` |
| `dotnet` | `dotnet` | `Directory.Build.props`, `.csharpierrc*`, `.editorconfig` |

- **Primary dep** (first column item): always present. Its major comes from the entry's `version`; `unknown` gives `<dep>@unknown`.
- **Secondary deps:** read from the entry dir's manifest. `react` and `typescript` come from `package.json` (`dependencies`, then `devDependencies`). `php` comes from `composer.json` `require.php`; for `wordpress` only, it falls back to the `Requires PHP:` header of the entry's header file. A dep that is not declared is **omitted**. A dep that is declared but unparseable is `@unknown`.
- **Major:** the leading digit run of the normalised version (`12.0` → `12`, `6.7.1` → `6`).
- **cfg hash:** take the union of the config set's matches in the entry dir and the scanned root, de-duplicated (the two are the same dir when the entry path is `.`), plus the Tailwind CSS files. Sort them by relative path (`LC_ALL=C`). For each file, emit `<relpath>` NUL `<content>` NUL. `cfg` is the first 12 lowercase hex characters of SHA-256 over that byte stream. No files means the hash of the empty stream (`e3b0c44298fc`). Manifests are never hashed, so a minor dependency bump leaves the line unchanged.
- **Plan refinement (flag if wrong):** spec Assumption 6 lists the configs as one union. This plan partitions them per profile (table above), so an unrelated tool's config does not invalidate every doc. Phase B's SKILL.md should copy this table.

### Detection rules (AC-2, made exact)

The scan is `find <root> -mindepth 1 -maxdepth 3` (Assumption 3). It prunes directories named `node_modules`, `vendor`, `.git`, `dist`, `build`, `out`, `.next`, `.turbo`, `coverage`, `bin` and `obj` at any level (the root itself is never pruned). Other hidden directories are scanned. "Nearest package root" means: walk up from the file's directory to the scanned root (inclusive), and stop at the first directory holding `package.json` or `composer.json`. If there is none, use the file's own directory.

| Evidence | Profile @ path | Version source (first non-unknown wins) |
|---|---|---|
| `package.json` with `next` in `dependencies` or `devDependencies` | `nextjs` @ its dir | that `next` value |
| `package.json` with `react` (same keys) and no `next` | `react` @ its dir | that `react` value |
| `package.json` with a `tailwindcss` dependency | `tailwind` @ its dir | that value |
| `tailwind.config.*` file | `tailwind` @ nearest package root | — |
| `*.css` with a line matching `@import[[:space:]]+["']tailwindcss(/[^"']*)?["']` | `tailwind` @ nearest package root | — |
| `composer.json` with `laravel/framework` in `require` (not `require-dev`) | `laravel` @ its dir | that value |
| `style.css` whose first 8 KB has a `Theme Name:` header line | `wordpress` @ its dir (a *header file*) | its `Requires at least:` |
| `*.php` whose first 8 KB has a `Plugin Name:` header line | `wordpress` @ its dir (a *header file*, and a *plugin path*) | its `Requires at least:` |
| `wp-config.php` file, or a `wp-content` directory | `wordpress` @ its parent dir | `$wp_version = '<v>'` in `<path>/wp-includes/version.php` |
| `WC requires at least:` or `WC tested up to:` in a header file's first 8 KB | `woocommerce` @ the header file's dir | its `WC requires at least:` |
| `composer.json` with `woocommerce/woocommerce` or `wpackagist-plugin/woocommerce` in `require` or `require-dev` | `woocommerce` @ its dir | that value |
| `package.json` with any `@woocommerce/*` dependency | `woocommerce` @ its dir | — |
| A scanned `*.php` file under a plugin path that matches `add_(action\|filter)[[:space:]]*\([[:space:]]*["']woocommerce_` | `woocommerce` @ the plugin path | — |
| `*.sln` | `dotnet` @ its dir | the projects below it |
| `*.csproj` | `dotnet` @ the nearest ancestor dir (up to the root) holding a `*.sln`, else its own dir | first `<TargetFramework>` / `<TargetFrameworks>` value matching `net<digits>[.<digits>]…`, giving `8.0` from `net8.0` (first project in sorted order) |

- **Header line**, as WordPress `get_file_data` reads it, case-insensitive: `^([[:space:]]*<\?php)?[[:space:]/*#@]*<Header>:(.*)$`, with the value trimmed.
- **Version normalisation:** strip leading whitespace and the characters `^ ~ > = < v`, then take the leading `[0-9]+(\.[0-9]+)*`. If that is empty, the version is `unknown`. Examples: `^16.0.1` → `16.0.1`, `>=15.1 <17` → `15.1`, `16.x` → `16`, `latest`, `*` and `workspace:*` → `unknown`.
- Entries for the same (profile, path) are merged, and their evidence is united.
- **Overlay rule:** a `woocommerce` entry at path P is kept only when a `wordpress` entry exists at a path W that is P or below it (W == P, or P == ".", or W starts with P + "/"); otherwise it is dropped. This keeps Bedrock (`wpackagist-plugin/woocommerce` in the root `composer.json` gives `woocommerce @ .`, `web/wp-config.php` gives `wordpress @ web`). `tailwind` can stand alone.
- **Limits** (go in the script header): heuristic; depth 3 means files four or more levels down are not seen; paths containing a tab or a newline are not supported.

### `nextjs-tailwind` fixture contract (Phases C, D and E smoke runs)

`tests/fixtures/stacks/nextjs-tailwind/` contains:

- `package.json` with `next`, `react` and `react-dom` in `dependencies`, and `tailwindcss`, `@tailwindcss/postcss` and `typescript` in `devDependencies`;
- `app/layout.tsx`, the root layout, which renders an existing `<footer>`;
- `app/page.tsx`, a home page that renders static article cards from an array module;
- `app/articles.ts`, the array module;
- `app/globals.css` with `@import "tailwindcss";`;
- no auth and no database.

Detection gives `[nextjs @ . 16.0.1, tailwind @ . 4.1.0]`.

### `--help` text (the final header, after A4)

```bash
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
```

A3 ships this header without the `fingerprint` lines (line 3, the `fingerprint:` paragraph and the fingerprint clause of the exit line). A4 adds them. Line 2 is the same in both, and its text after the name starts with `[`, which the narrowed convention rule keys on.

## Tasks

Waves: **1** = A1 ∥ A2 · **2** = A3 · **3** = A4. A2 shares no file with A1, A3 or A4, so it can also run alongside waves 2 and 3.

---

### Task A1 — Stack fixtures and their expected detection output

- **id:** A1
- **files:** `tests/fixtures/stacks/{nextjs-tailwind,react-vite,laravel,wordpress-theme,woocommerce-plugin,dotnet-api,monorepo}/**`, `tests/fixtures/stacks/<name>.expected.json` (×7)
- **depends_on:** []
- **pattern:** `tests/scripts/fixtures/` (committed static test data, kept small). No existing stack fixture exists; prompt 03 names `tests/fixtures/` because the bats tests and Phase E's smoke runs share these trees.
- **ACs:** AC-14 (and the inputs for AC-1, AC-2, AC-5)
- **test:** data only. A3's first test consumes the files and is where they go red, then green. Here, validate the JSON and check that git does not ignore any of the files.

Expected files sit **beside** each tree (`<name>.expected.json`), so the trees stay clean for Phase E's `cp -R …/<name>/. $P`. Each holds the `{profile, path, version}` triples in output order, which is the config `stacks` shape. Evidence is checked generically in A3.

Keep every source file to a minimal stub. Exact content matters only for the manifests, headers and configs listed below.

**Step 1: create the trees.**

`nextjs-tailwind/` (also the cross-phase contract above):

- `package.json`:
  ```json
  {
    "name": "fixture-nextjs-tailwind",
    "private": true,
    "scripts": { "dev": "next dev", "build": "next build", "lint": "eslint ." },
    "dependencies": { "next": "^16.0.1", "react": "^19.2.0", "react-dom": "^19.2.0" },
    "devDependencies": { "@tailwindcss/postcss": "^4.1.0", "@types/react": "^19.2.0", "eslint": "^9.0.0", "eslint-config-next": "^16.0.1", "tailwindcss": "^4.1.0", "typescript": "^5.6.0" }
  }
  ```
- `tsconfig.json` (standard Next.js strict config), `eslint.config.mjs` (exports `eslint-config-next`), `postcss.config.mjs` (`@tailwindcss/postcss` plugin), `next.config.ts` (empty config);
- `app/globals.css`: `@import "tailwindcss";` plus one `@theme { --color-brand: … }` token;
- `app/layout.tsx`: the root layout, importing `./globals.css`, with `<html><body>{children}<footer>…site name, two links, copyright…</footer></body></html>`. No newsletter form, because Phases C and D's issue and brief add that;
- `app/articles.ts`: `export const articles = [{ slug, title, excerpt }, …]` (three static items);
- `app/page.tsx`: maps `articles` to `<article>` cards (Tailwind classes). No auth, no database, no API routes.

`react-vite/`:

- `package.json`: `dependencies` `react ^19.2.0` and `react-dom ^19.2.0`; `devDependencies` `@vitejs/plugin-react ^5.0.0`, `eslint ^9.0.0`, `typescript ^5.6.0`, `vite ^7.0.0`;
- `tsconfig.json`, `eslint.config.js`, `vite.config.ts`, `index.html`, `src/main.tsx`, `src/App.tsx`, `src/App.css` (plain CSS with **no** Tailwind import);
- **only** `eslint.config.js` and `tsconfig.json` from the `react` config set: no `.editorconfig` and no prettier file. A4's recipe test relies on this.

`laravel/`:

- `composer.json`: `{"name":"fixture/laravel","type":"project","require":{"php":"^8.3","laravel/framework":"^12.0"},"require-dev":{"laravel/pint":"^1.18","phpunit/phpunit":"^11.0"},"autoload":{"psr-4":{"App\\":"app/"}}}`;
- `artisan` (a stub PHP file), `pint.json` (`{"preset":"laravel"}`), `.editorconfig`, `phpunit.xml`, `app/Models/User.php`, `routes/web.php`, `tests/Feature/ExampleTest.php`;
- **no** `package.json`, because Laravel's default one pulls in Tailwind and would add a `tailwind` entry.

`wordpress-theme/`:

- `style.css`, which starts:
  ```
  /*
  Theme Name: Fixture Theme
  Requires at least: 6.5
  Tested up to: 6.7
  Requires PHP: 8.1
  Version: 1.0.0
  Text Domain: fixture-theme
  */
  ```
- `functions.php` (enqueues `style.css` on `wp_enqueue_scripts`), `index.php`, `phpcs.xml.dist` (the `WordPress` ruleset).

`woocommerce-plugin/`:

- `fixture-shop-extension.php`:
  ```php
  <?php
  /**
   * Plugin Name: Fixture Shop Extension
   * Description: Adds an order note when an order is placed.
   * Version: 1.0.0
   * Requires at least: 6.5
   * Requires PHP: 8.1
   * WC requires at least: 9.0
   * WC tested up to: 9.4
   * Text Domain: fixture-shop-extension
   */
  defined( 'ABSPATH' ) || exit;
  add_action( 'before_woocommerce_init', function () {
  	\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
  } );
  require_once __DIR__ . '/includes/class-order-notes.php';
  ```
- `includes/class-order-notes.php`: a small class registering `add_action( 'woocommerce_checkout_order_processed', … )`;
- `phpcs.xml.dist`. No `package.json` and no `composer.json`.

`dotnet-api/`:

- `FixtureApi.sln` (a minimal valid solution referencing `src\FixtureApi\FixtureApi.csproj`);
- `src/FixtureApi/FixtureApi.csproj`: `<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net9.0</TargetFramework><Nullable>enable</Nullable></PropertyGroup></Project>`;
- `src/FixtureApi/Program.cs` (a minimal API with one `MapGet`), `Directory.Build.props`, `.editorconfig`;
- no `bin/` or `obj/`.

`monorepo/`:

- `package.json`: `{"name":"fixture-monorepo","private":true,"workspaces":["apps/web"]}`, with no stack dependencies;
- `.editorconfig`;
- `apps/web/package.json`: `dependencies` `next ^16.0.1`, `react ^19.2.0`, `react-dom ^19.2.0`; `devDependencies` `typescript ^5.6.0`;
- `apps/web/tsconfig.json`, `apps/web/next.config.ts`, `apps/web/app/page.tsx` (depth 4; deliberately not scanned);
- `apps/api/composer.json`: `{"require":{"php":"^8.3","laravel/framework":"^12.0"}}`;
- `apps/api/artisan`, `apps/api/pint.json`, `apps/api/routes/web.php`.

**Step 2: write the expected files** (one compact line each):

| File | Content |
|---|---|
| `nextjs-tailwind.expected.json` | `[{"profile":"nextjs","path":".","version":"16.0.1"},{"profile":"tailwind","path":".","version":"4.1.0"}]` |
| `react-vite.expected.json` | `[{"profile":"react","path":".","version":"19.2.0"}]` |
| `laravel.expected.json` | `[{"profile":"laravel","path":".","version":"12.0"}]` |
| `wordpress-theme.expected.json` | `[{"profile":"wordpress","path":".","version":"6.5"}]` |
| `woocommerce-plugin.expected.json` | `[{"profile":"wordpress","path":".","version":"6.5"},{"profile":"woocommerce","path":".","version":"9.0"}]` |
| `dotnet-api.expected.json` | `[{"profile":"dotnet","path":".","version":"9.0"}]` |
| `monorepo.expected.json` | `[{"profile":"laravel","path":"apps/api","version":"12.0"},{"profile":"nextjs","path":"apps/web","version":"16.0.1"}]` |

**Step 3: verify.**

```bash
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
for f in tests/fixtures/stacks/*.expected.json tests/fixtures/stacks/*/package.json tests/fixtures/stacks/*/composer.json tests/fixtures/stacks/*/apps/*/package.json tests/fixtures/stacks/*/apps/*/composer.json; do jq -e . "$f" > /dev/null || echo "BAD $f"; done
git add -A --dry-run tests/fixtures/stacks | wc -l      # every file is listed
git status --porcelain --ignored tests/fixtures/stacks | grep '^!!' || echo "none ignored"
```

Expected: no `BAD` lines, and `none ignored`. A global gitignore can hide `*.sln`, `.editorconfig` and so on; if one does, use `git add -f` and say so in the report.

**Step 4: commit.**

```
test: add stack detection fixtures

Seven minimal trees under tests/fixtures/stacks/ (nextjs-tailwind, react-vite,
laravel, wordpress-theme, woocommerce-plugin, dotnet-api, monorepo), each with
a sibling <name>.expected.json of {profile, path, version} triples.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

TDD note for the report: pure test data, so there is no RED here. It is guarded by A3's fixture test.

---

### Task A2 — Deny `gh` for `aew:*` agents in the Bash guard (spec Assumption 11)

- **id:** A2
- **files:** `scripts/hooks/guard-bash.sh`, `tests/scripts/hooks-guard-bash.bats`, `docs/DESIGN.md` (§11, one bullet)
- **depends_on:** []
- **pattern:** `guard_gh()` and its `deny` calls; `hook_field .agent_type` as already used in `scripts/hooks/gate-subagent.sh:137`; the dedicated `@test` blocks in `hooks-guard-bash.bats` ("the deny reason names the rule"), using `bash_payload`
- **ACs:** AC-12 (the enforcement half)
- **CTO cut (binding):** no fifth column in `bash-cases.tsv` and no parser change. About three lines of logic.
- **Rollback:** `git revert` of this task's single commit restores the prompt-02 guard, its tests and DESIGN §11 exactly. The rule holds no state and writes no files, so nothing else needs undoing; agents then fall back to the prompt-only ban (spec Assumption 11's documented fallback).

**Step 1: write the failing tests.** Add them to `tests/scripts/hooks-guard-bash.bats`, after `is_deny`:

```bash
# agent_payload <agent_type> <command> <cwd>: a Bash payload as sent from inside a subagent.
agent_payload() {
  bash_payload "$2" "$3" | jq -c --arg a "$1" '.agent_type = $a | .agent_id = "agent-1"'
}

@test "an aew agent may not run gh" {
  setup_guard_project
  git switch -q feat/x
  mkdir -p x
  run_hook guard-bash.sh "$(agent_payload aew:senior-engineer 'gh issue view 3' "$PROJECT")"
  assert_success
  is_deny
  assert_contains "$output" "aew agent"
  assert_contains "$output" "(only the orchestrator talks to GitHub; put the request in your NEXT line)"
  run_hook guard-bash.sh "$(agent_payload aew:developer 'cd x && gh pr list' "$PROJECT")"
  assert_success
  is_deny
  run_hook guard-bash.sh "$(agent_payload aew:developer 'git status && /opt/homebrew/bin/gh api user' "$PROJECT")"
  assert_success
  is_deny
}

@test "the agent gh rule spares other agents and non-gh commands" {
  setup_guard_project
  git switch -q feat/x
  run_hook guard-bash.sh "$(agent_payload Explore 'gh issue view 3' "$PROJECT")"
  assert_success
  assert_equal "$output" ""
  run_hook guard-bash.sh "$(agent_payload aew:developer 'git status' "$PROJECT")"
  assert_success
  assert_equal "$output" ""
  run_hook guard-bash.sh "$(agent_payload aew:developer 'echo gh issue view 3' "$PROJECT")"
  assert_success
  assert_equal "$output" ""
}
```

There is no explicit main-thread test. The base payload `pretooluse-bash.json` has no `agent_type` field, so the existing table row `allow feat . gh issue view 3` already proves that the main thread is allowed. State this in the report.

**Step 2: run and capture RED.**

```bash
bats -f 'aew agent|agent gh rule' tests/scripts/hooks-guard-bash.bats
```

Expected: `an aew agent may not run gh` fails at the first `is_deny`, because the output is empty (no deny). The "spares" test passes already, which is fine: it is the regression fence.

**Step 3: implement** in `scripts/hooks/guard-bash.sh`:

- with the globals (after `ecwd=""`): `AGENT_TYPE=""`;
- `deny()` takes an optional second argument that replaces the reason's tail. Change only its `local r=` line to:
  ```bash
  local r="aew guard: blocked $1 in \"$CURSEG\"${2-. aew never does this; if it is needed, James runs it himself.}"
  ```
  Every existing call passes one argument, so its reason text is byte-for-byte unchanged (`${2-…}` substitutes only when `$2` is unset);
- first statement of `guard_gh()`, after its `local` line:
  ```bash
  case "$AGENT_TYPE" in
    aew:*) deny "gh from an aew agent" " (only the orchestrator talks to GitHub; put the request in your NEXT line)" ;;
  esac
  ```
  giving `aew guard: blocked gh from an aew agent in "<segment>" (only the orchestrator talks to GitHub; put the request in your NEXT line)`.
- in the main block, right after `if [ -z "$cmd" ]; then exit 0; fi`:
  ```bash
  AGENT_TYPE=$(hook_field .agent_type) || AGENT_TYPE=""
  ```
- the header: in the opening sentence, change "`git clean -fdx`, and recursive `rm` outside the project (or of a `.git` path)." to "`git clean -fdx`, recursive `rm` outside the project (or of a `.git` path), and any `gh` command from an aew agent." (re-wrap the comment lines). Replace the Rules bullet `- gh: \`pr merge\` and \`repo delete\` are denied.` with:
  ```
  # - gh: inside an aew agent (the payload's agent_type starts with aew:) every
  #   gh command is denied, because only the orchestrator talks to GitHub.
  #   Otherwise `pr merge` and `repo delete` are denied.
  ```
  and append to the Limits paragraph:
  ```
  # The agent gh rule matches the gh command itself, so an agent calling the
  # plugin's scripts/gh-*.sh wrappers by path is not caught (agent prompts
  # never name them).
  ```

**Step 4: run and capture GREEN.**

```bash
bats tests/scripts/hooks-guard-bash.bats tests/scripts/hooks-json.bats
```

Expected: all pass, including the unchanged table test (`n ≥ 122`, 22 pins) and the hooks-json fail-open matrix.

**Step 5: DESIGN §11.** In the "`PreToolUse` on Bash (guard)" Blocks list, after `` `git clean -fdx`. ``, change that bullet's trailing `.` to `;` and add:

```
  - any `gh` command from an aew agent (the hook payload's `agent_type` starts with `aew:`), because agents never touch GitHub (§2.4).
```

**Step 6: full suite.** `tests/run-script-tests.sh` passes (shellcheck clean).

**Step 7: commit.**

```
feat(hooks): deny gh for aew agents in the Bash guard

Agents keep Bash, and frontmatter cannot deny one command without removing the
whole tool, so guard_gh now denies every gh segment when the PreToolUse payload's
agent_type starts with aew:. The main thread and non-aew agents are unaffected.
DESIGN section 11 lists the rule; the header documents that the plugin's gh-*.sh
wrappers called by path are not covered.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task A3 — `detect-stack.sh` detection, its bats tests, and the no-argument convention narrowing (spec Assumption 2)

- **id:** A3
- **files:** `scripts/detect-stack.sh` (new, `chmod +x`), `tests/scripts/detect-stack.bats` (new), `tests/scripts/conventions.bats` (`script_files subcommand` and the name of the test that uses it)
- **depends_on:** [A1]
- **pattern:** `scripts/state.sh` (header, the `-h|--help` case before anything else, `TMP` plus an `EXIT` trap, `die`), `scripts/lib/common.sh`, `tests/scripts/state.bats` (layout: `load helpers/common`, `setup` calling `common_setup`)
- **ACs:** AC-1, AC-2, AC-3, AC-5 (detection half), AC-6, AC-14 (assertion)
- **Why net-new:** there is no existing detection code; the only analog is the script skeleton. The script runs to about 200 lines in this task and about 300 after A4; it's one file because both forms share the scan.
- **Why the conventions change is in this task:** the rule only goes red once `detect-stack.sh` exists, and this task's definition of done is a green full suite.
- **Rollback:** `git revert` of this task's commit removes the script and restores the prompt-02 `script_files subcommand` rule unchanged. The two must be reverted together (the old rule fails on `detect-stack.sh`), which one commit guarantees.

**Step 1: write `tests/scripts/detect-stack.bats`** (the detection tests):

```bash
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
```

**Step 2: run and capture RED.**

```bash
bats tests/scripts/detect-stack.bats
```

Expected: every test fails with status 127 (`detect-stack.sh` not found). Keep the first two failure messages for the report.

**Step 3: implement `scripts/detect-stack.sh`** (detection only), with the A3 header from the contract. Structure:

1. Header; source `lib/common.sh`; a `-h|--help` case calling `print_usage "${BASH_SOURCE[0]}"`.
2. Argument parsing: any `-*` argument → `die "unknown option: $a"`; more than one positional → `die "too many arguments"`. `ROOT=${1-.}` (an explicit empty argument is not the default): if it is empty → `die "empty path"`. If it is not a directory → `die "not a directory: $ROOT"`. If `[ -r ] && [ -x ]` fails → `die "cannot read directory: $ROOT"`. Then `require_cmd jq find` and `cd "$ROOT" || die …`.
3. `TMP=$(mktemp -d)` with an `EXIT` trap that removes it. Record files: `rec` (records), `plugins` (plugin paths), `headers` (`<path>\t<header file>`), `hdrs` (the header pass output, below), `twcss` (Tailwind CSS files, for A4), and the candidate lists `hdrin` (`*.php` and `style.css`), `php` (`*.php`) and `css` (`*.css`), plus `plphp` and `hooked` for the hook pass (step 7).
4. Scan: `find . -mindepth 1 -maxdepth 3 \( -type d \( -name node_modules -o -name vendor -o -name .git -o -name dist -o -name build -o -name out -o -name .next -o -name .turbo -o -name coverage -o -name bin -o -name obj \) -prune \) -o -print`, then strip the leading `./` and `LC_ALL=C sort` into `$TMP/files`. Run `find` on its own (not in a pipeline), with stdout to a file and stderr to `$TMP/find.err`, and tolerate a non-zero exit (`|| true`): an unreadable subdirectory (a Docker volume such as `docker/mysql/data` is common in Laravel and WordPress repos) must not kill the script through `set -e`/`pipefail`. Re-emit each `find.err` line as a `warn` and carry on; the exit code stays 0. (`require_cmd find` already covers a missing `find`.)
5. Helpers. `norm_version <spec>` uses a regex held in a variable for bash 3.2 (`re='^[0-9]+(\.[0-9]+)*'`, and `[[ $v =~ $re ]]`). `dir_of <rel>` returns `.` for top-level files. `nearest_root <dir>` walks up to `.`. There is no per-file header helper: headers come from one `awk` pass (step 7). `add <rank> <profile> <path> <version> <evidence>` does a `printf` of a tab-separated line to `rec`.
6. Per-path rules, as one `case` on the basename (see the rules table). Use one `jq -r` call per manifest. For `package.json`: `(.devDependencies // {}) + (.dependencies // {})` (dependencies win), then keep the `next`, `react`, `tailwindcss` and `@woocommerce/*` entries as `@tsv`. For `composer.json`: `.require["laravel/framework"]`, plus the WooCommerce packages in `require` and `require-dev`. If jq fails, `warn "skipping $rel: invalid JSON"` and continue (check the status explicitly; `set -e` does not cover `$(...)`). Files are not opened in this loop except the manifests: each readable regular file (`[ -f ] && [ -r ]`, builtins, so `awk`/`grep` never abort on it) that is `*.php` or `style.css` is appended to `hdrin`, `*.php` also to `php`, and `*.css` to `css`. Only `*.php` files read 8 KB headers. Only `style.css` is checked for `Theme Name:`.
7. Second pass, with a fixed number of forks (no `head`/`grep` per file). Skip each step whose input list is empty (`[ -s ]`).
   - **Header pass:** one `awk` over `hdrin`: `sed 's|^|./|' "$TMP/hdrin" | tr '\n' '\0' | LC_ALL=C xargs -0 awk "$HDR_AWK" > "$TMP/hdrs"`. The `./` prefix stops awk treating a `name=value` file as an assignment; `LC_ALL=C` makes `length` count bytes. The program, held in a variable:
     ```awk
     BEGIN { pre = "^([[:space:]]*<[?]php)?[[:space:]/*#@]*"
             nk = split("plugin name|theme name|requires at least|requires php|wc requires at least|wc tested up to", k, "|") }
     function flush(  i, o) {
       if (cur == "" || !(((cur ~ /\.php$/) ? 1 : 2) in v)) return
       o = cur; for (i = 3; i <= nk; i++) o = o "\t" ((i in v) ? v[i] : "-"); print o }
     FNR == 1 { flush(); cur = FILENAME; sub(/^\.\//, "", cur); off = 0; split("", v) }
     off >= 8192 { nextfile }
     { off += length($0) + 1; l = tolower($0)
       for (i = 1; i <= nk; i++) if (!(i in v) && match(l, pre k[i] ":")) {
         s = substr($0, RSTART + RLENGTH); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); if (s != "") v[i] = s } }
     END { flush() }
     ```
     It prints one line per *header file* only (a `*.php` with `Plugin Name:`, a `style.css` with `Theme Name:`): `<rel>\t<Requires at least>\t<Requires PHP>\t<WC requires at least>\t<WC tested up to>`, with `-` for an absent value, so `IFS=$'\t' read` never collapses empty fields. The first match per header per file wins, as `get_file_data` does. The header regex stays anchored: `[[:space:]/*#@]*` cannot consume `WC `, so ` * WC requires at least:` never matches `Requires at least:` (verified on `/usr/bin/awk`). A line is read if it *starts* within the first 8192 bytes (`head -c` would have cut a straddling line instead; the late-header test is unaffected). `nextfile` is used: macOS `/usr/bin/awk` (BWK awk 20200816) supports it (checked), as do gawk and mawk, so no counter-and-`next` fallback is needed. One `while IFS=$'\t' read -r f ra rp wr wt` loop over `hdrs` then adds `wordpress` at the file's dir (version `ra`), writes `headers`, appends the dir to `plugins` for a `*.php`, and adds `woocommerce` at the file's dir (version `wr`) when `wr` or `wt` is not `-`. Versions go through `norm_version`, so a `-` becomes `unknown`.
   - **Tailwind CSS:** one `tr '\n' '\0' < "$TMP/css" | xargs -0 grep -l -E -- "$TW_RE" > "$TMP/twcss" || true` (`TW_RE` is the rules-table `@import` ERE; grep exits 1 when nothing matches), then a `tailwind` record at each listed file's nearest package root.
   - **`woocommerce_` hooks:** filter `php` to the files under any plugin path (P is `.`, or the rel path starts with `P/`; a bash `case`, no fork), write that list to `$TMP/plphp` and, if it is non-empty (`[ -s ]`), run one `tr '\n' '\0' < "$TMP/plphp" | xargs -0 grep -l -E -- "$HOOK_RE" > "$TMP/hooked" || true` (GNU `xargs` runs the command once on empty input and grep would then read stdin, hence the guard), then add one `woocommerce` record at each plugin path P that has a hooked file under it. One grep over the union replaces one grep per plugin path.
   - For `wp-config.php` / `wp-content` paths, read `<P>/wp-includes/version.php`. A `*.csproj` resolves its dir with an ancestor `*.sln` check, using a glob under `shopt -s nullglob`.
8. Merge and print with one jq program over `--rawfile`, not `-Rs`: split the lines, then `group_by([.path, .profile])`. Version: the lowest-rank non-`unknown` value, else `"unknown"`. Evidence: `map(.evidence) | unique`. Apply the overlay rule: `(map(select(.profile == "wordpress") | .path)) as $wp | map(select(.profile != "woocommerce" or (.path as $p | any($wp[]; . == $p or $p == "." or startswith($p + "/")))))`. Then `sort_by([(.path != "."), .path, (if .profile == "tailwind" or .profile == "woocommerce" then 1 else 0 end), .profile])` and emit `{profile, path, version, evidence}` with `-c`. An empty `rec` gives `[]`.

Bash 3.2 and lint constraints: no `sed -i`, `grep -P`, `readlink -f`, `stat`, `mapfile` or `declare -A`. Every function ends with `return 0`. Arrays that can be empty use `${a[@]+"${a[@]}"}`.

**Step 4: GREEN for the new file.** `bats tests/scripts/detect-stack.bats`: all pass. Then `npx --yes shellcheck --shell=bash -x -P SCRIPTDIR scripts/detect-stack.sh` is clean.

**Step 5: run conventions and capture RED for the narrowing.**

```bash
bats tests/scripts/conventions.bats
```

Expected: `subcommand scripts with no arguments exit 1 …` fails with `…/detect-stack.sh: exit 0 (want 1)`, because it scans the temp dir and prints `[]`. The `--help` and bad-option tests already pass for `detect-stack.sh`. Keep that output.

**Step 6: narrow the rule** in `tests/scripts/conventions.bats`. Replace the `subcommand)` line of `script_files` with:

```bash
    # A script whose Usage line names only optional arguments ("name [x]") may
    # succeed with none, so only scripts naming a required argument are kept.
    subcommand)
      for f in "$SCRIPTS"/*.sh; do
        case "$(sed -n '2s/^# Usage: [^ ]* *//p' "$f")" in
          '['*) ;;
          *) printf '%s\n' "$f" ;;
        esac
      done
      ;;
```

Rename the test to `"scripts whose Usage names a required argument exit 1 with no arguments, with error: on stderr"`. Leave the file header ("never edit this file to add one") as it is: no script is added here, the rule is narrowed. The bad-option and `--help` rules still apply to every script.

**Step 7: GREEN.** `bats tests/scripts/conventions.bats` passes, then `tests/run-script-tests.sh` passes (shellcheck plus every bats file). Check that the narrowed rule still covers the seven existing scripts: `for f in scripts/*.sh; do sed -n '2s/^# Usage: [^ ]* *//p' "$f"; done` shows that only `detect-stack.sh` starts with `[`.

**Step 8: commit.**

```
feat(scripts): add detect-stack.sh stack detection

Prints a JSON array of {profile, path, version, evidence} for nextjs, react,
laravel, wordpress and dotnet, with tailwind and woocommerce overlays, scanning
to depth 3 with build and dependency dirs pruned. Order is deterministic: path,
base before overlay, profile name.

conventions.bats now applies its no-argument rule only to scripts whose Usage
names a required argument, because detect-stack.sh [path] defaults to ".".

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task A4 — `detect-stack.sh fingerprint <profile> [path]`

- **id:** A4
- **files:** `scripts/detect-stack.sh`, `tests/scripts/detect-stack.bats`
- **depends_on:** [A3]
- **pattern:** A3's scan and records (reused, not duplicated: refactor A3's main flow into a `detect_json` function that both forms call), and the subcommand dispatch shape in `scripts/state.sh`
- **ACs:** AC-4, AC-5 (fingerprint half), AC-6 (re-run)

**Step 1: append the failing tests** to `tests/scripts/detect-stack.bats`:

```bash
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
  done <<'EOF'
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
EOF
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
```

The `[[ … ]]` inside the format-table loop sits in an `if` condition, which is safe. Standalone regex checks use `assert_match`.

**Step 2: run and capture RED.** Run `bats -f 'fingerprint|cfg|bump|unrelated|php comes|several paths|not detected|tracked' tests/scripts/detect-stack.bats`. Expected: they fail, because `fingerprint` is taken as a path, giving `error: not a directory: fingerprint` and exit 1 where success was asserted. The "not detected" and "no profile" tests may pass by accident (exit 1 plus `error:`); note this in the report, because the other nine are the real RED.

**Step 3: implement.**

- Move A3's scan → records → jq flow into `detect_json` (it prints the array). The default form calls it and prints.
- Dispatch: if `$1 = fingerprint`, shift. A missing profile → `die "fingerprint needs a profile"`. The same option, arity and path checks then apply, sharing the code with the default form.
- `PATH_OF=$(detect_json | jq -r --arg p "$PROFILE" 'map(select(.profile == $p)) | .[0].path // empty')`, plus the version. If it is empty → `die "profile not detected: $PROFILE"`. Check the status explicitly.
- Majors per the contract table. The primary comes from the entry `version`. Secondaries come from `<path>/package.json` or `<path>/composer.json` through jq, and for `wordpress` from the `Requires PHP` field of its header file's line in `$TMP/hdrs` (the header recorded in `$TMP/headers`; no re-read; `-` means not declared, so `php` is omitted, otherwise the value goes through `norm_version`). `major() { case $1 in unknown) echo unknown ;; *) echo "${1%%.*}" ;; esac; return 0; }`.
- Config files: a `case "$PROFILE"` sets a glob list; expand it in `<path>` and in `.` with `shopt -s nullglob`; keep readable regular files only (`[ -f ] && [ -r ]`, so `cat` in the hash pipeline cannot fail); build rel paths (`name` for `.`, `<path>/name` otherwise); add the `twcss` entries under `<path>` for `tailwind`; then de-duplicate and sort with `LC_ALL=C sort -u`.
- Hash: pick the SHA-256 tool with `shasum -a 256` if `command -v shasum` succeeds, else `sha256sum`, else `die`. Then `{ while IFS= read -r rel; do printf '%s\0' "$rel"; cat -- "$rel"; printf '\0'; done < "$TMP/cfgs"; } | <tool> | cut -c1-12`.
- Print `"$PROFILE" + deps + " cfg:$hash"`.
- Header: add the fingerprint lines from the contract's final `--help` text.

**Step 4: GREEN.** `bats tests/scripts/detect-stack.bats` passes (all A3 and A4 tests). Then `tests/run-script-tests.sh` passes. Then `scripts/detect-stack.sh --help | head -3` shows both Usage lines.

**Step 5: commit.**

```
feat(scripts): add detect-stack.sh fingerprint subcommand

fingerprint <profile> [path] prints "<profile> <dep>@<major>... cfg:<hash12>"
for the profile's first detected path: tracked majors plus the first 12 hex
of SHA-256 over its tool configs in that dir and the scanned root. Manifests
are not hashed, so minor bumps and unrelated edits leave it unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

## Phase verification (after A4 and A2)

```bash
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                                   # shellcheck + all bats: green
bats tests/scripts/detect-stack.bats tests/scripts/conventions.bats tests/scripts/hooks-guard-bash.bats
for n in nextjs-tailwind react-vite laravel wordpress-theme woocommerce-plugin dotnet-api monorepo; do printf '%s ' "$n"; scripts/detect-stack.sh "tests/fixtures/stacks/$n" | jq -c 'map(.profile+"@"+.path)'; done
scripts/detect-stack.sh fingerprint nextjs tests/fixtures/stacks/nextjs-tailwind
claude plugin validate .                                    # unchanged: still passes
git status --porcelain                                      # only this phase's files
```

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-1 output shape, order, `[]`, bad path | A3 | shape, order, empty, missing/file/extra, unreadable, stable-output tests |
| AC-2 rules | A3 | per-rule tests (nextjs/react, tailwind ×3, laravel, wordpress ×4 plus the 8 KB limit, woocommerce ×4 plus the base rule with its Bedrock positive, dotnet) |
| AC-3 depth 3, pruning, monorepo | A3 (+A1 monorepo) | depth, pruned-dirs and fixture-copy `node_modules` tests; monorepo fixture |
| AC-4 fingerprint | A4 | format, recipe, stability, sensitivity, major vs minor, unrelated, not-detected tests |
| AC-5 bats file | A3 + A4 | `tests/scripts/detect-stack.bats` |
| AC-6 bash 3.2, strict mode, shellcheck, `--help`, conventions | A3 (+A4 re-run) | `tests/run-script-tests.sh`; narrowed no-argument rule; bad-option and `--help` rules still apply |
| AC-12 no agent `gh` (enforcement) | A2 | two new `@test` blocks; existing main-thread table row; DESIGN §11 bullet. The prompt and frontmatter half belongs to Phases C and D |
| AC-14 fixtures | A1 (+A3 assertion) | seven trees plus `*.expected.json`; the fixture test |

## Decisions and refinements in this phase (flag if wrong)

1. **The fingerprint `[path]` is the project root**, with the first entry in detection order (spec Assumption 7). Phase D's step 4 must call `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" fingerprint <profile> .` from the project root (see the contract note). This is a required micro-revision of Phase D, not a Phase A blocker.
2. **Per-profile config sets** (the contract table) refine spec Assumption 6's single union list. `.editorconfig` is in every set; prettier is in the JS sets only; the Tailwind CSS import files are in the `tailwind` set only (spec-review note 3 churn: accepted).
3. **Primary dep always printed** (`@unknown` if unparseable); **secondary deps omitted when not declared.** This reconciles spec Assumption 1's "major is `unknown`" with Assumption 6's "absent dependency omitted".
4. **dotnet:** dep name `dotnet`; a `.csproj` belongs to the nearest ancestor `.sln` dir, so a standard `sln` at the root with `src/<App>/<App>.csproj` gives one entry at `.`. `net8.0;net9.0` takes the first.
5. **WooCommerce version:** `WC requires at least:` first, then the composer dependency. `@woocommerce/*` npm packages count as evidence only, because their versions are not WooCommerce's. WC headers are read only from the Plugin Name / Theme Name header files.
6. **Evidence contract:** the triggering relative path, then optionally `: <detail>`, unique and sorted. Expected fixture files pin `{profile, path, version}` only, so evidence wording can improve without touching fixtures.
7. **Tailwind `@import` match** also accepts subpaths (`"tailwindcss/…"`) and single quotes.
8. **Hash byte stream:** `relpath NUL content NUL` per file (spec Assumption 6 said `relative-path\0content`; the trailing NUL separates entries unambiguously).
9. **stdout is compact** (one line). Consumers parse it as JSON.

## Risks

- **A narrowed convention rule could hide a future required-argument script** whose Usage line is mistakenly written `[x]`. Mitigation: the bad-option and `--help` rules still apply, and Step 7 of A3 lists which scripts the rule exempts.
- **The guard is hot in every session.** The change adds one `jq` call for `.agent_type`. The existing "under a second" test still covers it; to drop the extra call, both fields could be read in one `jq` call, but that is not needed.
- **A global gitignore may drop fixture files** (`*.sln`, dotfiles). Mitigation: A1's Step 3 checks for ignored files.
- **Bats on bash 3.2:** a failing `[[ ]]` or `!` that is not the last line does not fail a test. The plan uses `assert_match`, `refute_equal` and `[ ]` throughout.
- **BSD `find` order is not sorted.** Every list goes through `LC_ALL=C sort`, and the final order is set by jq, never by `find`.

## Approval

- Senior architect: APPROVED on 2026-10-24T14:23:04Z (plan-diff-review of the revision round)
- Plan format: FULL (phase A of EPIC)
- Plan dependency graph: unchanged by the revision (no `files:` or `depends_on:` edits).
- Plan content hash (SHA-256): bb7bd8a47d2633f8e307cfba98fd501195f9c0c96f26d560cbbc16775c4874b6 (everything above `## Approval`)
- Diff-reviewed 2026-10-24T14:23:04Z: M1 overlay (W == P, P == ".", or W under P/) with the Bedrock positive and lib/loose negatives, single awk header pass and one `grep -l -E` per CSS/hook list, `deny()` optional tail (one-arg calls unchanged), `major()` `return 0`, `${1-.}` + empty-path test all confirmed; mechanical clarifications applied (`-` → `norm_version`/omitted `php`, guarded `plphp`/`hooked` hook pass).
