# Phase E plan — static checks and README

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583…6090`), overridden where they differ by the CTO simplicity-challenge cuts (2026-10-25, all adopted). The cuts that bind this phase are **1** (`skills.bats` checks statically that `resume` names the pending-gate re-ask; R1 is dropped from the simulations), **3** (the AC-2 bad-argument messages are proven statically here; at most one paid probe stays in phase F) and **11** (E1 gates phase F; E2 runs in parallel with F).
- **Phase:** E of the EPIC. `depends_on: [B, C, D]`. Phase F depends on **E1 only**. E2 depends on B–D and runs alongside F.
- **Depth:** lean
- **ACs covered:** AC-37, AC-38
- **Risk:** none of the risky criteria. One new bats file and a README section. No script, hook, agent, skill or template changes.
- **Date:** 2026-10-25
- **Naming note:** "AC-n" means the spec's ACs, "cut n" the CTO cut n, "I-n" Phase B's interface contract and "D-Cn" Phase D's. Task ids are `E1` and `E2`. The error lines `E1`–`E8` in I-7 are Phase B's names and have nothing to do with these task ids (this plan calls them "error line 1–8").

> **For agentic workers:** E1 checks files that already exist when it runs, so its RED is the absent bats file, followed by GREEN on the real tree and a **mutation proof** for the checks that could pass vacuously: each is shown to fail on a scratch copy with one planted defect, then the clean copy passes. E2's RED is the `_To be written._` placeholder under `## Commands`. Record the RED and GREEN output in the task report.

**Goal:** a `tests/scripts/skills.bats` that guards the cross-file contracts of the five entry skills (paths, agent and skill names, frontmatter, the stage coverage, the bad-argument messages, the resume re-ask), plus the README command reference and pipeline diagram.

**Architecture:** one bats file, picked up by `tests/run-script-tests.sh`'s default `bats tests/scripts` (no runner change). It loads `helpers/common` as every bats file does. It reads only files in the repo, makes no `gh` or git call and needs no fixture. It takes the stage list from `templates/state.schema.json`, so it can't drift from the schema. The README edit replaces one placeholder section. It guards contracts, not prose: it does not check wording beyond the verbatim strings the phase B/C/D contracts fix.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| Spec AC-1, AC-2, AC-20–AC-23, AC-37, AC-38 | What the checks and the README must cover |
| Phase B plan, contracts I-1, I-2, I-3 (the `gates.md` headings), I-5, I-6, I-7 and the B1 error lines | Verbatim frontmatter, the `## Stage:` headings, the routing table format, the strings to grep, name hygiene, `Answer with /aew:resume <id>`, `## Re-asking a pending gate` |
| Phase D plan, D-C1, D-C2 and cross-phase note 5 | init frontmatter, sections `## 1.` to `## 13.`, real plugin paths only, no label names |
| Phase C plan, K-1, K-2, K-3 and the phase-exit `cite_check` | resume/status/prompt frontmatter and argument hints, heading order, the strings (and count-0 bans) tests 9–11 grep, and the citation resolver test 13 lifts |
| `tests/scripts/conventions.bats` | Pattern: collect every offender, fail once, naming them (`finish_check`) |
| `tests/scripts/helpers/common.bash` | `REPO_ROOT`, `common_setup` |
| `templates/state.schema.json` | `.["$defs"].stage.enum`, the ten stages |
| `README.md`, DESIGN §5.1 and §7.3 | The section to replace, the skill table and the stage list the diagram draws |
| `skills/run-protocol/references/state-machine.md` (the Mermaid block) | The existing diagram: same stages and gates, written as a `stateDiagram-v2`. The README uses a simpler `flowchart` |

The regexes in E1 were dry-run with macOS BSD grep while this plan was written, on a sample holding B1's own sentence (`` `${CLAUDE_PLUGIN_ROOT}/…` ``), a quoted real path, a `<file>` placeholder, a brace list, bare script names, `tests/run-script-tests.sh`, `` `aew:blocked` `` and `/aew:ship-milestone`. They gave the expected tokens. The ellipsis cuts the token at `${CLAUDE_PLUGIN_ROOT}/`, which is the root and exists, so B1's sentence passes. The placeholder and the brace list are flagged. Bare names that contain a `/` are skipped.

