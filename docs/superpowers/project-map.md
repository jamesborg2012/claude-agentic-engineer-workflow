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

- 2026-10-24 standards/planning agents brainstorm (prompt 03): analogs are `scripts/state.sh` (script pattern), `run-protocol` (internal skill frontmatter), the artefact templates (agent outputs), and `gate-subagent.sh` `valid_return_block` (return-block rule for smoke checks). Cross-prompt contracts proposed for prompt 05: agent dispatch fields (`run_dir`; spec-analyser `spec_version`/`answers`; brief-compiler `mode`; senior-engineer `mode`/`n`/`base`), the standards fingerprint header `<!-- aew:standards fingerprint="…" generated="…" -->`, and `detect-stack.sh` output `{profile,path,version,evidence}`, from which the orchestrator drops `evidence` before writing config `stacks` (`additionalProperties:false`). Spec: `docs/superpowers/specs/2026-10-24-standards-and-planning-agents.md`.

- 2026-10-24 build agents brainstorm (prompt 04): analogs are `agents/senior-engineer.md` (prompt structure), `run-protocol` (skill frontmatter), the dev/QA/doc templates and `gate-subagent.sh` (the developer gate already fits package mode because each sub-developer writes its own `06-dev-report-WP<n>.md`). Key decisions: fan-out uses `git worktree add` from the feature HEAD under the run dir, with no `isolation` (built-in isolation branches from the default branch) and cherry-pick integration; QA phase B `failed` = "tests failed, report complete" (a run-protocol exception to the retry rule); `ui.axe_standard` expands to cumulative axe tags (`wcag22aa` alone misses `button-name`); a pinned `@playwright/mcp@0.0.83` is bundled instead of the official unpinned plugin. Proposed dispatch fields for prompt 05: developer `mode: full|package|fix` (+ `n`, `fix_from`; package `wp`, `worktree`, `branch`), qa-engineer `phase: A|B` (+ `n`, `triage`), doc-writer `run_dir`. Spec: `docs/superpowers/specs/2026-10-24-build-agents.md`.

- 2026-10-25 orchestrator brainstorm (prompt 05): analogs are `run-protocol`/`state-machine.md` (stage, gate and failure tables become `ship/references/routing.md` and `gates.md`), `github-ops` (every script call and the revision order), the agents' Inputs blocks (dispatch fields) and the smoke harness §2–4/§8.3 (simulations reuse `smoke_shop`, adding a bare `origin` and the stateful `gh` mock). Gaps found: standards-setter needs a brief (init needs `mode: init`), senior-engineer plan has no field for gate feedback (`notes`), `gh-pr.sh create` needs a run (init needs a run-less `open`), `gh-issue.sh fetch` needs the run dir first (init state before fetch). Review verdict and triage route already ride in the return block (SUMMARY first word; NEXT). Spec: `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md`.

### Gotchas

