> **Superseded draft.** Task D5 and CTO-1 changed after this phase approval; implement from the consolidated plan `docs/superpowers/plans/2026-10-25-orchestrator-and-entry-skills.md`, which is authoritative.

# Phase D plan — `init` skill

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `46335838…6090`)
- **Binding overrides:** the CTO simplicity-challenge (scratchpad `simplicity-adopted.md`): cut 6 (AC-31: anchored allow rules only, no deny rules, no V-7 verification task; V-7 already verified in `docs-facts-v7.md`) and cut 9 (AC-32: no deletion of an empty `chore/aew-init` branch). They win over the spec text where they differ.
- **Phase:** D of the EPIC. `depends_on: [A]`: it consumes Phase A contract C-2 (standards-setter `mode: init`, task A2) and C-3 (`gh-pr.sh open`, task A3). Phase E's `skills.bats` checks this file; Phase F runs I1/I2 against it and makes every DESIGN.md edit.
- **Depth:** full
- **ACs covered:** AC-24, AC-25, AC-26, AC-27, AC-28, AC-29, AC-30, AC-31, AC-32, AC-33. The live evidence for AC-33 (I1/I2, AC-44) is Phase F's; this phase proves every deterministic step for free in a scratch copy of the nextjs-tailwind fixture.
- **Risk:** permissions. Task D5 writes the project `.claude/settings.json` proposal that an interactive user may accept. It is RISKY and has a rollback.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" means the spec's assumption n. "§n" in this plan means section n of `skills/init/SKILL.md` (the section contract below), unless it says DESIGN or ui-qa.

> **For agentic workers:** implement task by task, in order (all six tasks write the same file). Every task records its RED (the check fails before the change) and its GREEN after. The checks are free: grep and awk over the skill, plus the skill's own shell snippets run with plain bash in a scratch project outside the repo. No Claude session, no spend, no network apart from `npx ajv-cli` (D3, D6).

**Goal:** one user-invocable skill, `/aew:init`, that prepares a target project for aew on a `chore/aew-init` branch and opens a PR: prerequisites, detection and config, labels, gitignore, the Playwright offer, a CLAUDE.md section, a permissions proposal, the first standards docs. A second run changes nothing.

**Architecture:** a single new file, `skills/init/SKILL.md`, with no `references/` (simplicity first; it stays under 500 lines, checked in D6). It is a numbered procedure the main thread follows. Every deterministic step is a short fenced `sh` snippet, and that is what the checks run. Scratch files live in `.aew/runs/` (gitignored by §3, inside the project, so Write and `acceptEdits` cover them, and no temp dir outside the project is needed). Init talks to GitHub only through `gh auth status` (the one direct, read-only call, Assumption 9) and the plugin scripts `gh-labels.sh ensure`, `git-branch.sh push` and `gh-pr.sh open`. No scripts, agents, hooks or DESIGN.md change in this phase.

