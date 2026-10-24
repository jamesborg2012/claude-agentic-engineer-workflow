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
    awaiting_input --> spec_analysis: James accepts the spec change
    awaiting_input --> parallel_planning: James declines, re-plan on the current spec

    state plan_gate <<choice>>
    parallel_planning --> plan_gate
    plan_gate --> develop: --auto or gates.plan_approval false
    plan_gate --> awaiting_plan_approval: gate on
    awaiting_plan_approval --> develop: approve
    awaiting_plan_approval --> parallel_planning: request changes (plan re-run with feedback)
    awaiting_plan_approval --> failed: stop

    develop --> review: ok
    develop --> parallel_planning: blocked (plan step impossible), senior revises the plan

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
    awaiting_input --> qa: answered, no material change
    qa --> blocked: failures, fix_cycle = max_fix_cycles

    docs --> pr: ok
    pr --> done: PR created, manual tests and retro filed
    done --> [*]

    state "any agent stage" as any_stage
    any_stage --> any_stage: agent failed once, retry the dispatch
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

An answer that confirms a material change is recorded first: a `spec-revision-v<N>.md` comment,
the issue body revision, `aew:spec-revised`, and `spec_revision + 1`. Then spec analysis re-runs
on the delta, and the stages after it run again.

## Failure paths

| Trigger | Result |
|---|---|
| Agent returns `failed` | Retry the same dispatch once. A second `failed` sets `blocked`. |
| Agent returns `blocked` | The orchestrator routes it: developer → senior-engineer (plan revision); anything else → `blocked`. |
| `changes_required` once `review_cycle` = `max_review_cycles` | `blocked` |
| QA failures once `fix_cycle` = `max_fix_cycles` | `blocked` |
| UI brief with an automatable UI test still failing | Not done. It counts as a QA failure. |
| James chooses stop at a gate | `failed` (terminal) |
| SubagentStop gate hook blocks (artefact or return block missing) | The agent continues until the artefact is valid. Claude Code overrides the hook after eight consecutive blocks; the return is then checked as usual, and a missing artefact or return block counts as `failed`. |

On `blocked`, the orchestrator posts a report comment with `gh-issue.sh comment`, sets
`aew:blocked` and stops. `resume` re-checks the branch and working tree, then continues from the
recorded `stage`.

## Counters

- `review_cycle` starts at 0 and goes up by one on each `changes_required`. The next review file is `07-review-<review_cycle + 1>.md`.
- `fix_cycle` starts at 0 and goes up by one on each failing QA pass that is routed to a fix. The next QA report is `08-qa-report-<fix_cycle + 1>.md`, and its triage is `09-triage-<same n>.md`.
- `spec_revision` starts at 1 (the author's original) and goes up by one on each recorded revision.
