<!--
Artefact: .aew/runs/<run-id>/05-plan.md
Written by: senior-engineer (plan mode). No code beyond short illustrative signatures.
Read by: orchestrator (plan gate summary), developer, senior-engineer (review, triage), doc-writer (key decisions)
-->
# Plan: #<issue> <title>

## Approach

<!-- The simplest approach that satisfies the brief. -->

## Alternatives considered

<!-- At least one. -->

| Alternative | Why rejected |
|---|---|

## Challenges to the spec

<!-- Challenges to the spec or its constraints. One that implies a material spec change means STATUS: needs_input. -->

## Work packages

### WP-1: <name>

- **Goal:**
- **ACs covered:** AC-1
- **Files (owned by this WP):**
  - create: <path>
  - modify: <path>
- **depends_on:** []
- **parallelisable:** yes / no

## Standards per work package

| WP | Standards doc and section |
|---|---|
| WP-1 | docs/standards/<profile>.md#<section> |

## Guardrails

- No new dependency without justification.
- Don't touch files outside the work package's file list.
- No public API changes unless the brief specifies them.

## Unit tests per work package

| WP | Expected unit tests |
|---|---|
| WP-1 | <behaviour under test> |

## Environment

<!-- What develop needs from the machine, one line each, or "None.". Only these forms, because scripts/check-env.sh checks them before the plan gate and when develop starts:
- tool: <command> <major>
- tool: <command>
- service: docker -->

## Risks

## AC→WP traceability

| AC | WP |
|---|---|
| AC-1 | WP-1 |

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/05-plan.md
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
