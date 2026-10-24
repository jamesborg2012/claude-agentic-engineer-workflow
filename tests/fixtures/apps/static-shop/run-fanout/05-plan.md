# Plan: #202 Add shop helpers

## Approach

Build the two helpers as separate modules with a unit test each. They share no files and neither depends on the other, so they are two work packages that can run in parallel. Prices stay integer pence and are formatted only inside `formatPrice`.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| One `helpers.js` module holding both functions | Two functions in one file would make the work packages share a file and force them to run in sequence. |
| Wire the helpers into the page now | Out of scope for the brief; it would touch existing files and add UI changes. |

## Challenges to the spec

None. Both ACs are fully specified with worked examples.

## Work packages

### WP-1: Price formatting

- **Goal:** Add `formatPrice(pence)` to its own module, returning pounds with two decimals and a `£` sign, and cover it with a unit test.
- **ACs covered:** AC-1
- **Files (owned by this WP):**
  - create: site/format-price.js
  - create: tests/unit/format-price.test.js
- **depends_on:** []
- **parallelisable:** yes

### WP-2: Quantity clamping

- **Goal:** Add `clampQuantity(n)` to its own module, returning an integer from 1 to 10, and cover it with a unit test.
- **ACs covered:** AC-2
- **Files (owned by this WP):**
  - create: site/clamp-quantity.js
  - create: tests/unit/clamp-quantity.test.js
- **depends_on:** []
- **parallelisable:** yes

## Standards per work package

| WP | Standards doc and section |
|---|---|
| WP-1 | docs/standards/web.md#language-idioms, docs/standards/web.md#testing-conventions |
| WP-2 | docs/standards/web.md#language-idioms, docs/standards/web.md#testing-conventions |

## Guardrails

- No new dependency without justification.
- Don't touch files outside the work package's file list.
- No public API changes unless the brief specifies them.

## Unit tests per work package

| WP | Expected unit tests |
|---|---|
| WP-1 | `formatPrice` returns `"£12.50"` for 1250, `"£0.05"` for 5 and `"£0.00"` for 0 (one test, `tests/unit/format-price.test.js`). |
| WP-2 | `clampQuantity` returns 1 for 0, 10 for 12 and 3 for 3 (one test, `tests/unit/clamp-quantity.test.js`). |

## Risks

Low. The work packages are disjoint, so integration is two clean cherry-picks. After integration `node --test` should run 3 tests: the basket test plus one per helper.

## AC→WP traceability

| AC | WP |
|---|---|
| AC-1 | WP-1 |
| AC-2 | WP-2 |

STATUS: ok
ARTEFACTS: .aew/runs/961/05-plan.md
SUMMARY: Plan for #202 Add shop helpers: two independent, parallelisable work packages. WP-1 adds formatPrice and its test; WP-2 adds clampQuantity and its test. File lists are disjoint and neither depends on the other. Standards are the web language idioms and testing conventions. Three unit tests run after integration.
NEXT: Run the developer in full mode, fanning out WP-1 and WP-2 in parallel.
