# Run state machine

`state.json` holds `stage` (where the run is) and `status` (how it is doing). Only
`scripts/state.sh` writes it, and each transition appends one line to `log.md` and one entry to
`history`. The diagram shows stages as states. Statuses other than `running` appear as their
own states. `parallel_planning` is the `qa_test_plan` ∥ `plan` step: both run at once, `stage`
reads `plan`, and the label is `aew:planning`. Inside `qa` (label `aew:testing`) the fix loop
keeps `stage` at `qa`.

```mermaid
stateDiagram-v2
    direction TB

    [*] --> spec_analysis: ship / prompt

    state "spec_analysis (aew:analysing)" as spec_analysis
    state "awaiting_input (aew:awaiting-input)" as awaiting_input
    state "brief (aew:planning)" as brief
    state "standards (aew:planning)" as standards
    state "awaiting_plan_approval (aew:awaiting-approval)" as awaiting_plan_approval
    state "develop (aew:building)" as develop
    state "review (aew:building)" as review
    state "docs (aew:documenting)" as docs
    state "pr (aew:ready-for-review)" as pr
    state "blocked (aew:blocked)" as blocked

    spec_analysis --> awaiting_input: needs_input (material change)
    awaiting_input --> spec_analysis: answered, re-run on the delta
    spec_analysis --> brief: ok (spec revision recorded if any change)
    brief --> standards: ok
    brief --> done: ok, prompt mode (prompt.md written)
    standards --> parallel_planning: ok (or reused)

    state parallel_planning {
        state fork_p <<fork>>
        state join_p <<join>>
        [*] --> fork_p
        fork_p --> qa_test_plan
        fork_p --> plan
        qa_test_plan --> join_p: ok
        plan --> join_p: ok
        join_p --> [*]
    }

    parallel_planning --> awaiting_input: plan needs_input (challenge implies material spec change)
    awaiting_input --> spec_analysis: plan challenge answered (any answer), revision recorded, the run continues from brief

    state plan_gate <<choice>>
    parallel_planning --> plan_gate
    plan_gate --> develop: --auto or gates.plan_approval false
    plan_gate --> awaiting_plan_approval: gate on
    awaiting_plan_approval --> develop: approve
    awaiting_plan_approval --> parallel_planning: request changes, senior-engineer re-plans with notes, QA phase A kept
    awaiting_plan_approval --> failed: stop

    develop --> review: ok
    develop --> awaiting_input: blocked by the environment (full mode), or check-env.sh fails before D8, gate environment
    awaiting_input --> develop: environment fixed, continue (re-plan allowance kept)
    awaiting_input --> parallel_planning: environment gate answered re-plan (first in the run)
    develop --> parallel_planning: blocked on the plan (first in the run), senior-engineer re-plans with notes, plan gate unless auto
    develop --> blocked: blocked on the plan a second time in the run, or blocked in fix mode

    state review_verdict <<choice>>
    review --> review_verdict
    review_verdict --> qa: approve
    review_verdict --> develop: changes_required, review_cycle below max_review_cycles (review_cycle + 1)
    review_verdict --> blocked: changes_required, review_cycle = max_review_cycles

    state qa {
        state qa_result <<choice>>
        state route <<choice>>
        [*] --> execute
        execute --> qa_result: 08-qa-report-n
        qa_result --> [*]: all pass and UI rule met
        qa_result --> route: failures, fix_cycle below max_fix_cycles (fix_cycle + 1)
        route --> developer_fix: impl_bug
        route --> senior_triage: plan_divergence, test_bug, or impl_bug unfixed after one cycle
        senior_triage --> developer_fix: fix instructions
        senior_triage --> qa_fix_test: test ruled wrong
        developer_fix --> execute
        qa_fix_test --> execute
    }

    qa --> docs: all pass
    qa --> awaiting_input: spec_ambiguity
    qa --> awaiting_input: triage needs_input (material by definition)
    awaiting_input --> spec_analysis: spec ambiguity or triage answered, revision recorded, then brief (a non-material spec ambiguity goes on to QA phase B after the brief, otherwise every stage from brief re-runs)
    qa --> blocked: failures, fix_cycle = max_fix_cycles

    docs --> pr: ok
    pr --> done: PR created, manual tests and retro filed
    done --> [*]

    state "any agent stage" as any_stage
    any_stage --> any_stage: agent failed once, retry the dispatch (qa-engineer phase B report excepted, see Failure paths)
    any_stage --> blocked: agent failed twice
    any_stage --> blocked: agent blocked (developer excepted, see above)

    blocked --> [*]: report posted, /aew:resume continues from the recorded stage
    failed --> [*]
```

