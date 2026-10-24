# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Plugin manifest (`aew`) with dependencies on superpowers, context7 and frontend-design.
- Local marketplace `jamesborg-plugins`, allowing dependencies from `claude-plugins-official`.
- Config and state JSON Schemas, with validating examples.
- Artefact templates for every run artefact.
- Internal `run-protocol` skill: run directory layout, stages, state machine, labels, return contract and file naming.
- Scripts under `scripts/`: `state.sh`, `gh-issue.sh`, `gh-labels.sh`, `gh-pr.sh`, `git-branch.sh`, `gh-milestone.sh` and `gh-retro.sh`, with shared libraries and a bats test suite (`tests/run-script-tests.sh`).
- Hooks (`hooks/hooks.json`): a Bash guard, an Edit/Write guard, a SubagentStop gate for developer and QA artefacts, and a SessionStart hint. They are inert outside projects with `.aew/config.json`.
- Internal `github-ops` skill documenting the scripts, the spec-revision recording order, operational rules and known limitations.
- Hook behaviour: the gate allows one corrective block per stop (`stop_hook_active`); agent types are `aew:`-prefixed (`aew:developer`, `aew:qa-engineer`); the guards match `Edit|Write` only.
- Limitation: no rewrite of a real issue body (`revise`, `manual-tests`) until prompt 07's sandbox end-to-end run passes.
- Rollback for hooks: disable the plugin (or start Claude Code without `--plugin-dir .`), or delete `hooks/hooks.json`. Do not remove `.aew/config.json` as a kill switch; aew itself needs it.
- `scripts/detect-stack.sh`: stack detection (`{profile,path,version,evidence}`) and a `fingerprint` subcommand, with bats tests and detection fixtures.
- Internal `stack-standards` skill: the standards document structure and six seeds (Next.js, React, Tailwind, Laravel, WordPress, WooCommerce).
- The four planning agents: `spec-analyser`, `brief-compiler`, `standards-setter` and `senior-engineer` (plan, review and triage modes), plus issue and brief fixtures.
- Headless agent smoke harness and recorded results in `tests/agent-smoke/README.md`.
- Agents that hold Bash (`standards-setter`, `senior-engineer`) search with `find` and `grep`; `Glob` and `Grep` are not in the default tool set on macOS and Linux.

### Changed

- `CLAUDE.md`: the ajv validation command now uses `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats`.
- `docs/DESIGN.md` §3/§11 and `state-machine.md`: gate failure path aligned with the verified hook documentation.
- `scripts/hooks/guard-bash.sh` now denies any `gh` command from an `aew:*` agent (agents never touch GitHub).
- `tests/scripts/conventions.bats`: the no-argument rule is narrowed so scripts whose arguments are all optional (`detect-stack.sh`) are exempt.
- `docs/DESIGN.md` §3 records the platform facts verified in the smoke runs (skill preloading, `agent_type`, memory directory, path variables, search tools).
