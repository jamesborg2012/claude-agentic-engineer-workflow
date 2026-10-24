# Brief: #201 Add to basket

Source: spec-final.md (v1)

## Goal

Shoppers can add a product to the basket and see the header count update, and the icon-only basket button in the header is usable by assistive technology.

## Context

A static shop (`site/`, served by `npx serve`) with a header, a list of three products and a footer. `site/basket.js` holds the basket logic and `site/app.js` wires the page to it. There is no order flow in this repo: orders and confirmation emails belong to the shop's order service.

## Acceptance criteria

- **AC-1** [UI] Given the shop page with an empty basket, when the customer selects "Add to basket" on a product, then the header status reads "Items in basket: 1"; selecting it on a second product makes it read "Items in basket: 2".
- **AC-2** [UI] [A11Y] The header basket button has the accessible name "View basket" and can be reached by keyboard, and the shop page has no serious or critical accessibility violations against WCAG 2.2 AA.
- **AC-3** [UI] At desktop (1440×900) and mobile (390×844), the header and all three products are visible without horizontal scrolling.
- **AC-4** Given a placed order, the customer receives a confirmation email listing the basket items. Orders are placed and emailed by the shop's order service, outside this repo.

## Non-goals

- Opening or rendering the basket panel.
- The order flow and checkout.
- Sending the confirmation email (the order service does this).

## Constraints

- No new runtime dependency.
- Accessibility target: WCAG 2.2 AA.

## Affected surfaces

- The header status ("Items in basket: <n>") and the icon-only basket button.
- The product list: the three "Add to basket" buttons.

## Test data and accounts needed

None; no accounts.

## UI changes: yes

## Definition of Done

- [ ] Every AC has a passing test, or a manual test with a reason.
- [ ] Lint, format, typecheck and unit tests pass.
- [ ] UI changes: every automatable UI test passes at every viewport, and the axe scan has no serious or critical violations.
- [ ] Review approved.
- [ ] Docs updated.

## Open risks

- AC-4 cannot be exercised from this repo; it needs the order service and a real inbox, so it is a manual test.

STATUS: ok
ARTEFACTS: .aew/runs/951/02-brief.md
SUMMARY: Compiled brief for #201, an add-to-basket count and an accessible basket button, with four ACs of which AC-4 is manual-only.
NEXT: standards
