<!-- aew:standards fingerprint="web serve@14 cfg:5f3c9a1e7b20" generated="2026-10-24" -->
Sources: package.json, .aew/config.json; sampled site/index.html, site/app.js, site/basket.js, tests/unit/basket.test.js; seed web; context7 not used

## Tooling and commands

- **[convention]** Install with `npm install`; serve the site with `npm start` (`serve -l 4173 site`), which listens on port 4173.
- **[convention]** Run unit tests with `node --test` from the project root (Node 22 or later).
- **[convention]** Run end-to-end specs with `npx playwright test`. No linter, formatter or type checker is configured, so nothing here is enforced by a tool.

## Project structure

- **[convention]** The site lives in `site/`: `index.html`, `app.js` (DOM wiring), `basket.js` (basket state, no DOM access) and `styles.css`.
- **[convention]** Unit tests live in `tests/unit/`, end-to-end specs in `tests/e2e/`.
- **[convention]** Keep state and logic in modules that never touch the DOM, so they can be unit tested.

## Naming

- **[convention]** Files are lower-case with hyphens; JavaScript identifiers use camelCase.
- **[convention]** Element ids are lower-case with hyphens, for example `basket-count`.

## Language idioms

- **[convention]** Use ES modules (`import` and `export`); never use `var`. Prefer `const`, and use `let` only when the value is reassigned.
- **[convention]** Serve ES modules over HTTP, never from `file://`, because browsers block module loading from local files.
- **[convention]** Store prices as integer pence and format them for display only at the edge.

Do:
```js
const priceInPence = 1250;
```
Don't:
```js
var price = 12.5;
```

## Framework conventions

- **[convention]** There is no framework. Wire the DOM in `app.js` with `addEventListener`; do not use inline `onclick` attributes.
- **[convention]** Update visible state through `textContent`, never by writing the value to a `data-*` attribute that nothing displays.

## Error handling

- **[convention]** Do not swallow errors. Let unexpected errors reach the console rather than catching and ignoring them.
- **[convention]** Validate a product id before use and throw a clear `Error` for an unknown one.

## Security

- **[convention]** Never build markup from strings with `innerHTML` when the data is not a constant; use `textContent`.
- **[convention]** Keep credentials out of the repo, and load no third-party scripts.

## Accessibility

- **[convention]** The target is WCAG 2.2 AA.
- **[convention]** Use semantic landmarks: one `header`, one `main` and one `footer`, and a single `h1`.
- **[convention]** Give every icon-only control an accessible name, such as `aria-label`, and mark the decorative icon `aria-hidden="true"`.
- **[convention]** Announce changing status text through `role="status"`, and keep every interactive target at least 24 by 24 CSS pixels.
- **[convention]** Keep every control reachable by keyboard, in DOM order.

Do:
```html
<button type="button" aria-label="View basket"><svg aria-hidden="true" focusable="false"></svg></button>
```
Don't:
```html
<button type="button"><svg aria-hidden="true" focusable="false"></svg></button>
```

## Testing conventions

- **[convention]** Unit tests go in `tests/unit/<module>.test.js` and run with `node --test`.
- **[convention]** End-to-end specs go in `tests/e2e/<feature>.spec.ts`. Never name a Playwright spec `*.test.*`, or `node --test` would pick it up.
- **[convention]** Name cases by behaviour, for example `adds one item to the basket`.

## Documentation and comment standards

- **[convention]** Comment why, not what. Keep comments short and in British English.
- **[convention]** Record durable learnings in `CLAUDE.md`, within its line cap.

## Anti-patterns

- **[convention]** Writing state to a `data-*` attribute instead of the visible text: set `textContent`.
- **[convention]** Icon-only buttons without an accessible name: add `aria-label`.
- **[convention]** Opening `site/index.html` through `file://`: serve it with `npm start`.
