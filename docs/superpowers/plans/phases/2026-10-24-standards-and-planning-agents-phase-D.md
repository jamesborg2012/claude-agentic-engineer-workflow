# Phase D plan — standards-setter and senior-engineer agents

- **Spec:** `docs/superpowers/specs/2026-10-24-standards-and-planning-agents.md` (hash `d41b2001…99c1`)
- **Phase:** D of the EPIC. `depends_on: []` (CTO cut): written against the spec's fixed contracts while Phases A and B are built in parallel. The agents are first *run* in Phase E.
- **Depth:** full
- **ACs covered:** AC-11 and AC-12 (for these two agents), AC-13 (standards-setter and senior-engineer bullets), AC-15 (the `tests/fixtures/briefs/` half)
- **Risk:** none. Markdown prompts and one fixture; nothing executes until Phase E.
- **Date:** 2026-10-24

## Purpose

Phase D writes two complete agent system prompts, `agents/standards-setter.md` and `agents/senior-engineer.md`, and the fixture brief that Phase E's senior-engineer smoke run plans against. It edits no file owned by another phase. It consumes, but does not build, `scripts/detect-stack.sh` (Phase A), the `gh` guard in `guard-bash.sh` (Phase A) and the `stack-standards` skill (Phase B).

## Facts verified while planning (not assumptions)

Checked on this machine (Claude Code 2.1.308) in a throwaway plugin under the session scratchpad:

- **`claude plugin validate .` does not validate agent frontmatter.** An agent with unparseable YAML (`description: [unclosed`), `name: bad:x`, `model: gpt9`, `effort: extreme` and `memory: galaxy` passed with exit 0 and no agent finding. So validate is necessary but not sufficient: each task also parses the frontmatter and asserts every value (check C1 below).
- `/usr/bin/ruby` (2.6, system) parses YAML with `YAML.safe_load`; `python3` has no `yaml` module and `yq` is absent. Ruby is used only in the one-off checks, never in shipped code.
- An unquoted `tools: Read, …, mcp__plugin_context7_context7__*` line parses as one plain string (the `*` is mid-scalar, not an alias).
- The DESIGN §8.1 "Material (ask first)" list extracts cleanly as eight lines with `sed -n '/\*\*Material (ask first):\*\*/,/^- \*\*Output/p' docs/DESIGN.md | sed -n 's/^    - //p'`, so the verbatim check needs no hand-copied list.
- `gate-subagent.sh` cannot be sourced (it runs on load), but `valid_return_block` can be lifted with `eval "$(sed -n '/^valid_return_block() {/,/^}/p' scripts/hooks/gate-subagent.sh)"`.

## Decisions made in this phase (flag if wrong)