**Tech stack:** bash/zsh-safe snippets (no bash-only syntax: the Bash tool runs the user's shell), jq 1.7.1, git, `npx --yes -p ajv-cli@5 -p ajv-formats@3`, the `gh` mock `tests/scripts/helpers/bin/gh` for the label and PR checks.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| spec AC-24–33, Assumptions 5, 9, 22–28, Risks ("Permission rules") | The behaviour to build |
| scratchpad `simplicity-adopted.md` (cuts 6, 9) and `docs-facts-v7.md` | The permission-rule semantics AC-31 relies on; no empty-branch deletion |
| `docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-A.md` C-2, C-3 | The two interfaces D6 calls |
| `templates/config.schema.json` | Required `project`, `default_branch`, `stacks` (`minItems: 1`, items `{profile,path,version}`, `additionalProperties: false`), `commands` (nine optional keys), `app` (four required keys, `env_type` enum `wp-env, ddev, local, docker, native, none`), `retro.repo` |
| `scripts/detect-stack.sh --help`, `gh-labels.sh --help`, `git-branch.sh --help` | Contracts (detect output `{profile,path,version,evidence}`; `ensure` makes 11 `gh label create --force` calls; `push` refuses the default branch and reads `default_branch` from config) |
| `skills/ui-qa/SKILL.md` §2 (and §4, §6, §7 it points to) | The Playwright setup init offers |
| `agents/standards-setter.md` Guardrails and Memory | The agent writes `docs/standards/**` and `.claude/agent-memory/aew-standards-setter/` |
| `tests/fixtures/stacks/nextjs-tailwind/` | The init target: `package.json` (`name` `fixture-nextjs-tailwind`; scripts `dev`, `build`, `lint`), `tsconfig.json`, `app/`; no lock file, no `.gitignore`, no `CLAUDE.md` |
| `tests/scripts/helpers/bin/gh` | Mock: needs `GH_MOCK_DIR`; logs to `$GH_MOCK_DIR/calls.log`; route = first two args (`label-create`, `pr-list`, `pr-create`); canned replies in `responses/<route>[.<n>].out` |
| `skills/ui-qa/SKILL.md` lines 1–8 | Skill frontmatter and numbered-section style to mirror |

Gotchas that apply (from `docs/superpowers/project-map.md`): `${CLAUDE_PLUGIN_ROOT}` is substituted in the skill body but is not in the Bash environment, so snippets spell `"${CLAUDE_PLUGIN_ROOT}/scripts/…"` (the checks export it as a shell variable to get the same effect); in zsh run `setopt interactivecomments` and quote separators; macOS `/var` is `/private/var` (compare `pwd -P` with `git rev-parse --show-toplevel`); the dev-workflow safety hook blocks any command whose text contains `git push`, so the scratch setup builds `origin` with `git clone --bare` and never pushes by hand; `jq -Rs` is unsafe for multi-byte text (not used).

## Interface contract (Phases E and F rely on this)

### D-C1. `skills/init/SKILL.md` frontmatter and sections

Frontmatter: `name: init`, a `description`, `disable-model-invocation: true`. No `argument-hint` (init takes no arguments), no `allowed-tools`. The body has no `` !`cmd` `` injection and no `$N` placeholders.

| § | Title | ACs | Task |
|---|---|---|---|
| (intro) | Plugin root, how to run, the ask rule, "Init's files" | 24, 33 | D1 |
| 1 | Prerequisites | 24 | D1 |
| 2 | Clean tree and branch | 24, 25 | D1 |
| 3 | Gitignore | 28 | D2 |
| 4 | Detect and discover | 24 (stack tools), 26 | D2 |
| 5 | Confirm in one question round | 26, 29 (the offer) | D3 |
| 6 | Write and validate the config | 27 | D3 |
| 7 | Labels | 28 | D4 |
| 8 | Playwright setup | 29 | D4 |
| 9 | CLAUDE.md section | 30 | D4 |
| 10 | Permissions proposal | 31 | D5 |
| 11 | Standards | 32 | D6 |
| 12 | Commit, push and PR | 32, 33 | D6 |
| 13 | Report | 26, 29, 31, 33 | D6 |

Headings are exactly `## <n>. <Title>`. Shell snippets are fenced ```` ```sh ```` **at column 0, never indented inside a list item** (the `snip` extractor matches `^```sh$`, and a heredoc's closing `EOF` must start its line; the plan shows some snippets indented under bullets only for readability). Snippets are numbered by their order inside their section, as the tasks state. Placeholders are `<snake_case>` in angle brackets, which the model replaces before running (the checks replace them with `sed`).

### D-C2. Paths and names the skill mentions (for Phase E's existence check)

Only existing paths: `${CLAUDE_PLUGIN_ROOT}/scripts/{detect-stack,gh-labels,git-branch,gh-pr,state,gh-issue,gh-milestone,gh-retro}.sh`, `${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json`, `${CLAUDE_PLUGIN_ROOT}/skills/ui-qa/SKILL.md`. Agent and skill names: `aew:standards-setter`, plus the commands `/aew:init`, `/aew:ship`, `/aew:resume`, `/aew:status`, `/aew:prompt` in the CLAUDE.md block (they all exist once B–D are merged). The permissions template lists each script by its real name, never `scripts/<name>.sh`, so a placeholder can't fail E's check. The skill never names a label (`aew:<stage>`), so E's `aew:<name>` pattern doesn't trip on one.

### D-C3. Files init writes in a target project ("Init's files")

`.gitignore`, `.aew/config.json`, `CLAUDE.md`, `.claude/settings.json` (only on a yes), `docs/standards/**` and `.claude/agent-memory/aew-standards-setter/**` (from the standards-setter), and, only when the Playwright offer is accepted, the ui-qa §2 files (`package.json`, the lock file, `playwright.config.ts`, `<ui.e2e_dir>/aew.ts`, or the nested `tests/e2e/` package). Scratch files (gitignored, removed in §13): `.aew/runs/init-config.json`, `.aew/runs/init-config-merged.json`, `.aew/runs/init-permissions.json`, `.aew/runs/init-settings.json`, `.aew/runs/init-pr-body.md`. Their names can't collide with run ids (`^[1-9][0-9]*$|^m-…`). **Phase C's `status` lists only directories whose names match the run-id pattern (`^[1-9][0-9]*$` or `^m-…`)**, so these files and `current` never show up as runs.

### D-C4. What a headless I1/I2 run (Phase F) should observe

- **I1 on the fixture** (AskUserQuestion absent, so every default is used): branch `chore/aew-init` from `main`; `.gitignore` = `.aew/runs/` and `.playwright-mcp/`; `.aew/config.json` equal to the reference proposal in D2 (it validates); 11 `label create` calls; Playwright skipped; `CLAUDE.md` created with the section; `.claude/settings.json` **not** written (the proposal is printed); standards-setter `mode: init` (nextjs and tailwind generated); one commit `chore: set up aew`; one `git-branch.sh push`; `gh-pr.sh open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base main`, which makes one `pr list` and one `pr create` call.
- **I2, straight after:** `git status --porcelain` empty; both branch heads unchanged; config sha unchanged; 11 `label create` calls (expected); no push; exactly one `pr list` (the PR is reused) and no `pr create`; the report says "nothing changed" and names the open PR. The harness cans `responses/pr-list.2.out` with the PR number from I1 so the second lookup finds it.
- The harness needs a canned `responses/pr-create.out` containing a `/pull/<n>` URL (C-3 parses it). Init's config names the real plugin repo as `retro.repo` (Assumption 23); G1 runs on that config, so Phase F's retro override (AC-39) must also cover the init-produced config.

## Verification scaffold (shared by every task)

Write this once to `${TMPDIR%/}/aew-init-env.sh` with the Write tool (not a heredoc, so no command text contains `git push`), and start each check with `. "${TMPDIR%/}/aew-init-env.sh"`. It needs no network and makes no GitHub call: the mock is first on `PATH`, `GH_MOCK_DIR` is set, and `origin` is a local bare repo.

```sh
REPO=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
W="${TMPDIR%/}/aew-init-check"
export CLAUDE_PLUGIN_ROOT="$REPO" GH_MOCK_DIR="$W/gh" PATH="$REPO/tests/scripts/helpers/bin:$PATH"
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
# fresh scratch project: the fixture as a repo on main, with a local bare origin
fresh() {
  rm -rf "$W" && mkdir -p "$W" &&
  cp -Rp "$REPO/tests/fixtures/stacks/nextjs-tailwind" "$W/p" &&
  git -C "$W/p" init -q -b main && git -C "$W/p" add -A && git -C "$W/p" commit -qm fixture &&
  git clone -q --bare "$W/p" "$W/origin.git" &&
  git -C "$W/p" remote add origin "$W/origin.git" && git -C "$W/p" fetch -q origin &&
  git -C "$W/p" branch -q -u origin/main main
}
# snip <section> [k]: the k-th ```sh block of "## <section>. " in the skill
snip() {
  awk -v s="## $1. " -v k="${2:-1}" 'index($0,s)==1{f=1;next} f&&/^## /{exit}
    f&&/^```sh$/{c++; if(c==k)b=1; next} b&&/^```$/{exit} b' "$REPO/skills/init/SKILL.md"
}
# run <section> [k] [sed-expr]: run that snippet in the scratch project with bash
run() { (cd "$W/p" && snip "$1" "${2:-1}" | sed "${3:-s/^//}" | /bin/bash -e); }
```

`run` uses `/bin/bash` (3.2) so a bash-4 construct fails, and snippets are written without zsh-incompatible syntax too, so they work under either shell. Each check below lists its commands and expected output; record the actual output in the task report.

## Tasks

Waves: **1** = D1 · **2** = D2 · **3** = D3 · **4** = D4 · **5** = D5 · **6** = D6 (after A2 and A3 have merged). All six tasks write `skills/init/SKILL.md`, so they run in series. D1–D5 have no cross-phase dependency and can start while Phase A is in flight.

---

### Task D1 — Skeleton, prerequisites, clean tree and branch (AC-24, AC-25)

- **id:** D1
- **files:** `skills/init/SKILL.md` (new)
- **depends_on:** []
- **pattern:** `skills/ui-qa/SKILL.md` (frontmatter shape, `# aew …` H1, `## <n>. <Title>` sections, short imperative prose); spec Assumption 22.
- **ACs:** AC-24 (all but the per-profile stack-tool warnings, which go in §4), AC-25
- **Risk:** NOT RISKY.

**Step 1: RED.** `test -f skills/init/SKILL.md` exits 1.

**Step 2: write the file.** Contents, section by section:

- **Frontmatter** as D-C1. Description, for example: "Sets a project up for aew: checks prerequisites, detects stacks, writes `.aew/config.json`, ensures labels and gitignore lines, offers Playwright, adds a CLAUDE.md section, proposes permissions, generates the first standards docs, and opens a PR from `chore/aew-init`. Safe to re-run: it only adds what is missing."
- **Intro** (≤ 25 lines):
  - The plugin root is `${CLAUDE_PLUGIN_ROOT}`. Run plugin scripts by their full quoted path, as the snippets do (never write a `${CLAUDE_PLUGIN_ROOT}/…` path with a placeholder in it: Phase E checks every such path exists). Run snippets from the project root, one Bash call per snippet, replacing `<…>` placeholders first.
  - Init takes no arguments. If any were given, stop with `usage: /aew:init (no arguments)`.
  - **The ask rule.** Init asks at most twice: the §5 question round and the §10 permissions question. If AskUserQuestion is not in your tool list (headless runs), don't try to call it. Use each question's default and list it in the report. A refused or empty answer also takes the default. The defaults are the recommended config values, Playwright skipped, and permissions not written. All of them can be reviewed in the PR.
  - **Idempotency.** Every step checks before it writes and says when it is a no-op. A second run on an unchanged repo changes no file and makes no commit, push or PR call.
  - **Init's files:** the D-C3 list, plus the scratch files and the rule that init stages only these.
  - Never install a global tool. Never touch GitHub except through `gh auth status` and the plugin scripts named here.
- **§1 Prerequisites.** Three snippets, each its own Bash call:
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
  Then a table maps each failure to its stop message and install hint: `git` (macOS `xcode-select --install`, else the OS package manager); `gh` (https://cli.github.com, then `gh auth login`; a failing `gh auth status` says to run `gh auth login`); `jq` (`brew install jq`, or the OS package manager); `node` missing or `old node` (Node 20 or later from https://nodejs.org or a version manager such as `nvm install 20`); not inside a git repo, or the top level differs from `pwd -P` ("run `/aew:init` from the repository root"); no `origin` ("add the GitHub remote as `origin`"). Any of these stops init, and nothing is written. `gh auth status` stays a separate, exact call, so the permission rule `Bash(gh auth status)` matches it and nothing broader is needed.
- **§2 Clean tree and branch.**
  - Default branch, first non-empty answer wins (snippet 1):
    ```sh
    jq -r '.default_branch // empty' .aew/config.json 2> /dev/null || true
    git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true
    git ls-remote --symref origin HEAD || true
    git branch --show-current
    ```
    Use the existing config's value. Otherwise use `origin/HEAD` without the `origin/` prefix, then the `ref: refs/heads/<name>` line of `ls-remote`. If none of those gives a value, use the current branch and mark it uncertain (it is asked in §5).
  - Clean tree (snippet 2, its own ```sh block): `git status --porcelain --untracked-files=all`. Empty → continue. Not empty → stop and list the paths ("commit or stash these first"). **One exception:** on `chore/aew-init`, when every listed path is one of Init's files, continue. That is an interrupted earlier init, and this run finishes it.
  - Branch (snippet 3):
    ```sh
    if git rev-parse --verify --quiet refs/heads/chore/aew-init > /dev/null ||
       git rev-parse --verify --quiet refs/remotes/origin/chore/aew-init > /dev/null; then
      git switch chore/aew-init
      if git merge-base --is-ancestor HEAD <default_branch>; then
        git switch -C chore/aew-init <default_branch>
        echo "restarted chore/aew-init from <default_branch>"
      elif ! git merge-base --is-ancestor <default_branch> HEAD; then
        echo "chore/aew-init is older than <default_branch>: if its PR is merged or closed run \`git branch -D chore/aew-init\`, otherwise rebase it, then re-run /aew:init"
        exit 1
      fi
    else
      git switch -c chore/aew-init <default_branch>
    fi
    ```
    If the branch already exists locally or on `origin`, init switches to it (git sets up tracking for a remote-only branch). Then there are three cases:
    - Its commits are all in the default branch (its PR was merged, or it never got a commit): init restarts it at the default branch. `switch -C` only moves a branch whose work is already merged, so nothing is lost.
    - The default branch has moved on and the branch has commits of its own (for example a squash-merged or closed PR): init stops with the message above and changes nothing. The user decides; init never deletes or rebases it.
    - Otherwise (the branch is ahead of the default branch, the usual re-run): init reuses it.

    A new branch is created from the local default branch. Init doesn't fetch or fast-forward: if the PR shows conflicts, the user rebases. A switch failure stops init.

**Step 3: GREEN.**

```sh
. "${TMPDIR%/}/aew-init-env.sh"
awk 'NR==1&&$0!="---"{exit 1} NR>1&&/^---$/{exit} NR>1' "$REPO/skills/init/SKILL.md"
#   -> name: init / description: … / disable-model-invocation: true   (three keys, nothing else)
grep -cE '^(argument-hint|allowed-tools):' "$REPO/skills/init/SKILL.md"   # 0
grep -c '!`' "$REPO/skills/init/SKILL.md"                                   # 0
grep -E '^## [0-9]+\. ' "$REPO/skills/init/SKILL.md"                        # ## 1. Prerequisites / ## 2. Clean tree and branch
fresh && run 1 1          # ok git / ok jq / ok node / ok gh / ok node <v>=20+>
run 1 2                   # toplevel == pwd -P (both /private/var/…/p), then $W/origin.git
mkdir -p "$W/bin" && ln -s "$(command -v git)" "$W/bin/git" && printf '#!/bin/sh\necho 18.19.0\n' > "$W/bin/node" && chmod +x "$W/bin/node"
(cd "$W/p" && snip 1 1 | PATH="$W/bin" /bin/bash)   # ok git / missing jq / ok node / missing gh / old node 18.19.0
run 2 1                   # (empty) / (empty) / ref: refs/heads/main<TAB>HEAD + a sha line / main
run 2 3 's/<default_branch>/main/' && git -C "$W/p" branch --show-current                     # chore/aew-init
run 2 3 's/<default_branch>/main/' && git -C "$W/p" rev-list --count main..chore/aew-init     # "Already on" message, "restarted chore/aew-init from main" (no commits yet: HEAD is an ancestor of main), then 0
git -C "$W/p" commit -q --allow-empty -m work && run 2 3 's/<default_branch>/main/' && git -C "$W/p" rev-list --count main..chore/aew-init   # reused: 1
# fully merged: fast-forward main past the branch without git merge, then re-run -> restarted
git -C "$W/p" branch -f main chore/aew-init && git -C "$W/p" switch -q main && git -C "$W/p" commit -q --allow-empty -m after   # branch -f from chore/aew-init: git refuses to force the checked-out branch
run 2 3 's/<default_branch>/main/' && test "$(git -C "$W/p" rev-parse chore/aew-init)" = "$(git -C "$W/p" rev-parse main)" && echo same   # restarted chore/aew-init from main / same
# diverged: a branch commit main lacks plus a main commit the branch lacks -> stops
git -C "$W/p" commit -q --allow-empty -m work2 && git -C "$W/p" switch -q main && git -C "$W/p" commit -q --allow-empty -m other
(run 2 3 's/<default_branch>/main/'; echo "exit $?") | tail -2     # chore/aew-init is older than main: … / exit 1
git -C "$W/p" switch -q chore/aew-init
touch "$W/p/stray.txt" && run 2 2      # ?? stray.txt   (the skill text says this stops init)
claude plugin validate "$REPO"          # ✔ Validation passed
```

The default-branch check shows the `ls-remote` fallback (the scratch repo has no `origin/HEAD`). `git -C "$W/p" remote set-head origin -a && run 2 1` then shows `origin/main` on line 2.

**Step 4: commit.**

```
feat(skills): add the init skill with prerequisite and branch steps

/aew:init (disable-model-invocation) checks git, gh auth, jq and Node 20+
with install hints and never installs global tools, requires a clean tree
(or an interrupted init's own files), and creates or switches to
chore/aew-init from the default branch.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task D2 — Gitignore, detection and command discovery (AC-26, AC-28 gitignore half, AC-24 stack tools)

- **id:** D2
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D1]
- **pattern:** the `detect-stack.sh` contract (drop `evidence`, as `docs/superpowers/project-map.md` records); ui-qa §2's lock-file-to-package-manager rule (reuse it, don't restate a different one); spec Assumption 23.
- **ACs:** AC-26 (detection and discovery), AC-28 (`.gitignore`), AC-24 (stack-tool warnings)
- **Risk:** NOT RISKY.

**Step 1: RED.** `grep -c '^## 3\. Gitignore$\|^## 4\. Detect and discover$' skills/init/SKILL.md` → `0`.

**Step 2: write.**

- **§3 Gitignore** (before any scratch file is written, so `.aew/runs/` is ignored from here on):
  ```sh
  touch .gitignore
  for l in '.aew/runs/' '.playwright-mcp/'; do
    if grep -qxF "$l" .gitignore; then echo "present $l"; else
      if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then echo >> .gitignore; fi
      echo "$l" >> .gitignore; echo "added $l"
    fi
  done
  ```
  Exact-line match, so each line appears once. A missing final newline is repaired before appending. Nothing else in the file changes (Assumption 25).
- **§4 Detect and discover.**
  - Stacks: `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" . | jq -c 'map(del(.evidence))'`. A non-zero exit stops init and quotes the `error:` line. `[]` stops init: "no supported stack detected; aew needs at least one (nextjs, react, laravel, wordpress, dotnet, with tailwind and woocommerce overlays)". The schema requires `minItems: 1`, so the config could never validate.
  - A **discovery table** (one row per source → config field, value, and certain or inferred):
    - `package.json` scripts (`jq -r '.scripts // {} | keys[]' package.json` in each stack path that has one). The package manager comes from the lock file, per ui-qa §2 (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, otherwise npm). Each script is mapped as `<pm> run <script>`: `dev` → dev; `build` → build; `lint` → lint; `format`, `format:check` → format; `typecheck`, `type-check` → typecheck; `test`, `test:unit` → test_unit; `test:e2e`, `e2e` → test_e2e; `seed`, `db:seed` → seed. All of these are certain. `install` is `npm ci` with a `package-lock.json` (certain) or `<pm> install` (certain when the lock file names the manager, inferred when there is no lock file).
    - `tsconfig.json` with no typecheck script → `npx tsc --noEmit` (inferred).
    - `@playwright/test` in a `package.json` → `test_e2e: npx playwright test` when there is no e2e script (certain).
    - `composer.json` scripts (`jq -r '.scripts // {} | keys[]' composer.json`): `test` → test_unit `composer test`; `lint` → lint; `format` → format; `analyse`, `phpstan` → typecheck. `install: composer install`. All certain.
    - `artisan` → test_unit `php artisan test` when there is no composer test script, seed `php artisan db:seed`. App: `php artisan serve`, `http://127.0.0.1:8000`, `native` (inferred).
    - `.wp-env.json` → app `env_type: wp-env`, start `npx wp-env start`, `base_url` `http://localhost:<port, default 8888>`, ready_check = base_url.
    - `.ddev/config.yaml` → `env_type: ddev`, start `ddev start`, `base_url` `https://<name>.ddev.site` (from its `name:`).
    - `*.csproj` (depth ≤ 3): build `dotnet build`; test_unit `dotnet test` when a `*Tests.csproj` exists; format `dotnet format --verify-no-changes`. App: start `dotnet run --project <web csproj>`, `base_url` from `Properties/launchSettings.json` (first `http://` applicationUrl) else `http://localhost:5000` (inferred), `native`.
    - `docker-compose.yml`/`compose.yaml` with no wp-env or ddev → `env_type: docker`, start `docker compose up -d` (inferred).
    - wordpress/woocommerce with no `.wp-env.json`, `.ddev/` or compose file → `env_type: local` (a Local-style site), `base_url: http://<project>.local`, empty `start_command`, `ready_check` = base_url. All inferred, so asked in §5.
    - nextjs → `http://localhost:3000`; react (Vite) → `http://localhost:5173`. Start is the `dev` command, ready_check = base_url, `env_type: native`. Inferred unless a script pins a port.
    - No app at all → `env_type: none`, `base_url: http://localhost`, empty `start_command` and `ready_check` (inferred).
    - `project`: the root `package.json` `name`, else the `composer.json` `name` after the `/`, else the first `.csproj` basename, else the directory name. Certain when found in a manifest.
    - `default_branch` from §2. `retro.repo` = `jamesborg2012/claude-agentic-engineer-workflow` (inferred, Assumption 23).
    - Commands that aren't found are left out (the schema has no required command keys).
  - **Stack tools** (warn, never stop): nextjs/react/tailwind → the package manager's binary; laravel → `php`, `composer`; wordpress/woocommerce → `php`, `composer`, and `docker` when `.wp-env.json` or `.ddev/` exists; dotnet → `dotnet`. Checked with `command -v`. A missing tool is a warning in the report with an install hint, nothing is installed, and init goes on.
  - **UI project** (used by §5 and §10): a detected nextjs, react, tailwind, wordpress or woocommerce profile, or a `pages/`, `app/`, `resources/views/` or `wp-content/themes/` directory.
  - Section closes with: "Put the proposal together in schema key order (`project`, `default_branch`, `stacks`, `commands`, `app`, `retro`; commands in schema order) with only these six keys. The optional sections (`ui`, `git`, `gates`, `limits`, `evidence`, `claude_md`) keep their schema defaults until someone edits the config."

**Reference proposal for the fixture** (D3, D6 and Phase F compare against it):

```json
{
  "project": "fixture-nextjs-tailwind",
  "default_branch": "main",
  "stacks": [
    { "profile": "nextjs", "path": ".", "version": "16.0.1" },
    { "profile": "tailwind", "path": ".", "version": "4.1.0" }
  ],
  "commands": {
    "install": "npm install",
    "dev": "npm run dev",
    "build": "npm run build",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit"
  },
  "app": {
    "base_url": "http://localhost:3000",
    "start_command": "npm run dev",
    "ready_check": "http://localhost:3000",
    "env_type": "native"
  },
  "retro": { "repo": "jamesborg2012/claude-agentic-engineer-workflow" }
}
```

The inferred values here are `install` (no lock file), `typecheck`, the four `app` values and `retro.repo`. A UI project without Playwright also gets the Playwright offer in §5.

**Step 3: GREEN.**

```sh
. "${TMPDIR%/}/aew-init-env.sh"
fresh && run 3 && run 3                 # added .aew/runs/ / added .playwright-mcp/ ; then present … twice
grep -cxF '.aew/runs/' "$W/p/.gitignore"; grep -cxF '.playwright-mcp/' "$W/p/.gitignore"   # 1 / 1
tail -c 1 "$W/p/.gitignore" | od -c | head -1      # \n
printf 'node_modules/' > "$W/p/.gitignore" && run 3 && cat "$W/p/.gitignore"   # node_modules/ then the two lines, each on its own line
(cd "$W/p" && "$REPO/scripts/detect-stack.sh" . | jq -c 'map(del(.evidence))')
#   [{"profile":"nextjs","path":".","version":"16.0.1"},{"profile":"tailwind","path":".","version":"4.1.0"}]
(cd "$W/p" && jq -r '.scripts // {} | keys[]' package.json)   # build / dev / lint
grep -c 'ui-qa' "$REPO/skills/init/SKILL.md"                   # >= 1 (package-manager rule reused, not restated differently)
claude plugin validate "$REPO"                                 # ✔ Validation passed
```

**Step 4: commit.** `feat(skills): init ignores run state and discovers stacks and commands` (body: gitignore lines once each; detect-stack without evidence; the discovery table; stack-tool warnings; the trailer).

---

### Task D3 — One question round, write and validate the config (AC-26 confirm, AC-27)

- **id:** D3
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D2]
- **pattern:** the CLAUDE.md `ajv` command; spec AC-8's AskUserQuestion conventions (recommended answer first, label ending "(recommended)", batch if the tool's schema caps a call), restated in one line here because Phase B's `gates.md` is not a dependency of this phase; Assumption 24 (existing values win).
- **ACs:** AC-26 (one round, defaults when headless, listed in the report), AC-27
- **Risk:** NOT RISKY.

