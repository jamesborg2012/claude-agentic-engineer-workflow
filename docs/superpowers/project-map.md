# Project map — claude-agentic-engineer-workflow

_Auto-generated structural index (`lib/project-map.sh`). Agents read this FIRST to
locate patterns instead of re-globbing the project. Regenerate when the structure
changes meaningfully: `${CLAUDE_PLUGIN_ROOT}/lib/project-map.sh .`_

- **Stack:** none
- **Generated against:** git HEAD `55650b4`

## Key directories

| Area | Path | Count | Examples |
|---|---|---|---|

## Key dependencies

- (no composer/package manifests found, or jq unavailable)

## Key directories (hand-written — the generator does not recognise a plugin repo)

| Area | Path | Notes |
|---|---|---|
| Source of truth | `docs/DESIGN.md` | Wins over any build prompt; flag conflicts |
| Build prompts | `docs/build-prompts/0N-*.md` | 01 scaffold (done) → 07 e2e; each builds on the last |
| Manifests | `.claude-plugin/plugin.json`, `marketplace.json` | plugin `aew`, marketplace `jamesborg-plugins` |
| Internal skills | `skills/<name>/SKILL.md` (+ `references/`) | `run-protocol`, `github-ops`; `user-invocable: false` frontmatter |
| Schemas | `templates/config.schema.json`, `templates/state.schema.json` | JSON Schema draft 2020-12 |
| Artefact templates | `templates/artefacts/*.md` | one per run artefact; header HTML comment = writer/reader |
| Scripts (prompt 02+) | `scripts/`, `scripts/lib/`, `scripts/hooks/` | bash, shellcheck-clean, `--help` |
| Tests (prompt 02+) | `tests/scripts/*.bats`, `tests/run-script-tests.sh` | `tests/tmp/` is gitignored scratch |

## Project knowledge (accumulating — NOT regenerated; agents append here)

<!-- BRIEF-STATUS: PRIMED 2026-10-24 -->

This section is the project's memory. Agents read it FIRST for baseline
orientation and append to it after each feature, so later work reuses it instead
of re-exploring. The structural index above is regenerable; this is not — it is
only ever appended to / corrected.

### Key contracts & canonical patterns

- **State file** — `templates/state.schema.json`: object, `additionalProperties:false`, all 16 fields required: `run_id` (string `^([1-9][0-9]*|m-[1-9][0-9]*)$`), `issues` (int[] ≥1, unique), `title`, `mode` (`single|bulk|sequential|sequential-child`), `auto` (bool), `stage` (`$defs.stage.enum`: spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr), `status` (`$defs.status.enum`: running, awaiting_input, awaiting_plan_approval, blocked, done, failed), `branch` (string|null), `base_branch` (string), `pr` (int|null), `spec_revision` (int ≥1, 1 = author original), `fix_cycle`/`review_cycle` (int ≥0), `started_at`/`updated_at` (ISO 8601 UTC `date-time`), `history` ([{stage, status, at, note?}], oldest first, mirrored one line each in `log.md`). Written ONLY by `scripts/state.sh`. Example: `templates/state.example.json`.
- **Config** — `.aew/config.json` in target project, schema `templates/config.schema.json`. Required: `project`, `default_branch` (default `main`), `stacks`, `commands`, `app`, `retro` (`retro.repo` required, no default; `retro.label` default `retro`). Defaults live in TWO places in the schema: leaf `properties.<a>.properties.<b>.default` AND object-level `properties.<a>.default` — a default-fallback reader must check both. Key defaults: `git.branch_pattern` `feat/{issue}-{slug}`, `git.milestone_branch_pattern` `feat/m{milestone}-{slug}`, `limits` 3/2/4, `gates.plan_approval` true.
- **Run dir** — `<project>/.aew/runs/<run-id>/` (gitignored), run id = issue number or `m-<milestone>`; `.aew/runs/current` holds the active id (hooks read it). Fixed artefact names: see `skills/run-protocol/SKILL.md` table. Cycle files: `07-review-<review_cycle+1>.md`, `08-qa-report-<fix_cycle+1>.md`, `09-triage-<same n>.md`; dev reports `06-dev-report.md` / `06-dev-report-WP<n>.md`; QA phase A `04-qa-test-plan.md`.
- **Return contract** — every agent's final message AND primary artefact end with exactly four lines: `STATUS: ok|needs_input|blocked|failed`, `ARTEFACTS: <paths>`, `SUMMARY: <≤150 words>`, `NEXT: <…>` (DESIGN §7.5; templates end with the placeholder form `STATUS: ok | needs_input | blocked | failed`, which must NOT count as valid).
- **Labels** — stage labels (exactly one): `aew:analysing`, `aew:awaiting-input`, `aew:planning`, `aew:awaiting-approval`, `aew:building`, `aew:testing`, `aew:documenting`, `aew:ready-for-review`, `aew:blocked`; flags `aew:spec-revised`, `aew:manual-test-required`. Stage/status→label mapping table: `skills/run-protocol/SKILL.md` "Labels". Set only via `gh-labels.sh`.
- **GitHub I/O** — agents never call `gh`; only the orchestrator, only via `scripts/gh-*.sh` and `git-branch.sh push` (DESIGN §2.4).
- **Internal skill frontmatter** — `name`, `description`, `user-invocable: false` (see `skills/run-protocol/SKILL.md`).
- **Schema validation command** — `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s <schema> -d <file>` (CLAUDE.md).

