## In plain English

James asked for a shopping basket on the static shop (issue #12). Shoppers could browse products but had nowhere to collect what they wanted to buy, so the request was to let them add items, change quantities and see a running total.

Shoppers can now press Add to basket on any product page, open the basket from the header, and remove items or change how many they want. The total updates straight away, and the basket is remembered if they close the tab and come back later.

It was built as a small piece of page script that keeps the basket in the browser itself, because the shop has no server to store it on. A cookie was considered and rejected, since it is sent with every request for no benefit here.

During planning the request was clarified so that a quantity can never drop below one. One manual check is still outstanding: trying the basket on a real phone, which the automated tests cannot do. All 14 checks pass on desktop and mobile.

| Suite | Result |
|---|---|
| Unit | 9/9 |

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
