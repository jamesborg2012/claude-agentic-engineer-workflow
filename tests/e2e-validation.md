# End-to-end validation on real GitHub (build prompt 07)

The record of build prompt 07: the plugin installed for real, run against a private sandbox repo on real
GitHub, fixed where it broke, then released as 0.1.0. Spec:
[`docs/superpowers/specs/2026-10-26-e2e-validation.md`](../docs/superpowers/specs/2026-10-26-e2e-validation.md);
plan: [`docs/superpowers/plans/2026-10-26-e2e-validation.md`](../docs/superpowers/plans/2026-10-26-e2e-validation.md).

## Environment

Recorded 2026-10-26, before the install.

| Item | Value |
|---|---|
| Claude Code | 2.1.308 |
| gh | 2.103.2 (2026-10-23), `git_protocol` https |
| Node | v26.12.1 |
| Plugins at user scope before the install | `context7@claude-plugins-official 58267944f921`, `dev-workflow@jamesborg 1.0.0`, `figma@claude-plugins-official 2.2.157`, `frontend-design@claude-plugins-official 58267944f921`, `superpowers@claude-plugins-official 7.0.0`, `warp@claude-code-warp 2.4.0` (all enabled). aew not listed. |
| Docker | installed at `/usr/local/bin/docker`, daemon not running |

### Install checks (AC-2, AC-3)

| Check | Result |
|---|---|
| Plugin repo at install | `233eb13` on `feature/e2e-validation`, clean tree |
| `claude plugin marketplace add <repo>` | `✔ Successfully added marketplace: jamesborg-plugins (declared in user settings)` |
| `claude plugin install aew@jamesborg-plugins --scope user` | `✔ Successfully installed plugin: aew@jamesborg-plugins (scope: user)`; the three dependencies were already installed at user scope, so nothing else was pulled in |
| `installPath` | `/Users/jamesborg/.claude/plugins/cache/jamesborg-plugins/aew/0.1.0`, a copy of the working tree at install time (untracked files such as `.idea/` included), recorded with `gitCommitSha` `233eb13…`. The docs (V-3) say a relative-path plugin from a local marketplace loads in place from the source directory; the install probe (A7) shows which path a session actually loads. |
| User-scope list after the install | `aew@jamesborg-plugins 0.1.0 true user`, `context7@claude-plugins-official 58267944f921 true user`, `frontend-design@claude-plugins-official 58267944f921 true user`, `superpowers@claude-plugins-official 7.0.0 true user` |
| Isolated proof, attempt 1 (`CLAUDE_CONFIG_DIR=$E2E/iso-config`, empty: `[]`) | marketplace added; install warned `dependency "superpowers@claude-plugins-official" was not installed (no marketplace you have added lists it)` (likewise context7 and frontend-design) `"aew" will not load without them`. As V-2 says, a fresh config does not know `claude-plugins-official`. |
| Isolated proof, attempt 2 | `claude plugin uninstall aew@jamesborg-plugins -y`, `claude plugin marketplace add anthropics/claude-plugins-official` (plugin list still empty), then aew alone: `✔ Successfully installed plugin: aew@jamesborg-plugins (scope: user) (+ 3 dependencies: superpowers, context7, frontend-design)`. List: aew 0.1.0, context7 58267944f921, frontend-design 58267944f921, superpowers 7.0.0, all `true user`. No login was needed. |
| Real config untouched by the isolated proof | `claude plugin list --json \| shasum` `6f13a16a…` before and after; the isolated config was then removed |

### Install probe (AC-4)

`e2e-run.sh <sandbox> probe.1 0.50 allow-probe.txt 'Reply with the single word OK. Do not use any tools.'` with
`--model haiku`, 2026-10-26T17:13Z. Evidence from `system/init`:

| Check | Result |
|---|---|
| Exit, reply | `0`, `OK` |
| aew slash commands | `aew:init`, `aew:prompt`, `aew:resume`, `aew:ship`, `aew:ship-milestone`, `aew:status` |
| aew agents | `aew:brief-compiler`, `aew:developer`, `aew:doc-writer`, `aew:qa-engineer`, `aew:senior-engineer`, `aew:spec-analyser`, `aew:standards-setter` |
| `plugin:aew:playwright` | `connected` (`plugin:context7:context7` is `needs-auth`, as before: no `CONTEXT7_API_KEY`) |
| Plugins loaded | superpowers, context7, frontend-design (cache paths), **aew from `/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow`**, plus three built-ins. dev-workflow, figma and warp are absent, so the sandbox's `.claude/settings.local.json` `false` entries beat the user-scope enables (AC-8, V-13). |
| Where aew loads from | the checkout, not the recorded `installPath`. `claude plugin update aew@jamesborg-plugins` agrees: `aew is read from its folder, … nothing to update. Edits there take effect at the next session start or /reload-plugins.` (V-3; DESIGN §3 "Local install loads in place"). Consequence for this validation: every session runs the plugin repo's checked-out branch, so a committed fix is live at the next session, and the checkout never switches branch while a session runs. |
| Permission mode, model | `acceptEdits`, `claude-haiku-5-5` |
| Cost | $0.0034 (cap $0.50) |
| Audit, git guard, plugin HEAD, gh config dir | clean (0 tool uses), unchanged, unchanged, empty |

## Platform facts

Checked against code.claude.com/docs on 2026-10-26 through one batched claude-code-guide dispatch (A1); "CLI help"
means the local `claude … --help` output of 2.1.308. "Not documented" is never filled in by inference.

| V | Question | Answer (quote) | Doc URL | Checked | DESIGN impact |
|---|---|---|---|---|---|
| V-1 | Marketplace add and user-scope install syntax; scope values | `claude plugin marketplace add [options] <source>` (a path starting `./`, `../` or `/`); `claude plugin install <plugin>@<marketplace> --scope user`. CLI help: "-s, --scope <scope> Installation scope: user, project, or local (default: "user")". Docs: "`--scope` takes `user`, `project`, or `local` … `update` also takes `managed`." | https://code.claude.com/docs/en/plugins/cli-reference.md | 2026-10-26 | none |
| V-2 | Cross-marketplace dependency auto-install; isolated proof; `CLAUDE_CONFIG_DIR` | Installed only when the root marketplace's `allowCrossMarketplaceDependenciesOn` names the target: "If `allowCrossMarketplaceDependenciesOn` is missing or doesn't include the target marketplace, Claude Code doesn't install the dependency." `CLAUDE_CONFIG_DIR`: "Claude Code then stores your settings, session history, and plugins there instead." A fresh config may lack the official marketplace: "on a machine where no one has opened an interactive Claude Code session yet, the official marketplace isn't registered". A clean-state proof procedure and whether `CLAUDE_CONFIG_DIR` needs a login: not documented (proved by running, A2). | https://code.claude.com/docs/en/plugins/dependencies.md, https://code.claude.com/docs/en/settings.md, https://code.claude.com/docs/en/plugins/install.md | 2026-10-26 | none |
| V-3 | How a local-directory marketplace plugin is cached; how changes are picked up | A relative-path plugin in a local marketplace is not copied: "the plugin loads in place from its path inside the marketplace folder. Your edits to the source directory take effect at the next session start or `/reload-plugins`, and you don't need to increase the version." Copied plugins: `marketplace update` then `plugin update`; an unchanged computed version leaves the cache as it is. `installPath` on reinstall: not documented. | https://code.claude.com/docs/en/plugins/loading.md, https://code.claude.com/docs/en/plugins/install.md | 2026-10-26 | §3 gains "Local install loads in place" |
| V-4 | Dependency tag format and the repo it is read from | "Tag each release as `<plugin-name>--v<version>`, where `<version>` matches the `version` field in that commit's `plugin.json`." Tag "the repository that the plugin's plugin source in `marketplace.json` points at": for a relative-path source, the marketplace repo. CLI help: `claude plugin tag` "Create a {name}--v{version} git tag for a plugin release". | https://code.claude.com/docs/en/plugins/dependencies.md, https://code.claude.com/docs/en/plugins/cli-reference.md | 2026-10-26 | §3 Dependencies: which repo carries the tag |
| V-5 | What `--bare` disables; login; with `-p`; a plugin-less alternative | `--bare` skips hooks, plugin sync, auto-memory, keychain reads and `CLAUDE.md` auto-discovery, and "Anthropic auth is strictly ANTHROPIC_API_KEY or apiKeyHelper via --settings (OAuth and keychain are never read)" (CLI help), so it does not work with a claude.ai login. It combines with `-p`. `--safe-mode` disables "CLAUDE.md, skills, plugins, hooks, MCP servers" with normal auth. Per plugin: `enabledPlugins` `false`. | https://code.claude.com/docs/en/headless.md, https://code.claude.com/docs/en/cli-reference.md | 2026-10-26 | none (decides S8's profile, Phase D) |
| V-6 | How a plugin MCP server shows as connected | "The `system/init` event reports session metadata including the model, tools, MCP servers, and loaded plugins"; plugin servers register as `plugin:<plugin-name>:<server-name>`. The full `status` enumeration and whether `claude mcp list` includes plugin servers: not documented. | https://code.claude.com/docs/en/headless.md, https://code.claude.com/docs/en/mcp.md | 2026-10-26 | none |
| V-7 | Where SessionStart `additionalContext` appears in a headless stream | Runtime: recorded from Phase B's headless `/aew:status` stream (Cut 1). Docs: SessionStart hook lifecycle events are always in stream-json; where `additionalContext` appears is not documented. | https://code.claude.com/docs/en/hooks.md, https://code.claude.com/docs/en/cli-reference.md | 2026-10-26 | pending (Phase B) |
| V-8 | `--max-budget-usd` interactively; reading an interactive session's cost | CLI help: "--max-budget-usd <amount> Maximum dollar amount to spend on API calls (only works with --print)". Interactive cost is the `/usage` Session block "Total cost": "Claude Code computes the dollar figure locally from token counts at list price". `/cost` is not on the costs page. | https://code.claude.com/docs/en/cli-reference.md, https://code.claude.com/docs/en/costs.md | 2026-10-26 | none (attended sessions are capped by James reading `/usage`) |
| V-9 | `claude -p` and SIGINT | "To end the turn instead, send SIGINT, or call the Agent SDK's `interrupt()`, before you stop the process." SIGTERM "exits with code 143". The `-p` exit code after SIGINT and subagent cancellation: not documented. | https://code.claude.com/docs/en/headless.md | 2026-10-26 | none (the launcher sends INT, then TERM, then KILL) |
| V-10 | gh token precedence, git credential helper, PAT scope, `gh issue transfer` | Proved by running: A6 canary (`GH_TOKEN` precedence, `gh auth git-credential` with an empty `GH_CONFIG_DIR`); `gh issue transfer` in Phase F (Cut 6). | n/a (gh) | 2026-10-26 | none |
| V-11 | gh milestones; `gh repo create --private --source --push` | Proved by running: A3 (`gh repo create aew-sandbox --private --source … --remote origin --push` created the repo and pushed `main`); milestones in Phase B (Cut 6). | n/a (gh) | 2026-10-26 | none |
| V-12 | Uninstall commands and cache clean-up | `claude plugin uninstall <plugin> [-s user\|project\|local] [--keep-data] [--prune] [-y]`; `claude plugin marketplace remove <name>`: "When you remove a marketplace from the last scope that declares it, Claude Code also deletes its cache and uninstalls every plugin you installed from it." Old version directories get an `.orphaned_at` marker and go "14 days later". Auto-installed dependencies stay until `claude plugin prune`. | https://code.claude.com/docs/en/plugins/cli-reference.md, https://code.claude.com/docs/en/plugins/loading.md | 2026-10-26 | none (README uninstall, Phase F) |
| V-13 | Does a project `.claude/settings.local.json` `enabledPlugins` `false` override a user-scope enable? | Yes: "For each plugin id, the value that applies is the one from the highest-precedence source that mentions the id." "To opt out of a project-enabled plugin on your machine, set the id to `false` in `.claude/settings.local.json`". Order, lowest first: `--add-dir`, user, project, local, flag, managed. | https://code.claude.com/docs/en/plugins/loading.md, https://code.claude.com/docs/en/settings.md | 2026-10-26 | none (runtime proof: A7) |

