# Phase C plan — resume, status and prompt

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583…6090`), overridden where they differ by the CTO simplicity-challenge cuts (2026-10-25, all adopted). The cut that binds this phase is **1**: R1 is not simulated, so `tests/scripts/skills.bats` must be able to check statically that `resume` names the pending-gate re-ask (contract K-3).
- **Phase:** C of the EPIC. `depends_on: [B]`. This phase Reads Phase B's `skills/ship/SKILL.md` and references and enters them at the sections named in Phase B's contract I-2 to I-5 (treated as binding). Phase E's `skills.bats` greps the strings in contract K-3. Phase F's R2 run drives `resume` headless and takes its commands from K-4. Phase D's note applies: `init` keeps flat scratch files (`init-*.json`, `init-pr-body.md`) under `.aew/runs/`, so `status` lists only directories whose names are run ids.
- **Depth:** lean (pattern references and section outlines; no inline skill text beyond the verbatim contract strings)
- **ACs covered:** AC-21, AC-22, AC-23
- **Risk:** none of the risky criteria. Three Markdown skills with no runtime effect until a user types the command. `status` writes nothing.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" is the spec's assumption n, "AC-n" the spec's ACs, "cut n" the CTO cut n, `I-n`, `D<n>` and `PD-n` are Phase B's contract items, dispatch rows and plan-level decisions. This phase's own items are `K-1`–`K-5` (contract) and `PC-1`–`PC-6` (plan-level decisions). Task ids are `C1`–`C3`.

> **For agentic workers:** implement task by task. These are documentation tasks, so each task's RED is a check that fails before the change (the file is absent) and its GREEN is the same checks passing. Record both outputs in the task report. Write the skill text from the outlines below in your own words, in British English. Headings, frontmatter, error lines, notes and commands marked **verbatim** are contracts: copy them exactly. Use Phase B's citation form (`` `<file>.md` `## <heading>` ``, I-2 / B1 Rules). In this phase's files `` `SKILL.md` `` always means ship's `skills/ship/SKILL.md`, `` `preflight.md` ``, `` `dispatch.md` `` and `` `gates.md` `` mean the files under `skills/ship/references/`, and `` `prompt/SKILL.md` `` means `skills/prompt/SKILL.md`. Never write a placeholder heading in citation form (write "ship's stage section `## Stage: <stage>`", not `` `SKILL.md` `## Stage: <stage>` ``), so every citation resolves.

**Goal:** three main-thread skills. `resume` continues an interrupted run from `state.json` by reading ship's procedure with Read and entering it at the recorded stage or the pending gate. `status` is a read-only view of one run or every run. `prompt` runs ship's run start and spec gate, then the brief-compiler in prompt mode, and offers to post `prompt.md`.

