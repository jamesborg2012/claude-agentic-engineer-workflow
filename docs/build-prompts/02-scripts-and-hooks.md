# Prompt 02 — Scripts, GitHub I/O and hooks

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. That includes hook event names, matcher semantics, stdin payload shapes, response formats, environment variables such as `CLAUDE_PLUGIN_ROOT`, and CLI flags. Use the claude-code-guide agent; don't rely on memory. If the docs contradict DESIGN.md §3 or §11, follow the docs, update DESIGN.md in the same commit, and call it out.
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
Build the deterministic layer: shell scripts for run state, git and *all* GitHub I/O, plus the safety and gate hooks. The orchestrator and hooks built later depend on these, so they must be boring, predictable and well tested. Agents never call `gh`; only the orchestrator does, through these scripts (DESIGN §2.4).

## Deliverables
1. **`scripts/lib/common.sh`:**
   - strict mode;
   - logging to stderr;
   - repo root detection;
   - `require_cmd`;
   - a config reader (jq, falling back to the schema defaults from `templates/config.schema.json`);
   - a run dir resolver.
2. **`scripts/state.sh`.** Subcommands:
   - `init <run-id> --issues <n,…> --mode <mode> [--auto] [--title …]`
   - `get [field]`
   - `stage <stage>`
   - `status <status> [--note …]`
   - `bump fix_cycle|review_cycle`
   - `set <field> <value>`
   - `current [set <run-id>|clear]`

   It keeps `state.json` valid against `templates/state.schema.json`, appends one line per transition to `log.md`, and maintains `.aew/runs/current`.
3. **`scripts/gh-issue.sh`.** Subcommands:
   - `fetch <n> <run-dir>` writes `issue.json` and `00-issue-original.md`. Include body, comments, labels, milestone, assignees, and linked or referenced issues.
   - `revise <n> <spec-final.md> <version>` sets the body to: marker `<!-- aew:spec vN -->` + the revised spec + every earlier version collapsed in `<details>`. It must be **idempotent**, and v1 is always preserved.
   - `comment <n> <file>`
   - `manual-tests <n> <file>` adds or replaces a marker-delimited "Manual testing required" section in the body.
4. **`scripts/gh-labels.sh`.** Subcommands:
   - `ensure` creates or updates every label in DESIGN §7.4, with colours and descriptions.
   - `stage <n> <stage>` ensures exactly one stage label at a time.
   - `flag <n> add|remove <flag>`
5. **`scripts/gh-pr.sh`.** Subcommands:
   - `create <run-id> <body-file> [--base <branch>] [--draft]` adds closing keywords for every issue in the run.
   - `update <pr> <body-file>`
   - `ready <pr>`
   - `comment <pr> <file>`
6. **`scripts/gh-milestone.sh`.**
   - `issues <milestone>` outputs JSON: `[{number, title, labels, state, depends_on: [n…]}]`.
   - `depends_on` is parsed from "Blocked by #n", "Depends on #n" and task-list references.
   - Accepts a milestone number or title.
7. **`scripts/gh-retro.sh`.**
   - `file <retro.md> <source-repo> <run-id>` reads the retro repo from config.
   - For each item, it searches open issues with the retro label. On a close title match it adds a comment ("seen again in <repo> run <id>"); otherwise it creates a new issue.
8. **`scripts/git-branch.sh`.**
   - `create <run-id> <slug> [--base <branch>]` uses the configured branch pattern and refuses on a dirty tree.
   - `push` pushes the current branch with an upstream, and refuses if it's the default branch.
9. **Hooks** (`hooks/hooks.json` plus `scripts/hooks/*.sh`). Implement exactly DESIGN §11.
   - Use `${CLAUDE_PLUGIN_ROOT}` paths.
   - Before writing, verify each event name, how `SubagentStop` matching works for a namespaced plugin agent, and the payload and response shapes.
10. **`skills/github-ops/`:** an internal reference skill (not a slash command) for the orchestrator. It covers when and how to use each script, with examples, and the rule that agents never call `gh`.
11. **Tests in `tests/scripts/`:**
    - Use bats-core if it's installed. Otherwise write a minimal bash test runner; don't install global tools without asking.
    - Mock `gh` with a PATH shim that records its arguments and returns fixture JSON.
    - Hook tests feed sample payload JSON on stdin.
    - Add one `tests/run-script-tests.sh` entry point.

## Acceptance criteria
- `shellcheck` is clean on every script. Every script supports `--help` and exits non-zero with a clear message on bad input.
- `gh-issue.sh revise` run twice with the same version produces an identical body. A v3 revision preserves v1 and v2, collapsed. No author content is ever lost (test it).
- `gh-labels.sh stage` leaves exactly one stage label in place (test it).
- The Bash guard has a test table of at least 20 cases.
  - **Blocked:** `git push origin main`, `git push` while on main, `git push -f`, `git push --force-with-lease`, `gh pr merge 3`, `gh repo delete`, `git reset --hard` on main, `rm -rf /`, `rm -rf ~`, `rm -rf ..`, `git clean -fdx`.
  - **Allowed:** push of a feature branch, `rm -rf node_modules`, `rm -rf tests/tmp`, `npm test`, `git reset --hard` on a feature branch, `gh issue view 3`.
  - All cases pass.
- The Edit/Write guard blocks `.env`, `.env.local` and `.git/config`, and allows `.env.example`.
- Hooks run in under a second, honour `stop_hook_active`, and fail open (exit 0 with a stderr warning) when jq, the config or the state file is missing.
- `tests/run-script-tests.sh` passes from a clean checkout.
