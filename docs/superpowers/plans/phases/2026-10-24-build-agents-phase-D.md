# Phase D plan: developer agent and the fan-out smoke run

- **Spec:** `docs/superpowers/specs/2026-10-24-build-agents.md` (hash `3507d614…c9c7`, NOVEL / EPIC)
- **Task source:** `docs/build-prompts/04-build-agents.md` (DESIGN.md wins on conflict)
- **Date:** 2026-10-24
- **Phase:** D · depth: full · risk: none
- **ACs covered:** AC-7 and AC-8 (the developer row and bullets), AC-9, AC-21, AC-23 (the developer-gate observations from the fan-out run: a stop that follows a valid report is allowed, and the nested `SubagentStop` behaviour)
- **Phase depends_on:** [B, A2, C4, C6]. Only the smoke task (D2) has these: B's fixture, A2's README §8 and spend ledger, C4's `smoke_shop` helper, and C6 (the last Phase C README edit, so README edits stay serialised per Phase C's PC-10). The agent prompt (D1) is written against the spec's fixed contracts and has no cross-phase dependency.

## Purpose

Phase D writes `agents/developer.md`, a complete system prompt for the three modes in DESIGN §8.5 (`full`, `package`, `fix`), and adds the DESIGN §3 platform facts and the §8.5 sentence the prompt relies on. It then proves `full` mode's fan-out in one small headless run (smoke 961): two sub-developers in two worktrees, a clean cherry-pick integration and green checks. The same run records whether nested sub-developers fire `SubagentStop`, and with which `agent_type`. Fix mode is written here but first *run* in Phase E (the 951 continuation, AC-20). The report-less gate runs (971/972) are Phase E's (CTO cut 3).

Phase D edits no file owned by another phase, except for appending to the shared `tests/agent-smoke/README.md` and separate bullets in `docs/DESIGN.md` (see Cross-phase notes).

## Facts relied on

From the spec's facts table (verified by the dispatching session on 2026-10-24, cited and not re-verified):

- **F3.** Subagents can spawn subagents up to 3 levels below the main thread. `Agent` must be in `tools` to spawn. `Agent(type)` restriction lists are ignored in a subagent definition, so the prompt, not the frontmatter, stops a sub-developer spawning.
- **F4.** Built-in worktree isolation branches from the repo's **default branch**, not the caller's HEAD. Its path and branch naming are undocumented, and changes are not merged back. So aew does not use it (A10).
- **F6.** The `SubagentStop` payload has `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path` and `last_assistant_message`. Whether a subagent spawned by a subagent fires it, and with which `agent_type`, is undocumented (AC-23 records it).

Checked in the repo while planning:

- `gate-subagent.sh` resolves the run dir through `HOOK_ROOT`, the **main** worktree (`git rev-parse --git-common-dir`). `hooks-gate-subagent.bats` already pins this ("a linked worktree cwd uses the main project's run"). A sub-developer's stop therefore gates on the main checkout's run dir, where its `06-dev-report-WP<n>.md` lives.
- The developer gate checks the **newest** `06-dev-report*.md`. It is not older than `state.json`, it ends in a valid return block, and when `STATUS: ok` it has a filled-in `## Commands run` row. So the parent's `06-dev-report.md` must be written last, after every WP report.
- `guard-bash.sh` follows `cd <dir>` across segments. It denies recursive `rm` outside the repo (so worktrees are removed only with `git worktree remove`), `git reset --hard` on the default branch, every push to the default branch and force pushes, and `gh` for any `aew:*` agent. It does not deny `git worktree`, `git cherry-pick` or `git branch -D`.
- `guard-edit.sh` denies any path with a `.git` component. Worktree paths (`.aew/runs/<id>/worktrees/WP-<n>/…`) have none.
- DESIGN §3 "Search tools": an agent with Bash has no Glob/Grep and searches with read-only `find`/`grep` (lesson `72497e2`). The prompt-03 fix `dcac6f4` showed that loops and `cat` chains break an allowlist, so the prompt asks for one plain command per call.
- `git cherry-pick -x` appends a `(cherry picked from commit …)` line, which would break AC-21's `(#202)` subject check and leave history noise. The prompt forbids `-x`.
- Local toolchain: git 2.54, node 26.12 (`node --test` discovers `**/*.test.js` with no arguments).
- `templates/artefacts/dev-report.md` already carries `Mode: package / fix (cycle <n>) / full` and the `## Commands run` table. `plan.md` WP blocks carry `create:`/`modify:` file lines, `depends_on` and `parallelisable`. No template changes are needed.

## Decisions made in this phase (flag if wrong)

