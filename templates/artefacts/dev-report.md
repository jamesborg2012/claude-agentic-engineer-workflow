<!--
Artefact: .aew/runs/<run-id>/06-dev-report.md (sub-developers: 06-dev-report-WP<n>.md)
Written by: developer
Read by: senior-engineer (review), qa-engineer (phase B), orchestrator (routing), SubagentStop gate hook (requires commands run with results)
-->
# Dev report: #<issue> <title>

Mode: package / fix (cycle <n>) / full

Block cause: none / plan / environment

## Work packages done

| WP | Status | Commit |
|---|---|---|
| WP-1 | done | <sha> |

## Files changed

## Commands run

<!-- Every check from config.commands that was run, with its result. Required by the SubagentStop gate. -->

| Command | Result |
|---|---|
| <lint command> | pass |
| <test_unit command> | pass (<n> tests) |

## Tests first

<!-- One line per WP (fix mode: per root cause) with the ACs its new tests cover: "- WP-1 (AC-1, AC-2): <test command narrowed to the new tests>: <n> failed before the change, passed after". A WP with no failing-first run says so with the reason (no planned unit tests, or the tests cover behaviour that already exists). QA phase B cites these lines, because it never runs its tests against the old code. -->

## Deviations

<!-- "None." only when every planned step and command ran. Otherwise each deviation from the plan, with the reason, a planned command or step that was skipped or could not run included ("bin/check: not run, <reason>"). A plan step that is impossible or clearly wrong stops the WP: STATUS: blocked. -->

## Notes for QA

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/06-dev-report.md
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