**Step 1: RED.** `grep -c '^## 5\. \|^## 6\. ' skills/init/SKILL.md` → `0`.

**Step 2: write.**

- **§5 Confirm in one question round.**
  - Write the detected proposal (from §4) to `.aew/runs/init-config.json` with the Write tool first (`.aew/runs/` is ignored since §3); the snippet below reads it.
  - Print the whole proposal. Mark certain values "found in the repo" and inferred values "inferred".
  - On a re-run, run this next and print what it shows (the existing value is kept, never overwritten):
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
    Stacks are compared by `(profile, path)`, not by array index, so a newly detected stack is reported as an addition.
  - Ask **one** AskUserQuestion round. It covers only the inferred values that are not already in the existing config, plus the Playwright offer when §4 found a UI project and no `@playwright/test`. Each question puts the recommended answer first, with its label ending "(recommended)", and offers one or two alternatives. The user can always type their own through "Other". The Playwright question is "Set up Playwright and axe for UI QA now? This installs `@playwright/test` and `@axe-core/playwright` as dev dependencies and downloads Chromium." It recommends **skip**: QA sets Playwright up on first use (ui-qa §2), and nothing gets installed without a yes. If the tool's schema caps questions or options per call, split the round over as many calls as needed. That still counts as one round. Nothing to ask → no call.
  - Headless or no answer: use the recommended values (Playwright skipped) and list them under "Defaults used" in the report.
  - Write the final proposal (with the answers or defaults) over `.aew/runs/init-config.json` with the Write tool.
