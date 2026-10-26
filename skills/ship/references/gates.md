# Gates

Read at `SKILL.md` `## Stage: spec_analysis`, `SKILL.md` `## Stage: plan` and `SKILL.md` `## Stage: qa`, and by `resume`. Every `${CLAUDE_PLUGIN_ROOT}` here is the plugin root stated in `SKILL.md` `## Plugin root`, and a bare `state.sh …` or `gh-labels.sh …` is that root's `scripts/` file by absolute path. `<rd>` is `.aew/runs/<id>`.

Each `## Gate: <id>` section has four steps: set pending, read, ask, apply the answer.

## Gate ids and pending state

The gate ids are `spec`, `plan-challenge`, `triage`, `spec-ambiguity` and `plan-approval`. A gate writes its pending status and label first, so `resume` can find it.

| Gate | Status write | Label write | Bounded read (step 2) |
|---|---|---|---|
| `spec` | `state.sh status awaiting_input --note "gate:spec 01-spec-analysis.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Questions` of `01-spec-analysis.md` |
| `plan-challenge` | `state.sh status awaiting_input --note "gate:plan-challenge 05-plan.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Challenges to the spec` of `05-plan.md` |
| `triage` | `state.sh status awaiting_input --note "gate:triage 09-triage-<k>.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md` |
| `spec-ambiguity` | `state.sh status awaiting_input --note "gate:spec-ambiguity 08-qa-report-<k>.md"` | `gh-labels.sh stage <n> awaiting-input` | the triage table and the `### TC-<n>:` entries classed `spec_ambiguity` |
| `plan-approval` | `state.sh status awaiting_plan_approval --note "gate:plan-approval 05-plan.md"` | `gh-labels.sh stage <n> awaiting-approval` | `05-plan.md` in full |

The pending gate is read back from `history` with:

`jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' .aew/runs/<id>/state.json`

In prompt mode (`/aew:prompt`), skip every `gh-labels.sh stage` call in this file and keep the `gh-labels.sh flag` call.

"Prompt mode" in this file means that this check prints `prompt`, that is, the `prompt` marker is present and `branch` is null. Never test the marker on its own.

`jq -r 'if ([.history[] | select(.note == "prompt")] | length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json`

The four `awaiting_input` gates never skip, even with `--auto`. Only `plan-approval` is skippable (`auto` is true, or the plan gate is `off`).

In a bulk run (`bulk.md` `## Overrides`), the `spec` gate is per issue: `<rd>` is `.aew/runs/<id>/issues/<k>`, `<n>` is `k`, the note is `gate:spec issues/<k>/01-spec-analysis.md`, its label goes on that issue only, and its step 4 returns to `bulk.md` `## Spec analysis`. Every other gate's label goes on every issue, and step 4 of `plan-challenge`, `triage` and `spec-ambiguity` is `bulk.md` `## Re-analysis`.

## Asking

- AskUserQuestion exists on the main thread only. Subagents never have it, which is why agents return `needs_input`. If it is not among your tools, go straight to `SKILL.md` `## Gate pending` and do not call it.
- Ask one question per source question. The recommended answer is the first option, and its label ends with ` (recommended)`. The other options are the listed alternatives. The tool adds free-text "Other" itself.
- If the tool's schema caps the questions per call or the options per question, split into several calls in question order. Never drop a question or the recommended option: keep the extra alternatives in the question text.
- The answer is the chosen label without ` (recommended)`, or the free text.
- A refusal or an empty answer goes to `SKILL.md` `## Gate pending`. The status and label from step 1 stay as they are.

## Gate: spec

Entered from `SKILL.md` `## Stage: spec_analysis` when spec-analyser returns `needs_input`.

1. Set pending: `state.sh status awaiting_input --note "gate:spec 01-spec-analysis.md"`, then `gh-labels.sh stage <n> awaiting-input` (skipped in prompt mode).
2. Read: `awk '/^## Questions$/{f=1;next} /^## |^STATUS:/{f=0} f' <rd>/01-spec-analysis.md`. Each `### Q<k>. <question>` is a question, its `**Recommended answer:**` is the first option, and its `**Alternatives:**` (split on `;`) are the rest.
3. Ask (`## Asking`).
4. Apply the answer: `state.sh stage spec_analysis --note "answers: gate:spec"`, then `gh-labels.sh stage <n> analysing` (skipped in prompt mode), then dispatch row D2 with `answers:` and one `Q<k>: <answer>` line per answer. Then run the prompt-mode check from `## Gate ids and pending state`.
   - `prompt`: return to the `prompt` skill's own step after its spec-analyser dispatch. Ship's spec_analysis exit goes on to D3, which prompt must not run.
   - `ship`: go to `SKILL.md` `## Stage: spec_analysis` step 4 (the return check).

   spec-analyser may return `needs_input` again for an unclear answer, which loops back to this gate.

