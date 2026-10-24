# Phase A plan — Foundation: shared library, run state, test harness

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** A of the EPIC (B, C and D are planned and implemented in parallel after A)
- **Depth:** full
- **ACs covered:** AC-1, AC-2, AC-3, AC-4, AC-25, AC-26, AC-27, AC-28
- **Risk:** none. All tasks NOT RISKY: new files only, no schema or template changes, no network in tests beyond the `npx` tool downloads (A34).
- **Date:** 2026-10-24

## Purpose

Phase A builds the contracts every later phase depends on: `scripts/lib/common.sh`, `scripts/state.sh`, the bats harness (helpers plus a stateful `gh` PATH shim), `tests/run-script-tests.sh`, and the glob-driven convention checks (`--help`, bad input, shebang and strict mode, bash 3.2 lint, shellcheck). Phases B, C and D then **add scripts and fixture files only**. They never edit an A-owned file (see "Interface contract" below, which is the authoritative reference for them).

## Facts verified while planning (not assumptions)

- The `ajv` command documented in `CLAUDE.md` (`npx ajv-cli validate --spec=draft2020 -s templates/state.schema.json …`) **fails** on `state.schema.json` with `unknown format "date-time"`. The working command, about 1 s warm, is:
  `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s <schema> -d <file1> -d <file2> …`
  It accepts several `-d` flags or a quoted glob, so a whole test file's snapshots validate in one call. A real bad `date-time` is rejected. **Decision for the closing task or human:** correct the `CLAUDE.md` Commands block. Phase A does not edit `CLAUDE.md`.
- `npx --yes shellcheck --version` works: it downloads ShellCheck 0.11.0 into the npx cache in about 8 s cold. `shellcheck --shell=bash -x -P SCRIPTDIR` follows `# shellcheck source=lib/common.sh` directives from any cwd.
- bats 1.14.0 (`run --separate-stderr`, `BATS_FILE_TMPDIR`, `bats_require_minimum_version`), jq 1.7.1 (`--rawfile`, `halt_error`), git 2.54 (`init -b`, `rev-parse --path-format=absolute --git-common-dir`, `GIT_CONFIG_GLOBAL`), perl with `Time::HiRes` at `/usr/bin/perl`.
- In bash 3.2, `"${arr[@]}"` on an empty array under `set -u` is a fatal "unbound variable" error. Use `${arr[@]+"${arr[@]}"}`.
- macOS `$TMPDIR` lives under `/var/folders/…`, which is a symlink to `/private/var/…`, and `git rev-parse` returns the physical path. Test fixtures must canonicalise with `cd … && pwd -P`, or path assertions fail.
- Inside a function, `BASH_SOURCE[0]` is the file that defines the function, so `common.sh` can locate the plugin root from its own path.

## Interface contract (what B, C and D rely on — do not change without a dependency note)

### `scripts/lib/common.sh`