## Gates

| Gate | When | Options | Skippable |
|---|---|---|---|
| Material spec change | `spec_analysis` or `plan` returns `needs_input` | AskUserQuestion with recommended answers | Never, even with `--auto` |
| Spec ambiguity | QA failure classed `spec_ambiguity` | AskUserQuestion with recommended answers | Never |
| Plan approval | `qa_test_plan` and `plan` both `ok` | approve / request changes / stop (plan summary of 25 lines or fewer, plus the file path) | `--auto` or `gates.plan_approval: false` |
| Irreversible or destructive operation | Any stage | confirm / cancel | Never |

The answers go to spec-analyser first. When it returns `ok` with changes in `spec-changes.json`, the
revision is recorded before the next stage: a `spec-revision-v<N>.md` comment, the issue body
revision, `aew:spec-revised`, and `spec_revision + 1`. The stages after it then run again.

**Unanswered gate.** If AskUserQuestion is unavailable (headless with `--permission-prompts none`),
refused or empty, the gate stays pending (`gate:<id> <file>` note in `history`); ship prints the
questions or plan summary and `Answer with /aew:resume <id>`, and stops. `/aew:resume` re-asks it.

## Failure paths

| Trigger | Result |
|---|---|
| Agent returns `failed` (any case other than the next row) | Retry the same dispatch once. A second `failed` sets `blocked`. |
| qa-engineer phase B returns `failed` with a complete report | "QA failures, report complete": route by triage class (the `qa` state above), counted against `max_fix_cycles`. Not retried. |
| Agent returns `blocked` | Developer in full mode → senior-engineer plan revision with `notes`, once per run (a second full-mode `blocked` → `blocked`); developer in fix mode (review or QA fix) → `blocked`; anything else → `blocked`. |
| `changes_required` once `review_cycle` = `max_review_cycles` | `blocked` |
| QA failures once `fix_cycle` = `max_fix_cycles` | `blocked` |
| UI brief with an automatable UI test still failing | Not done. It counts as a QA failure. |
| James chooses stop at a gate | `failed` (terminal) |
| SubagentStop gate hook blocks (artefact or return block missing) | The gate blocks once, and its reason becomes the agent's next instruction. If the agent stops again (`stop_hook_active` true), the gate allows the stop. The return is then checked as usual: a missing or invalid artefact or return block counts as `failed` (retry once, then `blocked`). |

qa-engineer phase B returns `failed` when its report is complete but tests or serious or critical accessibility checks failed. That `failed` means "QA failures, report complete": the orchestrator routes it by triage class under `limits.max_fix_cycles` and does not retry it. It counts as such only when `08-qa-report-<n>.md` exists, ends with a valid return block whose STATUS is `failed`, and the triage table at the top of its `## Failures` section has at least one `TC-<n>` row. Anything else is an ordinary agent `failed`: retry once, then `blocked`.

Mechanical test (the orchestrator implements it in prompt 05; the smoke checks use it), with `valid_return_block` as defined in `scripts/hooks/gate-subagent.sh`:

```sh
qa_failures_complete() {   # qa_failures_complete <report>; exit 0 = QA failures, report complete
  [ -f "$1" ] && [ "$(valid_return_block "$1")" = failed ] &&
    awk '/^## /{f=($0=="## Failures")} f && /^\|[[:space:]]*TC-[0-9]+[[:space:]]*\|/{n++} END{exit !(n>0)}' "$1"
}
```

On `blocked`, the orchestrator posts a report comment with `gh-issue.sh comment`, sets
`aew:blocked` and stops. `resume` re-checks the branch and working tree, then continues from the
recorded `stage`.

## Counters

- `review_cycle` starts at 0 and goes up by one on each `changes_required`. The next review file is `07-review-<review_cycle + 1>.md`.
- `fix_cycle` starts at 0 and goes up by one on each failing QA pass that is routed to a fix. The next QA report is `08-qa-report-<fix_cycle + 1>.md`, and its triage is `09-triage-<same n>.md`.
- `spec_revision` starts at 1 (the author's original) and goes up by one on each recorded revision.
