---
name: init
description: Sets a project up for aew by checking prerequisites, detecting stacks, writing .aew/config.json, ensuring labels and gitignore lines, offering Playwright, adding a CLAUDE.md section, proposing permissions, generating the first standards docs, and opening a PR from chore/aew-init. Safe to re-run, because it only adds what is missing.
disable-model-invocation: true
---

# aew init

Prepares the current project for aew on a `chore/aew-init` branch and opens a PR. The plugin root is
`${CLAUDE_PLUGIN_ROOT}`. Run plugin scripts by their full quoted path, as the snippets do. Run snippets from
the project root, one Bash call per snippet, and replace every `<…>` placeholder before running one.

Init takes no arguments. If any were given, stop with `usage: /aew:init (no arguments)`.

**The ask rule.** Init asks at most twice: the §5 question round and the §10 permissions question. If
AskUserQuestion is not in your tool list (headless runs), don't try to call it. Use each question's default
and list it in the report. A refused or empty answer also takes the default. The defaults are the
recommended config values, Playwright skipped, and permissions not written. All of them can be reviewed in
the PR.

**Idempotency.** Every step checks before it writes and says when it is a no-op. A second run on an
unchanged repo changes no file and makes no commit, push or PR call.

**Init's files.** These are the only files init writes or stages:

- `.gitignore`, `.aew/config.json`, `CLAUDE.md`
- `.claude/settings.json` (only on a yes) and `.claude/settings.local.json` (only on a yes; gitignored, so
  never committed or listed by §12)
- `docs/standards/**` and `.claude/agent-memory/aew-standards-setter/**` (from the standards-setter)
- only when the Playwright offer is accepted, the ui-qa §2 files (`package.json`, the lock file,
  `playwright.config.ts`, `<ui.e2e_dir>/aew.ts`, or the nested `tests/e2e/` package)

Scratch files live flat in the gitignored `.aew/runs/` and are removed in §13: `init-config.json`,
`init-config-merged.json`, `init-permissions.json`, `init-permissions-local.json`, `init-settings.json`,
`init-pr-body.md`.

Never install a global tool. Never touch GitHub except through `gh auth status` and the plugin scripts named
here.

## 1. Prerequisites

Check the tools, each snippet in its own Bash call.

```sh
for c in git jq node gh; do
  if command -v "$c" > /dev/null 2>&1; then echo "ok $c"; else echo "missing $c"; fi
done
if command -v node > /dev/null 2>&1; then
  v=$(node -p 'process.versions.node')
  if [ "${v%%.*}" -ge 20 ]; then echo "ok node $v"; else echo "old node $v"; fi
fi
```

```sh
git rev-parse --show-toplevel
pwd -P
git remote get-url origin
```

```sh
gh auth status
```

Any of these failures stops init, and nothing is written. Quote gh's own output when `gh auth status` fails.

| Failure | Stop message and hint |
|---|---|
| `missing git` | git is required. On macOS run `xcode-select --install`, otherwise use the OS package manager. |
| `missing gh` | The GitHub CLI is required. Install it from https://cli.github.com, then run `gh auth login`. |
| `gh auth status` fails | gh is not logged in. Run `gh auth login`, then re-run `/aew:init`. |
| `missing jq` | jq is required. `brew install jq`, or use the OS package manager. |
| `missing node` or `old node` | Node 20 or later is required. Install it from https://nodejs.org or with a version manager such as `nvm install 20`. |
| Not inside a git repo, or the top level differs from `pwd -P` | Run `/aew:init` from the repository root. |
| No `origin` | Add the GitHub remote as `origin`, then re-run. |

`gh auth status` stays a separate, exact call so the permission rule `Bash(gh auth status)` matches it and
nothing broader is needed.

## 2. Clean tree and branch

Work out the default branch. The first non-empty answer wins.

```sh
jq -r '.default_branch // empty' .aew/config.json 2> /dev/null || true
git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true
git ls-remote --symref origin HEAD || true
git branch --show-current
```

Use the existing config's value. Otherwise use `origin/HEAD` without the `origin/` prefix, then the
`ref: refs/heads/<name>` line of `ls-remote`. If none of those gives a value, use the current branch and mark
it uncertain (it is asked in §5).

