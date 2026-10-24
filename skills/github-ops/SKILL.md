---
name: github-ops
description: How the aew orchestrator reads and writes state, GitHub issues, labels, branches, pull requests, milestones and retro issues through scripts/. Covers each script, the spec-revision recording order, operational rules and known limitations. Use it whenever the orchestrator touches GitHub or state.json.
user-invocable: false
---

# aew github-ops

Only the orchestrator runs these scripts. Agents never call `gh` (DESIGN §2.4); they write files
and return a block. Every script has `--help`, exits 1 on invalid input before any write, and
lives in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Stage/status to label mapping: `run-protocol` "Labels".

## Scripts

| Script | Use it to | Example |
|---|---|---|
| `state.sh` | init, read and move the run's `state.json` (the only writer) | `state.sh stage develop --note "WP1 started"` |
| `gh-issue.sh` | fetch an issue, post a comment, record a spec revision, set the manual-tests block | `gh-issue.sh fetch 42 .aew/runs/42` |
| `gh-labels.sh` | create the 11 labels, set the one stage label, toggle flags | `gh-labels.sh stage 42 building` |
| `git-branch.sh` | create the run branch from the pattern; push it | `git-branch.sh create 42 add-export` |
| `gh-pr.sh` | open, update, ready and comment on the PR | `gh-pr.sh create 42 .aew/runs/42/pr-body.md --draft` |
| `gh-milestone.sh` | list a milestone's issues with parsed dependencies | `gh-milestone.sh issues "v1.2"` |
| `gh-retro.sh` | file `retro.md` items to the retro repo, deduplicated | `gh-retro.sh file .aew/runs/42/retro.md me/app 42` |

Other calls: `state.sh init 42 --issues 42 --mode single`, `state.sh bump fix_cycle`,
`state.sh set pr 17`, `gh-issue.sh comment 42 spec-revision-v2.md`,
`gh-issue.sh revise 42 spec-final.md 2`, `gh-issue.sh manual-tests 42 manual-tests.md`,
`gh-labels.sh flag 42 add spec-revised`, `git-branch.sh push`, `gh-pr.sh update 17 pr-body.md --run 42`,
`gh-pr.sh ready 17`.

## Spec-revision recording order

1. Render `spec-revision-v<N>.md` from `spec-changes.json`.
2. `gh-issue.sh revise <n> spec-final.md <N>`
3. `gh-issue.sh comment <n> spec-revision-v<N>.md`
4. `gh-labels.sh flag <n> add spec-revised`
5. `state.sh set spec_revision <N>`

## Operational rules

- Run `gh-labels.sh ensure` before the first `stage` or `flag`; neither creates labels.
- Check `state.pr` before `gh-pr.sh create`. It has no "PR exists" lookup. For a re-rendered body use `gh-pr.sh update <pr> <file> --run <id>`, which applies the same closing-line fix.
- `revise` refuses the same version with different content. Bump `N`, never overwrite.
- Malformed aew markers, or a body over 65,536 characters: set `aew:blocked` and stop. Never trim history.
- Write state before each developer dispatch, not while a developer runs. The developer gate compares the report to `state.json` at whole-second resolution.
- Sub-developers write WP reports to the main worktree's run dir by absolute path; the run dir is gitignored and absent from their worktrees.
- Return-block lines stay on one line (`STATUS:`, `ARTEFACTS:`, `SUMMARY:`, `NEXT:`); the gate reads them line by line.

## Conventions and known inconsistencies

| Topic | Fact |
|---|---|
| Argument order | `<subcommand> <id> <file-or-value>`, with exceptions below |
| Exceptions | `gh-issue.sh fetch <n> <run-dir>`; `gh-pr.sh create <run-id> <body-file>`; `gh-retro.sh file <retro.md> <src-repo> <run-id>`; `gh-milestone.sh issues <milestone>` (number or title); `git-branch.sh create <run-id> <slug>` |
| Issue-number check | Duplicated in gh-issue, gh-pr and gh-labels, with equivalent behaviour |
| Empty retro | `gh-retro.sh` accepts an empty `retro.md` (exit 0, no items) |
| Repo targeting | Only `gh-retro.sh` passes `--repo` (from `retro.repo`). The rest act on the cwd repo. `GH_REPO` is honoured by `gh` itself and by `gh-milestone.sh` cross-repo filtering |

Stdout contract:

| Script | Prints |
|---|---|
| `state.sh` | `get`: JSON or the field; `bump`: the new value; `current`: the run id |
| `gh-issue.sh` | `comment`: the comment URL; the others are quiet |
| `gh-labels.sh` | quiet |
| `git-branch.sh` | `create` and `push`: the branch name (git chatter on stderr) |
| `gh-pr.sh` | `create`: the PR number; the others are quiet |
| `gh-milestone.sh` | a JSON array of `{number, title, labels, state, depends_on}` |
| `gh-retro.sh` | one line per item: `created #n` or `commented #n` |

## Known limitations

- No rewrite of a real issue body (`revise`, `manual-tests`) until prompt 07's sandbox end-to-end run passes. Sandbox issues only until then.
- Rollback for a bad rewrite: GitHub's issue edit history ("edited" menu), or `00-issue-original.md` / `issue.json` in the run dir, which `fetch` writes verbatim.
- `revise` and `manual-tests` read the body, then edit it; a human edit between the two is lost (lost-update race).
- `blockedBy` links are read up to 50 per issue.
- `gh-retro.sh` may drop the retro label when the token lacks triage rights; the issue is still filed.
