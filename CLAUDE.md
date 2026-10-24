# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`aew` is a Claude Code plugin (and its own personal marketplace, `jamesborg-plugins`) that delivers
GitHub issues end to end through a spec-driven, multi-agent pipeline. It is in development and is
being built in stages from the prompts in `docs/build-prompts/` (01 scaffold → 07 e2e validation),
each run in a fresh session and building on the committed output of the previous one.

- `docs/DESIGN.md` is the source of truth. If a build prompt and DESIGN.md disagree, DESIGN.md wins
  and the conflict is flagged. If the current Claude Code docs contradict DESIGN.md §3/§11, follow the
  docs and update DESIGN.md in the same commit.
- Verify Claude Code features (manifest keys, frontmatter, hook events/payloads, namespacing,
  `CLAUDE_PLUGIN_ROOT`, CLI flags) against code.claude.com/docs, not memory.
- British English in all prose. Conventional commits. Keep `CHANGELOG.md` (Keep a Changelog) updated.
- Simplicity first: no files, options or abstractions DESIGN.md doesn't call for. Only create a
  directory when it gets files.

## Commands

```bash
claude plugin validate .        # validate plugin + marketplace manifests and components
claude --plugin-dir .           # load the plugin for one session (dependencies must already be installed)

# validate an example against its schema (JSON Schema draft 2020-12; ajv-formats needed for date-time)
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s templates/config.schema.json -d templates/config.example.json
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s templates/state.schema.json  -d templates/state.example.json
```

Scripts (from build prompt 02 onward) must be bash with `set -euo pipefail`, shellcheck-clean, support
`--help`, and be tested with a mocked `gh` (PATH shim) under `tests/scripts/`, run via
`tests/run-script-tests.sh` (bats-core where available). `tests/tmp/` is gitignored scratch space.

## Architecture

**Plugin layout.** `.claude-plugin/` holds only `plugin.json` and `marketplace.json`. Components live
at the plugin root: `skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `scripts/`. A `CLAUDE.md` at
the plugin root (this file) is not loaded by the plugin — it is only for working on this repo.
Skills are invoked as `/aew:<skill>`, agents are `aew:<agent>`.

**Dependencies** (`plugin.json`): superpowers, context7, frontend-design, all from
`claude-plugins-official`. `marketplace.json` must keep `allowCrossMarketplaceDependenciesOn:
["claude-plugins-official"]` or installs silently skip them. superpowers deliberately has no version
range (its tags are `v<x>`, not `superpowers--v<x>`, so a range breaks the install).

**Pipeline model.** The orchestrator (the `ship` skill, main thread) drives one run per issue (or
`m-<n>` per milestone) through fixed stages: `spec_analysis → brief → standards → qa_test_plan ∥ plan
→ (plan gate) → develop → review → qa → docs → pr`. Each stage is a specialised agent (spec-analyser,
brief-compiler, standards-setter, senior-engineer, developer, qa-engineer, doc-writer).

Key contracts every component must respect (full detail in `skills/run-protocol/`):

- **Agents communicate through files, never chat.** All working state lives in the target project's
  gitignored `.aew/runs/<run-id>/`, with fixed, numbered artefact names (`01-spec-analysis.md` …
  `10-summary.md`). Every artefact starts from its template in `templates/artefacts/` and keeps its
  sections and order. `.aew/runs/current` holds the active run id (hooks read it).
- **Return contract.** Every agent ends its final message and primary artefact with the four-line
  `STATUS / ARTEFACTS / SUMMARY / NEXT` block. The orchestrator routes on these and only opens full
  artefacts when a gate needs them.
- **Agents never touch GitHub.** Only the orchestrator does, and only through the plugin's
  `scripts/gh-*.sh` and `git-branch.sh push`. Agents read issue content from `00-issue-original.md`
  and `issue.json`. This keeps agents testable offline.
- **State is script-owned.** `state.json` and `log.md` are written only by `scripts/state.sh`, and
  must stay valid against `templates/state.schema.json`. Project config is `.aew/config.json`
  (schema `templates/config.schema.json`; config holds env-var names, never secrets).
- **Labels.** Exactly one `aew:<stage>` label on an issue at a time, plus the flags
  `aew:spec-revised` and `aew:manual-test-required`; set only via `gh-labels.sh`.
- **Hooks** (DESIGN §11) are safety guards (Bash, Edit/Write) and gates (`SubagentStop` for developer
  and qa-engineer) plus a `SessionStart` resume hint. They must honour `stop_hook_active`, fail open
  with a stderr warning when jq/config/state is missing, and finish in under a second.
