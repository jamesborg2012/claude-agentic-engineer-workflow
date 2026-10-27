---
name: ui-qa
description: How aew QA tests UI with Playwright. Covers setting Playwright up in a project, starting the app and waiting on ready_check, one Playwright project per viewport, @playwright/test spec conventions, JPEG screenshots per TC and viewport, the @axe-core/playwright scan with cumulative WCAG tags, exploratory checks through the bundled Playwright MCP, evidence rules and the manual-test handoff. Use it when writing or running UI tests or starting the app for an aew run.
user-invocable: false
---

# aew UI QA

Preloaded into `aew:qa-engineer` for phase B. The developer invokes it with the Skill tool in fix mode and
uses only §3 and §8. Placeholders `<…>` are config values (§1), and `<run_dir>` is the absolute run dir.

## 1. Config it reads

Read `.aew/config.json` with Read. All required keys and `app.*` are there. Defaults are the schema's.

| Key | Default | Meaning |
|---|---|---|
| `ui.viewports` | `desktop` 1440×900, `mobile` 390×844 | One Playwright project each (§4) |
| `ui.axe` | `true` | `false` means skip §7 and say so in the report |
| `ui.axe_standard` | `wcag22aa` | A conformance target, expanded in §7 |
| `ui.e2e_dir` | `tests/e2e` | Where specs live |
| `app.base_url`, `app.start_command` | none | §3 |
| `app.ready_check` | none | A URL if it starts with `http://` or `https://`, otherwise a command |
| `app.env_type` | none | `none` means no app to start |
| `app.test_accounts` | none | Env var names only. Specs read `process.env[<username_env>]`. Never write a value into a spec, a report or evidence. If a needed variable is unset, phase B is `blocked` and the summary names the variable |
| `evidence.dir` | `docs/qa` | §10 |
| `evidence.format` | `jpeg` | Any other value is unsupported in v1: use JPEG and note it |
| `evidence.quality` | `80` | JPEG quality |
| `commands.test_e2e` | not configured | Falls back to `npx playwright test` |
| `commands.install` | none | Dependency install |

## 2. Setting up Playwright

Run this when the project has no `@playwright/test` dependency or no `playwright.config.*`. If it already has
Playwright, keep its config and versions, add a project for each missing `ui.viewports` entry, add the `json`
reporter (`test-results/results.json`) if it is missing (§8 reads it), never remove existing projects, and note
any version mismatch in the report.

- The package dir is the repo root when a root `package.json` exists (JS projects). Otherwise it is `tests/e2e/`
  with its own `package.json` (`{"name": "<project>-e2e", "private": true}`) and its own `playwright.config.ts`
  (PHP and .NET projects). In the nested case `ui.e2e_dir` is that dir and `testDir` is `'.'`.
- Install from the package dir, exact-pinned, with the lockfile's package manager: `pnpm add -D -E …` if there
  is `pnpm-lock.yaml`, `yarn add -D -E …` if there is `yarn.lock`, otherwise
  `npm install --save-dev --save-exact @playwright/test@1.64.1 @axe-core/playwright@4.14.0`. Then
  `npx playwright install chromium`.
- Gitignore (append only the missing lines): `test-results/`, `playwright-report/`, `node_modules/` and
  `.playwright-mcp/` (the bundled MCP server writes page snapshots there, in the project cwd).
- Write `playwright.config.ts` (§4) and `<e2e_dir>/aew.ts` (§6 and §7). The setup is committed with QA's cycle
  commit (the qa-engineer prompt owns that rule).

## 3. Starting and stopping the app

`env_type: none` means there is no app to start: skip this section. Every other `env_type` (including wp-env,
ddev and docker) is started by `start_command`.

1. Reuse: `curl -fsS -o /dev/null --max-time 5 "<base_url>"`. If it exits 0, an instance is already running:
   use it and **leave it running**. Before relying on it, check it serves the current change (for example, a style
   or text the change introduced appears in the page or its stylesheet). If it serves stale content, return
   `blocked` and ask for that server to be restarted, because you may not restart one you did not start.
2. Otherwise start it from the project root in the background, logging to the run dir, with one Bash call that sets
   `run_in_background: true` and the command `nohup sh -c '<start_command>' > "<run_dir>/app.log" 2>&1`. Do not add a
   trailing `&`: a command with the `&` operator needs interactive approval and is refused when nobody can answer.
   Note that you started it.
