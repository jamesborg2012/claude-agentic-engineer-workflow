<!--
Artefact: .aew/runs/<run-id>/04-qa-test-plan.md
Written by: qa-engineer (phase A). Written without reading the implementation: brief, standards and existing test conventions only, and lists every file it opened under Files read.
Read by: qa-engineer (phase B), orchestrator (manual-only cases)
-->
# QA test plan: #<issue> <title>

## Test cases

<!-- Every AC maps to at least one TC. Level: unit | integration | e2e | UI | manual. -->

| TC | AC | Level | Description |
|---|---|---|---|
| TC-1 | AC-1 | UI | <what is checked> |

## Test data

## UI tests and viewports

<!-- Which TCs run in Playwright, at which viewports from ui.viewports, and which screenshots each captures. -->

| TC | Viewports | Key states to screenshot |
|---|---|---|
| TC-1 | desktop, mobile | <state> |

## Accessibility checks

<!-- axe scan against ui.axe_standard on every changed page, plus any manual checks (keyboard, focus order, screen reader). -->

## Manual-only cases

| TC | AC | Reason it can't be automated |
|---|---|---|

## Files read

<!-- Every project file opened in phase A, in order, one bullet each, path relative to the project root (run-dir files included; plugin files, this plan, the agent's memory dir and failed reads excluded). Phase A never opens the implementation, 05-plan.md, 06-dev-report*.md, or any diff or log. -->

- `<path>`

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/04-qa-test-plan.md
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
