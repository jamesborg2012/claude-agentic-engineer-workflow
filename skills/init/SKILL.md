---
name: init
description: Sets a project up for aew by checking prerequisites, detecting stacks, writing .aew/config.json, ensuring labels and gitignore lines, offering Playwright, adding a CLAUDE.md section, proposing permissions, generating the first standards docs, and opening a PR from chore/aew-init. Safe to re-run, because it only adds what is missing.
disable-model-invocation: true
---

# aew init

Prepares the current project for aew on a `chore/aew-init` branch and opens a PR. The plugin root is
`${CLAUDE_PLUGIN_ROOT}`. Run plugin scripts by their full quoted path, as the snippets do. Run snippets from
the project root, one Bash call per snippet, and replace every `<…>` placeholder before running one.
Write every command with literal paths and values: no shell variables, `$(…)`, loops, `VAR=value` prefixes
or jq `--slurpfile` (a headless run denies those before any allow rule applies). Where a step depends on
printed output, read it, then write the next command literally.

Init takes no arguments. If any were given, stop with `usage: /aew:init (no arguments)`.

**The ask rule.** Init asks at most twice: the §5 question round and the §10 permissions question. If
AskUserQuestion is not in your tool list (headless runs), don't try to call it. Use each question's default
and list it in the report. A refused or empty answer also takes the default. The defaults are the
recommended config values, Playwright skipped, and permissions not written. All of them can be reviewed in
the PR.

**Idempotency.** Every step checks before it writes and says when it is a no-op. A second run on an unchanged
repo changes no file and makes no commit, push or new PR.

**Init's files.** These are the only files init writes or stages:

- `.gitignore`, `.aew/config.json`, `CLAUDE.md`, and on a yes `.claude/settings.json` and
  `.claude/settings.local.json` (gitignored, so never committed or listed by §12)
- `docs/standards/**` and `.claude/agent-memory/aew-standards-setter/**` (from the standards-setter)
- only when the Playwright offer is accepted, the ui-qa §2 files (`package.json`, the lock file,
  `playwright.config.ts`, `<ui.e2e_dir>/aew.ts`, or the nested `tests/e2e/` package)

Scratch files, flat in the gitignored `.aew/runs/` and removed in §13: `init-config.json`,
`init-config-merged.json`, `init-permissions.json`, `init-permissions-local.json`, `init-settings.json`, `init-pr-body.md`.

Never install a global tool. Touch GitHub only through `gh auth status` and the plugin scripts named here.

## 1. Prerequisites

```sh
command -v git jq node gh
node --version
```

```sh
git rev-parse --show-toplevel --show-prefix
git remote -v
```

```sh
gh auth status
```

`command -v` prints a path for each tool it finds (no line means missing), `node --version` prints
`v<major>.…`, and the second `rev-parse` line is empty at the repository root. Any failure stops init with
nothing written. Quote gh's own output when `gh auth status` fails. `gh auth status` stays a separate, exact
call so `Bash(gh auth status)` matches it.

| Failure | Stop message and hint |
|---|---|
| no `git` line | git is required. On macOS run `xcode-select --install`, otherwise use the OS package manager. |
| no `gh` line | The GitHub CLI is required. Install it from https://cli.github.com, then run `gh auth login`. |
| `gh auth status` fails | gh is not logged in. Run `gh auth login`, then re-run `/aew:init`. |
| no `jq` line | jq is required. `brew install jq`, or use the OS package manager. |
| no `node` line, or a major version below 20 | Node 20 or later is required. Install it from https://nodejs.org or with a version manager such as `nvm install 20`. |
| `rev-parse` fails (not a git repo), or its second line is not empty | Run `/aew:init` from the repository root. |
| No `origin` line from `git remote -v` | Add the GitHub remote as `origin`, then re-run. |

## 2. Clean tree and branch

Work out the default branch. The first non-empty answer wins.

```sh
jq -r '.default_branch // empty' .aew/config.json 2> /dev/null || true
git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true
git ls-remote --symref origin HEAD || true
git branch --show-current
```

