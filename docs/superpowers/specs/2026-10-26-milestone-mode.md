# Brainstorm — Milestone mode: `ship-milestone`, bulk and sequential runs (build prompt 06)

- **Issue:** no issue. This is build prompt 06 (`docs/build-prompts/06-milestone-mode.md`). DESIGN.md wins on conflict.
- **Date:** 2026-10-26

## Problem

`ship` delivers one issue. DESIGN §10 also needs whole milestones delivered, in one of two ways. **Bulk** runs one combined pipeline and opens one PR, for small cheap milestones. **Sequential** runs the full single-issue pipeline per issue, in dependency order, stacking PRs where an issue builds on an unmerged one. Today nothing handles either. `ship` refuses `m-<n>` (E3, "coming in a later release"), and `resume`/`status` stop on any mode other than `single`. Build prompt 06 adds `ship-milestone`, reuses `ship`'s procedure without copying it, and teaches `resume` and `status` about milestone runs.

## Acceptance criteria

Every acceptance criterion from the prompt is kept and marked **[P]**. The rest turn the prompt's deliverables and DESIGN §7, §9 and §10 into testable criteria. "V-n" refers to the platform-facts list below.

**Scripts (deterministic, bats-tested with the mocked `gh`)**

1. **AC-1** `gh-milestone.sh select <milestone>` (new subcommand; `<milestone>` is a number or title, as for `issues`) makes one `gh issue list` call. That call is the existing one plus `milestone` in `--json`. It prints one JSON object:
   - `milestone`: `{number, title}`, taken from the issues.
   - `issues`: the **open** issues, sorted by number, each `{number, title, labels, depends_on, ac_count, stack_on}`.
   - `closed`: the numbers of the closed issues.
   - `order`: the topological order of the open issues, or `null` on a cycle.
   - `cycle`: `null`, or the sorted numbers that the sort could not place.
   - `stack_conflicts`: `[]`, or `[{issue, deps}]`.
   - `recommend`: `bulk` or `sequential`.
   - `reasons`: an array of short strings, empty when the recommendation is bulk.

   `issues` keeps its output exactly. Only its `gh` call gains `milestone`, and the bats "documented arguments" test is updated to match.
2. **AC-2** The criteria, as computed by the script:
   - A dependency is **blocking** when it is a `depends_on` entry that is not a closed issue of this milestone.
   - `order` is Kahn's algorithm over the open in-milestone edges only. Ties go to the lowest number first. Edges to issues outside the milestone are ignored for ordering.
   - `recommend` is `bulk` exactly when every one of these holds: there are 1 to 5 open issues; every `ac_count` is non-null and at most 5; and no open issue has a blocking dependency. Otherwise it is `sequential`, and each failed criterion adds one reason, for example `6 open issues (more than 5)`, `#14 has 8 acceptance criteria`, `#13 depends on #12`, or `#15: no acceptance-criteria list found`.
3. **AC-3** `ac_count` is the number of list items (`-`, `*`, `+`, `1.`, `1)`, with or without `[ ]`, indented 3 spaces or fewer) between a line that names acceptance criteria and the next heading. The opening line is a Markdown heading or a bold line whose text matches `acceptance criteria` (case-insensitive). The count is `null` when no such section exists. CRLF bodies and null bodies parse.
4. **AC-4** `stack_on`, for each open issue:
   - With no open in-milestone dependency, it is `null`.
   - Otherwise it is that dependency which comes latest in `order`. The issue's branch stacks on that dependency's branch.
   - If any other open in-milestone dependency is not on the chosen one's `stack_on` chain, the issue is listed in `stack_conflicts` and `stack_on` stays `null`, because one branch cannot hold both.
5. **AC-5 [P]** There are three fixture milestones under `tests/scripts/fixtures/milestone/`, tested in `gh-milestone.bats` with the mocked `gh`:
   - three small related issues → `bulk`, `reasons` `[]`;
   - five issues, one of them with more than 5 ACs → `sequential` with that reason;
   - three issues in a dependency chain, listed out of order → `sequential`, `order` is the chain order, and each `stack_on` is its predecessor.

   Further cases cover a cycle (`order` null, `cycle` set), a stack conflict, a missing AC section, closed dependencies (not blocking), an all-closed milestone, a title argument, and a `gh` failure (nothing on stdout).
6. **AC-6** `state.sh init <m-id> --mode bulk --issues a,b,c` also creates `issues/<k>/` for each issue in the run dir, so `gh-issue.sh fetch <k> .aew/runs/m-<n>/issues/<k>` has its existing directory. Other modes are unchanged.
7. **AC-7** `state.sh index` (new) owns `.aew/runs/m-<n>/index.json`. It is never written by hand.
   - `index init <m-id> [--stack-on <k>:<dep>,…]` needs the run's `state.json` with mode `sequential`. It writes `{run_id, order, children: [{issue, stack_on, status}]}`. `order` is that state's `issues`, and every `status` is `pending`.
   - `index set <m-id> <issue> <status>` takes `pending | running | done | blocked | failed`.
   - Both take an explicit run id (not `current`). Each write is checked first and made atomically, as `state.json` is.
   - Invalid input exits 1 and writes nothing: a mode that is not sequential, an issue that is not in the run, a `stack_on` that does not come earlier in `order`, or a bad status.
   - `--help` documents the format. Bats tests cover every rule.
8. **AC-8** Every changed script stays bash 3.2-compatible, keeps `set -euo pipefail`, passes shellcheck and supports `--help`. `tests/run-script-tests.sh` passes. `templates/state.schema.json` needs no change (Assumption 6), and every `state.json` the milestone flows write still validates against it.

**`skills/ship-milestone/` — structure, arguments and mode selection**