## Rails and launchers

Outside the repo and never committed: `/Users/jamesborg/Documents/Development/aew-e2e` (mode 700) holds
`e2e-run.sh`, `e2e-session.sh`, `selftest.sh`, `canary.sh`, the PAT file `.pat` (written by James, mode 600), the
empty gh config dir `ghcfg/`, the ledger `ledger-07/`, `audit-allow.json` (`[]`) and the session outputs `out/`.

**Interface** (one for every phase):

```text
e2e-run.sh <project> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]   # headless; <kill-stage> may be <run-id>:<stage>
e2e-run.sh --env-check <project> <command> [<arg>...]                                  # free: one command in the session environment
e2e-run.sh --attended <project> <run> <cap>   (= e2e-session.sh <project> <run> <cap>)   # interactive; James runs it
```

It is the `tests/agent-smoke/README.md` §9.2 reference launcher with the §10.2 kill form and these changes:

- **Preconditions** (refuse, exit 2): the project is a git work tree outside the plugin repo whose only remote,
  `origin`, matches `^https://github\.com/jamesborg2012/aew-sandbox(-[a-z0-9]+)?(\.git)?$`; `ghcfg/` exists and is
  empty; `.pat` is non-empty, mode 600 and owned by `$USER`; the real `gh` is on `PATH`. The mock-shim and bare-origin
  checks are gone.
- **Changed environment lines** (the session environment; the PAT is read once inside the script and never printed):

  ```text
  env -u <every inherited GIT_* variable> -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN -u GH_HOST -u SSH_AUTH_SOCK
      -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID
      GH_TOKEN=<from $E2E/.pat> GH_CONFIG_DIR="$E2E/ghcfg"
      GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=
      GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1="!/opt/homebrew/bin/gh auth git-credential"
      GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND=false
  ```

  Removed from §9.2: `PATH="$SHIM:$PATH"`, `GH_MOCK_DIR`, `GH_HOST=aew-smoke.invalid`. The inherited `GIT_*` unset was
  added after the self-test found `GIT_EDITOR` passing through.
- **Session flags.** Dropped `--plugin-dir`, `--add-dir` and `--settings`: sessions load the installed aew (which reads
  the checkout in place, as the probe shows), and the sandbox's gitignored `.claude/settings.local.json` disables
  dev-workflow, figma and warp. Kept stream-json, `--verbose`, `--forward-subagent-text`, `--include-hook-events`,
  `--max-budget-usd`, `--debug-file`, `--permission-mode acceptEdits --permission-prompts none` and `< /dev/null`.
- **Fixed denies appended by the launcher**, so no allow file can drop them: `--disallowedTools Bash(git push *)
  Bash(git reset *) Bash(git checkout *) Bash(git add -A*) Bash(git add .) Edit(//<plugin repo>/**) mcp__notion
  mcp__claude_ai_Claude_Docs mcp__claude_ai_Google_Drive mcp__claude_ai_Gmail mcp__claude_ai_Google_Calendar
  mcp__claude_ai_Figma`. Attended sessions get the same list.
- **Effective allow rules (CTO C-1).** Before every session the launcher reads the allow rules of user scope
  (`~/.claude/settings*.json`, empty `[]` today), the project's `.claude/settings.json` and `settings.local.json`, and
  the allow file, and refuses any `gh` rule other than exactly `Bash(gh auth status)`, any `git push` rule, and any
  interpreter or wildcard rule (`node`, `sh`, `bash`, `zsh`, `env`, `python*`, `npx *`, `curl *`, bare `Bash`,
  `Bash(*)` and other all-wildcard forms), with or without a leading path (`/bin/sh`, `/opt/homebrew/bin/gh`). Because
  claude splits a rule list on commas and spaces, any line that mentions `Bash` must be exactly one rule, so
  `Bash(npm *),Bash(gh *)` and `--allowedTools=Bash(gh *)` are refused too. An allow file may not set
  `--disallowedTools`, a permission mode or a launcher flag.
- **Kill.** SIGINT first (V-9: it ends the turn), TERM after 30 s, KILL after a further 30 s; `killed-at` records the
  time and the signal that ended it. The session starts as a job-controlled background job (`set -m`) so it keeps
  SIGINT, which a plain non-interactive `&` job ignores.
