---
name: run-protocol
description: The aew run protocol. Covers the run directory layout, stages and state machine, labels, the agent return contract, the rule that agents never touch GitHub, and file naming. Use it whenever you read or write files in .aew/runs/<run-id>/ or report back to the aew orchestrator.
user-invocable: false
---

# aew run protocol

Every aew agent and the orchestrator share this contract. Agents talk to the orchestrator
through files in the run directory plus one return block. They never talk through chat.

## Run directory

`.aew/runs/<run-id>/` in the target project. It is gitignored. The run id is the issue
number (`42`), or `m-<milestone-number>` for a milestone run (`m-3`).
`.aew/runs/current` holds the active run id, and hooks read it.

| File | Writer |
|---|---|
| `state.json`, `log.md` | scripts only (`state.sh`) |
| `issue.json`, `00-issue-original.md` | `gh-issue.sh fetch` |
| `01-spec-analysis.md`, `spec-final.md`, `spec-changes.json` | spec-analyser |
| `spec-revision-v<N>.md` | orchestrator, rendered from `spec-changes.json` |
| `02-brief.md` | brief-compiler |
| `03-standards.md` | standards-setter |
| `04-qa-test-plan.md` | qa-engineer (phase A) |
| `05-plan.md` | senior-engineer (plan) |
| `06-dev-report.md`, `06-dev-report-WP<n>.md` | developer, sub-developers |
| `07-review-<n>.md` | senior-engineer (review) |
| `08-qa-report-<n>.md` | qa-engineer (phase B) |
| `09-triage-<n>.md` | senior-engineer (triage) |
| `manual-tests.md` | qa-engineer |
| `10-summary.md`, `pr-body.md`, `retro.md` | doc-writer |
| `prompt.md` | brief-compiler (prompt mode only) |

Who reads each artefact, and its template: [references/artefacts.md](references/artefacts.md).
Templates live in the plugin at `templates/artefacts/`. Start every artefact from its template,
and keep its sections and their order.

Committed outputs outside the run dir: `docs/standards/`, `docs/specs/<issue>-<slug>.md`,
`docs/qa/<issue>/` (PR branch, final passing cycle only), the e2e dir and `CLAUDE.md`.

## Stages

`state.json` → `stage`, in order:

1. `spec_analysis`: material changes → `awaiting_input` → James answers → re-run on the delta.
2. `brief`
3. `standards`: reused when the fingerprint matches.
4. `qa_test_plan` and `plan`, **in parallel**. `stage` reads `plan` while both run.
   Then the plan gate (`awaiting_plan_approval`), unless `--auto` or `gates.plan_approval: false`.
5. `develop`
6. `review`: `changes_required` → back to `develop`, up to `limits.max_review_cycles`.
7. `qa`: failures → triage → fix → re-run QA, up to `limits.max_fix_cycles`.
8. `docs`
9. `pr`, then status `done`.

Prompt mode stops after `brief`: brief-compiler writes `prompt.md` and the status becomes `done`.

`status`: `running | awaiting_input | awaiting_plan_approval | blocked | done | failed`.

- Exceeding a cycle limit, or an agent returning `failed` twice, sets `blocked`.
  The orchestrator posts a report comment, sets `aew:blocked` and stops.
- `failed` is terminal: James chose to stop, or the run can't continue.
- `resume` continues from the recorded `stage`.

Every transition, gate and failure path is in [references/state-machine.md](references/state-machine.md).

## Labels

The orchestrator sets them through `gh-labels.sh`. Agents never do.

| Label | When |
|---|---|
| `aew:analysing` | `spec_analysis` running |
| `aew:awaiting-input` | status `awaiting_input` |
| `aew:planning` | `brief`, `standards`, `qa_test_plan`, `plan` running |
| `aew:awaiting-approval` | status `awaiting_plan_approval` |
| `aew:building` | `develop`, `review` |
| `aew:testing` | `qa` |
| `aew:documenting` | `docs` |
| `aew:ready-for-review` | `pr` (once the PR is open), status `done` |
| `aew:blocked` | status `blocked` |

Exactly one stage label at a time. Flags sit alongside it:

- `aew:spec-revised`: a spec revision was recorded on the issue.
- `aew:manual-test-required`: `manual-tests.md` has items.

## Return contract

Every agent ends its final message, and its primary artefact, with exactly these four lines:

```
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: <paths, comma-separated>
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
```

- `ok`: the job is done and the artefacts are complete.
- `needs_input`: only James can decide, for example a material spec change. Put the questions,
  each with a recommended answer, in the artefact.
- `blocked`: the agent can't proceed as instructed, for example an impossible plan step. Give the reason.
- `failed`: the agent tried and couldn't produce the artefact.

The orchestrator reads return blocks. It opens full artefacts only when a gate or routing
decision needs them, so the SUMMARY must carry the essentials.

## Agents never touch GitHub

Only the orchestrator talks to GitHub, through the plugin's scripts (`gh-*.sh`, `git-branch.sh push`).
Agents:

- never run `gh`, and never push, merge or open PRs;
- read inputs from the run dir and the repo, and write only the paths their role allows;
- get issue content from `00-issue-original.md` and `issue.json`, never from the network.

Agents can then be tested offline, and the permission surface stays small.

## File naming

- Run artefacts: a two-digit prefix gives pipeline order (`01-`…`10-`). The names are fixed; don't invent new ones.
- Cycle suffix `-<n>` starts at 1. The review file is `07-review-<review_cycle + 1>.md`.
  The QA report is `08-qa-report-<fix_cycle + 1>.md`, and its triage shares its `<n>`.
- Sub-developer reports: `06-dev-report-WP<n>.md`, one per work package.
- Spec revisions: `spec-revision-v<N>.md`. Version 1 is the author's original.
- IDs: `AC-<n>`, `TC-<n>`, `WP-<n>`. In bulk milestone runs, AC ids carry the issue prefix: `#12-AC-1`.
- Specs: `docs/specs/<issue>-<slug>.md`. Standards: `docs/standards/<profile>.md` plus `README.md`.
- Evidence: `docs/qa/<issue>/report.md`, `docs/qa/<issue>/screenshots/<TC>-<viewport>.jpg`.
- Branches: `git.branch_pattern` (`feat/{issue}-{slug}`), or `git.milestone_branch_pattern` for bulk runs.
- Slugs: lower-case kebab-case taken from the issue title.