Require a clean tree.

```sh
git status --porcelain --untracked-files=all
```

Empty output means continue. Anything else stops init: list the paths and say "commit or stash these first".
One exception: on `chore/aew-init`, when every listed path is one of Init's files, continue. That is an
interrupted earlier init, and this run finishes it.

Create or reuse the branch.

```sh
if git rev-parse --verify --quiet refs/heads/chore/aew-init > /dev/null ||
   git rev-parse --verify --quiet refs/remotes/origin/chore/aew-init > /dev/null; then
  git switch chore/aew-init
  if git merge-base --is-ancestor HEAD <default_branch>; then
    git switch -C chore/aew-init <default_branch>
    echo "restarted chore/aew-init from <default_branch>"
  elif ! git merge-base --is-ancestor <default_branch> HEAD; then
    echo "chore/aew-init is older than <default_branch>: if its PR is merged or closed run \`git switch <default_branch>\` and \`git branch -D chore/aew-init\`, otherwise rebase it, then re-run /aew:init"
    exit 1
  fi
else
  git switch -c chore/aew-init <default_branch>
fi
```

If the branch already exists locally or on `origin`, init switches to it (git sets up tracking for a
remote-only branch). Then there are three cases:

- Its commits are all in the default branch (its PR was merged, or it never got a commit): init restarts it
  at the default branch. `switch -C` only moves a branch whose work is already merged, so nothing is lost.
- The default branch has moved on and the branch has commits of its own (for example a squash-merged or
  closed PR): init stops on that branch with the message above and changes nothing else. The user decides;
  init never deletes or rebases it.
- Otherwise (the branch is ahead of the default branch, the usual re-run): init reuses it.

A new branch is created from the local default branch. Init doesn't fetch or fast-forward: if the PR shows
conflicts, the user rebases. A switch failure stops init.

## 3. Gitignore

Do this before any scratch file is written, so `.aew/runs/` is ignored from here on.

```sh
touch .gitignore
for l in '.aew/runs/' '.playwright-mcp/'; do
  if grep -qxF "$l" .gitignore; then echo "present $l"; else
    if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then echo >> .gitignore; fi
    echo "$l" >> .gitignore; echo "added $l"
  fi
done
```

The match is an exact line, so each line appears once. A missing final newline is repaired before appending.
Nothing else in the file changes. `.claude/settings.local.json` is added by §10, only when that file is
written.

## 4. Detect and discover

Detect the stacks. Drop `evidence` from the output.

```sh
"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" . | jq -c 'map(del(.evidence))'
```

A non-zero exit stops init: quote the script's `error:` line. `[]` also stops init: "no supported stack
detected; aew needs at least one (nextjs, react, laravel, wordpress, dotnet, with tailwind and woocommerce
overlays)". The config schema requires at least one stack, so it could never validate.

Then build a discovery table: one row per source, giving the config field, the value, and whether it is
certain or inferred. §5 asks about the inferred rows only.

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

Commands that are not found are left out of the proposal (the schema has no required command keys). To read the
scripts for a stack path and its package manager, replace `<stack_path>`:

```sh
p=<stack_path>
if [ -f "$p/pnpm-lock.yaml" ]; then echo pnpm; elif [ -f "$p/yarn.lock" ]; then echo yarn
elif [ -f "$p/bun.lock" ] || [ -f "$p/bun.lockb" ]; then echo bun; else echo npm; fi
jq -r '.scripts // {} | keys[]' "$p/package.json"
```

**Stack tools.** Warn, never stop. The tools to look for: nextjs, react and tailwind need the package
manager's binary; laravel needs `php` and `composer`; wordpress and woocommerce need `php` and `composer`,
plus `docker` when `.wp-env.json` or `.ddev/` exists; dotnet needs `dotnet`. Replace `<tools>` with the
space-separated list.

```sh
for c in <tools>; do
  if command -v "$c" > /dev/null 2>&1; then echo "ok $c"; else echo "missing $c"; fi
done
```

A missing tool becomes a warning in the §13 report with an install hint. Nothing is installed and init goes on.

**UI project** (used by §5 and §10): a detected nextjs, react, tailwind, wordpress or woocommerce profile, or a
`pages/`, `app/`, `resources/views/` or `wp-content/themes/` directory.

