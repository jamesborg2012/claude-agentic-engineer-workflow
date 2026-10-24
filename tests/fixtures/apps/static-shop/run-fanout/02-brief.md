# Brief: #202 Add shop helpers

Source: spec-final.md (v1)

## Goal

Add two small, pure helper modules for the static shop: one that formats a price held in pence for display, and one that clamps a basket quantity to the allowed range. Neither is used by the page yet.

## Context

The shop stores prices as integer pence and formats them only at the edge (`docs/standards/web.md`, Language idioms). The site is plain ES modules under `site/`, with unit tests under `tests/unit/` run by `node --test`. The basket today has one unit test.

## Acceptance criteria

- **AC-1** Given a price in pence, when `formatPrice(pence)` is called, then it returns pounds with two decimals and a `£` sign: `formatPrice(1250)` is `"£12.50"`, `formatPrice(5)` is `"£0.05"` and `formatPrice(0)` is `"£0.00"`.
- **AC-2** Given a quantity, when `clampQuantity(n)` is called, then it returns an integer from 1 to 10: `clampQuantity(0)` is `1`, `clampQuantity(12)` is `10` and `clampQuantity(3)` is `3`.

## Non-goals

- Wiring either helper into the page, the basket or any markup.
- Currencies other than pounds, and negative or fractional prices.

## Constraints

- ES modules only; no new dependencies.
- Each helper lives in its own module under `site/` with its own unit test under `tests/unit/`.
- After the work, `node --test` runs 3 tests: the existing basket test plus one for each helper.

## Affected surfaces

- New: `site/format-price.js`, `site/clamp-quantity.js`.
- New: `tests/unit/format-price.test.js`, `tests/unit/clamp-quantity.test.js`.
- No existing file changes.

## Test data and accounts needed

None; no accounts.

## UI changes: no

## Definition of Done

- [ ] Every AC has a passing test, or a manual test with a reason.
- [ ] Lint, format, typecheck and unit tests pass.
- [ ] UI changes: every automatable UI test passes at every viewport, and the axe scan has no serious or critical violations.
- [ ] Review approved.
- [ ] Docs updated.

## Open risks

None. The two helpers share no files, so they can be built independently.

STATUS: ok
ARTEFACTS: .aew/runs/961/02-brief.md
SUMMARY: Brief for #202 Add shop helpers. Two ACs: formatPrice turns pence into a £ string with two decimals, and clampQuantity returns an integer from 1 to 10. No UI changes and no wiring into the page; the helpers are independent modules, each with its own unit test.
NEXT: Standards are reused from the project; hand over to the senior engineer for planning.
