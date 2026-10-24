# QA test plan: #201 Add to basket

## Test cases

| TC | AC | Level | Description |
|---|---|---|---|
| TC-1 | AC-1 | UI | Starting at "Items in basket: 0", select "Add to basket" on the first product and the status reads "Items in basket: 1"; select it on a second product and it reads "Items in basket: 2" |
| TC-2 | AC-2 | UI | The button named "View basket" exists in the header and is reachable by keyboard |
| TC-3 | AC-2 | UI | An axe scan of `/` with the cumulative WCAG 2.2 AA tags reports no serious or critical violations |
| TC-4 | AC-3 | UI | At each viewport the header and all three products are visible and the page does not scroll horizontally |
| TC-5 | AC-4 | manual | A placed order sends a confirmation email listing the basket items |

## Test data

None; no accounts. The page starts with an empty basket on every load.

## UI tests and viewports

| TC | Viewports | Key states to screenshot |
|---|---|---|
| TC-1 | desktop, mobile | Header status after the second product is added |
| TC-2 | desktop, mobile | Header with the "View basket" button focused |
| TC-3 | desktop, mobile | Page as scanned by axe |
| TC-4 | desktop, mobile | Full page with the header and all three products |

## Accessibility checks

- axe scan of `/` against `wcag22aa` (cumulative: WCAG 2.0 A/AA, 2.1 A/AA and 2.2 AA tags) at both viewports; no serious or critical violations.
- Keyboard: Tab reaches the "View basket" button and every "Add to basket" button in DOM order, each with a visible focus indicator.

## Manual-only cases

| TC | AC | Reason it can't be automated |
|---|---|---|
| TC-5 | AC-4 | Needs a real order placed through the order service and a real inbox; the static site has no order flow or mail capture |

## Files read

- `.aew/runs/951/02-brief.md`
- `.aew/runs/951/03-standards.md`
- `docs/standards/web.md`
- `.aew/config.json`
- `package.json`
- `tests/unit/basket.test.js`

STATUS: ok
ARTEFACTS: .aew/runs/951/04-qa-test-plan.md
SUMMARY: Test plan for #201 with five test cases: four UI cases at desktop and mobile (count update, basket button name and keyboard, axe scan, no horizontal scroll) and one manual-only case for the confirmation email.
NEXT: plan