Put the proposal together in schema key order (`project`, `default_branch`, `stacks`, `commands`, `app`,
`retro`; commands in schema order) with only these six keys. The optional sections (`ui`, `git`, `gates`,
`limits`, `evidence`, `claude_md`) keep their schema defaults until someone edits the config.

## 5. Confirm in one question round

Write the detected proposal from §4 to `.aew/runs/init-config.json` with the Write tool first (read the file
first if it already exists). `.aew/runs/` is ignored since §3, and the snippet below reads this file.

Print the whole proposal. Mark certain values "found in the repo" and inferred values "inferred".

On a re-run (`.aew/config.json` exists), run this next and print what it shows. The existing value is kept and
never overwritten. Stacks are compared by `(profile, path)`, not by array index, so a newly detected stack is
reported as an addition.

```sh
jq -r --slurpfile p .aew/runs/init-config.json '. as $e | $p[0] as $q
  | ($q | del(.stacks) | paths(scalars) as $x
     | select(($e | getpath($x)) != null and ($e | getpath($x)) != ($q | getpath($x)))
     | "\($x | map(tostring) | join(".")): keeping \($e | getpath($x) | tojson), detected \($q | getpath($x) | tojson)"),
    ($q.stacks[] as $s | ([$e.stacks[] | select(.profile == $s.profile and .path == $s.path)] | first) as $o
     | if $o == null then "stacks: adding \($s.profile) at \($s.path) (\($s.version))"
       elif $o.version != $s.version then "stacks: keeping \($s.profile) at \($s.path) version \($o.version), detected \($s.version)"
       else empty end)' .aew/config.json
```

Then ask **one** AskUserQuestion round. It covers only the inferred values that are not already in the existing
config, plus the Playwright offer when §4 found a UI project and no `@playwright/test`. Each question puts the
recommended answer first, with its label ending "(recommended)", and offers one or two alternatives. The user
can always type their own through "Other".

The Playwright question is: "Set up Playwright and axe for UI QA now? This installs `@playwright/test` and
`@axe-core/playwright` as dev dependencies and downloads Chromium." It recommends **skip**: QA sets Playwright
up on first use (ui-qa §2), and nothing gets installed without a yes.

If the tool's schema caps questions or options per call, split the round over as many calls as needed. That
still counts as one round. Nothing to ask means no call. Headless or no answer: use the recommended values
(Playwright skipped) and list them under "Defaults used" in the §13 report.

Write the final proposal, with the answers or defaults, over `.aew/runs/init-config.json` with the Write tool.

## 6. Write and validate the config

Merge the proposal with any existing config, and say whether the result differs.

```sh
mkdir -p .aew
if [ -f .aew/config.json ]; then
  jq --slurpfile p .aew/runs/init-config.json '. as $e | ($p[0] * $e) | .stacks = $e.stacks + [$p[0].stacks[] | select([.profile, .path] as $k | all($e.stacks[]; [.profile, .path] != $k))]' .aew/config.json > .aew/runs/init-config-merged.json
else
  jq . .aew/runs/init-config.json > .aew/runs/init-config-merged.json
fi
if [ -f .aew/config.json ] && jq -e --slurpfile m .aew/runs/init-config-merged.json '. == $m[0]' .aew/config.json > /dev/null; then
  echo "config unchanged"
else
  echo "config changed"
fi
```

- `$p[0] * $e` is a recursive merge where the existing file wins. Missing fields from the proposal are added,
  and nothing is removed or duplicated. `stacks` is a union keyed by `(profile, path)`: every existing entry is
  kept as it is (its version included), and a newly detected stack is appended. Running the merge on its own
  output gives the same result.
- `==` compares JSON values, not text, so a hand-formatted config that already holds every value counts as
  unchanged and is never rewritten.
- `jq .` output (two-space indent, the proposal's key order) is the stable format.

Run the next snippet only on "config changed". It validates the scratch copy and only then replaces the live
file.

```sh
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json" -d .aew/runs/init-config-merged.json && cp .aew/runs/init-config-merged.json .aew/config.json && echo "config written"
```

An invalid result stops init before §7 and quotes ajv's errors. The live `.aew/config.json` is untouched,
because only the scratch copy was validated.
