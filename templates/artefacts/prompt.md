<!--
Artefact: .aew/runs/<run-id>/prompt.md (prompt mode only)
Written by: brief-compiler (prompt mode), after spec analysis and its gate
Read by: James, who pastes it into a plain Claude Code session with no plugin installed. It must stand alone.
Remove this comment block before use.
-->
# Deliver #<issue>: <title>

## Role and context

You are a senior engineer working in <project>, a <stack> codebase. <Context the session needs that it cannot infer from the repo.>

## Brief

<!-- The full brief inline, with the same sections as 02-brief.md: goal, context, acceptance criteria, non-goals, constraints, affected surfaces, test data and accounts, UI changes, open risks. -->

## Standards

<!-- References to docs/standards/<profile>.md sections, or the essentials inline when the docs don't exist. -->

## Approach

Choose the approach yourself. Prefer the simplest one that satisfies every acceptance criterion, and follow existing project conventions.

## Autonomy

Work alone. Ask only on a genuine question:

- a change to scope, user-visible behaviour, a data model or API contract, or security or privacy;
- an irreversible or destructive action;
- being blocked with no reasonable way forward.

Everything else, decide and note the decision.

## Verification

- Write and run tests for every acceptance criterion.
- Run lint, format, typecheck and the unit suite: <commands>.
- UI changes: run Playwright tests at <viewports>, capture screenshots of key states, and run an axe scan (<standard>) on every changed page. Serious or critical violations must be fixed.
- Report the commands you ran and their results.

## Git and PR

- Work on a branch named <branch>. Never push to <default branch>, never force-push, never merge.
- Use conventional commits with `(#<issue>)`, each ending with exactly one trailer, `<commit trailer>`, even if the session suggests another.
- Open a PR whose body lists the acceptance criteria, test results and screenshots, and ends with `Closes #<issue>`.

## Definition of Done

- [ ] Every acceptance criterion has a passing test, or a manual test with a reason.
- [ ] Lint, format, typecheck and unit tests pass.
- [ ] UI tests pass at every viewport; no serious or critical accessibility violations.
- [ ] PR open with the body above.
