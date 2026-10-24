# Phase B plan: the static-shop fixture and its fixture run dirs

- **Spec:** `docs/superpowers/specs/2026-10-24-build-agents.md` (hash `3507d614…26c9c7`)
- **Phase:** B of the EPIC. It has no phase dependencies and runs in parallel with A. Phases C and D depend on it, and E depends on it through them.
- **Depth:** lean (no inline code; each task names its files, pattern, the exact facts the fixture must contain, and its checks)
- **ACs covered:** AC-16, AC-17, AC-18
- **Risk:** none. Test fixtures only: no scripts, hooks, agents or plugin manifests change. The residual risk is an accidental extra defect in the site, which would cost a paid QA cycle; B1's browser check exists to catch it before Phase C spends money.
- **Date:** 2026-10-24

## Purpose

Phase B builds `tests/fixtures/apps/static-shop/`, the target project for every headless smoke run in this prompt (941, 951, 961, 971, 972). It has three parts:

- a tiny static shop served by `npx serve`, with exactly three planted problems (AC-16);
- `run/`, a fixture run dir for issue #201, as if the pipeline had reached QA phase B (AC-17);
- `run-fanout/`, a two-package plan for issue #202 that exercises the developer's fan-out (AC-18).

B creates only files under `tests/fixtures/apps/static-shop/`. It edits nothing that A, C, D or E owns: no template, agent, skill, harness or README change.

## Binding decisions (from the CTO cuts and spec-review notes; not re-derived)

- **CTO cut 2:** `run/` omits `00-issue-original.md`. It holds only `issue.json`, `spec-final.md` and `02`–`06`. This overrides the file list in AC-17's text.
- **CTO cut 4:** `run-fanout/` is only `02-brief.md` and `05-plan.md`. The fan-out project copies `run/03-standards.md`, so B writes no second standards artefact.
- **Spec-review note 1 / A26:** the fixture `.gitignore` ignores `.aew/runs/`, never `.aew/`, so `.aew/config.json` is committed.
- **Spec-review note 4:** the first line of the fixture `CLAUDE.md` states that it is fixture-only.
- **No `frontend-design` for the site.** This is a test fixture whose only job is to carry exactly three defects. Styling stays plain (system font stack, a high-contrast palette at 4.5:1 or better, one column that reflows at 390 px, no images). Visual polish would add accidental-defect risk and buy nothing.

## Interface contract (what Phases C, D and E rely on)

Values here are fixed. A later phase that needs a different value raises it at plan review; it doesn't edit B's files silently.

### Paths

| Path (under `tests/fixtures/apps/static-shop/`) | Purpose |
|---|---|
| `package.json` | `"name": "static-shop"`, `"private": true`, `"type": "module"`; `scripts` `start` (`serve -l 4173 site`) and `test` (`node --test`); `devDependencies` exactly `serve` `14.2.6`, `@playwright/test` `1.64.1`, `@axe-core/playwright` `4.14.0` (no `^` or `~`) |
| `.gitignore` | exactly `node_modules/`, `.aew/runs/`, `test-results/`, `playwright-report/` |
| `.aew/config.json` | see Config values |
| `site/index.html`, `site/app.js`, `site/basket.js`, `site/styles.css` | the shop |
| `tests/unit/basket.test.js` | the one passing unit test |
| `docs/standards/README.md`, `docs/standards/web.md` | the standards docs |
| `CLAUDE.md` | the near-cap project memory |
| `run/` | issue #201 run dir (7 files, below) |
| `run-fanout/` | issue #202 run dir (2 files, below) |

The fixture has **no** `playwright.config.*`, no `tests/e2e/`, and no `package-lock.json` (A4: QA creates the Playwright config, and the harness installs the dependencies).

### Config values (`.aew/config.json`, valid against `templates/config.schema.json`)