- Headless simulations with the `gh` shim: the Bash tool's shell is initialised from the user's profile, which can put the real `gh` ahead of the shim on `PATH`, and the static-shop fixture's `retro.repo` is the real plugin repo. Probe `command -v gh` inside the session first, point `GH_CONFIG_DIR` at an empty dir and override `retro.repo`.
- `claude plugin list --json` prints `[{id, version, installPath, …}]`; superpowers is `superpowers@claude-plugins-official` (7.0.0 on 2026-10-25).

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
- Agent frontmatter `disallowedTools: Bash(gh *)` removes ALL of Bash (docs); per-command denial needs `permissions.deny`, which a plugin cannot ship. A `PreToolUse` hook can deny instead, because subagent payloads carry `agent_type`.
- `${CLAUDE_PLUGIN_ROOT}` is substituted inline in agent and skill Markdown bodies but is NOT in the Bash tool's environment, so write literal `${CLAUDE_PLUGIN_ROOT}/…` paths in prompts.
- `memory:` on an agent auto-enables Read/Write/Edit; a missing `skills:` entry is skipped silently (debug-log warning only), so verify preloads with `--debug-file`.
- Headless runs in a project inside this repo load its `CLAUDE.md` as an ancestor and, inside the plugin tree, have `.aew/` writes denied as sensitive; the smoke harness therefore puts temp projects under `$TMPDIR/aew-smoke` and keeps `claudeMdExcludes` as a backstop.
- `tests/scripts/conventions.bats` runs every `scripts/*.sh` with no args expecting exit 1; a script whose args are all optional needs that rule narrowed.
- Agent smoke harness (`tests/agent-smoke/README.md`): temp projects live under `$TMPDIR/aew-smoke`, never inside the plugin tree (a project there gets every subagent `.aew/` Write denied as a sensitive file); `--add-dir "$REPO"` is mandatory so agents can read plugin templates; `--settings` carries `claudeMdExcludes` plus `enabledPlugins` disabling only `dev-workflow` and `figma` (disabling `frontend-design`, an `aew` dependency, stops `aew` loading); the subagent's final message is the last assistant event with non-null `parent_tool_use_id` (jq text block); return blocks are checked by loading `valid_return_block` from `gate-subagent.sh` via eval+sed. Skills preload as qualified names (`aew:run-protocol`, `superpowers:systematic-debugging`); verify with `--debug-file`.
- Agent dispatch fields for prompt 05 (from the agents' Inputs blocks; each falls back to `.aew/runs/current`): all take `run_dir`; spec-analyser adds `spec_version`, `answers` (re-run, `Q1: …`); brief-compiler adds `mode` (`pipeline|prompt`); senior-engineer adds `mode` (`plan|review|triage`, required), `n`, `base`; standards-setter takes `run_dir` only. Drop `evidence` from `detect-stack.sh` output when writing config `stacks`. Issue-body text outside aew blocks moves to the end on the first `revise` (strip or accept the duplication). Run ids in `state.sh init` are independent of issue numbers.
- Claude Code (2.1.308) refuses a subagent's Write of any file whose basename matches `/^(REPORT|SUMMARY|FINDINGS|ANALYSIS).*\.md$/i` ("Subagents should return findings as text…"); Edit and Bash are not checked. Keep agent output names off that pattern (numbered prefixes like `08-qa-report-<n>.md`, `10-summary.md` pass); the fixed DESIGN name `docs/qa/<issue>/report.md` is placed with one `cp` (qa-engineer step 13).
- Agents with Bash search with `find`/`grep` (Glob/Grep are absent by default on macOS/Linux and only returned to Bash-less subagents); `agent_type` is `aew:<agent>` in subagent `PreToolUse` payloads, which is what the guard-bash `gh` deny keys on; context7 tool names unverified (server `needs-auth` without `CONTEXT7_API_KEY`).
- Bash/shell gotchas from prompt 03: `CDPATH` breaks relative `cd` (unset or use absolute paths); unquoted glob patterns expand under `nullglob` (quote config patterns); tabs in tab-separated `read` collapse (see IFS note); zsh treats `#` in interactive one-liners as a literal and has no `declare -F` (use `type`); write smoke commands zsh-safe.
- Build-agent dispatch fields as built (prompt 05 contract): developer `run_dir`, `mode: full|package|fix`, fix `n`/`fix_from`, package `wp`/`worktree`/`branch`; qa-engineer `run_dir`, `phase: A|B`, `n`, optional `triage`; doc-writer `run_dir`. Developer commits per WP and per fix, QA commits per cycle (`test(e2e): …`); the doc-writer has no Bash, so the orchestrator commits its docs.
- QA phase B `failed` discriminator: a valid return block plus at least one triage row in `08-qa-report-<n>.md` means route by triage class; anything else is an ordinary agent failure.
- Fan-out contract: the developer runs `git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`, dispatches sub-developers in one message without `isolation`, cherry-picks in WP order, removes worktrees, reruns all checks. Sub-developers run git as `git -C <worktree> <subcommand>` (the Bash tool refuses `cd <dir> && git …`); the parent uses plain `git` in the main checkout. Nested sub-developers fire `SubagentStop` with the parent's `agent_type` and distinct `agent_id`s. Playwright MCP tool names: `tests/agent-smoke/README.md` §8.2.
- Smoke harness lessons (prompt 04): the plugin's Bash safety hook blocks any Bash command whose text contains `git push`, so write smoke scripts to files and run them; `smoke_use` does not clear `$O`, so use one output directory per step; restore snapshots with `cp -Rp`; the report-less gate probe reuses the project of the run it probes; prove screenshot overwrite by identical names plus newer mtimes and no stale files, not checksums; extract removed lines from `git diff -U0` with `grep -E '^-' | grep -v '^--- '`; Node 26 prints `ℹ pass N`. `@playwright/mcp` writes `.playwright-mcp/` into the session cwd (gitignored by `ui-qa` setup). Prompt-04 smoke spend: $7.52 of the $60 stop.
- Open item for prompt 05 (permissions, CTO-3a): scoped rules like `Bash(git -C * status *)` are not safe, because the first `*` also matches `<dir> -c core.fsmonitor=<cmd>` (and `-c core.hooksPath=` under `commit`, `--output=<path>` under `diff`), so an allowed rule can run code or write files. The permission proposal must deny or anchor `-c`, `--config-env`, `--exec-path`, `--git-dir` and `--output` for agent git commands (or route git through a script); the smoke harness's broad rules (`sh -c *`, `cp *`, `npx *`, `cd *`) are harness-only too.
- Open item for prompt 05 (orchestrator, CTO-3b): the developer gate still takes the newest `06-dev-report*.md` fresher than `state.json` (A29's gate-on-the-ARTEFACTS-report fallback was not needed in run 961, so it is unimplemented). In parallel fan-out that can wrongly allow (a parent or sub-developer passing on a sibling's report) or wrongly block (a sibling's half-written report); the orchestrator must check each named per-WP report itself.
- Other open items from prompt 04 (details in `tests/agent-smoke/README.md` §8.4 notes): attribution policy (Claude Code's co-author trailer vs the developer's "no trailer" rule); a nested `tests/e2e/` package (PHP/.NET) has no allowed run form under QA's no-`cd` rule; long installs and e2e runs need the Bash tool's `timeout` above 120 s; the curator under-prunes kept Commands lines and its date rule is too broad (would drop a dated changelog); the context7 wildcard `mcp__plugin_context7_context7__*` is unverified; the QA gate's plan stage, a genuine gate recovery, non-`impl_bug` triage routing, the failing-last-cycle path and `frontend-design` are unexercised live (prompt 07); dev fix mode and the QA re-run share the app port, so keep them serial; the plan text still shows the old `nohup … &` start form and DD-13's "no `git -C`" (superseded by `ui-qa` §3 and `agents/developer.md`); the spec's AC-17/AC-20 text predates CTO cuts 1 and 2; no LICENSE or icon (prompt 07).
