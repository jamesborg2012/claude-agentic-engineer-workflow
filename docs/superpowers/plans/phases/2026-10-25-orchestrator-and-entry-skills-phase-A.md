# Phase A plan — Component additions the skills need

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583883f5…6090`)
- **Binding overrides:** the CTO simplicity-challenge (SIMPLER-PATH, all 11 cuts adopted). For this phase: AC-34 and AC-36 are kept as written; AC-35 is minimal (skip `03-standards.md` and "Sections that apply", nothing else); `gh-pr.sh open` bats coverage is create, reuse and invalid input only; the three changes stay three parallel tasks. Cut 8 removes the "declining the change → re-plan with `notes`" branch of AC-14, so `notes` has two sources only (plan gate request-changes, AC-9; developer `blocked`, AC-12).
- **Phase:** A of the EPIC. `depends_on: []`. Phase B (ship) consumes contracts C-1 and C-3's absence of a `create` change; Phase D (init) consumes C-2 and C-3; Phase E's `skills.bats` may grep C-1/C-2 wording; Phase F records the DESIGN §8.3/§8.4 text (see C-4).
- **Depth:** lean
- **ACs covered:** AC-34, AC-35 (agent side; the "DESIGN §8.3 records it" clause is Phase F's, per cut 10 and AC-47), AC-36
- **Risk:** none. No risk line is crossed: no auth, payments, schema, dependency or GitHub-write change beyond a new wrapper subcommand that only the orchestrator and init call.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" means the spec's assumption n. Task ids `A1`–`A3` are unrelated to those numbers.

> **For agentic workers:** implement task by task, TDD. Every task records RED before the change and GREEN after. A1 and A2 are prompt edits, so their RED is a grep that fails before the change. A3's RED is the new bats tests failing against the current `gh-pr.sh` (`unknown subcommand: open`).

**Goal:** give the orchestrator and init the three small hooks they need: a way to feed gate feedback into a senior-engineer re-plan, a run-less standards pass for init, and a run-less, idempotent PR opener.

**Architecture:** two agent-prompt edits (`agents/senior-engineer.md`, `agents/standards-setter.md`) that add an optional dispatch field and an optional mode, each defaulting to today's behaviour; one new subcommand in `scripts/gh-pr.sh` that mirrors `cmd_create` (validation before any `gh` call, number parsed from gh's URL) plus an open-PR lookup; three new tests in the existing `tests/scripts/gh-pr.bats`; `skills/github-ops/SKILL.md` rows. No new files.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `agents/senior-engineer.md` (Inputs → Dispatch fields, Files per mode, Process → Mode: plan, Outputs, Definition of done → Mode: plan) | A1 edits these sections |
| `templates/artefacts/plan.md` (`## Approach` at line 8) | Where A1's "how each note was addressed" goes; template unchanged |
| `agents/standards-setter.md` (frontmatter description, Inputs, Process steps 1, 2, 8, Outputs, Return contract) | A2 edits these sections |
| `scripts/gh-pr.sh` (`cmd_create`, `need_file`, the Usage header, the dispatch `case`) | A3's pattern and edit target |
| `tests/scripts/gh-pr.bats` (`setup`, "create prints the PR number…", "create refusals make no gh call") | A3's test pattern; new tests go in this file |
| `tests/scripts/helpers/bin/gh`, `tests/scripts/helpers/common.bash` (`gh_mock_respond`, `assert_gh_called`, `refute_gh_called`, `gh_call_count`, `gh_captured_file`) | The mock routes `pr-list` and `pr-create`: without a canned response `pr list` succeeds with empty stdout (no open PR) |
| `scripts/git-branch.sh` line 78 | `git check-ref-format --branch` is the existing branch-name check to reuse; it works outside a repo too (checked) |
| `skills/github-ops/SKILL.md` (script table, "Other calls", Operational rules, Conventions/Exceptions, Stdout contract) | A3's documentation rows |
| `scripts/hooks/gate-subagent.sh` `valid_return_block` | ARTEFACTS must be non-empty, hence `ARTEFACTS: none` in C-2 |

## Interface contract (Phases B, D, E and F rely on this)

### C-1. senior-engineer plan mode: `notes` (A1, AC-34)

