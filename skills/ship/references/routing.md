# Routing

How `SKILL.md` moves between stages. `<rd>` means `.aew/runs/<id>`. D1 to D13 are the rows of `dispatch.md` `## Dispatch table`. "Blocked path" is `SKILL.md` `## Blocked path`.

## Stage table

| Stage | Entry | Exit | Failure |
|---|---|---|---|
| `spec_analysis` | `state.sh stage spec_analysis` (fresh run: Step 3); label `analysing`; D1, or D2 after a gate | `ok` → record the revision → `brief` | `needs_input` → gate `spec`; `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
| `brief` | `state.sh stage brief`; label `planning`; D3 | `ok` → `standards` (→ `qa` after a non-material spec-ambiguity answer) | `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
| `standards` | `state.sh stage standards`; label `planning`; D5 | `ok` → standards commit → `plan` | as `brief` |
| `qa_test_plan` | as `plan` (one step) | as `plan` | as `plan` |
| `plan` | `state.sh stage plan`; label `planning`; D6 ∥ D7 in one message (D7 alone with `notes`) | both `ok` → gate `plan-approval`, or `develop` when auto or the gate is off | plan `needs_input` → gate `plan-challenge`; `failed` → retry only that agent, then blocked path; `blocked` → blocked path |
| `develop` | `state.sh stage develop`; label `building`; D10 from `07-review-<review_cycle>.md` when `review_cycle` is at least 1 and that review is newer than `05-plan.md` (`dispatch.md` `## Required inputs per stage`), else D8 | `ok` with every named report valid → `review` | full-mode `blocked` → Developer blocked; fix-mode `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
| `review` | `state.sh stage review`; label `building`; D9 with n = review_cycle + 1 | `approve` → `qa` | `needs_input` → gate `review-decision`; `changes_required` → Review loop (limit → blocked path); `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
| `qa` | `state.sh stage qa`; label `testing`; D12 with n = fix_cycle + 1 | `ok` → `docs` | complete failure → QA loop (limit → blocked path); other `failed` → retry once, then blocked path; `blocked` → blocked path |
| `docs` | `state.sh stage docs`; label `documenting`; D13 | `ok` → docs and memory commits → `pr` | `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
| `pr` | `state.sh stage pr`; label set once the PR exists | push, PR, manual tests, retro → label `ready-for-review`, `done`, `current` cleared → final report | a script failure → blocked path (retro failure: warn only) |

## Agent status routing

Route on the STATUS of the return block, after the return check (`dispatch.md` `## Return check`).

| Status | Route |
|---|---|
| `ok` | The stage's Exit cell in `## Stage table`. |
| `needs_input` | Only spec-analyser (gate `spec`), senior-engineer in plan mode (gate `plan-challenge`), senior-engineer in review mode (gate `review-decision`) and senior-engineer in triage mode (gate `triage`) may return it. From any other agent it is an invalid return. |
| `blocked` | The developer in full mode goes to `## Developer blocked`. Any other agent, and the developer in fix mode, goes to the blocked path. |
| `failed` | Retry once (`dispatch.md` `## Retries`), then the blocked path. The exception is a QA `failed`, which goes to `## QA loop` first. |

## Review loop

Reached on `changes_required` from `<rd>/07-review-<r>.md`, where r = review_cycle + 1.

1. Read `max_review_cycles` (`## Cycle limits`) and `state.sh get review_cycle`.
2. `review_cycle < max_review_cycles`: run `state.sh bump review_cycle`, then `SKILL.md` `## Stage: develop` with the note `review fix <new review_cycle>`. Develop picks fix mode from the counter and the age of the review (the Entry cell of the `develop` row), and then the review stage runs again.
3. `review_cycle` at or above `max_review_cycles` (a `review-decision` gate also counts a cycle, so it can pass the limit): the blocked path, with the reason `review cycles used up (<max>): <SUMMARY>`.

## Developer blocked