## Tasks

Waves: **1** = E1 ∥ E2 (both after B, C and D have merged). Phase F starts once E1 has merged and does not wait for E2.

---

### Task E1 — `tests/scripts/skills.bats`

- **id:** E1
- **files:** `tests/scripts/skills.bats` (new)
- **depends_on:** [B8, D6, C1, C2, C3]. B8 is B's consistency pass, after B1–B7. D6 is the last of D's serial tasks. C1–C3 are the three Phase C skills.
- **pattern:** `tests/scripts/conventions.bats`. Same header (`#!/usr/bin/env bats`, a comment saying what it checks, `load helpers/common`, `setup() { common_setup; }`). Each test collects every offender and fails once, naming them. `finish_check` is local to conventions.bats, so E1 defines its own six-line `report_offenders <what> <offenders>`, which prints the list on stderr and returns 1 when the list is non-empty. No existing analog is shared: moving `finish_check` into `common.bash` would mean editing conventions.bats, which is out of this task's scope. Bash 3.2 only (no `mapfile`, no associative arrays, no `grep -P`, no `sed -i`).
- **AC:** AC-38 (and the static half of AC-45, cut 3)
- **Size:** about 200–250 lines, 13 tests. The long string lists in tests 8–11 are data (one string per line, read from a quoted `<<'EOF'` heredoc with `while IFS= read -r`, so backticks, `${…}` and `$` need no escaping), not extra tests.

**Shared variables** (top of the file): `ENTRY="init ship resume status prompt"`. `entry_files` lists `find "$REPO_ROOT/skills/<s>" -type f` for each entry skill, all files and not only `.md`. `frontmatter <file>` prints the lines between the first two `---` lines: `awk 'NR==1{if($0!="---")exit; next} $0=="---"{exit} {print}'`. `STAGES` comes from `jq -r '.["$defs"].stage.enum[]' "$REPO_ROOT/templates/state.schema.json"`. Every test that uses it first asserts that it has 10 entries.

**Tests** (names verbatim, so `bats -f` can target them; the strings and regexes are exact):

