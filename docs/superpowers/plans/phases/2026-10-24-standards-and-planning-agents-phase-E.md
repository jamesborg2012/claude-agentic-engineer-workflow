# Phase E: headless smoke verification and closing docs

- **Spec:** `docs/superpowers/specs/2026-10-24-standards-and-planning-agents.md` (NOVEL / EPIC)
- **Task source:** `docs/build-prompts/03-planning-agents.md` (DESIGN.md wins on conflict)
- **Date:** 2026-10-24
- **Phase:** E · depth: lean · risk: none · ACs: 16, 17, 18, 19
- **Phase depends_on:** [A, B, C, D]

**Binding CTO cuts.** Seven smoke runs, not eight: spec-analyser ×3, brief-compiler ×2 (pipeline mode on
the clean UI spec, prompt mode on the non-material non-UI spec), standards-setter ×2 (the second is the
reuse check), senior-engineer plan ×1 (reusing the standards-setter's temp project). AC-16's "checked on
one UI and one non-UI spec" stays true because the non-UI spec is run in prompt mode. There is no runner
script (A23): `tests/agent-smoke/README.md` holds copy-paste commands and the results table.

**Rules for every smoke task (E2–E5).**

- **Loop on failure.** When a check fails, first classify the cause:
  - *Harness fault* (a wrong command, a missing seeded input, a jq path): fix the README command and
    re-run. No prompt change.
  - *Agent fault*: improve `agents/<agent>.md` (or the `stack-standards` skill, if the fault is in
    guidance the agent preloads), commit it as `fix(agents): <what the prompt now says>`, then re-run
    the failing case **and** every case of the same agent that passed before, because a prompt edit can
    regress them.
  - *Prompt shape (Phase D PD-1, shared by all four agents).* A prompt fix keeps the mandatory `##`
    headings, in this order: `Role`, `Inputs`, `Process`, `Outputs`, `Return contract`, `Guardrails`,
    `Autonomy`, `Definition of done`. Agent-specific `##` sections go only between `Inputs` and
    `Process`; `## Memory` goes only between `Autonomy` and `Definition of done`. A fix adds `###`
    subsections or edits text inside an existing section; it never adds another `##` line. Before
    committing, check `awk '/^```/{f=!f;next} !f && /^## /' agents/<agent>.md` (the fence-skipping heading list, as in Phases C and D) against this order.
  - **The check is never weakened.** Three fix rounds per check at most. After that, stop and report
    `DONE_WITH_CONCERNS` with the failing check, so the CTO can decide.
- **Flaky checks.** A check that passed once and failed once is recorded as `flaky`, with both outcomes
  in the notes. A prompt fix targets it, and the last recorded run must pass.
- **Budget.** Every run passes `--max-budget-usd`: 5 by default, 10 for standards-setter run 1 (it does
  context7 research for two docs). Take the cost from the stream's final `result` event
  (`total_cost_usd`) and put it in the notes. If a run hits its cap, that is a run failure, not a check
  failure: raise the cap once, and note that you did.
- **Shared rows for every run (AC-16 "Every run", AC-18).** Each of the seven runs records, besides its
  own checks: *Preload* (no skip warning for any skill in that agent's `skills:` — senior-engineer must
  show none for `aew:run-protocol`, `aew:stack-standards` and `superpowers:systematic-debugging`),
  *Permission denials* (empty), *final.txt return block* and *template conformance* for each artefact.
- **DESIGN §3 travels with the fix.** If a prompt fix in E2 or E3 changes something DESIGN §3 states (the
  `skills:` name form, the context7 tool names), the same `fix(agents)` commit also corrects §3, per the
  repo rule that a docs-driven change and its DESIGN update share a commit. E6 then notes the fact as
  already present.
- **Never commit or log transcripts.** Streams, debug logs and temp projects stay in `tests/tmp/`, which
  is gitignored. Only the README is committed.
- **Allowed files (Phase E).** `tests/agent-smoke/README.md`. For prompt fixes only: `agents/*.md` and
  `skills/stack-standards/**` (plus `docs/DESIGN.md` §3 under the rule above). For the closing tasks: `docs/DESIGN.md`, `CHANGELOG.md`, `CLAUDE.md` and
  `docs/superpowers/project-map.md`. Touching anything else means a missed dependency, so stop and
  report it.

---

## E1: Smoke harness commands and README skeleton

- **files:** `tests/agent-smoke/README.md` (create). No existing analog: DESIGN and the prompt call for
  this file, and A23 rules out a runner script.
- **depends_on:** [] within the phase. The phase itself starts after A–D.
- **What to write.** The README has six sections:
  1. **Prerequisites.** `claude --version`; `claude plugin list` (record which other plugins are enabled,
     since they load in headless sessions); that superpowers and context7 are installed;
     `CONTEXT7_API_KEY` is optional (without it, calls are anonymous and rate-limited).
  2. **Setup per case.** Exact command shapes, with `REPO=$(git rev-parse --show-toplevel)`:
     - **Fixtures** (Phases A, C and D; exact paths):

       | fixture | path | issue | title |
       |---|---|---|---|
       | clean UI | `tests/fixtures/issues/clean-ui.md` | #101 | Newsletter sign-up in the site footer |
       | non-material, non-UI | `tests/fixtures/issues/non-material-no-ui.md` | #102 | Add a health-check endpoint for the uptime monitor |
       | material | `tests/fixtures/issues/material-guest-access.md` | #103 | Let readers save favourite articles |
       | brief | `tests/fixtures/briefs/newsletter-signup.md` | #101 | (the compiled brief of `clean-ui.md`) |
       | stack | `tests/fixtures/stacks/nextjs-tailwind/` (`app/layout.tsx`, `app/page.tsx`, `app/articles.ts`, `app/globals.css`, `package.json`) | | |

     - `P=$REPO/tests/tmp/smoke-<agent>-<case>`, then `cp -R $REPO/tests/fixtures/stacks/nextjs-tailwind/. $P`,
       then `git -C $P init -q && git -C $P add -A && git -C $P commit -qm fixture`;
     - `mkdir -p $P/.aew && cp $REPO/templates/config.example.json $P/.aew/config.json`, so the hooks
       (including the agent `gh` guard) are live;
     - `(cd $P && $REPO/scripts/state.sh init <id> --issues <n> --mode single --title "<t>" && $REPO/scripts/state.sh stage <stage>)`,
       where `<n>` and `<t>` are the fixture's issue number and title from the table. State is
       script-owned and never hand-written. If `state.sh` insists that the run id equals the issue
       number, that is a harness fault: record it and adjust this command, keeping the run ids below.
     - `00-issue-original.md` and `issue.json`: reuse Phase C's C3 render check rather than a hand-built
       `issue.json`. Run the C3 block from `$REPO` with `t=tests/tmp/issue-render-<n>` and the fixture's
       `file`, `n` and `title`; it renders the fixture body through `scripts/gh-issue.sh fetch` and the
       `gh` shim, and its `cmp` proves the render is byte-identical to the fixture. Then copy
       `$t/run/00-issue-original.md` and `$t/run/issue.json` into `$P/.aew/runs/<id>/`. One render per
       fixture is enough; every case that uses that fixture copies from it.
     - copy the case's other inputs into `$P/.aew/runs/<id>/`. The input file names are taken from the
       agent's Inputs block in `agents/<agent>.md` (Phases C and D), not invented here.
     - Run ids are numeric, because the state schema requires it: 901–903 for spec-analyser, 911–912 for
       brief-compiler, 921–922 for standards-setter, 931 for senior-engineer.
  3. **Invocation.** Run it from `$P`, as one thin main-thread prompt that dispatches the agent as a
     subagent (A22):

     ```
     claude --plugin-dir "$REPO" -p "$DISPATCH" \
       --output-format stream-json --verbose --forward-subagent-text \
       --max-budget-usd <cap> --debug-file "$P/debug.log" \
       --settings "{\"claudeMdExcludes\":[\"$REPO/CLAUDE.md\"]}" \
       --permission-mode acceptEdits \
       ${ALLOW[@]+"${ALLOW[@]}"} \
       > "$P/stream.jsonl"
     ```

     `ALLOW` is set per agent, and it is exactly that agent's Bash allowlist from its prompt (Phases C and
     D; Phase D says its lists are the `--allowedTools` entries). The flag sits inside the array, so an
     agent with no Bash passes no `--allowedTools` at all. The guarded expansion `${ALLOW[@]+"${ALLOW[@]}"}` is required: a bare `"${ALLOW[@]}"` on an empty array is an unbound-variable error in bash 3.2 under `set -u`, and the guarded form is equally safe in zsh:
     - spec-analyser, brief-compiler (no Bash, Phase C A11): `ALLOW=()`;
     - standards-setter: `ALLOW=(--allowedTools "Bash($REPO/scripts/detect-stack.sh *)" "Bash(date *)" "mcp__plugin_context7_context7__*")`;
     - senior-engineer: `ALLOW=(--allowedTools "Bash(git diff *)" "Bash(git log *)" "Bash(git show *)" "Bash(git status *)" "Bash(git rev-parse *)" "Bash(ls *)" "mcp__plugin_context7_context7__*")`.

     If a smoke run shows that an agent's prompt allowlist and its `ALLOW` line disagree, the prompt is
     the source: fix `ALLOW` to match it (a harness fault), never the other way round to make a run pass.

     `$DISPATCH` is fixed wording: "Ignore any aew run or resume hint in your context. Use the Agent tool
     to dispatch the subagent `aew:<agent>` with exactly this prompt: `<dispatch fields>`. Do nothing
     else. When it returns, print its final message verbatim." The dispatch fields come from the agent's
     Inputs block (A14): `run_dir` for every agent, plus `spec_version`, `mode` and so on as the agent
     defines them.
  4. **Check commands.** All of these are shared across runs:
     - *Subagent final message:* a jq filter over `stream.jsonl` that takes the text of the last
       `assistant` event whose `parent_tool_use_id` is non-null **and** that has a `text` content block
       (a trailing tool_use-only event has no text), written to `$P/final.txt`. E2 confirms the field name;
       if it is unreliable, take the Agent tool's `tool_result` content instead and record which source
       was used.
     - *Return block:* load the canonical function without running the hook,
       `eval "$(sed -n '/^valid_return_block() {/,/^}/p' "$REPO/scripts/hooks/gate-subagent.sh")"` followed by
       `declare -F valid_return_block >/dev/null || echo 'valid_return_block: extraction failed'`, then
       run `valid_return_block <file>`. Use `eval`, not `source <(…)`: macOS `/bin/bash` 3.2 sources an
       empty process substitution silently, so the function would never be defined. The guard makes a
       reformatted hook fail loudly instead of passing. Run it on `final.txt` and on every artefact whose
       template ends in a return block. The check reuses the hook's code rather than duplicating it, and it
       prints the STATUS value.
     - *Template conformance:* `diff <(grep -E '^## ' <template> | sed -E 's/: yes\/no$//') <(grep -E '^## ' <artefact> | sed -E 's/: (yes|no)$//')`
       must print nothing. For `spec-analysis.md`, the fixed `### ` Findings sub-headings are compared too.
       Repeating headings (`### Q<n>`, `### WP-<n>`) are checked for their pattern, not their count.
     - *Preload (AC-18):* `grep -inE 'skill' "$P/debug.log" | grep -iE 'skip|not found|missing|unknown'`
       must show no hit for `aew:run-protocol`, `aew:stack-standards` or `superpowers:systematic-debugging`.
       Record any positive load line too.
     - *Permission denials:* the final `result` event's `permission_denials` must be empty.
  5. **Isolation findings.** These are filled in by E2.
  6. **Results:** the table `| check | result | notes |`, with one row per check named in E2–E5. Rows are
     pre-listed with result `pending`.