**Architecture:** one `SKILL.md` per skill, no `references/` directories (each is well under 200 lines, and the procedure they reuse is ship's). `resume` and `prompt` state the plugin root in their own substituted body and Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and its references, never invoking `ship` through the Skill tool (V-1: `disable-model-invocation: true` blocks it; V-5: only the loaded body is substituted). `status` reads `state.json`, `log.md` and `.aew/config.json` with `jq`, `cat` and `tail` only. No script, hook, agent, template or ship file changes in this phase.

**Tech stack:** Markdown skill files; jq 1.7.1, zsh and bash 3.2 for the inline commands (both dry-run while planning, see C2); `claude plugin validate .`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` | `<spec-summary>`, AC-21–23, Assumptions 2, 4, 5, 11, 21, V-1, V-5 |
| CTO cuts (scratchpad `simplicity-adopted.md`) and docs facts (`docs-facts.md`) | Cut 1; facts 1 and 2 (Skill tool blocked; substitution in the body only) |
| `docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-B.md` | Interface contract I-1–I-10, PD-1, PD-2, PD-5, B1 Step 3 and Step 4 sub-steps, B2 checks, B4 `## Gate: spec` and `## Re-asking a pending gate` |
| `scripts/state.sh --help` | Every write acts on the run named in `.aew/runs/current`; `init` sets it; `get` reads only the current run (so `status` uses `jq`) |
| `templates/state.schema.json` | Run-id pattern `^([1-9][0-9]*\|m-[1-9][0-9]*)$`, the six statuses, `mode` values, `history[].note` |
| `agents/brief-compiler.md` (prompt mode) | `prompt.md` has no return block in the file; the return block is in the final message only |
| `skills/ui-qa/SKILL.md` lines 1–10 | Frontmatter style |
| `docs/superpowers/plans/phases/2026-10-24-build-agents-phase-A.md` | Format mirrored here |

Gotchas that apply: `${CLAUDE_PLUGIN_ROOT}` is not in the Bash tool's environment, so scripts are called by the substituted absolute path; `state.sh` writes need `current` to name the run first; the Bash tool runs zsh on this machine, where an unmatched glob is an error (`no matches found`) rather than the literal word; agent memory under `.claude/agent-memory/` is ignored by the restart form of ship's tree check (PD-2).

## Plan-level decisions (refinements the spec leaves open; flag if wrong)

- **PC-1 Prompt-mode marker** (Phase B I-11 marker, now fixed there; I-11 is binding). Straight after ship's sub-step 3.2 (`state.sh init`) and before the fetch (3.3), `prompt` writes `state.sh stage spec_analysis --note "prompt"` (verbatim, I-11). It doubles as D1's state write, and because it precedes the fetch, a fetch failure or closed issue still leaves a marked run (so `resume` and `status` give PC-6's hint, not ship's). Phase B's I-11 check is the marker alone (`jq '[.history[] | select(.note == "prompt")] | length'` ≥ 1); this plan keeps the stricter `branch == null` guard below, **pending reconciliation with Phase B's reviewer** (if B adopts the guard in I-11, use B's command verbatim; if B rejects it, this test drops the `branch` half). A run is a **prompt-mode run** when this jq test prints `prompt` (verbatim; used by `resume` and `status`):
  `jq -r 'if (.branch == null) and any(.history[]; .note == "prompt") then "prompt" else "ship" end' .aew/runs/<id>/state.json`
  The `branch == null` half matters: after `/aew:prompt 5`, `/aew:ship 5 --from spec_analysis` turns the run into a pipeline run (Step 4.5 creates the branch), and from then on it must resume as a ship run. Without this, an unanswered gate in prompt mode would tell James `Answer with /aew:resume <id>` (ship's `## Gate pending`) and resume would carry on into the full pipeline.
- **PC-2 Resuming a prompt-mode run.** `resume` Reads `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md` (as well as ship's files), skips the tree and branch checks (prompt commits nothing, AC-23), and enters `prompt/SKILL.md` at the section for the recorded stage, or at the re-asked spec gate under the prompt-mode rule (I-5).
- **PC-3 Prompt's stop.** An agent `blocked`/`failed` after ship's one retry, or a script failure, in prompt mode: `state.sh status blocked --note "<reason>"`, keep `current`, print the reason and `Resume with /aew:resume <n>`. No GitHub comment and no label: prompt mode sets no stage labels (AC-23, Assumption 21), and ship's `## Blocked path` would set `blocked`.
- **PC-4 Resume's own checks.** For a run it will continue, `resume` runs `preflight.md` checks 1, 3 and 5 (config, gh auth, no other active run; Check 5 already treats a resume of this run as allowed), then, for ship runs only, Check 2 in its restart form and the branch check. It skips checks 4 and 6 (the default branch no longer matters mid-run).
- **PC-5 Modes.** `resume` continues only `single` runs in this release. Any other `mode` stops with a message pointing at `/aew:ship-milestone` (prompt 06 extends resume, DESIGN §10). `status` shows every mode.
- **PC-6 Failed prompt-mode runs** (fetch failure or closed issue): `prompt` refuses an existing run dir (Assumption 21), so the hint is "remove `.aew/runs/<n>`, then run `/aew:prompt <n>` again". A finished prompt run can be built with aew via `/aew:ship <n> --from spec_analysis` (ship's restart checks allow a null branch at `spec_analysis`), and `prompt`'s finish message says so.

## Interface contract (Phase E and F rely on this)

### K-1. Frontmatter (verbatim)

```yaml
---
name: resume
description: Continue an interrupted aew run from its state.json - re-asks a pending gate, or re-enters the ship procedure at the recorded stage after checking the branch and working tree. Run it as /aew:resume [<run-id>].
disable-model-invocation: true
argument-hint: "[<run-id>]"
---
```

```yaml
---
name: status
description: Read-only view of aew runs in this project - with no argument lists every run (id, status, stage, updated, current, title); with a run id shows its state, the last 10 log lines, the review and fix cycles used, and the next action. Run it as /aew:status [<run-id>].
argument-hint: "[<run-id>]"
---
```

```yaml
---
name: prompt
description: Turn one GitHub issue into a single self-contained prompt (prompt.md) for a plain Claude Code session - spec analysis with the same material-change gate as ship, then the brief compiler in prompt mode. No branch, no commits, no stage labels. Run it as /aew:prompt <issue>.
disable-model-invocation: true
argument-hint: "<issue>"
---
```

In all three: no `allowed-tools`, no `` !`cmd` ``, no `$N` or `$ARGUMENTS[N]`, exactly one `$ARGUMENTS` (in Step 1). `status` has **no** `disable-model-invocation` (no side effects, DESIGN §5.1).

### K-2. Headings, in this order (verbatim; each exactly once)

| `skills/resume/SKILL.md` | `skills/status/SKILL.md` | `skills/prompt/SKILL.md` |
|---|---|---|
| `# aew resume` | `# aew status` | `# aew prompt` |
| `## Plugin root` | `## Rules` | `## Plugin root` |
| `## Rules` | `## Step 1. Parse the argument` | `## Rules` |
| `## Step 1. Pick the run` | `## List every run` | `## Step 1. Parse the argument` |
| `## Step 2. Read the state` | `## Show one run` | `## Step 2. Preflight` |
| `## Step 3. Finished runs` | `## Next action` | `## Step 3. Start the run` |
| `## Step 4. Checks` | | `## Step 4. Analyse the spec` |
| `## Step 5. Continue` | | `## Step 5. Compile the prompt` |
| | | `## Step 6. Finish` |
| | | `## Stopping` |

`resume` cites `` `prompt/SKILL.md` `## Step 4. Analyse the spec` `` and `` `prompt/SKILL.md` `## Step 5. Compile the prompt` `` (PC-2), which is why these two headings are contract.

### K-3. Strings Phase E's `skills.bats` greps (fixed strings; counts ≥ 1 unless stated)

- **resume** (cut 1: the static proof that resume re-asks a pending gate):
  - `` `gates.md` `## Re-asking a pending gate` `` — the pending-gate re-ask
  - `awaiting_input` and `awaiting_plan_approval` (both on the line or bullet that sends to the re-ask)
  - `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md`
  - `with the Skill tool` (in the sentence "Never invoke `ship` or `prompt` with the Skill tool: both set `disable-model-invocation: true`, which blocks it.", verbatim)
  - `Steps 1–4` (skip ship's argument parsing, preflight, run start and restart) and `## Stage: <stage>` and `the note \`resume\``
  - `` `preflight.md` `## Check 2. Clean working tree` ``, `restart form` and `git status --porcelain --untracked-files=all`
  - `state.sh current set <id>`
  - `/aew:ship <n> --from <stage>` (the failed-run hint)
  - error lines (verbatim, `<…>` filled in):
    - `aew resume: no current run. Name one: /aew:resume <run-id> (/aew:status lists the runs).`
    - `aew resume: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).`
    - `aew resume: unexpected argument "<token>".`
    - `aew resume: no run <id> (.aew/runs/<id>/state.json is missing).`
    - `aew resume: run <id> is a <mode> run; milestone runs are resumed by /aew:ship-milestone (coming in a later release).`
    - usage line `Usage: /aew:resume [<run-id>]`
- **status**:
  - absent (count 0): `^disable-model-invocation`, any of `state.sh`, `gh-issue.sh`, `gh-labels.sh`, `gh-pr.sh`, `gh-retro.sh`, `git-branch.sh`, `gh (auth|issue|pr|label|api|repo)`, `git (add|commit|switch|checkout|push|merge|rebase|reset|stash|fetch|pull|branch|status)` — status names no script and runs no git or gh command
  - the run-id pattern `^([1-9][0-9]*|m-[1-9][0-9]*)$` and the glob `.aew/runs/*/state.json`
  - `tail -n 10`, `max_review_cycles // 2`, `max_fix_cycles // 3`
  - the I-5 pending-gate lookup command (verbatim from Phase B)
  - the `## Next action` table: one row per status, each starting `` | `<status>` | `` for `running`, `awaiting_input`, `awaiting_plan_approval`, `blocked`, `done`, `failed`
  - lines (verbatim): `No aew runs in this project.` · `aew status: no run <id>.` · `aew status: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).` · `aew status: unexpected argument "<token>".` · `Usage: /aew:status [<run-id>]`
- **prompt**:
  - `` `preflight.md` `## Check 1. Config exists` ``, `` `preflight.md` `## Check 3. gh is authenticated` ``, `` `preflight.md` `## Check 5. No other active run` ``; and **absent**: `` `preflight.md` `## Check 2 `` (count 0)
  - `` `SKILL.md` `## Step 3. Start the run` `` with `3.1` … `3.5`, and `3.6` (in "skip 3.6–3.8")
  - `` `gates.md` `## Gate: spec` ``, `` `gates.md` `## Recording a spec revision` ``, `` `gates.md` `## Gate ids and pending state` `` (the prompt-mode rule), `` `SKILL.md` `## Gate pending` ``
  - `D1`, `D2`, `D4` and `mode: prompt`
  - `state.sh stage spec_analysis --note "prompt"` (PC-1, verbatim)
  - `gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`
  - `AskUserQuestion`, `Not posted.`, `/aew:ship <n> --from spec_analysis`
  - absent (count 0): `gh-labels.sh`, `git-branch.sh`, `git (add|commit|switch|push)`
  - error lines (verbatim): `aew prompt: missing issue number.` · `aew prompt: the issue must be a positive integer, got "<token>".` · `aew prompt: unexpected argument "<token>".` · `Usage: /aew:prompt <issue>`
- **All three:** every `aew:<name>` is one of the I-7 slash commands (`/aew:ship`, `/aew:resume`, `/aew:init`, `/aew:status`, `/aew:prompt`, `/aew:ship-milestone`); `/aew:ship-milestone` is the I-7 forward reference; no prefixed label names; every `${CLAUDE_PLUGIN_ROOT}/…` path exists and has no `<placeholder>`; every citation resolves (the phase-exit `cite_check`).

### K-4. Commands these skills run (Phase F's R2 allowlist; Phase D's permission proposal)

- **resume** (besides everything ship runs from the entered section, I-8): `cat .aew/runs/current`, `test -f .aew/runs/<id>/state.json`, `jq -r …` on `state.json` (the K-5 reads), `git status --porcelain --untracked-files=all` (Phase B review fix to the restart form), `git branch --show-current`, `git switch <branch>`, `gh auth status`, `<root>/scripts/state.sh current set <id>`.
- **status:** `cat .aew/runs/current`, `test -f`, `jq …`, `tail -n 10 .aew/runs/<id>/log.md`. Nothing else.
- **prompt** (besides ship's 3.1–3.5 and D1/D2/D4 recording calls): `<root>/scripts/state.sh stage spec_analysis --note "prompt"`, `state.sh stage brief`, `state.sh status done|blocked --note …`, `state.sh current clear`, `test -f .aew/runs/<n>/prompt.md`, `<root>/scripts/gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`.

### K-5. Shared reads (verbatim; dry-run while planning against `templates/state.example.json` copies)

- Run summary for resume Step 2: `jq -r '[.status, .stage, .mode, (.issues | map(tostring) | join(",")), (.branch // "-"), (.pr // "-" | tostring)] | @tsv' .aew/runs/<id>/state.json`
- Prompt-mode test: PC-1.
- Last note (blocked or failed reason): `jq -r '.history | last | .note // ""' .aew/runs/<id>/state.json`
- Pending gate: the I-5 lookup (`null` when no `gate:` note; `gates.md` `## Re-asking a pending gate` maps that case).

## Tasks

Wave **1** = C1 ∥ C2 ∥ C3 (three new files, no shared text; they agree only through K-1–K-5). C1 and C3 start once Phase B's files are merged; C2 needs only the I-5 lookup string and can start at any time. Then the phase-exit check (no commit).

Commit trailer for every task: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task C1 — `skills/resume/SKILL.md`

- **id:** C1
- **files:** `skills/resume/SKILL.md` (new)
- **depends_on:** [B1, B2, B4] (cites ship's `SKILL.md`, `preflight.md`, `gates.md`); its `prompt/SKILL.md` citations are checked at phase exit, after C3
- **pattern:** ship's `## Plugin root` and `## Rules` wording (B1); B1's Step-section style; frontmatter style of `skills/ui-qa/SKILL.md`
- **AC:** AC-21 (and cut 1's static re-ask check)
- **Size:** about 90–150 lines

**Step 1: RED.** `test -f skills/resume/SKILL.md; echo $?` gives `1`.

**Step 2: write it** with K-1 frontmatter and K-2 headings. Outline:

- `# aew resume`: one or two sentences. Continues the run named by the argument (default: the current run) from `state.json`. It never re-runs a stage before the recorded one and never duplicates ship's procedure: it reads it.
- `## Plugin root`: "The plugin root is `${CLAUDE_PLUGIN_ROOT}`." Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names (and, for a prompt-mode run, `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md`) with the Read tool. They are not substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above. The K-3 Skill-tool sentence, verbatim. The citation-form note from the agentic-workers box above, in one line.
- `## Rules`: ship's `SKILL.md` `## Rules` apply to everything resume does once it continues a run. Before Step 5 resume writes nothing. One line: the issue, `auto`, counters, branch and base branch come from `state.json` (ship's `## Run variables`).
- `## Step 1. Pick the run`: "The argument is: `$ARGUMENTS`." Split on whitespace. No token → `cat .aew/runs/current`; missing or empty → the no-current-run error. One token matching `^([1-9][0-9]*|m-[1-9][0-9]*)$` → the id; otherwise the not-a-run-id error. More than one → the unexpected-argument error. Each error is followed by the usage line, then stop. Then `test -f .aew/runs/<id>/state.json`; missing → the no-run error.
- `## Step 2. Read the state`: the K-5 summary read and the PC-1 test. `mode` other than `single` → the K-3 mode error, stop (PC-5).
- `## Step 3. Finished runs` (Assumption 11; nothing is written):
  - `done` → `Run <id> is done: nothing to resume.` then `PR #<pr> on <branch>.` (ship run) or `The prompt is at .aew/runs/<id>/prompt.md.` (prompt-mode run). Stop.
  - `failed` → the last note (K-5), then `Run <id> failed at <stage> and is finished: restart it with /aew:ship <n> --from <stage>.` (prompt-mode run: PC-6's hint instead). Stop.
- `## Step 4. Checks` (PC-4; read-only):
  1. `preflight.md` `## Check 1. Config exists`, `preflight.md` `## Check 3. gh is authenticated`, `preflight.md` `## Check 5. No other active run` (another active run → its stop message; this run → passes).
  2. Prompt-mode runs skip items 3 and 4 below, the tree and branch checks (PC-2).
  3. `preflight.md` `## Check 2. Clean working tree` in its **restart form** (agent memory ignored, PD-2): `git status --porcelain --untracked-files=all` (verbatim; plain `--porcelain` shows an untracked `.claude/` as one entry, so the `.claude/agent-memory/` filter would never match; Phase B B2 and I-8), ignoring lines whose path starts with `.claude/agent-memory/`. Dirty → stop with that check's message, which lists the paths. Nothing is stashed, reset or discarded.
  4. Branch: `branch` null → stop with `Run <id> has no branch: restart it with /aew:ship <n> --from spec_analysis.` Otherwise `git branch --show-current`; if it differs, `git switch <branch>` (the tree is clean, so this is safe); a failed switch stops with git's first error line.
- `## Step 5. Continue`:
  1. `state.sh current set <id>` (every `state.sh` write acts on the current run).
  2. `awaiting_input` or `awaiting_plan_approval` → Read `gates.md` and follow `gates.md` `## Re-asking a pending gate`: it finds the gate from the `gate:` note and enters that gate at step 2, so only what the gate reads is re-read and state and label are not re-written. The gate's apply step then continues into ship's sections as written. No answer again → ship's `SKILL.md` `## Gate pending` (the run stays pending). A prompt-mode run is handed back to the `prompt` skill by that section itself (I-11), so resume adds nothing for it here.
  3. `running` or `blocked`, ship run (PC-1 test prints `ship`) → Read ship's `SKILL.md` and its references; skip ship's Steps 1–4 (argument parsing, preflight, run start, restart: done above or not needed); enter ship's stage section `## Stage: <stage>` at step 1 with the note `resume`. A recorded `qa_test_plan` enters `## Stage: plan` (ship's redirect). The stage entry re-writes status `running` and moves the label off `blocked`. PD-5's mode choice applies at `develop`; `qa` re-dispatches QA phase B.
  4. `running` or `blocked`, prompt-mode run → Read `prompt/SKILL.md`; `spec_analysis` → `prompt/SKILL.md` `## Step 4. Analyse the spec`, `brief` → `prompt/SKILL.md` `## Step 5. Compile the prompt`, each entered at step 1 with the note `resume`.
  5. One closing line: no `state.sh init`, no fetch, no new branch, and never a stage before the recorded one.

**Step 3: GREEN.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/resume/SKILL.md
sed -n '1,6p' "$f"                                                     # exactly the K-1 resume frontmatter
grep -cx 'disable-model-invocation: true' "$f"                         # 1
grep -cxF 'argument-hint: "[<run-id>]"' "$f"                           # 1
grep -c '^allowed-tools:' "$f"; grep -c '!`' "$f"                      # 0, 0
grep -cE '\$[0-9]|\$ARGUMENTS\[' "$f"                                  # 0
grep -o '\$ARGUMENTS' "$f" | wc -l                                     # 1
wc -l < "$f"                                                           # 90–150
grep -n '^#' "$f" | cut -d: -f2-                                       # the K-2 resume column, in order
for m in '`gates.md` `## Re-asking a pending gate`' 'awaiting_input' 'awaiting_plan_approval' '${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md' '${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md' 'with the Skill tool' 'Steps 1–4' '## Stage: <stage>' 'the note `resume`' '`preflight.md` `## Check 2. Clean working tree`' 'restart form' 'git status --porcelain --untracked-files=all' 'state.sh current set <id>' '/aew:ship <n> --from <stage>' 'aew resume: no current run.' 'is not a run id' 'aew resume: unexpected argument' 'state.json is missing' '/aew:ship-milestone' 'Usage: /aew:resume [<run-id>]'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' "$f"                      # no output
grep -oE '/?aew:[a-z-]+' "$f" | sort -u                                # subset of /aew:prompt /aew:resume /aew:ship /aew:ship-milestone /aew:status
claude plugin validate .                                               # passes as before
```

The citation check runs at phase exit (it needs C3's file).

**Step 4: commit.**

```
feat(resume): add the resume skill

/aew:resume [<run-id>] continues a run from state.json: done and failed
runs are reported, another active run or a dirty tree stops it, and the
run branch is switched to when the tree is clean. A pending gate is
re-asked through gates.md; a running or blocked run re-enters ship's
stage section for the recorded stage. Ship's procedure is read with
Read under the plugin root, never through the Skill tool, which
disable-model-invocation blocks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task C2 — `skills/status/SKILL.md`

- **id:** C2
- **files:** `skills/status/SKILL.md` (new)
- **depends_on:** [] (uses only the I-5 lookup string and PC-1's test, both fixed in contracts)
- **pattern:** frontmatter style of `skills/ui-qa/SKILL.md`; the reads are new (no analog: nothing in the repo lists runs)
- **AC:** AC-22 (with the Phase D note: list only run-id directories, never `current` or `init-*` files)
- **Size:** about 70–120 lines

**Step 1: RED.** `test -f skills/status/SKILL.md; echo $?` gives `1`.

**Step 2: write it** with K-1 frontmatter and K-2 headings. Outline:

- `# aew status`: one sentence: a read-only view of aew runs.
- `## Rules`: read-only. It writes no file, runs no plugin script, no git and no gh command; it reads `state.json` with `jq` because the state script's `get` reads only the current run (do not name the script, so the K-3 absence check holds). Paths are relative to the project root.
- `## Step 1. Parse the argument`: "The argument is: `$ARGUMENTS`." No token → `## List every run`. One token matching `^([1-9][0-9]*|m-[1-9][0-9]*)$` → `## Show one run`. Otherwise the not-a-run-id or unexpected-argument line, then the usage line, then stop.
- `## List every run`:
  1. `cat .aew/runs/current` (missing or empty → no current run).
  2. One `jq` read (verbatim; `<cur>` is step 1's id or empty). The glob matches only directories that hold a `state.json`, so `.aew/runs/current` and init's flat `init-*` scratch files never match, and the `test()` keeps only run-id names:
     ```sh
     jq -r --arg cur '<cur>' 'input_filename as $f | ($f | split("/") | .[-2]) as $id | select($id | test("^([1-9][0-9]*|m-[1-9][0-9]*)$")) | [$id, .status, .stage, .updated_at, (if $id == $cur then "current" else "-" end), .title] | @tsv' .aew/runs/*/state.json
     ```
  3. Print a table `| Run | Status | Stage | Updated | Current | Title |`. No output, `no matches found` (zsh) or `Could not open file` (bash) → `No aew runs in this project.`
- `## Show one run`:
  1. `test -f .aew/runs/<id>/state.json`; missing → `aew status: no run <id>.`
  2. State fields (verbatim): `jq -r 'del(.history) | to_entries[] | "\(.key): \(.value | if type == "array" then map(tostring) | join(",") else tostring end)"' .aew/runs/<id>/state.json`
  3. Last 10 log lines: `tail -n 10 .aew/runs/<id>/log.md`.
  4. Cycles: `jq -r '"\(.limits.max_review_cycles // 2) \(.limits.max_fix_cycles // 3)"' .aew/config.json` (no config → the schema defaults 2 and 3, say so); print `review <review_cycle>/<max_review_cycles>, fix <fix_cycle>/<max_fix_cycles>`.
  5. For `awaiting_*`: the I-5 lookup (verbatim) names the gate; `null` → `plan-approval` for `awaiting_plan_approval`, `spec` for `awaiting_input` (B4's mapping). For `blocked`/`failed`: the K-5 last-note read gives the reason. PC-1's test marks a prompt-mode run.
  6. Then `## Next action`.
- `## Next action` (table `| Status | Next action |`, one row per status, verbatim first cells):
  - `running` — if no session is driving it (interrupted), `/aew:resume <id>`; otherwise wait.
  - `awaiting_input` — answer the `<gate>` gate with `/aew:resume <id>`.
  - `awaiting_plan_approval` — approve, change or stop the plan with `/aew:resume <id>` (the plan is `.aew/runs/<id>/05-plan.md`).
  - `blocked` — fix the reason shown, then `/aew:resume <id>`.
  - `done` — nothing to do: PR #<pr> (prompt-mode run: `.aew/runs/<id>/prompt.md`).
  - `failed` — finished: `/aew:ship <n> --from <stage>` (prompt-mode run: PC-6's hint).
  - One line under the table: a run whose mode is not `single` is handled by `/aew:ship-milestone` (coming in a later release).

**Step 3: GREEN.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/status/SKILL.md
sed -n '1,5p' "$f"                                                     # exactly the K-1 status frontmatter
grep -c '^disable-model-invocation' "$f"; grep -c '^allowed-tools:' "$f"; grep -c '!`' "$f"   # 0, 0, 0
grep -cxF 'argument-hint: "[<run-id>]"' "$f"                           # 1
grep -o '\$ARGUMENTS' "$f" | wc -l                                     # 1
wc -l < "$f"                                                           # 70–120
grep -n '^#' "$f" | cut -d: -f2-                                       # the K-2 status column, in order
grep -cE 'state\.sh|gh-issue\.sh|gh-labels\.sh|gh-pr\.sh|gh-retro\.sh|git-branch\.sh' "$f"   # 0
grep -cE 'gh (auth|issue|pr|label|api|repo)' "$f"                      # 0
grep -cE 'git (add|commit|switch|checkout|push|merge|rebase|reset|stash|fetch|pull|branch|status)' "$f"   # 0
for m in '^([1-9][0-9]*|m-[1-9][0-9]*)$' '.aew/runs/*/state.json' 'tail -n 10' 'max_review_cycles // 2' 'max_fix_cycles // 3' "[.history[] | select((.note // \"\") | startswith(\"gate:\"))] | last | .note" 'No aew runs in this project.' 'aew status: no run <id>.' 'is not a run id' 'aew status: unexpected argument' 'Usage: /aew:status [<run-id>]'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
for s in running awaiting_input awaiting_plan_approval blocked done failed; do printf '%s=%s\n' "$s" "$(grep -c "^| \`$s\` |" "$f")"; done   # each =1
```

Dry-run of the listing (copy the `jq` command from the written file, not from this plan; the scratch tree is outside the repo):

```sh
W="${TMPDIR%/}/aew-status-check"; R=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
rm -rf "$W" && mkdir -p "$W/.aew/runs/42" "$W/.aew/runs/7" "$W/.aew/runs/m-3" "$W/.aew/runs/junk" && cd "$W"
cp "$R/templates/state.example.json" .aew/runs/42/state.json
jq '.run_id = "7" | .issues = [7] | .status = "awaiting_input" | .history += [{"stage":"spec_analysis","status":"awaiting_input","at":"2026-10-24T11:00:00Z","note":"gate:spec 01-spec-analysis.md"}]' .aew/runs/42/state.json > .aew/runs/7/state.json
cp .aew/runs/7/state.json .aew/runs/junk/state.json; echo '{}' > .aew/runs/init-config.json; echo 42 > .aew/runs/current
# now run the listing jq with <cur> = 42
```

Expected (planning dry-run, zsh): two lines, `42	running	review	2026-10-24T10:42:00Z	current	Add a newsletter sign-up form to the footer` and `7	awaiting_input	review	…	-	…`. `junk`, `m-3` (no `state.json`), `current` and `init-config.json` are absent. In an empty directory zsh prints `no matches found` (exit 1) and bash `Could not open file` (exit 2): both mean "No aew runs". The I-5 lookup on run 7 prints `gate:spec 01-spec-analysis.md`, on run 42 `null`; the state-fields read prints `issues: 7`; the cycles read prints `2 3` on `templates/config.example.json` and on `{}`. Paste the outputs into the task report, then `rm -rf "$W"`.

**Step 4: commit.**

```
feat(status): add the read-only status skill

/aew:status lists every run directory whose name is a run id (so the
current pointer and init's scratch files never show), with status,
stage, last update and which run is current. With a run id it shows the
state fields, the last 10 log lines, the review and fix cycles used
against their limits, the pending gate, and the next action per status.
It writes nothing and runs no script, git or gh command.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task C3 — `skills/prompt/SKILL.md`

- **id:** C3
- **files:** `skills/prompt/SKILL.md` (new)
- **depends_on:** [B1, B2, B3, B4] (cites ship's `SKILL.md`, `preflight.md`, `dispatch.md`, `gates.md`)
- **pattern:** ship's `## Plugin root`, Step and Stage section style (B1); dispatch rows D1, D2, D4 (I-4); `gates.md` `## Gate: spec` and `## Recording a spec revision` (B4)
- **AC:** AC-23
- **Size:** about 100–160 lines

**Step 1: RED.** `test -f skills/prompt/SKILL.md; echo $?` gives `1`.

**Step 2: write it** with K-1 frontmatter and K-2 headings. Outline:

- `# aew prompt`: one or two sentences: writes `prompt.md`, a single self-contained prompt for a plain Claude Code session (DESIGN §8.2 prompt mode). No branch, no commits, no stage labels; the only GitHub writes are a recorded spec revision and, if James agrees, the `prompt.md` comment.
- `## Plugin root`: as `resume`'s (root sentence; Read ship's `SKILL.md` and references; literal `${CLAUDE_PLUGIN_ROOT}` = this root; the Skill-tool sentence, here naming `ship`).
- `## Rules`: ship's `SKILL.md` `## Rules` apply, except that this skill creates no branch, makes no commit, sets no stage label (`gates.md` `## Gate ids and pending state`, the prompt-mode rule) and runs no tree or default-branch check. Do not name the label or branch scripts (K-3 absence check).
- `## Step 1. Parse the argument`: "The argument is: `$ARGUMENTS`." Exactly one token matching `^[1-9][0-9]*$`. Errors (K-3, verbatim), each followed by the usage line: none → missing; first token not a positive integer → positive-integer error; a second token → unexpected argument. Nothing runs or is written in this step.
- `## Step 2. Preflight`: Read `preflight.md`; run `preflight.md` `## Check 1. Config exists`, `preflight.md` `## Check 3. gh is authenticated`, `preflight.md` `## Check 5. No other active run`, in that order, with their messages. Not checks 2, 4 or 6: nothing is committed or branched (AC-23).
- `## Step 3. Start the run`: Read ship's `SKILL.md`; run `SKILL.md` `## Step 3. Start the run` sub-steps 3.1–3.5 only, and skip 3.6–3.8 (label, branch, stage entry). Overrides: 3.1's stop message becomes `Run <n> already exists, and aew prompt only starts new runs: check it with /aew:status <n>.` (Assumption 21); 3.3 and 3.4 keep their state writes but print `Could not fetch issue #<n>: <reason>. Fix it, remove .aew/runs/<n>, then run /aew:prompt <n> again.` (PC-6). Between 3.2 and 3.3, the marker write `state.sh stage spec_analysis --note "prompt"` (PC-1, I-11, verbatim), which is also D1's state write.
- `## Step 4. Analyse the spec`:
  1. Entry, on resume only: `state.sh stage spec_analysis --note "resume"`.
  2. Required files (`dispatch.md` `## Required inputs per stage`); missing → `## Stopping` below.
  3. Dispatch D1 (`dispatch.md` `## Dispatch table`, `dispatch.md` `## How to dispatch`).
  4. Return check (`dispatch.md` `## Return check`, `dispatch.md` `## Retries`).
  5. `ok` → `gates.md` `## Recording a spec revision` (it sets the `spec-revised` flag when a revision is recorded) → Step 5. `needs_input` → `gates.md` `## Gate: spec` under the prompt-mode rule; at its step 4 the D2 re-dispatch returns here, to sub-step 4, instead of ship's spec-analysis stage. No answer → `SKILL.md` `## Gate pending` (resume continues it, PC-2). `blocked` or `failed` after the retry → `## Stopping` below.
- `## Step 5. Compile the prompt`:
  1. Entry: `state.sh stage brief` (D4's state write; with `--note "resume"` on resume). No label.
  2. Required files: `spec-final.md`, `issue.json`.
  3. Dispatch D4 (`mode: prompt`).
  4. Return check on the Agent result only (`prompt.md` has no return block in the file), then `test -f .aew/runs/<n>/prompt.md`.
  5. `ok` → Step 6. Anything else after the retry → `## Stopping`.
- `## Step 6. Finish`:
  1. `state.sh status done --note "prompt written"`, then `state.sh current clear`.
  2. Print `Prompt written: .aew/runs/<n>/prompt.md`, the spec version (and whether a revision was recorded), and `To build it with aew instead: /aew:ship <n> --from spec_analysis.`
  3. Offer with AskUserQuestion, one question `Post prompt.md as a comment on issue #<n>?`, options `Post it` and `Do not post`. AskUserQuestion not among the tools (headless), refused, empty, or `Do not post` → print `Not posted.` and stop. Do not try to call a tool you do not have.
  4. `Post it` → `gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`; print the comment URL it prints. A failure prints a warning with the first stderr line; the run stays `done`.
- `## Stopping` (PC-3): `state.sh status blocked --note "<reason, one line>"`, keep `current`, print `aew prompt #<n>: blocked at <stage>: <reason>.` then `Resume with /aew:resume <n>`, and stop. No issue comment and no label. Script failures after Step 3 (for example a `gh-issue.sh revise` refusal) come here too.

**Step 3: GREEN.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/prompt/SKILL.md
sed -n '1,6p' "$f"                                                     # exactly the K-1 prompt frontmatter
grep -cx 'disable-model-invocation: true' "$f"                         # 1
grep -cxF 'argument-hint: "<issue>"' "$f"                              # 1
grep -c '^allowed-tools:' "$f"; grep -c '!`' "$f"                      # 0, 0
grep -cE '\$[0-9]|\$ARGUMENTS\[' "$f"                                  # 0
grep -o '\$ARGUMENTS' "$f" | wc -l                                     # 1
wc -l < "$f"                                                           # 100–160
grep -n '^#' "$f" | cut -d: -f2-                                       # the K-2 prompt column, in order
for m in '`preflight.md` `## Check 1. Config exists`' '`preflight.md` `## Check 3. gh is authenticated`' '`preflight.md` `## Check 5. No other active run`' '`SKILL.md` `## Step 3. Start the run`' '3.1' '3.5' '3.6' '`gates.md` `## Gate: spec`' '`gates.md` `## Recording a spec revision`' '`gates.md` `## Gate ids and pending state`' '`SKILL.md` `## Gate pending`' 'D1' 'D2' 'D4' 'mode: prompt' 'state.sh stage spec_analysis --note "prompt"' 'gh-issue.sh comment <n> .aew/runs/<n>/prompt.md' 'AskUserQuestion' 'Not posted.' '/aew:ship <n> --from spec_analysis' 'with the Skill tool' 'aew prompt: missing issue number.' 'aew prompt: the issue must be a positive integer, got' 'aew prompt: unexpected argument' 'Usage: /aew:prompt <issue>' '${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
grep -cF '`preflight.md` `## Check 2' "$f"                             # 0
grep -cE 'gh-labels\.sh|git-branch\.sh' "$f"                           # 0
grep -cE 'git (add|commit|switch|push)' "$f"                           # 0
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' "$f"                      # no output
grep -oE '/?aew:[a-z-]+' "$f" | sort -u                                # subset of /aew:prompt /aew:resume /aew:ship /aew:status
claude plugin validate .                                               # passes as before
```

**Step 4: commit.**

```
feat(prompt): add the prompt skill

/aew:prompt <issue> runs config, gh auth and active-run preflight, ship's
run start without a label or branch, spec analysis with the same
material gate and revision recording (read from ship's gates.md), and
the brief compiler in prompt mode. It marks the run as prompt mode so
resume can continue it, prints the prompt.md path, and offers to post it
as an issue comment; an unanswered offer posts nothing.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

## Phase exit check (after C1–C3; no commit)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
cite_check() {   # one line per distinct citation in $1; each must end in =1
  grep -oE '`(prompt/SKILL|SKILL|preflight|dispatch|gates|routing|pr|final-report)\.md` `## [^`]+`' "$1" | sort -u |
  while IFS= read -r c; do
    f=${c%%'` `'*}; f=${f#'`'}; h=${c#*'` `'}; h=${h%'`'}
    case $f in
      SKILL.md) p=skills/ship/SKILL.md ;;
      prompt/SKILL.md) p=skills/prompt/SKILL.md ;;
      *) p=skills/ship/references/$f ;;
    esac
    printf '%s=%s\n' "$c" "$(grep -cxF -- "$h" "$p")"
  done
}
for s in resume status prompt; do echo "== $s"; cite_check "skills/$s/SKILL.md"; done      # every line =1 (status has none)
for s in resume prompt; do grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `),;]+' "skills/$s/SKILL.md"; done | sed -e 's|^\${CLAUDE_PLUGIN_ROOT}/||' -e 's|[.:]$||' | sort -u | while IFS= read -r p; do test -e "$p" && echo "ok $p" || echo "MISSING $p"; done   # every line starts "ok"
claude plugin validate .                                                                   # passes
```

`cite_check` was dry-run under `/bin/bash` 3.2 and zsh against a scratch tree while planning: a real heading prints `=1`, a missing one `=0`. Phase E may lift it into `skills.bats` for all of `skills/{ship,resume,prompt}`.

## AC → task matrix

| AC | Task | Static evidence (this phase) | Live evidence (Phase F) |
|---|---|---|---|
| AC-21 | C1 | K-3 resume strings, incl. the `## Re-asking a pending gate` citation (cut 1) | R2 (resume after the develop kill, stopped at `review`) |
| AC-22 | C2 | K-3 status strings, absence checks, the listing dry-run | none (read-only; not simulated) |
| AC-23 | C3 | K-3 prompt strings and absence checks | none (prompt is out of the simulated routes) |

## Cross-phase notes

- **Phase E (`skills.bats`):** grep K-1 frontmatter and K-2 headings in order, and the K-3 strings (presence and the absence counts). The cut-1 check is `` `gates.md` `## Re-asking a pending gate` `` plus `awaiting_input` and `awaiting_plan_approval` in `skills/resume/SKILL.md`. Allow `/aew:ship-milestone` as a forward reference in resume and status too. Citation resolution: `` `SKILL.md` `` → `skills/ship/SKILL.md`, `` `prompt/SKILL.md` `` → `skills/prompt/SKILL.md`, the other `<name>.md` → `skills/ship/references/`; the `cite_check` above is a ready implementation.
- **Phase F (R2):** add K-4's resume commands to the allowlist union (`git status --porcelain --untracked-files=all`, `git branch --show-current`, `git switch <branch>`, `cat .aew/runs/current`, `jq`, and `state.sh current set`). If the tree is dirty after the kill, resume stops at Step 4 and lists the paths (Assumption 8's first branch).
- **Phase B:** nothing changes, but two facts now depend on it: ship's `## Stage: spec_analysis` and `gates.md` `## Gate: spec` step 4 are followed by prompt with a different return point (stated in prompt, not in ship), and Restart check 2 must keep allowing a null branch at `spec_analysis` (prompt → ship conversion, PC-6). Ship's 3.1 message ("continue it with /aew:resume <n>, or restart a stage …") is shown for a finished prompt run too, which is correct.
- **Phase B (reconciled):** (1) The restart form of `preflight.md` `## Check 2. Clean working tree` uses `git status --porcelain --untracked-files=all` (B2, I-8); C1 writes that command and K-3 greps it. (2) The prompt-run marker is I-11's `--note "prompt"`, written straight after 3.2; C3 writes it and C1/C2 test it (PC-1). Phase B's `## Re-asking a pending gate` and `## Gate: spec` step 4 check the marker and hand a prompt run back to the `prompt` skill, so C1 Step 5.2 keeps only the citation. (3) **Open with Phase B's reviewer:** I-11's marker-only check treats a prompt run converted by `/aew:ship <n> --from spec_analysis` as still a prompt run, so a spec gate on the converted run would hand back to `prompt` from `gates.md`. PC-1 adds `branch == null`; I-11 and gates.md should use the same test, whichever form is agreed.
- **Phase D:** `status` relies on init's scratch files being flat files directly under `.aew/runs/`, never a directory named like a run id.
- **Closing docs:** record PC-1 (the `prompt` history note and the prompt-mode test) in DESIGN §8.2 or the run-protocol state notes, PC-3 (a blocked prompt run posts no report comment and sets no `blocked` label: a recorded deviation from DESIGN §7's blocked rule), and PC-5 (resume continues `single` runs only until prompt 06).

## Risks

- **Prompt-mode detection is a convention, not a schema field** (PC-1). If a later change writes a bare `prompt` note elsewhere or drops `branch` from a ship run, resume would route wrongly. Mitigation: the test needs both a null branch and the exact note; ship sets the branch before its first dispatch.
- **Resume entering ship mid-flow is untested live except R2** (cut 1 removed R1). A wrong section name would surface only at runtime; the phase-exit `cite_check` and Phase E's checks are the guard.
- **Cross-skill Read relies on V-5** (literal `${CLAUDE_PLUGIN_ROOT}` in read files is not substituted). Both skills state the root in their own substituted body, as ship does.
- **zsh glob behaviour** in status: an empty runs dir gives an error rather than empty output. The skill states both outcomes mean "no runs".

## Approval (Phase C)

- Senior architect: APPROVED on 2026-10-25T00:14:31Z (plan-review, Phase C)
- Plan format: LEAN
- Plan dependency graph: valid. Wave count: 1. Max wave width: 3 tasks parallel (C1 ∥ C2 ∥ C3; C1 and C3 after B1–B4, C2 free).
- Open cross-phase item: the `branch == null` guard in PC-1 versus Phase B I-11's marker-only check (see Cross-phase notes, Phase B (3)).
- Plan content hash (SHA-256, document above this trailer): 3b47f444fd6e18050fe55163cb1db44c453d3474949e60c395105c7a9beca828
