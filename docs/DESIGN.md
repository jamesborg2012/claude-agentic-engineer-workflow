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

Checked against code.claude.com/docs on 24 Oct 2026; the skill, headless, subagent, AskUserQuestion, plugin-version and permission-rule facts again on 25 Oct 2026 (build prompt 05); the install, dependency, tag, `--bare`, budget and uninstall facts again on 26 Oct 2026 (build prompt 07, `tests/e2e-validation.md` § Platform facts), with the SessionStart-in-a-stream and SIGINT facts observed in its runs on 27 Oct 2026. Re-verify each one before relying on it. If the docs now differ, follow the docs and update this section.

- **Plugin layout.** `.claude-plugin/` holds only `plugin.json` (and `marketplace.json` for a marketplace). Components live at the plugin root: `skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `scripts/`. Commands have merged into skills, so use `skills/`. A `CLAUDE.md` at the plugin root is **not** loaded.
- **Plugin name.** The plugin is named `aew`. Names starting with `claude-`, `anthropic-`, `anthropics-` or `cc-plugin-` are reserved and fail `claude plugin validate`.
- **Namespacing.** Skills are invoked as `/aew:<skill>`. Agents are named `aew:<agent>`. Plugin MCP tools are named `mcp__plugin_<plugin>_<server>__<tool>`, so `mcp__plugin_aew_<server>__<tool>`. The Agent tool's `subagent_type` for a plugin agent is `aew:<agent>`; the docs give the `plugin:agent` naming but not the exact string, so it is live-evidenced (smoke runs since prompt 03; the `system/init` agents list in P0b.2, `tests/agent-smoke/README.md` §9.3). Up to 20 background subagents run at once; several Agent calls in one message are not documented as concurrent, so aew relies only on them being dispatched together (run 961, and G2.3 and S1.1 in `tests/agent-smoke/README.md` §9: two Agent blocks under one `message.id`). https://code.claude.com/docs/en/sub-agents.md
- **Playwright MCP tool names.** aew's bundled server is `playwright`, so its tools are `mcp__plugin_aew_playwright__<tool>` (for example `mcp__plugin_aew_playwright__browser_navigate`), and the init `mcp_servers` entry is `plugin:aew:playwright`. Confirmed from the `system/init` event of a headless `--plugin-dir` session on 24 Oct 2026; the full list is in `tests/agent-smoke/README.md` §8.2. The server writes its page snapshots to `.playwright-mcp/` in the session's working directory, so target projects ignore that path. Agent `tools` accepts full MCP tool names. A server wildcard (`mcp__<server>__*`) is documented, but the plugin-prefixed wildcard is not shown, so qa-engineer lists exact names. An omitted `tools` inherits every tool, MCP included.
- **Agent frontmatter.** Plugin agents honour `name`, `description`, `model`, `effort`, `maxTurns`, `autoCompactWindow`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation` (only `worktree`), `color` and `experimental.cacheTtl`.
  - They **ignore** `hooks`, `mcpServers`, `permissionMode` and `initialPrompt`.
  - So hooks go in `hooks/hooks.json` and MCP servers in the plugin's `.mcp.json`.