Use the existing config's value, else `origin/HEAD` without the `origin/` prefix, else the
`ref: refs/heads/<name>` line of `ls-remote`, else the current branch, marked uncertain (asked in §5).

Require a clean tree.

```sh
git status --porcelain --untracked-files=all
```

Empty output means continue. Anything else stops init: list the paths and say "commit or stash these first".
One exception: on `chore/aew-init`, when every listed path is one of Init's files, continue. That is an
interrupted earlier init, and this run finishes it.

Create or reuse the branch.

```sh
if git rev-parse --verify refs/heads/chore/aew-init > /dev/null 2>&1 ||
   git rev-parse --verify refs/remotes/origin/chore/aew-init > /dev/null 2>&1; then
  git switch chore/aew-init
  if git merge-base --is-ancestor HEAD <default_branch>; then
    git switch -C chore/aew-init <default_branch>
    echo "restarted chore/aew-init from <default_branch>"
  elif ! git merge-base --is-ancestor <default_branch> HEAD; then
    echo "chore/aew-init is older than <default_branch>: if its PR is merged or closed run \`git switch <default_branch>\` and \`git branch -D chore/aew-init\`, otherwise rebase it, then re-run /aew:init"
  fi
else
  git switch -c chore/aew-init <default_branch>
fi
```

An existing branch (local or on `origin`) is switched to. When all its commits are in the default branch
(merged, or never committed) it is restarted there, which loses nothing. When the default branch has moved on
and the branch has its own commits (a squash-merged or closed PR), the snippet prints the `older than`
message and init stops there: the user decides, and init never deletes or rebases it. Otherwise (ahead of the
default branch, the usual re-run) it is reused.

A new branch starts from the local default branch (no fetch or fast-forward). A switch failure stops init.

## 3. Gitignore

Do this before any scratch file is written.

```sh
if grep -qxF '.aew/runs/' .gitignore 2> /dev/null; then echo "present .aew/runs/"; else
  if tail -c 1 .gitignore 2> /dev/null | grep -q .; then printf '\n' >> .gitignore; fi
  printf '%s\n' '.aew/runs/' >> .gitignore; echo "added .aew/runs/"
fi
if grep -qxF '.playwright-mcp/' .gitignore 2> /dev/null; then echo "present .playwright-mcp/"; else
  if tail -c 1 .gitignore 2> /dev/null | grep -q .; then printf '\n' >> .gitignore; fi
  printf '%s\n' '.playwright-mcp/' >> .gitignore; echo "added .playwright-mcp/"
fi
```

Each line is matched exactly, so it appears once, and a missing final newline is repaired before an append
(the pattern for any gitignore line); §10 adds `.claude/settings.local.json` only on a yes.

## 4. Detect and discover

Detect the stacks. Drop `evidence` from the output.

```sh
"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" . | jq -c 'map(del(.evidence))'
```

A non-zero exit stops init: quote the script's `error:` line. `[]` also stops init: "no supported stack
detected; aew needs at least one (nextjs, react, laravel, wordpress, dotnet, with tailwind and woocommerce
overlays)", since the schema requires one.

Then build a discovery table (source, field and value, certain or inferred); §5 asks about inferred rows only.

