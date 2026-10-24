# aew — Design

**Status:** approved design, v1 (24 Oct 2026). This is the source of truth for building the plugin. The build prompts in `docs/build-prompts/` implement it. If a prompt and this document disagree, this document wins. Flag the conflict.

## 1. Purpose

A personal Claude Code (CLI) plugin that delivers GitHub issues end to end through a spec-driven, multi-agent pipeline. Each issue is treated as a spec. The pipeline runs: analyse the spec → compile a brief → set standards → plan → build → review → test (including UI) → document → open a PR ready for review.

- **Owner:** James Borg. Solo use only.
- **Short slug:** `aew`. Used for labels, directories and the state folder.
- **Non-goals (v1):** merging PRs, deploying, agent teams (experimental), CI or GitHub Actions runs, multi-user configuration, and Notion sync.

## 2. Principles

1. **The spec is king.** Every line of code traces to a numbered acceptance criterion (AC).
2. **Simplest thing that satisfies the brief.** The senior engineer actively challenges complexity, constraints and alternatives.
3. **Agents communicate through files, never chat.** Each agent returns a short structured block (§7.5) to the orchestrator.
4. **Agents never touch GitHub.** The orchestrator owns all GitHub input and output, through the plugin's scripts. Agents read and write files in the run directory and the repo only. This keeps agents testable offline and keeps the permission surface small.
5. **Autonomy with honest escalation.** Act alone. Ask only on genuine questions: a material spec change, an irreversible action, or being blocked.
6. **Project conventions beat generic standards.**
7. **Evidence over assertion.** "Done" means tests ran and passed, with output and screenshots recorded.
8. **Every run leaves things better.** The project gets updated CLAUDE.md, standards docs and spec snapshots. The plugin gets retro issues.

## 3. Platform facts this design relies on (verify against current docs while building)

Checked against code.claude.com/docs on 24 Oct 2026. Re-verify each one before relying on it. If the docs now differ, follow the docs and update this section.

- **Plugin layout.** `.claude-plugin/` holds only `plugin.json` (and `marketplace.json` for a marketplace). Components live at the plugin root: `skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `scripts/`. Commands have merged into skills, so use `skills/`. A `CLAUDE.md` at the plugin root is **not** loaded.
- **Plugin name.** The plugin is named `aew`. Names starting with `claude-`, `anthropic-`, `anthropics-` or `cc-plugin-` are reserved and fail `claude plugin validate`.
- **Namespacing.** Skills are invoked as `/aew:<skill>`. Agents are named `aew:<agent>`. Plugin MCP tools are named `mcp__plugin_<plugin>_<server>__<tool>`, so `mcp__plugin_aew_<server>__<tool>`.
- **Agent frontmatter.** Plugin agents honour `name`, `description`, `model`, `effort`, `maxTurns`, `autoCompactWindow`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation` (only `worktree`), `color` and `experimental.cacheTtl`.
  - They **ignore** `hooks`, `mcpServers`, `permissionMode` and `initialPrompt`.
  - So hooks go in `hooks/hooks.json` and MCP servers in the plugin's `.mcp.json`.
