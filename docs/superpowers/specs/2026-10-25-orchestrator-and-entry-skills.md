# Brainstorm — Orchestrator and entry skills: init, ship, resume, status, prompt (build prompt 05)

- **Issue:** no issue — build prompt 05 (`docs/build-prompts/05-orchestrator.md`; DESIGN.md wins on conflict)
- **Date:** 2026-10-25

## Problem

Every piece of the pipeline now exists in isolation (scripts, hooks, seven agents, the run protocol), but nothing ties them together: no skill a user can type. Build prompt 05 adds the five user-invocable skills of DESIGN §5.1 (`init`, `ship`, `resume`, `status`, `prompt`; `ship-milestone` is prompt 06), with `ship` as the main-thread orchestrator that drives one issue through DESIGN §7.3 — dispatching agents with explicit file inputs, reading only their return blocks, running the gates and the review and QA loops, and owning every GitHub write through the plugin's scripts. It must be proven by simulated runs (mocked `gh` PATH shim, local fixture git repo with a local bare `origin`) recorded in `tests/agent-smoke/README.md`, and closes the two open items the prompt-04 CTO review left for prompt 05 (CTO-3a permissions, CTO-3b per-WP report check).

## Acceptance criteria

Every acceptance criterion from the prompt is kept and marked **[P]**. The rest turn the prompt's deliverables and DESIGN §4, §5.1, §7, §9 and §11 into testable criteria. "V-n" refers to the Claude Code facts table below (verified against code.claude.com/docs on 2026-10-25; V-7 still open).

**`skills/ship/` — structure and arguments**

