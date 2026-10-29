<!--
Artefact: .aew/runs/<run-id>/08-qa-report-<n>.md; the final passing cycle is also copied to docs/qa/<issue>/report.md
Written by: qa-engineer (phase B)
Read by: orchestrator (routing), senior-engineer (triage), developer (fix mode), doc-writer (Docs follow-ups are applied), SubagentStop gate hook
-->
# QA report <n>: #<issue> <title>

## Results

<!-- Test: the file holding the test whose title starts with this TC id, or manual-tests.md for a manual case. -->

| TC | AC | Test | Result |
|---|---|---|---|
| TC-1 | AC-1 | <test file> | pass / fail |

## Commands and output

<!-- Each command run, with a short excerpt of its output. -->

## Screenshots

<!-- docs/qa/<issue>/screenshots/<TC>-<viewport>.jpg -->

| TC | Viewport | File |
|---|---|---|
| TC-1 | desktop | docs/qa/<issue>/screenshots/TC-1-desktop.jpg |

## Accessibility

<!-- axe results per changed page. Serious or critical violations fail; moderate ones are reported. -->

| Page | Critical | Serious | Moderate | Notes |
|---|---|---|---|---|

## Docs follow-ups

<!-- "None." or one line per doc the change made stale, for the doc-writer: "- <file>: <what to change and why>" (for example a Commands line in CLAUDE.md). -->

## Failures

<!-- Triage table first: one row per failure, in the same order as the entries below; zero rows on a passing cycle, followed by "None.". Then one entry per failure. Triage class: impl_bug | plan_divergence | spec_ambiguity | test_bug. -->

| TC | AC | Triage class | Summary |
|---|---|---|---|
| TC-1 | AC-1 | impl_bug / plan_divergence / spec_ambiguity / test_bug | <one line> |

### <TC>: <short description>

- **Triage class:**
- **Expected:**
- **Actual:**
- **Evidence:**

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/08-qa-report-<n>.md
SUMMARY: <≤150 words; start with passed/total>
NEXT: <recommendation for the orchestrator>