- **Effort.** The valid `effort` values depend on the model; check the model's entry in the docs before setting one.
- **Agent tool restrictions.** A `disallowedTools` entry with a specifier (for example `Bash(gh *)`) removes the whole tool, not just that command, and a plugin cannot ship `permissions.deny`. Per-command denial therefore uses a `PreToolUse` hook (section 11): a subagent's payload carries `agent_id` and `agent_type`, and `agent_type` is `aew:<agent>` for plugin agents (null on the main thread). Live-evidenced in the smoke runs.
- **Path variables.** `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are substituted in agent and skill Markdown, and are not exported to Bash-tool commands, so prompts spell literal `${CLAUDE_PLUGIN_ROOT}/…` paths. Confirmed for `${CLAUDE_PLUGIN_ROOT}` in both an agent prompt and a preloaded skill (seeds were read at the substituted path); `${CLAUDE_SKILL_DIR}` is untested. A `Bash(<abs path> *)` allow rule matches the quoted `"<abs path>" …` call form.
- **Plugin dependencies at run time.** Disabling a plugin's dependency in `enabledPlugins` stops the dependent plugin loading (headless harnesses must disable only unrelated plugins). `claude plugin validate` does not check agent frontmatter, so agent fields are verified by running the agents.
- **context7 tool names.** Assumed `mcp__plugin_context7_context7__*` (context7 is a dependency plugin, not an `aew` server). Unverified: without `CONTEXT7_API_KEY` the server reports `needs-auth` in headless runs, no call was made, and the agents fall back to the seeds as designed.
- **Models.** Valid `model` values are `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit`.
- **Nesting.** Subagents can spawn subagents, up to depth 3. In this design: orchestrator (main thread, depth 0) → developer (1) → sub-developers (2). To spawn, `Agent` must be in the agent's `tools`. An `Agent(type)` restriction list is ignored in a subagent definition, so a sub-developer is kept from spawning by its prompt, not its frontmatter.
- **Worktree isolation.** `isolation: worktree` (in frontmatter or on the Agent call) branches from the repo's default branch, not the caller's HEAD, unless the user sets `worktree.baseRef: "head"`. Its path and branch naming are undocumented, it is auto-cleaned only when unchanged, and nothing is merged back. So aew does not use it, and the developer creates its worktrees with `git worktree add`.
- **Search tools.** On macOS, Linux and WSL `Glob` and `Grep` are not in the default tool set; Claude searches with `find` and `grep` through Bash instead (code.claude.com/docs/en/tools-reference). A subagent that lists `Glob` or `Grep` in `tools` and leaves out `Bash` gets them back for that subagent only (/en/sub-agents). So agents with Bash (standards-setter, senior-engineer) do not list them and search with `find`/`grep`; agents without Bash (spec-analyser, brief-compiler) list `Glob, Grep`. A built-in set of read-only Bash commands (`ls`, `cat`, `head`, `tail`, `grep`, `find`, `wc`, `diff`, `stat`, read-only `git`) runs without a permission prompt in every mode, but `find` with `-exec`, `-delete` or `-fprint` prompts (/en/permissions).
- **Skills in agents.** `skills:` frontmatter preloads full skill content into an agent. Agents can still invoke other skills with the Skill tool. Up to 32 skills can be preloaded, and a skill with `disable-model-invocation: true` cannot be. **A missing skill is skipped silently** (debug-log warning only), so verify preloads with `--debug-file`. Qualified plugin skill names preload, including dependency skills (`aew:run-protocol`, `superpowers:systematic-debugging`); the debug log shows `Preloaded skill '<name>'` (confirmed in headless smoke runs).
- **Agent memory.** `memory: project` gives an agent `.claude/agent-memory/<plugin>-<agent>/MEMORY.md` (for a plugin agent the directory is `aew-<agent>`, for example `aew-spec-analyser`, confirmed in a headless run). The first 200 lines or 25 KB are loaded. Memory scopes are `user`, `project` and `local`; any memory scope automatically enables Read, Write and Edit for the agent, and has no effect when auto memory is off.
- **Dependencies.** Each `dependencies` entry in `plugin.json` is `"name"`, `"name@marketplace"` or `{ name, marketplace, version }`. A `version` range resolves only against git tags named `<plugin>--v<version>` on the dependency's repo; with no matching tag, installing a dependency that has its own repo fails. Cross-marketplace dependencies need `allowCrossMarketplaceDependenciesOn` (an array of marketplace names) in the root marketplace's `marketplace.json`.
- **Skill visibility.** `user-invocable: false` hides a skill from the `/` menu while Claude and agents can still use it. `disable-model-invocation: true` is the reverse: the user can invoke it, but Claude won't load it on its own.
- **Validation.** `claude plugin validate <path>` checks a plugin or marketplace manifest and its components.
- **Blocking hooks.**
  - `PreToolUse` denies with `hookSpecificOutput.permissionDecision: "deny"` and `permissionDecisionReason` on exit 0. Top-level `decision`/`reason` are deprecated for `PreToolUse`.
  - `Stop` and `SubagentStop` block with `{"decision":"block","reason":…}` on exit 0. Exit 2 also blocks, but aew never uses it.
  - `stop_hook_active` is true when a stop hook has already continued the agent.
  - Documented cap: after 8 consecutive stop-hook continuations, the next block is overridden. The count resets on each tool call, and `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it. It is stated for `Stop`; the docs do not say it applies to `SubagentStop`, though the same protections are presumed to.
- **Hook matching and environment.**
  - `SubagentStop` matchers match `agent_type`, which for plugin agents is `aew:<agent>`.
  - A matcher of only letters, digits, `_`, `-`, space, `,` and `|` is an exact list. Anything else is an unanchored regex, so anchor it (`^aew:developer$`).
  - The default timeout is 600 s, so set explicit timeouts. A hook that reaches its timeout is cancelled and its output discarded, so it renders no decision. A timed-out `PreToolUse` hook does not block the tool call unless it sets `onFailure: "block"` (aew does not), and `onFailure` has no effect on `SubagentStop`. A timed-out hook therefore never blocks; a timed-out `SessionStart` hint is simply missing.
  - Exit-0 stderr is never shown to Claude (debug log only).
  - `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` are exported. The hook's cwd is not documented, so use the payload `cwd` or `CLAUDE_PROJECT_DIR`.
  - `SessionStart` adds context through `hookSpecificOutput.additionalContext`.
  - Whether `Write` and `Edit` matchers cover `MultiEdit` and `NotebookEdit` is not documented, so the `Edit|Write` guard may miss them (known limitation).
