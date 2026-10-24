# Plan: #201 Add to basket

## Approach

One work package. The click handler adds the product to the basket and writes the new count into the status text, so the header reads "Items in basket: <n>". The icon-only basket button gets the accessible name "View basket". No new module and no new dependency.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Re-render the whole header on each add | More code than writing one text node, and no AC needs it |
| Name the button with visually hidden text | Also valid, but `aria-label` is the convention in docs/standards/web.md and is a one-attribute change |

## Challenges to the spec

AC-4 (the confirmation email) needs no code in this repo: the order service places orders and sends the email. It is covered by a manual test.

## Work packages

### WP-1: Basket count and accessible basket button

- **Goal:** The click handler in `site/app.js` calls `basket.add(id)` and then writes the new count into the status text, so the status reads "Items in basket: 1" after one add and "Items in basket: 2" after a second. The icon-only basket button in `site/index.html` gets the accessible name "View basket" through `aria-label="View basket"`, with the SVG kept `aria-hidden="true"`.
- **ACs covered:** AC-1, AC-2, AC-3
- **Files (owned by this WP):**
  - modify: site/index.html
  - modify: site/app.js
  - modify: site/basket.js
  - modify: site/styles.css
  - modify: tests/unit/basket.test.js
- **depends_on:** []
- **parallelisable:** no

## Standards per work package

| WP | Standards doc and section |
|---|---|
| WP-1 | docs/standards/web.md#accessibility |
| WP-1 | docs/standards/web.md#framework-conventions |
| WP-1 | docs/standards/web.md#testing-conventions |

## Guardrails

- No new dependency without justification.
- Don't touch files outside the work package's file list.
- No public API changes unless the brief specifies them.

## Unit tests per work package

| WP | Expected unit tests |
|---|---|
| WP-1 | `createBasket().add` increases `count()` by one per product |

## Risks

- None beyond the usual: the change is two small edits in a page with no other behaviour.

## AC→WP traceability

| AC | WP |
|---|---|
| AC-1 | WP-1 |
| AC-2 | WP-1 |
| AC-3 | WP-1 |
| AC-4 | none: order service, manual test |

STATUS: ok
ARTEFACTS: .aew/runs/951/05-plan.md
SUMMARY: One work package fixes the header count (write it into the status text) and names the icon button "View basket". AC-4 needs no code here.
NEXT: develop
