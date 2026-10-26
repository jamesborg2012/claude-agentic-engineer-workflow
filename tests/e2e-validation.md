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

## Spend ledger

## Sandbox fixtures

## Guard false positives

## Fix log

## Retro triage

## Roll-up