3. Wait up to 120 s.
   - URL check, with no `sleep`: `curl -fsS -o /dev/null --max-time 5 --retry 60 --retry-delay 2 --retry-max-time 120 --retry-all-errors "<ready_check>"`.
   - Command check: `for i in $(seq 1 60); do <ready_check> && break; [ "$SECONDS" -ge 120 ] && break; sleep 2; done`,
     then run `<ready_check>` once more to get the final status. The loop bounds total elapsed time with
     `$SECONDS` (at most 120 s); the time of a single attempt is not limited (macOS has no `timeout`).
4. A timeout means STATUS `blocked`, with the message
   `App not ready after 120 s: <ready_check> (started with <start_command>). Last lines of <run_dir>/app.log:`
   followed by the output of `tail -n 20 "<run_dir>/app.log"`.
5. Stop only an instance you started, by the port of `base_url` (80 or 443 if it has none), in two plain calls:
   `lsof -ti tcp:<port> -sTCP:LISTEN` prints the pid, then `kill <pid>`. Confirm with
   `lsof -ti tcp:<port> -sTCP:LISTEN` again: it prints nothing. Never kill a process you did not start.

## 4. Playwright config and viewports

The template. Substitute the config values named in the comments:

```ts
// Written by aew QA (skill aew:ui-qa). One project per ui.viewports entry.
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',            // ui.e2e_dir, relative to this file ('.' in tests/e2e/)
  testMatch: '**/*.spec.ts',
  retries: 0,
  reporter: [['list'], ['json', { outputFile: 'test-results/results.json' }]],
  use: { baseURL: 'http://localhost:4173' },   // app.base_url
  projects: [                                   // ui.viewports, in order, named after them
    { name: 'desktop', use: { viewport: { width: 1440, height: 900 } } },
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
  ],
});
```

Rules: no `webServer` block (§3 starts the app, and the MCP checks need it too). No retries: a flaky test is a
`test_bug` to report, not to hide. The mobile project is viewport-only, without device emulation. No `html`
reporter (it can open a browser).

## 5. Writing specs

- Location and names: `<e2e_dir>/<issue>-<slug>.spec.ts`, one file per issue (the slug is the run-protocol
  slug). `.spec.ts` keeps them out of `node --test` and similar unit globs. Import `test` and `expect` from
  `./aew`, never from `@playwright/test` directly, so evidence capture is automatic.
- Titles: `TC-<n>: <behaviour>`, one test per TC (the evidence name comes from the title).
- Locators, in this order: `getByRole` (with `name`), `getByLabel`, `getByText`, then `getByTestId`. CSS or
  XPath only when nothing else can work, with a comment saying why.
- Waiting: `page.waitForTimeout` and any fixed sleep are banned. So is `networkidle`. Use web-first assertions
  (`await expect(locator).toHaveText(…)`, `toBeVisible`, `toHaveCount`) and auto-waiting actions only.
- Page objects only when more than three tests share a page: `<e2e_dir>/pages/<page>.ts`.
- Test data: create what the test needs inside the test, or use `commands.seed` when the plan names seed data.
  Never rely on existing data the brief and plan don't mention.
- Viewport-specific TCs: when the test plan lists a TC for one viewport only, skip it elsewhere with a reason
  (`test.skip(test.info().project.name !== 'mobile', 'TC-4 is mobile-only in the test plan')`). That is not a
  UI-done violation. Any other skip, `fixme` or `only` is.

Example (a newsletter form):

```ts
import { test, expect, axeScan } from './aew';

test('TC-1: a visitor can subscribe', async ({ page }) => {
  await page.goto('/');
  await page.getByLabel('Email').fill('reader@example.com');
  await page.getByRole('button', { name: 'Subscribe' }).click();
  await expect(page.getByRole('status')).toHaveText(/Thanks/);
});

test('TC-2: the home page has no serious or critical axe violations', async ({ page }) => {
  await page.goto('/');
  await axeScan(page);
});
```

## 6. Screenshots

The evidence half of `<e2e_dir>/aew.ts`:

