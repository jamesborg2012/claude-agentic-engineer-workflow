# Commits, pull request and finish

Read at the standards, docs and pr stages. `<id>`, `<n>`, `<rd>` and the script names are as in `SKILL.md` `## Run variables` and `SKILL.md` `## Plugin root`. Script failures follow `routing.md` `## Script failures`.

## Commit rules

Every commit the orchestrator makes follows these rules.

- The message is conventional and ends `(#<n>)`. Its only trailer is a last `-m "Co-Authored-By: Claude <noreply@anthropic.com>"`, even if the session asks for another attribution line, and with no model name.
- Stage explicit paths only: `git add -- <paths>`, then `git commit -m "<message>" -m "Co-Authored-By: Claude <noreply@anthropic.com>"`. Never stage everything.
- Commit only on the run branch: `git branch --show-current` must equal `state.sh get branch`. If it does not, stop on the blocked path (`SKILL.md` `## Blocked path`).
- Skip a commit when `git status --porcelain -- <paths>` prints nothing.

## Standards commit

Run after a standards `ok`.

- Paths: `docs/standards`.
- Message: `docs(standards): <add or update> <profile list> standards (#<n>)`. Take the profiles from the standards-setter's ARTEFACTS (`docs/standards/<profile>.md`). Use `add` when the files are new, otherwise `update`.

## Docs and memory commits

Run after a docs `ok`, in this order.

1. The doc-writer's outputs. Take the ARTEFACTS paths that are outside `.aew/` (expected: `docs/specs/<n>-<slug>.md` and `CLAUDE.md`) and commit them with `docs: add the issue spec<, and update CLAUDE.md> (#<n>)`. Drop the part in angle brackets when `CLAUDE.md` is not among the paths. The orchestrator makes this commit, not the doc-writer.
2. Agent memory. If `git status --porcelain -- .claude/agent-memory` is not empty, run `git add -- .claude/agent-memory` and commit with `chore(aew): update agent memory (#<n>)`. This is one commit per run, after the docs commit.
3. Run `git status --porcelain --untracked-files=all`. List anything left as a warning in the final report. Never commit it.

## Push and pull request

1. `git-branch.sh push`.
2. Check the PR introduction. `check-pr-intro.sh .aew/runs/<id>/pr-body.md --issues <count>`, where `<count>` is `jq '.issues | length' .aew/runs/<id>/state.json`. Exit 0: continue to step 3.
   - Any non-zero exit (a failed check, or a script error): re-dispatch D13 (doc-writer) once with `intro_check_output` set to the check's stdout. Do not rewind the stage: no `state.sh stage` call, because the doc-writer has no gate hook and only edits `pr-body.md`. Then run the check again.
   - If it still fails, carry on to step 3 anyway: the introduction never blocks a PR. Keep the check's last output for the final report (a `Warning` line) and for the retro item below.
   - This step sits before the create or update call, so a resume's update path is covered the same way and rewrites the whole body, with one introduction.
3. Read `state.sh get pr`.
   - Empty or null: `gh-pr.sh create <id> .aew/runs/<id>/pr-body.md`. It prints the PR number. Then `state.sh set pr <number>`.
   - Set: `gh-pr.sh update <pr> .aew/runs/<id>/pr-body.md --run <id>`. Never create a second PR.
4. The PR URL for the report: `jq -r '.url | sub("/issues/[0-9]+$"; "/pull/" + $pr)' --arg pr <pr> .aew/runs/<id>/issue.json` (the `--arg` goes after the filter, and `<pr>` is the plain PR number), for example `https://github.com/acme/static-shop/pull/12`.
5. The `ready-for-review` label is set in `## Finish`, not here.

## Manual tests

Count the cases: `grep -c '^- \[ \]' .aew/runs/<id>/manual-tests.md`. A missing file or a count of 0 skips this section (`grep -c` exits 1 on 0, so do not treat that as a failure).

If the count is 1 or more: `gh-issue.sh manual-tests <n> .aew/runs/<id>/manual-tests.md`, then `gh-labels.sh flag <n> add manual-test-required`.

## Retro

If the introduction check still failed after the retry, first append one item to `.aew/runs/<id>/retro.md`: a `###` heading (`PR introduction failed the check`), then a line on what happened (the doc-writer's introduction broke the rule after one retry) and the improvement to the doc-writer prompt, quoting the final check output. This is the only edit the orchestrator makes to that file.

1. Find the source repo: `jq -r '.url | capture("^https?://[^/]+/(?<r>[^/]+/[^/]+)/issues/").r' .aew/runs/<id>/issue.json` (a dry run gives `acme/static-shop`).
2. `gh-retro.sh file .aew/runs/<id>/retro.md <owner/repo> <id>`. Keep its stdout lines for the final report.
3. A non-zero exit only warns. Note it for the report and continue: the retro never blocks a run.

## Finish

In this order:

1. `gh-labels.sh stage <n> ready-for-review`.
2. `state.sh status done`.
3. `state.sh current clear`.
4. Go to `SKILL.md` `## Final report`. After the clear, read state with `jq -r .<field> .aew/runs/<id>/state.json`.
