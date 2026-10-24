# Build prompts — how to use

These seven prompts build the plugin described in `docs/DESIGN.md`, in order. Each one builds on the committed output of the previous one.

| # | Prompt | Builds |
|---|---|---|
| 01 | `01-scaffold.md` | Manifest, marketplace, dependencies, schemas, artefact templates, run-protocol skill |
| 02 | `02-scripts-and-hooks.md` | State and git scripts, all GitHub I/O scripts, guard and gate hooks, github-ops skill, script tests |
| 03 | `03-planning-agents.md` | Stack detection, standards system and seeds, spec-analyser, brief-compiler, standards-setter, senior-engineer |
| 04 | `04-build-agents.md` | developer, qa-engineer, doc-writer, ui-qa and claude-md-curation skills, Playwright MCP |
| 05 | `05-orchestrator.md` | init, ship, resume, status, prompt skills |
| 06 | `06-milestone-mode.md` | ship-milestone (bulk and sequential) |
| 07 | `07-e2e-validation.md` | Real GitHub sandbox runs, fixes, README, 0.1.0 release |

## Running them

1. Open Claude Code in this repo and use Opus for all seven. You're building the tool everything else depends on.
2. Start each prompt in a fresh session (`/clear`). Send:
   > Carry out the prompt in @docs/build-prompts/01-scaffold.md
3. When it finishes, read its summary and diff. Pay particular attention to any change it made to `docs/DESIGN.md`; prompts are told to update the design when the current docs contradict it. Answer its questions, then move to the next prompt.
4. Prompts 03, 04 and 07 are the longest and the most expensive. 07 creates a private sandbox repo on your GitHub account.

## Shared ground rules (every prompt repeats these)

- `docs/DESIGN.md` is the source of truth.
- Verify Claude Code features against the current docs rather than relying on memory.
- Work autonomously, and ask only on genuine blockers.
- Use British English.
- End with a summary and a conventional commit.