- **§6 Write and validate the config.** Two snippets:
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
  ```sh
  npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json" -d .aew/runs/init-config-merged.json && cp .aew/runs/init-config-merged.json .aew/config.json && echo "config written"
  ```
  The prose around them says:
  - `$p[0] * $e` is a recursive merge where the existing file wins. Missing fields from the proposal are added, and nothing is removed or duplicated. `stacks` is a union keyed by `(profile, path)`: every existing entry is kept as it is (its version included), and a newly detected stack is appended. Running the merge on its own output gives the same result.
  - `==` compares JSON values, not text, so a hand-formatted config that already holds every value counts as unchanged and is never rewritten.
  - Run the second snippet only on "config changed". An invalid result stops init before §7 with ajv's errors. The live `.aew/config.json` is untouched, because only the scratch copy was validated.
  - `jq .` output (two-space indent, the proposal's key order) is the stable format.

**Step 3: GREEN.** Write the D2 reference proposal to `$W/ref.json` first.

```sh
. "${TMPDIR%/}/aew-init-env.sh"
fresh && run 3 > /dev/null && cp "$W/ref.json" "$W/p/.aew/runs/init-config.json"
run 6 1                                     # config changed
run 6 2 | tail -1                           # .aew/runs/init-config-merged.json valid / config written
shasum -a 256 "$W/p/.aew/config.json" > "$W/sha1"
run 6 1                                     # config unchanged      (second-run no-op)
shasum -a 256 -c "$W/sha1"                  # OK
jq '.app.base_url = "http://localhost:3001" | del(.commands.lint)' "$W/p/.aew/config.json" > "$W/e.json" && cp "$W/e.json" "$W/p/.aew/config.json"
run 5 1                                     # app.base_url: keeping "http://localhost:3001", detected "http://localhost:3000"
run 6 1 && run 6 2 > /dev/null && jq -c '[.app.base_url, .commands.lint]' "$W/p/.aew/config.json"   # config changed, then ["http://localhost:3001","npm run lint"]
jq '.stacks = [.stacks[0] | .version = "15.0.0"]' "$W/p/.aew/config.json" > "$W/e.json" && cp "$W/e.json" "$W/p/.aew/config.json"   # drop tailwind, older nextjs
run 5 1 | grep '^stacks'                    # stacks: keeping nextjs at . version 15.0.0, detected 16.0.1 / stacks: adding tailwind at . (4.1.0)
run 6 1 && run 6 2 > /dev/null && jq -c '.stacks' "$W/p/.aew/config.json"   # config changed, then [{"profile":"nextjs","path":".","version":"15.0.0"},{"profile":"tailwind","path":".","version":"4.1.0"}]
run 6 1                                     # config unchanged (the union is idempotent)
jq '.app.env_type = "bogus"' "$W/ref.json" > "$W/p/.aew/runs/init-config.json" && rm "$W/p/.aew/config.json"
run 6 1 && (run 6 2; echo "exit $?") | tail -2; test -f "$W/p/.aew/config.json"; echo "present=$?"   # invalid … exit 1 ; present=1
git -C "$W/p" status --porcelain --untracked-files=all   # only .gitignore (scratch files are ignored)
```

**Step 4: commit.** `feat(skills): init confirms inferred config values once and validates the config` (body: one round with recommended answers, headless defaults; recursive merge where existing values win; semantic no-op; scratch-copy validation; the trailer).

---

### Task D4 — Labels, Playwright setup, CLAUDE.md section (AC-28 labels, AC-29, AC-30)

- **id:** D4
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D3]
- **pattern:** `gh-labels.sh --help` ("run ensure once before stage or flag"); ui-qa §2 (setup steps, gitignore lines), reused by reading it, never restated; the claude-md-curation skill's terse style for the section text.
- **ACs:** AC-28 (`gh-labels.sh ensure`), AC-29, AC-30
- **Risk:** NOT RISKY (any install happens only on an explicit yes).

