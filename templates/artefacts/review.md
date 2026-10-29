<!--
Artefact: .aew/runs/<run-id>/07-review-<n>.md
Written by: senior-engineer (review mode), comparing git diff <base>...HEAD with the plan, standards and brief
Read by: orchestrator (routing, gate review-decision), developer (when changes_required), doc-writer (open minors and nits become the PR body's Follow-ups)
-->
# Review <n>: #<issue> <title>

## Verdict

approve / changes_required

## Findings

<!-- Numbered. "None." when there are none. Every finding needs a location and a required fix. A fix cycle fixes blocker, major and minor findings; minors and nits still open on the last review go to the PR body's Follow-ups. -->

| # | Severity | Location | Finding | Required fix |
|---|---|---|---|---|
| 1 | <severity> | <file>:<line> | <what is wrong> | <what to do> |

## Questions for James

<!-- "None." unless a finding can only be fixed by a material spec change (senior-engineer, Mode: plan, step 5). Then one "### Q<k>. <question>" each, naming the finding, with "**Recommended answer:** <answer>" and "**Alternatives:** <a>; <b>" lines, and STATUS: needs_input. -->

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/07-review-<n>.md
SUMMARY: <≤150 words; start with the verdict>
NEXT: <recommendation for the orchestrator>