1. **AC-1** `skills/ship/SKILL.md` has frontmatter `name: ship`, a `description`, `disable-model-invocation: true` and `argument-hint: <issue> [--auto] [--from <stage>]` (V-1); no `allowed-tools` (it only pre-approves the invoking turn; approvals come from AC-31's settings or the harness allowlist). `SKILL.md` is the procedure (numbered steps, one section per stage, each stage section headed so it can be entered directly by name), under 500 lines; the detail lives in `skills/ship/references/`: `preflight.md`, `dispatch.md`, `gates.md`, `routing.md`, `pr.md`, `final-report.md`, linked by `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/<file>` (absolute, not relative links or `${CLAUDE_SKILL_DIR}`, because `resume` and `prompt` read these files from another skill, V-5). `SKILL.md` states the substituted plugin root once, so literal `${CLAUDE_PLUGIN_ROOT}` paths inside the reference files (read with Read, so not substituted, V-5) resolve (Assumption 2). `SKILL.md` uses no `` !`cmd` `` injection and no positional `$N` placeholders: when `resume` reads it with Read nothing in it is substituted or run, so the procedure must work as plain text from the stage sections on.
2. **AC-2 [P]** `$ARGUMENTS` (V-1) is parsed as `<issue> [--auto] [--from <stage>]`, options in any order after the issue. Each of these stops **before any state, label, branch or `gh` write** with a one-line error plus the usage line:
   - no issue number; a non-integer, zero or negative issue;
   - `m-<n>` (points to `/aew:ship-milestone`, prompt 06);
   - an unknown option; a repeated option; an extra positional argument;
   - `--from` without a value; `--from` with an unknown stage (the message lists the ten stage names from `templates/state.schema.json`).
3. **AC-3** Preflight (`preflight.md`, DESIGN §9), in this order, each failure stopping with what is wrong and how to fix it, and writing nothing:
   1. `.aew/config.json` exists (else "run `/aew:init`");
   2. the working tree is clean (`git status --porcelain`; dirty paths are listed; the run dir is gitignored so it never counts);
   3. `gh auth status` succeeds (Assumption 9);
   4. the default branch is up to date with `origin` (`git fetch`; fast-forwarded when it is only behind; stop when it has diverged) (Assumption 10);
   5. no other active run: `.aew/runs/current` is empty, or names a run whose status is `done` or `failed`, or names this issue and the call is a `--from` or a resume (Assumption 11);
   6. **superpowers major version** (warn only, never blocks): `claude plugin list --json` → the `superpowers@claude-plugins-official` entry's `version`; if it is semver (`^[0-9]+\.`) and its major differs from the one aew is built against (7, recorded once in `preflight.md`), print a warning naming both; if it is not semver (a git source reports a 12-character commit SHA, V-6), warn that the version `<value>` is not a release number and could not be compared with 7.x; if the call fails or the entry is missing, warn that it could not be checked (Assumption 12, V-6).
4. **AC-4** Run start (fresh run, no `--from`): `state.sh init <n> --issues <n> --mode single [--auto]` (refused when `.aew/runs/<n>/` already exists: the message points to `/aew:resume <n>` or `--from`) → `gh-issue.sh fetch <n> <run_dir>` → `state.sh set title` from `issue.json` (a fetch failure or a closed issue stops with a message after `state.sh status failed --note <reason>` and `state.sh current clear`, so no dangling active run is left; re-shipping needs `--from spec_analysis`, which re-fetches) → `gh-labels.sh stage <n> analysing` → `git-branch.sh create <n> <slug>` (slug: lower-case kebab-case from the title) → `state.sh set branch`. Initialising state before the fetch is a recorded order deviation (Conflict C4).

**`ship` — dispatch, gates and routing**

5. **AC-5** `dispatch.md` has one row per agent and mode with the exact dispatch fields (the prompt-03/04 contracts in `docs/superpowers/project-map.md`, plus AC-34's `notes`), the required run-dir files the orchestrator checks with `test -f` before dispatching, and the state write that precedes the dispatch (`state.sh stage …` or `bump …`; the developer gate needs `state.json` written first). Dispatch prompts are `key: value` lines only, through the Agent tool with `subagent_type` `aew:<agent>` (V-3).
6. **AC-6** Return check (`dispatch.md`): the last four lines of the Agent result must be a valid return block (the `valid_return_block` rule of `scripts/hooks/gate-subagent.sh`; template placeholders do not count), and every ARTEFACTS path must exist. For the developer, **each** `06-dev-report.md` / `06-dev-report-WP<n>.md` named in ARTEFACTS is checked with `tail -n 4` for a valid block (CTO-3b: the gate hook alone can pass a sibling's report). An invalid return counts as `failed`: retry the same dispatch once, then `blocked` (state-machine.md Failure paths).
7. **AC-7 [P]** QA phase A and the senior engineer's plan are dispatched **in one assistant message with two Agent calls** (V-3), after `state.sh stage plan`. If one fails, only that one is retried.
8. **AC-8 [P]** **Material spec change gate** (`gates.md`, always on, even with `--auto`): on `needs_input` from spec-analyser, `state.sh status awaiting_input` and `gh-labels.sh stage <n> awaiting-input` first; then AskUserQuestion (main thread only: the tool is removed from every subagent, which is why agents return `needs_input` instead of asking, V-4) built from the `## Questions` section of `01-spec-analysis.md` only, each with the recommended answer as the first option and its label ending "(recommended)" (the docs define no recommended marker, V-4); batched over several calls if the tool's schema caps questions or options per call (the caps are undocumented, so the procedure follows the schema the model sees); then spec-analyser is re-dispatched with `answers: Q1: …` and `spec_version`. When spec analysis returns `ok` and `spec-changes.json` lists at least one change (non-material included), the revision is recorded in the `github-ops` order: render `spec-revision-v<N>.md` from `spec-changes.json` with `jq` (so the JSON never enters context), `gh-issue.sh revise <n> spec-final.md <N>`, `gh-issue.sh comment <n> spec-revision-v<N>.md`, `gh-labels.sh flag <n> add spec-revised`, `state.sh set spec_revision <N>`.
9. **AC-9 [P]** **Plan gate** (`gates.md`), unless `state.auto` or `gates.plan_approval: false`: `state.sh status awaiting_plan_approval`, label `awaiting-approval`, then a plan summary of **25 lines or fewer** plus the `05-plan.md` path, with options approve / request changes / stop. Approve → `develop`. Request changes → senior-engineer `mode: plan` with `notes: <James's notes>` (AC-34); QA phase A is not re-run; the gate is shown again. Stop → `state.sh status failed`, `state.sh current clear`, stop.
10. **AC-10** An unanswered gate (AskUserQuestion not in the tool list — as in every headless run, which the harness starts with `--permission-prompts none`, removing the tool, V-4 — or refused, or empty) leaves the gate pending; when the tool is absent ship does not try to call it: state and label are already set, so ship prints the questions (or the plan summary) and `Answer with /aew:resume <id>`, and stops. Nothing after the gate runs (Assumption 5).
11. **AC-11 [P]** Review loop (`routing.md`): `07-review-<review_cycle+1>.md`; the verdict is the first word of the return SUMMARY (the review template requires it). `approve` → `qa`. `changes_required` with `review_cycle < limits.max_review_cycles` → `state.sh bump review_cycle`, `state.sh stage develop`, developer `mode: fix`, `fix_from: 07-review-<n>.md`, `n`, then review again; at the limit → blocked path.
12. **AC-12** Developer `blocked` (plan step impossible) → senior-engineer `mode: plan` with `notes:` carrying the developer's reason → the plan gate again (unless auto) → `develop`. A second developer `blocked` in the same run → blocked path (Assumption 16).
13. **AC-13 [P]** QA loop (`routing.md`, the triage table and cycle limits), `stage` stays `qa`: qa-engineer `phase: B`, `n: fix_cycle+1`. `ok` → `docs`. `failed` that passes the `qa_failures_complete` test (state-machine.md, run inline) → read only the triage table at the top of `## Failures`; at `fix_cycle = limits.max_fix_cycles` → blocked path; otherwise `state.sh bump fix_cycle` and route one class per cycle in this order (Assumption 17):
    - `spec_ambiguity` → the spec-ambiguity gate (AskUserQuestion from the failure entries), the answer to spec-analyser `answers`, the revision recorded; a material change re-runs every stage from `brief`; a non-material one re-runs `brief`, then QA (Assumption 18);
    - `plan_divergence` or `test_bug`, or an `impl_bug` on a TC that already had one developer fix → senior-engineer `mode: triage`, `n`; its NEXT routes to developer `mode: fix` (`fix_from: 09-triage-<n>.md`) and/or qa-engineer phase B with `triage: 09-triage-<n>.md`; triage `needs_input` → the material spec change gate;
    - `impl_bug` → developer `mode: fix`, `fix_from: 08-qa-report-<n>.md`, `n`;
    then QA phase B again. Any other `failed` is an ordinary agent failure (retry once, then blocked).
14. **AC-14** A plan `needs_input` (a challenge implying a material spec change) goes through the material spec change gate with the questions from the plan's `## Challenges to the spec` section. Accepting the recommended answer → spec-analyser re-run with the answer, revision recorded, brief and QA phase A re-run, plan kept (the senior engineer already planned on its recommendation), plan gate. Any other answer → every stage from `spec_analysis` re-runs. Declining the change → senior-engineer re-plans on the current spec with `notes` (Assumption 19).
15. **AC-15 [P]** Blocked path (any stage): a report comment (stage, reason from the agent SUMMARY, cycles used against limits, the run-dir artefact names, "Resume with `/aew:resume <id>`") written to a temp file outside the run dir and posted with `gh-issue.sh comment`; `gh-labels.sh stage <n> blocked`; `state.sh status blocked --note <reason>`; `current` kept; ship stops cleanly (Assumption 20).
16. **AC-16 [P]** End of run (`pr.md`): after the standards stage, changed `docs/standards/` files are committed (`docs(standards): … (#n)`); after the docs stage, the doc-writer's outputs (`docs/specs/<issue>-<slug>.md`, `CLAUDE.md`) are committed by the orchestrator (`docs: … (#n)`; DESIGN §8.7 wins over the prompt, Conflict C1); `git-branch.sh push`; `gh-pr.sh create <id> pr-body.md` when `state.pr` is null (else `gh-pr.sh update <pr> pr-body.md --run <id>`), then `state.sh set pr`; if `manual-tests.md` has items, `gh-issue.sh manual-tests <n> manual-tests.md` and `gh-labels.sh flag <n> add manual-test-required`; `gh-retro.sh file retro.md <owner/repo> <id>` (owner/repo from `issue.json` `url`; a retro failure warns, never blocks); `gh-labels.sh stage <n> ready-for-review`; `state.sh status done`; `state.sh current clear`.
17. **AC-17 [P]** Final report (`final-report.md`, DESIGN §9): outcome; PR link; ACs passed out of the total (counted with `grep -c` on the `10-summary.md` AC checklist, not read); review and fix cycles used against their limits; manual tests outstanding (count of `manual-tests.md` items); retro items filed (the `gh-retro.sh` output lines). Blocked and failed outcomes use the same report with the reason and resume hint in place of the PR link.
18. **AC-18** `--from <stage>`: needs an existing `.aew/runs/<n>/` (except `spec_analysis`, which may also start fresh); preflight's active-run check treats it as resuming this run; the tree must be clean and the run's branch is switched to if needed; the stage's required inputs (AC-5) must exist, else stop naming the missing ones; then `state.sh current set <n>`, `state.sh stage <stage> --note "--from"`, `state.sh set auto true` when `--auto` is given, and the procedure continues at that stage. Earlier stages are not redone; `qa_test_plan` and `plan` both mean the parallel planning step; counters are kept; `spec_analysis` re-fetches the issue (Assumption 13).
19. **AC-19** Context hygiene (`SKILL.md` has a "What the orchestrator reads" table): full file reads only of `05-plan.md` (plan gate). Bounded section reads: `## Questions` of `01-spec-analysis.md` (spec gate), `## Challenges to the spec` of `05-plan.md` (plan `needs_input`), the triage table of `08-qa-report-<n>.md` and the failure entries it names (routing; `spec_ambiguity` gate). Everything else is the Agent return block, `tail -n 4`, `test -f`, `grep -c` or a `jq` render to a file. DESIGN §9 ("artefacts only for gates and routing") wins over the prompt's narrower list (Conflict C2).
20. **AC-20 [P]** Stage coverage: `routing.md` has one row per DESIGN §7.3 stage (`spec_analysis`, `brief`, `standards`, `qa_test_plan`, `plan`, `develop`, `review`, `qa`, `docs`, `pr`) with non-empty **Entry** (state write, label, dispatch), **Exit** (next stage on `ok`) and **Failure** (where `failed`, `blocked`, `needs_input` and limit breaches go) columns.

**`skills/resume/`, `skills/status/`, `skills/prompt/`**

21. **AC-21 [P]** `resume [<run-id>]` (`disable-model-invocation: true`, DESIGN §5.1 side-effect rule): the id defaults to `.aew/runs/current`; reads `state.json`; refuses another run that is active; verifies the branch (switches to the run branch when the tree is clean; otherwise stops) and a clean tree, or lists what is dirty and stops; `done` → nothing to do (prints the PR); `failed` → terminal, suggests `/aew:ship <n> --from <stage>`; `awaiting_input` / `awaiting_plan_approval` → re-asks that pending gate (re-reading only what the gate reads); `running` / `blocked` → `state.sh current set`, then follows `ship`'s procedure from the recorded stage section, re-dispatching that stage. It reuses ship's procedure by reference and never duplicates it, and never re-runs a stage before the recorded one. **How it reuses it (V-1, V-5):** `ship` has `disable-model-invocation: true`, which also blocks the Skill tool, so `resume` must not invoke `ship` through the Skill tool. `resume`'s own `SKILL.md` (which is substituted) states the plugin root and says: Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names with the Read tool, read every literal `${CLAUDE_PLUGIN_ROOT}` in them as that root, skip ship's argument-parsing, preflight and run-start steps (the issue, auto flag and counters come from `state.json`), and enter at the section for the recorded stage. `ship-milestone` (prompt 06) reuses ship the same way (DESIGN §10).
22. **AC-22 [P]** `status [<run-id>]` is read-only (no `state.sh` writes, no `gh`, no git writes; reads `state.json` with `jq` because `state.sh get` only reads the current run). Without an argument it lists every run under `.aew/runs/` (id, title, stage, status, updated, which is current). With one it shows the state fields, the last 10 lines of `log.md`, `review_cycle`/`max_review_cycles` and `fix_cycle`/`max_fix_cycles` (config defaults from the schema), and the next action per status (table in the skill). No `disable-model-invocation` (no side effects, DESIGN §5.1).
23. **AC-23 [P]** `prompt <issue>` (`disable-model-invocation: true`): preflight items 1, 3 and 5 (no clean-tree or branch need: nothing is committed); `state.sh init` (mode `single`), fetch, spec-analyser with the **same** gate and recording (`${CLAUDE_PLUGIN_ROOT}/skills/ship/references/gates.md`, read with Read as in AC-21, never through the Skill tool), then brief-compiler `mode: prompt`; status `done`, `current` cleared; prints the `prompt.md` path and offers to post it with AskUserQuestion → `gh-issue.sh comment <n> prompt.md` (`prompt.md` has no return block); an unanswered offer is not posted. No branch, no stage labels; the `spec-revised` flag is set when a revision is recorded (Assumption 21).

**`skills/init/`**

24. **AC-24** Frontmatter `disable-model-invocation: true`. Prerequisites: git, `gh auth status`, jq, Node ≥ 20 (missing or too old: stop with install hints), and per detected profile the stack tools (nextjs/react/tailwind → npm or the lock file's manager; laravel → php, composer; wordpress/woocommerce → php, composer, and Docker when wp-env or ddev config exists; dotnet → dotnet), which only warn. It never installs a global tool. A dirty tree stops init (Assumption 22).
25. **AC-25** Branch `chore/aew-init`: created from the default branch, or switched to if it already exists.
26. **AC-26** Detection and discovery: `detect-stack.sh` (`evidence` dropped before writing `stacks`); commands from `package.json` scripts (with the package manager from the lock file), `composer.json` scripts, `artisan`, `.wp-env.json`, `.ddev/config.yaml` and `*.csproj`; `app` values from the env type (wp-env, ddev, local, docker, native, none); `default_branch` from `origin/HEAD`; `project` from the manifest name or directory. Values found in the repo are proposed as certain; inferred ones (for example `typecheck` from a `tsconfig.json`, `app.base_url`, `retro.repo`) are confirmed in **one** AskUserQuestion round with recommended answers. With no answer (headless) the recommended values are used and listed in the report (Assumption 23).
27. **AC-27** `.aew/config.json` is written with stable formatting (`jq` key order) and validated with the CLAUDE.md `ajv` command against `${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json`; an invalid config stops init before any commit. On a re-run, existing values win; only missing fields are added; nothing is removed or duplicated (Assumption 24).
28. **AC-28** `gh-labels.sh ensure`; `.gitignore` gets `.aew/runs/` and `.playwright-mcp/` once each (DESIGN §3 says target projects ignore the latter) (Assumption 25).
29. **AC-29** UI project (a detected UI profile, or a `pages`/`app`/`resources/views`/theme directory) without `@playwright/test`: offer the `ui-qa` setup and ask before installing anything; no answer → skipped and reported.
30. **AC-30** `CLAUDE.md` gets one short `## Agentic workflow` section (created if absent, never duplicated: heading check) pointing at `docs/standards/` and `docs/specs/` and the `/aew:` commands.
31. **AC-31** Permissions proposal: a project `.claude/settings.json` `permissions` block for this workflow (git, the plugin scripts, the project's package manager and test commands from config) is **shown and asked** before writing; merged into an existing file without duplicates; no answer → not written. It folds in CTO-3a: no broad `Bash(git -C *…)`, `Bash(sh -c *)`, `Bash(cp *)`, `Bash(npx *)` or `Bash(cd *)` allows (harness-only), and deny rules for git's `-c`, `--config-env`, `--exec-path`, `--git-dir` and `--output` forms (rule semantics V-7) (Assumption 26).
32. **AC-32** Standards: standards-setter is dispatched with `mode: init` (AC-35). Then, only if anything changed: `git add` of exactly the files init touched, one conventional commit with no issue ref (`chore: set up aew`), `git-branch.sh push`, and `gh-pr.sh open chore/aew-init <title> <body-file>` (AC-36). If nothing changed: no commit, push or PR; a branch init created in this run with no commits is deleted after switching back.
33. **AC-33 [P]** Idempotent: a second run on the same repo changes nothing — no file diff, no new commit on either branch, no `pr create` call (label `ensure` calls are idempotent on GitHub's side and are expected).

**Agent and script changes (smallest additions the skills need)**

34. **AC-34** `agents/senior-engineer.md` plan mode gains an optional `notes` dispatch field (James's change requests from the plan gate, or a developer's blocked reason): the revised plan must address each note and say how in `## Approach`.
35. **AC-35** `agents/standards-setter.md` gains `mode: init` (no `run_dir`, no brief): detect, reuse or write `docs/standards/<profile>.md` and `README.md` as usual, skip `03-standards.md` and the brief-driven "Sections that apply"; the return block goes only in the final message. DESIGN §8.3 records it (Conflict C3).
36. **AC-36** `scripts/gh-pr.sh` gains `open <branch> <title> <body-file> [--base <branch>]` for run-less PRs (init): if an open PR exists for the head branch it prints that number without creating one; otherwise it creates the PR and prints its number. Bats tests with the mocked `gh` (create, reuse, invalid input before any gh call), `--help` updated, `github-ops` lists it, `tests/run-script-tests.sh` passes (Assumption 27).

**README**

37. **AC-37 [P]** `README.md` `## Commands` replaces "_To be written._" with a reference for `/aew:init`, `/aew:ship <issue> [--auto] [--from <stage>]`, `/aew:resume [<run-id>]`, `/aew:status [<run-id>]` and `/aew:prompt <issue>` (syntax, what it does, which gates ask, one example each; `ship-milestone` listed as coming in a later release), plus a Mermaid `flowchart` of the pipeline: the stages, the parallel QA-plan/plan step, both gates, the review and QA loops with their limits, and the blocked exit.

**Static checks**

38. **AC-38 [P]** `tests/scripts/skills.bats` (picked up by `tests/run-script-tests.sh`) checks: every `${CLAUDE_PLUGIN_ROOT}/…` path and every `aew:<name>` mentioned in `skills/{init,ship,resume,status,prompt}/**` exists as a file, agent or skill; `disable-model-invocation: true` on init, ship, resume and prompt and absent on status; `routing.md` has a row for each of the ten schema stages with non-empty Entry, Exit and Failure cells; each AC-2 error case has its message in `ship/SKILL.md`. `claude plugin validate .` passes.

**Simulated runs (headless, mocked `gh`, local fixture repos)**

39. **AC-39** `tests/agent-smoke/README.md` gains a section 9 (orchestrator) with: a `smoke_ship_project` helper (fixture copy outside the repo under `$SMOKE`, `git init -b main`, a local bare repo as `origin`, the `gh` shim first on `PATH` with `GH_MOCK_DIR`, `GH_TOKEN`, `GITHUB_TOKEN`, `GH_ENTERPRISE_TOKEN` and `GITHUB_ENTERPRISE_TOKEN` unset (an env token would authenticate a real `gh` regardless of `GH_CONFIG_DIR`), the issue seeded in the mock's stateful `issues/<n>/` store, canned replies for `pr create`, `issue comment`, `issue list` and `issue create`, the fixture config's `retro.repo` overridden to a fake `acme/aew-retro`, and `GH_CONFIG_DIR` pointed at an empty directory so a real `gh` reached by mistake is unauthenticated); a mandatory probe run first (P0, `/aew:status` on the seeded project, cap $1) proving, from the session's own Bash and the `system/init` event: `command -v gh` resolves to the shim, the four token variables are empty, `git remote get-url origin` is the local bare repo, `AskUserQuestion` is absent from the tools list (V-4), the `aew:<agent>` names (`aew:qa-engineer`, `aew:senior-engineer`, `aew:developer` …) are listed as agents (V-3), and a `/aew:<skill>` invokes in `-p` (V-2); any P0 failure stops every paid run until fixed and re-probed; the invocation (`claude --plugin-dir "$REPO" -p "/aew:ship …"` with the section-3 flags, which already include `--permission-mode acceptEdits` because `-p` defaults to Manual mode since v2.1.302 (V-2), plus `--permission-prompts none` so nothing can hang on a prompt and AskUserQuestion is deterministically absent, and one explicit allowlist: the union of the agents' `ALLOW` lines plus the orchestrator's scripts, git and `jq` commands, exactly `Bash(gh auth status)` and `Bash(claude plugin list --json)`, and no other `gh` rule — no `bypassPermissions`); and a spend ledger (Assumption 7).
40. **AC-40 [P]** **S1** `/aew:ship 201 --auto` on the static-shop fixture (Assumption 6) completes every stage through PR creation (mocked): `state.json` validates against the schema with `status: done`; `.aew/runs/current` is cleared; the branch is on the bare `origin`; the mock's issue labels end with `aew:ready-for-review` (plus `aew:manual-test-required`, and `aew:spec-revised` if a revision was recorded); the recorded `gh` call routes match the expected sequence written in the README before the run (fetch, stage labels, revision calls if any, `pr create`, manual-tests body edit, retro search/create, final label), and no call targets anything but the mock. The stream shows the QA phase A and plan dispatches as two `Agent` tool_use blocks, `aew:qa-engineer` and `aew:senior-engineer`, under one `message.id` (AC-7, V-3; the same evidence form as run 961). Concurrent execution is not documented for one-message dispatch, so overlap of the two calls is recorded, not required.
41. **AC-41 [P]** **G1** `/aew:ship 103 --auto` with the material fixture on the nextjs-tailwind repo stops at the spec gate: `stage: spec_analysis`, `status: awaiting_input`, label `aew:awaiting-input`, no `02-brief.md`, the questions printed with recommended answers.
42. **AC-42 [P]** **G2** `/aew:ship 201` (no `--auto`) on a fresh static-shop project stops at the plan gate: `status: awaiting_plan_approval`, label `aew:awaiting-approval`, a summary of 25 lines or fewer plus the plan path printed, no `06-dev-report*.md`. **R1** `/aew:resume 201` on that project re-asks the plan gate and stops again, with `log.md` showing no stage re-entered.
43. **AC-43 [P]** **Resume**: on G2's project, **F1** `/aew:ship 201 --auto --from develop` is killed by the harness as soon as `state.json` reads `stage: develop` (Assumption 8); **R2** `/aew:resume 201` continues from `develop` and reaches `done`. Evidence: `log.md` has no `spec_analysis`, `brief`, `standards` or `plan` entry after the kill; `01-…05-` artefacts are byte-identical (sha) before and after; the mock shows one issue fetch in total; the final state validates with `status: done`.
44. **AC-44 [P]** **I1/I2** `/aew:init` on the nextjs-tailwind fixture produces a `.aew/config.json` that validates (`ajv`), the labels, `.gitignore` lines, the CLAUDE.md section, the standards docs, one commit on `chore/aew-init`, a push and one `pr create`; a second run changes nothing (AC-33 evidence: `git status --porcelain` empty, both branch heads unchanged, config sha unchanged, no second `pr create`).
45. **AC-45** Bad-argument probes (`/aew:ship`, `/aew:ship abc`, `/aew:ship 201 --bogus`, `/aew:ship 201 --from nowhere`) print the AC-2 messages and leave no run dir, no state and no `gh` call.
46. **AC-46 [P]** Results go in `tests/agent-smoke/README.md` (setup, invocation, check commands, a check | result | notes table, the ledger; no transcripts). After every run `git -C "$REPO" status --porcelain` shows only intended files. A failing check is fixed in the skill (or agent) and re-run; checks are never weakened.

**Closing**

47. **AC-47** DESIGN.md is updated in the same commit with the verified facts (§3, from V-1…V-7: `disable-model-invocation` also blocks the Skill tool; `${CLAUDE_SKILL_DIR}` is documented as substituted; reference files read with Read are not substituted; AskUserQuestion is main-thread only and is removed by `--permission-prompts none`; `-p` defaults to Manual mode; plugin versions may be commit SHAs) and the decisions below (§4 superpowers check, §8.3 init mode, §8.4 `notes`, §9 preflight detail, order, reads table and the unanswered-gate rule); `skills/run-protocol/references/state-machine.md` is updated where routing refines an arrow (AC-12, AC-13 `spec_ambiguity`, AC-14); `CHANGELOG.md`, `docs/superpowers/project-map.md` and CLAUDE.md "Recent changes" are updated. The final report lists checks, files, deviations from DESIGN and decisions needed; conventional commits.

## Scope

- **In:**
  - `skills/init/SKILL.md`, `skills/ship/SKILL.md` + the six references, `skills/resume/SKILL.md`, `skills/status/SKILL.md`, `skills/prompt/SKILL.md`;
  - the three small component changes AC-34 to AC-36 (senior-engineer `notes`, standards-setter `mode: init`, `gh-pr.sh open` with bats tests and `github-ops` row);
  - `tests/scripts/skills.bats`;
  - README `## Commands` and the Mermaid diagram;
  - the simulated runs and section 9 of `tests/agent-smoke/README.md`;
  - DESIGN, state-machine, CHANGELOG, project-map and CLAUDE.md updates.
- **Out:**
  - `ship-milestone` and milestone mode (prompt 06), and real-GitHub sandbox runs (prompt 07);
  - simulated runs of `prompt`, of the spec-ambiguity, triage and develop-blocked routes, and of a request-changes plan gate (static checks only; prompt 07 runs them live);
  - a deterministic argument-parsing or return-check script (the model follows the procedure; the commands are inline in the references) (Assumption 3);
  - the README's other "_To be written._" sections (config reference, labels, uninstall: DESIGN §12, prompt 07);
  - the prompt-04 open items not addressed to prompt 05: the commit-attribution policy, the nested `tests/e2e/` no-`cd` form, the curator's pruning rules, the context7 wildcard;
  - the unused `07-…`/`09-…` triage paths beyond what the S1 run happens to exercise.

## Context manifest

**Reference files** (downstream agents read these first):

- `docs/build-prompts/05-orchestrator.md`: deliverables and [P] ACs.
- `docs/DESIGN.md`: §3 (platform facts, incl. `${CLAUDE_PLUGIN_ROOT}` substitution and `${CLAUDE_SKILL_DIR}` untested), §4 (superpowers pin, built against 7.x), §5.1 (skill table, side-effect rule), §6.1 (config fields), §7 (run dir, state, stages, labels, return contract), §8 (agent inputs/outputs), §9 (orchestrator), §11 (hooks the orchestrator relies on).
- `docs/superpowers/project-map.md`: dispatch-field contracts per agent (prompts 03/04), CTO-3a/3b open items, harness gotchas.
- `skills/run-protocol/SKILL.md` and `references/state-machine.md`: stage/label mapping, gates table, failure paths, `qa_failures_complete`, counters and cycle-file naming.
- `skills/github-ops/SKILL.md`: every script call the orchestrator makes, the spec-revision recording order, "check `state.pr` before create", "write state before each developer dispatch".
- `scripts/state.sh`, `gh-issue.sh`, `gh-labels.sh`, `git-branch.sh`, `gh-pr.sh`, `gh-retro.sh` (`--help` is the contract); `scripts/hooks/gate-subagent.sh` (`valid_return_block`, developer/QA gate freshness).
- `agents/*.md` Inputs blocks (dispatch fields, required files) and Return contract sections (senior-engineer review SUMMARY starts with the verdict; triage NEXT names developer and/or qa-engineer; brief-compiler `prompt.md` has no return block).
- `templates/artefacts/spec-revision-comment.md`, `spec-changes.example.json` (the `jq` render), `spec-analysis.md` (`## Questions`, `### Q<n>.`), `plan.md` (`## Challenges to the spec`), `summary.md` (`- [x] AC-n` checklist), `qa-report.md` (triage table).
- `templates/config.schema.json` (required `project`, `default_branch`, `stacks`, `commands`, `app` with its four required keys, `retro`; defaults at leaf and object level), `state.schema.json`.
- `tests/agent-smoke/README.md` §2–4 (harness, `smoke_dispatch`, flags, final-message extraction), §8.3 (`smoke_shop`, static-shop install, port 4173).
- `tests/scripts/helpers/bin/gh` (stateful `issue view`/`issue edit` routes; any other route succeeds silently unless a canned `responses/<route>.out` exists) and `tests/scripts/helpers/common.bash` (seeding helpers to mirror outside bats).
- Fixtures: `tests/fixtures/apps/static-shop/` (config, issue #201 in `run/issue.json`, planted defects), `tests/fixtures/issues/material-guest-access.md` (#103), `tests/fixtures/stacks/nextjs-tailwind/`.
- Analog skill format: `skills/run-protocol/SKILL.md` (frontmatter), `skills/ui-qa/SKILL.md` (procedure skill with sections).

**Key facts learned from the codebase:**

- `state.sh` acts only on the run named in `current` (except `init` and `current set`); `init` refuses an existing run dir; `stage` always sets status `running`; there is no `--from` support and none is needed (AC-18 composes `current set` + `stage`).
- `gh-issue.sh fetch` writes into an **existing** run dir, so `state.sh init` must come first (DESIGN §9 lists fetch first: Conflict C4).
- `gh-pr.sh create` needs a run (`state.json` branch and title), so init's PR cannot use it; `git-branch.sh create` derives names from run patterns, so init creates `chore/aew-init` with plain `git switch -c`, while `git-branch.sh push` works for any non-default branch.
- standards-setter requires `02-brief.md` and blocks without it, so init cannot dispatch it as is (Conflict C3).
- senior-engineer plan mode has no field for James's change requests (needed by the plan gate and the developer-blocked route).
- The review verdict and the triage route are already in the return block (review SUMMARY "start with the verdict"; triage NEXT "developer (fix mode)" and/or "qa-engineer"), so routing needs no artefact read for them.
- `prompt.md` carries no return block, so it can be posted verbatim.
- The `gh` mock fails closed only without `GH_MOCK_DIR`; a real `gh` earlier on a re-initialised `PATH` would be reached. The Bash tool's shell is initialised from the user's profile, which may put `/opt/homebrew/bin` before the shim.
- The static-shop fixture's config names the **real** plugin repo as `retro.repo`; the harness must override it.
- `claude plugin list --json` reports `{"id":"superpowers@claude-plugins-official","version":"7.0.0",…}` on this machine.
- The existing smoke fixtures already cover the prompt's three needs: clean issue (#201 static-shop; #101 is Next and needs a heavy install), material issue (#103), nextjs-tailwind repo. Nothing new is needed beyond harness helpers.
- The SessionStart hook will print the resume hint inside the headless resume runs; harmless.

## Claude Code facts (verified against code.claude.com/docs on 2026-10-25)

| # | Fact the spec relies on | Result | Source | Design consequence |
|---|---|---|---|---|
| V-1 | Skill frontmatter and `$ARGUMENTS` | **Confirmed, with one change.** Keys include `argument-hint`, `disable-model-invocation`, `allowed-tools` (pre-approval for the invoking turn, not a restriction); unknown keys are ignored. `$ARGUMENTS` is the whole string, `$ARGUMENTS[N]`/`$N` are 0-based; with no placeholder the input is appended as `ARGUMENTS: <input>`. **Change:** `disable-model-invocation: true` also blocks Skill-tool invocation and removes the skill from Claude's context. | /en/skills | `argument-hint` set (AC-1); `$ARGUMENTS` parsed whole (AC-2, options in any order); `resume` and `prompt` reuse ship by Read, never the Skill tool (AC-21, AC-23); no `allowed-tools`. |
| V-2 | `-p "/aew:ship …"` runs a `disable-model-invocation` skill | **Confirmed** (user-invoked skills expand in `-p`). **New:** since v2.1.302 `-p` defaults to Manual mode (approvals denied); `--permission-prompts none` denies anything that would prompt; `--max-turns` errors when reached; `stream-json` needs `--verbose`. | code.claude.com/docs (page not recorded by the check; record the URL in DESIGN §3) | Harness keeps `--permission-mode acceptEdits` + explicit `--allowedTools`, adds `--permission-prompts none` (AC-39). |
| V-3 | `subagent_type: "aew:<agent>"`; parallel Agent calls in one message | **Partly documented.** Plugin agents are `plugin:agent`, but the exact `subagent_type` string is not spelled out; concurrency is documented for background subagents (limit 20), not for one-message dispatch. Live evidence already exists: `smoke_dispatch` uses `aew:<agent>` (prompts 03/04) and run 961 shows two `Agent` blocks under one `message.id`. | code.claude.com/docs (page not recorded by the check; record the URL in DESIGN §3) | P0 checks the agent names in `system/init`; S1 checks the one-message pair (AC-39, AC-40). Sequential execution of the pair would still be correct, so overlap is recorded, not required. |
| V-4 | AskUserQuestion limits and headless behaviour | **Changed.** Removed from every subagent's tool pool (main thread only). Per-call limits and a recommended-option marker are undocumented. Headless: `--permission-prompts none` removes the tool; otherwise `-p` behaviour is undocumented. | code.claude.com/docs (page not recorded by the check; record the URL in DESIGN §3) | Gates ask on the main thread only; recommended option first, labelled "(recommended)"; batching follows the tool schema (AC-8). Headless runs remove the tool, so G1/G2/R1 and init exercise the "absent" branch of AC-10 deterministically. |
| V-5 | `${CLAUDE_PLUGIN_ROOT}` substitution in references read with Read | **Confirmed as assumed.** `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_SKILL_DIR}` and `${CLAUDE_SESSION_ID}` are substituted in the skill body only; files read on demand are not; the Bash tool does not get `CLAUDE_PLUGIN_ROOT`. Supporting files: relative links recommended; keep `SKILL.md` under 500 lines. | /en/skills | `SKILL.md` states the root; absolute `${CLAUDE_PLUGIN_ROOT}` links (cross-skill reads by `resume`/`prompt` rule out relative links); no `` !`cmd` `` in ship (AC-1). DESIGN §3's "`${CLAUDE_SKILL_DIR}` untested" becomes "documented, unused". |
| V-6 | `claude plugin list --json` for the superpowers version | **Confirmed** as the documented route (`installed_plugins.json` also records it). **New:** for git sources `version` may be a 12-character SHA. | code.claude.com/docs (page not recorded by the check; record the URL in DESIGN §3) | AC-3.6 handles semver, SHA and failure separately; warn only. |
| V-7 | `Bash(...)` deny rules with inner wildcards; deny-over-allow | **Not covered by the 2026-10-25 check.** DESIGN §3 already records that a trailing ` *` matches the bare command only when it is the rule's only wildcard. | /en/permissions (to fetch) | The plan's AC-31 task verifies inner-wildcard matching and precedence first; until verified, the proposal uses exact rules and single-trailing-wildcard denies only. AC-31 is shown and asked, so the risk is bounded. |

## Conflicts between the prompt and DESIGN.md (DESIGN wins; each goes in the final report)

- **C1** Prompt: "the doc-writer commits". DESIGN §8.7: the doc-writer has no Bash and the orchestrator commits its docs. → The orchestrator commits (AC-16).
- **C2** Prompt: the orchestrator never reads *full* artefacts except the plan and failure lists. DESIGN §9: it opens artefacts for gates and routing, and the spec gate needs the questions. Not a true conflict: bounded section reads (`## Questions`, `## Challenges to the spec`) are not full reads, so AC-19 satisfies both; recorded as a clarification, not a deviation.
- **C3** Prompt and DESIGN §5.1: init generates the first standards docs. DESIGN §8.3: standards-setter takes a run dir and a brief. → A `mode: init` with no brief, recorded in §8.3 (AC-35).
- **C4** DESIGN §9 lists "fetch, then initialise state", but `gh-issue.sh fetch` needs the run dir that `state.sh init` creates. → Init state, then fetch (AC-4).
- **C5** Prompt AC "`/aew:ship 1 --auto`": the clean fixture is issue #201 (static-shop); the run uses `201`. Not a DESIGN conflict; recorded as a deviation (Assumption 6).

## Assumptions

**Skills and procedure**

1. **Assumed:** the orchestrator, resume and prompt run on the main thread as Markdown procedures the model follows; no new script parses arguments or checks returns. Reason: DESIGN calls for no such script, and CLAUDE.md says no files DESIGN doesn't call for. **Flag if wrong** (a small `scripts/ship-args.sh` would make AC-2 bats-testable).
2. **Assumed:** reference files use literal `${CLAUDE_PLUGIN_ROOT}/…` paths, and `SKILL.md` (which is substituted) says "the plugin root is `${CLAUDE_PLUGIN_ROOT}`; read every `${CLAUDE_PLUGIN_ROOT}` in the references as that path". Reason: V-5 confirmed (only the loaded skill body is substituted); absolute paths work for the cross-skill reads in `resume` and `prompt`, where relative links would resolve against the wrong skill.
3. **Assumed:** return blocks are checked inline (`tail -n 4` plus the `valid_return_block` rule restated in `dispatch.md`), and the QA discriminator is the `qa_failures_complete` snippet from `state-machine.md` run inline with `awk`. Reason: smallest change; state-machine.md already says the orchestrator implements it. **Flag if wrong.**
4. **Assumed:** `resume` and `prompt` reuse `ship`'s `SKILL.md` and `gates.md` by reference ("follow ship from the stage section for `<stage>`"), as DESIGN §10 asks for milestone mode, by **reading the files with Read** at `${CLAUDE_PLUGIN_ROOT}/skills/ship/…` (stated in their own substituted `SKILL.md`), never by invoking `ship` with the Skill tool, which `disable-model-invocation: true` blocks (V-1). Reason: no duplicated procedure, and ship keeps the side-effect flag DESIGN §5.1 requires.
5. **Assumed:** a gate that gets no answer (headless, refused, empty) is left pending and ship stops; `/aew:resume` re-asks it. For `init` only, no answer means the safe default: recommended config values, no dependency install, no settings write (all reviewable in the PR). Reason: ship gates guard material or irreversible decisions; init's choices are reversible. Headless runs remove AskUserQuestion (`--permission-prompts none`, V-4), so this is the branch the simulations exercise. **Flag if wrong.**

**Simulated runs**

6. **Assumed:** the simulated `ship` runs use the static-shop fixture and its issue **#201**, not "issue 1" on the nextjs fixture. Reason: static-shop runs with `npx serve` and a pre-installed Playwright (the proven prompt-04 harness), while the clean Next issue (#101) needs a full Next install and dev server for QA; fixture issue numbers are kept so renders stay byte-identical. The planted defects mean S1 also exercises one QA fix cycle (`impl_bug`) and the manual-tests path. **Flag if wrong.**
7. **Assumed:** simulated runs are real headless sessions (`claude --plugin-dir "$REPO" -p "/aew:…"`, as the existing harness), not a scripted replay; only `gh` and `origin` are fake. The allowlist is explicit (the union of the agents' `ALLOW` lines plus the orchestrator's script, git and `jq` calls), never `bypassPermissions`, so it doubles as the evidence for AC-31's proposal. Spend: caps per run (S1 and F1+R2 $25 each, G2 $8, init $3 each, G1 $3, probes $1), **stop at $60 total**, a cap hit raised once to 2x (prompt-03/04 ledger rules). The per-run caps are ceilings and sum to $68, so the $60 total stop takes precedence: if it is reached before every run has been made, the remaining runs are reported as not run rather than the cap being raised. **Flag if wrong.**
8. **Assumed:** "kill during develop" is the harness polling `state.json` once a second and killing the `claude` process when `stage` reads `develop`, so the developer has just been dispatched. If the tree is dirty after the kill, R2 must stop and list it (AC-21), and the harness records that, discards the partial work with `git checkout -- . && git clean -fd` (harness action, logged), and re-runs R2. Reason: deterministic enough; tests both resume branches. **Flag if wrong.**

**Preflight and run start**

9. **Assumed:** `gh auth status` is called directly (read-only) in ship and init preflight, the only `gh` call outside the scripts, allowed by the exact rule `Bash(gh auth status)` and nothing broader. Reason: no script wraps it; DESIGN §9 asks for the check; it writes nothing. It is a recorded deviation from CLAUDE.md's "only through the plugin's `scripts/gh-*.sh`" rule (final report). In the simulations it is also the canary: it is the first `gh` call, so a real `gh` reached by mistake meets the empty `GH_CONFIG_DIR` and unset tokens, fails, and preflight stops before any write. **Flag if wrong** (else add an `auth` subcommand to an existing script).
10. **Assumed:** "default branch up to date" means `git fetch origin <default>`, fast-forward the local default when it is only behind (`git merge --ff-only` if checked out, else `git fetch origin <d>:<d>`), stop when it has diverged. **Flag if wrong** (alternative: stop and ask James to pull).
11. **Assumed:** a run in `done` or `failed` is not active; `blocked`, `running` and `awaiting_*` are. `failed` also clears `current`. Reason: `failed` is terminal (run-protocol).
12. **Assumed:** the built-against superpowers major (7) is a single constant in `preflight.md`, compared with the `version` from `claude plugin list --json` (V-6) only when that is semver; a commit SHA or a failed call gives a "could not compare/check" warning instead. **Flag if wrong.**
13. **Assumed (`--from`):** it restarts an existing run at a stage without redoing earlier ones, keeps the counters, treats `qa_test_plan` and `plan` as the parallel step, and with `spec_analysis` re-fetches the issue. Re-shipping a `done` issue needs `--from` (or removing the run dir); a `done` run's PR is updated, not re-created (`state.pr`). **Flag if wrong.**
14. **Assumed:** ship does not run `gh-labels.sh ensure`; init does. Reason: `ensure` is 11 calls per run and idempotent; a missing label fails the first `stage` call loudly, and the error says to run `/aew:init`. **Flag if wrong.**
15. **Assumed:** retries are counted in the session, not in `state.json`; a resumed run starts with a fresh retry allowance. Reason: no schema field; the cycle limits are what bound loops.

**Routing**

16. **Assumed:** a developer `blocked` is routed to a senior-engineer plan revision once; the second `blocked` in a run is the blocked path; the revised plan goes through the plan gate again unless auto.
17. **Assumed:** one route per QA cycle, in the order `spec_ambiguity` → senior triage (any `plan_divergence`/`test_bug`, which also covers that cycle's `impl_bug` rows) → developer fix (`impl_bug` only). Reason: one decision-maker per cycle keeps fix-cycle counting simple. **Flag if wrong.**
18. **Assumed:** a `spec_ambiguity` answer goes to spec-analyser as `answers` (it owns the spec text and the change list); the revision is recorded; material → every stage from `brief` re-runs; non-material → brief re-run, then QA phase B. This refines the state-machine arrow "awaiting_input → qa: answered, no material change". **Flag if wrong.**
19. **Assumed:** for a plan `needs_input`, accepting the recommended answer keeps the plan (the senior engineer planned on it, per its prompt) and re-runs only spec analysis (recording), the brief and QA phase A; any other answer re-runs from `spec_analysis`.
20. **Assumed:** the blocked report comment is written to a temp file (`mktemp`), not into the run dir, because run-dir names are fixed (run-protocol "don't invent new ones"). **Flag if wrong** (a `blocked-report.md` would need a DESIGN §7.1 row).
21. **Assumed:** prompt mode sets no stage labels and creates no branch (only the `spec-revised` flag on a recorded revision), requires `.aew/config.json`, and refuses an issue that already has a run dir. Reason: it changes no code; stage labels would mislead. **Flag if wrong.**

**init**

22. **Assumed:** init stops on missing git, gh auth, jq or Node < 20 (it needs them to run) and only warns on stack tools; it requires a clean tree so its commit holds only its own files.
23. **Assumed:** `retro.repo` is proposed as `jamesborg2012/claude-agentic-engineer-workflow` (the plugin's repo, solo use), `app.base_url` from the framework default (Next: `http://localhost:3000`, wp-env: `http://localhost:8888`), `typecheck` as `npx tsc --noEmit` when a `tsconfig.json` exists and no script does; absent commands are omitted (the schema has no required command keys; agents record "not configured"). **Flag if wrong.**
24. **Assumed:** on a re-run, existing config values always win over fresh detection; init reports detected differences instead of overwriting them. Reason: "updates rather than duplicates" and the user may have hand-edited config.
25. **Assumed:** init adds `.playwright-mcp/` as well as `.aew/runs/` to `.gitignore`, because QA's MCP server writes it into the project in every UI run, and a dirty tree would block `resume`.
26. **Assumed:** the permission proposal allows the plugin scripts by their absolute installed path (re-running init after a plugin update refreshes them), read-only git, `git add`/`commit`/`switch`/`worktree` with specific subcommand rules, and the config's commands; it adds the CTO-3a deny rules. Exact rules are settled in the plan after V-7. **Flag if wrong.**
27. **Assumed:** init's PR goes through a new `gh-pr.sh open` subcommand rather than a direct `gh pr create`. Reason: DESIGN §4 "gh only, wrapped by plugin scripts"; the subcommand's open-PR lookup is what makes a re-run with new changes idempotent.
28. **Assumed:** orchestrator and init commits use plain conventional messages with no extra trailer beyond what the user's Claude Code settings add, matching the developer's rule; the attribution policy itself stays an open item.

## Risks

- **A real `gh` reached during a simulation** (the Bash tool's profile-initialised shell can put the real `gh` before the shim, and the fixture names a real retro repo). Mitigation, layered: P0 probe gates every other run (shim on `PATH`, tokens empty, `origin` the bare repo); `GH_CONFIG_DIR` empty and the four token variables unset, so a real `gh` is unauthenticated and the preflight `gh auth status` canary stops the run before any write (Assumption 9); `origin` is a local path, so a repo-inferred `gh` call cannot resolve a GitHub repo; `retro.repo` overridden to a fake repo; the issue URL is `acme/…`; the allowlist has no `gh` rule beyond `Bash(gh auth status)`, so the model cannot run `gh` directly; and `--permission-prompts none` denies anything unlisted.
- **Headless AskUserQuestion behaviour** (V-4) is undocumented except that `--permission-prompts none` removes the tool. The harness therefore always passes that flag, P0 confirms the tool is absent, and the gate tests prove the stop from state and labels (AC-41, AC-42). Interactive behaviour (answers, refusal) is exercised only in prompt 07.
- **Cost and length.** S1 runs every agent including a QA fix cycle; F1+R2 repeats develop to done. Caps and the $60 stop bound it; a cap hit is a run failure, not a check failure.
- **spec-analyser may class something in #201 as material** (for example the out-of-repo email service), stopping S1 at the spec gate even with `--auto`. That would be correct behaviour but fail AC-40; the fix is a harness fixture tweak (an unambiguous #201 body), recorded, never a weakened check.
- **Resume after a kill mid-WP**: the developer's full mode may redo or collide with a WP it had already committed; AC-43 kills early to avoid it, and the risk is recorded for prompt 07.
- **Model-followed procedure drift**: a long `SKILL.md` may be skipped in places. Mitigated by keeping `SKILL.md` short and procedural, detail in references read at the step that needs it, and AC-38's static checks; behaviour is proven only by the simulations.
- **Permission rules** (CTO-3a) are heuristic; a deny pattern may over- or under-match (V-7). The proposal is shown and asked before writing.
- **Parallel planning wall-clock**: two Opus agents at once; fine for cost, but a failure in one must not discard the other's output (retry only the failed one).
- **Developer gate freshness** (whole-second `-nt`): every developer dispatch must follow a `state.sh` write in the same procedure step.

## Open questions for human

(none — all decisions made from project context; V-1…V-6 verified and folded in on 2026-10-25; V-7 is verified by the plan's AC-31 task, with a defined fallback)

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T22:57:04Z (spec-review)
- Complexity: NOVEL
- Scale: EPIC
- Reason: custom main-thread orchestrator with no analog in the repo, about 15 tasks over more than one session, paid headless simulations with a real-GitHub safety surface, and a project permissions proposal (CTO-3a); five shippable slices with a clear dependency order.
- Spec content hash (SHA-256): 4633583883f5f733d49b1bb0ae24508f370b3a3b888af4014b8fdc1ea9ff6090 (the document above this section)
- Review fixes applied in place: V-1…V-7 folded in (table above); `resume`/`prompt` reuse ship by Read, not the Skill tool (AC-21, AC-23, Assumption 4); no `` !`cmd` `` or `$N` in ship (AC-1); superpowers SHA versions (AC-3.6, Assumption 12); fetch failure or closed issue leaves no dangling active run (AC-4); AskUserQuestion main-thread only, "(recommended)" label, headless `--permission-prompts none` (AC-8, AC-10, AC-39, Assumption 5); token variables unset, origin and agent-name probes, no `gh` allow rule beyond `gh auth status` (AC-39, Assumption 9, Risks); one-message dispatch evidence (AC-40); C2 restated as a clarification; spend-cap arithmetic (Assumption 7).
- Notes for the plan (not blocking): V-7 must be verified before the AC-31 rules are written; record the docs page URLs for V-2, V-3, V-4 and V-6 in DESIGN §3; AC-32's deletion of an empty `chore/aew-init` branch is optional polish and may be dropped if it complicates init.

<spec-summary>
- Topic: orchestrator-and-entry-skills
- Issue: no issue — build prompt `docs/build-prompts/05-orchestrator.md` (DESIGN.md wins)
- Problem: scripts, hooks, agents and the run protocol exist in isolation; nothing a user can type drives an issue through DESIGN §7.3. Add `init`, `ship`, `resume`, `status`, `prompt`, proven by mocked-`gh` headless simulations.
- ACs (testable): AC-1…AC-47 above; prompt ACs marked [P]. Key: AC-2 bad args stop before any write; AC-7 one-message QA-A + plan; AC-8/9/10 gates (unanswered → pending, stop); AC-11/13 review and QA loops within limits; AC-15 blocked path; AC-16/17 PR and final report; AC-21 resume by Read; AC-33 init idempotent; AC-38 static checks; AC-40…45 simulations S1, G1, G2/R1, F1/R2, I1/I2, bad-arg probes.
- Scope in: five skills (+ six ship references); senior-engineer `notes`, standards-setter `mode: init`, `gh-pr.sh open` (+ bats); `tests/scripts/skills.bats`; README commands + Mermaid; agent-smoke §9 simulations; DESIGN/state-machine/CHANGELOG/project-map/CLAUDE.md updates.
- Scope out: ship-milestone (06), real-GitHub runs (07), simulated prompt/triage/spec-ambiguity/develop-blocked/request-changes routes, an argument-parsing script, other README sections.
- Context manifest (key references):
  - `docs/DESIGN.md` §3, §4, §5.1, §7, §8.3, §8.4, §8.7, §9, §10 — contracts and platform facts
  - `skills/run-protocol/references/state-machine.md` — stage/gate/failure tables, `qa_failures_complete`
  - `skills/github-ops/SKILL.md` — every script call and the spec-revision order
  - `scripts/{state,gh-issue,gh-labels,git-branch,gh-pr,gh-retro}.sh --help` — script contracts
  - `scripts/hooks/gate-subagent.sh` — `valid_return_block`, developer gate freshness
  - `agents/*.md` Inputs + Return contract — dispatch fields
  - `tests/agent-smoke/README.md` §3, §8.3 — headless harness, `smoke_shop`
  - `tests/scripts/helpers/bin/gh` — stateful mock
- Assumptions (high-stakes, flag if wrong):
  - `gh auth status` called directly (only non-script `gh` call; recorded deviation; simulation canary)
  - simulations use #201 static-shop, real headless sessions, explicit allowlist + `--permission-prompts none`, $60 stop
  - unanswered ship gates stay pending; init falls back to safe defaults
  - `resume`/`prompt` Read ship's files under `${CLAUDE_PLUGIN_ROOT}`; never the Skill tool
  - init PR via new `gh-pr.sh open`; permission proposal shown and asked, V-7 verified first
- Complexity: NOVEL
- Scale: EPIC
- Spec content hash: 4633583883f5f733d49b1bb0ae24508f370b3a3b888af4014b8fdc1ea9ff6090
</spec-summary>

<epic-decomposition>
- phase: A
  title: Component additions the skills need
  scope: senior-engineer plan-mode `notes`, standards-setter `mode: init`, `gh-pr.sh open` with bats tests and the github-ops row
  acs: [34, 35, 36]
  depends_on: []
  depth: lean
  risk: none
- phase: B
  title: ship orchestrator
  scope: `skills/ship/SKILL.md` and the six references (arguments, preflight, run start, dispatch and return checks, both gates, review and QA routing, blocked path, PR, final report, --from)
  acs: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  depends_on: []
  depth: full
  risk: none
- phase: C
  title: resume, status and prompt
  scope: the three skills reusing ship's files by Read (`resume`, `prompt`) and the read-only `status`
  acs: [21, 22, 23]
  depends_on: [B]
  depth: lean
  risk: none
- phase: D
  title: init
  scope: prerequisites, `chore/aew-init` branch, detection and config, labels, gitignore, Playwright offer, CLAUDE.md section, permissions proposal (CTO-3a, V-7), standards-setter init, commit/push/PR, idempotency
  acs: [24, 25, 26, 27, 28, 29, 30, 31, 32, 33]
  depends_on: [A]
  depth: full
  risk: permissions (project `.claude/settings.json` allow/deny proposal)
- phase: E
  title: Static checks and README
  scope: `tests/scripts/skills.bats`, README `## Commands` and the Mermaid pipeline diagram
  acs: [37, 38]
  depends_on: [B, C, D]
  depth: lean
  risk: none
- phase: F
  title: Simulated runs and closing docs
  scope: agent-smoke §9 harness and P0 probe, S1, G1, G2/R1, F1/R2, I1/I2, bad-argument probes, ledger; DESIGN, state-machine, CHANGELOG, project-map, CLAUDE.md updates
  acs: [39, 40, 41, 42, 43, 44, 45, 46, 47]
  depends_on: [E]
  depth: full
  risk: real-GitHub safety of paid headless runs (mocked `gh`, local origin)
</epic-decomposition>
