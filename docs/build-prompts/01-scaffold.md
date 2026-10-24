# Prompt 01 — Scaffold, manifest and run protocol

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. That includes manifest keys, agent and skill frontmatter fields, hook events and payloads, MCP tool naming, namespacing, marketplace and dependency syntax, and CLI flags. Use the claude-code-guide agent; don't rely on memory. If the docs contradict DESIGN.md §3, follow the docs, update DESIGN.md in the same commit, and call it out.
- Work autonomously. Stop and ask me only when:
  - a decision isn't covered by DESIGN.md and is expensive to reverse;
  - the docs contradict the design in a way that changes behaviour;
  - you'd need to act outside this repo in a way this prompt doesn't ask for.
- Simplicity first: no abstractions, options or files the design doesn't call for.
- British English in all prose.
- Use superpowers' verification-before-completion before claiming you're done.
- Finish with:
  1. the checks you ran and their results;
  2. the files created or changed;
  3. any deviations from DESIGN.md, and why;
  4. anything I need to decide.

  Then commit with a conventional commit message.

## Goal
Create the plugin skeleton so it loads in Claude Code and declares its dependencies. Define the shared contracts every later part builds on: the config schema, the state schema, the artefact templates and the run protocol.

## Deliverables
1. **Repo basics:**
   - `git init` if needed, with `main` as the default branch;
   - `.gitignore` (node_modules, .DS_Store, `.idea/`, `.junie/`, `tests/tmp/`);
   - `README.md` skeleton (purpose, "status: in development", headings to fill in later);
   - `CHANGELOG.md` in Keep a Changelog format, with an Unreleased section.
2. **`.claude-plugin/plugin.json`:**
   - name `aew`, version `0.1.0`, a description, author James Borg;
   - `dependencies` per DESIGN §4. Pin superpowers to a semver range on its *current* major (look up the current version). Add context7 and frontend-design. Confirm the exact plugin names in `claude-plugins-official`.
3. **`.claude-plugin/marketplace.json`:** a personal local marketplace named `jamesborg-plugins` that lists this plugin with source `./`. Add whatever config the docs require to allow dependencies from `claude-plugins-official`.
4. **`templates/`:**
   - `config.schema.json` (JSON Schema 2020-12) for `.aew/config.json`. Cover every field in DESIGN §6.1, with descriptions and defaults.
   - `config.example.json`, a Next.js + Tailwind example that validates.
   - `state.schema.json` for DESIGN §7.2, plus `state.example.json`.
   - `templates/artefacts/`, one template per artefact in DESIGN §7.1: `spec-analysis.md`, `spec-changes.example.json`, `brief.md`, `standards-run.md`, `qa-test-plan.md`, `plan.md`, `dev-report.md`, `review.md`, `qa-report.md`, `triage.md`, `manual-tests.md`, `summary.md`, `pr-body.md`, `retro.md`, `prompt.md`, `spec-revision-comment.md`.
     - Use exactly the sections specified in DESIGN §8.
     - Each template opens with an HTML comment saying who writes it and who reads it.
     - Each agent-written template ends with the return block from DESIGN §7.5 where relevant.
5. **`skills/run-protocol/`:** an internal reference skill that agents can use but that isn't offered as a slash command. Verify which frontmatter fields achieve that.
   - `SKILL.md`, 150 lines or fewer, covering:
     - the run directory layout;
     - the stages and state machine;
     - the labels;
     - the agent return contract;
     - the "agents never touch GitHub" rule;
     - file naming.
   - Put the detail in `references/`:
     - `state-machine.md`, with a Mermaid diagram covering every transition, gate and failure path;
     - `artefacts.md`, a table of artefact → writer → readers → template.
6. Only create a directory when it gets files.

## Acceptance criteria
- `claude --plugin-dir .` starts with no plugin errors. The run-protocol skill is available to agents but isn't offered as a slash command.
- The CLI's plugin validation passes, if the CLI has a validation command (check).
- Both example files validate against their schemas, using `npx ajv-cli` or equivalent with the 2020-12 draft.
- Every stage, label and artefact named in DESIGN §7–§8 appears in run-protocol and the templates, with no extras.
- The dependency declaration matches the current documented syntax. If cross-marketplace dependencies need extra config, it's present and explained in the README.