Sourced as `. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`, preceded by `# shellcheck source=lib/common.sh` (from `scripts/hooks/`, the path is `../lib/common.sh`; from `scripts/lib/`, e.g. D's `hooks.sh`, it is `common.sh`). At source time it does only four things: `set -euo pipefail`, defines functions, sets a non-exported double-source guard, and records its own absolute path in a non-exported variable (pure parameter expansion, no fork: `$PWD/` is prefixed when `BASH_SOURCE[0]` is relative), so `plugin_root` stays correct after the caller `cd`s. It produces no output, runs no git or jq, and sets no traps. Every function is bash 3.2 safe. Value-printing functions are meant for `x=$(fn …)`. Their `die` exits the subshell with status 1, so callers that must not abort write `x=$(fn …) || handle`.

**Strict-mode caveat (verified on `/bin/bash` 3.2.57, load-bearing for every phase).** bash 3.2 does **not** apply `set -e` inside `$(…)`: `x=$(false; echo hi)` yields `hi` with status 0. `set -e` is also off inside any function called from `if`, `while`, `!`, `&&` or `||`. So a value-printing function (or any function that may be called in a condition) must never rely on errexit internally: every command whose failure matters is checked explicitly (`root=$(repo_root "$d") || return 1`, `out=$(jq …) || die …`). Never `local x=$(…)` (it masks the status; shellcheck SC2155). Top-level script code may rely on errexit as normal.

**Fail-open (for D).** `die` uses `exit`, so a hook's `trap … EXIT` sees and can override it; an ERR trap alone does not (it never fires for `exit`, and does not fire inside functions without `set -E`). Hooks parse `$1` (`--help`, bad option) **before** installing the fail-open EXIT trap, so convention 4's exit 1 survives. Exit 1 never blocks any event.

| Function | Signature | Behaviour |
|---|---|---|
| `info` | `info <msg…>` | stderr: `<script>: <msg>` (`<script>` = `${0##*/}`). Never fails. |
| `warn` | `warn <msg…>` | stderr: `<script>: warning: <msg>`. Never fails. |
| `die` | `die <msg…>` | stderr: `<script>: error: <msg>`, then `exit 1`. It uses `exit`, never `kill`, so a caller's `trap … EXIT` runs and **can replace the status** (`trap 'exit 0' EXIT` makes `die` exit 0). Hooks rely on this to fail open. |
| `require_cmd` | `require_cmd <cmd>…` | Returns 0 if every command is on `PATH`. Otherwise `die "required command not found: <cmd>"`, naming the first missing one. |
| `plugin_root` | `plugin_root` | Prints `$CLAUDE_PLUGIN_ROOT` (trailing `/` removed) if it is set and non-empty. Otherwise prints the physical path two levels above `common.sh`, using the absolute path recorded at source time (correct even after the caller `cd`s). No trailing slash. |
| `repo_root` | `repo_root [dir]` | Prints the **main worktree root** for `dir` (default `$PWD`): the parent of `git -C dir rev-parse --path-format=absolute --git-common-dir`. It is identical from a linked worktree, physical path, no trailing slash. If the common dir's basename is not `.git` (submodule, `--separate-git-dir`), it falls back to `git -C dir rev-parse --show-toplevel`. Outside a git repo: `die "not inside a git repository: <dir>"` (git's own stderr suppressed). One `git` spawn in the normal case. |
| `config_get` | `config_get <dotted.path>` | Reads `$(repo_root)/.aew/config.json` (a missing file is treated as `{}`). If the path holds a non-null value (including `false`, `0` or `""`), prints it. Otherwise prints the schema default from `$(plugin_root)/templates/config.schema.json`, checking the deepest leaf `default` first, then each ancestor object's `default` (for example `git.branch_pattern` checks `properties.git.properties.branch_pattern.default`, then `properties.git.default.branch_pattern`). Strings print raw; anything else prints compact JSON (`true`, `3`, `["a"]`). If there is neither a value nor a default: `die "config: no value or default for '<path>'"`. Invalid JSON in the config: `die "config: invalid JSON in <file>"`. Schema file missing (for example a wrong `CLAUDE_PLUGIN_ROOT`): `die "config: schema not found: <path>"`, checked before the `jq` call so it is never misreported as invalid config. Malformed path (must match `^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$`; no array indices): `die`. Exactly one `jq` call (plus `repo_root`'s `git`). |
| `is_run_id` | `is_run_id <s>` | Returns 0 if `s` matches `^([1-9][0-9]*\|m-[1-9][0-9]*)$` (the schema pattern), else 1. No output. |
| `run_dir` | `run_dir [run-id]` | With an id: validates it with `is_run_id` (`die "invalid run id: <id>"` otherwise) and prints `$(repo_root)/.aew/runs/<id>`. The directory need not exist. Without an id: reads the first line of `$(repo_root)/.aew/runs/current` (trailing whitespace and `\r` stripped), validates it, and prints the same path. If the file is missing or empty: `die "no current run (.aew/runs/current not set)"`. It does not check that `state.json` exists. |
| `print_usage` | `print_usage <file>` | Prints the file's header comment block to stdout: the contiguous `#` lines after the shebang, with `# ` (or a bare `#`) removed. The block must start with `Usage:`. Used by every `--help`. |
| `lib_main` | `lib_main <file> [arg…]` | For libraries executed directly. `-h`/`--help` runs `print_usage <file>` and exits 0. Anything else runs `die "<basename> is a library: source it, don't run it"`. The last line of each lib is `if [ "${BASH_SOURCE[0]}" = "$0" ]; then lib_main "$0" "$@"; fi`. **`scripts/lib/hooks.sh` (D) must end with the same line.** |

Root-dependent functions (`config_get`, `run_dir`) resolve from `$PWD`. A hook that resolves its project from `CLAUDE_PROJECT_DIR` or the payload `cwd` does `cd "$dir"` first. `common.sh` does not read `CLAUDE_PROJECT_DIR`. That precedence belongs to D's `hooks.sh`.

### Script conventions (enforced by `tests/scripts/conventions.bats`, which globs `scripts/*.sh`, `scripts/lib/*.sh` and `scripts/hooks/*.sh`)

1. Executables (`scripts/*.sh`, `scripts/hooks/*.sh`) have mode `+x`, their first line is `#!/usr/bin/env bash`, and they source `lib/common.sh` (or contain `set -euo pipefail`). Libraries (`scripts/lib/*.sh`) have the same shebang and end with the `lib_main` line.
2. Every file's line 2 onward is a `#` header block beginning `Usage:`. That block is the `--help` text.
3. `--help` or `-h` as `$1` prints usage on stdout and exits 0. It must work from a **non-git directory**, with no config, with `CLAUDE_PLUGIN_ROOT` unset and stdin at `/dev/null`. So handle it before any `require_cmd`, `repo_root` or stdin read.
4. An unrecognised option as `$1` (the loop uses `--definitely-not-an-option`) exits **exactly 1** with nothing on stdout and `error:` on stderr (via `die`), without reading stdin. Hooks must check `$1` before reading their payload. Exit 2 is never used for bad arguments, because it blocks in `PreToolUse`.
5. `scripts/*.sh` (subcommand scripts) run with **no arguments** exit 1 with `error:` on stderr (for example `die "missing subcommand (see --help)"`). Hooks are exempt, because they are invoked with no arguments.
6. bash 3.2 lint: no non-comment line matches any of these constructs: `declare -A`/`local -A`/`typeset -A`, `mapfile`, `readarray`, `${v,,}`/`${v^^}`/`${v,}`/`${v^}`, `${v@Q}`-style transformations, `declare -n`/`local -n`, `|&`, `&>>`, `coproc`, `wait -n`, `globstar`, `EPOCHREALTIME`/`EPOCHSECONDS`/`SRANDOM`, `${a[-1]}`, `sed -i`, `date -d`, `stat -c`/`stat -f`, `readlink -f`, `grep -P` (macOS `/usr/bin/grep` rejects it: "invalid option -- P", verified). For mtime comparisons use `[ a -nt b ]`, `find -newer` or `perl`.
7. shellcheck clean under `--shell=bash -x -P SCRIPTDIR` (run by `tests/run-script-tests.sh` over the three script globs plus `tests/run-script-tests.sh`, `tests/scripts/helpers/*.bash` and `tests/scripts/helpers/bin/*`).