1. Fix mode (a review fix or a QA fix): the blocked path.
2. Full mode: run `grep -m1 '^Block cause:' <rd>/06-dev-report.md`. `Block cause: environment` goes to `gates.md` `## Gate: environment`: the plan is sound, so a re-plan would spend the allowance on nothing. Any other line, or none, continues at step 3.
3. Run `jq '[.history[] | select(.note == "developer blocked: re-plan")] | length' <rd>/state.json`. At 1 or more, the blocked path.
4. Otherwise `SKILL.md` `## Stage: plan` with the note `developer blocked: re-plan`, dispatching D7 only, with `notes: developer blocked: <the developer's SUMMARY> / <the dev report path from ARTEFACTS>`. Then the plan gate (unless auto or the gate is off), then develop. The re-plan rewrites `05-plan.md`, so the next develop is full mode.

The note is how the once-per-run limit survives a resume: it is read from `history`, never from memory.

## QA loop

The `stage` stays `qa` throughout. Reached on a D12 `failed`. Here `k` is fix_cycle + 1 on entry, the number of the report just written. Use `<rd>/08-qa-report-<k>.md`.

1. **Complete-failure test.** Both must hold:
   - `grep -v '^$' <rd>/08-qa-report-<k>.md | tail -n 4` is a valid return block with `STATUS: failed`;
   - `awk '/^## /{f=($0=="## Failures")} f && /^\|[[:space:]]*TC-[0-9]+[[:space:]]*\|/{n++} END{print n+0}' <rd>/08-qa-report-<k>.md` prints 1 or more.

   If not both, it is an ordinary `failed`: retry once, then the blocked path.
2. **Triage rows.** This is the only read of the report. Run `awk -F'|' '/^## /{f=($0=="## Failures")} f && $2 ~ /^[[:space:]]*TC-[0-9]+[[:space:]]*$/ {gsub(/[[:space:]]/,"",$2); gsub(/[[:space:]]/,"",$4); print $2, $4}' <rd>/08-qa-report-<k>.md`. It prints `TC-<n> <class>` lines.
3. **Limit.** `fix_cycle = max_fix_cycles`: the blocked path, with the reason `fix cycles used up (<max>): <SUMMARY>`.
4. Run `state.sh bump fix_cycle`. The number it prints is the new fix_cycle, which equals `k`. Use that number; do not keep it in a shell variable.
5. **Route one class per cycle. The first match wins.**
   - a. Any `spec_ambiguity`: `gates.md` `## Gate: spec-ambiguity`.
   - b. Any `plan_divergence` or `test_bug`, or an `impl_bug` whose TC was also `impl_bug` in the same rows of `08-qa-report-<k-1>.md` (it has already had one developer fix): D11 with `n: k`. On its return, `needs_input` goes to `gates.md` `## Gate: triage`. On `ok`, read NEXT. If NEXT names the developer, run `state.sh stage qa --note "fix <k>: developer (triage)"`, then D10 with `fix_from: 09-triage-<k>.md` and `n: k`. Then (or straight away, when NEXT names only qa-engineer) D12 with `n: k+1` and `triage: .aew/runs/<id>/09-triage-<k>.md`.
   - c. Otherwise (`impl_bug` only): `state.sh stage qa --note "fix <k>: developer"`, then D10 with `fix_from: 08-qa-report-<k>.md` and `n: k`, then D12 with `n: k+1`.
6. The developer's return inside the loop: `ok` → D12. `blocked` → the blocked path (fix mode). `failed` → retry once, then the blocked path.
7. Repeat from step 1 with the new report. A D12 `ok` → `SKILL.md` `## Stage: docs`.

## Cycle limits

Read the limits with their schema defaults:

- `jq -r '.limits.max_review_cycles // 2' .aew/config.json`
- `jq -r '.limits.max_fix_cycles // 3' .aew/config.json`

The counters name the artefacts: review n is `07-review-<review_cycle+1>.md`, QA report n is `08-qa-report-<fix_cycle+1>.md`, and triage uses the same n as the report it classifies (`09-triage-<n>.md`). Counters are never reset, not by `--from`, a gate re-run or a resume.

## Script failures

A plugin script that exits non-zero after the run has started goes to the blocked path. The reason is `<script> <subcommand> failed: <first stderr line>`. Four exceptions:

- A fetch failure or a closed issue during run start: the run is `failed` and `current` is cleared (Step 3).
- `gh-retro.sh`: warn only, and carry on.
- `check-env.sh` exit 1: a check failed, which is the `environment` gate (`SKILL.md` `## Stage: develop`) or a line in the plan-approval summary, not a script failure.
- `gh-labels.sh` when a label is missing: the blocked path, with "run `/aew:init`" added to the reason.
