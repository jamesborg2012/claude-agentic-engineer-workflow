<!--
Artefact: .aew/runs/<run-id>/pr-body.md
Written by: doc-writer
Read by: orchestrator (gh-pr.sh create / update), James and reviewers, on GitHub
Remove this comment block before posting.
-->
## In plain English

<!--
Write this section LAST. First `##` section of the body. Remove this comment before posting.
Length: 100-250 words for a single issue. Bulk: an opening paragraph plus at most ~80 words per issue.
Content, in order (omit a point only if it genuinely does not apply):
1. What was asked for and why, in one or two sentences. Name the issue in words: "issue #12".
2. What changed for someone using the product: what they will see or can do now.
3. How it was done, in a sentence or two; any obvious alternative the plan rejected, and why.
4. What changed along the way: confirmed spec clarifications, decisions taken on James's behalf, deviations from the issue.
5. What needs attention: manual tests outstanding, risks, limitations, omissions. One line if none.
6. Confidence, one line (e.g. "All 14 checks pass on desktop and mobile.").
Style: plain words, short sentences. No file paths, function or variable names, code, backticks, or AC/TC/WP ids.
No tables or headings inside; at most one short list. Explain unavoidable technical terms in passing.
Do not restate the technical sections. Real, specific facts only.
Variants: stacked = say it builds on the PR for issue #n and must be merged after it.
Bulk = an opening paragraph on the milestone, then one short paragraph per issue.
Checked by scripts/check-pr-intro.sh before the PR is created or updated.
-->

## Summary

## Acceptance criteria

- [x] AC-1: <criterion> (TC-1)

## Test results

| Suite | Result |
|---|---|
| Unit | <passed>/<total> |
| Acceptance | <passed>/<total> |
| Accessibility | <violations by severity> |

## Screenshots

<!-- Link via blob/<branch>/…?raw=true so they render before merge. -->

| TC | Desktop | Mobile |
|---|---|---|
| TC-1 | ![TC-1 desktop](https://github.com/<owner>/<repo>/blob/<branch>/docs/qa/<issue>/screenshots/TC-1-desktop.jpg?raw=true) | ![TC-1 mobile](https://github.com/<owner>/<repo>/blob/<branch>/docs/qa/<issue>/screenshots/TC-1-mobile.jpg?raw=true) |

## Manual tests

<!-- "None." or the outstanding items from manual-tests.md. -->

## Closes

<!-- One line per issue in the run. -->
Closes #<issue>