- **Screenshots.** GitHub has no official API for image attachments, so QA evidence is committed to the PR branch.

## 4. Dependencies

| Dependency | Source | Use |
|---|---|---|
| superpowers | `claude-plugins-official`, no version range (see note below) | Specific skills preloaded into specific agents (§5.3). **Not used:** brainstorming, writing-plans, executing-plans, subagent-driven-development, or the using-superpowers session flow. The pipeline replaces those. |
| context7 | `claude-plugins-official` | Current library and framework docs for the standards-setter, senior-engineer and developer |
| frontend-design | `claude-plugins-official` | The developer uses it on UI work packages |
| Playwright MCP | plugin `.mcp.json`: `npx --yes @playwright/mcp@0.0.83 --headless --isolated` (exact version) | Exploratory UI checks by QA (§8.6). `claude-plugins-official` ships a `playwright` plugin (by Microsoft), but it is only an unpinned `npx @playwright/mcp@latest` `.mcp.json` with no skill, so it covers neither §8.6 (that is the `ui-qa` skill) nor the pinning rule. aew bundles its own pinned server instead (decided 24 Oct 2026). `--headless` because QA runs unattended; `--isolated` so no browser profile or login state persists between runs. If the official plugin is also enabled, both servers run under different tool prefixes. |

- **Why superpowers has no version range.** obra/superpowers tags releases as `v<version>`, not `superpowers--v<version>`, so a range such as `^7.0.0` can't resolve and the install would fail. The official marketplace pins superpowers to a commit (v7.0.0 on 24 Oct 2026), so the dependency only moves when that pin moves. The plugin is built and tested against superpowers 7.x. Add a range once upstream publishes `superpowers--v*` tags.
- **Playwright packages.** Plugin MCP servers start with the plugin, so every session with aew enabled runs one `npx @playwright/mcp` process (the first run downloads it). The test packages are not in the plugin: `ui-qa` setup exact-pins `@playwright/test@1.64.1` and `@axe-core/playwright@4.14.0` in the target project and installs Chromium with `npx playwright install chromium`.
- **CLI prerequisites:** git, gh (authenticated), jq, Node ≥ 20, plus stack tools as needed (php/composer, dotnet, Docker for wp-env or ddev).
- **GitHub access:** the `gh` CLI only, wrapped by plugin scripts. No GitHub MCP.

## 5. Components

### 5.1 User-invocable skills

| Skill | Purpose |
|---|---|
| `init` | Run once per project. Detects stacks, writes `.aew/config.json`, ensures labels, gitignore and Playwright setup, proposes permissions, adds a CLAUDE.md section, and generates the first standards docs. Works on a `chore/aew-init` branch and opens a PR. |
| `ship <issue> [--auto] [--from <stage>]` | Full pipeline for one issue |
| `ship-milestone <milestone> [--bulk\|--sequential] [--auto]` | Milestone mode (§10) |
| `resume [<run-id>]` | Continue an interrupted run from `state.json` |
| `status [<run-id>]` | Read-only view of the run state |
| `prompt <issue>` | Standalone mode. Runs spec analysis (with the same gate), then writes a single A-to-Z prompt (`prompt.md`). No pipeline. |

Skills with side effects set `disable-model-invocation: true`.

### 5.2 Internal reference skills (not user-invocable)

- **`run-protocol`:** run directory layout, state machine, artefact contracts, return contract and labels. Preloaded into every agent.
- **`github-ops`:** how the orchestrator uses the gh wrapper scripts.
- **`stack-standards`:** stack detection, fingerprinting, standards document structure, and seed references per stack.
- **`ui-qa`:** Playwright conventions, viewports, axe-core, evidence rules and manual-test handoff.
- **`claude-md-curation`:** rules for updating CLAUDE.md.

### 5.3 Agents