- **Audit (C3 as amended by CTO C-2).** After every session, every `tool_use` on every thread (headless: the stream;
  attended: the session's transcript files under `~/.claude/projects/<sandbox>/` written since the start, main and
  subagents). Bash commands are checked for the credential set
  `GH_TOKEN|GITHUB_TOKEN|GH_HOST|GH_CONFIG_DIR|GH_ENTERPRISE|auth token|git-credential|osxkeychain|security find-|GIT_CONFIG|GIT_ASKPASS|credential fill|credential\.helper|find-(generic|internet)-password|\.config/gh|env -i`,
  the spawn pattern ``(exec|spawn|popen|passthru|proc_open|system)[A-Za-z_]*\s*\(\s*\[?\s*['"`](gh|git|security|env)\b``,
  the command set `github\.com|--hostname|GH_CONFIG_DIR=|security |credential|remote (add|set-url)|\bunset\b|PATH=`, the
  real gh path and any `claude` command other than `claude plugin list --json`. Write, Edit, MultiEdit and NotebookEdit
  input is checked for the credential set, the spawn pattern and the real gh path (`credential` and `github.com` are
  left out for file contents, which use them legitimately). Any MCP tool outside `plugin_aew_playwright` and
  `plugin_context7_context7` is a hit. A hit exits 4 (`AUDIT HIT`). A genuine false positive is allowed only by its
  exact string in `audit-allow.json`, recorded here. The audit fails closed, also exit 4: a line jq cannot read
  (`AUDIT ERROR`), an attended session with no transcript newer than its start (`AUDIT GAP`), and the PAT's value
  found in any output or transcript, for example a session that printed its environment (`TOKEN LEAK`, checked with
  `grep -F -f .pat`, so the value is never printed).
- **Attended mode.** The same preconditions, environment, lock, C-1 check, fixed denies and post-session checks.
  `--max-budget-usd` works only with `--print` (V-8), so the launcher prints "read /usage at each gate and stop at
  $<cap>" and keeps the cap reserved in the ledger until James's `/usage` figure is written in. The audit runs over
  the transcripts, so the attended gap the plan expected is closed.
- **Kept unchanged:** the CTO-5 ledger lock, the port-4173 stop, the CTO-3 git guard (plugin repo config and hooks),
  the plugin-repo HEAD check, the empty `ghcfg` check and the "use the next attempt name" refusal. The stop is $200.
- **Plugin working tree (added after the Phase A review).** aew loads in place from the plugin checkout, so a change to
  its working tree during a session would change the code that session and later ones run. The launcher hashes
  `git status --porcelain --untracked-files=all` plus `git diff HEAD` of the checkout before and after every session,
  with `tests/e2e-validation.md` exempt (the executor records while sessions run), and exits 4 on a change
  (`REPO WORKING TREE`). Together with the HEAD check this sets an executor rule: no plugin-repo commit and no edit
  other than the record while a session runs.
- **Signals and children (review MINOR).** If the launcher itself receives INT, TERM or HUP it sends TERM to the session
  and still waits for it and audits it; the KILL step also kills the session's child processes (Playwright MCP).

**Self-test** (`selftest.sh`, a stub `claude` first on `PATH`, a dummy `.pat`, no API call): 61 passed, 0 failed
after two launcher fixes (the inherited `GIT_EDITOR`, and a jq error that silently skipped the file-content audit)
and one test fix (the kill fired before the stub set its trap). The per-task review then closed eight C-1 bypasses
(multi-rule lines, `--allowedTools=`, path-prefixed and all-wildcard rules) and four fail-open paths in the audit
(a non-string tool input, `unset` in quotes, an attended session whose transcript is not found, the PAT value in the
output); with the working-tree guard added after the review, the result is 79 passed, 0 failed. It covers:

| Case | Result |
|---|---|
| Normal session | exit 0, ledger row `cap cost start`, audit clean |
| Same run name again; 199 spent plus cap 2; ledger lock held for 2 s | exit 2; exit 3; waits, then starts |
| argv | every fixed deny and `--permission-prompts none`; no `--plugin-dir`, `--add-dir` or `--settings` |
| Session env names | exactly `GH_CONFIG_DIR GH_TOKEN GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_0 GIT_CONFIG_VALUE_1 GIT_SSH_COMMAND GIT_TERMINAL_PROMPT`; `GH_TOKEN` length 17 (the dummy) |
| Command audit hits (exit 4) | `unset GH_HOST`, `echo $GH_HOST`, `PATH=/tmp:$PATH claude -p x`, `env -u GH_TOKEN gh auth token`, `/opt/homebrew/bin/gh api user`, `git remote set-url origin x`, `curl https://github.com/x`, `env -i PATH=/usr/bin gh api user`, `"unset" FOO`, a non-string Bash command |
| File-content audit hits (exit 4) | a Write of `process.env.GH_TOKEN`; a Write of `execSync('gh api user', {env:{}})` |
| PAT value in the stream (exit 4) | `TOKEN LEAK`, reported without the value |
| Non-hits (exit 0) | `claude plugin list --json \| jq .`, `"<installPath>/scripts/state.sh" get stage`, `"<plugin checkout>/scripts/state.sh" get stage`, `npm test`, a Write of `fetch('/api/contact', { method: 'POST', credentials: 'same-origin' })` |
| A file written into `ghcfg` | exit 4 |
| A file created in the plugin checkout during a session | exit 4, `REPO WORKING TREE` |
| Refusals (exit 2) | allow rules `Bash(gh *)`, `Bash`, `Bash(*)`, `Bash(**)`, `Bash(node *)`, `Bash(sh -c *)`, `Bash(/bin/sh -c *)`, `Bash(npx *)`, `Bash(curl *)`, `Bash(env)`, `Bash(/opt/homebrew/bin/gh *)`, `Bash( gh *)`, `Bash(npm *),Bash(gh *)`, `Bash(npm *) Bash(gh *)`, `Read,Bash(*)`, `--allowedTools=Bash(gh *)`; `--permission-mode=default`; `--disallowedTools` in an allow file; `Bash(npx *)` in the project's `settings.local.json` (C-1); an SSH origin; a non-sandbox origin; a project inside the plugin repo; `.pat` at 644. An `aew-sandbox-woo` origin is accepted. |
| Kill at `develop`, and `<run-id>:develop` | `killed-at` names `INT`, the stub's INT trap ran, the ledger charges the cap |
| `--attended` (scratch `HOME`) | a reservation row with an empty cost, the fixed denies in argv, no `-p`/`--plugin-dir`/`--max-budget-usd`; a subagent transcript is found and audited (clean, 1 tool use); `unset GH_HOST` in the transcript exits 4; no transcript exits 4 (`AUDIT GAP`) |
| Leak check | the dummy token appears in no output file |

**Canary** (AC-9; `canary.sh`, every row through `e2e-run.sh --env-check <sandbox>`). The first run (2026-10-26T17:11Z)
failed rows 3, 4, 6 and 7 with `HTTP 401: Bad credentials`: the PAT file did not hold a fine-grained token (wrong
clipboard). James saved it again (93 characters with the fine-grained token prefix, checked without printing it) and the second run
passed. The review fixes above changed the launcher after this run (the session environment is unchanged), so the
canary was re-run before B1 (AC-9). The third run (2026-10-26, `canary.sh` now compares every row with its expected
value) passed all eleven rows; the results are the same as the second run's:

| # | Command (session environment) | Result |
|---|---|---|
| pre | `git config --show-origin --get-regexp '^credential'` (keys only) | one key: `credential.helper` from `/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig` (osxkeychain); no URL-scoped helper |
| 1 | env names `^(GH_\|GITHUB_\|GIT_\|SSH_AUTH_SOCK)` | `GH_CONFIG_DIR GH_TOKEN GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_0 GIT_CONFIG_VALUE_1 GIT_SSH_COMMAND GIT_TERMINAL_PROMPT` |
| 2 | `gh auth status \| grep -c '(GH_TOKEN)'` | `1` (V-10: `GH_TOKEN` beats the keychain) |
| 3 | `gh api user --jq .login` | `jamesborg2012` |
| 4 | `gh repo view` of `aew-sandbox` and `aew-sandbox-retro` | `aew-sandbox aew-sandbox-retro` |
| 5 | `gh repo view jamesborg2012/claude-agentic-engineer-workflow` | `exit=1` (private, outside the PAT) |
| 6 | `git ls-remote origin refs/heads/main` | `3278b71…`, equal to local `main` (V-10: the gh helper serves the PAT to git) |
| 7 | `git push --dry-run origin main` | `Everything up-to-date`, `exit=0` (write auth; nothing created) |
| 8 | `git ls-remote <plugin repo>` | `exit=128` (no helper reaches the keychain credential while `GH_TOKEN` is set) |
| 9 | `env -u GH_TOKEN gh api user`; `env -u GH_TOKEN gh auth token` | `api-exit=4`, `token-exit=0`: **accepted deviation** |
| 9b | `env -u GH_TOKEN git ls-remote <plugin repo>` (CTO C-3) | `exit=0`: **accepted deviation** |
| 10 | files in `ghcfg/` | `0` |

**Fix loop, step 6 as executed.** The plan's fix-loop step 6 ("refresh the install", then `cmp` each changed file
against `installPath`) assumed a cached copy. aew loads in place (install probe), so the recorded `installPath` copy
never changes and the `cmp` would fail falsely after any fix. Step 6 is therefore: the checkout is on
`feature/e2e-validation`, clean, with HEAD at the fix commit, and the next session's `system/init` shows aew's
`plugins[].path` equal to the plugin checkout. The paths init writes into the sandbox's settings are checked against
the checkout path, not `installPath`.

**C3 amended: detect-only for the keychain channel.** With `GH_TOKEN` removed, a session can still read James's keychain
gh token (`gh auth token`, row 9) and git reaches the plugin repo through the gh credential helper (row 9b). C3 asked
for the keychain token to be unreachable. James chose option (a) at A5 (2026-10-26, "Ledger approved, PAT saved,
(a)"), which the CTO risk gate accepted as an amendment to C3 with conditions C-1 to C-3 (the effective-allow-rule
refusal, the widened audit, rows 9 and 9b asserting this result). Every canary re-run is expected to show row 9 as
`api-exit=4 token-exit=0` (gh's own API calls see no login in the empty config dir, but `gh auth token` reads the
keychain) and row 9b as `exit=0`; a change shows up there.

**Headless ship allow file** (`$E2E/allow-ship.txt`, 76 lines, built after the init merge). The session also gets
the sandbox's own `.claude/settings.json` (26 rules from init) and `settings.local.json` (the nine plugin scripts).
The allow file adds, mirroring `smoke_ship_allow ship` (§9.2, with §10.2's `Bash(grep -v '^$' *)`) and narrowed per
the C3 decision:

- the nine plugin scripts by the checkout path, bare and quoted; `gh auth status`; `git status/switch/add/commit *`;
  `jq`, `printf`, `echo`, `date`; `claude plugin list --json`; `git fetch origin main`; `test`, `tail -n`, `grep -c`,
  `grep -v '^$'`; the read-only `git rev-parse/branch/diff/log/show *`, `git worktree *`, `git cherry-pick *`; `cd *`;
  the context7 tools; fourteen Playwright MCP tool names;
- npm narrowed from `npm *` to `npm ci`, `npm run *`, `npm test *`, `npm ls *` and `npm install --save-dev
  --save-exact *` (so no `npm exec`); `npx` only as `npx vitest|eslint|next|playwright *` and `npx tsc --noEmit *`;
  `AEW_EVIDENCE_DIR=* npx playwright test [*]`;
- `curl` only as ui-qa §3's two exact checks against `http://localhost:3000`; `lsof -ti tcp:3000 -sTCP:LISTEN`;
  `rm -rf <sandbox>/docs/qa/*/screenshots`; `cp <sandbox>/.aew/runs/* <sandbox>/docs/qa/*`; `mkdir -p *`; `file -b *`.

Left out on purpose: `node *`, `sh -c *`, `nohup sh -c *`, `npx *`, `curl *`, `kill *` and the `git -C * …` forms
(CTO-3a: a wildcard before the subcommand also matches `-c core.fsmonitor=<cmd>`; only the developer's fan-out mode
uses `git -C`). **Harness decision:** because no `sh` rule is allowed, QA cannot start the app headless (ui-qa §3
starts it with `nohup sh -c '<start_command>' …`). Before every headless run with a UI stage the executor starts the
sandbox's dev server itself, and QA takes ui-qa §3 step 1 ("an instance is already running: use it and leave it
running"). A free launch with a $1000 cap (exit 3 at the budget stop, nothing reserved) proved the launcher's C-1 check
accepts this allow file together with the sandbox's merged settings.

**Ship's `awk` reads (added 2026-10-27, James's decision at the S4 checkpoint).** DESIGN §3 lists `awk` among the
forms init leaves unapproved, which a headless run must allow itself. The allow file now carries exactly the four
programs ship prescribes, each as `Bash(awk '<program>' *)` (program fixed, only file arguments after it):
`/^## Questions$/…` (gate questions), `/^## Challenges to the spec$/…` (plan challenges), the `## Failures` TC count
and the `## (Root cause|Where the divergence started)` triage read. No `awk *`. Two of the programs contain
parentheses, which the launcher's one-rule-per-line check refused, so the check was refined: a Bash line must start
with `Bash`, end with its closing parenthesis, and have no second rule after a closing parenthesis. Self-test 81 of 81
(new: an exact awk rule with parentheses accepted; `Bash(awk 'x' *) Bash(gh *)` refused; every earlier bypass still
refused). The canary was re-run after the change (fourth run, all eleven rows pass).

**Credential incident playbook (CTO C-4).** An audit hit on a credential pattern (exit 4) is a P0 stop for James:
(1) no further sessions; (2) James revokes the PAT; (3) if the hit could have reached the keychain token, James
revokes the GitHub CLI OAuth grant (github.com → Settings → Applications) and logs in again; (4) James checks the
GitHub security log; (5) the executor lists every `gh` or `git` remote call from the stream. The executor never
revokes anything.

**C3 broad-lines decision, in writing.** The ship-run allow files (built in Phase B) start from init's anchored
`.claude/settings*.json` and add only narrowed harness lines: `npx` only as the sandbox's own tools (`npx vitest *`,
`npx eslint *`, `npx next *`, `npx playwright *`) and `curl` only against `http://localhost:*`. `node *` and `sh -c *`
are never added. Widening any line beyond these is a STOP for James (CTO C-1), never an executor decision.

**Blast radius (CTO C-8).** With aew enabled at user scope, its Playwright MCP server and SessionStart hook load in
every one of James's sessions during the validation; its hooks act only in repos with `.aew/config.json`. Rollback in
seconds: `claude plugin disable aew@jamesborg-plugins` (uninstall per V-12). The private sandbox repos carry no blast
radius.

## Spend ledger

CP-1 approved by James on 2026-10-26 at about 17:10Z ("Ledger approved, PAT saved, (a)"). Stop: **$200**.

| Item | Cap (USD) | Attended | Drive |
|---|---|---|---|
| Install probe | 0.50 | no | headless (haiku) |
| init | 5 | yes | interactive |
| S1 | 15 | yes | interactive |
| S2 | 20 | no | headless |
| S3 | 10 | yes | interactive |
| S4 | 12 | no | headless (attended resume if it gates) |
| S5 | 25 | yes (mode question) | interactive |
| S6 | 30 | no | headless `--sequential --auto` |
| S7 kill + status + resume | 8 (charged at cap) + 1 + 12 | no | headless |
| S8 prompt + plugin-less build | 4 + 8 | no | headless |
| Subtotal | 150.50 | | |
| Re-run reserve | 49.50 | | |
| Stop | 200 | | S9 (cap 25) only if 25 or more remains |

Attended sessions are capped by James reading `/usage` at each gate (V-8); their row keeps the cap reserved until his
figure is written in. Cost source: `result` = the stream's `total_cost_usd`; `usage` = James's `/usage` figure; `cap` =
a killed or crashed session, charged at its cap.

| Run | Attempt | Cap | Cost | Running total | Cap raised? | Attended | Cost source |
|---|---|---|---|---|---|---|---|
| probe | probe.1 | 0.50 | 0.0034 | 0.0034 | no | no | result |
| init | init.1 | 5 | 1.31 | 1.31 | no | yes | usage |
| S1 | S1.1 | 15 | 6.09 | 7.40 | no | yes | usage |
| S2 | S2.1 | 20 | 0.25 | 7.65 | no | no | result |
| S2 | S2.2 | 19.75 | 5.64 | 13.29 | no | no | result |
| S2 | S2.3 | 8 | 2.07 | 15.37 | no | no | result |
| S2 | S2.4 | 4 | 1.10 | 16.47 | no | no | result |
| S3 | S3.1 | 10 | 10.38 | 26.85 | no (ran $0.38 over, James's call to let it finish) | yes | usage |
| S3 | S3.2 | 2 | 0.94 | 27.79 | reserve, approved by James | no | result |
| S3 | S3.3 | 2 | 0.93 | 28.72 | reserve, approved by James | no | result |
| S4 | S4.1 | 12 | 1.94 | 30.66 | no | no | result |
| S4 | S4.2 | 10 | 9.74 | 40.40 | no (S4's line: 11.68 of 12) | yes | usage |
| S5 | S5.1 | 25 | 11.82 | 52.22 | no | yes | usage |

## Sandbox fixtures

**Sandbox app (AC-6, AC-7, AC-8).** `/Users/jamesborg/Documents/Development/aew-sandbox`, a sibling of the plugin
repo with no ancestor `CLAUDE.md`, pushed to private `jamesborg2012/aew-sandbox` (`main` at `3278b71`,
`chore: scaffold the aew sandbox (Next.js contact form)`); `deleteBranchOnMerge` is `false`. The empty private
`jamesborg2012/aew-sandbox-retro` has issues enabled and no labels.

- Scaffolded with `create-next-app@16.4.3 --ts --tailwind --eslint --app --no-src-dir --import-alias '@/*' --use-npm
  --no-agents-md --no-react-compiler --no-agent-feedback --disable-git` (versions looked up with `npm view` and the
  generator's own `--help`); no `AGENTS.md` or `CLAUDE.md` was written. The template's Google fonts and logos were
  removed so the build needs no network.
- `/` is a client form with labelled name, email and message fields that POSTs JSON to `/api/contact` and shows a
  `role="status"` line on `{ok:true}`. `app/api/contact/route.ts` returns `Response.json({ ok: true })` and stores
  nothing; `app/api/contact/route.test.ts` (Vitest, node environment) asserts status 200 and `{ ok: true }`.
- Exact pins: next 16.4.3, react and react-dom 19.3.0, eslint 9.39.5, eslint-config-next 16.4.3, tailwindcss and
  @tailwindcss/turbopack 4.3.3, typescript 5.9.3, vitest 5.0.5, @types/node 26.6.5 (raised from the template's `^20`,
  because vitest 5's peer range needs 22 or later), @types/react and @types/react-dom 19.3.0.
- Scripts `build dev lint start test` (`test` = `vitest run`); `npm run lint` 0, `npm test` 1 passed, `npm run build`
  0. No Playwright, no `.aew/`, no `CLAUDE.md`.
- `gh repo create aew-sandbox --private --source <sandbox> --remote origin --push` created the repo and pushed `main`
  (V-11); origin is `https://github.com/jamesborg2012/aew-sandbox.git`.
- AC-8: the gitignored `.claude/settings.local.json` holds `{"enabledPlugins": {"dev-workflow@jamesborg": false,
  "figma@claude-plugins-official": false, "warp@claude-code-warp": false}}`; the probe proves it works.

The issue and milestone fixtures are below.

**Fixture tuning (S2).** Next.js 16's dev server writes an untracked `AGENTS.md` into the project unless
`next.config.ts` sets `agentRules: false`, and that file fails aew's clean-tree checks. The executor set it on the
sandbox's `main` (`5868040`, "chore: stop the dev server writing AGENTS.md") before S2.1. A Next.js dev server also
kept serving stale CSS after a branch switch (S2.2); restarting it fixed that. Both go to README troubleshooting.

### Issue and milestone fixtures (AC-13)

Created on 2026-10-26 under the executor's own gh, before the first scenario. Milestones (V-11, proved by running):
`gh milestone --help` exits 1 (no built-in milestone command in gh 2.103.2; `gh help milestone` exits 0 but only
prints the general help), so `gh api repos/jamesborg2012/aew-sandbox/milestones -f title=<title> --jq '"\(.number) \(.title)"'`
was used: it returned `1 Contact page polish` and `2 Submissions log`. Issues were created with
`gh issue create --repo jamesborg2012/aew-sandbox --title <title> --body-file <draft> [--milestone <title>]`, in the
order below, S6b's and S6c's `Depends on` line filled with the real number of the previous child. Every body read
back with `gh issue view <n> --json body | jq -j .body` is byte-identical to its draft (GitHub stores the body as
sent; `gh … -q .body` only adds a trailing newline on output). These read-backs are the baseline for S3's v1 check.

| Scenario | Issue | Title | Milestone |
|---|---|---|---|
| S1 | #1 | Validate contact submissions on the server | — |
| S2 | #2 | Show inline errors on the contact form, announced to screen readers | — |
| S3 | #3 | Rate-limit contact submissions | — |
| S4 | #4 | Email the admin on each submission | — |
| S5a | #5 | Set the contact page title and description | Contact page polish (1) |
| S5b | #6 | Show a live character counter for the message | Contact page polish (1) |
| S5c | #7 | Add a privacy note under the Send button | Contact page polish (1) |
| S6a | #8 | Add a submissions store module | Submissions log (2) |
| S6b | #9 | Add GET /api/submissions | Submissions log (2) |
| S6c | #10 | Add a /submissions page | Submissions log (2) |
| S7 | #11 | Normalise contact fields on the server | — |
| S8 | #12 | Return a request id from the contact API | — |

S3 deliberately leaves out the limit, the key and the response (a material gap, so the spec gate must fire). S4's
AC 4 is the one non-automatable check. S5's three issues share the page and have no dependencies; S6's form a chain.

#### S1 (#1)

````markdown
### Summary

`POST /api/contact` (`app/api/contact/route.ts`) accepts any body and always replies `{ "ok": true }`. It should reject invalid submissions on the server, so bad data never reaches whatever handles messages later.

### Acceptance criteria

1. A request with a missing or blank `name` (after trimming) gets status 422 and a JSON body `{ "ok": false, "errors": { "name": "Enter your name" } }`.
2. A request whose `email` is missing or not a valid email address gets status 422 with `errors.email` set to "Enter a valid email address".
3. A request whose `message` is shorter than 10 or longer than 1000 characters gets status 422 with `errors.message` set to "Your message must be between 10 and 1000 characters". When several fields are invalid, every invalid field appears in `errors`.
4. A request with a valid name, email and message still gets status 200 and `{ "ok": true }`.

### Out of scope

- any change to the contact page (`app/page.tsx`);
- storing or sending the message.
````

#### S2 (#2)

````markdown
### Summary

The contact form (`app/page.tsx`) ignores the server's validation errors: when `POST /api/contact` replies 422 with `{ "ok": false, "errors": { … } }`, nothing is shown. People need to see what to fix, including people using a screen reader.

### Acceptance criteria

1. When the API replies 422, each field named in `errors` shows its message directly under that field, the field has `aria-invalid="true"`, and the message is linked to it with `aria-describedby`.
2. A summary such as "There are 2 problems with your message" is announced to screen readers through a live region when the errors appear.
3. Focus moves to the first invalid field (in the order name, email, message) when the errors appear.
4. When the form is submitted again with valid values, the errors and the summary disappear and the existing success line is shown.
5. At desktop (1440×900) and mobile (390×844) the form, its errors and the summary are visible without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.

### Out of scope

- client-side validation before submitting;
- changing the API's rules or messages.
````

#### S3 (#3)

````markdown
### Summary

The contact endpoint can be called as often as anyone likes. Please rate-limit contact submissions so the form can't be used to flood us.

### Acceptance criteria

1. Contact submissions are rate-limited.
2. Requests within the limit behave exactly as they do today.
3. The limit is covered by unit tests.

### Out of scope

- the contact page's appearance.
````

#### S4 (#4)

````markdown
### Summary

When someone submits the contact form, the site admin should get an email with the message, so nobody has to poll for new messages.

### Acceptance criteria

1. On a valid submission, `POST /api/contact` sends an email to the address in the `ADMIN_EMAIL` environment variable, with the sender's name and email in the subject and the message as the body, through a mail transport module that tests can replace.
2. If sending the email fails, the request still returns status 200 and `{ "ok": true }`, and the failure is logged on the server.
3. If `ADMIN_EMAIL` is not set, no email is attempted and the request still returns 200.
4. The admin actually receives the email in their inbox when the site runs with a real mail provider configured.

### Out of scope

- choosing or configuring a production mail provider;
- confirmation emails to the sender.
````

#### S5a (#5)

````markdown
### Summary

The contact page still has the generic title and description.

### Acceptance criteria

1. The page's `<title>` is "Contact us | aew sandbox".
2. The page has a meta description "Send us a message and we'll get back to you.".

### Out of scope

- other pages.
````

#### S5b (#6)

````markdown
### Summary

People don't know how long their message may be until they submit it.

### Acceptance criteria

1. Under the message field, a counter shows "<n> / 1000 characters", where n is the current message length, and updates as the person types.
2. The counter is linked to the message field with `aria-describedby`.
3. At desktop (1440×900) and mobile (390×844) the counter is visible without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.
````

#### S5c (#7)

````markdown
### Summary

The form doesn't say what we do with what people send.

### Acceptance criteria

1. Directly under the Send button, the page shows the text "We only use your details to reply to your message."
2. At desktop (1440×900) and mobile (390×844) the note is visible without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.
````

#### S6a (#8)

````markdown
### Summary

We want to keep contact submissions so they can be listed later. Start with a small store module the rest can build on.

### Acceptance criteria

1. A module `lib/submissions.ts` exports `addSubmission({ name, email, message })`, which stores the submission in memory with an `id` and a `receivedAt` ISO timestamp and returns the stored record.
2. It exports `listSubmissions()`, which returns every stored submission, newest first.
3. Both functions are covered by unit tests.

### Out of scope

- persistence across server restarts;
- wiring the store into `POST /api/contact`.
````

#### S6b (#9)

````markdown
### Summary

Expose the stored submissions through the API so a page can show them.

### Acceptance criteria

1. `GET /api/submissions` returns status 200 and `{ "submissions": [ … ] }`, the result of `listSubmissions()` from `lib/submissions.ts`, newest first.
2. With no submissions it returns `{ "submissions": [] }`.
3. The route is covered by unit tests.

### Out of scope

- authentication;
- pagination.

Depends on #8
````

#### S6c (#10)

````markdown
### Summary

Add a page that lists the submissions from `GET /api/submissions`.

### Acceptance criteria

1. A page at `/submissions` shows a heading "Submissions" and, for each submission, the name, email, received date and message, newest first.
2. With no submissions it shows "No submissions yet."
3. At desktop (1440×900) and mobile (390×844) the list is readable without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.

### Out of scope

- deleting or editing submissions;
- authentication.

Depends on #9
````

#### S7 (#11)

````markdown
### Summary

`POST /api/contact` should tidy what people type before validating it, so stray spaces or capital letters in an email address don't cause errors or duplicates.

### Acceptance criteria

1. Leading and trailing whitespace is removed from `name`, `email` and `message` before validation.
2. `email` is converted to lower case before validation.
3. Validation runs on the tidied values: a name of only spaces is still rejected as missing.
4. The behaviour is covered by unit tests of the route.

### Out of scope

- collapsing spaces inside the message;
- any change to the contact page.
````

#### S8 (#12)

````markdown
### Summary

When something goes wrong with a submission it's hard to match a user's report to the server log. Give every contact API response a request id.

### Acceptance criteria

1. Every response from `POST /api/contact` includes a `requestId` field, a newly generated UUID.
2. The same id is sent in an `X-Request-Id` response header.
3. Two requests get different ids.
4. The behaviour is covered by unit tests.

### Out of scope

- logging or tracing infrastructure;
- any change to the contact page.
````

## init

### init.1 (attended, 2026-10-26)

James ran `e2e-session.sh <sandbox> init.1 5` and `/aew:init`, answered the one question round with the recommended
answers (so Playwright was skipped, not set up as Assumption 5 expected) and chose **Write** for the permissions.
Cost $1.31 (`/usage`), cap $5. Init opened PR #13 (`chore: set up aew`, `08e47d4`).

| Expectation | Result | Evidence |
|---|---|---|
| Config written and valid (AC-11) | pass | `ajv validate … config.schema.json` `valid`; stacks `nextjs 16.4.3` and `tailwind 4.3.3` at `.`; commands install `npm ci`, dev, build, lint, test_unit from `package.json`, typecheck `npx tsc --noEmit` (inferred); app `npm run dev` on `http://localhost:3000`, `env_type` `native` |
| `retro.repo` is the sandbox retro repo | **fail, fixed** | init did not ask (its report: "it has only one sensible value") and wrote `jamesborg2012/claude-agentic-engineer-workflow`, which the sandbox-only PAT cannot reach. Plugin fix `658615f`; the sandbox config was corrected on the PR branch in `7caf360` (a re-run keeps existing values by design), with a PR comment saying so |
| All 11 aew labels exist | pass | `comm` of `gh-labels.sh`'s list against `gh label list` prints nothing; 11 `aew:` labels |
| Gitignore, `CLAUDE.md`, standards | pass | `.aew/runs/` and `.playwright-mcp/` added (`.claude/settings.local.json` already ignored); `## Agentic workflow` section; `docs/standards/nextjs.md`, `tailwind.md` and `README.md`, each doc headed by its fingerprint comment (`nextjs next@16 react@19 typescript@5 cfg:47154b75becb`, `tailwind tailwindcss@4 cfg:d13f5abf1acf`); context7 unavailable (needs auth), so seeds plus the repo were used |
| Permissions | pass | `.claude/settings.json` (26 anchored rules, in the PR) and `.claude/settings.local.json` (the nine scripts by the checkout's path, gitignored); AC-8's three `false` entries survived the merge |
| Playwright | skipped (James's answer) | "Playwright: skipped (QA sets it up on first use)". S2 therefore exercises ui-qa's first-use setup instead of init's |
| One PR on `main`; plain trailer (CR-5) | pass | PR #13 base `main`; `08e47d4` and `7caf360` carry exactly `Claude <noreply@anthropic.com>` |
| Guard hits (CR-6) | none | no `aew guard:` text in the two transcripts |
| Permission prompts (CR-7) | 1, **fixed** | `rm -f .aew/runs/init-config.json … init-pr-body.md` (§13 clean-up, split over two lines, no rule). Plugin fix `7ab432b`: one line, and the exact command in template 2. Settings diff against the pre-session snapshot: only init's own writes |
| Launcher post-checks | pass | exit 0; `audit clean (58 tool uses)` over 2 transcripts; git guard, plugin HEAD, working tree and `ghcfg` unchanged |
| Introduction (AC-14) | **accurate** | `check-pr-intro.sh` exit 0. It says what init set up, flags the two guessed values (typecheck, app start) and the permission rules for review, and says browser testing was deferred to first use, all true. Its "What init did" list names the old `retro.repo`, which predates the correction (noted in the PR comment) |
| Merge (CP-3, AC-12) | pass | James merged with a normal merge commit (`424e947`, 2026-10-26T19:38:56Z) and kept the branch; `main` fast-forwarded and equal to `origin/main` |

Cycles: none (init has no review loop). Duration: about 25 minutes of session time. Problems: the two init defects
above, both fixed before the merge; `skills/init/SKILL.md` was first brought under 500 lines (`f33feb1`).

## S1

### S1.1 (attended, gates on, 2026-10-26)

James ran `e2e-session.sh <sandbox> S1.1 15` and `/aew:ship 1` (no `--auto`). Run `1`, 19:46:45Z to 20:05:01Z
(18 minutes); cost $6.09 (`/usage`), cap $15. PR #14 on `feat/1-validate-contact-submissions-on-the-serv`.

| Expectation | Result | Evidence |
|---|---|---|
| [P] `ship` with gates on | pass | `state.json` `auto` `false`; `log.md`: `plan awaiting_plan_approval — gate:plan-approval 05-plan.md`, then `develop running — plan approved` |
| [P] Plan gate shown | **partial, fixed** | One AskUserQuestion, header `Plan gate`, question `Approve the plan for #1?`, options `Approve` / `Request changes` / `Stop` (transcript). But no summary and no `05-plan.md` path was shown: the orchestrator read the plan and asked at once (`gates.md` step 3 and DESIGN §9 require both). Fix `c3476b8` puts the summary and path in the question text; James chose to verify it live in S5 rather than re-run S1, and S5.1 confirmed it |
| [P] ACs traced to tests | pass | spec v2 has 11 criteria; the brief splits them into AC-1 to AC-22 with an explicit mapping (`02-brief.md` judgement note); `08-qa-report-1.md` maps TC-1 to TC-22 one-to-one, all pass; `10-summary.md` lists 22/22 checked; unit 40/40 |
| [P] PR opened (CR-3) | pass | PR #14, base `main`, body `Closes #1`, title `Validate contact submissions on the server` |
| Spec revision (non-material, auto) | pass | v2 added ACs 5 to 11 (exact 422 body, trim every field, WHATWG email rule, code points, non-strings, non-object body, 400 on bad JSON), all `non-material`, `source: auto`. Issue #1 now shows v2 on top; v1 extracted with `gh-issue-body.bats`'s `prev_of` is byte-identical to B2's read-back and to the `## Body` section of `00-issue-original.md` (the file adds a separator line); `Spec v1 (original)` summary present; one `Spec revision v2` comment |
| CR-1 state | pass | `state.json` valid against the schema; `status` `done`, `stage` `pr`; `.aew/runs/current` empty |
| CR-2 labels | pass | `aew:ready-for-review aew:spec-revised` (the flag is right: the spec was revised) |
| CR-4 lint, tests, typecheck, build on the PR branch | pass | `npm run lint` 0, `npm test` 40 passed, `npx tsc --noEmit` 0, `npm run build` 0 |
| CR-5 trailers | pass | 4 commits (`feat(contact)…`, `test(e2e)…`, `docs…`, `chore(aew): update agent memory`), each exactly `Co-Authored-By: Claude <noreply@anthropic.com>` |
| CR-6 guard hits | none | no `aew guard:` text in the 11 transcripts (main and subagents) |
| CR-7 prompts and denials | none | James saw no prompt; no denial in any tool result; both settings files unchanged against the snapshot. **C2 confirmed interactively:** ship's `grep -v '^$' … \| tail -n 4` return checks ran with no prompt |
| CR-8 report, cycles, duration | pass | review cycle 0 (approved first time), QA fix cycle 0; 18 minutes; stages each under 4 minutes |
| Retro filing (cross-repo) | pass | two items filed in `jamesborg2012/aew-sandbox-retro` (#1 standards override path, #2 TC ids in test names); listed again in Phase F |
| Launcher post-checks | pass | exit 0; `audit clean (287 tool uses)` over 11 transcripts; git guard, plugin HEAD, working tree, `ghcfg` unchanged |
| Introduction (AC-14) | **accurate** | `check-pr-intro.sh --issues 1` exit 0. It says what changed and what visitors see (nothing), why plain checks in the route (no new file or dependency), that the spec grew from 4 to 11 minor rules, the 422 choice over the standards' 400, the changed old test, that nothing needs a manual check, the follow-ups, and 22/22 with a clean review: all match the artefacts |

Merge (CP-3): James merged PR #14 with a normal merge commit (`0af0e38`, two parents) and kept the branch; issue #1
closed; `main` fast-forwarded.

Cycles: review 0, fix 0. Duration: 18 minutes. Problems: the plan gate's missing summary (fixed, `c3476b8`).
Fixture note: S1's auto revision (AC 6) already trims every field, which S7 asked for; S7 is left as filed and
judged on its remaining change (lowercasing the email) and its tests.

## S2

Issue #2, `/aew:ship 2 --auto`, headless, cap line $20. Four attempts on one run (`2`), $9.06 in all.

| Attempt | Cap | Cost | What happened |
|---|---|---|---|
| S2.1 | 20 | 0.25 | Stopped at preflight: the Read of `<plugin>/skills/ship/references/preflight.md` was denied ("requires approval", outside the working directories; the session has no approval surface). Nothing was written. **Plugin defect** for every headless user (S1 was interactive, where the same reads ran without a prompt): fixed in `444a579`, init's machine-local template now carries `Read(//<plugin root>/**)`; the rule was added to the sandbox's gitignored `settings.local.json` as a re-run of init would. Before S2.1 the dev server, started by the executor (the harness decision), wrote an untracked `AGENTS.md` (Next.js 16 does so unless `agentRules: false`), which fails the developer's clean-tree check; fixture fix on the sandbox's `main` (`5868040`, recorded under Sandbox fixtures) |
| S2.2 | 19.75 | 5.64 | spec (v2, 7 non-material changes) → brief (29 ACs) → standards → plan (no gate: `auto`) → develop (`45a6f68`) → review (approved, 2 minor and 2 nit findings) → QA **blocked**: TC-29 dark contrast read 3.06:1 because the executor's dev server served stale CSS after the run switched branches under it (confirmed: the served stylesheet lacked the branch's dark `--error: #f87171`). QA would not restart a server it did not start, as designed. **Harness/platform**, not a plugin defect |
| S2.3 | 8 | 2.07 | Executor restarted the dev server (now serving both colours), `/aew:resume 2`: QA passed, docs, PR #15 |
| S2.4 | 4 | 1.10 | `/aew:ship 2 --auto --from docs` after the doc-writer fix `7f188e8`, to verify it live: PR #15's body rewritten in place |

| Expectation | Result | Evidence |
|---|---|---|
| [P] `ship --auto`, no plan gate | pass | no AskUserQuestion in any S2 stream; `log.md` goes `plan running` → `develop running` with no `awaiting_plan_approval` |
| [P] Playwright specs committed | pass | `tests/e2e/2-show-inline-errors-on-the-contact-form-a.spec.ts`, `tests/e2e/aew.ts`, `playwright.config.ts` on the PR branch (`7424a3a`); QA set Playwright up on first use (ui-qa §2: `@playwright/test` 1.64.1, `@axe-core/playwright` 4.14.0, exact-pinned), since James skipped it at init |
| [P] Screenshots for both viewports in `docs/qa/` | pass | `docs/qa/2/screenshots/`: 54 JPEGs, a `-desktop` and a `-mobile` for each of 27 TCs; `sips`: 1440×900 and 390×844 |
| [P] axe results in the report | pass | `08-qa-report-1.md` `## Accessibility`: `/` loaded and with all errors shown, 0 critical/serious/moderate at wcag2a to wcag22aa (`axe-TC-17/18-{desktop,mobile}.json`); TC-28/29 also ran axe `color-contrast` in light and dark |
| For information: QA fix cycle; frontend-design | none; not checked per thread | `fix_cycle` 0; the stale-CSS block was not a fix cycle |
| Manual tests | 2, appropriate | TC-9 and TC-22 (VoiceOver announces the summary and the focused field) are not automatable; posted on the issue, `aew:manual-test-required` set, listed under `## Manual tests` in the PR |
| CR-1 state | pass | `state.json` valid; `done` at `pr`; `current` empty |
| CR-2 labels | pass | `aew:manual-test-required aew:ready-for-review aew:spec-revised` |
| CR-3 PR | pass | PR #15, base `main`, `Closes #2` |
| CR-4 lint, tests, typecheck, build | pass | lint 0; Vitest 54 passed; `tsc` 0; build 0 (run after stopping the dev server) |
| CR-5 trailers | pass | 6 commits, each exactly `Co-Authored-By: Claude <noreply@anthropic.com>` |
| CR-6 guard hits | none | no `aew guard:` text in the four streams |
| CR-7 denials | recorded | S2.1: the plugin Read (fixed, above). S2.2: `curl -fsS … "http://localhost:3000"` (**harness**: the exact rule lacked the quotes; quoted forms added to the allow file), then QA's `nohup sh -c 'npm run dev' …` (refused by design, C-1); five improvised `git -C <sandbox> diff/log/ls-files/rev-parse` reads by an agent (`git -C` is prescribed only for fan-out; recorded, watch for recurrence). S2.3: the same quoted `curl`; an improvised `lsof -nP -iTCP:3000 …; jq …` by the resumed orchestrator; QA's `env AEW_EVIDENCE_DIR=… npx playwright test` (improvised; it then ran the prescribed `AEW_EVIDENCE_DIR="…" npx playwright test`, which passed). S2.4: none |
| CR-8 report, cycles, duration | pass | review 0, fix 0; run time 20:20 to 20:48 (28 minutes) plus the docs re-run (7 minutes) |
| Launcher post-checks | pass | every attempt exit 0 and `audit clean` (1, 290, 127, 79 tool uses) |
| Introduction (AC-14), S2.3 | **gap, fixed** | `check-pr-intro.sh --issues 2` exit 0, and specific and true (inline errors, the announced summary, focus, kept input, contrast in both schemes, the decision taken on James's behalf, the two VoiceOver checks, the results). But no part of the PR body said that QA added two dev dependencies the plan had left for the (skipped) plan gate. Doc-writer fix `7f188e8` |
| Introduction (AC-14), S2.4 | **accurate** | now also: "Two browser-testing tools were added for development only, and the plan's usual approval step was skipped because the run was automatic." Check exit 0 |

Merge (CP-3): James merged PR #15 with a normal merge commit (`a6936d8`, two parents) and deleted the branch; issue #2
closed; `main` fast-forwarded.

Cycles: review 0, fix 0. Duration: about 50 minutes over four attempts. Problems: the plugin-file Read under headless
(`444a579`), the introduction gap (`7f188e8`), and two harness issues (stale dev-server CSS; unquoted `curl` rules).

## S3

Issue #3, deliberately silent on the limit, the client key and the response. Run `3`.

| Attempt | Drive | Cap | Cost | What happened |
|---|---|---|---|---|
| S3.1 | attended, `/aew:ship 3 --auto` | 10 | 10.38 (`/usage`) | spec gate under `--auto` → James's five answers → spec v2 → brief → standards (Tailwind doc updated) → plan (no gate) → develop, **fanned out** into WP-1 (limiter and route) and WP-2 (form message) in `git -C` worktrees, cherry-picked back → review (approved) → QA (started and stopped the app itself: `nohup sh -c 'npm run dev'`, `lsof`, `kill`; James saw no prompt) → docs → PR #16. 30 minutes. James let it run $0.38 past the cap to finish the PR body |
| S3.2 | headless, `--from docs` | 2 | 0.94 | after doc-writer fix `22b901f`; the doc-writer kept its earlier `pr-body.md` as "already accurate", so the fix was not applied (→ fix `468ed5f`). Also surfaced: no stage runs the build (→ `97291e4`), the `retro` label warning (→ `88f26c7`) and an improvised `for` loop (→ `d141b4d` after it recurred) |
| S3.3 | headless, `--from docs` | 2 | 0.93 | introduction rewritten with the clarification; no label warning; the `for` loop recurred (denied, recovered) |

James's answers at the spec gate (verbatim):

```text
Q1. What limit should apply to contact submissions? → 5 per client per 10 min, every POST (recommended)
Q2. How should the endpoint identify a client for the limit? → IP from x-forwarded-for (recommended)
Q3. What should a request over the limit receive? → 429 { ok: false } + Retry-After (recommended)
Q4. Should the contact form tell the user when they are rate-limited? → Yes, in the alert region (recommended)
Q5. Where should the request counts be kept? → Server memory, no new dep (recommended)
```

| Expectation | Result | Evidence |
|---|---|---|
| [P] Spec gate fires even with `--auto` | pass | `log.md`: `spec_analysis awaiting_input — gate:spec 01-spec-analysis.md`, then `answers: gate:spec`; `state.json` `auto` `true` |
| [P] After the answers, revision v2 appears on the issue | pass | issue #3's body starts `<!-- aew:spec v2 -->`; `spec_revision` 2; `spec-changes.json`: 5 `confirmed`, 6 `auto` changes; one `## Spec revision v2` comment; flag `aew:spec-revised` |
| [P] The original is collapsed | pass | `<summary>Spec v1 (original)</summary>` inside `<!-- aew:spec-prev v1 -->`; v1 extracted with `prev_of` (k=1) is byte-identical (`cmp` 0) to the body saved before the run (itself identical to B2's read-back) and to the `## Body` section of `00-issue-original.md` |
| PR (CR-3) | pass | PR #16, base `main`, `Closes #3` |
| CR-1, CR-2 | pass | `state.json` valid, `done`; labels `aew:ready-for-review aew:spec-revised` |
| CR-4 | pass | lint 0, Vitest 118 passed, `tsc` 0, build 0 |
| CR-5 | pass | 6 commits, plain trailer |
| CR-6 | none | no `aew:` guard text in 14 transcripts or the two streams |
| CR-7 | recorded | S3.1: James saw no prompt; settings unchanged. S3.2 and S3.3: the orchestrator's improvised `for f in …; do test -f "$f" …` loop, denied both times (H1), then one call per file (fixed `d141b4d`) |
| CR-8 | pass | review 0, fix 0; 30 minutes plus two short re-runs |
| Fan-out (first live use) | pass | `06-dev-report-WP1.md`, `-WP2.md`; worktrees under `.aew/runs/3/worktrees/` removed; `git worktree list` shows only the main checkout; sub-developers used `git -C <worktree>` |
| Retro "Seen again" | pass | the re-runs commented on retro #7 to #9 instead of filing duplicates |
| Introduction (AC-14), S3.1 | **gap, fixed** | check exit 0 and true, but it stated the limit and response as plain facts: it did not say the issue left them open and James decided them (the plan requires the clarification to be mentioned). Fixes `22b901f` and `468ed5f` |
| Introduction (AC-14), S3.3 | **accurate** | "The issue gave no numbers, so James answered the open questions: the limit is 5 per 10 minutes, every attempt counts even if it fails, visitors are told apart by network address, and the form shows the message above." Its "production build check was not run" was true of this run (before `97291e4`); the executor's build passed |

Merge (CP-3): James merged PR #16 with a normal merge commit (`f72586b`, two parents) and deleted the branch; issue #3
closed; `main` fast-forwarded.

Cycles: review 0, fix 0. Duration: 30 minutes plus two re-runs of about 3 minutes. Problems: five plugin fixes
(`22b901f`, `468ed5f`, `97291e4`, `88f26c7`, `d141b4d`).

## S4

Issue #4, "Email the admin on each submission", whose AC 4 ("the admin actually receives the email") is the one
non-automatable check. Run `4`, `/aew:ship 4 --auto`.

| Attempt | Drive | Cap | Cost | What happened |
|---|---|---|---|---|
| S4.1 | headless | 12 | 1.94 | spec analysis ran 24 minutes (22:04 to 22:28; S1 to S3 took about 4), then a **material** question the headless run cannot ask: the issue rules out choosing a mail provider, but AC 4 needs real delivery. Gate left pending (`awaiting_input`, label `aew:awaiting-input`), as designed. The fallback the plan names (the §9.5 precedent): an attended resume |
| S4.2 | attended, `/aew:resume 4` | 10 | 9.74 (`/usage`) | James answered "SMTP via nodemailer (recommended)" → spec v2 → brief (56 ACs) → standards → plan (no gate) → develop (two WPs in sequence; **the developer ran `npm run build`, pass**, the first live check of `97291e4`) → review (approved) → QA → docs → PR #17. 33 minutes after the answer |

James's answer (verbatim):

```text
Q1. Which real mail transport should issue #4 ship, given that choosing a production provider is out of scope but AC 4 needs a real email to arrive?
→ SMTP via nodemailer (recommended)
```

| Expectation | Result | Evidence |
|---|---|---|
| [P] Manual-testing section added to the issue | pass | issue #4's body has `<!-- aew:manual-tests -->` … `<!-- /aew:manual-tests -->` between the v2 spec and the collapsed v1; no line of B2's read-back is lost; v1 (`prev_of`, k=1) is byte-identical to B2's read-back |
| [P] Label set | pass | `aew:manual-test-required aew:ready-for-review aew:spec-revised` |
| [P] Listed in the PR | pass | PR #17 `## Manual tests` lists them; the final report counts them as outstanding |
| Exactly one manual test | **fail, fixed** | five: TC-10 (delivery, the real one), TC-41 ("the manual steps exist and no test sends mail"), TC-54 (TC-10 with two SMTP targets), TC-55 and TC-56 (accented name and emoji arrive intact). Cause: the spec analyser auto-added AC 13 ("criterion 4 is checked by hand") and AC 17 ("the manual check uses an accented name and an emoji") as non-material changes; the brief and QA then honestly made them manual. Fix `637e591` (ACs state behaviour, never test method). Not re-run live (about $12); James's call at the merge |
| Everything else automated | pass | `08-qa-report-1.md`: 51 TCs `pass`, the 5 above `manual` |
| CR-1, CR-3 | pass | `state.json` valid, `done`; PR #17 base `main`, `Closes #4` |
| CR-4 | pass | `npm ci`, lint 0, Vitest 221 passed, `tsc` 0, build 0 |
| CR-5 | pass | 5 commits, plain trailer |
| CR-6 | none | no guard text in the S4.1 stream or the 11 S4.2 transcripts |
| CR-7 | 1, harness | S4.1: the orchestrator's prescribed `awk '/^## Questions$/…' 01-spec-analysis.md` was denied: the narrowed allow file had no `awk` rule (DESIGN §3: headless runs must allow ship's `awk` reads themselves). Harmless here (the gate went pending), but the QA-routing `awk` reads would block a headless run whose QA fails. **James's decision (2026-10-27, CP for C-1):** add ship's four exact `awk` programs as rules and refine the launcher's one-rule check so a rule may contain parentheses while rule lists stay refused (see Rails and launchers). S4.2: no prompt, settings unchanged |
| CR-8 | pass | review 0, fix 0; 24 minutes of analysis, 19 minutes at the gate, 33 minutes to the PR |
| Introduction (AC-14) | **accurate** | check exit 0. It says a person still has to check the email (and the four extra checks); "The issue left the mail provider open. James chose SMTP … using the nodemailer library. That is a new dependency" (fixes `22b901f` and `7f188e8` seen working in a fresh run); the 10-second wait and why; no personal data in logs; the skipped plan gate |
| Slow stage | recorded | 24 minutes of spec analysis before the gate; the run's own retro attributes its slow stage to the 18-minute wait for James and misses this (triaged in Phase F) |

Merge (CP-3): James merged PR #17 with a normal merge commit (`515c610`, two parents) and deleted the branch; issue #4
closed; `main` fast-forwarded.

Cycles: review 0, fix 0. Problems: the spec analyser's test-method ACs (`637e591`); the harness `awk` gap (James's
decision).

## S5

### S5.1 (attended, no `--auto`, 2026-10-27)

Milestone 1 "Contact page polish" (#5, #6, #7). James ran `e2e-session.sh <sandbox> S5.1 25` and
`/aew:ship-milestone 1` (no mode flag, no `--auto`, so the plan gate fires: the live check of `c3476b8`). Run `m-1`,
07:00:47Z to 07:43:52Z (43 minutes); cost $11.82 (`/usage`), cap $25. James approved the recommended mode and the
plan, and answered nothing else.

| Expectation | Result | Evidence |
|---|---|---|
| [P] `ship-milestone` recommends bulk | pass | AskUserQuestion header `Mode`, `How should aew run milestone m-1 Contact page polish?`, options `Bulk (recommended)` / `Sequential` / `Stop`; James chose bulk; `state.json` `mode` `bulk`, `issues` `[5, 6, 7]` |
| [P] One PR closes all three | pass | PR #18 `Contact page polish`, base `main`, body `Closes #5`, `Closes #6`, `Closes #7`; `milestone-report.md` lists all three as shipped on PR #18; no other open PR |
| Plan gate shows the summary (S1 fix `c3476b8`, live) | **pass** | the gate's question text is a 17-line summary (approach, one WP and why, a line per issue, challenges, risks, "All 28 ACs map to WP-1"), then `.aew/runs/m-1/05-plan.md` on its own line, then `Approve the plan for m-1?`; options `Approve` / `Request changes` / `Stop` |
| QA fix loop (first live run) | pass | cycle 1: TC-12 (#6-AC-10) failed intermittently on desktop, classed `impl_bug`; `log.md` `qa running — fix 1: developer`; fix `6a02c42` (re-read the restored message on `pageshow`); cycle 2: 30/30 TCs, TC-12 passing 40 of 40 repeats |
| Spec revision (bulk, per issue) | pass | `spec revision: #6 v2` (non-material); `aew:spec-revised` on #6 only |
| CR-1, CR-2 | pass | `state.json` valid, `done`; #5 and #7 `aew:ready-for-review`, #6 also `aew:spec-revised` |
| CR-4 | pass | lint 0, Vitest 228 passed, `tsc` 0, build 0 |
| CR-5 | pass | 6 commits, plain trailer (the `feat` commit names only `(#6)` though it carries all three issues' changes: cosmetic) |
| CR-6, CR-7 | none | no guard text in 14 transcripts; James saw no prompt; settings unchanged |
| CR-8 | pass | review 0, fix 1; 43 minutes |
| Introduction (AC-14) | **accurate** | bulk variant: a milestone opening (why built together, no new dependency, plan approved by James), one paragraph per issue with what visitors see, the rejected site-wide title, #6's clarifications "applied automatically, not by your decision", the QA-found Back-button bug and its fix, no manual checks, the results. Check (`--issues 3`) exit 0 |

Cycles: review 0, fix 1. Duration: 43 minutes. Problems: none in the plugin.

## Guard false positives

## Fix log

| Commit | Problem | Scenario | Re-run | Result |
|---|---|---|---|---|
| `f33feb1` | `skills/init/SKILL.md` was 507 lines, over the 500-line guidance (refactor before any init fix) | init | none needed | 486 lines; suite green |
| `658615f` | init skipped the inferred `retro.repo` question and wrote the plugin repo | init.1 | not re-run: a re-run keeps existing config values; sandbox config corrected by hand (`7caf360`). Re-checked by the next fresh init (S9, if it runs) | `skills.bats` test red, then green |
| `7ab432b` | init's §13 clean-up prompted in an attended session (two lines, no rule) | init.1 | as above | `skills.bats` test red, then green |
| `c3476b8` | the plan gate asked "Approve the plan for #1?" with no summary or plan path | S1.1 | S5.1 (attended, no `--auto`), James's choice | `skills.bats` test red, then green; **verified live in S5.1**: 17-line summary and the path in the question |
| `444a579` | a headless run cannot read the plugin's references and templates (Read outside the working directories needs approval) | S2.1 | S2.2 (and every later headless run) | `skills.bats` test red, then green; S2.2 read them |
| `7f188e8` | the PR introduction did not mention new dev dependencies added under `--auto` without the plan gate's approval | S2.3 | S2.4 (`--from docs`) | `skills.bats` test red, then green; S2.4's introduction names them |
| `22b901f` | the introduction stated gate answers as plain facts, not as what the issue left open and James decided | S3.1 | S3.3 | test red, then green; S3.3's introduction names the open questions and the answers |
| `468ed5f` | on a `--from docs` re-run the doc-writer kept its earlier PR body as "already accurate", so new rules were never applied | S3.2 | S3.3 | test red, then green; S3.3 rewrote the introduction |
| `97291e4` | no stage ran `commands.build` (developer: lint, format, typecheck, unit; QA and review never build) | S3.2 report | next full run (S4) | test red, then green; DESIGN records it |
| `88f26c7` | `gh-retro.sh` warned on every run after the first that the `retro` label already exists | S3.2 | S3.3 | bats red, then green; no warning in S3.3 |
| `d141b4d` | the orchestrator checked ARTEFACTS with a `for` loop, denied headless (recurred) | S3.2, S3.3 | next headless run | test red, then green |
| `637e591` | the spec analyser added ACs about how a criterion is tested, turning one manual check into five | S4.2 | not re-run (about $12) | test red, then green |
| `43ee2fe` | AC-20: the "no rewrite of a real issue body" limitation lifted after the evidence (v1 byte-identical on #1, #3 and #4; S4's manual-tests block lost no line) | S1, S3, S4 | none | the limitation line is gone from `skills/github-ops/SKILL.md` and `CHANGELOG.md`; suite green |

## Retro triage

## Roll-up
