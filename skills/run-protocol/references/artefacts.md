# Artefacts

Paths are relative to `.aew/runs/<run-id>/` unless they start with `docs/`. Templates are relative
to the plugin root. "Scripts" means the plugin's `scripts/`, run by the orchestrator.

| Artefact | Writer | Readers | Template |
|---|---|---|---|
| `state.json` | scripts (`state.sh`) | orchestrator, scripts, hooks | `templates/state.schema.json` |
| `log.md` (append-only, one line per transition) | scripts (`state.sh`) | James, orchestrator (`status`) | — |
| `issue.json` | scripts (`gh-issue.sh fetch`) | spec-analyser | — |
| `00-issue-original.md` | scripts (`gh-issue.sh fetch`) | spec-analyser | — |
| `01-spec-analysis.md` | spec-analyser | orchestrator (material-change gate), spec-analyser (delta re-run) | `templates/artefacts/spec-analysis.md` |
| `spec-final.md` | spec-analyser | brief-compiler, doc-writer, scripts (`gh-issue.sh revise`) | — (the revised spec, in the issue's own structure) |
| `spec-changes.json` | spec-analyser | orchestrator | `templates/artefacts/spec-changes.example.json` |
| `spec-revision-v<N>.md` | orchestrator (rendered from `spec-changes.json`) | James and the issue author, as an issue comment | `templates/artefacts/spec-revision-comment.md` |
| `02-brief.md` | brief-compiler | standards-setter, senior-engineer, qa-engineer (A and B), developer, doc-writer | `templates/artefacts/brief.md` |
| `03-standards.md` | standards-setter | senior-engineer, developer, qa-engineer (A) | `templates/artefacts/standards-run.md` |
| `04-qa-test-plan.md` | qa-engineer (phase A) | qa-engineer (phase B), orchestrator | `templates/artefacts/qa-test-plan.md` |
| `05-plan.md` | senior-engineer (plan) | orchestrator (plan gate), developer, senior-engineer (review, triage), doc-writer | `templates/artefacts/plan.md` |
| `06-dev-report.md` | developer | senior-engineer (review), qa-engineer (B), orchestrator, developer SubagentStop hook | `templates/artefacts/dev-report.md` |
| `06-dev-report-WP<n>.md` | sub-developer (package mode) | developer (merging), senior-engineer (review) | `templates/artefacts/dev-report.md` |
| `07-review-<n>.md` | senior-engineer (review) | orchestrator (routing), developer | `templates/artefacts/review.md` |
| `08-qa-report-<n>.md` | qa-engineer (phase B) | orchestrator (routing), senior-engineer (triage), developer (fix mode), doc-writer, qa-engineer SubagentStop hook | `templates/artefacts/qa-report.md` |
| `09-triage-<n>.md` | senior-engineer (triage) | developer (fix mode), qa-engineer, orchestrator | `templates/artefacts/triage.md` |
| `manual-tests.md` | qa-engineer | orchestrator (`gh-issue.sh manual-tests`), doc-writer | `templates/artefacts/manual-tests.md` |
| `10-summary.md` | doc-writer | orchestrator (final report) | `templates/artefacts/summary.md` |
| `pr-body.md` | doc-writer | orchestrator (`gh-pr.sh`), James and reviewers on GitHub | `templates/artefacts/pr-body.md` |
| `retro.md` | doc-writer | orchestrator (`gh-retro.sh file`) | `templates/artefacts/retro.md` |
| `prompt.md` (prompt mode only) | brief-compiler | James, in a plain Claude Code session | `templates/artefacts/prompt.md` |
| `docs/qa/<issue>/report.md` and `screenshots/` | qa-engineer (final passing cycle) | PR reviewers, doc-writer | `templates/artefacts/qa-report.md` |

## Return blocks in artefacts

These artefacts end with the return block, so that the gate hooks and `resume` can check them:
`01-spec-analysis.md`, `02-brief.md`, `03-standards.md`, `04-qa-test-plan.md`, `05-plan.md`,
`06-dev-report*.md`, `07-review-<n>.md`, `08-qa-report-<n>.md`, `09-triage-<n>.md` and `10-summary.md`.

These artefacts don't, because they are posted to GitHub, filed elsewhere or pasted into
another session: `spec-revision-v<N>.md`, `manual-tests.md`, `pr-body.md`, `retro.md` and `prompt.md`.
