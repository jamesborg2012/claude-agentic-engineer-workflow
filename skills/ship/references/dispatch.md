# Dispatch reference

Read by `ship` at every stage. Read every literal `${CLAUDE_PLUGIN_ROOT}` in this file as the plugin root stated in `SKILL.md` `## Plugin root`. `<rd>` is `.aew/runs/<id>`, relative to the project root.

## How to dispatch

- Use the Agent tool. `subagent_type` is the row's `aew:<agent>` value, and `description` is `<stage> <id>`.
- The prompt is `key: value` lines only: one line per field, in the row's order, with nothing else (no prose, no artefact content). `answers:` is followed by its `Q<k>:` lines, one per answer.
- `run_dir` is always `.aew/runs/<id>`.
- Send one agent per Agent call. The single exception is D6 and D7: two Agent calls in one assistant message, with no other tool call in it. Concurrency is not guaranteed, and sequential execution is still correct.
- Do the row's state write first, and check its required files with `test -f <rd>/<file>`. A missing file goes to `SKILL.md` `## Blocked path`, naming it.

Example prompt (verbatim form):

```
run_dir: .aew/runs/201
mode: review
n: 1
base: main
```

## Dispatch table

| Row | Agent and mode | subagent_type | Prompt fields | Required files | State write before |
|---|---|---|---|---|---|
| D1 | spec-analyser, first run | `aew:spec-analyser` | `run_dir`, `spec_version: <spec_revision+1>` | `00-issue-original.md`, `issue.json` | Step 3 (fresh) or stage entry `spec_analysis` |
| D2 | spec-analyser, re-run with answers | `aew:spec-analyser` | `run_dir`, `spec_version: <spec_revision+1>`, `answers:` then one `Q<k>: …` line per answer | the above plus `01-spec-analysis.md` | `state.sh stage spec_analysis --note "answers: gate:<id>"` |
| D3 | brief-compiler, pipeline | `aew:brief-compiler` | `run_dir`, `mode: pipeline` | `spec-final.md`, `issue.json` | stage entry `brief` |
| D4 | brief-compiler, prompt (used by `prompt`) | `aew:brief-compiler` | `run_dir`, `mode: prompt` | `spec-final.md`, `issue.json` | `state.sh stage brief` (prompt mode sets no label) |
| D5 | standards-setter | `aew:standards-setter` | `run_dir` | `02-brief.md` | stage entry `standards` |
| D6 | qa-engineer, phase A | `aew:qa-engineer` | `run_dir`, `phase: A` | `02-brief.md`, `03-standards.md` | stage entry `plan` (one write for D6 and D7) |
| D7 | senior-engineer, plan | `aew:senior-engineer` | `run_dir`, `mode: plan`, optional `notes: <one line>` | `02-brief.md`, `03-standards.md` | stage entry `plan` |
| D8 | developer, full | `aew:developer` | `run_dir`, `mode: full` | `05-plan.md`, `02-brief.md`, `03-standards.md` | stage entry `develop` (immediately before) |
| D9 | senior-engineer, review | `aew:senior-engineer` | `run_dir`, `mode: review`, `n: <review_cycle+1>`, `base: <base_branch>` | `02-brief.md`, `05-plan.md`, `03-standards.md` | stage entry `review` |
| D10 | developer, fix | `aew:developer` | `run_dir`, `mode: fix`, `fix_from: <file>`, `n: <k>` | the `fix_from` file | stage entry `develop` (review fix) or `state.sh stage qa --note "fix <k>: developer"` (QA fix), immediately before |
| D11 | senior-engineer, triage | `aew:senior-engineer` | `run_dir`, `mode: triage`, `n: <k>` | `08-qa-report-<k>.md` | the `bump fix_cycle` of the QA loop |
| D12 | qa-engineer, phase B | `aew:qa-engineer` | `run_dir`, `phase: B`, `n: <fix_cycle+1>`, optional `triage: <rd>/09-triage-<k>.md` | `02-brief.md`, `04-qa-test-plan.md` | stage entry `qa` (first pass) |
| D13 | doc-writer | `aew:doc-writer` | `run_dir` | `spec-final.md`, `issue.json`, `state.json` | stage entry `docs` |