| Agent | Model | Effort | Memory | Preloaded skills | Writes to |
|---|---|---|---|---|---|
| `spec-analyser` | opus | high | project | run-protocol | run dir |
| `brief-compiler` | opus | medium | — | run-protocol | run dir |
| `standards-setter` | sonnet | medium | project | run-protocol, stack-standards | `docs/standards/`, run dir |
| `senior-engineer` | opus | high | project | run-protocol, stack-standards, superpowers systematic-debugging | run dir only |
| `developer` | sonnet | medium | — | run-protocol, superpowers test-driven-development, verification-before-completion, systematic-debugging | source, tests, run dir |
| `qa-engineer` | sonnet | medium | project | run-protocol, ui-qa, superpowers verification-before-completion | tests, `docs/qa/`, run dir |
| `doc-writer` | sonnet | medium | project | run-protocol, claude-md-curation | CLAUDE.md, `docs/specs/`, run dir |

- Verify the exact namespaced skill names of dependency plugins at build time.
- context7 and frontend-design are used through their tools and skills when needed, not preloaded, unless the docs say preloading is the right way.

## 6. Files in the target project

```
<project>/
├── .aew/
│   ├── config.json              # committed: project config (schema: plugin templates/config.schema.json)
│   └── runs/<run-id>/           # gitignored: run working state and artefacts
├── docs/
│   ├── standards/               # committed: one doc per stack profile + README index
│   ├── specs/<issue>-<slug>.md  # committed: final spec snapshot (repo = source of truth)
│   └── qa/<issue>/              # committed in PR branch: QA report + screenshots (final passing cycle only)
├── <e2e dir from config>/       # committed Playwright specs (regression suite)
└── CLAUDE.md                    # curated by doc-writer
```

### 6.1 `.aew/config.json` fields

- `project`: name
- `default_branch`
- `stacks`: `[{ profile, path, version }]`
- `commands`: `{ install, dev, build, lint, format, typecheck, test_unit, test_e2e, seed }`
- `app`: `{ base_url, start_command, ready_check (URL or command), env_type: wp-env | ddev | local | docker | native | none, test_accounts: [{ role, username_env, password_env }] }`
- `ui`:
  - `viewports`: default `[{ name: "desktop", width: 1440, height: 900 }, { name: "mobile", width: 390, height: 844 }]`
  - `axe`: `true`
  - `axe_standard`: `"wcag22aa"`
  - `e2e_dir`: `"tests/e2e"`
- `git`: `{ branch_pattern: "feat/{issue}-{slug}", milestone_branch_pattern: "feat/m{milestone}-{slug}", commit_convention: "conventional" }`
- `gates`: `{ plan_approval: true }`
- `limits`: `{ max_fix_cycles: 3, max_review_cycles: 2, max_parallel_developers: 4 }`
- `evidence`: `{ dir: "docs/qa", format: "jpeg", quality: 80 }`
- `claude_md`: `{ max_lines: 300 }`
- `retro`: `{ repo: "<owner>/<plugin-repo>", label: "retro" }`

Secrets never go in config. It holds environment variable names only.

## 7. Run protocol

### 7.1 Run directory `.aew/runs/<run-id>/`

The run id is the issue number, or `m-<milestone-number>` for milestone runs.

| File | Writer |
|---|---|
| `state.json`, `log.md` (append-only, one line per transition) | scripts |
| `issue.json`, `00-issue-original.md` | `gh-issue.sh fetch` |
| `01-spec-analysis.md`, `spec-final.md`, `spec-changes.json` | spec-analyser |
| `spec-revision-v<N>.md` (the "Spec revision vN" comment, rendered from `spec-changes.json`) | orchestrator |
| `02-brief.md` | brief-compiler |
| `03-standards.md` (which standards docs and sections apply) | standards-setter |
| `04-qa-test-plan.md` | qa-engineer (phase A) |
| `05-plan.md` | senior-engineer (plan) |
| `06-dev-report.md` (+ `06-dev-report-WP<n>.md` for sub-developers) | developer |
| `07-review-<n>.md` | senior-engineer (review) |
| `08-qa-report-<n>.md` | qa-engineer (phase B) |
| `09-triage-<n>.md` | senior-engineer (triage) |
| `manual-tests.md` | qa-engineer |
| `10-summary.md`, `pr-body.md`, `retro.md` | doc-writer |
| `prompt.md` (prompt mode only) | brief-compiler |

`.aew/runs/current` holds the active run id. Hooks use it.

### 7.2 `state.json`

- `run_id`
- `issues`: `[n…]`
- `title`
- `mode`: `single | bulk | sequential | sequential-child`
- `auto`: bool
- `stage`
- `status`: `running | awaiting_input | awaiting_plan_approval | blocked | done | failed`
- `branch`
- `base_branch`
- `pr`
- `spec_revision`
- `fix_cycle`
- `review_cycle`
- `started_at`
- `updated_at`
- `history`: `[{ stage, status, at, note }]`

