# Dev report: #201 Add to basket

Mode: full

## Work packages done

| WP | Status | Commit |
|---|---|---|
| WP-1 | done | fixture base commit |

## Files changed

- site/index.html
- site/app.js
- site/basket.js
- site/styles.css
- tests/unit/basket.test.js

## Commands run

| Command | Result |
|---|---|
| lint | not configured |
| format | not configured |
| typecheck | not configured |
| node --test | pass (1 test) |

## Deviations

None.

## Notes for QA

Start the app with `npx serve -l 4173 site` and open http://localhost:4173.

STATUS: ok
ARTEFACTS: .aew/runs/951/06-dev-report.md
SUMMARY: WP-1 done: the click handler updates the header status and the basket button is named. node --test passes (1 test); lint, format and typecheck are not configured.
NEXT: qa