Field notes, taken from each agent's Inputs:

- `spec_version` is always `spec_revision + 1`.
- `answers:` is a line of its own, then one `Q<k>: <answer>` line per answer. For a question spec-analyser did not ask, write `Q<k>: <question> => <answer>`, with k continuing after the highest `### Q<n>.` of `01-spec-analysis.md`.
- `notes` (D7 only) is one line and the last field of the prompt. Join several notes with ` / `. A developer `blocked` note reads `developer blocked: <the developer's SUMMARY> / <the dev report path>`.
- `n` for D10 and D11 is the cycle number `k` given by the step that dispatches. For D9 it is `review_cycle + 1`, and for D12 `fix_cycle + 1`.
- `fix_from` (D10) is a comma-separated list of file names in the run dir, such as `07-review-<k>.md`, `08-qa-report-<k>.md` or `09-triage-<k>.md`. Each must exist.
- `triage` (D12) is a run-dir path, `<rd>/09-triage-<k>.md`. Send it only when the QA loop sent you.
- `base` (D9) is `state.base_branch`.
- Developer `mode: package` and standards-setter `mode: init` are not in this table: package mode belongs to fan-out, and `init` dispatches its own agent.

## Required inputs per stage

Used by each stage's step 2, by `--from` and by resume. Check each file with `test -f <rd>/<file>`.

| Stage | Required files in `<rd>` |
|---|---|
| `spec_analysis` | `issue.json`, `00-issue-original.md` (after the fetch) |
| `brief` | `spec-final.md`, `issue.json` |
| `standards` | `02-brief.md` |
| `qa_test_plan` | `02-brief.md`, `03-standards.md` (the same step as `plan`) |
| `plan` | `02-brief.md`, `03-standards.md` |
| `develop` | `02-brief.md`, `03-standards.md`, `05-plan.md`, plus `07-review-<review_cycle>.md` in fix mode |
| `review` | `02-brief.md`, `03-standards.md`, `05-plan.md`, at least one `06-dev-report*.md` |
| `qa` | `02-brief.md`, `04-qa-test-plan.md` |
| `docs` | `spec-final.md`, `issue.json`, and `08-qa-report-<fix_cycle+1>.md`, whose return block (`awk 'NF' <file> \| tail -n 4`) reads `STATUS: ok` |
| `pr` | `pr-body.md`, `10-summary.md` |

Develop mode is fix only when `review_cycle` is at least 1 and `test <rd>/07-review-<review_cycle>.md -nt <rd>/05-plan.md` succeeds. Otherwise it is full mode, which needs no review file.

## Return check

1. The last four non-blank lines of the Agent result must be, in order, `STATUS: <ok|needs_input|blocked|failed>` (exactly one of the four words), `ARTEFACTS: <non-empty>`, `SUMMARY: <non-empty>` and `NEXT: <non-empty>`. This is the rule of `valid_return_block` in `${CLAUDE_PLUGIN_ROOT}/scripts/hooks/gate-subagent.sh`. The template form `STATUS: ok | needs_input | blocked | failed` is invalid.
2. Every comma-separated ARTEFACTS path must pass `test -f`. Paths are relative to the project root, or absolute for a sub-developer's report.
3. Developer only: for each `06-dev-report.md` or `06-dev-report-WP<n>.md` named in ARTEFACTS, `awk 'NF' <file> | tail -n 4` must also pass rule 1. In fan-out the gate hook can pass on a sibling's report, so the orchestrator checks every named report itself (CTO-3b).
4. If any rule fails, the return counts as `failed` (see `## Retries`). Do not open the artefact to fix it.
5. Otherwise route on STATUS through `routing.md` `## Agent status routing`. SUMMARY and NEXT are the only parts of the result the orchestrator uses.

## Retries

- A `failed` return, or an invalid one, is re-sent once as the same dispatch. A second failure goes to `SKILL.md` `## Blocked path`, with the reason taken from the last SUMMARY.
- The count is kept in this session only, so a resumed run starts with a fresh allowance.
- Exception: a QA phase B `failed` that passes the complete-failure test is not retried (`routing.md` `## QA loop`).
- In the planning pair, retry only the agent that failed, on its own.
