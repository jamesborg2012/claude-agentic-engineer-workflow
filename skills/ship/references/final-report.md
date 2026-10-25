# Final report

Printed once, as the last thing `ship` does, for every outcome: `done`, `blocked` and `failed` (DESIGN §9). Counts come from `grep -c` and `jq`; the artefacts are never opened.

## Format

Print exactly these lines. Text in angle brackets is filled in.

```
aew ship #<n> <title>: <done | blocked | failed>
PR: <url>
ACs passed: <passed>/<total>
Review cycles: <review_cycle>/<max_review_cycles>
Fix cycles: <fix_cycle>/<max_fix_cycles>
Manual tests outstanding: <count>
Retro items filed: <count> (<created #a, commented #b>)
Next: <next action>
```

The `Next:` line by outcome:

- `done`: `review and merge the PR`.
- `blocked`: `Resume with /aew:resume <id>`.
- `failed`: `restart with /aew:ship <n> --from <stage>`.

Warnings follow as `Warning: <text>` lines, one each: preflight check 6, the ahead-only warning of check 4, leftover dirty paths, a failed retro, and a failed `gh` call on the blocked path (name the call).

## Counting

Count, never read. `<id>` is the run id.

- ACs passed: `grep -c '^- \[x\] AC-' .aew/runs/<id>/10-summary.md`. Total: `grep -cE '^- \[[ x]\] AC-' .aew/runs/<id>/10-summary.md`.
- Manual tests outstanding: `grep -c '^- \[ \]' .aew/runs/<id>/manual-tests.md`.
- Retro items: the number of `created #` and `commented #` lines that `gh-retro.sh` printed this session.
- Title, PR, stage and cycles: `jq -r '.title, .pr, .stage, .review_cycle, .fix_cycle' .aew/runs/<id>/state.json`. The PR URL is built as in `pr.md` `## Push and pull request` step 3. Do not use `state.sh get`: it reads only the run named in `.aew/runs/current`, which `pr.md` `## Finish` and the plan-gate stop have already cleared, and it exits 1 with "no current run".
- Limits: `SKILL.md` `## Run variables`.

`grep -c` exits 1 when the count is 0. Read the printed number, not the exit status. A missing file counts as 0 (`n/a` for the ACs).

## Blocked and failed runs

Use the same format, with these changes.

- Replace `PR:` with `Reason: <reason>`, taken from the agent SUMMARY or the script error. Keep `PR: <url>` as well when `state.pr` is set.
- `ACs passed: n/a` when `10-summary.md` is absent, or when `stage` is not `pr`. The doc-writer writes the summary at the docs stage, so before `pr` any copy is left from an earlier pass (a `--from` restart) and is not a result of this run.
- A stop at the plan gate (outcome `failed`) adds the line `The awaiting-approval label stays on the issue.`