- `project` `static-shop`; `default_branch` `main`; `stacks` `[{ "profile": "web", "path": ".", "version": "es2022" }]`.
- `commands`: only `install` `npm install`, `test_unit` `node --test`, `test_e2e` `npx playwright test`. Lint, format and typecheck are omitted, so agents record them as "not configured".
- `app`: `base_url` and `ready_check` both `http://localhost:4173`; `start_command` `npx serve -l 4173 site`; `env_type` `native`; `test_accounts` `[]`.
- `ui` (written out explicitly at the schema defaults): viewports `desktop` 1440×900 and `mobile` 390×844; `axe` `true`; `axe_standard` `wcag22aa`; `e2e_dir` `tests/e2e`.
- `evidence`: `dir` `docs/qa`, `format` `jpeg`, `quality` `80`.
- `limits`: `max_fix_cycles` 3, `max_review_cycles` 2, `max_parallel_developers` 4.
- `claude_md`: `max_lines` **40**.
- `retro`: `repo` `jamesborg2012/claude-agentic-engineer-workflow`, `label` `retro`.
- `git` and `gates` are omitted (schema defaults apply: `feat/{issue}-{slug}`, plan approval on).

### The planted problems (AC-16) and how QA sees them

QA phase A is blind to `site/`, so every locator below comes from the brief's wording. The site's markup must make that wording true. Apart from these three problems, the site is clean.

| # | Problem | Where it lives (for B1 and the developer's fix only) | What QA observes | Expected cycle-1 TC result |
|---|---|---|---|---|
| D1 | Functional bug: "Add to basket" doesn't update the basket count | `site/app.js`: the click handler calls `basket.add(id)` correctly, then writes the new count to the count element's `data-count` attribute instead of its text. The visible text stays `0`. It throws nothing and logs nothing. | The header status (`getByRole('status')`) still reads `Items in basket: 0` after a click | TC-1 fails, `impl_bug` |
| D2 | Serious accessibility violation: the icon-only basket button has no accessible name | `site/index.html`: a header `<button type="button">` that contains only an inline SVG with `aria-hidden="true"` and `focusable="false"`. It has no text, `aria-label`, `aria-labelledby` or `title`. | `getByRole('button', { name: 'View basket' })` finds nothing; axe reports `button-name` (impact `critical`) | TC-2 fails, `impl_bug`; TC-3 fails in the serious-or-critical band, `impl_bug` |
| D3 | Non-automatable requirement: a confirmation email is sent when an order is placed | Brief AC-4 only. The site has no order flow: orders and email go through the shop's order service, which is outside this repo. | Nothing to automate | TC-5 is manual-only, so it goes to `manual-tests.md` |

