# Phase E: doc-writer, claude-md-curation, loop closure and closing docs

- **Spec:** `docs/superpowers/specs/2026-10-24-build-agents.md` (NOVEL / EPIC, approved)
- **Task source:** `docs/build-prompts/04-build-agents.md` (DESIGN.md wins on conflict)
- **Date:** 2026-10-24
- **Phase:** E · depth: lean · risk: none · ACs: 6, 7, 14, 20, 22, 23, 25, 26, 27
- **Phase depends_on:** [C, D], but only at task level. E1 and E2 (the skill and the agent) are written
  against the spec's fixed contracts and have no cross-phase dependency, so they can start in wave 1. The
  smoke runs (E3–E5) and the closing tasks (E6–E7) wait for the named C and D tasks.

**Binding CTO cuts that apply here.** (1) AC-20 has no checksum sub-check: the overwrite is proven by the
same file names as cycle 1, every file newer than the cycle-1 run, and no stale files. (2) The `run/`
fixture has no `00-issue-original.md`; the doc-writer reads `spec-final.md` and `issue.json`. (3) The gate
runs 971 and 972 reuse run 951's project `$P` through `smoke_use`, after the 951 doc-writer step:
`state.sh init 971` + stage + a report-less developer, then `state.sh init 972` + stage + a report-less
qa-engineer. They get separate run ids and no new `smoke_project`. If the $60 stop is reached, the
unpassed checks are recorded as open. A check is never weakened.

**Cross-phase names used below** (the consolidator maps them to the real ids):