| # | Decision | Why |
|---|---|---|
| PD-1 | Shared shape for all four agents (orchestrator reconciliation): the mandatory `##` headings, in this order, are `Role`, `Inputs`, `Process`, `Outputs`, `Return contract`, `Guardrails`, `Autonomy`, `Definition of done`. Agent-specific `##` sections are allowed only between `Inputs` and `Process`; a `## Memory` section is allowed only between `Autonomy` and `Definition of done`, for agents with `memory:`. Both D agents have memory, so both carry `## Memory` in that slot; neither needs an agent-specific `##`. No other `##` line appears in the body (subsections are `###`; templates are cited by path, never pasted). Phase C uses the same shape. | AC-11's list, made mechanically checkable. |
| PD-2 | Dispatch fields per A14. Fallbacks when a field is absent: `run_dir` → `.aew/runs/$(cat .aew/runs/current)`; senior `n` → review: `review_cycle + 1` from `state.json`; triage: the highest `<n>` among `08-qa-report-<n>.md`; senior `base` → `state.json` `base_branch`. A missing or unknown `mode` is `STATUS: blocked`. | The run dir alone must be enough to resume (spec-review note 4 applies the same idea to spec-analyser). The fallbacks restate run-protocol's naming rule; they invent nothing. |
| PD-3 | standards-setter, empty detection (`[]`): writes `03-standards.md` with "No stack detected by detect-stack.sh." under both tables, writes no standards doc, `STATUS: ok`. | Not James's decision (principle 5); downstream agents then fall back to repo conventions. |
| PD-4 | standards-setter writes `docs/standards/README.md` only when a doc was generated or updated, or the README is missing or omits a current profile. When every fingerprint matches it writes nothing under `docs/standards/` (byte-identical, AC-16). | AC-13 "reuses the doc unchanged"; the smoke reuse check checksums the whole directory. |
| PD-5 | standards-setter `ARTEFACTS`: `03-standards.md` first, then `docs/standards/README.md`, then every applicable profile doc, reused ones included. | Matches the template's ARTEFACTS line; downstream agents need the doc paths either way. |
| PD-6 | senior plan with a material challenge: still writes the complete plan on the recommended answer, and returns `needs_input` with the questions in "Challenges to the spec". | James can then approve by accepting the recommendation, with no second plan run. |
| PD-7 | `parallelisable: yes` iff at least one other WP can run at the same time (neither depends on the other, directly or transitively) **and** the two share no file. Otherwise `no`. No file appears in two WPs; if one must, the later WP depends on the earlier. | Makes the AC-16 "correctly marked" check decidable from the plan alone. |
| PD-8 | senior review: an empty diff is `changes_required` with one blocker; an unresolvable `base` or unreadable plan/brief is `STATUS: blocked`. `STATUS: ok` for both verdicts (A17). | A17; an empty diff is a result, not an inability to review. |
| PD-9 | senior triage: if the divergence started in the spec and fixing it is material (DESIGN §8.1 list), `STATUS: needs_input` with a question and recommended answer; otherwise `ok`. | The spec is James's to change (principle 5). |
| PD-10 | Static checks live as throwaway scripts in `tests/tmp/phase-d/` (gitignored) and are not committed. Phase E's headless runs are the behavioural tests. If the assembler wants a durable guard, the same checks fit a `tests/scripts/agents.bats`; not planned. | Simplicity (CLAUDE.md); no DESIGN item calls for an agent lint. |
| PD-11 | Fixture brief theme: "Newsletter sign-up in the site footer" (#101), file `tests/fixtures/briefs/newsletter-signup.md`. It is the **compiled brief of Phase C's clean UI issue fixture** `tests/fixtures/issues/clean-ui.md` (#101, newsletter form in the footer; orchestrator reconciliation): same issue number and title, and every requirement of that issue maps to one of the brief's ACs, with nothing added that the issue doesn't imply. At assembly, the two are cross-checked; if they diverge, D3 is micro-revised to match the issue (the issue is upstream). It cites Phase A's `nextjs-tailwind` paths `app/layout.tsx`, the Tailwind CSS file and `package.json`. **Phase A contract (confirmed by the orchestrator):** `app/layout.tsx` renders an existing footer element, `app/page.tsx` renders static article cards from an array module, a CSS file holds `@import "tailwindcss"`, `package.json` has `next`, `react`, `typescript`, `tailwindcss`, and there is no auth or database. Use A's actual CSS file name once A lands. | A20/A21; coherent with Phase C's clean issue and Phase A's tree. |

## Shared conventions for D1 and D2

These apply to both prompts; each task repeats them in its own words (prompts are self-contained, so no shared include).

- **Paths.** Plugin files are written literally as `${CLAUDE_PLUGIN_ROOT}/…` in the body (substituted at load, F9). The prompt says once, without naming the variable (so the C4 spelling check holds): "Plugin paths in this prompt are already absolute. Use them exactly as written. The plugin-root variable is not set in the Bash tool, so never rebuild these paths from the shell. If a preloaded skill shows a path that still contains an unexpanded `${…}`, use the matching plugin path from this prompt instead." (The last sentence covers Phase B's `${CLAUDE_SKILL_DIR}` seed paths if they are not substituted inside a preloaded subagent; Phase E confirms.) Every other path is relative to the project root, which is the working directory. Every `${CLAUDE_PLUGIN_ROOT}` occurrence is followed by `/`.
- **Templates.** Each output names its template: `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/<name>.md`. "Read it, start from it, keep every heading and its order, replace every `<placeholder>`, delete the instruction comments, end with the return block."
- **No GitHub.** Guardrails carry run-protocol's wording: "Never run `gh`, and never push, merge or open a PR. The aew Bash guard denies `gh` for every aew agent, so trying only wastes a turn. Issue content comes from the run dir."
- **Bash allowlist.** The prompt lists the exact commands the agent may run (below), and says "nothing else". Phase E uses the same list for `--allowedTools`.
- **Memory.** A `## Memory` section between `Autonomy` and `Definition of done` (PD-1): what to record (A19), what never to record (secrets, run-specific detail, anything already in `docs/standards/`), and that `Edit` and `Write` are allowed only in the memory dir and the role's write paths.
- **Return contract.** The four-line block (DESIGN §7.5), the agent's own meaning for each STATUS, and "the block is the last four non-blank lines of both the final message and the primary artefact".

## Tasks

All three tasks own disjoint files and can run in parallel.

```
- id: D1
  title: standards-setter agent prompt
  files: [agents/standards-setter.md]
  depends_on: []
  parallelisable: yes
  pattern: skills/run-protocol/SKILL.md (frontmatter + "Agents never touch GitHub" wording); templates/artefacts/standards-run.md (output); DESIGN §8.3
  checks: C1 frontmatter, C2 headings, C3 required strings, C4 path spelling, C5 British English, C6 validate
  ac: [11, 12, 13]
- id: D2
  title: senior-engineer agent prompt (plan, review, triage)
  files: [agents/senior-engineer.md]
  depends_on: []
  parallelisable: yes
  pattern: skills/run-protocol/SKILL.md; templates/artefacts/{plan,review,triage}.md; DESIGN §8.4, §8.1 material list, §8.6 triage classes
  checks: C1–C6, plus C7 material list verbatim
  ac: [11, 12, 13]
- id: D3
  title: senior-engineer fixture brief
  files: [tests/fixtures/briefs/newsletter-signup.md]
  depends_on: []
  parallelisable: yes
  pattern: templates/artefacts/brief.md
  checks: F1 headings, F2 ACs, F3 UI flag, F4 return block, F5 no leftover placeholders or comments, F6 #101 alignment
  ac: [15]
```

---

### D1 — `agents/standards-setter.md`

**Frontmatter** (exact values; F1 keys only):

```yaml
---
name: standards-setter
description: Detects the project's stacks, reuses or writes the per-stack docs in docs/standards/, and records in the run dir which standards sections apply to this brief. Dispatched by the aew orchestrator only; don't use it directly.
model: sonnet
effort: medium
memory: project
skills:
  - aew:run-protocol
  - aew:stack-standards
tools: Read, Grep, Glob, Write, Edit, Bash, mcp__plugin_context7_context7__*
---
```

No `disallowedTools` (F7: `Bash(gh *)` would remove all of Bash). Edit is listed explicitly because the *updated* path edits existing docs (memory would add it anyway, F4).

**Body outline** (target 150–230 lines):

1. **`## Role`** (3–5 lines). You are aew's standards-setter, the `standards` stage. You make sure the project has an accurate, current standards doc per stack profile, and you tell later agents which parts apply to this brief. Repo conventions beat generic standards (DESIGN principle 6). The preloaded `stack-standards` skill is your method; this prompt is your job.

2. **`## Inputs`**.
   - Dispatch fields: `run_dir` (for example `.aew/runs/42`); fallback per PD-2. Nothing else.
   - Read: `<run_dir>/02-brief.md` (required; the ACs, their tags and "Affected surfaces" drive section selection; its H1 gives `#<issue> <title>`); `.aew/config.json` (optional, `stacks` and `commands` only, for cross-checking); existing `docs/standards/*.md`.
   - Plugin files: `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`, `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/document-structure.md`, `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/<profile>.md`, `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/standards-run.md`.
   - The path note from "Shared conventions".

3. **`## Process`**, numbered steps:
   1. Read the brief. Missing or with no `AC-` ids → `blocked`.
   2. Detect: run `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" .`. Output is a JSON array of `{profile, path, version, evidence}`, already ordered. Non-zero exit → `failed`, quoting the `error:` line. `[]` → PD-3.
   3. Group by profile. One doc per profile (DESIGN §6); its fingerprint is that of the profile's **first** entry in detection order (the script picks it, step 4), and other paths are listed under Project structure (A7).
   4. For each profile, fingerprint, run from the project root (the same `.` as step 2): `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" fingerprint <profile> .`. The `.` is the scan root, not an entry path; the script fingerprints the first entry of that profile in detection order, so one call per profile, never one per entry. Take the printed line verbatim (format `<profile> dep@major… cfg:<hash12>`); never reformat it.
   5. Decide per profile, by reading line 1 of `docs/standards/<profile>.md`, which must be `<!-- aew:standards fingerprint="<line>" generated="YYYY-MM-DD" -->`:
      - **reused**: exact string match of `fingerprint`. Don't write, re-save or reformat the file.
      - **updated**: the doc exists and the value differs, or the header is missing or malformed.
      - **generated**: no doc.
   6. Generate or update, following `document-structure.md` for the section order, the **[tool]**/**[convention]** markers, the do/don't format and the ~400-line limit. Sources, quoted in DESIGN §8.3 order (verbatim list of four):
      1. repo tool configs (eslint, prettier, tsconfig, phpcs.xml, pint.json, phpstan, stylelint, .editorconfig, Directory.Build.props, .csharpierrc…);
      2. patterns sampled from existing code;
      3. the plugin's seed reference for the profile;
      4. context7 for version-specific guidance.

      Sub-rules:
      - Read every config present at the stack path and the repo root. Never read `.env*` or secret files.
      - Sample 3–6 representative source and test files per profile (Glob/Grep), and record the naming, structure and test layout you actually see. Where code contradicts the seed, the code wins, and the rule is marked [convention] with a one-line "observed in <path>".
      - A rule is **[tool]** only if a config in this repo enforces it. Re-mark seed rules accordingly.
      - context7: `resolve-library-id`, then `query-docs`, only for the detected major where the seed's "Versions covered" line doesn't cover it, or for a rule you need to confirm. If context7 is unavailable or rate-limited, continue without it and say so in the doc's sources line and in SUMMARY.
      - No seed (`dotnet`): generate on demand from sources 1, 2 and 4, and say "no seed; generated on demand" in SUMMARY so the doc-writer can raise the retro item (DESIGN §8.3).
      - Overlays (`tailwind`, `woocommerce`): their own doc, opening with "Overlay on: <base>", holding only additions and overrides. Overlay beats base; the repo beats both (A9).
      - **Updated** (A10): re-derive [tool] rules from the configs; keep [convention] rules and hand edits unless a new config or major contradicts them, and note each replacement in the doc's change line.
      - Line 1 is the header with the step 4 fingerprint and `generated=` today's date from `date +%Y-%m-%d`.
   7. README: PD-4. Format from `document-structure.md`.
   8. Write `<run_dir>/03-standards.md` from the template, **always**, even when everything was reused:
      - "Standards docs": one row per profile, base before overlay, with the exact fingerprint and status.
      - "Sections that apply": only the sections this brief touches, each row citing an AC id or affected surface. Heuristic table in the prompt: `[UI]` → framework conventions (components), accessibility; `[API]` → error handling, security, framework conventions (routing); `[DATA]` → framework conventions (data), security; `[SEC]` → security; `[A11Y]` → accessibility; `[PERF]` → framework conventions, anti-patterns. "Tooling and commands" and "Testing conventions" always apply, because every work package runs them. Don't list a section because it exists.
   9. Update memory (see `## Memory`), then return.

4. **`## Outputs`**: `docs/standards/<profile>.md` (generated or updated only), `docs/standards/README.md` (PD-4), `<run_dir>/03-standards.md` (always), each with its template or structure path. The standards docs are committed later by the orchestrator or init, never by this agent (A10).

5. **`## Return contract`**: the block, plus:
   - `ok`: `03-standards.md` is complete (whatever the per-profile statuses);
   - `blocked`: brief missing or without ACs, or `detect-stack.sh` missing;
   - `failed`: a script error, or a doc or artefact couldn't be written;
   - `needs_input`: not used by this agent (state it).
   - SUMMARY lists `<profile>: reused|generated|updated`, and says "reused" when every fingerprint matched (template rule). ARTEFACTS per PD-5. NEXT: "plan and qa_test_plan can start", or the blocking reason.

6. **`## Guardrails`**:
   - Write only `docs/standards/**`, `<run_dir>/03-standards.md` and `.claude/agent-memory/standards-setter/`. Never edit source, tool configs, `CLAUDE.md`, `.aew/config.json` (the orchestrator writes `stacks`) or `state.json`/`log.md` (script-owned).
   - Bash: exactly `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" …` (both forms) and `date +%Y-%m-%d`. No installs, builds, lint, tests, network or git writes. Never commit.
   - The no-GitHub wording.
   - Never copy a seed wholesale without checking it against the repo; never exceed ~400 lines; no secrets, tokens or env values in docs.

7. **`## Autonomy`**: never ask; you can't (subagents have no `AskUserQuestion`, F11). Every choice is settled by the source priority. Record judgement calls in the doc as [convention] rules with their evidence, not as questions.

7a. **`## Memory`** (PD-1 slot): record conventions discovered and why they were chosen over the seed (one line each, dated); don't record secrets, run detail, or anything already in `docs/standards/`.

8. **`## Definition of done`** (checklist):
   - Every detected profile has a row and a status.
   - Reused docs are untouched.
   - Every generated or updated doc starts with a valid header whose fingerprint is the script's line verbatim, follows `document-structure.md` order, and marks every rule.
   - README lists every profile.
   - `03-standards.md` keeps the template's headings in order, and every "Sections that apply" row cites an AC or surface.
   - The return block ends both the artefact and the final message.

**Checks (D1).** Write `tests/tmp/phase-d/check-agent.sh` (C1–C6, parameterised by file and C1 values, reused by D2) **before** authoring, run it against the missing file and capture the failure (the RED), then author and re-run until it passes (the GREEN). `tests/tmp/` is gitignored, so the script never travels between worktrees or to the integration branch: whichever tree runs a check (D1's, D2's, or the phase exit) recreates it from the C1–C7 text in this plan. D2 therefore has no hidden dependency on D1.

- **C1 frontmatter**:
  ```bash
  /usr/bin/ruby -ryaml -e '
    fm = File.read(ARGV[0])[/\A---\n(.*?)\n---\n/m, 1] or abort "no frontmatter"
    y = YAML.safe_load(fm)
    { "name"=>ARGV[1], "model"=>ARGV[2], "effort"=>ARGV[3], "memory"=>"project" }.each { |k,v| y[k]==v or abort "#{k}: #{y[k].inspect}" }
    y["skills"]==ARGV[4].split(",") or abort "skills: #{y["skills"].inspect}"
    y["tools"].split(/,\s*/).sort==ARGV[5].split(",").sort or abort "tools: #{y["tools"]}"
    y["description"].include?("aew orchestrator only") or abort "description"
    ok = %w[name description model effort maxTurns autoCompactWindow tools disallowedTools skills memory background omitClaudeMd isolation color]
    (y.keys-ok).empty? or abort "unhonoured keys: #{y.keys-ok}"
    y.key?("disallowedTools") and abort "disallowedTools removes Bash (F7)"
    puts "C1 ok"' agents/standards-setter.md standards-setter sonnet medium \
    aew:run-protocol,aew:stack-standards 'Read,Grep,Glob,Write,Edit,Bash,mcp__plugin_context7_context7__*'
  ```
- **C2 headings** (PD-1 shape: mandatory order, extras only in the two slots): skip fenced code blocks (the same awk toggle as Phase C), drop any agent-specific headings between `Inputs` and `Process`, then compare with the mandatory list, with `Memory` in its slot (both D agents have memory, so it is required here):
  ```bash
  got=$(awk '/^```/{f=!f;next} !f && /^## /' "$f" | sed 's/^## //' | awk '/^Inputs$/{print; skip=1; next} /^Process$/{skip=0} !skip')
  want=$(printf '%s\n' Role Inputs Process Outputs 'Return contract' Guardrails Autonomy Memory 'Definition of done')
  [ "$got" = "$want" ] || { echo "C2 headings:"; diff <(echo "$want") <(echo "$got"); exit 1; }
  ```
  A `## Memory` anywhere else, or any other extra `##` outside a fence, fails.
- **C3 required strings** (`grep -qiF` each, case-insensitive; any miss fails): `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`, `fingerprint <profile> .`, `<!-- aew:standards fingerprint="`, `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/standards-run.md`, `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/document-structure.md`, `references/seeds/`, `docs/standards/README.md`, `03-standards.md`, `reused`, `updated`, `generated`, `Overlay on:`, `[tool]`, `[convention]`, `resolve-library-id`, `query-docs`, `never run \`gh\``, `Never commit`, `run_dir`, `STATUS: ok | needs_input | blocked | failed`, `.claude/agent-memory/standards-setter/`; plus the four DESIGN §8.3 source lines, extracted with `sed -n '/^- \*\*Sources, in priority order:\*\*/,/^- \*\*Document sections/p' docs/DESIGN.md | sed -n 's/^  [0-9]\. //p'`, each present **and** in ascending line order (`grep -nF … | cut -d: -f1` is strictly increasing).
- **C4 path spelling** (per occurrence, not per line): `grep -oE '\$?\{?CLAUDE_PLUGIN_ROOT\}?/?' "$f" | grep -vxF '${CLAUDE_PLUGIN_ROOT}/'` prints nothing. Every `${CLAUDE_PLUGIN_ROOT}/templates/…` path exists in the repo. Paths under `scripts/detect-stack.sh` and `skills/stack-standards/` are checked against the Phase A/B contract names (they may not exist yet), and re-checked at the phase exit.
- **C5 British English** (body only): `sed '1,/^---$/d' "$f" | grep -nEi '\b(behavior|color|organiz|analyz|prioritiz|recogniz|summariz|initializ|favorite|center)'` prints nothing.
- **C6** `claude plugin validate .` exits 0, and its output has no line naming `agents/`.

**Commit:** `feat(agents): add standards-setter agent`

---

### D2 — `agents/senior-engineer.md`

**Frontmatter:**

```yaml
---
name: senior-engineer
description: Plans work packages from the brief, reviews the branch diff against the plan and standards, and triages QA failures to their root cause. Dispatched by the aew orchestrator only, with a mode of plan, review or triage; don't use it directly.
model: opus
effort: high
memory: project
skills:
  - aew:run-protocol
  - aew:stack-standards
  - superpowers:systematic-debugging
tools: Read, Grep, Glob, Write, Bash, mcp__plugin_context7_context7__*
---
```

No Edit in `tools`: memory adds it (F4), and the prompt confines it to the memory dir and the run dir (spec conflict 4).

**Body outline** (target 260–380 lines). Mode-specific material sits in `### Mode: plan`, `### Mode: review` and `### Mode: triage` subsections under Process, Outputs and Definition of done, so each mode reads top to bottom.

1. **`## Role`** (4–6 lines). You are aew's senior engineer. One of three jobs per dispatch, chosen by `mode`. Your bias is the simplest thing that satisfies the brief (DESIGN principle 2): challenge complexity, constraints and alternatives, reuse what exists, and trace every decision to an AC (principle 1). You never write production code; illustrative signatures only.

2. **`## Inputs`**.
   - Dispatch fields (A14), with PD-2 fallbacks: `run_dir`; `mode: plan | review | triage`; `n` (review: the `<n>` of `07-review-<n>.md`; triage: the `<n>` of `08-qa-report-<n>.md`, shared by `09-triage-<n>.md`); `base` (review only; the base branch).
   - A per-mode table of files. "Required" means missing → `blocked`.
     - **plan**: `02-brief.md` (required), `03-standards.md` (required) and the doc sections it lists, `spec-final.md` (context), `.aew/config.json` (`limits.max_parallel_developers`, `commands`), the codebase. Not `04-qa-test-plan.md` (it runs in parallel and must stay independent).
     - **review**: `02-brief.md`, `05-plan.md`, `03-standards.md` (required), `06-dev-report*.md`, `07-review-<n-1>.md` if any, the diff `git diff <base>...HEAD`.
     - **triage**: `08-qa-report-<n>.md` (required), `02-brief.md`, `spec-final.md`, `05-plan.md`, `06-dev-report*.md`, the diff, and the failing test files named in the report.
   - The path note and template paths: `plan.md`, `review.md`, `triage.md` under `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/`.

3. **`## Process`**. A shared step 0: resolve the fields; an unknown mode → `blocked`; read the required inputs.

   **`### Mode: plan`** (DESIGN §8.4), numbered:
   1. List every AC id in the brief verbatim (including `#12-AC-1` bulk ids). This list is the coverage target.
   2. Explore before designing: Glob/Grep for analogs, existing helpers, components and tests. Reuse first; a new file needs a reason.
   3. **Approach**: the simplest viable design, in a few sentences.
   4. **Alternatives**: at least one real alternative (not a straw man), each with why it was rejected.
   5. **Challenges**: question each constraint and any complexity the brief implies. Classify each against the Material list, which the prompt carries **verbatim** from DESIGN §8.1 (eight bullets, A16). A material challenge becomes a question with a recommended answer and alternatives in "Challenges to the spec", and `needs_input` (PD-6). Non-material ones are resolved in the plan and noted.
   6. **Work packages** `WP-n`: goal; ACs covered; files (create/modify), with no file in two WPs; `depends_on` (WP ids, acyclic); `parallelisable` per PD-7, stated as a rule in the prompt with a two-line example (a shared module WP that others depend on is `no` when it is alone at its level; two leaf WPs with disjoint files are `yes`). Size each WP for one Sonnet developer session; prefer fewer WPs; one WP is fine for a small brief. Never schedule more concurrent WPs than `limits.max_parallel_developers`.
   7. **Standards per WP**: rows `docs/standards/<profile>.md#<section>`, using only sections listed in `03-standards.md`.
   8. **Guardrails**: keep the template's three, and add brief-specific ones (for example "no client component for X", "keep the API contract in AC-2 unchanged").
   9. **Unit tests per WP**: behaviours under test, named and placed per the standards' testing conventions. Acceptance tests are QA's.
   10. **Risks**.
   11. **AC→WP matrix**: one row per AC from step 1. Self-check: the set of AC ids in the matrix equals the set from step 1, and every WP's "ACs covered" agrees with the matrix. Fix the plan until both hold.
   12. Use context7 (`resolve-library-id` → `query-docs`) only when a design choice depends on version-specific framework behaviour.

   **`### Mode: review`**:
   1. `git rev-parse --verify <base>`; failure → `blocked`. Then `git diff --stat <base>...HEAD`, `git diff <base>...HEAD`, `git log --oneline <base>..HEAD`. An empty diff → PD-8.
   2. Check, in this order:
      - **plan conformance**: every changed file is owned by a WP; each WP's files exist; guardrails held; no unplanned dependency or public API change;
      - **brief**: each AC visibly implemented;
      - **standards**: the sections in `03-standards.md`;
      - **tests**: the plan's unit tests exist and the dev report lists them run and passing;
      - **correctness**: edge cases, error handling, security, and accessibility for `[UI]`/`[A11Y]` ACs.
   3. Prior review: each finding of `07-review-<n-1>.md` is resolved, or re-raised at the same severity citing its old number.
   4. Severity definitions, in the prompt:
      - **blocker**: an AC broken or unimplemented, a security or data-loss defect, a build or test failure, or a guardrail breach (an unjustified dependency, a public API change, files outside the plan);
      - **major**: wrong behaviour in a case the brief covers, a missing planned unit test, missing error handling, an accessibility failure, a violation of a **[tool]** rule (the brief's DoD requires lint, format and typecheck to pass), or a **[convention]** violation whose concrete cost the finding names (a defect it invites, or a duplicate of an existing helper);
      - **minor**: any other **[convention]** deviation (naming, structure, readability);
      - **nit**: a preference, optional.
      - Don't inflate a severity to force a change, or deflate one to pass.
   5. Verdict rule, stated as an iff: `changes_required` if and only if there is at least one blocker or major; otherwise `approve`, even with minors and nits.
   6. Locations are `file:line` from the file at HEAD (read it with Read for line numbers), or `file` when the finding is a missing file. Every "Required fix" is a concrete instruction, never "consider".
   7. Never run tests, lint or builds, never check out, and never edit code (A17). That is the developer's and QA's job.

   **`### Mode: triage`** (DESIGN §8.4, §8.6):
   1. From `08-qa-report-<n>.md`, take the failures classed `plan_divergence` or `test_bug`, plus any `impl_bug` the orchestrator escalated (the developer didn't fix it in one cycle). `spec_ambiguity` is not yours: it goes to James through the orchestrator. List the TC ids in the header line.
   2. Apply the preloaded systematic-debugging method: root cause before any fix, evidence from the QA output excerpts, the failing test, the code under test, the AC text and the plan. No guessing.
   3. Trace each failure back through spec → brief → plan → implementation, and name the **first** point where it diverged. Definitions in the prompt:
      - **spec**: `spec-final.md` is itself ambiguous or wrong (PD-9);
      - **brief**: the brief misstates the spec;
      - **plan**: a WP misreads the brief;
      - **implementation**: the code departs from a correct plan.
   4. Group failures by root cause; every triaged TC is accounted for in exactly one group.
   5. **Fix instructions** for a Sonnet developer, as numbered steps. Each step names the file (and function or line), states the change in behavioural terms (an illustrative signature at most), names the test to add or update, and gives the exact command to re-run (from `.aew/config.json` `commands`, narrowed to the test file where the framework allows). No "investigate", no "consider", no options.
   6. **Test ruling**: when a test is wrong, name the TC and test file, quote the AC that shows why, and say what QA should assert instead. Otherwise "None.". Both sections may be filled when the failures differ.

4. **`## Outputs`**: plan → `<run_dir>/05-plan.md` (overwrites any earlier one); review → `<run_dir>/07-review-<n>.md`; triage → `<run_dir>/09-triage-<n>.md`; each from its template, with all headings kept. Review: the Verdict section holds exactly `approve` or `changes_required`; Findings holds "None." or the numbered table. Triage: the "Where the divergence started" section holds exactly one of `spec / brief / plan / implementation`.

5. **`## Return contract`**: the block, plus per-mode meanings:
   - plan: `ok`, or `needs_input` for a material challenge (questions in the artefact);
   - review: `ok` for both verdicts, with SUMMARY **starting with** the verdict word and severity counts; NEXT "qa" or "developer: fix findings 1, 3";
   - triage: `ok` or `needs_input` (PD-9); NEXT "developer (fix mode)" and/or "qa-engineer", per the template.
   - `blocked`: a required input is missing, `base` is unresolvable, or the mode is unknown. `failed`: the artefact couldn't be written.

6. **`## Guardrails`**:
   - Write and Edit only `<run_dir>/` (this mode's one artefact) and `.claude/agent-memory/senior-engineer/` (see `## Memory`). Never source, tests, configs, `docs/`, `CLAUDE.md`, `state.json` or `log.md`.
   - Bash read-only, exactly: `git diff`, `git log`, `git show`, `git status`, `git rev-parse --verify`, `ls`. Nothing else (no tests, builds, installs, checkouts or network).
   - The no-GitHub wording.
   - No code beyond short illustrative signatures. Don't widen scope beyond the brief; propose it as a challenge instead.

7. **`## Autonomy`**: decide alone; `needs_input` only for a material spec change (the eight-bullet list), never for engineering choices. When unsure between two designs, pick the simpler and record the other as an alternative.

7a. **`## Memory`** (PD-1 slot): record recurring review findings (pattern plus how to spot it) and architecture decisions with their reasons; don't record secrets, run detail, or anything already in `docs/standards/`.

8. **`## Definition of done`**, a checklist per mode (`### Mode: plan`, `### Mode: review`, `### Mode: triage`):
   - **plan**: ≥1 alternative; every WP has all five fields; no file owned twice; `depends_on` acyclic; `parallelisable` consistent with PD-7; the matrix covers every brief AC.
   - **review**: every finding has #, severity, location and fix; the verdict follows the iff rule; prior findings are addressed.
   - **triage**: one divergence origin; every TC accounted for; each fix step has file, change, test and command.
   - **all**: template headings in order, and the return block last in both the artefact and the final message.

**Checks (D2).** The same RED → GREEN procedure with `check-agent.sh`:

- **C1**: `agents/senior-engineer.md senior-engineer opus high aew:run-protocol,aew:stack-standards,superpowers:systematic-debugging 'Read,Grep,Glob,Write,Bash,mcp__plugin_context7_context7__*'`.
- **C2**: same headings; plus `grep -c '^### Mode: plan$'`, `…review$` and `…triage$` are each ≥ 2 (Process and Definition of done).
- **C3** strings: `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/plan.md`, `…/review.md`, `…/triage.md`, `05-plan.md`, `07-review-<n>.md`, `09-triage-<n>.md`, `08-qa-report-<n>.md`, `git diff <base>...HEAD`, `mode: plan | review | triage`, `base branch`, `parallelisable`, `depends_on`, `AC→WP`, `blocker`, `major`, `minor`, `nit`, `changes_required`, `if and only if`, `approve`, `plan_divergence`, `test_bug`, `impl_bug`, `spec_ambiguity`, `where the divergence started` (case-insensitive), `implementation`, `Sonnet developer`, `systematic-debugging`, `never run \`gh\``, `.claude/agent-memory/senior-engineer/`, `STATUS: ok | needs_input | blocked | failed`.
- **C4–C6**: as for D1.
- **C7 material list verbatim**: every line from the DESIGN §8.1 extraction (see "Facts") is present via `grep -qF`, and there are exactly 8.

**Commit:** `feat(agents): add senior-engineer agent with plan, review and triage modes`

---

### D3 — `tests/fixtures/briefs/newsletter-signup.md`

A finished `02-brief.md`, as brief-compiler would write it in pipeline mode: every template heading kept in order, instruction comments removed, placeholders filled, ending with a real return block. It creates `tests/fixtures/briefs/` (the directory gets this file only).

**Content outline:**

- `# Brief: #101 Newsletter sign-up in the site footer`, then `Source: spec-final.md (v1)`.
- **Goal**: visitors can subscribe to the newsletter from the footer of every page.
- **Context**: a Next.js App Router site with Tailwind (`nextjs-tailwind` fixture). The footer lives in `app/layout.tsx` (write "the footer element", never an angle-bracket tag, so F5 holds). There is no email provider yet; this issue stops at a validated subscribe endpoint that a later issue wires to a provider.
- **Acceptance criteria** (seven, `- **AC-n** [TAGS] Given/When/Then`; they map one to one onto #101's behaviour and accessibility points):
  1. **AC-1** [UI] Every page's footer shows a form with a visible label "Email address", an email input (`type="email"`, `autocomplete="email"`) and a "Subscribe" button.
  2. **AC-2** [API] `POST /api/newsletter` with JSON `{ "email": "ada@example.com" }` (any valid address, trimmed, including one already submitted) returns 201 and `{ "status": "subscribed" }`. Valid means, after trimming leading and trailing whitespace, one `@`, a non-empty local part, a dot in the domain part, and 254 characters or fewer.
  3. **AC-3** [API] [SEC] A missing or invalid `email` returns 400 `{ "error": "invalid_email" }`; a body over 1 KB returns 413; any method other than POST returns 405; nothing is stored in any case.
  4. **AC-4** [UI] [A11Y] While the request is pending, the button is disabled and reads "Subscribing…"; after a 201, the form is replaced by "Thanks, you're subscribed." in a polite live region.
  5. **AC-5** [UI] [A11Y] Invalid input, whether caught in the browser (and then not submitted) or returned as a 400, shows the inline error "Enter a valid email address" below the input, linked with `aria-describedby`; the input gets `aria-invalid="true"` and keeps focus.
  6. **AC-6** [UI] On a network error or a 5xx response, the message "Something went wrong. Please try again." appears in the polite live region and the input keeps its value.
  7. **AC-7** [A11Y] The form is keyboard-operable with a visible focus indicator, its text meets 4.5:1 contrast, and an axe scan shows no serious or critical violations at the 390×844 and 1440×900 viewports.
- **Non-goals**: storing or forwarding addresses (the route validates and responds only, and logs nothing); any mailing provider; double opt-in; rate limiting; analytics; translations (English copy only).
- **Constraints**: the client and the server validate with **the same** rule from one shared module (one source of truth); the API contract in AC-2 and AC-3 is fixed; no new runtime dependency; Tailwind utilities only, no new CSS file.
- **Affected surfaces**: `app/layout.tsx` (footer); new `app/api/newsletter/route.ts`; new shared `lib/newsletter.ts` (validation); new `components/newsletter-form.tsx` (client component).
- **Test data and accounts needed**: none (anonymous visitor). Sample valid and invalid addresses are listed.
- **UI changes: yes**. The heading is literally `## UI changes: yes`.
- **Definition of Done**: the template's five items, unchanged.
- **Open risks**: no provider yet, so "subscribed" is not persisted (accepted for this issue).
- Return block: `STATUS: ok`, `ARTEFACTS: .aew/runs/101/02-brief.md`, a one-line SUMMARY, `NEXT: standards`.

**Built-in WP opportunities** (why the fixture is shaped this way; not written into the file): the shared-validation constraint yields a foundation WP (`lib/newsletter.ts`) that the others depend on, so it is not parallelisable. The fixed API contract and the disjoint files let the route WP (`app/api/newsletter/route.ts`) and the form WP (`components/newsletter-form.tsx`, `app/layout.tsx`) run in parallel once it lands. A senior who folds validation into the route WP still gets a correctly marked `no` (the form then depends on the route). Either way AC-16's "correctly marked" check is decidable.

**Checks (D3)** in `tests/tmp/phase-d/check-brief.sh`. RED against the missing file first, then GREEN:

- **F1 headings**: `diff <(grep -E '^## ' templates/artefacts/brief.md) <(grep -E '^## ' "$f")` is empty, except that the template's `## UI changes: yes/no` is matched by `## UI changes: yes` (normalise with `sed 's/^## UI changes: .*/## UI changes/'` on both sides). Line 1 matches `^# Brief: #101 `.
- **F2 ACs**: `grep -oE '^- \*\*AC-[0-9]+\*\*' "$f"` yields `AC-1`…`AC-7`, consecutive from 1 (≥ 4 required by AC-15). Each AC line has ≥ 1 tag from `[UI] [API] [DATA] [A11Y] [PERF] [SEC]`, and the vague words `fast|nice|intuitive|user-friendly|secure` don't appear in the AC lines.
- **F3**: exactly one `^## UI changes: yes$`.
- **F4 return block**: `eval "$(sed -n '/^valid_return_block() {/,/^}/p' scripts/hooks/gate-subagent.sh)"; valid_return_block "$f"` prints `ok`.
- **F5**: no template placeholder or comment survives: `grep -nE '<[a-z!/]' "$f"` prints nothing (the fixture contains no HTML, so any `<word` or `<!--` is a leftover).
- **F6 #101 alignment**: the fixture contains `Thanks, you're subscribed.`, `Subscribing…`, `Something went wrong. Please try again.`, `405`, `rate limiting` and `translations`, and does not contain `Check your inbox`.

**Commit:** `test(fixtures): add senior-engineer fixture brief`

---

## Phase exit (after D1–D3 merge)

Run once on the integration branch:

1. `tests/tmp/phase-d/check-agent.sh` for both agents, `check-brief.sh` for the fixture: all pass.
2. C4's deferred paths: `scripts/detect-stack.sh`, `skills/stack-standards/references/document-structure.md` and `skills/stack-standards/references/seeds/` exist **if** Phases A and B have merged. If they haven't, list the paths still pending in the phase report; Phase E's smoke runs re-check them.
3. `claude plugin validate .` exits 0 with no `agents/` finding.
4. `tests/run-script-tests.sh` still passes (D adds no script, so this is a regression guard only).

## Hand-off to Phase E

- The Bash allowlists above are the exact `--allowedTools` entries for the standards-setter and senior-engineer smoke runs. Phase E's invocation must therefore add `"Bash(date *)"` (standards-setter's `generated=` date) and `"Bash(git rev-parse *)"` (senior review; harmless for plan) to its current list. E also confirms that a `Bash(<abs>/scripts/detect-stack.sh *)` rule matches the prompt's quoted `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" …` form; if it doesn't, both are micro-revised to agree.
- E verifies that `mcp__plugin_context7_context7__*` resolves (A13/F12) and that the three qualified `skills:` names preload (A12/AC-18). If either is wrong, both prompts' frontmatter is micro-revised (one line each) and the C1 expected values follow.
- E seeds `tests/fixtures/briefs/newsletter-signup.md` as `02-brief.md` in the standards-setter runs and the senior-engineer plan run (the same temp project). **Run ids belong to Phase E** (921, 922, 931). The fixture's `#101` is the issue it describes (Phase C's `clean-ui.md`), and its ARTEFACTS line `.aew/runs/101/02-brief.md` records the fixture's own provenance; no check compares either with the smoke run id, and agents take `#<issue> <title>` from the brief's H1 and their own paths from `run_dir`.
- E5's "correctly marked" rule should adopt PD-7: a WP with an empty `depends_on` that nothing can run alongside (the shared-validation foundation WP) is correctly `no`, even with no file overlap.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T14:05:06Z (plan-review, full depth)
- Plan format: FULL (phase D of EPIC)
- Plan dependency graph: valid. Wave count: 1. Max wave width: 3 tasks parallel (D1, D2, D3; disjoint files).
- Plan content hash before this trailer (SHA-256): a7fe7d9bca0293bdd9aeb4fa2b63e86a7608030aa62617fb17ce93b81a1cc1f0
- Diff-reviewed 2026-10-24T14:23:04Z (plan-diff-review, APPROVED): fingerprint call is `fingerprint <profile> .` from the project root, one per profile; D3 brief aligned with Phase C C3 #101 (7 ACs, "Thanks, you're subscribed.", type/autocomplete, 390×844/1440×900 axe bar, F6 check all match #101); fence-skipping C2; "base branch" C3 string; WP split unchanged (shared validation `no`, route/form `yes`). Hash re-recorded above; previous 11653d08911e71826e1aa7fe75e53ed4033c679030b1faf5b3e6164b2671acce.