### 7.3 Stages

1. `spec_analysis`. If there are material changes: set `awaiting_input` → ask the user → record → re-run the analysis on the delta.
2. `brief`
3. `standards`. Reuse if the fingerprint matches.
4. `qa_test_plan` **in parallel with** `plan`. Then the plan gate (unless `--auto`): `awaiting_plan_approval`.
5. `develop`
6. `review`. If `changes_required`: back to `develop`, up to `max_review_cycles`.
7. `qa`. On failures: route through triage (§8.6), up to `max_fix_cycles`.
8. `docs`
9. `pr`, then `done`.

Exceeding a cycle limit, or an agent returning `failed` twice, sets `blocked`. The orchestrator then posts a report comment, sets the `aew:blocked` label and stops.

Exception (§8.6): qa-engineer phase B returns `failed` when its report is complete but tests or serious or critical accessibility checks failed. That `failed` means "QA failures, report complete": the orchestrator routes it by triage class under `limits.max_fix_cycles` and does not retry it. It counts as such only when `08-qa-report-<n>.md` exists, ends with a valid return block whose STATUS is `failed`, and the triage table at the top of its `## Failures` section has at least one `TC-<n>` row. Anything else is an ordinary agent `failed`: retry once, then `blocked`.

### 7.4 Labels

- **Stage labels** (exactly one at a time): `aew:analysing`, `aew:awaiting-input`, `aew:planning`, `aew:awaiting-approval`, `aew:building`, `aew:testing`, `aew:documenting`, `aew:ready-for-review`, `aew:blocked`.
- **Flags:** `aew:spec-revised`, `aew:manual-test-required`.

### 7.5 Agent return contract

Every agent ends its final message with:

```
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: <paths, comma-separated>
SUMMARY: <≤150 words>
NEXT: <recommendation for the orchestrator>
```

The orchestrator reads return blocks and only reads full artefacts when a gate or routing decision needs them.

## 8. Agent specifications

### 8.1 spec-analyser (Opus, high)

- **Input:** `00-issue-original.md`, `issue.json`, and read-only access to the repo for feasibility.
- **Does:** finds gaps, ambiguities, contradictions, missing ACs and edge cases. Covers non-functional needs (accessibility, performance, security, privacy, i18n). Detects UI changes and checks testability.
- **Materiality rubric.** Every proposed change is classified as one of:
  - **Non-material (applied automatically):**
    - a wording clarification;
    - an implied AC made explicit;
    - an edge case consistent with the stated intent;
    - testability detail;
    - an accessibility requirement implied by WCAG 2.2 AA;
    - a correction of an obvious typo or a reference.
  - **Material (ask first):**
    - scope added or removed;
    - user-visible behaviour or UX changed;
    - a data model, API contract or schema change;
    - a security or privacy impact;
    - a change that removes or contradicts an existing AC;
    - a new dependency or external service;
    - an expected effort change of more than about 30%;
    - anything the issue author is better placed to decide.
- **Output:**
  - `01-spec-analysis.md`: findings, classification table, and questions, each with a recommended answer;
  - `spec-final.md`: the revised spec with non-material changes applied;
  - `spec-changes.json`: structured change list for the orchestrator to render as the issue comment.
- If any change is material: `STATUS: needs_input`.
- **Recording (done by the orchestrator via scripts):**
  - A comment titled "Spec revision vN", with a table: change | type | rationale | source (auto / confirmed by James).
  - The issue body is updated with a marker `<!-- aew:spec vN -->`, the revised spec on top, and every earlier version preserved in collapsed `<details>` blocks.
  - The `aew:spec-revised` label is added.
  - The author's content is never deleted.

### 8.2 brief-compiler (Opus, medium)

**Pipeline mode.** Turns `spec-final.md` into `02-brief.md` with these sections:

- Goal
- Context
- Acceptance criteria. Numbered `AC-1…`, each testable (Given/When/Then where it helps), tagged `[UI] [API] [DATA] [A11Y] [PERF] [SEC]`.
- Non-goals
- Constraints
- Affected surfaces
- Test data and accounts needed
- UI changes: yes/no
- Definition of Done
- Open risks

**Prompt mode.** Writes `prompt.md`, a single self-contained prompt for a plain Claude Code session with no plugin installed. It contains:

- role and context;
- the brief inline;
- standards references (or inline essentials);
- approach freedom;
- autonomy rules: work alone, and ask only on genuine questions (with a list of what counts);
- verification requirements (tests, UI checks with Playwright, screenshots, accessibility scan);
- git and PR rules;
- a Definition of Done checklist.

### 8.3 standards-setter (Sonnet, medium)

