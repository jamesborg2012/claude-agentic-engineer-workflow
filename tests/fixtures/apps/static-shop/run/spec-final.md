### Summary

Shoppers can add a product to their basket from the shop page and see the basket count in the header update straight away. The header also carries an icon-only basket button, which needs an accessible name.

### Behaviour

- The shop page lists three products: "Tea towel", "Mug" and "Notebook". Each has an "Add to basket" button.
- The header status reads "Items in basket: 0" on load. Selecting "Add to basket" on a product makes it read "Items in basket: 1"; selecting it on a second product makes it read "Items in basket: 2".
- The icon-only basket button in the header has the accessible name "View basket" and can be reached by keyboard. Opening the basket is a later issue.
- At desktop (1440×900) and mobile (390×844), the header and all three products are visible without horizontal scrolling.
- Orders are placed and emailed by the shop's order service, which lives outside this repo. A placed order sends the customer a confirmation email listing the basket items.

### Accessibility

- WCAG 2.2 AA.
- The page has no serious or critical axe violations.

### Acceptance criteria

1. With an empty basket, selecting "Add to basket" on a product makes the header status read "Items in basket: 1"; selecting it on a second product makes it read "Items in basket: 2".
2. The header basket button has the accessible name "View basket", can be reached by keyboard, and the shop page has no serious or critical accessibility violations against WCAG 2.2 AA.
3. At desktop (1440×900) and mobile (390×844), the header and all three products are visible without horizontal scrolling.
4. Given a placed order, the customer receives a confirmation email listing the basket items.

### Out of scope

- opening or rendering the basket panel;
- the order flow and checkout;
- sending the confirmation email (the order service does this).