| Source | Field and value | Certainty |
|---|---|---|
| `package.json` scripts, in each stack path that has one | Each script maps to `<pm> run <script>`: `dev` is dev, `build` is build, `lint` is lint, `format` and `format:check` are format, `typecheck` and `type-check` are typecheck, `test` and `test:unit` are test_unit, `test:e2e` and `e2e` are test_e2e, `seed` and `db:seed` are seed | certain |
| Lock file (package manager, the same rule as `${CLAUDE_PLUGIN_ROOT}/skills/ui-qa/SKILL.md` §2) | `pnpm-lock.yaml` is pnpm, `yarn.lock` is yarn, `bun.lock` or `bun.lockb` is bun, otherwise npm. `install` is `npm ci` with a `package-lock.json`, otherwise `<pm> install` | certain when a lock file names the manager, inferred with no lock file |
| `tsconfig.json` and no typecheck script | typecheck `npx tsc --noEmit` | inferred |
| `@playwright/test` in a `package.json` and no e2e script | test_e2e `npx playwright test` | certain |
| `composer.json` scripts | `test` is test_unit `composer test`, `lint` is lint, `format` is format, `analyse` and `phpstan` are typecheck; install is `composer install` | certain |
| `artisan` | test_unit `php artisan test` when there is no composer test script; seed `php artisan db:seed`; app start `php artisan serve`, `base_url` `http://127.0.0.1:8000`, `env_type` `native` | inferred |
| `.wp-env.json` | `env_type` `wp-env`, start `npx wp-env start`, `base_url` `http://localhost:<port>` (default 8888), ready_check is the base_url | certain |
| `.ddev/config.yaml` | `env_type` `ddev`, start `ddev start`, `base_url` `https://<name>.ddev.site` from its `name:` | certain |
| `*.csproj` (depth 3 or less) | build `dotnet build`; test_unit `dotnet test` when a `*Tests.csproj` exists; format `dotnet format --verify-no-changes`; app start `dotnet run --project <web csproj>`, `base_url` from the first `http://` applicationUrl in `Properties/launchSettings.json`, else `http://localhost:5000`, `env_type` `native` | commands certain, app inferred |
| `docker-compose.yml` or `compose.yaml`, with no wp-env or ddev | `env_type` `docker`, start `docker compose up -d` | inferred |
| wordpress or woocommerce, with no `.wp-env.json`, no `.ddev/` and no compose file | `env_type` `local` (a Local-style site), `base_url` `http://<project>.local`, empty `start_command`, ready_check is the base_url | inferred |
| nextjs, or react (Vite) | `base_url` `http://localhost:3000` (nextjs) or `http://localhost:5173` (react); start is the dev command, ready_check is the base_url, `env_type` `native` | inferred unless a script pins a port |
| no app at all | `env_type` `none`, `base_url` `http://localhost`, empty `start_command` and `ready_check` | inferred |
| `project` | the root `package.json` `name`, else the `composer.json` `name` after the `/`, else the first `.csproj` basename, else the directory name | certain when found in a manifest |
| `default_branch` | from §2 | certain, or inferred when §2 marked it uncertain |
| `retro.repo` | `jamesborg2012/claude-agentic-engineer-workflow` | inferred |

Commands not found are left out (the schema has no required command keys). To read a stack path's files
(the lock file in the listing names the package manager) and scripts, replace `<stack_path>`:

```sh
ls -a <stack_path>
jq -r '.scripts // {} | keys[]' <stack_path>/package.json
```

**Stack tools.** Warn, never stop. The tools to look for: nextjs, react and tailwind need the package
manager's binary; laravel needs `php` and `composer`; wordpress and woocommerce need `php` and `composer`,
plus `docker` when `.wp-env.json` or `.ddev/` exists; dotnet needs `dotnet`. Replace `<tools>` with the
space-separated list.

```sh
command -v <tools>
```

A tool with no line is missing: a §13 warning with an install hint. Nothing is installed.

**UI project** (§5, §10): a detected nextjs, react, tailwind, wordpress or woocommerce profile, or a `pages/`,
`app/`, `resources/views/` or `wp-content/themes/` directory.

Put the proposal together in schema key order (`project`, `default_branch`, `stacks`, `commands`, `app`,
`retro`; commands in schema order) with only these six keys. The optional sections (`ui`, `git`, `gates`,
`limits`, `evidence`, `claude_md`) keep their schema defaults until someone edits the config.

## 5. Confirm in one question round

First Write §4's proposal to `.aew/runs/init-config.json` with the Write tool (read it first if it exists).
Print the whole proposal. Mark certain values "found in the repo" and inferred values "inferred".

On a re-run (`.aew/config.json` exists), run this next and print what it shows. The existing value is kept and
never overwritten. Stacks are compared by `(profile, path)`, not by array index, so a newly detected stack is
reported as an addition.