```ts
// Written by aew QA (skill aew:ui-qa). Specs import test and expect from here.
import { test as base, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mkdirSync, writeFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';

const QUALITY = 80;               // evidence.quality
const AXE_STANDARD = 'wcag22aa';  // ui.axe_standard

// After every test, pass or fail: one JPEG per TC per viewport, written only when
// AEW_EVIDENCE_DIR is set (<evidence.dir>/<issue>/screenshots) and the spec file
// belongs to that issue (<issue>-<slug>.spec.ts), so other runs never touch evidence.
export const test = base.extend<{ aewEvidence: void }>({
  aewEvidence: [async ({ page }, use, testInfo) => {
    await use();
    const dir = process.env.AEW_EVIDENCE_DIR;
    const tc = /^(TC-\d+):/.exec(testInfo.title)?.[1];
    if (!dir || !tc || testInfo.status === 'skipped' || page.isClosed()) return;
    if (!basename(testInfo.file).startsWith(`${basename(dirname(dir))}-`)) return;
    mkdirSync(dir, { recursive: true });
    await page.screenshot({
      path: join(dir, `${tc}-${testInfo.project.name}.jpg`),
      type: 'jpeg',
      quality: QUALITY,
      fullPage: !testInfo.tags.includes('@viewport-only'),
    });
  }, { auto: true }],
});
export { expect };
```

The capture is at the test's final state, after its assertions, so a failing test still leaves evidence showing
the defect. A skipped test (a viewport-specific TC in another project, §5) captures nothing. Screenshots are
full-page by default. Tag a test `{ tag: '@viewport-only' }` when its state is a viewport-sized overlay (a
modal, a sticky bar). The viewport name in the file is the project name. QA writes `QUALITY` and `AXE_STANDARD`
from config and updates them if config changes.

## 7. Accessibility scan

The rest of `aew.ts`:

```ts
// ui.axe_standard is a conformance target: a WCAG level expands to every axe tag up
// to and including it (axe's wcag22aa tag alone marks only the rules new in 2.2).
const CUMULATIVE: Record<string, string[]> = {
  wcag2a: ['wcag2a'],
  wcag2aa: ['wcag2a', 'wcag2aa'],
  wcag21a: ['wcag2a', 'wcag21a'],
  wcag21aa: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'],
  wcag22aa: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'],
};

// Scans the current page. Fails on serious or critical violations; keeps every
// violation (all impacts) in test-results for the QA report.
export async function axeScan(page: Page) {
  const testInfo = test.info();
  const tags = CUMULATIVE[AXE_STANDARD] ?? [AXE_STANDARD];
  const { violations } = await new AxeBuilder({ page }).withTags(tags).analyze();
  const tc = /^(TC-\d+):/.exec(testInfo.title)?.[1] ?? 'page';
  const file = testInfo.outputPath(`axe-${tc}-${testInfo.project.name}.json`);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify({ url: page.url(), tags, violations }, null, 2));
  const blocking = violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
  expect(blocking.map((v) => `${v.id} (${v.impact}): ${v.nodes.length} node(s)`),
    'serious or critical axe violations').toEqual([]);
}
```

A WCAG level expands to the cumulative tags. For example, `wcag22aa` is
`wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`, and the table above gives the other levels. Any other value,
such as `best-practice` or `wcag2aaa`, is passed through as a single tag.

There is one axe TC per changed page, titled `TC-<n>: <page> has no serious or critical axe violations`, and it
runs in every viewport project. `serious` or `critical` fails the test. `moderate` and `minor` are reported, not
failed. After the run, `find test-results -name 'axe-*.json'` gives the raw files. The report's
`## Accessibility` table has one row per page (counts by impact, summed over viewports, raw files in Notes).
Read them before the next Playwright run, because it clears `test-results/`.

## 8. Running the suite

Run from the Playwright package dir (the dir holding `playwright.config.ts`). If `commands.test_e2e` changes
directory itself, run it from the project root instead.

- QA evidence run (phase B, every cycle): `rm -rf "<abs root>/<evidence.dir>/<issue>/screenshots"`, then
  `AEW_EVIDENCE_DIR="<abs root>/<evidence.dir>/<issue>/screenshots" <commands.test_e2e>`. The removal is what
  makes each cycle overwrite same-named files and drop stale ones (§10). The path is absolute, so a nested
  `tests/e2e/` package writes to the right place.
- A non-zero exit means test failures, not a QA failure: read the results and report them.
- Results per test and viewport:
  `jq -r '.. | objects | select(has("specs")) | .specs[] | .title as $t | .tests[] | "\($t)\t\(.projectName)\t\(.results[-1].status // "none")"' test-results/results.json`.
  `skipped`, `none` (not run) and unexpected statuses count as not passed for the UI-done rule.
