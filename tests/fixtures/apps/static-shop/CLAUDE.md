# static-shop CLAUDE.md (fixture-only: a test fixture for the aew smoke runs, not a real project)

Project memory for the static-shop site. Keep it under 40 lines.

## Commands

- Install: `npm install`.
- Serve the site: `npm start` (`serve -l 4173 site`), then open `http://localhost:4173`.
- Unit tests: `node --test` from the project root.
- End-to-end specs: `npx playwright test`.
- Node 22 or later is required, because `node --test` discovery depends on it.

## Gotchas

- The site uses ES modules, so serve it over HTTP; opening `index.html` from `file://` fails.
- Playwright specs are named `*.spec.ts` and live in `tests/e2e/`, so `node --test` skips them.
- Do not run `npm install` inside `site/`; dependencies live at the project root.
- `serve` caches nothing by default, so no cache-busting is needed after an edit.
- The Playwright browsers are installed separately with `npx playwright install chromium`.
- Screenshots and reports go to `docs/qa/`, never into `site/`.

## Architecture decisions

- Basket state lives in `site/basket.js`; the DOM wiring lives in `site/app.js`.
- `basket.js` has no DOM access, so the unit test can import it directly.
- Prices are integer pence and formatted only when displayed.
- There is no order flow: orders and email go through an external order service.

## Conventions

- Unit tests are in `tests/unit/<module>.test.js`, end-to-end specs in `tests/e2e/<feature>.spec.ts`.
- Prefer `const` over `let`, and never use `var`.
- Until 2026-11-30 the sale banner copy is frozen, so do not edit it.
- Give every icon-only control an accessible name.
- Use semantic landmarks: `header`, `main` and `footer`.
- Write comments in British English and explain why, not what.
- Update this file when a durable learning appears, and prune stale lines.