| # | Decision | Why |
|---|---|---|
| DD-1 | **Prompt shape.** These are the mandatory `##` headings, in order: `Role`, `Inputs`, `Process`, `Outputs`, `Return contract`, `Guardrails`, `Autonomy`, `Definition of done`. There is **no** `## Memory` (the developer has no memory, DESIGN §5.3). Mode material lives in `### Mode: full`, `### Mode: package` and `### Mode: fix` under both Process and Definition of done. Under Process there is also one shared `### Every work package` subsection (read the standards, TDD, the UI rule, checks and commit), so the three modes don't repeat it. | Same shape as prompt 03's agents (PD-1) and Phase C's qa-engineer. Mechanically checkable (C2). |
| DD-2 | **Dispatch fields and fallbacks** follow the Interface contract table below. A missing or unknown `mode` returns `blocked`. Package mode has **no fallbacks**: it needs an absolute `run_dir`, `wp`, `worktree` and `branch`, or it returns `blocked`. | A9. A sub-developer must never guess its run or worktree. |
| DD-3 | **Preconditions.** In `full` and `fix` the current branch (`git rev-parse --abbrev-ref HEAD`) must equal `state.json` `branch` when that is set, and never the config `default_branch` (default `main`). `git status --porcelain` must also be empty. Otherwise the developer returns `blocked` and names the problem. In package mode, `cd <worktree> && git rev-parse --abbrev-ref HEAD` must equal `branch`, and the worktree must be clean at the start. | Worktrees are created from HEAD, so uncommitted work would be missing from them. Commits must never land on the default branch. |
| DD-4 | **Wave rule** (A12 made exact). Each round, R is the set of unfinished WPs whose `depends_on` are all integrated. A wave W is built greedily in WP-number order from the members of R marked `parallelisable: yes` whose file lists are disjoint from every WP already in W, capped at `limits.max_parallel_developers` (4 when absent). If W has at least 2 WPs, they fan out (all Agent calls in **one** message). Otherwise the lowest-numbered WP in R runs sequentially in the main checkout. Repeat until every WP is done or one is blocked. | Deterministic. The developer checks disjointness itself, even if the plan says `yes` (AC-9). |
| DD-5 | **Integration** (A11 made exact). Before creating a wave's worktrees, write down the base sha (`git rev-parse HEAD`). Then, for each WP in WP-number order: (1) its report says `STATUS: ok`; (2) `git log --format=%H <base>..<branch>` lists exactly one commit; (3) `git diff --name-only <base> <branch>` lists only that WP's allowed files (DD-7); (4) run `git cherry-pick <sha>` (never `-x`, never `-n`); (5) confirm the pick with `git diff <sha> HEAD -- <WP files>`, which must be empty. Only then remove the worktree with `git worktree remove <path>`. `--force` is allowed only after step 5 succeeds, and only if the plain remove refused. Then `git branch -D <branch>`. Last, `git worktree list` must show only the main worktree, and the post-integration checks run. A failed check (1)–(3), or a pick conflict (`git cherry-pick --abort` first, naming the conflicting files from `git diff --name-only --diff-filter=U`), returns `blocked`. A post-integration check failure also returns `blocked`, with the output. There is never an extra commit to "make it pass". | Keeps one commit per WP and a linear history. Uses only `git diff`, so the confirmation step needs no new command family (and no `git cherry`). Covers the spec-review note on `--force`. |
| DD-6 | **Blocked fan-out.** After a WP blocks, no new WP is scheduled. The other WPs of that batch that finished `ok` are integrated (DD-5). The blocked WP's worktree and branch are left untouched (no `--force`) and named, with path and branch, in Deviations and NEXT. The post-integration checks are then **not run**, and are recorded as "not run: worktree WP-<n> left for inspection", because a test runner that scans from the root would also scan the leftover copy. At the **start** of a later `full` dispatch, a leftover `aew/<run-id>/wp-<n>` worktree or branch is removed (`git worktree remove --force`, `git branch -D`) and recorded in Deviations **only if** `06-dev-report-WP<n>.md` exists with `STATUS: blocked` or `STATUS: failed` (an abandoned, recorded attempt): the revised plan supersedes it and the report keeps the reason. Any other leftover (no WP report, or one saying `ok`, e.g. after a crash mid-integration) is a `blocked` return naming its path and branch. This is the one deliberate exception to the spec-review note "`--force` only after the pick" (Assumption 11), and it applies only to an attempt whose own report already abandoned it. **Flag if wrong.** (The alternative is for the orchestrator to clean up in prompt 05. Without that cleanup the re-run deadlocks on `git worktree add -b` with an existing branch.) | No silent loss of the blocked attempt, and no deadlock on re-run. |
| DD-7 | **Allowed files.** A WP may touch only its listed `create:`/`modify:` files (AC-9). Anything else, an unlisted test file included, is a wrong plan step, so `blocked`. Package mode checks `git diff --name-only` and `git status --porcelain` in the worktree against this set before `git add`. Fix mode may touch files owned by any WP, plus files named in a triage's Fix instructions. It never touches QA's specs (`ui.e2e_dir`), `docs/qa/`, `docs/standards/`, `CLAUDE.md`, `.aew/config.json`, `state.json` or `log.md`. | AC-9's "touches only its WP's files". Disjointness is only guaranteed on the listed files, and a stray file shows up again at DD-5 step 3. |
| DD-8 | **Commits.** Format: `<type>(<scope>): <summary> (#<issue>)`. The type is `feat` for new behaviour, or the fitting type (`fix`, `refactor`, `test`, `docs`, `chore`). Fix mode always uses `fix`. The scope is a short lower-case area name. The summary is imperative, and the whole subject is at most 72 characters. The issue comes from the brief's H1 `# Brief: #<n> …`. In a bulk run it is the issue whose prefixed AC ids the WP covers (`#12-AC-1` gives `#12`). Commit with `git add <explicit paths>` (never `-A` or `.`), then `git commit -m "<subject>"`, with an optional second `-m "<body>"`. No heredoc, no `$(…)`, no co-author trailer. Full and package modes make one commit per WP. Fix mode makes one commit per root cause. | AC-9. A single `-m` keeps the permission rule simple and the subject regex-checkable. |
| DD-9 | **Checks per WP.** Run `commands.lint`, `format`, `typecheck` and `test_unit`, in that order. An absent key is a `not configured` row. `commands.install` runs only if a check fails for missing dependencies. If `format` rewrites files, only changes to allowed files are kept. Every row goes in `## Commands run`. | DESIGN §8.5. The gate reads this table. |
| DD-10 | **UI WP.** A WP is a UI WP if it covers an AC tagged `[UI]` in the brief, or owns a file that renders UI (`.html`, `.css`, `.jsx`, `.tsx`, `.vue`, `.svelte`, `.blade.php`, or a template). Before implementing one, invoke `frontend-design:frontend-design` with the Skill tool. A sub-developer invokes it itself. Fix mode does **not** invoke it, because its fixes are narrow and follow the existing design. **Flag if wrong.** | AC-9 says "on a UI work package". Fix mode isn't one. |
| DD-11 | **Fix mode sources.** From an `08-qa-report-<n>.md`, fix the `impl_bug` failures only (the other classes go to senior triage first). From a `09-triage-<n>.md`, follow its Fix instructions (its Test ruling is QA's, not yours). From a `07-review-<n>.md`, fix the blocker and major findings, and list minors and nits under Deviations as "not addressed". When failing e2e tests must be re-run, invoke `aew:ui-qa` with the Skill tool, start the app per its app-start section, run only the failing spec files (`commands.test_e2e` narrowed to them) **without** `AEW_EVIDENCE_DIR`, and stop the app only if you started it. Then run the full unit suite and lint, format and typecheck. A test you believe is wrong is a `blocked` return for senior triage. Never edit it. | A15, A16 and DESIGN §8.5. |
| DD-12 | **STATUS.** `ok`: every WP in scope is done and the checks pass. `blocked`: a precondition, a missing field or input, a wrong or impossible plan step, a file outside the allowed set, a pick conflict, red checks that the developer cannot fix within the allowed files, or a QA test believed wrong. `failed`: git or the file system errored in a way unrelated to the plan, or the report could not be written. `needs_input` is never used: engineering choices are the developer's, and spec questions go through the senior engineer. The report is written on **every** outcome, `blocked` included. | Matches run-protocol routing (developer `blocked` goes to the senior engineer). The gate needs a report on every stop. |
| DD-13 | **Bash allowlist** (AC-8; the exact list in Guardrails). `git` with `status`, `diff`, `log`, `show`, `add`, `commit`, `worktree`, `cherry-pick`, `branch` and `rev-parse`. `cd <absolute worktree path> && <one allowed command>` is the only way to work in a worktree (no `git -C`: `guard-bash.sh` follows `cd` but does not resolve `-C`, and a `Bash(git -C *)` rule would admit every git subcommand). The configured `commands.*` (`install`, `lint`, `format`, `typecheck`, `test_unit`; `test_e2e` narrowed, fix mode only). `node`, `npm` and `npx` only as those commands need. In fix mode with e2e only: `app.start_command`, `curl` for the ready check, `lsof -ti tcp:<port>` and `kill <pid>` for the instance it started. Read-only `ls`, `find`, `grep`, `head` and `wc` for search (no `-exec`, `-delete` or `-fprint`). One plain command per call: no loops, `$(…)`, heredocs or `cat` chains. Never `gh`, `push`, `merge`, `rebase`, `reset`, `checkout`, `switch`, `stash`, `clean` or `rm -r`. | A17 plus A15 (app start in fix mode). This list becomes smoke 961's `ALLOW` line and prompt 05's permission proposal. |
| DD-14 | **Static checks** are throwaway scripts in `tests/tmp/phase-d-build/` (gitignored, never committed), as in prompt 03 (PD-10). The headless run (D2) is the behavioural test. | Simplicity. No DESIGN item calls for an agent lint. |
| DD-15 | **Smoke 961 shape.** Temp project from `tests/fixtures/apps/static-shop/`, keeping the fixture's `.gitignore` (A26). Remove `run/` and `run-fanout/` after copying, commit on `main`, then create `feat/202-<slug>`. State: `state.sh init 961 --issues 202`, `set branch`, `stage develop`. Seeds: `run-fanout/02-brief.md`, `run-fanout/05-plan.md`, `run/03-standards.md` (CTO cut 4). The project is built by C4's `smoke_shop`, which installs dependencies before the fixture commit (so the lock file is committed and the tree is clean). The developer itself has no reason to install (`node --test` needs no dependencies). Dispatch fields `run_dir: $RUN, mode: full`. Cap $10, one raise to exactly $20. `--settings` adds a `SubagentStop` payload-capture hook. | A27, CTO cuts 2 and 4. Keeps the test small. |
| DD-16 | **README helper (consolidator decision).** D2 defines no helper and creates no ledger. It uses Phase C's C4 `smoke_shop <agent> <case> <run-id> <issue> <title> <branch> <stage>` (plus `SHOP` and `SHOP_RUN`), and appends its cost row to A2's `### 8.1 Spend ledger` (stop at $60) and its result rows to its own subsection of A2's `## 8. Build agents (prompt 04)`. | One helper and one ledger, owned by C4 and A2. |
| DD-17 | **Re-dispatch after a block.** After `develop --> parallel_planning: blocked` (`skills/run-protocol/references/state-machine.md`), `full` mode is re-dispatched on a branch that already holds integrated WP commits. At Step 0 in `full` mode, if `06-dev-report.md` exists with `Mode: full`, every WP it lists whose sha is printed by `git log --format=%H <default_branch>..HEAD` is already integrated: skip it, count it as integrated for DD-4, and carry its row into the new report. If a done WP's block in the revised plan lists different files from those its commit touched (`git show --name-only --format= <sha>`), return `blocked`, naming the WP. No other report or `Mode:` marks a WP as done. Only allowlisted commands (`git log`, `git show`, the Read tool). | Without it, a re-run re-implements integrated WPs and duplicates their commits. |

## Interface contract (consumed by Phase E and prompt 05)

### Dispatch fields

| Field | Modes | Required | Fallback |
|---|---|---|---|
| `run_dir` | all | package: yes, **absolute** | `.aew/runs/<id>` from `.aew/runs/current` (full, fix) |
| `mode` | all | yes: `full \| package \| fix` | none; missing or unknown → `blocked` |
| `fix_from` | fix | yes: comma-separated run-dir file names (`09-triage-<n>.md`, `08-qa-report-<n>.md`, `07-review-<n>.md`) | none → `blocked` |
| `n` | fix | no | the `<n>` in the first `fix_from` file name |
| `wp` | package | yes: `WP-<n>` | none → `blocked` |
| `worktree` | package | yes: absolute path `<run_dir>/worktrees/WP-<n>` | none → `blocked` |
| `branch` | package | yes: `aew/<run-id>/wp-<n>` | none → `blocked` |

The parent builds each package dispatch as one Agent call to `aew:developer`, with the prompt `run_dir: <abs run dir>, mode: package, wp: WP-<n>, worktree: <abs path>, branch: aew/<run-id>/wp-<n>` and **no `isolation`**. It creates the worktree first, with `git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`.

### Reports

| Mode | File (in the main checkout's run dir) | `Mode:` line | WP rows | `## Commands run` |
|---|---|---|---|---|
| full | `06-dev-report.md`, written **last** | `Mode: full` | every WP, with its **feature-branch** sha (after the cherry-pick) | the post-integration checks on the feature branch |
| package | `06-dev-report-WP<n>.md` (`wp: WP-1` writes `06-dev-report-WP1.md`) | `Mode: package` | its one WP, with the **WP-branch** sha | the checks run in the worktree |
| fix | `06-dev-report.md`, overwritten | `Mode: fix (cycle <n>)` | the WPs whose files the fix touched, each with its `fix` commit sha | the re-run failing tests, the full unit suite, lint, format, typecheck |

ARTEFACTS names the report first, relative to the project root. Every outcome writes the report (DD-12).

### Commits

- Full and package modes: one `<type>(<scope>): <summary> (#<issue>)` per WP, usually `feat`. Fix mode: `fix(<scope>): <summary> (#<issue>)`, one per root cause.
- Sub-developers commit on their WP branch. The parent integrates with plain `git cherry-pick <sha>`, so the subject is unchanged and has no `cherry picked from` line.
- After `full` mode, `<base>..HEAD` holds exactly one commit per WP, in WP-number order. No WP branch or extra worktree remains.

### Return semantics

- `ok`: done, checks green, `## Commands run` filled. NEXT: `full` → "senior-engineer review"; `package` → "parent: integrate WP-<n>"; `fix` → "qa-engineer phase B (cycle <n+1>)" when `fix_from` named a QA report or triage, or "senior-engineer review" for a review.
- `blocked`: DD-12 reasons, named in SUMMARY. In `full` mode the finished WPs are integrated first (DD-6). The orchestrator routes this to the senior engineer (run-protocol, unchanged).
- `failed`: tooling or file-system error. The orchestrator retries once, then blocks (unchanged).
- `needs_input`: never.

### Bash allowlist and the smoke `ALLOW` line

The prompt's Guardrails list is DD-13. The smoke 961 `ALLOW` line derived from it is:

```sh
ALLOW=(--allowedTools "Bash(git status *)" "Bash(git diff *)" "Bash(git log *)" "Bash(git show *)" \
  "Bash(git add *)" "Bash(git commit *)" "Bash(git worktree *)" "Bash(git cherry-pick *)" \
  "Bash(git branch *)" "Bash(git rev-parse *)" "Bash(cd *)" "Bash(node *)" "Bash(npm *)" "Bash(npx *)" \
  "mcp__plugin_context7_context7__*")
```

`Bash(cd *)` is there from the first run because sub-developers work through `cd <worktree> && <cmd>`. It is harmless: each segment of a compound command is matched on its own, so the command after `cd` still needs its own rule. Including it up front saves a paid re-run; S3 still records whether the cd form ran without denials. There is deliberately no `Bash(git -C *)` (see DD-13). Phase E's 951 fix run adds `"Bash(curl *)" "Bash(lsof *)" "Bash(kill *)"`, for the app start in fix mode.

## Tasks

```
- id: D1
  title: developer agent prompt, with DESIGN §3 (F3, F4) and the §8.5 fan-out sentence
  files: [agents/developer.md, docs/DESIGN.md]
  depends_on: []
  pattern: agents/senior-engineer.md (structure, dispatch-fields block, path note, Guardrails wording); templates/artefacts/dev-report.md; DESIGN §8.5
  checks: C1–C8 (static, tests/tmp/phase-d-build/check-developer.sh)
  ac: [7, 8, 9]
  risk: none
- id: D2
  title: smoke 961, developer full-mode fan-out, plus the nested SubagentStop observation
  files: [tests/agent-smoke/README.md, docs/DESIGN.md, agents/developer.md (only on a prompt fix)]
  depends_on: [D1, B1 (site, package, config, .gitignore, unit test), B2 (docs/standards/web.md, which the plan's standards rows cite), B3 (run/, for run/03-standards.md), B4 (run-fanout/), C4 (smoke_shop helper), C6 (README edits serialised C4 → C5 → C6 → D2, Phase C PC-10; shared $60 ledger), A2 (README §8 + ledger)]
  pattern: tests/agent-smoke/README.md sections 2–4 (helpers, invocation, checks); prompt-03 phase E smoke-task shape
  checks: S1–S13
  ac: [7, 8, 9, 21, 23]
  risk: none (paid run, capped)
- id: D3
  title: (conditional) gate the developer report named in the stop message
  files: [scripts/hooks/gate-subagent.sh, tests/scripts/hooks-gate-subagent.bats, docs/DESIGN.md]
  depends_on: [D2]
  runs_only_if: D2's S10 records a developer stop that was blocked although its own report was present, fresh and valid
  pattern: gate_developer in scripts/hooks/gate-subagent.sh; the existing "developer:" bats rows
  ac: [23]
  risk: none
```

The B ids are Phase B's task ids (`docs/superpowers/plans/phases/2026-10-24-build-agents-phase-B.md`).

---

### D1: `agents/developer.md` (plus DESIGN §3 and §8.5)

**Frontmatter** (exact values):

```yaml
---
name: developer
description: Implements the plan's work packages, sequentially or fanned out to sub-developers in git worktrees, and fixes QA, triage or review failures. Dispatched by the aew orchestrator only, with a mode of full, package or fix; don't use it directly.
model: sonnet
effort: medium
skills:
  - aew:run-protocol
  - superpowers:test-driven-development
  - superpowers:verification-before-completion
  - superpowers:systematic-debugging
tools: Read, Write, Edit, Bash, Agent, Skill, mcp__plugin_context7_context7__*
---
```

There is no `memory`, no `isolation` (A10), no `disallowedTools` (it would remove all of Bash) and no Glob/Grep (the agent has Bash, see DESIGN §3 "Search tools").

**Body outline** (target 280–400 lines; second person, British English):

1. **`## Role`** (4–6 lines). You are aew's developer, the `develop` stage, and the fixer in the QA and review loops. You implement the plan exactly. You follow the standards docs strictly. You use TDD for unit tests. You write readable, simple code with doc comments on public functions and comments that explain *why*. You never diverge silently. One of three jobs per dispatch, chosen by `mode`. Then the plugin path note, worded as in senior-engineer ("Plugin paths in this prompt are already absolute…"). Every other path is relative to the project root, except in package mode, where you work by absolute path inside your worktree.

2. **`## Inputs`**.
   - `### Dispatch fields`: the Interface contract table, written out in prose bullets, with DD-2's package-mode rule. `state.json` is read only for `branch` and never written.
   - `### Files per mode`: a table. "Required" means that if the file is missing you return `blocked` and name it.
     - full: `05-plan.md`, `02-brief.md`, `03-standards.md` (required), the `docs/standards/` sections that `03-standards.md` lists, `.aew/config.json` (`commands`, `limits.max_parallel_developers`, `default_branch`), the codebase. `03-standards.md` is read only for its doc paths and the sections that apply. Its title line is never checked against the brief.
     - package: the same, but only your WP's block of `05-plan.md`. You read and edit code inside `worktree` only.
     - fix: every file in `fix_from` (required), `02-brief.md`, `05-plan.md`, `03-standards.md`, `06-dev-report.md`, the failing test files named there (read-only).
   - `### Templates`: `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/dev-report.md`, with the usual sentence (start from it, keep every heading and its order, replace placeholders, delete instruction comments, end with the return block). The `Mode:` line holds exactly one of the three values.

3. **`## Process`**. Step 0, for every mode: resolve the fields, check DD-3's preconditions, read the required inputs, and take the issue number per DD-8. In `full` mode, Step 0 also finds the already-integrated WPs (DD-17).
   - **`### Every work package`** (shared): (1) read the WP block (goal, ACs, files, the standards rows, guardrails, unit tests) and the matching brief ACs; (2) the UI rule (DD-10); (3) explore with `find`/`grep`, then reuse first; (4) TDD with the preloaded method: write the planned unit tests, watch them fail, implement, watch them pass; (5) use context7 (`resolve-library-id`, then `query-docs`) only for version-specific API questions, and carry on without it if it is unavailable; (6) the checks (DD-9); (7) the allowed-files check (DD-7); (8) commit (DD-8); (9) record the WP's files, commands and any deviation. A plan step that is impossible or clearly wrong stops the WP with `blocked` and the reason (DESIGN §8.5).
   - **`### Mode: full`**: (1) read the WP graph and check it is acyclic, else `blocked`; (2) clear leftovers per DD-6; (3) skip the already-integrated WPs (DD-17): if `06-dev-report.md` exists with `Mode: full`, each WP it lists whose sha appears in `git log --format=%H <default_branch>..HEAD` counts as integrated, keeps its row for your report, and is never re-implemented; if the revised plan's block for such a WP lists different files from `git show --name-only --format= <sha>`, return `blocked` naming it; (4) loop over the waves (DD-4), stated as numbered steps with a three-line example (two leaf WPs with disjoint files fan out; a WP that shares a file with another runs on its own; a single ready WP runs sequentially); (5) for a sequential WP, apply "Every work package" in the main checkout; (6) for a wave, write down the base sha, create each worktree with exactly `git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`, then dispatch every package Agent call **in one message** (fields per the Interface contract, no `isolation`) and wait for all of them; (7) integrate per DD-5, then read each `06-dev-report-WP<n>.md` and carry its rows and deviations into your report; (8) on a block, DD-6; (9) after the last WP, run the checks (DD-9) on the feature branch, unless DD-5 has just run them for a final wave; these rows fill `## Commands run`; (10) write `06-dev-report.md` last. Never set `isolation` on an Agent call: built-in isolation branches from the default branch and would lose the earlier WPs.
   - **`### Mode: package`**: you are a sub-developer. (1) Check `wp`, `worktree`, `branch` and an absolute `run_dir`, and that the worktree is on `branch` and clean (DD-3); (2) prefix every Bash command, git included, with `cd <worktree> && ` (one allowed command after it); Read, Edit and Write by absolute path inside the worktree only; never touch the main checkout except to write your report into `run_dir`; (3) apply "Every work package" to your WP only; (4) before `git add`, compare `git diff --name-only` and `git status --porcelain` with your allowed files; (5) make exactly one commit on `branch`; (6) write `<run_dir>/06-dev-report-WP<n>.md` with `Mode: package` and your WP-branch sha. Never call the Agent tool, never cherry-pick, never remove a worktree or delete a branch: the parent does all of that.
   - **`### Mode: fix`**: (1) read `fix_from` and build the list of failures to fix (DD-11); (2) for each root cause: reproduce it with a unit test where the cause is unit-testable (TDD), fix it within the allowed files (DD-7), and commit `fix(<scope>): … (#<issue>)`; (3) re-run the failing tests: unit tests directly; e2e tests via `aew:ui-qa`, invoked with the Skill tool, without `AEW_EVIDENCE_DIR`, stopping the app only if you started it; (4) run the full unit suite, lint, format and typecheck; (5) overwrite `06-dev-report.md` with `Mode: fix (cycle <n>)`. Never edit QA's specs. A test you believe is wrong means `blocked`, naming the TC and why.

4. **`## Outputs`**: code and unit tests, the commits (DD-8), and the report per the Interface contract "Reports" table. The run dir is gitignored and the reports are never committed. Write nothing else in `run_dir`.

5. **`## Return contract`**: the four-line block, then "the block is the last four non-blank lines of both the final message and the report". Meanings per DD-12, and NEXT values per the Interface contract. SUMMARY says which WPs ran sequentially and which fanned out, the commits, and the check results (or the blocked reason).

6. **`## Guardrails`**: the allowed files (DD-7); the exact Bash allowlist (DD-13), then "nothing else"; one plain command per call; the no-GitHub wording, verbatim from senior-engineer ("Never run `gh`, and never push, merge or open a PR. The aew Bash guard denies `gh` for every aew agent, so trying only wastes a turn. Issue content comes from the run dir."); never `git push`, `merge`, `rebase`, `reset`, `checkout`, `switch`, `stash` or `clean`; never `rm -r` (remove worktrees only with `git worktree remove`); never commit on the default branch; never set `isolation`; never spawn agents in package or fix mode; no new dependency unless the plan names it; no secrets in code, reports or commit messages.

7. **`## Autonomy`**: never ask; you can't. You make engineering choices inside a WP alone. Any departure from the plan is a `blocked` return, never a quiet change. When two designs both satisfy the plan, pick the simpler one.

8. **`## Definition of done`**: `### Mode: full` (every WP done, or blocked with the finished ones integrated; one commit per WP in WP-number order; no worktree or WP branch left, except DD-6's; post-integration checks green; the report written last); `### Mode: package` (one commit on `branch`, only allowed files, report `06-dev-report-WP<n>.md` with `Mode: package`); `### Mode: fix` (every in-scope failure fixed or `blocked` with the reason; the failing tests re-run and passing; the full unit suite green; `Mode: fix (cycle <n>)`); `### All modes` (template headings in order, no placeholders or comments, `## Commands run` filled for `ok`, the return block last in both).

**DESIGN.md (same commit, the repo rule for docs-driven facts):**

- §3 **Nesting**: extend the existing bullet. To spawn, `Agent` must be in the agent's `tools`. An `Agent(type)` restriction list is ignored in a subagent definition, so a sub-developer is kept from spawning by its prompt (F3).
- §3: a new **Worktree isolation** bullet, after Nesting. `isolation: worktree` (frontmatter or on the Agent call) branches from the repo's default branch, not the caller's HEAD, unless the user sets `worktree.baseRef: "head"`. Its path and branch naming are undocumented, it is auto-cleaned only when unchanged, and nothing is merged back. So aew does not use it, and the developer creates its worktrees with `git worktree add` (F4).
- §8.5 **Fan-out**: one sentence after the list. "The developer creates each worktree itself from the feature-branch HEAD (`git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`) and dispatches the sub-developers without `isolation` (§3); it integrates each work package's single commit with `git cherry-pick` in WP-number order, removes the worktrees and WP branches, and only then reruns the checks."

Grep §3 first (`grep -n 'Nesting\|isolation' docs/DESIGN.md`), so that a bullet Phase A or C already added is extended, not duplicated.

**Checks (D1).** Write `tests/tmp/phase-d-build/check-developer.sh` **before** authoring. Run it against the missing file and capture the failure (the RED). Then author and re-run until it passes (the GREEN). Every check below must pass.

- **C1 frontmatter** (Ruby `YAML.safe_load`, as in prompt-03 Phase D):
  ```bash
  /usr/bin/ruby -ryaml -e '
    fm = File.read(ARGV[0])[/\A---\n(.*?)\n---\n/m, 1] or abort "no frontmatter"
    y = YAML.safe_load(fm)
    { "name"=>"developer", "model"=>"sonnet", "effort"=>"medium" }.each { |k,v| y[k]==v or abort "#{k}: #{y[k].inspect}" }
    y["skills"]==%w[aew:run-protocol superpowers:test-driven-development superpowers:verification-before-completion superpowers:systematic-debugging] or abort "skills: #{y["skills"].inspect}"
    y["tools"].split(/,\s*/).sort==%w[Read Write Edit Bash Agent Skill mcp__plugin_context7_context7__*].sort or abort "tools: #{y["tools"]}"
    y["description"].include?("aew orchestrator only") or abort "description"
    %w[memory isolation disallowedTools].each { |k| y.key?(k) and abort "unexpected #{k}" }
    ok = %w[name description model effort maxTurns autoCompactWindow tools skills background omitClaudeMd color]
    (y.keys-ok).empty? or abort "unhonoured keys: #{y.keys-ok}"
    puts "C1 ok"' agents/developer.md
  ```
- **C2 headings** (fence-skipping, no Memory):
  ```bash
  got=$(awk '/^```/{f=!f;next} !f && /^## /' agents/developer.md | sed 's/^## //')
  want=$(printf '%s\n' Role Inputs Process Outputs 'Return contract' Guardrails Autonomy 'Definition of done')
  [ "$got" = "$want" ] || { diff <(echo "$want") <(echo "$got"); exit 1; }
  for m in full package fix; do [ "$(grep -c "^### Mode: $m\$" agents/developer.md)" -ge 2 ] || { echo "C2 Mode: $m"; exit 1; }; done
  grep -q '^### Every work package$' agents/developer.md || { echo "C2 Every work package"; exit 1; }
  ```
- **C3 required strings** (`grep -qF` each; any miss fails): `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/dev-report.md`, `06-dev-report.md`, `06-dev-report-WP<n>.md`, `mode: full | package | fix`, `run_dir`, `fix_from`, `wp`, `worktree`, `branch`, `git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`, `git cherry-pick`, `git worktree remove`, `--force`, `git branch -D`, `git worktree list`, `git diff --name-only`, `git status --porcelain`, `parallelisable`, `depends_on`, `max_parallel_developers`, `git log --format=%H <default_branch>..HEAD`, `in one message`, `isolation`, `cd <worktree> && `, `Mode: full`, `Mode: package`, `Mode: fix (cycle <n>)`, `(#<issue>)`, `feat(`, `fix(`, `frontend-design:frontend-design`, `aew:ui-qa`, `AEW_EVIDENCE_DIR`, `not configured`, `impl_bug`, `Never run \`gh\``, `never push, merge or open a PR`, `STATUS: ok | needs_input | blocked | failed`, `resolve-library-id`, `doc comments`.
- **C4 forbidden actions appear only as prohibitions.** `grep -c 'agent-memory'` is `0` (the developer has no memory). Each of `git push`, `rebase`, `reset`, `stash`, `cherry-pick -x`, `git add -A`, `rm -r` and `isolation: worktree` that occurs in the body occurs only on lines that also match `[Nn]ever|[Nn]ot `: `grep -nF "$s" agents/developer.md | grep -vE '[Nn]ever|[Nn]ot '` prints nothing for each `$s`. A plain absence check would be fragile, because the prompt has to name what it forbids.
- **C5 path spelling**: `grep -oE '\$?\{?CLAUDE_PLUGIN_ROOT\}?/?' agents/developer.md | grep -vxF '${CLAUDE_PLUGIN_ROOT}/'` prints nothing, and every `${CLAUDE_PLUGIN_ROOT}/templates/…` path exists in the repo.
- **C6 British English** (body only): `sed '1,/^---$/d' agents/developer.md | grep -nEi '\b(behavior|color|organiz|analyz|prioritiz|recogniz|summariz|initializ|favorite|center)'` prints nothing.
- **C7** `claude plugin validate .` exits 0 with no line naming `agents/`.
- **C8 DESIGN**: `grep -c 'Agent(type)' docs/DESIGN.md` ≥ 1; `grep -c 'worktree.baseRef' docs/DESIGN.md` ≥ 1; the §8.5 block (`awk '/^### 8.5/,/^### 8.6/' docs/DESIGN.md`) contains `git worktree add -b` and `cherry-pick`.

**Commit:** `feat(agents): add developer agent with full, package and fix modes`

---

### D2: smoke 961, fan-out and nested `SubagentStop`

**Files:** `tests/agent-smoke/README.md` (a new subsection under A2's `## 8. Build agents (prompt 04)`, after Phase C's: setup, invocation, checks and result rows for 961, plus a row appended to A2's `### 8.1 Spend ledger`; C4's `smoke_shop` is used, not redefined, per DD-16); `docs/DESIGN.md` §3 (the observed nested-`SubagentStop` fact). `agents/developer.md` only on a prompt fix.

**Loop on failure** (the prompt-03 rules, unchanged). A *harness fault* (a command, seed or jq path) is fixed in the README and re-run, with no prompt change. An *agent fault* is fixed in `agents/developer.md` with the DD-1 shape kept, committed as `fix(agents): <what the prompt now says>`, and 961 is re-run (it is the developer's only run in this phase). The check is never weakened. At most three fix rounds per check, then `DONE_WITH_CONCERNS`. A check that passed once and failed once is recorded as `flaky`, and the last run must pass.

**Setup** (zsh-safe; `REPO`, `SMOKE`, `smoke_use` and `smoke_dispatch` from README section 2; `smoke_shop`, `SHOP` and `SHOP_RUN` from C4's helper in README §8):

```sh
# C4's smoke_shop <agent> <case> <run-id> <issue> <title> <branch> <stage> copies the static-shop fixture (keeping its
# .gitignore), installs dependencies BEFORE the fixture commit, commits on main, switches to <branch>, initialises
# script-owned state and calls smoke_use. D2 sets T and BR itself, because later checks use them.
T="Add shop helpers"; BR=feat/202-add-shop-helpers
smoke_shop developer fanout 961 202 "$T" "$BR" develop
cp "$SHOP_RUN/03-standards.md" "$SHOP/run-fanout/02-brief.md" "$SHOP/run-fanout/05-plan.md" "$RUN/"
git -C "$P" rev-parse main > "$O/main.sha"
(cd "$P" && pwd -P) > "$O/p.real"
```

**Invocation.** README section 3's command, with three changes:

- `ALLOW` is the Interface contract line.
- `CAP=10`.
- `--settings` carries a `SubagentStop` capture hook as well. Build it with jq, so that the quoting is safe:

```sh
smoke_dispatch developer "run_dir: $RUN, mode: full"; CAP=10
SETTINGS=$(jq -nc --arg ex "$REPO/CLAUDE.md" --arg cap "cat >> '$O/stop-payloads.jsonl'; echo >> '$O/stop-payloads.jsonl'" \
  '{claudeMdExcludes:[$ex], enabledPlugins:{"dev-workflow@jamesborg":false,"figma@claude-plugins-official":false},
    hooks:{SubagentStop:[{hooks:[{type:"command",command:$cap}]}]}}')
cd "$P" && claude --plugin-dir "$REPO" -p "$DISPATCH" \
  --output-format stream-json --verbose --forward-subagent-text --include-hook-events \
  --max-budget-usd "$CAP" --debug-file "$O/debug.log" --settings "$SETTINGS" \
  --add-dir "$REPO" --permission-mode acceptEdits ${ALLOW[@]+"${ALLOW[@]}"} > "$O/stream.jsonl"
```

The capture hook has no matcher, so it records every `SubagentStop`, whatever the agent type. It runs alongside the plugin's gate, which still decides.

**Checks.** Each check gets a row in the README results (`| check | result | notes |`).

- **S1 Fan-out in one message.** The developer (events whose `parent_tool_use_id` is the main thread's Agent `tool_use` id) emits two `Agent` `tool_use` blocks under the **same** `message.id`. Both have `subagent_type` `aew:developer`, no `isolation` key, and a prompt containing `mode: package`, `wp: WP-1` or `WP-2`, `worktree: $RUN/worktrees/WP-<n>` and `branch: aew/961/wp-<n>`:
  ```sh
  MAIN=$(jq -r 'select(.type=="assistant" and .parent_tool_use_id==null) | .message.content[]? | select(.type=="tool_use" and .name=="Agent") | .id' "$O/stream.jsonl" | head -1)
  jq -c --arg m "$MAIN" 'select(.type=="assistant" and .parent_tool_use_id==$m) | .message as $g | $g.content[]?
      | select(.type=="tool_use" and .name=="Agent") | {mid:$g.id, t:.input.subagent_type, iso:(.input.isolation // null), p:.input.prompt}' "$O/stream.jsonl"
  ```
  If the stream doesn't carry the developer's own tool calls, fall back to the debug log's `[Agent: aew:developer]` lines plus S4, and record which source was used.
- **S2 Worktree commands.** The developer's Bash `command`s include two calls of the form `git worktree add -b aew/961/wp-<n> <…>/worktrees/WP-<n> HEAD`. Record one verbatim. The README row notes that the feature branch equals `main` at dispatch, so only this verbatim command evidences "worktree from HEAD"; S4–S7 cannot tell a HEAD worktree from a default-branch one.
- **S3 Sub-developer command form** (spec-review note). The Bash commands under each sub-developer's `parent_tool_use_id` use `cd <worktree> && …`. Confirm that none ran outside its worktree (other than writing its report into `$RUN`) and that none used `git -C`. If a `cd … &&` command was denied although `ALLOW` has `Bash(cd *)`, change the prompt to `git -C <worktree>` and absolute paths (an agent fault), give `ALLOW` one scoped rule per family (`"Bash(git -C * add *)"` and so on, never a bare `Bash(git -C *)`), re-run, and record the result for prompt 05.
- **S4 WP reports.** `$RUN/06-dev-report-WP1.md` and `06-dev-report-WP2.md` exist. Each has the line `Mode: package`, a valid return block with `STATUS: ok`, a filled `## Commands run`, and the template's headings (README section 4 conformance diff against `dev-report.md`). Each WP row's sha is a commit object (`git -C "$P" cat-file -t <sha>` prints `commit`) whose subject equals the subject of the matching integrated commit.
- **S5 Parent report.** `$RUN/06-dev-report.md` has `Mode: full` and a valid return block with `STATUS: ok`, conforms to the template, and is the newest `06-dev-report*.md` (`ls -t "$RUN"/06-dev-report*.md | head -1`). Its WP rows carry the two `main..HEAD` shas, and `## Commands run` has a `node --test` row that passes.
- **S6 Commits.**
  ```sh
  git -C "$P" log --reverse --format='%H %s' main..HEAD        # exactly 2 lines
  git -C "$P" log --format='%s' main..HEAD | grep -cvE '^feat\([a-z0-9-]+\): .+ \(#202\)$'   # 0
  git -C "$P" log --format='%B' main..HEAD | grep -c 'cherry picked from'                    # 0
  for wp in 1 2; do sed -n "/^### WP-$wp:/,/^##/p" "$RUN/05-plan.md" | sed -nE 's/^ *- (create|modify): *`?([^`]+)`?$/\2/p' | sort > "$O/wp$wp.files"; done
  git -C "$P" log --reverse --format=%H main..HEAD | head -1 | xargs -I{} git -C "$P" show --name-only --format= {} | sort | diff "$O/wp1.files" -
  git -C "$P" log --reverse --format=%H main..HEAD | tail -1 | xargs -I{} git -C "$P" show --name-only --format= {} | sort | diff "$O/wp2.files" -
  ```
  Both diffs print nothing, so each commit touches exactly its WP's files, and the commits are in WP-number order. If the `sed` extraction comes back empty for a WP, Phase B's plan format differs: that is a harness fault, so fix the `sed` line.
- **S7 Clean-up.** `git -C "$P" worktree list --porcelain | grep -c '^worktree '` is `1`, and that one path is `$(cat "$O/p.real")`. `git -C "$P" branch --list 'aew/*'` prints nothing. `ls "$RUN/worktrees" 2>/dev/null` prints nothing. `git -C "$P" status --porcelain` is empty. `git -C "$P" rev-parse --abbrev-ref HEAD` is `$BR`. `git -C "$P" rev-parse main` equals `$O/main.sha`.
- **S8 Checks re-run by the harness.** `(cd "$P" && node --test)` exits 0 with `# fail 0`, and its `# pass` count is at least 3 (the fixture's basket test plus at least one per WP, Phase B contract; AC-21 does not pin an exact count, and TDD may add cases). Record the count. Also `git -C "$P" status --porcelain` is still empty afterwards (the helper's lock file is in the fixture commit, and the developer had no reason to install).
- **S9 Final message.** `final.txt` is taken with the README section 4 filter, narrowed to `parent_tool_use_id == $MAIN`. It passes `valid_return_block` with `STATUS: ok`, and its ARTEFACTS names `06-dev-report.md`.
- **S10 Gate, AC-23.** The parent developer's stop, which follows a valid report, is **allowed**: no `SubagentStop` hook response in the stream (`jq -c 'select(.type=="system" and (.subtype // "" | test("hook"))) | select(tostring | test("SubagentStop"))'`) carries `"decision":"block"` for it. Any block decision is analysed: which stop (from the order and `agent_id`), and whether that agent's own report was present, fresh and valid at the time. A block on a stop whose own report was valid is a **mis-block**, which triggers D3. Record the gate's output per stop.
- **S11 Nested `SubagentStop`** (A29). From `$O/stop-payloads.jsonl`:
  ```sh
  jq -c '{agent_type, agent_id, stop_hook_active, artefacts: ((.last_assistant_message // "") | [scan("ARTEFACTS:[^\n]*")] | last)}' "$O/stop-payloads.jsonl"
  ```
  Record verbatim, in the README isolation table, whether the two sub-developers fired `SubagentStop` (three `aew:developer` lines with distinct `agent_id`s means yes; one line means no). Record their `agent_type` value (`aew:developer`, something else, or absent), and whether `last_assistant_message` carries the ARTEFACTS line naming `06-dev-report-WP<n>.md` (the input for A29's fallback). Cross-check with `grep -n 'SubagentStop' "$O/debug.log" | head`. Then add the result to DESIGN §3 under Hook matching, as a one-line fact replacing "undocumented".
- **S12 Agent hygiene.** No `isolation` on any Agent call. The sub-developers make no Agent call (no `tool_use` named `Agent` under their `parent_tool_use_id`s). No Bash command starts with `gh` or contains `git push`, `git merge`, `git rebase`, `git reset`, `git checkout`, `git switch`, `cherry-pick -x` or `rm -r` (list them with the README's tool-call filter and grep).
- **S13 Per-run rows** (feeding Phase E's AC-25 aggregate). *Preload*: the debug log shows `Preloaded skill` for all four `skills:` entries under `[Agent: aew:developer]`, with no skip, not-found or missing warning. Record how many times they appear: three times means the sub-developers preload them as well. `permission_denials` is `[]`. `git -C "$REPO" status --porcelain` shows only the README, `docs/DESIGN.md` (S11) and an intentional prompt fix. Append the cost row to A2's `### 8.1 Spend ledger`. The cap is raised only once, to exactly $20. If the shared $60 prompt-04 total is passed, stop and report `DONE_WITH_CONCERNS`.

If S1 fails because the developer worked sequentially, that is an agent fault (DD-4 not followed): fix the prompt and re-run. If the main thread cannot spawn at depth 2 at all (no package Agent call is possible), stop and report `DONE_WITH_CONCERNS`. It would invalidate F3, and the CTO decides.

**Commit:** `test(agent-smoke): record developer fan-out run and nested SubagentStop behaviour` (README and DESIGN §3). Any prompt fix gets its own `fix(agents): …` commit before it.

---

### D3 (conditional): gate the report named in the stop message

Runs **only** if S10 records a mis-block. Otherwise D2's notes say "A29 fallback not needed", and D3 is closed with no commit.

- **Change** (A29): in `gate_developer`, first look in `hook_field .last_assistant_message` for its last `ARTEFACTS:` line. If that line names a `06-dev-report*.md` that exists in the run dir, gate **that** file (with the same freshness, return-block and commands rules). Otherwise keep the current "newest report" rule. No other gate behaviour changes.
- **Tests first** (RED, then GREEN) in `tests/scripts/hooks-gate-subagent.bats`, following the existing `developer:` rows and the `payload` helper:
  - "developer: the report named in ARTEFACTS wins over a newer sibling": a valid `06-dev-report-WP1.md` is named, and a newer, malformed `06-dev-report-WP2.md` exists. Allowed.
  - "developer: a named report that is missing falls back to the newest": still blocks when there is no report.
  - "developer: a named stale report blocks".
  - The existing rows and the timing row stay green.
- `tests/run-script-tests.sh` passes (shellcheck and every bats file).
- **DESIGN §11**: the developer-gate bullet gains "the report named in the stop message's `ARTEFACTS` line, else the newest", recorded as a deviation from the original §11 wording.
- **Commit:** `fix(hooks): gate the developer report named in the stop message`. Then re-run 961 and record S10 again.

---

## Phase verification

Run once on the integration branch, with `superpowers:verification-before-completion`:

1. `tests/tmp/phase-d-build/check-developer.sh` (C1–C8) passes. Recreate it from this plan if the tree is fresh.
2. `claude plugin validate .` exits 0 with no `agents/` finding.
3. `tests/run-script-tests.sh` passes. It is a regression guard, and mandatory if D3 ran.
4. The README's 961 rows (S1–S13) are each `pass`, or `flaky` with a final pass. There are no `pending` rows for 961.
5. `git status` is clean, and `tests/tmp/` and `$SMOKE` hold no tracked file.

## AC → task matrix

| AC | Part covered by Phase D | Task | Evidence |
|---|---|---|---|
| AC-7 | the developer row: model, effort, no memory, four skills, tools including `Agent`, no `isolation`, the "aew orchestrator only" description, the prompt-03 structure | D1, D2 | C1, C2, C7; S13 preload |
| AC-8 | developer: no `gh`, push, merge or PR; the exact Bash families in Guardrails, which are also the `ALLOW` line | D1, D2 | C3, C4; S12; S3 (`ALLOW` derived from the prompt, no denials) |
| AC-9 | all of DESIGN §8.5: modes, fan-out rules, package mode, checks, commits, the UI rule, blocked, fix mode, `Agent` in tools, doc comments | D1 (all), D2 (full and package behaviour) | C3 strings; S1–S8. Fix mode runs in Phase E (AC-20). `frontend-design` stays untested (spec out of scope). |
| AC-21 | the whole fan-out check | D2 | S1, S4–S8 |
| AC-23 | a developer stop that follows a valid report is allowed; the nested `SubagentStop` fact; the fallback if it mis-blocks | D2, D3 (conditional) | S10, S11; D3's bats rows. The report-less runs 971/972 are Phase E's. |

## Risks

- **The agent works sequentially instead of fanning out** (medium). DD-4 is stated as an exact rule with an example, and S1 is a hard check. A prompt fix and a re-run are within the three-round limit.
- **Nested-event visibility.** The stream may not show the depth-2 tool calls. S1 and S3 fall back to the debug log and the structural checks (S4–S7), and record which source was used.
- **`cd <worktree> && …` permission matching** (spec-review note). `ALLOW` carries `Bash(cd *)` from the first run; S3 settles it, with one fallback (`git -C` plus absolute paths in the prompt, with scoped per-family rules). The result goes to prompt 05's permission proposal.
- **Writes inside `.aew/runs/<id>/worktrees/` denied as sensitive.** This was seen only inside the plugin tree (prompt 03), and `$SMOKE` sits outside it. If it appears anyway, it is a platform fact that changes A10's worktree location. Stop with `DONE_WITH_CONCERNS`, because the path is a fixed spec contract.
- **A test runner sees worktree copies.** Worktrees are removed before the post-integration checks (DD-5), and DD-6 skips the checks while one is left.
- **DD-6's forced clean-up of stale worktrees** at the start of a later full-mode dispatch discards a blocked attempt's uncommitted work. The attempt's `06-dev-report-WP<n>.md` and the senior's revised plan supersede it. Flagged.
- **Gate behaviour with siblings.** A malformed sibling report can cost a sub-developer one corrective turn (never a lasting block, because of `stop_hook_active`), and a report-less sub-developer can pass on a sibling's report. The parent's DD-5 checks catch the second case. S10 and S11 observe it live, and D3 is the planned fallback.
- **Cost.** Three Sonnet sessions in one run. Cap $10, one raise to $20, within the shared $60 stop.
- **Shared files with parallel phases.** DESIGN §3 is also edited by Phase A (Playwright names) and §11 possibly by D3. The README is also edited by Phases C and E. Phase D adds separate bullets and its own README part, so a merge needs no rewording (see Cross-phase notes).

## Cross-phase contracts and notes for the consolidator

- **For Phase E (951 fix run, 971 gate run) and prompt 05.** Use the Interface contract above: the dispatch fields per mode, the report names and `Mode:` lines, the commit format, the return semantics and the Bash allowlist. In fix mode, E's `ALLOW` adds `Bash(curl *)`, `Bash(lsof *)` and `Bash(kill *)`. E must still run `state.sh bump fix_cycle` before the fix dispatch, so that the gate's freshness rule holds.
- **For prompt 05 (orchestrator).** DD-3 requires a clean working tree in `full` and `fix` mode, so the orchestrator must commit the standards-setter's `docs/standards/` output (A14) before the `develop` dispatch, or the developer returns `blocked`.
- **For Phase E's report-less developer run (971).** The developer writes its report on every outcome (DD-12). A report-less stop therefore needs dispatch wording that explicitly overrides that rule. The expected pass is the gate's `block` naming the missing `06-dev-report*.md`, followed by the corrective turn writing it.
- **For Phase A (ui-qa).** Fix mode starts the app through `aew:ui-qa` (invoked with the Skill tool). Its app-start section must use only `app.start_command`, `curl` (ready check), `lsof -ti tcp:<port>` and `kill <pid>`, or the developer's allowlist and E's `ALLOW` line must change with it.
- **For Phase B** (matches B's contract: #202 "Add shop helpers", branch `feat/202-add-shop-helpers`, WP-1 `site/format-price.js` + `tests/unit/format-price.test.js`, WP-2 `site/clamp-quantity.js` + `tests/unit/clamp-quantity.test.js`, 3 tests after integration). D2 relies on: `run-fanout/02-brief.md` with the H1 `# Brief: #202 <title>`; `run-fanout/05-plan.md` with exactly `### WP-1:` and `### WP-2:` blocks, both `parallelisable: yes` and `depends_on: []`, whose files are listed as `  - create: <path>` lines (one new `site/` module plus its unit test each, disjoint); `run/03-standards.md`; a fixture `.aew/config.json` with `commands.test_unit: node --test`; and `.gitignore` listing `.aew/runs/`. B's harness note on `run/03-standards.md` (its title says #201) is met by D1's prompt: the developer reads `03-standards.md` for its section list and doc paths, and never blocks on a title mismatch.
- **README ownership (DD-16, consolidator decision).** C4 owns the single `smoke_shop <agent> <case> <run-id> <issue> <title> <branch> <stage>` helper (plus `SHOP` and `SHOP_RUN`), and A2 owns `## 8. Build agents (prompt 04)` with `### 8.1 Spend ledger` (stop at $60) and `### 8.2 Playwright MCP tool names`. D2 depends on both, defines no helper and appends its rows. Requirement on C4: keep installing dependencies before the fixture commit, so that `git status --porcelain` is clean after the helper (DD-3's clean-tree precondition and S7/S8 rely on it). D2 needs nothing else from it.
- **For prompt 05 and the senior engineer (DD-17).** A revised plan after a developer `blocked` keeps the numbers (and the file lists) of the WPs that are already integrated. The developer skips those WPs by matching the previous `06-dev-report.md` (`Mode: full`) against `<default_branch>..HEAD`, and returns `blocked` if a done WP's files changed.
- **DESIGN.md edits by D.** §3 Nesting (extended), §3 Worktree isolation (new bullet), the §8.5 sentence (D1), the §3 nested-`SubagentStop` fact (D2), and §11 only if D3 runs. Phase E's closing task records these as already present and does not re-add them.

## Phase approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T20:09:10Z (plan-diff-review of the revision round)
- M1 resolved: DD-17 plus Mode: full step (3) plus the prompt-05/senior-engineer cross-phase note; earlier mechanical fixes intact.
- Mechanical fix applied in this review: D2 (and the phase line) now also depend on C6, because C5 and C6 edit `tests/agent-smoke/README.md` and share the $60 ledger (Phase C PC-10 serialises C4 → C5 → C6 → D2).
- Plan dependency graph: valid (no cycles: C4, C5, C6, A2 and A3 depend on no D task).
- Plan content hash (SHA-256, before this note): 14138cb47e79c82d180852f883c6365b8131b6c61a00c30e334bf70ab747aebe