## Gate: plan-challenge

Entered from `SKILL.md` `## Stage: plan` when senior-engineer returns `needs_input`. One rule for every answer.

1. Set pending: `state.sh status awaiting_input --note "gate:plan-challenge 05-plan.md"`, then `gh-labels.sh stage <n> awaiting-input`.
2. Read: `awk '/^## Challenges to the spec$/{f=1;next} /^## /{f=0} f' <rd>/05-plan.md`. Take each material challenge's question, its recommended answer and its alternatives.
3. Ask (`## Asking`).
4. Apply: every answer (accept, other or decline) goes the same way. `state.sh stage spec_analysis --note "answers: gate:plan-challenge"`, then `gh-labels.sh stage <n> analysing`, then dispatch row D2 with answers written `Q<k>: <question> => <answer>`, where k continues after `grep -c '^### Q[0-9]' <rd>/01-spec-analysis.md`. On `ok`, run `## Recording a spec revision`, then go to `SKILL.md` `## Stage: brief`. That re-runs brief, standards, QA phase A and the plan in parallel, and the plan gate. Counters are kept.

## Gate: triage

Entered from `routing.md` `## QA loop` when senior-engineer (triage mode) returns `needs_input`.

1. Set pending: `state.sh status awaiting_input --note "gate:triage 09-triage-<k>.md"` (`<k>` is the cycle), then `gh-labels.sh stage <n> awaiting-input`.
2. Read: `awk '/^## (Root cause|Where the divergence started)$/{f=1;print;next} /^## /{f=0} f' <rd>/09-triage-<k>.md`. The question and the recommended answer are in that text or in the triage return's SUMMARY, which is already in context (the agent does not fix where it puts them), so use both.
3. Ask (`## Asking`).
4. Apply: as `## Gate: plan-challenge` step 4 (the change is material by definition), with the note `answers: gate:triage`. Then go to `SKILL.md` `## Stage: brief`.

## Gate: spec-ambiguity

Entered from `routing.md` `## QA loop` when the QA report classes test cases as `spec_ambiguity`.

1. Set pending: `state.sh status awaiting_input --note "gate:spec-ambiguity 08-qa-report-<k>.md"`, then `gh-labels.sh stage <n> awaiting-input`.
2. Read the triage rows (the command in `routing.md` `## QA loop`), then each `spec_ambiguity` entry: `awk -v h='### <TC>:' 'index($0,h)==1{f=1;print;next} /^### |^## |^STATUS:/{f=0} f' <rd>/08-qa-report-<k>.md`.
3. Ask one question per test case, `<TC>: the spec is ambiguous - <summary>. Which behaviour is intended?`, with the options `<Expected> (recommended)` and `<Actual>`. The recommendation follows the test, which was written from the brief.
4. Apply: `state.sh stage spec_analysis --note "answers: gate:spec-ambiguity"`, then `gh-labels.sh stage <n> analysing`, then dispatch row D2 with answers written `Q<k>: <question> => <answer>` (numbering as in `## Gate: plan-challenge` step 4). On `ok`, run `## Recording a spec revision`. Then decide with `jq '[.changes[] | select(.type == "material")] | length' <rd>/spec-changes.json`.
   - Greater than 0: go to `SKILL.md` `## Stage: brief`. Every stage from brief re-runs.
   - 0: go to `SKILL.md` `## Stage: brief`, entered with the note `spec-ambiguity: non-material`. That note is the persisted decision to continue at `SKILL.md` `## Stage: qa` after the brief, so it survives a resume (`SKILL.md` `## Stage: brief` step 5).

## Gate: plan-approval

Entered from `SKILL.md` `## Stage: plan` step 5 when `auto` is false and the plan gate is `on`.