- Verify each expected screenshot (UI TCs × planned viewports) exists and is a JPEG: `file -b <path>` starts
  with `JPEG image data`.
- Developer, fix mode: run only the failing specs (`npx playwright test <spec file> -g "TC-<n>:"`),
  **without** `AEW_EVIDENCE_DIR`, after §3. Never edit QA's specs.

## 9. Exploratory checks (Playwright MCP)

If no `mcp__plugin_aew_playwright__*` tool is present in the session (server failed, offline, no Chrome), do
not return `blocked` and do not skip silently. Write "Exploratory checks not run: Playwright MCP unavailable"
in `## Commands and output` and at the start of SUMMARY, then carry on with the scripted Playwright and axe
gate.

Otherwise, for each changed page and each viewport, with the app running (§3):

1. `mcp__plugin_aew_playwright__browser_resize` to the viewport's width and height, then
   `mcp__plugin_aew_playwright__browser_navigate` to `<base_url><path>`.
2. Layout: `mcp__plugin_aew_playwright__browser_snapshot` with `boxes: true`. A box extending past the
   viewport width (horizontal overflow), overlapping interactive boxes, or content clipped off-screen is a
   layout break.
3. Focus order and keyboard traps: `mcp__plugin_aew_playwright__browser_press_key` `Tab` repeatedly, reading
   the focused element from each result or snapshot (the focused element's line is marked `[active]`). Order
   must follow the visual and reading order. If focus stays on one element or cycles within a component, try
   `Shift+Tab` and `Escape`. Still stuck means a keyboard trap.
4. Console: `mcp__plugin_aew_playwright__browser_console_messages` with `level: "error"` after each page. Each
   error is a finding.
5. Interactions the ACs name: `mcp__plugin_aew_playwright__browser_click`,
   `mcp__plugin_aew_playwright__browser_type`, `mcp__plugin_aew_playwright__browser_select_option`,
   `mcp__plugin_aew_playwright__browser_hover`. Use `mcp__plugin_aew_playwright__browser_wait_for` only with
   `text` or `textGone`, never `time`.
6. `mcp__plugin_aew_playwright__browser_close` when done.

Recording: one bullet per page and viewport in `## Commands and output`:
`- MCP <page> @ <viewport>: <finding | no issues>`, with no new heading. A finding that breaks an AC, or is a
WCAG A/AA failure (keyboard trap, broken focus order), is also a `## Failures` entry with a triage class.
Everything else is an observation only. The MCP never writes evidence: screenshots come only from §6. The
server writes page snapshots to `.playwright-mcp/` in the project cwd, which §2 gitignores.

## 10. Evidence rules

- Paths: `<evidence.dir>/<issue>/report.md` and `<evidence.dir>/<issue>/screenshots/<TC>-<viewport>.jpg`
  (`docs/qa/…` by default).
- Specs write screenshots only when `AEW_EVIDENCE_DIR` is set. Only QA sets it, so developers, humans and later
  regression runs never change committed evidence.
- Each cycle clears the screenshots dir before its run (§8), so same-named files are overwritten and
  screenshots the cycle did not produce are deleted.
- `report.md` (a `cp` of the passing `08-qa-report-<n>.md`; a subagent's Write of a file named `report.md` is refused) is written only for a passing cycle. If the last
  allowed fix cycle fails, the committed screenshots are a failing cycle's and there is no `report.md`: the
  report says the evidence is not final, and the orchestrator must not present it as final.
- Evidence is committed on the feature branch (`git add` of the evidence dir also stages deletions), and squash
  merges carry only the final evidence into the default branch.
- JPEG at `evidence.quality`, viewport from the project name, TC from the title.
- The report's `## Screenshots` table lists every file §8 verified, one row per TC and viewport, by
  repo-relative path.
- The `## Accessibility` table follows §7: one row per changed page, counts summed over viewports.

## 11. Manual-test handoff

Write `<run_dir>/manual-tests.md` from `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/manual-tests.md`. Keep its
heading and drop every HTML comment, the leading one included: the orchestrator inserts the file verbatim into the
issue body. There is one checkbox line per manual-only TC, in the template's format:
`- [ ] **TC-<n> (AC-<n>):** <steps> → <expected>. _Why manual:_ <reason>.` Only the cases phase A classed
manual-only, with the reason it gave, go here. An automatable case is never moved here: that breaks the UI-done
rule. If there are no manual cases, don't write the file. The orchestrator posts it, and the doc-writer lists it
in the PR.
