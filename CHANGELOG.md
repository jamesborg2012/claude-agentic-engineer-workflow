# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Limitation: no rewrite of a real issue body (`revise`, `manual-tests`) until prompt 07's sandbox end-to-end run passes.
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

### Fixed

- `scripts/git-branch.sh --help` no longer says preflight updates the base branch; preflight only checks it.
- `claude-md-curation` keeps a dated rule until its end date has passed (today is the run's `updated_at`), keeps dated changelog lines, and reports an end date it cannot judge for a human to check, instead of dropping every entry with a date (James's decision on CTO condition C4).
- `ship` reads a return block with `grep -v '^$' <file> | tail -n 4` instead of `awk 'NF'`, so an interactive run under init's permissions no longer prompts on each check (CTO condition C2).
- `developer` ignores `.claude/agent-memory/` in its clean-tree and allowed-files checks, listing untracked files individually because `git status --porcelain` collapses an untracked directory to one line (found by B1.1).
- `qa-engineer` lists files only in ARTEFACTS, never a directory, so ship's return check no longer blocks a QA run (found by Q3.1).
- The bulk spec-revision lookup in `bulk.md` puts `jq --arg` after the filter, so it is pre-approvable headless (found by B1.1 and B1.2; not re-run live), and the `bulk.md` filters sit in `sh` fences so `skills.bats` checks them.