### Bats helpers — `tests/scripts/helpers/common.bash`

Each bats file starts with `load helpers/common` at top level and calls `common_setup` first in `setup()`. Loading prepends `tests/scripts/helpers/bin` to `PATH` (so **no test can reach the real `gh`**) and calls `bats_require_minimum_version 1.5.0`.

| Name | Purpose |
|---|---|
| `REPO_ROOT`, `SCRIPTS`, `FIXTURES` | Plugin repo root (physical path), `$REPO_ROOT/scripts`, `$REPO_ROOT/tests/scripts/fixtures`. Set at load. |
| `common_setup` | Per test: unsets `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` (so they don't leak from a Claude session). Exports `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1` and the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` identity. Exports `GH_MOCK_DIR=$BATS_TEST_TMPDIR/gh` (created empty). `cd "$BATS_TEST_TMPDIR"`. Leaves `HOME` untouched, so the npx cache keeps working. |
| `setup_project [--no-config]` | Creates a git repo at `$BATS_TEST_TMPDIR/project` (`git init -b main`), writes `.gitignore` (`.aew/runs/`) and `.aew/config.json` (a copy of `templates/config.example.json`, unless `--no-config`), makes one commit, `cd`s into it, and exports `PROJECT` as the **physical** path. Afterwards the tree is clean. |
| `write_config <json>` | Overwrites `$PROJECT/.aew/config.json` with `<json>`. It does not commit, so the tree is dirty afterwards. |
| `run_lib <lib-basename> <fn> [arg…]` | `run --separate-stderr bash -c '. "$1"; shift; "$@"' "<lib>" "$SCRIPTS/lib/<lib>" <fn> [arg…]`. The path is passed as an argument (bats does not export `SCRIPTS`), and `$0` in the child is the lib basename, so log prefixes read `common.sh: error: …` / `hooks.sh: warning: …`. It tests a library function in a child shell, so strict mode never leaks into bats. Example: `run_lib common.sh config_get default_branch`. |
| `run_hook <hook-basename> <json\|@file>` | Runs `$SCRIPTS/hooks/<hook>` with the JSON string (or the file after `@`) on stdin, using `run --separate-stderr`. |
| `elapsed_ms <cmd…>` | Runs the command (stdin, stdout and stderr discarded) and prints wall-clock milliseconds, measured with `perl -MTime::HiRes`. |
| `seed_run <run-id> [state.sh init option…]` | Calls the real `state.sh init <run-id>` with the defaults `--issues <run-id, or 1 for m-*> --mode single --title "Test run"`, overridden by any options given. It needs `setup_project` first. Added in A4. |
| `assert_success`, `assert_failure [status]` | Check `$status`. On a mismatch they print `$status`, `$output` and `$stderr`. |
| `assert_equal <actual> <expected>` | String equality with a diff-style message. |
| `assert_contains <haystack> <needle>`, `refute_contains …` | Substring checks. |
| `assert_json <file> <jq-expr>` | Passes when `jq -e "<jq-expr>" <file>` is true. Example: `assert_json "$d/state.json" '.stage == "brief"'`. |
| `validate_json_schema <schema> <file>…` | One `npx ajv` call (the command above) over every file. On failure it prints ajv's output and returns non-zero. |
| `gh_mock_issue <n> [--from <json-file>] [--body-file <f>] [--body <s>] [--labels a,b,…]` | Seeds the stateful issue store (see the shim). |
| `gh_mock_body <n>` / `gh_mock_labels <n>` | Prints the stored body (raw bytes, no added newline) or the labels (sorted, one per line). |
| `gh_mock_respond <route> <stdout-file\|-> [exit-code] [call-number]` | Canned response for a route such as `pr-create`. `-` reads stdin (heredoc). With a non-zero exit code, the content goes to **stderr**. With `call-number k`, it applies only to the k-th call of that route. |
| `gh_calls` | Prints `calls.log`. |
| `assert_gh_called <substring>`, `refute_gh_called <substring>` | Checks whether any `calls.log` line contains the substring. |
| `gh_call_count [substring]` | Prints the number of calls (matching the substring, if given). |
| `gh_captured_file <substring>` | Prints the path of the file captured from the **latest** call whose line contains the substring (for example the posted comment body). |

### `gh` PATH shim — `tests/scripts/helpers/bin/gh`

A bash 3.2 executable. If `GH_MOCK_DIR` is unset it prints `gh mock: GH_MOCK_DIR not set` and exits 99, so a test can never fall through to the real `gh`. Store layout:

```
$GH_MOCK_DIR/
  calls.log                     one line per invocation: the args joined by single spaces,
                                with embedded newlines written as the two characters \n
                                (e.g. `issue edit 12 --add-label aew:building`)
  files/<NNN>-<basename>        byte copy of every file passed via --body-file / -F / --input
                                (NNN = zero-padded 1-based call index; `-` = stdin, saved as `stdin`)
  issues/<n>/base.json          base object for `issue view` (default: {number, title:"Issue <n>",
                                state:"OPEN", url:"https://github.com/acme/widgets/issues/<n>"})
  issues/<n>/body               authoritative raw body bytes (CRLF preserved)
  issues/<n>/labels             label names, sorted and unique, one per line
  responses/<route>[.<k>].out   canned output (route = "<arg1>-<arg2>", e.g. issue-list, pr-create, api-graphql;
                                every char outside [A-Za-z0-9._-] becomes "_", so
                                `gh api repos/o/r/issues/5` → api-repos_o_r_issues_5)
  responses/<route>[.<k>].code  exit code (default 0); non-zero means .out is written to stderr
  counters/<route>              per-route call counter (for the .<k> sequencing)
```

Scripts under test always put the subcommand first (`gh issue view …`, never `gh -R o/r issue view …`), so the route is always the first two arguments. `-R`/`--repo <r>` after the subcommand is logged and otherwise ignored by the stateful routes.

Dispatch order for every call:

1. Append to `calls.log` and capture body files. Only values that are `-` (stdin) or an existing regular file are captured; anything else (for example `gh api -F key=value`, where `-F` is a field, not a file) is just logged.
2. If a canned response exists for the route (the call-specific `.<k>` first, then the plain one), serve it.
3. **Stateful routes**:
   - `issue view <n> [--json f1,f2…] [--jq/-q expr]` returns `base.json` with `body` (from `--rawfile`, byte exact) and `labels` (`[{name}]`) overridden. The result is projected to the `--json` fields, then `--jq` is applied. Without `--json` it prints the whole merged object (scripts always pass `--json`). An unseeded issue prints `GraphQL: Could not resolve to an issue or pull request with the number of <n>.` to stderr and exits 1.
   - `issue edit <n>` applies, in order, every `--body-file f` / `-F f` / `--body s` (byte-exact replace) and every `--add-label` / `--remove-label` (comma lists, repeatable; removing an absent label is a no-op). An unseeded issue exits 1.
4. Any other route: exit 0 with empty stdout. Write commands such as `label create`, `issue comment`, `pr edit` and `pr ready` need no setup; their effect is asserted through `calls.log` and `files/`.

**Fixture ownership.** `tests/scripts/fixtures/` is shared, but each phase writes only in its own subdirectory: B `fixtures/issue/` and `fixtures/labels/`; C `fixtures/pr/`, `fixtures/milestone/`, `fixtures/retro/` and `fixtures/branch/`; D `fixtures/hooks/`. Each bats file is named after its script (`gh-issue.bats`, `state.bats`, `hooks-guard-bash.bats`, …). A adds no fixture files.

### `scripts/state.sh` (used by every later phase's tests through `seed_run`)

`state.sh` acts only on the **current** run (a `--run` option is out of scope). A script that takes an explicit run id (C's `gh-pr.sh create <run-id>`) or must avoid a process spawn (D's gates) reads that run directly: `d=$(run_dir "$id") || …`, then `jq -r '.issues[]' "$d/state.json"` (or the field it needs). Phases never write `state.json` except through `state.sh`.

```
state.sh init <run-id> --issues <n,…> --mode <mode> [--auto] [--title <t>]
state.sh get [field]                 # whole state (pretty JSON) or one top-level field
state.sh stage <stage> [--note <n>]  # also sets status running
state.sh status <status> [--note <n>]
state.sh bump fix_cycle|review_cycle # prints the new value
state.sh set <field> <value>         # title | branch | base_branch | pr | spec_revision | auto
state.sh current [set <run-id>|clear]
```

All subcommands except `init` and `current set` act on the run in `.aew/runs/current`. `get <field>` uses the same output convention as `config_get`: strings raw, everything else compact JSON, and `null` printed as `null`. `log.md` line format: `- <at> <stage> <status>` or `- <at> <stage> <status> — <note>`. Timestamps: `date -u +%Y-%m-%dT%H:%M:%SZ`.

## Tasks

Order is linear (A1 → A2 → A3 → A4): each task's tests use the previous task's helpers or conventions, and A4 is the first real script the convention loops see.

---

### A1 — Bats harness, stateful `gh` shim and test entry point

- **files:** `tests/run-script-tests.sh` (new, `+x`), `tests/scripts/helpers/common.bash` (new), `tests/scripts/helpers/bin/gh` (new, `+x`), `tests/scripts/gh-mock.bats` (new)
- **depends_on:** []
- **pattern:** No in-repo analog (greenfield; spec "Key facts"). Contract: spec A33 and A34, `CLAUDE.md` script rules, and the "Bats helpers" and "`gh` PATH shim" sections above. Net-new surface is justified because no test harness exists and AC-27 requires one.
- **RISKY:** NOT RISKY
- **AC verified:** AC-26 (the runner runs shellcheck), AC-27 (runner, PATH shim recording args, stateful store, fixture JSON), AC-28 (shim and helpers are bash 3.2)
- **implementation notes:**
  - `run-script-tests.sh`: `--help` via its own header. `cd` to the repo root. Preflight `bats`, `jq`, `git`, `npx` and `perl`. A missing `bats` prints a `brew install bats-core` hint and exits 1 (A35). Resolve shellcheck as `shellcheck` on `PATH`, else `npx --yes shellcheck`. If neither runs `--version`, fail with a `brew install shellcheck` hint (A34). Collect files with `shopt -s nullglob` over `scripts/*.sh scripts/lib/*.sh scripts/hooks/*.sh tests/run-script-tests.sh tests/scripts/helpers/*.bash tests/scripts/helpers/bin/*`, and run `shellcheck --shell=bash -x -P SCRIPTDIR` once over all of them. Then run `bats "${@:-tests/scripts}"`. Print the `bash --version` first line for the record. Exit non-zero if shellcheck **or** bats fails, but always run both. The runner cannot source `common.sh` (it doesn't exist yet in A1, and it is test tooling), so it has its own `set -euo pipefail` and its own two-line `die`.
  - `common.bash`: the helpers in the contract table, except `seed_run` (A4). Use a file-level `# shellcheck disable=SC2154` with a comment, because bats injects `status`, `output`, `stderr` and `BATS_*`. `REPO_ROOT` is `cd "$BATS_TEST_DIRNAME/../.." && pwd -P`.
  - `bin/gh`: implements the dispatch order above. Parse with a `while`/`case` loop. jq builds the `issue view` JSON (`--rawfile body`, `--argjson labels`). Label sets use `sort -u`. No bash 4 features. Keep it minimal (spec risk "mock fidelity"): only `issue view` and `issue edit` are stateful.
- **test scenarios (`gh-mock.bats`)**. Write these first. RED: all fail with `gh mock` or `command not found`, or with a helper undefined.
  1. After `load`, `command -v gh` is `$REPO_ROOT/tests/scripts/helpers/bin/gh`.
  2. `GH_MOCK_DIR` unset → exit 99 with `GH_MOCK_DIR not set`.
  3. Every call appends exactly one space-joined line to `calls.log`. An argument containing a newline is recorded as `\n`. `assert_gh_called`, `refute_gh_called` and `gh_call_count` behave correctly.
  4. `gh_mock_issue 5 --body-file <CRLF fixture written in-test> --labels aew:building,bug`, then `gh issue view 5 --json body,labels`: `jq -j .body` is byte-identical (`cmp`) to the input, labels are `["aew:building","bug"]`, and no other keys are present.
  5. `--jq '.labels[].name'` is applied. `-q` works as an alias.
  6. `issue edit 5 --body-file f` replaces the body byte-exact. `gh_captured_file 'issue edit 5'` is a byte copy of `f`. `--body-file -` reads stdin.
  7. `issue edit 5 --add-label a,b --remove-label aew:building --add-label a` → labels `a`, `b`, `bug` (sorted, unique). Removing an absent label is a no-op.
  8. `issue view 404` / `issue edit 404` (unseeded) → exit 1 and the GraphQL-style message on stderr.
  9. `gh_mock_respond pr-create - <<<URL` → stdout is the URL. `gh_mock_respond issue-create - 0 2` serves only the second call, and the plain response serves the others. A non-zero code sends the content to stderr and returns that code.
  10. Unknown route (`gh label create x --force`) → exit 0, empty stdout, recorded. `gh_mock_respond api-repos_o_r_issues_5 -` is served for `gh api repos/o/r/issues/5`. `gh api graphql -F n=5` logs the call and captures no file. `gh issue view 5 -R acme/widgets --json body` behaves like the call without `-R`.
  11. `setup_project` yields a clean git tree (`git status --porcelain` empty), `.aew/config.json` present, `PROJECT` equal to `pwd -P`, and branch `main`. With `--no-config`, there is no config.
  12. `elapsed_ms true` prints an integer below 1000.
  13. `tests/run-script-tests.sh --help` exits 0 with `Usage:`.
- **verify:** `bats tests/scripts/gh-mock.bats` green, then `tests/run-script-tests.sh` green (shellcheck over the runner, helpers and shim).
- **commit:** `test: add bats harness, stateful gh PATH shim and run-script-tests.sh`

---

### A2 — Shared library `scripts/lib/common.sh`

- **files:** `scripts/lib/common.sh` (new), `tests/scripts/common.bats` (new)
- **depends_on:** [A1]
- **pattern:** The `common.sh` contract table above. Spec AC-1, A6 (plugin-root fallback through `BASH_SOURCE`), and "Key facts" (main worktree root through `--git-common-dir`). `templates/config.schema.json` for the two-level defaults. No in-repo analog. A new file is justified because DESIGN deliverable 1 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-1 (every function has a bats test), AC-28
- **implementation notes:**
  - `config_get` does one `jq -n` with `--slurpfile cfg <config or /dev/null>` and `--slurpfile sch <schema>`. `$k = path | split(".")`. Value = `try ($cfg[0] | getpath($k)) catch null`. If it is null, walk `i` from `len` down to 1 over `getpath([$k[:i][] | ("properties", .)] + ["default"]) | getpath($k[i:])` (each wrapped in `try … catch null`), and take the first non-null. **Never use `//`**, because it discards `false`. Not found → `halt_error(3)`. The bash side maps jq status 3 to the "no value or default" die and any other non-zero status to the invalid-JSON die.
  - `repo_root`: `git -C "${1:-$PWD}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null`, explicitly checked (`|| die …`), then `dirname`, then `cd … && pwd -P`. Submodule fallback per the contract.
  - `config_get`, `run_dir`: call `repo_root` as `root=$(repo_root) || return 1` (or `|| exit 1`). Never rely on errexit inside these functions (see the strict-mode caveat).
  - `plugin_root`: use the absolute `common.sh` path recorded at source time, not `BASH_SOURCE[0]` at call time.
  - `run_dir`: read `current` with `IFS= read -r line < file || [ -n "$line" ]`, then strip `\r` and whitespace with parameter expansion, not `sed`.
  - Bottom line: `if [ "${BASH_SOURCE[0]}" = "$0" ]; then lib_main "$0" "$@"; fi`. Header block begins `Usage: . scripts/lib/common.sh` and lists the functions.
- **test scenarios (`common.bats`, via `run_lib common.sh …`)**. RED first: every test fails with "No such file" on `common.sh`.
  1. Sourcing has no side effects: `bash -c '. common.sh; echo ok'` outputs exactly `ok` with empty stderr. After sourcing, `set -o` shows `errexit`, `nounset` and `pipefail` on. Sourcing twice is harmless.
  2. `info`, `warn` and `die` write only to stderr, with the prefixes `<script>: `, `<script>: warning: ` and `<script>: error: `. `die` exits 1.
  3. **Fail-open contract:** `bash -c '. common.sh; trap "exit 0" EXIT; die boom'` exits 0, and stderr contains `error: boom`.
  4. `require_cmd jq git` → 0. `require_cmd jq no-such-cmd-xyz` → exit 1, and stderr names `no-such-cmd-xyz`.
  5. `plugin_root`: with `CLAUDE_PLUGIN_ROOT` unset it equals `REPO_ROOT`. With `CLAUDE_PLUGIN_ROOT=/x` (and `/x/`) it prints `/x`. **After a `cd`:** `cd "$REPO_ROOT" && bash -c '. scripts/lib/common.sh; cd /; plugin_root'` (relative source path) still prints `REPO_ROOT`.
  6. `repo_root` from `$PROJECT` and from `$PROJECT/sub/dir` → `$PROJECT`. **Worktree:** after `git worktree add "$BATS_TEST_TMPDIR/wt" -b feat/x`, `repo_root` run inside `wt` → `$PROJECT` (not `wt`). `repo_root "$PROJECT"` given as an argument from a non-git cwd works. From a non-git dir → exit 1 with `not inside a git repository`.
  7. `config_get`: value present (`default_branch` with config `trunk` → `trunk`). Leaf default (config without `git` → `git.branch_pattern` = `feat/{issue}-{slug}`). Whole-object default (config without `git` → `config_get git` prints the compact `properties.git.default` object). Object-level-only default: in the real schema every object default also has leaf defaults, so this case needs a temp plugin root. Set `CLAUDE_PLUGIN_ROOT=$BATS_TEST_TMPDIR/plug` holding `templates/config.schema.json`, with `jq 'del(.properties.limits.properties.max_fix_cycles.default)'` applied. Then `limits.max_fix_cycles` → `3`, taken from `properties.limits.default`. `false` preserved (`gates.plan_approval: false` → `false`). A non-string prints JSON (`limits` → compact object). Missing config file → defaults still served. `retro.repo` missing with no default → exit 1 with `no value or default for 'retro.repo'`. Invalid JSON config → exit 1 with `invalid JSON`. Bad path `a..b` → exit 1.
  8. `is_run_id`: accepts `12` and `m-3`; rejects `0`, `012`, `m-0`, `../x`, `12/..` and the empty string.
  9. `run_dir 12` → `$PROJECT/.aew/runs/12`. `run_dir ../etc` → exit 1. With `current` holding `7\r\n` → `$PROJECT/.aew/runs/7`. No `current` → exit 1 with `no current run`. **From the linked worktree**, `run_dir` resolves the main worktree's `current` and path. **Errexit-in-substitution guard:** from a non-git dir, `run_dir 12` and `config_get default_branch` each exit 1 with **empty stdout** (not `/.aew/runs/12` or a default), and so does `bash -c '. common.sh; x=$(run_dir 12) || exit 1; echo "$x"'`.
  10. `print_usage` on a temp file prints only the header block, without the `# ` prefixes. `bash scripts/lib/common.sh --help` → exit 0 with `Usage:`. `bash scripts/lib/common.sh foo` → exit 1 with `is a library`.
- **verify:** `bats tests/scripts/common.bats` green. `tests/run-script-tests.sh` green (shellcheck now includes `common.sh`).
- **commit:** `feat(scripts): add common.sh shared library`

---

### A3 — Glob-driven script convention checks

- **files:** `tests/scripts/conventions.bats` (new)
- **depends_on:** [A1, A2]
- **pattern:** "Script conventions" 1–6 above. Spec AC-25, AC-28, and constraint 1 (the loops glob the three script dirs, so B, C and D never edit this file).
- **RISKY:** NOT RISKY
- **AC verified:** AC-25 (the `--help` and bad-input loops), AC-28 (static bash 3.2 lint), AC-27 (part of the suite)
- **implementation notes:**
  - A file-level helper `script_files <executables|libs|subcommand|all>` uses `shopt -s nullglob` over `scripts/*.sh`, `scripts/hooks/*.sh` and `scripts/lib/*.sh`. Missing dirs (`scripts/hooks/` until D) yield nothing.
  - Each `@test` loops over its set, collects **all** offending files, and fails once, listing them, so a later phase's failure names the exact script. Each test also asserts its set is non-empty (`common.sh` exists after A2), so the loop can never pass vacuously.
  - Executables are invoked directly, so the shebang resolves `/bin/bash` 3.2 on this machine. Libraries are invoked with `bash <file>`. Every run uses `cd "$BATS_TEST_TMPDIR"` (non-git), `env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR` and `</dev/null`.
  - The lint is one `grep -nE` per pattern over non-comment lines (`grep -vE '^[[:space:]]*#'` first). The test output names `file:line:pattern`. It also lints `tests/run-script-tests.sh` and the helpers.
- **test scenarios**. RED: write the tests, then temporarily drop a throwaway `scripts/zz-red.sh` (no `--help`, no shebang, `mapfile`). Each test fails naming it. Delete it before committing, and record the RED output in the report.
  1. Executables: mode `+x`, first line `#!/usr/bin/env bash`, and they source `lib/common.sh` or contain `set -euo pipefail`. Libs: the shebang, plus the `lib_main` last line.
  2. `--help` (and `-h`) on every file → exit 0, with stdout containing `Usage:`.
  3. `--definitely-not-an-option` on every file → exit **1**, empty stdout, and stderr containing `error:`.
  4. `scripts/*.sh` with no arguments → exit 1, with stderr containing `error:` (vacuous until A4 adds `state.sh`; the non-empty guard applies only to the sets in tests 1–3 and 5).
  5. No bash 4+ or GNU/BSD-divergent construct (the pattern list in convention 6) in any script, lib, hook, runner or helper.
- **verify:** `bats tests/scripts/conventions.bats` green against `common.sh`. `tests/run-script-tests.sh` green.
- **commit:** `test: add glob-driven --help, bad-input and bash 3.2 convention checks`

---

### A4 — Run-state manager `scripts/state.sh`

- **files:** `scripts/state.sh` (new, `+x`), `tests/scripts/state.bats` (new), `tests/scripts/helpers/common.bash` (append `seed_run` only; additive)
- **depends_on:** [A1, A2, A3]
- **pattern:** `templates/state.schema.json` (the contract, with enums at `$defs.stage.enum`, `$defs.status.enum` and `properties.mode.enum`). `templates/state.example.json` (the first history entry has no note; the shape of the stage-entry notes). DESIGN §7.1–7.2. Spec AC-2, AC-3, AC-4 and A18–A23. The usage block is in the contract above. A new file is justified because DESIGN deliverable 2 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-2, AC-3, AC-4, AC-25 and AC-28 (picked up by the A3 loops)
- **implementation notes:**
  - Order: `--help` handling, then `require_cmd jq git`, then subcommand dispatch. The schema is at `$(plugin_root)/templates/state.schema.json`. Enums are read with one `jq -r` per validation (`schema_enum stage|status|mode` as a local function), and membership is checked in bash. **Nothing is duplicated from the schema.**
  - **Validate everything before writing anything.** A write is: `tmp=$(mktemp "$dir/.state.json.XXXXXX")`, `jq … state.json > "$tmp"`, `mv -f "$tmp" state.json`. A `trap` removes `$tmp` on failure. Then append the `log.md` line. `current` is written the same way (temp file plus `mv`).
  - `init`:
    - Validate the run id with `is_run_id`.
    - `--issues` must match `^[1-9][0-9]*(,[1-9][0-9]*)*$` with no duplicates (schema `uniqueItems`).
    - `--mode` must be in the schema enum and is required.
    - Reject unknown options.
    - `--title` defaults to `""` (A22).
    - Refuse if `<run>/state.json` exists (`die "run <id> already exists"`).
    - `base_branch` comes from `config_get default_branch`, read before `mkdir`.
    - Create the run dir, then `state.json` (with `started_at == updated_at == now` and one history entry `{stage:"spec_analysis", status:"running", at:now}` without a note), then the `log.md` line, then `current`.
  - `stage <s> [--note n]` sets stage and `status: running`. `status <s> [--note n]` keeps the stage. Both append exactly one history entry (with `note` only when `--note` is given) and one `log.md` line, and update `updated_at`.
  - `bump`: allowed names are only `fix_cycle` and `review_cycle`. It increments the counter, updates `updated_at`, writes no log line (A19), and prints the new value.
  - `set`:
    - The allow-list (policy, A20) is `title`, `branch`, `base_branch`, `pr`, `spec_revision` and `auto`.
    - Coercion follows the schema property's `type` (string or array) and `minimum`.
      - The literal `null` becomes `null` only where the type allows it.
      - Integers must match `^-?[0-9]+$` and meet `minimum`.
      - Booleans must be `true` or `false`.
      - Otherwise the value is a string.
    - Any mismatch → `die "invalid value for <field>: <value>"`.
    - Fields not on the list → `die "field cannot be set: <field>"`.
  - `get`: an unknown field (not in the schema's `properties`) dies. With no current run, `run_dir`'s own `no current run` die propagates (no second message). `current` naming a run with no `state.json` → `die "no state.json for run <id>"`. A corrupt `state.json` → `die "state.json is not valid JSON: <path>"`. These apply to every current-run subcommand, not just `get`.
  - `current`: prints the id, or exits 1 with `no current run`. `current set <id>` requires `<run>/state.json`. `current clear` is idempotent.
  - Append `seed_run` to `common.bash` (see the contract).
- **test scenarios (`state.bats`)**. RED first: all fail on the missing `state.sh`. The local wrapper `st <args>` runs `state.sh` with `--separate-stderr`, then copies `state.json` (if one exists) into `$BATS_FILE_TMPDIR/snapshots/${BATS_TEST_NUMBER}-<n>.json` (`<n>` a per-test shell counter; each test is its own process, so a global counter would not persist). Tests that deliberately corrupt `state.json` use plain `run`, never `st`, so no invalid snapshot is taken.
  1. `init 12 --issues 12 --mode single --title "Add widget"` →
     - `state.json` has `stage spec_analysis`, `status running`, `branch null`, `pr null`, `base_branch main`, `spec_revision 1`, both cycles 0 and `started_at == updated_at`;
     - one history entry with no `note` key;
     - `log.md` has exactly one line matching `^- <ts> spec_analysis running$`;
     - `current` is `12`.
     `base_branch` follows the config (`default_branch: trunk` → `trunk`). `--auto` → `auto true`. `m-3 --issues 4,5 --mode bulk` works.
  2. `init` refusals, each with exit 1, a clear stderr message, and **no files created** (`.aew/runs` absent or unchanged):
     - an existing run;
     - run ids `0`, `abc` and `../x`;
     - issues `""`, `1,,2`, `1,1` and `x`;
     - a missing `--mode`, and `--mode solo`;
     - an unknown option `--bogus`.
  3. `get` prints the whole state as JSON. `get stage` → `spec_analysis`. `get pr` → `null`. `get issues` → `[12]`. `get nosuch` → exit 1. No current run → exit 1. `current` pointing at a run with no `state.json` → exit 1 with `no state.json`. Corrupt `state.json` (via plain `run`) → exit 1 with `not valid JSON`.
  4. `stage brief --note "spec confirmed"` → `stage brief`, `status running`, history +1 with the note, `log.md` +1 line ending ` — spec confirmed`. `status awaiting_input --note "1 material change"` keeps the stage and appends history and log. Without `--note` there is no `note` key. `stage develop` after `status blocked` resets `status` to `running`.
  5. `updated_at`: pre-set it to `2000-01-01T00:00:00Z` with a test-side jq edit, then each of `stage`, `status`, `bump` and `set` changes it. `started_at` never changes.
  6. `bump fix_cycle` prints `1`, then `2`. `bump review_cycle` → `1`. Neither adds a `log.md` line or a history entry.
  7. `set`:
     - `set branch feat/12-x` → string; `set branch null` → `null`;
     - `set pr 7` → integer `7`; `set pr null` → `null`;
     - `set spec_revision 2` → `2`; `set auto true` → `true`;
     - `set title "New title"` → string;
     - `set base_branch develop`.
  8. **Byte-identical on invalid input.** For each case, `cp state.json before`, run it, assert exit 1 and an error on stderr, then `cmp before state.json` and confirm the `log.md` line count is unchanged:
     - `stage nosuch`, `status nosuch`;
     - `bump nosuch`, `bump issues`;
     - `set pr 0`, `set pr abc`, `set spec_revision 0`, `set auto yes`;
     - `set stage develop`, `set history x`, `set run_id 5`, `set nosuch 1`;
     - `stage` with no argument, `set pr` with no value.
  9. **Atomic write.** The inode of `state.json` (`ls -i`) changes after a successful write. No `.state.json.*` temp files remain after successes or refusals.
  10. `current` → `12`. `current set 99` (no such run) → exit 1. `current set m-3` (an existing run) switches. `current clear` removes the file, and repeating it exits 0. After clearing, `current` exits 1.
  11. Works from a linked worktree: `state.sh get stage` inside `git worktree add …` reads the main worktree's run.
  12. **AC-4, last test in the file:** `validate_json_schema "$REPO_ROOT/templates/state.schema.json" "$BATS_FILE_TMPDIR"/snapshots/*.json` passes, and asserts at least 25 snapshots, so the validation is never vacuous (one `npx` call for the whole file).
  13. **Validator self-test:** a snapshot copy with `started_at: "nope"`, written to `$BATS_TEST_TMPDIR` (never into `snapshots/`), fails `validate_json_schema`. This proves the format checking is live.
  14. `seed_run 12` creates a current run that `state.sh get run_id` reads back as `12`.
- **verify:** `bats tests/scripts/state.bats` green. `bats tests/scripts/conventions.bats` green (now covering `state.sh`, including the no-argument test). Full `tests/run-script-tests.sh` green from a clean checkout (`git stash -u` or a fresh clone of the branch).
- **commit:** `feat(scripts): add state.sh run-state manager`

---

## Phase exit check

- `tests/run-script-tests.sh` exits 0: shellcheck is clean on `common.sh`, `state.sh`, the runner, the helpers and the shim, and all four bats files pass.
- `ls tests/scripts/` shows `common.bats`, `conventions.bats`, `gh-mock.bats`, `state.bats` and `helpers/` (`common.bash`, `bin/gh`), with no fixture files.
- The interface contract above matches what was built. If an implementer had to deviate (a renamed helper, a different exit code), they update this section in the same commit, because B, C and D are planned against it.

## Notes for `dw-plan` / closing

- **CLAUDE.md ajv command is wrong** for `state.schema.json` (it needs `ajv-formats`). Phase A uses the working command in tests only. The closing task, or the human, should decide whether to correct `CLAUDE.md`, which Phase A doesn't own.
- The project map's `## Project knowledge` should get the Phase A contract summary (common.sh functions, the shim layout, the helper names) in the closing task, not in A. B, C and D run in parallel and would conflict on that file.
- Four commits are planned for A. The prompt asks for one conventional commit, so raise squashing at human review (architect constraint 4).

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:36:39Z (plan-review, full depth)
- Plan format: FULL
- Plan dependency graph: valid (A1 → A2 → A3 → A4; no cycles, no dangling refs; A4's additive edit to `common.bash` is covered by `depends_on: [A1]`). Wave count: 4. Max wave width: 1.
- Interface contract: amended during review (strict-mode caveat, fail-open ordering, `plugin_root` after `cd`, `run_lib` argv, shim route sanitising and capture rule, `state.sh` current-run-only note). B, C and D plan against the amended text.
- Plan content hash (SHA-256): f4ecf664e6d153e4e3a8b15685eb8213b735545a3458215bdbff60c15fad4de6 (hash before this section was appended)