1. `entry skills: name and description frontmatter, no allowed-tools`. For each of the five, `skills/<s>/SKILL.md` exists. Its frontmatter has a line `name: <s>` (`grep -cx`), a line matching `^description: .+`, and no line matching `^allowed-tools:`.
2. `entry skills: disable-model-invocation on init, ship, resume and prompt, not status`. The frontmatter of init, ship, resume and prompt has `grep -cxF 'disable-model-invocation: true'` = 1. Status's frontmatter has `grep -c '^disable-model-invocation:'` = 0 (AC-22, DESIGN §5.1).
3. `entry skills: no injection or positional placeholders; one ARGUMENTS placeholder and the argument hints`. (No `$` in the test name: bats expands it, so `$ARGUMENTS` would print as an empty string. Verified with bats 1.14.0.) In all five `SKILL.md` files (the only files that get substituted), `grep -nF '!`'` and `grep -nE '\$[0-9]|\$ARGUMENTS\['` find nothing. The frontmatter has, by `grep -cxF` = 1: ship `argument-hint: "<issue> [--auto] [--from <stage>]"` (I-1), resume and status `argument-hint: "[<run-id>]"`, prompt `argument-hint: "<issue>"` (K-1). Ship, resume, status and prompt each have exactly one `$ARGUMENTS` (`grep -o '\$ARGUMENTS' | wc -l`, with spaces stripped, gives `1`) (AC-1, I-1, K-1). **Note for C and D:** an awk `$1` inside any of these `SKILL.md` files would be substituted at load, so this test enforces D-C1's "no `$N`" rule and applies the same rule to C.
4. `entry skills: every plugin path and script name exists, with no placeholder`. Three checks over `entry_files`:
   - placeholders and brace lists: `grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*[<{]'` finds nothing (I-7, D-C2);
   - existence: every token from `grep -ohE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*'`, with trailing dots stripped (`sed 's/[.]*$//'`) and the `${CLAUDE_PLUGIN_ROOT}/` prefix removed, names an existing path under `$REPO_ROOT` (`-e`). There must be at least one token; zero tokens is a failure;
   - bare script names: every token from `grep -ohE '[A-Za-z0-9_./-]*\.sh' | grep -E '^[a-z][a-z0-9-]*\.sh$'` (tokens with a `/` are skipped) exists as `scripts/<t>` or `scripts/hooks/<t>`.
5. `entry skills: every aew:<name> is an agent or a skill (ship-milestone allowed)`. Every distinct `grep -ohE 'aew:[a-z][a-z0-9-]*'` match must name `agents/<name>.md` or `skills/<name>/SKILL.md`, or be exactly `ship-milestone` (a forward reference to prompt 06; the exception is a single named case, not a pattern). This also enforces "labels are written bare" (I-7, D-C2), because a label name such as `aew:blocked` is neither an agent nor a skill.
6. `ship: a section for every schema stage and the reads table`. In `skills/ship/SKILL.md`, `grep -cxF "## Stage: <s>"` = 1 for each of the ten `STAGES`, and `grep -cxF '## What the orchestrator reads'` = 1 (I-2, I-7).
7. `ship: routing Stage table has a complete row for every schema stage`. In `skills/ship/references/routing.md`, `grep -cxF '| Stage | Entry | Exit | Failure |'` = 1. Then, for each stage, the Phase B5 awk restricted to the `## Stage table` section:
   ```
   awk -F'|' -v s="\`$s\`" '/^## /{t=($0=="## Stage table")} t && $2 ~ "^[[:space:]]*" s "[[:space:]]*$" { n++; e=$3; x=$4; fl=$5; gsub(/[[:space:]]/,"",e); gsub(/[[:space:]]/,"",x); gsub(/[[:space:]]/,"",fl); if (NF==6 && e!="" && x!="" && fl!="") ok++ } END { printf "rows=%d ok=%d\n", n, ok }'
   ```
   It must print `rows=1 ok=1`. `NF==6` proves there is no stray `|` inside a cell (I-6, AC-20). Together with test 6, this is "every DESIGN §7.3 stage has an entry, exit and failure path in ship".
8. `ship: every bad-argument case has its message`. `skills/ship/SKILL.md` contains each of these (`grep -cF --` ≥ 1). A comment maps each one to its AC-2 case:
   - error line 1 (no issue): `aew ship: missing issue number.`
   - error line 2 (non-integer, zero or negative): `must be a positive integer`
   - error line 3 (`m-<n>`): `/aew:ship-milestone (coming in a later release)`
   - error line 4 (unknown option): `unknown option`
   - error line 5 (repeated option): `given more than once`
   - error line 6 (extra positional): `unexpected argument`
   - error line 7 (`--from` without a value): `aew ship: --from needs a stage.`
   - error line 8 (unknown stage): `unknown stage`, plus `Stages: <list>.` where `<list>` is built in the test from the schema, `jq -r '.["$defs"].stage.enum | join(", ")'` (B1's E8 writes the list literally: `Stages: spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr.`). Building it from the schema means the check fails if ship's listed stages drift from the schema.
   - the usage line: `Usage: /aew:ship <issue> [--auto] [--from <stage>]`
Tests 9–11 take their strings from Phase C's K-2 (headings) and K-3 (strings). For each skill, the K-2 headings are checked as an exact ordered list: the `#` and `##` heading lines outside column-0 code fences, ``awk '/^```/{f=!f;next} !f && /^(# |## )/' <file>`` (a shell comment in a fenced snippet is not a heading), equal the K-2 column line for line (each once, in order, no other heading). Presence strings use `grep -cF --` ≥ 1, and absence strings must give count 0. Fixed strings are `-F`, and the patterns K-3 gives as regexes (`^disable-model-invocation`, `gh (…)`, `git (…)`) are `-E`. The `gh`/`git` patterns get a left boundary, `(^|[^A-Za-z0-9_-])gh (auth|issue|pr|label|api|repo)` and the same for `git (…)`, so prose such as "through issue" doesn't match.
9. `resume: re-asks a pending gate through ship's gates.md` (cut 1, AC-21). `skills/resume/SKILL.md`: the K-2 resume headings, and every K-3 resume string, including the cut-1 core (`` `gates.md` `## Re-asking a pending gate` ``, `awaiting_input`, `awaiting_plan_approval`), the two `${CLAUDE_PLUGIN_ROOT}/skills/{ship,prompt}/SKILL.md` paths written in full, `with the Skill tool`, `Steps 1–4`, `## Stage: <stage>`, ``the note `resume` ``, `` `preflight.md` `## Check 2. Clean working tree` ``, `restart form`, `git status --porcelain --untracked-files=all`, `state.sh current set <id>`, `/aew:ship <n> --from <stage>`, the five error lines and `Usage: /aew:resume [<run-id>]`. `skills/ship/references/gates.md` has `grep -cxF '## Re-asking a pending gate'` = 1. `skills/ship/SKILL.md` contains `Answer with /aew:resume <id>` (I-5), the line that points the user at the re-ask.
10. `status: reads only, names no script and runs no git or gh` (AC-22). `skills/status/SKILL.md`: the K-2 status headings; the K-3 status presence strings (the run-id pattern, `.aew/runs/*/state.json`, `tail -n 10`, `max_review_cycles // 2`, `max_fix_cycles // 3`, the I-5 lookup command, one `` | `<status>` | `` row for each of the six statuses (`grep -c '^| `<s>` |'` = 1), the four lines and `Usage: /aew:status [<run-id>]`); and count 0 for every K-3 status absence entry. Nothing under `skills/status/` matches `grep -rF '${CLAUDE_PLUGIN_ROOT}/scripts/'`.
11. `prompt: ship's run start and spec gate by citation, then the brief in prompt mode` (AC-23). `skills/prompt/SKILL.md`: the K-2 prompt headings; every K-3 prompt presence string (the preflight Check 1, 3 and 5 citations, `` `SKILL.md` `## Step 3. Start the run` ``, `3.1`, `3.5`, `3.6`, the three `gates.md` citations and `` `SKILL.md` `## Gate pending` ``, `D1`, `D2`, `D4`, `mode: prompt`, `gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`, `AskUserQuestion`, `Not posted.`, `/aew:ship <n> --from spec_analysis`, the three error lines and `Usage: /aew:prompt <issue>`); and count 0 for `` `preflight.md` `## Check 2 ``, `gh-labels.sh`, `git-branch.sh` and `git (add|commit|switch|push)`. The PC-1 marker string `state.sh stage spec_analysis --note "prompt mode"` is in the list too, but **marked for the consolidator**: Phase B's I-11 writes `--note "prompt"`, Phase C's PC-1 writes `"prompt mode"`, and the test takes whichever B and C settle on.
12. `init: numbered sections 1 to 13 in order` (D-C1). `grep -E '^## [0-9]+\. ' skills/init/SKILL.md | sed -E 's/^## ([0-9]+)\..*/\1/' | tr '\n' ' '` equals `1 2 3 4 5 6 7 8 9 10 11 12 13 `.
13. `ship, resume and prompt: every file-and-heading citation resolves` (B1 citation form, C's phase-exit check, cut 1). Phase C's `cite_check` lifted as-is (it was dry-run under bash 3.2): over every `.md` file under `skills/ship/`, `skills/resume/` and `skills/prompt/`, each distinct `` `<file>.md` `## <heading>` `` citation (`SKILL.md` → `skills/ship/SKILL.md`, `prompt/SKILL.md` → `skills/prompt/SKILL.md`, any other name → `skills/ship/references/<name>`) names a file whose `grep -cxF '<heading>'` is 1. Every unresolved citation is listed. At least one citation must be found in `skills/ship/SKILL.md`; none at all is a failure, so the check can't pass because the regex matched nothing. This is the static guard for "resume enters ship at a named section", which cut 1 leaves unsimulated.

`claude plugin validate .` (part of AC-38) is not in bats, because it needs the `claude` CLI. It is a verification step below and in phase F.

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
bats tests/scripts/skills.bats
```

Expected: bats reports that `tests/scripts/skills.bats` does not exist, with a non-zero exit.

**Step 2: write `tests/scripts/skills.bats`** with the 13 tests above.

**Step 3: GREEN on the real tree.**

```sh
bats tests/scripts/skills.bats            # 1..13, every line "ok", exit 0
tests/run-script-tests.sh                 # shellcheck (over scripts and helpers; bats files are not in its list) and the whole suite pass, skills.bats included; exit 0
claude plugin validate .                  # passes, as before
```

If a test fails on the real tree, the fault is in the skill (or in a contract this plan copied wrongly). Report it: the fix goes in the owning phase's files (B, C or D), not in E1's commit, or the contract is reconciled. Never weaken the check.

**Step 4: mutation proof** for the checks that could pass vacuously: the absence checks, the token extractors, the routing awk and the citation resolver. A regex that matches nothing passes an absence check silently, so each of these must be seen to fail once. The presence checks (fixed strings, exact headings, the init section list) can't pass vacuously: GREEN on the real tree is their evidence, and a wrongly copied string fails GREEN. Build a scratch copy under the gitignored `tests/tmp/`, so `REPO_ROOT` resolves to the copy:

```sh
M=tests/tmp/skills-mut
reset_copy() { rm -rf "$M" && mkdir -p "$M/tests/scripts" && cp -R agents skills scripts templates "$M/" && cp -R tests/scripts/skills.bats tests/scripts/helpers "$M/tests/scripts/"; }
```

For each row: run `reset_copy`, apply the defect with `perl -0pi -e` (or append with `printf >>`), then run `bats -f '<test name prefix>' "$M/tests/scripts/skills.bats"`. Expected: `not ok`, exit 1, with the planted offender named in the output.

| # | Defect planted in the copy | Test that must fail |
|---|---|---|
| 2 | add `disable-model-invocation: true` to status's frontmatter | 2 |
| 3 | append `` awk '{print $1}' `` to `skills/init/SKILL.md` | 3 |
| 4a | append `` `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/<file>.md` `` to ship's `SKILL.md` | 4 |
| 4b | append `` `${CLAUDE_PLUGIN_ROOT}/scripts/nope.sh` `` to ship's `SKILL.md` | 4 |
| 4c | append `` run `stat.sh` `` to ship's `SKILL.md` | 4 |
| 5 | append `` the `aew:blocked` label `` to ship's `SKILL.md` | 5 |
| 7a | in `routing.md`, put a `|` inside a cell of the `` `review` `` row | 7 |
| 7b | delete the `` `pr` `` row from `routing.md` | 7 |
| 10a | append `` `${CLAUDE_PLUGIN_ROOT}/scripts/state.sh` `` to status's `SKILL.md` | 10 |
| 10b | append `then run gh issue view` to status's `SKILL.md` | 10 |
| 11 | append `` `gh-labels.sh` `` to `skills/prompt/SKILL.md` | 11 |
| 13 | in `skills/ship/references/gates.md`, rename `## Re-asking a pending gate` to `## Re-asking a gate` | 13 (and 9) |

Then `reset_copy && bats "$M/tests/scripts/skills.bats"` (all 13 ok), followed by `rm -rf "$M"`. Test 5 passing on the clean copy, where `/aew:ship-milestone` appears in ship's error line 3, is the evidence for the forward-reference exception. Finish with `git status --porcelain`, which shows only `tests/scripts/skills.bats`.

**Step 5: commit.**

```
test(skills): add static checks for the five entry skills

skills.bats checks that every ${CLAUDE_PLUGIN_ROOT} path, bare script
name and aew:<name> the init, ship, resume, status and prompt skills
mention exists (ship-milestone is allowed as a forward reference, and
label names fail, so labels stay bare). It also checks the frontmatter
(disable-model-invocation on all but status, ship's argument hint, no
allowed-tools, no injection or positional placeholders), a ship section
and a complete routing row for each schema stage, every AC-2
bad-argument message, the resume, status and prompt headings and
contract strings (resume's pending-gate re-ask, status naming no script
and running no git or gh, prompt reusing ship's gates), init's 13
sections, and that every file-and-heading citation in ship, resume and
prompt resolves.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task E2 — README command reference and pipeline diagram

- **id:** E2
- **files:** `README.md` (the `## Commands` section only)
- **depends_on:** [B8, D6, C1, C2, C3]. It runs in parallel with E1 and with phase F (cut 11).
- **pattern:** the README's existing style (short prose, British English, fenced `bash` examples, one table where it helps). The facts come from the merged skills: each skill's frontmatter `argument-hint` and `description`, ship's gates (`gates.md` `## Gate ids and pending state`), init's sections 5, 8 and 10 (its three asks), and the stage list in DESIGN §5.1 and §7.3. The README restates no procedure detail and links to `docs/DESIGN.md` for that.
- **AC:** AC-37
- **Size:** about 70–100 lines added. The other `_To be written._` sections (Config reference, Labels, Uninstall) stay as they are (spec scope: out).

**Content.** Replace the `_To be written._` line under `## Commands` with:

- One subsection per command, with these headings verbatim and in this order: `### /aew:init`, `### /aew:ship`, `### /aew:resume`, `### /aew:status`, `### /aew:prompt`. Each one has:
  - the syntax in backticks, exactly: `/aew:init`, `/aew:ship <issue> [--auto] [--from <stage>]`, `/aew:resume [<run-id>]`, `/aew:status [<run-id>]`, `/aew:prompt <issue>`;
  - what it does, in two to four sentences;
  - which gates ask:
    - init: one config question round, the Playwright offer and the permissions proposal; with no answer it uses safe defaults and writes no settings;
    - ship: the material spec change gate (always, even with `--auto`), the plan gate (skipped with `--auto` or `gates.plan_approval: false`), and the QA triage and spec-ambiguity questions; an unanswered gate stays pending until `/aew:resume`;
    - resume: re-asks the pending gate;
    - status: none, read-only;
    - prompt: the spec gate, then the offer to post `prompt.md`;
  - one example, as an inline code line or a short fenced block, for example `/aew:ship 42 --auto` or `/aew:ship 42 --from review`.
- One line saying `/aew:ship-milestone` (milestone runs) is coming in a later release.
- `### Pipeline`: one fenced ```` ```mermaid ```` block whose first line is `flowchart TD`, drawing: `spec_analysis` → `brief` → `standards` → `qa_test_plan` and `plan` in parallel (a fork and join, or a subgraph) → the plan gate (with the skip edge for `--auto`) → `develop` → `review` → `qa` → `docs` → `pr` → done. Also draw the spec gate loop off `spec_analysis`; the review loop `changes_required` → `develop`, labelled with `max_review_cycles` (default 2); the QA loop failures → triage or fix → `qa`, labelled with `max_fix_cycles` (default 3); and a `blocked` exit (a cycle limit, or an agent failing twice), reached from the loops, with "report comment, resume with `/aew:resume`". Quote every node and edge label that contains punctuation (`A["…"]`, `-- "…" -->`), which is Mermaid's usual parse trap. One sentence under the block points at `skills/run-protocol/references/state-machine.md` for the full state machine.

**Step 1: RED.**

```sh
awk '/^## Commands$/{f=1;next} /^## /{f=0} f' README.md | grep -cxF '_To be written._'   # 1
grep -c '^```mermaid$' README.md                                                       # 0
```

**Step 2: write the section** as above.

**Step 3: GREEN.**

```sh
S=$(awk '/^## Commands$/{f=1;next} /^## /{f=0} f' README.md)
printf '%s\n' "$S" | grep -cxF '_To be written._'                                     # 0
for h in '### /aew:init' '### /aew:ship' '### /aew:resume' '### /aew:status' '### /aew:prompt' '### Pipeline'; do printf '%s=%s\n' "$h" "$(printf '%s\n' "$S" | grep -cxF "$h")"; done   # each =1
for x in '/aew:ship <issue> [--auto] [--from <stage>]' '/aew:resume [<run-id>]' '/aew:status [<run-id>]' '/aew:prompt <issue>' 'ship-milestone' 'max_review_cycles' 'max_fix_cycles' 'blocked' 'qa_test_plan'; do printf '%s=%s\n' "$x" "$(printf '%s\n' "$S" | grep -cF -- "$x")"; done   # each >= 1
printf '%s\n' "$S" | grep -A1 -xF '```mermaid' | sed -n 2p                            # flowchart TD
grep -c '_To be written._' README.md                                                  # 3 (Config reference, Labels, Uninstall untouched)
git diff --stat                                                                        # README.md only
```

No local Mermaid render. `mmdc` pulls puppeteer and a Chromium for a single diagram, and its bundled Mermaid version is not GitHub's, so a local pass wouldn't prove the GitHub render anyway. The checks are: (a) a syntax read of the block against the rules above (the first line is `flowchart TD`; every label with punctuation is quoted; node ids are bare `[A-Za-z_]` words; no `end` as a bare node id, which is Mermaid's reserved word), recorded in the task report; (b) the render that matters, on GitHub. Once the branch is pushed, the README on the branch or PR page must show a diagram, not a "Unable to render" box. The human reviewer checks this at the PR, and a broken render is a one-line fix.

**Step 4: commit.**

```
docs(readme): add the command reference and pipeline diagram

Replaces the Commands placeholder with a reference for /aew:init,
/aew:ship, /aew:resume, /aew:status and /aew:prompt (syntax, what each
does, which gates ask, an example), notes that /aew:ship-milestone is
coming in a later release, and adds a Mermaid flowchart of the pipeline:
the stages, the parallel QA plan and plan step, both gates, the review
and QA loops with their limits, and the blocked exit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

## AC → task matrix

| AC | Task | Evidence |
|---|---|---|
| AC-37 | E2 | Step 3 greps, the recorded syntax read, and the GitHub render at the PR |
| AC-38 | E1 | `bats tests/scripts/skills.bats` 13/13, the mutation table, `tests/run-script-tests.sh`, `claude plugin validate .` |
| AC-45 (static half, cut 3) | E1 test 8 | The bad-argument messages are present. The single paid probe stays in phase F |

## Cross-phase notes (to reconcile)

1. **Phase C (reconciled at plan review):** tests 3 and 9–11 take their argument hints, headings and strings from C's K-1, K-2 and K-3, and test 13 lifts C's `cite_check`. If C changes a contract string, the matching test string changes with it. Don't drop the check. One string is still open, **for the consolidator**: the prompt-run marker. B's I-11 writes `--note "prompt"`, C's PC-1 writes `--note "prompt mode"`, and test 11 uses whichever B and C settle on. Test 5 (an agent, a skill or `ship-milestone`) is looser than K-3's "slash commands only" rule, so C passes it.
2. **Phases B, C and D:** test 3 forbids `$<digit>` and `$ARGUMENTS[` in every entry `SKILL.md`. Claude Code substitutes them at load, so an awk `$1` in a `SKILL.md` snippet would break. Awk field references belong in reference files (read with Read, not substituted). D's snippets are in `SKILL.md`, so D must avoid `$N` there, as D-C1 already says. Test 4 also flags brace lists (`${CLAUDE_PLUGIN_ROOT}/scripts/{a,b}.sh`): the skills name each path in full (D-C2).
3. **Phases B, C and D:** test 5 accepts only agents, skills and `ship-milestone`. Any other `aew:<x>`, including a label or `plugin:aew:playwright`, fails it. Labels are written bare (I-7).
4. **Phase F:** depends on **E1 only** (cut 11). E2 runs alongside F. CHANGELOG, project-map and CLAUDE.md entries for `skills.bats` and the README section are F's closing docs (cut 10), not this phase's.
5. **Consolidator:** neither task touches a file outside its `files:` list. E1 and E2 share no file, so they can run in parallel worktrees.

## Approval (Phase E)

- Senior architect: APPROVED 2026-10-25T00:16:08Z (plan-review, lean)
- Plan format: LEAN
- Dependency graph: valid. One wave (E1 ∥ E2) after B8, D6 and C1–C3. No shared files. Phase F waits on E1 only.
- Open for the consolidator: the prompt-run marker string (B I-11 `"prompt"` or C PC-1 `"prompt mode"`), used by test 11.
- Plan content hash (SHA-256, the doc above this trailer): 9e72a53fe7c5edeaa53c0d25f6011f4d5119aaa7c628b6c5aaa16c769db158ea
