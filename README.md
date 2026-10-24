# aew

A personal Claude Code plugin that delivers GitHub issues end to end through a spec-driven,
multi-agent pipeline. Each issue is treated as a spec. The pipeline runs: analyse the spec →
compile a brief → set standards → plan → build → review → test (including UI) → document →
open a PR ready for review.

**Status: in development.** The design is in [`docs/DESIGN.md`](docs/DESIGN.md) and the build
order is in [`docs/build-prompts/`](docs/build-prompts/00-README.md).

## Install

This repo is both the plugin and a personal marketplace, `jamesborg-plugins`.

```bash
claude plugin marketplace add /path/to/claude-agentic-engineer-workflow
claude plugin install aew@jamesborg-plugins
```

To try it for one session without installing it, run `claude --plugin-dir .` from the repo. The
dependencies below must already be installed, because a `--plugin-dir` session doesn't install them.

## Prerequisites

git, gh (authenticated), jq, Node 20 or later, plus stack tools as needed (php/composer, dotnet,
Docker for wp-env or ddev).

## Dependencies

Declared in `.claude-plugin/plugin.json`, all from the official `claude-plugins-official` marketplace:

| Plugin | Used for |
|---|---|
| `superpowers` | TDD, debugging and verification skills preloaded into specific agents |
| `context7` | Current library and framework docs |
| `frontend-design` | UI work packages |

**Cross-marketplace config.** Claude Code won't install a dependency from a different marketplace
unless the root marketplace allows it. `.claude-plugin/marketplace.json` therefore sets
`"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]`. Without it, the install
completes without the dependencies and `aew` fails to load. If `claude-plugins-official` isn't
in `claude plugin marketplace list`, add it with
`claude plugin marketplace add anthropics/claude-plugins-official`.

**Why superpowers has no version range.** A version range resolves only against git tags named
`superpowers--v<version>`. The superpowers repo tags releases as `v<version>`, so a range such as
`^7.0.0` would make the install fail. The official marketplace pins superpowers to a commit
(v7.0.0 when this was written), so the dependency moves only when that pin does. `aew` is built
against superpowers 7.x.

**Installing the dependencies by hand.** Do this when using `--plugin-dir`, or if the install
skipped them:

```bash
claude plugin install superpowers@claude-plugins-official
claude plugin install context7@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
```

A copy of superpowers from another marketplace, such as `anthropic-plugin-directory`, doesn't
satisfy `superpowers@claude-plugins-official`. The CLI treats it as the same plugin and installs
nothing, so switch it over with
`claude plugin install superpowers@claude-plugins-official --replace`.

## Commands

_To be written._

## Config reference

`.aew/config.json` in the target project. Schema: [`templates/config.schema.json`](templates/config.schema.json).
Example: [`templates/config.example.json`](templates/config.example.json).

_Field reference to be written._

## Labels

_To be written._

## Troubleshooting

- **`Dependency "superpowers@claude-plugins-official" is not installed`:** install the dependencies
  (see above), then run `/reload-plugins`.

## Uninstall

_To be written._