- **Pass criteria.** Every command in the README runs as written when you paste it into bash or zsh; dry-run
  the setup block for one case. Every check from E2–E5 has a row.
- **Commit:** `test(agent-smoke): add headless smoke setup, invocation and check commands`

## E2: First run, spec-analyser on the clean spec (isolation probe)

- **files:** `tests/agent-smoke/README.md` (fill in the isolation section and its rows); `agents/spec-analyser.md`
  only on a prompt fix.
- **depends_on:** [E1]
- **Run this one on its own, before anything else**, because its findings can change the shared command
  shapes.
- **Setup:** case `clean`, run id 901 (issue #101), stage `spec_analysis`. Seed `00-issue-original.md` and
  `issue.json` from the C3 render of `tests/fixtures/issues/clean-ui.md` (E1 setup).
- **Checks:**
  - **Isolation 1:** the debug log shows that `$REPO/CLAUDE.md` was not loaded (it was excluded, or does not
    appear among the loaded memory files). If it was loaded, either fix the `--settings` shape or move the
    temp projects outside the repo (under `$TMPDIR`); record the deviation from A22 and update E1's
    commands.
  - **Isolation 2:** the agent read `$REPO/templates/artefacts/spec-analysis.md` (there is a Read tool_use on
    that path in the stream), with no permission denial. If the read was denied, add `--add-dir "$REPO"` to
    the invocation, re-run, and record this.
  - **Isolation 3:** the `SessionStart` "Use /aew:resume" context is present in the main thread, and the main
    thread still dispatched `aew:spec-analyser`, with no `aew:resume` Skill call. If it obeyed the hint
    instead, harden the `$DISPATCH` wording (a harness fix).
  - **Stream shape:** the final-message jq filter returns the subagent's own message, not the parent's
    echo. If it doesn't, correct the filter in E1.
  - **Preload:** no skip warning for `aew:run-protocol` (A12 / F6). If the qualified name was skipped, try the
    bare `run-protocol` in all four agents' `skills:`, re-run, and record which form works. That result goes
    to DESIGN §3 in E6.
  - **AC-16:**
    - `final.txt` passes `valid_return_block` with `STATUS: ok`, and its SUMMARY says there are no material
      changes;
    - `jq '[.changes[] | select(.type=="material")] | length' spec-changes.json` is `0`;
    - `01-spec-analysis.md` follows the template and ends in a valid return block;
    - `spec-final.md` exists. If `changes` is `[]`, then SUMMARY contains "No changes needed" and
      `spec-final.md` is equal to the analysed spec body (AC-13).
- **Commit:** `test(agent-smoke): record isolation findings and spec-analyser clean run`

## E3: Parallel batch of five runs (spec-analyser ×2, brief-compiler ×2, standards-setter run 1)

- **files:** `tests/agent-smoke/README.md` (results rows); on a prompt fix only, `agents/spec-analyser.md`,
  `agents/brief-compiler.md`, `agents/standards-setter.md`, `skills/stack-standards/**`.
- **depends_on:** [E2]
- **Parallelism.** The five runs are independent: each uses its own temp dir and run id. Launch them
  concurrently as background processes, then check each one when it finishes. The README rows are written
  afterwards, in one task, because all five runs write the same file. Prompt-fix loops are per agent:
  re-running a fixed agent does not hold up the others.
- **Run a, spec-analyser non-material** (902, stage `spec_analysis`, `tests/fixtures/issues/non-material-no-ui.md`,
  #102). Pass when:
  - `STATUS: ok`;
  - `spec-changes.json` has at least one change, all of them `type: non-material`, `source: auto`;
  - those changes are applied in `spec-final.md` (spot-check each one, and note it);
  - the Classification table has no `material` row;
  - the artefacts follow their templates and end in a valid return block.
- **Run b, spec-analyser material** (903, stage `spec_analysis`, `tests/fixtures/issues/material-guest-access.md`,
  #103). Pass when:
  - `STATUS: needs_input`;
  - Classification has at least one `material` row;
  - there is at least one `### Q<n>` block with a non-empty `**Recommended answer:**` line and an
    `**Alternatives:**` line, and the question is about guest versus logged-in access;
  - `spec-changes.json` holds no material change (A15);
  - the artefacts follow their templates and end in a valid return block.
- **Run c, brief-compiler pipeline, UI** (911, stage `brief`, `mode: pipeline`, #101). Seed `spec-final.md`
  from `tests/fixtures/issues/clean-ui.md`, plus `00-issue-original.md` and `issue.json` from its C3
  render. Pass when:
  - `02-brief.md` follows the template;
  - the ACs are numbered `AC-1…AC-n` contiguously, and each one is atomic and has an observable expected
    result. Judge this per AC and record it in the notes; any vague word must be converted, or listed under
    Open risks;
  - *UI flag:* `grep -E '^#{2,3} UI changes: (yes|no)$' 02-brief.md` prints exactly one line, and its value
    is `yes` (the level is `##` in `02-brief.md`);
  - the artefact and `final.txt` both end in a valid return block with `STATUS: ok`.
- **Run d, brief-compiler prompt mode, non-UI** (912, `mode: prompt`, #102). Seed `spec-final.md` from
  `tests/fixtures/issues/non-material-no-ui.md` (plus `issue.json` from its C3 render), and leave
  `docs/standards/` absent, so the A18 seed-inlining path is exercised. Pass when:
  - `prompt.md` exists and no `02-brief.md` was written;
  - its `## ` headings match `templates/artefacts/prompt.md`;
  - `grep -cE 'aew|\.aew/|/aew:|run-protocol|CLAUDE_PLUGIN_ROOT' prompt.md` is `0`;
  - `grep -c '<!--' prompt.md` is `0`;
  - *UI flag:* `grep -E '^#{2,3} UI changes: (yes|no)$' prompt.md` prints exactly one line, and its value
    is `no` (the level is `###`, under `## Brief`, in `prompt.md`);
  - every requirement in the source spec maps to an `AC-n` in `prompt.md` (contiguous numbering; record
    the mapping in the notes);
  - `prompt.md` itself has **no** return block, but `final.txt` passes `valid_return_block`.
- **Run e, standards-setter run 1** (921, stage `standards`, #101; seed `tests/fixtures/briefs/newsletter-signup.md`
  as `02-brief.md`). Before the run, record `(cd $P && $REPO/scripts/detect-stack.sh fingerprint nextjs .)`
  and the same for `tailwind`. This is the call standards-setter itself makes (Phase A contract: the
  fingerprint `[path]` is the project root, `.` from the project root, never an entry's `path`).
  Pass when:
  - the agent's own fingerprint calls in the stream (the `command` of each Bash `tool_use`) are
    `… detect-stack.sh" fingerprint <profile> .`, and their output equals the recorded value;
  - **Allow-rule match (first run with Bash):** the agent's `detect-stack.sh` calls appear in the stream in
    the prompt's quoted form, `"<substituted plugin root>/scripts/detect-stack.sh" …`, with the substituted
    root equal to `$REPO`, and none of them is in `permission_denials`. Record one such `command` verbatim.
    If the rule `Bash($REPO/scripts/detect-stack.sh *)` does not match the quoted form, choose one fix and
    record it: change the `ALLOW` rule (harness fault; for example a rule that includes the quotes), or
    micro-revise the prompt's call form in `agents/standards-setter.md` (agent fault, under the loop rules).
    The prompt's allowlist and `ALLOW` must agree afterwards;
  - **Seed path resolution:** from the stream (Read `tool_use` inputs) and `debug.log`, record which path
    the agent used to read each seed: the preloaded skill's `${CLAUDE_SKILL_DIR}/references/seeds/<profile>.md`
    as substituted, or the agent prompt's `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/`
    path, and whether any Read or debug line shows an unexpanded `${`. Write the result in the README's
    isolation section. If it shows whether `${CLAUDE_SKILL_DIR}` is substituted inside a skill preloaded by a
    subagent, and DESIGN §3 doesn't say so yet, E6 adds it to the F9 bullet. If no seed was read at all,
    find out why from the stream before classifying the fault;
  - `docs/standards/nextjs.md`, `tailwind.md` and `README.md` exist;
  - the first line of each profile doc matches
    `^<!-- aew:standards fingerprint="<recorded fingerprint>" generated="[0-9]{4}-[0-9]{2}-[0-9]{2}" -->$`;
  - `README.md` follows the index format in `document-structure.md` and lists both docs and their
    fingerprints;
  - each doc is about 400 lines or fewer (`wc -l`), and `tailwind.md` opens with "Overlay on: nextjs";
  - `03-standards.md` follows the template, both rows have Status `generated`, and the "Sections that
    apply" rows name sections that exist in the docs;
  - `STATUS: ok`.
  - **AC-18:** there is no skip warning for `aew:stack-standards`, and the context7 tool names actually
    called (the `name` values of `tool_use` events matching `mcp__`) are recorded verbatim in the README.
    If they differ from `mcp__plugin_context7_context7__*`, fix the `tools:` entry in
    `agents/standards-setter.md` and `agents/senior-engineer.md`, and carry the result to E6.
  - After it passes: `git -C $P add -A && git -C $P commit -qm standards`. This mirrors the orchestrator
    committing `docs/standards/` (prompt 05), and gives E4 a clean tree.
- **Commit:** `test(agent-smoke): record spec-analyser, brief-compiler and first standards-setter runs`

## E4: Standards-setter run 2 (the reuse check)

- **files:** `tests/agent-smoke/README.md`; `agents/standards-setter.md` only on a prompt fix.
- **depends_on:** [E3]. It needs run e's project and committed docs. Sequential.
- **Setup:** the same `$P` as run e. Run `state.sh init 922 …` and `stage standards`, and seed
  `tests/fixtures/briefs/newsletter-signup.md` as `02-brief.md`. Before the run, take
  `shasum -a 256 $P/docs/standards/*` and keep the output, and re-record
  `(cd $P && $REPO/scripts/detect-stack.sh fingerprint <profile> .)` for `nextjs` and `tailwind` in exactly
  run e's form. Both must equal run e's recorded values (the tree is unchanged since the `standards`
  commit); if they don't, the reuse expectation doesn't hold, which is a harness fault to fix before the run.
- **Pass when:**
  - the agent's fingerprint calls are again `… fingerprint <profile> .` from the project root, and their
    output equals the values recorded in setup;
  - `STATUS: ok`, and SUMMARY contains "reused";
  - `03-standards.md` has Status `reused` on both rows;
  - the checksums after the run are byte-identical to the ones before;
  - `git -C $P status --porcelain docs/standards` is empty;
  - the artefact follows its template and both return blocks are valid.
- **On failure:** if the docs were rewritten, fix the reuse rule in the prompt or the skill (exact
  fingerprint match, A7), then re-run **both** run e (on a fresh copy of the project) and run 2.
- **Commit:** `test(agent-smoke): record standards-setter reuse run`

## E5: Senior-engineer plan run

- **files:** `tests/agent-smoke/README.md`; `agents/senior-engineer.md` only on a prompt fix.
- **depends_on:** [E4]. It reuses the standards-setter project. Sequential.
- **Setup:** the same `$P`. Run `state.sh init 931 …` and `stage plan`. Seed
  `tests/fixtures/briefs/newsletter-signup.md` as `02-brief.md`, and copy `03-standards.md` from run 922.
  The dispatch is `mode: plan`, plus the fields in the agent's Inputs block.
- **Pass when:**
  - `05-plan.md` follows the template, and both return blocks are valid. STATUS is `ok`, or `needs_input`
    only with a material challenge listed under Challenges (record which);
  - "Alternatives considered" has at least one alternative, each with a reason for rejecting it;
  - the AC→WP matrix covers every AC:
    `grep -oE 'AC-[0-9]+' 02-brief.md | sort -u` equals the AC column of the traceability table, and every
    WP id named in the matrix exists as a `### WP-<n>` block;
  - at least one WP is `parallelisable: yes`, and **every** WP's value is correct under Phase D's PD-7:
    `yes` if and only if at least one other WP can run at the same time (neither depends on the other,
    directly or transitively, through `depends_on`) **and** the two share no file; otherwise `no`. A `no`
    WP needs neither a non-empty `depends_on` nor a file overlap of its own: a foundation or shared-module
    WP that every other WP depends on is correctly `no`. Also check PD-7's file rule: no file appears in two
    WPs unless the later WP depends on the earlier. Work the check from the plan's `depends_on` and owned
    files alone, record the per-WP reasoning in the notes, and compare it with the fixture brief's designed
    split;
  - every WP has standards references (the doc and section) that exist in `docs/standards/`, and unit tests
    are listed for every WP.
- **Commit:** `test(agent-smoke): record senior-engineer plan run`

## E6: Closing docs (DESIGN §3/§11, CHANGELOG, CLAUDE.md, project map)

- **files:** `docs/DESIGN.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/superpowers/project-map.md`
- **depends_on:** [E5]. It needs the empirical results from E2–E5.
- **DESIGN §3.** First grep §3, so that nothing Phases A–D already added is duplicated. Then add or extend:
  - F3: `effort` values, which depend on the model;
  - F4: the `memory` scopes `user`, `project` and `local`; memory automatically enables Read, Write and Edit,
    and has no effect when auto memory is off (extend the existing Agent memory bullet);
  - F5: `skills:` preloading — up to 32 skills; a skill with `disable-model-invocation: true` can't be
    preloaded; **a missing skill is skipped silently** (debug-log warning only). Extend the existing Skills
    in agents bullet;
  - F6, from E2: which name form works in `skills:` for plugin and dependency skills;
  - F7: a `disallowedTools` entry with a specifier removes the whole tool; a plugin can't ship
    `permissions.deny`;
  - F8: `PreToolUse` inside a subagent carries `agent_id` and `agent_type`;
  - F9: `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are substituted in agent and skill Markdown, and
    are not exported to Bash-tool commands. Add E3 run e's seed path result if it is new: whether
    `${CLAUDE_SKILL_DIR}` is substituted in a skill preloaded by a subagent. Also add whether a
    `Bash(<abs path> *)` allow rule matches the quoted `"<abs path>" …` call form, if run e settled it;
  - F12, from E3 run e: the context7 tool names exactly as observed. Correct the Namespacing bullet if they
    differ.

  Keep the existing bullet style and British English. If a smoke run contradicted §3, follow the observed
  behaviour and say so in the final report.
- **DESIGN §11.** Check that the Bash-guard bullet for the agent `gh` deny (A11) landed in Phase A. Add it
  only if it is missing; it is a single bullet.
- **CHANGELOG.md.** Under `[Unreleased]`, grep first for entries Phases A–D already added, and merge rather
  than duplicate.
  - **Added:** `detect-stack.sh` (detection and fingerprint); the `stack-standards` skill with the
    document structure and six seeds; the four agents; the fixtures; the headless smoke results in
    `tests/agent-smoke/README.md`.
  - **Changed:** the narrowed no-argument convention rule; the Bash guard now denies `gh` to `aew:*` agents.
- **CLAUDE.md.**
  - One "Recent changes" line in the existing format:
    `- 2026-10-24 · <git branch --show-current> · Standards system and planning agents (build prompt 03): … · [spec](…) · [plan](…)`.
  - If the Commands block doesn't already have it, one line pointing to `tests/agent-smoke/README.md`
    (manual headless smoke runs).
- **project-map.md.** Append to `## Project knowledge`, one terse line each:
  - the smoke harness contract (temp project under `tests/tmp/`, seeding through `state.sh init`, the
    invocation flags, the final-message jq field, `valid_return_block` loaded with `sed`);
  - the isolation findings from E2, plus run e's seed path and allow-rule results;
  - the verified `skills:` name form and the context7 tool names;
  - the dispatch fields as actually implemented (A14 final);
  - any prompt-fix lesson that generalises.

  If anything in the structural part of the map has moved, regenerate it with the project-map script; the
  knowledge section is preserved.
- **Pass criteria:** every F-row in the spec facts table marked "add" or "record" now appears in §3, or is
  noted as already present. CHANGELOG has no duplicate bullets.
- **Commit:** `docs: record verified Claude Code facts, changelog and project knowledge for prompt 03`

## E7: Verification and final report

- **files:** none. This task only verifies; any fix it needs goes back to the owning task's files and gets
  its own commit.
- **depends_on:** [E6]
- **Use** `superpowers:verification-before-completion`. Run each of these fresh and read the output:
  - `tests/run-script-tests.sh` (shellcheck plus every bats file, including `detect-stack.bats`): green;
  - `claude plugin validate .`: passes;
  - `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s templates/config.schema.json -d templates/config.example.json`
    and the same for `state.schema.json` / `state.example.json`: both valid;
  - `wc -l skills/stack-standards/references/seeds/*.md`: each is 300 lines or fewer;
  - `grep -c pending tests/agent-smoke/README.md`: `0`, and every results row is `pass`, or `flaky` with a
    final pass. A row left `fail` after three fix rounds is not green: report the phase as
    `DONE_WITH_CONCERNS` with that row, never as done;
  - `git status`: clean, and `tests/tmp/` is not tracked.
- **Final report** (returned to the orchestrator, not written to a file):
  1. **Checks run**, with their results: the commands above, plus the seven-run smoke summary and total cost.
  2. **Files created or changed** across phases A–E: `git diff --stat main...HEAD`.
  3. **Deviations from DESIGN.md and why:**
     - A2, the narrowed convention rule;
     - A11, the hook-based `gh` deny plus no Bash;
     - the CTO cut to seven runs;
     - any isolation workaround from E2 (`--add-dir`, temp dirs outside the repo);
     - the `skills:` name form, if it isn't the qualified one.
  4. **Decisions for James:**
     - the flagged assumptions that still stand (A1, A2, A6, A7, A11, A12, A18, A22);
     - A26: squash the per-task commits into the one conventional commit the prompt asks for, or keep them.
       Recommendation: keep the per-task conventional commits on the branch (the `fix(agents)` commits are
       the evidence that checks were met by prompt fixes, not weakened, and prompt 02 was merged the same
       way in PR #1); if a single commit on `main` is wanted, squash at PR merge with a
       `feat: …` title. Never rewrite history autonomously;
     - any check that ended `DONE_WITH_CONCERNS`.
- **Commit:** none, unless a verification fix is needed. A fix is committed as
  `fix(<scope>): <what was wrong>` in the owning files.

---

## Task graph

```
E1 → E2 → E3 (five runs launched concurrently) → E4 → E5 → E6 → E7
```

The parallelism is between processes inside E3. The tasks themselves are sequential, because E2–E5 all
write `tests/agent-smoke/README.md`, and E4 and E5 depend on run e's temp project. E4 and E5 can't share
that project concurrently either: `state.sh init` repoints its single `.aew/runs/current`, which the hooks
read.

## Approval

- Senior architect: APPROVED on 2026-10-24T14:23:04Z (plan-diff-review of the revision round)
- Plan format: FULL (phase E of EPIC)
- Plan dependency graph: unchanged by the revision (sequential E1 → E2 → E3 → E4 → E5 → E6 → E7; no `depends_on:` edits).
- Plan content hash (SHA-256): 336ef0bfa6feb7e004788edb24236974327a41cb89ddd97941c2b9c9a8119920 (everything above `## Approval`)
- Diff-reviewed 2026-10-24T14:23:04Z: exact C/D fixture paths and titles, C3 render reuse, per-agent `ALLOW` matching Phase C A11 and Phase D's D1/D2 allowlists, `fingerprint <profile> .` from the project root, PD-7 parallelisable check, UI-flag regex, seed-path and allow-rule checks, PD-1 shape all confirmed; mechanical fixes applied (`${ALLOW[@]+"${ALLOW[@]}"}` for bash 3.2 `set -u`, fence-skipping heading check in the fix loop).