1. Set pending: `state.sh status awaiting_plan_approval --note "gate:plan-approval 05-plan.md"`, then `gh-labels.sh stage <n> awaiting-approval`.
2. Read `05-plan.md` in full (the only full read).
3. Write a summary of 25 lines or fewer: the headline approach, the work packages (and which run in parallel), the challenges resolved, the risks, and whether every AC is mapped. Ask one question whose question text is that summary, then a blank line, then the path `.aew/runs/<id>/05-plan.md` on its own line, then a blank line, then `Approve the plan for #<n>?`, with the options `Approve`, `Request changes` and `Stop`. The summary goes inside the question text, not only in a message before it, because the question is what the user sees at the gate: a gate asked without the summary and the path is a defect (prompt 07's first attended run asked the bare question). Free text counts as Request changes, with the text as the notes. `Request changes` without text gets one follow-up question for the notes (answered through "Other"). If nothing comes back, the gate stays pending (`SKILL.md` `## Gate pending`).
4. Apply:
   - Approve: go to `SKILL.md` `## Stage: develop`.
   - Request changes: go to `SKILL.md` `## Stage: plan` with the note `plan revision: request changes` and `notes:` set to the answer (dispatch row D7 only; QA phase A is not re-run). Then return to this gate.
   - Stop: `state.sh status failed --note "stopped at the plan gate"`, then `state.sh current clear`, then `SKILL.md` `## Final report` (outcome `failed`). The stage label stays `awaiting-approval`, because the label set has none for `failed`; the final report says so.

## Recording a spec revision

Run it after spec-analyser (first run or D2) returns `ok`. It runs only when `jq '.changes | length' <rd>/spec-changes.json` is greater than 0 and `jq '.version' <rd>/spec-changes.json` is greater than `state.sh get spec_revision`. Otherwise skip it, so a resumed or repeated `ok` never posts twice. `<N>` is that version.

1. Render the comment to a file, so the JSON never enters context:

   ```sh
   jq -r '
     def cell: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
     "## Spec revision v\(.version)",
     "",
     "The issue body now shows spec v\(.version) on top. Earlier versions are kept below it, collapsed. Nothing the author wrote has been deleted.",
     "",
     "| Change | Type | Rationale | Source |",
     "|---|---|---|---|",
     (.changes[] | "| \(.change | cell) | \(.type | cell) | \(.rationale | cell) | \(if .source == "confirmed" then "confirmed by James" else "auto" end) |")
   ' .aew/runs/<id>/spec-changes.json > .aew/runs/<id>/spec-revision-v<N>.md
   ```

2. `gh-issue.sh revise <n> .aew/runs/<id>/spec-final.md <N>`.
3. `gh-issue.sh comment <n> .aew/runs/<id>/spec-revision-v<N>.md`.
4. `gh-labels.sh flag <n> add spec-revised`.
5. `state.sh set spec_revision <N>`.

A refusal (malformed markers, or a body over 65,536 characters) goes to `SKILL.md` `## Blocked path`. Never trim the history.

In a bulk run, `bulk.md` `## Overrides` sets `<rd>` and `<n>` per issue, takes the version from that issue's `spec revision: #<k> v<N>` note instead of `spec_revision`, and replaces step 5 with that note.

## Re-asking a pending gate

Used by `resume`. Run the pending-gate lookup from `## Gate ids and pending state`, map the gate id in the note to its `## Gate: <id>` section, and enter it at step 2, because the status and label are already set.

- A status of `awaiting_plan_approval` with no `gate:` note means `plan-approval`.
- A status of `awaiting_input` with no `gate:` note is treated as `spec`.
- Before re-asking, run the prompt-mode check from `## Gate ids and pending state`. On a prompt-mode run only `gate:spec` can be pending: re-ask it under the prompt-mode rule, and its step 4 hands back to the `prompt` skill.
- In a bulk run, a note `gate:spec issues/<k>/01-spec-analysis.md` gives `<rd>` `.aew/runs/<id>/issues/<k>` and `<n>` `k` (`bulk.md` `## Overrides`).

## Destructive operations

Ship runs none: no force-push, reset, branch deletion or history rewrite. If a step would need one, ask confirm or cancel with AskUserQuestion. No answer means cancel, which goes to `SKILL.md` `## Blocked path`. This gate is never skipped, even with `--auto`.
