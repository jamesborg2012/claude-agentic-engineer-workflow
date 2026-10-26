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
  `Bash(*)`). An allow file may not set `--disallowedTools`, a permission mode or a launcher flag.
- **Kill.** SIGINT first (V-9: it ends the turn), TERM after 30 s, KILL after a further 30 s; `killed-at` records the
  time and the signal that ended it. The session starts as a job-controlled background job (`set -m`) so it keeps
  SIGINT, which a plain non-interactive `&` job ignores.
- **Audit (C3 as amended by CTO C-2).** After every session, every `tool_use` on every thread (headless: the stream;
  attended: the session's transcript files under `~/.claude/projects/<sandbox>/` written since the start, main and
  subagents). Bash commands are checked for the credential set
  `GH_TOKEN|GITHUB_TOKEN|GH_HOST|GH_CONFIG_DIR|GH_ENTERPRISE|auth token|git-credential|osxkeychain|security find-|GIT_CONFIG|GIT_ASKPASS|credential fill|credential\.helper|find-(generic|internet)-password|\.config/gh|env -i`,
  the spawn pattern ``(exec|spawn|popen|passthru|proc_open|system)[A-Za-z_]*\s*\(\s*\[?\s*['"`](gh|git|security|env)\b``,
  the command set `github\.com|--hostname|GH_CONFIG_DIR=|security |credential|remote (add|set-url)|unset |PATH=`, the
  real gh path and any `claude` command other than `claude plugin list --json`. Write, Edit, MultiEdit and NotebookEdit
  input is checked for the credential set, the spawn pattern and the real gh path (`credential` and `github.com` are
  left out for file contents, which use them legitimately). Any MCP tool outside `plugin_aew_playwright` and
  `plugin_context7_context7` is a hit. A hit exits 4 (`AUDIT HIT`). A genuine false positive is allowed only by its
  exact string in `audit-allow.json`, recorded here.
- **Attended mode.** The same preconditions, environment, lock, C-1 check, fixed denies and post-session checks.
  `--max-budget-usd` works only with `--print` (V-8), so the launcher prints "read /usage at each gate and stop at
  $<cap>" and keeps the cap reserved in the ledger until James's `/usage` figure is written in. The audit runs over
  the transcripts, so the attended gap the plan expected is closed.
- **Kept unchanged:** the CTO-5 ledger lock, the port-4173 stop, the CTO-3 git guard (plugin repo config and hooks),
  the plugin-repo HEAD check, the empty `ghcfg` check and the "use the next attempt name" refusal. The stop is $200.

**Self-test** (`selftest.sh`, a stub `claude` first on `PATH`, a dummy `.pat`, no API call): 61 passed, 0 failed
after two launcher fixes (the inherited `GIT_EDITOR`, and a jq error that silently skipped the file-content audit)
and one test fix (the kill fired before the stub set its trap). It covers:

| Case | Result |
|---|---|
| Normal session | exit 0, ledger row `cap cost start`, audit clean |
| Same run name again; 199 spent plus cap 2; ledger lock held for 2 s | exit 2; exit 3; waits, then starts |
| argv | every fixed deny and `--permission-prompts none`; no `--plugin-dir`, `--add-dir` or `--settings` |
| Session env names | exactly `GH_CONFIG_DIR GH_TOKEN GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_0 GIT_CONFIG_VALUE_1 GIT_SSH_COMMAND GIT_TERMINAL_PROMPT`; `GH_TOKEN` length 17 (the dummy) |
| Command audit hits (exit 4) | `unset GH_HOST`, `echo $GH_HOST`, `PATH=/tmp:$PATH claude -p x`, `env -u GH_TOKEN gh auth token`, `/opt/homebrew/bin/gh api user`, `git remote set-url origin x`, `curl https://github.com/x`, `env -i PATH=/usr/bin gh api user` |
| File-content audit hits (exit 4) | a Write of `process.env.GH_TOKEN`; a Write of `execSync('gh api user', {env:{}})` |
| Non-hits (exit 0) | `claude plugin list --json \| jq .`, `"<installPath>/scripts/state.sh" get stage`, `npm test`, a Write of `fetch('/api/contact', { method: 'POST', credentials: 'same-origin' })` |
| A file written into `ghcfg` | exit 4 |
| Refusals (exit 2) | allow rules `Bash(gh *)`, `Bash`, `Bash(*)`, `Bash(node *)`, `Bash(sh -c *)`, `Bash(npx *)`, `Bash(curl *)`, `Bash(env)`; `--permission-mode=default`; `--disallowedTools` in an allow file; `Bash(npx *)` in the project's `settings.local.json` (C-1); an SSH origin; a non-sandbox origin; a project inside the plugin repo; `.pat` at 644. An `aew-sandbox-woo` origin is accepted. |
| Kill at `develop`, and `<run-id>:develop` | `killed-at` names `INT`, the stub's INT trap ran, the ledger charges the cap |
| `--attended` | a reservation row with an empty cost, the fixed denies in argv, no `-p`/`--plugin-dir`/`--max-budget-usd`, post-checks and the transcript audit ran |
| Leak check | the dummy token appears in no output file |

**Canary** (AC-9; `canary.sh`, every row through `e2e-run.sh --env-check <sandbox>`). The first run (2026-10-26T17:11Z)
failed rows 3, 4, 6 and 7 with `HTTP 401: Bad credentials`: the PAT file did not hold a fine-grained token (wrong
clipboard). James saved it again (93 characters, `github_pat_` prefix, checked without printing it) and the second run
passed:

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

**C3 amended: detect-only for the keychain channel.** With `GH_TOKEN` removed, a session can still read James's keychain
gh token (`gh auth token`, row 9) and git reaches the plugin repo through the gh credential helper (row 9b). C3 asked
for the keychain token to be unreachable. James chose option (a) at A5 (2026-10-26, "Ledger approved, PAT saved,
(a)"), which the CTO risk gate accepted as an amendment to C3 with conditions C-1 to C-3 (the effective-allow-rule
refusal, the widened audit, rows 9 and 9b asserting this result). Rows 9 and 9b are expected to exit 0 on every canary
re-run; a change shows up there.

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

The issue and milestone fixtures follow in Phase B.

## Guard false positives

## Fix log

## Retro triage

## Roll-up
