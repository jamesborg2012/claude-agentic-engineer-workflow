# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `guard.allow_paths` in `.aew/config.json`: committed files with no secrets (such as `.env.test` or `.npmrc`)
  that the edit guard would otherwise refuse, as exact repo-relative paths that also match inside run worktrees.
  `.git/` is never allowed (#39, #45).
- Environment check before development: the plan's new `## Environment` section lists what develop needs from
  the machine (`- tool: <command> [<major>]`, `- service: docker`), and `scripts/check-env.sh` checks those lines
  and the plan's `Owner hand-off:` files. Its result is in the plan-approval summary, and it runs again before
  every full-mode developer dispatch, so `--auto` runs are covered; a failure goes to the `environment` gate
  (fixed, continue / continue without the check / stop). Init pre-approves the script (#44, #50).
- `review-decision` gate: a review finding that can only be fixed by a material spec change (for example an AC
  that must be rewritten) is put to James as a question in the review's new `## Questions for James`. The
  answer goes through spec re-analysis, so the revision is recorded on the issue, and the run continues from
  the brief, as after a triage gate. The gate counts as a review cycle (#40).
- PR body `## Follow-ups`: the minor and nit findings still open on the last review, so findings an approving
  review raises are no longer lost (#12, #14, #43, #55).
- Plan hardening, in senior-engineer plan mode (new step 14, tool assumptions):
  - a tool behaviour the brief flags or the plan relies on is confirmed with context7, or proved by a small test
    at the start of the work package that relies on it, and listed as an `Unverified:` risk that the plan gate
    quotes (#42).
  - a risk mitigation the code can carry (a fallback handler, a retry) goes into a work package's goal in the
    first pass instead of being left as a QA check (#19).
  - an AC met by a tool setting is checked against the installed tool version and gets a unit test of the
    setting's effect, not of its presence (#41).
  - a pinned tool or companion-package version is one the plan has confirmed, with `@latest` as the named
    fallback and the version used recorded by the developer (#47).
  - a container health check names its probe and tests what the code uses (TCP or a real query), never a socket
    or process check (#48).
  - tests of state that outlives a request use one isolation pattern the plan names, in a shared helper that
    QA's phase B specs reuse, with no test-only production code path (#15).
- Brief `## Standards overrides`: an AC whose value contradicts a standards rule (a 422 where the standard says
  400) is recorded once in the brief, carried into `03-standards.md`, and followed by the planner, developer and
  reviewer instead of the standard (#7).
- Brief `## Spec criteria map`: each spec criterion and the brief ACs it became, so a criterion split into
  several ACs still traces back; the spec snapshot's traceability table gains a Spec criterion column (#22).
- Brief `## Forbidden literals`: strings an existing repository-search test fails on, found by the brief-compiler
  (the plan can add more as guardrails). The developer, qa-engineer and doc-writer, and the CLAUDE.md curation
  rules, never write them into a committed file, replacing a one-off NEXT line and agent memory (#17, #23).
- QA's repository-search tests scope their search to the files the AC is about, never test files, and a plan whose
  work must write a guarded string narrows the guard test in a work package instead of working around it (#16).
- Plan `## Notes for QA`: what QA's phase B tests need to know about how the plan builds the ACs (supporting
  steps, so an order check is relative; seams; test data), read by QA phase B instead of a plan NEXT line the
  orchestrator never passed on (#59).
- `[needs GitHub]` tag for manual tests that need a real pull request, review or workflow run: defined in the run
  protocol, applied by QA phase A, grouped in the PR body and counted once in the final report (#60).
- `## Docs follow-ups` in the review and QA report: a doc the change made stale, as `<file>: <what to change>`,
  which the doc-writer applies (through the CLAUDE.md curation rules) instead of a NEXT line (#18).
- Every QA test, at every level, has a title starting `TC-<n>: `, and the QA report's Results table gains a Test
  column with each TC's test file, which the spec snapshot's traceability table uses (#8, #30).
- Agent prompt fixes from the retro:
  - developer: a look-alike Unicode fixture is an escape in a form the edit tooling keeps (`\u{212A}`), its test
    asserts the code point, and `grep -n '[^ -~]' <file>` must show no raw character before the report calls
    it an escape (#31).
  - standards: every generated or updated doc's testing conventions carry the same look-alike fixture rule,
    whatever the stack (#32).
  - developer fix mode: a fix that changes escaping is tested on the string the code generates (the SQL, the
    pattern), with a test that fails on the old behaviour (#49).

### Changed

- README: install from GitHub pinned to a release tag (`#aew--v<version>`), with the upgrade steps, the init
  re-run after an upgrade and the rule that every release bumps `version`; the local-folder install is now the
  route for working on aew itself.
- A review fix cycle now fixes minor findings as well as blocker and major ones, so they are not re-raised
  unchanged in the next review (#43). The review limit blocks at or above `max_review_cycles`.

### Fixed

- Developer leftover clean-up no longer deletes a blocked work package's uncommitted files: it commits them in
  the worktree, removes the worktree without `--force`, and keeps the attempt on an
  `aew/<run-id>/wp-<n>-salvage-<k>` branch named in the dev report (#46).
- aew no longer plans work its own edit guard refuses: the senior-engineer names a guarded file that
  `guard.allow_paths` lacks as an `Owner hand-off:` risk instead of giving it to a work package, and the
  plan-approval summary quotes it. The guard's deny message no longer names James; it points to
  `guard.allow_paths`. Shell writes to guarded files are recorded as a known limit of the Bash guard (#39).
- A developer blocked by its environment (a stopped service, a missing tool, a credential, a guarded file) no
  longer spends the run's one re-plan. The dev report's new `Block cause:` line tells plan blocks from
  environment blocks, and a full-mode environment block pauses at a new `environment` gate (fixed, continue /
  re-plan / stop) that never skips, even with `--auto`. A sequential work package it interrupted is left
  uncommitted and picked up by the next full-mode dispatch (#51).

## [0.1.0] - 2026-10-27

### Added

- Plugin manifest (`aew`) with dependencies on superpowers, context7 and frontend-design.
- Local marketplace `jamesborg-plugins`, allowing dependencies from `claude-plugins-official`.
- Config and state JSON Schemas, with validating examples.
- Artefact templates for every run artefact.
- Internal `run-protocol` skill: run directory layout, stages, state machine, labels, return contract and file naming.
- Scripts under `scripts/`: `state.sh`, `gh-issue.sh`, `gh-labels.sh`, `gh-pr.sh`, `git-branch.sh`, `gh-milestone.sh` and `gh-retro.sh`, with shared libraries and a bats test suite (`tests/run-script-tests.sh`).
- Hooks (`hooks/hooks.json`): a Bash guard, an Edit/Write guard, a SubagentStop gate for developer and QA artefacts, and a SessionStart hint. They are inert outside projects with `.aew/config.json`.
- Internal `github-ops` skill documenting the scripts, the spec-revision recording order, operational rules and known limitations.
- Hook behaviour: the gate allows one corrective block per stop (`stop_hook_active`); agent types are `aew:`-prefixed (`aew:developer`, `aew:qa-engineer`); the guards match `Edit|Write` only.
- Rollback for hooks: disable the plugin (or start Claude Code without `--plugin-dir .`), or delete `hooks/hooks.json`. Do not remove `.aew/config.json` as a kill switch; aew itself needs it.
- `scripts/detect-stack.sh`: stack detection (`{profile,path,version,evidence}`) and a `fingerprint` subcommand, with bats tests and detection fixtures.
- Internal `stack-standards` skill: the standards document structure and six seeds (Next.js, React, Tailwind, Laravel, WordPress, WooCommerce).
- The four planning agents: `spec-analyser`, `brief-compiler`, `standards-setter` and `senior-engineer` (plan, review and triage modes), plus issue and brief fixtures.
- Headless agent smoke harness and recorded results in `tests/agent-smoke/README.md`.
- Agents that hold Bash (`standards-setter`, `senior-engineer`) search with `find` and `grep`; `Glob` and `Grep` are not in the default tool set on macOS and Linux.
- Pinned Playwright MCP server (`.mcp.json`, `@playwright/mcp@0.0.83`) bundled for QA.
- Skills `ui-qa` (Playwright, axe and QA evidence) and `claude-md-curation`.
- Agents `developer` (full, package and fix modes; manual worktree fan-out with cherry-pick integration), `qa-engineer` (blind phase A, phase B with Playwright, axe and MCP exploration, triage) and `doc-writer`.
- Static-shop fixture with planted defects, with `run/` and `run-fanout/` run directories.
- Prompt-04 smoke harness and recorded results in `tests/agent-smoke/README.md` §8.
- Entry skills `init`, `ship`, `resume`, `status` and `prompt` (build prompt 05). `ship` is the orchestrator, with the references `preflight.md`, `dispatch.md`, `gates.md`, `routing.md`, `pr.md` and `final-report.md`; `resume` and `prompt` reuse it by Read.
- `init` discovers the stack and commands, confirms the config once and validates it, ensures labels, offers Playwright, adds the `CLAUDE.md` section, proposes anchored permission rules (portable ones for `.claude/settings.json`, plugin scripts for the gitignored `.claude/settings.local.json`), generates standards and opens its PR idempotently.
- `gh-pr.sh open` for run-less PRs: prints the PR number and reuses an open PR without a create call.
- senior-engineer plan mode takes an optional `notes` field (plan-gate change requests or the developer's `blocked` reason); standards-setter has a run-less `mode: init`.
- `tests/scripts/skills.bats`: 18 static checks of the entry skills (paths, agent names, stages and routing, citations, bad-argument messages, frontmatter YAML, pre-approvable commands, printed checks).
- `README.md` command reference and a Mermaid diagram of the pipeline.
- Orchestrator smoke harness (`ship-run.sh` launcher with real-GitHub rails, allowlists and a spend ledger) and the recorded prompt-05 runs P0, P1, S1, G2, run F1 and R2, I1 and I2, and G1 in `tests/agent-smoke/README.md` §9 ($26.82 of a $60 stop).
- `scripts/check-pr-intro.sh`: checks that a PR body opens with a plain-English introduction (first `##` section, 100-250 words or 80 per issue plus 80 for a bulk PR, no backticks, paths, AC/TC/WP ids, tables or headings), with bats tests and fixtures (build prompt 05b).
- `/aew:ship-milestone <n> [--bulk|--sequential] [--auto]` (build prompt 06): ships a milestone as one bulk run (one branch, one PR closing every issue) or a sequential run (one child per issue, stacked on its dependency), with a mode recommendation, a cycle and stack-conflict stop and a milestone report comment on every issue. It follows `ship`'s procedure through `references/{mode-selection,bulk,sequential}.md`, with no copy of its stages.
- `gh-milestone.sh select`: milestone order, cycle, AC counts, `stack_on`, stack conflicts and the deterministic mode recommendation, tested on the three prompt fixtures.
- `state.sh index init|set` for a sequential run's `index.json`, and `state.sh init --mode bulk` creating the per-issue `issues/<k>/` subdirs.
- `tests/scripts/skills.bats` checks that `ship-milestone` holds no `## Stage:` copy of `ship`.
- Milestone smoke runs M1, M3, B1, Q1 to Q3 and their ledger (stop $45) in `tests/agent-smoke/README.md` section 10.
- End-to-end validation on real GitHub (build prompt 07), recorded in `tests/e2e-validation.md`: a real user-scope install, a private sandbox, init, scenarios S1 to S8 (S9 skipped: Docker not running), the fix log, the retro triage and the spend ledger.
- README: prerequisites, a config reference for every schema field, the labels, the files aew creates in a project, troubleshooting from the validation runs, and uninstall commands.

### Changed

- `CLAUDE.md`: the ajv validation command now uses `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats`.
- `docs/DESIGN.md` §3/§11 and `state-machine.md`: gate failure path aligned with the verified hook documentation.
- `scripts/hooks/guard-bash.sh` now denies any `gh` command from an `aew:*` agent (agents never touch GitHub).
- `tests/scripts/conventions.bats`: the no-argument rule is narrowed so scripts whose arguments are all optional (`detect-stack.sh`) are exempt.
- `docs/DESIGN.md` §3 records the platform facts verified in the smoke runs (skill preloading, `agent_type`, memory directory, path variables, search tools).
- QA templates: `04-qa-test-plan.md` gains a `## Files read` section and `08-qa-report-<n>.md` a triage table.
- run-protocol: a QA phase B `failed` with a complete report is routed by triage class instead of retried (`state-machine.md`, DESIGN §7.3).
- `ui.axe_standard` is described as a cumulative conformance target (`wcag22aa` expands to WCAG 2.0 A/AA, 2.1 A/AA and 2.2 AA).
- `docs/DESIGN.md` §3 adds the Playwright MCP tool names, worktree isolation and nested `SubagentStop`, the `SubagentStop` payload and Bash permission-rule facts.
- `docs/DESIGN.md` §3 records the prompt-05 platform facts: skill arguments and the Skill-tool block, headless Manual mode and `--permission-prompts none`, AskUserQuestion on the main thread only, permission-rule matching, the headless permission pre-checks (rules H1 to H8, M1, M2), silent false `test` results, killed sessions without a `result` event, user-level MCP connectors in `-p` sessions, and subagent spend under `--max-budget-usd`. §9 records the orchestrator's deviations and the unanswered-gate rule.
- run-protocol `state-machine.md` follows `ship`'s routing: one rule for a plan challenge, a developer `blocked` re-plans once (full mode only), spec-ambiguity re-enters at `brief`, and an unanswered gate stays pending.
- Every Bash command the entry skills run is pre-approvable headless (no shell variables, substitutions or pipes in conditions), and every check prints its outcome.
- Every commit aew makes ends with the single trailer `Co-Authored-By: Claude <noreply@anthropic.com>`, with no model name (developer, qa-engineer, ship, init and the preflight memory hint).
- Every PR aew opens starts with `## In plain English`, a short introduction for the reviewer (build prompt 05b): the PR body template, the doc-writer (written last; one retry input, `intro_check_output`; the stacked variant from a `stacked_on` dispatch field) and `init`'s PR body. `ship` runs `check-pr-intro.sh` before it creates or updates the PR, re-dispatches the doc-writer once on a failure, and never blocks the PR: a persistent failure becomes a final-report warning and a retro item.
- `docs/DESIGN.md` §8.7 specifies the introduction; §9 states that every completed run ends in a PR (single, bulk, each sequential child and `init`), that blocked runs open none, and that a resume or re-run rewrites the introduction; §10 names the bulk and stacked variants.
- `resume` continues bulk and sequential milestone runs (a sequential parent resumes into its recorded child); `status` shows a sequential run's children and a child's milestone.
- `ship` gains one-line hooks into the bulk and sequential references, hands a finished or blocked sequential child back to the sequence, and `preflight.md` Check 5 allows a milestone parent and its child to be active together.
- Agent inputs: `brief-compiler` takes `issues` for one bulk brief, `qa-engineer` takes `m-<n>` as `<issue>` in a bulk run (evidence in `docs/qa/m-<n>/`), and `doc-writer` writes one spec snapshot per issue.
- `docs/DESIGN.md` section 10 records the prompt-06 deviations; run-protocol, github-ops and the README document milestone runs.
- `docs/DESIGN.md` §3 re-verifies the install, dependency, tag, `--bare`, budget and uninstall facts, and records that a local-marketplace install loads in place from the checkout and that aew's dependency tags go on this repo (build prompt 07).
- `init`'s permission rule lists move to `skills/init/references/permissions.md`, bringing `SKILL.md` under 500 lines; a headless init carries on when it cannot read them.
- `docs/DESIGN.md` records prompt 07's deviations: the introduction's contents and length targets, behaviour-only ACs, the developer's build step, and init's plugin `Read` rule.
- Runtime prompts no longer carry build-history notes.

### Fixed

- `scripts/git-branch.sh --help` no longer says preflight updates the base branch; preflight only checks it.
- `claude-md-curation` keeps a dated rule until its end date has passed (today is the run's `updated_at`), keeps dated changelog lines, and reports an end date it cannot judge for a human to check, instead of dropping every entry with a date (James's decision on CTO condition C4).
- `ship` reads a return block with `grep -v '^$' <file> | tail -n 4` instead of `awk 'NF'`, so an interactive run under init's permissions no longer prompts on each check (CTO condition C2).
- `developer` ignores `.claude/agent-memory/` in its clean-tree and allowed-files checks, listing untracked files individually because `git status --porcelain` collapses an untracked directory to one line (found by B1.1).
- `qa-engineer` lists files only in ARTEFACTS, never a directory, so ship's return check no longer blocks a QA run (found by Q3.1).
- The bulk spec-revision lookup in `bulk.md` puts `jq --arg` after the filter, so it is pre-approvable headless (found by B1.1 and B1.2; not re-run live), and the `bulk.md` filters sit in `sh` fences so `skills.bats` checks them.
- `init` asks every inferred config value, `retro.repo` included, instead of skipping one that looks obvious (found by the sandbox init).
- `init`'s report clean-up is one command with an exact allow rule, so an attended init no longer prompts on it (found by the sandbox init).
- `init` pre-approves reading the plugin's own references and templates (`Read(//<plugin root>/**)`), which a headless run otherwise denies (found by S2).
- The plan-approval gate puts the plan summary and the `05-plan.md` path in the question itself (found by S1; verified in S5).
- The doc-writer's PR introduction names new dependencies and plan decisions taken unapproved under `--auto` (found by S2), and says what the issue left open and what James decided at a gate (found by S3).
- The doc-writer rewrites the summary and PR body on every dispatch except a retry, aims the introduction at about 200 words, and cuts a length retry relative to the check's maximum (found by S3 and S6; verified in S7).
- The developer runs the configured build once on the feature branch and in fix mode, and never commits files the build leaves behind (found by S3).
- `gh-retro.sh` stays quiet when the retro label already exists (found by S3).
- `ship` checks each ARTEFACTS path in its own call, never in a `for` loop that a headless run denies (found by S3).
- The spec analyser adds behaviour ACs only, never ACs about how a criterion is tested (found by S4).
- The build prompt `prompt.md` asks for aew's plain commit trailer (found by S8).
- Retro fixes: CLAUDE.md lines are counted as the last line number Read shows (retro #26); the developer copies test counts from the runner (retro #9), reuses the brief's exact contract strings in fixtures (retro #10) and records a repeat count for an intermittent fix (retro #20); ui-qa checks that a reused app serves the current change (retro #11); `ship` says `spec-final.md` is the spec after a revision (retro #24); the brief keeps spec criterion numbers and AC ids distinct (retro #25); long screenshot tables fold into a `<details>` block (retro #21); QA compares HTML attribute names case-insensitively, in unit and e2e tests (retro #28); the folded table keeps the blank lines GitHub needs; and the revision note says `--from spec_analysis` re-fetches the issue.
