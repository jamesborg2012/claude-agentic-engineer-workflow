# Phase B plan — the ship orchestrator

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583…6090`), overridden where they differ by the CTO simplicity-challenge cuts (2026-10-25, all adopted). The cuts that bind this phase are **7** (preflight checks the default branch but does not fast-forward, and writes nothing), **8** (one rule for a plan `needs_input`) and **10** (DESIGN §9 only points at `skills/ship/references/`, so the preflight order and the reads table must live here in full).
- **Phase:** B of the EPIC. `depends_on: []`. Phase C (`resume`, `prompt`) Reads this phase's `SKILL.md` and references and enters them at the named sections. Phase E's `tests/scripts/skills.bats` greps the strings in the interface contract. Phase F's allowlist and expected `gh` call order come from contract I-8 and I-9. Phase A's senior-engineer `notes` field is used here as a single dispatch line (I-10).
- **Depth:** full
- **ACs covered:** AC-1 to AC-20. AC-3.4 and AC-14 as amended by cuts 7 and 8.
- **Risk:** none of the risky criteria. The files are Markdown procedures with no runtime effect until a user types `/aew:ship`, and nothing exercises them live before phase F.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" means the spec's assumption n, "AC-n" the spec's ACs, and "cut n" the CTO simplicity cut n. Task ids are `B1`–`B8`, dispatch rows are `D1`–`D13` (contract I-4), and plan-level decisions are `PD-1`–`PD-14`. These number ranges are unrelated to each other.

> **For agentic workers:** implement task by task. These are documentation tasks, so each task's RED is a check that fails before the change (the file is absent, or a grep count is 0) and its GREEN is the same check passing. Record both outputs in the task report. Write the skill text from the outlines below. The headings, gate ids, note formats, error strings, table formats and commands marked **verbatim** are contracts: copy them exactly. Everything else is content to write in your own words, in British English, with the same rules.

**Goal:** a main-thread `ship` skill that takes one issue through DESIGN §7.3. It parses `$ARGUMENTS`, runs the §9 preflight, starts or restarts the run, dispatches each agent with explicit file inputs, reads only return blocks and the bounded sections a gate or routing decision needs, and runs the two gates, the review loop, the QA loop, the blocked path, the PR steps and the final report. Each stage gets its own section, so `resume` can enter it by name.

**Architecture:** one procedure file, `skills/ship/SKILL.md` (frontmatter, rules, the reads table, Steps 1–4, ten `## Stage:` sections, and the gate-pending, blocked and final-report exits), plus six reference files, each read at the step that needs it. All paths are absolute `${CLAUDE_PLUGIN_ROOT}/…` paths. Only `SKILL.md` is substituted when it loads (V-5), so it states the root once and tells the reader to map the literal `${CLAUDE_PLUGIN_ROOT}` in the references to it. No script, hook, agent or template changes in this phase. The commands the references give (the `jq` render, the `awk` section reads, the return-block check) were dry-run against the templates while this plan was written (see PD-6 and the B3/B4/B5 notes).