9. **AC-9** `skills/ship-milestone/SKILL.md` has this frontmatter: `name: ship-milestone`, a `description`, `disable-model-invocation: true` and `argument-hint: "<milestone> [--bulk|--sequential] [--auto]"`.
   - The file stays under 500 lines and contains the procedure. The detail goes in `references/mode-selection.md`, `references/bulk.md` and `references/sequential.md` [P], cited by absolute `${CLAUDE_PLUGIN_ROOT}/…` paths.
   - It states the plugin root once (ship's rule) and reads ship's files with Read, never with the Skill tool.
   - It uses no `$N` and no `` !`cmd` ``, and parses `$ARGUMENTS` whole. That way `resume` can read it.
10. **AC-10 [P]** Arguments are `<milestone> [--bulk|--sequential] [--auto]`.
    - Every token that does not start with `--` belongs to the milestone, and the tokens are joined by single spaces. One surrounding pair of matching double or single quotes is then removed, because `$ARGUMENTS` may carry the quotes of `/aew:ship-milestone "Sprint 3"` verbatim. One token matching `^[1-9][0-9]*$` or `^m-[1-9][0-9]*$` is a number.
    - Each of these stops before any write, with one error line plus the usage line: no milestone; both `--bulk` and `--sequential`; a repeated option; an unknown option.
11. **AC-11** The run starts in this order, and nothing is written until it has finished:
    - ship's `preflight.md` checks 1 to 4 and 6;
    - `gh-milestone.sh select`;
    - Check 5 with the run id `m-<number>`, where the number comes from `milestone.number`.

    It stops with a clear message when the milestone has no open issues, and when `.aew/runs/m-<n>` already exists (pointing to `/aew:resume m-<n>`).
12. **AC-12 [P]** With no mode flag, `mode-selection.md` builds the recommendation from the script's `recommend` and `reasons`, plus James's judgement criteria. The judgement criteria are "same area" and "low risk", taken from titles and labels only (the AC count comes from the quick read in AC-3, not from a spec analysis). Judgement can only turn bulk into sequential, and it says why.
    - The skill prints a one-paragraph rationale, then asks one AskUserQuestion. The recommended mode comes first, labelled ` (recommended)`, then the other mode, then `Stop`.
    - If there is no answer (the tool is absent headless, refused, or empty), it prints the rationale and `Rerun with /aew:ship-milestone <m> --bulk` (or `--sequential`), then stops having written nothing.
    - With a flag, there is no question. It prints one line, `Mode: <mode> (given)`, plus a warning for each reason that argues against a forced bulk run.
13. **AC-13 [P]** In sequential mode, a dependency cycle or a stack conflict stops the run before anything is written. The message names the issues and asks James to break or add a dependency link on GitHub, then rerun. A bulk run ignores both, with a warning, because it runs on one branch.

**Bulk (`bulk.md`)**

14. **AC-14 [P]** Bulk start:
    - The run id is `m-<n>`: `state.sh init m-<n> --issues <open issues> --mode bulk --title "<milestone title>"`, plus `--auto` when given.
    - Each issue is fetched into `issues/<k>/`. A closed issue stops with the usual message.
    - Every issue gets `gh-labels.sh stage <k> analysing`.
    - One branch from `git-branch.sh create m-<n> <slug>` (`milestone_branch_pattern`; the slug is the milestone title, using ship's slug filter).
15. **AC-15 [P]** Bulk spec analysis:
    - One D1 per issue, all in **one** assistant message. Each gets `run_dir: .aew/runs/m-<n>/issues/<k>` and `spec_version: <that issue's version + 1>`. Each has its own return check and its own retry.
    - Each `ok` records **that issue's** revision with gates.md `## Recording a spec revision`: `<rd>` is `issues/<k>` and `<n>` is `k`. The per-issue version is the history note `spec revision: #<k> v<N>` (written with `state.sh status running --note …`), which replaces `state.sh set spec_revision`. The idempotency check reads the same note.
    - Each `needs_input` gets **its own** spec gate. Its label (`awaiting-input`) goes on that issue only, and its pending note is `gate:spec issues/<k>/01-spec-analysis.md`. Gates run one at a time, in issue order.
    - A resumed bulk spec stage re-dispatches only those issues whose `01-spec-analysis.md` return block is not yet `ok`.
16. **AC-16 [P]** D3 is dispatched once, with the extra field `issues: <a,b,c>`. The brief-compiler reads each `issues/<k>/spec-final.md` and `issue.json` and writes one `02-brief.md`. Its AC ids are prefixed by issue (`#12-AC-1`, which the brief-compiler already numbers that way), and its H1 is `# Brief: m-<n> <milestone title>`.
17. **AC-17 [P]** After the brief, ship's stage sections run unchanged:
    - one standards pass, one plan (D6 ∥ D7), one plan gate unless `--auto`, and one develop, review and QA loop;
    - every `gh-labels.sh stage` call is made once per issue in `issues`;
    - the QA report's TC → AC table carries the prefixed ids, which gives traceability per issue;
    - qa-engineer uses the run id `m-<n>` as its `<issue>` for its spec file name and evidence dir (`docs/qa/m-<n>/`, Assumption 9).

    A plan-challenge, triage or spec-ambiguity answer re-runs D2 only for the issues named by `#<k>` in the question (all of them when none is named), then records each revision, then goes to the brief.
18. **AC-18 [P]** Docs and the PR:
    - The doc-writer writes one `docs/specs/<k>-<slug>.md` per issue, from `issues/<k>/`, plus one `pr-body.md` whose introduction is the bulk variant.
    - `check-pr-intro.sh … --issues <count>` runs, as now. `gh-pr.sh create m-<n>` opens **one** PR with a `Closes #k` for every issue.
    - Manual tests, if any, go to every issue, and each issue gets the `manual-test-required` flag.
    - `ready-for-review` goes on every issue. The retro is filed once.
19. **AC-19** The bulk blocked path posts the blocked comment and sets `aew:blocked` on every issue in the run.

**Sequential (`sequential.md`)**

20. **AC-20 [P]** Sequential start:
    - The order is `select`'s `order`.
    - `state.sh init m-<n> --issues <order> --mode sequential --title "<milestone title>"` (plus `--auto`), then `state.sh index init m-<n> --stack-on …`.
    - Before anything is written, `test -e .aew/runs/<k>` must print `absent` for every child. Otherwise it stops, naming the run.
    - Between children, `current` is `m-<n>`.
21. **AC-21 [P]** For each child in order, the child runs **ship's own procedure**:
    - ship's `## Step 3. Start the run`, with three substitutions (`sequential.md` `## Start a child`):
      - `--mode sequential-child`, plus `--auto` from the parent;
      - the history note `milestone m-<n>` straight after init (the `prompt` marker precedent);
      - for a stacked child, `git-branch.sh create <k> <slug> --base <dependency branch>`, then `state.sh set base_branch <dependency branch>`;
    - then ship's stage sections from `## Stage: spec_analysis` step 2 onwards, unchanged.

    The index goes `running` at the start, then `done`, `blocked` or `failed` from the child's final status. ship's `## Final report`, its blocked path and its plan-gate stop hand a `sequential-child` run back to `sequential.md` `## After a child`, and do not stop. So does ship's Step 3.3/3.4 stop (fetch failed or issue closed), which today prints and stops without reaching `## Final report`: for a child it records the index `failed` and goes to `## After a child`. ship's `## Gate pending` (any gate, unanswered) stops the session as for a single run: the index stays `running`, `current` stays `<k>`, and both `/aew:resume <k>` and `/aew:resume m-<n>` continue it (AC-28). The plan gate applies per child unless `--auto` [P].
22. **AC-22 [P]** A stacked child's PR targets the dependency's branch: `gh-pr.sh create` already reads `base_branch`, and review D9 diffs against the same base. D13 gets `stacked_on: <dependency issue>`. The doc-writer writes the stacked introduction, which says in words that this builds on the PR for issue #k and must be merged after it. It also adds one line to the PR body's summary naming the base branch. `check-pr-intro.sh` passes.
23. **AC-23 [P]** A child ending `blocked` or `failed` stops the sequence:
    - the index records it;
    - `state.sh current set m-<n>`, then `state.sh status blocked --note "child #<k> <status>: <reason>"`;
    - the milestone report (AC-26) is written, then the final report (AC-27), then the run stops.

    Later children get no state, branch or label.
24. **AC-24** ship's `preflight.md` Check 5 also passes when `current` is `m-<n>` and this run is that milestone's child, as its history note `milestone m-<n>` shows. Then `/aew:ship <k> --from <stage>` on a stopped child works and hands back to the sequence when it finishes.

**Shared: reuse, report and summary**

25. **AC-25** There is no pipeline copy-paste:
    - `ship-milestone` has no `## Stage:` sections, no dispatch-table rows and no gate steps;
    - ship gains only single-line hooks that point into ship-milestone's references: Rules (bulk spec analysis is a second exception to one Agent call per message), Run variables (in bulk, `<n>` means each issue), `## Stage: spec_analysis` (bulk), docs (`stacked_on`), Final report, Blocked path, Gate pending (sequential child);
    - gates.md, preflight.md, pr.md and final-report.md gain only the bulk path overrides (`issues/<k>/issue.json` for the URL and repo; the `#<k>-AC-` count pattern);
    - ship's E3 now says `use /aew:ship-milestone <n>`;
    - a `skills.bats` check enforces the first point.
26. **AC-26 [P]** The milestone summary goes in `.aew/runs/m-<n>/milestone-report.md`, written with the Write tool (Read first if it exists). It is posted with `gh-issue.sh comment <k>` on **every issue of the run**, in both modes, whether the run finished or stopped. It has:
    - a heading with the milestone and its outcome;
    - one line per issue: shipped (PR link), blocked or failed (with the reason), or not started;
    - the manual tests outstanding per issue;
    - `Resume with /aew:resume m-<n>` when the run stopped.

    A failed comment only warns, and the warning goes into the final report.
27. **AC-27 [P]** The final report to James, printed last, has these lines:
    - `aew ship-milestone m-<n> <title>: <done | stopped>`;
    - `Mode:`;
    - `Shipped:` (`#k → PR url`, one per line);
    - `Blocked:` (`#k at <stage>: <reason>`, or none);
    - `Not started:`;
    - `Manual tests outstanding:` (a count per issue);
    - `Retro items filed:`;
    - `Next:`;
    - `Warning:` lines.

    In a sequential run each child's own ship final report is printed as well, when that child ends.

**`resume` and `status`**

28. **AC-28 [P]** `resume` drops the "coming in a later release" stop.
    - `bulk`: it continues like `single` (ship's sections plus the bulk hooks). A pending per-issue gate takes `<rd>` and `<n>` from the path in its note.
    - `sequential`, or a `sequential-child` id (the parent comes from the child's note): it reads `ship-milestone/SKILL.md` and `sequential.md` and enters `sequential.md` `## Resume`. That section works through the index:
      - the first child that is not `done` is the one to act on;
      - a `pending` child is started;
      - a running, pending-gate or blocked child is continued through resume's own Steps 4 and 5, run with that child's id (branch check, tree check, `current set`, then the gate re-ask or the stage entry), and the sequence continues once it finishes;
      - a `failed` child prints `/aew:ship <k> --from <stage>` and stops;
      - when every child is done, the run finishes.

    A sequential parent skips the branch check, because its `branch` is null. Resume never re-runs a finished child.
29. **AC-29** `status`:
    - its list is unchanged (it is mode-agnostic);
    - `## Show one run` for a sequential parent prints the index as a table (child, index status, the child's status and stage from its `state.json`, PR). A child shows `Part of milestone run m-<n>`;
    - the next-action table gains the milestone rows, and the "coming in a later release" line goes.

    It stays read-only and runs no script.
30. **AC-30** `skills.bats` adds `ship-milestone` to its entry skills, and its references to the citation resolver and to tests 17 and 18 (pre-approvable commands, printed checks). Frontmatter, argument hint, paths and citations all resolve. The suite passes.

**Documentation**

31. **AC-31** These are updated:
    - DESIGN §7.1: the bulk `issues/<k>/` layout, `index.json` and `milestone-report.md`;
    - DESIGN §9: the resume line ("`single` runs only until prompt 06");
    - DESIGN §10: a procedure-detail pointer, the dependency and AC-count rules, and the recorded deviations below;
    - the run-protocol skill (run-dir layout) and github-ops (`select`, `state.sh index`);
    - the README commands section, `CHANGELOG.md`, CLAUDE.md `## Recent changes`, and the project-map knowledge.

    All of it is in British English.

**Simulated runs (prompt 06 ACs; recorded in `tests/agent-smoke/README.md` §10)**

32. **AC-32 [P]** Mode probes M1 to M3 are headless `/aew:ship-milestone <m>` sessions, one per AC-5 fixture, with no flag. Each prints the recommendation (bulk, sequential, then sequential with the chain order and the stacked order), stops because AskUserQuestion is absent, and creates no run dir and no `gh` write.
33. **AC-33 [P]** B1, `/aew:ship-milestone <m> --bulk --auto` on three small static-shop issues, completes with:
    - one `pr create` whose body has `Closes #` for all three issues and passes `check-pr-intro.sh --issues 3`;
    - a `Spec revision vN` comment, a body marker and the `spec-revised` flag on each issue whose analysis changed it, and on no other;
    - `ready-for-review` on all three;
    - the milestone report comment on each issue;
    - a valid `state.json` (`done`).
34. **AC-34 [P]** Q1 and Q2 run the chain fixture.
    - Q1, `--sequential --auto`, ships child 1 (PR base `main`) and is killed in child 2. The launcher's kill trigger keys on child 2's own `.aew/runs/<k2>/state.json` stage, not on `current`'s, because child 1 passes through the same stages first.
    - Q2, `/aew:resume m-<n>`, continues child 2 from its recorded stage, with no earlier stage and no child-1 work redone. Child 2's PR base is child 1's branch, with the stacked introduction.
    - Child 3 is then forced to `blocked`: its branch is pre-created by the harness, so `git-branch.sh create` fails and goes to the blocked path.
    - The sequence stops cleanly. The index reads `done, done, blocked`, the parent `state.json` is `blocked`, the milestone report is on all three issues, and child 3 has no agent dispatch.
35. **AC-35 [P]** The results are recorded in `tests/agent-smoke/README.md` §10 in §9's form: rails, launcher, spend ledger with a stop, per-run check tables, and a roll-up of the build-prompt ACs. Transcripts are never committed.

## Scope

- **In:**
  - `gh-milestone.sh select`, `state.sh index` and bulk subdirs in `state.sh init`, with bats tests and fixtures;
  - `skills/ship-milestone/` (four files);
  - the one-line hooks and overrides in ship's `SKILL.md` and references;
  - `resume` and `status`;
  - small input changes to brief-compiler (`issues` field), qa-engineer (bulk `<issue>` = run id) and doc-writer (per-issue snapshots and the stacked summary line);
  - run-protocol, github-ops, DESIGN, README, CHANGELOG and CLAUDE.md;
  - `skills.bats`;
  - simulated runs M1–M3, B1, Q1 and Q2.
- **Out:**
  - merging or retargeting PRs;
  - re-checking a dependency's PR state on GitHub between children (Assumption 11);
  - parallel children in sequential mode;
  - a schema file for `index.json` (Assumption 7);
  - a milestone variant of `prompt`;
  - the hook scripts (none needs a change);
  - real-GitHub runs (prompt 07);
  - fixing ship's existing limitation that a resume at `spec_analysis` after an answered plan-challenge re-runs D1 without the answers (Risk 6).

## Context manifest

**Reference files** (downstream agents read these first):

- `docs/DESIGN.md` §7.1, §7.2, §9, §10. §10 is the whole spec of the mode. §9's resume line and §7.1's run-dir table change.
- `docs/build-prompts/06-milestone-mode.md`: the deliverables and ACs.
- `skills/ship/SKILL.md`: the procedure that is reused. Step 3 (run start) is reused with substitutions. The stage sections, `## Gate pending`, `## Blocked path` and `## Final report` gain hook lines.
- `skills/ship/references/{preflight,dispatch,gates,routing,pr,final-report}.md`:
  - preflight Check 5 (AC-24);
  - dispatch D1, D3 and D13 (`stacked_on` already documented), and Required inputs (bulk paths);
  - gates `## Recording a spec revision` and `## Re-asking a pending gate` (per-issue);
  - pr.md (the `issue.json` URL and retro repo; commit `(#<n>)`);
  - final-report.md (the AC count pattern).
- `skills/resume/SKILL.md` Step 2.3 and Step 4.4, and `skills/status/SKILL.md` `## Show one run` and `## Next action`: these are where the milestone stops live today.
- `scripts/gh-milestone.sh` and `tests/scripts/gh-milestone.bats`, with `fixtures/milestone/{issues,expected}.json`. These are the pattern for `select`, and the `depends_on` parser is already done.
- `scripts/state.sh` and `tests/scripts/state.bats`: the pattern for `index` (validate, `write_state`-style atomic temp and `mv`, `--help` header).
- `scripts/git-branch.sh` (`create --base`, milestone pattern already supported) and `scripts/gh-pr.sh` (`create` already uses `base_branch` and closes every issue in `issues`). No change is needed.
- `agents/brief-compiler.md` (bulk numbering is already specified, but its inputs are single-issue), `agents/doc-writer.md` (`stacked_on` and the bulk intro are already there, but its inputs are single-issue) and `agents/qa-engineer.md` (`<issue>` = `issues[0]`). Developer and senior-engineer are already bulk-aware.
- `tests/scripts/skills.bats`: `ENTRY`, the citation resolver (around line 464) and tests 17 and 18 (around line 521).
- `tests/agent-smoke/README.md` §9 (rails, 9.2 launcher with `<kill-stage>`, F1/R2 kill-and-resume, S1 check form) and §9.10 (the latest record format).
- `tests/scripts/helpers/bin/gh`: canned routes (`issue-list`, call-specific `issue-list.<n>`) and stateful `issue view|edit`. Unseeded issue numbers fail.
- `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md`: the format and depth analog.

**Key facts learned from the codebase:**

- These already support milestones, so no change is needed:
  - `state.schema.json`: `run_id` `m-<n>`, and `mode` `single|bulk|sequential|sequential-child` (parent = `sequential`);
  - `git-branch.sh create m-<n>` uses `milestone_branch_pattern`, and `create <k> --base <b>` stacks;
  - `gh-pr.sh create <id>` reads `base_branch` and adds `Closes #n` for every issue;
  - `check-pr-intro.sh --issues <n>` handles the bulk length;
  - the brief-compiler numbers `#<issue>-AC-<n>` in bulk;
  - the developer assigns WPs to issues by prefix;
  - the senior-engineer lists prefixed ids;
  - the doc-writer handles `stacked_on` and the bulk intro;
  - dispatch.md already documents D13 `stacked_on`;
  - init's allow templates already include `gh-milestone.sh *` and `state.sh *`, so init needs no change (its `SKILL.md` is at 498/500 lines).
- `gh-milestone.sh issues` drops `body`, so the AC count must be computed in the script (AC-3). It also has no milestone number or title, so `select` adds `milestone` to the `gh` fields.
- `state.sh` writes only the run named in `current` (except `init` and `current set`). `run_dir` is flat (`.aew/runs/<id>`), so child runs are `.aew/runs/<k>` beside the parent `m-<n>`, and the parent and child are linked only by the index and the child's history note.
- `gh-issue.sh fetch` refuses a missing directory, so bulk subdirs must exist first. `mkdir` has no init allow rule, so `state.sh init` creates them (AC-6).
- Precedents that are reused:
  - the `prompt` history marker written straight after init gives the child note `milestone m-<n>`;
  - `gate:<id> <file>` notes give per-issue gates, by carrying the subdir path;
  - decisions read from `history`, not from memory, give the per-issue revision notes;
  - the flat Write-tool comment file (`blocked-<id>.md`) gives `milestone-report.md`.
- Headless rules (DESIGN §3: H1–H8, M1, M2, no pipe in a condition, printed checks) bind every command in the new skill. The sequence loop is model-driven, with no shell loops.
- The gh mock returns canned `issue-list` to `gh-retro.sh` as well. A milestone listing must use the call-specific `issue-list.1` (or the harness must order its responses), or retro de-duplication sees milestone issues.

## Platform facts this design relies on (for the parallel verifier; DESIGN §3 numbering where it exists)

1. **V-1**:
   - A skill with `disable-model-invocation: true` is user-invocable as `/aew:ship-milestone`, and headless `claude -p "/aew:ship-milestone …"` expands it;
   - a Skill-tool call to it is blocked, so `resume` reads its files with Read;
   - `$ARGUMENTS` is the whole string, quotes included, for a quoted milestone title;
   - `argument-hint` containing `|` must be a quoted YAML string.
2. Only the loaded `SKILL.md` body has `${CLAUDE_PLUGIN_ROOT}` substituted, not references read with Read (§3 Path variables).
3. Several Agent calls in one assistant message are dispatched together, now with up to 5 (bulk spec analysis, one per issue), not 2. Is there a per-message cap, and is "up to 20 background subagents" relevant to foreground calls? Correctness does not depend on them running concurrently.
4. **V-4**:
   - AskUserQuestion exists only on the main thread, and is absent under `--permission-prompts none`;
   - its limits on questions per call and options per question matter, because the mode confirmation uses three options and a per-issue spec gate may have several questions;
   - "Other" is added automatically.
5. Long main-thread sessions. A sequential run drives several full pipelines in one session. Verify how auto-compaction treats a skill loaded earlier and references read earlier. The design re-reads state and references at each step, and never relies on memory.
6. The `SubagentStop` gates key on `agent_type` only, and read `.aew/runs/current`. During a child that is the child's run. During bulk it is `m-<n>`. No new hook behaviour is needed.
7. Headless smoke facts:
   - a killed `-p` session emits no `result`;
   - `--max-budget-usd` includes subagent spend.
8. GitHub, not Claude Code:
   - `gh issue list --json milestone` gives `{number, title}`;
   - several `Closes #n` lines in one PR body close every issue on merge;
   - when a stacked PR's base branch is deleted after its own PR merges, GitHub retargets the stacked PR to the merged PR's base. This only matters for Risk 3.

## Conflicts between the prompt and DESIGN.md (DESIGN wins; each goes in the final report)

- **C1 AC count.**
  - DESIGN §10 says "5 ACs or fewer once analysed". The prompt says "from a quick read of each issue, not a full spec analysis".
  - Running spec-analyser (Opus, high) on every issue just to choose a mode would double the analysis cost in sequential mode, because each child re-analyses in its own run dir.
  - This spec reads DESIGN's "once analysed" as the orchestrator's quick analysis of the issue (the script's AC-list count, AC-3), and updates DESIGN §10's wording to say so. **Flag if wrong.**
- **C2 Cycle "asks".** DESIGN and the prompt say a cycle "stops the run and asks". Here it stops before writing anything and asks in its message, not through AskUserQuestion: no answer could fix GitHub links from inside the run (AC-13). **Flag if wrong.**
- **C3 Evidence path.** DESIGN §6 is `docs/qa/<issue>/`. A bulk run's QA is one pass for several issues, so its evidence goes under `docs/qa/m-<n>/` (AC-17). This is recorded as a §10 deviation.
- **Prompt note (not a DESIGN conflict).** Deliverable 3 names `gh-milestone.sh issues` for the fetch. This spec fetches through the new `select` subcommand of the same script (AC-1), which reuses `issues`' `gh` call and dependency filter and leaves its output unchanged. Name it in the final report's deviations.
- **C4 Run-dir layout.** DESIGN §7.1 has fixed, flat artefact names. Bulk adds per-issue `issues/<k>/` subdirs for the spec-analysis artefacts, and sequential adds `index.json`. §7.1 is updated, with no renaming of existing artefacts.

## Assumptions

1. **Assumed:** dependency parsing stays where it is (`gh-milestone.sh`'s existing `depends_on`), and the ordering, cycle detection, AC count, stacking and deterministic recommendation go in one new `select` subcommand of the same script, not in prose. Reason: anything testable belongs in a script (bats with the mocked `gh` proves AC-5), and one subcommand adds no file. **Flag if wrong** (the name `select` is open to a better one).
2. **Assumed:** "same area" and "low risk" stay judgement in the skill, based only on titles and labels, and can only turn a bulk recommendation into sequential. Reason: they can't be made deterministic, and the safe direction is sequential. **Flag if wrong.**
3. **Assumed:** a dependency counts as blocking (for the bulk criterion) when it is anything other than a **closed issue of this milestone**. That includes issues outside the milestone, whose state the listing does not give. Ordering and stacking ignore out-of-milestone edges. Reason: it is conservative, and it is only a recommendation that James confirms. **Flag if wrong.**
4. **Assumed:** the AC-count heuristic is AC-3. An issue with no AC list gives `null`, which counts as not small, so the recommendation is sequential. Reason: it is deterministic and conservative. **Flag if wrong.**
5. **Assumed:** ship is reused by following its files directly. ship gains one-line hooks into ship-milestone's references, and the milestone-specific divergences live only in `bulk.md` and `sequential.md`. No new shared reference file is created. Reason: this adds the fewest files, and `resume` gets the hooks for free because it reads ship. **Flag if wrong.**
6. **Assumed:** `state.schema.json` needs no change. The parent-to-child link is the child's history note `milestone m-<n>` (the `prompt`-marker precedent), and a bulk issue's spec version is the note `spec revision: #<k> v<N>`. The bulk `spec_revision` field stays 1 (unused). Reason: there is no schema migration, and decisions already come from `history`. **Flag if wrong**, if a `spec_revisions` object or a `milestone` field is preferred.
7. **Assumed:** `index.json` has no schema file. `state.sh index` checks every write and bats pins the format. Reason: no file that DESIGN doesn't call for. **Flag if wrong.**
8. **Assumed:** the index holds only what no child `state.json` holds: the order, each child's `stack_on`, and its milestone-level status (`pending|running|done|blocked|failed`). Live detail (stage, gate, PR) is read from the child's `state.json`. Reason: there is one owner per fact, so nothing drifts.
9. **Assumed:** in bulk, QA uses `m-<n>` as `<issue>` (spec file `<e2e_dir>/m-<n>-<slug>.spec.ts`, evidence `docs/qa/m-<n>/`), and every bulk commit by the orchestrator or QA ends `(#a, #b, #c)`. Reason: there is one QA pass, and commits reference every issue. **Flag if wrong.**
10. **Assumed:** the parent `state.json` of a sequential run keeps `stage` `spec_analysis` throughout. Only its `status` means anything (`running`, then `blocked` or `done`). Reason: the stage enum is per pipeline. The SessionStart hint for a stopped milestone therefore names `spec_analysis` (Risk 5).
11. **Assumed:** "depends on an issue whose PR is still open" is decided without a `gh` call. A dependency that was closed when the run was selected is merged, so its dependant is not stacked. A dependency shipped earlier in this run has an open PR (aew never merges), so its dependant is stacked. Reason: no new GitHub read. **Flag if wrong.**
12. **Assumed:** a stack conflict (two open dependencies that are not one chain) stops a sequential run before it starts, like a cycle. Reason: one branch can't hold both, and guessing would ship code that doesn't build. **Flag if wrong.**
13. **Assumed:** a child that ends `failed` stops the sequence just as `blocked` does. The parent becomes `blocked`. The parent is never `failed`. Reason: the milestone can be resumed after James restarts the child with `ship --from` (AC-24).
14. **Assumed:** the milestone report is posted on every issue of the run, including issues not started, but not on closed issues of the milestone that were left out. A failed post only warns. Reason: "each issue in the milestone", and the run is already finished.
15. **Assumed:** in bulk, the whole `manual-tests.md` goes to every issue, and each issue gets the flag. Reason: the cases carry prefixed AC ids, so readers can tell which belong to them, and splitting them would need a parser. **Flag if wrong.**
16. **Assumed:** in bulk, the spec gates run one issue at a time, in issue order, each through gates.md `## Gate: spec` with `<rd>` = `issues/<k>`. A mid-pipeline material answer re-analyses the issues named by `#<k>` (all of them when none is named). **Flag if wrong.**
17. **Assumed:** agent changes are kept to inputs:
    - brief-compiler: the `issues` dispatch field and per-issue spec paths;
    - qa-engineer: bulk `<issue>`;
    - doc-writer: per-issue snapshots from `issues/<k>/`, and one stacked line in the summary naming `base_branch`.

    No agent learns about the index or the sequence. Reason: agents stay testable offline and ignorant of orchestration.
18. **Assumed:** the simulated-run plan is M1–M3 (cap 1 each), B1 (cap 15), Q1 (cap 8, killed, so charged at its cap) and Q2 (cap 12). That totals $38 against a **stop of $45**. The harness is §9's launcher and rails, rebuilt from the README reference copy. The child-3 `blocked` is forced by pre-creating its branch. Reason: these are the cheapest deterministic levers, and resume and the forced block share one sequential milestone. **Flag if wrong** (the budget is James's call).
19. **Assumed:** a milestone argument of `m-<n>` is accepted as the number `n`. Reason: ship's E3 and resume use that form. This is minor.

## Risks

1. **Context growth.** A sequential run drives several full pipelines in one main-thread session, and auto-compaction may drop procedure detail. The mitigation: state and references are re-read at every step, the index and history are the only memory, and an interrupted milestone resumes cheaply (AC-28).
2. **Override drift.** Bulk changes many small things in ship (labels per issue, paths, the AC grep). A missed one fails quietly (for example, labels only on the first issue). The mitigation: the overrides are listed in one `bulk.md` table, ship carries the hook lines, B1 checks labels and comments on every issue, and the `skills.bats` citations resolve.
3. **Stacked PRs after merges.** If James merges child 1 before child 2's PR, the base branch may be deleted. GitHub usually retargets the stacked PR (fact 8). Resume does not re-base, so a long-paused milestone may need a manual base fix. This is documented, not automated.
4. **Mock collision.** The canned `issue-list` is shared with `gh-retro.sh`, so the harness must serve the milestone listing on a call-specific route. `select` may be called twice in a run (selection, then start), so the plan should call it once and keep its output in context, or the harness must answer both calls.
5. **Misleading hint.** The SessionStart hint for a stopped sequential milestone says `stage spec_analysis` (Assumption 10). It is cosmetic and is fixed only by a hook change, which is out of scope.
6. **Inherited resume gap.** The existing ship behaviour also applies to bulk: a resume at `spec_analysis` after answers have been applied does not re-send them. This is not fixed here and is noted for prompt 07.
7. **Spend.** B1 analyses three issues in parallel (three Opus spec-analysers). A material finding under `--auto` still gates and leaves the headless run pending, so the fixture bodies must be tuned (as #201's AC-4 was in §9.5) before the paid run.
8. **Line count.** Ship's `SKILL.md` (255 lines) and the references grow by hook lines only. `ship-milestone/SKILL.md` must stay under 500 lines, so keep the detail in the three references.

## Open questions for human

(none: every decision was taken from project context. The flagged assumptions above, chiefly C1, 3, 6, 9, 11, 12, 15, 16 and 18, are what to check at plan approval.)

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-26T08:42:41Z (spec-review)
- Complexity: NOVEL
- Scale: EPIC
- Reason: a second orchestrator mode with no in-repo analog (bulk fan-out of per-issue analyses, a model-driven sequence of whole ship pipelines, stacked branches, a new script-owned index), 35 ACs and well over 8 tasks across scripts, two skill references, ship hooks, resume/status and paid simulated runs; no `_common.md` risk line is crossed (no schema change, no new dependency, no auth surface).
- Spec content hash (SHA-256): a1ec22d79894b53cfc99e992473b640744861d6c1f6484d68dd6d0da74f4288e (the document above this section, after the review fixes below)
- Review fixes applied in place: AC-10 strips one surrounding pair of quotes from the joined milestone title; AC-21 hands ship's Step 3.3/3.4 stop (fetch failed or issue closed) back to `## After a child` (index `failed`) and states the child `## Gate pending` behaviour; AC-34 keys Q1's kill trigger on child 2's own `state.json`; the conflicts section records `select` as a prompt-wording deviation.
- Platform facts checked against the verifier's findings: V-1 holds (`disable-model-invocation`, `$ARGUMENTS`, `argument-hint`); fact 2 holds (substitution only in the loaded body, so ship-milestone keeps ship's plugin-root rule for when `resume` Reads it); fact 3 holds (default cap 20 concurrent, 5 is well inside; no ordering guarantee, which the design does not need); V-4 holds (main thread only, absent under `--permission-prompts none`, 1–4 questions and 2–4 options per call, "Other" automatic; the three-option mode question fits); fact 6 holds (`agent_type` and `stop_hook_active` in the payload). Facts 5, 7 and 8 were not re-verified; 7 was proved in §9.6 and 5 is mitigated by re-reading.
- Notes for the plan (not blocking):
  - Contracts verified in code: `state.sh init` sets `current` and `base_branch` = default and never checks `current`, so child init is safe; `state.sh index` taking an explicit run id is a deliberate, documented exception to the "acts on `current`" rule and must be stated in its `--help` header; `gh-pr.sh create <id>` and D9 already read `base_branch`; `git-branch.sh create --base` resolves a local branch, so child 1's local branch suffices; the evidence fixture's `startsWith(basename(dirname(dir)) + '-')` works for `m-<n>-<slug>.spec.ts` (Assumption 9 holds); no hook needs a change.
  - C1 is a defensible reading, but DESIGN §10's wording change must be recorded as a deviation (as AC-31 says), not a silent reword; James confirms it at plan approval.
  - Phases C and D both add hook lines to `skills/ship/SKILL.md` and ship's references. They can be planned in parallel, but the plan must declare a cross-phase `depends_on` for those ship edits (or serialise them) so parallel implementation does not conflict-merge.
  - AC-15: say explicitly that after one issue's spec gate is answered and re-analysed, the bulk stage moves to the next `needs_input` issue and goes to the brief only when every issue is `ok`.
  - `select` must reuse `issues`' `JQ_FILTER` and `gh` call, not copy them (AC-1).
  - The budget ($38 of a $45 stop) is plausible against §9.1 (S1 cost $4.42 against a $25 cap); Q1's cap of 8 must cover child 1 in full plus part of child 2, so set the kill stage early in child 2 (for example `brief`) and keep the "spend can pass the cap" rule from §9.1.

<spec-summary>
- Topic: milestone-mode
- Issue: no issue — build prompt `docs/build-prompts/06-milestone-mode.md` (DESIGN.md wins)
- Problem: `ship` delivers one issue; DESIGN §10 needs whole milestones delivered in bulk (one pipeline, one PR) or sequentially (ship per issue in dependency order, stacked PRs). Today `ship` refuses `m-<n>` and `resume`/`status` stop on non-`single` modes.
- ACs (testable):
  1. AC-1–8 scripts: `gh-milestone.sh select` (order, cycle, AC count, `stack_on`, stack conflicts, deterministic recommend + reasons); `state.sh init` bulk `issues/<k>/` subdirs; `state.sh index init|set` owns `index.json`; bats with mocked `gh`, three prompt fixtures plus edge cases; bash 3.2, shellcheck, `--help`; no schema change.
  2. AC-9–13 ship-milestone skill: frontmatter, four files, argument parsing (quoted titles), start order (preflight 1–4, 6, `select`, Check 5), recommendation + one AskUserQuestion or headless rerun hint, cycle/stack-conflict stop before any write.
  3. AC-14–19 bulk: one run `m-<n>`, per-issue fetch/labels, parallel D1 with per-issue revision notes and gates, one brief with prefixed ids, ship stages unchanged, one PR closing all, per-issue snapshots, blocked on every issue.
  4. AC-20–24 sequential: index, children run ship Step 3 with three substitutions then ship's stages, hand-back points (final report, blocked, plan-gate stop, Step 3.3/3.4), stacked PR base and intro, stop on blocked/failed, Check 5 child exception.
  5. AC-25 no copy-paste (enforced by `skills.bats`); AC-26 milestone report on every run issue; AC-27 final report lines.
  6. AC-28–30 resume (bulk like single; sequential via `sequential.md ## Resume`) and status (index table), `skills.bats`.
  7. AC-31 docs (DESIGN §7.1/§9/§10, run-protocol, github-ops, README, CHANGELOG, CLAUDE.md, project map).
  8. AC-32–35 paid simulated runs M1–M3, B1, Q1 (kill in child 2), Q2 (resume, child 3 forced blocked), recorded in README §10.
- Scope in: the two scripts + bats + fixtures; `skills/ship-milestone/` (four files); one-line hooks in ship and its references; resume, status; input-only changes to brief-compiler, qa-engineer, doc-writer; docs; `skills.bats`; simulated runs.
- Scope out: merging/retargeting PRs; re-checking dependency PR state on GitHub; parallel children; an `index.json` schema; a milestone `prompt`; hook changes; real-GitHub runs; ship's inherited resume-after-answers gap.
- Context manifest (key references):
  - docs/DESIGN.md §7.1, §7.2, §9, §10 — the mode spec and the layout and resume lines that change
  - skills/ship/SKILL.md + references/{preflight,dispatch,gates,routing,pr,final-report}.md — the reused procedure and hook points
  - scripts/gh-milestone.sh, scripts/state.sh (+ bats) — patterns for `select` and `index`
  - scripts/git-branch.sh, scripts/gh-pr.sh — stacking and PR base already supported
  - skills/resume/SKILL.md, skills/status/SKILL.md — the milestone stops to remove
  - agents/{brief-compiler,qa-engineer,doc-writer}.md — single-issue inputs to extend
  - tests/scripts/skills.bats, tests/scripts/helpers/bin/gh, tests/agent-smoke/README.md §9 — enforcement, mock routes, harness and ledger
- Assumptions (high-stakes only, marked "flag if wrong"):
  - C1: "5 ACs or fewer once analysed" is the script's quick AC-list count, not a spec-analyser pass (DESIGN §10 deviation)
  - Blocking dependency = anything but a closed issue of this milestone; stacking is decided without a `gh` call (Assumptions 3, 11)
  - No schema change: child link and bulk spec versions live in `history` notes (Assumption 6)
  - Stack conflicts stop a sequential run before any write (Assumption 12)
  - Simulated-run budget $38 against a $45 stop (Assumption 18, James's call)
- Complexity: NOVEL
- Scale: EPIC
- Spec content hash: a1ec22d79894b53cfc99e992473b640744861d6c1f6484d68dd6d0da74f4288e
</spec-summary>

<epic-decomposition>
- phase: A
  title: Deterministic layer for milestones
  scope: `gh-milestone.sh select`, `state.sh init` bulk subdirs, `state.sh index init|set`, three prompt fixtures plus edge-case fixtures, bats
  acs: [1, 2, 3, 4, 5, 6, 7, 8]
  depends_on: []
  depth: lean
  risk: none
- phase: B
  title: ship-milestone entry, mode selection and shared report
  scope: `SKILL.md` (frontmatter, arguments, start order, milestone report, final report), `references/mode-selection.md`, cycle and stack-conflict stops, ship E3 wording
  acs: [9, 10, 11, 12, 13, 26, 27]
  depends_on: [A]
  depth: lean
  risk: none
- phase: C
  title: Bulk mode
  scope: `references/bulk.md` (override table), ship bulk hook lines, gates/preflight/pr/final-report bulk overrides, brief-compiler `issues` input, qa-engineer bulk `<issue>`, doc-writer per-issue snapshots
  acs: [14, 15, 16, 17, 18, 19, 25]
  depends_on: [B]
  depth: full
  risk: none
- phase: D
  title: Sequential mode
  scope: `references/sequential.md` (start, start a child, after a child, resume), ship child hand-back hooks, preflight Check 5 child exception, stacked base and doc-writer stacked summary line
  acs: [20, 21, 22, 23, 24, 25]
  depends_on: [B]
  depth: full
  risk: none
- phase: E
  title: resume, status and static checks
  scope: resume bulk and sequential entry, status index table and next-action rows, `skills.bats` (entry skill, citations, tests 17 and 18, no-`## Stage:` check)
  acs: [28, 29, 30]
  depends_on: [C, D]
  depth: lean
  risk: none
- phase: F
  title: Documentation and simulated runs
  scope: DESIGN §7.1/§9/§10 with recorded deviations, run-protocol, github-ops, README, CHANGELOG, CLAUDE.md, project map; paid runs M1–M3, B1, Q1, Q2 recorded in README §10
  acs: [31, 32, 33, 34, 35]
  depends_on: [E]
  depth: full
  risk: none
</epic-decomposition>