**Step 1: RED.** `grep -c '^## 7\. \|^## 8\. \|^## 9\. ' skills/init/SKILL.md` → `0`.

**Step 2: write.**

- **§7 Labels.** One ```sh block: `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-labels.sh" ensure`. It's idempotent on GitHub's side (`--force`) and runs on every init. A failure stops init before the commit and quotes the error ("is `origin` a GitHub repo you can write to?").
- **§8 Playwright setup.** Only when §5's offer was answered yes. Read `${CLAUDE_PLUGIN_ROOT}/skills/ui-qa/SKILL.md` §2 with the Read tool and follow it: install with the lock file's manager, exact-pinned; `npx playwright install chromium`; the gitignore lines (append the missing ones with the §3 snippet's pattern); `playwright.config.ts` from ui-qa §4; `<ui.e2e_dir>/aew.ts` from ui-qa §6 and §7. The files go into init's commit, not a QA cycle commit. Then add `commands.test_e2e: npx playwright test` to `.aew/runs/init-config.json` for a root package, and re-run §6. Skipped (no, headless, no answer, not a UI project, or Playwright already present) → report "Playwright: skipped (QA sets it up on first use)" or "present".
- **§9 CLAUDE.md section.**
  ```sh
  [ -f CLAUDE.md ] || printf '# CLAUDE.md\n' > CLAUDE.md
  if grep -qxF '## Agentic workflow' CLAUDE.md; then echo "CLAUDE.md section present"; else
    if [ -n "$(tail -c 1 CLAUDE.md)" ]; then echo >> CLAUDE.md; fi
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
  fi
  ```
  The exact-heading check means the section is never duplicated. An existing section is left as it is, even if it was edited.

**Step 3: GREEN.**

```sh
. "${TMPDIR%/}/aew-init-env.sh"
fresh && run 7 && wc -l < "$GH_MOCK_DIR/calls.log"                 # 11 (gh-labels.sh: ensured 11 labels on stderr)
grep -c '^label create aew:' "$GH_MOCK_DIR/calls.log"              # 11
run 9 && run 9                                                     # CLAUDE.md section added / CLAUDE.md section present
grep -cxF '## Agentic workflow' "$W/p/CLAUDE.md"                    # 1
head -1 "$W/p/CLAUDE.md"                                            # # CLAUDE.md
printf '# Existing\nno newline' > "$W/p/CLAUDE.md" && run 9 && sed -n 1,4p "$W/p/CLAUDE.md"   # # Existing / no newline / (blank) / ## Agentic workflow
grep -o '`/aew:[a-z-]*' "$REPO/skills/init/SKILL.md" | sort -u      # /aew:init /aew:prompt /aew:resume /aew:ship /aew:status
grep -c 'ui-qa/SKILL.md' "$REPO/skills/init/SKILL.md"               # >= 1 (§8 reads ui-qa §2, no restated install list)
grep -c '@playwright/test@1' "$REPO/skills/init/SKILL.md"           # 0 (versions live only in ui-qa)
```

**Step 4: commit.** `feat(skills): init ensures labels, offers Playwright and adds the CLAUDE.md section` (body plus the trailer).

---

### Task D5 — Permissions proposal (AC-31, CTO-3a, cut 6)

- **id:** D5
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D4]
- **pattern:** V-7 (`docs-facts-v7.md`): put `*` only after the subcommand; `git -C d <sub>` and `git -c k=v <sub>` don't match `Bash(git <sub> *)`; compound commands must match per subcommand; deny rules aren't a security boundary. DESIGN §3: a `Bash(<abs path> *)` rule matches the quoted `"<abs path>" …` form; read-only git and `ls/cat/grep/find/head/tail/wc` are built-in no-prompt commands. The developer and qa-engineer Guardrails command families (`tests/agent-smoke/README.md` §8.3 `ALLOW` lines, minus the harness-only broad rules).
- **ACs:** AC-31
- **Risk:** **RISKY** (permissions). An accepted proposal pre-approves commands for every session and subagent in the project.
- **Rollback:** `git revert` of this task's commit removes §10, and init then proposes nothing. In a target project, the proposal is a reviewable hunk in `.claude/settings.json` inside the init PR, so not merging the PR (or deleting the added `allow` entries) undoes it.

**Step 1: RED.** `grep -c '^## 10\. Permissions proposal$' skills/init/SKILL.md` → `0`.

**Step 2: write §10.**

- **Rules template** (a fenced `json` block). `<root>` is the substituted plugin root. Each script is listed by its real name. Every rule is an exact command, or a subcommand followed by a single trailing ` *`:
  ```json
  { "permissions": { "allow": [
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/state.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-issue.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-labels.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-milestone.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-pr.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-retro.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/git-branch.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh *)",
    "Bash(gh auth status)",
    "Bash(claude plugin list --json)",
    "Bash(git add *)", "Bash(git commit *)", "Bash(git switch *)", "Bash(git branch *)",
    "Bash(git worktree *)", "Bash(git cherry-pick *)",
    "Bash(git fetch origin <default_branch>)",
    "Bash(jq *)",
    "Bash(date +%Y-%m-%d)"
  ] } }
  ```
  `${CLAUDE_PLUGIN_ROOT}` is substituted when the skill loads, so the proposal carries the real installed path. That path changes with each plugin version: re-running init after an update adds the new rules, and the old ones stay harmless (nothing is removed).
- **Rules from config**, added to the list:
  - `commands.install` → the exact command, no wildcard (`Bash(npm install)`), so it can't install an arbitrary package.
  - `build`, `lint`, `format`, `typecheck`, `test_unit`, `test_e2e`, `seed` → `Bash(<command> *)`.
  - UI project → `Bash(npx playwright test *)` and `Bash(npx playwright install chromium)`.
  - A command becomes a rule only if it's one simple command: no `&&`, `||`, `;`, `|`, `>`, `<`, `$(`, backtick or newline, and it doesn't start with `cd `, `sh `, `bash `, `env ` or a `NAME=` assignment. Anything else is listed as "not pre-approved".
  - `dev` and `app.start_command` get no rule (QA starts the app through ui-qa §3).
- **Deliberately not pre-approved** (prose, never in `Bash(…)` form, so a grep for broad rules stays meaningful):
  - `git -C <dir> …`, the sub-developers' worktree form. A wildcard before the subcommand would also match `-c core.fsmonitor=<cmd>`.
  - `git diff`, `git log`, `git show` and `git format-patch` with a wildcard, because `--output=<path>` writes files. Their read-only forms already run without a prompt.
  - `git fetch` with a wildcard (`--upload-pack=<cmd>`). Only the exact preflight form above is allowed.
  - `git push`, which goes through `git-branch.sh` only. Every other `gh` command, because only the scripts call `gh`.
  - `sh -c`, `nohup`, `cd <dir> && …`, `cp`, `curl`, `kill`, `rm -rf`, and bare `npx`, `npm` or `node`.
  - These prompt when used. Say so, plus: "These rules only cut down prompts. They are not a security boundary: the plugin's Bash guard hook is what blocks dangerous commands." Global git options sit before the subcommand, so an anchored rule can never match them. That's why no deny rules are needed (V-7).
- **Ask:** print the full concrete list and the not-pre-approved list. Then ask one AskUserQuestion: "Write these rules to `.claude/settings.json`?" with **Write (recommended)** and Don't write. A **no answer or headless run means don't write** (the ask rule). Init then reports the list so the user can add it by hand.
- **Merge on yes.** Write the concrete `{"permissions":{"allow":[…]}}` to `.aew/runs/init-permissions.json` with the Write tool, then:
  ```sh
  s=.claude/settings.json; [ -f "$s" ] || s=/dev/null
  jq -n --slurpfile p .aew/runs/init-permissions.json --slurpfile e "$s" '($e[0] // {}) as $e
    | ($e.permissions.allow // []) as $a
    | $e | .permissions.allow = $a + (($p[0].permissions.allow | unique) - $a)' > .aew/runs/init-settings.json
  if [ -f .claude/settings.json ] && jq -e --slurpfile m .aew/runs/init-settings.json '. == $m[0]' .claude/settings.json > /dev/null; then
    echo "settings unchanged"
  else
    mkdir -p .claude && cp .aew/runs/init-settings.json .claude/settings.json && echo "settings written"
  fi
  ```
  Existing rules keep their order. New ones are appended once. `deny`, `ask` and every other key are kept as they are, and an unchanged file is never rewritten.

**Fixture reference list** (what the model should produce for the D2 proposal; `<root>` = the plugin root): the eight script rules, `Bash(gh auth status)`, `Bash(claude plugin list --json)`, the six git rules, `Bash(git fetch origin main)`, `Bash(jq *)`, `Bash(date +%Y-%m-%d)`, `Bash(npm install)`, `Bash(npm run build *)`, `Bash(npm run lint *)`, `Bash(npx tsc --noEmit *)`, `Bash(npx playwright test *)`, `Bash(npx playwright install chromium)`. 26 rules.

**Step 3: GREEN.** Write the 26-rule fixture list (with `<root>` = `$REPO`) to `$W/perm.json` as `{"permissions":{"allow":[…]}}`.

```sh
. "${TMPDIR%/}/aew-init-env.sh"
anchored() { jq -r '.permissions.allow[]' "$1" | awk '{x=$0; sub(/^Bash\(/,"",x); sub(/\)$/,"",x); n=gsub(/\*/,"*",x)
  if (n>1 || (n==1 && x !~ / \*$/)) print "BAD wildcard: " $0
  if (x ~ /^(git -C|git -c|git --|sh |bash |cd |cp |curl |npx \*|npm \*|node \*)/ || x ~ /^git (diff|log|show|format-patch|push)( |$)/ || x ~ /^git fetch .*\*/) print "BAD rule: " $0 }'; }
anchored "$W/perm.json"                                                         # (no output)
jq '.permissions.allow | length' "$W/perm.json"                                 # 26
awk '/^## 10\. /{f=1} f&&/^```json$/{b=1;next} b&&/^```$/{exit} b' "$REPO/skills/init/SKILL.md" | sed 's#${CLAUDE_PLUGIN_ROOT}#/root#g; s/<default_branch>/main/g' > "$W/tpl.json" && jq -e . "$W/tpl.json" > /dev/null && anchored "$W/tpl.json"   # template parses, (no output)
grep -cE 'Bash\((git -C|sh -c|cp \*|npx \*\)|cd \*|curl|git (diff|log|show|format-patch|push))' "$REPO/skills/init/SKILL.md"   # 0
grep -c 'not a security boundary' "$REPO/skills/init/SKILL.md"                  # 1
fresh && run 3 > /dev/null && cp "$W/perm.json" "$W/p/.aew/runs/init-permissions.json"
mkdir -p "$W/p/.claude" && printf '{"model":"opus","permissions":{"allow":["Bash(jq *)","Bash(make *)"],"deny":["Bash(rm -rf *)"]}}' > "$W/p/.claude/settings.json"
run 10 && run 10                                    # settings written / settings unchanged
jq -c '[.model, .permissions.deny, (.permissions.allow|length), (.permissions.allow[:2]), (.permissions.allow|map(select(.=="Bash(jq *)"))|length)]' "$W/p/.claude/settings.json"
#   ["opus",["Bash(rm -rf *)"],27,["Bash(jq *)","Bash(make *)"],1]
rm -r "$W/p/.claude" && run 10 && jq -c 'keys, (.permissions|keys)' "$W/p/.claude/settings.json"   # settings written / ["permissions"] / ["allow"]
```

Also confirm that the §10 prose says no answer means not written, and that it prints the list in that case (`grep -n "Don't write" skills/init/SKILL.md`).

**Step 4: commit.**

```
feat(skills): init proposes anchored project permissions

Shows and asks before writing a .claude/settings.json allow list: each
plugin script by path, gh auth status, git add/commit/switch/branch/
worktree/cherry-pick, the exact preflight fetch, jq, and the config's
commands (install exact, the rest with one trailing wildcard). No rule has
a wildcard before a subcommand, so git's global -c/-C/--git-dir forms and
diff/log/show --output never match; no deny rules are needed. Merged
without duplicates; never written without a yes. CTO-3a.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task D6 — Standards, commit/push/PR, report, and the two-pass idempotency check (AC-32, AC-33)

- **id:** D6
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D5, A2, A3]. A2 = standards-setter `mode: init` (Phase A C-2), A3 = `gh-pr.sh open` (Phase A C-3). The consolidator should check these ids against the assembled plan.
- **pattern:** Phase A C-2 (dispatch exactly `mode: init`; return block in the final message only; ARTEFACTS `docs/standards/README.md` then profile docs, or `none`), C-3 (`open <branch> <title> <body-file> [--base <branch>]`, caller pushes first, prints one PR number, reuses an open PR); `gate-subagent.sh` `valid_return_block` for the return check; `git-branch.sh push`; spec AC-32 as amended by cut 9.
- **ACs:** AC-32, AC-33
- **Risk:** NOT RISKY (it pushes only `chore/aew-init`, never the default branch, which `git-branch.sh push` and the Bash guard also refuse).

**Step 1: RED.** `grep -c '^## 1[123]\. ' skills/init/SKILL.md` → `0`. Also `"$REPO/scripts/gh-pr.sh" --help | grep -c '^  open <branch>'` is `1` (top-level `--help`: C-3 rejects an unknown option after `open`) (A3 has merged; if it's `0`, stop: the dependency hasn't landed).

**Step 2: write.**

- **§11 Standards.**
  - Dispatch the Agent tool with `subagent_type: aew:standards-setter` and the prompt exactly `mode: init`.
  - Return check: the result's last four non-blank lines are `STATUS: <ok|needs_input|blocked|failed>`, `ARTEFACTS: …` (non-empty, `none` allowed), `SUMMARY: …`, `NEXT: …`, each holding a single value, not the template's `ok | needs_input | …` placeholder.
  - `ok` → continue, keeping SUMMARY's `<profile>: reused|generated|updated` list for the report.
  - `blocked`, `failed` or an invalid block → retry once, then stop before the commit and quote SUMMARY. The files written so far stay on `chore/aew-init`, and §2's exception lets the next init finish.
  - Then list what changed:
    ```sh
    git status --porcelain --untracked-files=all -- docs/standards/ .claude/agent-memory/aew-standards-setter/
    ```
  - **Memory decision (flag if wrong):** the agent's project memory is meant to be shared, so init commits `.claude/agent-memory/aew-standards-setter/` along with everything else. One exception keeps a re-run idempotent. When the memory directory is the **only** change in the whole tree (step one of §12 shows nothing else), the memory update is dropped: `git restore -- .claude/agent-memory/aew-standards-setter/` for tracked files, and `rm` of each untracked file under it. The report says "standards-setter memory update discarded (nothing else changed)".
- **§12 Commit, push and PR.**
  - Snippet 1 (its own ```sh block): `git status --porcelain --untracked-files=all`. Every path must be one of Init's files. Otherwise stop, list the strangers and commit nothing (something else changed the tree during init).
  - Changes → `git add -- <each listed path>`, then `git commit -m "chore: set up aew"`. Plain conventional message with no issue ref and no trailer (Assumption 28). Never `git add -A` or `git add .`.
  - Snippet 2 decides the push and the PR:
    ```sh
    if git rev-parse --verify --quiet refs/remotes/origin/chore/aew-init > /dev/null; then
      echo "unpushed $(git rev-list --count origin/chore/aew-init..HEAD)"
    else
      echo "unpushed $(git rev-list --count <default_branch>..HEAD)"
    fi
    echo "ahead $(git rev-list --count <default_branch>..HEAD)"
    ```
  - `unpushed` above 0 → `"${CLAUDE_PLUGIN_ROOT}/scripts/git-branch.sh" push`. This is the case when this run committed, or when an earlier run stopped after its commit.
  - `ahead` above 0 → open the PR, even when nothing was pushed this run:
    - write `.aew/runs/init-pr-body.md` with the Write tool (what init did: stacks, config created or updated, defaults used that need review, labels, gitignore, Playwright, CLAUDE.md, permissions written or only proposed, standards per profile);
    - run `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-pr.sh" open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base <default_branch>` and keep the printed number.
  - `open` reuses an open PR (one `pr list`, no create), so calling it on every run is idempotent. It also retries a PR that failed after an earlier push. A `gh-pr.sh` failure is reported with its error and leaves everything else in place, and the next run retries it.
  - `ahead` 0 (the branch holds nothing the default branch lacks) → no push and no PR call. Leave the branch checked out: cut 9 means no branch deletion, and the next run reuses or restarts it (§2).
- **§13 Report.** Remove the scratch files (`rm -f .aew/runs/init-config.json .aew/runs/init-config-merged.json .aew/runs/init-permissions.json .aew/runs/init-settings.json .aew/runs/init-pr-body.md`). Then print, in this order:
  - prerequisites and stack-tool warnings;
  - stacks;
  - config written / unchanged, plus the detected differences that were kept;
  - "Defaults used" (headless or unanswered);
  - labels ensured;
  - gitignore lines added or present;
  - Playwright set up / skipped / present;
  - CLAUDE.md section added / present;
  - permissions written / unchanged / proposed only (with the list);
  - standards per profile;
  - the commit sha, or "nothing changed";
  - the PR number, or none;
  - next step: "merge the PR, then `/aew:ship <issue>`".

**Step 3: GREEN.**

Static checks first, then a full two-pass dry run of every deterministic step on the fixture. It stands in for the paid I1/I2 runs: the model's parts are played by the reference files, and the standards-setter is played by writing one doc.

```sh
. "${TMPDIR%/}/aew-init-env.sh"
grep -c '^## [0-9]*\. ' "$REPO/skills/init/SKILL.md"                            # 13
wc -l < "$REPO/skills/init/SKILL.md"                                             # < 500
grep -c 'subagent_type: aew:standards-setter' "$REPO/skills/init/SKILL.md"       # 1
grep -c '`mode: init`' "$REPO/skills/init/SKILL.md"                              # >= 1
grep -c 'gh-pr.sh" open chore/aew-init' "$REPO/skills/init/SKILL.md"             # 1
grep -cE 'git add (-A|\.)( |$)' "$REPO/skills/init/SKILL.md"                     # 1 (only the "Never git add -A or git add ." line)
grep -cE 'git branch -[dD]' "$REPO/skills/init/SKILL.md"                         # 1: only the hint in §2's stop message; init never runs it (cut 9)
grep -o '\${CLAUDE_PLUGIN_ROOT}/[A-Za-z0-9_./-]*' "$REPO/skills/init/SKILL.md" | sort -u | sed "s#\${CLAUDE_PLUGIN_ROOT}#$REPO#" | while read -r f; do test -e "$f" || echo "missing $f"; done   # (no output; D-C2)
```

Write the pass to `$W/pass.sh` with the Write tool, then run it twice (`. env; fresh; bash "$W/pass.sh" > "$W/out1"; record; bash "$W/pass.sh" > "$W/out2"`):

```sh
# one init pass, deterministic steps only (headless: no Playwright, no settings write)
set -e
. "${TMPDIR%/}/aew-init-env.sh"
S='s/<default_branch>/main/g'
run 2 3 "$S"                                   # branch
run 3                                          # gitignore
cp "$W/ref.json" "$W/p/.aew/runs/init-config.json"
run 6 1; if [ -f "$W/p/.aew/runs/init-config-merged.json" ] && ! jq -e --slurpfile m "$W/p/.aew/runs/init-config-merged.json" '. == $m[0]' "$W/p/.aew/config.json" > /dev/null 2>&1; then run 6 2; fi
run 7 2> /dev/null                             # labels (mock)
run 9                                          # CLAUDE.md
# standards-setter stand-in: write the doc once, reuse afterwards (C-2 reused = no write)
mkdir -p "$W/p/docs/standards"; [ -f "$W/p/docs/standards/nextjs.md" ] || echo '<!-- aew:standards -->' > "$W/p/docs/standards/nextjs.md"
(cd "$W/p" && git status --porcelain --untracked-files=all)
(cd "$W/p" && if [ -n "$(git status --porcelain)" ]; then git add -- .gitignore .aew/config.json CLAUDE.md docs/standards/nextjs.md && git commit -qm "chore: set up aew" && echo committed; fi)
out=$(run 12 2 "$S"); echo "$out"
u=$(echo "$out" | sed -n 's/^unpushed //p'); a=$(echo "$out" | sed -n 's/^ahead //p')
printf 'https://github.com/acme/fixture/pull/7\n' > "$GH_MOCK_DIR/responses/pr-create.out"   # pass 1: create
printf '7\n' > "$GH_MOCK_DIR/responses/pr-list.2.out"                                      # pass 2: the lookup finds #7
if [ "$u" -gt 0 ]; then (cd "$W/p" && "$REPO/scripts/git-branch.sh" push); fi
if [ "$a" -gt 0 ]; then (cd "$W/p" && printf 'body\n' > .aew/runs/init-pr-body.md && "$REPO/scripts/gh-pr.sh" open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base main); fi
```

Expected:

- `out1`: `committed`, `unpushed 1`, `ahead 1`, `chore/aew-init`, then `7`. The mock log has 11 `label create`, one `pr list`, one `pr create … --base main --title chore: set up aew --body-file …`.
- Record `git -C "$W/p" rev-parse main chore/aew-init`, `shasum -a 256 .aew/config.json` and `wc -l < "$GH_MOCK_DIR/calls.log"` (13) between the passes.
- `out2`: `config unchanged`, `present …` twice, `CLAUDE.md section present`, an empty status listing, no `committed`, `unpushed 0`, `ahead 1`, then `7` (reused). No push.
- After pass 2: `git -C "$W/p" status --porcelain` is empty. Both heads and the config sha are unchanged. The mock log grew by exactly 12 lines: 11 `label create` and one `pr list`. `grep -c '^pr ' "$GH_MOCK_DIR/calls.log"` is `3` and `grep -c '^pr create' "$GH_MOCK_DIR/calls.log"` is still `1`. That is AC-33's evidence form, free.
- `git -C "$W/origin.git" rev-parse chore/aew-init` equals the local head (pushed to the local bare origin only).

Finally: `claude plugin validate "$REPO"` → `✔ Validation passed`; `tests/run-script-tests.sh` stays green (no script changed here); `git -C "$REPO" status --porcelain` shows only `skills/init/SKILL.md` before the commit.

**Step 4: commit.**

```
feat(skills): init generates standards and opens its PR idempotently

Dispatches standards-setter in mode: init, commits only init's own files
as "chore: set up aew", pushes chore/aew-init through git-branch.sh and
opens or reuses the PR through gh-pr.sh open on every run where the branch
is ahead (so a failed PR call is retried). An unchanged repo gives no
commit, push or new PR; a memory-only standards-setter update is dropped
so a re-run changes nothing.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

## Phase verification (after D1–D6)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
claude plugin validate .                                                   # ✔ Validation passed
grep -E '^## [0-9]+\. ' skills/init/SKILL.md | wc -l                       # 13
grep -c '^disable-model-invocation: true$' skills/init/SKILL.md            # 1
wc -l < skills/init/SKILL.md                                               # < 500
tests/run-script-tests.sh                                                  # green
git log --oneline -6                                                       # the six conventional commits of D1–D6
git status --porcelain                                                     # clean apart from files of other phases
```

## AC → task matrix

| AC | Task(s) | Evidence (free, this phase) | Live evidence |
|---|---|---|---|
| AC-24 frontmatter, prerequisites, stack tools warn, no global installs, dirty tree stops | D1 (§1, §2), D2 (stack tools) | Frontmatter awk; `run 1 1` ok and fake-PATH outputs; `stray.txt` listing | Phase F I1 |
| AC-25 `chore/aew-init` created or switched to (restarted when merged, stops when diverged) | D1 | `run 2 3`: create, reuse, restart, diverged stop | I1, I2 |
| AC-26 detection, discovery (all six `env_type` values), one round, headless defaults listed | D2, D3 | detect output without `evidence`; the reference proposal; `run 5 1` difference and stack lines | I1 report's "Defaults used" |
| AC-27 written with stable format, ajv-valid, existing values win, nothing removed or duplicated, invalid stops | D3 | `run 6` sequence: changed → written, unchanged + sha, kept 3001 + re-added lint, tailwind re-added with nextjs's existing version kept, invalid → exit 1 with no file | I1 `ajv` (AC-44) |
| AC-28 `gh-labels.sh ensure`, two gitignore lines once each | D4, D2 | 11 `label create` in the mock; `grep -cxF` = 1 each | I1/I2 |
| AC-29 Playwright offer, ask before installing, no answer skipped and reported | D3 (the offer in the round), D4 (§8) | §5/§8 text greps; recommended = skip | I1 report "skipped" |
| AC-30 one `## Agentic workflow` section, never duplicated | D4 | `run 9` twice; heading count 1 | I1/I2 |
| AC-31 permissions shown and asked, merged without duplicates, no answer → not written, anchored rules (cut 6) | D5 | `anchored` checks on the template and the 26-rule list; merge twice; broad-rule grep 0 | I1 "proposed only" |
| AC-32 standards-setter `mode: init`; commit only if changed; push; `gh-pr.sh open` (no branch deletion, cut 9) | D6 | dispatch greps; pass 1 log (`pr list`, `pr create --base main`) | I1 |
| AC-33 second run changes nothing | D6 | pass 2: clean status, heads and config sha unchanged, only 11 `label create` and one `pr list` (reuse) added, no `pr create` | I2 (AC-44) |

## Cross-phase assumptions (to reconcile)

1. **Phase A (C-2, task A2):** init dispatches exactly `mode: init` with no other field. It reads the return block from the final message and treats `ARTEFACTS: none` as valid. When every fingerprint matches, nothing under `docs/standards/` is written (README included). That is what makes I2 clean. Memory may still change, and init handles that (§11 memory decision).
2. **Phase A (C-3, task A3):** init calls `gh-pr.sh open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base <default_branch>` after `git-branch.sh push`. The body file is inside the project, under the gitignored `.aew/runs/`. Init relies on stdout being exactly the PR number and on a reuse making no `pr create` call.
3. **Phase B:** §10's `Bash(git fetch origin <default_branch>)` assumes ship's preflight runs exactly `git fetch origin <default_branch>` (cut 7). If B uses another form (for example a bare `git fetch`), one of the two must change so the exact rule matches. The other orchestrator commands B uses (`state.sh` and the other scripts, `jq`, `git switch`, `claude plugin list --json`, `gh auth status`) are covered. B's temp-file handling for the blocked report (Assumption 20, `mktemp`) is not pre-approved and will prompt interactively.
4. **Phase C:** `status` lists only directories under `.aew/runs/` whose names match the run-id pattern (`^[1-9][0-9]*$` or `^m-…`), so init's scratch files (removed at the end of every run, but left behind if a run is interrupted) and `current` never show up as runs.
5. **Phase E:** `skills.bats` can rely on D-C1 (13 numbered sections, frontmatter) and D-C2 (every `${CLAUDE_PLUGIN_ROOT}/…` path is real; no label names). The permissions template uses the literal `${CLAUDE_PLUGIN_ROOT}/scripts/<real name>.sh`.
6. **Phase F:** I1/I2 expectations are D-C4. The harness needs a canned `pr-create.out` with a `/pull/<n>` URL and a canned `pr-list.2.out` with that number (I2's reuse lookup), and should create the bare origin with `main` as HEAD (`git clone --bare`, or `git init --bare -b main`) so the `ls-remote` fallback finds the default branch. The I1 allowlist must cover §1–§13's commands, including `npx --yes -p ajv-cli@5 … ajv validate *`, the gitignore/CLAUDE.md snippets (`touch`, `grep`, `tail`, `printf`, `cat`, `echo` in compound form) and `rm -f .aew/runs/init-*`. DESIGN.md records init mode (§8.3) and AC-31's rule semantics in Phase F only: this phase does not edit DESIGN.

## Decisions in this phase (flag if wrong)

1. **One file, no `references/`.** The procedure is about 300–400 lines, well under the 500-line limit, and nothing else reads it (unlike ship's references, which resume reads).
2. **The Playwright offer joins the §5 question round**, so the user is asked at most twice (the config round and the permissions question). Its recommended answer is **skip**, because QA sets Playwright up on first use (ui-qa §2) and nothing installs without a yes.
3. **The config holds only the six required keys.** Optional sections stay at schema defaults (every reader already falls back to them), so a later default change in the plugin reaches the project. `config.example.json` shows the full form.
4. **Empty detection stops init.** `stacks` has `minItems: 1`, so no valid config is possible. The standards-setter's own empty-detection branch (C-2) is therefore never reached from init.
5. **Scratch files go in `.aew/runs/`** (gitignored in §3 first, inside the project), not in `mktemp` outside it. Write and `acceptEdits` cover the project, ajv sees a `.json` name, and an invalid config never reaches `.aew/config.json`.
6. **The no-op is decided on semantic equality** (`jq ==`), not bytes. A hand-formatted, already-complete config or settings file is never rewritten.
7. **An interrupted init is finished, not refused.** On `chore/aew-init`, a dirty tree made only of Init's files passes §2. Without this, any failure after the first write would block every later init until the user cleaned up by hand.
8. **The branch is created from the local default branch, with no fetch.** The init PR is a plain review: conflicts show there, and a re-run never touches the default branch. An existing `chore/aew-init` whose commits are all in the default branch (merged PR) is restarted there with `git switch -C`. One that has diverged (squash-merged or closed PR, plus new default-branch commits) stops init with a `git branch -D` / rebase hint. Init never deletes or rebases it itself.
9. **Push and PR recovery:** push when `origin` lacks the branch's commits. Call `gh-pr.sh open` whenever the branch is ahead of the default branch: `open` reuses an open PR, so this is idempotent, and it retries a PR that failed after an earlier push. A clean re-run therefore makes one `pr list` call and no `pr create`.
10. **Standards-setter memory:** committed with init's other files. A memory-only change on a re-run is discarded so AC-33 holds (coordinator item; Phase A keeps memory updates in init mode).
11. **Permissions (cut 6):** allow rules only, each exact or `<command> <subcommand> *`. `install` is exact. Read-only git needs no rule (built in). `git diff/log/show/format-patch` and `git fetch` get no wildcard. `git branch *` is allowed because the developer uses it (local refs only). The proposal says it isn't a security boundary.

## Risks

- **Permissions over-match** (RISKY, D5): a trailing wildcard on a config command (`npm run lint *`) allows any arguments to that script, which already runs project code. Mitigations: anchored rules only, no wildcard before a subcommand, `install` exact, scripts by exact path, never written without a yes, a reviewable hunk in the PR, and the Bash guard hook remains the enforcement. Rollback as in D5.
- **Model-followed procedure drift:** the model may paraphrase a snippet. The snippets are short and checked here verbatim, and I1/I2 in Phase F are the behavioural proof.
- **Standards-setter rewriting on a re-run** (README or a doc when nothing changed) would break AC-33. C-2 says it doesn't. If I2 shows a diff, the fix goes in the agent (Phase A's file), never by weakening the check.
- **ajv via `npx`** needs the npm cache or the network on first use. A failure stops init before any write to `.aew/config.json`, with ajv's message.
- **Default-branch detection** can fall through to the current branch on unusual remotes. It's then asked in §5 (headless: used and listed under "Defaults used").
- **Global `chromium` download** on a Playwright yes goes to Playwright's user cache, not a global tool install. It happens only on an explicit yes, and the question says so.

## Approval (Phase D)

- Senior architect: APPROVED 2026-10-24T23:28:05Z (plan-review FULL, then plan-diff-review of the M1–M4 revision)
- Plan format: FULL
- Dependency graph: valid. 6 waves, max width 1 (all tasks write `skills/init/SKILL.md`); D6 also depends on Phase A tasks A2 and A3 (ids confirmed).
- Risk lines crossed: permissions (D5); rollback recorded; CTO risk-gate applies to D5.
- Plan content hash (SHA-256, the doc above this trailer): 82ec56451c3ab8f788919e844d48808ab6911c7603eb1fe28f5a8e3cd6c83d3a
