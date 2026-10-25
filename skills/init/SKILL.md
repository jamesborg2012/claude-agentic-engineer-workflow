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
