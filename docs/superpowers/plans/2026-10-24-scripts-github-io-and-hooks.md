# Plan — Scripts, GitHub I/O and hooks (build prompt 02)  (EPIC · 4 phases + closing task)

- Spec: `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (senior APPROVED WITH NOTES · NOVEL · EPIC)
- Issue: no issue (build prompt `docs/build-prompts/02-scripts-and-hooks.md`; DESIGN.md wins on conflict)
- Platform facts (verified against code.claude.com/docs, 2026-10-24): `docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-platform-facts.md`
- Execution mode is fixed: subagent-driven only. Proceed to dw-human-review.

## Context manifest

Copied from the spec. Also read the platform-facts file above and, for B/C/D, Phase A's **Interface contract** section below.


**Reference files** (downstream agents read these first):

- `docs/build-prompts/02-scripts-and-hooks.md`: the task, the 11 deliverables and the ACs marked [P] above.
- `docs/DESIGN.md`: §2.4 (agents never touch GitHub), §3 (platform facts: blocking hooks, `stop_hook_active`, the eight-block override, namespacing `aew:<agent>`), §6.1 (config fields), §7.1–7.4 (run dir, state, stages, labels), §7.5 (return contract), §8.1 (revision recording), §10 (dependency phrases), §11 (hooks, verbatim spec), §12 (script quality bar).
- `CLAUDE.md`: script rules (bash, strict mode, shellcheck, `--help`, `gh` PATH shim, bats, gitignored `tests/tmp/`), the ajv-cli validation command, British English, conventional commits, keeping the CHANGELOG.
- `templates/state.schema.json`: the exact `state.json` contract. Enums sit in `$defs.stage.enum` and `$defs.status.enum`, with `additionalProperties: false`.
- `templates/state.example.json`: realistic history, including separate `qa_test_plan` and `plan` entries during parallel planning, and notes on stage transitions.
- `templates/config.schema.json`: config defaults appear both at leaf level and as whole-object `default`s. `retro.repo` is required and has no default. `default_branch` defaults to `main`.
- `skills/run-protocol/SKILL.md`: the run dir table, the stage/status→label table, file naming (`08-qa-report-<fix_cycle+1>.md` and so on), the return contract and the internal skill frontmatter pattern for `github-ops`.
- `skills/run-protocol/references/state-machine.md`: the SubagentStop failure-path row (needs reconciling), counters and the order of the gate recording.
- `templates/artefacts/dev-report.md`: the `## Commands run` table (`| Command | Result |`) and the trailing return block, which the developer gate checks.
- `templates/artefacts/qa-test-plan.md`, `templates/artefacts/qa-report.md`: the trailing return blocks the QA gate checks. Placeholders such as `STATUS: ok | needs_input | …` must fail the check.
- `templates/artefacts/manual-tests.md`: the `## Manual testing required` heading that `gh-issue.sh manual-tests` wraps in markers.
- `templates/artefacts/spec-revision-comment.md`: the comment `gh-issue.sh comment` posts, and its wording ("Nothing the author wrote has been deleted"), which `revise` must honour.
- `templates/artefacts/retro.md`: items are `###` headings under `##` sections. A heading such as `<short title>` is a placeholder to skip. `## Cycles used` holds prose with no items.
- `templates/artefacts/pr-body.md`: already ends with `## Closes` / `Closes #<issue>`, so `gh-pr.sh create` must not duplicate it.
- `docs/superpowers/project-map.md`: primed with these contracts in this pass.

**Key facts learned from the codebase and environment:**

- This is a greenfield deterministic layer. There is no existing script, hook or test in the repo to mirror. The analogs are the schemas, templates and `run-protocol`, which are the contracts the scripts implement.
- The only bash is macOS `/bin/bash` 3.2.57: no associative arrays, `mapfile`, `${v,,}` or `EPOCHREALTIME`. Tools: bats 1.14.0, jq 1.7.1, git 2.54 (`--path-format=absolute --git-common-dir` is available), gh 2.103.2, node 26. `realpath` exists but must not be relied on for paths that don't exist. shellcheck is not installed.
- gh 2.103 exposes `blockedBy`, `blocking`, `parent`, `subIssues` and `closedByPullRequestsReferences` as `--json` fields on `gh issue view` and `gh issue list`. This gives `fetch` real "linked issues" without GraphQL. `gh issue list --milestone` accepts a number or a title. `gh label create --force` updates an existing label.
- `tests/tmp/` and `node_modules/` are already gitignored. `docs/superpowers/` is not.
- The downstream callers are prompt 05 (`gh-labels.sh ensure`, `gh-issue.sh revise`/`comment`/flag, `git-branch.sh push`, `gh-pr.sh create`, `gh-issue.sh manual-tests`, `gh-retro.sh file`) and prompt 06 (`gh-milestone.sh issues`).
- `.aew/runs/` is gitignored in target projects, so it **does not exist inside a sub-developer's git worktree**. The run-dir resolver must go to the main worktree root (the parent of `git rev-parse --git-common-dir`), not `--show-toplevel`.
- Plugin hooks fire in every project where the plugin is enabled, so they must be cheap (one jq call where possible) and inert outside an aew project.

## Assumptions the human should read first

High-stakes, flag if wrong (full list in the spec, A1–A38, plus per-phase B-A1…B-A7 and C "Decisions"):

- **Hooks are inert outside aew projects** (spec A9): no `.aew/` → silent no-op; `.aew/` without `config.json` → warn (debug log only) and allow. The guards therefore never protect your non-aew repos.
- **Gates allow one corrective block** (A8): when `stop_hook_active` is true the gate lets the stop through; the orchestrator then treats a missing/invalid artefact as `failed`. `state-machine.md` is reworded to match (the "eight blocks" wording goes).
- **Gate matches only `aew:developer` / `aew:qa-engineer`** (documented plugin agent_type; anchored matcher). Developer gate: newest `06-dev-report*.md` must not be older than `state.json`; commands table required only when STATUS is `ok`.
- **Bash guard is a pattern-matching safety net, not a sandbox** (A12): it doesn't look inside `bash -c`, `eval`, `$(…)` or backticks. It also treats the branch as the default after an earlier `git switch/checkout <default>` in the same command (reviewer addition — only ever adds blocks).
- **Issue-body format** (A24 / Phase B contract): marker-delimited blocks; earlier spec versions newest-first with v1 labelled original; author text outside aew blocks is kept but **moved to the end** (B-A1 — also applies to `manual-tests`; AC-9 says "untouched"); malformed bodies and content containing markers are refused, never repaired; `revise N` refuses if vN is already recorded with different content (B-A2).
- **shellcheck via PATH or `npx --yes shellcheck`** (A34): nothing installed globally; first run downloads ~8 s.
- **Secrets list** for the Edit guard includes `.npmrc` and `auth.json` (A13).

## Phase graph

- Phase A (depth: full · risk: none) — Foundation: common.sh, state.sh, test harness, gh shim — depends_on: []
- Phase B (depth: full · risk: data-integrity) — gh-issue.sh, gh-labels.sh — depends_on: [A]
- Phase C (depth: lean · risk: none) — gh-pr.sh, git-branch.sh, gh-milestone.sh, gh-retro.sh — depends_on: [A]
- Phase D (depth: full · risk: safety-guards) — hooks.json, hooks.sh, 4 hook scripts, DESIGN/state-machine corrections — depends_on: [A]
- Closing task Z1 (lean · risk: none) — github-ops skill, CHANGELOG, project map, final report — depends_on: [B, C, D]

Waves: 1=[A]  2=[B, C, D]  3=[Z1]
Within phases: A1→A2→A3→A4 · {B1, B4}→B2→B3 · {C1, C2, C3, C4} · D1→{D2, D3, D4, D5}→D6→D7

RISKY tasks: B2, B3 (data-integrity); D2, D3, D4, D6 (safety-guards). All others NOT RISKY.

## Simplicity-challenge

CTO verdict: SIMPLER-PATH — 4 cuts adopted:
1. Phase E folded into closing task Z1 (no separate phase plan/review).
2. `gh-pr.sh create` has no "PR already exists → update" branch; the orchestrator checks `state.pr` first (deviation from spec AC-13 wording).
3. `gh-issue.sh fetch` does no per-reference `gh issue view` lookups; referenced issues = de-duplicated `#n`/URL list (AC-5 amended).
4. `scripts/lib/hooks.sh` sources `common.sh` and reuses its run-dir/worktree-root resolution; hooks.sh is the shared preamble only; the return-block validator lives in `gate-subagent.sh`.

## Orchestrator adoptions after phase review

- C1: `gh-pr.sh update <pr> <body-file> [--run <id>]` applies the same closing-line fix as `create` (senior MINOR adopted).
- CLAUDE.md's ajv command corrected to `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats …` (verified passing on both examples; edit is in the working tree and lands with this feature).

## Commit model

The build prompt asks for one conventional commit; dw-implement commits per task (~19 commits). Raised at
human review. CTO recommendation: keep per-task commits on the feature branch during implementation (resume,
review, bisect, and D6 revertable on its own), then squash to one conventional commit at merge, e.g.
`feat: add scripts, GitHub I/O and safety hooks`.

## CTO conditions (risk-gate, APPROVED WITH CONDITIONS, 2026-10-24) — binding on the named tasks

These override the phase bodies below where they differ. Implementers of the named tasks must apply them.

**B2 / B3 (data-integrity)**
- **B-1 (AC-9 wording, B3):** AC-9 is amended to: `manual-tests` leaves the spec and history blocks byte-identical and preserves all author content byte-for-byte; author text outside aew blocks in a managed body is moved to the end on the first rewrite and is stable thereafter. B3's "AC verified" line reads accordingly. (The spec file is not edited, to keep its approval hash; this plan records the amendment.) Listed under deviations in the Z1 final report.
- **B-2 (CRLF no-op, B2):** In `revise` with `N == cur`, if `S` equals the stored spec content after removing one trailing `\r` from each line, treat it as the identical case: re-serialise, keeping the stored bytes, and never refuse. Add one test: a v2 body converted to CRLF, then `revise 2 spec-v2.md` gives exit 0, no refusal, and `spec_of` still holds the stored (CRLF) bytes.
- **B-3 (UTF-8 guard, B2, inherited by B3 through `rewrite_body`):** Before the transform, refuse a content file that is not valid UTF-8: `jq -n -j --rawfile c "$f" '$c' | cmp -s - "$f" || die "<file> is not valid UTF-8; refusing to edit"`. Add one refusal test for each op (a file containing byte 0xFF gives exit 1 and no `issue edit` call).
- **B-4 (rollback / blast radius, add to Phase B "Accepted risks"):** Blast radius: one issue body per call; in this build it is zero, because the tests only use the shim and the first real writes come in prompts 05/07. Rollback for a bad rewrite: restore the previous body from GitHub's issue edit history ("edited" menu); the pre-revision body for the first rewrite is also in the run dir (`00-issue-original.md` / `issue.json`, written verbatim by `fetch`). No rewrite runs against a non-sandbox issue until prompt 07's sandbox e2e passes; say this in the github-ops skill's known limitations.

**D2 / D3 / D4 / D6 (safety-guards)**
- **D-1 (rollback / blast radius, new section in Phase D, mirrored in one CHANGELOG line):** Blast radius: every session with the aew plugin enabled, but the hooks are active only in repos that have `.aew/config.json`. Failure modes: (a) a guard false positive denies that single tool call with a reason, and the session continues; (b) a crash fails open through the EXIT trap, and a timeout (5 s) is treated as non-blocking (confirm against the platform facts or state it as an assumption); (c) a gate bug costs at most one extra corrective turn per subagent stop (`stop_hook_active`); (d) a SessionStart bug only gives a wrong or missing hint. Rollback: immediately, disable the plugin or start Claude Code without `--plugin-dir .`; permanently, revert the D6 commit or delete `hooks/hooks.json` (the scripts stay, nothing fires). Do not use "remove `.aew/config.json`" as the kill switch, because that breaks aew itself.
- **D-2 (`.git` rule, D2):** A recursive `rm` whose normalised target has a path component equal to `.git` is denied with reason `rm of git internals`. Add table rows: block `rm -rf .git`, block `rm -rf sub/.git`; allow `rm -f .git/index.lock` (not recursive), allow `rm -rf .github/old`. Update the row count in the D2 commit message and the table-integrity test.
- **D-3 (branch switch, D2):** Track the target of the latest `git switch/checkout` instead of a sticky flag. For `-c/-C/-b/-B` it is the new branch name. Later branch-dependent rules use that target when set, otherwise `branch_of`. A later switch to a non-default branch therefore clears the default-branch status. Add an allow row: `git checkout main && git checkout -b feat/y && git push -u origin HEAD` (feat). The existing block rows stay.

**Z1**
- **Z1-1:** Add B-2, B-3, D-2 and D-3 to the final report's deviations and decisions list, together with the AC-9 amendment. Add the D-1 rollback line and the "no real-issue rewrites until prompt 07 e2e" limitation to the CHANGELOG and to the github-ops skill.

---

## Closing task Z1 — github-ops skill, CHANGELOG, project map, final report

- id: Z1
- depends_on: [all of B, C, D]
- risk: NOT RISKY
- ACs: AC-24, AC-29
- files:
  - `skills/github-ops/SKILL.md` (new; `user-invocable: false`, matching `skills/run-protocol/SKILL.md` frontmatter)
  - `CHANGELOG.md` (Unreleased → Added/Changed)
  - `docs/superpowers/project-map.md` (Project knowledge + Gotchas)
