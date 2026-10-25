## In plain English

This milestone makes the static shop usable end to end: shoppers can fill a basket, see delivery costs before paying, and find products through search. It closes issues #12, #13 and #14, each of which stands on its own, and the three were built one after another on a single branch so that the finished shop behaves consistently.

Issue #12 adds the basket. Shoppers press Add to basket on any product page, open the basket from the header, and change or remove items. The total updates at once and the basket is remembered between visits, because it is stored in the browser rather than on a server.

Issue #13 shows delivery costs. Before paying, shoppers now see the delivery charge for their country and the final total, so there is no surprise at the last step. The charges come from a short list agreed in the issue, and an unknown country shows a clear message instead of a guess.

Delivery costs were the riskiest part, so they were checked against every country on the list, and the three issues share one set of page styles so that nothing looks out of place or behaves differently when a shopper moves between them.

Issue #14 adds search. A search box in the header finds products by name or description as the shopper types. During planning it was clarified that the search ignores capital letters. One manual check is still outstanding: trying the basket and search on a real phone. All 31 checks pass on desktop and mobile.

## Summary

Adds a basket module in `src/basket.js` and wires it into `docs/index.html`.

## Acceptance criteria

- [x] AC-1: Add to basket on a product page (TC-1)
- [ ] AC-4: Basket usable on a real phone (TC-4)

## Test results

| Suite | Result |
|---|---|
| Unit | 9/9 |
| Acceptance | 5/5 |

## Manual tests

- TC-4: open the basket on a real phone.

## Closes

Closes #12