- **Effort.** The valid `effort` values depend on the model; check the model's entry in the docs before setting one.
- **Agent tool restrictions.** A `disallowedTools` entry with a specifier (for example `Bash(gh *)`) removes the whole tool, not just that command, and a plugin cannot ship `permissions.deny`. Per-command denial therefore uses a `PreToolUse` hook (section 11): a subagent's payload carries `agent_id` and `agent_type`, and `agent_type` is `aew:<agent>` for plugin agents (null on the main thread). Live-evidenced in the smoke runs.
- **Path variables.** `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are substituted in agent and skill Markdown, and are not exported to Bash-tool commands, so prompts spell literal `${CLAUDE_PLUGIN_ROOT}/…` paths. Confirmed for `${CLAUDE_PLUGIN_ROOT}` in both an agent prompt and a preloaded skill (seeds were read at the substituted path). `${CLAUDE_SKILL_DIR}` and `${CLAUDE_SESSION_ID}` are documented as substituted too, and aew doesn't use them. Only the loaded skill or agent body is substituted; a file read on demand with Read (a skill's `references/`) is not, so `ship/SKILL.md` states the substituted root once and its references spell literal `${CLAUDE_PLUGIN_ROOT}/…` paths, absolute rather than relative links because `resume` and `prompt` read them from another skill. A `Bash(<abs path> *)` allow rule matches the quoted `"<abs path>" …` call form. https://code.claude.com/docs/en/skills.md
- **Skill frontmatter and arguments** (V-1). The keys aew uses are `name`, `description`, `argument-hint` and `disable-model-invocation`; unknown keys are ignored. `allowed-tools` only pre-approves tools for the invoking turn and restricts nothing, so aew's entry skills don't set it. `$ARGUMENTS` is the whole string, `$ARGUMENTS[N]` and `$N` are 0-based, and with no placeholder the input is appended as `ARGUMENTS: <input>`. `ship` parses `$ARGUMENTS` whole and uses no `$N` and no `` !`cmd` ``, because `resume` reads it with Read. Keep `SKILL.md` under 500 lines. `claude plugin validate` does not catch invalid YAML frontmatter (an unquoted `: ` in a `description:` value), so parse frontmatter separately. https://code.claude.com/docs/en/skills.md
- **Headless runs** (V-2). `claude -p "/aew:<skill> …"` expands user-invoked skills, `disable-model-invocation` ones included (P0b.2 and P1.1, `tests/agent-smoke/README.md` §9.3). Since v2.1.302 `-p` defaults to Manual mode, which denies approvals, so an unattended run sets a permission mode and an explicit allowlist (aew's harness: `acceptEdits` plus `--allowedTools`, never `bypassPermissions`). https://code.claude.com/docs/en/headless.md#auto-approve-tools `--permission-prompts none` (v2.1.259+) denies anything that would prompt and removes AskUserQuestion. https://code.claude.com/docs/en/headless.md#turn-off-permission-prompts-in-unattended-runs `--max-turns` errors when reached, and `--output-format stream-json` needs `--verbose`. https://code.claude.com/docs/en/cli-reference.md
- **AskUserQuestion** (V-4). It is removed from every subagent's tool pool, so only main-thread skills (`ship`, `init`, `resume`, `prompt`) ask, and agents return `needs_input` instead. No per-call limits and no recommended-option marker are documented, so aew lists the recommended answer first with a label ending ` (recommended)` and batches by the schema the model sees; `Other` is added automatically. With `--permission-prompts none` the tool is absent, so gates are left pending (§9; G2.3 at the plan gate and G1.2 at the spec gate, `tests/agent-smoke/README.md` §9.5 and §9.8). https://code.claude.com/docs/en/tools-reference.md#askuserquestion-tool-behavior
- **Plugin versions** (V-6). `claude plugin list --json` prints `[{id: "<name>@<marketplace>", version, installPath, …}]` and `~/.claude/plugins/installed_plugins.json` records the same. For a git source `version` may be a 12-character commit SHA, which `ship`'s superpowers check reports as not comparable. https://code.claude.com/docs/en/plugins/loading.md#find-plugins-on-disk, https://code.claude.com/docs/en/plugins/cli-reference.md
- **Local install loads in place.** A plugin whose `source` is a relative path in a local-directory marketplace (aew's `./`) is not copied to the plugin cache: "the plugin loads in place from its path inside the marketplace folder. Your edits to the source directory take effect at the next session start or `/reload-plugins`, and you don't need to increase the version." So a user-scope install from this checkout runs whatever branch is checked out, and committed fixes need no `marketplace update` or `plugin update`. https://code.claude.com/docs/en/plugins/loading.md
- **Plugin dependencies at run time.** Disabling a plugin's dependency in `enabledPlugins` stops the dependent plugin loading (headless harnesses must disable only unrelated plugins). `claude plugin validate` does not check agent frontmatter, so agent fields are verified by running the agents.
- **context7 tool names.** Assumed `mcp__plugin_context7_context7__*` (context7 is a dependency plugin, not an `aew` server). Unverified: without `CONTEXT7_API_KEY` the server reports `needs-auth` in headless runs, no call was made, and the agents fall back to the seeds as designed.
- **Models.** Valid `model` values are `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit`.
- **Nesting.** Subagents can spawn subagents, up to depth 3. In this design: orchestrator (main thread, depth 0) → developer (1) → sub-developers (2). To spawn, `Agent` must be in the agent's `tools`. An `Agent(type)` restriction list is ignored in a subagent definition, so a sub-developer is kept from spawning by its prompt, not its frontmatter.
- **Worktree isolation.** `isolation: worktree` (in frontmatter or on the Agent call) branches from the repo's default branch, not the caller's HEAD, unless the user sets `worktree.baseRef: "head"`. Its path and branch naming are undocumented, it is auto-cleaned only when unchanged, and nothing is merged back. So aew does not use it, and the developer creates its worktrees with `git worktree add`. Observed in run 961 (Claude Code 2.1.308): a sub-developer spawned by the developer fires `SubagentStop` with `agent_type` `aew:developer` and its own `agent_id` (so the developer gate runs for it as well, against the main run dir), and `last_assistant_message` carries its ARTEFACTS line. The Bash tool also refuses any `cd <dir> && git …` command (it cannot be allowlisted), so a sub-developer runs git as `git -C <worktree> <subcommand>` and other commands as `cd <worktree> && <command>`.
- **Search tools.** On macOS, Linux and WSL `Glob` and `Grep` are not in the default tool set; Claude searches with `find` and `grep` through Bash instead (code.claude.com/docs/en/tools-reference). A subagent that lists `Glob` or `Grep` in `tools` and leaves out `Bash` gets them back for that subagent only (/en/sub-agents). So agents with Bash (standards-setter, senior-engineer) do not list them and search with `find`/`grep`; agents without Bash (spec-analyser, brief-compiler, doc-writer) list `Glob, Grep`. A built-in set of read-only Bash commands (`ls`, `cat`, `head`, `tail`, `grep`, `find`, `wc`, `diff`, `stat`, read-only `git`) runs without a permission prompt in every mode, but `find` with `-exec`, `-delete` or `-fprint` prompts (/en/permissions).
- **SubagentStop payload.** `SubagentStop` carries `agent_type`, `agent_id`, `agent_transcript_path`, `last_assistant_message` and `stop_hook_active` (code.claude.com/docs/en/hooks). The nested-subagent behaviour observed in run 961 is under Worktree isolation above.
- **Bash tool and permission rules.** A trailing `&` in a Bash command is refused in headless runs, so background processes start with the Bash tool's `run_in_background: true` and no `&`. `nohup` is stripped before permission rules are matched, so `Bash(sh -c *)` is what matches a `nohup sh -c …` start. A trailing ` *` also matches the bare command, but only when it is the rule's only wildcard. A `Skill` call (`aew:ui-qa`) works headless without an allow entry. Rule matching (V-7): `*` matches any text anywhere, and `Bash(git commit *)` matches the bare command too. In a compound command (`&&`, `||`, `;`, pipes, `$(…)`, subshells) every part must match an allow, while deny and ask apply when any part matches. Leading env assignments are skipped for allows only when the variable is known-safe (for deny and ask, any assignment). `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob` and bare `xargs` are stripped; `npx` and `docker exec` are not. `git -C <dir>` and `git -c k=v` are not normalised, so `Bash(git <sub> *)` never matches them. Precedence is deny, then ask, then allow, first match wins. Deny rules are not a security boundary around a program, so aew's enforcement stays its Bash guard hook (§11), and `init`'s proposal uses anchored per-subcommand allow rules only (no deny rules, no `commands.seed` rule, which may reset data), written to the committed `.claude/settings.json` (portable rules) and the gitignored `.claude/settings.local.json` (James's decision at plan review: plugin scripts by absolute machine path, added to `.gitignore` only on a yes and only when `git check-ignore` says it isn't already ignored). The local file also carries `Read(//<plugin root>/**)`, because a headless run denies reading the plugin's references and templates outside the working directories (recorded deviation, prompt 07: S2's first headless run stopped at preflight; https://code.claude.com/docs/en/permissions). Rules reduce prompts; they are not a security boundary. An existing settings file that isn't valid JSON is left untouched and reported as not merged. https://code.claude.com/docs/en/permissions.md
- **Headless permission pre-checks** (Claude Code 2.1.308; probes RULES.1 and RULES.2 and the first P0, `tests/agent-smoke/README.md` §9.9). Under `--permission-mode acceptEdits --permission-prompts none` some Bash forms are denied before any allow rule is consulted; interactively each one prompts every time. So every command a skill runs follows these rules (James's decision: rewrite the skills inline, no new scripts):
  - H1 no shell parameter expansion (`$VAR`, `"$VAR"`, `$?`, loop variables) outside single quotes; `${CLAUDE_PLUGIN_ROOT}` and `$ARGUMENTS` are substituted at load. H2 no `$(…)` or backticks: run the inner command, then write its output literally into the next one.
  - H3 jq `--arg`/`--argjson` go after the filter (before it, the filter is path-checked as a file); H4 their values are plain tokens; H5 no jq `--slurpfile`, `--rawfile`, `-f`, `-L`, `system(`, `include` or `import`.
  - H6 heredoc delimiters are quoted (`<<'EOF'`); H7 no brace expansion; H8 no awk `system(`, `| "cmd"`, `getline` or `@load`.
  - M1 no `VAR=value cmd` prefix; M2 every leading form either runs without a rule or has one in `init`'s templates (otherwise it is denied as "requires approval"). The exceptions are the forms `init` deliberately leaves unapproved (`awk`, `node -p` and the `npx … ajv validate` line; `skills/init/references/permissions.md` `## Deliberately not pre-approved`): they prompt interactively, and a headless run must allow them itself, as the smoke lanes do (`tests/agent-smoke/README.md` §9.2).
  - An exact allow rule overrides the variable check, but not the jq path or dangerous-flag checks. A pipe inside an `if` or `while` condition is denied as a compound whose parts need approval (I1.1; the cause is inferred from the denial text, and I1.2 ran clean once the pipes left the conditions).
  - `tests/scripts/skills.bats` test 17 ("every skill command is pre-approvable headless") checks H1 to H8, M1 and pipes in conditions over the entry skills and the `references/` of `ship`, `ship-milestone` and `init`; M2 is checked per smoke lane against its allow file (§9.2).
- **Silent false checks.** In Claude Code 2.1.308 a false `test` or `[ … ]` returns `(Bash completed with no output)` with `is_error` false, exactly what a true one returns (only the stream's `returnCodeInterpretation` and the debug log differ, and the model sees neither). In G2.2 the model read a false `test -e` as true. So every check the model acts on prints its outcome (`test -e <path> && echo exists || echo absent`), which `skills.bats` test 18 enforces.
- **Headless session facts** (`tests/agent-smoke/README.md` §9). The Bash tool keeps the launching environment: the `gh` shim first on `PATH`, unset token variables and `GH_HOST` all held inside the session (P0a.2 checks 1 to 3). `system/init` lists plugin agents as `aew:<agent>` beside the built-ins (P0b.2 check 10). A `-p` session killed with SIGTERM emits no `result` event, so its cost is unknown (F1.1, R2.1); on SIGINT it ends the turn, exits 0 and does emit a `result` (`error_during_execution`, with its real cost; prompt 07 S7.1). In a headless stream a `SessionStart` hook's `additionalContext` arrives as a `system` event with `subtype` `hook_response`, inside its `output` (prompt 07 S7.2). `--max-budget-usd` works only with `--print`; an interactive session's cost is the `/usage` total (V-8). User-level MCP connectors (claude.ai connectors, notion) load into `-p --plugin-dir` sessions; a deny rule naming the server (`mcp__<server>`) removes all its tools while `mcp_servers` still lists it (G2.3's `system/init` had the tools; S1.1, F1.1, R2.1 and G1.2, with the denials, had none). `--max-budget-usd` counts subagent spend, and the main thread, told its remaining budget, may stop itself before the cap: G1.1 paused at `plan` with about $1.07 of $3 left, which `ship` does not describe.
- **Skills in agents.** `skills:` frontmatter preloads full skill content into an agent. Agents can still invoke other skills with the Skill tool. Up to 32 skills can be preloaded, and a skill with `disable-model-invocation: true` cannot be. **A missing skill is skipped silently** (debug-log warning only), so verify preloads with `--debug-file`. Qualified plugin skill names preload, including dependency skills (`aew:run-protocol`, `superpowers:systematic-debugging`); the debug log shows `Preloaded skill '<name>'` (confirmed in headless smoke runs).
- **Agent memory.** `memory: project` gives an agent `.claude/agent-memory/<plugin>-<agent>/MEMORY.md` (for a plugin agent the directory is `aew-<agent>`, for example `aew-spec-analyser`, confirmed in a headless run). The first 200 lines or 25 KB are loaded. Memory scopes are `user`, `project` and `local`; any memory scope automatically enables Read, Write and Edit for the agent, and has no effect when auto memory is off.
- **Dependencies.** Each `dependencies` entry in `plugin.json` is `"name"`, `"name@marketplace"` or `{ name, marketplace, version }`. A `version` range resolves only against git tags named `<plugin>--v<version>` on the repo the dependency's `source` in `marketplace.json` points at (its own repo for a `github`, `url` or `git-subdir` source; the marketplace repo for a relative path such as aew's `./`, so aew's tags go on this repo); with no matching tag, installing a dependency that has its own repo fails. `claude plugin tag` creates the tag. https://code.claude.com/docs/en/plugins/dependencies.md Cross-marketplace dependencies need `allowCrossMarketplaceDependenciesOn` (an array of marketplace names) in the root marketplace's `marketplace.json`.
- **Skill visibility.** `user-invocable: false` hides a skill from the `/` menu while Claude and agents can still use it. `disable-model-invocation: true` is the reverse: the user can invoke it, but Claude won't load it on its own. It also removes the skill from Claude's context and blocks a Skill-tool call to it, so `resume` and `prompt` reuse `ship` by reading its files with Read, never through the Skill tool (V-1).
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
| Playwright MCP | plugin `.mcp.json`: `npx --yes @playwright/mcp@0.0.83 --headless --isolated` (exact version) | Exploratory UI checks by QA (§8.6). `claude-plugins-official` ships a `playwright` plugin (by Microsoft), but it is only an unpinned `npx @playwright/mcp@latest` `.mcp.json` with no skill, so it covers neither §8.6 (that is the `ui-qa` skill) nor the pinning rule. aew bundles its own pinned server instead (decided 24 Oct 2026). `--headless` because QA runs unattended; `--isolated` so no browser profile or login state persists between runs. If the official plugin is also enabled, both servers run under different tool prefixes. The server drives the MCP's default browser channel, the installed Google Chrome (verified 24 Oct 2026). |

- **Why superpowers has no version range.** obra/superpowers tags releases as `v<version>`, not `superpowers--v<version>`, so a range such as `^7.0.0` can't resolve and the install would fail. The official marketplace pins superpowers to a commit (v7.0.0 on 24 Oct 2026), so the dependency only moves when that pin moves. The plugin is built and tested against superpowers 7.x. `ship`'s preflight warns, never blocks, when the installed major isn't 7 or the version is a commit SHA (`skills/ship/references/preflight.md`). Add a range once upstream publishes `superpowers--v*` tags.
- **Playwright packages.** Plugin MCP servers start with the plugin, so every session with aew enabled runs one `npx @playwright/mcp` process (the first run downloads it). The test packages are not in the plugin: `ui-qa` setup exact-pins `@playwright/test@1.64.1` and `@axe-core/playwright@4.14.0` in the target project and installs Chromium with `npx playwright install chromium`.
- **CLI prerequisites:** git, gh (authenticated), jq, Node ≥ 20, plus stack tools as needed (php/composer, dotnet, Docker for wp-env or ddev).
- **GitHub access:** the `gh` CLI only, wrapped by plugin scripts. No GitHub MCP. The one direct call is the read-only `gh auth status` in the `ship` and `init` preflights (no script wraps it; a recorded deviation, prompt 05). Newer `gh` may exit non-zero from it when any configured host is unhealthy, so preflight quotes gh's own output when it stops.

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
- `guard`: `{ allow_paths: [] }`: committed, non-secret files the edit guard would refuse (for example `.env.test`, `.npmrc`), as repo-relative paths (§11)
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
| `issues/<k>/` (bulk only: per issue `issue.json`, `00-issue-original.md`, `01-spec-analysis.md`, `spec-final.md`, `spec-changes.json`, `spec-revision-v<N>.md`) | as for the root files |
| `index.json` (sequential only: `order`, each child's `stack_on` and milestone status) | `state.sh index` only |
| `milestone-report.md` (milestone runs) | orchestrator, with Write |

A sequential run's children are ordinary runs `.aew/runs/<k>/` beside `m-<n>`, linked by the index and by the child's history note `milestone m-<n>`. A bulk issue's spec version is the history note `spec revision: #<k> v<N>` (no schema change).

`.aew/runs/current` holds the active run id. Hooks use it.

Flat files directly under `.aew/runs/` are scratch, not runs: init's `init-*` files and ship's blocked comment `blocked-<id>.md` (written with Write, posted with `gh-issue.sh comment`). `status` lists only directories named like a run id.

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
- **Does:** finds gaps, ambiguities, contradictions, missing ACs and edge cases. Covers non-functional needs (accessibility, performance, security, privacy, i18n). Detects UI changes and checks testability. ACs state behaviour; how a criterion is tested is QA's test plan (prompt 07, S4).
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
- **Init mode.** `/aew:init` dispatches it with `mode: init` and no run dir. There is no brief, so it skips the brief and `03-standards.md`, writes or reuses `docs/standards/` as above (nothing changes when every fingerprint matches), and puts its return block in its final message only. This settles §5.1's "init generates the first standards docs" against the run-dir inputs above (Conflict C3, prompt 05).

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
- the environment develop needs (runtimes with their major version, commands on PATH, a running Docker), in line forms `scripts/check-env.sh` checks (§9);
- risks;
- an AC→WP traceability matrix.

**Revision notes.** An optional `notes` dispatch field carries James's change requests from the plan gate, or the developer's `blocked` reason. The senior engineer reads the existing `05-plan.md`, rewrites it, and ends `## Approach` with `Revision notes:`, one line per note saying what changed or why not. A note that needs a material spec change becomes a challenge (`needs_input`).

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
- Before finishing each work package, runs lint, format, typecheck and unit tests from config. After the last work package, and in fix mode, it also runs the build from config once on the feature branch: no other stage builds the project (recorded deviation, prompt 07: S3's summary flagged that the build had never run).
- Commits per work package using conventional commits, with `(#issue)`. Every commit aew makes (agents and orchestrator) ends with the one trailer `Co-Authored-By: Claude <noreply@anthropic.com>`, with no model name, whatever attribution line the session asks for (James's decision, 2026-10-26).
- Code is readable, simple and documented: doc comments on public functions, and comments that explain why rather than what.
- **Fan-out.** If at least two work packages are marked parallelisable and own disjoint files, it spawns sub-developers:
  - the same agent type, in "package mode", one work package each;
  - each in its own git worktree;
  - at most `max_parallel_developers` at once;
  - then it integrates their commits into the feature branch one at a time and reruns all checks.

  Otherwise it works sequentially.

  The developer creates each worktree itself from the feature-branch HEAD (`git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`) and dispatches the sub-developers without `isolation` (§3). It integrates each work package's single commit with `git cherry-pick` in WP-number order, removes the worktrees and WP branches, and only then reruns the checks.
- **Deviations.** If a plan step is impossible or clearly wrong, it stops that work package and returns `STATUS: blocked` with the reason. The orchestrator routes this to the senior engineer. It never diverges silently.
- **Environment blocks.** The report's `Block cause:` line tells a plan block from an environment block: a stopped service or daemon, a missing tool or wrong runtime version, a missing credential, a guarded file or no network. In full mode an environment block pauses at the `environment` gate (fix and continue, re-plan, or stop) instead of spending the run's one re-plan, and a sequential work package it interrupted is left uncommitted and picked up by the next full-mode dispatch (#51).
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
  - `## In plain English` first, before `## Summary`, written last so it summarises what is actually there:
    - 100-250 words for a single issue, aiming for about 200; for a bulk PR an opening paragraph plus at most about 80 words per issue, aiming for about 60 (prompt 07, S6: drafts ran over the limit);
    - in order: what was asked and why (naming "issue #12" in words); what changed for a user of the product; how it was done, including any obvious alternative the plan rejected; what changed along the way (confirmed spec clarifications, saying what the issue left open and what James decided at a gate; decisions taken on James's behalf; any new dependency, runtime or development; any decision the plan left for the plan gate that went ahead unapproved because `--auto` skipped it; deviations from the issue; recorded deviation, prompt 07: S2 and S3); what needs attention (manual tests, risks, limitations, omissions, or one line saying none); confidence in one line;
    - plain words and short sentences; no file paths, function or variable names, code, backticks or AC/TC/WP ids; no tables or headings inside, at most one short list; unavoidable technical terms explained in passing; no restating of the technical sections; real facts only;
    - variants: stacked (says it builds on the PR for issue #n and must be merged after it), bulk (opening paragraph, then one short paragraph per issue), `init` (what was set up and why, what to check, such as detected commands and permissions, and what happens next);
    - checked by `scripts/check-pr-intro.sh` (§9);
  - a summary and an AC checklist;
  - test results;
  - screenshots linked via `blob/<branch>/…?raw=true`;
  - manual tests;
  - `Closes #n` for every issue in the run.
- **`retro.md`:** improvements to the plugin seen during the run (agent mistakes, missing rules, slow stages, cycles used, false-positive hooks). The orchestrator files these to the retro repo. They never go in the project repo.

The doc-writer has no Bash and doesn't commit. The orchestrator commits its docs after the stage, as it does `docs/standards/` (prompt 05; this overrides the build prompt's "the doc-writer commits", Conflict C1).

## 9. Orchestrator (`ship` skill)

Runs on the main thread.

- **Preflight:**
  - config exists (if not, suggest `init`);
  - the working tree is clean;
  - gh is authenticated;
  - the default branch is up to date with `origin`: checked after a fetch and never fast-forwarded; behind or diverged stops with a `git pull` hint (preflight writes nothing);
  - the superpowers major version (warning only);
  - no other active run is in progress (unless resuming).
- **Steps:**
  - initialise state (this creates the run dir);
  - fetch the issue into it (Conflict C4: the fetch needs the run dir);
  - set labels;
  - create the branch;
  - dispatch agents with explicit input paths;
  - run QA phase A and planning in parallel (one message, two Agent calls);
  - handle gates and routing;
  - push the branch (never the default branch);
  - check the PR introduction with `scripts/check-pr-intro.sh <pr-body.md> [--issues <n>]`: on failure, re-dispatch the doc-writer once with the check's output; if it still fails, carry on and note the failure in the final report and the retro (the introduction never blocks a PR);
  - create the PR;
  - file the manual tests and retro items;
  - give the final report.
- **Gates:**
  - A material spec change always gets a gate, even with `--auto`. It uses AskUserQuestion with recommended answers.
  - Plan approval is on by default. `--auto`, or `gates.plan_approval: false`, skips it. James sees a plan summary of 25 lines or fewer plus the file path, with the options approve / request changes / stop.
  - Irreversible or destructive operations always get a gate.
  - A developer blocked by the environment in full mode gets the `environment` gate, even with `--auto`: fix and continue (the re-plan allowance is kept), re-plan, or stop.
  - **Environment check (#44, #50).** `scripts/check-env.sh <05-plan.md>` checks the plan's `## Environment` lines (`- tool: <command> [<major>]`, `- service: docker`) and its `Owner hand-off:` files (they must exist or be in `guard.allow_paths`). Its `FAIL:` lines go into the plan-approval summary, and it runs again before every D8 dispatch, so `--auto` runs are covered: a failure is the `environment` gate (fixed, continue / continue without the check / stop).
  - **Unanswered gate.** When AskUserQuestion is unavailable (headless runs with `--permission-prompts none`), refused or answered empty, the gate stays pending: state and label are already set, ship prints the questions (or the plan summary and path) and `Answer with /aew:resume <id>`, and stops; nothing after the gate runs. `init` instead uses its recommended defaults and writes no settings.
- **Every completed run ends in a PR:** single-issue runs, bulk milestone runs, each sequential-milestone child and `init`. Blocked runs open none and keep their behaviour: a report comment, the blocked label, and a stop. A resumed or re-run run updates the existing PR and rewrites its `## In plain English` section to match the final state, never appending a second one. Issue bodies and comments carry no such introduction.
- **Resume:** reads `state.json`, verifies the branch and working tree, and continues from the recorded stage. `resume` reads `ship`'s files with Read and enters at the recorded stage's section.
- **Context hygiene:** reads return blocks only. It opens artefacts only for gates and routing. The exact reads (the plan in full at the plan gate, and bounded section reads for the gates and QA routing) are the reads table in `skills/ship/SKILL.md` `## What the orchestrator reads`.
- **Final report:**
  - outcome;
  - PR link;
  - ACs passed out of the total;
  - review and fix cycles used;
  - manual tests outstanding;
  - retro items filed.
- **Procedure detail.** The preflight order and messages, run start, `--from`, dispatch rows and return checks, gate steps, routing table, PR steps and final-report format are in `skills/ship/SKILL.md` and `skills/ship/references/` (`preflight.md`, `dispatch.md`, `gates.md`, `routing.md`, `pr.md`, `final-report.md`); this section doesn't restate them.
- **Recorded deviations (build prompt 05).** C1: the orchestrator commits the doc-writer's outputs (§8.7). C3: standards-setter init mode (§8.3). C4: state before fetch (Steps). C5: the simulated runs ship the static-shop fixture's issue #201, not issue 1 (`tests/agent-smoke/README.md` §9). The direct `gh auth status` (§4). A blocked prompt-mode run posts no report comment and sets no `aew:blocked` label, because prompt mode sets no labels (§7.3's blocked rule; Phase C PC-3). On a corrupt `state.json`, `status` names the corrupt file and still lists the other runs. The final report prints `ACs passed: n/a` when `10-summary.md` is absent or `stage` is not `pr`.
- **Prompt mode and resume.** `/aew:prompt` marks its run with the `history` note `prompt` (written before the fetch), and a run is a prompt-mode run when that note exists and `branch` is null; the one check is in `skills/ship/references/gates.md` and is used unchanged by `resume` and `status`. `resume` continues every mode: a bulk run like a single one, and a sequential run (or any of its children) at its first unfinished child, through `skills/ship-milestone/references/sequential.md`. `status` shows every mode, and a sequential run's children.

## 10. Milestone mode

`ship-milestone <milestone> [--bulk|--sequential] [--auto]`

Procedure detail: `skills/ship-milestone/` (`SKILL.md`, `references/mode-selection.md`, `bulk.md`, `sequential.md`); the deterministic part is `gh-milestone.sh select` and `state.sh index`.

**Mode selection.** If no mode is given, the orchestrator recommends one and asks James to confirm. It recommends **bulk** when all of these hold:

- 5 issues or fewer;
- each issue small (5 ACs or fewer by a quick count of the issue's acceptance-criteria list);
- the same area of the codebase;
- low risk;
- no blocking dependencies.

Dependency rules:

- A dependency blocks bulk unless it is a closed issue of this milestone.
- Order is Kahn's algorithm over the open in-milestone edges, lowest issue number first.
- A stacked child branches from the latest of its dependencies in `order`; two open dependencies that are not one chain stop a sequential run before anything is written.
- Stacking is decided without a `gh` call: a dependency shipped earlier in the run has an open PR, so its dependant stacks on its branch.
- aew never merges or retargets a stacked PR, so merge them in order.

Otherwise it recommends **sequential**.

**Bulk:**

- Spec analysis runs per issue in parallel. Each issue gets its own revision record and gate.
- One combined brief, with AC ids prefixed by issue (`#12-AC-1`).
- One plan, one branch (`milestone_branch_pattern`), one QA pass with traceability per issue.
- One PR that closes all the issues, opening with a bulk-variant introduction (§8.7).

**Sequential:**

- Issues are ordered by their dependencies: "Blocked by #n", "Depends on #n", and task lists. A dependency cycle stops the run and asks.
- Each issue runs through the single-issue pipeline (reuse `ship`'s procedure; don't duplicate it) and gets its own branch and PR.
- An issue that depends on an unmerged one branches from that issue's branch (a stacked PR), and this is noted in the PR, including in its introduction (the stacked variant, §8.7).
- The plan gate applies per issue unless `--auto`.
- The sequence stops on `blocked` and posts a milestone report.

**Recorded deviations (prompt 06).**

- **C1.** The AC count is the script's quick count of the issue body's acceptance-criteria list, not a spec analysis; the wording above replaces "once analysed". James confirmed this at plan approval on 2026-10-26.
- **C2.** A dependency cycle or stack conflict stops before any write and asks in its stop message, not through AskUserQuestion.
- **C3.** Bulk QA evidence goes to `docs/qa/m-<n>/` (not §6's `docs/qa/<issue>/`).
- **`select` wording.** The prompt's `gh-milestone.sh issues` fetch is the new `select` subcommand of the same script, which reuses its `gh` call.
- **C4.** The run dir gains `issues/<k>/` and `index.json` (§7.1), with no renamed artefact. The stacked PR carries the stacked introduction only, with no extra summary line.
- **AC-24 over AC-25.** AC-25 lets `preflight.md` gain only the bulk path overrides, but `preflight.md` `## Check 5. No other active run` also gains the two-way milestone exception that AC-24 requires, as one continuation line.
- **Developer clean tree (found by B1).** The developer's full and fix preconditions and its allowed-files check ignore paths under `.claude/agent-memory/`, like preflight's restart form and `resume`. Agents that run before `develop` may write memory, and ship commits it only at the docs stage, so without this the developer blocked every bulk run (and single runs whenever an early agent wrote memory). Outside the approved plan; James approved the fix and a B1 re-run on 2026-10-26.
- **QA ARTEFACTS are files (found by Q3).** The qa-engineer's return contract now says ARTEFACTS lists files only, never a directory, because ship checks each path with `test -f`; a run listed `docs/qa/<issue>/screenshots` and was blocked after two invalid returns.

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
- **`PreToolUse` on Edit and Write (guard).** Blocks writes to `.env*`, known secret files and `.git/`. A secret-file block is lifted for a path that `guard.allow_paths` lists, matched exactly against the path relative to the checkout holding it (the main one or a run worktree); `.git/` is never allowed. The deny reason tells the agent the owner can list the file or create it. The senior-engineer plans such a file only if it is listed, and otherwise names it as an owner hand-off in the plan's risks, which the plan-approval summary quotes. It may not cover `MultiEdit` or `NotebookEdit` (undocumented, see section 3). Shell writes to the same files (`>`, `tee`, `cp`, `mv`, `sed -i`) are not caught: the Bash guard does not track write targets, and the developer and QA Bash allowlists already exclude those commands (known limitation).
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
- The sandbox scenarios in build prompt 07 pass: init and S1 to S8 on 26 and 27 Oct 2026; S9 skipped because Docker was not running (`tests/e2e-validation.md`).
- The README covers install, prerequisites, commands, config reference, labels, troubleshooting and uninstall.

## 13. Later (not v1)

- A C#/.NET seed standard after the first real use.
- Headless or CI runs (`claude -p`, GitHub Actions).
- A one-way Notion mirror of `docs/specs/`.
- Agent teams, once they are stable.
