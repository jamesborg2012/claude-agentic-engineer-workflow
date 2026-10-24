# Brainstorm — Scripts, GitHub I/O and hooks (build prompt 02)

- **Issue:** no issue (build prompt `docs/build-prompts/02-scripts-and-hooks.md`)
- **Date:** 2026-10-24

## Problem

The aew plugin has a scaffold (manifests, schemas, templates, `run-protocol`) but no deterministic layer. The orchestrator (prompt 05), milestone mode (prompt 06) and the agents (prompts 03–04) all depend on boring, predictable, well-tested shell scripts for run state, git and *all* GitHub I/O, plus the safety and gate hooks from DESIGN §11. This work builds that layer.

## Acceptance criteria

Every acceptance criterion from the prompt is kept (marked **[P]**); the rest turn the prompt's deliverables into testable criteria.

**Shared library and state**

1. **AC-1** `scripts/lib/common.sh` provides: strict mode (`set -euo pipefail`); `info`/`warn`/`die` logging to stderr; repo-root detection; `require_cmd <cmd>…` (dies naming the missing command); `config_get <dotted.path>`, which reads `.aew/config.json` with jq and falls back to the default in `templates/config.schema.json` (checking both the leaf `default` and the parent object's `default`), dying with a clear message when there is neither a value nor a default; and `run_dir [run-id]`, which resolves `<main-worktree-root>/.aew/runs/<id>` (defaulting to `.aew/runs/current`). Each function has a bats test.
2. **AC-2** `state.sh init <run-id> --issues <n,…> --mode <mode> [--auto] [--title …]` creates `state.json` (stage `spec_analysis`, status `running`, `branch` null, `base_branch` from `config_get default_branch`, `pr` null, `spec_revision` 1, both cycles 0, `started_at` = `updated_at`, one history entry), writes the first `log.md` line, and sets `.aew/runs/current`. It refuses (non-zero, clear message, nothing written) when the run already exists, or when the run id, issue list or mode is invalid.
3. **AC-3** `state.sh` `get [field]`, `stage <stage> [--note …]`, `status <status> [--note …]`, `bump fix_cycle|review_cycle`, `set <field> <value>` and `current [set <run-id>|clear]` work as specified. Every `stage`/`status` call appends exactly one `history` entry and one `log.md` line. Every write updates `updated_at` and is atomic (temp file + `mv`). Invalid input (an unknown stage, status, counter or field, or a wrong value type) exits non-zero and leaves `state.json` byte-identical.
4. **AC-4** After every `state.sh` subcommand in the test suite, `state.json` validates against `templates/state.schema.json` (`npx ajv-cli validate --spec=draft2020`, the command documented in `CLAUDE.md`). The stage, status and mode enums are read from the schema at runtime, not duplicated in the script.

**GitHub I/O**

5. **AC-5** `gh-issue.sh fetch <n> <run-dir>` writes `issue.json` (number, title, body, state, url, author, comments, labels, milestone, assignees, `blockedBy`, `blocking`, `parent`, `subIssues`, `closedByPullRequestsReferences`, and a `referenced_issues` list parsed from `#n` references in the body and comments) and a readable `00-issue-original.md` (title, metadata, body verbatim, comments in order, linked and referenced issues).
6. **AC-6 [P]** Running `gh-issue.sh revise` twice with the same version produces an identical body.
7. **AC-7 [P]** A v3 revision preserves v1 and v2, collapsed in `<details>`. No author content is ever lost. Tested with a v1 body containing Markdown, HTML comments, its own `<details>` block, a code fence and CRLF line endings: the v1 text is recoverable byte for byte from the v3 body.
8. **AC-8** `revise` writes the marker `<!-- aew:spec vN -->` at the top. It refuses `N < 2`, a version gap (`N > current + 1`) and a regression (`N < current`). It preserves an existing manual-tests block and any content found outside aew blocks. It refuses, without editing, a body that would exceed GitHub's 65,536-character limit.
9. **AC-9** `gh-issue.sh comment <n> <file>` posts the file as a comment. `gh-issue.sh manual-tests <n> <file>` adds or replaces one marker-delimited "Manual testing required" block. It is idempotent, and leaves the spec and history blocks and all author content untouched.
10. **AC-10** `gh-labels.sh ensure` creates or updates all 11 DESIGN §7.4 labels with fixed colours and descriptions (`gh label create … --force`).
11. **AC-11 [P]** `gh-labels.sh stage <n> <stage>` leaves exactly one stage label in place. Tested against a stateful `gh` fake that starts with two stage labels, a flag and an unrelated label: afterwards only the target stage label, the flag and the unrelated label remain.
12. **AC-12** `gh-labels.sh flag <n> add|remove <flag>` accepts only `spec-revised` and `manual-test-required` (with or without the `aew:` prefix), and rejects anything else.
13. **AC-13** `gh-pr.sh create <run-id> <body-file> [--base <branch>] [--draft]` opens a PR from the run's branch to `--base`, or else the run's `base_branch`. It ensures the body has `Closes #n` for every issue in `state.issues` (adding missing ones and never duplicating) and prints the PR number. If a PR already exists for the branch, it updates that PR's body and prints its number instead. `update <pr> <body-file>`, `ready <pr>` and `comment <pr> <file>` wrap `gh pr edit --body-file`, `gh pr ready` and `gh pr comment --body-file`.
14. **AC-14** `gh-milestone.sh issues <milestone>` accepts a milestone number or title and prints a JSON array `[{number, title, labels: [name…], state, depends_on: [n…]}]`. `depends_on` is the sorted, de-duplicated union of "Blocked by #n" and "Depends on #n" (case-insensitive, including lists such as `#3, #4 and #5`), task-list references (`- [ ] #n` and `- [x] #n`), and GitHub's native `blockedBy`. It excludes self-references. Each pattern is covered by a fixture test.
15. **AC-15** `gh-retro.sh file <retro.md> <source-repo> <run-id>` reads `retro.repo` (required) and `retro.label` (default `retro`) from config. For each `###` item in `retro.md`, skipping template placeholders, it searches the open issues with that label. On a close title match (normalised: case, punctuation and whitespace ignored) it comments "Seen again in <repo> run <id>" plus the item body; otherwise it creates an issue with the label. Both paths are tested.
16. **AC-16** `git-branch.sh create <run-id> <slug> [--base <branch>]` builds the name from `git.branch_pattern` (or from `git.milestone_branch_pattern` for an `m-<n>` run id), validates the slug as lower-case kebab-case, refuses on a dirty tree (including untracked files) or an existing branch, creates the branch from the base (default `default_branch`) and prints the branch name. `git-branch.sh push` runs `git push -u origin <current-branch>`, and refuses on the default branch or a detached HEAD.

**Hooks**

17. **AC-17 [P]** The Bash guard (`PreToolUse`, matcher `Bash`) has a table of at least 20 cases, and all of them pass. It must include at least these:
    - **Blocked:** `git push origin main`; `git push` while on main; `git push -f`; `git push --force-with-lease`; `gh pr merge 3`; `gh repo delete`; `git reset --hard` on main; `rm -rf /`; `rm -rf ~`; `rm -rf ..`; `git clean -fdx`.
    - **Allowed:** a push of a feature branch; `rm -rf node_modules`; `rm -rf tests/tmp`; `npm test`; `git reset --hard` on a feature branch; `gh issue view 3`.

    It also covers compound commands (`cd x && git push origin main`), `git -C <dir>`, `+refspec` force pushes, `src:main` refspecs, `sudo rm -r`, and separated or reordered flags (`git clean -xdf`, `rm -r -f`).
18. **AC-18 [P]** The Edit/Write guard (`PreToolUse`, matching `Edit` and `Write`, plus `MultiEdit` or `NotebookEdit` if the docs list them as current tools) blocks `.env`, `.env.local` and `.git/config`, and allows `.env.example`. It also blocks any path with a `.git/` component and the short known-secrets list (see Assumptions).
19. **AC-19** The developer `SubagentStop` gate blocks unless the newest `06-dev-report*.md` in the current run dir exists, was modified at or after the run's `updated_at`, ends with a valid return block, and, when `STATUS: ok`, has a `## Commands run` table with at least one row whose command and result are filled in (not template placeholders).
20. **AC-20** The qa-engineer `SubagentStop` gate blocks unless the artefact for the current phase exists and ends with a valid return block. The phase comes from the state: stage `plan` or `qa_test_plan` means `04-qa-test-plan.md`; stage `qa` means `08-qa-report-<fix_cycle+1>.md`. For any other stage the gate allows the stop with a warning. A "valid return block" means the last four non-blank lines are `STATUS: <one of ok|needs_input|blocked|failed>`, `ARTEFACTS: <non-empty>`, `SUMMARY: <non-empty>` and `NEXT: <non-empty>`. The template placeholder form (`STATUS: ok | needs_input | …`) fails.
21. **AC-21** The `SessionStart` hook, when `.aew/runs/current` exists and that run's status is not `done`, returns the additional context "Active aew run <id> at stage <stage> (<status>). Use /aew:resume." Otherwise it outputs nothing and exits 0.
22. **AC-22 [P]** Every hook runs in under a second (measured in the tests) and honours `stop_hook_active`: when it is true, a gate allows the stop. Every hook fails open, exiting 0 with a stderr warning, when jq, the config or the state file is missing. No unexpected error can ever produce a blocking exit: an ERR trap forces exit 0 with a warning.
23. **AC-23** `hooks/hooks.json` uses `${CLAUDE_PLUGIN_ROOT}/scripts/hooks/…` paths and a per-hook `timeout`. Its event names, matchers, payload fields and response formats have been verified against code.claude.com/docs (see the plan's verification step). `claude plugin validate .` passes.

**Skill, quality, tests**

24. **AC-24** `skills/github-ops/SKILL.md` (`user-invocable: false`) covers, for the orchestrator: when and how to use each script, with an example invocation of each; the state-stage→label mapping (pointing to `run-protocol`); the ordering for recording a spec revision (render the comment, `revise`, `comment`, `flag add spec-revised`, `state.sh set spec_revision`); and the rule that agents never call `gh`.
25. **AC-25 [P]** Every script supports `--help` (exit 0, usage on stdout) and exits non-zero with a clear message on bad input. A test loops over every script for both.
26. **AC-26 [P]** `shellcheck` is clean on every script, hook and test helper. `tests/run-script-tests.sh` runs it.
27. **AC-27 [P]** `tests/run-script-tests.sh` runs every bats file under `tests/scripts/` and passes from a clean checkout. `gh` is mocked by a PATH shim that records its arguments and returns fixture JSON, with a small amount of state for issue bodies and labels. Hook tests feed payload JSON on stdin.
28. **AC-28** All scripts run under macOS `/bin/bash` 3.2 (the only bash on the dev machine), so no bash 4+ features are used.
29. **AC-29** Closing: `CHANGELOG.md` is updated. DESIGN §3/§11 is updated in the same commit wherever the docs differ. `skills/run-protocol/references/state-machine.md`'s SubagentStop failure-path row is reconciled with the `stop_hook_active` behaviour. The final report lists the checks run, the files changed, the deviations from DESIGN and any decisions needed. Everything lands in one conventional commit.

## Scope

- **In:** the 11 deliverables of prompt 02: `scripts/lib/common.sh`, `scripts/lib/hooks.sh` (shared hook helpers; see Assumptions), `state.sh`, `gh-issue.sh`, `gh-labels.sh`, `gh-pr.sh`, `gh-milestone.sh`, `gh-retro.sh`, `git-branch.sh`, `hooks/hooks.json`, `scripts/hooks/*.sh`, `skills/github-ops/SKILL.md`, `tests/scripts/` (bats files, the `gh` shim, fixtures) and `tests/run-script-tests.sh`. Also the CHANGELOG entry, the DESIGN §3/§11 corrections the verification finds, and the one-row state-machine reconciliation.
- **Out:**
  - `scripts/detect-stack.sh` (prompt 03).
  - The orchestrator `ship`/`resume`/`status`/`init` skills (prompt 05).
  - Milestone ordering, cycle detection and stacking logic (prompt 06). `gh-milestone.sh` only *reports* `depends_on`.
  - Rendering `spec-revision-v<N>.md` from `spec-changes.json`: the orchestrator does that (DESIGN §7.1).
  - Writing state from `gh-pr.sh` or `git-branch.sh`: they print the PR number or branch, and the orchestrator calls `state.sh set`.
  - A `--run <id>` option on `state.sh`.
  - README updates.
  - Installing shellcheck globally.
  - Any real GitHub calls in tests.

## Context manifest

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

## Assumptions

**Platform.** All of these are current-best-understanding; verify against code.claude.com/docs during implementation, as the plan's first step.

1. **Assumed:** hooks.json shape is `{"hooks": {"<Event>": [{"matcher": "<regex>", "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/<x>.sh", "timeout": <s>}]}]}}`. The event names are `PreToolUse`, `SubagentStop` and `SessionStart`. **Verify against code.claude.com/docs during implementation.**
2. **Assumed:** the `PreToolUse` stdin has `tool_name`, `tool_input.command` (Bash), `tool_input.file_path` (Edit/Write) and `cwd`. Deny with exit 0 and `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`, which beats exit 2 because the reason reaches Claude in a structured form. **Verify. Flag if wrong.**
3. **Assumed:** the `SubagentStop` stdin carries `stop_hook_active`, `agent_type` (and `agent_id`), `cwd`, and `transcript_path` / `agent_transcript_path`. Block with `{"decision":"block","reason":"…"}` (DESIGN §3). **Verify against code.claude.com/docs during implementation.**
4. **Assumed (high-leverage, flag if wrong):** it is uncertain whether the `SubagentStop` matcher compares against `agent_type`, and whether a plugin agent's type is `aew:developer` or `developer`. To stay correct either way, the gate script **filters on `agent_type` itself, accepting both `developer` and `aew:developer`** (likewise for `qa-engineer`). The matcher only narrows for speed and is set to whatever the docs confirm, or omitted if matching isn't supported. A bare `developer` from another plugin is gated only while an aew run is current, which is acceptable for solo use.
5. **Assumed:** `SessionStart` returns `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"…"}}`, with no matcher (it fires on startup, resume, clear and compact). **Verify.**
6. **Assumed:** hooks get `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` in their environment. The project root is resolved from `CLAUDE_PROJECT_DIR`, then the payload's `cwd`, then `$PWD`, each mapped to the main worktree root. Scripts outside hooks find the plugin root from `CLAUDE_PLUGIN_ROOT`, falling back to their own `BASH_SOURCE` location, so tests and manual runs work. **Verify.**
7. **Assumed:** stderr from a hook that exits 0 is not shown to the model and only appears in transcript or debug mode, so fail-open warnings are not noisy in non-aew projects. **Verify. Flag if wrong.** If it turns out to be noisy, the warning is silenced when no `.aew/` directory exists at all.

**Hook behaviour**

8. **Assumed (conflict, DESIGN wins):** DESIGN §11 says "honour `stop_hook_active`". `state-machine.md` says the agent "continues until the artefact is valid … overridden after eight consecutive blocks". We follow DESIGN: when `stop_hook_active` is true the gate allows the stop with a stderr warning, so the agent gets exactly one corrective block. The orchestrator then checks the return as usual, and a missing artefact counts as `failed`. The state-machine row is reworded to match. **Flag if wrong.**
9. **Assumed (prompt adds to DESIGN; reconciled):** DESIGN lists jq and the state file as fail-open triggers, and the prompt adds config. Every hook is **inert outside an aew project**: if `.aew/config.json` is missing, it exits 0 with a warning. This also scopes the guards to aew projects, so the plugin never blocks `git push --force-with-lease` in James's unrelated repos. Inside an aew project, the guards need only `default_branch` and never the state, and the gates and SessionStart fail open without the state. **Flag if wrong**, since the alternative is guards active in all repos with a `main` default.
10. **Assumed:** `stop_hook_active` is checked in every hook through the shared helper, as the AC asks. It only appears in Stop/SubagentStop payloads, so it has no effect on the guards or SessionStart.
11. **Assumed:** the Bash guard is a heuristic safety net, not a sandbox. It splits the command on `&&`, `||`, `;`, `|` and newlines; strips leading `VAR=…`, `sudo`, `command` and `env`; and handles `git -C <dir>`. It does not look inside `bash -c "…"`, `eval` or aliases. These limits are documented in the script header. **Flag if wrong.**
12. **Assumed:** these Bash guard rules apply.
    - **Push to the default branch** covers an explicit `main` or `*:main` refspec, `HEAD` or a bare `git push` while on main, and `--delete … main`.
    - **Force push** covers `-f`, `--force`, `--force-with-lease[=…]`, `--force-if-includes`, a short-flag cluster containing `f`, or a `+refspec`.
    - `git reset --hard` is blocked only when the current branch (from the payload `cwd`, or the `-C` directory) is the default branch.
    - `git clean` is blocked when the flags include `f`, `d` and `x` in any order or split (`-X` is allowed).
    - Any recursive `rm` (`-r`, `-R`, `--recursive`, with or without `-f`) is blocked if a target, normalised in pure bash against `cwd`, resolves to `/`, `$HOME`, the repo root, an ancestor of it, or anywhere outside the repo.
    - Targets containing unexpanded `$`, a backtick or `$(` are blocked conservatively. A trailing `/*` is resolved as its directory, so `rm -rf ./*` at the root is blocked and `rm -rf dist/*` is allowed.
    - **Flag if wrong** (false positives go in the retro "False-positive hooks" section).
13. **Assumed:** the Edit/Write guard's known-secrets list is kept short.
    - **Blocked:** a basename of `.env` or `.env.*` (except `.env.example`, `.env.sample` and `.env.template`); `*.pem`, `*.key`, `*.p12`, `*.pfx`; `id_rsa*`, `id_ed25519*`, `id_ecdsa*`; `.netrc`, `.npmrc`, `.pgpass`; `auth.json` (Composer credentials); and any `.git/` path component.
    - **Flag if wrong**, particularly `.npmrc` and `auth.json`, which some projects commit without secrets.
14. **Assumed:** the developer gate checks the **newest** `06-dev-report*.md`, so sub-developers' `-WP<n>` reports work. It also requires the report's mtime to be at or after `state.updated_at`, so a stale report from an earlier fix cycle can't pass (the orchestrator sets `stage develop` just before dispatch). When the report's STATUS is not `ok`, only the return block is required, so a `blocked` developer isn't forced to invent commands. **Flag if wrong.** Under parallel sub-developers, "newest" can pick a sibling's report. This is accepted, because the parent developer's own merge-and-rerun produces `06-dev-report.md` last.
15. **Assumed:** the QA gate maps stage `plan` or `qa_test_plan` to phase A and stage `qa` to phase B, and uses the deterministic name `08-qa-report-<fix_cycle+1>.md` rather than "the newest file".
16. **Assumed:** SessionStart follows DESIGN literally and shows the hint for every status other than `done`, including `failed`. **Flag if wrong**, since "Use /aew:resume" is arguably misleading for a terminal `failed` run.
17. **Assumed:** one gate script, `scripts/hooks/gate-subagent.sh`, dispatches on `agent_type`, instead of two near-identical scripts. The return-block validator and the fail-open, payload-reading and `stop_hook_active` helpers live in `scripts/lib/hooks.sh`. That is the one file beyond the prompt's list, justified because four hook scripts share the helpers and there is no existing analog. Hook scripts: `guard-bash.sh`, `guard-edit.sh`, `gate-subagent.sh`, `session-start.sh`.

**State and scripts**

18. **Assumed:** `state.sh stage <s>` also sets `status` to `running` (entering a stage means work restarts, as in every stage entry of `state.example.json`), and takes an optional `--note`. The prompt lists `--note` only for `status`, but the example's history has notes on stage entries. **Flag if wrong.**
19. **Assumed:** `log.md` mirrors `history` only: one line per `stage`/`status` transition, in the format `- <at> <stage> <status>[ — <note>]`. `bump` and `set` change state without a log line.
20. **Assumed:** `state.sh set` allows only `title`, `branch`, `base_branch`, `pr`, `spec_revision` and `auto`. Types are coerced from the schema (`pr`/`spec_revision` integers, `auto` boolean, the literal `null` for `branch`/`pr`). `stage`, `status`, `history`, the cycles, `run_id`, `issues` and the timestamps can only change through their dedicated subcommands.
21. **Assumed:** there is no file locking, because the orchestrator is the only writer and calls are sequential. Atomic `mv` prevents torn reads by hooks.
22. **Assumed:** `init` on an existing run refuses, and resume reuses the existing state. `init`'s default `--title` is empty, so the orchestrator passes the issue title. `--mode` is required.
23. **Assumed:** `state.sh` validates by construction (enums read from the schema, types checked in jq) rather than running ajv on every write. ajv would be too slow and needs the network. ajv runs in the tests (AC-4).
24. **Assumed:** the issue-body layout for `revise` and `manual-tests` is as follows (top to bottom).
    - The current spec, between `<!-- aew:spec vN -->` and `<!-- /aew:spec -->`.
    - The manual-tests block, between `<!-- aew:manual-tests -->` and `<!-- /aew:manual-tests -->`, if any.
    - One `<details><summary>Spec vK…</summary>` per earlier version, newest first, each wrapping `<!-- aew:spec-prev vK -->` … `<!-- /aew:spec-prev vK -->`. v1 is labelled "(original)".
    - Any content found outside aew blocks, preserved verbatim at the end. This keeps idempotency and loses nothing an author edits in later.
    - A body without a marker is v1 in its entirety.
    - Markers are matched line-anchored and tolerate a trailing `\r`.
    - **Flag if wrong.**
25. **Assumed:** `manual-tests` on a body with no aew spec marker appends the block at the end and leaves the author's body intact. An empty file is an error.
26. **Assumed:** `fetch` writes the current body verbatim, even when it already holds aew markers (resume or re-run). `referenced_issues` are same-repo `#n` and issue-URL references from the body and comments, looked up with one `gh issue view <m> --json number,title,state` each, capped at 20 with a warning.
27. **Assumed:** labels take their name with or without the `aew:` prefix (`stage 12 building`). The orchestrator maps state stage/status to the label using the `run-protocol` table. The scripts don't own that mapping.
28. **Assumed:** these are the label colours.
    - Stage labels: a blue family for active stages, amber for the awaiting labels, green for `ready-for-review` and red for `blocked`.
    - Flags: purple (`spec-revised`) and orange (`manual-test-required`).
    - The descriptions come from the run-protocol "When" column. Cosmetic.
29. **Assumed:** the PR title is `state.title` as-is, and `create` defaults to non-draft (DESIGN: "a PR ready for review"). `create` is idempotent: if `gh pr list --head <branch>` finds an open PR, it updates the body and prints that PR's number. **Flag if wrong.**
30. **Assumed:** in `gh-milestone.sh`, a task-list reference `- [ ] #n` in issue A means **A depends on n** (A tracks n as a sub-task). Native `blockedBy` is merged in. `depends_on` keeps references outside the milestone, so the orchestrator can decide. The listing uses `--state all --limit 500`. **Flag if wrong.**
31. **Assumed:** a "close title match" in `gh-retro.sh` means normalised equality: lower-case, punctuation stripped, whitespace collapsed. This avoids fuzzy false merges. The retro label is created in the retro repo if it is missing (`gh label create`, ignoring "already exists"). The script prints one line per item: `commented #n` or `created #n`. **Flag if wrong.**
32. **Assumed:** `git-branch.sh create` validates the slug (`^[a-z0-9]+(-[a-z0-9]+)*$`) and refuses rather than transforming it. The orchestrator produces the slug. `{issue}` is replaced with the run id (for a single run) and `{milestone}` with the number after `m-`. It uses `git switch -c <branch> <base>`, and fetching and updating the base is preflight's job (DESIGN §9).
33. **Assumed:** the `gh` mock is a single `tests/scripts/helpers/bin/gh` shim on `PATH`. It appends each invocation's arguments to `$GH_MOCK_LOG` and serves fixtures from `tests/scripts/fixtures/`. It keeps a small stateful store under `$BATS_TEST_TMPDIR` for issue body and labels (`issue view --json body,labels`, `issue edit --body-file/--add-label/--remove-label`), which AC-6/7/11 need, and nothing more. Test repos are temporary git repos under `$BATS_TEST_TMPDIR`.
34. **Assumed (environment, defensible default):** shellcheck runs through `shellcheck` on `PATH` if present, otherwise `npx --yes shellcheck`. The npm `shellcheck` package downloads a binary into the npx cache, which is not a global install. If neither works, `run-script-tests.sh` fails with a message suggesting `brew install shellcheck`. Schema validation in the tests uses `npx ajv-cli` as `CLAUDE.md` documents. Both need the network on first use; "clean checkout" means a clean repo, not an offline machine. **Flag if wrong.**
35. **Assumed:** bats is installed, so there is no fallback runner (the prompt's fallback is conditional). `run-script-tests.sh` exits non-zero with an install hint if `bats` is missing.
36. **Assumed:** hook timing is measured with `perl -MTime::HiRes` (available on macOS; bash 3.2 has no `EPOCHREALTIME`). The limit is under one second per invocation.
37. **Assumed:** the extra gh JSON fields (`blockedBy`, `subIssues` and so on) mean a minimum gh version. Scripts don't check the version; the github-ops skill and the CHANGELOG note "gh ≥ 2.103 tested". **Flag if wrong.**
38. **Assumed:** nothing is added to `CLAUDE.md`'s decision log in this pass, because these are not yet approved. The project facts (bash 3.2, gh fields, hooks fire everywhere) are recorded in `docs/superpowers/project-map.md`'s Gotchas instead.

## Risks

- **SubagentStop matching for namespaced plugin agents** (high). If the matcher semantics or the `agent_type` form differ from expectations, the gates either never fire or fire for every subagent. Mitigation: Assumption 4 (the script filters on both name forms itself). The plan's first task verifies this against the docs, and DESIGN §3/§11 is updated if needed.
- **Worktree run-dir resolution** (high). Sub-developers run in isolated worktrees where the gitignored `.aew/runs/` is absent. If `run_dir` used `--show-toplevel`, the developer gate would fail open silently for every sub-developer. Mitigation: resolve through `--git-common-dir`, and test it from a real `git worktree`.
- **Bash guard bypass and false positives.** A heuristic parser can be evaded (`bash -c`, `eval`, variables) and will block some legitimate commands (`rm -rf "$TMP"`). It is a safety net for agent mistakes, not an adversarial sandbox. The limits are documented, and false positives feed the retro.
- **Issue-body integrity.** This is where author content could be lost. Risks include CRLF bodies from the GitHub web editor, an author's own `<details>` or HTML comments, an author editing the body after a revision, and the 65,536-character limit after several revisions. Mitigation: line-anchored unique markers, a byte-for-byte v1 round-trip test, out-of-block content preserved, and a refusal (never truncation) over the limit.
- **Stale or ambiguous gate inputs.** A dev report from an earlier cycle, or a parallel sibling's report, can satisfy the developer gate. Mitigation: the mtime check against `updated_at` (Assumption 14), and the orchestrator still reads the return block.
- **`stop_hook_active` reading** (Assumption 8). If "honour" were meant as "keep blocking until valid", one corrective block may be too few. This is cheap to reverse: one condition in `gate-subagent.sh`.
- **Hooks are global.** Hooks run in every project with the plugin enabled. A slow or buggy hook degrades every session. Mitigation: they are inert without `.aew/config.json`, an ERR trap forces exit 0, there is a per-hook timeout in hooks.json, and timing tests enforce under one second.
- **bash 3.2.** Accidental bash 4 syntax would pass shellcheck (unless `--shell=bash` catches it) but break at runtime. Mitigation: run the suite under `/bin/bash` explicitly, which is the default here anyway.
- **Mock fidelity.** The stateful `gh` fake can drift from real `gh` behaviour, for example the output format of `pr create` (a URL), or label add/remove ordering. Mitigation: the fake is minimal, and prompt 07's sandbox e2e exercises real gh.
- **Network-dependent test tooling.** `npx ajv-cli` and `npx shellcheck` download on first run (Assumption 34).
- **Scale.** About 10 scripts, 5 hook files, 1 skill and roughly 8 bats files: this is large for one session. A phased plan is expected (see the complexity note in the hand-back).

## Open questions for human

(none — all decisions made from project context; high-leverage defaults are flagged above, particularly Assumptions 4, 8, 9, 12–14 and 24)

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:17:27Z
- Complexity: NOVEL
- Scale: EPIC
- Reason: greenfield deterministic layer with no in-repo analog, roughly 14 tasks across three independently testable subsystems (state, GitHub I/O, hooks), and two high-stakes surfaces (rewriting author-owned issue bodies; global safety hooks).
- Spec content hash (SHA-256): 12eb8c0da523e7682bcd416762186660c642292d866250ed0162df1d783fa918 (hash of the spec before this section was appended)

<spec-summary>
- Topic: scripts-github-io-and-hooks
- Issue: no issue (build prompt `docs/build-prompts/02-scripts-and-hooks.md`; DESIGN.md wins on conflict)
- Problem: the plugin has schemas, templates and run-protocol but no deterministic layer; prompts 03–06 depend on tested scripts for run state, git and all GitHub I/O, plus the DESIGN §11 safety and gate hooks.
- ACs (testable): AC-1…AC-29 above. Prompt-mandated [P]: 6, 7, 11, 17, 18, 22, 25, 26, 27. Highest stakes: AC-7 (v1 byte-for-byte round trip), AC-17 (≥20-case Bash guard table), AC-19/20 (gates), AC-22 (fail open, <1 s, stop_hook_active).
- Scope in: common.sh, hooks.sh, state.sh, gh-issue/labels/pr/milestone/retro.sh, git-branch.sh, hooks.json + 4 hook scripts, skills/github-ops, tests/scripts + run-script-tests.sh, CHANGELOG, DESIGN §3/§11 corrections, state-machine.md SubagentStop row.
- Scope out: detect-stack.sh, orchestrator skills, milestone ordering/cycles/stacking, spec-revision rendering, state writes from gh-pr/git-branch, `--run` on state.sh, README, global shellcheck install, real GitHub calls in tests.
- Context manifest (key references):
  - docs/DESIGN.md §2.4, §3, §6.1, §7.1–7.5, §8.1, §10, §11, §12 — contracts
  - templates/state.schema.json — state contract; enums read at runtime
  - templates/config.schema.json — defaults at leaf AND object level
  - skills/run-protocol/SKILL.md (+ references/state-machine.md) — file naming, labels, return contract
  - templates/artefacts/dev-report.md, qa-test-plan.md, qa-report.md — what the gates parse
  - templates/artefacts/pr-body.md, manual-tests.md, retro.md — what gh-pr/gh-issue/gh-retro consume
- Assumptions (high-stakes only, flag if wrong):
  - A4: gate filters agent_type itself, accepting `developer` and `aew:developer` (same for qa-engineer)
  - A8: stop_hook_active true → allow stop (one corrective block); state-machine.md reworded
  - A9: hooks inert when `.aew/config.json` is missing (guards protect aew projects only)
  - A12/A13: Bash guard rules and secrets list as listed
  - A14: dev gate uses the newest 06-dev-report*.md with mtime ≥ updated_at; commands table only required when STATUS ok
  - A24: issue-body block layout and markers
  - A34: shellcheck via PATH or `npx --yes shellcheck`
- Complexity: NOVEL
- Scale: EPIC
- Spec content hash: 12eb8c0da523e7682bcd416762186660c642292d866250ed0162df1d783fa918
</spec-summary>

<epic-decomposition>
- phase: A
  title: Foundation — shared library, run state, test harness
  scope: scripts/lib/common.sh, scripts/state.sh, tests/run-script-tests.sh, bats helpers, the stateful gh PATH shim, and the glob-driven --help / bad-input / shellcheck loops
  acs: [1, 2, 3, 4, 25, 26, 27, 28]
  depends_on: []
  depth: full
  risk: none (novel and foundational; every later phase builds on its contracts)
- phase: B
  title: Issue body and labels
  scope: gh-issue.sh (fetch, revise, comment, manual-tests) and gh-labels.sh (ensure, stage, flag)
  acs: [5, 6, 7, 8, 9, 10, 11, 12]
  depends_on: [A]
  depth: full
  risk: data-integrity (rewrites author-owned GitHub issue bodies; AC-7 must never lose content)
- phase: C
  title: PR, branch, milestone and retro I/O
  scope: gh-pr.sh, git-branch.sh, gh-milestone.sh, gh-retro.sh
  acs: [13, 14, 15, 16]
  depends_on: [A]
  depth: lean
  risk: none
- phase: D
  title: Hooks
  scope: verify the platform facts against the docs, then hooks/hooks.json, scripts/lib/hooks.sh, guard-bash.sh, guard-edit.sh, gate-subagent.sh, session-start.sh; DESIGN §3/§11 corrections and the state-machine.md row
  acs: [17, 18, 19, 20, 21, 22, 23]
  depends_on: [A]
  depth: full
  risk: safety-guards (hooks fire in every session; a bug either bricks sessions or silently removes protection)
- phase: E
  title: github-ops skill and closing
  scope: skills/github-ops/SKILL.md, CHANGELOG entry, final report (checks, files, deviations, decisions)
  acs: [24, 29]
  depends_on: [B, C, D]
  depth: lean
  risk: none
</epic-decomposition>

**Architect planning constraints (for dw-plan; B, C and D run in parallel):**

1. Phase A owns `scripts/lib/common.sh`, the `gh` shim, the bats helpers and `tests/run-script-tests.sh`. The `--help`, bad-input and shellcheck loops must glob `scripts/*.sh`, `scripts/lib/*.sh` and `scripts/hooks/*.sh`, so later phases never edit them. The shim's stateful store (issue body and labels) is built in A, and B, C and D add **fixture files only**. If a later phase finds it must edit an A-owned file, it declares a dependency on A's completion and keeps the edit additive. Phases must not silently co-edit those files.
2. `scripts/lib/hooks.sh`, `DESIGN.md` and `state-machine.md` belong to D only. `CHANGELOG.md` belongs to E only.
3. Do the docs verification (claude-code-guide: event names, SubagentStop matcher and agent_type form, payload and response shapes, CLAUDE_PLUGIN_ROOT and CLAUDE_PROJECT_DIR, exit-0 stderr visibility) **at the start of D's planning**, not during implementation, so the D plan is built on confirmed shapes.
4. The prompt asks for one conventional commit. If dw-implement commits per task, raise squashing at human review. Don't squash autonomously.
