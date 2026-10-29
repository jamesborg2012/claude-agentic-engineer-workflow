<!--
Artefact: .aew/runs/<run-id>/02-brief.md
Written by: brief-compiler (pipeline mode)
Read by: standards-setter, senior-engineer (plan, review, triage), qa-engineer (phases A and B), developer, doc-writer
-->
# Brief: #<issue> <title>

Source: spec-final.md (v<n>)

## Goal

## Context

## Acceptance criteria

<!-- Number AC-1, AC-2… (bulk runs: #<issue>-AC-1). Each must be testable; use Given/When/Then where it helps. Tag each with any of [UI] [API] [DATA] [A11Y] [PERF] [SEC]. -->

- **AC-1** [UI] Given <context>, when <action>, then <outcome>.

## Spec criteria map

<!-- Every brief AC in exactly one row, so a split criterion traces back to the spec. An AC that comes from somewhere other than a numbered criterion names its source (an edge case, a constraint). -->

| Spec criterion | Brief ACs |
|---|---|
| spec criterion 1 | AC-1, AC-2 |

## Non-goals

## Constraints

## Standards overrides

<!-- "None." or one line per AC whose concrete value contradicts a rule in docs/standards/: "- <doc>#<section>: <the rule> → <what this brief requires instead> (<AC ids>)". The brief wins over the standard. -->

## Affected surfaces

## Test data and accounts needed

<!-- Account roles refer to app.test_accounts in .aew/config.json. Never write credentials here. -->

## UI changes: yes/no

## Definition of Done

- [ ] Every AC has a passing test, or a manual test with a reason.
- [ ] Lint, format, typecheck and unit tests pass.
- [ ] UI changes: every automatable UI test passes at every viewport, and the axe scan has no serious or critical violations.
- [ ] Review approved.
- [ ] Docs updated.

## Open risks

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/02-brief.md
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