- **Scripts (prompt 02)** — `scripts/lib/common.sh` (shared: run-dir and main-worktree-root resolution via `git rev-parse --path-format=absolute --git-common-dir`, config reader with schema defaults, die/usage helpers), `scripts/lib/hooks.sh` (hook preamble: sources common.sh, EXIT-trap fail-open, inert without `.aew/config.json`), `scripts/lib/issue-body.jq` (marker-block transform). Each script prints its contract via `--help`; the `github-ops` skill lists them and their stdout.
- **Test harness** — `tests/run-script-tests.sh` runs bats plus shellcheck (PATH or `npx --yes shellcheck`). The `gh` shim `tests/scripts/helpers/bin/gh` is put first on PATH by `tests/scripts/helpers/common.bash`, so no test reaches the real gh; its state (call log, issue bodies and labels) lives in `$GH_MOCK_DIR` under `$BATS_TEST_TMPDIR`. Helpers: `gh_mock_issue`, `gh_mock_respond <route> <body|->` (canned reply; `-` reads stdin), `gh_calls`, `assert_gh_called`, `gh_call_count`, `gh_captured_file`, `setup_project`, `seed_run`, `run_hook`, `elapsed_ms`. `tests/tmp/` is gitignored scratch space (not used by the suite).
- **Issue-body format** — marker-delimited aew blocks: current spec on top, earlier versions newest-first in collapsed history blocks (v1 = author original, byte for byte), optional manual-tests block. Author text outside aew blocks moves to the end on first rewrite, stable after. Malformed markers, marker lines in content, invalid UTF-8 and bodies over 65,536 chars are refused, never repaired. `revise N` refuses same-version-different-content, except CRLF-only difference (no-op).
- **Hooks** — `hooks/hooks.json` uses anchored matchers, explicit timeouts, `Edit|Write` only; gate matches `aew:developer` / `aew:qa-engineer`; one corrective block per stop. Rollback: disable the plugin or delete `hooks/hooks.json`.

### Per-feature learnings

- 2026-10-24 scripts/hooks brainstorm (prompt 02): greenfield — no in-repo script analog; contracts above are the inputs. Spec: `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md`.
- 2026-10-24 scripts/hooks built (prompt 02): new scripts follow `scripts/state.sh` (Usage header = `--help`, `lib_main`, `die`) and test with `tests/scripts/helpers/common.bash` + the `gh` shim; new hooks call `hook_init "$@"` from `scripts/lib/hooks.sh` and add a row to `tests/scripts/hooks-json.bats`'s fail-open matrix automatically (it globs `scripts/hooks/*.sh`). Reviews found most defects in bash 3.2 strict-mode edges and guard bypasses — table-driven tests (`fixtures/hooks/bash-cases.tsv`) were the cheapest way to pin them.

### Gotchas

- Dev machine `bash` is macOS `/bin/bash` 3.2.57 (the only bash on PATH): no associative arrays, `mapfile`, `${v,,}`, `EPOCHREALTIME`, `|&`. Scripts must stay 3.2-compatible.
- `shellcheck` is not installed globally; bats-core 1.14 is (`/opt/homebrew/bin/bats`); jq 1.7.1; gh 2.103.
- gh ≥ 2.103 exposes `blockedBy`, `blocking`, `parent`, `subIssues`, `closedByPullRequestsReferences` as `--json` fields on `gh issue view|list`; `gh issue list --milestone` accepts a number or title.
- Plugin hooks fire in EVERY project where the plugin is enabled, so hooks must be cheap and inert outside an aew project.
- In zsh, `echo =====` fails (`=word` expansion) — quote separators in shell one-liners.
- bash 3.2: `set -e` does not apply inside `$(...)` assignments or `if`/`&&` conditions; check status explicitly. Empty arrays expand as unbound under `set -u` (use `${a[@]+"${a[@]}"}`).
- `-nt` file freshness is whole-second on macOS, so gates compare at that resolution; write state before dispatching a developer.
- `IFS=$'\t' read` collapses a leading empty field; use a non-whitespace delimiter or a sentinel.
- macOS `/var` is a symlink to `/private/var`; compare resolved paths, and do not rely on `realpath` for paths that do not exist.
- `claude plugin validate` only warns on unknown hook events; it will not catch a mistyped one. Plugin agent types are `aew:<agent>`. `grep -P` is unavailable on macOS.
- jq 1.7.1: `jq -Rs` corrupts multi-byte characters at 4096-byte read boundaries; use `--rawfile`.
- bats: a bare `! cmd` that is not the last line of a test never fails it; use the refute helpers.
- bats helper `elapsed_ms` discards the command's exit status and stdin; time with `bash -c '"$0" < "$1"'` and assert the real run separately.
