<!--
Artefact: .aew/runs/<run-id>/manual-tests.md
Written by: qa-engineer
Read by: orchestrator (adds it to the issue body as the "Manual testing required" checklist and sets aew:manual-test-required), doc-writer (summary and PR body)
Only cases that can't be automated belong here. A case that needs a real GitHub event (a pull request, a review, a workflow run) carries the tag [needs GitHub], as in the second line.
-->
## Manual testing required

- [ ] **TC-<n> (AC-<n>):** <steps to perform> → <expected result>. _Why manual:_ <reason>.
- [ ] **TC-<n> (AC-<n>) [needs GitHub]:** <steps to perform> → <expected result>. _Why manual:_ needs a real <pull request / review / workflow run>, which no agent may create.