- Detects stacks with `scripts/detect-stack.sh`.
- Computes a fingerprint: profile + major versions + hash of the relevant tool configs. If `docs/standards/<profile>.md` exists and its fingerprint header matches, it reuses it (`STATUS: ok`, "reused").
- **Sources, in priority order:**
  1. repo tool configs (eslint, prettier, tsconfig, phpcs.xml, pint.json, phpstan, stylelint, .editorconfig, Directory.Build.props, .csharpierrc…);
  2. patterns sampled from existing code;
  3. the plugin's seed reference for the profile;
  4. context7 for version-specific guidance.
- **Document sections:**
  - fingerprint header;
  - tooling and commands;
  - project structure;
  - naming;
  - language idioms;
  - framework conventions;
  - error handling;
  - security;
  - accessibility;
  - testing conventions;
  - documentation and comment standards;
  - anti-patterns.

  Each rule is marked **[tool]** (enforced by a linter or formatter) or **[convention]**. Use concrete do/don't examples. Keep each document under about 400 lines.
- **Seed profiles (v1):**
  - `nextjs` (includes React and TypeScript);
  - `react`;
  - `laravel`;
  - `wordpress` (PHP, JS and CSS per the WordPress Coding Standards);
  - `woocommerce` (overlay on wordpress);
  - `tailwind` (overlay).
- **C#/.NET:** generated on demand, with no seed. After the first real use, a retro item proposes adding a seed.
- **Output:** `docs/standards/<profile>.md`, the index `docs/standards/README.md`, and `03-standards.md` for the run (which docs and sections apply to this brief).

### 8.4 senior-engineer (Opus, high)

The orchestrator passes the mode.

**plan.** Reads the brief, the standards and the codebase. Writes `05-plan.md` with:

- the approach (simplest viable);
- alternatives considered and why each was rejected (at least one);
- challenges to the spec or its constraints. If a challenge implies a material spec change: `STATUS: needs_input`.
- work packages `WP-n`, each with:
  - goal;
  - ACs covered;
  - files to create or modify (file ownership);
  - `depends_on`;
  - `parallelisable`;
- the standards sections that apply to each work package;
- guardrails, for example:
  - no new dependency without justification;
  - don't touch unrelated files;
  - no public API changes unless specified;
- the unit tests the developer is expected to write per work package;
- risks;
- an AC→WP traceability matrix.

No code beyond short illustrative signatures.

**review.** Compares the diff (`git diff <base>...HEAD`) against the plan, the standards and the brief. Verdict: `approve` or `changes_required`, with numbered findings (severity, `file:line`, required fix). Writes `07-review-<n>.md`.

**triage.** Takes QA failures classified as `plan_divergence` or `test_bug`, or an `impl_bug` the developer failed to fix in one cycle. Writes `09-triage-<n>.md` with:

- the root cause;
- where the divergence started (spec, brief, plan or implementation);
- fix instructions;
- or a ruling that a test is wrong, with instructions for QA.

**Tools:** read tools, plus Bash for read-only commands, plus Write restricted by instruction to the run dir.

### 8.5 developer (Sonnet, medium)

- Implements the plan's work packages in dependency order.
- Follows the standards docs strictly. Uses TDD (per superpowers) for unit tests.
- Before finishing each work package, runs lint, format, typecheck and unit tests from config.
- Commits per work package using conventional commits, with `(#issue)`.
- Code is readable, simple and documented: doc comments on public functions, and comments that explain why rather than what.
- **Fan-out.** If at least two work packages are marked parallelisable and own disjoint files, it spawns sub-developers:
  - the same agent type, in "package mode", one work package each;
  - each in an isolated worktree;
  - at most `max_parallel_developers` at once;
  - then it merges their branches into the feature branch one at a time and reruns all checks.

  Otherwise it works sequentially.

  The developer creates each worktree itself from the feature-branch HEAD (`git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`) and dispatches the sub-developers without `isolation` (§3). It integrates each work package's single commit with `git cherry-pick` in WP-number order, removes the worktrees and WP branches, and only then reruns the checks.
- **Deviations.** If a plan step is impossible or clearly wrong, it stops that work package and returns `STATUS: blocked` with the reason. The orchestrator routes this to the senior engineer. It never diverges silently.
- **Fix mode.** Takes the triage instructions or QA's failing tests, fixes them, then reruns those tests and the full unit suite.
- Uses the frontend-design skill on UI work packages.
- **Output:** code, tests, and `06-dev-report.md` (work packages done, files changed, commands run with results, deviations, notes for QA).

### 8.6 qa-engineer (Sonnet, medium)