| name | owner | what E needs from it |
|---|---|---|
| `B:fixture` | Phase B | `tests/fixtures/apps/static-shop/` with `run/`, and the two planted CLAUDE.md lines (the one that duplicates a `docs/standards/web.md` rule, and the time-bound one) quoted verbatim in B's plan or the README fixture notes, so E4 can `grep -Fx` them |
| `C:harness` | Phase C | the prompt-04 section of `tests/agent-smoke/README.md`: the static-shop `smoke_project` variant (it keeps the fixture `.gitignore`, sets `branch` with `state.sh set`), the qa-engineer `ALLOW` line, the prompt-04 spend ledger with the $60 stop, and the prompt-04 results table |
| `C:smoke-951-cycle-1` | Phase C | run 951 in `$SMOKE/smoke-<agent>-<case>` after QA cycle 1, with its evidence committed by QA (A14) and its outputs in `$SMOKE/out-951-qa1/` (if C names this directory differently, E uses C's name) |
| `C:qa-agent` | Phase C | the final `agents/qa-engineer.md` |
| `D:developer-agent` | Phase D | the final `agents/developer.md` and its `ALLOW` line in the README |
| `D:smoke-961` | Phase D | the fan-out results, including the nested `SubagentStop` observation (Assumption 29) |
| `C:all`, `D:all` | C, D | every C and D task done, including their DESIGN edits and README rows |

---

## Rules for every smoke task (E3–E5)

- **Harness.** Use Phase C's prompt-04 harness as written (`C:harness`): `$SMOKE` outside the repo,
  `smoke_use`, `smoke_dispatch`, the invocation block with `--include-hook-events`, `--debug-file`,
  `--add-dir "$REPO"` and each agent's `ALLOW` line. The doc-writer has no Bash, so it uses `ALLOW=()`.
  Run 951 has several dispatches, so after `smoke_use` re-point `O` to one directory per step:
  `out-951-fix1`, `out-951-qa2` and `out-951-docs`. State is driven only through `state.sh` (`bump`,
  `stage`, `init`, `set`), before each dispatch, so that the gate's freshness rule holds.
- **Snapshots for re-runs.** Before each 951 step, copy `$P` with `cp -Rp` to `$SMOKE/snap-951-<step>`.
  A re-run after a prompt fix restores the snapshot to the same path, so the run state, `fix_cycle`, git
  history and screenshot mtimes are exactly what the step saw the first time. QA cycle 1 is never re-run
  for E's sake.
- **Shared rows for every run (AC-25).** Besides its own checks, each run records these rows:
  - *Template conformance* of every artefact it wrote, using the README heading-diff command.
  - *Return block:* `valid_return_block` on `final.txt` and on every artefact whose template ends in one.
  - *Preload:* no skip warning in the debug log for any entry in the agent's `skills:` list. For the
    developer that is `aew:run-protocol` and the three superpowers skills; for qa-engineer, `aew:run-protocol`,
    `aew:ui-qa` and `superpowers:verification-before-completion`; for the doc-writer, `aew:run-protocol` and
    `aew:claude-md-curation`.
  - *Permission denials:* empty.
  - *Repo hygiene:* `git -C "$REPO" status --porcelain` shows only intentional files.
  - *Spend:* a row in the prompt-04 ledger.
- **Budget.** Caps: developer fix $5, QA phase B $8, doc-writer $5, gate probes $2. Each run gets one raise,
  to exactly 2x. Stop at a $60 running total across all prompt-04 runs (C, D and E). Then record every
  unpassed E check as `open` and finish E6–E7 with `DONE_WITH_CONCERNS`.
- **Loop on failure** (the same rules as the prompt-03 analog):
  - A *harness fault* is fixed in the README command, then the run is repeated. The prompt doesn't change.
  - An *agent fault* is fixed in `agents/<agent>.md` (or in the skill the agent preloads), committed as
    `fix(agents): <what the prompt now says>`, and the run is repeated from its snapshot. Then re-run every
    earlier passing case of that agent whose mode the edit touches. An edit to a shared section (Inputs,
    Return contract, Guardrails) re-runs all of them, D's 961 included.
  - A prompt fix keeps the mandatory `##` order: Role, Inputs, (agent-specific sections), Process,
    Outputs, Return contract, Guardrails, Autonomy, (Memory), Definition of done. Check it with the
    fence-skipping `awk` heading list before committing.
  - Each check gets at most three fix rounds, then E reports `DONE_WITH_CONCERNS` with that check. A check
    that passed once and failed once is recorded as `flaky`, and its last run must pass.
- **Never commit transcripts.** Streams, debug logs, snapshots and temp projects stay under `$SMOKE`. Only
  the README rows are committed.
- **Allowed files (Phase E).**
  - Always: `skills/claude-md-curation/SKILL.md`, `agents/doc-writer.md`, `docs/DESIGN.md` (§3, §8.7, and §11
    only under A29), `tests/agent-smoke/README.md`, `CHANGELOG.md`, `CLAUDE.md`,
    `docs/superpowers/project-map.md`.
  - Prompt fixes only: `agents/developer.md`, `agents/qa-engineer.md`, `agents/doc-writer.md`,
    `skills/ui-qa/**`, `skills/claude-md-curation/**`.
  - A29 fallback only: `scripts/hooks/gate-subagent.sh`, `tests/scripts/hooks-gate-subagent.bats`.
  - Anything else means a missed dependency: stop and report it.

---

## E1: `skills/claude-md-curation/SKILL.md`

- **files:** `skills/claude-md-curation/SKILL.md` (create). There is no existing analog, because DESIGN §5.2
  and the prompt call for this skill. It is one file with no `references/` (A25).
- **depends_on:** [] (no cross-phase dependency).
- **pattern:** `skills/stack-standards/SKILL.md` (frontmatter shape, `user-invocable: false`, section
  style). For the rules, DESIGN §8.7 and spec AC-6 / A24.
- **What it holds** (AC-6):
  - Frontmatter `name: claude-md-curation`, a `description` that says when to use it, and
    `user-invocable: false`. No `disable-model-invocation`, so the skill can be preloaded.
  - Rules: only durable, non-obvious, project-specific learnings (commands, gotchas, architecture
    decisions, discovered conventions); edit and prune before appending; stay within the cap; link to
    `docs/` for detail; never duplicate the standards docs.
  - Entry format: one bullet per learning, each a fact plus where to read more, under Commands, Gotchas,
    Architecture decisions and Conventions (A24). Existing project headings are kept, not renamed.
  - At least three good and three bad example entries, each with the reason it is good or bad. The bad
    ones cover a restated standards rule, a time-bound note and an obvious-from-the-code fact.
  - Never-include list: secrets, run logs, anything already in the standards docs, anything obvious from
    the code, anything time-bound.
  - Size cap: `claude_md.max_lines` from `.aew/config.json`, or the schema default 300 when it is unset.
    Line counting is done by reading the file (the doc-writer has no Bash).
  - Prune procedure, step by step (A24): read the whole file; drop never-include items; merge duplicates;
    rewrite stale entries against the code; only then append; recount against the cap and drop the least
    durable entries until it fits. Record every removed or rewritten entry, with a reason, for the caller
    (the doc-writer lists them in `10-summary.md`, A22).
  - Whole-file curation: entries James wrote are curated too, and every removal is reported, never silent.
- **Verification:**
  - `head -5` shows the three frontmatter keys;
  - the never-include list has the five items;
  - six or more labelled examples, each with a reason;
  - the numbered prune steps are in A24's order;
  - `wc -l` is about 300 or fewer;
  - `claude plugin validate .` passes;
  - British English.
- **ac:** AC-6
- **risk:** none
- **Commit:** `feat(skills): add claude-md-curation skill`

## E2: `agents/doc-writer.md` and DESIGN §8.7

- **files:** `agents/doc-writer.md` (create), `docs/DESIGN.md` (§8.7 only; the §3 Search tools word moves to
  E6, after Phases A and D have made their §3 edits). There is no existing analog: DESIGN §5.3 calls for this
  agent.
- **depends_on:** [] (no cross-phase dependency; it references `aew:claude-md-curation` by the AC-6 contract
  and doesn't restate it).
- **pattern:** `agents/brief-compiler.md`, a Bash-less agent with `tools: Read, Grep, Glob, Write`, for the
  frontmatter and the Bash-less search wording. `agents/senior-engineer.md` for the section structure
  (Dispatch fields / Files / Templates under Inputs, `## Memory` placement, the "plugin paths are already
  absolute" paragraph).
- **Frontmatter** (AC-7): `name: doc-writer`; a `description` that ends "Dispatched only by the aew
  orchestrator; do not use it for ordinary requests"; `model: sonnet`; `effort: medium`; `memory: project`;
  `skills: [aew:run-protocol, aew:claude-md-curation]`; `tools: Read, Write, Edit, Glob, Grep`. No Bash and
  no `isolation`.
- **Sections, in order:** Role · Inputs · Spec snapshot (agent-specific) · Process · Outputs · Return
  contract · Guardrails · Autonomy · Memory · Definition of done.
  - **Inputs.**
    - Dispatch field: `run_dir`, falling back to `.aew/runs/current` (A9).
    - Files: `spec-final.md`, `issue.json` (`url`, title), `state.json` (`branch`, `issues`,
      `spec_revision`, cycle counters), any `spec-revision-v<N>.md`, `02-brief.md`, `05-plan.md` (its
      alternatives), `04-qa-test-plan.md`, the highest-numbered `08-qa-report-<n>.md` (the passing cycle),
      `manual-tests.md` if it exists, `06-dev-report*.md`, any `07-review-<n>.md` and `09-triage-<n>.md`,
      `log.md`, `.aew/config.json` (`claude_md.max_lines`, `evidence.dir`), `docs/standards/` (read only to
      avoid duplicating it), `CLAUDE.md` and `docs/qa/<issue>/` (found with Glob).
    - No `00-issue-original.md` (CTO cut 2).
    - Templates: `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/{summary,pr-body,retro}.md`.
  - **Spec snapshot** (A22): `docs/specs/<issue>-<slug>.md`, with the slug in lower-case kebab case from
    the issue title (run-protocol). Fixed `##` sections, in order:
    - Spec (from `spec-final.md`);
    - Revision history (`spec_revision` and any `spec-revision-v<N>.md`, or "No revisions");
    - Key decisions (from the plan's alternatives, with the reason each was rejected);
    - Traceability (`| AC | TC | Test | Result |`: every brief AC; manual ACs point to `manual-tests.md`;
      results come from the passing QA report);
    - Outstanding manual tests.
  - **Process:**
    - Find the passing QA report. If none exists, return `blocked`.
    - Write the spec snapshot.
    - Curate CLAUDE.md by following `aew:claude-md-curation` (whole file, within the cap), and keep the
      list of removals.
    - Write `10-summary.md` and `pr-body.md` from their templates:
      - the Summary lists every CLAUDE.md removal (A22);
      - the AC checklist;
      - test results from the passing report;
      - screenshot links as `https://github.com/<owner>/<repo>/blob/<branch>/<evidence.dir>/<issue>/screenshots/<TC>-<viewport>.jpg?raw=true`,
        with owner and repo parsed from `issue.json` `url` and the branch from `state.json`, one per file
        that exists;
      - manual tests ("None." if there are none);
      - `Closes #<n>` for every issue in `state.json` `issues`;
      - every template comment removed from `pr-body.md`.
    - Write `retro.md` from its template. Its items describe the plugin's behaviour (an agent, skill,
      hook, script or stage), drawn from `log.md`, the cycle counters, the triage and review artefacts and
      the dev and QA reports, and never the project's code.
  - **Return contract:** `ok`, or `blocked` when an input is missing. ARTEFACTS lists exactly the five
    paths in the summary template.
  - **Guardrails:**
    - the run-protocol rule (no `gh`, no push, no merge into the base branch, no PR);
    - there is no Bash, so no commit: the orchestrator commits the docs (A14);
    - write only the five outputs plus memory;
    - never edit source, tests, standards or evidence;
    - never include secrets.
  - **Autonomy:** decide wording and pruning yourself; never ask.
  - **Memory** (A23): curation decisions (what was pruned and why), so the agent doesn't re-add pruned
    entries; never secrets, run detail or standards content.
  - **Definition of done:** a checklist mirroring the outputs above.
- **DESIGN** (same commit, change 6):
  - §8.7 gets one sentence: the doc-writer has no Bash and doesn't commit; the orchestrator commits its
    docs after the stage, as it does `docs/standards/` (prompt 05).
- **Verification:**
  - the fence-skipping `awk` heading list matches the order above;
  - the frontmatter matches the AC-7 row exactly (`grep` each key), with no `isolation` or `Bash`;
  - the description has the dispatched-only sentence;
  - the template paths use `${CLAUDE_PLUGIN_ROOT}`;
  - `claude plugin validate .` passes;
  - British English.
- **ac:** AC-7, AC-8 (doc-writer row), AC-14, AC-27 (§8.7)
- **risk:** none
- **Commit:** `feat(agents): add doc-writer agent`

## E3: Loop closure on run 951 (developer fix, then QA cycle 2)

- **files:** `tests/agent-smoke/README.md` (prompt-04 results rows and ledger rows). Prompt fixes only:
  `agents/developer.md`, `agents/qa-engineer.md`, `skills/ui-qa/**`.
- **depends_on:** [C:smoke-951-cycle-1, C:qa-agent, D:developer-agent]. It may run concurrently with
  D:smoke-961 (a different `$P`); the README rows are written after the run.
- **Setup:**
  - `smoke_use` the 951 project.
  - Record `C1=$(git -C "$P" rev-parse HEAD)`, and the cycle-1 screenshot list from
    `git -C "$P" ls-tree --name-only "$C1" docs/qa/201/screenshots/`.
  - Snapshot to `snap-951-fix1`.
  - `state.sh bump fix_cycle` (prints 1), then `state.sh stage develop`.
- **Step 1, developer fix:** dispatch `aew:developer` with `run_dir: $RUN, mode: fix, n: 1, fix_from: 08-qa-report-1.md`,
  cap $5, into `out-951-fix1`. Pass when:
  - `git -C "$P" log --format=%s "$C1"..HEAD` has at least one subject, every one matching
    `^fix\([^)]+\): .+ \(#201\)$`;
  - no fix commit touches `tests/e2e/` (the developer never edits QA's specs, A15);
  - `06-dev-report.md` has `Mode: fix (cycle 1)`, a filled `## Commands run`, and a valid return block with
    `STATUS: ok`;
  - the stream shows the developer's `SubagentStop` gate ran and returned no `block` (the allow half of
    AC-23).
- **Step 2, QA cycle 2:**
  - Snapshot to `snap-951-qa2`, then `state.sh stage qa` (with `fix_cycle` 1, the gate expects
    `08-qa-report-2.md`).
  - Dispatch `aew:qa-engineer` with `run_dir: $RUN, phase: B, n: 2`, cap $8, into `out-951-qa2`.
  - Pass when:
    - `final.txt` and `08-qa-report-2.md` both pass `valid_return_block` with `STATUS: ok`, and the report
      shows the basket-count and `button-name` TCs passing;
    - `docs/qa/201/report.md` exists;
    - `manual-tests.md` still holds the email case;
    - *overwrite (CTO cut 1):* the sorted screenshot list after cycle 2 equals the cycle-1 list (same names,
      no stale files); `find docs/qa/201/screenshots -type f ! -newer "$SMOKE/out-951-qa1/stream.jsonl"`
      prints nothing (every file is newer than the cycle-1 run); every file is a real JPEG by `file`;
    - QA committed cycle 2's evidence (`test(e2e): … (#201)`), and the tree is clean apart from ignored files;
    - the qa-engineer gate returned no `block`.
- **On failure:** follow the loop rules. A developer fix restores `snap-951-fix1`; a QA fix restores
  `snap-951-qa2`.
- **ac:** AC-20, AC-23 (allow half, for these two stops), AC-25, AC-26
- **risk:** none
- **Commit:** `test(agent-smoke): record developer fix and QA cycle 2 runs`

## E4: Doc-writer run on 951

- **files:** `tests/agent-smoke/README.md`. Prompt fixes only: `agents/doc-writer.md`,
  `skills/claude-md-curation/**`.
- **depends_on:** [E1, E2, E3, B:fixture]
- **Setup:**
  - `smoke_use` the 951 project.
  - Record `H=$(git -C "$P" rev-parse HEAD)`.
  - Read `claude_md.max_lines` from `$P/.aew/config.json` with `jq`.
  - Snapshot to `snap-951-docs`, then `state.sh stage docs`.
  - Dispatch `aew:doc-writer` with `run_dir: $RUN` and `ALLOW=()`, cap $5, into `out-951-docs`.
- **Pass when:**
  - *CLAUDE.md (AC-22):*
    - `wc -l < CLAUDE.md` is ≤ the cap;
    - `git -C "$P" diff --quiet -- CLAUDE.md` exits 1 (the file changed);
    - `grep -Fx` finds neither planted line (`B:fixture`): the standards duplicate is gone and the
      time-bound line is pruned;
    - no added diff line restates a standards rule: `grep -Fxf` of the added lines against
      `docs/standards/*` prints nothing, and each added line is judged against `web.md`, with the per-line
      verdict in the notes;
    - every removed non-blank line is listed in `10-summary.md`'s Summary (judged where reworded).
  - *Spec snapshot:*
    - exactly one `docs/specs/201-*.md`, whose name equals `201-` plus the kebab-cased `state.json` title;
    - its `##` headings are the five A22 sections, in order;
    - `grep -oE '^- \*\*AC-[0-9]+' $RUN/02-brief.md | grep -oE 'AC-[0-9]+' | sort -u` (the AC bullets only,
      not the template comment) equals the Traceability table's AC column;
    - manual rows point to `manual-tests.md`.
  - *pr-body.md:*
    - `grep -c '<!--'` is `0`;
    - `Closes #201` is present;
    - every screenshot link matches `https://github.com/<owner>/<repo>/blob/<state.json branch>/docs/qa/201/screenshots/TC-[0-9]+-(desktop|mobile)\.jpg\?raw=true`,
      with owner and repo from `issue.json` `.url`;
    - the set of linked files equals the files in `docs/qa/201/screenshots/`.
  - *10-summary.md and retro.md:*
    - both follow their templates;
    - `10-summary.md` and `final.txt` pass `valid_return_block` with `STATUS: ok`, and ARTEFACTS lists the
      five paths;
    - `retro.md` has at least one `### ` item naming a plugin component (an agent, skill, hook, script or
      stage), with every item judged plugin-not-project in the notes.
  - *No commit and scoped writes:*
    - `git -C "$P" rev-parse HEAD` equals `$H`;
    - `git -C "$P" status --porcelain --untracked-files=all` shows only `CLAUDE.md`, `docs/specs/201-*.md` and the agent memory
      directory (`.claude/agent-memory/aew-doc-writer/`).
- **On failure:** restore `snap-951-docs` and follow the loop rules.
- **ac:** AC-14 (live), AC-22, AC-25, AC-26
- **risk:** none
- **Commit:** `test(agent-smoke): record doc-writer run`

## E5: Report-less gate runs 971 and 972 (AC-23)

- **files:** `tests/agent-smoke/README.md`. A29 fallback only: `scripts/hooks/gate-subagent.sh`,
  `tests/scripts/hooks-gate-subagent.bats`, `docs/DESIGN.md` §11.
- **depends_on:** [E4, D:smoke-961]. It reuses 951's `$P` after the doc-writer (CTO cut 3).
  `state.sh init` re-points `.aew/runs/current`, so it can't overlap E3 or E4.
- **Probe wording** (fixed, added to the dispatch fields): "Gate probe: do not read, create or edit any
  file. End at once with a return block, `STATUS: blocked`, SUMMARY `gate probe`."
- **971, developer:**
  - Run `state.sh init 971 --issues 201 --mode single --title "<951 title>"`, `state.sh set branch <951 branch>`,
    then `state.sh stage develop`.
  - Dispatch `aew:developer` with `run_dir: $RUN, mode: fix, n: 1, fix_from: 08-qa-report-1.md` plus the
    probe, cap $2, into `out-971`.
- **972, qa-engineer:**
  - Run `state.sh init 972 …`, `set branch`, then `stage qa` (`fix_cycle` 0).
  - Dispatch `aew:qa-engineer` with `run_dir: $RUN, phase: B, n: 1` plus the probe, cap $2, into `out-972`.
- **Pass when:**
  - the hook events in the stream (or the debug log if the stream omits them; record which source was
    used) show a `SubagentStop` `block` decision for `aew:developer` whose reason names `06-dev-report`, and
    one for `aew:qa-engineer` whose reason names `08-qa-report-1.md`;
  - the following stop is allowed (`stop_hook_active`), so there is no block loop; record what the agent
    did in its corrective turn;
  - the allow half is cited from E3's two stops, C's cycle-1 row and D's 961 rows;
  - D's nested-sub-developer observation (fired or not, and with which `agent_type`) is copied into the
    AC-23 notes.
  - If the agent wrote a report before its first stop, so that no block happened, that is a harness fault:
    tighten the probe wording and re-run once.
  - If the gate fails to block when no report exists, that is a gate fault, handled under A29: fix it, add
    bats rows, run `tests/run-script-tests.sh`, record a deviation and update §11, all in one
    `fix(hooks): …` commit.
- **ac:** AC-23, AC-25, AC-26
- **risk:** none
- **Commit:** `test(agent-smoke): record report-less gate runs`

## E6: Closing docs (DESIGN §3, CHANGELOG, CLAUDE.md, project map)

- **files:** `docs/DESIGN.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/superpowers/project-map.md`
- **depends_on:** [E5, C:all, D:all]
- **DESIGN §3.** Grep first, so that nothing Phases A, C or D added is repeated. Then record F6 (the
  `SubagentStop` payload fields) and the observed nested-`SubagentStop` behaviour from D:smoke-961 and E5.
  Note F2 (exact MCP names in `tools`; the plugin-prefixed wildcard is unverified) only if Phase A didn't.
  Add doc-writer to the Search tools bullet's Bash-less agents that list `Glob, Grep` (moved from E2 so it
  doesn't conflict with Phase A/D §3 edits in parallel worktrees).
  If a run contradicted §3, follow what was observed and say so in the final report.
- **CHANGELOG.md**, under `[Unreleased]`. Grep first and merge rather than duplicate.
  - **Added:** the pinned Playwright MCP (`.mcp.json`), the `ui-qa` and `claude-md-curation` skills, the
    `developer`, `qa-engineer` and `doc-writer` agents, the static-shop fixture, and the prompt-04 smoke
    results.
  - **Changed:** the `## Files read` section in the QA test plan and the triage table in the QA report;
    the run-protocol exception that routes a QA phase B `failed` by triage class; the `axe_standard`
    description (cumulative tags); the gate change, if A29 triggered.
- **CLAUDE.md.** One "Recent changes" line in the existing format:
  `- 2026-10-24 · <git branch --show-current> · Build-side agents (build prompt 04): developer, qa-engineer, doc-writer, ui-qa and claude-md-curation skills, pinned Playwright MCP, static-shop fixture, headless loop and fan-out smoke runs · [spec](docs/superpowers/specs/2026-10-24-build-agents.md) · [plan](docs/superpowers/plans/2026-10-24-build-agents.md)`.
  Use the consolidated plan's real path.
- **project-map.md**, appended to `## Project knowledge`: grep first, one terse line each, and skip
  anything another phase already added.
  - The dispatch fields as implemented (A9 final).
  - Commit ownership (A14): developer and QA commit; the doc-writer does not.
  - The QA `failed` discriminator (A13).
  - The fan-out mechanics contract (A10/A11), if D didn't add it.
  - The Playwright MCP tool names.
  - Harness lessons: one output directory per step, the `cp -Rp` snapshot restore, the report-less probe,
    the overwrite proof.
  - The nested `SubagentStop` observation.
  - Any prompt-fix lesson that generalises.
- **Verification:** each DESIGN change listed in the spec appears in DESIGN (or is noted as present);
  CHANGELOG has no duplicate bullets; the Recent changes line matches the existing format.
- **ac:** AC-27
- **risk:** none
- **Commit:** `docs: record build-agent facts, changelog and project knowledge for prompt 04`

## E7: Verification and final report

- **files:** none. A fix goes back to the owning task's files and gets its own commit.
- **depends_on:** [E6]
- **Use** `superpowers:verification-before-completion`. Run each of these fresh and read the output:
  - `tests/run-script-tests.sh` passes;
  - `claude plugin validate .` passes;
  - the ajv validations of `config.schema.json` / `config.example.json` and `state.schema.json` /
    `state.example.json`, plus `tests/fixtures/apps/static-shop/.aew/config.json` against the config schema;
  - the fence-skipping heading-order check on all three new agents;
  - `wc -l skills/ui-qa/SKILL.md skills/claude-md-curation/SKILL.md`;
  - in the prompt-04 README section: no `pending`; every row is `pass`, `flaky` with a final pass, or `open`
    because of the $60 stop (an `open` or failing row means `DONE_WITH_CONCERNS`); the AC-25 shared rows
    exist for every prompt-04 run (C, D and E); the ledger total is recorded; no transcript content;
  - `git status` is clean, and `tests/tmp/` is not tracked.
- **Final report** (returned, not written to a file):
  1. The checks run and their results, the smoke summary and the total cost.
  2. `git diff --stat main...HEAD`.
  3. Deviations from DESIGN and why:
     - A1, the bundled pinned MCP rather than the official plugin;
     - A5, cumulative axe tags;
     - A10/A11, manual worktrees from HEAD and cherry-pick instead of `isolation`;
     - A13, the QA `failed` exception;
     - A14, commit ownership;
     - the CTO cuts;
     - A29, if it triggered;
     - any harness workaround.
  4. Decisions for James:
     - the flagged assumptions that still stand (A1, A5, A6, A10, A11, A13, A14, A22, A27);
     - A30: keep the per-task conventional commits (recommended, since the `fix(agents)` commits are the
       evidence that no check was weakened), or squash at PR merge;
     - any `open` or `DONE_WITH_CONCERNS` check.
- **ac:** AC-25 (aggregate), AC-26, AC-27
- **risk:** none
- **Commit:** none, unless a verification fix is needed (`fix(<scope>): …` in the owning files).

---

## Task graph

```
E1 ─┐
E2 ─┤ (wave 1, parallel, no cross-phase deps)
    │
C:smoke-951-cycle-1, C:qa-agent, D:developer-agent → E3 → E4 (needs E1, E2, B:fixture)
                                                         → E5 (needs D:smoke-961) → E6 (needs C:all, D:all) → E7
```

E1 and E2 touch different files (E2 also edits DESIGN §8.7, which no other wave-1 task touches) and
may run in parallel worktrees. E3–E5 are sequential: they share run 951's `$P`, and `state.sh init`
re-points its single `.aew/runs/current`. E3 may overlap D:smoke-961 (a different project), but README
edits are committed one task at a time.

---

## Approval (phase E)

- Senior architect: APPROVED WITH NOTES on 2026-10-24T19:52:51Z (plan-review, lean)
- Plan format: LEAN · risk lines crossed: none
- Dependency graph: valid (no cycles, no dangling refs; cross-phase refs symbolic). Wave count: 6 within E
  (E1 ∥ E2, then E3 → E4 → E5 → E6 → E7). Max wave width: 2.
- AC coverage: 6 (E1), 7/8/14 (E2), 14/20/22/23/25/26 (E3–E5), 27 (E2 §8.7, E6, E7). Complete.
- Author-flagged extra checks: both kept. E3's no-`tests/e2e/` check pins A15 ("never edits QA's specs");
  E4's `<!--` count is AC-14's "template comment removed" (the template has four comments).
- Auto-applied: the §3 Search tools word moved from E2 to E6 (avoids a wave-1 DESIGN §3 conflict with A/D);
  E4 `status --porcelain --untracked-files=all` (otherwise new directories collapse to `?? docs/`);
  E4 brief AC grep anchored to the AC bullets (the brief template's comment contains "AC-1, AC-2").
- Plan content hash (SHA-256, before this trailer): 9d55648ea2f73ed04f9a90ed261d0eef610320579494b7e515ec2ef22516aa6e
