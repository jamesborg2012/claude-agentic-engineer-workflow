# Brainstorm — End-to-end validation on real GitHub and the 0.1.0 release (build prompt 07)

- **Issue:** no issue. This is build prompt 07 (`docs/build-prompts/07-e2e-validation.md`). DESIGN.md wins on conflict.
- **Date:** 2026-10-26

## Problem

Every stage of aew has been proven only against a mocked `gh`, a local bare `origin` and fixture apps (prompts 03 to 06). Nothing has yet run against real GitHub, a real install from the marketplace or a project James did not hand-build for the harness. Build prompt 07 is an **operational validation with a fix loop**, not a feature build: install the plugin for real, run eight (optionally nine) scenarios in a private sandbox repo, fix what breaks, record the evidence, triage the retro issues and release 0.1.0.

What can be decided now is the environment, the sandbox app, the scenario fixtures, how each scenario is driven, the order and merge points, the evidence format, the spend envelope and the fix-loop protocol. What can't be decided now is which fixes will be needed. This spec therefore defines **how** a failure is handled, not what the fixes are.

## Acceptance criteria

Every acceptance criterion and scenario expectation from the prompt is kept and marked **[P]**. The rest turn the prompt's steps, DESIGN §3, §6, §9 to §12 and the items carried forward from prompts 05 and 06 into testable criteria. "V-n" refers to the verification list below. "CP-n" refers to the execution-time human checkpoints.

### Verification before relying on a platform feature

