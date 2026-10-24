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

### Changed

- `CLAUDE.md`: the ajv validation command now uses `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats`.
- `docs/DESIGN.md` §3/§11 and `state-machine.md`: gate failure path aligned with the verified hook documentation.