```sh
jq -r -s '.[0] as $e | .[1] as $q
  | ($q | del(.stacks) | paths(scalars) as $x
     | select(($e | getpath($x)) != null and ($e | getpath($x)) != ($q | getpath($x)))
     | "\($x | map(tostring) | join(".")): keeping \($e | getpath($x) | tojson), detected \($q | getpath($x) | tojson)"),
    ($q.stacks[] as $s | ([$e.stacks[] | select(.profile == $s.profile and .path == $s.path)] | first) as $o
     | if $o == null then "stacks: adding \($s.profile) at \($s.path) (\($s.version))"
       elif $o.version != $s.version then "stacks: keeping \($s.profile) at \($s.path) version \($o.version), detected \($s.version)"
       else empty end)' .aew/config.json .aew/runs/init-config.json
```

Then ask **one** AskUserQuestion round: only the inferred values not already in the existing config, plus the
Playwright offer when §4 found a UI project and no `@playwright/test`. Each question puts the recommended
answer first, its label ending "(recommended)", with one or two alternatives ("Other" is always available).

The Playwright question is: "Set up Playwright and axe for UI QA now? This installs `@playwright/test` and
`@axe-core/playwright` as dev dependencies and downloads Chromium." It recommends **skip** (QA sets Playwright
up on first use, ui-qa §2).

If the tool caps questions or options per call, split the round over several calls (still one round).
Nothing to ask means no call. Headless or no answer: use the recommended values (Playwright skipped) and
list them under "Defaults used" in the §13 report.

Write the final proposal, with the answers or defaults, over `.aew/runs/init-config.json` with the Write tool.

## 6. Write and validate the config

Merge the proposal with any existing config, and say whether the result differs.

```sh
mkdir -p .aew
if [ -f .aew/config.json ]; then
  jq -s '.[0] as $e | .[1] as $p | ($p * $e) | .stacks = $e.stacks + [$p.stacks[] | select([.profile, .path] as $k | all($e.stacks[]; [.profile, .path] != $k))]' .aew/config.json .aew/runs/init-config.json > .aew/runs/init-config-merged.json
else
  jq . .aew/runs/init-config.json > .aew/runs/init-config-merged.json
fi
if [ -f .aew/config.json ] && jq -s -e '.[0] == .[1]' .aew/config.json .aew/runs/init-config-merged.json > /dev/null; then
  echo "config unchanged"
else
  echo "config changed"
fi
```

- `$p * $e` is a recursive merge where the existing file wins: missing fields are added, nothing is removed
  or duplicated. `stacks` is a union keyed by `(profile, path)`; existing entries (versions included) are kept
  and a newly detected stack is appended. Merging its own output changes nothing.
