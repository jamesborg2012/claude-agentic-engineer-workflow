<!--
Artefact: .aew/runs/<run-id>/01-spec-analysis.md
Written by: spec-analyser
Read by: orchestrator (material-change gate), spec-analyser (re-run on the delta)
Companions: spec-final.md (revised spec, non-material changes applied), spec-changes.json
-->
# Spec analysis: #<issue> <title>

Spec version analysed: v<n>

## Findings

<!-- Cover each heading. Write "None found." rather than deleting one. -->

### Gaps

### Ambiguities

### Contradictions

### Missing acceptance criteria

### Edge cases

### Non-functional needs

- Accessibility:
- Performance:
- Security:
- Privacy:
- i18n:

### UI changes

<!-- yes/no, and which screens or components. -->

### Testability

<!-- Anything that cannot be verified as written, and what would make it verifiable. -->

## Classification

<!-- One row per proposed change. Type is material or non-material (DESIGN §8.1 rubric). Non-material rows are already applied in spec-final.md. -->

| # | Change | Type | Rubric reason | Rationale |
|---|---|---|---|---|
| 1 | <change> | non-material | <e.g. implied AC made explicit> | <why> |
| 2 | <change> | material | <e.g. user-visible behaviour changed> | <why> |

## Questions

<!-- One per material change. The orchestrator asks these with AskUserQuestion. -->

### Q1. <question> (change #2)

- **Recommended answer:** <answer>, because <reason>.
- **Alternatives:** <option>; <option>.

<!-- Return block (DESIGN §7.5). needs_input if any change is material. -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/01-spec-analysis.md, .aew/runs/<run-id>/spec-final.md, .aew/runs/<run-id>/spec-changes.json
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
