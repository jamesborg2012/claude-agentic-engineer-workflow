# Bulk mode

Read by `ship-milestone` after mode selection, by `ship`'s hook lines (each names this file) and by `resume`. A bulk run is one run `<id>` (`m-<number>`, mode `bulk`) that goes through ship's own stage sections once, on one branch, with one PR. This file holds only what differs. Read every literal `${CLAUDE_PLUGIN_ROOT}` here as the plugin root stated in `ship-milestone/SKILL.md` `## Plugin root` (or in `resume`'s own statement of it), and a bare `state.sh …`, `gh-issue.sh …`, `gh-labels.sh …` or `git-branch.sh …` as that root's `scripts/` file by absolute path.

Citations: ship's skill file is always `ship/SKILL.md`, ship-milestone's is always `ship-milestone/SKILL.md`, and ship's references (`dispatch.md`, `gates.md`, `routing.md`, `pr.md`, `final-report.md`, `preflight.md`) are named bare. `<id>` is the run id `m-<number>`, `<number>` is the milestone number (`<mn>` in `ship-milestone/SKILL.md` `## Run variables`), `<k>` is one issue of the run, and `<rd_k>` is `.aew/runs/<id>/issues/<k>`.

## Overrides

Apply each row wherever ship's files reach the place in the first column.

| Where | Single run | Bulk run |
|---|---|---|
| 1. Run variables `<n>` (`ship/SKILL.md` `## Run variables`) | the issue | each issue `<k>` of `issues`, ascending. Every `gh-labels.sh stage <n> …`, `gh-labels.sh flag <n> …`, `gh-issue.sh comment <n> …` and `gh-issue.sh manual-tests <n> …` call runs once per issue, except where rows 8 and 9 name one issue |
| 2. Printed `#<n>` (gate questions, the `plan-approval` question, `ship/SKILL.md` `## Gate pending`'s first line, the final report's first line) | `#<n>` | the run id `<id>`, with no `#`. A per-issue spec-gate question is prefixed `#<k>: ` |
| 3. D1 and D2 (`dispatch.md` `## Dispatch table`) | `run_dir: .aew/runs/<id>` and `spec_version` from `state.sh get spec_revision` | `run_dir: .aew/runs/<id>/issues/<k>` and `spec_version: <v_k + 1>` (row 7). Required files: `issues/<k>/00-issue-original.md` and `issues/<k>/issue.json` (D2 adds `issues/<k>/01-spec-analysis.md`). `description` is `spec_analysis <id> #<k>` |
| 4. D3 | no `issues` field | the fields are `run_dir: .aew/runs/<id>`, `mode: pipeline`, then `issues: <a,b,c>`, taken from the issue list filter below (`### Filters`, filter F1). Required files: `issues/<k>/spec-final.md` and `issues/<k>/issue.json` for every k |
| 5. D13 | run-root `spec-final.md` and `issue.json` | required files `issues/<k>/spec-final.md` and `issues/<k>/issue.json` for every k, and `state.json`. Fields unchanged |
| 6. `## Required inputs per stage` (`dispatch.md`) | files at the run root | `spec_analysis`: per issue as row 3. `brief`: per issue as row 4. `docs`: per issue as row 5, plus the unchanged `08-qa-report-<fix_cycle+1>.md` rule. Other stages are unchanged |
| 7. `spec_revision` | `state.sh get spec_revision` | `<v_k>`, from the revision filter below (`### Filters`, filter F2). With no note it is 1. `state.sh set spec_revision` is never called in a bulk run |
| 8. `gates.md` `## Gate: spec` | `<rd>` is `.aew/runs/<id>`, `<n>` is the issue, note `gate:spec 01-spec-analysis.md` | `<rd>` is `.aew/runs/<id>/issues/<k>` and `<n>` is `k`. Step 1's note is `gate:spec issues/<k>/01-spec-analysis.md`, and its label goes on issue k only. Step 4's `gh-labels.sh stage <k> analysing` goes on k only, and D2 goes to k only. After the D2 return check (`dispatch.md` `## Return check`, retried once as `dispatch.md` `## Retries`), go to `## Spec analysis` step 1, not `ship/SKILL.md` `## Stage: spec_analysis` step 4 |
| 9. `gates.md` `## Recording a spec revision` | paths under `.aew/runs/<id>/`, version compared with `spec_revision`, step 5 sets `spec_revision` | for issue k, every `.aew/runs/<id>/` path is `.aew/runs/<id>/issues/<k>/`, `<n>` is `k`, the version check compares `jq '.version' …` with `<v_k>` (row 7), and step 5 is `state.sh status running --note "spec revision: #<k> v<N>"`. The idempotency rule is unchanged: no post when the version is not greater than `<v_k>` |
| 10. The other four gates (`plan-challenge`, `triage`, `spec-ambiguity`, `plan-approval`) | label on the issue, step 4 re-runs D2 on the run | the pending status writes are unchanged and the label goes on every issue. Step 4 of `plan-challenge`, `triage` and `spec-ambiguity` is `## Re-analysis`. `plan-approval` is unchanged apart from row 2 |
| 11. `gates.md` `## Re-asking a pending gate` | `<rd>` is `.aew/runs/<id>` | a note `gate:spec issues/<k>/01-spec-analysis.md` gives `<rd>` `.aew/runs/<id>/issues/<k>` and `<n>` `k` (`resume` uses this) |
| 12. `pr.md` `## Commit rules` | suffix `(#<n>)` | every issue, from the suffix filter below (`### Filters`, filter F3), for example `(#12, #13, #14)`. This also applies to the standards commit and the memory commit |
| 13. `pr.md` `## Docs and memory commits` step 1 | `docs: add the issue spec<, and update CLAUDE.md> (#<n>)` | `docs: add the issue specs<, and update CLAUDE.md> (#12, #13, #14)`. The paths rule is unchanged (every ARTEFACTS path outside `.aew/`: one `docs/specs/<k>-<slug>.md` per issue, and `CLAUDE.md`) |
| 14. `issue.json` in `pr.md` `## Push and pull request` step 4 (the PR URL) and `pr.md` `## Retro` step 1 (the repo) | `.aew/runs/<id>/issue.json` | `.aew/runs/<id>/issues/<first issue>/issue.json`. `gh-pr.sh create <id>` and `check-pr-intro.sh … --issues <count>` are unchanged |
| 15. `pr.md` `## Manual tests` | the issue | the whole `manual-tests.md` goes to every issue (`gh-issue.sh manual-tests <k> …`), and every issue gets `gh-labels.sh flag <k> add manual-test-required` |
| 16. `pr.md` `## Finish` step 1 | `ready-for-review` on the issue | `ready-for-review` on every issue. The retro is filed once, as now |
| 17. `final-report.md` | first line `aew ship #<n> <title>: …`, AC counts without a prefix | the first line is `aew ship <id> <title>: ` followed by `done`, `blocked` or `failed`. The AC counts are `grep -c '^- \[x\] #[0-9][0-9]*-AC-' .aew/runs/<id>/10-summary.md` and `grep -cE '^- \[[ x]\] #[0-9]+-AC-' .aew/runs/<id>/10-summary.md`. `failed` reads `Next: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk`. After the report, go to `## Report` |
| 18. `ship/SKILL.md` `## Blocked path` | steps 2 and 3 on the issue | steps 2 (`gh-issue.sh comment <k> .aew/runs/blocked-<id>.md`) and 3 (`gh-labels.sh stage <k> blocked`) run once per issue, and step 4 runs once. A failed call for one issue never skips the others or step 4 |
| 19. Agents, for reference (no orchestrator action) | `<issue>` is the issue number | the developer and senior-engineer are already bulk-aware. qa-engineer's `<issue>` is `<id>` (evidence under `docs/qa/<id>/`). doc-writer writes one snapshot per issue. The `SubagentStop` gates read `.aew/runs/current`, which is `<id>` |

Everything else in ship's files applies unchanged: one standards pass, one plan (D6 ∥ D7), one plan gate unless `auto`, one develop, review and QA loop, one docs pass and one PR.

### Filters

Run each with the Bash tool exactly as written, with `<id>` and `<k>` filled in. They sit outside the table so that no pipe in them is read as a table column.

F1, the issue list (row 4):

```
jq -r '.issues | map(tostring) | join(",")' .aew/runs/<id>/state.json
```

F2, the revision `<v_k>` of issue k (row 7):

```
jq -r --arg k <k> '[.history[] | (.note // "") | select(startswith("spec revision: #" + $k + " v")) | ltrimstr("spec revision: #" + $k + " v") | tonumber] | max // 1' .aew/runs/<id>/state.json
```

F3, the commit suffix (row 12):

```
jq -r '.issues | map("#" + tostring) | join(", ")' .aew/runs/<id>/state.json
```

## Start

Reached from `ship-milestone/SKILL.md` `## Step 5. Start the run`, with `<number>`, the milestone title, the open issue numbers ascending and `auto` in context. Nothing has been written yet.

1. Run `state.sh init <id> --issues <a,b,c> --mode bulk --title "<milestone title>"`, adding `--auto` when given. `<a,b,c>` is the open issues from `select`, ascending. The title is a double-quoted literal with `"`, `$`, backtick and `\` escaped (ship's `## Rules`). This also creates `issues/<k>/` for each issue.
2. For each k, ascending: `gh-issue.sh fetch <k> .aew/runs/<id>/issues/<k>`. On failure run `state.sh status failed --note "fetch failed: #<k>: <first stderr line>"`, then `state.sh current clear`, then print `Could not fetch issue #<k>: <reason>. Fix it, then remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.` and stop. No label has been set and no milestone report is posted, because nothing ran.
3. For each k: `jq -r .state .aew/runs/<id>/issues/<k>/issue.json`. `CLOSED` takes the same three actions as step 2, with the reason `issue #<k> is closed`.
4. For each k: `gh-labels.sh stage <k> analysing`.
5. Compute the slug with `jq -r '.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | .[0:40] | rtrimstr("-") | if . == "" then "milestone-<number>" else . end' .aew/runs/<id>/state.json`, then run `git-branch.sh create <id> <slug>` (it prints the branch name, from `git.milestone_branch_pattern`), then `state.sh set branch <name>`. A failure goes to `ship/SKILL.md` `## Blocked path` (`routing.md` `## Script failures`), with the overrides above.
6. Go to `## Spec analysis`. `state.sh init` has already set the stage `spec_analysis`, and step 4 set the labels.

## Spec analysis

Entered from `ship/SKILL.md` `## Stage: spec_analysis` (after its step 1), from `## Start`, from a per-issue spec gate (row 8) and from `## Re-analysis`. It decides from each issue's file every time, so a fresh start, a resume at `spec_analysis` and the return from a gate all take the same path.

1. **Classify** each issue k, ascending: `test -f .aew/runs/<id>/issues/<k>/01-spec-analysis.md && echo yes || echo no`. On `yes`, run `grep -v '^$' .aew/runs/<id>/issues/<k>/01-spec-analysis.md | tail -n 4` and read its first line. `STATUS: ok` is done, `STATUS: needs_input` is waiting, and anything else (`no`, `blocked`, `failed`, an invalid block) is to run.
2. **Dispatch** every to-run issue. Check its required files (row 3, `test -f … && echo yes || echo no`; a missing one goes to `ship/SKILL.md` `## Blocked path`), read its `<v_k>` (row 7), then send one D1 per issue, all in one assistant message with no other tool call in it (ship's `## Rules`). The prompt per issue:

   ```
   run_dir: .aew/runs/m-7/issues/12
   spec_version: 2
   ```

   Skip this step when no issue is to run.
3. **Check each return** with `dispatch.md` `## Return check`. Retry a `failed` or invalid one once, on its own (`dispatch.md` `## Retries`); a second failure goes to `ship/SKILL.md` `## Blocked path`. A `blocked` goes to `routing.md` `## Agent status routing`. One issue's retry never re-sends another.
4. **Record** each done issue's revision, ascending: `gates.md` `## Recording a spec revision` under row 9. It is idempotent, so issues recorded on an earlier pass are skipped by its version check.
5. **Gate** the first waiting issue, ascending: `gates.md` `## Gate: spec` under row 8 (pending note `gate:spec issues/<k>/01-spec-analysis.md`, label on k only, questions prefixed `#<k>: `). Gates run one at a time: no second gate is set while one is open. Its step 4 dispatches D2 for k alone, checks that return, and comes back to step 1. With no answer, `ship/SKILL.md` `## Gate pending` stops the run, and the other issues stay as their files say.
6. **Exit** when step 1 finds every issue done (none to run, none waiting) and step 4 has run: go to `ship/SKILL.md` `## Stage: brief`, whose Entry sets `planning` on every issue (row 1).

So after one issue's gate is answered and re-analysed, the stage moves on to the next issue still waiting, and goes to the brief only when every issue is `ok`.

## Re-analysis

Replaces step 4 of `gates.md` `## Gate: plan-challenge`, `gates.md` `## Gate: triage` and `gates.md` `## Gate: spec-ambiguity` in a bulk run.

1. **Group the answers** by issue: a question naming `#<k>` of the run goes to k (to each k it names); a question naming none goes to every issue.
2. Run `state.sh stage spec_analysis --note "answers: gate:<gate-id>"`, then `gh-labels.sh stage <k> analysing` for every issue.
3. For each issue with answers, read `<v_k>` and `grep -c '^### Q[0-9]' .aew/runs/<id>/issues/<k>/01-spec-analysis.md` (`grep -c` prints `0` and exits 1 when there are none). Then send one D2 per issue, all in one assistant message: `run_dir`, `spec_version: <v_k + 1>`, `answers:` and that issue's lines `Q<j>: <question> => <answer>`, with j continuing after the count.
4. Check each return as in `## Spec analysis` step 3. Any `needs_input` goes to `## Spec analysis` step 1, whose exit is a plain `ship/SKILL.md` `## Stage: brief`. Otherwise record each re-analysed issue's revision (`## Spec analysis` step 4).
5. **Exit.** After `plan-challenge` or `triage`: `ship/SKILL.md` `## Stage: brief`. After `spec-ambiguity`: count `jq -s '[.[].changes[] | select(.type == "material")] | length' <files>`, where `<files>` are the re-analysed issues' `.aew/runs/<id>/issues/<k>/spec-changes.json` only (the others are from an earlier pass). Greater than 0: `ship/SKILL.md` `## Stage: brief`. 0: `ship/SKILL.md` `## Stage: brief` entered with the note `spec-ambiguity: non-material`, as in `gates.md` `## Gate: spec-ambiguity` step 4.

## Report

Reached from `ship/SKILL.md` `## Final report` for every outcome. After ship's own report, follow `ship-milestone/SKILL.md` `## Milestone report`, then `ship-milestone/SKILL.md` `## Final report`, which is printed last. `current` may already be cleared (`pr.md` `## Finish`, the plan-gate stop) or kept (the blocked path), so those sections read the run with `jq … .aew/runs/<id>/state.json`.
