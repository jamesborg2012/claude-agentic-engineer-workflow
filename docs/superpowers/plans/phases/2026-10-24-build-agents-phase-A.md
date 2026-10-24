# Phase A plan — Playwright integration and the ui-qa skill

- **Spec:** `docs/superpowers/specs/2026-10-24-build-agents.md` (hash `3507d614…c9c7`)
- **Phase:** A of the EPIC. `depends_on: []`. Phase C consumes the tool names, the ui-qa contract and the README section; Phase D consumes ui-qa §3 and §8 (developer fix mode); Phase B is told which target-project files QA will create; Phase E appends to the README section and writes the CHANGELOG and project-map entries.
- **Depth:** full
- **ACs covered:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-15 (the `config.schema.json` `ui.axe_standard` description bullet and the "full script suite still passes" clause only; the template and run-protocol bullets are Phase C's)
- **Risk:** new runtime dependency. The bundled `@playwright/mcp` server starts in every session where aew is enabled. Task A1 is RISKY and has an explicit rollback.
- **Date:** 2026-10-24
- **Naming note:** "Assumption n" means the spec's assumption n. Task ids here are `A1`–`A4` and are unrelated to those numbers. Smoke ids: `940` is this phase's MCP probe (a plain session, no run dir and no `state.json`); `941`–`972` belong to Phases C–E.

> **For agentic workers:** implement task by task. Every task records its RED evidence before the change and its GREEN evidence after. A1, A2 and A4 are config and documentation tasks, so their RED is a check that fails before the change. A3's RED is the Assumption 5 demonstration in its snippet check.

**Goal:** bundle a pinned Playwright MCP server, verify its real tool names in a headless session and record them, write the `ui-qa` skill that QA (preloaded) and the developer's fix mode (through the Skill tool) follow, and fix the `ui.axe_standard` schema description so the default `wcag22aa` means a cumulative target.

**Architecture:** one new root file (`.mcp.json`, auto-discovered, no `plugin.json` change), one new internal skill (`skills/ui-qa/SKILL.md`, a single file per Assumption 25), a one-string schema edit, and additions to DESIGN §3/§4 and the smoke README. No scripts, hooks or agents change in this phase. The skill's three code templates are proven in a free, local scratch project before commit (no Claude spend); the only paid step is the A2 probe (Haiku, cap $1).

**Tech stack:** `@playwright/mcp@0.0.83` (its own bundled `playwright` is `1.64.0-alpha-1790635538000`, checked with `npm view @playwright/mcp@0.0.83 dependencies`), `@playwright/test@1.64.1`, `@axe-core/playwright@4.14.0`, `serve@14.2.6` (scratch only), Node ≥ 20, jq 1.7.1, `claude` CLI headless (`-p`, `stream-json`).

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/specs/2026-10-24-build-agents.md` | AC-1–5, AC-15; Assumptions 1–8, 17, 19, 25; facts F1, F2, F7, F8; DESIGN changes 1–2; spec-review notes on the browser channel |
| `docs/DESIGN.md` §3 (Namespacing, "context7 tool names" bullet at line ~38), §4 (Playwright row, line ~69; CLI prerequisites, line ~72), §6/§6.1 (`docs/qa/<issue>/`, `ui.*`, `app.*`, `evidence.*`), §8.6 | The rows and bullets this phase edits, and the rules ui-qa encodes |
| `templates/config.schema.json` (`ui` at line ~115, `axe_standard` at line ~153, `app` at line ~66, `evidence` at line ~231) | Defaults the skill lists; the description A4 rewrites |
| `templates/artefacts/qa-report.md`, `qa-test-plan.md`, `manual-tests.md` | Section names the skill's evidence, axe and handoff rules point at (unchanged here) |
| `skills/stack-standards/SKILL.md` (lines 1–30) | Internal-skill frontmatter and numbered-section style to mirror |
| `tests/agent-smoke/README.md` §1–§3 | Harness conventions (`$SMOKE` outside the repo, `--settings` `enabledPlugins`, `--debug-file`, spend ledger, after-run `git status`) that the A2 probe reuses |
| `@playwright/mcp@0.0.83` README (`npm view @playwright/mcp@0.0.83 readme`; 0.0.83 is `latest`) | CLI options (`--headless`, `--isolated`, `--browser` values `chrome, firefox, webkit, msedge`, default Chrome channel) and the core tool list (`browser_navigate`, `browser_snapshot` with `boxes`, `browser_click`, `browser_type`, `browser_press_key`, `browser_select_option`, `browser_hover`, `browser_resize`, `browser_console_messages`, `browser_wait_for`, `browser_close`, …). The "Browser installation" group is empty in 0.0.83 (no install tool) |

Gotchas that apply (from `docs/superpowers/project-map.md`): temp projects for headless runs must live under `$SMOKE` (`${TMPDIR%/}/aew-smoke`), never inside the plugin tree; `enabledPlugins` may disable only `dev-workflow` and `figma` (disabling `frontend-design` stops aew loading); in zsh run `setopt interactivecomments` first and quote separators; `${CLAUDE_PLUGIN_ROOT}` is substituted in skill Markdown but is not in the Bash environment; macOS `/var` is a symlink to `/private/var`.

## Interface contract (Phases B, C, D and E rely on this)

### C-1. MCP server and tool names

- `.mcp.json` (A1) declares exactly one server, key `playwright`, wrapper form:
  ```json
  {
    "mcpServers": {
      "playwright": {
        "command": "npx",
        "args": ["--yes", "@playwright/mcp@0.0.83", "--headless", "--isolated"]
      }
    }
  }
  ```
  A2 may append `"--browser", "<value>"` only under its Step 5 fallback; nothing else changes.
- Tool prefix: `mcp__plugin_aew_playwright__`. The init `mcp_servers` entry is expected as `plugin:aew:playwright` (by analogy with `plugin:context7:context7`; A2 records the real value).
- **The qa-engineer's Playwright tools (Assumption 2), expected names, to be confirmed or replaced by A2's recorded list:**
  ```
  mcp__plugin_aew_playwright__browser_navigate
  mcp__plugin_aew_playwright__browser_snapshot
  mcp__plugin_aew_playwright__browser_click
  mcp__plugin_aew_playwright__browser_type
  mcp__plugin_aew_playwright__browser_press_key
  mcp__plugin_aew_playwright__browser_select_option
  mcp__plugin_aew_playwright__browser_hover
  mcp__plugin_aew_playwright__browser_resize
  mcp__plugin_aew_playwright__browser_console_messages
  mcp__plugin_aew_playwright__browser_wait_for
  mcp__plugin_aew_playwright__browser_close
  ```
  The authoritative list is the code block "qa-engineer Playwright tools" that A2 writes in `tests/agent-smoke/README.md` §8.2. Phase C copies it **verbatim** into `agents/qa-engineer.md` `tools:` (exact names, no wildcard) and into the QA `ALLOW` line. `browser_take_screenshot` and `browser_evaluate` are deliberately excluded (decision 3 below); `browser_evaluate` is added only if A2 Step 5c triggers.
- Where the facts live: README §8.2 (full init list verbatim, the server entry and status, the browser outcome, files written to cwd, the focus marker); DESIGN §3 bullet "Playwright MCP tool names"; DESIGN §4 Playwright row.

### C-2. `skills/ui-qa/SKILL.md` section contract

Frontmatter: `name: ui-qa`, `description: …`, `user-invocable: false` (no `disable-model-invocation`). Preload name: `aew:ui-qa`. Sections, numbered and in this order. Phases C and D may cite them by number and title:

| § | Title | Used by |
|---|---|---|
| 1 | Config it reads | QA, developer |
| 2 | Setting up Playwright | QA (phase B, when the project has none) |
| 3 | Starting and stopping the app | QA; developer fix mode |
| 4 | Playwright config and viewports | QA |
| 5 | Writing specs | QA |
| 6 | Screenshots | QA |
| 7 | Accessibility scan | QA |
| 8 | Running the suite | QA; developer fix mode (failing specs only, no `AEW_EVIDENCE_DIR`) |
| 9 | Exploratory checks (Playwright MCP) | QA |
| 10 | Evidence rules | QA, doc-writer (paths) |
| 11 | Manual-test handoff | QA |

### C-3. Files QA creates in a target project (Phase B's fixture must not pre-empt or contradict these)

| File | Content |
|---|---|
| `playwright.config.ts` in the Playwright package dir (repo root for JS projects, `tests/e2e/` for PHP and .NET) | Template in A3 §4: `testDir` = `ui.e2e_dir` relative to the file, `testMatch: '**/*.spec.ts'`, `retries: 0`, `list` plus `json` reporters (`test-results/results.json`), `baseURL` = `app.base_url`, one project per `ui.viewports` entry |
| `<e2e_dir>/aew.ts` | The shared helper (A3 §6/§7 template): the auto evidence fixture and `axeScan()` |
| `<e2e_dir>/<issue>-<slug>.spec.ts` | One spec file per issue; every test title starts `TC-<n>: ` |
| `.gitignore` additions | `test-results/`, `playwright-report/`, `node_modules/` if absent, and `.playwright-mcp/` only if A2 observes the server writing it |

- Specs are `*.spec.ts`, so Node's default `node --test` globs (`*.test.*`, `test/` dirs) never pick them up. Phase B's unit test (`tests/unit/basket.test.js`) and `test_unit: node --test` are unaffected. The fixture needs no `tsconfig.json`; Playwright transpiles TypeScript itself.
- Evidence capture env: `AEW_EVIDENCE_DIR=<absolute project root>/<evidence.dir>/<issue>/screenshots`. The fixture captures only for spec files whose name starts with `<issue>-`, where `<issue>` is the name of `AEW_EVIDENCE_DIR`'s parent dir. This stops an older issue's `TC-1` from overwriting the current issue's `TC-1` when the whole regression suite runs.
- Raw axe results: `test-results/**/axe-<TC>-<viewport>.json` (`{url, tags, violations}`, all impacts), for the report's `## Accessibility` table.
- App log: `<run_dir>/app.log` (the run dir is gitignored).

### C-4. Bash families the skill tells QA (and the developer in fix mode) to run

Phase C's Guardrails allowlist and its `ALLOW` line must cover these (Assumption 17 already lists most of them; **new here:** `nohup`, `sh -c`, `rm -rf <evidence screenshots dir>`, `mkdir -p`, `file`):
`curl` (ready check), `nohup sh -c '<start_command>' > <run_dir>/app.log 2>&1 &`, `lsof -ti tcp:<port> -sTCP:LISTEN`, `kill <pid>`, `tail -n 20 <run_dir>/app.log`, `npx playwright test …`, `npx playwright install chromium`, the package-manager install in §2, `rm -rf "<abs evidence screenshots dir>"`, `mkdir -p`, `file -b <jpg>`, `jq` over `test-results/results.json`, `find test-results -name 'axe-*.json'`.

### C-5. Report placement rules ui-qa fixes (Phase C's prompt follows them; no template change beyond Phase C's AC-15 bullets)

- Exploratory findings go in `08-qa-report-<n>.md` `## Commands and output` as bullet lines `- MCP <page> @ <viewport>: <finding | no issues>`, with no new heading. A finding that breaks an AC, or is a WCAG A/AA failure (keyboard trap, broken focus order), is also a `## Failures` entry with a triage class (Assumption 19). Anything else is an observation only.
- axe: one `## Accessibility` row per changed page, counts summed over viewports, raw files named in Notes.

### C-6. README §8 skeleton (A2 creates it; Phases C and E append)

A2 appends `## 8. Build agents (prompt 04)` after `## 7. Notes`, containing `### 8.1 Spend ledger (prompt 04, stop at $60)` (columns as the prompt-03 ledger; first row is probe 940) and `### 8.2 Playwright MCP tool names (AC-2, probe 940)`. Phases C and E add `### 8.3 …` onwards (setup, invocation, checks and results for 941–972) and append ledger rows. **Consolidator: reconcile this numbering with C and E.**

### C-7. DESIGN sections touched here (the others stay with their phases)

§3 (one new bullet) and §4 (Playwright row, one prerequisites bullet). **Not here:** §3 F3/F4 (Phase D), F6/nested `SubagentStop` (Phase D/E), §7.3 and §8.6, including the sentence "axe_standard expands to cumulative tags, see `ui-qa` §7" (Phase C), §8.5 (D) and §8.7 (E).

## Tasks

Waves: **1** = A1 ∥ A4 · **2** = A2 · **3** = A3. A4 shares no file with the others, so it can run in any wave.

---

### Task A1 — Bundle the pinned Playwright MCP server (Assumption 1)

- **id:** A1
- **files:** `.mcp.json` (new), `docs/DESIGN.md` (§4 Playwright row; one new §4 bullet)
- **depends_on:** []
- **pattern:** the official `external_plugins/playwright/.mcp.json` (`{"playwright":{"command":"npx","args":["@playwright/mcp@latest"]}}`), changed to the `mcpServers` wrapper form (F1), an exact version and the two flags. For the DESIGN row, follow the existing §4 table and the bullet style of "Why superpowers has no version range".
- **ACs:** AC-1
- **Risk:** **RISKY.** New runtime dependency: every session with aew enabled starts `npx @playwright/mcp@0.0.83` (the first run downloads the package; the server is one Node process per session).
- **Rollback:** `git revert` of this task's commit removes `.mcp.json` and restores the §4 row. No other file depends on it until Phase C. After a revert, QA's Playwright tools would be absent, and its `tools:` entries would take no tool (debug-log warning only, as with context7).

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
jq -e '.mcpServers.playwright.args == ["--yes","@playwright/mcp@0.0.83","--headless","--isolated"]' .mcp.json
```

Expected: `jq: error: Could not open file .mcp.json: No such file or directory`, exit 2.

**Step 2: write `.mcp.json`** with exactly the JSON in contract C-1, two-space indented, with a trailing newline.

**Step 3: DESIGN §4.** Replace the Playwright row with:

```
| Playwright MCP | plugin `.mcp.json`: `npx --yes @playwright/mcp@0.0.83 --headless --isolated` (exact version) | Exploratory UI checks by QA (§8.6). `claude-plugins-official` ships a `playwright` plugin (by Microsoft), but it is only an unpinned `npx @playwright/mcp@latest` `.mcp.json` with no skill, so it covers neither §8.6 (that is the `ui-qa` skill) nor the pinning rule. aew bundles its own pinned server instead (decided 24 Oct 2026). `--headless` because QA runs unattended; `--isolated` so no browser profile or login state persists between runs. If the official plugin is also enabled, both servers run under different tool prefixes. |
```

After the superpowers bullet, add:

```
- **Playwright packages.** Plugin MCP servers start with the plugin, so every session with aew enabled runs one `npx @playwright/mcp` process (the first run downloads it). The test packages are not in the plugin: `ui-qa` setup exact-pins `@playwright/test@1.64.1` and `@axe-core/playwright@4.14.0` in the target project and installs Chromium with `npx playwright install chromium`.
```

**Step 4: GREEN.**

```sh
jq -e '.mcpServers | keys == ["playwright"]' .mcp.json                     # true
jq -e '.mcpServers.playwright.command == "npx" and .mcpServers.playwright.args == ["--yes","@playwright/mcp@0.0.83","--headless","--isolated"]' .mcp.json   # true
grep -c '@latest\|\^\|~' .mcp.json                                         # 0
claude plugin validate .                                                   # passes, as before
npx --yes @playwright/mcp@0.0.83 --help | grep -E -- '--headless|--isolated'   # both options listed (also warms the npx cache for A2)
```

Record the `claude plugin validate .` output line and the two `--help` lines in the task report.

**Step 5: commit.**

```
feat(mcp): bundle a pinned Playwright MCP server for QA

Adds .mcp.json with one server, playwright, run as
npx --yes @playwright/mcp@0.0.83 --headless --isolated. The official
claude-plugins-official playwright plugin is an unpinned @latest config with
no skill, so it covers neither DESIGN section 8.6 nor the pinning rule; DESIGN
section 4 records the decision and that the test packages are pinned in the
target project instead.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task A2 — Verify and record the real tool names, the browser and the focus marker (probe 940)

- **id:** A2
- **files:** `tests/agent-smoke/README.md` (new `## 8` section, contract C-6), `docs/DESIGN.md` (§3 new bullet; §4 one sentence on the browser), `.mcp.json` (**only** under the Step 5a fallback)
- **depends_on:** [A1]
- **pattern:** README §2–§4 (temp dir under `$SMOKE`, `--settings` with `enabledPlugins`, `--debug-file`, stream extraction with `jq`, spend ledger, after-run `git -C "$REPO" status --porcelain`); the DESIGN §3 "context7 tool names" bullet for wording.
- **ACs:** AC-2 (and the AC-1 browser half of Assumption 3)
- **Risk:** NOT RISKY (paid but capped at $1, one 2x raise to $2). It becomes RISKY only if Step 5a edits `.mcp.json`; A1's rollback then covers it.

One headless session records the init tool list **and** exercises the browser, so a single cheap run settles Assumption 2, Assumption 3, whether the server writes files into the project, and how focus shows in a snapshot (the exploratory focus-order check in A3 §9 depends on it).

**Step 1: RED.** `grep -c 'mcp__plugin_aew_playwright__' tests/agent-smoke/README.md docs/DESIGN.md` gives `0` for both files.

**Step 2: run the probe** (bash or zsh, from the repo):

```sh
setopt interactivecomments 2>/dev/null || true
REPO=$(git rev-parse --show-toplevel)
SMOKE="${TMPDIR:-/tmp}"; SMOKE="${SMOKE%/}/aew-smoke"; mkdir -p "$SMOKE"
PROBE="$SMOKE/probe-playwright"; O="$SMOKE/out-940"
rm -rf "$PROBE" "$O" && mkdir -p "$PROBE" "$O"
git -C "$PROBE" init -q && git -C "$PROBE" commit -q --allow-empty -m probe
claude --version > "$O/claude-version.txt"
URL='data:text/html,<title>aew-probe</title><button>One</button><button>Two</button>'
T=mcp__plugin_aew_playwright__browser
cd "$PROBE" && claude --plugin-dir "$REPO" -p "Use only the Playwright MCP tools, in this order: 1) browser_navigate to $URL 2) browser_press_key Tab 3) browser_snapshot 4) browser_console_messages with level error 5) browser_close. Then print four lines: TITLE: the page title; FOCUS: the snapshot line for the button that has focus, verbatim; CONSOLE: the console errors, or none; ERRORS: the exact text of any failed tool call, or none." \
  --model haiku --output-format stream-json --verbose --max-budget-usd 1 --debug-file "$O/debug.log" \
  --settings '{"enabledPlugins":{"dev-workflow@jamesborg":false,"figma@claude-plugins-official":false}}' \
  --allowedTools "${T}_navigate" "${T}_press_key" "${T}_snapshot" "${T}_console_messages" "${T}_close" \
  > "$O/stream.jsonl"
cd "$REPO"
```

The probe dir is outside the repo, so the repo's `CLAUDE.md` is not an ancestor and no `claudeMdExcludes` is needed.

**Step 3: checks** (record every output in the README §8.2 table):

```sh
S='select(.type=="system" and .subtype=="init")'
jq -r "$S | .mcp_servers[] | select(.name|test(\"playwright\")) | \"\(.name) \(.status)\"" "$O/stream.jsonl"
#   expect: plugin:aew:playwright connected
jq -r "$S | .tools[] | select(startswith(\"mcp__plugin_aew_playwright__\"))" "$O/stream.jsonl" | LC_ALL=C sort > "$O/playwright-tools.txt"
wc -l < "$O/playwright-tools.txt"
#   expect: >= 11 (the 0.0.83 README lists 24 core tools plus browser_tabs)
for t in navigate snapshot click type press_key select_option hover resize console_messages wait_for close; do
  grep -qx "mcp__plugin_aew_playwright__browser_$t" "$O/playwright-tools.txt" || echo "MISSING browser_$t"
done
#   expect: no output
jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | "\(.is_error // false) \(.content|tostring|.[0:160])"' "$O/stream.jsonl"
#   expect: five lines, each starting "false"
jq -r 'select(.type=="result") | .result' "$O/stream.jsonl"
#   expect: TITLE: aew-probe; a FOCUS line for button "One" carrying a focus marker (expected "[active]"); CONSOLE: none; ERRORS: none
jq -r 'select(.type=="result") | .total_cost_usd' "$O/stream.jsonl"
git -C "$PROBE" status --porcelain --untracked-files=all
#   expect: empty. Anything (for example .playwright-mcp/) means the server writes into the project cwd
git -C "$REPO" status --porcelain
#   expect: only this task's intended edits. Anything else means the server's cwd is the plugin root: revert it and record it
grep -i 'playwright' "$O/debug.log" | head -20
```

**Step 4: GREEN (the normal path).** The server is connected, all eleven names are present, the five tool results have no errors, and the title is `aew-probe`. Then:

1. **README:** append contract C-6's `## 8. Build agents (prompt 04)` with:
   - `### 8.1 Spend ledger (prompt 04, stop at $60)`: the prompt-03 ledger columns; row `940 Playwright MCP probe (haiku) | 940 | <cost> | <cost> | no`; one sentence on the caps (Assumption 27: $5 per run, $8 for QA phase B, $10 fan-out, $2 gate checks, one 2x raise, stop at $60).
   - `### 8.2 Playwright MCP tool names (AC-2, probe 940)`: the Step 2 commands and the Step 3 checks (copy-paste ready); the `claude --version`; a check | result | notes table (server entry and status; the count; all eleven present; the tool results; the title, focus and console lines; cwd files; repo `git status`); the full init list verbatim in a code block titled "Full `mcp__plugin_aew_playwright__*` list (init, 0.0.83)"; and a second code block, under a line reading **qa-engineer Playwright tools**, holding exactly the eleven names one per line between plain ```` ``` ```` fences (no language tag, so A3's `awk` extraction works); this is the list Phase C copies verbatim. No transcripts.
2. **DESIGN §3:** after the "context7 tool names" bullet, add:
   ```
   - **Playwright MCP tool names.** aew's bundled server is `playwright`, so its tools are `mcp__plugin_aew_playwright__<tool>` (for example `mcp__plugin_aew_playwright__browser_navigate`), and the init `mcp_servers` entry is `<recorded name>`. Confirmed from the `system/init` event of a headless `--plugin-dir` session on 24 Oct 2026; the full list is in `tests/agent-smoke/README.md` §8.2. Agent `tools` accepts full MCP tool names. A server wildcard (`mcp__<server>__*`) is documented, but the plugin-prefixed wildcard is not shown, so qa-engineer lists exact names. An omitted `tools` inherits every tool, MCP included.
   ```
3. **DESIGN §4:** append to the Playwright row's Use cell: `The server drives the MCP's default browser channel, the installed Google Chrome (verified 24 Oct 2026).` (Or, under 5a, the fallback wording.)

**Step 5: fallbacks** (each is recorded in README §8.2 and, where it changes behaviour, in DESIGN §4; re-run the probe after any change, as a new ledger row):

- **5a. Browser unavailable** (a tool result says the Chrome distribution or executable is not found). Apply Assumption 3, following the spec-review note that the browser build belongs to the MCP's own bundled Playwright: add `"--browser", "chromium"` to the `.mcp.json` args (the 0.0.83 Docker example uses `--browser chromium`; its options table lists only `chrome, firefox, webkit, msedge`, so if `chromium` is rejected, record that and use the browser the error message suggests), and install with the exact bundled version: `npx --yes playwright@1.64.0-alpha-1790635538000 install chromium` (version from `npm view @playwright/mcp@0.0.83 dependencies.playwright`). DESIGN §4 then records the flag and the install step instead of the Chrome sentence, and A3 §2 adds the step as a prerequisite. The task becomes RISKY (contract change to `.mcp.json`).
- **5b. Server not connected** (status `pending` or `failed`, or no aew names). Re-run once with `MCP_TIMEOUT=60000` in front of `claude`. If it is still not connected, stop: return BLOCKED with the debug-log lines, because A3 and Phase C cannot name the tools.
- **5c. No focus marker in the snapshot.** Record the snapshot excerpt. If focus can't be read from `browser_snapshot` or the `browser_press_key` result, add `mcp__plugin_aew_playwright__browser_evaluate` to the "qa-engineer Playwright tools" block (for `document.activeElement` only), and A3 §9 says so. Record it as a refinement of Assumption 2.
- **5d. Files written into the probe cwd** (for example `.playwright-mcp/`). Record the path. A3 §2 adds it to the gitignore list, and contract C-3 already reserves it. Phase B's fixture `.gitignore` adds it too (consolidator note).
- **5e. A name differs from the expected eleven** (renamed tool). Put the init list's equivalent in the qa-engineer block and note the mapping (Assumption 2 allows this).

**Step 6: hygiene.** `git -C "$REPO" status --porcelain` shows only `tests/agent-smoke/README.md`, `docs/DESIGN.md` and, under 5a, `.mcp.json`. `claude plugin validate .` still passes.

**Step 7: commit.**

```
test(agent-smoke): record the Playwright MCP tool names from a headless probe

Probe 940 ran one Haiku session with --plugin-dir, read the system/init tools
array and drove the bundled server once (navigate, Tab, snapshot, console,
close). README section 8 starts the prompt-04 ledger and lists the
mcp__plugin_aew_playwright__* names verbatim, with the eleven that
qa-engineer will list. DESIGN section 3 records the naming fact and why the
names are exact, and section 4 records the browser the server uses.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task A3 — `skills/ui-qa/SKILL.md` (Assumptions 4–8, 19)

- **id:** A3
- **files:** `skills/ui-qa/SKILL.md` (new)
- **depends_on:** [A2] (exact tool names, focus marker, browser and cwd outcomes for §2 and §9)
- **pattern:** `skills/stack-standards/SKILL.md` (internal-skill frontmatter, short intro naming the readers, `## n. Title` numbered sections, literal `"${CLAUDE_PLUGIN_ROOT}/…"` paths); `templates/artefacts/manual-tests.md` (handoff format, quoted not copied); `templates/artefacts/qa-report.md` (section names the rules point at).
- **ACs:** AC-3, AC-4, AC-5
- **Risk:** NOT RISKY (new file; read only by Phase C and D agents).
- **Size:** about 280 lines, a single file with no `references/` (Assumption 25). If the draft passes about 330 lines, tighten the prose. Don't split the templates out: preloading loads only `SKILL.md`.

**Step 1: RED (free, local): prove the Assumption 5 bug and the templates in a scratch project.** Nothing here is committed and no Claude session runs. It also leaves Chromium installed for Phase C's harness.

```sh
REPO=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
SMOKE="${TMPDIR:-/tmp}"; SMOKE="${SMOKE%/}/aew-smoke"; S="$SMOKE/uiqa-snippets"
rm -rf "$S" && mkdir -p "$S/site" "$S/tests/e2e" && cd "$S"
printf '{ "name": "uiqa-snippets", "private": true, "type": "module" }\n' > package.json
npm install --save-dev --save-exact @playwright/test@1.64.1 @axe-core/playwright@4.14.0 serve@14.2.6
npx playwright install chromium
cat > site/index.html <<'EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Snippet check</title></head>
<body><main><h1>Shop</h1><button type="button"><svg aria-hidden="true" width="16" height="16"></svg></button></main></body></html>
EOF
```

Write `playwright.config.ts` (the §4 template: `testDir: './tests/e2e'`, `baseURL: 'http://localhost:4174'`, the two default viewports), `tests/e2e/aew.ts` (the §6/§7 template with `QUALITY = 80`, `AXE_STANDARD = 'wcag22aa'`), `tests/e2e/1-snippet.spec.ts` (`TC-1: the home page shows the heading`, asserting the `h1` with `getByRole('heading', { name: 'Shop' })`; `TC-2: the home page has no serious or critical axe violations`, calling `axeScan(page)`), and `tests/e2e/2-other.spec.ts` (`TC-1: another issue's test`, asserting the heading). Start the app with §3's commands (`nohup sh -c 'npx serve -l 4174 site' > app.log 2>&1 &`, then the §3 `curl` wait).

RED: in `aew.ts`, temporarily replace the cumulative lookup with `const tags = [AXE_STANDARD];` (the literal reading of today's schema description), then run `npx playwright test`. **Expected RED:** all 6 tests pass, so the icon-only button's `button-name` violation is **missed** under the `wcag22aa` tag alone. Capture the `list` reporter summary (`6 passed`).

**Step 2: write `skills/ui-qa/SKILL.md`** with this content (prose in British English; code blocks verbatim except for the noted config substitutions):

Frontmatter:

```yaml
---
name: ui-qa
description: How aew QA tests UI with Playwright. Covers setting Playwright up in a project, starting the app and waiting on ready_check, one Playwright project per viewport, @playwright/test spec conventions, JPEG screenshots per TC and viewport, the @axe-core/playwright scan with cumulative WCAG tags, exploratory checks through the bundled Playwright MCP, evidence rules and the manual-test handoff. Use it when writing or running UI tests or starting the app for an aew run.
user-invocable: false
---
```

Intro (3–4 lines): preloaded into `aew:qa-engineer` for phase B. The developer invokes it with the Skill tool in fix mode and uses only §3 and §8. Placeholders `<…>` are config values (§1), and `<run_dir>` is the absolute run dir.

**§1 Config it reads.** A table of the keys with their schema defaults (the leaf default and the object-level default agree): `ui.viewports` (`desktop` 1440×900, `mobile` 390×844), `ui.axe` (`true`; `false` means skip §7 and say so in the report), `ui.axe_standard` (`wcag22aa`, see §7), `ui.e2e_dir` (`tests/e2e`), `app.base_url`, `app.start_command`, `app.ready_check` (a URL if it starts with `http://` or `https://`, otherwise a command), `app.env_type`, `app.test_accounts` (env var names only: specs read `process.env[<username_env>]`; never write a value into a spec, a report or evidence; if a needed variable is unset, phase B is blocked and the summary names the variable), `evidence.dir` (`docs/qa`), `evidence.format` (`jpeg`; any other value is unsupported in v1, so use JPEG and note it), `evidence.quality` (`80`), `commands.test_e2e` (fall back to `npx playwright test` when it is not configured), `commands.install`. All required keys and `app.*` are in `.aew/config.json`; read it with Read.

**§2 Setting up Playwright.** When to run: the project has no `@playwright/test` dependency or no `playwright.config.*`. If the project already has Playwright, keep its config and versions, add a project for each missing `ui.viewports` entry, add the `json` reporter (`test-results/results.json`) if it is missing (§8 reads it), never remove existing projects, and note any version mismatch in the report.
- The package dir: the repo root when a root `package.json` exists (JS projects); otherwise `tests/e2e/` with its own `package.json` (`{"name": "<project>-e2e", "private": true}`) and its own `playwright.config.ts` (PHP and .NET projects). In the nested case, `ui.e2e_dir` is that dir and `testDir` is `'.'`.
- Install, from the package dir, exact-pinned, using the lockfile's package manager: `pnpm add -D -E …` if there is `pnpm-lock.yaml`, `yarn add -D -E …` if there is `yarn.lock`, otherwise `npm install --save-dev --save-exact @playwright/test@1.64.1 @axe-core/playwright@4.14.0`. Then `npx playwright install chromium`.
- Gitignore (append only the missing lines): `test-results/`, `playwright-report/`, `node_modules/` (+ `.playwright-mcp/` if A2 Step 5d triggered). (+ A2 5a's browser install step as a prerequisite, if triggered.)
- Write `playwright.config.ts` (§4) and `<e2e_dir>/aew.ts` (§6/§7). The setup is committed with QA's cycle commit (the commit itself is the qa-engineer prompt's rule, Phase C).

**§3 Starting and stopping the app** (Assumption 7). `env_type: none` means there is no app to start: skip this section. Every other `env_type` (including wp-env, ddev and docker) is started by `start_command`.
1. Reuse: `curl -fsS -o /dev/null --max-time 5 "<base_url>"`. If it exits 0, an instance is already running: use it and **leave it running**.
2. Otherwise start it from the project root in the background, logging to the run dir: `nohup sh -c '<start_command>' > "<run_dir>/app.log" 2>&1 &`. Note that you started it.
3. Wait up to 120 s, with no `sleep` for a URL check: `curl -fsS -o /dev/null --max-time 5 --retry 60 --retry-delay 2 --retry-max-time 120 --retry-all-errors "<ready_check>"`. For a command check: `for i in $(seq 1 60); do <ready_check> && break; sleep 2; done`, then run `<ready_check>` once more to get the final status.
4. Timeout means STATUS `blocked`, with the message `App not ready after 120 s: <ready_check> (started with <start_command>). Last lines of <run_dir>/app.log:` followed by `tail -n 20 "<run_dir>/app.log"`.
5. Stop only an instance you started, by the port of `base_url` (80 or 443 if it has none): `kill $(lsof -ti tcp:<port> -sTCP:LISTEN)`, then confirm `lsof -ti tcp:<port> -sTCP:LISTEN` prints nothing. Never kill a process you did not start.

**§4 Playwright config and viewports** (Assumption 8). The template, verbatim apart from the config substitutions in comments:

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

Rules: no `webServer` block (§3 starts the app, and the MCP checks need it too); no retries (a flaky test is a `test_bug` to report, not to hide); the mobile project is viewport-only, without device emulation; no `html` reporter (it can open a browser).

**§5 Writing specs** (AC-3 first bullet).
- Location and names: `<e2e_dir>/<issue>-<slug>.spec.ts`, one file per issue (the slug is the run-protocol slug). `.spec.ts` keeps them out of `node --test` and similar unit globs. Import `test` and `expect` from `./aew` (the form proven in the snippet check), never from `@playwright/test` directly, so evidence capture is automatic.
- Titles: `TC-<n>: <behaviour>`, one test per TC (the evidence name comes from the title).
- Locators, in this order: `getByRole` (with `name`), `getByLabel`, `getByText`, then `getByTestId`. CSS or XPath only when nothing else can work, with a comment saying why.
- Waiting: `page.waitForTimeout` and any fixed sleep are banned. So is `networkidle`. Use web-first assertions (`await expect(locator).toHaveText(…)`, `toBeVisible`, `toHaveCount`) and auto-waiting actions only.
- Page objects only when more than three tests share a page: `<e2e_dir>/pages/<page>.ts`.
- Test data: create what the test needs inside the test, or use `commands.seed` when the plan names seed data. Never rely on existing data the brief and plan don't mention.
- Viewport-specific TCs: when the test plan lists a TC for one viewport only, skip it elsewhere with a reason (`test.skip(test.info().project.name !== 'mobile', 'TC-4 is mobile-only in the test plan')`). That is not a UI-done violation; any other skip, `fixme` or `only` is.
- A short example spec (a generic newsletter form, not the fixture: `TC-1` filling `getByLabel('Email')`, clicking `getByRole('button', { name: 'Subscribe' })`, expecting `getByRole('status')` `toHaveText(/Thanks/)`; `TC-2` calling `axeScan(page)`).

**§6 Screenshots** (Assumption 6). The evidence half of `aew.ts`, verbatim:

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

Rules in prose: the capture is at the test's final state, after its assertions, so a failing test still leaves its evidence showing the defect. A skipped test (a viewport-specific TC in another project, §5) captures nothing. Full-page by default. Tag a test `{ tag: '@viewport-only' }` when its state is a viewport-sized overlay (a modal, a sticky bar). The viewport name in the file is the project name. QA writes `QUALITY` and `AXE_STANDARD` from config and updates them if config changes.

**§7 Accessibility scan** (AC-4). The rest of `aew.ts`, verbatim:

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

Rules in prose: the mapping table as text (the AC-4 wording: a WCAG level expands to the cumulative tags; any other value, such as `best-practice` or `wcag2aaa`, is passed through as a single tag). There is one axe TC per changed page, titled `TC-<n>: <page> has no serious or critical axe violations`, and it runs in every viewport project. `serious` or `critical` fails the test; `moderate` and `minor` are reported, not failed. After the run, `find test-results -name 'axe-*.json'` gives the raw files; the report's `## Accessibility` table has one row per page (counts by impact, summed over viewports, files in Notes). Read them before the next Playwright run, because it clears `test-results/`.

**§8 Running the suite.** From the Playwright package dir:
- QA evidence run (phase B, every cycle): `rm -rf "<abs root>/<evidence.dir>/<issue>/screenshots"`, then `AEW_EVIDENCE_DIR="<abs root>/<evidence.dir>/<issue>/screenshots" <commands.test_e2e>`. The removal is what makes each cycle overwrite and drop stale files (§10). The path is absolute, so a nested `tests/e2e/` package writes to the right place.
- A non-zero exit means test failures, not a QA failure: read the results and report them.
- Results per test and viewport (the jq form proven in the snippet check): `jq -r '.. | objects | select(has("specs")) | .specs[] | .title as $t | .tests[] | "\($t)\t\(.projectName)\t\(.results[-1].status // "none")"' test-results/results.json`. `skipped`, `none` (not run) and unexpected statuses count as not passed for the UI-done rule.
- Verify each expected screenshot (UI TCs × planned viewports) exists and is a JPEG: `file -b <path>` starts with `JPEG image data`.
- Developer, fix mode: run only the failing specs (`npx playwright test <spec file> -g "TC-<n>:"`), **without** `AEW_EVIDENCE_DIR`, after §3. Never edit QA's specs.

**§9 Exploratory checks (Playwright MCP).** The bundled server's tools are listed by full name. A3 copies the "qa-engineer Playwright tools" block from README §8.2, so every name in this section is in that list. For each changed page and each viewport, with the app running (§3):
1. `browser_resize` to the viewport's width and height; `browser_navigate` to `<base_url><path>`.
2. Layout: `browser_snapshot` with `boxes: true`. A box extending past the viewport width (horizontal overflow), overlapping interactive boxes, or content clipped off-screen is a layout break.
3. Focus order and keyboard traps: `browser_press_key` `Tab` repeatedly, reading the focused element from each result or snapshot (marked `<A2's recorded marker>`, or under 5c by `browser_evaluate` of `document.activeElement`). Order must follow the visual and reading order. If focus stays on one element or cycles within a component, try `Shift+Tab` and `Escape`; still stuck means a keyboard trap.
4. Console: `browser_console_messages` with `level: "error"` after each page; each error is a finding.
5. Interactions the ACs name: `browser_click`, `browser_type`, `browser_select_option`, `browser_hover`. `browser_wait_for` only with `text`/`textGone`, never `time`.
6. `browser_close` when done.
- Recording (contract C-5): a bullet line per page and viewport in `## Commands and output` (`- MCP <page> @ <viewport>: <finding | no issues>`). A finding that breaks an AC or is a WCAG A/AA failure (keyboard trap, broken focus order) is also a `## Failures` entry with a triage class. Everything else is an observation only. The MCP never writes evidence: screenshots come only from §6.

**§10 Evidence rules** (AC-5):
- Paths: `<evidence.dir>/<issue>/report.md` and `<evidence.dir>/<issue>/screenshots/<TC>-<viewport>.jpg` (`docs/qa/…` by default).
- Specs write screenshots only when `AEW_EVIDENCE_DIR` is set. Only QA sets it, so developers, James and later regression runs never change committed evidence.
- Each cycle clears the screenshots dir before its run (§8), so same-named files are overwritten and screenshots the cycle did not produce are deleted.
- `report.md` (a copy of the passing `08-qa-report-<n>.md`) is written only for a passing cycle, so only the final passing cycle is kept.
- Evidence is committed on the feature branch (`git add` of the evidence dir also stages deletions), and squash merges carry only the final evidence into the default branch.
- JPEG at `evidence.quality`, viewport from the project name, TC from the title.
- The report's `## Screenshots` table (DESIGN §8.6 "screenshot index") lists every file §8 verified, one row per TC and viewport, by repo-relative path.

**§11 Manual-test handoff.** Write `<run_dir>/manual-tests.md` from `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/manual-tests.md` (keep its heading and comment). There is one checkbox line per manual-only TC, in the template's format (`- [ ] **TC-<n> (AC-<n>):** <steps> → <expected>. _Why manual:_ <reason>.`). Only the cases phase A classed manual-only, with the reason it gave, go here. An automatable case is never moved here: that breaks the UI-done rule. If there are no manual cases, don't write the file. The orchestrator posts it, and the doc-writer lists it in the PR.

**Step 3: GREEN (scratch project, from Step 1).** Restore the cumulative lookup (the exact §7 template) and replace the scratch files with the skill's code blocks exactly as written (config substitutions only). Then:

```sh
cd "$S"
npx playwright test; echo "exit=$?"
#   expect: 4 passed, 2 failed (TC-2 desktop and mobile), exit=1; the failure message lists button-name with its impact (axe rates it critical) and "1 node(s)"
find test-results -name 'axe-*.json' | sort
#   expect: two files, axe-TC-2-desktop.json and axe-TC-2-mobile.json, each containing "button-name"
jq -r '.. | objects | select(has("specs")) | .specs[] | .title as $t | .tests[] | "\($t)\t\(.projectName)\t\(.results[-1].status // "none")"' test-results/results.json
#   expect: six lines; TC-2 lines "failed", the others "passed"
ls docs 2>/dev/null; echo "no-evidence-without-env=$?"
#   expect: no docs/ (exit 1): nothing is written without AEW_EVIDENCE_DIR
E="$S/docs/qa/1/screenshots"; rm -rf "$E"
AEW_EVIDENCE_DIR="$E" npx playwright test >/dev/null; ls "$E"
#   expect exactly: TC-1-desktop.jpg TC-1-mobile.jpg TC-2-desktop.jpg TC-2-mobile.jpg
#   (failing TC-2 still captured; 2-other.spec.ts's TC-1 did NOT overwrite 1-snippet's TC-1)
for f in "$E"/*.jpg; do file -b "$f" | cut -c1-15; done
#   expect: "JPEG image data" four times
curl -fsS -o /dev/null --max-time 2 --retry 2 --retry-delay 1 --retry-max-time 4 --retry-all-errors http://localhost:4999; echo "dead-port=$?"
#   expect: non-zero (7), proving the timeout branch reports rather than hangs
kill $(lsof -ti tcp:4174 -sTCP:LISTEN); lsof -ti tcp:4174 -sTCP:LISTEN; echo "stopped=$?"
#   expect: no PID printed, stopped=1
```

If any template line fails (for example the `./aew` import form under `"type": "module"`, the `@axe-core/playwright` default import, or `testInfo.tags`), fix the skill's code block, re-run, and record the corrected form in the task report. The skill ships only code that ran here.

**Step 4: structural checks (repo).**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
sed -n '1,5p' skills/ui-qa/SKILL.md                       # ---, name: ui-qa, description:, user-invocable: false, ---
grep -c 'disable-model-invocation' skills/ui-qa/SKILL.md  # 0
grep -E '^## [0-9]+\. ' skills/ui-qa/SKILL.md             # exactly the 11 titles of contract C-2, in order
wc -l < skills/ui-qa/SKILL.md                             # about 280, at most ~330
SMOKE="${TMPDIR:-/tmp}"; SMOKE="${SMOKE%/}/aew-smoke"
grep -o 'mcp__plugin_aew_playwright__browser_[a-z_]*' skills/ui-qa/SKILL.md | sort -u > "$SMOKE/uiqa-names.txt"
#   every line must appear in the README §8.2 "qa-engineer Playwright tools" block:
awk '/qa-engineer Playwright tools/{f=1} f&&/^```$/{n++; if(n==2) exit} f&&/^mcp__/' tests/agent-smoke/README.md | sort -u | comm -23 "$SMOKE/uiqa-names.txt" -
#   expect: no output
grep -nE 'waitForTimeout|networkidle' skills/ui-qa/SKILL.md   # only in the "banned" sentence
grep -n '1\.64\.1\|4\.14\.0' skills/ui-qa/SKILL.md            # both pins present (§2)
grep -c 'wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa' skills/ui-qa/SKILL.md   # >= 1: the AC-4 mapping is stated in the §7 prose
claude plugin validate .                                      # passes
git status --porcelain                                        # only skills/ui-qa/SKILL.md
```

The live preload check (`Preloaded skill 'aew:ui-qa'` in the debug log, no skip warning) is Phase C's AC-25 check on run 941/951, not repeated here.

**Step 5: commit.**

```
feat(skills): add the ui-qa skill for Playwright, axe and QA evidence

Internal skill preloaded into qa-engineer and invoked by the developer in fix
mode. It sets Playwright up (exact-pinned @playwright/test@1.64.1 and
@axe-core/playwright@4.14.0, nested tests/e2e package for PHP and .NET),
starts the app and waits on ready_check with a 120 s limit, runs one project
per viewport, captures <TC>-<viewport>.jpg only when AEW_EVIDENCE_DIR is set,
expands ui.axe_standard to cumulative WCAG tags (wcag22aa alone misses
button-name), and defines the exploratory MCP checks, the evidence rules and
the manual-test handoff. The code templates were run in a scratch project
before commit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task A4 — Describe `ui.axe_standard` as a cumulative target (Assumption 5; AC-15 schema bullet)

- **id:** A4
- **files:** `templates/config.schema.json` (one `description` string)
- **depends_on:** []
- **pattern:** the neighbouring `description` strings in the `ui` block (one sentence or two, no Markdown)
- **ACs:** AC-15 (the `config.schema.json` bullet, plus "the full script suite still passes"); supports AC-4
- **Risk:** NOT RISKY (description only; shape, type and default unchanged)

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
jq -r '.properties.ui.properties.axe_standard.description' templates/config.schema.json
```

Expected: `axe-core rule tag to scan against.` (the wording that makes `wcag22aa` mean one tag).

**Step 2: edit.** Replace that string with:

```
WCAG conformance target for the axe-core scan. A WCAG level (wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa) expands to the cumulative axe tags up to and including it, so wcag22aa scans wcag2a, wcag2aa, wcag21a, wcag21aa and wcag22aa. Any other value is used as a single axe tag.
```

**Step 3: GREEN.**

```sh
jq -r '.properties.ui.properties.axe_standard | "\(.type) \(.default)"' templates/config.schema.json   # string wcag22aa
jq -r '.properties.ui.default.axe_standard' templates/config.schema.json                              # wcag22aa
git diff --stat templates/config.schema.json                                                          # 1 file, 1 insertion(+), 1 deletion(-)
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s templates/config.schema.json -d templates/config.example.json   # "templates/config.example.json valid"
tests/run-script-tests.sh                                                                             # shellcheck clean, all bats pass (common.bats reads this schema)
```

**Step 4: commit.**

```
docs(config): describe ui.axe_standard as a cumulative WCAG target

axe-core's wcag22aa tag marks only the rules new in WCAG 2.2 AA, so reading
the default as a single tag would skip most checks, including button-name.
The description now says a WCAG level expands to the cumulative tags, as the
ui-qa skill does. Type, default and shape are unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

## Phase verification (after A1–A4)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
claude plugin validate .                                                     # passes
jq -e '.mcpServers.playwright.args[1] == "@playwright/mcp@0.0.83"' .mcp.json  # true
tests/run-script-tests.sh                                                    # green (AC-15 clause)
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s templates/config.schema.json -d templates/config.example.json   # valid
grep -E '^## [0-9]+\. ' skills/ui-qa/SKILL.md | wc -l                         # 11
grep -c 'mcp__plugin_aew_playwright__' docs/DESIGN.md tests/agent-smoke/README.md   # both >= 1
git log --oneline -4                                                         # the four conventional commits of A1-A4
git status --porcelain                                                       # clean apart from files from other phases
```

The ledger total after this phase is probe 940's cost (expected under $0.20), plus any 5a/5b re-run.

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-1 pinned `.mcp.json`, wrapper form, exact version, validate passes, DESIGN §4 decision | A1 (+A2 browser sentence, 5a fallback) | Step 4 jq checks, `claude plugin validate .`, the §4 row diff |
| AC-2 names verified from `system/init`, recorded in README and DESIGN §3, exact names for qa-engineer | A2 (the names); Phase C (copies the block into `tools:`) | `$O/playwright-tools.txt`, README §8.2 with both code blocks, DESIGN §3 bullet |
| AC-3 ui-qa frontmatter and every listed topic | A3 | §1–§11 per contract C-2; Step 4 structural checks |
| AC-4 cumulative tag mapping; serious/critical fail; all results kept | A3 (+A4 schema wording) | Step 1 RED (6 passed, violation missed) → Step 3 GREEN (TC-2 fails on `button-name (critical)`; axe JSON files present) |
| AC-5 evidence paths, `AEW_EVIDENCE_DIR`-only writes, overwrite and prune, report on pass only, committed on the branch | A3 | §10 text; Step 3 (no `docs/` without the env var; exactly four JPEGs by `file -b`; no cross-issue overwrite) |
| AC-15 `ui.axe_standard` description; suite still passes | A4 | Step 1 RED/Step 3 GREEN; `tests/run-script-tests.sh` |
| AC-15 template and run-protocol bullets | Phase C | not here |

## Decisions and refinements in this phase (flag if wrong)

1. **One probe session for AC-2 and Assumption 3.** Probe 940 reads the init tool list and drives the browser once with Haiku (cap $1). This settles the tool names, the browser channel, whether the server writes into the cwd, and how focus appears, before Phase C spends $8 on QA. Its id is outside the spec's 941–972 run list, and it has no run dir.
2. **The browser is the MCP default (installed Google Chrome) unless the probe fails.** The fallback flag and install use the MCP's bundled Playwright version (`1.64.0-alpha-1790635538000`), not `@playwright/test@1.64.1` (spec-review note). The 0.0.83 options table doesn't list `chromium` for `--browser` (only the Docker example uses it), so 5a records whichever value works.
3. **Exploratory layout checks use `browser_snapshot` with `boxes: true`**, not screenshots, so the tool set stays exactly Assumption 2's eleven. `browser_take_screenshot` is excluded: MCP screenshots must never become evidence, and unnamed ones go to an output dir that might land in the project. `browser_evaluate` is added only if focus can't be read otherwise (5c).
4. **Evidence is captured by an auto fixture after each test** (pass or fail), not by explicit calls before assertions. A failing cycle-1 test still yields its `<TC>-<viewport>.jpg` (needed by AC-19), and a passing one shows the final asserted state. Consequence: one test per UI TC.
5. **Cross-issue guard on evidence:** the fixture captures only for `<issue>-*.spec.ts`, with the issue taken from `AEW_EVIDENCE_DIR`'s parent dir. Without it, a regression run of an older issue's `TC-1` would overwrite the current issue's `TC-1`. Milestone runs with several issues are not covered (prompt 06).
6. **Stale-screenshot pruning is `rm -rf` of the screenshots dir before each QA evidence run**, rather than mtime comparisons (macOS `find -newer` resolution) or `find -delete` (prompts). This satisfies "overwrite same names and delete what the cycle did not produce" and suits Phase E's mtime and no-stale check. The guard allows recursive `rm` inside the project.
7. **TypeScript specs and config (`*.spec.ts`, `playwright.config.ts`)** in every project, because Playwright runs TypeScript without a build step and no `tsconfig.json` is needed. JavaScript is used only if the project already has JS Playwright specs. The `.spec.ts` suffix keeps specs out of `node --test`.
8. **Reporters `list` and `json` (`test-results/results.json`), no `html`, `retries: 0`, no `webServer`, viewport-only mobile project.** These keep results machine-readable, never open a browser, never hide flakiness, and leave app start to §3 (Assumption 7).
9. **App start uses `nohup sh -c '<start_command>' > <run_dir>/app.log 2>&1 &`**, not the Bash tool's background mode, so start, log tail and stop are plain commands the allowlist can name (contract C-4). Whether a `nohup` child survives between Bash tool calls in a headless subagent is first exercised in Phase C's run 951. If it does not, the fix goes in the skill text and is recorded there.
10. **Command `ready_check` polling uses `sleep 2`** inside a bounded loop. That is the only sleep (the URL form uses `curl --retry`). It is untested, because the fixture uses a URL check.
11. **Config values are written into `aew.ts` and `playwright.config.ts` as literals** (quality, axe standard, base URL, viewports). QA updates them when config changes, rather than a runtime config reader (no new abstraction).
12. **README §8 numbering** (`8.1` ledger, `8.2` tool names) is a proposal for the consolidator to reconcile with Phases C and E.

## Risks

- **The MCP server starts in every aew session** (RISKY, A1): there is a first-run download and a Node process per session, even outside aew projects. Mitigations: an exact pin, `--headless --isolated`, A1's npx cache warm-up, A2's connected-status check, and the A1 rollback. Residual: the per-session cost is accepted by DESIGN §4.
- **MCP connection timing in headless mode:** a slow `npx` start could leave the server `pending` in `system/init`, so no names. Mitigation: the A1 Step 4 warm-up and A2 5b (`MCP_TIMEOUT=60000`, then BLOCKED rather than guessing names).
- **Browser availability** (Assumption 3): Chrome may be missing on another machine. The probe proves it only on James's machine; 5a gives the pinned fallback. Phase C's README setup should list "Google Chrome installed, or the 5a step" as a prerequisite.
- **Template drift between `@playwright/test` and the skill text:** every code block runs in A3's scratch project before commit. ESM import forms are the likeliest break, and Step 3 catches them.
- **Server writes into the project or plugin cwd** (snapshots, console logs): A2 Step 3 checks both `git status` outputs, and 5d adds the gitignore line.
- **Phase C copying a stale name list:** the README block is the single source, and A3 Step 4's `comm` check proves the skill uses only listed names. Phase C should run the same check on `agents/qa-engineer.md`.
- **Probe spend counts toward the $60 stop.** Expected well under $1.

## Approval (Phase A)

- Senior architect: APPROVED WITH NOTES on 2026-10-24T20:00:37Z (plan-review, full depth)
- Plan content hash (SHA-256, before this note): 29ed3e5bf7f98eb8511f020435cf4a096291baba5d8f8ecf3c15bf1002917c89
- Dependency graph: valid (A1 → A2 → A3; A4 independent). Wave count: 3. Max wave width: 2 (A1 ∥ A4).
- Risk lines crossed: new runtime dependency (A1, rollback present; A2 only under 5a).
- Applied during review (mechanical): skipped-test guard in the evidence fixture and its §6 prose; §2 adds the `json` reporter to an existing Playwright config; §10 names the report's `## Screenshots` index; A3 Step 4 name extraction requires `browser_` and the AC-4 mapping grep no longer matches on `wcag22aa` alone.
- Notes for implementation and the consolidator: see the review report (command `ready_check` per-attempt timeout; Phase C allowlist matching of `kill $(…)`, `for … $(seq …)` and `nohup … &`; evidence state when the last allowed cycle fails; `commands.test_e2e` run from the package dir).