**Phase A: test plan.** Runs in parallel with planning. It **must not read the implementation**. It reads only the brief, the standards and the existing test conventions. It writes `04-qa-test-plan.md` with:

- test cases `TC-n`, each mapped to an `AC-n`;
- the level of each: unit, integration, e2e, UI or manual;
- test data needed;
- the UI tests and viewports;
- accessibility checks;
- manual-only cases, each with a reason.

It lists every project file it opened in the plan's `## Files read` section.

**Phase B: execute.** Runs after the review approves.

- Implements the automated acceptance tests in the project's frameworks. UI tests are `@playwright/test` specs in `ui.e2e_dir`.
- Starts the app per config and waits for `ready_check`.
- Runs everything, and captures screenshots at key states for each viewport.
- Runs an axe scan on every changed page. Serious or critical violations fail; moderate ones are reported. `ui.axe_standard` names a conformance target: a WCAG level expands to the cumulative axe tags up to and including it (`wcag22aa` → `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`); any other value is one tag.
- Does exploratory checks of the changed UI with Playwright MCP.
- Writes `08-qa-report-<n>.md` with:
  - a results table (TC → AC → pass/fail);
  - commands and output excerpts;
  - a screenshot index;
  - accessibility results;
  - failures, each with a triage class.
- Returns `ok` (all pass, UI rule met), `failed` (report complete, failures in its triage table; routed per §7.3) or `blocked` (couldn't execute).
- Commits its specs, Playwright setup and evidence at the end of every phase-B cycle (`test(e2e): … (#n)`).

**Triage classes and routing:**

| Class | Route |
|---|---|
| `impl_bug` | developer (fix mode), with the failing test |
| `plan_divergence` | senior-engineer (triage) → developer |
| `spec_ambiguity` | orchestrator → James |
| `test_bug` | senior-engineer decides → QA or developer |

The loop repeats until everything passes or `max_fix_cycles` is reached.

**UI rule.** If the brief has UI changes, the run cannot be done until every automatable UI test passes. Anything that can't be automated goes into `manual-tests.md`. The orchestrator adds it to the issue as a "Manual testing required" checklist section and sets the `aew:manual-test-required` label. The PR description lists them too.

**Evidence.**

- Paths: `docs/qa/<issue>/report.md` and `docs/qa/<issue>/screenshots/<TC>-<viewport>.jpg`.
- Format: JPEG at quality 80.
- Only the final passing cycle is kept; earlier cycles are overwritten. This limits repo growth, because squash merges carry the evidence into main.
- Committed in the PR branch.
- Specs write screenshots only when `AEW_EVIDENCE_DIR` is set, so other test runs never churn evidence.
- Each cycle deletes screenshots it didn't produce, and `report.md` is written only for a passing cycle.
- If the last allowed fix cycle fails, the committed screenshots are a failing cycle's and there is no `report.md`. The report says the evidence is not final, and the orchestrator must not present it as final.

### 8.7 doc-writer (Sonnet, medium)

- **`docs/specs/<issue>-<slug>.md`:** the final spec, revision history, key decisions (from the plan's alternatives), AC→test traceability, and any outstanding manual tests.
- **CLAUDE.md** (via claude-md-curation):
  - only durable, non-obvious, project-specific learnings (commands, gotchas, architecture decisions, discovered conventions);
  - edit and prune existing entries before appending;
  - stay within `claude_md.max_lines`;
  - link to `docs/` for detail;
  - never duplicate the standards docs.
- **`10-summary.md` and `pr-body.md`:**
  - a summary and an AC checklist;
  - test results;
  - screenshots linked via `blob/<branch>/…?raw=true`;
  - manual tests;
  - `Closes #n` for every issue in the run.
- **`retro.md`:** improvements to the plugin seen during the run (agent mistakes, missing rules, slow stages, cycles used, false-positive hooks). The orchestrator files these to the retro repo. They never go in the project repo.

## 9. Orchestrator (`ship` skill)

Runs on the main thread.

- **Preflight:**
  - config exists (if not, suggest `init`);
  - the working tree is clean;
  - gh is authenticated;
  - the default branch is up to date;
  - no other active run is in progress (unless resuming).
- **Steps:**
  - fetch the issue into the run dir;
  - initialise state;
  - set labels;
  - create the branch;
  - dispatch agents with explicit input paths;
  - run QA phase A and planning in parallel (one message, two Agent calls);
  - handle gates and routing;
  - push the branch (never the default branch);
  - create the PR;
  - file the manual tests and retro items;
  - give the final report.
- **Gates:**
  - A material spec change always gets a gate, even with `--auto`. It uses AskUserQuestion with recommended answers.
  - Plan approval is on by default. `--auto`, or `gates.plan_approval: false`, skips it. James sees a plan summary of 25 lines or fewer plus the file path, with the options approve / request changes / stop.
  - Irreversible or destructive operations always get a gate.
- **Resume:** reads `state.json`, verifies the branch and working tree, and continues from the recorded stage.
- **Context hygiene:** reads return blocks only. It opens artefacts only for gates and routing.
- **Final report:**
  - outcome;
  - PR link;
  - ACs passed out of the total;
  - review and fix cycles used;
  - manual tests outstanding;
  - retro items filed.

## 10. Milestone mode

`ship-milestone <milestone> [--bulk|--sequential] [--auto]`

**Mode selection.** If no mode is given, the orchestrator recommends one and asks James to confirm. It recommends **bulk** when all of these hold:

- 5 issues or fewer;
- each issue small (5 ACs or fewer once analysed);
- the same area of the codebase;
- low risk;
- no blocking dependencies.

Otherwise it recommends **sequential**.

**Bulk:**

- Spec analysis runs per issue in parallel. Each issue gets its own revision record and gate.
- One combined brief, with AC ids prefixed by issue (`#12-AC-1`).
- One plan, one branch (`milestone_branch_pattern`), one QA pass with traceability per issue.
- One PR that closes all the issues.

**Sequential:**

- Issues are ordered by their dependencies: "Blocked by #n", "Depends on #n", and task lists. A dependency cycle stops the run and asks.
- Each issue runs through the single-issue pipeline (reuse `ship`'s procedure; don't duplicate it) and gets its own branch and PR.
- An issue that depends on an unmerged one branches from that issue's branch (a stacked PR), and this is noted in the PR.
- The plan gate applies per issue unless `--auto`.
- The sequence stops on `blocked` and posts a milestone report.

## 11. Hooks (`hooks/hooks.json` → `scripts/hooks/`)

Matchers: `Bash`; `Edit|Write`; one `SubagentStop` entry with `^aew:(developer|qa-engineer)$`; `SessionStart` with no matcher. Every hook has a 5 s timeout.

- **`PreToolUse` on Bash (guard).** Blocks:
  - a push to the default branch;
  - any force push (including `--force-with-lease`);
  - `gh pr merge`;
  - `gh repo delete`;
  - `git reset --hard` while on the default branch;
  - `rm -rf` on the repo root, home or system paths, or anything outside the repo;
  - `git clean -fdx`;
  - any `gh` command from an aew agent (the hook payload's `agent_type` starts with `aew:`), because agents never touch GitHub (§2, principle 4).

  The guard is a heuristic (it does not unwrap `bash -c` or `eval`); its limits are documented in the script header.
- **`PreToolUse` on Edit and Write (guard).** Blocks writes to `.env*`, known secret files and `.git/`. It may not cover `MultiEdit` or `NotebookEdit` (undocumented, see section 3).
- **`SubagentStop` for qa-engineer (gate).** Blocks unless the latest QA artefact for the current stage exists (stage-to-artefact mapping) and ends with a valid return block.
- **`SubagentStop` for developer (gate).** Blocks unless the newest `06-dev-report*.md` exists, is not older than `state.json`, ends with a valid return block, and, when `STATUS: ok`, lists the commands run with their results.
- **Gates block once.** The reason becomes the agent's next instruction. When `stop_hook_active` is true, the gate allows the stop and the orchestrator's normal return check decides.
- **`SessionStart`.** If `.aew/runs/current` exists and that run is not `done`, it adds context: "Active aew run <id> at stage <stage> (<status>). Use /aew:resume."
- **All hooks:**
  - inert and silent outside an aew project (no `.aew/`); they warn and stay inert when `.aew/` exists without `config.json`;
  - fail open (exit 0, stderr warning, visible only in the debug log) when jq or the state is missing, or on any unexpected error, so they never brick a session;
  - finish in under a second.

## 12. Quality bar for the plugin itself

- Every agent prompt covers: role, inputs, process, outputs, return contract, guardrails and autonomy rules.
- Scripts: bash with `set -euo pipefail`, shellcheck-clean, `--help` on each, and tests with a mocked `gh`.
- Plugin validation passes, if the CLI offers it.
- The sandbox scenarios in build prompt 07 pass.
- The README covers install, prerequisites, commands, config reference, labels, troubleshooting and uninstall.

## 13. Later (not v1)

- A C#/.NET seed standard after the first real use.
- Headless or CI runs (`claude -p`, GitHub Actions).
- A one-way Notion mirror of `docs/specs/`.
- Agent teams, once they are stable.