- `==` compares JSON values, not text, so a hand-formatted config that holds every value is never rewritten.
  `jq .` output (two-space indent, the proposal's key order) is the stable format.

Run the next snippet only on "config changed". It validates the scratch copy, then replaces the live file.

```sh
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json" -d .aew/runs/init-config-merged.json && jq . .aew/runs/init-config-merged.json > .aew/config.json && echo "config written"
```

An invalid result stops init before §7 and quotes ajv's errors; the live config is untouched.

## 7. Labels

Create or update the aew labels (idempotent; runs on every init).

```sh
"${CLAUDE_PLUGIN_ROOT}/scripts/gh-labels.sh" ensure
```

A failure stops init before the commit: quote the error and ask "is `origin` a GitHub repo you can write to?".

## 8. Playwright setup

Only when §5's Playwright offer was answered yes. Read `${CLAUDE_PLUGIN_ROOT}/skills/ui-qa/SKILL.md` `## 2. Setting up
Playwright` with the Read tool and follow it: install with the lock file's package manager, exact-pinned, run
`npx playwright install chromium`, append the missing gitignore lines with the §3 pattern, then write
`playwright.config.ts` from ui-qa §4 and `<ui.e2e_dir>/aew.ts` from ui-qa §6 and §7 (versions live only in
ui-qa). The files go into init's commit. For a root package, then add `commands.test_e2e` as
`npx playwright test` to `.aew/runs/init-config.json` (Read, then Write) and re-run §6.

Otherwise report "Playwright: skipped (QA sets it up on first use)", or "Playwright: present" when
`@playwright/test` was already there. Nothing is installed without a yes.

## 9. CLAUDE.md section

Add the workflow section once; an existing section is left as it is, even if edited.

```sh
[ -f CLAUDE.md ] || printf '# CLAUDE.md\n' > CLAUDE.md
if grep -qxF '## Agentic workflow' CLAUDE.md; then echo "CLAUDE.md section present"; else echo "CLAUDE.md section missing"; fi
```

Only on "missing", append it:

```sh
if tail -c 1 CLAUDE.md | grep -q .; then printf '\n' >> CLAUDE.md; fi
cat >> CLAUDE.md << 'EOF'

## Agentic workflow

Issues are shipped with the aew plugin. Agents follow the stack standards in `docs/standards/` and
record each shipped issue's final spec in `docs/specs/`. Settings are in `.aew/config.json`; run state
in `.aew/runs/` is gitignored.

- `/aew:ship <issue> [--auto]`: spec, plan, build, review, QA, docs and PR for one issue.
- `/aew:resume [<run-id>]`, `/aew:status [<run-id>]`: continue or inspect a run.
- `/aew:prompt <issue>`: spec analysis and a single build prompt, no pipeline.
- `/aew:init`: re-run after the stack changes; it only adds what is missing.
EOF
echo "CLAUDE.md section added"
```

## 10. Permissions proposal

Propose rules that cut down permission prompts for the commands aew runs. Nothing is written without a yes.
`.claude/settings.local.json` holds the plugin scripts by absolute path (gitignored, so this machine's path
never reaches other cloners); `.claude/settings.json` holds the portable rules (committed in the init PR).

Every rule is an exact command, or a subcommand plus a single trailing ` *`; none has a wildcard before the
subcommand. `${CLAUDE_PLUGIN_ROOT}` is substituted when this skill loads, so the proposal carries the real path.

Template 1 is `.claude/settings.local.json`:

```json
{ "permissions": { "allow": [
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/state.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-issue.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-labels.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-milestone.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-pr.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-retro.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/git-branch.sh *)",
  "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh *)"
] } }
```

Template 2 is `.claude/settings.json`. Replace `<default_branch>` with the default branch from the config:

```json
{ "permissions": { "allow": [
  "Bash(gh auth status)",
  "Bash(claude plugin list --json)",
  "Bash(git add *)", "Bash(git commit *)", "Bash(git switch *)", "Bash(git branch *)",
  "Bash(git worktree *)", "Bash(git cherry-pick *)",
  "Bash(git fetch origin <default_branch>)",
  "Bash(git rev-parse *)", "Bash(git rev-list --left-right *)", "Bash(git check-ignore *)",
  "Bash(git symbolic-ref --quiet --short refs/remotes/origin/HEAD)",
  "Bash(git ls-remote --symref origin HEAD)",
  "Bash(git restore -- .claude/agent-memory/aew-standards-setter/)",
  "Bash(command -v *)", "Bash(jq *)", "Bash(echo *)", "Bash(printf *)",
  "Bash(date +%Y-%m-%d)"
] } }
```

The plugin path changes with each version; re-running init adds the new rules and keeps the old, harmless ones.

**Rules from the config**, added to the portable list:

- `commands.install` becomes the exact command, no wildcard (for example `Bash(npm install)`).
- `build`, `lint`, `format`, `typecheck`, `test_unit`, `test_e2e` become `Bash(<command> *)`; a UI project also
  gets `Bash(npx playwright test *)` and `Bash(npx playwright install chromium)`.
- A command becomes a rule only if it is one simple command: no `&`, `|`, `;`, `>`, `<`, `*`, `$(`,
  backtick or newline, and it doesn't start with `cd `, `sh `, `bash `, `env ` or a `NAME=` assignment.
  Anything else is listed as not pre-approved.
- `dev` and `app.start_command` get no rule (QA starts the app through ui-qa §3).
- `commands.seed` gets no rule, because it may reset data.

**Deliberately not pre-approved.** These are listed as prose and never written as rules, and they prompt when
used:

- `git -C <dir> …`, the sub-developers' worktree form (a wildcard before the subcommand would also match
  `-c core.fsmonitor=<cmd>`).
- `git diff`, `git log`, `git show` and `git format-patch` with a wildcard (`--output=<path>` writes files);
  their read-only forms already run without a prompt.
- `git fetch` and `git ls-remote` with a wildcard (`--upload-pack=<cmd>`), and `git symbolic-ref` with one
  (it can repoint `HEAD`); only the exact preflight and §2 forms are allowed.
- `git push` (it goes through `git-branch.sh` only) and every other `gh` command (only the scripts call `gh`).
- `sh -c`, `nohup`, `cd <dir> && …`, `cp`, `curl`, `kill`, `rm -rf`, `awk` (its programs can write any file),
  `node -p` and bare `npx`, `npm` or `node`.
- `commands.seed` (may reset data).

These rules only cut down prompts. They are not a security boundary: the plugin's Bash guard hook is what
blocks dangerous commands. An anchored rule can never match global git options (they sit before the
subcommand), so no deny rules are proposed.

**Ask.** Print both concrete lists, each under its target file (`.claude/settings.json`: portable, committed in
the init PR; `.claude/settings.local.json`: this machine's plugin paths, gitignored), then the not pre-approved
list. Then ask one AskUserQuestion, once, before writing either file: "Write these rules to
`.claude/settings.json` and `.claude/settings.local.json`?" with **Write (recommended)** and Don't write. No
answer or a headless run means write neither (the ask rule): report both lists in §13 for the user to add by
hand, and skip the rest of this section.

**On a yes.** Write the two concrete `{"permissions":{"allow":[…]}}` lists with the Write tool (read each file
first if it already exists): the portable one (template 2 plus the config rules) to
`.aew/runs/init-permissions.json`, and the plugin-script one (template 1) to
`.aew/runs/init-permissions-local.json`. Then run the snippets below in order.

The first makes sure `.claude/settings.local.json` is ignored before it is written: `git check-ignore` honours
every ignore source, so a third `.gitignore` line is added (only on a yes) only when nothing ignores it yet.

```sh
if git ls-files --error-unmatch .claude/settings.local.json > /dev/null 2>&1; then echo "tracked .claude/settings.local.json"
elif git check-ignore -q .claude/settings.local.json; then echo "ignored .claude/settings.local.json"
else
  if tail -c 1 .gitignore 2> /dev/null | grep -q .; then printf '\n' >> .gitignore; fi
  printf '%s\n' '.claude/settings.local.json' >> .gitignore; echo "added .claude/settings.local.json"
fi
```

The second merges one file (a missing file starts as `{}`). Run it with `<settings_file>` =
`.claude/settings.json` and `<rules_file>` = `.aew/runs/init-permissions.json`, then again with
`.claude/settings.local.json` and `.aew/runs/init-permissions-local.json`, unless the first printed
`tracked`: then the user already tracks the local file, so report "skipped .claude/settings.local.json
(tracked)" with its rules.

```sh
mkdir -p .claude
[ -f <settings_file> ] || printf '{}\n' > <settings_file>
if ! jq -s '.[0] as $p | (.[1] // {}) as $e | ($e.permissions.allow // []) as $a | $e | .permissions.allow = $a + (($p.permissions.allow | unique) - $a)' <rules_file> <settings_file> > .aew/runs/init-settings.json; then
  echo "not merged <settings_file> (not valid JSON)"
elif jq -s -e '.[0] == .[1]' <settings_file> .aew/runs/init-settings.json > /dev/null; then
  echo "unchanged <settings_file>"
else
  jq . .aew/runs/init-settings.json > <settings_file> && echo "written <settings_file>"
fi
```

Existing rules keep their order, new ones are appended once, every other key is kept, and an unchanged file
is never rewritten. A file that isn't valid JSON is left untouched: report "not merged" with its rules.

## 11. Standards

Dispatch the Agent tool with `subagent_type: aew:standards-setter` and the prompt exactly `mode: init`. The
last four non-blank lines of the result must be `STATUS: <ok|needs_input|blocked|failed>`, `ARTEFACTS: …`
(`none` allowed), `SUMMARY: …` and `NEXT: …`, each a single value, not the template placeholder. On `ok`, keep
SUMMARY's `<profile>: reused|generated|updated` list for the report. On `blocked`, `failed` or an invalid
block, dispatch once more, then stop before §12 and quote SUMMARY (§2's exception lets the next init finish).

Init commits the agent's shared memory (`.claude/agent-memory/aew-standards-setter/`) too, except that when it
holds the only change in the tree, it is dropped, so a re-run changes nothing.

```sh
git status --porcelain --untracked-files=all
```

If it prints nothing, or any path outside `.claude/agent-memory/aew-standards-setter/`, the memory is kept.
Otherwise run the next snippet, then `rm -f <path> …` with every path it printed, written out literally, and
report "standards-setter memory update discarded (nothing else changed)".

```sh
if git ls-files -m -- .claude/agent-memory/aew-standards-setter/ | grep -q .; then git restore -- .claude/agent-memory/aew-standards-setter/; fi
git ls-files --others --exclude-standard -- .claude/agent-memory/aew-standards-setter/
```

## 12. Commit, push and PR

```sh
git status --porcelain --untracked-files=all
if [ -f .claude/settings.json ] && ! git ls-files --error-unmatch .claude/settings.json > /dev/null 2>&1 && git check-ignore -q .claude/settings.json; then echo "ignored .claude/settings.json (not committed)"; fi
if [ -f .claude/settings.local.json ] && ! git ls-files --error-unmatch .claude/settings.local.json > /dev/null 2>&1 && git check-ignore -q .claude/settings.local.json; then echo "ignored .claude/settings.local.json (not committed)"; fi
```

Every changed path must be one of Init's files, or stop, list the strangers and commit nothing. An
`ignored …` line is not a change: don't force-add it, report it in §13. With changes, `git add -- <path>`
each path (never `git add -A` or `git add .`), then `git commit -m "chore: set up aew"` (no issue ref, no
trailer). Then decide the push and the PR.

```sh
if git rev-parse --verify refs/remotes/origin/chore/aew-init > /dev/null 2>&1; then
  printf 'unpushed '; git rev-list --count origin/chore/aew-init..HEAD
else
  printf 'unpushed '; git rev-list --count <default_branch>..HEAD
fi
printf 'ahead '; git rev-list --count <default_branch>..HEAD
```

- `unpushed` above 0: run `"${CLAUDE_PLUGIN_ROOT}/scripts/git-branch.sh" push`.
- `ahead` above 0, even when nothing was pushed: Write `.aew/runs/init-pr-body.md` (read it first if it
  exists) saying what init did and which defaults need review, then run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-pr.sh" open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base <default_branch>`
  and keep the number. `open` reuses an open PR, so every run is safe and a failed call is retried; on
  failure report the error.
- `ahead` 0: no push, no PR call. Init never deletes a branch (§2 reuses or restarts it).

## 13. Report

```sh
rm -f .aew/runs/init-config.json .aew/runs/init-config-merged.json .aew/runs/init-permissions.json \
  .aew/runs/init-permissions-local.json .aew/runs/init-settings.json .aew/runs/init-pr-body.md
```

Print, in order: prerequisite and stack-tool warnings; stacks; config written or unchanged and the detected
differences kept; "Defaults used"; labels; gitignore lines added or present; Playwright set up, skipped or
present; CLAUDE.md section added or present; permissions for `.claude/settings.json` and
`.claude/settings.local.json` each written, unchanged or proposed only (with the lists), the local file's
`.gitignore` line, and any settings file that is gitignored and so not committed; standards per profile (and
any discarded memory update); the commit sha or "nothing changed"; the PR number or none; next step: "merge
the PR, then `/aew:ship <issue>`".