**Tech stack:** Markdown skill files; bash 3.2, jq 1.7.1, awk (BSD) for the inline commands; `claude plugin validate .`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` | AC-1–20, Assumptions 2–5, 9–20, 28, Conflicts C2 and C4, V-1, V-3, V-4, V-5, V-6 |
| CTO cuts (scratchpad `simplicity-adopted.md`) | Cuts 7, 8 and 10 (above) |
| `skills/run-protocol/SKILL.md`, `references/state-machine.md` | Stage→label mapping, gates table, failure paths, the `qa_failures_complete` rule, counters and cycle-file naming. `routing.md` and `gates.md` restate them as procedure and link back for the diagram |
| `skills/github-ops/SKILL.md` | Every script call, the spec-revision recording order, "check `state.pr` before create", "write state before each developer dispatch" |
| `scripts/{state,gh-issue,gh-labels,git-branch,gh-pr,gh-retro}.sh --help` | Script contracts. Notes: `state.sh init` sets stage `spec_analysis`, status `running`, `base_branch` = config `default_branch`, and refuses an existing `state.json`; `stage` always sets status `running`; `git-branch.sh create` refuses a dirty tree (untracked files count) or an existing branch; `gh-pr.sh create` prints the PR number |
| `scripts/hooks/gate-subagent.sh` (`valid_return_block`, `gate_developer`, `gate_qa`) | The return-block rule (the last four **non-blank** lines), the developer freshness check (`state.json -nt` the newest report), and the QA gate's `08-qa-report-<fix_cycle+1>.md` name |
| `agents/*.md` Inputs and Return contract sections | Dispatch fields and required files (dispatch table I-4); the review verdict is the first word of SUMMARY; triage NEXT names "developer (fix mode)" and/or "qa-engineer"; triage `needs_input` carries "the question and your recommended answer" with no dedicated section (PD-12); spec-analyser's re-run records answers against question ids |
| `templates/artefacts/{spec-analysis,plan,qa-report,triage,summary,manual-tests,spec-revision-comment}.md`, `spec-changes.example.json` | The sections the bounded reads target (`## Questions` / `### Q<n>.`, `## Challenges to the spec`, the `## Failures` triage table and the `### <TC>:` entries, `- [x] AC-n`, `- [ ] **TC-n`), and the revision comment the `jq` render reproduces |
| `templates/config.schema.json` | `limits` defaults 3 (fix) and 2 (review), `gates.plan_approval` default `true`, `default_branch` default `main` |
| `docs/superpowers/plans/phases/2026-10-24-build-agents-phase-A.md` | Format mirrored here |

Gotchas that apply (from `docs/superpowers/project-map.md`): `${CLAUDE_PLUGIN_ROOT}` is not in the Bash tool's environment, so the model writes the substituted absolute path into each command; the developer gate compares at whole-second resolution, so the state write goes immediately before every developer dispatch; the Bash safety hook blocks any command whose text contains `git push` (`git-branch.sh push` does not contain it); `grep -c` exits 1 when the count is 0; agents with `memory: project` write `.claude/agent-memory/aew-<agent>/` into the target project during a run (PD-2).

## Plan-level decisions (each one is a refinement the spec leaves open; flag if wrong)

- **PD-1 Pending-gate representation.** Every gate writes its pending status with a note in a fixed format: `state.sh status <awaiting_input|awaiting_plan_approval> --note "gate:<gate-id> <source file>"`. `resume` finds the gate with one `jq` read of `history` (contract I-5). There is no new schema field: `state.sh` already stores `--note` in `history`.
- **PD-2 Agent memory.** spec-analyser, standards-setter, senior-engineer, qa-engineer and doc-writer write `.claude/agent-memory/aew-<agent>/` into the project during a run (seen in smoke run 951). Left alone, this makes every later `--from`, resume and fresh ship fail the clean-tree check. Ship therefore (a) commits `.claude/agent-memory/` once, after the docs commit (`chore(aew): update agent memory (#<n>)`), and (b) for `--from` (and Phase C's resume) treats the tree as clean when the only changes are under `.claude/agent-memory/`. A fresh run still needs a fully clean tree, because `git-branch.sh create` counts untracked files.
- **PD-3 Developer `blocked`.** A full-mode developer `blocked` re-plans once (AC-12). Each re-plan writes the note `developer blocked: re-plan`, and a second full-mode `blocked` is detected from `history`, so the count survives a resume. A `blocked` from **fix mode** (review fix or QA fix) goes to the blocked path, because re-planning a finished build in the middle of a loop is not what AC-12 describes.
- **PD-4 Answers to questions spec-analyser did not ask.** These come from plan challenges, triage and spec-ambiguity. They go to spec-analyser as new ids that continue its numbering, with the question text inline: `Q<k>: <question> => <answer>`. Untested live in this prompt (prompt 07 covers it). If spec-analyser refuses such answers, the fix is one Inputs line in `agents/spec-analyser.md`.
- **PD-5 The develop stage picks its mode from `review_cycle` and file age.** Fix mode needs both `review_cycle = k ≥ 1` **and** `test <rd>/07-review-<k>.md -nt <rd>/05-plan.md`. Then it is `mode: fix`, `fix_from: 07-review-<k>.md`, `n: k`; otherwise `mode: full`. A re-plan rewrites `05-plan.md`, which makes the last review older than the plan, so the next develop is full. The review loop bumps the counter and enters `## Stage: develop`, so in-session flow, `--from develop` and resume all take the same path and reach the same mode. Resume at `qa` simply re-dispatches QA phase B, as AC-21 says ("re-dispatching that stage").
- **PD-6 `jq` and `false`.** `jq '.gates.plan_approval // true'` returns `true` for an explicit `false`, so the plan gate reads it as `jq -r 'if .gates.plan_approval == false then "off" else "on" end'` (dry-run: `{"gates":{"plan_approval":false}}` gives `off`, `{}` gives `on`).
- **PD-7 Return check.** The check reads the last four **non-blank** lines (`awk 'NF' <file> | tail -n 4`), which is `valid_return_block`'s rule. A plain `tail -n 4` would fail on a trailing blank line. For the Agent result, the model checks the last four non-blank lines of the text it received.
- **PD-8 Spec-revision recording is idempotent.** Recording runs only when `spec-changes.json` has at least one change **and** its `version` is greater than `state.spec_revision`, so a resumed or repeated `ok` never re-posts.
- **PD-9 Script failures.** A plugin script that exits non-zero after the run has started goes to the blocked path, with its first stderr line as the reason. There are three exceptions: a fetch failure or a closed issue during run start (`failed`, then `current` cleared, AC-4); `gh-retro.sh` (warn only, AC-16); and `gh-labels.sh` when a label is missing (blocked path, with "run `/aew:init`" added to the reason, Assumption 14).
- **PD-10 Default branch ahead of origin only** (cut 7 covers behind and diverged): warn that the PR will include the unpushed commits, then continue. A missing local default branch stops the run with a `git switch <default>` hint.
- **PD-11 Stopping at the plan gate.** `state.sh status failed`, then `current` cleared. The stage label stays `awaiting-approval` (the label set has none for `failed`), and the final report says so. Recorded for prompt 07.
- **PD-12 Triage `needs_input` questions.** The triage template has no Questions section, so the gate reads `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md`, a bounded read added to AC-19's list.
- **PD-13 Slug.** One `jq` expression: lower-case the title, turn runs of anything other than `[a-z0-9]` into `-`, trim the ends, cut to 40 characters and trim again, with `issue-<n>` as the fallback (dry-run: `Add to basket: fix £ totals!! ` gives `add-to-basket-fix-totals`).
- **PD-14 Commits the orchestrator makes** stage explicit paths only (`git add -- <paths>`), never `-A` or `.`. The docs commit takes the doc-writer's ARTEFACTS paths that are outside `.aew/`.

## Interface contract (Phases C, E and F rely on this)

### I-1. `skills/ship/SKILL.md` frontmatter (verbatim)

```yaml
---
name: ship
description: Ship one GitHub issue through the aew pipeline - spec analysis, brief, standards, QA plan and plan in parallel, the plan gate, development, review, QA with triage, docs and a pull request. Run it as /aew:ship <issue> [--auto] [--from <stage>].
disable-model-invocation: true
argument-hint: "<issue> [--auto] [--from <stage>]"
---
```

There is no `allowed-tools`, no `` !`cmd` `` injection, no `$N` or `$ARGUMENTS[N]`, and exactly one `$ARGUMENTS` (in Step 1). When `resume` reads the file with Read, nothing in it is substituted or run (AC-1).

### I-2. `SKILL.md` headings, in this order (verbatim; each occurs exactly once)

```
# aew ship
## Plugin root
## Rules
## Run variables
## What the orchestrator reads
## References
## Step 1. Parse the arguments
## Step 2. Preflight
## Step 3. Start the run
## Step 4. Restart at a stage (--from)
## Stage: spec_analysis
## Stage: brief
## Stage: standards
## Stage: qa_test_plan
## Stage: plan
## Stage: develop
## Stage: review
## Stage: qa
## Stage: docs
## Stage: pr
## Gate pending
## Blocked path
## Final report
```

- Each `## Stage: <stage>` section has numbered steps, and **step 1 is always Entry** (the state write and the label). Later steps are Dispatch, Check, Exit and Failure. `## Stage: qa_test_plan` is a two-line section: "`qa_test_plan` and `plan` are one step. Go to `## Stage: plan`."
- **How Phase C enters** (resume): Read this file and the references it names, skip Steps 1–4 (`resume` does its own branch and tree checks, and takes the issue, `auto` and counters from `state.json` via `## Run variables`), then enter `## Stage: <state.stage>` at step 1 with the note `resume`. For `awaiting_input` or `awaiting_plan_approval`, enter `gates.md` `## Re-asking a pending gate` instead (I-5).
- **How Phase C enters** (prompt): `## Step 3. Start the run` sub-steps 3.1–3.5 (existence check, `state.sh init`, fetch, closed check, title), skipping 3.6–3.8 (label, branch, stage entry). Straight after 3.2 it writes the I-11 `prompt` marker (`state.sh stage spec_analysis --note "prompt"`); without it, a resumed prompt run would continue into ship's D3. Then `gates.md` `## Gate: spec` and `## Recording a spec revision` under the prompt-mode rule in I-5, and dispatch rows D1, D2 and D4 (I-4). Phase C uses preflight checks 1, 3 and 5 by their headings (I-3).

### I-3. Reference files: what each covers, and its headings (verbatim)

| File | Headings | Read at |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/preflight.md` | `## Check 1. Config exists`, `## Check 2. Clean working tree`, `## Check 3. gh is authenticated`, `## Check 4. Default branch up to date`, `## Check 5. No other active run`, `## Check 6. superpowers major version (warn only)`, `## Restart checks (--from)` | Step 2, Step 4 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/dispatch.md` | `## How to dispatch`, `## Dispatch table`, `## Required inputs per stage`, `## Return check`, `## Retries` | every Stage section |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/gates.md` | `## Gate ids and pending state`, `## Asking`, `## Gate: spec`, `## Gate: plan-challenge`, `## Gate: triage`, `## Gate: spec-ambiguity`, `## Gate: plan-approval`, `## Recording a spec revision`, `## Re-asking a pending gate`, `## Destructive operations` | spec_analysis, plan, qa; resume |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/routing.md` | `## Stage table`, `## Agent status routing`, `## Review loop`, `## Developer blocked`, `## QA loop`, `## Cycle limits`, `## Script failures` | every Stage section |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/pr.md` | `## Commit rules`, `## Standards commit`, `## Docs and memory commits`, `## Push and pull request`, `## Manual tests`, `## Retro`, `## Finish` | standards, docs, pr |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/final-report.md` | `## Format`, `## Counting`, `## Blocked and failed runs` | Final report |

Each `## Gate: <id>` section has four numbered steps: **1. Set pending** (state and label), **2. Read** (the bounded source read), **3. Ask**, **4. Apply the answer**. Each `## Check n.` section gives the command, the pass condition and the exact stop (or warning) message.

### I-4. Dispatch rows (`dispatch.md` `## Dispatch table`; ids are cited from `SKILL.md` and `routing.md`)

Table columns (verbatim header): `| Row | Agent and mode | subagent_type | Prompt fields | Required files | State write before |`. `<rd>` is `.aew/runs/<id>`, relative to the project root.

| Row | Agent and mode | subagent_type | Prompt fields | Required files (`test -f`) | State write before |
|---|---|---|---|---|---|
| D1 | spec-analyser, first run | `aew:spec-analyser` | `run_dir`, `spec_version: <spec_revision+1>` | `00-issue-original.md`, `issue.json` | Step 3 (fresh) or stage entry `spec_analysis` |
| D2 | spec-analyser, re-run with answers | `aew:spec-analyser` | `run_dir`, `spec_version: <spec_revision+1>`, `answers:` then one `Q<k>: …` line per answer | the above plus `01-spec-analysis.md` | `state.sh stage spec_analysis --note "answers: gate:<id>"` |
| D3 | brief-compiler, pipeline | `aew:brief-compiler` | `run_dir`, `mode: pipeline` | `spec-final.md`, `issue.json` | stage entry `brief` |
| D4 | brief-compiler, prompt (used by `prompt`) | `aew:brief-compiler` | `run_dir`, `mode: prompt` | `spec-final.md`, `issue.json` | `state.sh stage brief` (prompt mode sets no label; Phase C) |
| D5 | standards-setter | `aew:standards-setter` | `run_dir` | `02-brief.md` | stage entry `standards` |
| D6 | qa-engineer, phase A | `aew:qa-engineer` | `run_dir`, `phase: A` | `02-brief.md`, `03-standards.md` | stage entry `plan` (one write for D6 and D7) |
| D7 | senior-engineer, plan | `aew:senior-engineer` | `run_dir`, `mode: plan`, optional `notes: <one line>` | `02-brief.md`, `03-standards.md` | stage entry `plan` |
| D8 | developer, full | `aew:developer` | `run_dir`, `mode: full` | `05-plan.md`, `02-brief.md`, `03-standards.md` | stage entry `develop` (immediately before) |
| D9 | senior-engineer, review | `aew:senior-engineer` | `run_dir`, `mode: review`, `n: <review_cycle+1>`, `base: <base_branch>` | `02-brief.md`, `05-plan.md`, `03-standards.md` | stage entry `review` |
| D10 | developer, fix | `aew:developer` | `run_dir`, `mode: fix`, `fix_from: <file>`, `n: <k>` | the `fix_from` file | stage entry `develop` (review fix) or `state.sh stage qa --note "fix <k>: developer"` (QA fix), immediately before |
| D11 | senior-engineer, triage | `aew:senior-engineer` | `run_dir`, `mode: triage`, `n: <k>` | `08-qa-report-<k>.md` | the `bump fix_cycle` of the QA loop |
| D12 | qa-engineer, phase B | `aew:qa-engineer` | `run_dir`, `phase: B`, `n: <fix_cycle+1>`, optional `triage: <rd>/09-triage-<k>.md` | `02-brief.md`, `04-qa-test-plan.md` | stage entry `qa` (first pass) |
| D13 | doc-writer | `aew:doc-writer` | `run_dir` | `spec-final.md`, `issue.json`, `state.json` | stage entry `docs` |

standards-setter `mode: init` is **not** in this table: init dispatches it, and Phase D owns that row.

### I-5. Gates: ids, pending state and re-asking

- Gate ids (verbatim): `spec`, `plan-challenge`, `triage`, `spec-ambiguity`, `plan-approval`.
- Pending writes (verbatim formats):

  | Gate | Status write | Label write (verbatim) | Bounded read (step 2) |
  |---|---|---|---|
  | `spec` | `state.sh status awaiting_input --note "gate:spec 01-spec-analysis.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Questions` of `01-spec-analysis.md` |
  | `plan-challenge` | `state.sh status awaiting_input --note "gate:plan-challenge 05-plan.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Challenges to the spec` of `05-plan.md` |
  | `triage` | `state.sh status awaiting_input --note "gate:triage 09-triage-<k>.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md` |
  | `spec-ambiguity` | `state.sh status awaiting_input --note "gate:spec-ambiguity 08-qa-report-<k>.md"` | `gh-labels.sh stage <n> awaiting-input` | the triage table and the `### TC-<n>:` entries classed `spec_ambiguity` |
  | `plan-approval` | `state.sh status awaiting_plan_approval --note "gate:plan-approval 05-plan.md"` | `gh-labels.sh stage <n> awaiting-approval` | `05-plan.md` in full |

- Pending gate lookup (verbatim command; `resume` uses it): `jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' .aew/runs/<id>/state.json`. `## Re-asking a pending gate` maps the note's gate id to its `## Gate: <id>` section and says to enter it **at step 2** (state and label are already set).
- Unanswered gate (AC-10): AskUserQuestion not among the tools, refused, or an empty answer → `SKILL.md` `## Gate pending`, which prints the questions (or the plan summary and path), then the line `Answer with /aew:resume <id>` (verbatim), then stops.
- Prompt-mode rule (verbatim sentence in `## Gate ids and pending state`): "In prompt mode (`/aew:prompt`), skip every `gh-labels.sh stage` call in this file and keep the `gh-labels.sh flag` call."

### I-6. `routing.md` `## Stage table` format (Phase E checks it)

- Header (verbatim): `| Stage | Entry | Exit | Failure |`, then the separator `|---|---|---|---|`.
- Ten rows, one per schema stage, in schema order. Each row starts with the backticked stage name, for example `` | `spec_analysis` | ``.
- **No literal `|` inside any cell** (use "or" or `∥`), so a split on `|` gives exactly 4 cells. Every cell is non-empty. The `qa_test_plan` row's cells may read "as `plan` (one step)".

### I-7. Strings Phase E's static checks grep for (all in `skills/ship/SKILL.md` unless named)

- AC-2 error lines (verbatim prefixes and fragments): `aew ship: missing issue number.` · `must be a positive integer` · `/aew:ship-milestone` · `unknown option` · `given more than once` · `unexpected argument` · `--from needs a stage` · `unknown stage` · the stage list `spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr` · the usage line `Usage: /aew:ship <issue> [--auto] [--from <stage>]`.
- The ten `## Stage: <stage>` headings (I-2), and the reads table heading `## What the orchestrator reads`.
- Frontmatter lines `disable-model-invocation: true` and `argument-hint: "<issue> [--auto] [--from <stage>]"`.
- **Name hygiene for the existence checks** (AC-38):
  - every `${CLAUDE_PLUGIN_ROOT}/…` path in `skills/ship/**` names a real file or directory, with no `<placeholder>` inside the path;
  - every `aew:<name>` is an agent used as `subagent_type` (`aew:spec-analyser`, `aew:brief-compiler`, `aew:standards-setter`, `aew:qa-engineer`, `aew:senior-engineer`, `aew:developer`, `aew:doc-writer`) or a slash command (`/aew:ship`, `/aew:resume`, `/aew:init`, `/aew:status`, `/aew:prompt`, `/aew:ship-milestone`);
  - labels are always written bare (`gh-labels.sh stage <n> blocked`, "the `blocked` label"), never as `aew:<label>`;
  - **`/aew:ship-milestone` is a forward reference** (prompt 06), and Phase E must allow it explicitly.

### I-8. Commands ship runs (Phase F's allowlist union; Phase D's permission proposal)

The commands are given with `<placeholders>` that the orchestrator fills in, and with no shell variables, so each command matches an anchored rule. `<root>` is the substituted plugin root.

- Plugin scripts by absolute path: `<root>/scripts/state.sh …`, `gh-issue.sh …`, `gh-labels.sh …`, `git-branch.sh create|push`, `gh-pr.sh create|update …`, `gh-retro.sh file …`.
- `gh auth status` (exact; the only direct `gh` call, Assumption 9) and `claude plugin list --json` (exact, piped into `jq`).
- git: `git status --porcelain` (with an optional `-- <path>`), `git status --porcelain --untracked-files=all` (both forms of preflight Check 2), `git fetch origin <default>`, `git rev-parse --verify --quiet refs/heads/<default>`, `git rev-list --left-right --count <default>...origin/<default>`, `git branch --show-current`, `git switch <branch>`, `git add -- <paths>`, `git commit -m <msg>`.
- Read-only helpers: `jq …`, `awk …`, `tail -n 4`, `test -f|-d|-e …`, `test <file> -nt <file>` (PD-5), `grep -c …`, `cat .aew/runs/current`, `ls .aew/runs/<id>`.
- Blocked comment: `mktemp -t aew-blocked`, then `cat > <tmpfile> <<'EOF' … EOF`.
- The `spec-revision-v<N>.md` render: `jq -r '…' <rd>/spec-changes.json > <rd>/spec-revision-v<N>.md`.

### I-9. Script-call order on a clean `--auto` run (Phase F writes the S1 expected `gh` routes from this)

`gh auth status` → `state.sh init` → `gh-issue.sh fetch` → `state.sh set title` → `gh-labels.sh stage analysing` → `git-branch.sh create` → `state.sh set branch` → spec-analyser → [if changes: `gh-issue.sh revise`, `gh-issue.sh comment`, `gh-labels.sh flag add spec-revised`, `state.sh set spec_revision`] → `gh-labels.sh stage planning` (at brief; the standards and plan entries repeat it as no-ops) → [standards commit] → `gh-labels.sh stage building` (develop; review repeats it) → `gh-labels.sh stage testing` → [a fix cycle changes no label] → `gh-labels.sh stage documenting` → [docs and memory commits] → `git-branch.sh push` → `gh-pr.sh create` → `state.sh set pr` → [if manual tests: `gh-issue.sh manual-tests`, `gh-labels.sh flag add manual-test-required`] → `gh-retro.sh file` → `gh-labels.sh stage ready-for-review` → `state.sh status done` → `state.sh current clear`.

### I-10. Cross-phase field formats

- `notes:` (Phase A's senior-engineer field) is **one line** and the **last** field of the D7 prompt (Phase A C-1 allows several lines; one line is a compatible subset): James's notes, joined with ` / `, or `developer blocked: <the developer's SUMMARY> / <the dev report path>` (the C-1 developer source: reason plus report path).
- `answers:` is a line of its own, followed by one `Q<k>: <answer>` line per answer. Questions spec-analyser did not ask are written `Q<k>: <question> => <answer>`, with k continuing after the highest `### Q<n>.` in `01-spec-analysis.md` (PD-4).

### I-11. Run markers in `history` (written with `--note`, read with `jq`; they survive a resume)

| Marker (verbatim note) | Written by | When | Read by | Check (verbatim) |
|---|---|---|---|---|
| `prompt` | the `prompt` skill (Phase C) | `state.sh stage spec_analysis --note "prompt"`, straight after its `state.sh init` (3.2) and before the fetch | `gates.md` `## Gate: spec` step 4 and `## Re-asking a pending gate`; Phase C's `resume` (a prompt run hands back to the `prompt` skill, never to ship's D3) | `jq -r 'if ([.history[] \| select(.note == "prompt")] \| length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json`: `prompt` means a prompt-mode run. The `.branch == null` half is part of the check, owned here and used unchanged by Phase C: a prompt run never has a branch, and `/aew:ship <n> --from spec_analysis` (the only way to turn a prompt run into a ship run; restart checks refuse any other stage while `branch` is null) sets `branch` in Step 4.5 before any dispatch, so the converted run reads `ship` and is never handed back to `prompt` |
| `spec-ambiguity: non-material` | ship, `gates.md` `## Gate: spec-ambiguity` step 4 | the note on the `brief` Entry after a non-material answer | `SKILL.md` `## Stage: brief` exit | `jq -r '.history \| (map(.note == "spec-ambiguity: non-material") \| indices(true) \| last) as $i \| if $i == null then "no" elif (.[$i+1:] \| any(.stage != "brief")) then "no" else "yes" end' .aew/runs/<id>/state.json`: `yes` → `## Stage: qa` |

(Inside this table the `\|` stands for a literal `|` in the command.) Both checks were dry-run while revising: a history ending in the non-material note followed only by `brief` entries (`blocked`, `resume`) gives `yes`; with a later `qa` entry, or with no marker, it gives `no`; the prompt-mode check gives `prompt` for a marker with `branch` null, and `ship` once `branch` is set or with no marker (re-run while reviewing). "Prompt mode" anywhere in ship's files means this check prints `prompt`; neither ship nor Phase C tests the marker on its own.

## Tasks

Waves: **1** = B1 · **2** = B2 ∥ B3 ∥ B4 ∥ B5 ∥ B6 ∥ B7 (each writes one reference file and shares no text with the others; they agree only through contracts I-3 to I-6) · **3** = B8.

Commit trailer for every task: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. It applies to this repo's commits only. The orchestrator's own commits in target projects add no trailer (Assumption 28).

---

### Task B1 — `skills/ship/SKILL.md`, the procedure

- **id:** B1
- **files:** `skills/ship/SKILL.md` (new)
- **depends_on:** []
- **pattern:** frontmatter and numbered-section style from `skills/ui-qa/SKILL.md`; the stage list and failure rules from `skills/run-protocol/SKILL.md` "Stages". The procedure itself has no analog in the repo (spec: NOVEL).
- **ACs:** AC-1, AC-2, AC-4, AC-7 (the one-message rule), AC-10 (`## Gate pending`), AC-12/AC-11/AC-13 (summarised; detail in B5), AC-15, AC-18, AC-19, plus the skeleton every other AC hangs off
- **Size:** about 330–420 lines. **Hard limit 499.**

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
test -f skills/ship/SKILL.md; echo $?                       # 1
```

**Step 2: write `skills/ship/SKILL.md`** with the frontmatter in I-1 and the headings in I-2, in order. Content per section:

- `# aew ship`: two sentences. This is the main-thread orchestrator for one issue. It is the only part of aew that touches GitHub, and only through the plugin scripts. Agents are dispatched with explicit inputs, and only their return blocks are read.
- `## Plugin root`:
  - "The plugin root is `${CLAUDE_PLUGIN_ROOT}`." (substituted when the skill loads).
  - The scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Call each one by its absolute path, written out in the command, because the Bash tool has no `CLAUDE_PLUGIN_ROOT` variable. In this file and the references, a bare `state.sh …` (or `gh-issue.sh …` and so on) means that absolute path. Never write a `<placeholder>` inside a `${CLAUDE_PLUGIN_ROOT}/…` path (I-7).
  - The references are read with Read and are **not** substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above.
  - A skill that reads this file with Read (`resume`, `prompt`) states the root itself, and the same rule applies to this file.
- `## Rules` (bullets):
  - run every command from the project root and never `cd`;
  - never run `gh` except `gh auth status` in preflight;
  - never run git's push, merge, rebase, reset or force forms; push only with `git-branch.sh push`;
  - stage explicit paths only (PD-14);
  - never edit an artefact, `state.json` or `log.md` (scripts own state). The only files ship writes are `spec-revision-v<N>.md` (the `jq` render), the blocked-comment temp file and the commits in `pr.md`;
  - read only what `## What the orchestrator reads` lists;
  - every developer dispatch comes straight after a `state.sh` write in the same step (the developer gate's freshness check);
  - one agent per Agent call, except the planning pair;
  - an invalid return counts as `failed`; a failed dispatch is retried once in this session, then the blocked path;
  - script failures follow `routing.md` `## Script failures` (PD-9);
  - write labels bare (I-7);
  - a gate's answer comes only from AskUserQuestion on the main thread: never from an agent, and never invented.
  - **Citation form** (used in this file and in every reference, and checked by B8): a section of another file is cited as `` `<file>.md` `## <heading>` ``, for example `` `gates.md` `## Gate: spec` `` or `` `SKILL.md` `## Stage: develop` ``, with the file name in backticks, one space, then the exact heading in backticks.
- `## Run variables`: where each value comes from, read fresh before each use.
  - `<id>` and `<n>`: the run id and the issue number (the same number in single mode).
  - `<rd>`: `.aew/runs/<id>`.
  - `auto`, `review_cycle`, `fix_cycle`, `spec_revision`, `branch`, `base_branch`, `pr`, `stage`, `status`: `state.sh get <field>`.
  - Limits: `jq -r '.limits.max_review_cycles // 2' .aew/config.json` and `jq -r '.limits.max_fix_cycles // 3' .aew/config.json`.
  - Plan gate: the PD-6 expression.
  - `<default>`: `jq -r '.default_branch // "main"' .aew/config.json`.
  - Say once that `resume` takes all of these from `state.json`.
  - Say once that after `state.sh current clear` (run-start failures, the plan-gate stop, `## Finish`) `state.sh get` fails, so any later read uses `jq -r .<field> .aew/runs/<id>/state.json`.
- `## What the orchestrator reads` (AC-19; table `| Read | When | How |`). Rows:
  - the Agent return block (every dispatch; the last four non-blank lines of the result);
  - ARTEFACTS paths and required inputs (`test -f`), and the develop-mode age check (`test <rd>/07-review-<review_cycle>.md -nt <rd>/05-plan.md`, PD-5);
  - each named developer report (`awk 'NF' <file> | tail -n 4`);
  - `05-plan.md` (plan gate; **the only full read**);
  - `## Questions` of `01-spec-analysis.md` (gate `spec`);
  - `## Challenges to the spec` of `05-plan.md` (gate `plan-challenge`);
  - `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md` (gate `triage`, PD-12);
  - the triage table of `08-qa-report-<k>.md`, and of `<k-1>` for the repeat check (QA loop);
  - the `### TC-<n>:` entries classed `spec_ambiguity` (gate `spec-ambiguity`);
  - `state.json` (`state.sh get`, or `jq` for `history` notes);
  - `.aew/config.json` fields (`jq`);
  - `spec-changes.json` (`jq` counts and render to a file only);
  - `issue.json` (`jq` for `title`, `state` and `url`);
  - `10-summary.md` and `manual-tests.md` (`grep -c`).
  - Closing line: "Nothing else. Never open other artefacts, and never read source code." Then one sentence on the C2 clarification: bounded section reads are not full reads.
- `## References`: the I-3 table, with full `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/<file>` paths (real file names, no placeholder), plus `${CLAUDE_PLUGIN_ROOT}/skills/run-protocol/references/state-machine.md` for the diagram and `${CLAUDE_PLUGIN_ROOT}/skills/github-ops/SKILL.md` for script output contracts.
- `## Step 1. Parse the arguments` (AC-2):
  - "The arguments are: `$ARGUMENTS`" (the only placeholder).
  - Split on whitespace. Nothing in this step runs a command or writes anything. The first error wins. Print the error line, then the usage line `Usage: /aew:ship <issue> [--auto] [--from <stage>]`, then stop.
  - Algorithm, in order:
    1. no tokens → E1;
    2. first token `^m-[0-9]+$` → E3; `^[1-9][0-9]*$` → the issue; starts with `--` → E1; otherwise → E2;
    3. each later token from left to right: `--auto` (a second one → E5); `--from` (a second one → E5; no next token, or a next token starting with `-` → E7; a next token not among the ten stages → E8; otherwise that token is the stage); any other token starting with `-` → E4; anything else → E6.
  - Error lines (**verbatim**, `<…>` filled in):
    - E1 `aew ship: missing issue number.`
    - E2 `aew ship: the issue must be a positive integer, got "<token>".`
    - E3 `aew ship: "<token>" is a milestone; milestone runs use /aew:ship-milestone (coming in a later release).`
    - E4 `aew ship: unknown option "<token>".`
    - E5 `aew ship: option "<token>" given more than once.`
    - E6 `aew ship: unexpected argument "<token>".`
    - E7 `aew ship: --from needs a stage.`
    - E8 `aew ship: unknown stage "<token>". Stages: spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr.`
  - Result: `<n>`, `auto` (true or false) and `from` (a stage or none).
- `## Step 2. Preflight`: run `preflight.md` checks 1–6 in order. The first failing check stops the run with its message, having written nothing. Check 6 only warns. With `--from`, Check 2 uses the restart form and Check 5 treats this issue's run as being resumed. Then: `from` set → Step 4; otherwise → Step 3.
- `## Step 3. Start the run` (AC-4; sub-steps numbered **3.1–3.8 verbatim**, I-2). Write each one as a bullet starting `- 3.1 ` (the number, then a space):
  - 3.1 `test -e .aew/runs/<n>`: if it exists, stop with `Run <n> already exists: continue it with /aew:resume <n>, or restart a stage with /aew:ship <n> --from <stage>.`
  - 3.2 `state.sh init <n> --issues <n> --mode single` (add `--auto` when given).
  - 3.3 `gh-issue.sh fetch <n> .aew/runs/<n>`. On failure: `state.sh status failed --note "fetch failed: <first stderr line>"`, then `state.sh current clear`, then print `Could not fetch issue #<n>: <reason>. Fix it, then restart with /aew:ship <n> --from spec_analysis.` and stop.
  - 3.4 `jq -r .state .aew/runs/<n>/issue.json` gives `CLOSED`: the same three actions, with the reason `issue #<n> is closed`.
  - 3.5 `state.sh set title "$(jq -r .title .aew/runs/<n>/issue.json)"`.
  - 3.6 `gh-labels.sh stage <n> analysing`.
  - 3.7 the slug with the PD-13 `jq` expression (verbatim in B1: `jq -r '.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | .[0:40] | rtrimstr("-") | if . == "" then "issue-<n>" else . end' .aew/runs/<n>/issue.json`), then `git-branch.sh create <n> <slug>` (it prints the branch name), then `state.sh set branch <name>`.
  - 3.8 go to `## Stage: spec_analysis` **step 2** (Step 3 has done its Entry).
  - One line records the C4 order deviation (state is initialised before the fetch, because `fetch` writes into an existing run dir).
- `## Step 4. Restart at a stage (--from)` (AC-18):
  1. Run `preflight.md` `## Restart checks (--from)`. A missing run dir with `from = spec_analysis` → Step 3. The other failures stop there.
  2. `state.sh current set <n>`.
  3. Add `state.sh set auto true` when `--auto` was given. Without `--auto`, the run keeps its recorded value.
  4. If the current branch is not `state.branch`: `git switch <branch>`.
  5. For `spec_analysis`: `gh-issue.sh fetch` (failures and the closed check as in 3.3 and 3.4, but `current` was just set, so clear it again), `state.sh set title` (3.5), and 3.7 only when `state.branch` is null.
  6. `qa_test_plan` and `plan` both go to `## Stage: plan`.
  7. Enter `## Stage: <from>` at step 1 with the note `--from`.
  - Earlier stages are not redone, counters are kept, and a `done` run's PR is updated rather than re-created (`state.pr`).
- Stage sections. Each has these steps: 1 Entry (`state.sh stage <stage> --note "<why>"`, where the note is `--from`, `resume`, or the reason given by the step that sent you here, and may be left out on plain forward flow; then `gh-labels.sh stage <n> <label>`); 2 Check required files (`dispatch.md` `## Required inputs per stage`; a missing file goes to the blocked path, naming it); 3 Dispatch (row id); 4 Return check (`dispatch.md`); 5 Exit; 6 Failure (`routing.md` row). Keep each section to about 8–16 lines:
  - `## Stage: spec_analysis`: label `analysing`, D1. `ok` → `gates.md` `## Recording a spec revision` → `## Stage: brief`. `needs_input` → `gates.md` `## Gate: spec`.
  - `## Stage: brief`: label `planning`, D3. `ok` → `## Stage: standards`, except after a non-material `spec-ambiguity` answer, which goes to `## Stage: qa`. The exit decides this from `history` (I-11), not from session memory, so a resumed brief takes the same exit: the I-11 non-material check (write the command verbatim, with real `|`) prints `yes` → `## Stage: qa`, `no` → `## Stage: standards`.
  - `## Stage: standards`: label `planning`, D5. `ok` → `pr.md` `## Standards commit` → `## Stage: plan`.
  - `## Stage: qa_test_plan`: the two-line redirect (I-2).
  - `## Stage: plan` (AC-7):
    - label `planning`;
    - **send D6 and D7 as two Agent calls in ONE assistant message**, with no other tool call in it, and do not wait for one before sending the other;
    - when this stage was entered with `notes` (a plan-gate change request, or a developer `blocked`), dispatch only D7 with `notes:`, because QA phase A is not re-run;
    - check both returns; if one failed, retry only that one, on its own;
    - plan `needs_input` → `## Gate: plan-challenge`;
    - both `ok` → `## Gate: plan-approval` when `auto` is false and the plan gate is `on`, otherwise → `## Stage: develop`.
  - `## Stage: develop`: label `building`, with PD-5's mode choice: D10 (`fix_from: 07-review-<review_cycle>.md`) when `review_cycle ≥ 1` and `test .aew/runs/<id>/07-review-<review_cycle>.md -nt .aew/runs/<id>/05-plan.md` succeeds, otherwise D8. The Entry write is the state write the developer gate needs, so dispatch straight after it. Return check includes every named `06-dev-report*.md` (`dispatch.md`, CTO-3b). `ok` → `## Stage: review`. `blocked` → `routing.md` `## Developer blocked`.
  - `## Stage: review`: label `building`, D9 with `n = review_cycle + 1`. The verdict is the first word of SUMMARY: `approve` → `## Stage: qa`; `changes_required` → `routing.md` `## Review loop`; any other word → invalid return.
  - `## Stage: qa`: label `testing`, D12 with `n = fix_cycle + 1` (plus `triage:` only when sent by the QA loop). `ok` → `## Stage: docs`. `failed` → `routing.md` `## QA loop` (the complete-failure test decides between routing and retrying).
  - `## Stage: docs`: label `documenting`, D13. `ok` → `pr.md` `## Docs and memory commits` → `## Stage: pr`.
  - `## Stage: pr`: Entry `state.sh stage pr` only (the `ready-for-review` label is set once the PR exists). Then `pr.md` `## Push and pull request`, `## Manual tests`, `## Retro`, `## Finish` → `## Final report`.
- `## Gate pending` (AC-10): reached when a gate's Ask step gets no answer (AskUserQuestion is not among your tools, as in every headless run started with `--permission-prompts none`; or the question is refused; or the answer is empty). Do not try to call a tool you do not have. State and label are already set. Print `aew ship #<n>: waiting at the <gate-id> gate.`, then the questions with their recommended answers (or the plan summary and the `05-plan.md` path), then `Answer with /aew:resume <id>` (verbatim). Stop: nothing after the gate runs.
- `## Blocked path` (AC-15), in this order:
  1. `mktemp -t aew-blocked` (outside the run dir; Assumption 20).
  2. Write the comment with `cat > <tmpfile> <<'EOF'`. The body: heading `## aew run <id> blocked`, then bullets for stage, reason (the agent SUMMARY or the script error), cycles (`review <review_cycle>/<max_review_cycles>, fix <fix_cycle>/<max_fix_cycles>`) and the artefact names from `ls .aew/runs/<id>` ("in the run dir, not on GitHub"), then the line ``Resume with `/aew:resume <id>`.``
  3. `gh-issue.sh comment <n> <tmpfile>`.
  4. `gh-labels.sh stage <n> blocked`.
  5. `state.sh status blocked --note "<reason, one line>"`.
  6. Keep `current`.
  7. `## Final report`, then stop.
  - A failed `gh` call in steps 3 or 4 never skips step 5. The final report names the call that failed.
- `## Final report`: follow `final-report.md` for every outcome (`done`, `blocked`, `failed`).

**Step 3: GREEN.**

```sh
f=skills/ship/SKILL.md
sed -n '1,6p' "$f"                                                   # exactly the I-1 frontmatter
grep -cx 'name: ship' "$f"                                           # 1
grep -cx 'disable-model-invocation: true' "$f"                       # 1
grep -cxF 'argument-hint: "<issue> [--auto] [--from <stage>]"' "$f"  # 1
grep -c '^allowed-tools:' "$f"                                       # 0
wc -l < "$f"                                                         # 330–499
grep -c '!`' "$f"                                                    # 0
grep -cE '\$[0-9]|\$ARGUMENTS\[' "$f"                                # 0
grep -o '\$ARGUMENTS' "$f" | wc -l                                   # 1
for h in '# aew ship' '## Plugin root' '## Rules' '## Run variables' '## What the orchestrator reads' '## References' '## Step 1. Parse the arguments' '## Step 2. Preflight' '## Step 3. Start the run' '## Step 4. Restart at a stage (--from)' '## Gate pending' '## Blocked path' '## Final report'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done
# every line ends in =1
for s in spec_analysis brief standards qa_test_plan plan develop review qa docs pr; do printf '%s=%s\n' "$s" "$(grep -cx "## Stage: $s" "$f")"; done
# every line ends in =1
grep -n '^## ' "$f" | cut -d: -f2-                                   # the I-2 list, in that order
for m in 'aew ship: missing issue number.' 'must be a positive integer' '/aew:ship-milestone' 'unknown option' 'given more than once' 'unexpected argument' '--from needs a stage' 'unknown stage' 'spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr' 'Usage: /aew:ship <issue> [--auto] [--from <stage>]' 'Answer with /aew:resume <id>'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' "$f"                    # no output
grep -cF 'spec-ambiguity: non-material' "$f"                         # >= 1 (brief exit, I-11)
grep -cF -- '-nt .aew/runs/<id>/05-plan.md' "$f"                        # >= 1 (develop mode, PD-5)
for s in 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8; do printf '%s=%s\n' "$s" "$(grep -c "^- $s " "$f")"; done   # each =1 (sub-step bullets)
claude plugin validate .                                             # passes as before
```

The reference links resolve only after wave 2; B8 checks them.

**Step 4: commit.**

```
feat(ship): add the ship orchestrator procedure

skills/ship/SKILL.md drives one issue through the DESIGN 7.3 stages on
the main thread: argument parsing with clear errors before any write,
preflight, run start (state before fetch, C4) and --from restarts, one
section per stage with entry, dispatch, exit and failure steps, the
gate-pending stop, the blocked path and the final report. Detail lives
in references/, linked by absolute plugin-root paths so resume and
prompt can read them with Read.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B2 — `references/preflight.md`

- **id:** B2
- **files:** `skills/ship/references/preflight.md` (new)
- **depends_on:** [B1]
- **pattern:** DESIGN §9 "Preflight" (the order) and the check, command and message style of `skills/ui-qa/SKILL.md` §3.
- **ACs:** AC-3 (with cut 7 applied to item 4), AC-18 (restart checks), Assumptions 9, 11 and 12, PD-2, PD-10
- **Size:** about 90–130 lines.

**Step 1: RED.** `test -f skills/ship/references/preflight.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings. Open with: "Run the checks in order; the first failure stops with its message. Preflight writes nothing: no state, label, branch, commit or `gh` write. (`git fetch` only updates remote-tracking refs.)" Then:

- `## Check 1. Config exists`: `test -f .aew/config.json`. Stop with `No .aew/config.json in this project: run /aew:init first.`
- `## Check 2. Clean working tree`:
  - **Fresh run:** `git status --porcelain --untracked-files=all` must print nothing. Otherwise stop with `The working tree has uncommitted changes; commit or stash them, then retry:` followed by the paths. If **every** dirty path is under `.claude/agent-memory/` (memory left by an earlier run that never reached its docs commit), add the line `These are aew agent memory files from an earlier run: commit them (git add -- .claude/agent-memory && git commit -m "chore(aew): update agent memory"), then retry.` (PD-2). Committing keeps the memory, while stashing would hide it from the agents.
  - **Restart form (`--from`, and `resume`):** `git status --porcelain --untracked-files=all` (verbatim), ignoring lines whose path starts with `.claude/agent-memory/` (PD-2: memory written earlier in this run, committed at the docs stage). The flag is required: without it a wholly untracked `.claude/` collapses to `?? .claude/` and the filter never matches (verified while reviewing).
  - Note: `.aew/runs/` is gitignored by init, so the run dir never counts. If it shows up, the message adds "add `.aew/runs/` to `.gitignore` (run /aew:init)".
- `## Check 3. gh is authenticated`: `gh auth status` (exact; read-only; the only direct `gh` call, a recorded deviation, Assumption 9). Non-zero → stop with `gh is not authenticated: run gh auth login, then retry.`
- `## Check 4. Default branch up to date` (cut 7, PD-10):
  1. `<default>` comes from config.
  2. `git rev-parse --verify --quiet refs/heads/<default>`. Missing → stop with `The default branch <default> does not exist locally: run git switch <default>, then retry.`
  3. `git fetch origin <default>`. Failure → stop with `Could not fetch origin/<default>: <stderr>.`
  4. `git rev-list --left-right --count <default>...origin/<default>` prints `<ahead> <behind>`. If behind > 0 (only behind, or diverged), stop with `<default> is behind origin/<default> by <behind> commit(s)<, and ahead by <ahead>>: run git switch <default> && git pull --ff-only (or reconcile the divergence), then retry.` If ahead only, warn `<default> has <ahead> unpushed commit(s); the PR will include them.` and continue.
- `## Check 5. No other active run` (Assumption 11):
  - Read `cat .aew/runs/current`; a missing or empty file passes.
  - Otherwise `jq -r .status .aew/runs/<cur>/state.json`.
  - Pass when the status is `done` or `failed`, or when `<cur>` is this issue and the call is `--from` or `resume`.
  - `<cur>` is another run and active (`running`, `blocked`, `awaiting_input`, `awaiting_plan_approval`) → stop with `Run <cur> is active (<status>): finish it with /aew:resume <cur>, or check it with /aew:status <cur>.`
  - `<cur>` is this issue without `--from` → stop with `Run <n> is active (<status>): continue it with /aew:resume <n>, or restart a stage with /aew:ship <n> --from <stage>.`
- `## Check 6. superpowers major version (warn only)` (Assumption 12, V-6):
  - One sentence: superpowers cannot be range-pinned (DESIGN §4), so this is the early warning.
  - The constant: **`Built against superpowers major: 7`** (verbatim line; the one place it is recorded).
  - Command (verbatim): `claude plugin list --json | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version'`.
  - Outcomes:
    - empty output or a non-zero exit → warn `Could not check the installed superpowers version.`;
    - the value matches `^[0-9]+\.` and its major is not 7 → warn `superpowers <value> is installed; aew is built against 7.x. Check the superpowers release notes before relying on this run.`;
    - the value is not semver (for example a 12-character commit SHA) → warn `The installed superpowers version "<value>" is not a release number, so it could not be compared with 7.x.`;
    - a 7.x value → no output.
  - Never stop.
- `## Restart checks (--from)` (AC-18; read-only):
  1. `test -f .aew/runs/<n>/state.json`. If it is missing, `spec_analysis` → back to `SKILL.md` Step 3 (fresh start). Any other stage → stop with `No run <n> to restart: start it with /aew:ship <n>.`
  2. `jq -r .branch .aew/runs/<n>/state.json`: null with a stage other than `spec_analysis` → stop with `Run <n> has no branch yet: restart it with /aew:ship <n> --from spec_analysis.`
  3. The stage's required inputs (`dispatch.md` `## Required inputs per stage`), each `test -f`. Missing → stop with `Cannot restart run <n> at <stage>: missing <files>.`
  - The writes (`current set`, `set auto`, `git switch`) are in `SKILL.md` Step 4, not here.

**Step 3: GREEN.**

```sh
f=skills/ship/references/preflight.md
for h in '## Check 1. Config exists' '## Check 2. Clean working tree' '## Check 3. gh is authenticated' '## Check 4. Default branch up to date' '## Check 5. No other active run' '## Check 6. superpowers major version (warn only)' '## Restart checks (--from)'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -cF 'Built against superpowers major: 7' "$f"                                          # 1
grep -cF "claude plugin list --json | jq -r '.[] | select(.id == \"superpowers@claude-plugins-official\") | .version'" "$f"   # 1
grep -cF 'gh auth status' "$f"                                                              # >= 1
grep -cE 'git (merge|pull) --ff-only' "$f"                                                  # 1 (the hint text only, inside the stop message)
grep -cF '.claude/agent-memory/' "$f"                                                       # >= 1
grep -cF -- 'git status --porcelain --untracked-files=all' "$f"                              # >= 1 (restart form)
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked)' "$f"   # 0
claude plugin list --json | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version'   # 7.0.0 on this machine (the command works)
```

**Step 4: commit.**

```
feat(ship): add the preflight reference

Six checks in DESIGN 9 order: config, clean tree (agent memory ignored on
restarts), gh auth, default branch up to date (fetch and stop when behind
or diverged, never fast-forward), no other active run, and a warn-only
superpowers major-version check that handles semver, commit SHAs and an
unreadable plugin list. Plus the read-only --from restart checks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B3 — `references/dispatch.md`

- **id:** B3
- **files:** `skills/ship/references/dispatch.md` (new)
- **depends_on:** [B1]
- **pattern:** the agents' Inputs and Return contract sections (field names copied exactly) and `valid_return_block` in `scripts/hooks/gate-subagent.sh` (restated as a rule, not copied as code).
- **ACs:** AC-5, AC-6 (including CTO-3b), AC-7 (the mechanics), PD-7
- **Size:** about 90–120 lines.

**Step 1: RED.** `test -f skills/ship/references/dispatch.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## How to dispatch`:
  - The Agent tool, `subagent_type` = the row's `aew:<agent>` (V-3), `description` = `<stage> <id>`.
  - The prompt is `key: value` lines only, one per field, in the row's order, with nothing else (no prose, no artefact content). `answers:` is followed by its `Q<k>:` lines (I-10).
  - `run_dir` is `.aew/runs/<id>`.
  - One agent per call. The single exception is D6 ∥ D7: two Agent calls in one assistant message, with no other tool call in it (V-3; concurrency is not guaranteed and sequential execution is still correct).
  - Example block (verbatim):
    ```
    run_dir: .aew/runs/201
    mode: review
    n: 1
    base: main
    ```
- `## Dispatch table`: exactly the I-4 table (header verbatim, rows D1–D13), followed by one note per field taken from the agent files. `spec_version` is always `spec_revision + 1`. `n` for D10 and D11 is the cycle number `k` given by the step that dispatches. `triage` is a run-dir path. `base` is `state.base_branch`. `notes` is one line (I-10).
- `## Required inputs per stage` (used by Stage step 2, `--from` and resume; table `| Stage | Required files in <rd> |`, **ten rows, one per stage, each row starting with the backticked stage name**):
  - `spec_analysis`: `issue.json`, `00-issue-original.md` (after the fetch);
  - `brief`: `spec-final.md`, `issue.json`;
  - `standards`: `02-brief.md`;
  - `qa_test_plan`: `02-brief.md`, `03-standards.md` (the same step as `plan`);
  - `plan`: `02-brief.md`, `03-standards.md`;
  - `develop`: `02-brief.md`, `03-standards.md`, `05-plan.md`, plus `07-review-<review_cycle>.md` in fix mode (PD-5);
  - `review`: `02-brief.md`, `03-standards.md`, `05-plan.md`, at least one `06-dev-report*.md`;
  - `qa`: `02-brief.md`, `04-qa-test-plan.md`;
  - `docs`: `spec-final.md`, `issue.json`, and an `08-qa-report-<n>.md` whose return block reads `STATUS: ok`;
  - `pr`: `pr-body.md`, `10-summary.md`.
- `## Return check` (AC-6, PD-7):
  1. The last four non-blank lines of the Agent result must be, in order, `STATUS: <ok|needs_input|blocked|failed>`, `ARTEFACTS: <non-empty>`, `SUMMARY: <non-empty>`, `NEXT: <non-empty>`. This is `valid_return_block`'s rule (`${CLAUDE_PLUGIN_ROOT}/scripts/hooks/gate-subagent.sh`). The template form `STATUS: ok | needs_input | blocked | failed` is invalid.
  2. Every comma-separated ARTEFACTS path must pass `test -f` (paths are relative to the project root, or absolute for a sub-developer's report).
  3. **Developer:** for **each** `06-dev-report.md` or `06-dev-report-WP<n>.md` named in ARTEFACTS, `awk 'NF' <file> | tail -n 4` must pass rule 1. One sentence explains why: in fan-out the gate hook can pass a sibling's report (CTO-3b).
  4. If any of these fails, the return counts as `failed` (→ `## Retries`). Do not open the artefact to "fix" it.
  5. Then route on STATUS through `routing.md`. The SUMMARY and NEXT text are the only parts of the result the orchestrator uses.
- `## Retries`:
  - A `failed` return (or an invalid one) → re-send the **same** dispatch once. A second failure → `SKILL.md` `## Blocked path`, with the reason taken from the last SUMMARY.
  - Counted in this session only (Assumption 15), so a resumed run starts with a fresh allowance.
  - Exception: a QA phase B `failed` that passes the complete-failure test is not retried (`routing.md` `## QA loop`).
  - In the planning pair, retry only the agent that failed, on its own.

**Step 3: GREEN.**

```sh
f=skills/ship/references/dispatch.md
for h in '## How to dispatch' '## Dispatch table' '## Required inputs per stage' '## Return check' '## Retries'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -cxF '| Row | Agent and mode | subagent_type | Prompt fields | Required files | State write before |' "$f"   # 1
for r in D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12 D13; do printf '%s=%s\n' "$r" "$(grep -c "^| $r |" "$f")"; done   # each =1
grep -oE 'aew:[a-z-]+' "$f" | sort -u                                  # exactly the 7 agents
for a in $(grep -oE 'aew:[a-z-]+' "$f" | sort -u | sed 's/^aew://'); do test -f "agents/$a.md" || echo "MISSING $a"; done   # no output
for s in spec_analysis brief standards qa_test_plan plan develop review qa docs pr; do printf '%s=%s\n' "$s" "$(grep -c "^| \`$s\` |" "$f")"; done   # each =1 (the required-inputs table)
grep -cF "awk 'NF'" "$f"                                               # >= 1
grep -cF 'tail -n 4' "$f"                                              # >= 1
grep -c 'CTO-3b' "$f"                                                  # >= 1
```

**Step 4: commit.**

```
feat(ship): add the dispatch reference

One row per agent and mode (D1-D13) with the exact key: value prompt
fields from the agents' Inputs, the files checked with test -f before
dispatching, and the state write that precedes each dispatch; required
inputs per stage for --from and resume; the return check, including a
per-report block check for every developer report named in ARTEFACTS
(CTO-3b); and the retry-once rule.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B4 — `references/gates.md`

- **id:** B4
- **files:** `skills/ship/references/gates.md` (new)
- **depends_on:** [B1]
- **pattern:** `skills/run-protocol/references/state-machine.md` "Gates" table; `skills/github-ops/SKILL.md` "Spec-revision recording order" (copied as steps); `templates/artefacts/spec-revision-comment.md` (reproduced by the render).
- **ACs:** AC-8, AC-9, AC-10, AC-13 (the gate halves of `spec_ambiguity` and triage `needs_input`), AC-14 as amended by cut 8, PD-1, PD-4, PD-8, PD-11, PD-12
- **Size:** about 150–200 lines.

**Step 1: RED.** `test -f skills/ship/references/gates.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Gate ids and pending state`: the I-5 table (verbatim formats), the pending lookup command, the prompt-mode sentence (verbatim), and the I-11 prompt-mode check command (verbatim, with real `|`; "prompt mode" in this file means that check prints `prompt`, i.e. the `prompt` marker is present **and** `branch` is null). One line: the four `awaiting_input` gates never skip, even with `--auto`. Only `plan-approval` is skippable (auto, or the plan gate `off`).
- `## Asking` (AC-8, V-4):
  - AskUserQuestion exists on the main thread only; subagents never have it, which is why agents return `needs_input`. If it is not among your tools, go straight to `SKILL.md` `## Gate pending` and do not call it.
  - One question per source question. The **recommended answer is the first option, and its label ends with ` (recommended)`**. The other options are the listed alternatives. The tool adds free-text "Other" itself.
  - If the tool's schema caps questions per call or options per question, split into several calls in question order. Never drop a question or the recommended option; keep the extra alternatives in the question text.
  - The answer is the chosen label without ` (recommended)`, or the free text.
  - A refusal or an empty answer → `## Gate pending`.
- `## Gate: spec` (from `spec_analysis` `needs_input`):
  1. Set pending: `state.sh status awaiting_input --note "gate:spec 01-spec-analysis.md"`, then `gh-labels.sh stage <n> awaiting-input` (skipped in prompt mode).
  2. Read: `awk '/^## Questions$/{f=1;next} /^## |^STATUS:/{f=0} f' <rd>/01-spec-analysis.md`. Each `### Q<k>. <question>` gives the question, `**Recommended answer:**` the first option, and `**Alternatives:**` (split on `;`) the rest.
  3. Ask.
  4. Apply the answer: `state.sh stage spec_analysis --note "answers: gate:spec"`, `gh-labels.sh stage <n> analysing` (skipped in prompt mode), then D2 with `answers:` (`Q<k>: <answer>` lines). Then run the I-11 prompt-mode check. `prompt` → return to the `prompt` skill's own step after its spec-analyser dispatch, because ship's spec_analysis exit goes on to D3, which prompt must not run. `ship` → `SKILL.md` `## Stage: spec_analysis` step 4 (return check). spec-analyser may return `needs_input` again for an unclear answer, which loops back here.
- `## Gate: plan-challenge` (AC-14 per **cut 8, one rule**):
  1. Set pending: `state.sh status awaiting_input --note "gate:plan-challenge 05-plan.md"`, then `gh-labels.sh stage <n> awaiting-input`.
  2. Read: `awk '/^## Challenges to the spec$/{f=1;next} /^## /{f=0} f' <rd>/05-plan.md`. Take each material challenge's question, its recommended answer and its alternatives.
  3. Ask.
  4. Apply: every answer (accept, other, or decline) goes the same way. `state.sh stage spec_analysis --note "answers: gate:plan-challenge"`, label `analysing`, then D2 with PD-4 answers (`Q<k>: <question> => <answer>`, k after `grep -c '^### Q[0-9]' <rd>/01-spec-analysis.md`). On `ok`, `## Recording a spec revision`, then `SKILL.md` `## Stage: brief`, which re-runs brief, standards, QA phase A ∥ plan and the plan gate. One line notes that the counters are kept.
- `## Gate: triage` (triage `needs_input`):
  1. Set pending: `state.sh status awaiting_input --note "gate:triage 09-triage-<k>.md"` (`<k>` = the cycle), then `gh-labels.sh stage <n> awaiting-input`.
  2. Read: `awk '/^## (Root cause|Where the divergence started)$/{f=1;print;next} /^## /{f=0} f' <rd>/09-triage-<k>.md` (PD-12). The question and the senior engineer's recommended answer are in that text or in the triage return's SUMMARY (already in context; the agent file does not fix where it goes), so use both.
  3. Ask.
  4. Apply: as plan-challenge step 4 (the change is material by definition), with the note `answers: gate:triage`, then `## Stage: brief`.
- `## Gate: spec-ambiguity` (AC-13, Assumption 18):
  1. Set pending: `state.sh status awaiting_input --note "gate:spec-ambiguity 08-qa-report-<k>.md"`, then `gh-labels.sh stage <n> awaiting-input`.
  2. Read the triage rows (the `routing.md` command), then each `spec_ambiguity` entry: `awk -v h='### <TC>:' 'index($0,h)==1{f=1;print;next} /^### |^## |^STATUS:/{f=0} f' <rd>/08-qa-report-<k>.md`.
  3. Ask one question per TC, `<TC>: the spec is ambiguous - <summary>. Which behaviour is intended?`, with the options `<Expected> (recommended)` and `<Actual>`. The recommendation follows the test, which was written from the brief.
  4. Apply: note `answers: gate:spec-ambiguity`, D2 with PD-4 answers, then recording. Then decide with `jq '[.changes[] | select(.type == "material")] | length' <rd>/spec-changes.json`: greater than 0 → `## Stage: brief` (every stage from brief re-runs); 0 → `## Stage: brief`, entered with the note `spec-ambiguity: non-material` (verbatim, I-11). That note is the persisted "continue at `## Stage: qa` after the brief" decision, so it survives a resume (`SKILL.md` brief exit).
- `## Gate: plan-approval` (AC-9):
  1. Set pending: `state.sh status awaiting_plan_approval --note "gate:plan-approval 05-plan.md"`, then `gh-labels.sh stage <n> awaiting-approval`.
  2. Read `05-plan.md` in full (the only full read).
  3. Write a summary of **25 lines or fewer**: the headline approach, the work packages (which run in parallel), the challenges resolved, the risks, and whether every AC is mapped. Then the path `.aew/runs/<id>/05-plan.md`. Ask one question, `Approve the plan for #<n>?`, with the options `Approve`, `Request changes`, `Stop`. Free text counts as request changes, with the text as the notes. `Request changes` without text → one follow-up question asking for the notes (answered through "Other"). If nothing comes back, the gate stays pending.
  4. Apply:
     - Approve → `SKILL.md` `## Stage: develop`.
     - Request changes → `SKILL.md` `## Stage: plan` with `notes:` (the note `plan revision: request changes`; D7 only; QA phase A is not re-run), then this gate again.
     - Stop → `state.sh status failed --note "stopped at the plan gate"`, `state.sh current clear`, `SKILL.md` `## Final report` (outcome `failed`; PD-11 label note).
- `## Recording a spec revision` (AC-8, PD-8; the `github-ops` order). It runs when `jq '.changes | length' <rd>/spec-changes.json` is greater than 0 **and** `jq '.version' …` is greater than `state.sh get spec_revision`; otherwise skip it. Steps, with `<N>` = that version:
  1. The render (**verbatim**; dry-run against `templates/artefacts/spec-changes.example.json` while planning gave the template's heading, paragraph and three rows):
     ```sh
     jq -r '
       def cell: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
       "## Spec revision v\(.version)",
       "",
       "The issue body now shows spec v\(.version) on top. Earlier versions are kept below it, collapsed. Nothing the author wrote has been deleted.",
       "",
       "| Change | Type | Rationale | Source |",
       "|---|---|---|---|",
       (.changes[] | "| \(.change | cell) | \(.type | cell) | \(.rationale | cell) | \(if .source == "confirmed" then "confirmed by James" else "auto" end) |")
     ' .aew/runs/<id>/spec-changes.json > .aew/runs/<id>/spec-revision-v<N>.md
     ```
  2. `gh-issue.sh revise <n> .aew/runs/<id>/spec-final.md <N>`.
  3. `gh-issue.sh comment <n> .aew/runs/<id>/spec-revision-v<N>.md`.
  4. `gh-labels.sh flag <n> add spec-revised`.
  5. `state.sh set spec_revision <N>`.
  - A refusal (malformed markers, or a body over 65,536 characters) → blocked path. Never trim the history.
- `## Re-asking a pending gate` (for `resume`): run the I-5 lookup command, then map the gate id to its `## Gate: <id>` and enter it at **step 2**. A status of `awaiting_plan_approval` with no `gate:` note means `plan-approval`. A status of `awaiting_input` with no note is treated as `spec`. Before re-asking, run the I-11 prompt-mode check. On a prompt-mode run only `gate:spec` can be pending: re-ask it under the prompt-mode rule, and step 4 hands back to the `prompt` skill.
- `## Destructive operations`: ship runs none (no force-push, reset, branch deletion or history rewrite). If a step would need one, ask confirm or cancel with AskUserQuestion. No answer means cancel, which goes to the blocked path. This gate is never skipped.

**Step 3: GREEN.**

```sh
f=skills/ship/references/gates.md
for h in '## Gate ids and pending state' '## Asking' '## Gate: spec' '## Gate: plan-challenge' '## Gate: triage' '## Gate: spec-ambiguity' '## Gate: plan-approval' '## Recording a spec revision' '## Re-asking a pending gate' '## Destructive operations'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
for g in spec plan-challenge triage spec-ambiguity plan-approval; do printf '%s=%s\n' "$g" "$(grep -cF "gate:$g " "$f")"; done   # each >= 1
grep -cF '(recommended)' "$f"                                           # >= 1
grep -cF 'In prompt mode (`/aew:prompt`), skip every `gh-labels.sh stage` call in this file and keep the `gh-labels.sh flag` call.' "$f"   # 1
grep -cF "[.history[] | select((.note // \"\") | startswith(\"gate:\"))] | last | .note" "$f"   # 1
grep -cF '25 lines or fewer' "$f"                                       # >= 1
grep -cF 'spec-ambiguity: non-material' "$f"                            # >= 1 (I-11)
grep -cF 'select(.note == "prompt")' "$f"                               # >= 1 (I-11)
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
```

Render check: copy the `jq` program from the written `gates.md` (not from this plan) and run it by hand, with `templates/artefacts/spec-changes.example.json` as input and no redirect. Expected: `## Spec revision v2`, a blank line, the template's paragraph, the header row, the separator and three rows. The third row ends `| material | Changes user-visible behaviour and adds a privacy-relevant step. | confirmed by James |`. Paste the output into the task report.

**Step 4: commit.**

```
feat(ship): add the gates reference

Five gates with fixed ids and a gate:<id> history note as the pending
state, so resume can re-ask them: the material spec change gate, plan
challenges (one rule, cut 8: finalise the spec and re-run from brief),
triage and spec-ambiguity questions, and plan approval with a summary of
25 lines or fewer. AskUserQuestion on the main thread only, recommended
answer first; no tool or no answer leaves the gate pending. The spec
revision is recorded in the github-ops order with a jq render, so the
JSON never enters context.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B5 — `references/routing.md`

- **id:** B5
- **files:** `skills/ship/references/routing.md` (new)
- **depends_on:** [B1]
- **pattern:** `skills/run-protocol/references/state-machine.md` "Failure paths", "Counters" and the `qa_failures_complete` snippet (restated as two commands); the agents' Return contract sections for each status.
- **ACs:** AC-11, AC-12, AC-13, AC-15 (when to take the blocked path), AC-20, PD-3, PD-5, PD-9
- **Size:** about 110–150 lines.

**Step 1: RED.** `test -f skills/ship/references/routing.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Stage table` (AC-20, I-6 format). The rows to write (cells condensed; no `|` inside a cell):

  | Stage | Entry | Exit | Failure |
  |---|---|---|---|
  | `spec_analysis` | `state.sh stage spec_analysis` (fresh run: Step 3); label `analysing`; D1, or D2 after a gate | `ok` → record the revision → `brief` | `needs_input` → gate `spec`; `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `brief` | `state.sh stage brief`; label `planning`; D3 | `ok` → `standards` (→ `qa` after a non-material spec-ambiguity answer) | `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `standards` | `state.sh stage standards`; label `planning`; D5 | `ok` → standards commit → `plan` | as `brief` |
  | `qa_test_plan` | as `plan` (one step) | as `plan` | as `plan` |
  | `plan` | `state.sh stage plan`; label `planning`; D6 ∥ D7 in one message (D7 alone with `notes`) | both `ok` → gate `plan-approval`, or `develop` when auto or the gate is off | plan `needs_input` → gate `plan-challenge`; `failed` → retry only that agent, then blocked path; `blocked` → blocked path |
  | `develop` | `state.sh stage develop`; label `building`; D10 from `07-review-<review_cycle>.md` when `review_cycle` is at least 1 and that review is newer than `05-plan.md` (`test -nt`), else D8 | `ok` with every named report valid → `review` | full-mode `blocked` → Developer blocked; fix-mode `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `review` | `state.sh stage review`; label `building`; D9 with n = review_cycle + 1 | `approve` → `qa` | `changes_required` → Review loop (limit → blocked path); `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `qa` | `state.sh stage qa`; label `testing`; D12 with n = fix_cycle + 1 | `ok` → `docs` | complete failure → QA loop (limit → blocked path); other `failed` → retry once, then blocked path; `blocked` → blocked path |
  | `docs` | `state.sh stage docs`; label `documenting`; D13 | `ok` → docs and memory commits → `pr` | `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `pr` | `state.sh stage pr`; label set once the PR exists | push, PR, manual tests, retro → label `ready-for-review`, `done`, `current` cleared → final report | a script failure → blocked path (retro failure: warn only) |

- `## Agent status routing` (a table per status). `ok` → the stage Exit. `needs_input` → only spec-analyser, senior-engineer plan and senior-engineer triage use it, each to its gate; from any other agent it is an invalid return. `blocked` → the developer goes to `## Developer blocked`, any other agent to the blocked path. `failed` → `dispatch.md` `## Retries`, with the QA exception.
- `## Review loop` (AC-11), on `changes_required` from `07-review-<r>.md` (r = review_cycle + 1):
  - `review_cycle < max_review_cycles` → `state.sh bump review_cycle`, then `SKILL.md` `## Stage: develop` with the note `review fix <new review_cycle>`. Develop picks fix mode from the counter and the review's age (PD-5), and then the review runs again.
  - `review_cycle = max_review_cycles` → blocked path, with the reason `review cycles used up (<max>): <SUMMARY>`.
- `## Developer blocked` (AC-12, PD-3):
  - Fix mode → blocked path.
  - Full mode: `jq '[.history[] | select(.note == "developer blocked: re-plan")] | length' <rd>/state.json`. If it is ≥ 1 → blocked path. Otherwise `SKILL.md` `## Stage: plan` with the note `developer blocked: re-plan` and `notes: developer blocked: <the developer's SUMMARY> / <the dev report path from ARTEFACTS>` (I-10; D7 only), then the plan gate (unless auto or off), then develop.
- `## QA loop` (AC-13, Assumption 17). The `stage` stays `qa` throughout. On a D12 `failed`:
  1. **Complete-failure test** (state-machine.md, inline): `awk 'NF' <rd>/08-qa-report-<k>.md | tail -n 4` is a valid block with `STATUS: failed`, **and** `awk '/^## /{f=($0=="## Failures")} f && /^\|[[:space:]]*TC-[0-9]+[[:space:]]*\|/{n++} END{print n+0}' <rd>/08-qa-report-<k>.md` prints ≥ 1. Not both → an ordinary `failed` (retry once, then blocked path). Here `k` = fix_cycle + 1, the report just written.
  2. **Triage rows** (verbatim; the only read of the report): `awk -F'|' '/^## /{f=($0=="## Failures")} f && $2 ~ /^[[:space:]]*TC-[0-9]+[[:space:]]*$/ {gsub(/[[:space:]]/,"",$2); gsub(/[[:space:]]/,"",$4); print $2, $4}' <rd>/08-qa-report-<k>.md` prints `TC-<n> <class>` lines. (The command was dry-run while planning.)
  3. **Limit:** `fix_cycle = max_fix_cycles` → blocked path, with the reason `fix cycles used up (<max>): <SUMMARY>`.
  4. `state.sh bump fix_cycle`; the number it prints is the new fix_cycle, `k`, which equals the failing report's number (no shell variable, I-8).
  5. **Route one class per cycle, the first match wins:**
     - a. any `spec_ambiguity` → `gates.md` `## Gate: spec-ambiguity`.
     - b. any `plan_divergence` or `test_bug`, **or** an `impl_bug` whose TC was also `impl_bug` in the triage rows of `08-qa-report-<k-1>.md` (it has already had one developer fix) → D11 with `n: k`. On its return: `needs_input` → `gates.md` `## Gate: triage`. `ok` → read NEXT. If NEXT names the developer: `state.sh stage qa --note "fix <k>: developer (triage)"`, then D10 with `fix_from: 09-triage-<k>.md` and `n: k`. Then (or straight away, when NEXT names only qa-engineer) D12 with `n: k+1` and `triage: .aew/runs/<id>/09-triage-<k>.md`.
     - c. otherwise (`impl_bug` only) → `state.sh stage qa --note "fix <k>: developer"`, then D10 with `fix_from: 08-qa-report-<k>.md` and `n: k`, then D12 with `n: k+1`.
  6. The developer's return inside the loop: `ok` → D12. `blocked` → blocked path (fix mode, PD-3). `failed` → retry once, then blocked path.
  7. Repeat from step 1 with the new report. A D12 `ok` → `## Stage: docs`.
- `## Cycle limits`: the two `jq` reads with the schema defaults (`max_review_cycles` 2, `max_fix_cycles` 3); the counters (`07-review-<review_cycle+1>.md`, `08-qa-report-<fix_cycle+1>.md`, `09-triage-<same n>.md`); and one line saying the counters are never reset (not by `--from`, a gate re-run or resume).
- `## Script failures` (PD-9): the rule, the three exceptions, and the reason format `<script> <subcommand> failed: <first stderr line>`.

**Step 3: GREEN.**

```sh
f=skills/ship/references/routing.md
for h in '## Stage table' '## Agent status routing' '## Review loop' '## Developer blocked' '## QA loop' '## Cycle limits' '## Script failures'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -cxF '| Stage | Entry | Exit | Failure |' "$f"                   # 1
for s in spec_analysis brief standards qa_test_plan plan develop review qa docs pr; do
  awk -F'|' -v s="\`$s\`" '
    $2 ~ "^[[:space:]]*" s "[[:space:]]*$" { n++; e=$3; x=$4; fl=$5; gsub(/[[:space:]]/,"",e); gsub(/[[:space:]]/,"",x); gsub(/[[:space:]]/,"",fl); if (NF==6 && e!="" && x!="" && fl!="") ok++ }
    END { printf "%s rows=%d ok=%d\n", s, n, ok }' "$f"
done
# ten lines, each "rows=1 ok=1" (NF==6 proves no stray | inside a cell).
# The loop was dry-run while planning against the Stage table above: ten lines, each rows=1 ok=1.
grep -cF "awk 'NF'" "$f"                                             # >= 1
grep -cF 'bump fix_cycle' "$f"; grep -cF 'bump review_cycle' "$f"    # >= 1 each
grep -cF 'developer blocked' "$f"                                    # >= 1
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked)' "$f"   # 0
```

**Step 4: commit.**

```
feat(ship): add the routing reference

The stage table with an entry, exit and failure path for each of the ten
schema stages, routing per agent status, the review loop up to
max_review_cycles, the developer-blocked re-plan (once per run, read
from the history), the QA loop with the complete-failure test, one
triage class per cycle and the fix-cycle limit, and the script-failure
rule.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B6 — `references/pr.md`

- **id:** B6
- **files:** `skills/ship/references/pr.md` (new)
- **depends_on:** [B1]
- **pattern:** `skills/github-ops/SKILL.md` "Operational rules" (check `state.pr`; `update --run`) and the `gh-pr.sh`, `gh-issue.sh manual-tests` and `gh-retro.sh` `--help` text.
- **ACs:** AC-16 (with Conflict C1: the orchestrator commits the doc-writer's outputs), PD-2, PD-14
- **Size:** about 70–100 lines.

**Step 1: RED.** `test -f skills/ship/references/pr.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Commit rules`:
  - conventional messages ending `(#<n>)`;
  - no trailer beyond what the user's Claude Code settings add (Assumption 28);
  - stage explicit paths only (`git add -- <paths>`), then `git commit -m "<message>"`;
  - commit only on the run branch (`git branch --show-current` equals `state.branch`);
  - skip a commit when `git status --porcelain -- <paths>` is empty.
- `## Standards commit` (after a standards `ok`): paths `docs/standards`; message `docs(standards): <add or update> <profile list> standards (#<n>)`, with the profiles taken from the standards-setter's ARTEFACTS (`docs/standards/<profile>.md`).
- `## Docs and memory commits` (after a docs `ok`):
  1. The doc-writer's ARTEFACTS paths outside `.aew/` (expected: `docs/specs/<n>-<slug>.md`, `CLAUDE.md`); message `docs: add the issue spec<, and update CLAUDE.md> (#<n>)`.
  2. Then, if `git status --porcelain -- .claude/agent-memory` is non-empty, `git add -- .claude/agent-memory` with the message `chore(aew): update agent memory (#<n>)` (PD-2).
  3. Then `git status --porcelain`. Anything left is listed as a warning in the final report, never committed.
- `## Push and pull request`:
  1. `git-branch.sh push`.
  2. `state.sh get pr` is null → `gh-pr.sh create <id> .aew/runs/<id>/pr-body.md` (it prints the number), then `state.sh set pr <number>`. Otherwise `gh-pr.sh update <pr> .aew/runs/<id>/pr-body.md --run <id>`.
  3. The PR URL for the report: `jq -r --arg pr <pr> '.url | sub("/issues/[0-9]+$"; "/pull/" + $pr)' .aew/runs/<id>/issue.json` (dry-run while planning).
  4. `gh-labels.sh stage <n> ready-for-review` comes in `## Finish`, not here.
- `## Manual tests`: `grep -c '^- \[ \]' .aew/runs/<id>/manual-tests.md` (a missing file or 0 → skip). If it is ≥ 1, `gh-issue.sh manual-tests <n> .aew/runs/<id>/manual-tests.md`, then `gh-labels.sh flag <n> add manual-test-required`.
- `## Retro`: the source repo comes from `jq -r '.url | capture("^https?://[^/]+/(?<r>[^/]+/[^/]+)/issues/").r' .aew/runs/<id>/issue.json` (dry-run: `acme/static-shop`). Then `gh-retro.sh file .aew/runs/<id>/retro.md <owner/repo> <id>`. Keep its stdout lines for the final report. A non-zero exit → warn and continue (never blocked).
- `## Finish`: `gh-labels.sh stage <n> ready-for-review`, `state.sh status done`, `state.sh current clear`, then `SKILL.md` `## Final report`.

**Step 3: GREEN.**

```sh
f=skills/ship/references/pr.md
for h in '## Commit rules' '## Standards commit' '## Docs and memory commits' '## Push and pull request' '## Manual tests' '## Retro' '## Finish'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
for c in 'git-branch.sh push' 'gh-pr.sh create' 'gh-pr.sh update' 'state.sh set pr' 'gh-issue.sh manual-tests' 'flag <n> add manual-test-required' 'gh-retro.sh file' 'stage <n> ready-for-review' 'state.sh status done' 'state.sh current clear' 'docs(standards):' 'chore(aew): update agent memory'; do printf '%s=%s\n' "$c" "$(grep -cF -- "$c" "$f")"; done   # each >= 1
grep -cE 'git add (-A|\.)( |$)' "$f"                                  # 0
grep -cF 'git push' "$f"                                              # 0 (only git-branch.sh push; the Bash guard blocks the literal)
```

**Step 4: commit.**

```
feat(ship): add the PR and finish reference

The orchestrator commits the standards docs and the doc-writer's outputs
(DESIGN 8.7 wins over the prompt, C1) plus the agents' memory, then
pushes with git-branch.sh, creates or updates the PR from state.pr, files
the manual-tests block and flag, files the retro (a failure only warns),
sets ready-for-review, marks the run done and clears current.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B7 — `references/final-report.md`

- **id:** B7
- **files:** `skills/ship/references/final-report.md` (new)
- **depends_on:** [B1]
- **pattern:** DESIGN §9 "Final report" bullets; `templates/artefacts/summary.md` (`- [x] AC-n`) and `manual-tests.md` (`- [ ] **TC-n`) for the counts.
- **ACs:** AC-17
- **Size:** about 40–60 lines.

**Step 1: RED.** `test -f skills/ship/references/final-report.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Format` (verbatim block; lines in angle brackets are filled in):
  ```
  aew ship #<n> <title>: <done | blocked | failed>
  PR: <url>
  ACs passed: <passed>/<total>
  Review cycles: <review_cycle>/<max_review_cycles>
  Fix cycles: <fix_cycle>/<max_fix_cycles>
  Manual tests outstanding: <count>
  Retro items filed: <count> (<created #a, commented #b>)
  Next: <next action>
  ```
  The `Next:` line: `done` → `review and merge the PR`; `blocked` → `Resume with /aew:resume <id>`; `failed` → `restart with /aew:ship <n> --from <stage>`. Warnings (preflight check 6, check 4's ahead-only warning, leftover dirty paths, a failed retro, a failed `gh` call on the blocked path) follow as `Warning: …` lines.
- `## Counting`. The artefacts are never read, only counted:
  - passed `grep -c '^- \[x\] AC-' .aew/runs/<id>/10-summary.md`; total `grep -cE '^- \[[ x]\] AC-' .aew/runs/<id>/10-summary.md`;
  - manual tests `grep -c '^- \[ \]' .aew/runs/<id>/manual-tests.md`;
  - retro: the number of `created #` and `commented #` lines that `gh-retro.sh` printed this session;
  - title, `pr` and the cycles from `jq -r '.title, .pr, .review_cycle, .fix_cycle' .aew/runs/<id>/state.json`, **not** `state.sh get` (it only reads the run named in `.aew/runs/current`, which `## Finish` and the plan-gate stop have already cleared; verified: `state.sh get` exits 1 with "no current run"); the limits from `SKILL.md` `## Run variables`.
  - One line: `grep -c` exits 1 when the count is 0; read the printed number, and treat a missing file as 0 (or `n/a` for the ACs).
- `## Blocked and failed runs` (AC-17): the same format. `PR:` is replaced by `Reason: <reason>` (with `PR: <url>` kept as well when `state.pr` is set). `ACs passed: n/a` when `10-summary.md` is absent. A plan-gate stop adds the PD-11 line `The awaiting-approval label stays on the issue.`

**Step 3: GREEN.**

```sh
f=skills/ship/references/final-report.md
for h in '## Format' '## Counting' '## Blocked and failed runs'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
for l in 'PR: <url>' 'ACs passed: <passed>/<total>' 'Review cycles: <review_cycle>/<max_review_cycles>' 'Fix cycles: <fix_cycle>/<max_fix_cycles>' 'Manual tests outstanding: <count>' 'Retro items filed:' 'Resume with /aew:resume <id>'; do printf '%s=%s\n' "$l" "$(grep -cF -- "$l" "$f")"; done   # each >= 1
printf -- '- [x] AC-1: a (TC-1)\n- [ ] AC-2: b (TC-2)\n- [x] AC-3: c (TC-3)\n' > tests/tmp/summary-probe.md
grep -c '^- \[x\] AC-' tests/tmp/summary-probe.md; grep -cE '^- \[[ x]\] AC-' tests/tmp/summary-probe.md   # 2 then 3
rm tests/tmp/summary-probe.md
```

**Step 4: commit.**

```
feat(ship): add the final-report reference

The DESIGN 9 report for every outcome: PR link (or the reason and resume
hint), ACs passed out of the total, review and fix cycles against their
limits, manual tests outstanding and retro items filed, all counted with
grep -c rather than read.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B8 — Cross-file consistency pass

- **id:** B8
- **files:** any of `skills/ship/SKILL.md` and `skills/ship/references/*.md`, **only** to fix a mismatch found below
- **depends_on:** [B2, B3, B4, B5, B6, B7]
- **pattern:** the I-7 name-hygiene rules. This is the same kind of check Phase E's `skills.bats` will automate, run by hand now so that Phase C reads files that agree with each other.
- **ACs:** AC-1 (links resolve), AC-19 (every read the references make is in the reads table), AC-20 (re-checked)

**Step 1: RED.** None. This is a verification task, and it starts from the wave-2 state. If every check below passes the first time, there is no commit, and the task report records the outputs.

**Step 2: run the checks and fix mismatches in place.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
# 1. Every ${CLAUDE_PLUGIN_ROOT}/ path exists, and none has a placeholder.
grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' skills/ship | sed 's/[.,]*$//' | sort -u | while read -r p; do f=${p#'${CLAUDE_PLUGIN_ROOT}/'}; [ -e "$f" ] || echo "MISSING $f"; done   # no output
grep -rnE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' skills/ship                                            # no output
# 2. Every aew:<name> is a real agent or one of the allowed slash commands (I-7).
grep -rhoE '/?aew:[a-z][a-z-]*' skills/ship | sort -u
# expected subset of: /aew:init /aew:prompt /aew:resume /aew:ship /aew:ship-milestone /aew:status aew:brief-compiler aew:developer aew:doc-writer aew:qa-engineer aew:senior-engineer aew:spec-analyser aew:standards-setter
for a in $(grep -rhoE '(^|[^/])aew:[a-z][a-z-]*' skills/ship | sed -E 's/^[^a]*aew://' | sort -u); do test -f "agents/$a.md" || echo "NOT AN AGENT $a"; done   # no output
# 3. No prefixed label names anywhere.
grep -rnE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' skills/ship   # no output
# 4. Every cited section exists (citation form from B1 Rules: `<file>.md` `## <heading>`).
grep -ohE '[A-Za-z-]+\.md` `## [^`]+' skills/ship/SKILL.md skills/ship/references/*.md | sed 's/` `/|/' | sort -u |
  while IFS='|' read -r file h; do
    case "$file" in SKILL.md) p=skills/ship/SKILL.md ;; *) p=skills/ship/references/$file ;; esac
    grep -qxF "$h" "$p" 2>/dev/null || echo "BROKEN $file -> $h"
  done                                                                # no output
# 5. Gate ids, dispatch rows and stage names agree across files.
for g in spec plan-challenge triage spec-ambiguity plan-approval; do printf '%s %s\n' "$g" "$(grep -rlxF "## Gate: $g" skills/ship | tr '\n' ' ')"; done   # each lists only gates.md
grep -ohE 'D[0-9]+' skills/ship/SKILL.md skills/ship/references/*.md | sort -u   # only D1–D13
for r in $(grep -ohE 'D[0-9]+' skills/ship/SKILL.md skills/ship/references/*.md | sort -u); do grep -q "^| $r |" skills/ship/references/dispatch.md || echo "UNDEFINED $r"; done   # no output
# 6. Each bounded read named in the references is a row of the SKILL.md reads table: check by eye that every awk/grep -c/jq read in gates.md, routing.md, pr.md and final-report.md has a row in "## What the orchestrator reads".
# 7. Size, frontmatter and validation.
wc -l < skills/ship/SKILL.md                                          # < 500
claude plugin validate .                                              # passes
tests/run-script-tests.sh                                             # passes, unchanged (no script touched)
git status --porcelain                                                # only skills/ship/** (if fixes were made)
```

**Step 3: GREEN.** Every check above prints its expected output.

**Step 4: commit** (only if a fix was needed):

```
fix(ship): align cross-references between the procedure and its references

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

## Cross-phase notes for Phase F (closing docs)

Two documentation mismatches that this phase's design creates, for Phase F to fix with its DESIGN, state-machine and project-map updates:

- `skills/run-protocol/references/state-machine.md` "Failure paths": the row "Agent returns `blocked`: developer → senior-engineer (plan revision)" lacks PD-3's exceptions. Only a full-mode developer `blocked` re-plans, and only once per run; a fix-mode `blocked` or a second one goes to `blocked`.
- `scripts/git-branch.sh --help` says "the base branch is updated by preflight, not here". That has been untrue since cut 7: preflight only checks and stops. Reword it to "preflight checks the base branch is up to date; nothing updates it" (a `--help` text change only; `conventions.bats` is unaffected).

## Phase exit criteria

- `skills/ship/SKILL.md` (under 500 lines) and the six references exist, with the I-2 and I-3 headings exactly.
- The B1–B8 GREEN checks pass, `claude plugin validate .` passes, and `tests/run-script-tests.sh` is unchanged and passing.
- Contracts I-1 to I-11 hold as written. If a task changed one, it updated this plan's contract section in the same commit and recorded it in the task report for the consolidator.

## Risks (this phase)

- **The procedure drifts from the model's behaviour.** A long procedure can be followed only partly. Mitigations: `SKILL.md` is short and stepwise, the references are read at the step that needs them, and Phase E's static checks plus Phase F's S1, G1, G2 and F1/R2 runs are the behavioural proof. This phase proves structure only.
- **PD-4** (answers to questions spec-analyser did not ask) and **PD-12** (the triage question source) are untested until prompt 07, because the simulations exclude these routes (spec scope).
- **The counters survive gate re-runs.** After a material change late in the run, a re-run from `brief` may meet `review_cycle` or `fix_cycle` already near its limit and block early. That is correct under the spec ("counters are kept"); recorded for prompt 07.
- **Allowlist matching** (Phase F): the commands in I-8 avoid shell variables. Two forms still need checking in P0/S1 against the explicit allowlist: the `$(jq …)` substitution in 3.5, and the `cat > <tmpfile> <<'EOF'` heredoc. If either is denied, the fallback is to pass the title as a literal argument and write the comment file with Write to a path under `$TMPDIR`.

## Approval (Phase B)

- Senior architect: APPROVED 2026-10-25T00:14:54Z (plan-review FULL, then plan-diff-review of the revision round)
- Plan format: FULL
- Plan dependency graph: valid. Waves: 3 (B1; B2 to B7 in parallel; B8). Max wave width: 6.
- Plan content hash (SHA-256, the document above this trailer): 60a6bfe4f7fc5f5ef6657971cd8985901bf6e6bcb0357b78940701961d9759c8