- pattern reference: `skills/run-protocol/SKILL.md` (frontmatter, length ≤150 lines, tone); Keep a Changelog entries already in `CHANGELOG.md`.
- content:
  - **github-ops skill (AC-24):** when and how to use each script with one example invocation each (state.sh, gh-issue.sh, gh-labels.sh, gh-pr.sh, gh-milestone.sh, gh-retro.sh, git-branch.sh); stage→label mapping (point to run-protocol); spec-revision recording order (render comment → `revise` → `comment` → `flag add spec-revised` → `state.sh set spec_revision`); agents never call `gh`. Plus the operational rules collected from the phase notes: `labels ensure` before `stage`/`flag`; check `state.pr` before `gh-pr.sh create`; use `update --run <id>` for re-rendered bodies; `revise` refuses same-version-different-content (bump N); malformed markers or the 65,536 limit → `aew:blocked`, never trim history; write state before each developer dispatch and not while a developer runs (gate freshness is whole-second); sub-developers write WP reports to the main worktree's run dir by absolute path; return-block lines stay on one line; retro filing may drop the label without triage rights (known limitation).
  - **CHANGELOG:** scripts, hooks, github-ops skill; hooks inert outside aew projects; one corrective block per gate stop; `aew:`-prefixed agent types; `Edit|Write`-only matcher.
  - **project map:** Phase A contract summary (common.sh functions, shim layout, helper names); issue-body format contract summary; gotchas (bash 3.2 `set -e` not applying in `$(…)`/conditions; `-nt` whole-second; IFS-tab collapse of a leading empty field; empty arrays under `set -u`; `/var`→`/private/var`; `claude plugin validate` only warns on unknown hook events; plugin agent types are `aew:<agent>`; `grep -P` unavailable).
  - **final report (AC-29):** checks run with results (`tests/run-script-tests.sh`, shellcheck, `claude plugin validate .`, ajv), files changed, deviations from DESIGN/prompt (CTO cuts 2–3; C Decision 5 retro label without `--force`; A4 narrowing; `Edit|Write`-only; EXIT trap; `-nt` freshness; developer gate's commands table only when ok; session hint also for `failed` runs; `stage --note`; extra `hooks.sh`, `issue-body.jq`; B-A1 relocation vs AC-9 "untouched"; ajv command), and decisions needed.
- tests / verification: `tests/run-script-tests.sh` passes from a clean checkout; `claude plugin validate .` passes; the github-ops skill is not offered as a slash command in `claude --plugin-dir .`.
- commit: `docs: add github-ops skill, changelog and project-map notes for scripts and hooks`

---


---

<!-- Phase A: from docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-phase-A.md -->

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

---

<!-- Phase B: from docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-phase-B.md -->

# Phase B plan — Issue body and labels

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** B of the EPIC. Phase-level dependency: A (built on A's "Interface contract", as revised after senior review). Runs in parallel with C and D.
- **Depth:** full
- **ACs covered:** AC-5 (amended by the CTO simplicity cut, below), AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12. AC-25 and AC-28 are picked up automatically by A's glob-driven `conventions.bats`.
- **Risk:** data-integrity. B2 and B3 rewrite author-owned GitHub issue bodies and are RISKY. B1 and B4 are NOT RISKY.
- **Date:** 2026-10-24

## Purpose

Phase B builds the two scripts the orchestrator uses for issue I/O:

- `scripts/gh-issue.sh`, with the subcommands `fetch`, `comment`, `revise` and `manual-tests`.
- `scripts/gh-labels.sh`, with the subcommands `ensure`, `stage` and `flag`.

The hard part is the issue-body format behind `revise` and `manual-tests`. The "Issue-body format contract" section below is authoritative. It is written so that preserving v1 byte for byte (AC-7) and idempotency (AC-6) both follow from how the format is built, not from careful coding.

## Facts verified while planning (gh 2.103.2, jq 1.7.1)

- **`gh issue view --json` fields** (`gh issue view 1 -R cli/cli --json nosuchfield`): `assignees author blockedBy blocking body closed closedAt closedByPullRequestsReferences comments createdAt id isPinned issueType labels milestone number parent projectCards projectItems reactionGroups state stateReason subIssues subIssuesSummary title updatedAt url`.
- **Shapes** (from a real public issue):
  - `blockedBy`, `blocking` and `subIssues` are **connection objects** `{"nodes": [...], "totalCount": n}`, not arrays.
  - `parent` is `null` or an issue object.
  - `closedByPullRequestsReferences` is an array of `{id, number, url, repository: {name, owner: {login}}}`.
  - `author` is `{id, is_bot, login, name}`, and `milestone` is `null` or an object.
  - Labels are `{id, name, description, color}`.
  - Comments are `{id, author: {login}, authorAssociation, body, createdAt, url, …}`.
  - **Comment bodies written in the web editor use CRLF.**
  - I could not find a public issue with a non-empty `subIssues`, `blockedBy` or `parent`. Renderers must therefore read node fields defensively (`.number`, `.title // ""`, `.state // ""`, `.url // ""`). B1's fixture assumes nodes are shaped like `{number, title, state, url}`.
- `gh label create <name> --color <6-hex, no #> --description <d> --force` updates an existing label. `gh issue edit <n>` accepts `--body-file f` (`-F`), `--add-label a,b` and `--remove-label a,b`. `gh issue comment <n> --body-file f` posts a comment and prints its URL.
- **jq:**
  - `"" | split("\n")` is `[]`, and `"a\n" | split("\n")` is `["a",""]`.
  - `split("\n") | join("\n")` round-trips exactly, keeping every `\r`.
  - `length` on a string counts codepoints (`"é😀" | length` = 2).
  - `halt_error(5)` prints a string to stderr and exits 5.
  - `--rawfile` and `-j` keep the bytes exact, including CRLF.
- **Data-loss traps that every B task must avoid:**
  - `$(…)` strips trailing newlines, so an issue body or file content must **never** pass through command substitution or a shell variable. Bodies always go file → jq → file.
  - `gh … --jq .body` appends a newline. Use `--json body` and extract with `jq -j`.

## How B uses the Phase A contract (as revised)

- Every script starts like this:
  - `#!/usr/bin/env bash`;
  - a `# Usage:` header block (which is the `--help` text);
  - `# shellcheck source=lib/common.sh`;
  - `. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`.

  Then: `-h|--help` → `print_usage "$0"; exit 0`; an unknown `-*` as `$1` → `die`; no arguments → `die "missing subcommand (see --help)"`. Only after that does it call `require_cmd gh jq`.
- **Strict-mode caveat (A, revised).** `set -e` is off inside `$(…)` and inside functions called from `if`, `while`, `!`, `&&` or `||`. Every value capture and every conditionally called function checks failures explicitly: `labels=$(gh issue view …) || die …`, `jq … >"$out" 2>"$err" || …`, `parse_args "$@" || return 1`. Never use `local x=$(…)`; write `local x; x=$(…) || return 1`. Top-level code may rely on errexit.
- No B script needs `repo_root`, `config_get`, `run_dir` or `state.sh`. `fetch` takes the run dir explicitly, and `gh` infers the repository from the cwd. So `--help` and bad-input handling never need git.
- Scripts call `gh <subcommand> …` with the subcommand first, so the shim's routes are `issue-view`, `issue-edit`, `issue-comment` and `label-create`. Failures are injected with `gh_mock_respond <route> - <code> [k]`.
- Body files are passed to `gh` as **existing regular files** in a `mktemp -d` work dir, never as `-`, so the shim captures them (`gh_captured_file`). The work dir is removed by `trap 'rm -rf "$work"' EXIT`, which is set straight after `mktemp -d "${TMPDIR:-/tmp}/aew-gh-issue.XXXXXX"`.
- Tests: `load helpers/common`, `common_setup` in `setup()`, then `gh_mock_issue`, `gh_mock_body`, `gh_mock_labels`, `gh_call_count`, `assert_gh_called`, `refute_gh_called`, `gh_captured_file`, `assert_json` and `run --separate-stderr`. Tests run in `$BATS_TEST_TMPDIR`, which is not a git repo; no B script needs one.
- **A-interface requests: none.** B adds scripts, `scripts/lib/issue-body.jq` (not matched by the `*.sh` globs, so neither the convention checks nor shellcheck touch it) and fixtures under `tests/scripts/fixtures/issue/`. B edits no A-owned file. `fixtures/labels/` stays unused: B4 seeds label state with `gh_mock_issue --labels`.

## Issue-body format contract (authoritative for B2 and B3)

### Markers

Each marker is a whole line. A trailing `\r` is tolerated, and the version numbers are `[1-9][0-9]*`.

| Name | Line regex |
|---|---|
| `SPEC_OPEN` | `^<!-- aew:spec v(N) -->\r?$` |
| `SPEC_CLOSE` | `^<!-- /aew:spec -->\r?$` |
| `MT_OPEN` / `MT_CLOSE` | `^<!-- aew:manual-tests -->\r?$` / `^<!-- /aew:manual-tests -->\r?$` |
| `PREV_OPEN` / `PREV_CLOSE` | `^<!-- aew:spec-prev v(K) -->\r?$` / `^<!-- /aew:spec-prev v(K) -->\r?$` (same K) |
| `ANY_MARKER` | `^<!-- /?aew:[a-z-]+( v[0-9]+)? -->\r?$` |

### Canonical serialisation

Bodies are worked on as `L = body | split("\n")`. The content of a block is **exactly the lines strictly between its two marker lines, joined with `\n`**. That is the inverse of how blocks are written, so recovering the content is byte-exact by construction.

```
spec_block     = "<!-- aew:spec vN -->\n" + S + "\n<!-- /aew:spec -->"
manual_block   = "<!-- aew:manual-tests -->\n" + M + "\n<!-- /aew:manual-tests -->"
prev_block(K)  = "<!-- aew:spec-prev vK -->\n<details>\n<summary>Spec vK" + (K==1 ? " (original)" : "")
                 + "</summary>\n\n" + C_K + "\n\n</details>\n<!-- /aew:spec-prev vK -->"

managed body   = join([spec_block, manual_block?, prev_block(N-1), …, prev_block(1), O?], "\n\n") + "\n"
unmanaged body with a manual block
               = (V == "" ? "" : V + "\n\n") + manual_block + "\n"
```

- `S` is the spec file's bytes, `M` is the manual-tests file's bytes, and `C_K` is spec vK's bytes (with `C_1` = the author's original body).
- `V` is the author's whole body when it has no spec marker.
- `O` is author content found outside aew blocks in a managed body.
- There are no timestamps or other variable text, so the same inputs always give the same bytes.
- The blank line after `</summary>` makes GitHub render the Markdown inside `<details>`.

### Parsing (the inverse of serialisation)

1. **Find the blocks.** Scan `L` once, top to bottom, with two states. *Outside:* a `SPEC_OPEN`, `MT_OPEN` or `PREV_OPEN` line enters a block; any other `ANY_MARKER` line (a close marker, an unknown kind such as `<!-- aew:foo -->`, or a bad version such as `v0`/`v01`) is malformed. *Inside:* the **next** `ANY_MARKER` line must be the matching close (same kind and, for prev, the same `K`); anything else (a nested opener, a mismatched close) is malformed. Reaching the end of `L` while inside a block is malformed. *(Architect clarification at plan-review: this is the original rule stated as a state machine, so every edge case has exactly one outcome.)* The same `ANY_MARKER` predicate is used for the content-file check below, which is what makes pairing unambiguous: no recorded content can ever contain a marker line.
2. **Classify the body.** It is *managed* if it has exactly one spec block; more than one is malformed. All prev blocks must have distinct `K`s, and together they must be exactly `{1 … N-1}` (any order); otherwise the body is malformed. There is at most one manual block; more than one is malformed. A body with no spec block may contain only an optional manual block; any prev block there is malformed.
3. **Read the prev blocks.** Prev payload lines `P = L[open+1 : close]` must look like this; otherwise the body is malformed:
   - `P | length >= 6` (the serialiser always emits at least six lines, because even an empty `C_K` contributes one empty line; without this check a hand-trimmed 4- or 5-line payload would make `P[2]` and `P[-2]` overlap and silently yield `""`);
   - `P[0]` matches `^<details>\r?$`;
   - `P[1]` matches `^<summary>.*</summary>\r?$`;
   - `P[2]` matches `^\r?$`;
   - `P[-2]` matches `^\r?$`;
   - `P[-1]` matches `^</details>\r?$`.

   Then `C_K = P[3:-2] | join("\n")`.
4. **Collect the gaps (managed body).** A gap is a run of lines outside the blocks: before the first block, between blocks, or after the last one. A gap whose lines all match `^\s*$` is a separator and is discarded. Any other gap has its leading and trailing blank lines dropped and becomes one piece of `O`. The pieces keep document order and are joined with `"\n\n"`. So author text anywhere outside the blocks is kept, and moved to the end.
5. **Recover `V` (unmanaged body).**
   - With no blocks at all, `V` is the **whole body, unchanged**.
   - With a manual block at line `o`: if `o == 0`, `V` is `""`. Otherwise, if `L[o-1]` matches `^\r?$`, `V = L[0:o-1] | join("\n")`; if not, `V = L[0:o] | join("\n")`. (The serialiser always puts `""` there; tolerating `"\r"` keeps a CRLF re-saved body from growing a stray `\r` line in `V`, consistent with the "trailing `\r` tolerated" marker rule.)
   - Lines after the manual close marker other than the final `""` (an author appended text) are added to `V` after `"\n\n"`, with blank edge lines trimmed.

### Operations and refusals

Every refusal exits 1 with a clear `error:` message, makes **no `issue edit` call**, and leaves the body unchanged.

**Input checks (both operations):**

- Refuse a content file (spec or manual) that is missing, empty or contains an `ANY_MARKER` line. A marker inside the content would break the round trip.
- Refuse a malformed body, with the message `issue #n body has malformed aew blocks; refusing to edit (fix by hand)`.

**`revise N S`.** Run these checks in order:

1. Refuse `N < 2`.
2. Work out the current version: an unmanaged body is `cur = 1`; a managed body is `cur = N` from its spec marker.
3. Refuse `N < cur` as a regression, and `N > cur + 1` as a gap.
4. If `N == cur`: when `S` is byte-identical to the stored spec, the result is the same body re-serialised (a no-op on a canonical body). When `S` differs, **refuse** with `spec vN already recorded with different content; use version N+1`. This is the conservative choice; see assumption B-A2.
5. If `N == cur + 1`, the current spec moves to the history. On an unmanaged body, `C_1 = V` and `O = ""`. On a managed body, prev blocks become `[(cur, S_cur)] + prevs`. The manual block and `O` are carried over unchanged.

**`manual-tests M`:**

- A managed body gets the manual block set or replaced and is re-serialised.
- An unmanaged body becomes `V` + manual block (the unmanaged form above).

**Both operations:**

- If the new body's `length` (codepoints) exceeds **65,536**, refuse with `new body would be <len> characters (GitHub limit 65536); not editing`. The body is never truncated.
- If the new body is byte-identical to the current one, skip the `gh issue edit` call and print the info line `issue #n body unchanged`.

### Implementation shape (B2 builds it, B3 extends it)

`scripts/lib/issue-body.jq` is one jq program, run as:

```
jq -n -j --slurpfile view "$work/view.json" --rawfile content "$file" \
   --arg op revise|manual --argjson version "$N" --argjson limit 65536 \
   -f "$lib/issue-body.jq" >"$work/new" 2>"$work/err"
```

- The body is `$view[0].body // ""`.
- Refusals use `halt_error(5)` with the message. The script maps exit 5 to `die "$(cat "$work/err")"` (reading a small error file is fine), and maps any other non-zero exit to `die "internal error in issue-body.jq"`.
- `$lib` is `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib`. It is resolved at the top level and checked with `|| die`.
- jq is chosen because it keeps strings exact (including `\r`), and bash 3.2 cannot hold a body safely. Net-new file: no analog exists, and the format logic does not belong in the shell.

## Tasks

`B1 → B2 → B3` run in sequence because all three edit `scripts/gh-issue.sh`. `B4` is independent and can run in parallel with B1.

---

### B1 — `gh-issue.sh` skeleton, `fetch` and `comment`

- **files:**
  - `scripts/gh-issue.sh` (new, `+x`)
  - `tests/scripts/gh-issue.bats` (new)
  - `tests/scripts/fixtures/issue/view-12.json` (new)
  - `tests/scripts/fixtures/issue/body-12.md` (new)
  - `tests/scripts/fixtures/issue/view-minimal.json` (new)
- **depends_on:** []
- **pattern:** `scripts/state.sh` from A4 (the header and Usage block, the `--help` → `die` → `require_cmd` order, and the subcommand `case`). The A contract's `common.sh` functions. DESIGN §7.1 (`issue.json` and `00-issue-original.md` are written by `fetch`). Spec AC-5 as amended and A26 (the current body is written verbatim). New file justified: DESIGN deliverable 3 names it.
- **RISKY:** NOT RISKY (it reads from GitHub and posts a comment; it never edits the issue)
- **AC verified:** AC-5 (amended), AC-9 (the `comment` half), AC-25 and AC-28 (via A's conventions loop)
- **CTO simplicity cut (adopted; AC-5 amended):** there are no per-reference `gh issue view` lookups and no 20-reference cap. Linked issues come from the same single `--json` call. `referenced_issues` is a sorted, de-duplicated array of numbers.
- **implementation notes:**
  - Usage header lists `fetch <n> <run-dir>` and `comment <n> <file>`. B2 and B3 append their lines. The issue number must match `^[1-9][0-9]*$`, otherwise `die "invalid issue number: <x>"`.
  - **`fetch`:**
    1. Validate `<n>` and the run dir. The run dir must be an existing directory (`die "run dir not found: <d>"`); `state.sh init` creates it, and `fetch` never runs `mkdir`.
    2. Make **one** call, captured to a file: `gh issue view "$n" --json number,title,body,state,url,author,comments,labels,milestone,assignees,blockedBy,blocking,parent,subIssues,closedByPullRequestsReferences > "$work/view.json"`, with `|| die "gh issue view #<n> failed"`.
    3. Run one jq program that adds `referenced_issues`:
       - Scan `.body` and every `.comments[].body` for `#n` with the regex `(^|[^A-Za-z0-9_&/#])#([1-9][0-9]*)(?![A-Za-z0-9_])` (this excludes `owner/repo#n`, `&#35;` entities, `abc#1` anchors and, via the trailing lookahead added at plan-review, hex colours such as `#1D76DB`).
       - Also scan for issue URLs whose prefix equals this issue's own `url` with the number removed (`https://github.com/acme/widgets/issues/`). Other repos' URLs and `/pull/` URLs don't match.
       - Convert to numbers, remove the issue's own number, `unique`.
    4. Write `issue.json` (pretty, via `jq .`, fields as gh returns them plus `referenced_issues`) to `$work`, then render `00-issue-original.md` with a second jq call (`-j`, string templates).
    5. `mv -f` both files into the run dir, only after both have been built. A gh or jq failure leaves the run dir untouched.
  - **`00-issue-original.md` layout:**

    ```
    # #<n> <title>
    (blank)
    - **URL:** <url>
    - **State:** <state>
    - **Author:** @<login>
    - **Labels:** <comma-separated names, or "none">
    - **Milestone:** <title> (#<number>), or "none"
    - **Assignees:** @a, @b, or "none"
    (blank)
    ## Body
    (blank)
    <body, byte for byte>
    (one "\n" if the body doesn't end in a newline, then a blank line)
    ## Comments (<count>)
    ```

    - Each comment gets `### @<login> — <createdAt>`, a blank line, the body verbatim, and a blank line. With no comments: `None.`
    - `## Linked issues` has one list line each for `Parent`, `Blocked by`, `Blocking`, `Sub-issues` and `Closed by pull requests`. Items are rendered as `#<number> <title> (<state>)`, joined with `; `, or `none`. Node fields are read defensively, and connections are read through `.nodes // []`.
    - `## Referenced issues` lists `#3, #4, …`, or `none`.
  - **`comment`:**
    - The file must exist and be non-empty (`[ -s ]`), otherwise `die`.
    - Run `gh issue comment "$n" --body-file "$file"`. gh's stdout (the comment URL) passes through, and a non-zero status from gh → `die "gh issue comment #<n> failed"`.
    - The caller's file path is passed straight through (it is an existing file, so the shim captures it).
- **fixtures:**
  - `view-12.json` is the base object for issue 12, in `acme/widgets`:
    - a title, `state` `OPEN`, the URL, and `author` `{login: "octo", …}`;
    - two comments: the first with a **CRLF body written in-fixture as `\r\n` JSON escapes** that mentions `#20`, the second LF, mentioning `#12` (the issue itself) and `other/repo#9`;
    - `milestone` `{number: 2, title: "v1.0"}`, and `assignees` `[{login: "james"}]`;
    - `blockedBy` `{nodes: [{number: 3, title: "Auth", state: "OPEN", url: …}], totalCount: 1}`, and `blocking` `{nodes: [], totalCount: 0}`;
    - `parent` `{number: 1, title: "Epic", state: "OPEN", url: …}`;
    - `subIssues` `{nodes: [{number: 13, …}], totalCount: 1}`;
    - `closedByPullRequestsReferences` `[{number: 6, url: ".../pull/6", repository: {…}}]`.
  - `body-12.md` contains these references:
    - counted: `#3`, the list `#4, #5`, `https://github.com/acme/widgets/issues/7` and the duplicate `#3`;
    - not counted: `https://github.com/other/repo/issues/8`, `https://github.com/acme/widgets/pull/6`, `&#35;99`, `page#10`, the colour `#1D76DB` and `#12` (the issue itself).

    It also has a Markdown heading and a code fence.
  - `view-minimal.json`: no comments, `milestone` null, `assignees` `[]`, empty connections, `parent` null, `closedByPullRequestsReferences` `[]`.
- **test scenarios (`gh-issue.bats`).** Write these first. RED: every test fails with "No such file or directory" on `scripts/gh-issue.sh`. Capture that output.
  1. **fetch, full.** Seed `gh_mock_issue 12 --from view-12.json --body-file body-12.md --labels aew:analysing,bug`, then run `fetch 12 "$d"` (where `$d` is a temporary dir) → exit 0.
     - `issue.json` has every AC-5 key (`number title body state url author comments labels milestone assignees blockedBy blocking parent subIssues closedByPullRequestsReferences referenced_issues`).
     - `jq -j .body issue.json | cmp - body-12.md` succeeds.
     - `.referenced_issues == [3,4,5,7,20]`.
     - The labels are `aew:analysing` and `bug`.
  2. **One gh call (CTO cut).** `gh_call_count` is `1`, and the call line contains `issue view 12 --json` and each of `blockedBy`, `blocking`, `parent`, `subIssues` and `closedByPullRequestsReferences`.
  3. **`00-issue-original.md`:**
     - it starts with `# #12 `;
     - it contains `- **Milestone:** v1.0 (#2)` and `- **Assignees:** @james`;
     - `jq -e -Rs --rawfile b body-12.md 'contains("## Body\n\n" + $b)'` passes, which proves the body is there verbatim;
     - the comments appear in order, and the CRLF comment's `\r` bytes are preserved;
     - `Blocked by: #3 Auth (OPEN)`, `Parent: #1 Epic (OPEN)` and `Sub-issues: #13` are present;
     - `## Referenced issues` lists `#3, #4, #5, #7, #20`.
  4. **fetch, minimal** (`view-minimal.json`, empty body) → `Comments (0)`, `None.`, every linked line `none`, `referenced_issues == []`, `Milestone: none`.
  5. **A body that already has aew markers** (seeded with `--from view-minimal.json --body-file` a body starting `<!-- aew:spec v2 -->…`) is written verbatim (A26). A second fetch overwrites both files.
  6. **fetch refusals**, each with exit 1, `error:` on stderr and the run dir unchanged:
     - the run dir is missing (no gh call);
     - `fetch abc "$d"` and `fetch 0 "$d"` (no gh call);
     - a missing argument;
     - an unseeded issue `fetch 404` (the gh error is propagated, and **no `issue.json` or `00-issue-original.md` exists afterwards**);
     - `gh_mock_respond issue-view - 1` with a message (no files written).
  7. **comment.** With `gh_mock_respond issue-comment - <<<"https://github.com/acme/widgets/issues/12#issuecomment-1"`, `comment 12 "$f"` → exit 0 and stdout is exactly that URL (pass-through). `gh_captured_file 'issue comment 12'` is a byte copy of `$f` (`cmp`). The call line is `issue comment 12 --body-file …`.
  8. **comment refusals** (exit 1, no gh call): an empty file, a missing file, `comment x f`, a missing argument. A failing gh (`gh_mock_respond issue-comment - 1`) → exit 1.
  9. **Dispatch.** `gh-issue.sh nosuch` → exit 1 with `error:`. `--help` lists `fetch` and `comment`.
- **verify:** `bats tests/scripts/gh-issue.bats` passes. `bats tests/scripts/conventions.bats` passes (it now covers `gh-issue.sh`). `tests/run-script-tests.sh` passes, which includes shellcheck.
- **commit:** `feat(scripts): add gh-issue.sh fetch and comment`

---

### B2 — Issue-body format library and `gh-issue.sh revise`

- **files:**
  - `scripts/lib/issue-body.jq` (new)
  - `scripts/gh-issue.sh` (modified: the `revise` subcommand and its Usage line)
  - `tests/scripts/gh-issue-body.bats` (new)
  - these new fixtures under `tests/scripts/fixtures/issue/`: `body-v1.md`, `spec-v2.md`, `spec-v3.md`, `body-v1-stray-marker.md`, `body-v1-manual.md`, `manual-tests.md`, `expected-v2.md`
- **depends_on:** [B1]
- **pattern:** the "Issue-body format contract" above (authoritative). DESIGN §8.1 "Recording" (marker, revised spec on top, earlier versions in collapsed `<details>`, the author's content never deleted). Spec AC-6, AC-7, AC-8 and A24. `templates/artefacts/spec-revision-comment.md` (the wording "Earlier versions are kept below it, collapsed" must stay true). Net-new `issue-body.jq` is justified in the contract section.
- **RISKY:** **RISKY** (data-integrity: it rewrites an author-owned issue body). The senior should review it against the format contract line by line.
- **AC verified:** AC-6, AC-7, AC-8
- **implementation notes:**
  - Usage: `revise <n> <spec-file> <version>`.
  - Validate the arguments before any gh call:
    - `<n>` must be a valid number;
    - `<version>` must match `^(0|[1-9][0-9]*)$` (anything else, including `02`, which `--argjson` would reject as invalid JSON → `die "invalid version: <v>"`), and `N < 2` → `die "version must be >= 2 (v1 is the author's original)"`;
    - the spec file must exist and be non-empty.
  - Then run, at the top level:
    1. `gh issue view "$n" --json body > "$work/view.json"`, with `|| die`.
    2. `jq -j '.body // ""' "$work/view.json" > "$work/old"`.
    3. The jq transform (`op=revise`), producing `$work/new`.
    4. `cmp -s "$work/old" "$work/new"`. If they match: `info "issue #$n body unchanged (spec v$N)"`, exit 0. Otherwise: `gh issue edit "$n" --body-file "$work/new"` (`|| die`), then `info "issue #$n body revised to spec v$N"`.
  - stdout stays empty.
  - **Exit-code capture (strict mode):** run the transform as `rc=0; jq … >"$work/new" 2>"$work/err" || rc=$?`, then branch on `rc` (0 → continue, 5 → refusal, else internal error). A bare `jq …; rc=$?` would abort under errexit at the top level, and inside B3's `rewrite_body` the explicit `|| rc=$?` is required anyway.
  - In `issue-body.jq`, write small `def`s: `markers`, `blocks` (the pairing scan over `L` with indices), `classify`, `prev_content`, `gaps`, `serialise_managed`, `serialise_unmanaged`, and `refuse(msg)` = `msg | halt_error(5)`. Implement **parsing and serialising of the manual block now** (B2's tests need it). B3 only adds `op == "manual"`.
  - **Gotcha:** the content check must run on `$content | split("\n")` per line, so that `ANY_MARKER` (which is line-anchored) catches a marker even in the last line without a newline.
- **fixtures** (all LF in git; the tests build CRLF and no-final-newline variants on the fly, because CRLF in git is unreliable. Build them in this order: first `perl -pe 'chomp if eof'` (drops the final newline), then `perl -pe 's/\n/\r\n/'`. Doing it the other way round leaves a stray `\r` at the end):
  - `body-v1.md`: the tricky original. It contains:
    - an `#` heading, a nested list and a table;
    - a single-line `<!-- author note -->` and a multi-line HTML comment;
    - the author's own `<details><summary>Logs</summary> … </details>` block;
    - a ```` ``` ```` code fence holding `<details>` and `-->` text;
    - non-ASCII text (`café`, `—`, an emoji);
    - a line ending in two spaces (a Markdown line break) and a tab-indented line.
  - `spec-v2.md`, `spec-v3.md`: realistic `spec-final.md` content (headings, ACs, a code fence), different from each other.
  - `body-v1-stray-marker.md`: a v1 body whose code fence contains the line `<!-- /aew:spec -->` (it must be refused).
  - `manual-tests.md`: a filled-in `templates/artefacts/manual-tests.md` (the `## Manual testing required` heading and two `- [ ]` items).
  - `body-v1-manual.md`: the canonical unmanaged form `body-v1.md` + `"\n\n"` + the manual block of `manual-tests.md` + `"\n"`, written by hand to the contract. B3's output is checked against this same file.
  - `expected-v2.md`: the golden canonical body for `body-v1.md` revised with `spec-v2.md`, built by hand from the contract. It pins the on-GitHub format: a change to the format after release would make bodies written by an older plugin version fail to parse, so any change must be deliberate.
- **test-local helpers (in `gh-issue-body.bats`, written from the contract and independent of `issue-body.jq`).** Both read the body file with `jq -Rs` and `split("\n")`, and output with `-j`:
  - `prev_of <body-file> <K>` prints `C_K` (`P[3:-2] | join("\n")`).
  - `spec_of <body-file>` prints the spec block content.
  - `assert_no_line_lost <before-file> <after-file> [--except-manual]` *(added at plan-review; this is what proves AC-7's "no author content is ever lost" beyond the v1 block)*: strips one trailing `\r` from every line of both files, drops blank lines and `ANY_MARKER` lines, and (with `--except-manual`) drops the lines inside the *before* file's manual block. It then asserts that every remaining line of *before* occurs in *after* at least as many times (a multiset check, done in `awk`). It fails with the first missing line. Call it after **every successful edit** in scenarios 1, 3, 6, 7, 8 and 9 below, and in B3's scenarios 1, 3 (with `--except-manual`), 4 and 5.
- **test scenarios (`gh-issue-body.bats`).** Write these first. RED: `revise` → `error: unknown subcommand` (B1's dispatcher), so every test fails. Capture that output.
  1. **v1 → v2 golden.** Seed issue 7 with `body-v1.md` and run `revise 7 spec-v2.md 2` → exit 0.
     - `cmp <(gh_mock_body 7) expected-v2.md` passes, and the first line is `<!-- aew:spec v2 -->`.
     - `spec_of` = `spec-v2.md` and `prev_of 1` = `body-v1.md` (both by `cmp`).
     - There is exactly one `issue edit 7 --body-file` call, and its captured file equals the stored body.
     - The summary line is `<summary>Spec v1 (original)</summary>`.
  2. **AC-6, idempotent.** Run `revise 7 spec-v2.md 2` again → exit 0, the body is byte-identical (`cmp` against a copy taken after run 1), `gh_call_count 'issue edit'` is still `1`, and stderr contains `unchanged`.
  3. **AC-7, v3 with a tricky CRLF v1 (headline test).** Seed `body-v1.crlf` (CRLF throughout, **with no final newline**), then run `revise … 2` and `revise … 3` →
     - `spec_of` = `spec-v3.md`;
     - the prev blocks appear in the order v2, then v1 (by line number);
     - `prev_of 2` = `spec-v2.md`;
     - **`prev_of 1` matches `body-v1.crlf` byte for byte (`cmp`)**;
     - the author's `<details>`, the HTML comments, the code fence and the non-ASCII text are all inside the v1 block.

     Running `revise … 3` again leaves the body identical (AC-6 at v3). The same check also passes with the LF fixture.
  4. **AC-8, refusals** (each: exit 1, `error:` naming the reason, `gh_call_count 'issue edit'` is 0, and the body is unchanged by `cmp`):
     - `N` = `1`, `0` and `abc` (no gh call at all);
     - a gap: a v1 body with `revise … 3`;
     - a regression: a v3 body with `revise … 2`;
     - a v2 body with `revise … 2` and **different** content (B-A2);
     - a missing, empty or marker-bearing spec file (a spec file containing `<!-- aew:spec-prev v1 -->`);
     - a stray marker: `body-v1-stray-marker.md`;
     - malformed managed bodies, built in-test from `expected-v2.md`: the `<!-- /aew:spec -->` line deleted; a second spec block; prev `v1` relabelled `v3` (**both** its open and close lines, so the pairing is well-formed and the `{1 … N-1}` set rule is what refuses it); a prev close whose `K` differs from its open; the `</details>` line removed from a prev block; a prev payload trimmed to five lines; a spec marker nested inside the prev block; an unknown-kind line `<!-- aew:foo -->` between blocks; the spec marker changed to `v0`; a duplicated manual block;
     - marker-bearing spec files in the two edge forms the per-line check must catch: `<!-- /aew:spec -->` as the **last line with no final newline**, and as a CRLF line (`<!-- /aew:spec -->\r`);
     - `gh_mock_respond issue-edit - 1` (the edit fails) → exit 1.
  5. **AC-8, the 65,536 limit, counted in codepoints.**
     - Revise a scratch issue with a one-character spec to measure `B0` = the codepoint length of the result.
     - Build a spec of `65536 - B0 + 1` codepoints, padded with `é` so bytes exceed codepoints → accepted. The stored body's `jq -Rs length` is exactly 65536, and its byte count is larger.
     - One more `é` → refused with `GitHub limit 65536`, and nothing is edited.
  6. **AC-8, manual-tests block preserved.** Seed `body-v1-manual.md` and run `revise 2` →
     - the manual block sits between the spec block and the v1 block, byte-identical to `manual-tests.md`;
     - `prev_of 1` = `body-v1.md` exactly, so the unmanaged `V` recovery is correct and the separator was not absorbed.

     `revise 3` keeps the manual block.

     **Author text after the manual block (step 5, last rule).** Seed `body-v1-manual.md` with `\nAuthor PS\n` appended, then `revise 2` → `prev_of 1` is exactly `body-v1.md` + `"\n\nAuthor PS"`, the manual block is still byte-identical to `manual-tests.md`, and a second `revise 2` changes nothing.
  7. **AC-8, content outside aew blocks is kept.**
     - Take the v2 body, add a line `Author note above` before the spec marker and a paragraph `Author follow-up` at the end, then `revise 3`.
     - Both texts appear exactly once, after the last prev block. `prev_of 1` is still the v1 fixture exactly.
     - A second `revise 3` produces an identical body.
  8. **CRLF re-save tolerance.** Convert the whole v2 body to CRLF, as the web editor would on an author's save, then `revise 3` → exit 0. The markers are still recognised, every v1 line is present in `prev_of 1` (CRLF line endings are accepted), and `prev_of 2` is `spec-v2.md` with `\r` added.
  9. **An empty v1 body** (`""`) with `revise 2` → `prev_of 1` is empty, and running it again changes nothing.
  10. **Dispatch.** `revise` with missing arguments → exit 1. `--help` lists `revise`.
- **verify:**
  - `bats tests/scripts/gh-issue-body.bats` and `bats tests/scripts/gh-issue.bats` pass;
  - `tests/run-script-tests.sh` passes;
  - review step: the diff of `issue-body.jq` against the contract; every refusal path has a test.
- **commit:** `feat(scripts): add gh-issue.sh revise with versioned issue-body blocks`

---

### B3 — `gh-issue.sh manual-tests`

- **files:**
  - `scripts/gh-issue.sh` (modified: the `manual-tests` subcommand and its Usage line)
  - `scripts/lib/issue-body.jq` (modified: `op == "manual"`)
  - `tests/scripts/gh-issue-body.bats` (tests appended)
  - `tests/scripts/fixtures/issue/manual-tests-2.md` (new)
- **depends_on:** [B2]
- **pattern:** B2's `revise` flow (validate → view → transform → `cmp` → edit), reused as is. The only differences are `--arg op manual` and no version argument (pass `--argjson version 0`). The format contract's `manual-tests` rules. Spec AC-9, A24 and A25. `templates/artefacts/manual-tests.md` (the heading inside the block).
- **RISKY:** **RISKY** (data-integrity: it rewrites an author-owned issue body)
- **AC verified:** AC-9 (the `manual-tests` half)
- **implementation notes:**
  - Usage: `manual-tests <n> <file>`. The file must exist, be non-empty and contain no aew marker line.
  - The file content is inserted **verbatim**, including any leading `<!-- Artefact: … -->` template comment, which GitHub doesn't render (B-A4).
  - It never touches labels: setting `aew:manual-test-required` is the orchestrator's separate `gh-labels.sh flag` call.
  - Put the shared view/transform/edit flow in one function, `rewrite_body <n> <op> <file> <version>`, called by both `revise` and `manual-tests`. It must check every step explicitly (`|| return 1`), because callers may run it in a condition. This keeps the edit path in one place instead of two copies.
- **fixture:** `manual-tests-2.md`: a different checklist (three items).
- **test scenarios (appended to `gh-issue-body.bats`).** RED: `manual-tests` → `unknown subcommand`. Capture that output.
  1. **Unmanaged body.** Seed `body-v1.md` and run `manual-tests 7 manual-tests.md` → the body is byte-identical to `body-v1-manual.md` (the same golden B2 consumes). The author's bytes are an exact prefix (`cmp -n <size of body-v1.md>`).
  2. **Idempotent.** Running it again gives an identical body, and `gh_call_count 'issue edit'` stays `1`.
  3. **Replace.** Run `manual-tests 7 manual-tests-2.md` → exactly one `MT_OPEN` line (`grep -c`), the block content = `manual-tests-2.md`, the author's prefix unchanged, and `manual-tests.md`'s items gone.
  4. **Managed body.** From `expected-v2.md` plus a `revise 3`, run `manual-tests` →
     - the block is inserted after the spec block and before the v2 block;
     - `spec_of`, `prev_of 2` and `prev_of 1` are byte-identical to their values before the call (`cmp`);
     - an existing `O` paragraph is kept;
     - replacing the block with `manual-tests-2.md` leaves the spec and history blocks byte-identical.
  5. **End to end with CRLF.** Use a CRLF v1 without a final newline: run `manual-tests`, then `revise 2`, then `revise 3` → `prev_of 1` matches the CRLF v1 byte for byte, and the manual block survives both revisions.
  6. **Refusals** (exit 1, no edit, body unchanged): an empty file, a missing file, a file containing `<!-- /aew:manual-tests -->`, a malformed body (two manual blocks), a body pushed over 65,536 codepoints, and a bad issue number.
  7. **Labels untouched.** After `manual-tests`, `gh_mock_labels` is unchanged, and there is no `--add-label` in `calls.log`.
- **verify:** `bats tests/scripts/gh-issue-body.bats` passes (the B2 tests still pass), and `tests/run-script-tests.sh` passes.
- **commit:** `feat(scripts): add gh-issue.sh manual-tests block`

---

### B4 — `gh-labels.sh ensure`, `stage` and `flag`

- **files:** `scripts/gh-labels.sh` (new, `+x`), `tests/scripts/gh-labels.bats` (new)
- **depends_on:** [] (it can run in parallel with B1)
- **pattern:** `scripts/state.sh` (A4) for the header, `--help` and dispatch. DESIGN §7.4 (the 11 labels). The `skills/run-protocol/SKILL.md` "Labels" table (descriptions). Spec AC-10–12, A27 and A28. New file justified: DESIGN deliverable 4 names it.
- **RISKY:** NOT RISKY (label changes are cosmetic and reversible; it never edits bodies)
- **AC verified:** AC-10, AC-11, AC-12, plus AC-25 and AC-28 via the conventions loop
- **implementation notes:**
  - **One label table.** A function `label_table` prints `kind|name|colour|description` lines from a heredoc (bash 3.2, so no associative arrays). It is the only source for `ensure`, the stage set and the flag set. The table, with cosmetic colours (A28) and descriptions of 100 characters or fewer:

    | kind | name | colour | description |
    |---|---|---|---|
    | stage | aew:analysing | 1D76DB | aew: spec analysis is running |
    | stage | aew:awaiting-input | FBCA04 | aew: waiting for answers to spec questions |
    | stage | aew:planning | 0052CC | aew: brief, standards, test plan and plan in progress |
    | stage | aew:awaiting-approval | E4A11B | aew: plan is waiting for approval |
    | stage | aew:building | 0075CA | aew: development and code review in progress |
    | stage | aew:testing | 006B75 | aew: QA is running |
    | stage | aew:documenting | 5DA9E9 | aew: summary, PR body and retro being written |
    | stage | aew:ready-for-review | 0E8A16 | aew: PR is open and ready for human review |
    | stage | aew:blocked | B60205 | aew: run is blocked and needs a human |
    | flag | aew:spec-revised | 8250DF | aew: the spec on this issue was revised (history kept in the body) |
    | flag | aew:manual-test-required | D93F0B | aew: some tests must be run by hand (see the issue body) |

  - **`norm_label <kind> <arg>`** adds an `aew:` prefix if it is missing, then checks the result against the table for that kind. An unknown name → `die "unknown <kind> label: <arg> (expected one of: …)"`. A flag name passed to `stage`, or a stage name passed to `flag`, is rejected. Validation happens **before** any gh call.
  - **`ensure`** takes no arguments; extra arguments → `die`. For each row, in table order, it runs `gh label create "$name" --color "$colour" --description "$desc" --force`, with the arguments in exactly that order for testability. A failure → `die "gh label create <name> failed"`. This fails fast, and a re-run is safe because `--force` makes the command idempotent. At the end: `info "ensured 11 labels"`.
  - `<n>` (for `stage` and `flag`) is validated with the same `^[1-9][0-9]*$` rule as `gh-issue.sh` (`die "invalid issue number: <x>"`) before any gh call.
  - **`stage <n> <stage>`:**
    1. `labels=$(gh issue view "$n" --json labels --jq '.labels[].name') || die …`.
    2. In bash, `remove` = the current labels that are stage labels other than the target, and `add` = the target if it is absent.
    3. If both are empty: exit 0 (idempotent, no edit call). Otherwise make **one** call: `gh issue edit "$n" [--add-label <target>] [--remove-label <a,b,…>]`, with `|| die`.
    4. Never touch non-stage labels.
    5. Build the argument arrays with the `${arr[@]+"${arr[@]}"}` idiom (A: empty arrays are fatal under `set -u` on bash 3.2).
  - **`flag <n> add|remove <flag>`:** validate the action and the flag, then view the labels the same way, and make **one** `issue edit` call with `--add-label` or `--remove-label` only when that call would change something. A no-op exits 0 without an edit.
  - Labels must exist before `stage` or `flag` adds them. The orchestrator runs `ensure` first, and phase E's github-ops skill documents this. `stage` never creates labels itself.
- **test scenarios (`gh-labels.bats`).** Write these first. RED: missing `scripts/gh-labels.sh`. Capture that output.
  1. **AC-10, ensure.**
     - Exit 0, and `gh_call_count 'label create'` is `11`.
     - The set of created names equals the `aew:[a-z-]+` names extracted from DESIGN §7.4 (`awk` from `### 7.4 Labels` to the next `###` heading in `$REPO_ROOT/docs/DESIGN.md`, then `grep -oE`). This is a drift guard against DESIGN.
     - Every call line matches `label create aew:… --color [0-9A-Fa-f]{6} --description .+ --force`.
     - Each name appears exactly once.
  2. **ensure failure.** `gh_mock_respond label-create - 1 3` → exit 1, stderr names the third label, and there are only 3 `label create` calls. `ensure extra` → exit 1, no gh call.
  3. **AC-11 (headline).** Seed issue 12 with the labels `aew:analysing,aew:planning,aew:spec-revised,enhancement`, then run `stage 12 building` → exit 0. `gh_mock_labels 12` is **exactly** `aew:building`, `aew:spec-revised`, `enhancement`. There is exactly one `issue edit 12` call, which includes both `--add-label aew:building` and `--remove-label`.
  4. `stage 12 aew:building` (with the prefix) gives the same result as the bare name.
  5. **Idempotent.** With only `aew:building` (plus others) present, `stage 12 building` makes no `issue edit` call and leaves the labels unchanged.
  6. **Target present alongside another stage label** → remove only, with no `--add-label` in the call. **No stage label at all** → add only.
  7. **Every one of the 9 stage names** is accepted (a loop over a fresh issue each time; exactly one stage label afterwards).
  8. **AC-12, flag.**
     - `flag 12 add spec-revised` → `aew:spec-revised` added, and the stage label is untouched.
     - `flag 12 add aew:manual-test-required` works.
     - Adding a flag that is already present → no edit call.
     - `flag 12 remove spec-revised` → removed.
     - Removing a flag that is absent → exit 0, no edit call.
  9. **AC-12 rejections** (exit 1, `error:`, **zero gh calls**): `flag 12 add blocked`, `flag 12 add aew:building`, `flag 12 add bug`, `flag 12 add ""`, `flag 12 toggle spec-revised`, and a missing flag argument.
  10. **Stage rejections** (exit 1, zero gh calls): `stage 12 nosuch`, `stage 12 spec-revised` (a flag), `stage x building`, `stage 0 building`, and a missing stage argument.
  11. **gh errors propagate.** An unseeded issue with `stage 404 building` → exit 1 with `error:` and no edit call. `gh_mock_respond issue-edit - 1` → exit 1.
  12. **Dispatch.** `gh-labels.sh nosuch` → exit 1. `--help` lists `ensure`, `stage` and `flag`.
- **verify:** `bats tests/scripts/gh-labels.bats` passes, `bats tests/scripts/conventions.bats` passes, and `tests/run-script-tests.sh` passes.
- **commit:** `feat(scripts): add gh-labels.sh ensure, stage and flag`

---

## Phase B assumptions (beyond the spec; flag if wrong)

- **B-A1:** `revise` and `manual-tests` re-serialise the body into the canonical form. Author text found between or above aew blocks is kept but moved to the end of the body. Nothing is dropped, though its position changes once. This applies to `manual-tests` too, so on a hand-edited managed body AC-9's "author content untouched" holds as "unchanged bytes, possibly relocated". **Flag if wrong**: the alternative is for `manual-tests` to splice its block in place (a second output path in `issue-body.jq`).
- **B-A2:** `revise N` when spec vN is already recorded with **different** content refuses, instead of overwriting the earlier vN draft. The orchestrator must use N+1. This is conservative (it never discards text) and costs nothing on the normal path. **Flag if wrong**: the alternative is to replace vN in place.
- **B-A3:** a body with malformed or stray aew markers is refused, never repaired. James fixes it by hand. This includes an author's code fence that quotes a marker line exactly, which is unlikely.
- **B-A4:** the manual-tests file is inserted verbatim, including any template header comment.
- **B-A5:** the 65,536 limit is counted in codepoints (jq `length`). GitHub's exact counting rule is undocumented; codepoints match its "characters" wording.
- **B-A6:** `fetch` requires the run dir to exist already. It writes both files atomically, overwrites them on re-fetch, and takes all comments from the single `--json comments` call, with no pagination handling. Prompt 07's sandbox e2e checks a long-thread issue.
- **B-A7:** `ensure` fails fast on the first `gh label create` error, because a re-run is idempotent.

## Accepted risks

- **Read-modify-write race.** An author editing the body at the same moment as `revise` could have their edit overwritten. `gh` has no conditional update. Mitigations: the window is a single call, and GitHub keeps the body's edit history. This is noted for the github-ops skill (phase E).
- **Format permanence.** Once released, bodies on GitHub carry this format. `expected-v2.md` and `body-v1-manual.md` pin it, so a format change shows up as a failing golden test.
- **Real-GitHub byte fidelity (added at plan-review).** The mock stores bodies byte for byte. If real GitHub normalised a body we send (for example by dropping the final `\n` or converting line endings), the no-op `cmp` would see a difference and every re-run would make an edit call (content stays correct, but AC-6's "no edit" would not hold in practice). Prompt 07's sandbox e2e must run `revise 2` twice on a real issue and assert the second run reports `unchanged`.

## Phase exit check

- `tests/run-script-tests.sh` exits 0, with shellcheck clean on `gh-issue.sh` and `gh-labels.sh`, and `gh-issue.bats`, `gh-issue-body.bats`, `gh-labels.bats` and `conventions.bats` all passing.
- `git diff --stat` touches only `scripts/gh-issue.sh`, `scripts/gh-labels.sh`, `scripts/lib/issue-body.jq`, the three bats files and `tests/scripts/fixtures/issue/*`. No A-owned file changes.

## Notes for `dw-plan`, phase C and phase E

- **For C (`gh-milestone.sh`):** `blockedBy` is a connection `{nodes: [{number, …}], totalCount}` in `gh issue list` and `gh issue view` JSON, not an array. Read it as `.blockedBy.nodes // [] | map(.number)`.
- **For E (github-ops skill):**
  - `stage` and `flag` need `ensure` to have run.
  - `revise` refuses the same version with different content (bump N instead).
  - Bodies with malformed markers need a human.
  - A 65,536-limit refusal also needs a human (the history grows with each revision, so a long spec revised several times can hit it): set `aew:blocked`, never trim history.
  - Recording order: render the comment → `revise` → `comment` → `flag add spec-revised` → `state.sh set spec_revision`.
  - The project map should get the issue-body format contract summary (the marker set, the canonical layout and the refusal rules).
- Four commits are planned for B. The prompt wants a single commit, so the squash is raised at human review (architect constraint 4).

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:48:40Z (plan-review, full depth)
- Plan format: FULL (phase B of EPIC; risk: data-integrity, B2 and B3 RISKY, so the CTO risk gate applies)
- Plan dependency graph: valid. Wave count: 3 ({B1, B4} → {B2} → {B3}). Max wave width: 2 tasks in parallel. File overlaps (`gh-issue.sh`; `issue-body.jq` and `gh-issue-body.bats`) are serialised by B1 → B2 → B3. No overlap with A-owned files or C/D files.
- Auto-applied at review: state-machine pairing rule (step 1); `length(P) >= 6` prev-payload check; `^\r?$` separator tolerance in unmanaged `V` recovery; version regex `^(0|[1-9][0-9]*)$`; explicit `|| rc=$?` exit-code capture; `#n` trailing lookahead plus a hex-colour fixture case; `assert_no_line_lost` invariant helper wired into every successful-edit scenario; extra malformed-body and marker-edge refusal cases; author-text-after-manual-block case; B1 test 5 seeded `--from view-minimal.json`; comment-URL pass-through assertion; B4 `<n>` validation; B-A1 widened to AC-9 and flagged; phase E note on limit refusals; accepted risk on real-GitHub byte fidelity (prompt 07 e2e).
- Plan content hash (SHA-256): bd80d94ddbe75abdd33663047c538fe97fb3e640e93e8359697982c26c7bf86f (hash before this section was appended)

---

<!-- Phase C: from docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-phase-C.md -->

# Phase C plan — PR, branch, milestone and retro I/O

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** C of the EPIC. Depends on A (built on A's "Interface contract"). Runs in parallel with B and D.
- **Depth:** lean (one section per task, no inline code; the implementer writes the code from the contracts named here)
- **ACs covered:** AC-13, AC-14, AC-15, AC-16 (AC-25 and AC-28 are picked up automatically by A's `conventions.bats` globs)
- **Risk:** none. All four tasks are NOT RISKY: new files only, no edits to A-owned files, no schema or template changes, no network in tests (`gh` is the A shim; `git push` goes to a local bare remote).
- **Date:** 2026-10-24

## Shared ground rules for C1–C4 (from A's contract; not repeated per task)

- Each script is `scripts/<name>.sh`, mode `+x`, `#!/usr/bin/env bash`, then a `#` header block starting `Usage:` (the `--help` text, printed via `print_usage`), then `# shellcheck source=lib/common.sh` and `. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`.
- Order inside every script: handle `-h`/`--help` first (no `require_cmd`, git, config or stdin before it), then `require_cmd`, then subcommand dispatch. No arguments → `die "missing subcommand (see --help)"`. Unknown subcommand or option → `die` (exit 1, nothing on stdout). Every positional is validated before any `gh` or `git` call. A bad-input test always asserts **no `gh` call was made** (`gh_call_count` is 0) or the repo is unchanged.
- Machine output goes to stdout only (a PR number, a branch name, one line per retro item, a JSON array). `git` and `gh` chatter goes to stderr (`>&2`). A failing `gh`/`git` call makes the script exit non-zero with the tool's stderr passed through and nothing on stdout.
- bash 3.2: optional `gh` arguments are built in an array and expanded as `${args[@]+"${args[@]}"}`. Text parsing uses jq (Oniguruma regex) or POSIX/BSD `awk` (no gawk extensions such as `IGNORECASE`, `gensub`, `\y`). No `sed -i`, no `grep -P` (both banned by convention 6). Inputs may have CRLF line endings: strip a trailing `\r` before matching.
- Strict-mode caveat (A contract): bash 3.2 does not apply `set -e` inside `$(…)` or inside a function called from `if`/`while`/`!`/`&&`/`||`. Every captured value whose failure matters is checked explicitly (`state=$(jq … "$d/state.json") || die …`, `n=$(parse_pr_number …) || die …`, `root=$(repo_root) || exit 1`), and helper functions use `|| return 1` internally. Never `local x=$(…)` (SC2155): declare, then assign.
- Run state is **read**, never written: `gh-pr.sh` reads `d=$(run_dir "$id") || exit 1`, then `jq … "$d/state.json"` directly (never via `state.sh get`, which only sees the current run) (`state.sh` has no `--run` option, and only the orchestrator writes state). `gh-pr.sh` and `git-branch.sh` print their result; the orchestrator calls `state.sh set` (spec scope-out).
- Every bats file starts with `load helpers/common` and calls `common_setup` in `setup()`. Canned `gh` output goes through `gh_mock_respond <route>`. Asserting what was sent uses `assert_gh_called`, `gh_call_count` and `gh_captured_file`. Fixture files live only in this phase's subdirectories (`tests/scripts/fixtures/{pr,milestone,retro,branch}/`), and tests create small inputs inline with heredocs where that is clearer.
- TDD: write the bats file first, run it, and capture the RED (every test fails on the missing script). Then implement until green. Then run `bats tests/scripts/conventions.bats` (the new script must pass `--help`, bad option, no-arg and the bash 3.2 lint) and the full `tests/run-script-tests.sh` (shellcheck clean).

## Decisions made in this phase (flag if wrong)

1. **`gh-pr.sh create` closing keywords.** A body line already "covers" issue `n` when it matches a GitHub closing keyword (`close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`, case-insensitive) followed by `#n` with a number boundary, so `Closes #123` does not cover `#12`. Placeholder lines `Closes #<issue>` (the `pr-body.md` template's last line) are **removed**. Each uncovered issue gets one `Closes #n` line appended at the end of the body, in `state.issues` order, using the body's existing line ending (CRLF if the body is CRLF, else LF). With the template, the appended lines therefore land under its `## Closes` heading. The input body file is never modified: the normalised body goes to a temp file that is passed to `gh`.
2. **`gh-pr.sh create` needs `state.branch` and a non-empty `state.title`.** It passes `--head <branch> --base <base> --title <title> --body-file <tmp>` explicitly, so it is independent of the current checkout. A null branch or an empty title dies with a hint (`state.sh set branch|title …`). The PR number is parsed from the `…/pull/<n>` URL that `gh pr create` prints. Per the adopted CTO cut, there is no "PR already exists" lookup: a second create fails loudly in `gh`.
3. **`gh-pr.sh update <pr> <body-file> [--run <id>]`.** With `--run <id>` it applies the same closing-line fix as `create` (Decision 1): the placeholder is stripped and a `Closes #n` line is appended for each run issue not already covered. It calls the same internal function as `create` (no duplication), validates the run id and `state.json` first, and never modifies the input file (the fixed body goes to a temp file). Without `--run` it stays a plain `gh pr edit` wrapper. *Note for phase E (github-ops skill):* when the orchestrator re-posts a re-rendered `pr-body.md` via `update`, it should pass `--run <id>`; without it the placeholder `Closes #<issue>` stays in the body.
4. **`gh-milestone.sh` parses issue bodies only, not comments** (DESIGN §10 names body phrases and task lists). Dependency phrases are `blocked by` and `depends on` (case-insensitive, optional `:`), followed by a list of `#n` joined by commas, `and`, `&` or whitespace. Task-list references count only when `#n` is the first token after the checkbox (`- [ ] #7 …`, `* [x] #8`). `- [ ] Fix login (#7)` does not count. References qualified with a repo (`acme/other#3`) and issue URLs are not counted. Native `blockedBy` numbers are merged in. Output is sorted by issue number.
5. **`gh-retro.sh` ensures the retro label best-effort: `gh label create <label> --repo <retro.repo> --color … --description …` (no `--force`); any non-zero exit → `warn` with gh's message and continue.** *(Architect amendment at plan-review; the author's original choice was `--force`.)* This is spec A31's "ignore already exists" without error-string matching. It also does not reset colour/description on a repo aew does not own on every run, and it does not abort filing when the user lacks label permission on the retro repo (the default `retro.repo` is the plugin maintainer's repo, where most users are not collaborators; a label 403 must not block filing). If the label is genuinely missing and could not be created, the later `issue create --label` fails loudly. `gh-labels.sh ensure` (AC-10) keeps `--force` because it owns the project repo's labels; the retro repo is not aew's to rewrite. Every `gh` call in `gh-retro.sh` carries `--repo <retro.repo>`, so retro I/O can never touch the project repo.
6. **`gh-retro.sh` title match** is normalised equality, done in jq: lower-case, then each `[[:punct:]]` character replaced by a space, then whitespace collapsed and trimmed (spec A31). Replacing rather than deleting makes `stale-report` equal `stale report`; checked with jq 1.7 while planning (re-checked at plan-review on jq 1.7.1: `dev gate — Stale REPORT passes!`, `Dev gate: stale report passes` and `  dev   gate: stale-report passes. ` all normalise to `dev gate stale report passes`; the em dash is matched by `[[:punct:]]`). Lower-casing uses `ascii_downcase`, so non-ASCII letters keep their case. If several open issues match, the lowest number wins. An issue created earlier in the same run is added to the in-memory list, so a duplicate heading later in the same `retro.md` comments on it instead of creating a second issue. A re-run after a partial failure can post a second "Seen again" comment on items it already filed. That is accepted (noisy, not lossy).
7. **`git-branch.sh create` creates the branch with `git switch --no-track -c <branch> <base>`.** `--no-track` stops a remote-tracking base such as `origin/main` from becoming the upstream; `push -u` sets the real upstream later. The result is checked with `git check-ref-format --branch`. A pattern that still holds an unresolved `{…}` placeholder after substitution dies (for example `{issue}` in a milestone pattern). Only local branches count as "existing". `push` prints the branch name on stdout after a successful push.

## A-interface requests

None. C uses only the documented contract: `common.sh` (`die`, `info`, `warn`, `require_cmd`, `repo_root`, `config_get`, `is_run_id`, `run_dir`, `print_usage`), the helpers (`setup_project`, `write_config`, `seed_run`, `gh_mock_respond` with call-number sequencing, `gh_calls`, `assert_gh_called`, `refute_gh_called`, `gh_call_count`, `gh_captured_file`, the `assert_*` helpers), `state.sh set` for test setup, and the shim's default "unknown route → exit 0" for `label create`, `issue comment`, `pr edit`, `pr ready` and `pr comment`. One shim property is relied on and worth keeping: the route is `<arg1>-<arg2>`, so scripts must put `--repo` and other flags **after** the subcommand (`gh issue list --repo R …`), never before it.

## Tasks

The four tasks are independent (`depends_on: []`), touch disjoint files, and can run in parallel worktrees.

---

### C1 — `scripts/gh-pr.sh` (create, update, ready, comment)

- **files:** `scripts/gh-pr.sh` (new, `+x`), `tests/scripts/gh-pr.bats` (new), `tests/scripts/fixtures/pr/` (only if a case is clearer as a file than a heredoc; the real `templates/artefacts/pr-body.md` is used directly as the template-body input)
- **depends_on:** []
- **pattern:** A's script conventions and `common.sh` contract. Spec AC-13, A29 as amended by the CTO cut (no existing-PR branch). `templates/artefacts/pr-body.md` (ends with `## Closes` / `Closes #<issue>`). `templates/state.schema.json` (`issues`, `title`, `branch`, `base_branch`). No in-repo analog; a new file is justified because DESIGN deliverable 5 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-13
- **behaviour:** `create <run-id> <body-file> [--base <b>] [--draft]` (options in any order after the positionals; an unknown option dies) validates the run id (`is_run_id`), that the body file exists and is non-empty, and that `$(run_dir <id>)/state.json` exists. It reads `issues`, `title`, `branch` and `base_branch` in one jq call, normalises the closing lines (Decision 1), runs `gh pr create --head … --base <--base or base_branch> --title … --body-file <tmp> [--draft]`, and prints only the PR number. `update <pr> <body-file> [--run <id>]` → `gh pr edit <pr> --body-file <f>`; with `--run <id>` the body first goes through the same closing-line normaliser as `create` (shared internal function; the run id and `state.json` are validated before any `gh` call; the fixed body goes to a temp file, the input is never modified; an unknown option or `--run` without a value dies). `ready <pr>` → `gh pr ready <pr>`. `comment <pr> <file>` → `gh pr comment <pr> --body-file <f>`. `<pr>` must match `^[1-9][0-9]*$`, and the files must exist and be non-empty. These three print nothing on success. Temp files are removed by a `trap` on EXIT.
- **test scenarios (`gh-pr.bats`):** each test uses `setup_project`, `seed_run`, then `state.sh set branch feat/12-add-widget`, with `gh_mock_respond pr-create` serving `https://github.com/acme/widgets/pull/7`.
  1. `create 12 <pr-body.md template>` prints exactly `7`. The call has `--head feat/12-add-widget --base main --title Test run`. The captured body file contains `Closes #12` exactly once and no `#<issue>`. The rest of the template is unchanged (compare it with the template minus the placeholder line). The input file is byte-identical afterwards (`cmp`).
  2. Bulk run (`seed_run m-3 --issues 4,5 --mode bulk`) with a body already containing `Closes #4`: the captured body has `Closes #4` once, then `Closes #5` added once, in that order.
  3. Other keywords and case count as coverage. `fixes #4` and `RESOLVED #5` → nothing added. `Closes #123` does not cover `#12`, so `Closes #12` is added.
  4. Running the normaliser twice is stable. Feed the captured body from test 1 back in as the input: the next captured body is byte-identical.
  5. `--base develop` → the call has `--base develop`. With no `--base`, it uses `state.base_branch` (after `state.sh set base_branch trunk` → `--base trunk`). `--draft` → the call has `--draft`. With no `--draft`, the call does not contain `--draft`.
  6. CRLF body: placeholder detection and coverage still work, and no stray `\r`-only duplicates appear. Appended `Closes` lines use the body's existing line ending: for a CRLF body the appended line ends in `\r\n` (assert with `od`/`grep` on the captured file, and that no bare-LF line was added); for an LF body they end in `\n` only.
  7. `gh` failure (`gh_mock_respond pr-create - 1` with `a pull request for branch … already exists`) → non-zero exit, empty stdout, and gh's message on stderr.
  8. Output with no `/pull/<n>` URL → exit 1 with a clear message.
  9. Refusals, each with exit 1, `error:` on stderr, and `gh_call_count` 0:
     - run id `abc`;
     - a run with no `state.json`;
     - a missing or empty body file;
     - `branch` null (no `state.sh set branch`);
     - an empty title (`state.sh set title ""`);
     - `--base` without a value;
     - `--bogus`;
     - missing positionals.
  9a. `update 7 <rendered pr-body.md with the placeholder> --run 12` posts a body (`gh_captured_file 'pr edit 7'`) that contains `Closes #12` exactly once and no `#<issue>`; the rest of the template is unchanged and the input file is byte-identical (`cmp`). `update 7 f --run abc` and `--run` without a value → exit 1 with no gh call.
  10. `update 7 f` (no `--run`) records `pr edit 7 --body-file …`, and `gh_captured_file 'pr edit 7'` is a byte copy of `f`. `ready 7` records `pr ready 7`. `comment 7 f` records `pr comment 7 --body-file …` with a byte-exact capture. `update abc f`, `ready 0`, `comment 7 <missing>` → exit 1 with no gh call. None of the three prints anything on stdout.
- **verify:** `bats tests/scripts/gh-pr.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add gh-pr.sh for PR create, update, ready and comment`

---

### C2 — `scripts/git-branch.sh` (create, push)

- **files:** `scripts/git-branch.sh` (new, `+x`), `tests/scripts/git-branch.bats` (new). No fixture files are expected (`tests/scripts/fixtures/branch/` stays unused unless needed).
- **depends_on:** []
- **pattern:** A's conventions. `common.sh` (`config_get git.branch_pattern`, `git.milestone_branch_pattern`, `default_branch`; `is_run_id`). Spec AC-16 and A32. DESIGN §6.1 (`git` patterns, placeholders `{issue}`, `{milestone}`, `{slug}`), §9 (preflight updates the base, not this script), §10 (stacked PRs branch from another feature branch via `--base`). No in-repo analog; a new file is justified because DESIGN deliverable 8 names it.
- **RISKY:** NOT RISKY (local git only; the push goes to whatever `origin` is, and tests use a local bare repo)
- **AC verified:** AC-16
- **behaviour:** `create <run-id> <slug> [--base <b>]`:
  - Validates the run id and the slug (`^[a-z0-9]+(-[a-z0-9]+)*$`, refused, not transformed).
  - Picks the pattern: a numeric id uses `git.branch_pattern`, with `{issue}` replaced by the id. `m-N` uses `git.milestone_branch_pattern`, with `{milestone}` replaced by `N`. `{slug}` is replaced in both. Substitution is literal (quoted-pattern `${p//"$pat"/$v}`; verify this under bash 3.2 in the tests).
  - Dies if a `{…}` placeholder survives, and dies on `git check-ref-format --branch` failure.
  - Refuses on a dirty tree (`git status --porcelain` non-empty: modified, staged or untracked; gitignored files don't count).
  - Refuses an existing local branch (`git show-ref --verify --quiet refs/heads/<b>`).
  - Refuses a base that doesn't resolve to a commit (base = `--base`, else `config_get default_branch`).
  - Then runs `git switch --no-track -c <branch> <base>` (output to stderr) and prints the branch name.

  `push` takes no further arguments. It dies on a detached HEAD (`git symbolic-ref --quiet --short HEAD` fails) and when the current branch equals `config_get default_branch`. Otherwise it runs `git push -u origin <branch>` (output to stderr) and prints the branch name.
- **test scenarios (`git-branch.bats`):** real temp repos via `setup_project`. For push tests, `git init --bare "$BATS_TEST_TMPDIR/remote.git"` and `git remote add origin` it. After any `write_config`, commit (`git commit -qam cfg`) so the tree is clean again. All path comparisons use `pwd -P` values.
  1. `create 12 add-widget` prints `feat/12-add-widget`. `git symbolic-ref --short HEAD` equals it, and the new branch's commit equals `main`'s.
  2. `create m-3 sprint-four` prints `feat/m3-sprint-four` (milestone pattern).
  3. Custom patterns from config (`git.branch_pattern: "aew/{slug}-{issue}"`) → `aew/add-widget-12`. A config with no `git` key falls back to the schema defaults.
  4. `--base`: create a branch `feat/3-base` with an extra commit, switch back to `main`, then `create 4 child --base feat/3-base` → the new branch's commit equals `feat/3-base`'s (stacked). `--base nosuch` → exit 1, no branch created. Default base follows `default_branch` (config `trunk` with a `trunk` branch present).
  5. No upstream is set after create, even from a remote-tracking base (`--base origin/main` after a push of main to the bare remote): `git rev-parse --abbrev-ref @{u}` fails.
  6. Dirty-tree refusals, each with exit 1, `error:` on stderr, HEAD unchanged and no new branch: a modified tracked file; a staged new file; an untracked file. A file under the gitignored `.aew/runs/` does **not** block create.
  7. An existing branch (`create 12 add-widget` twice, switching back to `main` between) → the second exits 1, and HEAD stays on `main`.
  8. Bad input, exit 1 with no branch created:
     - slugs `Add-Widget`, `add_widget`, `-x`, `x-`, `a--b`, `""`;
     - run ids `0`, `abc`;
     - a pattern with an unknown placeholder (`feat/{ticket}-{slug}`) → `error:` naming the placeholder;
     - a pattern yielding an invalid ref (`feat/{slug}..x`);
     - `--bogus`; missing positionals.
  9. `push` on `feat/12-add-widget` → exit 0, prints `feat/12-add-widget`. The bare remote has `refs/heads/feat/12-add-widget` at HEAD's commit. `@{u}` is `origin/feat/12-add-widget`.
  10. `push` on `main` → exit 1 with an error naming the default branch, and the bare remote has no refs. With `default_branch: trunk` while on `trunk` → also refused.
  11. `push` on a detached HEAD (`git switch --detach`) → exit 1 with `detached`. `push extra` → exit 1. `push` with no `origin` remote → non-zero with git's error on stderr and nothing on stdout.
- **verify:** `bats tests/scripts/git-branch.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add git-branch.sh for run branch create and push`

---

### C3 — `scripts/gh-milestone.sh` (issues)

- **files:** `scripts/gh-milestone.sh` (new, `+x`), `tests/scripts/gh-milestone.bats` (new), `tests/scripts/fixtures/milestone/issues.json` (new: a canned `gh issue list` response, one issue per pattern), `tests/scripts/fixtures/milestone/expected.json` (new: the full expected output)
- **depends_on:** []
- **pattern:** A's conventions. Spec AC-14 and A30. DESIGN §10 (the dependency phrases; ordering and cycle detection are prompt 06, out of scope). The spec's "Key facts": gh 2.103 `--json` fields `blockedBy` and `labels` (`[{name,…}]`), `state` (`OPEN`/`CLOSED`), and `--milestone` taking a number or a title. No in-repo analog; a new file is justified because DESIGN deliverable 6 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-14
- **behaviour:** `issues <milestone>` (a non-empty string, passed through verbatim, whether a number or a title) runs one `gh issue list --milestone <m> --state all --limit 500 --json number,title,labels,state,body,blockedBy`. It then makes one jq pass that emits `[{number, title, labels: [name…], state, depends_on: [n…]}]`, sorted by `number`. `depends_on` is the `unique` (sorted, de-duplicated) union of three sources, minus the issue's own number (Decision 4):
  - phrase references;
  - task-list references;
  - native `blockedBy` numbers. Accept both an array of `{number,…}` and a `{nodes:[…]}` connection shape. If network and auth are available, confirm the real shape once by hand with `gh issue view <n> -R cli/cli --json blockedBy` (read-only; never in tests), and record the result in the report. If the real entries carry the blocking issue's repository and it differs from the listed repo, drop them (same reason as Decision 4: a bare number from another repo is ambiguous); if they carry no repository field, merge all numbers and note that in the report.

  CRLF bodies are handled. A null body counts as empty. Exactly 500 results → `warn` that the list may be truncated. An empty milestone → `[]`. A gh error → non-zero exit with gh's stderr.
- **test scenarios (`gh-milestone.bats`):** `gh_mock_respond issue-list "$FIXTURES/milestone/issues.json"`. One `@test` per pattern, each asserting the `depends_on` of one fixture issue with `jq -e`:
  1. `Blocked by #3` → `[3]`.
  2. `depends on #3, #4 and #5` (lower case) and `DEPENDS ON: #6 & #7` → `[3,4,5]` and `[6,7]` respectively (case-insensitive, list forms, optional colon).
  3. Task list `- [ ] #8` and `- [x] #9` (plus `* [X] #10`) → `[8,9,10]`. `- [ ] Fix login (#11)` and a prose mention `see #12` → not counted.
  4. Native `blockedBy: [{number: 13}]` → `[13]`. The connection shape `{nodes:[{number:14}]}` → `[14]`.
  5. Union, de-duplication and sorting: an issue with `Blocked by #5`, `- [ ] #3` and native `blockedBy` 5 → `[3,5]`.
  6. A self-reference (issue 20 saying `Depends on #20, #2`) → `[2]`.
  7. CRLF body with `Blocked by #4\r\n` → `[4]`. A null body and no `blockedBy` → `[]`.
  8. `acme/other#3` and `https://github.com/acme/widgets/issues/3` → not counted.
  9. The whole output equals `fixtures/milestone/expected.json` (`jq -S` on both sides). Each element has exactly the keys `number,title,labels,state,depends_on`. `labels` is an array of names. The output is sorted by number.
  10. The call is `issue list --milestone 3 --state all --limit 500 --json number,title,labels,state,body,blockedBy`. `issues "Sprint 4"` passes `--milestone Sprint 4` (with the title verbatim).
  11. An empty response `[]` → prints `[]`, exit 0. A gh failure (`gh_mock_respond issue-list - 1` with `could not find milestone`) → non-zero, empty stdout, message on stderr. A 500-item response (generated in-test with jq) → a `warning:` on stderr and still valid output.
  12. Bad input: `issues` with no milestone, `issues ""`, `bogus 3`, `--bogus` → exit 1 with no gh call.
- **verify:** `bats tests/scripts/gh-milestone.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add gh-milestone.sh issue listing with depends_on parsing`

---

### C4 — `scripts/gh-retro.sh` (file)

- **files:** `scripts/gh-retro.sh` (new, `+x`), `tests/scripts/gh-retro.bats` (new), `tests/scripts/fixtures/retro/retro.md` (new), `tests/scripts/fixtures/retro/open-issues.json` (new: a canned `gh issue list` response)
- **depends_on:** []
- **pattern:** A's conventions and `config_get` (`retro.repo` is required with no default and dies through `config_get`; `retro.label` defaults to `retro`). Spec AC-15 and A31 (Decisions 5 and 6 amend it). `templates/artefacts/retro.md`: items are `###` headings under `##` sections, a `### <short title>` heading is a placeholder, `## Cycles used` holds prose, and there is a leading HTML comment. DESIGN §8.7 and §9 (the orchestrator files retro items; never to the project repo). No in-repo analog; a new file is justified because DESIGN deliverable 7 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-15
- **behaviour:** `file <retro.md> <source-repo> <run-id>` validates:
  - that the file exists;
  - `source-repo` against `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`;
  - the run id (`is_run_id`).

  It reads `retro.repo` and `retro.label` (two `config_get` calls; a missing `retro.repo` dies before any `gh` call). It parses items with BSD-safe awk into a temp dir, one title and body per item:
  - a `###` heading starts an item;
  - the body runs until the next `#`/`##`/`###` heading, with leading and trailing blank lines trimmed;
  - headings inside fenced code blocks are ignored;
  - `\r` is stripped;
  - titles matching `^<.*>$`, or empty, are skipped.

  No items → `info` and exit 0 with no `gh` calls. Otherwise it:
  1. Ensures the label (Decision 5).
  2. Fetches the open issues once with `gh issue list --repo R --label L --state open --limit 500 --json number,title`.
  3. For each item, in file order:
     - **Match:** `gh issue comment <n> --repo R --body-file <tmp>`, where the body is `Seen again in <source-repo> run <run-id>`, a blank line, then the item body. Prints `commented #n`.
     - **No match:** `gh issue create --repo R --title <title> --label L --body-file <tmp>`, where the body is the item body plus a trailing provenance line `Filed by aew from <source-repo> run <run-id>.` It parses `#n` from the `/issues/<n>` URL and prints `created #n`.

  Normalisation and same-file duplicates follow Decision 6. A gh failure on any item stops with non-zero, and the lines already printed stand.
- **test scenarios (`gh-retro.bats`):** `setup_project` (the example config has `retro.repo jamesborg2012/claude-agentic-engineer-workflow` and label `retro`). `gh_mock_respond issue-list "$FIXTURES/retro/open-issues.json"` holds `{41, "Dev gate: stale report passes"}` and `{42, "Other thing"}`. `issue-create` responses are sequenced per call (`gh_mock_respond issue-create - 0 1` → `…/issues/50`, `… 0 2` → `…/issues/51`). The fixture `retro.md` has:
  - the template's leading comment;
  - a `### <short title>` placeholder;
  - `### dev gate — Stale REPORT passes!` (which must match #41);
  - `### Flaky QA screenshot` (new);
  - a fenced block containing `### not an item`;
  - prose under `## Cycles used`;
  - a second `### flaky qa screenshot` (a same-file duplicate).
  1. Output is exactly three lines, in order: `commented #41`, `created #50`, `commented #50`. There is exactly one `issue create` call and no call for the placeholder or the fenced heading.
  2. Comment body (`gh_captured_file 'issue comment 41'`): its first line is `Seen again in acme/widgets run 12`, then a blank line, then the item body verbatim, with no heading line and no trailing blank lines.
  3. Create call: the calls.log line contains `--title Flaky QA screenshot` and `--label retro`. The captured body holds the item body and the provenance line.
  4. **Every** calls.log line contains `--repo jamesborg2012/claude-agentic-engineer-workflow` (retro I/O never targets the project repo). The label call is `label create retro --repo …` (with `--color` and `--description`, without `--force`) and comes before `issue list`. `issue list` has `--label retro --state open`.
  4a. Label ensure is best-effort: `gh_mock_respond label-create - 1` with `label with name "retro" already exists` (and separately with `HTTP 403`) → a `warning:` on stderr, and stdout and the remaining calls are the same as test 1.
  5. Normalisation table, one in-test case each against `{41, "Dev gate: stale report passes"}`:
     - `DEV GATE STALE REPORT PASSES` → match;
     - `  dev   gate: stale-report passes. ` → match;
     - `dev gate stale report` → **no** match (equality, not prefix).
  6. Lowest number wins when two open issues normalise equal.
  7. A custom label in config (`retro.label: "aew-retro"`, committed) → used in the label, list and create calls. A config with `retro` holding only `repo` → label `retro`.
  8. Config without `retro.repo` (`write_config` with the key removed) → exit 1 with `no value or default for 'retro.repo'` and `gh_call_count` 0.
  9. A retro with only placeholders, or the bare `templates/artefacts/retro.md` → exit 0, empty stdout, no gh calls.
  10. CRLF `retro.md` → same results as test 1. The captured bodies contain no `\r`.
  11. A gh failure on create (`gh_mock_respond issue-create - 1`) → non-zero exit, and `commented #41` was already printed before the failure.
  12. Bad input, exit 1 with no gh call: a missing file; source repo `widgets` (no owner); run id `abc`; missing positionals; `bogus`; `--bogus`.
- **verify:** `bats tests/scripts/gh-retro.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add gh-retro.sh to file retro items to the retro repo`

---

## Phase exit check

- `tests/run-script-tests.sh` exits 0, with shellcheck clean on the four new scripts and `conventions.bats` covering them (`--help`, bad option, no arguments, bash 3.2 lint).
- `git diff --stat` against A's tip touches only `scripts/{gh-pr,git-branch,gh-milestone,gh-retro}.sh`, `tests/scripts/{gh-pr,git-branch,gh-milestone,gh-retro}.bats` and `tests/scripts/fixtures/{pr,milestone,retro,branch}/`. No A-, B- or D-owned file is changed.
- Four commits are planned (one per task). The prompt asks for one conventional commit overall, so squashing is raised at human review (architect constraint 4) and not done autonomously.

## Notes for phase E (github-ops skill) and closing

- Example invocations to document: `gh-pr.sh create <run-id> .aew/runs/<id>/pr-body.md [--draft]` → PR number → `state.sh set pr <n>`. `git-branch.sh create <run-id> <slug> [--base <parent-branch>]` → branch → `state.sh set branch <b>`. `git-branch.sh push`. `gh-milestone.sh issues <m>` (ordering and cycles are the orchestrator's job, prompt 06). `gh-retro.sh file .aew/runs/<id>/retro.md <owner/repo> <run-id>`.
- `gh-pr.sh update <pr> <body-file> --run <id>` for re-rendered bodies (Decision 3); plain `update` leaves the placeholder.
- The orchestrator must check `state.pr` before calling `create` (the CTO cut). A second create fails in `gh`.
- List the CTO cut as a deviation from AC-13 in the final report ("If a PR already exists … updates that PR's body" is not implemented), and the Decision 5 amendment as a deviation from A31's wording.
- Retro filing by a non-collaborator: `gh issue create --label` on a repo where the user lacks triage rights may drop the label or fail. Untestable offline; document it in the github-ops skill as a known limitation.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:38:30Z (plan-review, lean)
- Plan format: LEAN
- Risk lines crossed: none
- Plan dependency graph: valid. Wave count: 1. Max wave width: 4 tasks parallel (C1–C4, disjoint files).
- Architect amendments applied: strict-mode and `grep -P` ground rules (A contract update); `run_dir "$id"` read made explicit; Decision 5 changed from `--force` to best-effort create (warn and continue) plus test 4a; cross-repo `blockedBy` handling; normalisation re-check note; closing-report deviations.
- Plan content hash (SHA-256): bc0ec1f4885f41f4214b28f98019d85539db6b35d1a80c36d38097e049584eac (hash of the plan before this section was appended)
- Micro-revision on 2026-10-24T10:39:12Z: C1 update --run closing-line fix (senior MINOR adopted by orchestrator)

---

<!-- Phase D: from docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-phase-D.md -->

# Phase D plan — Hooks

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** D of the EPIC (runs in parallel with B and C after A; E closes)
- **Depth:** full
- **ACs covered:** AC-17, AC-18, AC-19, AC-20, AC-21, AC-22, AC-23
- **Risk:** safety-guards. Hooks fire in every session where the plugin is enabled; a bug either bricks sessions or silently removes protection. D2, D3, D4 and D6 are RISKY.
- **Builds on:** Phase A "Interface contract" (as revised after senior review) and `docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-platform-facts.md` (verified against code.claude.com/docs, 2026-10-24). This plan does not re-verify the docs.
- **Date:** 2026-10-24

## Purpose

Phase D builds DESIGN §11: two `PreToolUse` guards (Bash, Edit/Write), one `SubagentStop` gate (developer and qa-engineer), the `SessionStart` resume hint, the shared preamble `scripts/lib/hooks.sh`, `hooks/hooks.json`, and the DESIGN §3/§11 and `state-machine.md` corrections those platform facts require. D edits no A-owned file. Its tests are `tests/scripts/hooks-*.bats` and its fixtures live only under `tests/scripts/fixtures/hooks/`.

## Facts verified while planning (not assumptions)

Checked on this machine (`/bin/bash` 3.2.57, jq 1.7.1, Claude Code 2.1.308):

- **`[ a -nt b ]` is whole-second on bash 3.2.** A file written 0.2 s after another is *not* `-nt` it. So "report modified at or after the state write" is `! [ "$state" -nt "$report" ]`, which is true for the same second and later. No `stat`, no `perl`, no extra spawn. Tests make a report stale with `touch -t 202001010000 <report>` (portable on BSD and GNU).
- `read -r -a toks <<< "$seg"` word-splits on IFS **without** glob expansion (`*` survives as a literal token), and quotes stay in the token (`"main"`). So the Bash guard tokenises with `read -r -a` and strips `'` and `"` per token. No `set -f` needed.
- `${s//&&/$'\n'}` works on bash 3.2.
- `shopt -s nocasematch` works with `case` on bash 3.2 (`.ENV` matches `.env)`).
- **IFS-whitespace collapse:** with `IFS=$'\t' read -r a b <<< $'\tfalse'`, `a` becomes `false` (a leading empty field is collapsed, because tab is IFS whitespace). So when one jq `@tsv` line carries several fields, the field that is never empty goes **first** (`[stop_hook_active, cwd]`).
- jq exits 5 on a non-object payload (`[]`), and exits **0 with no output** on empty stdin. So the preamble rejects an empty payload explicitly; it can't rely on jq's status.
- An EXIT trap set inside a function under `set -e` fires on a failing `x=$(exit 3)` with `$?` = 3, and `exit 0` in the trap makes the shell exit 0. This is the fail-open mechanism.
- **(Added at architect review, verified on `/bin/bash` 3.2.57.)** After an **unbound variable** (`set -u`) or a **syntax error** later in the file, bash 3.2 still runs the EXIT trap and the hook exits 0, but `$?` in the trap is **0**, so `_hook_exit` prints no "failing open" warning. These paths fail open *silently*. In the Bash guard that means an empty-array expansion such as `"${toks[@]}"` on a blank segment silently **allows the whole command**. Hence the empty-segment and empty-token rules in D2 and the `${a[@]+"${a[@]}"}` rule below.
- **(Added at architect review, verified.)** `IFS=$'\t' read -r a b <<<"$(jq … bad-file)"` returns 0 with empty fields when jq fails: a failure inside a here-string's `$(…)` is invisible. Capture first (`x=$(jq …) || …`), then `read <<<"$x"`.
- **(Added at architect review, verified.)** In `case` patterns, `[a-z]*` means *one* letter followed by *anything*, not "zero or more letters". So the glob `-[a-zA-Z]*f[a-zA-Z]*` does **not** match `-uf` or `-f`. Short-option clusters are therefore defined in D2 as tokens matching `-[!-]*`, tested with `*f*`.
- `claude plugin validate .` passes on the current tree (exit 0, "passed with warnings" from the directory profile). It **does** validate `hooks/hooks.json`, but an unknown event name is only a warning (`❯ hooks: hooks.PreToolUze: unknown hook event; entry ignored at runtime`) and still exits 0. The hooks.json test therefore also asserts there is no `hooks:` finding in the output.

## Corrections to the spec's assumptions (from the platform facts)

| Spec | Change in this plan | Why |
|---|---|---|
| A4 (accept `developer` and `aew:developer`) | Accept only `aew:developer` and `aew:qa-engineer`. The `SubagentStop` matcher is the anchored regex `^aew:(developer\|qa-engineer)$`, so a bare name never reaches the script; accepting it would be dead code. Any other `agent_type` → exit 0 silently. | Platform facts 3: the matcher matches `agent_type`, and plugin agents are `aew:<agent>`. |
| A2 / A3 / A5 | Confirmed as written: PreToolUse deny is `hookSpecificOutput.permissionDecision: "deny"` on exit 0, SubagentStop block is top-level `{"decision":"block","reason":…}` on exit 0, SessionStart uses `hookSpecificOutput.additionalContext`. No hook ever exits 2. | Platform facts 4–6. |
| A7 | Confirmed: exit-0 stderr is never shown to Claude (debug log only). Per the architect's note, hooks are still **silent** when there is no `.aew/` at all, and warn only when `.aew/` exists without `config.json`. | Platform facts 7. |
| A17 | The return-block validator moves from `hooks.sh` into `gate-subagent.sh`, its only caller (CTO cut). | CTO cut. |
| AC-18 (`MultiEdit`/`NotebookEdit` "if the docs list them") | Matcher is `Edit\|Write` only. `MultiEdit` is not a documented current tool, and `NotebookEdit` edits only `.ipynb` files, which can't be a `.env*`, a secret file or a `.git/` path in practice. | Platform facts 2 ("not documented"); simplicity. |
| AC-22 ("an ERR trap forces exit 0") | An **EXIT** trap, installed after `$1` handling. | Phase A contract: ERR never fires for `die`'s `exit`, nor inside functions without `set -E`. |
| AC-19 ("modified at or after the run's `updated_at`") | Implemented as "not older than `state.json`" (`! [ state.json -nt report ]`). `state.sh` writes `updated_at = now` and renames `state.json` in the same second, and only `state.sh` writes it, so the two are equivalent at bash 3.2's whole-second resolution without a date parse or a `stat`. | Facts above; A lint bans `stat -c`/`stat -f`. |

## Contract for D2–D5: `scripts/lib/hooks.sh`

A library (the A conventions for `scripts/lib/*.sh` apply: shebang, `Usage:` header, last line `if [ "${BASH_SOURCE[0]}" = "$0" ]; then lib_main "$0" "$@"; fi`). It sources common.sh with `# shellcheck source=common.sh` then `. "$(dirname "${BASH_SOURCE[0]}")/common.sh"`. At source time it only defines functions. It is the shared preamble and nothing else.

Every hook script starts:

```bash
#!/usr/bin/env bash
# Usage: <hook>.sh < payload.json
# …
# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"
hook_init "$@"
```

Sourcing `common.sh` explicitly satisfies A's convention 1 (the executable sources `lib/common.sh`). The double-source guard makes the second source inside `hooks.sh` a no-op.

| Function | Behaviour |
|---|---|
| `hook_init [arg…]` | In this order. **(1)** Arguments: `-h`/`--help` → `print_usage "$0"`, exit 0. Any other non-empty `$1` → `die "unexpected argument: $1 (hooks take their payload on stdin)"`, exit 1 (convention 4; the trap isn't installed yet, so the 1 survives). **(2)** `trap _hook_exit EXIT`. **(3)** `command -v jq` fails → `warn "jq not found; aew hooks are disabled"`, exit 0. **(4)** `HOOK_PAYLOAD=$(cat)`. If it's empty, or `parsed=$(jq -r '[(.stop_hook_active == true \| tostring), (.cwd // "" \| tostring)] \| @tsv' <<<"$HOOK_PAYLOAD" 2>/dev/null)` fails → `warn "unreadable hook payload; failing open"`, exit 0. `IFS=$'\t' read -r HOOK_STOP_ACTIVE HOOK_CWD <<<"$parsed"` (the never-empty field first; see the IFS fact). **(5)** `HOOK_STOP_ACTIVE` = `true` → `warn "stop_hook_active is set; allowing the stop"`, exit 0. **(6)** `dir=${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}` (spec A6 precedence). `HOOK_ROOT=$(repo_root "$dir" 2>/dev/null) \|\| exit 0`: not a git repo, so not an aew project, so **silent**. **(7)** `[ -f "$HOOK_ROOT/.aew/config.json" ]` fails → if `[ -d "$HOOK_ROOT/.aew" ]`, `warn ".aew/config.json is missing; aew hooks are disabled (run /aew:init)"`; exit 0 either way (silent when there's no `.aew/`). **(8)** `cd "$HOOK_ROOT"` (so `config_get`/`run_dir` resolve), and set `HOOK_CWD=${HOOK_CWD:-$dir}`. Globals afterwards: `HOOK_PAYLOAD`, `HOOK_CWD` (where the tool runs; may be a linked worktree), `HOOK_ROOT` (main worktree root, physical), `HOOK_STOP_ACTIVE`. |
| `_hook_exit` (EXIT trap) | `s=$?`; `trap - EXIT`; if `s` ≠ 0, `warn "unexpected error (status $s); failing open"`; `exit 0`. Every path after step (2) therefore exits 0, including `die`, errexit and a failing `$(…)` at top level. |
| `hook_field <jq-path>` | `jq -r "<path> // empty" <<<"$HOOK_PAYLOAD"`. Prints the raw string (empty if absent or null). Callers write `cmd=$(hook_field .tool_input.command) \|\| exit 0`, per the A strict-mode caveat. |

Rules every hook follows (A strict-mode caveat): internal functions are called from `if`/`&&`/`||`, so `set -e` is off inside them. Every command whose failure matters is checked explicitly (`x=$(fn) || return 1`). Never `local x=$(…)`. Never feed `$(…)` straight into `read <<<` (its failure is invisible; capture it first). Every array expansion that can be empty is written `${a[@]+"${a[@]}"}`, and every `${a[0]}` is guarded by a `${#a[@]}` check, because an unbound-variable exit fails open silently (facts above). Output is produced by one `jq -n --arg …` call at the very end, so a failure can't leave partial JSON on stdout. No `|&`, `&>>`, `stat`, `grep -P` or `sed -i` anywhere (A lint), including inside `case` patterns. The redirection pattern is written `'&>'*`, never with a literal `&>>`.

## Tasks

Dependency graph: D1 → {D2, D3, D4, D5} (in parallel; each touches only its own script, bats file and fixtures) → D6 → D7.

---

### D1 — Shared hook preamble `scripts/lib/hooks.sh`

- **files:** `scripts/lib/hooks.sh` (new), `tests/scripts/hooks-lib.bats` (new), `tests/scripts/fixtures/hooks/pretooluse-bash.json`, `pretooluse-edit.json`, `subagentstop.json`, `sessionstart.json` (new)
- **depends_on:** []. Phase A must be complete (`common.sh`, the helpers, `seed_run`).
- **pattern:** The `hooks.sh` contract above. Phase A's `common.sh` (library layout, `lib_main` last line, `print_usage` header). Spec A6, A9 and A10, and the CTO cut. Net-new file: no analog exists, four hooks share the preamble, and the spec's scope names it.
- **RISKY:** NOT RISKY. The library has no effect until a hook uses it. D2–D6 carry the risk.
- **AC verified:** AC-22 (the preamble half: fail open, `stop_hook_active`, EXIT trap), AC-28
- **implementation notes:**
  - Payload fixtures are the documented shapes (platform facts 3, 4 and 6), with the common fields `session_id`, `transcript_path`, `cwd`, `hook_event_name` and `permission_mode`, plus:
    - `pretooluse-bash.json`: `tool_name: "Bash"`, `tool_input.command`, `tool_use_id`;
    - `pretooluse-edit.json`: `tool_name: "Edit"`, `tool_input.file_path` (absolute), `old_string`, `new_string`;
    - `subagentstop.json`: `stop_hook_active: false`, `agent_id`, `agent_type: "aew:developer"`, `agent_transcript_path`, `last_assistant_message`;
    - `sessionstart.json`: `source: "startup"`.
    Tests override fields with `jq -c --arg …`, never by editing the files.
  - In-test stub hook: each test writes `$BATS_TEST_TMPDIR/stub.sh`, with a `Usage:` header, sourcing `$SCRIPTS/lib/common.sh` and `hooks.sh` by absolute path, then calling `hook_init "$@"`, then `printf 'cwd=%s root=%s pwd=%s\n' "$HOOK_CWD" "$HOOK_ROOT" "$PWD"`, then an optional `$STUB_TAIL` evaluated (for example `false`, `die boom` or `x=$(exit 3)`).
- **test scenarios (`hooks-lib.bats`).** RED first: every test fails with "No such file" on `hooks.sh`.
  1. `bash scripts/lib/hooks.sh --help` → exit 0 with `Usage:` on stdout. `bash scripts/lib/hooks.sh foo` → exit 1 with `is a library`.
  2. Stub `--help` from a non-git dir with stdin at `/dev/null` → exit 0 with `Usage:`. Stub `--bogus` → exit **1**, empty stdout, `error:` on stderr. This proves `$1` is handled before the trap.
  3. Happy path in an aew project (`setup_project`; payload `cwd` = `$PROJECT/sub`) → exit 0, `cwd=$PROJECT/sub`, `root=$PROJECT`, `pwd=$PROJECT`.
  4. Precedence: `CLAUDE_PROJECT_DIR=$PROJECT` with payload `cwd` = a non-git temp dir → active (`root=$PROJECT`). No `CLAUDE_PROJECT_DIR` and no `cwd` key → falls back to `$PWD`.
  5. Linked worktree: `git worktree add "$BATS_TEST_TMPDIR/wt" -b feat/x`, payload `cwd` = `wt` → `root=$PROJECT`, `cwd=…/wt`.
  6. Inert and silent: a non-git `cwd` → exit 0, empty stdout, **empty stderr**. A git repo without `.aew/` (`setup_project --no-config`, then `rm -rf .aew`) → exit 0 with empty stdout and stderr.
  7. `.aew/` without `config.json` (`setup_project --no-config`, `mkdir .aew`) → exit 0, empty stdout, stderr has `stub.sh: warning:` and `config.json is missing` (`warn` prefixes `${0##*/}`, which is the stub, not `hooks.sh`).
  8. jq missing: build `$BATS_TEST_TMPDIR/nojq` with symlinks to `bash` and `dirname` only, then run the stub with `PATH=$BATS_TEST_TMPDIR/nojq` → exit 0, empty stdout, stderr has `jq not found`.
  9. Payload `''`, `not json` and `[]` → exit 0, stub tail not reached (no `cwd=` on stdout), stderr has `unreadable hook payload`.
  10. `stop_hook_active: true` → exit 0, not reached, stderr has `stop_hook_active`. `stop_hook_active: false`, or the key absent → reached.
  11. Fail-open trap: `STUB_TAIL='false'`, `'die boom'` and `'x=$(exit 3)'` → each exits 0, and stderr has `failing open` (plus `error: boom` for `die`).
  12. `hook_field .tool_input.command` returns the string. A missing path returns empty with status 0. A `null` returns empty.
- **verify:** `bats tests/scripts/hooks-lib.bats` green. `bats tests/scripts/conventions.bats` green (`hooks.sh` now in the lib set). `tests/run-script-tests.sh` green (shellcheck).
- **commit:** `feat(hooks): add shared hook preamble hooks.sh`

---

### D2 — Bash guard `scripts/hooks/guard-bash.sh`

- **files:** `scripts/hooks/guard-bash.sh` (new, `+x`), `tests/scripts/hooks-guard-bash.bats` (new), `tests/scripts/fixtures/hooks/bash-cases.tsv` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. DESIGN §11 (the Bash guard list). Spec AC-17, A11 and A12. Output shape from platform facts 4. A new file is justified because DESIGN §11 names the hook and nothing in the repo parses shell commands.
- **RISKY:** RISKY. It runs on every Bash call in aew projects. A false negative removes protection; a false positive blocks agent work.
- **AC verified:** AC-17, AC-22 (the guard's timing)
- **implementation notes:**
  - The header block documents the rules and the **limits**: it's a heuristic safety net, not a sandbox. It doesn't look inside `bash -c`/`sh -c`, `eval`, `$(…)` or backtick command substitution, aliases, functions or `xargs`. It doesn't parse `sudo` options that take a value (`sudo -u root rm -rf /` is not caught). Branch-dependent rules use the branch at hook time, plus the conservative `git switch`/`git checkout` rule in the flow below. Quoted text containing `;`, `|` or `&&` is split too, and heredoc lines are scanned as commands, so false positives are possible (spec risk "Bash guard bypass", retro "False-positive hooks").
  - Flow:
    1. `hook_init "$@"`.
    2. `cmd=$(hook_field .tool_input.command) || exit 0`; an empty `cmd` → exit 0.
    3. `ecwd` = `HOOK_CWD` canonicalised with `(cd "$HOOK_CWD" 2>/dev/null && pwd -P)`, falling back to `HOOK_ROOT`.
    4. First delete backslash-newline line continuations (`${cmd//$'\\\n'/ }`, so `git push \⏎ --force` is one command). Then split `cmd` into segments: replace `&&`, `||`, `|`, `;` and newline with newline, in that order, using `${…//…/$'\n'}`. **Skip a segment whose token array is empty**, before or after normalisation (blank lines, `&&⏎`, a lone `}`, `> out.log`). An empty array must never reach an unguarded expansion (facts: that exits 0 silently and allows the whole command).
    5. For each segment: `read -r -a`, then normalise the tokens:
       - strip `'` and `"`;
       - strip leading `(`/`{` from the first token and trailing `)`/`}` from any token, then **drop tokens that are now empty** (`( git push -f )`, `{ git push -f; }`);
       - a standalone `&` token **ends the command**: the tokens before it are checked, and the tokens after it are processed as a new segment (`sleep 1 & git push -f`). A trailing `&` just ends the last command;
       - drop redirections, i.e. tokens matching `'>'*`, `'<'*`, `[0-9]'>'*`, `[0-9]'<'*` or `'&>'*` (glob semantics: one digit, not "any digits"). When the token **ends** with `>` or `<` (`>`, `>>`, `2>`, `2>>`, `&>`, `<`), drop the next token too. Without this, `git push origin >/dev/null` on main reads `>/dev/null` as a refspec and is allowed.
    6. Strip leading prefix words: `VAR=value` assignments, `sudo` (and its `-*` flags), `env` (and its `-*` flags and assignments), `command`, `builtin`, `exec`, `nohup`, `time`, `!`, `if`, `then`, `elif`, `else`, `do`, `while` and `until`.
    7. `cd <dir>` updates `ecwd` for the following segments (relative to `ecwd`; no argument means `$HOME`; `cd -` or a missing dir leaves it unchanged).
    8. Dispatch on the basename of the first token (`/usr/bin/git` → `git`).
    9. The first violation prints the deny JSON and exits 0.
  - **Short-option cluster** (used by push, clean and rm): a token matching the glob `-[!-]*` (one dash, then a non-dash). "Contains `f`" is `*f*` on that token. Long options (`--*`) are never clusters, so `--follow-tags` and `--no-verify` don't count as `f`. Don't use the glob `-[a-zA-Z]*f[a-zA-Z]*`, which matches neither `-f` nor `-uf` (facts).
  - **Branch switch in the same command (conservative).** A `git switch` or `git checkout` segment without a `--` argument, whose branch argument (the value of `-c`/`-C`/`-b`/`-B`, or else the first positional) equals the default branch, sets `switched_to_default=1` for the rest of the command. From then on, the push-without-refspec, `HEAD`/`@` and `reset --hard` rules treat the branch as the default whatever `branch_of` says. This catches `git checkout main && git merge feat/x && git push`. It only ever adds blocks. `git checkout main -- f` (a file checkout) doesn't count.
  - Lazy, cached lookups (only when a rule needs them):
    - `default_branch` from `config_get default_branch`. If that fails, `warn` and exit 0 (fail open).
    - `branch_of <dir>` from `git -C <dir> symbolic-ref --short -q HEAD` (empty if detached or not a repo, which counts as "not the default").
    - `toplevel_of <dir>` from `git -C <dir> rev-parse --show-toplevel`, canonicalised with `pwd -P` (empty outside a repo).
  - **git:**
    - Global options: `-C <d>` (cumulative, relative to the previous dir), `-c <kv>`, `--git-dir=`, `--work-tree=`, `--no-pager`, and any other `-*`. The next non-option token is the subcommand.
    - **push.** Options that take a value: `-o`, `--push-option`, `--receive-pack`, `--exec`, `--repo`. `--` ends the options. Then:
      - **Force:** `--force`, `--force-with-lease*`, `--force-if-includes`, a short-option cluster containing `f` (`-f`, `-uf`, `-fu`), or any refspec starting with `+` → deny "force push".
      - **Everything:** `--all` or `--mirror` → deny "push of every branch includes '<default>'".
      - **Positionals:** the first is the remote and the rest are refspecs. For each refspec, the destination is the part after the last `:` (or the whole refspec), with `refs/heads/` stripped. `HEAD` or `@` means `branch_of <git dir>`.
      - A destination equal to the default branch → deny "push to the default branch". This covers `main`, `HEAD:main`, `x:refs/heads/main`, `:main` and `--delete main`.
      - No refspecs, and `branch_of` equals the default → deny.
    - **reset.** Any `--hard` and `branch_of <git dir>` equal to the default → deny "git reset --hard on the default branch".
    - **clean.** Union of the letters in short clusters, plus `f` for `--force`. If it contains `f`, `d` **and** lower-case `x` → deny "git clean -fdx". `-X` is allowed.
  - **gh:** skip `-*` options (`-R`/`--repo` take a value). The first two positionals `pr merge` → deny. `repo delete` → deny.
  - **rm:**
    - Recursive if any short cluster contains `r` or `R`, or `--recursive` is present (`--` ends the options). Not recursive → allow.
    - For each target:
      - if it contains `$` or a backtick → deny "unexpanded variable or command substitution";
      - `~` and `~/…` expand to `$HOME`; `~user` → deny;
      - a trailing `/*` (or a bare `*`) becomes its directory;
      - normalise lexically against `ecwd` (pure bash: split on `/`, a stack for `.` and `..`, collapse `//`), then canonicalise the nearest existing ancestor with `pwd -P` and re-append the rest (macOS `/var` → `/private/var`). If no ancestor exists, use the lexical result.
    - Deny unless the target is **strictly inside** `toplevel_of "$ecwd"` and is not `$HOME`. This covers `/`, system paths, home, the repo root, its ancestors, and anything outside the repo, including when there is no toplevel.
  - Deny JSON, built with one `jq -n --arg r "$reason"`: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}`. The reason reads `aew guard: blocked <rule> in "<segment>". aew never does this; if it is needed, James runs it himself.`
- **test table `fixtures/hooks/bash-cases.tsv`.** Columns are `expect` (`block`/`allow`), `branch` (`main`/`feat`, where `feat` is `feat/x`), `cwd` (relative to `$PROJECT`: `.`, `sub` or `tests`) and `command`. `@PROJECT@` is substituted with the physical project path, and the `command` column is passed through `printf '%b'`, so `\n` is a newline and `\\` a backslash (no other row contains a backslash). There are 82 rows, listed below.
  - **Prompt-mandated blocked (11):**
    - `git push origin main` (feat)
    - `git push` (main)
    - `git push -f` (feat)
    - `git push --force-with-lease` (feat)
    - `gh pr merge 3`
    - `gh repo delete`
    - `git reset --hard` (main)
    - `rm -rf /`
    - `rm -rf ~`
    - `rm -rf ..` (cwd `.`)
    - `git clean -fdx`
  - **Prompt-mandated allowed (6):**
    - `git push origin feat/x` (feat)
    - `rm -rf node_modules`
    - `rm -rf tests/tmp`
    - `npm test`
    - `git reset --hard` (feat)
    - `gh issue view 3`
  - **Spec-mandated blocked:**
    - compound commands: `cd sub && git push origin main`, `npm test && git push -f`
    - `-C`: `git -C .. push` (cwd `sub`, main)
    - `+refspec` and destination refspecs: `git push origin +feat/x`, `git push origin HEAD:main`, `git push origin feat/x:refs/heads/main`
    - `sudo rm -r /etc`
    - separated and reordered flags: `git clean -xdf`, `git clean -f -d -x`, `rm -r -f /`
  - **Further blocked:**
    - `git push -uf origin feat/x`
    - `git push --force origin feat/x`
    - `git push --force-with-lease=feat/x origin feat/x`
    - `git push origin --delete main`
    - `git push origin :main`
    - `git push origin HEAD` (main)
    - `git push --all`
    - `git push 2>&1` (main; the redirection is stripped)
    - `FOO=1 git push -f`
    - `env GIT_TRACE=1 git push origin main`
    - `/usr/bin/git push origin main`
    - `(git push -f)`
    - `if true; then git push -f; fi`
    - `git push -f &`
    - `rm -rf "$HOME"`
    - `rm -rf $TMPDIR/x`
    - `rm -rf ./*` (cwd `.`)
    - `rm -rf /tmp/build`
    - `rm -rf @PROJECT@`
    - `rm -rf ../..` (cwd `sub`)
    - `rm --recursive --force /`
    - `git reset --hard origin/main` (main)
    - `gh pr merge 3 --squash --auto`
    - `gh repo delete acme/widgets --yes`
    - `git push origin 'main'`
  - **Parser edge cases, added at architect review (blocked, 9):**
    - `sleep 1 & git push -f` (feat; `&` separates commands)
    - `( git push -f )` (standalone `(`/`)` tokens)
    - `{ git push -f; }`
    - `> out.log && git push -f` (a segment that is empty after normalisation)
    - `git status &&\ngit push -f` (feat; a blank segment from `&&` plus a newline)
    - `git push \\\n  --force` (feat; line continuation)
    - `git push origin >/dev/null 2>&1` (main; the redirection is not a refspec)
    - `git checkout main && git push` (feat)
    - `git switch main && git reset --hard origin/main` (feat)
  - **Parser edge cases, added at architect review (allowed, 2):**
    - `git checkout feat/x && git push` (feat)
    - `git checkout main -- README.md && git push` (feat; a file checkout)
  - **Further allowed:**
    - `git push` (feat)
    - `git push -u origin feat/x`
    - `git push origin HEAD` (feat)
    - `git push origin feature-main` (main)
    - `git push --follow-tags origin feat/x`
    - `rm -rf dist/*`
    - `cd tests && rm -rf tmp`
    - `rm -rf ./node_modules`
    - `rm -f /tmp/x` (not recursive)
    - `rm file.txt`
    - `git reset --soft HEAD~1` (main)
    - `git clean -fd`
    - `git clean -fdX`
    - `git commit -m "main"`
    - `echo "git push -f"`
    - `gh pr view 3`
    - `gh pr create --fill`
    - `git status`
    - `ls -la`
- **test scenarios (`hooks-guard-bash.bats`).** RED first: every test fails because `guard-bash.sh` is missing. Record that output.
  1. **Table.** `setup_project`, then `mkdir -p sub tests/tmp node_modules dist`, then `git branch feat/x`. For each row: `git switch -q <branch>`, build the payload from `pretooluse-bash.json` with `.tool_input.command` and `.cwd` overridden, then `run_hook guard-bash.sh "$payload"`. Every run must exit 0. Stdout must be either empty (allow) or JSON with `.hookSpecificOutput.permissionDecision == "deny"`, `hookEventName == "PreToolUse"` and a non-empty `permissionDecisionReason` (block). Collect every mismatch as `expect/branch/cwd/command/got`, and fail once listing them all.
  2. **Table integrity.** The table has at least 20 rows. All 17 prompt-mandated rows are present with the expected outcome, matched exactly by `command` and `expect`, so the table can't erode silently.
  3. The deny reason names the rule: `git push -f` → `force push`; `git push origin main` → `default branch`; `rm -rf /` → `rm`.
  4. A custom default branch: `write_config` with `default_branch: "trunk"`, then `git switch -c trunk`. `git push origin trunk` is blocked and `git push origin main` is allowed.
  5. A linked worktree (`git worktree add ../wt feat/x`, payload `cwd` = `wt`): `rm -rf node_modules` inside `wt` is allowed (the toplevel is `wt`), `rm -rf ../project` is blocked, and `git push` is allowed (the branch is `feat/x`).
  6. Timing: write the worst-case payload (`cd sub && git push origin HEAD && git reset --hard && rm -rf ../tests/tmp`, on feat) to a file, then `elapsed_ms bash -c '"$0" < "$1"' "$SCRIPTS/hooks/guard-bash.sh" "$f"` < 1000.
- **verify:** `bats tests/scripts/hooks-guard-bash.bats` green. `bats tests/scripts/conventions.bats` green (`--help`, bad option, lint). `tests/run-script-tests.sh` green.
- **commit:** `feat(hooks): add PreToolUse Bash guard with an 82-case table`

---

### D3 — Edit/Write guard `scripts/hooks/guard-edit.sh`

- **files:** `scripts/hooks/guard-edit.sh` (new, `+x`), `tests/scripts/hooks-guard-edit.bats` (new), `tests/scripts/fixtures/hooks/edit-cases.tsv` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. The deny JSON from D2 (the same one-line `jq -n` written inline; the CTO cut keeps `hooks.sh` to the preamble). DESIGN §11. Spec AC-18 and A13. Platform facts 4: `file_path` is always absolute.
- **RISKY:** RISKY. It runs on every Edit/Write in aew projects.
- **AC verified:** AC-18, AC-22 (timing)
- **implementation notes:**
  - Flow:
    1. `hook_init "$@"`.
    2. `p=$(hook_field .tool_input.file_path) || exit 0`; empty → exit 0.
    3. A relative path is prefixed with `HOOK_CWD/` (defensive).
    4. `shopt -s nocasematch`.
    5. `.git` component: `case "/$p/" in */.git/*)` → deny. This covers `.git/config`, `.git/hooks/x` and a worktree's `.git` file, but not `.gitignore` or `.github/`.
    6. Basename `b=${p##*/}`. Allowed first: `.env.example`, `.env.sample`, `.env.template`. Then denied: `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `.netrc`, `.npmrc`, `.pgpass` and `auth.json`.
  - Reason: `aew guard: blocked a write to <path> (<rule>). Secrets and git internals are never edited by aew; ask James.`
- **test table `edit-cases.tsv`** (`expect`, `path relative to $PROJECT`). These are written as absolute paths in the payload.
  - **Blocked:** `.env`, `.env.local`, `.git/config`, `.git/hooks/pre-commit`, `config/.env.production`, `.ENV`, `certs/server.pem`, `tls.key`, `id_rsa`, `id_ed25519.pub`, `.netrc`, `.npmrc`, `.pgpass`, `auth.json`, `sub/.git`.
  - **Allowed:** `.env.example`, `.env.sample`, `.env.template`, `.gitignore`, `.github/workflows/ci.yml`, `src/env.ts`, `README.md`, `docs/keys.md`, `environment.md`, `src/.envrc-notes.md`.
- **test scenarios (`hooks-guard-edit.bats`).** RED first: every test fails because the script is missing.
  1. Table loop (as in D2), with both `tool_name: "Edit"` and `tool_name: "Write"` payloads. All rows match, and all exit 0. AC-18's four named paths (`.env`, `.env.local`, `.git/config` blocked; `.env.example` allowed) are asserted present.
  2. The deny JSON shape is the same as D2's. The reason contains the path.
  3. A missing `tool_input.file_path` → allow, exit 0.
  4. Timing on a blocked path is under 1000 ms.
- **verify:** `bats tests/scripts/hooks-guard-edit.bats` green. Conventions and `run-script-tests.sh` green.
- **commit:** `feat(hooks): add PreToolUse Edit/Write guard for secrets and .git`

---

### D4 — Subagent gate `scripts/hooks/gate-subagent.sh`

- **files:** `scripts/hooks/gate-subagent.sh` (new, `+x`), `tests/scripts/hooks-gate-subagent.bats` (new), `tests/scripts/fixtures/hooks/dev-report-ok.md`, `dev-report-blocked.md`, `dev-report-no-commands.md`, `qa-test-plan-ok.md`, `qa-report-ok.md` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. DESIGN §7.1 (file names), §7.5 (the return block) and §11. Spec AC-19, AC-20, A8, A14 and A15. `templates/artefacts/dev-report.md`, `qa-test-plan.md` and `qa-report.md` are what the gate parses. The tests also run the **real templates**, so template drift is caught. Block shape from platform facts 5. Reads state directly (`jq … "$(run_dir)/state.json"`), per the A contract. Only `state.sh` writes it.
- **RISKY:** RISKY. A wrong block traps the developer or QA in a loop; a wrong allow removes the gate.
- **AC verified:** AC-19, AC-20, AC-22 (gate timing and `stop_hook_active` through the preamble)
- **implementation notes:**
  - Flow:
    1. `hook_init "$@"`. `stop_hook_active: true` has already exited 0 there (A8: exactly one corrective block).
    2. `agent=$(hook_field .agent_type) || exit 0`. Case `aew:developer` → `gate_developer`; `aew:qa-engineer` → `gate_qa`; anything else → exit 0 silently.
    3. Both gates: `[ -f .aew/runs/current ]`, else `warn "no current aew run; not gating"` and exit 0. Then `rd=$(run_dir) || exit 0`. The explicit `exit 0` means the trap sees status 0 and adds nothing; `run_dir`'s own `error:` line, for example `invalid run id`, is the stderr message. `[ -f "$rd/state.json" ]`, else warn "state file missing" and exit 0. Then **one** jq call, captured first: `st=$(jq -r '[.stage, (.fix_cycle|tostring)]|@tsv' "$rd/state.json" 2>/dev/null) || { warn "unreadable state file; not gating"; exit 0; }`, then `IFS=$'\t' read -r stage fix_cycle <<<"$st"`. Don't put the jq call inside the here-string, where its failure is invisible (facts). An empty `stage` → the same warning, exit 0.
  - `valid_return_block <file>`. `awk` collects the non-blank lines (with `\r` stripped) and prints the last four. Bash then checks them in order:
    - `^STATUS:[[:space:]]*(ok|needs_input|blocked|failed)[[:space:]]*$`;
    - `^ARTEFACTS:[[:space:]]*[^[:space:]]`;
    - `^SUMMARY:[[:space:]]*[^[:space:]]`;
    - `^NEXT:[[:space:]]*[^[:space:]]`.
    The regexes live in variables for bash 3.2's `[[ =~ ]]`. On failure it prints a one-line reason (`last 4 non-blank lines are not STATUS/ARTEFACTS/SUMMARY/NEXT`, or `STATUS must be one of ok, needs_input, blocked, failed`) and returns 1. On success it prints the status value. The template placeholder `STATUS: ok | needs_input | …` fails the STATUS regex.
  - `gate_developer`:
    1. Find the newest of `"$rd"/06-dev-report*.md` with a pure-bash `-nt` loop (no `ls`). None → block "no 06-dev-report*.md".
    2. `[ "$rd/state.json" -nt "$newest" ]` → block "<file> predates the current run state (an earlier cycle); write this cycle's report".
    3. `valid_return_block` fails → block with its reason.
    4. Status `ok` and `commands_filled "$newest"` fails → block "STATUS ok but the ## Commands run table has no filled-in row (command and result)".
  - `commands_filled`: `awk` over the lines after `^## Commands run` up to the next `^## `. Table rows are `^\|`. Skip the header (first cell `Command`) and the separator (`^\|[-: |]+\|$`). A row counts when both trimmed cells are non-empty and neither matches `^<.*>$`. The template rows `| <lint command> | pass |` don't count.
  - `gate_qa`:
    - Stage `plan` or `qa_test_plan` → `04-qa-test-plan.md`.
    - Stage `qa` → `08-qa-report-$((fix_cycle + 1)).md`.
    - Any other stage → `warn "qa-engineer stopped at stage <stage>; not gating"`, exit 0.
    - Missing → block "<file> is missing". Then `valid_return_block`.
  - Block output, built with one `jq -n --arg r`: `{"decision":"block","reason":$r}`. The reason is prefixed `aew gate:`, names the path relative to the project (`.aew/runs/<id>/…`), and adds `Use the template at <plugin_root>/templates/artefacts/<name>.md and end the file with the return block (STATUS, ARTEFACTS, SUMMARY, NEXT).`
- **test scenarios (`hooks-gate-subagent.bats`).** Setup: `setup_project`, then `seed_run 12`. Payloads come from `subagentstop.json` with `.agent_type` and `.cwd` overridden. Stages are moved with the real `state.sh stage …` and `state.sh bump fix_cycle`. RED first: every test fails because the script is missing.
  - **Developer:**
    1. No report → block. The JSON has `decision == "block"` and `reason` contains `06-dev-report`.
    2. `dev-report-ok.md` copied in after `state.sh stage develop` → allow (empty stdout, exit 0).
    3. The real `templates/artefacts/dev-report.md` copied in → block (the placeholder STATUS).
    4. `dev-report-no-commands.md` (STATUS ok, header-only table) → block naming `Commands run`. A row with only `| <lint command> | pass |` → block.
    5. `dev-report-blocked.md` (STATUS blocked, no rows) → allow (A14).
    6. Stale: the ok report with `touch -t 202001010000` → block naming `earlier cycle`. The same report touched now → allow.
    7. Newest wins: an old invalid `06-dev-report.md` (`touch -t` in the past) plus a fresh valid `06-dev-report-WP2.md` → allow. Swap them → block.
    8. Return-block variants (generated in-test from the ok report):
       - CRLF line endings → allow;
       - trailing blank lines → allow;
       - text after the block → block;
       - `STATUS: done` → block;
       - empty `ARTEFACTS:` → block;
       - lines out of order → block.
    9. A linked worktree: payload `cwd` = `wt` (sub-developer) and `CLAUDE_PROJECT_DIR` unset → the main project's run is used (an ok report → allow; none → block).
  - **QA:**
    10. Stage `plan` and stage `qa_test_plan`, without `04-qa-test-plan.md` → block. With `qa-test-plan-ok.md` → allow. With the real template → block.
    11. Stage `qa` with `fix_cycle` 0: `08-qa-report-1.md` ok → allow. After `bump fix_cycle`, the same file present but `08-qa-report-2.md` missing → block naming `08-qa-report-2.md`.
    12. Stage `develop` → allow, with a stderr warning naming the stage.
  - **Scope and fail-open:**
    13. `agent_type` of `general-purpose`, `developer` (bare) or `other:developer` → allow silently, even with no report.
    14. `stop_hook_active: true` with no report → allow, with the stderr warning (A8).
    15. No `current` → allow with a warning. `current` set but `state.json` deleted → allow with a warning. `state.json` corrupt (`echo x >`) → allow with a warning.
    16. Timing: the developer ok path (every check runs) is under 1000 ms, and so is the QA ok path.
- **verify:** `bats tests/scripts/hooks-gate-subagent.bats` green. Conventions and `run-script-tests.sh` green.
- **commit:** `feat(hooks): add SubagentStop gate for developer and qa-engineer`

---

### D5 — Session-start hint `scripts/hooks/session-start.sh`

- **files:** `scripts/hooks/session-start.sh` (new, `+x`), `tests/scripts/hooks-session-start.bats` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. DESIGN §11 (exact wording). Spec AC-21 and A16. Output shape from platform facts 6.
- **RISKY:** NOT RISKY. It only adds context, and every failure path exits 0 with no output.
- **AC verified:** AC-21, AC-22 (timing)
- **implementation notes:**
  - `hook_init "$@"`. No `.aew/runs/current` → exit 0 **silently** (the normal case). `rd=$(run_dir) || exit 0` (`run_dir`'s own `error:` line is the message; the trap sees status 0). No `state.json` → `warn`, exit 0.
  - One jq call reads `[.run_id, .stage, .status]|@tsv`, captured with `x=$(jq …) || { warn …; exit 0; }` before any `read <<<"$x"`. Status `done` → exit 0 with no output.
  - Otherwise, one `jq -n --arg c "Active aew run $id at stage $stage ($status). Use /aew:resume."` produces `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$c}}`.
  - It doesn't read `source`, because it fires for every source (A5).
- **test scenarios (`hooks-session-start.bats`).** RED first: the script is missing.
  1. `seed_run 12`, then `state.sh stage develop` → stdout JSON has `hookEventName == "SessionStart"` and `additionalContext == "Active aew run 12 at stage develop (running). Use /aew:resume."`.
  2. `state.sh status blocked` → `(blocked)`. `failed` → still shown (A16).
  3. `state.sh status done` → empty stdout, exit 0.
  4. No current run → empty stdout **and** empty stderr. `current` pointing at a missing `state.json` → empty stdout, warning on stderr.
  5. It works for every `source` value (`startup`, `resume`, `clear`, `compact`, `fork`).
  6. An `m-3` run id shows as `m-3`.
  7. Timing is under 1000 ms.
- **verify:** `bats tests/scripts/hooks-session-start.bats` green. Conventions and `run-script-tests.sh` green.
- **commit:** `feat(hooks): add SessionStart active-run hint`

---

### D6 — Wire `hooks/hooks.json`, plus the cross-hook fail-open suite

- **files:** `hooks/hooks.json` (new), `tests/scripts/hooks-json.bats` (new)
- **depends_on:** [D2, D3, D4, D5]
- **pattern:** Platform facts 1, 2, 3 and 8 (shape, matcher semantics, anchored regex, explicit timeouts). DESIGN §3 plugin layout (`hooks/hooks.json` at the plugin root). Spec AC-22 and AC-23.
- **RISKY:** RISKY. This is the step that makes the hooks fire in every session.
- **AC verified:** AC-22 (every hook: fail open, `stop_hook_active`, silent outside aew), AC-23
- **implementation notes:** The exact content:
  ```json
  {
    "description": "aew safety guards (Bash, Edit/Write), subagent artefact gates and the active-run hint",
    "hooks": {
      "PreToolUse": [
        { "matcher": "Bash", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/guard-bash.sh\"", "timeout": 5 }] },
        { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/guard-edit.sh\"", "timeout": 5 }] }
      ],
      "SubagentStop": [
        { "matcher": "^aew:(developer|qa-engineer)$", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/gate-subagent.sh\"", "timeout": 5 }] }
      ],
      "SessionStart": [
        { "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh\"", "timeout": 5 }] }
      ]
    }
  }
  ```
  - `Bash` and `Edit|Write` use only exact-match characters. The SubagentStop matcher contains `:`, so it's a regex and is anchored.
  - A 5 s timeout replaces the 600 s default and leaves headroom over the < 1 s budget for a cold first `git`/`jq`.
  - SessionStart has no matcher, so it fires for every `source`.
- **test scenarios (`hooks-json.bats`).** RED first: `hooks/hooks.json` is missing.
  1. Valid JSON. The event keys are exactly `PreToolUse`, `SubagentStop` and `SessionStart`. Every hook has `type: "command"`, an integer `timeout` from 1 to 10, and a `command` that starts with `"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/`.
  2. Each `command`, with `${CLAUDE_PLUGIN_ROOT}` replaced by `$REPO_ROOT` and the quotes removed, is an existing executable. Every `scripts/hooks/*.sh` is referenced exactly once, so there are no orphans and nothing missing.
  3. Matchers:
     - `Bash` and `Edit|Write` match `^[A-Za-z0-9_|, -]+$` (exact semantics).
     - The SubagentStop matcher, under `grep -Eq`, matches `aew:developer` and `aew:qa-engineer`.
     - It doesn't match `developer`, `qa-engineer`, `aew:developer-x`, `xaew:developer` or `other:qa-engineer`.
  4. **Fail-open matrix, looping over every `scripts/hooks/*.sh`** (glob, non-empty) with its event's payload fixture:
     - jq missing (the `nojq` PATH from D1) → exit 0, empty stdout;
     - not a git repo → exit 0, empty stdout, empty stderr;
     - git repo without `.aew/` → exit 0, empty stdout and stderr, even for the dangerous inputs (`git push -f`, `.env`, and no dev report);
     - `.aew/` without config → exit 0, empty stdout, warning on stderr;
     - empty or invalid payload → exit 0, empty stdout, warning;
     - `stop_hook_active: true` → exit 0, empty stdout.
     This also proves the guards are inert outside aew projects (A9).
  5. No hook ever exits 2 across the matrix and the per-hook suites. Each case asserts `status -eq 0`.
  6. `claude plugin validate "$REPO_ROOT"`, skipped when `claude` is not on `PATH`: exit 0, and the output contains no line matching `hooks:` (unknown events and malformed entries surface there only as warnings).
- **verify:** `bats tests/scripts/hooks-json.bats` green. `claude plugin validate .` run manually, with the output recorded in the report. Full `tests/run-script-tests.sh` green.
- **commit:** `feat(hooks): wire hooks.json with anchored matchers and explicit timeouts`

---

### D7 — DESIGN §3/§11 and state-machine corrections

- **files:** `docs/DESIGN.md` (§3 "Blocking hooks" bullet and §11 only), `skills/run-protocol/references/state-machine.md` (the SubagentStop failure-path row only)
- **depends_on:** [D6]
- **pattern:** The platform-facts file, the "Corrections" table above, and DESIGN's own prose style (British English, bullet lists, no new sections). Spec AC-29 (the DESIGN and state-machine part; E owns the CHANGELOG and the final report).
- **RISKY:** NOT RISKY (docs only)
- **AC verified:** AC-23 (documented verification), AC-29 (partial)
- **changes:**
  - **§3 "Blocking hooks" bullet.** Replace it with these sub-bullets:
    - `PreToolUse` denies with `hookSpecificOutput.permissionDecision: "deny"` and `permissionDecisionReason` on exit 0 (top-level `decision`/`reason` are deprecated for `PreToolUse`).
    - `Stop`/`SubagentStop` block with `{"decision":"block","reason":…}` on exit 0. Exit 2 also blocks, but aew never uses it.
    - `stop_hook_active` is true when a stop hook already continued the agent.
    - The documented cap: after 8 consecutive stop-hook continuations, the next block is overridden. The count resets on each tool call, and `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it. It's stated for `Stop`, and the same protections apply to `SubagentStop`.
  - **§3, new bullet "Hook matching and environment":**
    - `SubagentStop` matchers match `agent_type`, which for plugin agents is `aew:<agent>`.
    - A matcher of only letters, digits, `_`, `-`, space, `,` and `|` is an exact list. Anything else is an unanchored regex, so anchor it (`^aew:developer$`).
    - The default timeout is 600 s, so set explicit timeouts.
    - Exit-0 stderr is never shown to Claude (debug log only).
    - `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` are exported. The hook's cwd is not documented, so use the payload `cwd` or `CLAUDE_PROJECT_DIR`.
    - `SessionStart` adds context through `hookSpecificOutput.additionalContext`.
  - **§11:**
    - Name the matchers (`Bash`; `Edit|Write`; one `SubagentStop` entry with `^aew:(developer|qa-engineer)$`; `SessionStart` with no matcher) and the 5 s timeouts.
    - Gates: one corrective block. When `stop_hook_active` is true, the gate allows the stop and the orchestrator's normal return check decides (spec A8).
    - Developer gate: the newest `06-dev-report*.md`, not older than `state.json`; commands and results required when `STATUS: ok`.
    - QA gate: the stage-to-artefact mapping.
    - "All hooks": inert and silent outside an aew project (no `.aew/`). They warn and stay inert when `.aew/` exists without `config.json`. They fail open (exit 0, stderr warning, visible in the debug log) when jq or the state is missing, or on any unexpected error.
    - Add a one-line note that the Bash guard is a heuristic (no `bash -c`/`eval`), with its limits in the script header.
  - **state-machine.md, the SubagentStop failure row**, reworded to:

    > The gate blocks once, and its reason becomes the agent's next instruction. If the agent stops again (`stop_hook_active` true), the gate allows the stop. The return is then checked as usual: a missing or invalid artefact or return block counts as `failed` (retry once, then `blocked`).

    Delete the "eight consecutive blocks" wording from that row.
- **test scenarios:**
  1. `grep` checks:
     - DESIGN §3 contains `permissionDecision` and `aew:<agent>`;
     - §11 contains `^aew:(developer|qa-engineer)$` and `stop_hook_active`;
     - `state-machine.md` no longer contains `eight consecutive blocks`.
     This is a manual verification step recorded in the report (docs aren't bats-tested).
  2. Diff review: only §3's hook bullets, §11 and that single table row change.
- **verify:** `git diff --stat` shows only the two files. British English throughout.
- **commit:** `docs: align DESIGN §3/§11 and the gate failure path with the verified hook docs`

## Phase exit check

- `tests/run-script-tests.sh` exits 0, including shellcheck over `hooks.sh` and the four hooks, A's convention loops over them, and the six `hooks-*.bats` files.
- Every hook measures under 1000 ms in its timing test. No test observes exit 2.
- `claude plugin validate .` exits 0 with no `hooks:` finding.
- Files added: `hooks/hooks.json`, `scripts/lib/hooks.sh`, `scripts/hooks/{guard-bash,guard-edit,gate-subagent,session-start}.sh`, `tests/scripts/hooks-{lib,guard-bash,guard-edit,gate-subagent,session-start,json}.bats`, and `tests/scripts/fixtures/hooks/*`. Edited: `docs/DESIGN.md` (§3 and §11) and `skills/run-protocol/references/state-machine.md` (one row). No A-owned file is touched.

## Requests to Phase A (additive only; none blocking)

- None needed. D relies on the contract as revised. Two points D depends on, which A's tests should keep true:
  - convention 1's "sources `lib/common.sh`" check must accept `../lib/common.sh`, as a substring match;
  - `elapsed_ms` discards stdin, so D times hooks through `bash -c '"$0" < "$1"' <hook> <payload-file>`.

## Notes for `dw-plan` / closing (E)

- CHANGELOG (E) should list:
  - the hooks;
  - the A4 narrowing to `aew:`-prefixed agent types;
  - the `Edit|Write`-only matcher;
  - inert outside aew projects;
  - one corrective block per gate stop.
- The project map's Gotchas (E) should get:
  - bash 3.2 `-nt` is whole-second;
  - the IFS-tab collapse;
  - `claude plugin validate` only warns on unknown hook events;
  - plugin agent types are `aew:<agent>`.
- `CLAUDE.md` lines 70–71 (the hooks summary) are still accurate; no edit is needed.
- Contract for prompt 05 (orchestrator): write state (`state.sh stage develop` or `bump fix_cycle`) **before** each developer dispatch, or the developer gate rejects a reused report as stale. Also, don't write `state.json` while a developer or sub-developer is still running: a write after the report makes that report look stale (whole-second `-nt`).
- Seven commits are planned for D. The prompt asks for one conventional commit, so raise squashing at human review (architect constraint 4).

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:51:00Z (plan-review, full depth)
- Plan format: FULL
- Mechanical fixes applied at review: the facts on the bash 3.2 EXIT trap with `$?`=0, here-string capture and glob semantics; the empty-array and capture rules; D1 test 7's warn prefix; the D2 parser (line continuations, empty segments and tokens, the `&` separator, redirection globs, the short-option cluster definition, the nearest existing ancestor, the conservative branch-switch rule, documented limits); 11 new table rows (71 → 82); D4/D5 state-read capture and the `run_dir` wording; the prompt-05 contract note.
- Plan dependency graph: valid. Wave count: 4 (D1 → {D2, D3, D4, D5} → D6 → D7). Max wave width: 4 tasks in parallel. No file overlap inside wave 2.
- Risk lines crossed: safety-guards (D2, D3, D4, D6), which the epic already flags; the CTO risk gate applies per the phase's `depth: full`.
- Plan content hash (SHA-256): c95048b9b8b01b16c0fb8a81dff4d9e1f4d2363b90845f111557fe5c1a248b23 (hash of the plan before this section was appended)

---

## Approval

- Senior architect: APPROVED WITH NOTES per phase (A, B, C, D — trailers in each phase section above); C micro-revision on 2026-10-24T10:39:12Z
- Plan format: FULL (A, B, D) · LEAN (C, Z1) — EPIC plan-of-phases
- Simplicity-challenge: SIMPLER-PATH, 4 cuts adopted
- CTO: APPROVED WITH CONDITIONS on 2026-10-24T10:55:40Z, mode: risk-gate (B, D) + routine-signoff (A, C, Z1)
- Conditions: B-1, B-2, B-3, B-4, D-1, D-2, D-3, Z1-1 (see "CTO conditions" section)
- Phase graph: A → {B, C, D} → Z1
- Plan content hash (SHA-256): e5df3abdf7f39753c17a4ca827b3355f494f5b5bee4610e55adfdd479de36344 (hash of the plan before this section was appended)
- Human (developer): APPROVED on 2026-10-24T11:23:28Z
- Commit model (developer): per-task commits on the feature branch; squash to one conventional commit at merge
- Plan content hash at approval: e09540a3cee10671ab2b61bb61b6cf3dd525ebeb475a53b5ab80e5eb27b9c7f3