- **Field:** `notes`, optional, plan mode only (ignored in review and triage). Dispatch line form `notes: <text>`. It is the **last** field of the dispatch prompt and its value runs to the end of the prompt, so it may span several lines; every other field stays a single `key: value` line before it.
- **Sources (Phase B):** James's change requests from the plan gate "request changes" option (AC-9), verbatim; or the developer's `blocked` reason (AC-12), as `developer blocked: <SUMMARY text>` plus the dev report path. Phase B's `dispatch.md` row for senior-engineer plan lists `run_dir`, `mode: plan`, and `notes` (optional, last).
- **Behaviour with `notes`:** the agent also reads the existing `<run_dir>/05-plan.md` (the plan being revised; not required — absent means plan from scratch and still address the notes), then overwrites `05-plan.md` as today. `## Approach` ends with a `Revision notes:` list, one bullet per note: the note (quoted or paraphrased in one line) → what changed in the plan, or why it was not adopted. A note that can only be met by a material spec change (the step 5 list) becomes a question in `## Challenges to the spec` and the return is `needs_input`, exactly as step 5 already works.
- **Return:** unchanged (`ok` / `needs_input` / `blocked` / `failed`; ARTEFACTS `<run_dir>/05-plan.md`). No new required files; without `notes` behaviour is byte-for-byte today's.
- **Not changed:** QA phase A is not re-run by the agent (that is Phase B's routing); `04-qa-test-plan.md` stays unread in plan mode.

### C-2. standards-setter `mode: init` (A2, AC-35)

- **Field:** `mode`, optional: `pipeline` (default, today's behaviour, requires `run_dir`) or `init`. An unknown mode is `STATUS: blocked`.
- **Dispatch (Phase D):** exactly `mode: init`. No `run_dir`; the agent does not read `.aew/runs/current` and does not need a run to exist. Working directory is the project root.
- **Behaviour in `init`:** skip step 1 (no brief) and step 8 (no `03-standards.md`, so no "Sections that apply"). Steps 2–7 run unchanged: detect, fingerprint, reuse/update/generate each `docs/standards/<profile>.md`, write or refresh `docs/standards/README.md` under step 7's rule (nothing under `docs/standards/` changes when every fingerprint matched). Memory update (step 9) still applies, so `.claude/agent-memory/aew-standards-setter/` may change. `.aew/config.json` is read if present (cross-check only), as today.
- **Empty detection in `init`:** write nothing, return `ok`, SUMMARY "No stack detected by detect-stack.sh.", `ARTEFACTS: none`.
- **Return:** the four-line block goes **only in the final message** (there is no artefact). `ARTEFACTS`: `docs/standards/README.md` (when it exists), then every profile doc, reused ones included; or `none`. `SUMMARY`: `<profile>: reused|generated|updated` per profile, as today. `NEXT`: "init can stage docs/standards/" or the blocking reason. `blocked` in init mode only for a missing `detect-stack.sh` or an unknown mode; `failed` as today.
- **What changed on disk:** the agent does not list changed files separately. Phase D finds them with `git status --porcelain -- docs/standards/ .claude/agent-memory/aew-standards-setter/`.

### C-3. `scripts/gh-pr.sh open` (A3, AC-36)

```
gh-pr.sh open <branch> <title> <body-file> [--base <branch>]
```

- **Purpose:** run-less PRs (init). Reads no run state and no config. The caller pushes the branch first (`git-branch.sh push`).
- **Validation, all before any `gh` call, each exit 1 with an `error:` line on stderr and empty stdout:** wrong argument count or an unexpected extra argument; unknown option; `--base` without a value; `<branch>` or `--base` value not a valid branch name (`git check-ref-format --branch`); empty `<title>` or a title containing a newline; `<body-file>` missing or empty (`need_file`).
- **Calls, in order:**
  1. `gh pr list --head <branch> --state open --json number --jq '.[0].number // empty'`.
  2. Only if step 1 printed nothing: `gh pr create --head <branch> [--base <base>] --title <title> --body-file <body-file>`. Without `--base`, no `--base` is passed and gh uses the repository's default branch; **Phase D passes `--base <config default_branch>` explicitly.**
- **Body:** passed verbatim (no `Closes #n` normalisation; there is no run issue). The body file is never modified.
- **Stdout:** exactly one line, the PR number — the existing open PR's number (reuse; no create call) or the new PR's number parsed from gh's `/pull/<n>` URL (create).
- **Exit codes:** 0 success (reuse or create); 1 invalid input, a `gh` failure (gh's message passes through on stderr, stdout empty), a lookup result that is not a positive integer, or create output without a `/pull/<n>` URL.
- **Unchanged:** `create`, `update`, `ready`, `comment` keep their signatures and behaviour; `create` still has no lookup (ship keeps checking `state.pr`, Phase B).

### C-4. DESIGN sections

Not touched in this phase. Phase F writes DESIGN §8.3 (`mode: init`, Conflict C3) and §8.4 (`notes`) from C-1 and C-2 (cut 10, AC-47). The project-map dispatch-field line ("standards-setter takes `run_dir` only") is also Phase F's to refresh.

## Tasks

Waves: **1** = A1 ∥ A2 ∥ A3. The three tasks share no file.

---

### Task A1 — senior-engineer plan mode accepts `notes` (AC-34)

- **id:** A1
- **files:** `agents/senior-engineer.md`
- **depends_on:** []
- **pattern:** the existing Dispatch fields bullets (`n`, `base`: field, modes it applies to, fallback) and step 5's material-challenge rule, which the note handling reuses rather than restates.
- **AC:** AC-34
- **Edits (no inline prose here; wording to the implementer, British English):**
  1. Dispatch fields: add the `notes` bullet per C-1 (optional, plan only, last field, may span lines, sources).
  2. Files per mode, plan row "Also read": add "`05-plan.md` when `notes` is given".
  3. Mode: plan: one new step before step 1 (or a sub-bullet of step 3): when `notes` is given, read the earlier plan, treat each note as a requirement on the revision, and end `## Approach` with the `Revision notes:` list per C-1; a note that needs a material spec change goes through step 5.
  4. Definition of done → Mode: plan: add "with `notes`, `## Approach` addresses every note".
- **RED:** `grep -c 'notes' agents/senior-engineer.md` → `0` (checked 2026-10-25).
- **GREEN:**
  - `grep -n '`notes`' agents/senior-engineer.md` shows hits in Dispatch fields, Files per mode, Mode: plan and Definition of done (4 sections).
  - `grep -n 'Revision notes' agents/senior-engineer.md` → at least one hit.
  - `claude plugin validate .` → `✔ Validation passed` (warnings as before).
  - `git diff --stat` touches only `agents/senior-engineer.md`.
- **Commit:** `feat(agents): let senior-engineer plan mode take gate and blocked notes`

---

### Task A2 — standards-setter `mode: init` (AC-35)

- **id:** A2
- **files:** `agents/standards-setter.md`
- **depends_on:** []
- **pattern:** senior-engineer's `mode` field rule ("A missing or unknown mode is `STATUS: blocked`") adapted to a defaulted mode; standards-setter's own step 2 empty-detection branch for the init empty case.
- **AC:** AC-35 (agent side)
- **Edits:**
  1. Frontmatter `description`: mention that init also dispatches it (keep one sentence, keep "don't use it directly").
  2. Inputs: add the `mode` field per C-2 (`pipeline` default with `run_dir`; `init` with no `run_dir`, no brief, no `.aew/runs/current` read; unknown → `blocked`). Mark `02-brief.md` as required in pipeline mode only.
  3. Process: step 1 and step 8 say "pipeline mode only"; step 2's empty-array branch gains the init variant (write nothing, `ARTEFACTS: none`).
  4. Outputs and Return contract: `03-standards.md` pipeline only; in init the return block is in the final message only, ARTEFACTS / NEXT / `blocked` per C-2.
  5. Definition of done: the `03-standards.md` bullets apply to pipeline mode.
- **RED:** `grep -c 'mode: init' agents/standards-setter.md` → `0` (checked 2026-10-25).
- **GREEN:**
  - `grep -n 'mode: init' agents/standards-setter.md` → hits in Inputs and Return contract at least.
  - `grep -n 'ARTEFACTS: none' agents/standards-setter.md` → one hit.
  - Pipeline wording intact: `grep -c '03-standards.md' agents/standards-setter.md` is not lower than before (the existing references stay, each qualified as pipeline-only; none deleted).
  - `claude plugin validate .` → `✔ Validation passed`.
  - `git diff --stat` touches only `agents/standards-setter.md`.
- **Commit:** `feat(agents): add a run-less init mode to standards-setter`

---

### Task A3 — `gh-pr.sh open` with bats tests and github-ops rows (AC-36)

- **id:** A3
- **files:** `scripts/gh-pr.sh`, `tests/scripts/gh-pr.bats`, `skills/github-ops/SKILL.md`
- **depends_on:** []
- **pattern:** `cmd_create` in `scripts/gh-pr.sh` (option loop, positional collection, `need_file`, refusals before gh, URL → number); `git-branch.sh` line 78 for the branch check; the "create prints the PR number…" and "create refusals make no gh call" tests in `gh-pr.bats`.
- **AC:** AC-36
- **Reuse:** extract the existing URL → PR-number lines of `cmd_create` into one small helper that `cmd_create` and `cmd_open` both call (the existing "output without a /pull/<n> URL is an error" test guards the refactor). Reuse `need_file`. `require_cmd git` inside `cmd_open` only. No new library function.
- **Script edits:** add `cmd_open` per C-3 and an `open)` arm in the dispatch `case`; add the `open` entry to the Usage header (this is `--help`); change the header's "There is no 'PR already exists' lookup: check state.pr before calling create." to say `create` has none and `open` does.
- **Tests (three, appended to `gh-pr.bats`, reusing its `setup`, which already cans `pr-create` → `.../pull/7`):**
  1. `open creates a PR when none is open and prints its number`: body file `printf 'Set up aew.\n'`. `"$PR" open chore/aew-init "chore: set up aew" body.md` → success, `$output` = `7`; `assert_gh_called "pr list --head chore/aew-init --state open"`; `assert_gh_called "pr create --head chore/aew-init --title chore: set up aew --body-file"`; `refute_gh_called "--base"`; captured body `cmp` equal to the input. The `refute_gh_called "--base"` assertion runs before the next call. Then, in the same test, a second call with `--base main` (the call log accumulates): success, `$output` = `7`, `assert_gh_called "--base main"`.
  2. `open reuses an already-open PR without creating one`: `gh_mock_respond pr-list - 0 <<< "17"` → success, `$output` = `17`, `refute_gh_called "pr create"`, `gh_call_count` = 1.
  3. `open refusals make no gh call`: each exits 1 with `error:` on stderr — no args; branch only; branch + title only; `bad..branch`; empty title `""`; title with a newline; missing body file; empty body file; `--base` with no value; `--base 'bad..x'`; `--bogus`; a fourth positional. Then `gh_call_count` = 0.
- **RED:** run `bats -f 'open ' tests/scripts/gh-pr.bats` before the script change → 3 tests, the first two fail with stderr `gh-pr.sh: error: unknown subcommand: open (see --help)`. (Test 3 passes vacuously at RED because every call exits 1 with `error:` already; record that, and that it goes on guarding the "before any gh call" rule.)
- **GREEN:**
  - `bats tests/scripts/gh-pr.bats` → all tests pass (the existing 16 plus 3 new).
  - `scripts/gh-pr.sh --help` shows the `open <branch> <title> <body-file> [--base <branch>]` line.
  - `tests/run-script-tests.sh` → shellcheck clean and every bats file passes (`conventions.bats` covers strict mode, `--help` and bash 3.2 conventions).
- **github-ops edits (`skills/github-ops/SKILL.md`):** script table row "Use it to" becomes "open (for a run or run-less), update, ready and comment on the PR"; "Other calls" adds `gh-pr.sh open chore/aew-init "chore: set up aew" pr-body.md --base main`; Operational rules: the `state.pr` bullet keeps `create`'s rule and adds that `open` is for run-less PRs (init) and reuses an open PR for the head branch; Conventions → Exceptions adds `gh-pr.sh open <branch> <title> <body-file>`; Stdout contract: "`create` and `open`: the PR number".
  - GREEN check: `grep -c 'gh-pr.sh open' skills/github-ops/SKILL.md` → at least `3` (RED: `0`, checked 2026-10-25).
- **Commit:** `feat(scripts): add gh-pr.sh open for run-less PRs that reuses an open PR`

## Phase verification (after A1–A3)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                      # all green, shellcheck clean
claude plugin validate .                       # ✔ Validation passed (existing warnings only)
grep -c 'notes' agents/senior-engineer.md      # > 0
grep -c 'mode: init' agents/standards-setter.md  # > 0
scripts/gh-pr.sh --help | grep -c 'open <branch>'  # 1
git status --porcelain                         # only the five files above (plus the pre-existing spec/project-map changes)
```

No paid run in this phase. Live exercise of C-1 and C-2 is Phase F's (G2/R2 do not reach a request-changes gate headless; I1/I2 dispatch `mode: init`).

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-34 optional `notes`, revised plan addresses each note and says how in `## Approach` | A1 | A1 GREEN greps; C-1 |
| AC-35 `mode: init`: no run dir, no brief, docs + README as usual, no `03-standards.md` / "Sections that apply", block in final message only | A2 | A2 GREEN greps; C-2 |
| AC-35 "DESIGN §8.3 records it (C3)" | Phase F | not here (cut 10, AC-47) |
| AC-36 `open <branch> <title> <body-file> [--base]`, reuse an open PR, create otherwise, prints number; bats create/reuse/invalid-before-gh; `--help`; github-ops; suite passes | A3 | three bats tests; `--help`; `tests/run-script-tests.sh`; github-ops grep |

## Decisions (flag if wrong)

1. **`notes` is the last dispatch field and may span lines**, rather than a file in the run dir or a one-line squashed value. Gate feedback is free text, and AC-5's "`key: value` lines only" holds for every other field. Phase B must put it last.
2. **A note that needs a material spec change returns `needs_input` through step 5**, not `blocked`. This reuses the agent's existing challenge path, and Phase B already routes plan `needs_input` (cut 8).
3. **standards-setter's mode defaults to `pipeline`**, so the existing orchestrator dispatch (`run_dir` only) and the prompt-03 smoke runs stay valid.
4. **Init mode still updates agent memory.** Cut "nothing else" read literally. Phase D must decide whether `.claude/agent-memory/aew-standards-setter/` is staged in init's commit (it is project-scoped memory, so committing it is consistent with DESIGN §3).
5. **`ARTEFACTS: none`** for an init run with no detected stack, because the return-block rule needs a value.
6. **`open` passes no `--base` by default** (gh's repository default applies) and reads no config, keeping the subcommand run- and config-free. Init passes `--base` from config.
7. **`open` does not normalise the body** (no `Closes #n`): there is no issue. A later caller with issues should use `create`.
8. **Lookup is `--state open` only.** A merged or closed earlier init PR does not block a new one; init's "no changes → no PR call" rule (AC-33) handles the idempotent case.
9. **Three bats tests only** (cut list): gh failure on the lookup and a non-numeric lookup result are handled in code (exit 1) but not separately tested.
10. **DESIGN §8.3/§8.4 text deferred to Phase F**, so no two phases edit DESIGN in parallel.

## Risks

- **Multi-line `notes` misread as further fields.** Mitigation: C-1 makes it the last field; Phase B's `dispatch.md` states it; Phase E's `skills.bats` can grep that `notes` is listed last.
- **`gh pr list --head` matching a same-named branch from a fork.** `--head` filters by branch name only; a fork's open PR with the same head name could be reused by mistake. Residual and unlikely for `chore/aew-init` in the user's own repo; recorded for prompt 07's sandbox run.
- **The mock ignores `--jq`.** Canned `pr-list` output is the post-jq value (`17`), so the tests do not prove the jq expression; it is the documented `gh` form. Prompt 07's sandbox run exercises it live.
- **Refactoring `cmd_create`'s number parsing** could regress `create`. Guarded by the existing "output without a /pull/<n> URL is an error" and "create prints the PR number" tests, run in A3 GREEN.

## Approval (Phase A)

- Senior architect: APPROVED on 2026-10-24T23:08:38Z (plan-review)
- Plan format: LEAN
- Plan dependency graph: valid. Wave count: 1. Max wave width: 3 tasks parallel (A1, A2, A3; no file overlap).
- Mechanical fix applied: A3 test 1 now states the `refute_gh_called "--base"` ordering and that the `--base main` call runs in the same test.
- Plan content hash (SHA-256, doc above this trailer): 557809207c3986deb4d5ed6c44ff66f2a3b7c6eb045be8410930b55fb2c05327