1. **AC-1** Before step 1, every fact in the V-list is checked against code.claude.com/docs through the claude-code-guide agent (and gh's own docs for V-10 and V-11). Each result goes into `tests/e2e-validation.md` `## Platform facts`, with the date and the doc URL. Where the docs contradict DESIGN §3 or §11, DESIGN is updated in the same commit as the change that depends on it (repo CLAUDE.md rule). Nothing in this spec about the CLI's flags is asserted from memory.

### Step 1: install for real

2. **AC-2 [P]** The local marketplace is added and `aew` is installed at **user scope**, using the commands V-1 confirms (expected shape: `claude plugin marketplace add <abs path to this repo>`, then `claude plugin install aew@jamesborg-plugins --scope user`). `claude plugin list --json` then shows `aew@jamesborg-plugins` at version `0.1.0`, enabled, plus `superpowers`, `context7` and `frontend-design` from `claude-plugins-official`, all enabled.
3. **AC-3 [P]** Dependency resolution is **proven**, not inferred. The three dependencies are already installed at user scope on this machine (superpowers 7.0.0, context7 and frontend-design at `58267944f921`, observed 2026-10-26), so the user-scope install can't show them being pulled in. The install is therefore repeated in an isolated, throwaway Claude config (the mechanism V-2 confirms, expected `CLAUDE_CONFIG_DIR=<scratch>`), where the install of `aew` alone must bring in all three (Assumption 3).
4. **AC-4 [P]** One cheap probe session (haiku, in the sandbox, cap $0.50) proves that:
   - its `system/init` lists the six user-invocable skills `/aew:init`, `ship`, `ship-milestone`, `resume`, `status` and `prompt`;
   - it lists the seven agents as `aew:<agent>`;
   - `plugin:aew:playwright` reports as connected (V-6).
5. **AC-5 [P]** README `## Install` records the exact commands that worked in AC-2 (with `--scope user`), the isolated dependency check of AC-3 as a troubleshooting aid, and how to refresh the install after a change (V-3).

### Step 2: the sandbox

6. **AC-6 [P]** `gh repo create aew-sandbox --private` creates `jamesborg2012/aew-sandbox` (absent on 2026-10-26). In the same step, `gh repo create aew-sandbox-retro --private` creates `jamesborg2012/aew-sandbox-retro`, an empty repo used only as the runs' `retro.repo` (AC-9, AC-11, AC-29). The local clone is `/Users/jamesborg/Documents/Development/aew-sandbox`. It is a sibling of this repo and its own git repo, never inside the plugin tree, because a project there has every subagent `.aew/` write denied (project-map gotcha) and loads this repo's `CLAUDE.md` as an ancestor. No ancestor directory has a `CLAUDE.md` (checked).
7. **AC-7 [P]** The sandbox app is minimal and pinned:
   - Next.js (App Router, TypeScript) with Tailwind CSS;
   - one page (`app/page.tsx`) with a contact form (name, email, message) that posts to one API route (`app/api/contact/route.ts`), which answers `200 {"ok":true}` and keeps nothing;
   - a `lint` script (ESLint);
   - a unit-test setup (Vitest) with one passing test of the route handler;
   - `build` passes.

   There is no Playwright and no `.aew/`. Dependency versions are exact pins, taken at creation time from the current releases (checked with context7 or npm, not memory). A short README says what the sandbox is for. Everything is pushed to `main`.
8. **AC-8** The sandbox gets a gitignored `.claude/settings.local.json` that disables the unrelated user-scope plugins `dev-workflow`, `figma` and `warp` for this project only (V-13), so that their hooks and skills can't intercept a session or produce a guard denial that would be mistaken for aew's. `frontend-design`, `superpowers` and `context7` stay enabled, because disabling a dependency stops `aew` loading (DESIGN §3). `init` merges its own entries into this file later (Assumption 6).

### Real-GitHub rails (CTO condition C3, carried from prompt 05)

9. **AC-9** No session in this prompt runs under the keychain `gh` token.
   - James creates a fine-grained PAT (CP-2) whose selected repositories are **only** `aew-sandbox` and `aew-sandbox-retro` (plus `aew-sandbox-woo` if S9 runs, AC-25), with contents, issues, pull requests and metadata access. A fine-grained PAT's permissions apply uniformly to every selected repo, so the plugin repo is **not** selected: selecting it would give agents (which hold Bash and see `GH_TOKEN`) contents and pull-request write on the plugin. This keeps CTO condition C3 ("scoped to the sandbox repo only") as written (Assumption 4).
   - The token lives in a mode-600 file outside both repos. The launchers export it as `GH_TOKEN` and point `GH_CONFIG_DIR` at an empty directory. git pushes over HTTPS through gh's credential helper (V-10).
   - Canary, before the first session and after any launcher change: in the session environment, `gh api user` names James, `gh repo view` of a private repo outside the PAT's scope fails, **and** `git ls-remote https://github.com/<owner>/<that out-of-scope private repo>.git` fails (so no git credential helper, such as `osxkeychain`, still reaches the keychain credential; C3 "make the keychain token unreachable"). The output is recorded, and the token is never printed.
10. **AC-10** Every session starts through one of two launchers in `$E2E` (`/Users/jamesborg/Documents/Development/aew-e2e`, a plain directory and never a repo; Assumption 7):
    - **`e2e-run.sh`** is for headless sessions. It is rebuilt from the `tests/agent-smoke/README.md` §9.2 reference copy, with the environment lines changed for real GitHub (no `gh` shim, no `GH_HOST=…invalid`, a real `origin`; AC-9). It keeps the explicit allowlist, `--permission-mode acceptEdits`, `--permission-prompts none`, the deny on editing the plugin checkout, the denies on user MCP connectors, the spend ledger with a stop, the kill-stage trigger and the post-session Bash audit. The audit gains the C3 patterns: `GH_HOST` without `=`, `unset ` and `PATH=`. The allowlist starts from the `.claude/settings*.json` that `init` wrote and adds only what the harness needs, so the headless runs also test init's proposal. It carries no `awk 'NF'` rule (C2: dropped). For the broad harness lines (`sh -c *`, `node *`, `npx *`, `curl *`), C3's choice is made and recorded in `tests/e2e-validation.md` `## Rails and launchers`: either each is narrowed, or it is recorded in writing that the audit only detects (it does not prevent) a bypass through them.
    - **`e2e-session.sh`** is for attended interactive sessions. It applies the same environment and `cwd`, then starts `claude` in the sandbox for James.
    - The launcher's diff against the §9.2 copy is recorded in `tests/e2e-validation.md`. Streams, transcripts and the token file are never committed.

### Step 3: init

11. **AC-11 [P]** `/aew:init` runs **attended** (CP-4), because it asks three things that a headless run would answer with defaults:
    - **The config values.** James confirms them, with `retro.repo` = `jamesborg2012/aew-sandbox-retro`. That is inside the PAT's scope, and it still exercises `gh-retro.sh`'s cross-repo `--repo` path and its "Seen again" de-duplication on real GitHub. The items reach the plugin repo by transfer at step 6 (AC-29).
    - **Playwright.** James accepts it, so S2 can commit specs (Assumption 5).
    - **Permissions.** James accepts them, so the later sessions don't prompt on every command.

    The checks:
    - `.aew/config.json` validates against `templates/config.schema.json`;
    - `stacks` includes `nextjs` and `tailwind`;
    - `commands` names the sandbox's lint, unit-test, build and dev scripts;
    - every DESIGN §7.4 label exists on the sandbox repo;
    - the `.gitignore` lines, the `CLAUDE.md` section and `docs/standards/` (with the fingerprint header) are present;
    - `.claude/settings.json` and `.claude/settings.local.json` are written and merged with AC-8's file;
    - a PR from `chore/aew-init` opens with `## In plain English`, which passes `check-pr-intro.sh` **and** the accuracy review (AC-14).
12. **AC-12 [P]** The executor reviews the init PR and then asks James to merge it (CP-3). It never calls `gh pr merge`, which the guard blocks by design. After the merge, the executor fast-forwards local `main` (`git pull --ff-only`), because ship's preflight stops on a `main` that is behind. The same fast-forward follows **every** CP-3 merge, before the next scenario starts.

### Step 4: scenarios

13. **AC-13** Issues and milestones are created with `gh` in the sandbox before the first scenario. Milestones go through `gh api` if `gh` has no milestone command (V-11). The S6 issues are created in chain order, so that each `Depends on #n` names a real number. The body of every issue is recorded verbatim in `tests/e2e-validation.md` `## Sandbox fixtures`, so that a re-run is reproducible. The fixtures are listed under "Scenario fixtures" below.
14. **AC-14 [P] Introduction review, for every PR** (the init PR, S1 to S6 and each S6 child, and S7's):
    - `check-pr-intro.sh` exits 0 on the PR body as opened.
    - The executor writes a verdict of `accurate` or `fail`, with one line of reasons, after comparing the introduction against what actually happened: the run's `state.json` history, `10-summary.md`, the QA report, the manual tests and the review and fix cycles.
    - It fails if a reader couldn't understand the run from the introduction alone, if it is generic (it would fit any PR), or if it states anything the artefacts contradict. A failure counts **even when the script passes**, and it goes into the fix loop as a doc-writer prompt defect.
15. **AC-15** Common checks, applied to every ship-style run (S1 to S7) and recorded per run:
    - **CR-1** `state.json` validates against the schema, and its `status` is `done` (or the designed stop), with `current` cleared.
    - **CR-2** Each issue ends with exactly one stage label, `aew:ready-for-review`, plus only the flags the scenario expects.
    - **CR-3** The PR body carries a `Closes #n` for every issue, and the PR's base is correct.
    - **CR-4** On the PR branch, the sandbox's lint, unit tests and build pass when the executor runs them.
    - **CR-5** Every aew-made commit ends with exactly `Co-Authored-By: Claude <noreply@anthropic.com>`, with no model-name trailer (the prompt-05 attribution item).
    - **CR-6** Every guard-hook denial is listed and classified as a true or a false positive (AC-27).
    - **CR-7** Every permission denial in a headless stream is listed. A denial of a command the plugin itself prescribes is a defect. A denial of an improvised agent command is recorded and fixed in the agent's prompt if it recurs.
    - **CR-8** The final report is printed. The review and fix cycles and the duration (`started_at` to `updated_at`, plus wall-clock) are recorded.
    - **CR-9** The retro items filed in `aew-sandbox-retro` are listed against the run, with any "Seen again" de-duplication comment noted.
16. **AC-16 [P] S1, non-UI, gates on.** `/aew:ship <S1>` (no `--auto`), attended, through `e2e-session.sh` (CP-4).
    - The plan gate is shown as an AskUserQuestion with approve, request changes and stop. The plan summary is 25 lines or fewer, plus the path.
    - James approves.
    - Every AC is traced to at least one test (the QA report's TC → AC table, and `10-summary.md` shows `n/n` ACs passed).
    - A PR is opened.
    - This is the first paid ship run, so it also confirms CTO condition C2: ship's `grep -v '^$' <file> | tail -n 4` return checks raise no prompt interactively. S2 (AC-17) confirms they cause no denial headless.
17. **AC-17 [P] S2, UI with an accessibility requirement, `--auto`.** `/aew:ship <S2> --auto`, headless through `e2e-run.sh`. The checks:
    - no plan gate;
    - Playwright specs are committed under `ui.e2e_dir`;
    - screenshots for both viewports (`desktop` 1440×900, `mobile` 390×844) are in `docs/qa/<S2>/`;
    - the axe results (to the `ui.axe_standard` target) are in the QA report.

    Recorded for information: whether the developer invoked `frontend-design`, and whether the QA fix-cycle route ran. Both are open items carried from prompt 04.
18. **AC-18 [P] S3, deliberate material ambiguity.** `/aew:ship <S3> --auto`, attended, because the gate needs James's answer.
    - The spec gate fires even with `--auto`.
    - After James answers, the issue body shows revision v2 on top, with the author's original kept below as a collapsed v1, byte for byte.
    - A revision comment lists the changes, and the `aew:spec-revised` flag is set.
    - The run continues to a PR.
19. **AC-19 [P] S4, one non-automatable check.** `/aew:ship <S4> --auto`, headless. The checks:
    - the issue body gains the aew manual-tests block;
    - `aew:manual-test-required` is set;
    - the PR lists the manual test, and the final report counts it as outstanding;
    - every other AC is automated.

    If the spec analyser treats the email requirement as material and gates, the run is resumed attended (CP-4) and the fixture note records it (the §9.5 precedent).
20. **AC-20** A pass of S3 and S4 is the evidence that writes to a real issue body are safe. On a pass, the "no rewrite of a real issue body until prompt 07" limitation is removed from `skills/github-ops/SKILL.md` and from the CHANGELOG.
21. **AC-21 [P] S5, a bulk milestone.** `/aew:ship-milestone <M-S5> --auto`, with no mode flag, attended, because the mode question needs an answer.
    - The skill recommends **bulk** with its rationale, and James confirms.
    - One PR has a `Closes #` for all three issues.
    - Its introduction is the bulk variant and passes `--issues 3`.
    - Each issue has `aew:ready-for-review` and the milestone report comment.
22. **AC-22 [P] S6, a sequential chain.** `/aew:ship-milestone <M-S6> --sequential`, attended, with gates on, so the per-child plan gate (never exercised live) is shown three times and James approves each plan.
    - The order is the chain order.
    - Child 1's PR targets `main`, child 2's targets child 1's branch and child 3's targets child 2's branch, each with the stacked introduction.
    - The index reads `done, done, done`.
    - The milestone report is on all three issues.

    **Stacked merge protocol** (CP-3). `Closes #n` fires only when a PR merges into the default branch, and GitHub retargets a stacked PR automatically only when its merged base branch is deleted. aew never retargets (DESIGN §10).
    - James merges children 1 and 2 with **"Create a merge commit"**, not squash. That way, once retargeted, the next child's diff holds only its own commits.
    - Before James merges child 2, and again before child 3, the executor runs `gh pr view <pr> --json baseRefName` and checks that the base is `main`. If it isn't, James retargets the PR to `main` in the GitHub UI first. Neither aew nor the executor ever retargets.
    - After all three merges, the executor checks that all three issues are closed and that `main` contains all three changes (the store module, the route and the page).
    - It records, per child, the merge method, whether the branch was deleted, and whether GitHub retargeted the next PR on its own or James did. This is prompt 06's Risk 3, recorded and not automated.
23. **AC-23 [P] S7, an interrupt during `develop`.** `/aew:ship <S7> --auto` is an S1-style non-UI issue, run headless.
    - The launcher's kill-stage trigger sends SIGINT, the signal Ctrl-C sends, once `state.json` shows `develop` (V-9).
    - A headless `/aew:status` then shows the run at `develop`, status `running`.
    - A new session shows the SessionStart hint "Active aew run <id> at stage develop (running). Use /aew:resume.", evidenced by the hook output in the stream or the debug log (V-7).
    - A headless `/aew:resume` continues from `develop`. Artefacts 01 to 05 are byte-identical to before the kill, no earlier stage is re-dispatched, and the run reaches a PR (Assumption 8).
24. **AC-24 [P] S8, prompt mode, then a plugin-less session.**
    - **Prompt mode.** A headless `/aew:prompt <S8>` writes `.aew/runs/<S8>/prompt.md`, with no branch, no commit and no stage label. The offer to post it is unanswered headless, so nothing is posted.
    - **Plugin-less session.** `prompt.md` is then the only input to a session with no plugin: `claude --bare -p` if V-5 confirms it works under James's authentication, otherwise a profile with every plugin disabled. That session runs headless, through `e2e-run.sh`, with a cap, in a separate local worktree **beside** the sandbox (`/Users/jamesborg/Documents/Development/aew-sandbox-s8`), not inside it. No aew guard runs in that session, so it is fenced by its environment instead:
      - it gets **no** `GH_TOKEN`;
      - `git push` and `gh` are left out of its allowlist, so `--permission-prompts none` denies them.
    - **Pass.** The session produces a plan and completes at least the first work package with its tests passing, without needing anything aew-specific that `prompt.md` doesn't give it (no `/aew:` skill, no agent and no `.aew/` artefact other than ones `prompt.md` names). The executor's verdict lists any gap it hit. Its branch is local only and is never pushed (Assumption 9).
25. **AC-25 [P] S9, optional, WooCommerce with wp-env.** At the S9 checkpoint (CP-5), `docker info` decides it. On 2026-10-26 Docker is installed but its daemon is not running.
    - **If the daemon is up and the spend envelope allows it:**
      - a second private sandbox, `aew-sandbox-woo`, is created and cloned beside the first;
      - James adds `aew-sandbox-woo` to the PAT's selected repositories, and the AC-9 canary is re-run before any S9 session;
      - it holds a minimal WooCommerce extension with `.wp-env.json`;
      - `/aew:init` detects `wordpress` and `woocommerce` and generates both standards docs;
      - one small issue ships through `/aew:ship <n> --auto` to a PR, with AC-14 and AC-15 applied.
    - **Otherwise** S9 is recorded as skipped, with the reason.

### Step 5: recording results

26. **AC-26 [P]** `tests/e2e-validation.md` (new) is complete, in the record form of `tests/agent-smoke/README.md` §9 and §10. It has these sections:
    - **Environment:** the Claude Code, gh, Node and plugin versions, and the installed dependency versions.
    - **Platform facts:** AC-1.
    - **Rails and launchers:** AC-9 and AC-10.
    - **Spend ledger:** one row per session, giving its cap, cost, running total, whether it was attended, and the cost source (the stream's `result`, `/cost`, or the cap counted for a killed session).
    - **Sandbox fixtures:** AC-13.
    - **A section per scenario**, holding:
      - the expectation table with pass or fail for each [P] expectation and each CR check, and its evidence;
      - the review and fix cycles used;
      - the rough duration;
      - the problems found;
      - one sub-heading per attempt.
    - **Introduction verdicts:** AC-14.
    - **Guard and permission denial log:** CR-6 and CR-7.
    - **Fix log:** commit, problem, scenario, re-run and result.
    - **Retro triage:** AC-29.
    - **Roll-up:** the build-prompt ACs and this spec's ACs, each `pass`, `fail` or `skipped` with its evidence.

    Each scenario's section is written straight after that scenario, before the next one starts.

### Fix loop

27. **AC-27 [P] No guard false positive is left unresolved.** Every aew guard denial (Bash or Edit/Write) in any session is logged with its command and classified.
    - **A false positive** is fixed in `scripts/hooks/guard-*.sh`, with a new row in the table-driven bats cases, and the affected scenario is re-run.
    - **A true positive** is recorded with the reason the block was right.

    The guard stays a heuristic (DESIGN §11). A false positive is fixed by narrowing its pattern, never by removing a protection DESIGN lists.
28. **AC-28 [P] Fix-loop protocol**, for any failed expectation:
    1. **Classify** it as a plugin defect, a sandbox or fixture issue, a platform behaviour or an operator error. Only plugin defects change the plugin. A fixture issue is fixed in the fixture and recorded (the §9.5 and §10.7 tuning precedent).
    2. **Diagnose** it with `superpowers:systematic-debugging` from the run's artefacts and stream, before any change.
    3. **Fix** it on the plugin repo branch `feature/e2e-validation`:
       - a scriptable defect gets a failing bats test first;
       - an agent or skill defect is fixed by **improving the prompt**, never by weakening the scenario's expectation or the check;
       - a fix that would change designed behaviour updates DESIGN in the same commit, as a "Recorded deviations (prompt 07)" entry in the relevant section;
       - a fix not covered by DESIGN that is expensive to reverse stops for James (CP-6);
       - init's `SKILL.md` is at 507 lines (measured 2026-10-26), already over the 500-line guidance, so any init fix first moves content to `skills/init/references/` and brings the file back under 500.
    4. **Commit** each fix on its own, as a conventional commit with the plain Claude trailer.
    5. **Check** that `tests/run-script-tests.sh` and `claude plugin validate .` pass.
    6. **Refresh** the installed plugin by V-3's method, and prove the installed copy matches the fix (the changed file compared under `installPath`).
    7. **Re-run** the failed scenario as a new attempt in the ledger. Re-runs come out of the reserve, and a re-run beyond the reserve asks first (CP-1).

### Step 6: retro triage

29. **AC-29 [P]** The retro items first move to the plugin repo. The executor does this in its **own** session under the keychain token, never inside a run session or under the PAT:
    1. It makes sure a `retro` label exists in `jamesborg2012/claude-agentic-engineer-workflow`.
    2. It moves each open item in `aew-sandbox-retro` with `gh issue transfer <n> jamesborg2012/claude-agentic-engineer-workflow`.
    3. It records the old-to-new number mapping in `tests/e2e-validation.md`.
    4. If the transfer dropped the label (V-10), it adds `retro` back.

    A transfer is a move, not a deletion. Every retro issue now in the plugin repo (`gh issue list --label retro`; none were open on 2026-10-26) is then triaged in a table.
    - **Small** means a one-commit fix that needs no design decision. It is fixed now, in its own commit, and the issue is closed with a comment naming the commit.
    - Everything else is left open with a comment that says why and what it would take.

    Closing an issue is not a deletion. No issue is ever deleted.

### Step 7: release

30. **AC-30 [P]** README is finalised and accurate against these runs:
    - purpose;
    - install (AC-5);
    - prerequisites;
    - commands;
    - a config reference, one row per `config.schema.json` field with its default;
    - labels (DESIGN §7.4 stage labels and flags, with what each means);
    - the files the plugin creates in a project (DESIGN §6, the run dir, and init's settings and gitignore entries);
    - troubleshooting, from the problems actually hit;
    - uninstall, using commands V-12 confirms.

    The "in development" status line goes. Every command in the README was run, or is a documented form of one that was.
31. **AC-31 [P]** CHANGELOG: `[Unreleased]` becomes `[0.1.0] - <release date>`, with the validation fixes under `### Fixed`, and a new, empty `[Unreleased]` above it. `plugin.json` stays `0.1.0` (Assumption 10).
32. **AC-32 [P]** The release tag is `aew--v0.1.0`, the `<plugin>--v<version>` form that DESIGN §3 records for dependency version ranges (re-checked under V-4). It is an annotated tag on the commit James merges to `main` (CP-7), pushed by the executor after that merge. aew's Bash guard is inactive in the plugin repo (it acts only where `.aew/config.json` exists), and in any case blocks only pushes to the default branch, which a tag push is not. dev-workflow's guard matches the text `git push`, so the tag push goes through a script file run with `/bin/bash` (Key facts).
33. **AC-33** These are updated:
    - CLAUDE.md `## Recent changes`;
    - the project-map knowledge (prompt-07 learnings and the platform gotchas found), including a correction of the stale "init's SKILL.md is at 498 of 500 lines" note to the line count measured at release;
    - DESIGN §3, with each re-verified fact, and §12's quality-bar line, with the sandbox scenarios now passing.

    All of it is in British English.
34. **AC-34 [P]** Before claiming completion, `superpowers:verification-before-completion` is applied: the bats suite, `claude plugin validate .`, the schema validations, and a final re-read of `tests/e2e-validation.md` against every AC here. The executor then opens the plugin PR itself (`gh pr create`, per James's standing preference).
35. **AC-35 [P]** The final summary to James lists:
    - what was fixed during validation (commits);
    - the known limitations;
    - the open retro items;
    - any DESIGN conflicts found;
    - S1 to S8 as passed, with S9 passed or skipped and its reason;
    - the spend against the stop.

## Scenario fixtures

These bodies are drafted at execution in the sandbox's real context and recorded verbatim (AC-13). The shape is fixed now:

| # | Issue(s) | Shape | Why |
|---|---|---|---|
| S1 | "Validate contact submissions on the server" | `POST /api/contact` returns 422 with per-field errors (name required; email valid; message 10 to 1000 characters), and 200 otherwise. 4 ACs, no UI. | Non-UI, testable by unit tests. |
| S2 | "Show inline errors on the contact form, announced to screen readers" | Uses S1's 422 shape. Each error sits under its field (`aria-invalid`, `aria-describedby`), a summary is announced (live region), and focus moves to the first invalid field. WCAG 2.2 AA, both viewports. | UI plus accessibility, and depends on S1's code. |
| S3 | "Rate-limit contact submissions" | Deliberately leaves out the limit, the key (IP or global) and the response, which are material behaviour. | A gate is certain, and the build is small once answered (James answers, for example, 5 per IP per 10 minutes, 429 with `Retry-After`, in memory). |
| S4 | "Email the admin on each submission" | Sends to `ADMIN_EMAIL` through a mail transport. The AC "the admin receives the email" can't be automated, while the rest can (transport called, failure doesn't break the 200). | Exercises the manual-tests route. |
| S5 | Milestone "Contact page polish": three issues | Page title and meta description; a live character counter for the message; a privacy note under the button. Each has 3 ACs or fewer, the same page and no dependencies. | `select` must recommend bulk. |
| S6 | Milestone "Submissions log": three issues | (a) a submissions store module with unit tests; (b) `GET /api/submissions`, which depends on (a); (c) a `/submissions` page, which depends on (b). | A chain, so the PRs stack. |
| S7 | "Normalise contact fields on the server" | Trim the fields and lowercase the email. Non-UI, S1-style, on S1's code. | Long enough to reach `develop` before the kill. |
| S8 | "Return a request id from the contact API" | Small, clear and non-UI. | Prompt mode with no gate, then a plugin-less build. |

## Order, independence and merges

Nothing can start until the init PR is merged, because every run needs `.aew/config.json` on `main`. Preflight Check 5 allows one active run per project, so the scenarios in one sandbox run one at a time.

Every PR rewrites `CLAUDE.md` (curated by the doc-writer) and adds `docs/specs/`, so any two PRs cut from the same `main` would conflict. aew never rebases, so **each PR is merged before the next ship-style scenario starts**. The order is:

init → S1 → S2 (needs S1's code) → S3 → S4 → S5 → S6 (three children, merged in order) → S7 (needs S1's code).

**S8 is the one independent scenario.** It opens no PR and builds in a separate local worktree, so it runs while any PR waits for James's merge. S9 is a second repo and is independent of the rest.

## Execution-time human checkpoints (not brainstorm questions)

- **CP-1 Spend.** Before the first paid session, the executor shows the ledger (the caps below and the stop) and asks James to approve it. After that it asks only when a session would pass the stop, a cap would rise above 2× (the §9.1 rule), or a re-run would exceed the reserve.

  | Item | Cap (USD) | Attended | Drive |
  |---|---|---|---|
  | Install probe | 0.50 | no | headless (haiku) |
  | init | 5 | yes | interactive |
  | S1 | 15 | yes | interactive |
  | S2 | 20 | no | headless |
  | S3 | 10 | yes | interactive |
  | S4 | 12 | no | headless (attended resume if it gates) |
  | S5 | 25 | yes (mode question) | interactive |
  | S6 | 30 | yes (three plan gates) | interactive |
  | S7 kill, status probe, hint probe, resume | 8 (killed, so charged at cap) + 1 + 1 + 12 | no | headless |
  | S8 prompt, then plugin-less build | 4 + 8 | no | headless |
  | **Subtotal** | **151.50** | | |
  | Re-run reserve | 48.50 | | |
  | **Stop** | **200** | | S9 (cap 25) only if 25 or more remains under the stop |

  The caps come from the measured prompt-05 and prompt-06 costs (S1 $4.42, one sequential child $4.59), scaled up for a real Next.js app, real installs and Playwright. Interactive costs are read with `/cost`, or from the session's usage (V-8). If `--max-budget-usd` does not apply to interactive sessions, James checks `/cost` at each gate and stops the session once it reaches its cap.
- **CP-2 PAT.** James creates the fine-grained PAT (AC-9), selecting only `aew-sandbox` and `aew-sandbox-retro` (never the plugin repo), and saves it to the token file. The executor never sees or prints its value.
- **CP-3 Merges.** The executor asks James to merge each PR: init, S1 to S5, the S6 children in order, S7, and the plugin release PR. It never calls `gh pr merge`.
  - The merge method is James's choice and is recorded for each PR.
  - S6 follows AC-22's stacked merge protocol: children 1 and 2 are merged with a merge commit, and each base is checked as `main` before the merge, with James retargeting in the UI if needed.
- **CP-4 Attended sessions.** James runs init, S1, S3, S5 and S6 (and S4's resume, if it gates) through `e2e-session.sh` in his terminal, and answers the questions. The executor prepares each command and checks the results afterwards.
- **CP-5 S9.** This costs money and needs Docker. James decides whether to start Docker Desktop and run S9, or skip it. If S9 runs, he adds `aew-sandbox-woo` to the PAT's selected repositories, and the canary is re-run.
- **CP-6 Undesigned and expensive to reverse.** Any fix outside DESIGN that is expensive to reverse stops for James. So does anything that would delete a GitHub resource. The sandbox repos are never deleted, and deleting a branch after a merge is James's own choice in the merge UI.
- **CP-7 Release.** James merges the plugin PR, and the executor then tags and pushes `aew--v0.1.0`.

## Scope

- **In:**
  - V-list verification;
  - the real install and the isolated dependency proof;
  - the sandbox app and repo, and the empty `aew-sandbox-retro` repo;
  - the two launchers and the rails (outside the repo);
  - init and S1 to S8 against real GitHub;
  - S9 only if Docker is up and CP-5 agrees;
  - every plugin fix the runs expose, with tests;
  - `tests/e2e-validation.md`;
  - the retro transfer to the plugin repo and the triage;
  - the README, CHANGELOG, DESIGN, CLAUDE.md and project-map updates;
  - the 0.1.0 tag.
- **Out:**
  - aew or the executor merging or retargeting PRs (DESIGN §1 non-goals; James does both in the GitHub UI);
  - widening the PAT beyond the sandbox repos (that would change CTO condition C3, which is not the executor's call);
  - CI or GitHub Actions;
  - new features not needed to make a scenario pass;
  - a LICENSE or an icon (an open item from prompt 04, which DESIGN doesn't call for; listed as a known limitation);
  - committing the launchers, streams or transcripts;
  - fixing prompt 06's known gap (a sequential child blocked by a failed `git-branch.sh create` resumes from no branch), unless S6 hits it;
  - a GitHub release object (only the tag is asked for).

## Context manifest

**Reference files** (downstream agents read these first):

- `docs/build-prompts/07-e2e-validation.md`: steps, scenarios and ACs.
- `docs/DESIGN.md` §3 (platform facts to re-verify; the dependency tag format), §4 (dependencies, prerequisites, why superpowers has no version range), §6 and §6.1 (project files and config, for the README), §7.4 (labels), §9 (preflight, gates, the unanswered gate, every run ends in a PR), §10 (milestone rules and stacking), §11 (the guard list, so a false-positive fix keeps every protection) and §12 (the quality bar).
- `tests/agent-smoke/README.md` §9 (rails 1 to 9, the §9.1 ledger rules, the §9.2 launcher reference copy, the kill-stage trigger, the post-session audit) and §10 (the milestone harness, the §10.6 roll-up format, and §10.7's prompt-07 carry-overs). This is the pattern for `e2e-run.sh` and for the record format of `tests/e2e-validation.md`.
- `docs/superpowers/project-map.md` `## Project knowledge`: the headless pre-check rules (H1 to H8, M1, M2), the CTO conditions C2 and C3, and the open items carried to prompt 07.
- `README.md` (Install, Dependencies, Commands done; Config reference, Labels and Uninstall still "to be written"), `CHANGELOG.md` (`[Unreleased]` only, never released), `.claude-plugin/plugin.json` (version `0.1.0`, untagged) and `.claude-plugin/marketplace.json` (`jamesborg-plugins`, source `./`, cross-marketplace allow).
- `scripts/hooks/guard-bash.sh`, `guard-edit.sh` and `tests/scripts/fixtures/hooks/bash-cases.tsv`: where a guard false positive is fixed and pinned.
- `skills/github-ops/SKILL.md:75`: the real-issue-body limitation that AC-20 removes.
- `skills/init/SKILL.md` (507 lines, over the 500-line guidance) and `skills/ship/references/*.md`: likely fix sites.
- `docs/superpowers/specs/2026-10-26-milestone-mode.md`: the format analog.

**Key facts learned from the codebase and machine (2026-10-26):**

- Claude Code is 2.1.308, Node 26.12.1 and gh 2.103.
- superpowers 7.0.0, context7 and frontend-design (`58267944f921`), dev-workflow, figma and warp are all installed and enabled at user scope. `claude-plugins-official` is already a configured marketplace. `jamesborg-plugins` is **not** added yet. The `jamesborg` marketplace is the separate dev-workflow repo, so the names don't clash.
- The git remote is `jamesborg2012/claude-agentic-engineer-workflow`. It has no tags. `aew-sandbox` doesn't exist. No retro issues are open.
- Docker is installed at `/usr/local/bin/docker`, but its daemon is not running.
- No ancestor `CLAUDE.md` exists above the sibling sandbox path.
- The prompt-05 and prompt-06 `$SMOKE` launchers were deleted, so the launcher is rebuilt from the README reference copy.
- The C3 condition requires a PAT scoped to the sandbox only. Retro items are therefore filed in a sandbox retro repo, then transferred to the plugin repo at step 6 (Assumption 4).
- The plugin's own Bash guard (and dev-workflow's) blocks commands whose text contains `git push`. Launches and harness steps therefore go in script files run with `/bin/bash`. `git-branch.sh push` is not affected.
- A killed `-p` session emits no `result` event, so its cost is charged at the cap. `--max-budget-usd` includes subagent spend, and the model budgets against its own cap, so each cap must cover the whole scenario (§10.7).

## Platform facts to verify at execution (claude-code-guide; do not assert from memory)

- **V-1** The exact syntax of `claude plugin marketplace add <local path>` and `claude plugin install <plugin>@<marketplace> --scope user`, and the valid scope values.
- **V-2**
  - Do a plugin's `dependencies` auto-install from another marketplace on `install`, given `allowCrossMarketplaceDependenciesOn`?
  - How is that proven from a clean state? Is `CLAUDE_CONFIG_DIR` (or an equivalent) supported for an isolated install, and does it need authentication?
- **V-3**
  - How is a plugin from a local-directory marketplace cached (the `installPath` form)?
  - How are committed changes picked up: `marketplace update`, then `plugin update`? Does an unchanged `version` block the update, and does reinstalling change `installPath`? Init's `.claude/settings.local.json` names the scripts by that path.
- **V-4** Is the git tag format for dependency version resolution still `<plugin>--v<version>`, and which repo is it read from (the marketplace repo or the plugin's source)?
- **V-5** `claude --bare`:
  - what does it disable (plugins, hooks, skills, MCP, `CLAUDE.md`, auto-memory)?
  - does it work with James's login, or does it need an API key?
  - does it combine with `-p`?

  The fallback is a profile with every plugin disabled.
- **V-6** How is a plugin MCP server shown as connected: the `system/init` `mcp_servers[].status`, or `claude mcp list` including plugin servers?
- **V-7** Where does a `SessionStart` hook's `additionalContext` show up in a headless stream (hook events with `--include-hook-events` or an equivalent, or only the debug log)?
- **V-8**
  - Does `--max-budget-usd` apply to interactive sessions?
  - How is an interactive session's cost read: `/cost`, or the transcript's usage?
  - If the cap doesn't apply interactively, the fallback is CP-1's: James checks `/cost` at each gate and stops the session once it reaches its cap.
- **V-9** Does `claude -p` exit on SIGINT the way Ctrl-C ends an interactive turn? Is in-flight subagent work cancelled, and is state left as written?
- **V-10** (GitHub/gh)
  - `GH_TOKEN` takes precedence over the keychain token;
  - `gh auth git-credential` serves `GH_TOKEN` for HTTPS pushes with an empty `GH_CONFIG_DIR`;
  - which fine-grained PAT permissions do the plugin's scripts need (contents, issues, pull requests, metadata)? Confirm that the permissions are set per token and apply to every selected repository, not per repository, which is why the plugin repo stays unselected;
  - `gh issue transfer`: which permissions it needs on both repos, and whether it keeps labels (a label missing in the target is expected to be dropped), the milestone and the comments.
- **V-11** (gh) Is there a `gh` command for milestones, or is it `gh api repos/{owner}/{repo}/milestones`? Does `gh repo create --private --source --push` work for an existing local repo?
- **V-12** The uninstall commands: `claude plugin uninstall`, removing a marketplace, and whether removal cleans the cache. These are for the README.
- **V-13** Does a project's `.claude/settings.local.json` `enabledPlugins: {"<id>": false}` override a user-scope enable?

## Conflicts between the prompt and DESIGN.md (DESIGN wins; each goes in the final report)

- **None that changes behaviour.** The prompt's tag example `aew--v0.1.0` matches DESIGN §3's `<plugin>--v<version>`. Its expectations match DESIGN §9 and §10.
- **Prompt note.** "Bump the version if anything changed." `plugin.json` is already `0.1.0` and has never been tagged or released, so the first release is 0.1.0 (Assumption 10).
- **Carried condition, not a conflict: C3 kept; retro items are transferred.** CTO condition C3 (a PAT scoped to the sandbox only) meets the prompt's retro triage, which expects issues in the plugin repo. The runs file into the sandbox repo `aew-sandbox-retro`, and the executor transfers the items to the plugin repo under its own keychain token at step 6 (AC-29). The PAT is never widened.

## Assumptions

1. **Assumed:** this spec plans the protocol, not the fixes. Each fix is a separate conventional commit on `feature/e2e-validation`, through AC-28. Reason: fixes can't be known before the runs.
2. **Assumed:** the drive mode per scenario is the one in the CP-1 table. Attended interactive sessions are used only where a question must be answered (init, S1, S3, S5, S6). Everything else runs headless through the rebuilt launcher (S2, S4, S7, S8), which is cheaper of James's time and reproducible. Reason: AskUserQuestion is absent headless (DESIGN §3), and headless runs are the proven harness. **Flag if wrong.**
3. **Assumed:** dependency auto-install is proven in an isolated, throwaway Claude config, not by uninstalling James's user-scope superpowers, context7 and frontend-design (which other plugins and sessions use). Reason: it is the same proof and touches nothing of his. **Flag if wrong**, if a real uninstall-and-reinstall at user scope is wanted.
4. **Decided at spec review (keeps C3):** the PAT selects only the sandbox repos (`aew-sandbox`, `aew-sandbox-retro`, and `aew-sandbox-woo` for S9).
   - `retro.repo` is `jamesborg2012/aew-sandbox-retro`, which still exercises `gh-retro.sh`'s cross-repo `--repo` path and its "Seen again" de-duplication on real GitHub.
   - At step 6 the executor transfers the items to the plugin repo under its own keychain token (AC-29).
   - Reason: a fine-grained PAT's permissions apply to every selected repo. Adding the plugin repo would hand agents contents and pull-request write on it, and widening the PAT would change a CTO condition, which is not the executor's call.
5. **Assumed:** at init, James accepts the Playwright offer. Reason: the prompt says "No Playwright yet" for the sandbox, which reads as "let init or `ui-qa` set it up", and S2 needs committed specs. **Flag if wrong**, if `ui-qa`'s own setup during S2's QA should do the install instead.
6. **Assumed:** dev-workflow, figma and warp are disabled for the sandbox only (AC-8). Reason: dev-workflow's own guard and session skill would otherwise act in aew's runs and blur the guard false-positive AC. James's normal use may have them on, so the README's troubleshooting notes the interaction. **Flag if wrong.**
7. **Assumed:** the launchers, the token file, the ledger and the streams live in `/Users/jamesborg/Documents/Development/aew-e2e` (a sibling, not a repo), not in `$TMPDIR`. Reason: this prompt spans days, and `$TMPDIR` may be cleared. Nothing there is ever committed, and the ledger is copied into `tests/e2e-validation.md` after each session. This is minor.
8. **Assumed:** S7 "Ctrl-C" is reproduced by the launcher sending SIGINT to a headless `--auto` run at `develop` (the F1/R2 precedent), and status, the hint and resume are proven headless. Reason: it is deterministic, it needs no plan gate, and it leaves the same state as an interactive Ctrl-C. **Flag if wrong**, if James wants to press Ctrl-C himself in an attended run.
9. **Assumed:** S8's plugin-less session runs headless with `prompt.md` as its prompt (the equivalent of pasting), in a separate local worktree beside the sandbox (`aew-sandbox-s8`). It has no `GH_TOKEN` and no `git push` or `gh` in its allowlist, and it is never pushed. Its local branch and worktree are removed afterwards, which is a local cleanup, not a GitHub deletion. Reason: it keeps `main` clean for the next scenario and costs none of James's time. **Flag if wrong.**
10. **Assumed:** `plugin.json` stays `0.1.0`. The fixes land inside the unreleased 0.1.0, because nothing was released before it, and the CHANGELOG's `[Unreleased]` becomes `[0.1.0]`. Reason: "bump if anything changed" refers to an already-released version. A fixed version through the validation also keeps the cached `installPath` stable for init's settings (V-3). **Flag if wrong.**
11. **Assumed:** the spend envelope is $151.50 of caps plus a $48.50 reserve, with a **stop of $200** and S9 extra only if $25 remains (CP-1). Reason: the scaled prompt-05 and prompt-06 measurements. **Flag if wrong** (the budget is James's call).
12. **Assumed:** each ship-style scenario waits for its predecessor's merge, and only S8 (and S9) run in parallel with a pending merge. Reason: every PR curates `CLAUDE.md`, and aew never rebases.
13. **Assumed:** the scenario issues are created up front (AC-13). S3's body is deliberately ambiguous, and any fixture tuning (the §9.5 and §10.7 precedent) is recorded beside the body, never hidden.

## Risks

1. **Spend overrun.** Real apps and real installs cost more than the fixtures. The mitigations are the ledger with a stop, caps per session, and asking before the reserve is exceeded. A model may stop itself near its cap (§10.7), so the caps are set to cover a whole scenario.
2. **Stale install.** A fix committed but not picked up by the cached install would make a re-run test old code. The mitigation is AC-28 step 6, which proves the installed copy matches before every re-run (V-3).
3. **Token exposure.** `GH_TOKEN` is visible to the Bash tool, and so to agents. The mitigations are the PAT scope (AC-9: sandbox repos only, never the plugin repo), the guard's agent `gh` deny, and the audit for commands that echo the environment. Nothing that prints the token is ever recorded.
4. **Gates under `--auto`.** S2, S4 or S7 may hit a material spec gate headless and stop pending. The fallback is an attended `/aew:resume` (CP-4), with the fixture tuning recorded.
5. **Stacked-PR merges.** `Closes #n` fires only on a merge into `main`, and GitHub retargets a stacked PR only when its merged base branch is deleted. A child merged into a non-default base would leave its issue open, and a squash of child 1 would put child 1's commits back into child 2's retargeted diff. The mitigation is AC-22's protocol: a merge commit for children 1 and 2, a base check (`main`) before each later merge, James retargeting in the UI if needed, and a final check that the issues are closed and `main` holds all three changes. aew doesn't automate any of it (DESIGN §10).
6. **Attended time.** Five attended sessions need James's presence for the gate moments only. Each run then continues unattended in his terminal.
7. **Plugin interplay.** User-scope plugins and the claude.ai and Notion connectors load in every session. The mitigations are AC-8 and the MCP denies in every headless allowlist.
8. **`--bare` and authentication.** If `--bare` refuses James's login, S8 uses the plugin-less profile fallback (V-5). Either way it is recorded.
9. **Init line cap.** Init is at 507 lines, already over the 500-line guidance (the project map's "498" predates prompt 05b). Any init fix must first move content into references (AC-28).

## Open questions for human

(none: every fork was resolved from project context or the prompt. The flagged assumptions above, chiefly 2, 3, 5, 8, 10 and 11, are what to check at plan approval. Assumption 4 was decided at spec review. The execution-time checkpoints CP-1 to CP-7 are the gates the prompt mandates, not open questions.)

## Approval

- Senior architect: APPROVED on 2026-10-26T15:04:36Z (spec-review, round 2)
- Complexity: NOVEL
- Scale: EPIC
- Reason: first run against real GitHub, with real credentials, a real install and a published tag, over several sessions and with no earlier analogue (NOVEL); about 18 tasks crossing two risk lines, credentials/infra and the release tag (EPIC).
- Spec content hash (SHA-256): b3456e41a8e2af74eaaed0ff4d2fe34ba0e3c3c5d3ead22a41e09dd30069fe5a (the file before this Approval section was appended)

<spec-summary>
- Topic: e2e-validation
- Issue: no issue (build prompt 07, `docs/build-prompts/07-e2e-validation.md`)
- Problem: aew has only ever run against a mocked `gh` and fixtures. Prove it on real GitHub with a real install, fix what breaks, triage the retro items and release 0.1.0.
- ACs (testable): AC-1 to AC-35 above. Key ones:
  1. V-list facts verified against the docs and recorded (AC-1)
  2. User-scope install; dependency pull-in proven in an isolated config; skills, agents and Playwright MCP visible (AC-2 to AC-5)
  3. Sandbox app, plus aew-sandbox-retro; a sandbox-only PAT (C3) with a canary covering gh and git (AC-6 to AC-10)
  4. init attended, PR merged by James, `main` fast-forwarded after every merge (AC-11, AC-12)
  5. S1 to S8 pass their [P] expectations plus CR-1 to CR-9; every PR introduction checked by the script and judged for accuracy (AC-13 to AC-24)
  6. S9 passes or is recorded as skipped with its reason (AC-25)
  7. tests/e2e-validation.md complete; no unresolved guard false positive; fix-loop protocol (AC-26 to AC-28)
  8. Retro items transferred to the plugin repo and triaged; README, CHANGELOG [0.1.0], tag aew--v0.1.0 after James's merge (AC-29 to AC-35)
- Scope in: V-list, install, sandbox and retro repos, launchers and rails, init, S1 to S8 (S9 optional), plugin fixes with tests, the record, retro triage, docs, the tag
- Scope out: merging or retargeting PRs by aew or the executor, CI, new features, LICENSE and icon, committing launchers or streams, a GitHub release object
- Context manifest (key references):
  - docs/DESIGN.md §3, §4, §6, §7.4, §9 to §12: source of truth
  - tests/agent-smoke/README.md §9 and §10: launcher reference copy, ledger and record format
  - docs/superpowers/project-map.md: H1 to H8, M1, M2, C2, C3, carried items
  - scripts/hooks/guard-*.sh plus tests/scripts/fixtures/hooks/*-cases.tsv: where guard false positives are fixed
  - skills/github-ops/SKILL.md:75: the limitation AC-20 removes
  - skills/init/SKILL.md (507 lines, over the 500-line guidance)
- Assumptions (high-stakes, flag if wrong):
  - 4: PAT selects sandbox repos only; retro items go to aew-sandbox-retro and are transferred at step 6 (keeps C3)
  - 10: plugin.json stays 0.1.0 (never released)
  - 11: spend stop $200 (caps $151.50, reserve $48.50)
- Complexity: NOVEL
- Scale: EPIC
- Spec content hash: b3456e41a8e2af74eaaed0ff4d2fe34ba0e3c3c5d3ead22a41e09dd30069fe5a
</spec-summary>

<epic-decomposition>
- phase: A
  title: Platform checks, real install, sandbox repos and rails
  scope: V-list, user-scope install plus isolated dependency proof, README install, aew-sandbox app and aew-sandbox-retro, AC-8 settings, PAT, launchers, canary
  acs: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  depends_on: []
  depth: full
  risk: credentials/infra
- phase: B
  title: init, fixtures and the serialised single-issue scenarios S1 to S4
  scope: attended init and merge, issue and milestone fixtures, S1 to S4 each merged before the next, removal of the real-issue-body limitation
  acs: [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  depends_on: [A]
  depth: full
  risk: real issue-body rewrites
- phase: C
  title: Milestones and interrupt (S5 to S7)
  scope: bulk milestone, sequential chain with the stacked merge protocol, SIGINT at develop then status, hint and resume
  acs: [21, 22, 23]
  depends_on: [B]
  depth: lean
  risk: none
- phase: D
  title: Prompt mode and plugin-less build (S8)
  scope: headless /aew:prompt, then a plugin-less session in aew-sandbox-s8 with no GH_TOKEN
  acs: [24]
  depends_on: [B]
  depth: lean
  risk: none
- phase: E
  title: Optional WooCommerce sandbox (S9)
  scope: run only if Docker is up and CP-5 agrees; second sandbox, init stack detection, one small ship
  acs: [25]
  depends_on: [A]
  depth: lean
  risk: none
- phase: F
  title: Retro triage and the 0.1.0 release
  scope: transfer and triage retro items, final README, CHANGELOG [0.1.0], DESIGN, CLAUDE.md and project map, verification, plugin PR, tag after James's merge
  acs: [29, 30, 31, 32, 33, 34, 35]
  depends_on: [C, D, E]
  depth: full
  risk: release tag
</epic-decomposition>

(ACs 14, 15 and 26 to 28 apply across phases B to E. D needs only the init merge from B.)