**Fixed markup facts** (the brief states them; B1 makes them true; C's specs rely on them):

- `<html lang="en">`, `<title>Static Shop</title>`, landmarks `header`, `main` and `footer`, one `h1` ("Static Shop"), one `h2` per product.
- The header holds the D2 button and, outside it, a basket status `<p role="status">` whose full text is `Items in basket: <n>`, with the number in `<span id="basket-count">`. It starts at `0`.
- `main` has a `ul` of exactly three products: "Tea towel" (£8.00), "Mug" (£12.50) and "Notebook" (£5.00). Each `li` holds its `h2` name, its price text and one `<button type="button">Add to basket</button>` carrying `data-product-id`.
- `site/app.js` is an ES module loaded with `<script type="module" src="app.js">` and imports `./basket.js`. `basket.js` exports `createBasket()`, which returns `{ add(productId), count() }`. It is correct, and it is the only module the unit test covers.
- Every button is at least 24×24 CSS px (set in `styles.css`), so axe's `target-size` rule (tagged `wcag22aa`, and run by the cumulative tags) reports nothing. Chromium's default button is about 21 px high.
- At both viewports, nothing scrolls horizontally (`document.documentElement.scrollWidth` ≤ `window.innerWidth`). There are no console errors or page errors, and every control can be reached by keyboard in DOM order.

**The intended fix** (two edits; the developer's fix mode finds it alone, and B1 proves it clears every failure): set the count element's `textContent` instead of `data-count`, and give the basket button `aria-label="View basket"`. After both edits, axe reports no violations of any impact with the cumulative WCAG 2.2 AA tags, and one click makes the status read `Items in basket: 1`.

### Issue, run and TC identifiers

| | #201 (`run/`) | #202 (`run-fanout/`) |
|---|---|---|
| Title / slug | "Add to basket" / `add-to-basket` | "Add shop helpers" / `add-shop-helpers` |
| Branch (harness) | `feat/201-add-to-basket` | `feat/202-add-shop-helpers` |
| `issue.json` `url` | `https://github.com/acme/static-shop/issues/201`, so owner/repo is `acme/static-shop` | none (`run-fanout/` has no `issue.json`) |
| Run id in ARTEFACTS lines | `951` (`.aew/runs/951/…`) | `961` |
| UI changes | yes | no |

**#201 brief ACs** (fixed wording; C, D and E match on these ids):

- **AC-1** [UI] Given the shop page with an empty basket, when the customer selects "Add to basket" on a product, then the header status reads "Items in basket: 1"; selecting it on a second product makes it read "Items in basket: 2".
- **AC-2** [UI] [A11Y] The header basket button has the accessible name "View basket" and can be reached by keyboard, and the shop page has no serious or critical accessibility violations against WCAG 2.2 AA.
- **AC-3** [UI] At desktop (1440×900) and mobile (390×844), the header and all three products are visible without horizontal scrolling.
- **AC-4** Given a placed order, the customer receives a confirmation email listing the basket items. Orders are placed and emailed by the shop's order service, outside this repo.

**#201 test cases** (`run/04-qa-test-plan.md`):

| TC | AC | Level | Viewports | Cycle 1 | Cycle 2 |
|---|---|---|---|---|---|
| TC-1 | AC-1 | UI | desktop, mobile | fail (`impl_bug`, D1) | pass |
| TC-2 | AC-2 | UI | desktop, mobile | fail (`impl_bug`, D2) | pass |
| TC-3 | AC-2 | UI (axe scan) | desktop, mobile | fail, `button-name` critical (`impl_bug`, D2) | pass |
| TC-4 | AC-3 | UI | desktop, mobile | pass | pass |
| TC-5 | AC-4 | manual | — | manual-only: "needs a real order placed through the order service and a real inbox; the static site has no order flow or mail capture" | manual |

The expected screenshots are `docs/qa/201/screenshots/TC-<n>-<viewport>.jpg` for n = 1 to 4 and viewports `desktop` and `mobile`: 8 files. TC-1's screenshots are the ones whose pixels the fix changes.

**#202 brief ACs and work packages** (`run-fanout/`):

- **AC-1** `formatPrice(pence)` returns pounds with two decimals and a `£` sign: `formatPrice(1250)` is `"£12.50"`, `formatPrice(5)` is `"£0.05"`, `formatPrice(0)` is `"£0.00"`.
- **AC-2** `clampQuantity(n)` returns an integer from 1 to 10: `clampQuantity(0)` is `1`, `clampQuantity(12)` is `10`, `clampQuantity(3)` is `3`.
- **WP-1** "Price formatting" (AC-1): create `site/format-price.js` and `tests/unit/format-price.test.js`. `depends_on: []`, `parallelisable: yes`.
- **WP-2** "Quantity clamping" (AC-2): create `site/clamp-quantity.js` and `tests/unit/clamp-quantity.test.js`. `depends_on: []`, `parallelisable: yes`.
- Neither module is wired into the page. After integration, `node --test` runs 3 tests: basket plus the two new ones.

### CLAUDE.md planted lines (Phase E's AC-22 checks)

- The cap is `claude_md.max_lines` 40, and the fixture `CLAUDE.md` is 34 to 37 lines (`wc -l`).
- **Standards duplicate:** exactly one line contains the marker ``never use `var` ``. It restates a `docs/standards/web.md` `## Language idioms` rule, which contains the same marker.
- **Time-bound line:** exactly one line contains the marker `Until 2026-11-30` (a deploy freeze for a sale).
- Line 1 says that the file is fixture-only (it contains `fixture`).

### Standards fingerprint

`docs/standards/web.md` line 1 is `<!-- aew:standards fingerprint="web serve@14 cfg:5f3c9a1e7b20" generated="2026-10-24" -->`. The same fingerprint string appears in `docs/standards/README.md` and in `run/03-standards.md` (status `reused`). It is a fixed fixture value: no standards-setter runs on this fixture.

### Unit test command

`node --test`, run from the project root (Node 22 or later, whose default discovery finds `tests/unit/*.test.js` and skips `node_modules`). Before fan-out it runs 1 test.

### Notes for the harness and the agents (C, D, E)

- **Install before the first commit.** There is no lockfile, so the harness runs `npm install` (and `npx playwright install chromium`) before `git add -A`, or `package-lock.json` would show up as an unintended file in AC-25's `git status` check.
- **Keep the fixture's `.gitignore`.** Don't overwrite it with `.aew/`, as prompt 03's `smoke_project` does (A26). Remove `run/` and `run-fanout/` from the temp project after copying their files into the run dir.
- **Spec naming.** Playwright specs go in `tests/e2e/` named `*.spec.ts` (never `*.test.*`), so `node --test` never runs them. `playwright.config` must set `testDir` to `ui.e2e_dir`, or Playwright's default match would pick up `tests/unit/*.test.js`. The fixture's `web.md` states the naming rule, so phase A learns it from the standards.
- **Fan-out standards.** The fan-out project copies `run/03-standards.md`, whose title line says #201 (CTO cut 4). That is harmless. If the developer stops on the mismatch, the harness may rewrite the title line only.
- **Stale dev report.** `run/06-dev-report.md` is a valid `STATUS: ok` report with a filled `## Commands run`. For the report-less gate checks (971/972), the harness must write `state.json` (`state.sh stage …`) after copying it, so the copied report is older than the state and the gate blocks.
- **Run ids in ARTEFACTS lines.** `run/` names run `951`. When 941 copies `02-brief.md` and `03-standards.md`, the mismatch is harmless, because agents don't follow the ARTEFACTS lines of their inputs.
- **Template contract with Phase C (AC-15).** `run/04-qa-test-plan.md` already has `## Files read` as its last `##` heading, after `## Manual-only cases` and before the return block. C's edit to `templates/artefacts/qa-test-plan.md` must put the heading in that position, so the fixture keeps conforming.

## Tasks

Waves: **B1 ∥ B2**, then **B3 ∥ B4**. Run every check from `tests/fixtures/apps/static-shop/` unless it says otherwise. `$REPO` is the repo root.

### B1: the shop site, package and config

- **files:** `tests/fixtures/apps/static-shop/{package.json, .gitignore, .aew/config.json, site/index.html, site/app.js, site/basket.js, site/styles.css, tests/unit/basket.test.js}`
- **depends_on:** []
- **pattern:** fixture conventions from `tests/fixtures/stacks/react-vite/` (minimal, realistic project files, nothing extra); `templates/config.example.json` for the config's shape; the Interface contract for every value. Unit test: `node:test` plus `node:assert/strict`, with one `test()` that adds two products and asserts `count()` is 2.
- **covers AC-16** (the site, the pins, the config, the `.gitignore` and the unit test). It must contain exactly D1 and D2 as described, and D3 needs nothing in the site.
- **Checks:**
  - `node --test` passes and reports 1 test;
  - the config is valid: `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "$REPO/templates/config.schema.json" -d .aew/config.json`;
  - `jq -r '.devDependencies | to_entries[] | "\(.key)@\(.value)"' package.json | sort` prints exactly `@axe-core/playwright@4.14.0`, `@playwright/test@1.64.1`, `serve@14.2.6`;
  - `jq -r '.claude_md.max_lines, .app.start_command, .commands.test_unit' .aew/config.json` prints `40`, `npx serve -l 4173 site`, `node --test`;
  - `git -C "$REPO" check-ignore -q tests/fixtures/apps/static-shop/.aew/config.json` fails (the config is not ignored), and `git -C "$REPO" check-ignore -q tests/fixtures/apps/static-shop/.aew/runs/x` succeeds;
  - **browser check** (throwaway, under the gitignored `$REPO/tests/tmp/static-shop-check/`, never committed): copy the fixture there, run `npm install` and `npx playwright install chromium`, start `npx serve -l 4173 site` in the background, and run a one-off Node script that uses `chromium` from `@playwright/test` and `AxeBuilder` from `@axe-core/playwright` with the tags `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`. At each viewport, the script asserts:
    1. the axe violations are exactly `["button-name"]`, with impact `serious` or `critical`;
    2. after one click on "Add to basket", the status still reads `Items in basket: 0`;
    3. nothing scrolls horizontally;
    4. there are no console errors or page errors.

    Then, in the copy only, apply the intended fix's two edits and assert there are zero violations and the status reads `Items in basket: 1`. Stop the server by its port. Record the output in the task report. If the network is unavailable, report `DONE_WITH_CONCERNS` and leave the check for Phase C's first paid run to catch.
- **Commit:** `test(fixtures): add the static-shop app fixture with planted defects`
- **Risk:** none

### B2: standards docs and the near-cap CLAUDE.md

- **files:** `tests/fixtures/apps/static-shop/{docs/standards/README.md, docs/standards/web.md, CLAUDE.md}`
- **depends_on:** []
- **pattern:** `skills/stack-standards/references/document-structure.md`: the line-1 header, the `Sources:` line, the 11 required headings in order, `**[convention]**` markers (all rules are conventions, because the fixture runs no linter), and the README index table plus its precedence line. CLAUDE.md follows the A24 entry format: one bullet per learning under a few headings (Commands, Gotchas, Architecture decisions, Conventions).
- **covers AC-16** (the small `docs/standards/`, and the CLAUDE.md close to its cap).
  - `web.md` stays short (≤ 120 lines) and specific to this site: semantic landmarks; an accessible name on every icon-only control; prices as integer pence; ES modules served over HTTP (never `file://`); the ``never use `var` `` rule under `## Language idioms`; and, under `## Testing conventions`, unit tests in `tests/unit/<module>.test.js` run by `node --test`, with e2e specs in `tests/e2e/<feature>.spec.ts`.
  - CLAUDE.md has the fixture-only first line, durable entries (commands, the `serve` port, modules served over HTTP, basket state in `basket.js` with DOM wiring in `app.js`, Node 22+), and the two planted lines from the contract.
- **Checks:**
  - `head -1 docs/standards/web.md` equals the contract header;
  - the heading diff against the 11 headings prints nothing (the same `diff <(grep '^## ' …) <(printf …)` form as prompt 03's shared seed check);
  - `grep -c 'WCAG 2\.2 AA' docs/standards/web.md` ≥ 1;
  - `grep -c '5f3c9a1e7b20' docs/standards/README.md` = 1;
  - `wc -l < CLAUDE.md` is from 34 to 37;
  - `head -1 CLAUDE.md | grep -ci fixture` = 1;
  - ``grep -c 'never use `var`' CLAUDE.md`` = 1, and the same grep on `web.md` is ≥ 1;
  - `grep -c 'Until 2026-11-30' CLAUDE.md` = 1;
  - no secrets, tokens or URLs other than `localhost:4173`.
- **Commit:** `test(fixtures): add the static-shop standards and near-cap CLAUDE.md`
- **Risk:** none

### B3: `run/`, the #201 fixture run dir

- **files:** `tests/fixtures/apps/static-shop/run/{issue.json, spec-final.md, 02-brief.md, 03-standards.md, 04-qa-test-plan.md, 05-plan.md, 06-dev-report.md}`
- **depends_on:** [B1, B2] (it names their files, markup facts and fingerprint)
- **pattern:** each artefact starts from its template in `templates/artefacts/` (`brief.md`, `standards-run.md`, `qa-test-plan.md`, `plan.md`, `dev-report.md`), keeps every section in order and drops only the template's guidance comments. Tone and density follow `tests/fixtures/briefs/newsletter-signup.md`. `spec-final.md` uses the `###` body structure of `tests/fixtures/issues/clean-ui.md`'s `## Body` (Summary, Behaviour, Acceptance criteria, Out of scope). `issue.json` is produced by the real script, not by hand: follow the steps of `smoke_render` in `tests/agent-smoke/README.md` inline under `$REPO/tests/tmp/issue-render-201/` (the mocked `gh` and `scripts/gh-issue.sh fetch 201`), with `body.md` taken from `spec-final.md`, the title "Add to basket" and the URL `https://github.com/acme/static-shop/issues/201`. Don't call the function itself: it hard-codes `acme/web`, reads the body from `tests/fixtures/issues/<file>`'s `## Body`, and `cmp`s the render against that file. Skip the `cmp` and keep only the `issue.json` it writes.
- **covers AC-17** (as amended by CTO cut 2). Content:
  - **`02-brief.md`:** the four #201 ACs verbatim from the contract; `## UI changes: yes`; Affected surfaces (the header status and basket button, the product list); Test data ("none; no accounts"); Non-goals (opening the basket panel; the order flow); `Source: spec-final.md (v1)`.
  - **`03-standards.md`:** one row for `web`, the fingerprint and `reused`; sections that apply (Accessibility → AC-2, Framework conventions → AC-1, Testing conventions → all ACs).
  - **`04-qa-test-plan.md`:** the TC table from the contract; UI tests and viewports for TC-1 to TC-4 at `desktop, mobile`, with the state each screenshots; accessibility checks (axe on `/` with the cumulative WCAG 2.2 AA tags, plus keyboard reach); TC-5 in Manual-only cases with its reason; `## Files read` last (`02-brief.md`, `03-standards.md`, `docs/standards/web.md`, `.aew/config.json`, `package.json`, `tests/unit/basket.test.js`).
  - **`05-plan.md`:** one WP, WP-1 "Basket count and accessible basket button", `depends_on: []`, `parallelisable: no`. It owns `site/index.html`, `site/app.js`, `site/basket.js`, `site/styles.css` and `tests/unit/basket.test.js`. Its Goal says explicitly that the click handler writes the new count into the status text and that the icon button gets the accessible name "View basket", so that the planted code contradicts the plan, which makes the failures `impl_bug`. The traceability maps AC-1 to AC-3 to WP-1 and AC-4 to "none: order service, manual test", and `## Challenges to the spec` notes that AC-4 needs no code here.
  - **`06-dev-report.md`:** `Mode: full`; WP-1 done (Commit: `fixture base commit`); files changed; Commands run `node --test` | `pass (1 test)`, with lint, format and typecheck `not configured`; Deviations `None.`; Notes for QA (start command and URL); `STATUS: ok`.
  - Every `02`–`06` file ends with a valid return block naming run `951`. Only `#201` appears.
- **Checks** (from `run/`; `T=$REPO/templates/artefacts`):
  - `ls | sort` is exactly the 7 files (no `00-issue-original.md`);
  - the heading diffs print nothing:
    - brief against `brief.md`, with the README's `: yes/no` normalisation;
    - `03` against `standards-run.md`;
    - `05` against `plan.md`, with `### WP-` checked by pattern;
    - `06` against `dev-report.md`;
    - `04` against `qa-test-plan.md`'s `##` headings with `## Files read` appended;
  - `valid_return_block` (extracted from `gate-subagent.sh` with the README's `eval "$(sed -n …)"` line) passes on `02`–`06`, and `commands_filled` (extracted the same way) passes on `06-dev-report.md`;
  - `jq -e '.number == 201 and .url == "https://github.com/acme/static-shop/issues/201" and (.referenced_issues | length == 0)' issue.json`;
  - `grep -c '^- \*\*AC-[0-9]' 02-brief.md` = 4, and `02-brief.md` contains `WCAG 2.2 AA`, `1440`, `390`, `confirmation email`, `Items in basket: 1` and `View basket`;
  - `04-qa-test-plan.md`: each of `TC-1` to `TC-5` appears, and TC-5's row in Manual-only cases has a non-empty reason;
  - `grep -c 'View basket' 05-plan.md` ≥ 1, and `! grep -q '#202' -- *` succeeds (`grep -c` over several files prints one count per file, not a single 0).
- **Commit:** `test(fixtures): add the static-shop #201 run dir`
- **Risk:** none

### B4: `run-fanout/`, the #202 fan-out fixture

- **files:** `tests/fixtures/apps/static-shop/run-fanout/{02-brief.md, 05-plan.md}`
- **depends_on:** [B1] (the WP files must not collide with the site's existing files)
- **pattern:** `templates/artefacts/brief.md` and `plan.md`, with the B3 conventions; the #202 ACs and WPs from the contract.
- **covers AC-18.** The brief has `## UI changes: no` and both ACs verbatim. The plan has exactly two WPs, each with the exact template field lines (``- **depends_on:** []``, ``- **parallelisable:** yes``) and `create:` entries for its module and its unit test. It also has standards per WP (`web.md` Language idioms and Testing conventions), the expected unit tests per WP, traceability AC-1 → WP-1 and AC-2 → WP-2, and return blocks naming run `961`.
- **Checks** (from `run-fanout/`):
  - `ls | sort` is exactly `02-brief.md 05-plan.md`;
  - the heading diffs against `brief.md` and `plan.md` print nothing;
  - `valid_return_block` passes on both;
  - `grep -c '^### WP-' 05-plan.md` = 2, `grep -c 'parallelisable:\*\* yes' 05-plan.md` = 2, and `grep -c 'depends_on:\*\* \[\]' 05-plan.md` = 2;
  - the four `create:` paths are pairwise distinct, none of them exists under `tests/fixtures/apps/static-shop/`, and the two WPs share no file;
  - `! grep -q '#201' -- *` succeeds.
- **Commit:** `test(fixtures): add the static-shop #202 fan-out run dir`
- **Risk:** none

## Phase exit check (after B3 and B4; no separate task)

```bash
cd "$REPO"
tests/run-script-tests.sh                                   # still passes (nothing under scripts/ changed; nested fixtures are not scanned)
claude plugin validate .                                    # passes
git diff --name-only <phase-B-base>..HEAD | grep -v '^tests/fixtures/apps/static-shop/'   # prints nothing: B touched only the fixture
git ls-files tests/fixtures/apps/static-shop | grep -cE 'node_modules|package-lock|test-results|playwright-report'   # = 0
```

## AC → task matrix

| AC | Tasks |
|---|---|
| AC-16 | B1 (site, pins, config, `.gitignore`, unit test, D1/D2 and the browser check), B2 (standards, CLAUDE.md) |
| AC-17 | B3 (as amended by CTO cut 2: no `00-issue-original.md`) |
| AC-18 | B4 |

## Notes for the consolidator

- 4 tasks in 2 waves (B1 ∥ B2, then B3 ∥ B4), with no risk lines. No DECOMPOSE is needed.
- B adds no CHANGELOG, project-map or DESIGN entries. Phase E records the fixture, the planted-defect contract and the harness notes above in the project map.

## Approval

- Senior architect: APPROVED on 2026-10-24T19:54:50Z (plan-review, lean, Phase B)
- Plan format: LEAN
- Risk lines crossed: none (test fixtures only)
- Dependency graph: valid. Waves: 2 (B1 ∥ B2, then B3 ∥ B4). Max wave width: 2. No file overlap between tasks in the same wave.
- Auto-applied: the 24×24 button-size markup fact (axe `target-size` under `wcag22aa`); B3's `issue.json` step spelled out (`smoke_render` can't be called as-is); the `#201`/`#202` absence checks rewritten as `! grep -q`.
- Plan content hash (SHA-256, before this trailer): 5a6b5a95655d6e625a8232d25e35deeb25dbfd0ee5ce0336991ea42ffceea83d
