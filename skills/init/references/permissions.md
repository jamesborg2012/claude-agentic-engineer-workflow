# init: permission rules from the config, and what is never pre-approved

Read by `skills/init/SKILL.md` §10 before it prints the proposal.

## Rules from the config

Added to the portable list (`.claude/settings.json`):

- `commands.install` becomes the exact command, no wildcard (for example `Bash(npm install)`).
- `build`, `lint`, `format`, `typecheck`, `test_unit`, `test_e2e` become `Bash(<command> *)`; a UI project also
  gets `Bash(npx playwright test *)` and `Bash(npx playwright install chromium)`.
- A command becomes a rule only if it is one simple command: no `&`, `|`, `;`, `>`, `<`, `*`, `$(`,
  backtick or newline, and it doesn't start with `cd `, `sh `, `bash `, `env ` or a `NAME=` assignment.
  Anything else is listed as not pre-approved.
- `dev` and `app.start_command` get no rule (QA starts the app through ui-qa §3).
- `commands.seed` gets no rule, because it may reset data.

## Deliberately not pre-approved

These are listed as prose and never written as rules, and they prompt when used:

- `git -C <dir> …`, the sub-developers' worktree form (a wildcard before the subcommand would also match
  `-c core.fsmonitor=<cmd>`).
- `git diff`, `git log`, `git show` and `git format-patch` with a wildcard (`--output=<path>` writes files);
  their read-only forms already run without a prompt.
- `git fetch` and `git ls-remote` with a wildcard (`--upload-pack=<cmd>`), and `git symbolic-ref` with one
  (it can repoint `HEAD`); only the exact preflight and §2 forms are allowed.
- `git push` (it goes through `git-branch.sh` only) and every other `gh` command (only the scripts call `gh`).
- `sh -c`, `nohup`, `cd <dir> && …`, `cp`, `curl`, `kill`, `rm -rf`, `awk` (its programs can write any file),
  `node -p` and bare `npx`, `npm` or `node`, so §6's `npx … ajv validate` prompts (its `-c` loads a module).
- `commands.seed` (may reset data).
