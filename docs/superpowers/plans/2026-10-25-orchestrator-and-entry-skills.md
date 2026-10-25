# Plan: orchestrator and entry skills — init, ship, resume, status, prompt (build prompt 05)  (EPIC · 6 phases)

- Spec: `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `46335838…6ff6090`)
- Issue: no issue (build prompt `docs/build-prompts/05-orchestrator.md`; DESIGN.md wins on conflict)
- Phase plans below are copied verbatim from `docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-{A..F}.md`, each with its own senior approval trailer; this file is the authoritative copy. Precedence where texts disagree: **CTO conditions > Orchestrator reconciliations > Simplicity-challenge cuts > phase plan > spec.**
- Execution mode is fixed: subagent-driven only. Proceed to dw-human-review.

## Context manifest

**Reference files** (downstream agents read these first; full list and notes in the spec's §Context manifest):

- `docs/build-prompts/05-orchestrator.md`: deliverables and [P] ACs.
- `docs/DESIGN.md`: §3 platform facts, §4 dependencies and the superpowers pin (built against 7.x), §5.1 skill table, §6.1 config, §7 run dir / state / stages / labels / return contract, §8 agent inputs and outputs, §9 orchestrator, §11 hooks.
- `docs/superpowers/project-map.md`: dispatch-field contracts per agent, CTO-3a/3b open items, bash 3.2 / zsh / jq gotchas.
- `skills/run-protocol/SKILL.md`, `references/state-machine.md`, `references/artefacts.md`: stage/label mapping, gates, failure paths, `qa_failures_complete`, counters, artefact names.
- `skills/github-ops/SKILL.md` and `scripts/{state,gh-issue,gh-labels,git-branch,gh-pr,gh-retro,detect-stack}.sh --help`: the script contracts.
- `scripts/hooks/gate-subagent.sh` (`valid_return_block`, gate freshness), `scripts/hooks/guard-bash.sh` (`guard_gh` denies `gh` to `aew:*` agents).
- `agents/*.md`: Inputs and Return contract sections.
- `templates/config.schema.json`, `templates/state.schema.json`, `templates/artefacts/*`.
- `tests/agent-smoke/README.md` (harness, `smoke_dispatch`, `smoke_shop`, ledger), `tests/scripts/helpers/bin/gh` (stateful mock), fixtures `tests/fixtures/apps/static-shop/` (#201), `tests/fixtures/issues/material-guest-access.md` (#103), `tests/fixtures/stacks/nextjs-tailwind/`.

**Key facts (verified 2026-10-25 against code.claude.com/docs; detail and URLs in the spec's facts table and Phase F task F7):**

- `disable-model-invocation: true` still allows `/aew:<skill>` (also in `-p`) but blocks the Skill tool, so `resume` and `prompt` **Read** `${CLAUDE_PLUGIN_ROOT}/skills/ship/…` and never invoke ship.
- `${CLAUDE_PLUGIN_ROOT}`, `$ARGUMENTS`, `$N`/`$ARGUMENTS[N]` are substituted only in the loaded `SKILL.md` body, never in files read with Read; the Bash tool does not get `CLAUDE_PLUGIN_ROOT`. No `` !`cmd` `` and no `$<digit>` in any entry `SKILL.md`.
- AskUserQuestion is main-thread only; per-call limits undocumented; `--permission-prompts none` removes it, so headless gates stay pending and ship stops.
- `-p` defaults to Manual permission mode since v2.1.302: simulations pass `--permission-mode acceptEdits --permission-prompts none` plus an explicit allowlist; never `bypassPermissions`.
- Permission rules (V-7, /en/permissions): deny → ask → allow; `git -C`/`git -c` forms are not normalised; deny rules are not a security boundary. init's proposal uses anchored per-subcommand rules only.
- Plugin agents are `aew:<agent>`; one-message parallel dispatch is evidenced (run 961), not documented — S1 records it.
- superpowers version from `claude plugin list --json` may be semver or a 12-character SHA.

## Assumptions the human should read first

The spec's "flag if wrong" defaults with the widest consequences, as amended by the cuts and reconciliations (full list: spec §Assumptions 1–28).

- **A1. Procedures, not scripts.** ship, resume and prompt are Markdown procedures the main thread follows; no argument-parsing or return-checking script (bad-argument messages are proven statically by `skills.bats`).
- **A5. Unanswered gates.** A ship gate with no answer (headless, refused, empty) stays pending (`state.sh status awaiting_*` with a `gate:<id>` note) and ship stops; `/aew:resume` re-asks it. init with no answer takes safe defaults: recommended config, no installs, no settings file written.
- **A6/A7. Simulations.** Real headless sessions on static-shop #201 (clean), nextjs-tailwind #103 (material) and nextjs-tailwind (init); only `gh` (the mock) and `origin` (a local bare repo) are fake. Caps total $56 under a hard $60 stop; expected spend ~$25–30.
- **A9. One direct `gh` call.** `gh auth status` in ship and init preflight (read-only, the simulation canary) is the only `gh` call outside the plugin scripts — a recorded deviation.
- **Cut 7 (replaces A10).** Preflight fetches and *checks* the default branch; behind or diverged → stop with a `git pull` hint. It never fast-forwards and writes nothing.
- **A13. `--from <stage>`** restarts an existing run (`state.sh current set` + `state.sh stage <stage> --note "--from"`), keeps counters, redoes nothing earlier.
- **A16/PD-3. Developer `blocked`** in full mode re-plans once (the senior engineer gets the reason as `notes`); a second `blocked`, or one in fix mode, takes the blocked path.
- **Cut 8 (replaces A19).** On a plan `needs_input`, the material gate runs, spec-analyser finalises, the revision is recorded, and the run re-runs from `brief`.
- **PD-2. Agent memory.** Agents write `.claude/agent-memory/aew-*/` (`memory: project`, meant to be committed). ship commits it once per run after the docs commit; restarts treat memory-only changes as clean; init commits standards-setter memory and discards a memory-only change on a re-run so the second run changes nothing.
- **A23/A26. init defaults.** `retro.repo` defaults to the plugin's own repo; the permission proposal (anchored rules, exact script paths, no wildcard on `diff`/`log`/`show`/`format-patch`, exact `fetch`) is shown and asked, and never written headless.
- **A27. init's PR** goes through the new `gh-pr.sh open` (idempotent: reuses an open PR), called whenever `chore/aew-init` is ahead of the default branch.

## Phase graph

- Phase A (depth: lean · risk: none): senior-engineer `notes`, standards-setter `mode: init`, `gh-pr.sh open` + bats. depends_on: []
- Phase B (depth: full · risk: none): `skills/ship/SKILL.md` + six references. depends_on: []
- Phase C (depth: lean · risk: none): `resume`, `status`, `prompt`. depends_on: [B] at task level (C2 has none)
- Phase D (depth: full · risk: permissions proposal, D5 RISKY): `skills/init/SKILL.md`. depends_on: [A] at task level (D6 needs A2, A3)
- Phase E (depth: lean · risk: none): E1 `tests/scripts/skills.bats` (gates F), E2 README `## Commands` + Mermaid diagram (parallel with F). depends_on: [B8, C1–C3, D6]
- Phase F (depth: full · risk: real-GitHub safety and spend of paid headless runs): harness, P0/P1, S1, G2, F1+R2, I1/I2/G1, DESIGN and closing docs. depends_on: [E1]

**Task-level waves** (paid runs never exceed two concurrent sessions; every `tests/agent-smoke/README.md` edit is serialised inside phase F):

1. A1 ∥ A2 ∥ A3 ∥ B1 ∥ C2 ∥ D1
2. B2 ∥ B3 ∥ B4 ∥ B5 ∥ B6 ∥ B7 ∥ D2
3. B8 ∥ C1 ∥ C3 ∥ D3
4. D4
5. D5
6. D6
7. E1 ∥ E2 ∥ F7
8. F1 (harness, free)
9. F2 (P0 safety probe + P1; any failure stops every paid run)
10. F4 (G2) ∥ F6 (I1, I2, G1)
11. F3 (S1) ∥ F5 (run F1 + R2)
12. F8 (results roll-up and closing docs)

Tasks: A 3 · B 8 · C 3 · D 6 · E 2 · F 8 = 30.

## Simplicity-challenge

The CTO returned SIMPLER-PATH; all 11 cuts were adopted (no independent deliverables merged). Kept after challenge: senior-engineer `notes`, standards-setter `mode: init`, `gh-pr.sh open`, `skills.bats`, and every real-GitHub safety rail.

1. R1 (resume re-asking the plan gate) dropped from the simulations; `skills.bats` checks resume names the re-ask. AC-42 = G2 only.
2. R2 stops at `review`, not `done` (S1 already proves develop → PR → `done`).
3. At most one paid bad-argument probe; the messages are proven statically.
4. Order I1 → I2 → G1; G1 runs on init's output after `main` is fast-forwarded to `chore/aew-init` on the bare origin (no hand-seeded config).
5. Budget ~$55 within the $60 stop.
6. init's permission proposal uses anchored rules only; no deny rules and no separate V-7 task (V-7 verified during planning).
7. Preflight checks the default branch, doesn't fast-forward.
8. One rule for plan `needs_input` (re-run from `brief`).
9. No deletion of an empty `chore/aew-init` branch.
10. DESIGN records facts, conflicts and deviations and *points at* ship's references for preflight order and the reads table.
11. The README task does not gate phase F.

## Orchestrator reconciliations across phases (binding)

- **R-1 Prompt-run detection.** Phase B I-11 owns one combined check, used verbatim in ship's `gates.md` and in Phase C's resume, status and prompt: `jq -r 'if ([.history[] | select(.note == "prompt")] | length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json`. Phase C's PC-1 jq is replaced by this command; nothing tests the marker on its own. The marker is written with `state.sh stage spec_analysis --note "prompt"` between ship Step 3.2 and 3.3 (before the fetch).
- **R-2 `notes`.** ship sends senior-engineer `notes` as a single line (multiple notes joined by ` / `) and as the last dispatch field — a compatible subset of Phase A C-1.
- **R-3 Clean tree.** Preflight Check 2 uses `git status --porcelain --untracked-files=all` in both forms; it agrees with `git-branch.sh create`'s `--untracked-files=normal` (same dirty set).
- **R-4 status listing (C2).** Use `(.title // "-")` in the listing jq, and report a jq parse error as a corrupt `state.json` (naming it), not "No aew runs".
- **R-5 prompt stop (C3/C1).** prompt's `## Stopping` gives PC-6's hint (remove `.aew/runs/<n>`, run `/aew:prompt` again) when `issue.json` is missing.
- **R-6 Flat scratch files.** init's `init-*` files and ship's `blocked-<id>.md` live flat under the gitignored `.aew/runs/`; `status` lists only directories matching `^([1-9][0-9]*|m-[1-9][0-9]*)$`.
- **R-7 DESIGN ownership.** All DESIGN.md edits are in F7 only. F7/F8 also record: the PC-3 deviation (a prompt-mode `blocked` posts no comment and sets no label), PC-1's marker (as a pointer), PC-5 (resume continues `single` runs only until prompt 06), PD-3's fix-mode exception in `state-machine.md` failure paths, the §7.1 line on flat scratch files, and the `git-branch.sh` help wording fix (no "base branch is updated by preflight").
- **R-8 Blocked comment (Phase B `## Blocked path` steps 1–3, I-8 "Blocked comment" line and its allowlist-matching note).** ship writes the report comment with the **Write tool** to `.aew/runs/blocked-<id>.md`, then runs `gh-issue.sh comment <n> .aew/runs/blocked-<id>.md`. No `mktemp`, no heredoc, no removal (replaces spec Assumption 20). F1 fails before any paid run if `grep -rl mktemp skills/ship` finds anything.
- **R-9 Simulation `gh` host.** The launcher also sets `GH_HOST=aew-smoke.invalid` so a real `gh` reached by any path cannot authenticate against github.com (Phase F rail 3).

## CTO conditions (risk-gate, APPROVED WITH CONDITIONS, 2026-10-25): binding on the named tasks

- **CTO-1 (D5).** `commands.seed` gets no allow rule; list it under "not pre-approved" with the reason "may reset data". Update the "Rules from config" bullet and the D5 commit body. (The fixture has no seed command, so D5's portable and local rule counts are unchanged.)
- **CTO-2 (F1 launcher, F2 P0a).** The session environment also sets `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=` (empty value resets the helper list), `GIT_TERMINAL_PROMPT=0`, `GIT_SSH_COMMAND=false`, and unsets `SSH_AUTH_SOCK`. F1 free check in the same environment: `printf 'protocol=https\nhost=github.com\n\n' | git credential fill > /dev/null 2>&1` must exit non-zero (output discarded, never printed), and the I-9 dry-run push to the bare origin must still succeed. P0a step 4 also prints `GIT_CONFIG_COUNT GIT_TERMINAL_PROMPT GIT_SSH_COMMAND`; check 3 expects `1`, `0`, `false`.
- **CTO-3 (F1 `smoke_ship_allow` item 5 and the launcher).** Add `Edit(/$REPO/**)` in the absolute `//…` form (checked against /en/permissions in F1) to `--disallowedTools`. The launcher hashes `$(git -C "$REPO" rev-parse --git-common-dir)/config` and that directory's `hooks/` before and after each session; a mismatch exits 4 and counts as a P0 failure.
- **CTO-4 (F1 launcher; every paid run).** Post-session audit of every Bash `tool_use` in `stream.jsonl` on any thread for `github\.com`, `--hostname`, `GH_HOST=`, `GH_TOKEN`, `GITHUB_TOKEN`, `GH_CONFIG_DIR=`, `security `, `credential`, `remote (add|set-url)`, the real `gh` path F1 recorded, and any `claude ` command other than exactly `claude plugin list --json`. A hit writes `$O/audit.txt`, prints `AUDIT HIT`, exits 4 and is a P0 failure (paid runs stop until classified). A genuine false positive is recorded in §9.9 and allowed by its exact string, never by loosening the pattern.
- **CTO-5 (F1 launcher).** The spent read and the reservation write sit inside a `mkdir "$L/.lock"` spin lock, released straight after the reservation and before `claude` starts. F1 also checks the docs on whether `--max-budget-usd` counts subagent spend and records it in §9.2.

**CTO notes (non-binding; folded in as written):** F8 records for prompt 07 that concurrent runs on different branches will conflict in agent-memory `MEMORY.md` at merge. F7 notes that newer `gh` may exit non-zero from `gh auth status` when any configured host is unhealthy, so preflight quotes gh's own output when it stops. I-8's stale `mktemp` line is overridden by R-8 and must not reach `dispatch.md` or any allowlist. init's §10 text must not suggest `git switch *` / `git branch *` block `-f`/`-D`, nor claim anything about redirection matching. F's kill step also stops a surviving QA app server on port 4173 (`lsof -ti tcp:4173 -sTCP:LISTEN`, then `kill <pid>`) before the next attempt.

**Decided by James at plan review:** plugin-script rules go in gitignored `.claude/settings.local.json`; portable rules in `.claude/settings.json`.

## Commit model

Each task gets its own conventional commit on the feature branch (`feature/orchestrator-and-entry-skills`), and the planning docs (spec, phase plans, this plan, project-map update) go in one commit at the start of implementation. The build prompt asks for "a conventional commit"; as in prompts 02–04, squash to one conventional commit when the PR is merged if a single commit is wanted.

---

# Phase A plan — Component additions the skills need

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583883f5…6090`)
- **Binding overrides:** the CTO simplicity-challenge (SIMPLER-PATH, all 11 cuts adopted). For this phase: AC-34 and AC-36 are kept as written; AC-35 is minimal (skip `03-standards.md` and "Sections that apply", nothing else); `gh-pr.sh open` bats coverage is create, reuse and invalid input only; the three changes stay three parallel tasks. Cut 8 removes the "declining the change → re-plan with `notes`" branch of AC-14, so `notes` has two sources only (plan gate request-changes, AC-9; developer `blocked`, AC-12).
- **Phase:** A of the EPIC. `depends_on: []`. Phase B (ship) consumes contracts C-1 and C-3's absence of a `create` change; Phase D (init) consumes C-2 and C-3; Phase E's `skills.bats` may grep C-1/C-2 wording; Phase F records the DESIGN §8.3/§8.4 text (see C-4).
- **Depth:** lean
- **ACs covered:** AC-34, AC-35 (agent side; the "DESIGN §8.3 records it" clause is Phase F's, per cut 10 and AC-47), AC-36
- **Risk:** none. No risk line is crossed: no auth, payments, schema, dependency or GitHub-write change beyond a new wrapper subcommand that only the orchestrator and init call.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" means the spec's assumption n. Task ids `A1`–`A3` are unrelated to those numbers.

> **For agentic workers:** implement task by task, TDD. Every task records RED before the change and GREEN after. A1 and A2 are prompt edits, so their RED is a grep that fails before the change. A3's RED is the new bats tests failing against the current `gh-pr.sh` (`unknown subcommand: open`).

**Goal:** give the orchestrator and init the three small hooks they need: a way to feed gate feedback into a senior-engineer re-plan, a run-less standards pass for init, and a run-less, idempotent PR opener.

**Architecture:** two agent-prompt edits (`agents/senior-engineer.md`, `agents/standards-setter.md`) that add an optional dispatch field and an optional mode, each defaulting to today's behaviour; one new subcommand in `scripts/gh-pr.sh` that mirrors `cmd_create` (validation before any `gh` call, number parsed from gh's URL) plus an open-PR lookup; three new tests in the existing `tests/scripts/gh-pr.bats`; `skills/github-ops/SKILL.md` rows. No new files.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `agents/senior-engineer.md` (Inputs → Dispatch fields, Files per mode, Process → Mode: plan, Outputs, Definition of done → Mode: plan) | A1 edits these sections |
| `templates/artefacts/plan.md` (`## Approach` at line 8) | Where A1's "how each note was addressed" goes; template unchanged |
| `agents/standards-setter.md` (frontmatter description, Inputs, Process steps 1, 2, 8, Outputs, Return contract) | A2 edits these sections |
| `scripts/gh-pr.sh` (`cmd_create`, `need_file`, the Usage header, the dispatch `case`) | A3's pattern and edit target |
| `tests/scripts/gh-pr.bats` (`setup`, "create prints the PR number…", "create refusals make no gh call") | A3's test pattern; new tests go in this file |
| `tests/scripts/helpers/bin/gh`, `tests/scripts/helpers/common.bash` (`gh_mock_respond`, `assert_gh_called`, `refute_gh_called`, `gh_call_count`, `gh_captured_file`) | The mock routes `pr-list` and `pr-create`: without a canned response `pr list` succeeds with empty stdout (no open PR) |
| `scripts/git-branch.sh` line 78 | `git check-ref-format --branch` is the existing branch-name check to reuse; it works outside a repo too (checked) |
| `skills/github-ops/SKILL.md` (script table, "Other calls", Operational rules, Conventions/Exceptions, Stdout contract) | A3's documentation rows |
| `scripts/hooks/gate-subagent.sh` `valid_return_block` | ARTEFACTS must be non-empty, hence `ARTEFACTS: none` in C-2 |

## Interface contract (Phases B, D, E and F rely on this)

### C-1. senior-engineer plan mode: `notes` (A1, AC-34)

- **Field:** `notes`, optional, plan mode only (ignored in review and triage). Dispatch line form `notes: <text>`. It is the **last** field of the dispatch prompt and its value runs to the end of the prompt, so it may span several lines; every other field stays a single `key: value` line before it.
- **Sources (Phase B):** James's change requests from the plan gate "request changes" option (AC-9), verbatim; or the developer's `blocked` reason (AC-12), as `developer blocked: <SUMMARY text>` plus the dev report path. Phase B's `dispatch.md` row for senior-engineer plan lists `run_dir`, `mode: plan`, and `notes` (optional, last).
- **Behaviour with `notes`:** the agent also reads the existing `<run_dir>/05-plan.md` (the plan being revised; not required — absent means plan from scratch and still address the notes), then overwrites `05-plan.md` as today. `## Approach` ends with a `Revision notes:` list, one bullet per note: the note (quoted or paraphrased in one line) → what changed in the plan, or why it was not adopted. A note that can only be met by a material spec change (the step 5 list) becomes a question in `## Challenges to the spec` and the return is `needs_input`, exactly as step 5 already works.
- **Return:** unchanged (`ok` / `needs_input` / `blocked` / `failed`; ARTEFACTS `<run_dir>/05-plan.md`). No new required files; without `notes` behaviour is byte-for-byte today's.
- **Not changed:** QA phase A is not re-run by the agent (that is Phase B's routing); `04-qa-test-plan.md` stays unread in plan mode.

### C-2. standards-setter `mode: init` (A2, AC-35)

- **Field:** `mode`, optional: `pipeline` (default, today's behaviour, requires `run_dir`) or `init`. An unknown mode is `STATUS: blocked`.
- **Dispatch (Phase D):** exactly `mode: init`. No `run_dir`; the agent does not read `.aew/runs/current` and does not need a run to exist. Working directory is the project root.
- **Behaviour in `init`:** skip step 1 (no brief) and step 8 (no `03-standards.md`, so no "Sections that apply"). Steps 2–7 run unchanged: detect, fingerprint, reuse/update/generate each `docs/standards/<profile>.md`, write or refresh `docs/standards/README.md` under step 7's rule (nothing under `docs/standards/` changes when every fingerprint matched). Memory update (step 9) still applies, so `.claude/agent-memory/aew-standards-setter/` may change. `.aew/config.json` is read if present (cross-check only), as today.
- **Empty detection in `init`:** write nothing, return `ok`, SUMMARY "No stack detected by detect-stack.sh.", `ARTEFACTS: none`.
- **Return:** the four-line block goes **only in the final message** (there is no artefact). `ARTEFACTS`: `docs/standards/README.md` (when it exists), then every profile doc, reused ones included; or `none`. `SUMMARY`: `<profile>: reused|generated|updated` per profile, as today. `NEXT`: "init can stage docs/standards/" or the blocking reason. `blocked` in init mode only for a missing `detect-stack.sh` or an unknown mode; `failed` as today.
- **What changed on disk:** the agent does not list changed files separately. Phase D finds them with `git status --porcelain -- docs/standards/ .claude/agent-memory/aew-standards-setter/`.

### C-3. `scripts/gh-pr.sh open` (A3, AC-36)

```
gh-pr.sh open <branch> <title> <body-file> [--base <branch>]
```

- **Purpose:** run-less PRs (init). Reads no run state and no config. The caller pushes the branch first (`git-branch.sh push`).
- **Validation, all before any `gh` call, each exit 1 with an `error:` line on stderr and empty stdout:** wrong argument count or an unexpected extra argument; unknown option; `--base` without a value; `<branch>` or `--base` value not a valid branch name (`git check-ref-format --branch`); empty `<title>` or a title containing a newline; `<body-file>` missing or empty (`need_file`).
- **Calls, in order:**
  1. `gh pr list --head <branch> --state open --json number --jq '.[0].number // empty'`.
  2. Only if step 1 printed nothing: `gh pr create --head <branch> [--base <base>] --title <title> --body-file <body-file>`. Without `--base`, no `--base` is passed and gh uses the repository's default branch; **Phase D passes `--base <config default_branch>` explicitly.**
- **Body:** passed verbatim (no `Closes #n` normalisation; there is no run issue). The body file is never modified.
- **Stdout:** exactly one line, the PR number — the existing open PR's number (reuse; no create call) or the new PR's number parsed from gh's `/pull/<n>` URL (create).
- **Exit codes:** 0 success (reuse or create); 1 invalid input, a `gh` failure (gh's message passes through on stderr, stdout empty), a lookup result that is not a positive integer, or create output without a `/pull/<n>` URL.
- **Unchanged:** `create`, `update`, `ready`, `comment` keep their signatures and behaviour; `create` still has no lookup (ship keeps checking `state.pr`, Phase B).

### C-4. DESIGN sections

Not touched in this phase. Phase F writes DESIGN §8.3 (`mode: init`, Conflict C3) and §8.4 (`notes`) from C-1 and C-2 (cut 10, AC-47). The project-map dispatch-field line ("standards-setter takes `run_dir` only") is also Phase F's to refresh.

## Tasks

Waves: **1** = A1 ∥ A2 ∥ A3. The three tasks share no file.

---

### Task A1 — senior-engineer plan mode accepts `notes` (AC-34)

- **id:** A1
- **files:** `agents/senior-engineer.md`
- **depends_on:** []
- **pattern:** the existing Dispatch fields bullets (`n`, `base`: field, modes it applies to, fallback) and step 5's material-challenge rule, which the note handling reuses rather than restates.
- **AC:** AC-34
- **Edits (no inline prose here; wording to the implementer, British English):**
  1. Dispatch fields: add the `notes` bullet per C-1 (optional, plan only, last field, may span lines, sources).
  2. Files per mode, plan row "Also read": add "`05-plan.md` when `notes` is given".
  3. Mode: plan: one new step before step 1 (or a sub-bullet of step 3): when `notes` is given, read the earlier plan, treat each note as a requirement on the revision, and end `## Approach` with the `Revision notes:` list per C-1; a note that needs a material spec change goes through step 5.
  4. Definition of done → Mode: plan: add "with `notes`, `## Approach` addresses every note".
- **RED:** `grep -c 'notes' agents/senior-engineer.md` → `0` (checked 2026-10-25).
- **GREEN:**
  - `grep -n '`notes`' agents/senior-engineer.md` shows hits in Dispatch fields, Files per mode, Mode: plan and Definition of done (4 sections).
  - `grep -n 'Revision notes' agents/senior-engineer.md` → at least one hit.
  - `claude plugin validate .` → `✔ Validation passed` (warnings as before).
  - `git diff --stat` touches only `agents/senior-engineer.md`.
- **Commit:** `feat(agents): let senior-engineer plan mode take gate and blocked notes`

---

### Task A2 — standards-setter `mode: init` (AC-35)

- **id:** A2
- **files:** `agents/standards-setter.md`
- **depends_on:** []
- **pattern:** senior-engineer's `mode` field rule ("A missing or unknown mode is `STATUS: blocked`") adapted to a defaulted mode; standards-setter's own step 2 empty-detection branch for the init empty case.
- **AC:** AC-35 (agent side)
- **Edits:**
  1. Frontmatter `description`: mention that init also dispatches it (keep one sentence, keep "don't use it directly").
  2. Inputs: add the `mode` field per C-2 (`pipeline` default with `run_dir`; `init` with no `run_dir`, no brief, no `.aew/runs/current` read; unknown → `blocked`). Mark `02-brief.md` as required in pipeline mode only.
  3. Process: step 1 and step 8 say "pipeline mode only"; step 2's empty-array branch gains the init variant (write nothing, `ARTEFACTS: none`).
  4. Outputs and Return contract: `03-standards.md` pipeline only; in init the return block is in the final message only, ARTEFACTS / NEXT / `blocked` per C-2.
  5. Definition of done: the `03-standards.md` bullets apply to pipeline mode.
- **RED:** `grep -c 'mode: init' agents/standards-setter.md` → `0` (checked 2026-10-25).
- **GREEN:**
  - `grep -n 'mode: init' agents/standards-setter.md` → hits in Inputs and Return contract at least.
  - `grep -n 'ARTEFACTS: none' agents/standards-setter.md` → one hit.
  - Pipeline wording intact: `grep -c '03-standards.md' agents/standards-setter.md` is not lower than before (the existing references stay, each qualified as pipeline-only; none deleted).
  - `claude plugin validate .` → `✔ Validation passed`.
  - `git diff --stat` touches only `agents/standards-setter.md`.
- **Commit:** `feat(agents): add a run-less init mode to standards-setter`

---

### Task A3 — `gh-pr.sh open` with bats tests and github-ops rows (AC-36)

- **id:** A3
- **files:** `scripts/gh-pr.sh`, `tests/scripts/gh-pr.bats`, `skills/github-ops/SKILL.md`
- **depends_on:** []
- **pattern:** `cmd_create` in `scripts/gh-pr.sh` (option loop, positional collection, `need_file`, refusals before gh, URL → number); `git-branch.sh` line 78 for the branch check; the "create prints the PR number…" and "create refusals make no gh call" tests in `gh-pr.bats`.
- **AC:** AC-36
- **Reuse:** extract the existing URL → PR-number lines of `cmd_create` into one small helper that `cmd_create` and `cmd_open` both call (the existing "output without a /pull/<n> URL is an error" test guards the refactor). Reuse `need_file`. `require_cmd git` inside `cmd_open` only. No new library function.
- **Script edits:** add `cmd_open` per C-3 and an `open)` arm in the dispatch `case`; add the `open` entry to the Usage header (this is `--help`); change the header's "There is no 'PR already exists' lookup: check state.pr before calling create." to say `create` has none and `open` does.
- **Tests (three, appended to `gh-pr.bats`, reusing its `setup`, which already cans `pr-create` → `.../pull/7`):**
  1. `open creates a PR when none is open and prints its number`: body file `printf 'Set up aew.\n'`. `"$PR" open chore/aew-init "chore: set up aew" body.md` → success, `$output` = `7`; `assert_gh_called "pr list --head chore/aew-init --state open"`; `assert_gh_called "pr create --head chore/aew-init --title chore: set up aew --body-file"`; `refute_gh_called "--base"`; captured body `cmp` equal to the input. The `refute_gh_called "--base"` assertion runs before the next call. Then, in the same test, a second call with `--base main` (the call log accumulates): success, `$output` = `7`, `assert_gh_called "--base main"`.
  2. `open reuses an already-open PR without creating one`: `gh_mock_respond pr-list - 0 <<< "17"` → success, `$output` = `17`, `refute_gh_called "pr create"`, `gh_call_count` = 1.
  3. `open refusals make no gh call`: each exits 1 with `error:` on stderr — no args; branch only; branch + title only; `bad..branch`; empty title `""`; title with a newline; missing body file; empty body file; `--base` with no value; `--base 'bad..x'`; `--bogus`; a fourth positional. Then `gh_call_count` = 0.
- **RED:** run `bats -f 'open ' tests/scripts/gh-pr.bats` before the script change → 3 tests, the first two fail with stderr `gh-pr.sh: error: unknown subcommand: open (see --help)`. (Test 3 passes vacuously at RED because every call exits 1 with `error:` already; record that, and that it goes on guarding the "before any gh call" rule.)
- **GREEN:**
  - `bats tests/scripts/gh-pr.bats` → all tests pass (the existing 16 plus 3 new).
  - `scripts/gh-pr.sh --help` shows the `open <branch> <title> <body-file> [--base <branch>]` line.
  - `tests/run-script-tests.sh` → shellcheck clean and every bats file passes (`conventions.bats` covers strict mode, `--help` and bash 3.2 conventions).
- **github-ops edits (`skills/github-ops/SKILL.md`):** script table row "Use it to" becomes "open (for a run or run-less), update, ready and comment on the PR"; "Other calls" adds `gh-pr.sh open chore/aew-init "chore: set up aew" pr-body.md --base main`; Operational rules: the `state.pr` bullet keeps `create`'s rule and adds that `open` is for run-less PRs (init) and reuses an open PR for the head branch; Conventions → Exceptions adds `gh-pr.sh open <branch> <title> <body-file>`; Stdout contract: "`create` and `open`: the PR number".
  - GREEN check: `grep -c 'gh-pr.sh open' skills/github-ops/SKILL.md` → at least `3` (RED: `0`, checked 2026-10-25).
- **Commit:** `feat(scripts): add gh-pr.sh open for run-less PRs that reuses an open PR`

## Phase verification (after A1–A3)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                      # all green, shellcheck clean
claude plugin validate .                       # ✔ Validation passed (existing warnings only)
grep -c 'notes' agents/senior-engineer.md      # > 0
grep -c 'mode: init' agents/standards-setter.md  # > 0
scripts/gh-pr.sh --help | grep -c 'open <branch>'  # 1
git status --porcelain                         # only the five files above (plus the pre-existing spec/project-map changes)
```

No paid run in this phase. Live exercise of C-1 and C-2 is Phase F's (G2/R2 do not reach a request-changes gate headless; I1/I2 dispatch `mode: init`).

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-34 optional `notes`, revised plan addresses each note and says how in `## Approach` | A1 | A1 GREEN greps; C-1 |
| AC-35 `mode: init`: no run dir, no brief, docs + README as usual, no `03-standards.md` / "Sections that apply", block in final message only | A2 | A2 GREEN greps; C-2 |
| AC-35 "DESIGN §8.3 records it (C3)" | Phase F | not here (cut 10, AC-47) |
| AC-36 `open <branch> <title> <body-file> [--base]`, reuse an open PR, create otherwise, prints number; bats create/reuse/invalid-before-gh; `--help`; github-ops; suite passes | A3 | three bats tests; `--help`; `tests/run-script-tests.sh`; github-ops grep |

## Decisions (flag if wrong)

1. **`notes` is the last dispatch field and may span lines**, rather than a file in the run dir or a one-line squashed value. Gate feedback is free text, and AC-5's "`key: value` lines only" holds for every other field. Phase B must put it last.
2. **A note that needs a material spec change returns `needs_input` through step 5**, not `blocked`. This reuses the agent's existing challenge path, and Phase B already routes plan `needs_input` (cut 8).
3. **standards-setter's mode defaults to `pipeline`**, so the existing orchestrator dispatch (`run_dir` only) and the prompt-03 smoke runs stay valid.
4. **Init mode still updates agent memory.** Cut "nothing else" read literally. Phase D must decide whether `.claude/agent-memory/aew-standards-setter/` is staged in init's commit (it is project-scoped memory, so committing it is consistent with DESIGN §3).
5. **`ARTEFACTS: none`** for an init run with no detected stack, because the return-block rule needs a value.
6. **`open` passes no `--base` by default** (gh's repository default applies) and reads no config, keeping the subcommand run- and config-free. Init passes `--base` from config.
7. **`open` does not normalise the body** (no `Closes #n`): there is no issue. A later caller with issues should use `create`.
8. **Lookup is `--state open` only.** A merged or closed earlier init PR does not block a new one; init's "no changes → no PR call" rule (AC-33) handles the idempotent case.
9. **Three bats tests only** (cut list): gh failure on the lookup and a non-numeric lookup result are handled in code (exit 1) but not separately tested.
10. **DESIGN §8.3/§8.4 text deferred to Phase F**, so no two phases edit DESIGN in parallel.

## Risks

- **Multi-line `notes` misread as further fields.** Mitigation: C-1 makes it the last field; Phase B's `dispatch.md` states it; Phase E's `skills.bats` can grep that `notes` is listed last.
- **`gh pr list --head` matching a same-named branch from a fork.** `--head` filters by branch name only; a fork's open PR with the same head name could be reused by mistake. Residual and unlikely for `chore/aew-init` in the user's own repo; recorded for prompt 07's sandbox run.
- **The mock ignores `--jq`.** Canned `pr-list` output is the post-jq value (`17`), so the tests do not prove the jq expression; it is the documented `gh` form. Prompt 07's sandbox run exercises it live.
- **Refactoring `cmd_create`'s number parsing** could regress `create`. Guarded by the existing "output without a /pull/<n> URL is an error" and "create prints the PR number" tests, run in A3 GREEN.

## Approval (Phase A)

- Senior architect: APPROVED on 2026-10-24T23:08:38Z (plan-review)
- Plan format: LEAN
- Plan dependency graph: valid. Wave count: 1. Max wave width: 3 tasks parallel (A1, A2, A3; no file overlap).
- Mechanical fix applied: A3 test 1 now states the `refute_gh_called "--base"` ordering and that the `--base main` call runs in the same test.
- Plan content hash (SHA-256, doc above this trailer): 557809207c3986deb4d5ed6c44ff66f2a3b7c6eb045be8410930b55fb2c05327

---

# Phase B plan — the ship orchestrator

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583…6090`), overridden where they differ by the CTO simplicity-challenge cuts (2026-10-25, all adopted). The cuts that bind this phase are **7** (preflight checks the default branch but does not fast-forward, and writes nothing), **8** (one rule for a plan `needs_input`) and **10** (DESIGN §9 only points at `skills/ship/references/`, so the preflight order and the reads table must live here in full).
- **Phase:** B of the EPIC. `depends_on: []`. Phase C (`resume`, `prompt`) Reads this phase's `SKILL.md` and references and enters them at the named sections. Phase E's `tests/scripts/skills.bats` greps the strings in the interface contract. Phase F's allowlist and expected `gh` call order come from contract I-8 and I-9. Phase A's senior-engineer `notes` field is used here as a single dispatch line (I-10).
- **Depth:** full
- **ACs covered:** AC-1 to AC-20. AC-3.4 and AC-14 as amended by cuts 7 and 8.
- **Risk:** none of the risky criteria. The files are Markdown procedures with no runtime effect until a user types `/aew:ship`, and nothing exercises them live before phase F.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" means the spec's assumption n, "AC-n" the spec's ACs, and "cut n" the CTO simplicity cut n. Task ids are `B1`–`B8`, dispatch rows are `D1`–`D13` (contract I-4), and plan-level decisions are `PD-1`–`PD-14`. These number ranges are unrelated to each other.

> **For agentic workers:** implement task by task. These are documentation tasks, so each task's RED is a check that fails before the change (the file is absent, or a grep count is 0) and its GREEN is the same check passing. Record both outputs in the task report. Write the skill text from the outlines below. The headings, gate ids, note formats, error strings, table formats and commands marked **verbatim** are contracts: copy them exactly. Everything else is content to write in your own words, in British English, with the same rules.

**Goal:** a main-thread `ship` skill that takes one issue through DESIGN §7.3. It parses `$ARGUMENTS`, runs the §9 preflight, starts or restarts the run, dispatches each agent with explicit file inputs, reads only return blocks and the bounded sections a gate or routing decision needs, and runs the two gates, the review loop, the QA loop, the blocked path, the PR steps and the final report. Each stage gets its own section, so `resume` can enter it by name.

**Architecture:** one procedure file, `skills/ship/SKILL.md` (frontmatter, rules, the reads table, Steps 1–4, ten `## Stage:` sections, and the gate-pending, blocked and final-report exits), plus six reference files, each read at the step that needs it. All paths are absolute `${CLAUDE_PLUGIN_ROOT}/…` paths. Only `SKILL.md` is substituted when it loads (V-5), so it states the root once and tells the reader to map the literal `${CLAUDE_PLUGIN_ROOT}` in the references to it. No script, hook, agent or template changes in this phase. The commands the references give (the `jq` render, the `awk` section reads, the return-block check) were dry-run against the templates while this plan was written (see PD-6 and the B3/B4/B5 notes).

**Tech stack:** Markdown skill files; bash 3.2, jq 1.7.1, awk (BSD) for the inline commands; `claude plugin validate .`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` | AC-1–20, Assumptions 2–5, 9–20, 28, Conflicts C2 and C4, V-1, V-3, V-4, V-5, V-6 |
| CTO cuts (scratchpad `simplicity-adopted.md`) | Cuts 7, 8 and 10 (above) |
| `skills/run-protocol/SKILL.md`, `references/state-machine.md` | Stage→label mapping, gates table, failure paths, the `qa_failures_complete` rule, counters and cycle-file naming. `routing.md` and `gates.md` restate them as procedure and link back for the diagram |
| `skills/github-ops/SKILL.md` | Every script call, the spec-revision recording order, "check `state.pr` before create", "write state before each developer dispatch" |
| `scripts/{state,gh-issue,gh-labels,git-branch,gh-pr,gh-retro}.sh --help` | Script contracts. Notes: `state.sh init` sets stage `spec_analysis`, status `running`, `base_branch` = config `default_branch`, and refuses an existing `state.json`; `stage` always sets status `running`; `git-branch.sh create` refuses a dirty tree (untracked files count) or an existing branch; `gh-pr.sh create` prints the PR number |
| `scripts/hooks/gate-subagent.sh` (`valid_return_block`, `gate_developer`, `gate_qa`) | The return-block rule (the last four **non-blank** lines), the developer freshness check (`state.json -nt` the newest report), and the QA gate's `08-qa-report-<fix_cycle+1>.md` name |
| `agents/*.md` Inputs and Return contract sections | Dispatch fields and required files (dispatch table I-4); the review verdict is the first word of SUMMARY; triage NEXT names "developer (fix mode)" and/or "qa-engineer"; triage `needs_input` carries "the question and your recommended answer" with no dedicated section (PD-12); spec-analyser's re-run records answers against question ids |
| `templates/artefacts/{spec-analysis,plan,qa-report,triage,summary,manual-tests,spec-revision-comment}.md`, `spec-changes.example.json` | The sections the bounded reads target (`## Questions` / `### Q<n>.`, `## Challenges to the spec`, the `## Failures` triage table and the `### <TC>:` entries, `- [x] AC-n`, `- [ ] **TC-n`), and the revision comment the `jq` render reproduces |
| `templates/config.schema.json` | `limits` defaults 3 (fix) and 2 (review), `gates.plan_approval` default `true`, `default_branch` default `main` |
| `docs/superpowers/plans/phases/2026-10-24-build-agents-phase-A.md` | Format mirrored here |

Gotchas that apply (from `docs/superpowers/project-map.md`): `${CLAUDE_PLUGIN_ROOT}` is not in the Bash tool's environment, so the model writes the substituted absolute path into each command; the developer gate compares at whole-second resolution, so the state write goes immediately before every developer dispatch; the Bash safety hook blocks any command whose text contains `git push` (`git-branch.sh push` does not contain it); `grep -c` exits 1 when the count is 0; agents with `memory: project` write `.claude/agent-memory/aew-<agent>/` into the target project during a run (PD-2).

## Plan-level decisions (each one is a refinement the spec leaves open; flag if wrong)

- **PD-1 Pending-gate representation.** Every gate writes its pending status with a note in a fixed format: `state.sh status <awaiting_input|awaiting_plan_approval> --note "gate:<gate-id> <source file>"`. `resume` finds the gate with one `jq` read of `history` (contract I-5). There is no new schema field: `state.sh` already stores `--note` in `history`.
- **PD-2 Agent memory.** spec-analyser, standards-setter, senior-engineer, qa-engineer and doc-writer write `.claude/agent-memory/aew-<agent>/` into the project during a run (seen in smoke run 951). Left alone, this makes every later `--from`, resume and fresh ship fail the clean-tree check. Ship therefore (a) commits `.claude/agent-memory/` once, after the docs commit (`chore(aew): update agent memory (#<n>)`), and (b) for `--from` (and Phase C's resume) treats the tree as clean when the only changes are under `.claude/agent-memory/`. A fresh run still needs a fully clean tree, because `git-branch.sh create` counts untracked files.
- **PD-3 Developer `blocked`.** A full-mode developer `blocked` re-plans once (AC-12). Each re-plan writes the note `developer blocked: re-plan`, and a second full-mode `blocked` is detected from `history`, so the count survives a resume. A `blocked` from **fix mode** (review fix or QA fix) goes to the blocked path, because re-planning a finished build in the middle of a loop is not what AC-12 describes.
- **PD-4 Answers to questions spec-analyser did not ask.** These come from plan challenges, triage and spec-ambiguity. They go to spec-analyser as new ids that continue its numbering, with the question text inline: `Q<k>: <question> => <answer>`. Untested live in this prompt (prompt 07 covers it). If spec-analyser refuses such answers, the fix is one Inputs line in `agents/spec-analyser.md`.
- **PD-5 The develop stage picks its mode from `review_cycle` and file age.** Fix mode needs both `review_cycle = k ≥ 1` **and** `test <rd>/07-review-<k>.md -nt <rd>/05-plan.md`. Then it is `mode: fix`, `fix_from: 07-review-<k>.md`, `n: k`; otherwise `mode: full`. A re-plan rewrites `05-plan.md`, which makes the last review older than the plan, so the next develop is full. The review loop bumps the counter and enters `## Stage: develop`, so in-session flow, `--from develop` and resume all take the same path and reach the same mode. Resume at `qa` simply re-dispatches QA phase B, as AC-21 says ("re-dispatching that stage").
- **PD-6 `jq` and `false`.** `jq '.gates.plan_approval // true'` returns `true` for an explicit `false`, so the plan gate reads it as `jq -r 'if .gates.plan_approval == false then "off" else "on" end'` (dry-run: `{"gates":{"plan_approval":false}}` gives `off`, `{}` gives `on`).
- **PD-7 Return check.** The check reads the last four **non-blank** lines (`awk 'NF' <file> | tail -n 4`), which is `valid_return_block`'s rule. A plain `tail -n 4` would fail on a trailing blank line. For the Agent result, the model checks the last four non-blank lines of the text it received.
- **PD-8 Spec-revision recording is idempotent.** Recording runs only when `spec-changes.json` has at least one change **and** its `version` is greater than `state.spec_revision`, so a resumed or repeated `ok` never re-posts.
- **PD-9 Script failures.** A plugin script that exits non-zero after the run has started goes to the blocked path, with its first stderr line as the reason. There are three exceptions: a fetch failure or a closed issue during run start (`failed`, then `current` cleared, AC-4); `gh-retro.sh` (warn only, AC-16); and `gh-labels.sh` when a label is missing (blocked path, with "run `/aew:init`" added to the reason, Assumption 14).
- **PD-10 Default branch ahead of origin only** (cut 7 covers behind and diverged): warn that the PR will include the unpushed commits, then continue. A missing local default branch stops the run with a `git switch <default>` hint.
- **PD-11 Stopping at the plan gate.** `state.sh status failed`, then `current` cleared. The stage label stays `awaiting-approval` (the label set has none for `failed`), and the final report says so. Recorded for prompt 07.
- **PD-12 Triage `needs_input` questions.** The triage template has no Questions section, so the gate reads `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md`, a bounded read added to AC-19's list.
- **PD-13 Slug.** One `jq` expression: lower-case the title, turn runs of anything other than `[a-z0-9]` into `-`, trim the ends, cut to 40 characters and trim again, with `issue-<n>` as the fallback (dry-run: `Add to basket: fix £ totals!! ` gives `add-to-basket-fix-totals`).
- **PD-14 Commits the orchestrator makes** stage explicit paths only (`git add -- <paths>`), never `-A` or `.`. The docs commit takes the doc-writer's ARTEFACTS paths that are outside `.aew/`.

## Interface contract (Phases C, E and F rely on this)

### I-1. `skills/ship/SKILL.md` frontmatter (verbatim)

```yaml
---
name: ship
description: Ship one GitHub issue through the aew pipeline - spec analysis, brief, standards, QA plan and plan in parallel, the plan gate, development, review, QA with triage, docs and a pull request. Run it as /aew:ship <issue> [--auto] [--from <stage>].
disable-model-invocation: true
argument-hint: "<issue> [--auto] [--from <stage>]"
---
```

There is no `allowed-tools`, no `` !`cmd` `` injection, no `$N` or `$ARGUMENTS[N]`, and exactly one `$ARGUMENTS` (in Step 1). When `resume` reads the file with Read, nothing in it is substituted or run (AC-1).

### I-2. `SKILL.md` headings, in this order (verbatim; each occurs exactly once)

```
# aew ship
## Plugin root
## Rules
## Run variables
## What the orchestrator reads
## References
## Step 1. Parse the arguments
## Step 2. Preflight
## Step 3. Start the run
## Step 4. Restart at a stage (--from)
## Stage: spec_analysis
## Stage: brief
## Stage: standards
## Stage: qa_test_plan
## Stage: plan
## Stage: develop
## Stage: review
## Stage: qa
## Stage: docs
## Stage: pr
## Gate pending
## Blocked path
## Final report
```

- Each `## Stage: <stage>` section has numbered steps, and **step 1 is always Entry** (the state write and the label). Later steps are Dispatch, Check, Exit and Failure. `## Stage: qa_test_plan` is a two-line section: "`qa_test_plan` and `plan` are one step. Go to `## Stage: plan`."
- **How Phase C enters** (resume): Read this file and the references it names, skip Steps 1–4 (`resume` does its own branch and tree checks, and takes the issue, `auto` and counters from `state.json` via `## Run variables`), then enter `## Stage: <state.stage>` at step 1 with the note `resume`. For `awaiting_input` or `awaiting_plan_approval`, enter `gates.md` `## Re-asking a pending gate` instead (I-5).
- **How Phase C enters** (prompt): `## Step 3. Start the run` sub-steps 3.1–3.5 (existence check, `state.sh init`, fetch, closed check, title), skipping 3.6–3.8 (label, branch, stage entry). Straight after 3.2 it writes the I-11 `prompt` marker (`state.sh stage spec_analysis --note "prompt"`); without it, a resumed prompt run would continue into ship's D3. Then `gates.md` `## Gate: spec` and `## Recording a spec revision` under the prompt-mode rule in I-5, and dispatch rows D1, D2 and D4 (I-4). Phase C uses preflight checks 1, 3 and 5 by their headings (I-3).

### I-3. Reference files: what each covers, and its headings (verbatim)

| File | Headings | Read at |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/preflight.md` | `## Check 1. Config exists`, `## Check 2. Clean working tree`, `## Check 3. gh is authenticated`, `## Check 4. Default branch up to date`, `## Check 5. No other active run`, `## Check 6. superpowers major version (warn only)`, `## Restart checks (--from)` | Step 2, Step 4 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/dispatch.md` | `## How to dispatch`, `## Dispatch table`, `## Required inputs per stage`, `## Return check`, `## Retries` | every Stage section |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/gates.md` | `## Gate ids and pending state`, `## Asking`, `## Gate: spec`, `## Gate: plan-challenge`, `## Gate: triage`, `## Gate: spec-ambiguity`, `## Gate: plan-approval`, `## Recording a spec revision`, `## Re-asking a pending gate`, `## Destructive operations` | spec_analysis, plan, qa; resume |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/routing.md` | `## Stage table`, `## Agent status routing`, `## Review loop`, `## Developer blocked`, `## QA loop`, `## Cycle limits`, `## Script failures` | every Stage section |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/pr.md` | `## Commit rules`, `## Standards commit`, `## Docs and memory commits`, `## Push and pull request`, `## Manual tests`, `## Retro`, `## Finish` | standards, docs, pr |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/final-report.md` | `## Format`, `## Counting`, `## Blocked and failed runs` | Final report |

Each `## Gate: <id>` section has four numbered steps: **1. Set pending** (state and label), **2. Read** (the bounded source read), **3. Ask**, **4. Apply the answer**. Each `## Check n.` section gives the command, the pass condition and the exact stop (or warning) message.

### I-4. Dispatch rows (`dispatch.md` `## Dispatch table`; ids are cited from `SKILL.md` and `routing.md`)

Table columns (verbatim header): `| Row | Agent and mode | subagent_type | Prompt fields | Required files | State write before |`. `<rd>` is `.aew/runs/<id>`, relative to the project root.

| Row | Agent and mode | subagent_type | Prompt fields | Required files (`test -f`) | State write before |
|---|---|---|---|---|---|
| D1 | spec-analyser, first run | `aew:spec-analyser` | `run_dir`, `spec_version: <spec_revision+1>` | `00-issue-original.md`, `issue.json` | Step 3 (fresh) or stage entry `spec_analysis` |
| D2 | spec-analyser, re-run with answers | `aew:spec-analyser` | `run_dir`, `spec_version: <spec_revision+1>`, `answers:` then one `Q<k>: …` line per answer | the above plus `01-spec-analysis.md` | `state.sh stage spec_analysis --note "answers: gate:<id>"` |
| D3 | brief-compiler, pipeline | `aew:brief-compiler` | `run_dir`, `mode: pipeline` | `spec-final.md`, `issue.json` | stage entry `brief` |
| D4 | brief-compiler, prompt (used by `prompt`) | `aew:brief-compiler` | `run_dir`, `mode: prompt` | `spec-final.md`, `issue.json` | `state.sh stage brief` (prompt mode sets no label; Phase C) |
| D5 | standards-setter | `aew:standards-setter` | `run_dir` | `02-brief.md` | stage entry `standards` |
| D6 | qa-engineer, phase A | `aew:qa-engineer` | `run_dir`, `phase: A` | `02-brief.md`, `03-standards.md` | stage entry `plan` (one write for D6 and D7) |
| D7 | senior-engineer, plan | `aew:senior-engineer` | `run_dir`, `mode: plan`, optional `notes: <one line>` | `02-brief.md`, `03-standards.md` | stage entry `plan` |
| D8 | developer, full | `aew:developer` | `run_dir`, `mode: full` | `05-plan.md`, `02-brief.md`, `03-standards.md` | stage entry `develop` (immediately before) |
| D9 | senior-engineer, review | `aew:senior-engineer` | `run_dir`, `mode: review`, `n: <review_cycle+1>`, `base: <base_branch>` | `02-brief.md`, `05-plan.md`, `03-standards.md` | stage entry `review` |
| D10 | developer, fix | `aew:developer` | `run_dir`, `mode: fix`, `fix_from: <file>`, `n: <k>` | the `fix_from` file | stage entry `develop` (review fix) or `state.sh stage qa --note "fix <k>: developer"` (QA fix), immediately before |
| D11 | senior-engineer, triage | `aew:senior-engineer` | `run_dir`, `mode: triage`, `n: <k>` | `08-qa-report-<k>.md` | the `bump fix_cycle` of the QA loop |
| D12 | qa-engineer, phase B | `aew:qa-engineer` | `run_dir`, `phase: B`, `n: <fix_cycle+1>`, optional `triage: <rd>/09-triage-<k>.md` | `02-brief.md`, `04-qa-test-plan.md` | stage entry `qa` (first pass) |
| D13 | doc-writer | `aew:doc-writer` | `run_dir` | `spec-final.md`, `issue.json`, `state.json` | stage entry `docs` |

standards-setter `mode: init` is **not** in this table: init dispatches it, and Phase D owns that row.

### I-5. Gates: ids, pending state and re-asking

- Gate ids (verbatim): `spec`, `plan-challenge`, `triage`, `spec-ambiguity`, `plan-approval`.
- Pending writes (verbatim formats):

  | Gate | Status write | Label write (verbatim) | Bounded read (step 2) |
  |---|---|---|---|
  | `spec` | `state.sh status awaiting_input --note "gate:spec 01-spec-analysis.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Questions` of `01-spec-analysis.md` |
  | `plan-challenge` | `state.sh status awaiting_input --note "gate:plan-challenge 05-plan.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Challenges to the spec` of `05-plan.md` |
  | `triage` | `state.sh status awaiting_input --note "gate:triage 09-triage-<k>.md"` | `gh-labels.sh stage <n> awaiting-input` | `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md` |
  | `spec-ambiguity` | `state.sh status awaiting_input --note "gate:spec-ambiguity 08-qa-report-<k>.md"` | `gh-labels.sh stage <n> awaiting-input` | the triage table and the `### TC-<n>:` entries classed `spec_ambiguity` |
  | `plan-approval` | `state.sh status awaiting_plan_approval --note "gate:plan-approval 05-plan.md"` | `gh-labels.sh stage <n> awaiting-approval` | `05-plan.md` in full |

- Pending gate lookup (verbatim command; `resume` uses it): `jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' .aew/runs/<id>/state.json`. `## Re-asking a pending gate` maps the note's gate id to its `## Gate: <id>` section and says to enter it **at step 2** (state and label are already set).
- Unanswered gate (AC-10): AskUserQuestion not among the tools, refused, or an empty answer → `SKILL.md` `## Gate pending`, which prints the questions (or the plan summary and path), then the line `Answer with /aew:resume <id>` (verbatim), then stops.
- Prompt-mode rule (verbatim sentence in `## Gate ids and pending state`): "In prompt mode (`/aew:prompt`), skip every `gh-labels.sh stage` call in this file and keep the `gh-labels.sh flag` call."

### I-6. `routing.md` `## Stage table` format (Phase E checks it)

- Header (verbatim): `| Stage | Entry | Exit | Failure |`, then the separator `|---|---|---|---|`.
- Ten rows, one per schema stage, in schema order. Each row starts with the backticked stage name, for example `` | `spec_analysis` | ``.
- **No literal `|` inside any cell** (use "or" or `∥`), so a split on `|` gives exactly 4 cells. Every cell is non-empty. The `qa_test_plan` row's cells may read "as `plan` (one step)".

### I-7. Strings Phase E's static checks grep for (all in `skills/ship/SKILL.md` unless named)

- AC-2 error lines (verbatim prefixes and fragments): `aew ship: missing issue number.` · `must be a positive integer` · `/aew:ship-milestone` · `unknown option` · `given more than once` · `unexpected argument` · `--from needs a stage` · `unknown stage` · the stage list `spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr` · the usage line `Usage: /aew:ship <issue> [--auto] [--from <stage>]`.
- The ten `## Stage: <stage>` headings (I-2), and the reads table heading `## What the orchestrator reads`.
- Frontmatter lines `disable-model-invocation: true` and `argument-hint: "<issue> [--auto] [--from <stage>]"`.
- **Name hygiene for the existence checks** (AC-38):
  - every `${CLAUDE_PLUGIN_ROOT}/…` path in `skills/ship/**` names a real file or directory, with no `<placeholder>` inside the path;
  - every `aew:<name>` is an agent used as `subagent_type` (`aew:spec-analyser`, `aew:brief-compiler`, `aew:standards-setter`, `aew:qa-engineer`, `aew:senior-engineer`, `aew:developer`, `aew:doc-writer`) or a slash command (`/aew:ship`, `/aew:resume`, `/aew:init`, `/aew:status`, `/aew:prompt`, `/aew:ship-milestone`);
  - labels are always written bare (`gh-labels.sh stage <n> blocked`, "the `blocked` label"), never as `aew:<label>`;
  - **`/aew:ship-milestone` is a forward reference** (prompt 06), and Phase E must allow it explicitly.

### I-8. Commands ship runs (Phase F's allowlist union; Phase D's permission proposal)

The commands are given with `<placeholders>` that the orchestrator fills in, and with no shell variables, so each command matches an anchored rule. `<root>` is the substituted plugin root.

- Plugin scripts by absolute path: `<root>/scripts/state.sh …`, `gh-issue.sh …`, `gh-labels.sh …`, `git-branch.sh create|push`, `gh-pr.sh create|update …`, `gh-retro.sh file …`.
- `gh auth status` (exact; the only direct `gh` call, Assumption 9) and `claude plugin list --json` (exact, piped into `jq`).
- git: `git status --porcelain` (with an optional `-- <path>`), `git status --porcelain --untracked-files=all` (both forms of preflight Check 2), `git fetch origin <default>`, `git rev-parse --verify --quiet refs/heads/<default>`, `git rev-list --left-right --count <default>...origin/<default>`, `git branch --show-current`, `git switch <branch>`, `git add -- <paths>`, `git commit -m <msg>`.
- Read-only helpers: `jq …`, `awk …`, `tail -n 4`, `test -f|-d|-e …`, `test <file> -nt <file>` (PD-5), `grep -c …`, `cat .aew/runs/current`, `ls .aew/runs/<id>`.
- Blocked comment: `mktemp -t aew-blocked`, then `cat > <tmpfile> <<'EOF' … EOF`.
- The `spec-revision-v<N>.md` render: `jq -r '…' <rd>/spec-changes.json > <rd>/spec-revision-v<N>.md`.

### I-9. Script-call order on a clean `--auto` run (Phase F writes the S1 expected `gh` routes from this)

`gh auth status` → `state.sh init` → `gh-issue.sh fetch` → `state.sh set title` → `gh-labels.sh stage analysing` → `git-branch.sh create` → `state.sh set branch` → spec-analyser → [if changes: `gh-issue.sh revise`, `gh-issue.sh comment`, `gh-labels.sh flag add spec-revised`, `state.sh set spec_revision`] → `gh-labels.sh stage planning` (at brief; the standards and plan entries repeat it as no-ops) → [standards commit] → `gh-labels.sh stage building` (develop; review repeats it) → `gh-labels.sh stage testing` → [a fix cycle changes no label] → `gh-labels.sh stage documenting` → [docs and memory commits] → `git-branch.sh push` → `gh-pr.sh create` → `state.sh set pr` → [if manual tests: `gh-issue.sh manual-tests`, `gh-labels.sh flag add manual-test-required`] → `gh-retro.sh file` → `gh-labels.sh stage ready-for-review` → `state.sh status done` → `state.sh current clear`.

### I-10. Cross-phase field formats

- `notes:` (Phase A's senior-engineer field) is **one line** and the **last** field of the D7 prompt (Phase A C-1 allows several lines; one line is a compatible subset): James's notes, joined with ` / `, or `developer blocked: <the developer's SUMMARY> / <the dev report path>` (the C-1 developer source: reason plus report path).
- `answers:` is a line of its own, followed by one `Q<k>: <answer>` line per answer. Questions spec-analyser did not ask are written `Q<k>: <question> => <answer>`, with k continuing after the highest `### Q<n>.` in `01-spec-analysis.md` (PD-4).

### I-11. Run markers in `history` (written with `--note`, read with `jq`; they survive a resume)

| Marker (verbatim note) | Written by | When | Read by | Check (verbatim) |
|---|---|---|---|---|
| `prompt` | the `prompt` skill (Phase C) | `state.sh stage spec_analysis --note "prompt"`, straight after its `state.sh init` (3.2) and before the fetch | `gates.md` `## Gate: spec` step 4 and `## Re-asking a pending gate`; Phase C's `resume` (a prompt run hands back to the `prompt` skill, never to ship's D3) | `jq -r 'if ([.history[] \| select(.note == "prompt")] \| length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json`: `prompt` means a prompt-mode run. The `.branch == null` half is part of the check, owned here and used unchanged by Phase C: a prompt run never has a branch, and `/aew:ship <n> --from spec_analysis` (the only way to turn a prompt run into a ship run; restart checks refuse any other stage while `branch` is null) sets `branch` in Step 4.5 before any dispatch, so the converted run reads `ship` and is never handed back to `prompt` |
| `spec-ambiguity: non-material` | ship, `gates.md` `## Gate: spec-ambiguity` step 4 | the note on the `brief` Entry after a non-material answer | `SKILL.md` `## Stage: brief` exit | `jq -r '.history \| (map(.note == "spec-ambiguity: non-material") \| indices(true) \| last) as $i \| if $i == null then "no" elif (.[$i+1:] \| any(.stage != "brief")) then "no" else "yes" end' .aew/runs/<id>/state.json`: `yes` → `## Stage: qa` |

(Inside this table the `\|` stands for a literal `|` in the command.) Both checks were dry-run while revising: a history ending in the non-material note followed only by `brief` entries (`blocked`, `resume`) gives `yes`; with a later `qa` entry, or with no marker, it gives `no`; the prompt-mode check gives `prompt` for a marker with `branch` null, and `ship` once `branch` is set or with no marker (re-run while reviewing). "Prompt mode" anywhere in ship's files means this check prints `prompt`; neither ship nor Phase C tests the marker on its own.

## Tasks

Waves: **1** = B1 · **2** = B2 ∥ B3 ∥ B4 ∥ B5 ∥ B6 ∥ B7 (each writes one reference file and shares no text with the others; they agree only through contracts I-3 to I-6) · **3** = B8.

Commit trailer for every task: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. It applies to this repo's commits only. The orchestrator's own commits in target projects add no trailer (Assumption 28).

---

### Task B1 — `skills/ship/SKILL.md`, the procedure

- **id:** B1
- **files:** `skills/ship/SKILL.md` (new)
- **depends_on:** []
- **pattern:** frontmatter and numbered-section style from `skills/ui-qa/SKILL.md`; the stage list and failure rules from `skills/run-protocol/SKILL.md` "Stages". The procedure itself has no analog in the repo (spec: NOVEL).
- **ACs:** AC-1, AC-2, AC-4, AC-7 (the one-message rule), AC-10 (`## Gate pending`), AC-12/AC-11/AC-13 (summarised; detail in B5), AC-15, AC-18, AC-19, plus the skeleton every other AC hangs off
- **Size:** about 330–420 lines. **Hard limit 499.**

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
test -f skills/ship/SKILL.md; echo $?                       # 1
```

**Step 2: write `skills/ship/SKILL.md`** with the frontmatter in I-1 and the headings in I-2, in order. Content per section:

- `# aew ship`: two sentences. This is the main-thread orchestrator for one issue. It is the only part of aew that touches GitHub, and only through the plugin scripts. Agents are dispatched with explicit inputs, and only their return blocks are read.
- `## Plugin root`:
  - "The plugin root is `${CLAUDE_PLUGIN_ROOT}`." (substituted when the skill loads).
  - The scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Call each one by its absolute path, written out in the command, because the Bash tool has no `CLAUDE_PLUGIN_ROOT` variable. In this file and the references, a bare `state.sh …` (or `gh-issue.sh …` and so on) means that absolute path. Never write a `<placeholder>` inside a `${CLAUDE_PLUGIN_ROOT}/…` path (I-7).
  - The references are read with Read and are **not** substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above.
  - A skill that reads this file with Read (`resume`, `prompt`) states the root itself, and the same rule applies to this file.
- `## Rules` (bullets):
  - run every command from the project root and never `cd`;
  - never run `gh` except `gh auth status` in preflight;
  - never run git's push, merge, rebase, reset or force forms; push only with `git-branch.sh push`;
  - stage explicit paths only (PD-14);
  - never edit an artefact, `state.json` or `log.md` (scripts own state). The only files ship writes are `spec-revision-v<N>.md` (the `jq` render), the blocked-comment temp file and the commits in `pr.md`;
  - read only what `## What the orchestrator reads` lists;
  - every developer dispatch comes straight after a `state.sh` write in the same step (the developer gate's freshness check);
  - one agent per Agent call, except the planning pair;
  - an invalid return counts as `failed`; a failed dispatch is retried once in this session, then the blocked path;
  - script failures follow `routing.md` `## Script failures` (PD-9);
  - write labels bare (I-7);
  - a gate's answer comes only from AskUserQuestion on the main thread: never from an agent, and never invented.
  - **Citation form** (used in this file and in every reference, and checked by B8): a section of another file is cited as `` `<file>.md` `## <heading>` ``, for example `` `gates.md` `## Gate: spec` `` or `` `SKILL.md` `## Stage: develop` ``, with the file name in backticks, one space, then the exact heading in backticks.
- `## Run variables`: where each value comes from, read fresh before each use.
  - `<id>` and `<n>`: the run id and the issue number (the same number in single mode).
  - `<rd>`: `.aew/runs/<id>`.
  - `auto`, `review_cycle`, `fix_cycle`, `spec_revision`, `branch`, `base_branch`, `pr`, `stage`, `status`: `state.sh get <field>`.
  - Limits: `jq -r '.limits.max_review_cycles // 2' .aew/config.json` and `jq -r '.limits.max_fix_cycles // 3' .aew/config.json`.
  - Plan gate: the PD-6 expression.
  - `<default>`: `jq -r '.default_branch // "main"' .aew/config.json`.
  - Say once that `resume` takes all of these from `state.json`.
  - Say once that after `state.sh current clear` (run-start failures, the plan-gate stop, `## Finish`) `state.sh get` fails, so any later read uses `jq -r .<field> .aew/runs/<id>/state.json`.
- `## What the orchestrator reads` (AC-19; table `| Read | When | How |`). Rows:
  - the Agent return block (every dispatch; the last four non-blank lines of the result);
  - ARTEFACTS paths and required inputs (`test -f`), and the develop-mode age check (`test <rd>/07-review-<review_cycle>.md -nt <rd>/05-plan.md`, PD-5);
  - each named developer report (`awk 'NF' <file> | tail -n 4`);
  - `05-plan.md` (plan gate; **the only full read**);
  - `## Questions` of `01-spec-analysis.md` (gate `spec`);
  - `## Challenges to the spec` of `05-plan.md` (gate `plan-challenge`);
  - `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md` (gate `triage`, PD-12);
  - the triage table of `08-qa-report-<k>.md`, and of `<k-1>` for the repeat check (QA loop);
  - the `### TC-<n>:` entries classed `spec_ambiguity` (gate `spec-ambiguity`);
  - `state.json` (`state.sh get`, or `jq` for `history` notes);
  - `.aew/config.json` fields (`jq`);
  - `spec-changes.json` (`jq` counts and render to a file only);
  - `issue.json` (`jq` for `title`, `state` and `url`);
  - `10-summary.md` and `manual-tests.md` (`grep -c`).
  - Closing line: "Nothing else. Never open other artefacts, and never read source code." Then one sentence on the C2 clarification: bounded section reads are not full reads.
- `## References`: the I-3 table, with full `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/<file>` paths (real file names, no placeholder), plus `${CLAUDE_PLUGIN_ROOT}/skills/run-protocol/references/state-machine.md` for the diagram and `${CLAUDE_PLUGIN_ROOT}/skills/github-ops/SKILL.md` for script output contracts.
- `## Step 1. Parse the arguments` (AC-2):
  - "The arguments are: `$ARGUMENTS`" (the only placeholder).
  - Split on whitespace. Nothing in this step runs a command or writes anything. The first error wins. Print the error line, then the usage line `Usage: /aew:ship <issue> [--auto] [--from <stage>]`, then stop.
  - Algorithm, in order:
    1. no tokens → E1;
    2. first token `^m-[0-9]+$` → E3; `^[1-9][0-9]*$` → the issue; starts with `--` → E1; otherwise → E2;
    3. each later token from left to right: `--auto` (a second one → E5); `--from` (a second one → E5; no next token, or a next token starting with `-` → E7; a next token not among the ten stages → E8; otherwise that token is the stage); any other token starting with `-` → E4; anything else → E6.
  - Error lines (**verbatim**, `<…>` filled in):
    - E1 `aew ship: missing issue number.`
    - E2 `aew ship: the issue must be a positive integer, got "<token>".`
    - E3 `aew ship: "<token>" is a milestone; milestone runs use /aew:ship-milestone (coming in a later release).`
    - E4 `aew ship: unknown option "<token>".`
    - E5 `aew ship: option "<token>" given more than once.`
    - E6 `aew ship: unexpected argument "<token>".`
    - E7 `aew ship: --from needs a stage.`
    - E8 `aew ship: unknown stage "<token>". Stages: spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr.`
  - Result: `<n>`, `auto` (true or false) and `from` (a stage or none).
- `## Step 2. Preflight`: run `preflight.md` checks 1–6 in order. The first failing check stops the run with its message, having written nothing. Check 6 only warns. With `--from`, Check 2 uses the restart form and Check 5 treats this issue's run as being resumed. Then: `from` set → Step 4; otherwise → Step 3.
- `## Step 3. Start the run` (AC-4; sub-steps numbered **3.1–3.8 verbatim**, I-2). Write each one as a bullet starting `- 3.1 ` (the number, then a space):
  - 3.1 `test -e .aew/runs/<n>`: if it exists, stop with `Run <n> already exists: continue it with /aew:resume <n>, or restart a stage with /aew:ship <n> --from <stage>.`
  - 3.2 `state.sh init <n> --issues <n> --mode single` (add `--auto` when given).
  - 3.3 `gh-issue.sh fetch <n> .aew/runs/<n>`. On failure: `state.sh status failed --note "fetch failed: <first stderr line>"`, then `state.sh current clear`, then print `Could not fetch issue #<n>: <reason>. Fix it, then restart with /aew:ship <n> --from spec_analysis.` and stop.
  - 3.4 `jq -r .state .aew/runs/<n>/issue.json` gives `CLOSED`: the same three actions, with the reason `issue #<n> is closed`.
  - 3.5 `state.sh set title "$(jq -r .title .aew/runs/<n>/issue.json)"`.
  - 3.6 `gh-labels.sh stage <n> analysing`.
  - 3.7 the slug with the PD-13 `jq` expression (verbatim in B1: `jq -r '.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | .[0:40] | rtrimstr("-") | if . == "" then "issue-<n>" else . end' .aew/runs/<n>/issue.json`), then `git-branch.sh create <n> <slug>` (it prints the branch name), then `state.sh set branch <name>`.
  - 3.8 go to `## Stage: spec_analysis` **step 2** (Step 3 has done its Entry).
  - One line records the C4 order deviation (state is initialised before the fetch, because `fetch` writes into an existing run dir).
- `## Step 4. Restart at a stage (--from)` (AC-18):
  1. Run `preflight.md` `## Restart checks (--from)`. A missing run dir with `from = spec_analysis` → Step 3. The other failures stop there.
  2. `state.sh current set <n>`.
  3. Add `state.sh set auto true` when `--auto` was given. Without `--auto`, the run keeps its recorded value.
  4. If the current branch is not `state.branch`: `git switch <branch>`.
  5. For `spec_analysis`: `gh-issue.sh fetch` (failures and the closed check as in 3.3 and 3.4, but `current` was just set, so clear it again), `state.sh set title` (3.5), and 3.7 only when `state.branch` is null.
  6. `qa_test_plan` and `plan` both go to `## Stage: plan`.
  7. Enter `## Stage: <from>` at step 1 with the note `--from`.
  - Earlier stages are not redone, counters are kept, and a `done` run's PR is updated rather than re-created (`state.pr`).
- Stage sections. Each has these steps: 1 Entry (`state.sh stage <stage> --note "<why>"`, where the note is `--from`, `resume`, or the reason given by the step that sent you here, and may be left out on plain forward flow; then `gh-labels.sh stage <n> <label>`); 2 Check required files (`dispatch.md` `## Required inputs per stage`; a missing file goes to the blocked path, naming it); 3 Dispatch (row id); 4 Return check (`dispatch.md`); 5 Exit; 6 Failure (`routing.md` row). Keep each section to about 8–16 lines:
  - `## Stage: spec_analysis`: label `analysing`, D1. `ok` → `gates.md` `## Recording a spec revision` → `## Stage: brief`. `needs_input` → `gates.md` `## Gate: spec`.
  - `## Stage: brief`: label `planning`, D3. `ok` → `## Stage: standards`, except after a non-material `spec-ambiguity` answer, which goes to `## Stage: qa`. The exit decides this from `history` (I-11), not from session memory, so a resumed brief takes the same exit: the I-11 non-material check (write the command verbatim, with real `|`) prints `yes` → `## Stage: qa`, `no` → `## Stage: standards`.
  - `## Stage: standards`: label `planning`, D5. `ok` → `pr.md` `## Standards commit` → `## Stage: plan`.
  - `## Stage: qa_test_plan`: the two-line redirect (I-2).
  - `## Stage: plan` (AC-7):
    - label `planning`;
    - **send D6 and D7 as two Agent calls in ONE assistant message**, with no other tool call in it, and do not wait for one before sending the other;
    - when this stage was entered with `notes` (a plan-gate change request, or a developer `blocked`), dispatch only D7 with `notes:`, because QA phase A is not re-run;
    - check both returns; if one failed, retry only that one, on its own;
    - plan `needs_input` → `## Gate: plan-challenge`;
    - both `ok` → `## Gate: plan-approval` when `auto` is false and the plan gate is `on`, otherwise → `## Stage: develop`.
  - `## Stage: develop`: label `building`, with PD-5's mode choice: D10 (`fix_from: 07-review-<review_cycle>.md`) when `review_cycle ≥ 1` and `test .aew/runs/<id>/07-review-<review_cycle>.md -nt .aew/runs/<id>/05-plan.md` succeeds, otherwise D8. The Entry write is the state write the developer gate needs, so dispatch straight after it. Return check includes every named `06-dev-report*.md` (`dispatch.md`, CTO-3b). `ok` → `## Stage: review`. `blocked` → `routing.md` `## Developer blocked`.
  - `## Stage: review`: label `building`, D9 with `n = review_cycle + 1`. The verdict is the first word of SUMMARY: `approve` → `## Stage: qa`; `changes_required` → `routing.md` `## Review loop`; any other word → invalid return.
  - `## Stage: qa`: label `testing`, D12 with `n = fix_cycle + 1` (plus `triage:` only when sent by the QA loop). `ok` → `## Stage: docs`. `failed` → `routing.md` `## QA loop` (the complete-failure test decides between routing and retrying).
  - `## Stage: docs`: label `documenting`, D13. `ok` → `pr.md` `## Docs and memory commits` → `## Stage: pr`.
  - `## Stage: pr`: Entry `state.sh stage pr` only (the `ready-for-review` label is set once the PR exists). Then `pr.md` `## Push and pull request`, `## Manual tests`, `## Retro`, `## Finish` → `## Final report`.
- `## Gate pending` (AC-10): reached when a gate's Ask step gets no answer (AskUserQuestion is not among your tools, as in every headless run started with `--permission-prompts none`; or the question is refused; or the answer is empty). Do not try to call a tool you do not have. State and label are already set. Print `aew ship #<n>: waiting at the <gate-id> gate.`, then the questions with their recommended answers (or the plan summary and the `05-plan.md` path), then `Answer with /aew:resume <id>` (verbatim). Stop: nothing after the gate runs.
- `## Blocked path` (AC-15), in this order:
  1. `mktemp -t aew-blocked` (outside the run dir; Assumption 20).
  2. Write the comment with `cat > <tmpfile> <<'EOF'`. The body: heading `## aew run <id> blocked`, then bullets for stage, reason (the agent SUMMARY or the script error), cycles (`review <review_cycle>/<max_review_cycles>, fix <fix_cycle>/<max_fix_cycles>`) and the artefact names from `ls .aew/runs/<id>` ("in the run dir, not on GitHub"), then the line ``Resume with `/aew:resume <id>`.``
  3. `gh-issue.sh comment <n> <tmpfile>`.
  4. `gh-labels.sh stage <n> blocked`.
  5. `state.sh status blocked --note "<reason, one line>"`.
  6. Keep `current`.
  7. `## Final report`, then stop.
  - A failed `gh` call in steps 3 or 4 never skips step 5. The final report names the call that failed.
- `## Final report`: follow `final-report.md` for every outcome (`done`, `blocked`, `failed`).

**Step 3: GREEN.**

```sh
f=skills/ship/SKILL.md
sed -n '1,6p' "$f"                                                   # exactly the I-1 frontmatter
grep -cx 'name: ship' "$f"                                           # 1
grep -cx 'disable-model-invocation: true' "$f"                       # 1
grep -cxF 'argument-hint: "<issue> [--auto] [--from <stage>]"' "$f"  # 1
grep -c '^allowed-tools:' "$f"                                       # 0
wc -l < "$f"                                                         # 330–499
grep -c '!`' "$f"                                                    # 0
grep -cE '\$[0-9]|\$ARGUMENTS\[' "$f"                                # 0
grep -o '\$ARGUMENTS' "$f" | wc -l                                   # 1
for h in '# aew ship' '## Plugin root' '## Rules' '## Run variables' '## What the orchestrator reads' '## References' '## Step 1. Parse the arguments' '## Step 2. Preflight' '## Step 3. Start the run' '## Step 4. Restart at a stage (--from)' '## Gate pending' '## Blocked path' '## Final report'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done
# every line ends in =1
for s in spec_analysis brief standards qa_test_plan plan develop review qa docs pr; do printf '%s=%s\n' "$s" "$(grep -cx "## Stage: $s" "$f")"; done
# every line ends in =1
grep -n '^## ' "$f" | cut -d: -f2-                                   # the I-2 list, in that order
for m in 'aew ship: missing issue number.' 'must be a positive integer' '/aew:ship-milestone' 'unknown option' 'given more than once' 'unexpected argument' '--from needs a stage' 'unknown stage' 'spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr' 'Usage: /aew:ship <issue> [--auto] [--from <stage>]' 'Answer with /aew:resume <id>'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' "$f"                    # no output
grep -cF 'spec-ambiguity: non-material' "$f"                         # >= 1 (brief exit, I-11)
grep -cF -- '-nt .aew/runs/<id>/05-plan.md' "$f"                        # >= 1 (develop mode, PD-5)
for s in 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8; do printf '%s=%s\n' "$s" "$(grep -c "^- $s " "$f")"; done   # each =1 (sub-step bullets)
claude plugin validate .                                             # passes as before
```

The reference links resolve only after wave 2; B8 checks them.

**Step 4: commit.**

```
feat(ship): add the ship orchestrator procedure

skills/ship/SKILL.md drives one issue through the DESIGN 7.3 stages on
the main thread: argument parsing with clear errors before any write,
preflight, run start (state before fetch, C4) and --from restarts, one
section per stage with entry, dispatch, exit and failure steps, the
gate-pending stop, the blocked path and the final report. Detail lives
in references/, linked by absolute plugin-root paths so resume and
prompt can read them with Read.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B2 — `references/preflight.md`

- **id:** B2
- **files:** `skills/ship/references/preflight.md` (new)
- **depends_on:** [B1]
- **pattern:** DESIGN §9 "Preflight" (the order) and the check, command and message style of `skills/ui-qa/SKILL.md` §3.
- **ACs:** AC-3 (with cut 7 applied to item 4), AC-18 (restart checks), Assumptions 9, 11 and 12, PD-2, PD-10
- **Size:** about 90–130 lines.

**Step 1: RED.** `test -f skills/ship/references/preflight.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings. Open with: "Run the checks in order; the first failure stops with its message. Preflight writes nothing: no state, label, branch, commit or `gh` write. (`git fetch` only updates remote-tracking refs.)" Then:

- `## Check 1. Config exists`: `test -f .aew/config.json`. Stop with `No .aew/config.json in this project: run /aew:init first.`
- `## Check 2. Clean working tree`:
  - **Fresh run:** `git status --porcelain --untracked-files=all` must print nothing. Otherwise stop with `The working tree has uncommitted changes; commit or stash them, then retry:` followed by the paths. If **every** dirty path is under `.claude/agent-memory/` (memory left by an earlier run that never reached its docs commit), add the line `These are aew agent memory files from an earlier run: commit them (git add -- .claude/agent-memory && git commit -m "chore(aew): update agent memory"), then retry.` (PD-2). Committing keeps the memory, while stashing would hide it from the agents.
  - **Restart form (`--from`, and `resume`):** `git status --porcelain --untracked-files=all` (verbatim), ignoring lines whose path starts with `.claude/agent-memory/` (PD-2: memory written earlier in this run, committed at the docs stage). The flag is required: without it a wholly untracked `.claude/` collapses to `?? .claude/` and the filter never matches (verified while reviewing).
  - Note: `.aew/runs/` is gitignored by init, so the run dir never counts. If it shows up, the message adds "add `.aew/runs/` to `.gitignore` (run /aew:init)".
- `## Check 3. gh is authenticated`: `gh auth status` (exact; read-only; the only direct `gh` call, a recorded deviation, Assumption 9). Non-zero → stop with `gh is not authenticated: run gh auth login, then retry.`
- `## Check 4. Default branch up to date` (cut 7, PD-10):
  1. `<default>` comes from config.
  2. `git rev-parse --verify --quiet refs/heads/<default>`. Missing → stop with `The default branch <default> does not exist locally: run git switch <default>, then retry.`
  3. `git fetch origin <default>`. Failure → stop with `Could not fetch origin/<default>: <stderr>.`
  4. `git rev-list --left-right --count <default>...origin/<default>` prints `<ahead> <behind>`. If behind > 0 (only behind, or diverged), stop with `<default> is behind origin/<default> by <behind> commit(s)<, and ahead by <ahead>>: run git switch <default> && git pull --ff-only (or reconcile the divergence), then retry.` If ahead only, warn `<default> has <ahead> unpushed commit(s); the PR will include them.` and continue.
- `## Check 5. No other active run` (Assumption 11):
  - Read `cat .aew/runs/current`; a missing or empty file passes.
  - Otherwise `jq -r .status .aew/runs/<cur>/state.json`.
  - Pass when the status is `done` or `failed`, or when `<cur>` is this issue and the call is `--from` or `resume`.
  - `<cur>` is another run and active (`running`, `blocked`, `awaiting_input`, `awaiting_plan_approval`) → stop with `Run <cur> is active (<status>): finish it with /aew:resume <cur>, or check it with /aew:status <cur>.`
  - `<cur>` is this issue without `--from` → stop with `Run <n> is active (<status>): continue it with /aew:resume <n>, or restart a stage with /aew:ship <n> --from <stage>.`
- `## Check 6. superpowers major version (warn only)` (Assumption 12, V-6):
  - One sentence: superpowers cannot be range-pinned (DESIGN §4), so this is the early warning.
  - The constant: **`Built against superpowers major: 7`** (verbatim line; the one place it is recorded).
  - Command (verbatim): `claude plugin list --json | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version'`.
  - Outcomes:
    - empty output or a non-zero exit → warn `Could not check the installed superpowers version.`;
    - the value matches `^[0-9]+\.` and its major is not 7 → warn `superpowers <value> is installed; aew is built against 7.x. Check the superpowers release notes before relying on this run.`;
    - the value is not semver (for example a 12-character commit SHA) → warn `The installed superpowers version "<value>" is not a release number, so it could not be compared with 7.x.`;
    - a 7.x value → no output.
  - Never stop.
- `## Restart checks (--from)` (AC-18; read-only):
  1. `test -f .aew/runs/<n>/state.json`. If it is missing, `spec_analysis` → back to `SKILL.md` Step 3 (fresh start). Any other stage → stop with `No run <n> to restart: start it with /aew:ship <n>.`
  2. `jq -r .branch .aew/runs/<n>/state.json`: null with a stage other than `spec_analysis` → stop with `Run <n> has no branch yet: restart it with /aew:ship <n> --from spec_analysis.`
  3. The stage's required inputs (`dispatch.md` `## Required inputs per stage`), each `test -f`. Missing → stop with `Cannot restart run <n> at <stage>: missing <files>.`
  - The writes (`current set`, `set auto`, `git switch`) are in `SKILL.md` Step 4, not here.

**Step 3: GREEN.**

```sh
f=skills/ship/references/preflight.md
for h in '## Check 1. Config exists' '## Check 2. Clean working tree' '## Check 3. gh is authenticated' '## Check 4. Default branch up to date' '## Check 5. No other active run' '## Check 6. superpowers major version (warn only)' '## Restart checks (--from)'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -cF 'Built against superpowers major: 7' "$f"                                          # 1
grep -cF "claude plugin list --json | jq -r '.[] | select(.id == \"superpowers@claude-plugins-official\") | .version'" "$f"   # 1
grep -cF 'gh auth status' "$f"                                                              # >= 1
grep -cE 'git (merge|pull) --ff-only' "$f"                                                  # 1 (the hint text only, inside the stop message)
grep -cF '.claude/agent-memory/' "$f"                                                       # >= 1
grep -cF -- 'git status --porcelain --untracked-files=all' "$f"                              # >= 1 (restart form)
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked)' "$f"   # 0
claude plugin list --json | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version'   # 7.0.0 on this machine (the command works)
```

**Step 4: commit.**

```
feat(ship): add the preflight reference

Six checks in DESIGN 9 order: config, clean tree (agent memory ignored on
restarts), gh auth, default branch up to date (fetch and stop when behind
or diverged, never fast-forward), no other active run, and a warn-only
superpowers major-version check that handles semver, commit SHAs and an
unreadable plugin list. Plus the read-only --from restart checks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B3 — `references/dispatch.md`

- **id:** B3
- **files:** `skills/ship/references/dispatch.md` (new)
- **depends_on:** [B1]
- **pattern:** the agents' Inputs and Return contract sections (field names copied exactly) and `valid_return_block` in `scripts/hooks/gate-subagent.sh` (restated as a rule, not copied as code).
- **ACs:** AC-5, AC-6 (including CTO-3b), AC-7 (the mechanics), PD-7
- **Size:** about 90–120 lines.

**Step 1: RED.** `test -f skills/ship/references/dispatch.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## How to dispatch`:
  - The Agent tool, `subagent_type` = the row's `aew:<agent>` (V-3), `description` = `<stage> <id>`.
  - The prompt is `key: value` lines only, one per field, in the row's order, with nothing else (no prose, no artefact content). `answers:` is followed by its `Q<k>:` lines (I-10).
  - `run_dir` is `.aew/runs/<id>`.
  - One agent per call. The single exception is D6 ∥ D7: two Agent calls in one assistant message, with no other tool call in it (V-3; concurrency is not guaranteed and sequential execution is still correct).
  - Example block (verbatim):
    ```
    run_dir: .aew/runs/201
    mode: review
    n: 1
    base: main
    ```
- `## Dispatch table`: exactly the I-4 table (header verbatim, rows D1–D13), followed by one note per field taken from the agent files. `spec_version` is always `spec_revision + 1`. `n` for D10 and D11 is the cycle number `k` given by the step that dispatches. `triage` is a run-dir path. `base` is `state.base_branch`. `notes` is one line (I-10).
- `## Required inputs per stage` (used by Stage step 2, `--from` and resume; table `| Stage | Required files in <rd> |`, **ten rows, one per stage, each row starting with the backticked stage name**):
  - `spec_analysis`: `issue.json`, `00-issue-original.md` (after the fetch);
  - `brief`: `spec-final.md`, `issue.json`;
  - `standards`: `02-brief.md`;
  - `qa_test_plan`: `02-brief.md`, `03-standards.md` (the same step as `plan`);
  - `plan`: `02-brief.md`, `03-standards.md`;
  - `develop`: `02-brief.md`, `03-standards.md`, `05-plan.md`, plus `07-review-<review_cycle>.md` in fix mode (PD-5);
  - `review`: `02-brief.md`, `03-standards.md`, `05-plan.md`, at least one `06-dev-report*.md`;
  - `qa`: `02-brief.md`, `04-qa-test-plan.md`;
  - `docs`: `spec-final.md`, `issue.json`, and an `08-qa-report-<n>.md` whose return block reads `STATUS: ok`;
  - `pr`: `pr-body.md`, `10-summary.md`.
- `## Return check` (AC-6, PD-7):
  1. The last four non-blank lines of the Agent result must be, in order, `STATUS: <ok|needs_input|blocked|failed>`, `ARTEFACTS: <non-empty>`, `SUMMARY: <non-empty>`, `NEXT: <non-empty>`. This is `valid_return_block`'s rule (`${CLAUDE_PLUGIN_ROOT}/scripts/hooks/gate-subagent.sh`). The template form `STATUS: ok | needs_input | blocked | failed` is invalid.
  2. Every comma-separated ARTEFACTS path must pass `test -f` (paths are relative to the project root, or absolute for a sub-developer's report).
  3. **Developer:** for **each** `06-dev-report.md` or `06-dev-report-WP<n>.md` named in ARTEFACTS, `awk 'NF' <file> | tail -n 4` must pass rule 1. One sentence explains why: in fan-out the gate hook can pass a sibling's report (CTO-3b).
  4. If any of these fails, the return counts as `failed` (→ `## Retries`). Do not open the artefact to "fix" it.
  5. Then route on STATUS through `routing.md`. The SUMMARY and NEXT text are the only parts of the result the orchestrator uses.
- `## Retries`:
  - A `failed` return (or an invalid one) → re-send the **same** dispatch once. A second failure → `SKILL.md` `## Blocked path`, with the reason taken from the last SUMMARY.
  - Counted in this session only (Assumption 15), so a resumed run starts with a fresh allowance.
  - Exception: a QA phase B `failed` that passes the complete-failure test is not retried (`routing.md` `## QA loop`).
  - In the planning pair, retry only the agent that failed, on its own.

**Step 3: GREEN.**

```sh
f=skills/ship/references/dispatch.md
for h in '## How to dispatch' '## Dispatch table' '## Required inputs per stage' '## Return check' '## Retries'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -cxF '| Row | Agent and mode | subagent_type | Prompt fields | Required files | State write before |' "$f"   # 1
for r in D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12 D13; do printf '%s=%s\n' "$r" "$(grep -c "^| $r |" "$f")"; done   # each =1
grep -oE 'aew:[a-z-]+' "$f" | sort -u                                  # exactly the 7 agents
for a in $(grep -oE 'aew:[a-z-]+' "$f" | sort -u | sed 's/^aew://'); do test -f "agents/$a.md" || echo "MISSING $a"; done   # no output
for s in spec_analysis brief standards qa_test_plan plan develop review qa docs pr; do printf '%s=%s\n' "$s" "$(grep -c "^| \`$s\` |" "$f")"; done   # each =1 (the required-inputs table)
grep -cF "awk 'NF'" "$f"                                               # >= 1
grep -cF 'tail -n 4' "$f"                                              # >= 1
grep -c 'CTO-3b' "$f"                                                  # >= 1
```

**Step 4: commit.**

```
feat(ship): add the dispatch reference

One row per agent and mode (D1-D13) with the exact key: value prompt
fields from the agents' Inputs, the files checked with test -f before
dispatching, and the state write that precedes each dispatch; required
inputs per stage for --from and resume; the return check, including a
per-report block check for every developer report named in ARTEFACTS
(CTO-3b); and the retry-once rule.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B4 — `references/gates.md`

- **id:** B4
- **files:** `skills/ship/references/gates.md` (new)
- **depends_on:** [B1]
- **pattern:** `skills/run-protocol/references/state-machine.md` "Gates" table; `skills/github-ops/SKILL.md` "Spec-revision recording order" (copied as steps); `templates/artefacts/spec-revision-comment.md` (reproduced by the render).
- **ACs:** AC-8, AC-9, AC-10, AC-13 (the gate halves of `spec_ambiguity` and triage `needs_input`), AC-14 as amended by cut 8, PD-1, PD-4, PD-8, PD-11, PD-12
- **Size:** about 150–200 lines.

**Step 1: RED.** `test -f skills/ship/references/gates.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Gate ids and pending state`: the I-5 table (verbatim formats), the pending lookup command, the prompt-mode sentence (verbatim), and the I-11 prompt-mode check command (verbatim, with real `|`; "prompt mode" in this file means that check prints `prompt`, i.e. the `prompt` marker is present **and** `branch` is null). One line: the four `awaiting_input` gates never skip, even with `--auto`. Only `plan-approval` is skippable (auto, or the plan gate `off`).
- `## Asking` (AC-8, V-4):
  - AskUserQuestion exists on the main thread only; subagents never have it, which is why agents return `needs_input`. If it is not among your tools, go straight to `SKILL.md` `## Gate pending` and do not call it.
  - One question per source question. The **recommended answer is the first option, and its label ends with ` (recommended)`**. The other options are the listed alternatives. The tool adds free-text "Other" itself.
  - If the tool's schema caps questions per call or options per question, split into several calls in question order. Never drop a question or the recommended option; keep the extra alternatives in the question text.
  - The answer is the chosen label without ` (recommended)`, or the free text.
  - A refusal or an empty answer → `## Gate pending`.
- `## Gate: spec` (from `spec_analysis` `needs_input`):
  1. Set pending: `state.sh status awaiting_input --note "gate:spec 01-spec-analysis.md"`, then `gh-labels.sh stage <n> awaiting-input` (skipped in prompt mode).
  2. Read: `awk '/^## Questions$/{f=1;next} /^## |^STATUS:/{f=0} f' <rd>/01-spec-analysis.md`. Each `### Q<k>. <question>` gives the question, `**Recommended answer:**` the first option, and `**Alternatives:**` (split on `;`) the rest.
  3. Ask.
  4. Apply the answer: `state.sh stage spec_analysis --note "answers: gate:spec"`, `gh-labels.sh stage <n> analysing` (skipped in prompt mode), then D2 with `answers:` (`Q<k>: <answer>` lines). Then run the I-11 prompt-mode check. `prompt` → return to the `prompt` skill's own step after its spec-analyser dispatch, because ship's spec_analysis exit goes on to D3, which prompt must not run. `ship` → `SKILL.md` `## Stage: spec_analysis` step 4 (return check). spec-analyser may return `needs_input` again for an unclear answer, which loops back here.
- `## Gate: plan-challenge` (AC-14 per **cut 8, one rule**):
  1. Set pending: `state.sh status awaiting_input --note "gate:plan-challenge 05-plan.md"`, then `gh-labels.sh stage <n> awaiting-input`.
  2. Read: `awk '/^## Challenges to the spec$/{f=1;next} /^## /{f=0} f' <rd>/05-plan.md`. Take each material challenge's question, its recommended answer and its alternatives.
  3. Ask.
  4. Apply: every answer (accept, other, or decline) goes the same way. `state.sh stage spec_analysis --note "answers: gate:plan-challenge"`, label `analysing`, then D2 with PD-4 answers (`Q<k>: <question> => <answer>`, k after `grep -c '^### Q[0-9]' <rd>/01-spec-analysis.md`). On `ok`, `## Recording a spec revision`, then `SKILL.md` `## Stage: brief`, which re-runs brief, standards, QA phase A ∥ plan and the plan gate. One line notes that the counters are kept.
- `## Gate: triage` (triage `needs_input`):
  1. Set pending: `state.sh status awaiting_input --note "gate:triage 09-triage-<k>.md"` (`<k>` = the cycle), then `gh-labels.sh stage <n> awaiting-input`.
  2. Read: `awk '/^## (Root cause|Where the divergence started)$/{f=1;print;next} /^## /{f=0} f' <rd>/09-triage-<k>.md` (PD-12). The question and the senior engineer's recommended answer are in that text or in the triage return's SUMMARY (already in context; the agent file does not fix where it goes), so use both.
  3. Ask.
  4. Apply: as plan-challenge step 4 (the change is material by definition), with the note `answers: gate:triage`, then `## Stage: brief`.
- `## Gate: spec-ambiguity` (AC-13, Assumption 18):
  1. Set pending: `state.sh status awaiting_input --note "gate:spec-ambiguity 08-qa-report-<k>.md"`, then `gh-labels.sh stage <n> awaiting-input`.
  2. Read the triage rows (the `routing.md` command), then each `spec_ambiguity` entry: `awk -v h='### <TC>:' 'index($0,h)==1{f=1;print;next} /^### |^## |^STATUS:/{f=0} f' <rd>/08-qa-report-<k>.md`.
  3. Ask one question per TC, `<TC>: the spec is ambiguous - <summary>. Which behaviour is intended?`, with the options `<Expected> (recommended)` and `<Actual>`. The recommendation follows the test, which was written from the brief.
  4. Apply: note `answers: gate:spec-ambiguity`, D2 with PD-4 answers, then recording. Then decide with `jq '[.changes[] | select(.type == "material")] | length' <rd>/spec-changes.json`: greater than 0 → `## Stage: brief` (every stage from brief re-runs); 0 → `## Stage: brief`, entered with the note `spec-ambiguity: non-material` (verbatim, I-11). That note is the persisted "continue at `## Stage: qa` after the brief" decision, so it survives a resume (`SKILL.md` brief exit).
- `## Gate: plan-approval` (AC-9):
  1. Set pending: `state.sh status awaiting_plan_approval --note "gate:plan-approval 05-plan.md"`, then `gh-labels.sh stage <n> awaiting-approval`.
  2. Read `05-plan.md` in full (the only full read).
  3. Write a summary of **25 lines or fewer**: the headline approach, the work packages (which run in parallel), the challenges resolved, the risks, and whether every AC is mapped. Then the path `.aew/runs/<id>/05-plan.md`. Ask one question, `Approve the plan for #<n>?`, with the options `Approve`, `Request changes`, `Stop`. Free text counts as request changes, with the text as the notes. `Request changes` without text → one follow-up question asking for the notes (answered through "Other"). If nothing comes back, the gate stays pending.
  4. Apply:
     - Approve → `SKILL.md` `## Stage: develop`.
     - Request changes → `SKILL.md` `## Stage: plan` with `notes:` (the note `plan revision: request changes`; D7 only; QA phase A is not re-run), then this gate again.
     - Stop → `state.sh status failed --note "stopped at the plan gate"`, `state.sh current clear`, `SKILL.md` `## Final report` (outcome `failed`; PD-11 label note).
- `## Recording a spec revision` (AC-8, PD-8; the `github-ops` order). It runs when `jq '.changes | length' <rd>/spec-changes.json` is greater than 0 **and** `jq '.version' …` is greater than `state.sh get spec_revision`; otherwise skip it. Steps, with `<N>` = that version:
  1. The render (**verbatim**; dry-run against `templates/artefacts/spec-changes.example.json` while planning gave the template's heading, paragraph and three rows):
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
  - A refusal (malformed markers, or a body over 65,536 characters) → blocked path. Never trim the history.
- `## Re-asking a pending gate` (for `resume`): run the I-5 lookup command, then map the gate id to its `## Gate: <id>` and enter it at **step 2**. A status of `awaiting_plan_approval` with no `gate:` note means `plan-approval`. A status of `awaiting_input` with no note is treated as `spec`. Before re-asking, run the I-11 prompt-mode check. On a prompt-mode run only `gate:spec` can be pending: re-ask it under the prompt-mode rule, and step 4 hands back to the `prompt` skill.
- `## Destructive operations`: ship runs none (no force-push, reset, branch deletion or history rewrite). If a step would need one, ask confirm or cancel with AskUserQuestion. No answer means cancel, which goes to the blocked path. This gate is never skipped.

**Step 3: GREEN.**

```sh
f=skills/ship/references/gates.md
for h in '## Gate ids and pending state' '## Asking' '## Gate: spec' '## Gate: plan-challenge' '## Gate: triage' '## Gate: spec-ambiguity' '## Gate: plan-approval' '## Recording a spec revision' '## Re-asking a pending gate' '## Destructive operations'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
for g in spec plan-challenge triage spec-ambiguity plan-approval; do printf '%s=%s\n' "$g" "$(grep -cF "gate:$g " "$f")"; done   # each >= 1
grep -cF '(recommended)' "$f"                                           # >= 1
grep -cF 'In prompt mode (`/aew:prompt`), skip every `gh-labels.sh stage` call in this file and keep the `gh-labels.sh flag` call.' "$f"   # 1
grep -cF "[.history[] | select((.note // \"\") | startswith(\"gate:\"))] | last | .note" "$f"   # 1
grep -cF '25 lines or fewer' "$f"                                       # >= 1
grep -cF 'spec-ambiguity: non-material' "$f"                            # >= 1 (I-11)
grep -cF 'select(.note == "prompt")' "$f"                               # >= 1 (I-11)
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
```

Render check: copy the `jq` program from the written `gates.md` (not from this plan) and run it by hand, with `templates/artefacts/spec-changes.example.json` as input and no redirect. Expected: `## Spec revision v2`, a blank line, the template's paragraph, the header row, the separator and three rows. The third row ends `| material | Changes user-visible behaviour and adds a privacy-relevant step. | confirmed by James |`. Paste the output into the task report.

**Step 4: commit.**

```
feat(ship): add the gates reference

Five gates with fixed ids and a gate:<id> history note as the pending
state, so resume can re-ask them: the material spec change gate, plan
challenges (one rule, cut 8: finalise the spec and re-run from brief),
triage and spec-ambiguity questions, and plan approval with a summary of
25 lines or fewer. AskUserQuestion on the main thread only, recommended
answer first; no tool or no answer leaves the gate pending. The spec
revision is recorded in the github-ops order with a jq render, so the
JSON never enters context.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B5 — `references/routing.md`

- **id:** B5
- **files:** `skills/ship/references/routing.md` (new)
- **depends_on:** [B1]
- **pattern:** `skills/run-protocol/references/state-machine.md` "Failure paths", "Counters" and the `qa_failures_complete` snippet (restated as two commands); the agents' Return contract sections for each status.
- **ACs:** AC-11, AC-12, AC-13, AC-15 (when to take the blocked path), AC-20, PD-3, PD-5, PD-9
- **Size:** about 110–150 lines.

**Step 1: RED.** `test -f skills/ship/references/routing.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Stage table` (AC-20, I-6 format). The rows to write (cells condensed; no `|` inside a cell):

  | Stage | Entry | Exit | Failure |
  |---|---|---|---|
  | `spec_analysis` | `state.sh stage spec_analysis` (fresh run: Step 3); label `analysing`; D1, or D2 after a gate | `ok` → record the revision → `brief` | `needs_input` → gate `spec`; `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `brief` | `state.sh stage brief`; label `planning`; D3 | `ok` → `standards` (→ `qa` after a non-material spec-ambiguity answer) | `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `standards` | `state.sh stage standards`; label `planning`; D5 | `ok` → standards commit → `plan` | as `brief` |
  | `qa_test_plan` | as `plan` (one step) | as `plan` | as `plan` |
  | `plan` | `state.sh stage plan`; label `planning`; D6 ∥ D7 in one message (D7 alone with `notes`) | both `ok` → gate `plan-approval`, or `develop` when auto or the gate is off | plan `needs_input` → gate `plan-challenge`; `failed` → retry only that agent, then blocked path; `blocked` → blocked path |
  | `develop` | `state.sh stage develop`; label `building`; D10 from `07-review-<review_cycle>.md` when `review_cycle` is at least 1 and that review is newer than `05-plan.md` (`test -nt`), else D8 | `ok` with every named report valid → `review` | full-mode `blocked` → Developer blocked; fix-mode `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `review` | `state.sh stage review`; label `building`; D9 with n = review_cycle + 1 | `approve` → `qa` | `changes_required` → Review loop (limit → blocked path); `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `qa` | `state.sh stage qa`; label `testing`; D12 with n = fix_cycle + 1 | `ok` → `docs` | complete failure → QA loop (limit → blocked path); other `failed` → retry once, then blocked path; `blocked` → blocked path |
  | `docs` | `state.sh stage docs`; label `documenting`; D13 | `ok` → docs and memory commits → `pr` | `blocked` → blocked path; `failed` or invalid → retry once, then blocked path |
  | `pr` | `state.sh stage pr`; label set once the PR exists | push, PR, manual tests, retro → label `ready-for-review`, `done`, `current` cleared → final report | a script failure → blocked path (retro failure: warn only) |

- `## Agent status routing` (a table per status). `ok` → the stage Exit. `needs_input` → only spec-analyser, senior-engineer plan and senior-engineer triage use it, each to its gate; from any other agent it is an invalid return. `blocked` → the developer goes to `## Developer blocked`, any other agent to the blocked path. `failed` → `dispatch.md` `## Retries`, with the QA exception.
- `## Review loop` (AC-11), on `changes_required` from `07-review-<r>.md` (r = review_cycle + 1):
  - `review_cycle < max_review_cycles` → `state.sh bump review_cycle`, then `SKILL.md` `## Stage: develop` with the note `review fix <new review_cycle>`. Develop picks fix mode from the counter and the review's age (PD-5), and then the review runs again.
  - `review_cycle = max_review_cycles` → blocked path, with the reason `review cycles used up (<max>): <SUMMARY>`.
- `## Developer blocked` (AC-12, PD-3):
  - Fix mode → blocked path.
  - Full mode: `jq '[.history[] | select(.note == "developer blocked: re-plan")] | length' <rd>/state.json`. If it is ≥ 1 → blocked path. Otherwise `SKILL.md` `## Stage: plan` with the note `developer blocked: re-plan` and `notes: developer blocked: <the developer's SUMMARY> / <the dev report path from ARTEFACTS>` (I-10; D7 only), then the plan gate (unless auto or off), then develop.
- `## QA loop` (AC-13, Assumption 17). The `stage` stays `qa` throughout. On a D12 `failed`:
  1. **Complete-failure test** (state-machine.md, inline): `awk 'NF' <rd>/08-qa-report-<k>.md | tail -n 4` is a valid block with `STATUS: failed`, **and** `awk '/^## /{f=($0=="## Failures")} f && /^\|[[:space:]]*TC-[0-9]+[[:space:]]*\|/{n++} END{print n+0}' <rd>/08-qa-report-<k>.md` prints ≥ 1. Not both → an ordinary `failed` (retry once, then blocked path). Here `k` = fix_cycle + 1, the report just written.
  2. **Triage rows** (verbatim; the only read of the report): `awk -F'|' '/^## /{f=($0=="## Failures")} f && $2 ~ /^[[:space:]]*TC-[0-9]+[[:space:]]*$/ {gsub(/[[:space:]]/,"",$2); gsub(/[[:space:]]/,"",$4); print $2, $4}' <rd>/08-qa-report-<k>.md` prints `TC-<n> <class>` lines. (The command was dry-run while planning.)
  3. **Limit:** `fix_cycle = max_fix_cycles` → blocked path, with the reason `fix cycles used up (<max>): <SUMMARY>`.
  4. `state.sh bump fix_cycle`; the number it prints is the new fix_cycle, `k`, which equals the failing report's number (no shell variable, I-8).
  5. **Route one class per cycle, the first match wins:**
     - a. any `spec_ambiguity` → `gates.md` `## Gate: spec-ambiguity`.
     - b. any `plan_divergence` or `test_bug`, **or** an `impl_bug` whose TC was also `impl_bug` in the triage rows of `08-qa-report-<k-1>.md` (it has already had one developer fix) → D11 with `n: k`. On its return: `needs_input` → `gates.md` `## Gate: triage`. `ok` → read NEXT. If NEXT names the developer: `state.sh stage qa --note "fix <k>: developer (triage)"`, then D10 with `fix_from: 09-triage-<k>.md` and `n: k`. Then (or straight away, when NEXT names only qa-engineer) D12 with `n: k+1` and `triage: .aew/runs/<id>/09-triage-<k>.md`.
     - c. otherwise (`impl_bug` only) → `state.sh stage qa --note "fix <k>: developer"`, then D10 with `fix_from: 08-qa-report-<k>.md` and `n: k`, then D12 with `n: k+1`.
  6. The developer's return inside the loop: `ok` → D12. `blocked` → blocked path (fix mode, PD-3). `failed` → retry once, then blocked path.
  7. Repeat from step 1 with the new report. A D12 `ok` → `## Stage: docs`.
- `## Cycle limits`: the two `jq` reads with the schema defaults (`max_review_cycles` 2, `max_fix_cycles` 3); the counters (`07-review-<review_cycle+1>.md`, `08-qa-report-<fix_cycle+1>.md`, `09-triage-<same n>.md`); and one line saying the counters are never reset (not by `--from`, a gate re-run or resume).
- `## Script failures` (PD-9): the rule, the three exceptions, and the reason format `<script> <subcommand> failed: <first stderr line>`.

**Step 3: GREEN.**

```sh
f=skills/ship/references/routing.md
for h in '## Stage table' '## Agent status routing' '## Review loop' '## Developer blocked' '## QA loop' '## Cycle limits' '## Script failures'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -cxF '| Stage | Entry | Exit | Failure |' "$f"                   # 1
for s in spec_analysis brief standards qa_test_plan plan develop review qa docs pr; do
  awk -F'|' -v s="\`$s\`" '
    $2 ~ "^[[:space:]]*" s "[[:space:]]*$" { n++; e=$3; x=$4; fl=$5; gsub(/[[:space:]]/,"",e); gsub(/[[:space:]]/,"",x); gsub(/[[:space:]]/,"",fl); if (NF==6 && e!="" && x!="" && fl!="") ok++ }
    END { printf "%s rows=%d ok=%d\n", s, n, ok }' "$f"
done
# ten lines, each "rows=1 ok=1" (NF==6 proves no stray | inside a cell).
# The loop was dry-run while planning against the Stage table above: ten lines, each rows=1 ok=1.
grep -cF "awk 'NF'" "$f"                                             # >= 1
grep -cF 'bump fix_cycle' "$f"; grep -cF 'bump review_cycle' "$f"    # >= 1 each
grep -cF 'developer blocked' "$f"                                    # >= 1
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked)' "$f"   # 0
```

**Step 4: commit.**

```
feat(ship): add the routing reference

The stage table with an entry, exit and failure path for each of the ten
schema stages, routing per agent status, the review loop up to
max_review_cycles, the developer-blocked re-plan (once per run, read
from the history), the QA loop with the complete-failure test, one
triage class per cycle and the fix-cycle limit, and the script-failure
rule.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B6 — `references/pr.md`

- **id:** B6
- **files:** `skills/ship/references/pr.md` (new)
- **depends_on:** [B1]
- **pattern:** `skills/github-ops/SKILL.md` "Operational rules" (check `state.pr`; `update --run`) and the `gh-pr.sh`, `gh-issue.sh manual-tests` and `gh-retro.sh` `--help` text.
- **ACs:** AC-16 (with Conflict C1: the orchestrator commits the doc-writer's outputs), PD-2, PD-14
- **Size:** about 70–100 lines.

**Step 1: RED.** `test -f skills/ship/references/pr.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Commit rules`:
  - conventional messages ending `(#<n>)`;
  - no trailer beyond what the user's Claude Code settings add (Assumption 28);
  - stage explicit paths only (`git add -- <paths>`), then `git commit -m "<message>"`;
  - commit only on the run branch (`git branch --show-current` equals `state.branch`);
  - skip a commit when `git status --porcelain -- <paths>` is empty.
- `## Standards commit` (after a standards `ok`): paths `docs/standards`; message `docs(standards): <add or update> <profile list> standards (#<n>)`, with the profiles taken from the standards-setter's ARTEFACTS (`docs/standards/<profile>.md`).
- `## Docs and memory commits` (after a docs `ok`):
  1. The doc-writer's ARTEFACTS paths outside `.aew/` (expected: `docs/specs/<n>-<slug>.md`, `CLAUDE.md`); message `docs: add the issue spec<, and update CLAUDE.md> (#<n>)`.
  2. Then, if `git status --porcelain -- .claude/agent-memory` is non-empty, `git add -- .claude/agent-memory` with the message `chore(aew): update agent memory (#<n>)` (PD-2).
  3. Then `git status --porcelain`. Anything left is listed as a warning in the final report, never committed.
- `## Push and pull request`:
  1. `git-branch.sh push`.
  2. `state.sh get pr` is null → `gh-pr.sh create <id> .aew/runs/<id>/pr-body.md` (it prints the number), then `state.sh set pr <number>`. Otherwise `gh-pr.sh update <pr> .aew/runs/<id>/pr-body.md --run <id>`.
  3. The PR URL for the report: `jq -r --arg pr <pr> '.url | sub("/issues/[0-9]+$"; "/pull/" + $pr)' .aew/runs/<id>/issue.json` (dry-run while planning).
  4. `gh-labels.sh stage <n> ready-for-review` comes in `## Finish`, not here.
- `## Manual tests`: `grep -c '^- \[ \]' .aew/runs/<id>/manual-tests.md` (a missing file or 0 → skip). If it is ≥ 1, `gh-issue.sh manual-tests <n> .aew/runs/<id>/manual-tests.md`, then `gh-labels.sh flag <n> add manual-test-required`.
- `## Retro`: the source repo comes from `jq -r '.url | capture("^https?://[^/]+/(?<r>[^/]+/[^/]+)/issues/").r' .aew/runs/<id>/issue.json` (dry-run: `acme/static-shop`). Then `gh-retro.sh file .aew/runs/<id>/retro.md <owner/repo> <id>`. Keep its stdout lines for the final report. A non-zero exit → warn and continue (never blocked).
- `## Finish`: `gh-labels.sh stage <n> ready-for-review`, `state.sh status done`, `state.sh current clear`, then `SKILL.md` `## Final report`.

**Step 3: GREEN.**

```sh
f=skills/ship/references/pr.md
for h in '## Commit rules' '## Standards commit' '## Docs and memory commits' '## Push and pull request' '## Manual tests' '## Retro' '## Finish'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
for c in 'git-branch.sh push' 'gh-pr.sh create' 'gh-pr.sh update' 'state.sh set pr' 'gh-issue.sh manual-tests' 'flag <n> add manual-test-required' 'gh-retro.sh file' 'stage <n> ready-for-review' 'state.sh status done' 'state.sh current clear' 'docs(standards):' 'chore(aew): update agent memory'; do printf '%s=%s\n' "$c" "$(grep -cF -- "$c" "$f")"; done   # each >= 1
grep -cE 'git add (-A|\.)( |$)' "$f"                                  # 0
grep -cF 'git push' "$f"                                              # 0 (only git-branch.sh push; the Bash guard blocks the literal)
```

**Step 4: commit.**

```
feat(ship): add the PR and finish reference

The orchestrator commits the standards docs and the doc-writer's outputs
(DESIGN 8.7 wins over the prompt, C1) plus the agents' memory, then
pushes with git-branch.sh, creates or updates the PR from state.pr, files
the manual-tests block and flag, files the retro (a failure only warns),
sets ready-for-review, marks the run done and clears current.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B7 — `references/final-report.md`

- **id:** B7
- **files:** `skills/ship/references/final-report.md` (new)
- **depends_on:** [B1]
- **pattern:** DESIGN §9 "Final report" bullets; `templates/artefacts/summary.md` (`- [x] AC-n`) and `manual-tests.md` (`- [ ] **TC-n`) for the counts.
- **ACs:** AC-17
- **Size:** about 40–60 lines.

**Step 1: RED.** `test -f skills/ship/references/final-report.md; echo $?` gives `1`.

**Step 2: write it** with the I-3 headings:

- `## Format` (verbatim block; lines in angle brackets are filled in):
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
  The `Next:` line: `done` → `review and merge the PR`; `blocked` → `Resume with /aew:resume <id>`; `failed` → `restart with /aew:ship <n> --from <stage>`. Warnings (preflight check 6, check 4's ahead-only warning, leftover dirty paths, a failed retro, a failed `gh` call on the blocked path) follow as `Warning: …` lines.
- `## Counting`. The artefacts are never read, only counted:
  - passed `grep -c '^- \[x\] AC-' .aew/runs/<id>/10-summary.md`; total `grep -cE '^- \[[ x]\] AC-' .aew/runs/<id>/10-summary.md`;
  - manual tests `grep -c '^- \[ \]' .aew/runs/<id>/manual-tests.md`;
  - retro: the number of `created #` and `commented #` lines that `gh-retro.sh` printed this session;
  - title, `pr` and the cycles from `jq -r '.title, .pr, .review_cycle, .fix_cycle' .aew/runs/<id>/state.json`, **not** `state.sh get` (it only reads the run named in `.aew/runs/current`, which `## Finish` and the plan-gate stop have already cleared; verified: `state.sh get` exits 1 with "no current run"); the limits from `SKILL.md` `## Run variables`.
  - One line: `grep -c` exits 1 when the count is 0; read the printed number, and treat a missing file as 0 (or `n/a` for the ACs).
- `## Blocked and failed runs` (AC-17): the same format. `PR:` is replaced by `Reason: <reason>` (with `PR: <url>` kept as well when `state.pr` is set). `ACs passed: n/a` when `10-summary.md` is absent. A plan-gate stop adds the PD-11 line `The awaiting-approval label stays on the issue.`

**Step 3: GREEN.**

```sh
f=skills/ship/references/final-report.md
for h in '## Format' '## Counting' '## Blocked and failed runs'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
for l in 'PR: <url>' 'ACs passed: <passed>/<total>' 'Review cycles: <review_cycle>/<max_review_cycles>' 'Fix cycles: <fix_cycle>/<max_fix_cycles>' 'Manual tests outstanding: <count>' 'Retro items filed:' 'Resume with /aew:resume <id>'; do printf '%s=%s\n' "$l" "$(grep -cF -- "$l" "$f")"; done   # each >= 1
printf -- '- [x] AC-1: a (TC-1)\n- [ ] AC-2: b (TC-2)\n- [x] AC-3: c (TC-3)\n' > tests/tmp/summary-probe.md
grep -c '^- \[x\] AC-' tests/tmp/summary-probe.md; grep -cE '^- \[[ x]\] AC-' tests/tmp/summary-probe.md   # 2 then 3
rm tests/tmp/summary-probe.md
```

**Step 4: commit.**

```
feat(ship): add the final-report reference

The DESIGN 9 report for every outcome: PR link (or the reason and resume
hint), ACs passed out of the total, review and fix cycles against their
limits, manual tests outstanding and retro items filed, all counted with
grep -c rather than read.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task B8 — Cross-file consistency pass

- **id:** B8
- **files:** any of `skills/ship/SKILL.md` and `skills/ship/references/*.md`, **only** to fix a mismatch found below
- **depends_on:** [B2, B3, B4, B5, B6, B7]
- **pattern:** the I-7 name-hygiene rules. This is the same kind of check Phase E's `skills.bats` will automate, run by hand now so that Phase C reads files that agree with each other.
- **ACs:** AC-1 (links resolve), AC-19 (every read the references make is in the reads table), AC-20 (re-checked)

**Step 1: RED.** None. This is a verification task, and it starts from the wave-2 state. If every check below passes the first time, there is no commit, and the task report records the outputs.

**Step 2: run the checks and fix mismatches in place.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
# 1. Every ${CLAUDE_PLUGIN_ROOT}/ path exists, and none has a placeholder.
grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' skills/ship | sed 's/[.,]*$//' | sort -u | while read -r p; do f=${p#'${CLAUDE_PLUGIN_ROOT}/'}; [ -e "$f" ] || echo "MISSING $f"; done   # no output
grep -rnE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' skills/ship                                            # no output
# 2. Every aew:<name> is a real agent or one of the allowed slash commands (I-7).
grep -rhoE '/?aew:[a-z][a-z-]*' skills/ship | sort -u
# expected subset of: /aew:init /aew:prompt /aew:resume /aew:ship /aew:ship-milestone /aew:status aew:brief-compiler aew:developer aew:doc-writer aew:qa-engineer aew:senior-engineer aew:spec-analyser aew:standards-setter
for a in $(grep -rhoE '(^|[^/])aew:[a-z][a-z-]*' skills/ship | sed -E 's/^[^a]*aew://' | sort -u); do test -f "agents/$a.md" || echo "NOT AN AGENT $a"; done   # no output
# 3. No prefixed label names anywhere.
grep -rnE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' skills/ship   # no output
# 4. Every cited section exists (citation form from B1 Rules: `<file>.md` `## <heading>`).
grep -ohE '[A-Za-z-]+\.md` `## [^`]+' skills/ship/SKILL.md skills/ship/references/*.md | sed 's/` `/|/' | sort -u |
  while IFS='|' read -r file h; do
    case "$file" in SKILL.md) p=skills/ship/SKILL.md ;; *) p=skills/ship/references/$file ;; esac
    grep -qxF "$h" "$p" 2>/dev/null || echo "BROKEN $file -> $h"
  done                                                                # no output
# 5. Gate ids, dispatch rows and stage names agree across files.
for g in spec plan-challenge triage spec-ambiguity plan-approval; do printf '%s %s\n' "$g" "$(grep -rlxF "## Gate: $g" skills/ship | tr '\n' ' ')"; done   # each lists only gates.md
grep -ohE 'D[0-9]+' skills/ship/SKILL.md skills/ship/references/*.md | sort -u   # only D1–D13
for r in $(grep -ohE 'D[0-9]+' skills/ship/SKILL.md skills/ship/references/*.md | sort -u); do grep -q "^| $r |" skills/ship/references/dispatch.md || echo "UNDEFINED $r"; done   # no output
# 6. Each bounded read named in the references is a row of the SKILL.md reads table: check by eye that every awk/grep -c/jq read in gates.md, routing.md, pr.md and final-report.md has a row in "## What the orchestrator reads".
# 7. Size, frontmatter and validation.
wc -l < skills/ship/SKILL.md                                          # < 500
claude plugin validate .                                              # passes
tests/run-script-tests.sh                                             # passes, unchanged (no script touched)
git status --porcelain                                                # only skills/ship/** (if fixes were made)
```

**Step 3: GREEN.** Every check above prints its expected output.

**Step 4: commit** (only if a fix was needed):

```
fix(ship): align cross-references between the procedure and its references

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

## Cross-phase notes for Phase F (closing docs)

Two documentation mismatches that this phase's design creates, for Phase F to fix with its DESIGN, state-machine and project-map updates:

- `skills/run-protocol/references/state-machine.md` "Failure paths": the row "Agent returns `blocked`: developer → senior-engineer (plan revision)" lacks PD-3's exceptions. Only a full-mode developer `blocked` re-plans, and only once per run; a fix-mode `blocked` or a second one goes to `blocked`.
- `scripts/git-branch.sh --help` says "the base branch is updated by preflight, not here". That has been untrue since cut 7: preflight only checks and stops. Reword it to "preflight checks the base branch is up to date; nothing updates it" (a `--help` text change only; `conventions.bats` is unaffected).

## Phase exit criteria

- `skills/ship/SKILL.md` (under 500 lines) and the six references exist, with the I-2 and I-3 headings exactly.
- The B1–B8 GREEN checks pass, `claude plugin validate .` passes, and `tests/run-script-tests.sh` is unchanged and passing.
- Contracts I-1 to I-11 hold as written. If a task changed one, it updated this plan's contract section in the same commit and recorded it in the task report for the consolidator.

## Risks (this phase)

- **The procedure drifts from the model's behaviour.** A long procedure can be followed only partly. Mitigations: `SKILL.md` is short and stepwise, the references are read at the step that needs them, and Phase E's static checks plus Phase F's S1, G1, G2 and F1/R2 runs are the behavioural proof. This phase proves structure only.
- **PD-4** (answers to questions spec-analyser did not ask) and **PD-12** (the triage question source) are untested until prompt 07, because the simulations exclude these routes (spec scope).
- **The counters survive gate re-runs.** After a material change late in the run, a re-run from `brief` may meet `review_cycle` or `fix_cycle` already near its limit and block early. That is correct under the spec ("counters are kept"); recorded for prompt 07.
- **Allowlist matching** (Phase F): the commands in I-8 avoid shell variables. Two forms still need checking in P0/S1 against the explicit allowlist: the `$(jq …)` substitution in 3.5, and the `cat > <tmpfile> <<'EOF'` heredoc. If either is denied, the fallback is to pass the title as a literal argument and write the comment file with Write to a path under `$TMPDIR`.

## Approval (Phase B)

- Senior architect: APPROVED 2026-10-25T00:14:54Z (plan-review FULL, then plan-diff-review of the revision round)
- Plan format: FULL
- Plan dependency graph: valid. Waves: 3 (B1; B2 to B7 in parallel; B8). Max wave width: 6.
- Plan content hash (SHA-256, the document above this trailer): 60a6bfe4f7fc5f5ef6657971cd8985901bf6e6bcb0357b78940701961d9759c8

---

# Phase C plan — resume, status and prompt

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583…6090`), overridden where they differ by the CTO simplicity-challenge cuts (2026-10-25, all adopted). The cut that binds this phase is **1**: R1 is not simulated, so `tests/scripts/skills.bats` must be able to check statically that `resume` names the pending-gate re-ask (contract K-3).
- **Phase:** C of the EPIC. `depends_on: [B]`. This phase Reads Phase B's `skills/ship/SKILL.md` and references and enters them at the sections named in Phase B's contract I-2 to I-5 (treated as binding). Phase E's `skills.bats` greps the strings in contract K-3. Phase F's R2 run drives `resume` headless and takes its commands from K-4. Phase D's note applies: `init` keeps flat scratch files (`init-*.json`, `init-pr-body.md`) under `.aew/runs/`, so `status` lists only directories whose names are run ids.
- **Depth:** lean (pattern references and section outlines; no inline skill text beyond the verbatim contract strings)
- **ACs covered:** AC-21, AC-22, AC-23
- **Risk:** none of the risky criteria. Three Markdown skills with no runtime effect until a user types the command. `status` writes nothing.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" is the spec's assumption n, "AC-n" the spec's ACs, "cut n" the CTO cut n, `I-n`, `D<n>` and `PD-n` are Phase B's contract items, dispatch rows and plan-level decisions. This phase's own items are `K-1`–`K-5` (contract) and `PC-1`–`PC-6` (plan-level decisions). Task ids are `C1`–`C3`.

> **For agentic workers:** implement task by task. These are documentation tasks, so each task's RED is a check that fails before the change (the file is absent) and its GREEN is the same checks passing. Record both outputs in the task report. Write the skill text from the outlines below in your own words, in British English. Headings, frontmatter, error lines, notes and commands marked **verbatim** are contracts: copy them exactly. Use Phase B's citation form (`` `<file>.md` `## <heading>` ``, I-2 / B1 Rules). In this phase's files `` `SKILL.md` `` always means ship's `skills/ship/SKILL.md`, `` `preflight.md` ``, `` `dispatch.md` `` and `` `gates.md` `` mean the files under `skills/ship/references/`, and `` `prompt/SKILL.md` `` means `skills/prompt/SKILL.md`. Never write a placeholder heading in citation form (write "ship's stage section `## Stage: <stage>`", not `` `SKILL.md` `## Stage: <stage>` ``), so every citation resolves.

**Goal:** three main-thread skills. `resume` continues an interrupted run from `state.json` by reading ship's procedure with Read and entering it at the recorded stage or the pending gate. `status` is a read-only view of one run or every run. `prompt` runs ship's run start and spec gate, then the brief-compiler in prompt mode, and offers to post `prompt.md`.

**Architecture:** one `SKILL.md` per skill, no `references/` directories (each is well under 200 lines, and the procedure they reuse is ship's). `resume` and `prompt` state the plugin root in their own substituted body and Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and its references, never invoking `ship` through the Skill tool (V-1: `disable-model-invocation: true` blocks it; V-5: only the loaded body is substituted). `status` reads `state.json`, `log.md` and `.aew/config.json` with `jq`, `cat` and `tail` only. No script, hook, agent, template or ship file changes in this phase.

**Tech stack:** Markdown skill files; jq 1.7.1, zsh and bash 3.2 for the inline commands (both dry-run while planning, see C2); `claude plugin validate .`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` | `<spec-summary>`, AC-21–23, Assumptions 2, 4, 5, 11, 21, V-1, V-5 |
| CTO cuts (scratchpad `simplicity-adopted.md`) and docs facts (`docs-facts.md`) | Cut 1; facts 1 and 2 (Skill tool blocked; substitution in the body only) |
| `docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-B.md` | Interface contract I-1–I-10, PD-1, PD-2, PD-5, B1 Step 3 and Step 4 sub-steps, B2 checks, B4 `## Gate: spec` and `## Re-asking a pending gate` |
| `scripts/state.sh --help` | Every write acts on the run named in `.aew/runs/current`; `init` sets it; `get` reads only the current run (so `status` uses `jq`) |
| `templates/state.schema.json` | Run-id pattern `^([1-9][0-9]*\|m-[1-9][0-9]*)$`, the six statuses, `mode` values, `history[].note` |
| `agents/brief-compiler.md` (prompt mode) | `prompt.md` has no return block in the file; the return block is in the final message only |
| `skills/ui-qa/SKILL.md` lines 1–10 | Frontmatter style |
| `docs/superpowers/plans/phases/2026-10-24-build-agents-phase-A.md` | Format mirrored here |

Gotchas that apply: `${CLAUDE_PLUGIN_ROOT}` is not in the Bash tool's environment, so scripts are called by the substituted absolute path; `state.sh` writes need `current` to name the run first; the Bash tool runs zsh on this machine, where an unmatched glob is an error (`no matches found`) rather than the literal word; agent memory under `.claude/agent-memory/` is ignored by the restart form of ship's tree check (PD-2).

## Plan-level decisions (refinements the spec leaves open; flag if wrong)

- **PC-1 Prompt-mode marker** (Phase B I-11 marker, now fixed there; I-11 is binding). Straight after ship's sub-step 3.2 (`state.sh init`) and before the fetch (3.3), `prompt` writes `state.sh stage spec_analysis --note "prompt"` (verbatim, I-11). It doubles as D1's state write, and because it precedes the fetch, a fetch failure or closed issue still leaves a marked run (so `resume` and `status` give PC-6's hint, not ship's). Phase B's I-11 check is the marker alone (`jq '[.history[] | select(.note == "prompt")] | length'` ≥ 1); this plan keeps the stricter `branch == null` guard below, **pending reconciliation with Phase B's reviewer** (if B adopts the guard in I-11, use B's command verbatim; if B rejects it, this test drops the `branch` half). A run is a **prompt-mode run** when this jq test prints `prompt` (verbatim; used by `resume` and `status`):
  `jq -r 'if (.branch == null) and any(.history[]; .note == "prompt") then "prompt" else "ship" end' .aew/runs/<id>/state.json`
  The `branch == null` half matters: after `/aew:prompt 5`, `/aew:ship 5 --from spec_analysis` turns the run into a pipeline run (Step 4.5 creates the branch), and from then on it must resume as a ship run. Without this, an unanswered gate in prompt mode would tell James `Answer with /aew:resume <id>` (ship's `## Gate pending`) and resume would carry on into the full pipeline.
- **PC-2 Resuming a prompt-mode run.** `resume` Reads `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md` (as well as ship's files), skips the tree and branch checks (prompt commits nothing, AC-23), and enters `prompt/SKILL.md` at the section for the recorded stage, or at the re-asked spec gate under the prompt-mode rule (I-5).
- **PC-3 Prompt's stop.** An agent `blocked`/`failed` after ship's one retry, or a script failure, in prompt mode: `state.sh status blocked --note "<reason>"`, keep `current`, print the reason and `Resume with /aew:resume <n>`. No GitHub comment and no label: prompt mode sets no stage labels (AC-23, Assumption 21), and ship's `## Blocked path` would set `blocked`.
- **PC-4 Resume's own checks.** For a run it will continue, `resume` runs `preflight.md` checks 1, 3 and 5 (config, gh auth, no other active run; Check 5 already treats a resume of this run as allowed), then, for ship runs only, Check 2 in its restart form and the branch check. It skips checks 4 and 6 (the default branch no longer matters mid-run).
- **PC-5 Modes.** `resume` continues only `single` runs in this release. Any other `mode` stops with a message pointing at `/aew:ship-milestone` (prompt 06 extends resume, DESIGN §10). `status` shows every mode.
- **PC-6 Failed prompt-mode runs** (fetch failure or closed issue): `prompt` refuses an existing run dir (Assumption 21), so the hint is "remove `.aew/runs/<n>`, then run `/aew:prompt <n>` again". A finished prompt run can be built with aew via `/aew:ship <n> --from spec_analysis` (ship's restart checks allow a null branch at `spec_analysis`), and `prompt`'s finish message says so.

## Interface contract (Phase E and F rely on this)

### K-1. Frontmatter (verbatim)

```yaml
---
name: resume
description: Continue an interrupted aew run from its state.json - re-asks a pending gate, or re-enters the ship procedure at the recorded stage after checking the branch and working tree. Run it as /aew:resume [<run-id>].
disable-model-invocation: true
argument-hint: "[<run-id>]"
---
```

```yaml
---
name: status
description: Read-only view of aew runs in this project - with no argument lists every run (id, status, stage, updated, current, title); with a run id shows its state, the last 10 log lines, the review and fix cycles used, and the next action. Run it as /aew:status [<run-id>].
argument-hint: "[<run-id>]"
---
```

```yaml
---
name: prompt
description: Turn one GitHub issue into a single self-contained prompt (prompt.md) for a plain Claude Code session - spec analysis with the same material-change gate as ship, then the brief compiler in prompt mode. No branch, no commits, no stage labels. Run it as /aew:prompt <issue>.
disable-model-invocation: true
argument-hint: "<issue>"
---
```

In all three: no `allowed-tools`, no `` !`cmd` ``, no `$N` or `$ARGUMENTS[N]`, exactly one `$ARGUMENTS` (in Step 1). `status` has **no** `disable-model-invocation` (no side effects, DESIGN §5.1).

### K-2. Headings, in this order (verbatim; each exactly once)

| `skills/resume/SKILL.md` | `skills/status/SKILL.md` | `skills/prompt/SKILL.md` |
|---|---|---|
| `# aew resume` | `# aew status` | `# aew prompt` |
| `## Plugin root` | `## Rules` | `## Plugin root` |
| `## Rules` | `## Step 1. Parse the argument` | `## Rules` |
| `## Step 1. Pick the run` | `## List every run` | `## Step 1. Parse the argument` |
| `## Step 2. Read the state` | `## Show one run` | `## Step 2. Preflight` |
| `## Step 3. Finished runs` | `## Next action` | `## Step 3. Start the run` |
| `## Step 4. Checks` | | `## Step 4. Analyse the spec` |
| `## Step 5. Continue` | | `## Step 5. Compile the prompt` |
| | | `## Step 6. Finish` |
| | | `## Stopping` |

`resume` cites `` `prompt/SKILL.md` `## Step 4. Analyse the spec` `` and `` `prompt/SKILL.md` `## Step 5. Compile the prompt` `` (PC-2), which is why these two headings are contract.

### K-3. Strings Phase E's `skills.bats` greps (fixed strings; counts ≥ 1 unless stated)

- **resume** (cut 1: the static proof that resume re-asks a pending gate):
  - `` `gates.md` `## Re-asking a pending gate` `` — the pending-gate re-ask
  - `awaiting_input` and `awaiting_plan_approval` (both on the line or bullet that sends to the re-ask)
  - `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md`
  - `with the Skill tool` (in the sentence "Never invoke `ship` or `prompt` with the Skill tool: both set `disable-model-invocation: true`, which blocks it.", verbatim)
  - `Steps 1–4` (skip ship's argument parsing, preflight, run start and restart) and `## Stage: <stage>` and `the note \`resume\``
  - `` `preflight.md` `## Check 2. Clean working tree` ``, `restart form` and `git status --porcelain --untracked-files=all`
  - `state.sh current set <id>`
  - `/aew:ship <n> --from <stage>` (the failed-run hint)
  - error lines (verbatim, `<…>` filled in):
    - `aew resume: no current run. Name one: /aew:resume <run-id> (/aew:status lists the runs).`
    - `aew resume: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).`
    - `aew resume: unexpected argument "<token>".`
    - `aew resume: no run <id> (.aew/runs/<id>/state.json is missing).`
    - `aew resume: run <id> is a <mode> run; milestone runs are resumed by /aew:ship-milestone (coming in a later release).`
    - usage line `Usage: /aew:resume [<run-id>]`
- **status**:
  - absent (count 0): `^disable-model-invocation`, any of `state.sh`, `gh-issue.sh`, `gh-labels.sh`, `gh-pr.sh`, `gh-retro.sh`, `git-branch.sh`, `gh (auth|issue|pr|label|api|repo)`, `git (add|commit|switch|checkout|push|merge|rebase|reset|stash|fetch|pull|branch|status)` — status names no script and runs no git or gh command
  - the run-id pattern `^([1-9][0-9]*|m-[1-9][0-9]*)$` and the glob `.aew/runs/*/state.json`
  - `tail -n 10`, `max_review_cycles // 2`, `max_fix_cycles // 3`
  - the I-5 pending-gate lookup command (verbatim from Phase B)
  - the `## Next action` table: one row per status, each starting `` | `<status>` | `` for `running`, `awaiting_input`, `awaiting_plan_approval`, `blocked`, `done`, `failed`
  - lines (verbatim): `No aew runs in this project.` · `aew status: no run <id>.` · `aew status: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).` · `aew status: unexpected argument "<token>".` · `Usage: /aew:status [<run-id>]`
- **prompt**:
  - `` `preflight.md` `## Check 1. Config exists` ``, `` `preflight.md` `## Check 3. gh is authenticated` ``, `` `preflight.md` `## Check 5. No other active run` ``; and **absent**: `` `preflight.md` `## Check 2 `` (count 0)
  - `` `SKILL.md` `## Step 3. Start the run` `` with `3.1` … `3.5`, and `3.6` (in "skip 3.6–3.8")
  - `` `gates.md` `## Gate: spec` ``, `` `gates.md` `## Recording a spec revision` ``, `` `gates.md` `## Gate ids and pending state` `` (the prompt-mode rule), `` `SKILL.md` `## Gate pending` ``
  - `D1`, `D2`, `D4` and `mode: prompt`
  - `state.sh stage spec_analysis --note "prompt"` (PC-1, verbatim)
  - `gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`
  - `AskUserQuestion`, `Not posted.`, `/aew:ship <n> --from spec_analysis`
  - absent (count 0): `gh-labels.sh`, `git-branch.sh`, `git (add|commit|switch|push)`
  - error lines (verbatim): `aew prompt: missing issue number.` · `aew prompt: the issue must be a positive integer, got "<token>".` · `aew prompt: unexpected argument "<token>".` · `Usage: /aew:prompt <issue>`
- **All three:** every `aew:<name>` is one of the I-7 slash commands (`/aew:ship`, `/aew:resume`, `/aew:init`, `/aew:status`, `/aew:prompt`, `/aew:ship-milestone`); `/aew:ship-milestone` is the I-7 forward reference; no prefixed label names; every `${CLAUDE_PLUGIN_ROOT}/…` path exists and has no `<placeholder>`; every citation resolves (the phase-exit `cite_check`).

### K-4. Commands these skills run (Phase F's R2 allowlist; Phase D's permission proposal)

- **resume** (besides everything ship runs from the entered section, I-8): `cat .aew/runs/current`, `test -f .aew/runs/<id>/state.json`, `jq -r …` on `state.json` (the K-5 reads), `git status --porcelain --untracked-files=all` (Phase B review fix to the restart form), `git branch --show-current`, `git switch <branch>`, `gh auth status`, `<root>/scripts/state.sh current set <id>`.
- **status:** `cat .aew/runs/current`, `test -f`, `jq …`, `tail -n 10 .aew/runs/<id>/log.md`. Nothing else.
- **prompt** (besides ship's 3.1–3.5 and D1/D2/D4 recording calls): `<root>/scripts/state.sh stage spec_analysis --note "prompt"`, `state.sh stage brief`, `state.sh status done|blocked --note …`, `state.sh current clear`, `test -f .aew/runs/<n>/prompt.md`, `<root>/scripts/gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`.

### K-5. Shared reads (verbatim; dry-run while planning against `templates/state.example.json` copies)

- Run summary for resume Step 2: `jq -r '[.status, .stage, .mode, (.issues | map(tostring) | join(",")), (.branch // "-"), (.pr // "-" | tostring)] | @tsv' .aew/runs/<id>/state.json`
- Prompt-mode test: PC-1.
- Last note (blocked or failed reason): `jq -r '.history | last | .note // ""' .aew/runs/<id>/state.json`
- Pending gate: the I-5 lookup (`null` when no `gate:` note; `gates.md` `## Re-asking a pending gate` maps that case).

## Tasks

Wave **1** = C1 ∥ C2 ∥ C3 (three new files, no shared text; they agree only through K-1–K-5). C1 and C3 start once Phase B's files are merged; C2 needs only the I-5 lookup string and can start at any time. Then the phase-exit check (no commit).

Commit trailer for every task: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task C1 — `skills/resume/SKILL.md`

- **id:** C1
- **files:** `skills/resume/SKILL.md` (new)
- **depends_on:** [B1, B2, B4] (cites ship's `SKILL.md`, `preflight.md`, `gates.md`); its `prompt/SKILL.md` citations are checked at phase exit, after C3
- **pattern:** ship's `## Plugin root` and `## Rules` wording (B1); B1's Step-section style; frontmatter style of `skills/ui-qa/SKILL.md`
- **AC:** AC-21 (and cut 1's static re-ask check)
- **Size:** about 90–150 lines

**Step 1: RED.** `test -f skills/resume/SKILL.md; echo $?` gives `1`.

**Step 2: write it** with K-1 frontmatter and K-2 headings. Outline:

- `# aew resume`: one or two sentences. Continues the run named by the argument (default: the current run) from `state.json`. It never re-runs a stage before the recorded one and never duplicates ship's procedure: it reads it.
- `## Plugin root`: "The plugin root is `${CLAUDE_PLUGIN_ROOT}`." Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names (and, for a prompt-mode run, `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md`) with the Read tool. They are not substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above. The K-3 Skill-tool sentence, verbatim. The citation-form note from the agentic-workers box above, in one line.
- `## Rules`: ship's `SKILL.md` `## Rules` apply to everything resume does once it continues a run. Before Step 5 resume writes nothing. One line: the issue, `auto`, counters, branch and base branch come from `state.json` (ship's `## Run variables`).
- `## Step 1. Pick the run`: "The argument is: `$ARGUMENTS`." Split on whitespace. No token → `cat .aew/runs/current`; missing or empty → the no-current-run error. One token matching `^([1-9][0-9]*|m-[1-9][0-9]*)$` → the id; otherwise the not-a-run-id error. More than one → the unexpected-argument error. Each error is followed by the usage line, then stop. Then `test -f .aew/runs/<id>/state.json`; missing → the no-run error.
- `## Step 2. Read the state`: the K-5 summary read and the PC-1 test. `mode` other than `single` → the K-3 mode error, stop (PC-5).
- `## Step 3. Finished runs` (Assumption 11; nothing is written):
  - `done` → `Run <id> is done: nothing to resume.` then `PR #<pr> on <branch>.` (ship run) or `The prompt is at .aew/runs/<id>/prompt.md.` (prompt-mode run). Stop.
  - `failed` → the last note (K-5), then `Run <id> failed at <stage> and is finished: restart it with /aew:ship <n> --from <stage>.` (prompt-mode run: PC-6's hint instead). Stop.
- `## Step 4. Checks` (PC-4; read-only):
  1. `preflight.md` `## Check 1. Config exists`, `preflight.md` `## Check 3. gh is authenticated`, `preflight.md` `## Check 5. No other active run` (another active run → its stop message; this run → passes).
  2. Prompt-mode runs skip items 3 and 4 below, the tree and branch checks (PC-2).
  3. `preflight.md` `## Check 2. Clean working tree` in its **restart form** (agent memory ignored, PD-2): `git status --porcelain --untracked-files=all` (verbatim; plain `--porcelain` shows an untracked `.claude/` as one entry, so the `.claude/agent-memory/` filter would never match; Phase B B2 and I-8), ignoring lines whose path starts with `.claude/agent-memory/`. Dirty → stop with that check's message, which lists the paths. Nothing is stashed, reset or discarded.
  4. Branch: `branch` null → stop with `Run <id> has no branch: restart it with /aew:ship <n> --from spec_analysis.` Otherwise `git branch --show-current`; if it differs, `git switch <branch>` (the tree is clean, so this is safe); a failed switch stops with git's first error line.
- `## Step 5. Continue`:
  1. `state.sh current set <id>` (every `state.sh` write acts on the current run).
  2. `awaiting_input` or `awaiting_plan_approval` → Read `gates.md` and follow `gates.md` `## Re-asking a pending gate`: it finds the gate from the `gate:` note and enters that gate at step 2, so only what the gate reads is re-read and state and label are not re-written. The gate's apply step then continues into ship's sections as written. No answer again → ship's `SKILL.md` `## Gate pending` (the run stays pending). A prompt-mode run is handed back to the `prompt` skill by that section itself (I-11), so resume adds nothing for it here.
  3. `running` or `blocked`, ship run (PC-1 test prints `ship`) → Read ship's `SKILL.md` and its references; skip ship's Steps 1–4 (argument parsing, preflight, run start, restart: done above or not needed); enter ship's stage section `## Stage: <stage>` at step 1 with the note `resume`. A recorded `qa_test_plan` enters `## Stage: plan` (ship's redirect). The stage entry re-writes status `running` and moves the label off `blocked`. PD-5's mode choice applies at `develop`; `qa` re-dispatches QA phase B.
  4. `running` or `blocked`, prompt-mode run → Read `prompt/SKILL.md`; `spec_analysis` → `prompt/SKILL.md` `## Step 4. Analyse the spec`, `brief` → `prompt/SKILL.md` `## Step 5. Compile the prompt`, each entered at step 1 with the note `resume`.
  5. One closing line: no `state.sh init`, no fetch, no new branch, and never a stage before the recorded one.

**Step 3: GREEN.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/resume/SKILL.md
sed -n '1,6p' "$f"                                                     # exactly the K-1 resume frontmatter
grep -cx 'disable-model-invocation: true' "$f"                         # 1
grep -cxF 'argument-hint: "[<run-id>]"' "$f"                           # 1
grep -c '^allowed-tools:' "$f"; grep -c '!`' "$f"                      # 0, 0
grep -cE '\$[0-9]|\$ARGUMENTS\[' "$f"                                  # 0
grep -o '\$ARGUMENTS' "$f" | wc -l                                     # 1
wc -l < "$f"                                                           # 90–150
grep -n '^#' "$f" | cut -d: -f2-                                       # the K-2 resume column, in order
for m in '`gates.md` `## Re-asking a pending gate`' 'awaiting_input' 'awaiting_plan_approval' '${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md' '${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md' 'with the Skill tool' 'Steps 1–4' '## Stage: <stage>' 'the note `resume`' '`preflight.md` `## Check 2. Clean working tree`' 'restart form' 'git status --porcelain --untracked-files=all' 'state.sh current set <id>' '/aew:ship <n> --from <stage>' 'aew resume: no current run.' 'is not a run id' 'aew resume: unexpected argument' 'state.json is missing' '/aew:ship-milestone' 'Usage: /aew:resume [<run-id>]'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' "$f"                      # no output
grep -oE '/?aew:[a-z-]+' "$f" | sort -u                                # subset of /aew:prompt /aew:resume /aew:ship /aew:ship-milestone /aew:status
claude plugin validate .                                               # passes as before
```

The citation check runs at phase exit (it needs C3's file).

**Step 4: commit.**

```
feat(resume): add the resume skill

/aew:resume [<run-id>] continues a run from state.json: done and failed
runs are reported, another active run or a dirty tree stops it, and the
run branch is switched to when the tree is clean. A pending gate is
re-asked through gates.md; a running or blocked run re-enters ship's
stage section for the recorded stage. Ship's procedure is read with
Read under the plugin root, never through the Skill tool, which
disable-model-invocation blocks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task C2 — `skills/status/SKILL.md`

- **id:** C2
- **files:** `skills/status/SKILL.md` (new)
- **depends_on:** [] (uses only the I-5 lookup string and PC-1's test, both fixed in contracts)
- **pattern:** frontmatter style of `skills/ui-qa/SKILL.md`; the reads are new (no analog: nothing in the repo lists runs)
- **AC:** AC-22 (with the Phase D note: list only run-id directories, never `current` or `init-*` files)
- **Size:** about 70–120 lines

**Step 1: RED.** `test -f skills/status/SKILL.md; echo $?` gives `1`.

**Step 2: write it** with K-1 frontmatter and K-2 headings. Outline:

- `# aew status`: one sentence: a read-only view of aew runs.
- `## Rules`: read-only. It writes no file, runs no plugin script, no git and no gh command; it reads `state.json` with `jq` because the state script's `get` reads only the current run (do not name the script, so the K-3 absence check holds). Paths are relative to the project root.
- `## Step 1. Parse the argument`: "The argument is: `$ARGUMENTS`." No token → `## List every run`. One token matching `^([1-9][0-9]*|m-[1-9][0-9]*)$` → `## Show one run`. Otherwise the not-a-run-id or unexpected-argument line, then the usage line, then stop.
- `## List every run`:
  1. `cat .aew/runs/current` (missing or empty → no current run).
  2. One `jq` read (verbatim; `<cur>` is step 1's id or empty). The glob matches only directories that hold a `state.json`, so `.aew/runs/current` and init's flat `init-*` scratch files never match, and the `test()` keeps only run-id names:
     ```sh
     jq -r --arg cur '<cur>' 'input_filename as $f | ($f | split("/") | .[-2]) as $id | select($id | test("^([1-9][0-9]*|m-[1-9][0-9]*)$")) | [$id, .status, .stage, .updated_at, (if $id == $cur then "current" else "-" end), .title] | @tsv' .aew/runs/*/state.json
     ```
  3. Print a table `| Run | Status | Stage | Updated | Current | Title |`. No output, `no matches found` (zsh) or `Could not open file` (bash) → `No aew runs in this project.`
- `## Show one run`:
  1. `test -f .aew/runs/<id>/state.json`; missing → `aew status: no run <id>.`
  2. State fields (verbatim): `jq -r 'del(.history) | to_entries[] | "\(.key): \(.value | if type == "array" then map(tostring) | join(",") else tostring end)"' .aew/runs/<id>/state.json`
  3. Last 10 log lines: `tail -n 10 .aew/runs/<id>/log.md`.
  4. Cycles: `jq -r '"\(.limits.max_review_cycles // 2) \(.limits.max_fix_cycles // 3)"' .aew/config.json` (no config → the schema defaults 2 and 3, say so); print `review <review_cycle>/<max_review_cycles>, fix <fix_cycle>/<max_fix_cycles>`.
  5. For `awaiting_*`: the I-5 lookup (verbatim) names the gate; `null` → `plan-approval` for `awaiting_plan_approval`, `spec` for `awaiting_input` (B4's mapping). For `blocked`/`failed`: the K-5 last-note read gives the reason. PC-1's test marks a prompt-mode run.
  6. Then `## Next action`.
- `## Next action` (table `| Status | Next action |`, one row per status, verbatim first cells):
  - `running` — if no session is driving it (interrupted), `/aew:resume <id>`; otherwise wait.
  - `awaiting_input` — answer the `<gate>` gate with `/aew:resume <id>`.
  - `awaiting_plan_approval` — approve, change or stop the plan with `/aew:resume <id>` (the plan is `.aew/runs/<id>/05-plan.md`).
  - `blocked` — fix the reason shown, then `/aew:resume <id>`.
  - `done` — nothing to do: PR #<pr> (prompt-mode run: `.aew/runs/<id>/prompt.md`).
  - `failed` — finished: `/aew:ship <n> --from <stage>` (prompt-mode run: PC-6's hint).
  - One line under the table: a run whose mode is not `single` is handled by `/aew:ship-milestone` (coming in a later release).

**Step 3: GREEN.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/status/SKILL.md
sed -n '1,5p' "$f"                                                     # exactly the K-1 status frontmatter
grep -c '^disable-model-invocation' "$f"; grep -c '^allowed-tools:' "$f"; grep -c '!`' "$f"   # 0, 0, 0
grep -cxF 'argument-hint: "[<run-id>]"' "$f"                           # 1
grep -o '\$ARGUMENTS' "$f" | wc -l                                     # 1
wc -l < "$f"                                                           # 70–120
grep -n '^#' "$f" | cut -d: -f2-                                       # the K-2 status column, in order
grep -cE 'state\.sh|gh-issue\.sh|gh-labels\.sh|gh-pr\.sh|gh-retro\.sh|git-branch\.sh' "$f"   # 0
grep -cE 'gh (auth|issue|pr|label|api|repo)' "$f"                      # 0
grep -cE 'git (add|commit|switch|checkout|push|merge|rebase|reset|stash|fetch|pull|branch|status)' "$f"   # 0
for m in '^([1-9][0-9]*|m-[1-9][0-9]*)$' '.aew/runs/*/state.json' 'tail -n 10' 'max_review_cycles // 2' 'max_fix_cycles // 3' "[.history[] | select((.note // \"\") | startswith(\"gate:\"))] | last | .note" 'No aew runs in this project.' 'aew status: no run <id>.' 'is not a run id' 'aew status: unexpected argument' 'Usage: /aew:status [<run-id>]'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
for s in running awaiting_input awaiting_plan_approval blocked done failed; do printf '%s=%s\n' "$s" "$(grep -c "^| \`$s\` |" "$f")"; done   # each =1
```

Dry-run of the listing (copy the `jq` command from the written file, not from this plan; the scratch tree is outside the repo):

```sh
W="${TMPDIR%/}/aew-status-check"; R=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
rm -rf "$W" && mkdir -p "$W/.aew/runs/42" "$W/.aew/runs/7" "$W/.aew/runs/m-3" "$W/.aew/runs/junk" && cd "$W"
cp "$R/templates/state.example.json" .aew/runs/42/state.json
jq '.run_id = "7" | .issues = [7] | .status = "awaiting_input" | .history += [{"stage":"spec_analysis","status":"awaiting_input","at":"2026-10-24T11:00:00Z","note":"gate:spec 01-spec-analysis.md"}]' .aew/runs/42/state.json > .aew/runs/7/state.json
cp .aew/runs/7/state.json .aew/runs/junk/state.json; echo '{}' > .aew/runs/init-config.json; echo 42 > .aew/runs/current
# now run the listing jq with <cur> = 42
```

Expected (planning dry-run, zsh): two lines, `42	running	review	2026-10-24T10:42:00Z	current	Add a newsletter sign-up form to the footer` and `7	awaiting_input	review	…	-	…`. `junk`, `m-3` (no `state.json`), `current` and `init-config.json` are absent. In an empty directory zsh prints `no matches found` (exit 1) and bash `Could not open file` (exit 2): both mean "No aew runs". The I-5 lookup on run 7 prints `gate:spec 01-spec-analysis.md`, on run 42 `null`; the state-fields read prints `issues: 7`; the cycles read prints `2 3` on `templates/config.example.json` and on `{}`. Paste the outputs into the task report, then `rm -rf "$W"`.

**Step 4: commit.**

```
feat(status): add the read-only status skill

/aew:status lists every run directory whose name is a run id (so the
current pointer and init's scratch files never show), with status,
stage, last update and which run is current. With a run id it shows the
state fields, the last 10 log lines, the review and fix cycles used
against their limits, the pending gate, and the next action per status.
It writes nothing and runs no script, git or gh command.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task C3 — `skills/prompt/SKILL.md`

- **id:** C3
- **files:** `skills/prompt/SKILL.md` (new)
- **depends_on:** [B1, B2, B3, B4] (cites ship's `SKILL.md`, `preflight.md`, `dispatch.md`, `gates.md`)
- **pattern:** ship's `## Plugin root`, Step and Stage section style (B1); dispatch rows D1, D2, D4 (I-4); `gates.md` `## Gate: spec` and `## Recording a spec revision` (B4)
- **AC:** AC-23
- **Size:** about 100–160 lines

**Step 1: RED.** `test -f skills/prompt/SKILL.md; echo $?` gives `1`.

**Step 2: write it** with K-1 frontmatter and K-2 headings. Outline:

- `# aew prompt`: one or two sentences: writes `prompt.md`, a single self-contained prompt for a plain Claude Code session (DESIGN §8.2 prompt mode). No branch, no commits, no stage labels; the only GitHub writes are a recorded spec revision and, if James agrees, the `prompt.md` comment.
- `## Plugin root`: as `resume`'s (root sentence; Read ship's `SKILL.md` and references; literal `${CLAUDE_PLUGIN_ROOT}` = this root; the Skill-tool sentence, here naming `ship`).
- `## Rules`: ship's `SKILL.md` `## Rules` apply, except that this skill creates no branch, makes no commit, sets no stage label (`gates.md` `## Gate ids and pending state`, the prompt-mode rule) and runs no tree or default-branch check. Do not name the label or branch scripts (K-3 absence check).
- `## Step 1. Parse the argument`: "The argument is: `$ARGUMENTS`." Exactly one token matching `^[1-9][0-9]*$`. Errors (K-3, verbatim), each followed by the usage line: none → missing; first token not a positive integer → positive-integer error; a second token → unexpected argument. Nothing runs or is written in this step.
- `## Step 2. Preflight`: Read `preflight.md`; run `preflight.md` `## Check 1. Config exists`, `preflight.md` `## Check 3. gh is authenticated`, `preflight.md` `## Check 5. No other active run`, in that order, with their messages. Not checks 2, 4 or 6: nothing is committed or branched (AC-23).
- `## Step 3. Start the run`: Read ship's `SKILL.md`; run `SKILL.md` `## Step 3. Start the run` sub-steps 3.1–3.5 only, and skip 3.6–3.8 (label, branch, stage entry). Overrides: 3.1's stop message becomes `Run <n> already exists, and aew prompt only starts new runs: check it with /aew:status <n>.` (Assumption 21); 3.3 and 3.4 keep their state writes but print `Could not fetch issue #<n>: <reason>. Fix it, remove .aew/runs/<n>, then run /aew:prompt <n> again.` (PC-6). Between 3.2 and 3.3, the marker write `state.sh stage spec_analysis --note "prompt"` (PC-1, I-11, verbatim), which is also D1's state write.
- `## Step 4. Analyse the spec`:
  1. Entry, on resume only: `state.sh stage spec_analysis --note "resume"`.
  2. Required files (`dispatch.md` `## Required inputs per stage`); missing → `## Stopping` below.
  3. Dispatch D1 (`dispatch.md` `## Dispatch table`, `dispatch.md` `## How to dispatch`).
  4. Return check (`dispatch.md` `## Return check`, `dispatch.md` `## Retries`).
  5. `ok` → `gates.md` `## Recording a spec revision` (it sets the `spec-revised` flag when a revision is recorded) → Step 5. `needs_input` → `gates.md` `## Gate: spec` under the prompt-mode rule; at its step 4 the D2 re-dispatch returns here, to sub-step 4, instead of ship's spec-analysis stage. No answer → `SKILL.md` `## Gate pending` (resume continues it, PC-2). `blocked` or `failed` after the retry → `## Stopping` below.
- `## Step 5. Compile the prompt`:
  1. Entry: `state.sh stage brief` (D4's state write; with `--note "resume"` on resume). No label.
  2. Required files: `spec-final.md`, `issue.json`.
  3. Dispatch D4 (`mode: prompt`).
  4. Return check on the Agent result only (`prompt.md` has no return block in the file), then `test -f .aew/runs/<n>/prompt.md`.
  5. `ok` → Step 6. Anything else after the retry → `## Stopping`.
- `## Step 6. Finish`:
  1. `state.sh status done --note "prompt written"`, then `state.sh current clear`.
  2. Print `Prompt written: .aew/runs/<n>/prompt.md`, the spec version (and whether a revision was recorded), and `To build it with aew instead: /aew:ship <n> --from spec_analysis.`
  3. Offer with AskUserQuestion, one question `Post prompt.md as a comment on issue #<n>?`, options `Post it` and `Do not post`. AskUserQuestion not among the tools (headless), refused, empty, or `Do not post` → print `Not posted.` and stop. Do not try to call a tool you do not have.
  4. `Post it` → `gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`; print the comment URL it prints. A failure prints a warning with the first stderr line; the run stays `done`.
- `## Stopping` (PC-3): `state.sh status blocked --note "<reason, one line>"`, keep `current`, print `aew prompt #<n>: blocked at <stage>: <reason>.` then `Resume with /aew:resume <n>`, and stop. No issue comment and no label. Script failures after Step 3 (for example a `gh-issue.sh revise` refusal) come here too.

**Step 3: GREEN.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/prompt/SKILL.md
sed -n '1,6p' "$f"                                                     # exactly the K-1 prompt frontmatter
grep -cx 'disable-model-invocation: true' "$f"                         # 1
grep -cxF 'argument-hint: "<issue>"' "$f"                              # 1
grep -c '^allowed-tools:' "$f"; grep -c '!`' "$f"                      # 0, 0
grep -cE '\$[0-9]|\$ARGUMENTS\[' "$f"                                  # 0
grep -o '\$ARGUMENTS' "$f" | wc -l                                     # 1
wc -l < "$f"                                                           # 100–160
grep -n '^#' "$f" | cut -d: -f2-                                       # the K-2 prompt column, in order
for m in '`preflight.md` `## Check 1. Config exists`' '`preflight.md` `## Check 3. gh is authenticated`' '`preflight.md` `## Check 5. No other active run`' '`SKILL.md` `## Step 3. Start the run`' '3.1' '3.5' '3.6' '`gates.md` `## Gate: spec`' '`gates.md` `## Recording a spec revision`' '`gates.md` `## Gate ids and pending state`' '`SKILL.md` `## Gate pending`' 'D1' 'D2' 'D4' 'mode: prompt' 'state.sh stage spec_analysis --note "prompt"' 'gh-issue.sh comment <n> .aew/runs/<n>/prompt.md' 'AskUserQuestion' 'Not posted.' '/aew:ship <n> --from spec_analysis' 'with the Skill tool' 'aew prompt: missing issue number.' 'aew prompt: the issue must be a positive integer, got' 'aew prompt: unexpected argument' 'Usage: /aew:prompt <issue>' '${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done
# every count >= 1
grep -cF '`preflight.md` `## Check 2' "$f"                             # 0
grep -cE 'gh-labels\.sh|git-branch\.sh' "$f"                           # 0
grep -cE 'git (add|commit|switch|push)' "$f"                           # 0
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `)]*<' "$f"                      # no output
grep -oE '/?aew:[a-z-]+' "$f" | sort -u                                # subset of /aew:prompt /aew:resume /aew:ship /aew:status
claude plugin validate .                                               # passes as before
```

**Step 4: commit.**

```
feat(prompt): add the prompt skill

/aew:prompt <issue> runs config, gh auth and active-run preflight, ship's
run start without a label or branch, spec analysis with the same
material gate and revision recording (read from ship's gates.md), and
the brief compiler in prompt mode. It marks the run as prompt mode so
resume can continue it, prints the prompt.md path, and offers to post it
as an issue comment; an unanswered offer posts nothing.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

## Phase exit check (after C1–C3; no commit)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
cite_check() {   # one line per distinct citation in $1; each must end in =1
  grep -oE '`(prompt/SKILL|SKILL|preflight|dispatch|gates|routing|pr|final-report)\.md` `## [^`]+`' "$1" | sort -u |
  while IFS= read -r c; do
    f=${c%%'` `'*}; f=${f#'`'}; h=${c#*'` `'}; h=${h%'`'}
    case $f in
      SKILL.md) p=skills/ship/SKILL.md ;;
      prompt/SKILL.md) p=skills/prompt/SKILL.md ;;
      *) p=skills/ship/references/$f ;;
    esac
    printf '%s=%s\n' "$c" "$(grep -cxF -- "$h" "$p")"
  done
}
for s in resume status prompt; do echo "== $s"; cite_check "skills/$s/SKILL.md"; done      # every line =1 (status has none)
for s in resume prompt; do grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ `),;]+' "skills/$s/SKILL.md"; done | sed -e 's|^\${CLAUDE_PLUGIN_ROOT}/||' -e 's|[.:]$||' | sort -u | while IFS= read -r p; do test -e "$p" && echo "ok $p" || echo "MISSING $p"; done   # every line starts "ok"
claude plugin validate .                                                                   # passes
```

`cite_check` was dry-run under `/bin/bash` 3.2 and zsh against a scratch tree while planning: a real heading prints `=1`, a missing one `=0`. Phase E may lift it into `skills.bats` for all of `skills/{ship,resume,prompt}`.

## AC → task matrix

| AC | Task | Static evidence (this phase) | Live evidence (Phase F) |
|---|---|---|---|
| AC-21 | C1 | K-3 resume strings, incl. the `## Re-asking a pending gate` citation (cut 1) | R2 (resume after the develop kill, stopped at `review`) |
| AC-22 | C2 | K-3 status strings, absence checks, the listing dry-run | none (read-only; not simulated) |
| AC-23 | C3 | K-3 prompt strings and absence checks | none (prompt is out of the simulated routes) |

## Cross-phase notes

- **Phase E (`skills.bats`):** grep K-1 frontmatter and K-2 headings in order, and the K-3 strings (presence and the absence counts). The cut-1 check is `` `gates.md` `## Re-asking a pending gate` `` plus `awaiting_input` and `awaiting_plan_approval` in `skills/resume/SKILL.md`. Allow `/aew:ship-milestone` as a forward reference in resume and status too. Citation resolution: `` `SKILL.md` `` → `skills/ship/SKILL.md`, `` `prompt/SKILL.md` `` → `skills/prompt/SKILL.md`, the other `<name>.md` → `skills/ship/references/`; the `cite_check` above is a ready implementation.
- **Phase F (R2):** add K-4's resume commands to the allowlist union (`git status --porcelain --untracked-files=all`, `git branch --show-current`, `git switch <branch>`, `cat .aew/runs/current`, `jq`, and `state.sh current set`). If the tree is dirty after the kill, resume stops at Step 4 and lists the paths (Assumption 8's first branch).
- **Phase B:** nothing changes, but two facts now depend on it: ship's `## Stage: spec_analysis` and `gates.md` `## Gate: spec` step 4 are followed by prompt with a different return point (stated in prompt, not in ship), and Restart check 2 must keep allowing a null branch at `spec_analysis` (prompt → ship conversion, PC-6). Ship's 3.1 message ("continue it with /aew:resume <n>, or restart a stage …") is shown for a finished prompt run too, which is correct.
- **Phase B (reconciled):** (1) The restart form of `preflight.md` `## Check 2. Clean working tree` uses `git status --porcelain --untracked-files=all` (B2, I-8); C1 writes that command and K-3 greps it. (2) The prompt-run marker is I-11's `--note "prompt"`, written straight after 3.2; C3 writes it and C1/C2 test it (PC-1). Phase B's `## Re-asking a pending gate` and `## Gate: spec` step 4 check the marker and hand a prompt run back to the `prompt` skill, so C1 Step 5.2 keeps only the citation. (3) **Open with Phase B's reviewer:** I-11's marker-only check treats a prompt run converted by `/aew:ship <n> --from spec_analysis` as still a prompt run, so a spec gate on the converted run would hand back to `prompt` from `gates.md`. PC-1 adds `branch == null`; I-11 and gates.md should use the same test, whichever form is agreed.
- **Phase D:** `status` relies on init's scratch files being flat files directly under `.aew/runs/`, never a directory named like a run id.
- **Closing docs:** record PC-1 (the `prompt` history note and the prompt-mode test) in DESIGN §8.2 or the run-protocol state notes, PC-3 (a blocked prompt run posts no report comment and sets no `blocked` label: a recorded deviation from DESIGN §7's blocked rule), and PC-5 (resume continues `single` runs only until prompt 06).

## Risks

- **Prompt-mode detection is a convention, not a schema field** (PC-1). If a later change writes a bare `prompt` note elsewhere or drops `branch` from a ship run, resume would route wrongly. Mitigation: the test needs both a null branch and the exact note; ship sets the branch before its first dispatch.
- **Resume entering ship mid-flow is untested live except R2** (cut 1 removed R1). A wrong section name would surface only at runtime; the phase-exit `cite_check` and Phase E's checks are the guard.
- **Cross-skill Read relies on V-5** (literal `${CLAUDE_PLUGIN_ROOT}` in read files is not substituted). Both skills state the root in their own substituted body, as ship does.
- **zsh glob behaviour** in status: an empty runs dir gives an error rather than empty output. The skill states both outcomes mean "no runs".

## Approval (Phase C)

- Senior architect: APPROVED on 2026-10-25T00:14:31Z (plan-review, Phase C)
- Plan format: LEAN
- Plan dependency graph: valid. Wave count: 1. Max wave width: 3 tasks parallel (C1 ∥ C2 ∥ C3; C1 and C3 after B1–B4, C2 free).
- Open cross-phase item: the `branch == null` guard in PC-1 versus Phase B I-11's marker-only check (see Cross-phase notes, Phase B (3)).
- Plan content hash (SHA-256, document above this trailer): 3b47f444fd6e18050fe55163cb1db44c453d3474949e60c395105c7a9beca828

---

# Phase D plan — `init` skill

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `46335838…6090`)
- **Binding overrides:** the CTO simplicity-challenge (scratchpad `simplicity-adopted.md`): cut 6 (AC-31: anchored allow rules only, no deny rules, no V-7 verification task; V-7 already verified in `docs-facts-v7.md`) and cut 9 (AC-32: no deletion of an empty `chore/aew-init` branch). They win over the spec text where they differ.
- **Phase:** D of the EPIC. `depends_on: [A]`: it consumes Phase A contract C-2 (standards-setter `mode: init`, task A2) and C-3 (`gh-pr.sh open`, task A3). Phase E's `skills.bats` checks this file; Phase F runs I1/I2 against it and makes every DESIGN.md edit.
- **Depth:** full
- **ACs covered:** AC-24, AC-25, AC-26, AC-27, AC-28, AC-29, AC-30, AC-31, AC-32, AC-33. The live evidence for AC-33 (I1/I2, AC-44) is Phase F's; this phase proves every deterministic step for free in a scratch copy of the nextjs-tailwind fixture.
- **Risk:** permissions. Task D5 writes the `.claude/settings.json` (portable) and `.claude/settings.local.json` (plugin scripts, gitignored) proposal that an interactive user may accept. It is RISKY and has a rollback.
- **Date:** 2026-10-25
- **Naming note:** "Assumption n" means the spec's assumption n. "§n" in this plan means section n of `skills/init/SKILL.md` (the section contract below), unless it says DESIGN or ui-qa.

> **For agentic workers:** implement task by task, in order (all six tasks write the same file). Every task records its RED (the check fails before the change) and its GREEN after. The checks are free: grep and awk over the skill, plus the skill's own shell snippets run with plain bash in a scratch project outside the repo. No Claude session, no spend, no network apart from `npx ajv-cli` (D3, D6).

**Goal:** one user-invocable skill, `/aew:init`, that prepares a target project for aew on a `chore/aew-init` branch and opens a PR: prerequisites, detection and config, labels, gitignore, the Playwright offer, a CLAUDE.md section, a permissions proposal, the first standards docs. A second run changes nothing.

**Architecture:** a single new file, `skills/init/SKILL.md`, with no `references/` (simplicity first; it stays under 500 lines, checked in D6). It is a numbered procedure the main thread follows. Every deterministic step is a short fenced `sh` snippet, and that is what the checks run. Scratch files live in `.aew/runs/` (gitignored by §3, inside the project, so Write and `acceptEdits` cover them, and no temp dir outside the project is needed). Init talks to GitHub only through `gh auth status` (the one direct, read-only call, Assumption 9) and the plugin scripts `gh-labels.sh ensure`, `git-branch.sh push` and `gh-pr.sh open`. No scripts, agents, hooks or DESIGN.md change in this phase.

**Tech stack:** bash/zsh-safe snippets (no bash-only syntax: the Bash tool runs the user's shell), jq 1.7.1, git, `npx --yes -p ajv-cli@5 -p ajv-formats@3`, the `gh` mock `tests/scripts/helpers/bin/gh` for the label and PR checks.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| spec AC-24–33, Assumptions 5, 9, 22–28, Risks ("Permission rules") | The behaviour to build |
| scratchpad `simplicity-adopted.md` (cuts 6, 9) and `docs-facts-v7.md` | The permission-rule semantics AC-31 relies on; no empty-branch deletion |
| `docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-A.md` C-2, C-3 | The two interfaces D6 calls |
| `templates/config.schema.json` | Required `project`, `default_branch`, `stacks` (`minItems: 1`, items `{profile,path,version}`, `additionalProperties: false`), `commands` (nine optional keys), `app` (four required keys, `env_type` enum `wp-env, ddev, local, docker, native, none`), `retro.repo` |
| `scripts/detect-stack.sh --help`, `gh-labels.sh --help`, `git-branch.sh --help` | Contracts (detect output `{profile,path,version,evidence}`; `ensure` makes 11 `gh label create --force` calls; `push` refuses the default branch and reads `default_branch` from config) |
| `skills/ui-qa/SKILL.md` §2 (and §4, §6, §7 it points to) | The Playwright setup init offers |
| `agents/standards-setter.md` Guardrails and Memory | The agent writes `docs/standards/**` and `.claude/agent-memory/aew-standards-setter/` |
| `tests/fixtures/stacks/nextjs-tailwind/` | The init target: `package.json` (`name` `fixture-nextjs-tailwind`; scripts `dev`, `build`, `lint`), `tsconfig.json`, `app/`; no lock file, no `.gitignore`, no `CLAUDE.md` |
| `tests/scripts/helpers/bin/gh` | Mock: needs `GH_MOCK_DIR`; logs to `$GH_MOCK_DIR/calls.log`; route = first two args (`label-create`, `pr-list`, `pr-create`); canned replies in `responses/<route>[.<n>].out` |
| `skills/ui-qa/SKILL.md` lines 1–8 | Skill frontmatter and numbered-section style to mirror |

Gotchas that apply (from `docs/superpowers/project-map.md`): `${CLAUDE_PLUGIN_ROOT}` is substituted in the skill body but is not in the Bash environment, so snippets spell `"${CLAUDE_PLUGIN_ROOT}/scripts/…"` (the checks export it as a shell variable to get the same effect); in zsh run `setopt interactivecomments` and quote separators; macOS `/var` is `/private/var` (compare `pwd -P` with `git rev-parse --show-toplevel`); the dev-workflow safety hook blocks any command whose text contains `git push`, so the scratch setup builds `origin` with `git clone --bare` and never pushes by hand; `jq -Rs` is unsafe for multi-byte text (not used).

## Interface contract (Phases E and F rely on this)

### D-C1. `skills/init/SKILL.md` frontmatter and sections

Frontmatter: `name: init`, a `description`, `disable-model-invocation: true`. No `argument-hint` (init takes no arguments), no `allowed-tools`. The body has no `` !`cmd` `` injection and no `$N` placeholders.

| § | Title | ACs | Task |
|---|---|---|---|
| (intro) | Plugin root, how to run, the ask rule, "Init's files" | 24, 33 | D1 |
| 1 | Prerequisites | 24 | D1 |
| 2 | Clean tree and branch | 24, 25 | D1 |
| 3 | Gitignore | 28 | D2 |
| 4 | Detect and discover | 24 (stack tools), 26 | D2 |
| 5 | Confirm in one question round | 26, 29 (the offer) | D3 |
| 6 | Write and validate the config | 27 | D3 |
| 7 | Labels | 28 | D4 |
| 8 | Playwright setup | 29 | D4 |
| 9 | CLAUDE.md section | 30 | D4 |
| 10 | Permissions proposal | 31 | D5 |
| 11 | Standards | 32 | D6 |
| 12 | Commit, push and PR | 32, 33 | D6 |
| 13 | Report | 26, 29, 31, 33 | D6 |

Headings are exactly `## <n>. <Title>`. Shell snippets are fenced ```` ```sh ```` **at column 0, never indented inside a list item** (the `snip` extractor matches `^```sh$`, and a heredoc's closing `EOF` must start its line; the plan shows some snippets indented under bullets only for readability). Snippets are numbered by their order inside their section, as the tasks state. Placeholders are `<snake_case>` in angle brackets, which the model replaces before running (the checks replace them with `sed`).

### D-C2. Paths and names the skill mentions (for Phase E's existence check)

Only existing paths: `${CLAUDE_PLUGIN_ROOT}/scripts/{detect-stack,gh-labels,git-branch,gh-pr,state,gh-issue,gh-milestone,gh-retro}.sh`, `${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json`, `${CLAUDE_PLUGIN_ROOT}/skills/ui-qa/SKILL.md`. Agent and skill names: `aew:standards-setter`, plus the commands `/aew:init`, `/aew:ship`, `/aew:resume`, `/aew:status`, `/aew:prompt` in the CLAUDE.md block (they all exist once B–D are merged). The permissions template lists each script by its real name, never `scripts/<name>.sh`, so a placeholder can't fail E's check. The skill never names a label (`aew:<stage>`), so E's `aew:<name>` pattern doesn't trip on one.

### D-C3. Files init writes in a target project ("Init's files")

`.gitignore`, `.aew/config.json`, `CLAUDE.md`, `.claude/settings.json` (only on a yes), `.claude/settings.local.json` (only on a yes; gitignored, so never committed or listed by §12), `docs/standards/**` and `.claude/agent-memory/aew-standards-setter/**` (from the standards-setter), and, only when the Playwright offer is accepted, the ui-qa §2 files (`package.json`, the lock file, `playwright.config.ts`, `<ui.e2e_dir>/aew.ts`, or the nested `tests/e2e/` package). Scratch files (gitignored, removed in §13): `.aew/runs/init-config.json`, `.aew/runs/init-config-merged.json`, `.aew/runs/init-permissions.json`, `.aew/runs/init-permissions-local.json`, `.aew/runs/init-settings.json`, `.aew/runs/init-pr-body.md`. Their names can't collide with run ids (`^[1-9][0-9]*$|^m-…`). **Phase C's `status` lists only directories whose names match the run-id pattern (`^[1-9][0-9]*$` or `^m-…`)**, so these files and `current` never show up as runs.

### D-C4. What a headless I1/I2 run (Phase F) should observe

- **I1 on the fixture** (AskUserQuestion absent, so every default is used): branch `chore/aew-init` from `main`; `.gitignore` = `.aew/runs/` and `.playwright-mcp/`; `.aew/config.json` equal to the reference proposal in D2 (it validates); 11 `label create` calls; Playwright skipped; `CLAUDE.md` created with the section; neither `.claude/settings.json` nor `.claude/settings.local.json` written and no `.claude/settings.local.json` line in `.gitignore` (the proposal is printed: 17 portable rules and the 8 plugin-script rules); standards-setter `mode: init` (nextjs and tailwind generated); one commit `chore: set up aew`; one `git-branch.sh push`; `gh-pr.sh open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base main`, which makes one `pr list` and one `pr create` call.
- **I2, straight after:** `git status --porcelain` empty; both branch heads unchanged; config sha unchanged; 11 `label create` calls (expected); no push; exactly one `pr list` (the PR is reused) and no `pr create`; the report says "nothing changed" and names the open PR. The harness cans `responses/pr-list.2.out` with the PR number from I1 so the second lookup finds it.
- The harness needs a canned `responses/pr-create.out` containing a `/pull/<n>` URL (C-3 parses it). Init's config names the real plugin repo as `retro.repo` (Assumption 23); G1 runs on that config, so Phase F's retro override (AC-39) must also cover the init-produced config.

## Verification scaffold (shared by every task)

Write this once to `${TMPDIR%/}/aew-init-env.sh` with the Write tool (not a heredoc, so no command text contains `git push`), and start each check with `. "${TMPDIR%/}/aew-init-env.sh"`. It needs no network and makes no GitHub call: the mock is first on `PATH`, `GH_MOCK_DIR` is set, and `origin` is a local bare repo.

```sh
REPO=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
W="${TMPDIR%/}/aew-init-check"
export CLAUDE_PLUGIN_ROOT="$REPO" GH_MOCK_DIR="$W/gh" PATH="$REPO/tests/scripts/helpers/bin:$PATH"
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
# fresh scratch project: the fixture as a repo on main, with a local bare origin
fresh() {
  rm -rf "$W" && mkdir -p "$W" &&
  cp -Rp "$REPO/tests/fixtures/stacks/nextjs-tailwind" "$W/p" &&
  git -C "$W/p" init -q -b main && git -C "$W/p" add -A && git -C "$W/p" commit -qm fixture &&
  git clone -q --bare "$W/p" "$W/origin.git" &&
  git -C "$W/p" remote add origin "$W/origin.git" && git -C "$W/p" fetch -q origin &&
  git -C "$W/p" branch -q -u origin/main main
}
# snip <section> [k]: the k-th ```sh block of "## <section>. " in the skill
snip() {
  awk -v s="## $1. " -v k="${2:-1}" 'index($0,s)==1{f=1;next} f&&/^## /{exit}
    f&&/^```sh$/{c++; if(c==k)b=1; next} b&&/^```$/{exit} b' "$REPO/skills/init/SKILL.md"
}
# run <section> [k] [sed-expr]: run that snippet in the scratch project with bash
run() { (cd "$W/p" && snip "$1" "${2:-1}" | sed "${3:-s/^//}" | /bin/bash -e); }
```

`run` uses `/bin/bash` (3.2) so a bash-4 construct fails, and snippets are written without zsh-incompatible syntax too, so they work under either shell. Each check below lists its commands and expected output; record the actual output in the task report.

## Tasks

Waves: **1** = D1 · **2** = D2 · **3** = D3 · **4** = D4 · **5** = D5 · **6** = D6 (after A2 and A3 have merged). All six tasks write `skills/init/SKILL.md`, so they run in series. D1–D5 have no cross-phase dependency and can start while Phase A is in flight.

---

### Task D1 — Skeleton, prerequisites, clean tree and branch (AC-24, AC-25)

- **id:** D1
- **files:** `skills/init/SKILL.md` (new)
- **depends_on:** []
- **pattern:** `skills/ui-qa/SKILL.md` (frontmatter shape, `# aew …` H1, `## <n>. <Title>` sections, short imperative prose); spec Assumption 22.
- **ACs:** AC-24 (all but the per-profile stack-tool warnings, which go in §4), AC-25
- **Risk:** NOT RISKY.

**Step 1: RED.** `test -f skills/init/SKILL.md` exits 1.

**Step 2: write the file.** Contents, section by section:

- **Frontmatter** as D-C1. Description, for example: "Sets a project up for aew: checks prerequisites, detects stacks, writes `.aew/config.json`, ensures labels and gitignore lines, offers Playwright, adds a CLAUDE.md section, proposes permissions, generates the first standards docs, and opens a PR from `chore/aew-init`. Safe to re-run: it only adds what is missing."
- **Intro** (≤ 25 lines):
  - The plugin root is `${CLAUDE_PLUGIN_ROOT}`. Run plugin scripts by their full quoted path, as the snippets do (never write a `${CLAUDE_PLUGIN_ROOT}/…` path with a placeholder in it: Phase E checks every such path exists). Run snippets from the project root, one Bash call per snippet, replacing `<…>` placeholders first.
  - Init takes no arguments. If any were given, stop with `usage: /aew:init (no arguments)`.
  - **The ask rule.** Init asks at most twice: the §5 question round and the §10 permissions question. If AskUserQuestion is not in your tool list (headless runs), don't try to call it. Use each question's default and list it in the report. A refused or empty answer also takes the default. The defaults are the recommended config values, Playwright skipped, and permissions not written. All of them can be reviewed in the PR.
  - **Idempotency.** Every step checks before it writes and says when it is a no-op. A second run on an unchanged repo changes no file and makes no commit, push or PR call.
  - **Init's files:** the D-C3 list, plus the scratch files and the rule that init stages only these.
  - Never install a global tool. Never touch GitHub except through `gh auth status` and the plugin scripts named here.
- **§1 Prerequisites.** Three snippets, each its own Bash call:
  ```sh
  for c in git jq node gh; do
    if command -v "$c" > /dev/null 2>&1; then echo "ok $c"; else echo "missing $c"; fi
  done
  if command -v node > /dev/null 2>&1; then
    v=$(node -p 'process.versions.node')
    if [ "${v%%.*}" -ge 20 ]; then echo "ok node $v"; else echo "old node $v"; fi
  fi
  ```
  ```sh
  git rev-parse --show-toplevel
  pwd -P
  git remote get-url origin
  ```
  ```sh
  gh auth status
  ```
  Then a table maps each failure to its stop message and install hint: `git` (macOS `xcode-select --install`, else the OS package manager); `gh` (https://cli.github.com, then `gh auth login`; a failing `gh auth status` says to run `gh auth login`); `jq` (`brew install jq`, or the OS package manager); `node` missing or `old node` (Node 20 or later from https://nodejs.org or a version manager such as `nvm install 20`); not inside a git repo, or the top level differs from `pwd -P` ("run `/aew:init` from the repository root"); no `origin` ("add the GitHub remote as `origin`"). Any of these stops init, and nothing is written. `gh auth status` stays a separate, exact call, so the permission rule `Bash(gh auth status)` matches it and nothing broader is needed.
- **§2 Clean tree and branch.**
  - Default branch, first non-empty answer wins (snippet 1):
    ```sh
    jq -r '.default_branch // empty' .aew/config.json 2> /dev/null || true
    git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true
    git ls-remote --symref origin HEAD || true
    git branch --show-current
    ```
    Use the existing config's value. Otherwise use `origin/HEAD` without the `origin/` prefix, then the `ref: refs/heads/<name>` line of `ls-remote`. If none of those gives a value, use the current branch and mark it uncertain (it is asked in §5).
  - Clean tree (snippet 2, its own ```sh block): `git status --porcelain --untracked-files=all`. Empty → continue. Not empty → stop and list the paths ("commit or stash these first"). **One exception:** on `chore/aew-init`, when every listed path is one of Init's files, continue. That is an interrupted earlier init, and this run finishes it.
  - Branch (snippet 3):
    ```sh
    if git rev-parse --verify --quiet refs/heads/chore/aew-init > /dev/null ||
       git rev-parse --verify --quiet refs/remotes/origin/chore/aew-init > /dev/null; then
      git switch chore/aew-init
      if git merge-base --is-ancestor HEAD <default_branch>; then
        git switch -C chore/aew-init <default_branch>
        echo "restarted chore/aew-init from <default_branch>"
      elif ! git merge-base --is-ancestor <default_branch> HEAD; then
        echo "chore/aew-init is older than <default_branch>: if its PR is merged or closed run \`git branch -D chore/aew-init\`, otherwise rebase it, then re-run /aew:init"
        exit 1
      fi
    else
      git switch -c chore/aew-init <default_branch>
    fi
    ```
    If the branch already exists locally or on `origin`, init switches to it (git sets up tracking for a remote-only branch). Then there are three cases:
    - Its commits are all in the default branch (its PR was merged, or it never got a commit): init restarts it at the default branch. `switch -C` only moves a branch whose work is already merged, so nothing is lost.
    - The default branch has moved on and the branch has commits of its own (for example a squash-merged or closed PR): init stops with the message above and changes nothing. The user decides; init never deletes or rebases it.
    - Otherwise (the branch is ahead of the default branch, the usual re-run): init reuses it.

    A new branch is created from the local default branch. Init doesn't fetch or fast-forward: if the PR shows conflicts, the user rebases. A switch failure stops init.

**Step 3: GREEN.**

```sh
. "${TMPDIR%/}/aew-init-env.sh"
awk 'NR==1&&$0!="---"{exit 1} NR>1&&/^---$/{exit} NR>1' "$REPO/skills/init/SKILL.md"
#   -> name: init / description: … / disable-model-invocation: true   (three keys, nothing else)
grep -cE '^(argument-hint|allowed-tools):' "$REPO/skills/init/SKILL.md"   # 0
grep -c '!`' "$REPO/skills/init/SKILL.md"                                   # 0
grep -E '^## [0-9]+\. ' "$REPO/skills/init/SKILL.md"                        # ## 1. Prerequisites / ## 2. Clean tree and branch
fresh && run 1 1          # ok git / ok jq / ok node / ok gh / ok node <v>=20+>
run 1 2                   # toplevel == pwd -P (both /private/var/…/p), then $W/origin.git
mkdir -p "$W/bin" && ln -s "$(command -v git)" "$W/bin/git" && printf '#!/bin/sh\necho 18.19.0\n' > "$W/bin/node" && chmod +x "$W/bin/node"
(cd "$W/p" && snip 1 1 | PATH="$W/bin" /bin/bash)   # ok git / missing jq / ok node / missing gh / old node 18.19.0
run 2 1                   # (empty) / (empty) / ref: refs/heads/main<TAB>HEAD + a sha line / main
run 2 3 's/<default_branch>/main/' && git -C "$W/p" branch --show-current                     # chore/aew-init
run 2 3 's/<default_branch>/main/' && git -C "$W/p" rev-list --count main..chore/aew-init     # "Already on" message, "restarted chore/aew-init from main" (no commits yet: HEAD is an ancestor of main), then 0
git -C "$W/p" commit -q --allow-empty -m work && run 2 3 's/<default_branch>/main/' && git -C "$W/p" rev-list --count main..chore/aew-init   # reused: 1
# fully merged: fast-forward main past the branch without git merge, then re-run -> restarted
git -C "$W/p" branch -f main chore/aew-init && git -C "$W/p" switch -q main && git -C "$W/p" commit -q --allow-empty -m after   # branch -f from chore/aew-init: git refuses to force the checked-out branch
run 2 3 's/<default_branch>/main/' && test "$(git -C "$W/p" rev-parse chore/aew-init)" = "$(git -C "$W/p" rev-parse main)" && echo same   # restarted chore/aew-init from main / same
# diverged: a branch commit main lacks plus a main commit the branch lacks -> stops
git -C "$W/p" commit -q --allow-empty -m work2 && git -C "$W/p" switch -q main && git -C "$W/p" commit -q --allow-empty -m other
(run 2 3 's/<default_branch>/main/'; echo "exit $?") | tail -2     # chore/aew-init is older than main: … / exit 1
git -C "$W/p" switch -q chore/aew-init
touch "$W/p/stray.txt" && run 2 2      # ?? stray.txt   (the skill text says this stops init)
claude plugin validate "$REPO"          # ✔ Validation passed
```

The default-branch check shows the `ls-remote` fallback (the scratch repo has no `origin/HEAD`). `git -C "$W/p" remote set-head origin -a && run 2 1` then shows `origin/main` on line 2.

**Step 4: commit.**

```
feat(skills): add the init skill with prerequisite and branch steps

/aew:init (disable-model-invocation) checks git, gh auth, jq and Node 20+
with install hints and never installs global tools, requires a clean tree
(or an interrupted init's own files), and creates or switches to
chore/aew-init from the default branch.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task D2 — Gitignore, detection and command discovery (AC-26, AC-28 gitignore half, AC-24 stack tools)

- **id:** D2
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D1]
- **pattern:** the `detect-stack.sh` contract (drop `evidence`, as `docs/superpowers/project-map.md` records); ui-qa §2's lock-file-to-package-manager rule (reuse it, don't restate a different one); spec Assumption 23.
- **ACs:** AC-26 (detection and discovery), AC-28 (`.gitignore`), AC-24 (stack-tool warnings)
- **Risk:** NOT RISKY.

**Step 1: RED.** `grep -c '^## 3\. Gitignore$\|^## 4\. Detect and discover$' skills/init/SKILL.md` → `0`.

**Step 2: write.**

- **§3 Gitignore** (before any scratch file is written, so `.aew/runs/` is ignored from here on):
  ```sh
  touch .gitignore
  for l in '.aew/runs/' '.playwright-mcp/'; do
    if grep -qxF "$l" .gitignore; then echo "present $l"; else
      if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then echo >> .gitignore; fi
      echo "$l" >> .gitignore; echo "added $l"
    fi
  done
  ```
  Exact-line match, so each line appears once. A missing final newline is repaired before appending. Nothing else in the file changes (Assumption 25).
- **§4 Detect and discover.**
  - Stacks: `"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" . | jq -c 'map(del(.evidence))'`. A non-zero exit stops init and quotes the `error:` line. `[]` stops init: "no supported stack detected; aew needs at least one (nextjs, react, laravel, wordpress, dotnet, with tailwind and woocommerce overlays)". The schema requires `minItems: 1`, so the config could never validate.
  - A **discovery table** (one row per source → config field, value, and certain or inferred):
    - `package.json` scripts (`jq -r '.scripts // {} | keys[]' package.json` in each stack path that has one). The package manager comes from the lock file, per ui-qa §2 (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, otherwise npm). Each script is mapped as `<pm> run <script>`: `dev` → dev; `build` → build; `lint` → lint; `format`, `format:check` → format; `typecheck`, `type-check` → typecheck; `test`, `test:unit` → test_unit; `test:e2e`, `e2e` → test_e2e; `seed`, `db:seed` → seed. All of these are certain. `install` is `npm ci` with a `package-lock.json` (certain) or `<pm> install` (certain when the lock file names the manager, inferred when there is no lock file).
    - `tsconfig.json` with no typecheck script → `npx tsc --noEmit` (inferred).
    - `@playwright/test` in a `package.json` → `test_e2e: npx playwright test` when there is no e2e script (certain).
    - `composer.json` scripts (`jq -r '.scripts // {} | keys[]' composer.json`): `test` → test_unit `composer test`; `lint` → lint; `format` → format; `analyse`, `phpstan` → typecheck. `install: composer install`. All certain.
    - `artisan` → test_unit `php artisan test` when there is no composer test script, seed `php artisan db:seed`. App: `php artisan serve`, `http://127.0.0.1:8000`, `native` (inferred).
    - `.wp-env.json` → app `env_type: wp-env`, start `npx wp-env start`, `base_url` `http://localhost:<port, default 8888>`, ready_check = base_url.
    - `.ddev/config.yaml` → `env_type: ddev`, start `ddev start`, `base_url` `https://<name>.ddev.site` (from its `name:`).
    - `*.csproj` (depth ≤ 3): build `dotnet build`; test_unit `dotnet test` when a `*Tests.csproj` exists; format `dotnet format --verify-no-changes`. App: start `dotnet run --project <web csproj>`, `base_url` from `Properties/launchSettings.json` (first `http://` applicationUrl) else `http://localhost:5000` (inferred), `native`.
    - `docker-compose.yml`/`compose.yaml` with no wp-env or ddev → `env_type: docker`, start `docker compose up -d` (inferred).
    - wordpress/woocommerce with no `.wp-env.json`, `.ddev/` or compose file → `env_type: local` (a Local-style site), `base_url: http://<project>.local`, empty `start_command`, `ready_check` = base_url. All inferred, so asked in §5.
    - nextjs → `http://localhost:3000`; react (Vite) → `http://localhost:5173`. Start is the `dev` command, ready_check = base_url, `env_type: native`. Inferred unless a script pins a port.
    - No app at all → `env_type: none`, `base_url: http://localhost`, empty `start_command` and `ready_check` (inferred).
    - `project`: the root `package.json` `name`, else the `composer.json` `name` after the `/`, else the first `.csproj` basename, else the directory name. Certain when found in a manifest.
    - `default_branch` from §2. `retro.repo` = `jamesborg2012/claude-agentic-engineer-workflow` (inferred, Assumption 23).
    - Commands that aren't found are left out (the schema has no required command keys).
  - **Stack tools** (warn, never stop): nextjs/react/tailwind → the package manager's binary; laravel → `php`, `composer`; wordpress/woocommerce → `php`, `composer`, and `docker` when `.wp-env.json` or `.ddev/` exists; dotnet → `dotnet`. Checked with `command -v`. A missing tool is a warning in the report with an install hint, nothing is installed, and init goes on.
  - **UI project** (used by §5 and §10): a detected nextjs, react, tailwind, wordpress or woocommerce profile, or a `pages/`, `app/`, `resources/views/` or `wp-content/themes/` directory.
  - Section closes with: "Put the proposal together in schema key order (`project`, `default_branch`, `stacks`, `commands`, `app`, `retro`; commands in schema order) with only these six keys. The optional sections (`ui`, `git`, `gates`, `limits`, `evidence`, `claude_md`) keep their schema defaults until someone edits the config."

**Reference proposal for the fixture** (D3, D6 and Phase F compare against it):

```json
{
  "project": "fixture-nextjs-tailwind",
  "default_branch": "main",
  "stacks": [
    { "profile": "nextjs", "path": ".", "version": "16.0.1" },
    { "profile": "tailwind", "path": ".", "version": "4.1.0" }
  ],
  "commands": {
    "install": "npm install",
    "dev": "npm run dev",
    "build": "npm run build",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit"
  },
  "app": {
    "base_url": "http://localhost:3000",
    "start_command": "npm run dev",
    "ready_check": "http://localhost:3000",
    "env_type": "native"
  },
  "retro": { "repo": "jamesborg2012/claude-agentic-engineer-workflow" }
}
```

The inferred values here are `install` (no lock file), `typecheck`, the four `app` values and `retro.repo`. A UI project without Playwright also gets the Playwright offer in §5.

**Step 3: GREEN.**

```sh
. "${TMPDIR%/}/aew-init-env.sh"
fresh && run 3 && run 3                 # added .aew/runs/ / added .playwright-mcp/ ; then present … twice
grep -cxF '.aew/runs/' "$W/p/.gitignore"; grep -cxF '.playwright-mcp/' "$W/p/.gitignore"   # 1 / 1
tail -c 1 "$W/p/.gitignore" | od -c | head -1      # \n
printf 'node_modules/' > "$W/p/.gitignore" && run 3 && cat "$W/p/.gitignore"   # node_modules/ then the two lines, each on its own line
(cd "$W/p" && "$REPO/scripts/detect-stack.sh" . | jq -c 'map(del(.evidence))')
#   [{"profile":"nextjs","path":".","version":"16.0.1"},{"profile":"tailwind","path":".","version":"4.1.0"}]
(cd "$W/p" && jq -r '.scripts // {} | keys[]' package.json)   # build / dev / lint
grep -c 'ui-qa' "$REPO/skills/init/SKILL.md"                   # >= 1 (package-manager rule reused, not restated differently)
claude plugin validate "$REPO"                                 # ✔ Validation passed
```

**Step 4: commit.** `feat(skills): init ignores run state and discovers stacks and commands` (body: gitignore lines once each; detect-stack without evidence; the discovery table; stack-tool warnings; the trailer).

---

### Task D3 — One question round, write and validate the config (AC-26 confirm, AC-27)

- **id:** D3
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D2]
- **pattern:** the CLAUDE.md `ajv` command; spec AC-8's AskUserQuestion conventions (recommended answer first, label ending "(recommended)", batch if the tool's schema caps a call), restated in one line here because Phase B's `gates.md` is not a dependency of this phase; Assumption 24 (existing values win).
- **ACs:** AC-26 (one round, defaults when headless, listed in the report), AC-27
- **Risk:** NOT RISKY.

**Step 1: RED.** `grep -c '^## 5\. \|^## 6\. ' skills/init/SKILL.md` → `0`.

**Step 2: write.**

- **§5 Confirm in one question round.**
  - Write the detected proposal (from §4) to `.aew/runs/init-config.json` with the Write tool first (`.aew/runs/` is ignored since §3); the snippet below reads it.
  - Print the whole proposal. Mark certain values "found in the repo" and inferred values "inferred".
  - On a re-run, run this next and print what it shows (the existing value is kept, never overwritten):
    ```sh
    jq -r --slurpfile p .aew/runs/init-config.json '. as $e | $p[0] as $q
      | ($q | del(.stacks) | paths(scalars) as $x
         | select(($e | getpath($x)) != null and ($e | getpath($x)) != ($q | getpath($x)))
         | "\($x | map(tostring) | join(".")): keeping \($e | getpath($x) | tojson), detected \($q | getpath($x) | tojson)"),
        ($q.stacks[] as $s | ([$e.stacks[] | select(.profile == $s.profile and .path == $s.path)] | first) as $o
         | if $o == null then "stacks: adding \($s.profile) at \($s.path) (\($s.version))"
           elif $o.version != $s.version then "stacks: keeping \($s.profile) at \($s.path) version \($o.version), detected \($s.version)"
           else empty end)' .aew/config.json
    ```
    Stacks are compared by `(profile, path)`, not by array index, so a newly detected stack is reported as an addition.
  - Ask **one** AskUserQuestion round. It covers only the inferred values that are not already in the existing config, plus the Playwright offer when §4 found a UI project and no `@playwright/test`. Each question puts the recommended answer first, with its label ending "(recommended)", and offers one or two alternatives. The user can always type their own through "Other". The Playwright question is "Set up Playwright and axe for UI QA now? This installs `@playwright/test` and `@axe-core/playwright` as dev dependencies and downloads Chromium." It recommends **skip**: QA sets Playwright up on first use (ui-qa §2), and nothing gets installed without a yes. If the tool's schema caps questions or options per call, split the round over as many calls as needed. That still counts as one round. Nothing to ask → no call.
  - Headless or no answer: use the recommended values (Playwright skipped) and list them under "Defaults used" in the report.
  - Write the final proposal (with the answers or defaults) over `.aew/runs/init-config.json` with the Write tool.
- **§6 Write and validate the config.** Two snippets:
  ```sh
  mkdir -p .aew
  if [ -f .aew/config.json ]; then
    jq --slurpfile p .aew/runs/init-config.json '. as $e | ($p[0] * $e) | .stacks = $e.stacks + [$p[0].stacks[] | select([.profile, .path] as $k | all($e.stacks[]; [.profile, .path] != $k))]' .aew/config.json > .aew/runs/init-config-merged.json
  else
    jq . .aew/runs/init-config.json > .aew/runs/init-config-merged.json
  fi
  if [ -f .aew/config.json ] && jq -e --slurpfile m .aew/runs/init-config-merged.json '. == $m[0]' .aew/config.json > /dev/null; then
    echo "config unchanged"
  else
    echo "config changed"
  fi
  ```
  ```sh
  npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json" -d .aew/runs/init-config-merged.json && cp .aew/runs/init-config-merged.json .aew/config.json && echo "config written"
  ```
  The prose around them says:
  - `$p[0] * $e` is a recursive merge where the existing file wins. Missing fields from the proposal are added, and nothing is removed or duplicated. `stacks` is a union keyed by `(profile, path)`: every existing entry is kept as it is (its version included), and a newly detected stack is appended. Running the merge on its own output gives the same result.
  - `==` compares JSON values, not text, so a hand-formatted config that already holds every value counts as unchanged and is never rewritten.
  - Run the second snippet only on "config changed". An invalid result stops init before §7 with ajv's errors. The live `.aew/config.json` is untouched, because only the scratch copy was validated.
  - `jq .` output (two-space indent, the proposal's key order) is the stable format.

**Step 3: GREEN.** Write the D2 reference proposal to `$W/ref.json` first.

```sh
. "${TMPDIR%/}/aew-init-env.sh"
fresh && run 3 > /dev/null && cp "$W/ref.json" "$W/p/.aew/runs/init-config.json"
run 6 1                                     # config changed
run 6 2 | tail -1                           # .aew/runs/init-config-merged.json valid / config written
shasum -a 256 "$W/p/.aew/config.json" > "$W/sha1"
run 6 1                                     # config unchanged      (second-run no-op)
shasum -a 256 -c "$W/sha1"                  # OK
jq '.app.base_url = "http://localhost:3001" | del(.commands.lint)' "$W/p/.aew/config.json" > "$W/e.json" && cp "$W/e.json" "$W/p/.aew/config.json"
run 5 1                                     # app.base_url: keeping "http://localhost:3001", detected "http://localhost:3000"
run 6 1 && run 6 2 > /dev/null && jq -c '[.app.base_url, .commands.lint]' "$W/p/.aew/config.json"   # config changed, then ["http://localhost:3001","npm run lint"]
jq '.stacks = [.stacks[0] | .version = "15.0.0"]' "$W/p/.aew/config.json" > "$W/e.json" && cp "$W/e.json" "$W/p/.aew/config.json"   # drop tailwind, older nextjs
run 5 1 | grep '^stacks'                    # stacks: keeping nextjs at . version 15.0.0, detected 16.0.1 / stacks: adding tailwind at . (4.1.0)
run 6 1 && run 6 2 > /dev/null && jq -c '.stacks' "$W/p/.aew/config.json"   # config changed, then [{"profile":"nextjs","path":".","version":"15.0.0"},{"profile":"tailwind","path":".","version":"4.1.0"}]
run 6 1                                     # config unchanged (the union is idempotent)
jq '.app.env_type = "bogus"' "$W/ref.json" > "$W/p/.aew/runs/init-config.json" && rm "$W/p/.aew/config.json"
run 6 1 && (run 6 2; echo "exit $?") | tail -2; test -f "$W/p/.aew/config.json"; echo "present=$?"   # invalid … exit 1 ; present=1
git -C "$W/p" status --porcelain --untracked-files=all   # only .gitignore (scratch files are ignored)
```

**Step 4: commit.** `feat(skills): init confirms inferred config values once and validates the config` (body: one round with recommended answers, headless defaults; recursive merge where existing values win; semantic no-op; scratch-copy validation; the trailer).

---

### Task D4 — Labels, Playwright setup, CLAUDE.md section (AC-28 labels, AC-29, AC-30)

- **id:** D4
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D3]
- **pattern:** `gh-labels.sh --help` ("run ensure once before stage or flag"); ui-qa §2 (setup steps, gitignore lines), reused by reading it, never restated; the claude-md-curation skill's terse style for the section text.
- **ACs:** AC-28 (`gh-labels.sh ensure`), AC-29, AC-30
- **Risk:** NOT RISKY (any install happens only on an explicit yes).

**Step 1: RED.** `grep -c '^## 7\. \|^## 8\. \|^## 9\. ' skills/init/SKILL.md` → `0`.

**Step 2: write.**

- **§7 Labels.** One ```sh block: `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-labels.sh" ensure`. It's idempotent on GitHub's side (`--force`) and runs on every init. A failure stops init before the commit and quotes the error ("is `origin` a GitHub repo you can write to?").
- **§8 Playwright setup.** Only when §5's offer was answered yes. Read `${CLAUDE_PLUGIN_ROOT}/skills/ui-qa/SKILL.md` §2 with the Read tool and follow it: install with the lock file's manager, exact-pinned; `npx playwright install chromium`; the gitignore lines (append the missing ones with the §3 snippet's pattern); `playwright.config.ts` from ui-qa §4; `<ui.e2e_dir>/aew.ts` from ui-qa §6 and §7. The files go into init's commit, not a QA cycle commit. Then add `commands.test_e2e: npx playwright test` to `.aew/runs/init-config.json` for a root package, and re-run §6. Skipped (no, headless, no answer, not a UI project, or Playwright already present) → report "Playwright: skipped (QA sets it up on first use)" or "present".
- **§9 CLAUDE.md section.**
  ```sh
  [ -f CLAUDE.md ] || printf '# CLAUDE.md\n' > CLAUDE.md
  if grep -qxF '## Agentic workflow' CLAUDE.md; then echo "CLAUDE.md section present"; else
    if [ -n "$(tail -c 1 CLAUDE.md)" ]; then echo >> CLAUDE.md; fi
    cat >> CLAUDE.md << 'EOF'

  ## Agentic workflow

  Issues are shipped with the aew plugin. Agents follow the stack standards in `docs/standards/` and
  record each shipped issue's final spec in `docs/specs/`. Settings are in `.aew/config.json`; run state
  in `.aew/runs/` is gitignored.

  - `/aew:ship <issue> [--auto]`: spec, plan, build, review, QA, docs and PR for one issue.
  - `/aew:resume [<run-id>]`, `/aew:status [<run-id>]`: continue or inspect a run.
  - `/aew:prompt <issue>`: spec analysis and a single build prompt, no pipeline.
  - `/aew:init`: re-run after the stack changes; it only adds what is missing.
  EOF
    echo "CLAUDE.md section added"
  fi
  ```
  The exact-heading check means the section is never duplicated. An existing section is left as it is, even if it was edited.

**Step 3: GREEN.**

```sh
. "${TMPDIR%/}/aew-init-env.sh"
fresh && run 7 && wc -l < "$GH_MOCK_DIR/calls.log"                 # 11 (gh-labels.sh: ensured 11 labels on stderr)
grep -c '^label create aew:' "$GH_MOCK_DIR/calls.log"              # 11
run 9 && run 9                                                     # CLAUDE.md section added / CLAUDE.md section present
grep -cxF '## Agentic workflow' "$W/p/CLAUDE.md"                    # 1
head -1 "$W/p/CLAUDE.md"                                            # # CLAUDE.md
printf '# Existing\nno newline' > "$W/p/CLAUDE.md" && run 9 && sed -n 1,4p "$W/p/CLAUDE.md"   # # Existing / no newline / (blank) / ## Agentic workflow
grep -o '`/aew:[a-z-]*' "$REPO/skills/init/SKILL.md" | sort -u      # /aew:init /aew:prompt /aew:resume /aew:ship /aew:status
grep -c 'ui-qa/SKILL.md' "$REPO/skills/init/SKILL.md"               # >= 1 (§8 reads ui-qa §2, no restated install list)
grep -c '@playwright/test@1' "$REPO/skills/init/SKILL.md"           # 0 (versions live only in ui-qa)
```

**Step 4: commit.** `feat(skills): init ensures labels, offers Playwright and adds the CLAUDE.md section` (body plus the trailer).

---

### Task D5 — Permissions proposal (AC-31, CTO-3a, cut 6)

- **id:** D5
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D4]
- **pattern:** V-7 (`docs-facts-v7.md`): put `*` only after the subcommand; `git -C d <sub>` and `git -c k=v <sub>` don't match `Bash(git <sub> *)`; compound commands must match per subcommand; deny rules aren't a security boundary. DESIGN §3: a `Bash(<abs path> *)` rule matches the quoted `"<abs path>" …` form; read-only git and `ls/cat/grep/find/head/tail/wc` are built-in no-prompt commands. The developer and qa-engineer Guardrails command families (`tests/agent-smoke/README.md` §8.3 `ALLOW` lines, minus the harness-only broad rules).
- **ACs:** AC-31
- **Risk:** **RISKY** (permissions). An accepted proposal pre-approves commands for every session and subagent in the project.
- **Rollback:** `git revert` of this task's commit removes §10, and init then proposes nothing. In a target project, the portable rules are a reviewable hunk in `.claude/settings.json` inside the init PR, so not merging the PR (or deleting the added `allow` entries) undoes them. The plugin-script rules live only in this machine's gitignored `.claude/settings.local.json`, which is never committed; deleting that file (or its added entries) undoes them. A `.claude/settings.local.json` line init added to `.gitignore` is harmless and rides in the same PR.

**Step 1: RED.** `grep -c '^## 10\. Permissions proposal$' skills/init/SKILL.md` → `0`.

**Step 2: write §10.**

- **Rules templates** (two fenced `json` blocks, in this order). `<root>` is the substituted plugin root. Each script is listed by its real name. Every rule is an exact command, or a subcommand followed by a single trailing ` *`. Block 1 is `.claude/settings.local.json` (machine-specific: absolute plugin path, username, plugin version; gitignored):
  ```json
  { "permissions": { "allow": [
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/state.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-issue.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-labels.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-milestone.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-pr.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/gh-retro.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/git-branch.sh *)",
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh *)"
  ] } }
  ```
  Block 2 is `.claude/settings.json` (portable, committed in the init PR; the config-command rules below are added to it):
  ```json
  { "permissions": { "allow": [
    "Bash(gh auth status)",
    "Bash(claude plugin list --json)",
    "Bash(git add *)", "Bash(git commit *)", "Bash(git switch *)", "Bash(git branch *)",
    "Bash(git worktree *)", "Bash(git cherry-pick *)",
    "Bash(git fetch origin <default_branch>)",
    "Bash(jq *)",
    "Bash(date +%Y-%m-%d)"
  ] } }
  ```
  `${CLAUDE_PLUGIN_ROOT}` is substituted when the skill loads, so the proposal carries the real installed path. That path changes with each plugin version: re-running init after an update adds the new rules to `.claude/settings.local.json`, and the old ones stay harmless (nothing is removed). Because they live in the local file, they never reach other cloners.
- **Rules from config**, added to the portable (`.claude/settings.json`) list:
  - `commands.install` → the exact command, no wildcard (`Bash(npm install)`), so it can't install an arbitrary package.
  - `build`, `lint`, `format`, `typecheck`, `test_unit`, `test_e2e` → `Bash(<command> *)`. `seed` gets no rule (CTO-1; see below).
  - UI project → `Bash(npx playwright test *)` and `Bash(npx playwright install chromium)`.
  - A command becomes a rule only if it's one simple command: no `&&`, `||`, `;`, `|`, `>`, `<`, `$(`, backtick or newline, and it doesn't start with `cd `, `sh `, `bash `, `env ` or a `NAME=` assignment. Anything else is listed as "not pre-approved".
  - `dev` and `app.start_command` get no rule (QA starts the app through ui-qa §3).
- **Deliberately not pre-approved** (prose, never in `Bash(…)` form, so a grep for broad rules stays meaningful):
  - `git -C <dir> …`, the sub-developers' worktree form. A wildcard before the subcommand would also match `-c core.fsmonitor=<cmd>`.
  - `git diff`, `git log`, `git show` and `git format-patch` with a wildcard, because `--output=<path>` writes files. Their read-only forms already run without a prompt.
  - `git fetch` with a wildcard (`--upload-pack=<cmd>`). Only the exact preflight form above is allowed.
  - `git push`, which goes through `git-branch.sh` only. Every other `gh` command, because only the scripts call `gh`.
  - `sh -c`, `nohup`, `cd <dir> && …`, `cp`, `curl`, `kill`, `rm -rf`, and bare `npx`, `npm` or `node`.
  - `commands.seed`, because it may reset data (CTO-1).
  - These prompt when used. Say so, plus: "These rules only cut down prompts. They are not a security boundary: the plugin's Bash guard hook is what blocks dangerous commands." Global git options sit before the subcommand, so an anchored rule can never match them. That's why no deny rules are needed (V-7).
- **Ask:** print both concrete lists, each under its target file (`.claude/settings.json`: portable, committed in the init PR; `.claude/settings.local.json`: this machine's plugin paths, gitignored), and the not-pre-approved list. Then ask one AskUserQuestion, once, before writing either file: "Write these rules to `.claude/settings.json` and `.claude/settings.local.json`?" with **Write (recommended)** and Don't write. A **no answer or headless run means don't write** either file (the ask rule). Init then reports both lists so the user can add them by hand.
- **Gitignore for the local file.** DESIGN §3 doesn't say whether Claude Code gitignores `.claude/settings.local.json`, and its own ignore handling (if any) can't be relied on for a file init writes through Bash, so init makes sure itself. `git check-ignore` honours every ignore source (`.gitignore`, `.git/info/exclude`, the user's global excludes), so a line is added only when nothing ignores the file yet, and a re-run changes nothing. This is a third, conditional line beside §3's two (AC-28's `.aew/runs/` and `.playwright-mcp/` stay exactly once each), and it is written only on a yes, so a headless run leaves `.gitignore` with §3's two lines. If the user already tracks `.claude/settings.local.json`, init leaves it alone and reports the plugin-script rules instead, so they never land in a commit.
- **Merge on yes.** Write the two concrete `{"permissions":{"allow":[…]}}` lists with the Write tool: the portable one (block 2 plus the config rules) to `.aew/runs/init-permissions.json`, the plugin-script one (block 1) to `.aew/runs/init-permissions-local.json`. Then:
  ```sh
  l=.claude/settings.local.json; t=0
  if git ls-files --error-unmatch "$l" > /dev/null 2>&1; then t=1; echo "tracked $l"
  elif git check-ignore -q "$l"; then echo "ignored $l"
  else
    if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then echo >> .gitignore; fi
    echo "$l" >> .gitignore; echo "added $l"
  fi
  merge() {
    s=$2; [ -f "$s" ] || s=/dev/null
    jq -n --slurpfile p "$1" --slurpfile e "$s" '($e[0] // {}) as $e
      | ($e.permissions.allow // []) as $a
      | $e | .permissions.allow = $a + (($p[0].permissions.allow | unique) - $a)' > .aew/runs/init-settings.json
    if [ -f "$2" ] && jq -e --slurpfile m .aew/runs/init-settings.json '. == $m[0]' "$2" > /dev/null; then
      echo "unchanged $2"
    else
      mkdir -p .claude && cp .aew/runs/init-settings.json "$2" && echo "written $2"
    fi
  }
  merge .aew/runs/init-permissions.json .claude/settings.json
  if [ "$t" = 1 ]; then echo "skipped $l (tracked)"; else merge .aew/runs/init-permissions-local.json "$l"; fi
  ```
  The ignore check runs before the local file is written, so it is never untracked-and-unignored. In each file, existing rules keep their order. New ones are appended once. `deny`, `ask` and every other key are kept as they are, and an unchanged file is never rewritten.

**Fixture reference lists** (what the model should produce for the D2 proposal; `<root>` = the plugin root). Local (`.claude/settings.local.json`): the eight script rules. 8 rules. Portable (`.claude/settings.json`): `Bash(gh auth status)`, `Bash(claude plugin list --json)`, the six git rules, `Bash(git fetch origin main)`, `Bash(jq *)`, `Bash(date +%Y-%m-%d)`, `Bash(npm install)`, `Bash(npm run build *)`, `Bash(npm run lint *)`, `Bash(npx tsc --noEmit *)`, `Bash(npx playwright test *)`, `Bash(npx playwright install chromium)`. 17 rules. (25 in all: the earlier "26-rule" total was a miscount of this same list.)

**Step 3: GREEN.** Write the 17-rule portable list to `$W/perm.json` and the 8-rule local list (with `<root>` = `$REPO`) to `$W/perm-local.json`, each as `{"permissions":{"allow":[…]}}`.

```sh
. "${TMPDIR%/}/aew-init-env.sh"
# neutralise the user's global excludes (some machines already carry **/.claude/settings.local.json there) so the expectations below hold anywhere
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null
anchored() { jq -r '.permissions.allow[]' "$1" | awk '{x=$0; sub(/^Bash\(/,"",x); sub(/\)$/,"",x); n=gsub(/\*/,"*",x)
  if (n>1 || (n==1 && x !~ / \*$/)) print "BAD wildcard: " $0
  if (x ~ /^(git -C|git -c|git --|sh |bash |cd |cp |curl |npx \*|npm \*|node \*)/ || x ~ /^git (diff|log|show|format-patch|push)( |$)/ || x ~ /^git fetch .*\*/) print "BAD rule: " $0 }'; }
for f in perm perm-local; do anchored "$W/$f.json"; done                       # (no output)
jq '.permissions.allow | length' "$W/perm.json" "$W/perm-local.json"            # 17 / 8
jq -r '.permissions.allow[]' "$W/perm.json" | grep -c '/scripts/'               # 0 (no machine path in the portable list)
jq -r '.permissions.allow[]' "$W/perm-local.json" | grep -vc "^Bash($REPO/scripts/"   # 0 (only plugin scripts in the local list)
for k in 1 2; do awk -v k=$k '/^## 10\. /{f=1} f&&/^## 11\. /{exit} f&&/^```json$/{c++; if(c==k)b=1; next} b&&/^```$/{exit} b' "$REPO/skills/init/SKILL.md" | sed 's#${CLAUDE_PLUGIN_ROOT}#/root#g; s/<default_branch>/main/g' > "$W/tpl$k.json" && jq -e . "$W/tpl$k.json" > /dev/null && anchored "$W/tpl$k.json"; done   # both templates parse, (no output)
grep -c '/scripts/' "$W/tpl2.json"; jq '.permissions.allow | length' "$W/tpl1.json"   # 0 / 8
grep -cE 'Bash\((git -C|sh -c|cp \*|npx \*\)|cd \*|curl|git (diff|log|show|format-patch|push))' "$REPO/skills/init/SKILL.md"   # 0
grep -c 'not a security boundary' "$REPO/skills/init/SKILL.md"                  # 1
fresh && run 3 > /dev/null && cp "$W/perm.json" "$W/p/.aew/runs/init-permissions.json" && cp "$W/perm-local.json" "$W/p/.aew/runs/init-permissions-local.json"
mkdir -p "$W/p/.claude" && printf '{"model":"opus","permissions":{"allow":["Bash(jq *)","Bash(make *)"],"deny":["Bash(rm -rf *)"]}}' > "$W/p/.claude/settings.json"
run 10   # added .claude/settings.local.json / written .claude/settings.json / written .claude/settings.local.json
run 10   # ignored .claude/settings.local.json / unchanged .claude/settings.json / unchanged .claude/settings.local.json
jq -c '[.model, .permissions.deny, (.permissions.allow|length), (.permissions.allow[:2]), (.permissions.allow|map(select(.=="Bash(jq *)"))|length)]' "$W/p/.claude/settings.json"
#   ["opus",["Bash(rm -rf *)"],18,["Bash(jq *)","Bash(make *)"],1]
jq -c '[keys, (.permissions.allow|length)]' "$W/p/.claude/settings.local.json"   # [["permissions"],8]
for l in '.aew/runs/' '.playwright-mcp/' '.claude/settings.local.json'; do grep -cxF "$l" "$W/p/.gitignore"; done   # 1 / 1 / 1 (AC-28's two lines still once each)
git -C "$W/p" status --porcelain --untracked-files=all -- .claude/               # ?? .claude/settings.json (the local file is ignored)
rm -r "$W/p/.claude" && run 10 && jq -c 'keys, (.permissions|keys)' "$W/p/.claude/settings.json" "$W/p/.claude/settings.local.json"   # ignored … / written … twice / ["permissions"] / ["allow"] for each
# already ignored elsewhere (e.g. Claude Code or the user): no .gitignore line
fresh && run 3 > /dev/null && cp "$W/perm.json" "$W/p/.aew/runs/init-permissions.json" && cp "$W/perm-local.json" "$W/p/.aew/runs/init-permissions-local.json"
echo '.claude/settings.local.json' >> "$W/p/.git/info/exclude" && run 10 && grep -c 'settings.local' "$W/p/.gitignore"   # ignored … / written … twice / 0
# tracked by the user: left alone
fresh && run 3 > /dev/null && cp "$W/perm.json" "$W/p/.aew/runs/init-permissions.json" && cp "$W/perm-local.json" "$W/p/.aew/runs/init-permissions-local.json"
mkdir -p "$W/p/.claude" && echo '{}' > "$W/p/.claude/settings.local.json" && git -C "$W/p" add .claude/settings.local.json && git -C "$W/p" commit -qm local
run 10 && cat "$W/p/.claude/settings.local.json"   # tracked … / written .claude/settings.json / skipped .claude/settings.local.json (tracked) / {}
```

Also confirm that the §10 prose says no answer means neither file is written, and that it prints both lists in that case (`grep -n "Don't write" skills/init/SKILL.md`).

**Step 4: commit.**

```
feat(skills): init proposes anchored project permissions

Shows both files and asks once before writing either. The portable rules
go in the committed .claude/settings.json: gh auth status, git add/commit/
switch/branch/worktree/cherry-pick, the exact preflight fetch, jq, and the
config's commands (install exact, the rest with one trailing wildcard;
seed gets no rule because it may reset data). Each plugin script by its
absolute path goes in .claude/settings.local.json, which init makes sure
is gitignored (git check-ignore first, so nothing is added twice), so this
machine's paths never reach other cloners. No rule has a wildcard before a
subcommand, so git's global -c/-C/--git-dir forms and diff/log/show
--output never match; no deny rules are needed. Each file is merged
without duplicates; neither is written without a yes. CTO-3a.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task D6 — Standards, commit/push/PR, report, and the two-pass idempotency check (AC-32, AC-33)

- **id:** D6
- **files:** `skills/init/SKILL.md`
- **depends_on:** [D5, A2, A3]. A2 = standards-setter `mode: init` (Phase A C-2), A3 = `gh-pr.sh open` (Phase A C-3). The consolidator should check these ids against the assembled plan.
- **pattern:** Phase A C-2 (dispatch exactly `mode: init`; return block in the final message only; ARTEFACTS `docs/standards/README.md` then profile docs, or `none`), C-3 (`open <branch> <title> <body-file> [--base <branch>]`, caller pushes first, prints one PR number, reuses an open PR); `gate-subagent.sh` `valid_return_block` for the return check; `git-branch.sh push`; spec AC-32 as amended by cut 9.
- **ACs:** AC-32, AC-33
- **Risk:** NOT RISKY (it pushes only `chore/aew-init`, never the default branch, which `git-branch.sh push` and the Bash guard also refuse).

**Step 1: RED.** `grep -c '^## 1[123]\. ' skills/init/SKILL.md` → `0`. Also `"$REPO/scripts/gh-pr.sh" --help | grep -c '^  open <branch>'` is `1` (top-level `--help`: C-3 rejects an unknown option after `open`) (A3 has merged; if it's `0`, stop: the dependency hasn't landed).

**Step 2: write.**

- **§11 Standards.**
  - Dispatch the Agent tool with `subagent_type: aew:standards-setter` and the prompt exactly `mode: init`.
  - Return check: the result's last four non-blank lines are `STATUS: <ok|needs_input|blocked|failed>`, `ARTEFACTS: …` (non-empty, `none` allowed), `SUMMARY: …`, `NEXT: …`, each holding a single value, not the template's `ok | needs_input | …` placeholder.
  - `ok` → continue, keeping SUMMARY's `<profile>: reused|generated|updated` list for the report.
  - `blocked`, `failed` or an invalid block → retry once, then stop before the commit and quote SUMMARY. The files written so far stay on `chore/aew-init`, and §2's exception lets the next init finish.
  - Then list what changed:
    ```sh
    git status --porcelain --untracked-files=all -- docs/standards/ .claude/agent-memory/aew-standards-setter/
    ```
  - **Memory decision (flag if wrong):** the agent's project memory is meant to be shared, so init commits `.claude/agent-memory/aew-standards-setter/` along with everything else. One exception keeps a re-run idempotent. When the memory directory is the **only** change in the whole tree (step one of §12 shows nothing else), the memory update is dropped: `git restore -- .claude/agent-memory/aew-standards-setter/` for tracked files, and `rm` of each untracked file under it. The report says "standards-setter memory update discarded (nothing else changed)".
- **§12 Commit, push and PR.**
  - Snippet 1 (its own ```sh block): `git status --porcelain --untracked-files=all`. Every path must be one of Init's files. Otherwise stop, list the strangers and commit nothing (something else changed the tree during init).
  - Changes → `git add -- <each listed path>`, then `git commit -m "chore: set up aew"`. Plain conventional message with no issue ref and no trailer (Assumption 28). Never `git add -A` or `git add .`.
  - Snippet 2 decides the push and the PR:
    ```sh
    if git rev-parse --verify --quiet refs/remotes/origin/chore/aew-init > /dev/null; then
      echo "unpushed $(git rev-list --count origin/chore/aew-init..HEAD)"
    else
      echo "unpushed $(git rev-list --count <default_branch>..HEAD)"
    fi
    echo "ahead $(git rev-list --count <default_branch>..HEAD)"
    ```
  - `unpushed` above 0 → `"${CLAUDE_PLUGIN_ROOT}/scripts/git-branch.sh" push`. This is the case when this run committed, or when an earlier run stopped after its commit.
  - `ahead` above 0 → open the PR, even when nothing was pushed this run:
    - write `.aew/runs/init-pr-body.md` with the Write tool (what init did: stacks, config created or updated, defaults used that need review, labels, gitignore, Playwright, CLAUDE.md, permissions written or only proposed, standards per profile);
    - run `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-pr.sh" open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base <default_branch>` and keep the printed number.
  - `open` reuses an open PR (one `pr list`, no create), so calling it on every run is idempotent. It also retries a PR that failed after an earlier push. A `gh-pr.sh` failure is reported with its error and leaves everything else in place, and the next run retries it.
  - `ahead` 0 (the branch holds nothing the default branch lacks) → no push and no PR call. Leave the branch checked out: cut 9 means no branch deletion, and the next run reuses or restarts it (§2).
- **§13 Report.** Remove the scratch files (`rm -f .aew/runs/init-config.json .aew/runs/init-config-merged.json .aew/runs/init-permissions.json .aew/runs/init-permissions-local.json .aew/runs/init-settings.json .aew/runs/init-pr-body.md`). Then print, in this order:
  - prerequisites and stack-tool warnings;
  - stacks;
  - config written / unchanged, plus the detected differences that were kept;
  - "Defaults used" (headless or unanswered);
  - labels ensured;
  - gitignore lines added or present;
  - Playwright set up / skipped / present;
  - CLAUDE.md section added / present;
  - permissions written / unchanged / proposed only, for `.claude/settings.json` and `.claude/settings.local.json` each (with the lists), and whether the local file's `.gitignore` line was added or already ignored;
  - standards per profile;
  - the commit sha, or "nothing changed";
  - the PR number, or none;
  - next step: "merge the PR, then `/aew:ship <issue>`".

**Step 3: GREEN.**

Static checks first, then a full two-pass dry run of every deterministic step on the fixture. It stands in for the paid I1/I2 runs: the model's parts are played by the reference files, and the standards-setter is played by writing one doc.

```sh
. "${TMPDIR%/}/aew-init-env.sh"
grep -c '^## [0-9]*\. ' "$REPO/skills/init/SKILL.md"                            # 13
wc -l < "$REPO/skills/init/SKILL.md"                                             # < 500
grep -c 'subagent_type: aew:standards-setter' "$REPO/skills/init/SKILL.md"       # 1
grep -c '`mode: init`' "$REPO/skills/init/SKILL.md"                              # >= 1
grep -c 'gh-pr.sh" open chore/aew-init' "$REPO/skills/init/SKILL.md"             # 1
grep -cE 'git add (-A|\.)( |$)' "$REPO/skills/init/SKILL.md"                     # 1 (only the "Never git add -A or git add ." line)
grep -cE 'git branch -[dD]' "$REPO/skills/init/SKILL.md"                         # 1: only the hint in §2's stop message; init never runs it (cut 9)
grep -o '\${CLAUDE_PLUGIN_ROOT}/[A-Za-z0-9_./-]*' "$REPO/skills/init/SKILL.md" | sort -u | sed "s#\${CLAUDE_PLUGIN_ROOT}#$REPO#" | while read -r f; do test -e "$f" || echo "missing $f"; done   # (no output; D-C2)
```

Write the pass to `$W/pass.sh` with the Write tool, then run it twice (`. env; fresh; bash "$W/pass.sh" > "$W/out1"; record; bash "$W/pass.sh" > "$W/out2"`):

```sh
# one init pass, deterministic steps only (headless: no Playwright, neither settings file written)
set -e
. "${TMPDIR%/}/aew-init-env.sh"
S='s/<default_branch>/main/g'
run 2 3 "$S"                                   # branch
run 3                                          # gitignore
cp "$W/ref.json" "$W/p/.aew/runs/init-config.json"
run 6 1; if [ -f "$W/p/.aew/runs/init-config-merged.json" ] && ! jq -e --slurpfile m "$W/p/.aew/runs/init-config-merged.json" '. == $m[0]' "$W/p/.aew/config.json" > /dev/null 2>&1; then run 6 2; fi
run 7 2> /dev/null                             # labels (mock)
run 9                                          # CLAUDE.md
# standards-setter stand-in: write the doc once, reuse afterwards (C-2 reused = no write)
mkdir -p "$W/p/docs/standards"; [ -f "$W/p/docs/standards/nextjs.md" ] || echo '<!-- aew:standards -->' > "$W/p/docs/standards/nextjs.md"
(cd "$W/p" && git status --porcelain --untracked-files=all)
(cd "$W/p" && if [ -n "$(git status --porcelain)" ]; then git add -- .gitignore .aew/config.json CLAUDE.md docs/standards/nextjs.md && git commit -qm "chore: set up aew" && echo committed; fi)
out=$(run 12 2 "$S"); echo "$out"
u=$(echo "$out" | sed -n 's/^unpushed //p'); a=$(echo "$out" | sed -n 's/^ahead //p')
printf 'https://github.com/acme/fixture/pull/7\n' > "$GH_MOCK_DIR/responses/pr-create.out"   # pass 1: create
printf '7\n' > "$GH_MOCK_DIR/responses/pr-list.2.out"                                      # pass 2: the lookup finds #7
if [ "$u" -gt 0 ]; then (cd "$W/p" && "$REPO/scripts/git-branch.sh" push); fi
if [ "$a" -gt 0 ]; then (cd "$W/p" && printf 'body\n' > .aew/runs/init-pr-body.md && "$REPO/scripts/gh-pr.sh" open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base main); fi
```

Expected:

- `out1`: `committed`, `unpushed 1`, `ahead 1`, `chore/aew-init`, then `7`. The mock log has 11 `label create`, one `pr list`, one `pr create … --base main --title chore: set up aew --body-file …`.
- Record `git -C "$W/p" rev-parse main chore/aew-init`, `shasum -a 256 .aew/config.json` and `wc -l < "$GH_MOCK_DIR/calls.log"` (13) between the passes.
- `out2`: `config unchanged`, `present …` twice, `CLAUDE.md section present`, an empty status listing, no `committed`, `unpushed 0`, `ahead 1`, then `7` (reused). No push.
- After pass 2: `git -C "$W/p" status --porcelain` is empty. Both heads and the config sha are unchanged. The mock log grew by exactly 12 lines: 11 `label create` and one `pr list`. `grep -c '^pr ' "$GH_MOCK_DIR/calls.log"` is `3` and `grep -c '^pr create' "$GH_MOCK_DIR/calls.log"` is still `1`. That is AC-33's evidence form, free.
- `git -C "$W/origin.git" rev-parse chore/aew-init` equals the local head (pushed to the local bare origin only).
- After each pass: neither `$W/p/.claude/settings.json` nor `$W/p/.claude/settings.local.json` exists, and `.gitignore` holds only §3's two lines (`wc -l < "$W/p/.gitignore"` is `2`; no `.claude/settings.local.json` line, which §10 adds only on a yes).

Finally: `claude plugin validate "$REPO"` → `✔ Validation passed`; `tests/run-script-tests.sh` stays green (no script changed here); `git -C "$REPO" status --porcelain` shows only `skills/init/SKILL.md` before the commit.

**Step 4: commit.**

```
feat(skills): init generates standards and opens its PR idempotently

Dispatches standards-setter in mode: init, commits only init's own files
as "chore: set up aew", pushes chore/aew-init through git-branch.sh and
opens or reuses the PR through gh-pr.sh open on every run where the branch
is ahead (so a failed PR call is retried). An unchanged repo gives no
commit, push or new PR; a memory-only standards-setter update is dropped
so a re-run changes nothing.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

## Phase verification (after D1–D6)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
claude plugin validate .                                                   # ✔ Validation passed
grep -E '^## [0-9]+\. ' skills/init/SKILL.md | wc -l                       # 13
grep -c '^disable-model-invocation: true$' skills/init/SKILL.md            # 1
wc -l < skills/init/SKILL.md                                               # < 500
tests/run-script-tests.sh                                                  # green
git log --oneline -6                                                       # the six conventional commits of D1–D6
git status --porcelain                                                     # clean apart from files of other phases
```

## AC → task matrix

| AC | Task(s) | Evidence (free, this phase) | Live evidence |
|---|---|---|---|
| AC-24 frontmatter, prerequisites, stack tools warn, no global installs, dirty tree stops | D1 (§1, §2), D2 (stack tools) | Frontmatter awk; `run 1 1` ok and fake-PATH outputs; `stray.txt` listing | Phase F I1 |
| AC-25 `chore/aew-init` created or switched to (restarted when merged, stops when diverged) | D1 | `run 2 3`: create, reuse, restart, diverged stop | I1, I2 |
| AC-26 detection, discovery (all six `env_type` values), one round, headless defaults listed | D2, D3 | detect output without `evidence`; the reference proposal; `run 5 1` difference and stack lines | I1 report's "Defaults used" |
| AC-27 written with stable format, ajv-valid, existing values win, nothing removed or duplicated, invalid stops | D3 | `run 6` sequence: changed → written, unchanged + sha, kept 3001 + re-added lint, tailwind re-added with nextjs's existing version kept, invalid → exit 1 with no file | I1 `ajv` (AC-44) |
| AC-28 `gh-labels.sh ensure`, two gitignore lines once each | D4, D2 | 11 `label create` in the mock; `grep -cxF` = 1 each | I1/I2 |
| AC-29 Playwright offer, ask before installing, no answer skipped and reported | D3 (the offer in the round), D4 (§8) | §5/§8 text greps; recommended = skip | I1 report "skipped" |
| AC-30 one `## Agentic workflow` section, never duplicated | D4 | `run 9` twice; heading count 1 | I1/I2 |
| AC-31 permissions shown and asked (both files, one question), merged without duplicates per file, no answer → neither written, anchored rules (cut 6); plugin-script rules only in gitignored `.claude/settings.local.json` | D5 | `anchored` checks on both templates and on the 17-rule portable and 8-rule local lists; no `/scripts/` rule in the portable list; merge twice per file; `.claude/settings.local.json` ignored (line added once, or already ignored, or tracked and skipped) with AC-28's two lines still once each; broad-rule grep 0 | I1 "proposed only", neither file present |
| AC-32 standards-setter `mode: init`; commit only if changed; push; `gh-pr.sh open` (no branch deletion, cut 9) | D6 | dispatch greps; pass 1 log (`pr list`, `pr create --base main`) | I1 |
| AC-33 second run changes nothing | D6 | pass 2: clean status, heads and config sha unchanged, only 11 `label create` and one `pr list` (reuse) added, no `pr create` | I2 (AC-44) |

## Cross-phase assumptions (to reconcile)

1. **Phase A (C-2, task A2):** init dispatches exactly `mode: init` with no other field. It reads the return block from the final message and treats `ARTEFACTS: none` as valid. When every fingerprint matches, nothing under `docs/standards/` is written (README included). That is what makes I2 clean. Memory may still change, and init handles that (§11 memory decision).
2. **Phase A (C-3, task A3):** init calls `gh-pr.sh open chore/aew-init "chore: set up aew" .aew/runs/init-pr-body.md --base <default_branch>` after `git-branch.sh push`. The body file is inside the project, under the gitignored `.aew/runs/`. Init relies on stdout being exactly the PR number and on a reuse making no `pr create` call.
3. **Phase B:** §10's `Bash(git fetch origin <default_branch>)` assumes ship's preflight runs exactly `git fetch origin <default_branch>` (cut 7). If B uses another form (for example a bare `git fetch`), one of the two must change so the exact rule matches. The other orchestrator commands B uses (`state.sh` and the other scripts, `jq`, `git switch`, `claude plugin list --json`, `gh auth status`) are covered. B's temp-file handling for the blocked report (Assumption 20, `mktemp`) is not pre-approved and will prompt interactively.
4. **Phase C:** `status` lists only directories under `.aew/runs/` whose names match the run-id pattern (`^[1-9][0-9]*$` or `^m-…`), so init's scratch files (removed at the end of every run, but left behind if a run is interrupted) and `current` never show up as runs.
5. **Phase E:** `skills.bats` can rely on D-C1 (13 numbered sections, frontmatter) and D-C2 (every `${CLAUDE_PLUGIN_ROOT}/…` path is real; no label names). The permissions template uses the literal `${CLAUDE_PLUGIN_ROOT}/scripts/<real name>.sh`.
6. **Phase F:** I1/I2 expectations are D-C4. The harness needs a canned `pr-create.out` with a `/pull/<n>` URL and a canned `pr-list.2.out` with that number (I2's reuse lookup), and should create the bare origin with `main` as HEAD (`git clone --bare`, or `git init --bare -b main`) so the `ls-remote` fallback finds the default branch. The I1 allowlist must cover §1–§13's commands, including `npx --yes -p ajv-cli@5 … ajv validate *`, the gitignore/CLAUDE.md snippets (`touch`, `grep`, `tail`, `printf`, `cat`, `echo` in compound form) and `rm -f .aew/runs/init-*`. DESIGN.md records init mode (§8.3) and AC-31's rule semantics in Phase F only: this phase does not edit DESIGN.

## Decisions in this phase (flag if wrong)

1. **One file, no `references/`.** The procedure is about 300–400 lines, well under the 500-line limit, and nothing else reads it (unlike ship's references, which resume reads).
2. **The Playwright offer joins the §5 question round**, so the user is asked at most twice (the config round and the permissions question). Its recommended answer is **skip**, because QA sets Playwright up on first use (ui-qa §2) and nothing installs without a yes.
3. **The config holds only the six required keys.** Optional sections stay at schema defaults (every reader already falls back to them), so a later default change in the plugin reaches the project. `config.example.json` shows the full form.
4. **Empty detection stops init.** `stacks` has `minItems: 1`, so no valid config is possible. The standards-setter's own empty-detection branch (C-2) is therefore never reached from init.
5. **Scratch files go in `.aew/runs/`** (gitignored in §3 first, inside the project), not in `mktemp` outside it. Write and `acceptEdits` cover the project, ajv sees a `.json` name, and an invalid config never reaches `.aew/config.json`.
6. **The no-op is decided on semantic equality** (`jq ==`), not bytes. A hand-formatted, already-complete config or settings file is never rewritten.
7. **An interrupted init is finished, not refused.** On `chore/aew-init`, a dirty tree made only of Init's files passes §2. Without this, any failure after the first write would block every later init until the user cleaned up by hand.
8. **The branch is created from the local default branch, with no fetch.** The init PR is a plain review: conflicts show there, and a re-run never touches the default branch. An existing `chore/aew-init` whose commits are all in the default branch (merged PR) is restarted there with `git switch -C`. One that has diverged (squash-merged or closed PR, plus new default-branch commits) stops init with a `git branch -D` / rebase hint. Init never deletes or rebases it itself.
9. **Push and PR recovery:** push when `origin` lacks the branch's commits. Call `gh-pr.sh open` whenever the branch is ahead of the default branch: `open` reuses an open PR, so this is idempotent, and it retries a PR that failed after an earlier push. A clean re-run therefore makes one `pr list` call and no `pr create`.
10. **Standards-setter memory:** committed with init's other files. A memory-only change on a re-run is discarded so AC-33 holds (coordinator item; Phase A keeps memory updates in init mode).
11. **Permissions (cut 6):** allow rules only, each exact or `<command> <subcommand> *`. `install` is exact. Read-only git needs no rule (built in). `git diff/log/show/format-patch` and `git fetch` get no wildcard. `git branch *` is allowed because the developer uses it (local refs only). The proposal says it isn't a security boundary.

## Risks

- **Permissions over-match** (RISKY, D5): a trailing wildcard on a config command (`npm run lint *`) allows any arguments to that script, which already runs project code. Mitigations: anchored rules only, no wildcard before a subcommand, `install` exact, scripts by exact path, never written without a yes, a reviewable hunk in the PR, and the Bash guard hook remains the enforcement. Rollback as in D5.
- **Model-followed procedure drift:** the model may paraphrase a snippet. The snippets are short and checked here verbatim, and I1/I2 in Phase F are the behavioural proof.
- **Standards-setter rewriting on a re-run** (README or a doc when nothing changed) would break AC-33. C-2 says it doesn't. If I2 shows a diff, the fix goes in the agent (Phase A's file), never by weakening the check.
- **ajv via `npx`** needs the npm cache or the network on first use. A failure stops init before any write to `.aew/config.json`, with ajv's message.
- **Default-branch detection** can fall through to the current branch on unusual remotes. It's then asked in §5 (headless: used and listed under "Defaults used").
- **Global `chromium` download** on a Playwright yes goes to Playwright's user cache, not a global tool install. It happens only on an explicit yes, and the question says so.

## Approval (Phase D)

- Senior architect: APPROVED 2026-10-24T23:28:05Z (plan-review FULL, then plan-diff-review of the M1–M4 revision)
- Plan format: FULL
- Dependency graph: valid. 6 waves, max width 1 (all tasks write `skills/init/SKILL.md`); D6 also depends on Phase A tasks A2 and A3 (ids confirmed).
- Risk lines crossed: permissions (D5); rollback recorded; CTO risk-gate applies to D5.
- Plan content hash (SHA-256, the doc above this trailer): 82ec56451c3ab8f788919e844d48808ab6911c7603eb1fe28f5a8e3cd6c83d3a

---

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

---

# Phase F plan — Simulated runs and closing docs

- **Spec:** `docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md` (hash `4633583…6090`), overridden where they differ by the CTO simplicity-challenge cuts (2026-10-25, all adopted). The cuts that bind this phase: **1** (no R1), **2** (R2 is killed at `review`; its evidence list), **3** (one paid bad-argument probe, straight after P0), **4** (order I1 → I2 → G1, G1 on init's output after `main` is fast-forwarded to `chore/aew-init` on the local bare origin), **5** (about $55 of caps inside the $60 stop), **10** (what the closing docs say, and the pointer instead of restating §9 detail).
- **Phase:** F of the EPIC. `depends_on: [E]`: only Phase E's static-checks task **E1** (`tests/scripts/skills.bats`) must pass; the README task (E2) runs in parallel with this phase. Inputs from other phases are listed under "Inputs consumed" below; nothing here changes their contracts except through the fix loop (a failing live check is fixed in the skill or agent that caused it).
- **Depth:** full
- **ACs covered:** AC-39, AC-40, AC-41, AC-42 (G2 only, cut 1), AC-43 (as amended by cut 2), AC-44, AC-45 (one paid probe, cut 3; the static half is E1's), AC-46, AC-47 (as shaped by cut 10). AC-35's "DESIGN §8.3 records it" clause and Phase A's C-4 (DESIGN §8.3/§8.4) land here.
- **Risk:** **real-GitHub safety of paid headless runs.** Every paid session runs the real orchestrator with Bash. The rails below are non-negotiable and are proven by a probe (P0) before any other paid run. No other risk line is crossed (no schema, auth flow, payments or dependency change; the closing edits are documentation).
- **Date:** 2026-10-25
- **Naming note:** task ids are `F1`–`F8`. Run names are the spec's (P0, S1, G1, G2, F1, R2, I1, I2) plus P0a/P0b (the two P0 sessions) and P1 (the bad-argument probe). The run called F1 is always written **"run F1"**; "Task F1" is the harness task. An attempt is suffixed `.1`, `.2` (for example `S1.1`). "Assumption n" and "AC-n" are the spec's, "cut n" the CTO cut, "I-n"/"PD-n" Phase B's contracts and decisions, "D-Cn" Phase D's, "C-n" Phase A's.

> **For agentic workers:** implement task by task. Every task records RED before and GREEN after. For the run tasks, RED is the README subsection's rows reading `pending`, and GREEN is every check in the task's table passing with the recorded output; for the doc tasks, RED/GREEN are grep counts. Paid sessions run only through `$SMOKE/ship-run.sh` (Task F1), which enforces the budget and the environment. Long sessions (S1 can take an hour) are started with the Bash tool's `run_in_background: true` and waited for, never polled in a foreground loop. Never commit transcripts, streams, debug logs or anything under `$SMOKE`.

**Goal:** prove the five entry skills in real headless Claude Code sessions with only `gh` and `origin` faked, record the evidence in `tests/agent-smoke/README.md` §9, and close the build prompt with the DESIGN, state-machine, CHANGELOG, project-map and CLAUDE.md updates.

**Architecture:** one harness section (README §9: helpers, a launcher script kept under `$SMOKE`, per-project allowlist files, expected values written before the runs), then nine paid sessions in four lanes after the P0 gate, then two doc tasks. The launcher enforces the safety environment, the explicit allowlist, `--permission-prompts none` and the $60 stop for every session, and is the only way a paid session starts. Results go into per-run README subsections, so parallel tasks edit disjoint lines; the ledger lives in `$SMOKE/ledger-05/` (one file per session, concurrency-safe) and is rendered into the README by the last task.

**Tech stack:** Claude Code CLI 2.1.308 or later (`-p`, `--output-format stream-json --verbose`, `--permission-mode acceptEdits`, `--permission-prompts none`, `--max-budget-usd`), bash 3.2, jq 1.7.1, `npx ajv-cli@5`/`ajv-formats@3`, the stateful `gh` mock `tests/scripts/helpers/bin/gh`, Node ≥ 20 with the static-shop fixture's Playwright.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| Spec ACs 39–47, Assumptions 6–9, Risks, Conflicts C1–C5, the V-1…V-7 table | What the runs prove and what DESIGN records |
| CTO cuts (scratchpad `simplicity-adopted.md`), docs facts with URLs (`docs-facts.md`, `docs-facts-v7.md`) | Binding run shape; §3 wording and URLs |
| `tests/agent-smoke/README.md` §1 (prerequisites, ledger rules), §2 (`smoke_render`), §3 (flags, `enabledPlugins`, `--add-dir`), §4 (`valid_return_block` eval, final-message and denial checks), §8.3 (`smoke_shop`, the QA phase B `ALLOW` line), 961 (developer `ALLOW` line, script-file rule, `< /dev/null`) | Patterns this phase mirrors; never re-derived |
| `tests/scripts/helpers/bin/gh`, `tests/scripts/helpers/common.bash` (`gh_mock_issue`) | Route naming (`<arg1>-<arg2>`, call-numbered `responses/<route>.<n>.out`), the stateful `issues/<n>/{base.json,body,labels}` store, `calls.log` format |
| `scripts/gh-issue.sh`, `gh-labels.sh`, `gh-pr.sh`, `gh-retro.sh`, `state.sh` (`log_line`) | Which `gh` calls each script makes (expected S1 routes); `log.md` line form `- <ts> <stage> <status> — <note>` |
| Phase B `…-phase-B.md` I-5, I-8, I-9, PD-1, PD-2, `## Gate pending` text | Pending-gate note and lookup, the commands to allow, the call order, the agent-memory rule, the gate output lines |
| Phase D `…-phase-D.md` D-C3, D-C4, cross-phase item 6, the D2 reference proposal | I1/I2 expectations, canned replies, I1 allowlist needs, the reference config |
| Phase A `…-phase-A.md` C-1, C-2, C-4 | What DESIGN §8.3/§8.4 must say |
| `docs/DESIGN.md` §3, §4, §8.3, §8.4, §8.7, §9; `skills/run-protocol/references/state-machine.md` | The text the closing tasks edit |
| `templates/artefacts/retro.md`, `manual-tests.md` | How S1's expected routes count retro items and manual tests |

Gotchas that apply (project map): temp projects live under `$SMOKE` (`${TMPDIR%/}/aew-smoke`), never inside the plugin tree; `enabledPlugins` may disable only `dev-workflow` and `figma`; the dev-workflow and aew Bash guards block any command whose text contains `git push`, so launches and multi-step harness actions go in script files written with the Write tool; `smoke_use` does not clear `$O` (this phase's launcher refuses an existing output dir instead); in zsh run `setopt interactivecomments` first and quote separators; macOS `/var` is `/private/var`; `grep -c` exits 1 on a zero count; `jq -Rs` is unsafe for multi-byte text (use `fromjson?` per line).

## Real-GitHub safety rails (non-negotiable; every paid session)

1. **The `gh` shim is first on `PATH`** for the session (`$REPO/tests/scripts/helpers/bin`), with `GH_MOCK_DIR` set. The shim fails closed without `GH_MOCK_DIR` (exit 99).
2. **`GH_TOKEN`, `GITHUB_TOKEN`, `GH_ENTERPRISE_TOKEN` and `GITHUB_ENTERPRISE_TOKEN` are unset** (`env -u`), because an env token authenticates a real `gh` regardless of its config dir.
3. **`GH_CONFIG_DIR` is an empty directory** (`$W/ghcfg`), so a real `gh` reached by mistake is unauthenticated. After every run `ls -A "$W/ghcfg"` must print nothing. **`GH_HOST=aew-smoke.invalid`** is set as well, because on macOS `gh` can keep its token in the keychain, which an empty config dir may not hide: with it, a real `gh` resolves every `OWNER/REPO` and its token lookup to a host that doesn't exist. Task F1 proves both for free (`gh auth token` fails).
4. **`origin` is a local bare repo** (`$W/origin.git`, HEAD `main`), so nothing can be pushed anywhere else and a repo-inferred `gh` call can't resolve a GitHub repo.
5. **`gh auth status` is the canary.** It is the orchestrator's first `gh` call (Assumption 9). With rails 2–3 a real `gh` fails it and preflight stops before any write. Task F1 proves that outside any session, for free.
6. **`retro.repo` is the fake `acme/aew-retro`** in every config a session reads: the static-shop copy (overridden before its fixture commit) and the init-produced nextjs config (overridden after I2, before G1). Issue URLs are `acme/…`.
7. **One explicit allowlist per project**, built by `smoke_ship_allow`: no `gh` rule except exactly `Bash(gh auth status)`, plus exactly `Bash(claude plugin list --json)`; `--permission-mode acceptEdits`; `--permission-prompts none`, so anything unlisted is denied and AskUserQuestion is absent. **Never `bypassPermissions`.**
8. **P0 runs first.** It proves rails 1–4 and 7 from inside a session (the session's own Bash, the `system/init` event). **Any P0 failure stops every paid run** until it is fixed and P0 re-run. P0 is also re-run whenever the launcher's environment lines change.

## Inputs consumed from other phases (read their interface sections only)

- **Phase B.** I-8 (commands ship runs) gives the orchestrator part of the allowlist; the `$(jq …)` title substitution (3.5) Phase B flagged is checked in P0a (analogue) and S1 (`permission_denials` must be `[]`). The other flagged form, the `mktemp` + `cat > <tmpfile> <<'EOF'` blocked comment, is **settled here instead of probed** (Decision 11, reconciliation for Phase B): ship writes the comment with the Write tool to `.aew/runs/blocked-<id>.md`, the gitignored flat-file form Phase D already uses for init's scratch files (R-6), outside every run dir so Assumption 20 still holds. P0a check 8 proves that Write form. I-9 (call order) is the source of `expected_s1`. I-5/PD-1: pending gates write `gate:<id> <file>` notes, found with the I-5 `jq` lookup; `## Gate pending` prints `aew ship #<n>: waiting at the <gate-id> gate.`, then the questions or plan summary, then `Answer with /aew:resume <id>`. PD-2: `.claude/agent-memory/` changes are tolerated by `--from` and resume, and committed at the docs stage. **If the merged Phase B text differs from these strings, the merged text wins: update the expected values in README §9 before the run that uses them, never after.**
- **Phase C.** R2 runs `/aew:resume 201`, which must Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and enter `## Stage: develop` (AC-21), never invoke `ship` through the Skill tool.
- **Phase D.** D-C4 is I1/I2's expectation list (as merged). Current text: I1 makes 11 `label create`, one `pr list` and one `pr create --base main`; I2 makes 11 `label create`, exactly one `pr list` (reuse, answered by a canned `pr-list.2.out`) and no push and no `pr create`. The D2 reference proposal is I1's expected config. D-C3 lists init's files and its `.aew/runs/init-*` scratch files.
- **Phase A.** C-1 (`notes`) and C-2 (`mode: init`) are what DESIGN §8.4 and §8.3 record (C-4).
- **Phase E.** E1's `skills.bats` is the static half of AC-45 (the error strings) and of cut 1 (resume names the pending-gate re-ask); it must pass before Task F2.

## Run matrix

| run | task | project (`$SMOKE/ship-<name>`) | prompt | model | cap (USD) | ACs |
|---|---|---|---|---|---|---|
| P0a | F2 | `p0` (static-shop) | Bash probe (fixed text, Task F2) | haiku | 0.50 | 39 |
| P0b | F2 | `p0` | `/aew:status` | default | 0.50 | 39 |
| P1 | F2 | `p0` | `/aew:ship 201 --from nowhere` | default | 1 | 45 |
| G2 | F4 | `g2` (static-shop) | `/aew:ship 201` | default | 8 | 42 |
| I1 | F6 | `init` (nextjs-tailwind) | `/aew:init` | default | 3 | 44 |
| I2 | F6 | `init` | `/aew:init` | default | 3 | 44 |
| G1 | F6 | `init` (after the fast-forward) | `/aew:ship 103 --auto` | default | 3 | 41 |
| S1 | F3 | `s1` (static-shop) | `/aew:ship 201 --auto` | default | 25 | 40 |
| run F1 | F5 | `g2` | `/aew:ship 201 --auto --from develop` (killed) | default | 2 | 43 |
| R2 | F5 | `g2` | `/aew:resume 201` (killed) | default | 10 | 43 |
| **total** | | | | | **56** | |

Caps sum to $56, inside the $60 stop (cut 5's "about $55"), leaving $4 for a re-probe or one small re-run. Killed sessions emit no `result` event, so the ledger counts their cap as their cost (conservative). Expected actual spend is about $25–30 (prompt-04 agent runs cost $0.3–1.1 each; S1 runs every agent once plus one QA fix cycle and the main thread).

**Waves:** 1 = Task F1 ∥ Task F7 · 2 = Task F2 (the P0 gate) · 3 = Task F4 (G2) ∥ Task F6 (I1, I2, G1) · 4 = Task F3 (S1) ∥ Task F5 (run F1, R2) · 5 = Task F8. At most two paid sessions run at once (Task F5 also waits for Task F6, so a ready-as-soon-as-possible dispatcher can't run S1, Task F6's tail and run F1 together), and only S1 uses port 4173 (run F1 and R2 are killed before `qa`). S1 waits for G2 on purpose: G2 is the $8 canary for the spec → plan prefix that S1 repeats at $25.

**Fix loop (AC-46, every run task).** A failing check is classified first. *Harness fault* (wrong command, missing allow rule, seed): fix README §9 and the helper, re-run; a missing allow rule gets the narrowest matching rule, recorded with the denied command verbatim. *Skill or agent fault*: fix the file that caused it (`skills/{ship,resume,status,prompt,init}/**`, `agents/*.md`, or a script with a bats test), commit `fix(skills): …` / `fix(agents): …` / `fix(scripts): …`, run `tests/run-script-tests.sh` (it includes E1's `skills.bats`) and `claude plugin validate .`, then re-run the failing session as the next attempt. A fix to a file another lane is exercising is merged before that lane's next launch; an already-passed run is re-run only when the fix changes a section it exercised (record the decision either way). Checks are never weakened. Three fix rounds per check at most, then stop and report `DONE_WITH_CONCERNS`. If a fix changes something DESIGN §3 states, the same commit corrects §3. When the launcher refuses a session for budget, stop and report `DONE_WITH_CONCERNS` with the checks still open.

**After every session (mandatory):** `git -C "$REPO" status --porcelain` shows only `tests/agent-smoke/README.md` and intended fix files, and `ls -A "$W/ghcfg"` prints nothing.

---

### Task F1 — Harness: README §9 skeleton, helpers, launcher, allowlists, expected values and free dry-runs (AC-39, AC-46)

- **id:** F1
- **files:** `tests/agent-smoke/README.md` (new `## 9. Orchestrator (prompt 05)`, subsections 9.1–9.9 below). Kept outside the repo, never committed: `$SMOKE/ship-run.sh` (the launcher, written with the Write tool).
- **depends_on:** [] (phase-level: E1)
- **pattern:** README §2 helpers (`smoke_project`, `smoke_render`), §8.3 `smoke_shop` (static-shop copy, install before the fixture commit), 961 (script file, `< /dev/null`, `--settings` built with `jq -nc`), §8.1 ledger rules; Phase D's verification scaffold `fresh()` (bare origin by `git clone --bare`, upstream set).
- **ACs:** AC-39 (helper, rails, invocation, allowlist, ledger), AC-46 (results format)
- **Risk:** NOT RISKY on its own (free; no session). It defines the rails every paid task depends on.
- **Spend cap:** $0 (no Claude session).

**Step 1: RED.** `grep -c '^## 9\. ' tests/agent-smoke/README.md` prints `0`.

**Step 2: README §9 skeleton.** Add, after §8.4, exactly these headings, each run subsection with its check table (`| run | check | result | notes |`) and every row `pending`:

```
## 9. Orchestrator (prompt 05)
### 9.1 Spend ledger (prompt 05, stop at $60)
### 9.2 Harness
### 9.3 P0 safety probe and the bad-argument probe (P0a, P0b, P1)
### 9.4 S1: `/aew:ship 201 --auto` to a mocked PR
### 9.5 G2: plan-gate stop
### 9.6 Run F1 and R2: kill during develop, resume to review
### 9.7 I1 and I2: init twice
### 9.8 G1: spec-gate stop on init's output
### 9.9 Notes (prompt 05)
```

Keep one blank line plus the heading between subsections, so parallel tasks' edits never touch adjacent lines. §9.1 states the rules (copied from §8.1 and the run matrix): caps per the run matrix; one raise to exactly 2x per session, only if the launcher accepts it; stop at $60; killed sessions count their cap; costs come from `$SMOKE/ledger-05/` and the table is filled by Task F8. §9.3–§9.8 each carry the setup, invocation, checks and table from their task below (copy-paste ready, no transcripts). §9.9 holds cap raises, harness faults, fixes and deviations, newest last.

**Step 3: §9.2 helpers** (bash or zsh; run §2's `REPO`/`SMOKE` lines and §2's `smoke_render` first, and §4's `valid_return_block` eval line):

```sh
SHIM="$REPO/tests/scripts/helpers/bin"; SHOP="$REPO/tests/fixtures/apps/static-shop"; SHOP_RUN="$SHOP/run"

# smoke_ship_project <name> shop|next   (sets W, P, GHM; origin = $W/origin.git, a local bare repo with HEAD main)
smoke_ship_project() {
  W="$SMOKE/ship-$1"; P="$W/p"; GHM="$W/gh"
  rm -rf "$W" && mkdir -p "$P" "$GHM/responses" "$W/ghcfg" "$W/out" || return 1
  case $2 in
    shop) cp -R "$SHOP/." "$P" && rm -rf "$P/run" "$P/run-fanout" "$P/node_modules" &&
          jq '.retro.repo = "acme/aew-retro"' "$SHOP/.aew/config.json" > "$P/.aew/config.json" &&
          (cd "$P" && npm install --no-audit --no-fund --silent && npx playwright install chromium) || return 1
          R=static-shop ;;
    next) cp -R "$REPO/tests/fixtures/stacks/nextjs-tailwind/." "$P" || return 1; R=web ;;
    *) echo "smoke_ship_project: shop or next" >&2; return 1 ;;
  esac
  git -C "$P" init -q -b main && git -C "$P" add -A && git -C "$P" commit -qm fixture &&
    git clone -q --bare "$P" "$W/origin.git" && git -C "$P" remote add origin "$W/origin.git" &&
    git -C "$P" fetch -q origin && git -C "$P" branch -q -u origin/main main || return 1
  # canned replies; every other route succeeds silently, issue view/edit are stateful
  printf 'https://github.com/acme/%s/pull/7\n' "$R" > "$GHM/responses/pr-create.out"
  printf 'https://github.com/acme/%s/issues/1#issuecomment-1\n' "$R" > "$GHM/responses/issue-comment.out"
  printf '[]\n' > "$GHM/responses/issue-list.out"
  printf 'https://github.com/acme/aew-retro/issues/1\n' > "$GHM/responses/issue-create.out"
  git -C "$P" status --porcelain      # must print nothing
}

# smoke_ship_issue <n> <json-with-body>   (seeds the mock's stateful store; mirrors gh_mock_issue --from)
smoke_ship_issue() {
  local d="$GHM/issues/$1"
  mkdir -p "$d" && jq 'del(.body, .labels, .referenced_issues)' "$2" > "$d/base.json" &&
    jq -j '.body // ""' "$2" > "$d/body" && : > "$d/labels"
}
```

`smoke_ship_allow <kind>` prints one CLI argument per line for `ship-run.sh` (kinds `ship`, `p0`, `init`). It must be called with `$P` set to the project. Its lines are, in this order:

1. `--allowedTools`, then the **orchestrator rules** (Phase B I-8): `Bash($REPO/scripts/state.sh *)`, the same for `gh-issue.sh`, `gh-labels.sh`, `git-branch.sh`, `gh-pr.sh`, `gh-retro.sh`, `detect-stack.sh`; `Bash(gh auth status)`; `Bash(claude plugin list --json)`; `Bash(git status *)`, `Bash(git fetch origin main)`, `Bash(git rev-parse *)`, `Bash(git rev-list --left-right --count main...origin/main)`, `Bash(git branch *)`, `Bash(git switch *)`, `Bash(git add *)`, `Bash(git commit *)`, `Bash(git diff *)`, `Bash(git log *)`, `Bash(git show *)`; `Bash(jq *)`, `Bash(awk *)`, `Bash(test *)`, `Bash(tail -n *)` (I-8's `tail -n 4`, status's `tail -n 10`), `Bash(grep -c *)`, `Bash(cat .aew/runs/current)` (I-8, K-4: resume and status read it), `Bash(date *)`, `Bash(ls *)`; `mcp__plugin_context7_context7__*`. No `mktemp` or `cat >` rule: the blocked comment is written with Write (Decision 11).
2. `ship` and `p0` add the **agent lines already recorded in this README** (the union, harness-only): 961's developer line (`git worktree`, `cherry-pick`, the per-subcommand `git -C * …` rules, `cd *`, `node *`, `npm *`, `npx *`) and §8.3's QA phase B line with `$P`/`P_REAL` for this project (`rm -rf <P>/docs/qa/201/screenshots` in both forms) and the eleven Playwright MCP names. **Not** §8.3's `--disallowedTools "Bash(gh *)"`: a deny beats every allow and would deny `gh auth status` (the aew Bash guard already denies `gh` to every agent).
3. `p0` adds the probe-only rules `Bash(command -v gh)`, `Bash(type -a gh)`, `Bash(printenv *)`, `Bash(git remote get-url origin)`, `Bash(echo *)`.
4. `init` adds (Phase D cross-phase item 6) `Bash(git --version)`, `Bash(jq --version)`, `Bash(node --version)`, `Bash(git symbolic-ref *)`, `Bash(git ls-remote *)`, `Bash(npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate *)`, `Bash(touch *)`, `Bash(grep *)`, `Bash(tail *)`, `Bash(printf *)`, `Bash(cat *)`, `Bash(echo *)`, `Bash(mkdir -p *)`, `Bash(rm -f .aew/runs/init-*)`, then **every further command in `skills/init/SKILL.md` §1–§13**, found with the extraction below and mapped to an exact rule or a `<command> <subcommand> *` rule (each part of a compound command needs its own rule, V-7):
   ```sh
   awk '/^```sh$/{f=1;next} /^```$/{f=0} f' "$REPO/skills/init/SKILL.md" | sed -E 's/^[[:space:]]+//' | grep -vE '^(#|$)' \
     | tr '|;&' '\n\n\n' | sed -E 's/^[[:space:](!]+//' | awk '{print $1, $2}' | sort -u
   ```
5. `--disallowedTools`, `Bash(git push *)`, `Bash(git reset *)`, `Bash(git checkout *)`, `Bash(git add -A*)`, `Bash(git add .)`.

Comment block above the function: "Harness-only: the developer and QA lines are broad (`cd *`, `npx *`, `cp *`, `sh -c *`) and are never a template for user settings; init's own proposal (AC-31, cut 6) is anchored."

Check helpers (same block):

```sh
# smoke_res <O>: the session's result text. smoke_main <O>: main-thread tool calls (name TAB command|path|agent|skill)
smoke_res()  { jq -rR 'fromjson? | select(.type == "result") | .result' "$1/stream.jsonl"; }
smoke_main() { jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id == null) | .message.content[]?
  | select(.type == "tool_use") | [.name, (.input.command // .input.file_path // .input.subagent_type // .input.skill // "")] | @tsv' "$1/stream.jsonl"; }
smoke_denials() { jq -cR 'fromjson? | select(.type == "result") | .permission_denials' "$1/stream.jsonl"; }
smoke_init_evt() { jq -cR "fromjson? | select(.type == \"system\" and .subtype == \"init\") | $2" "$1/stream.jsonl"; }
# smoke_pair <O>: main-thread messages whose Agent calls are exactly aew:qa-engineer + aew:senior-engineer (AC-7, run-961 form)
smoke_pair() { jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id == null)
  | .message as $m | $m.content[]? | select(.type == "tool_use" and .name == "Agent") | [$m.id, .id, .input.subagent_type] | @tsv' "$1/stream.jsonl" \
  | sort -u | cut -f1,3 \
  | awk -F'\t' '{a[$1] = a[$1] " " $2} END {for (k in a) {n = split(a[k], x, " "); q = s = 0;
      for (i = 1; i <= n; i++) {if (x[i] == "aew:qa-engineer") q++; if (x[i] == "aew:senior-engineer") s++}
      if (q == 1 && s == 1 && n == 2) c++} print c + 0}'; }
smoke_state_valid() { npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "$REPO/templates/state.schema.json" -d "$1"; }
# smoke_bash_results <O>: every main-thread Bash command with its tool_result (P0 evidence comes from these, not the model's prose)
smoke_bash_results() { jq -rRs '[split("\n")[] | fromjson?] as $e
  | ([$e[] | select(.type == "user") | .message.content[]? | select(.type == "tool_result")
      | {key: .tool_use_id, value: (.content | if type == "array" then map(.text // "") | join("") else tostring end)}] | from_entries) as $r
  | $e[] | select(.type == "assistant" and .parent_tool_use_id == null) | .message.content[]?
  | select(.type == "tool_use" and .name == "Bash") | "$ \(.input.command)\n\($r[.id] // "<no result>")"' "$1/stream.jsonl"; }
```

S1's expected `gh` routes (AC-40), written **before** S1 and derived from Phase B I-9 and the scripts' `gh` calls. Label reads (`issue view --json labels`, one per `gh-labels.sh` call) are dropped, so a no-op stage label leaves no line:

```sh
# smoke_norm <calls.log>: one line per routed gh call
smoke_norm() { awk '
  $1 == "auth" && $2 == "status" {print "auth-status"; next}
  $1 == "issue" && /--repo acme\/aew-retro/ {print "retro-" $2; next}
  $1 == "label" && $2 == "create" && /--repo acme\/aew-retro/ {print "retro-label-create"; next}
  $1 == "issue" && $2 == "view" && /--json labels/ {next}
  $1 == "issue" && $2 == "view" && $NF == "body" {print "issue-view-body"; next}
  $1 == "issue" && $2 == "view" {print "issue-fetch"; next}
  $1 == "issue" && $2 == "edit" && /--body-file/ {print "issue-edit-body"; next}
  $1 == "issue" && $2 == "edit" {s = "issue-edit"; for (i = 3; i < NF; i++) if ($i == "--add-label") s = s " +" $(i + 1); print s; next}
  {print $1 "-" $2}' "$1"; }
# expected_s1 <revisions r> <manual 0|1> <retro items k>   (Phase B I-9)
expected_s1() {
  local i
  printf '%s\n' auth-status issue-fetch 'issue-edit +aew:analysing'
  i=0; while [ "$i" -lt "$1" ]; do printf '%s\n' issue-view-body issue-edit-body issue-comment; [ "$i" -eq 0 ] && echo 'issue-edit +aew:spec-revised'; i=$((i + 1)); done
  printf '%s\n' 'issue-edit +aew:planning' 'issue-edit +aew:building' 'issue-edit +aew:testing' 'issue-edit +aew:documenting' pr-create
  [ "$2" = 1 ] && printf '%s\n' issue-view-body issue-edit-body 'issue-edit +aew:manual-test-required'
  if [ "$3" -gt 0 ]; then printf '%s\n' retro-label-create retro-list; i=0; while [ "$i" -lt "$3" ]; do echo retro-create; i=$((i + 1)); done; fi
  echo 'issue-edit +aew:ready-for-review'
}
# the flags come from artefacts, never from calls.log
s1_flags() { local rd=$1
  printf '%s %s %s\n' "$(ls "$rd"/spec-revision-v*.md 2>/dev/null | wc -l | tr -d ' ')" \
    "$([ "$(grep -c '^- \[ \]' "$rd/manual-tests.md" 2>/dev/null || true)" -gt 0 ] 2>/dev/null && echo 1 || echo 0)" \
    "$(grep -cE '^### [^<]' "$rd/retro.md" 2>/dev/null || true)"; }
```

**Step 4: the launcher.** Write `$SMOKE/ship-run.sh` with the Write tool (it contains no `git push` text), `chmod +x` it, and copy its text into §9.2 as the reference. Contract: `ship-run.sh <repo> <W> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]`. `<repo>` is an argument, not baked in, because parallel tasks run from different worktrees.

```bash
#!/bin/bash
# Harness-only launcher for tests/agent-smoke/README.md section 9. Every paid prompt-05 session starts here.
set -uo pipefail
[ $# -ge 6 ] || { echo "usage: ship-run.sh <repo> <W> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]" >&2; exit 2; }
REPO=$1 W=$2 RUN=$3 CAP=$4 ALLOWF=$5 PROMPT=$6 KSTAGE=${7:-} KAGENT=${8:-}
P="$W/p"; O="$W/out/$RUN"; L="${W%/*}/ledger-05"
[ -e "$O" ] && { echo "ship-run: $O exists; use the next attempt name" >&2; exit 2; }
[ -d "$W/ghcfg" ] && [ -z "$(ls -A "$W/ghcfg")" ] || { echo "ship-run: $W/ghcfg missing or not empty" >&2; exit 2; }
mkdir -p "$O" "$L" || exit 1
spent=$(cat "$L"/*.tsv 2>/dev/null | awk -F'\t' '{s += ($2 != "" ? $2 : $1)} END {printf "%.2f", s + 0}')
if awk -v s="$spent" -v c="$CAP" 'BEGIN {exit !(s + c > 60)}'; then
  echo "ship-run: $spent spent or reserved + cap $CAP passes 60; not started" >&2; exit 3
fi
printf '%s\t\n' "$CAP" > "$L/${W##*/}-$RUN.tsv"        # reserved until the cost is known
ALLOW=(); while IFS= read -r a; do [ -n "$a" ] && ALLOW+=("$a"); done < "$ALLOWF"
SETTINGS=$(jq -nc --arg ex "$REPO/CLAUDE.md" '{claudeMdExcludes: [$ex], enabledPlugins: {"dev-workflow@jamesborg": false, "figma@claude-plugins-official": false}}')
cd "$P" || exit 1
env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN \
  PATH="$REPO/tests/scripts/helpers/bin:$PATH" GH_MOCK_DIR="$W/gh" GH_CONFIG_DIR="$W/ghcfg" GH_HOST=aew-smoke.invalid \
  claude --plugin-dir "$REPO" -p "$PROMPT" \
    --output-format stream-json --verbose --forward-subagent-text --include-hook-events \
    --max-budget-usd "$CAP" --debug-file "$O/debug.log" --settings "$SETTINGS" \
    --add-dir "$REPO" --permission-mode acceptEdits --permission-prompts none \
    ${ALLOW[@]+"${ALLOW[@]}"} > "$O/stream.jsonl" 2> "$O/stderr.txt" < /dev/null &
pid=$!
if [ -n "$KSTAGE" ]; then
  while kill -0 "$pid" 2>/dev/null; do
    id=$(cat .aew/runs/current 2>/dev/null || true)
    s=$(jq -r '.stage' ".aew/runs/$id/state.json" 2>/dev/null || true)
    if [ -n "$id" ] && [ "$s" = "$KSTAGE" ] && { [ -z "$KAGENT" ] || grep -Eq "\"subagent_type\": ?\"$KAGENT\"" "$O/stream.jsonl"; }; then
      date -u +%Y-%m-%dT%H:%M:%SZ > "$O/killed-at"
      pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null
      break
    fi
    sleep 1
  done
fi
wait "$pid"; echo "$?" > "$O/exit"
cost=$(jq -rR 'fromjson? | select(.type == "result") | .total_cost_usd' "$O/stream.jsonl" | tail -n 1)
[ -n "$cost" ] || cost=$CAP                              # killed or crashed: no result event, count the cap
printf '%s\t%s\n' "$CAP" "$cost" > "$L/${W##*/}-$RUN.tsv"
echo "ship-run: $RUN exit $(cat "$O/exit") cost $cost"
```

The `--model` flag for P0a is passed by putting `--model haiku` on the first line of P0a's allow file (it is just another argument); every other session uses the default model, recorded from `system/init`.

**Step 5: free checks** (record each output in §9.2's "Harness checks" table):

```sh
claude --version                                                    # expect 2.1.308 or later; record
claude --help | grep -cE -- '--permission-prompts|--permission-mode|--max-budget-usd|--forward-subagent-text'   # 4
/bin/bash -n "$SMOKE/ship-run.sh" && npx --yes shellcheck "$SMOKE/ship-run.sh"   # no output
claude plugin list --json | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version'   # 7.x: S1 expects no superpowers warning
# real-gh canary, outside any session (read-only; an unauthenticated gh makes no request):
REAL=$(type -a gh | awk '{print $NF}' | grep -v "$SHIM" | head -n 1); C="$SMOKE/canary-ghcfg"; rm -rf "$C"; mkdir -p "$C"
env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN GH_CONFIG_DIR="$C" "$REAL" auth status; echo "exit=$?"
#   expect: a "not logged in" message and a non-zero exit. A zero exit stops the phase (rail 5 would not hold).
# keychain check (rail 3): output discarded so a token is never printed
env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN GH_CONFIG_DIR="$C" "$REAL" auth token > /dev/null 2>&1; echo "token-exit=$?"   # record: 0 means the keychain token is visible despite the empty config dir
env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN GH_CONFIG_DIR="$C" GH_HOST=aew-smoke.invalid "$REAL" auth token > /dev/null 2>&1; echo "token-exit=$?"   # non-zero, else stop the phase
ls -A "$C"                                                          # record whether gh writes into an empty config dir
```

Then the **I-9 dry-run** (free, proves `smoke_norm`/`expected_s1` against the real scripts and the mock). Write it to `$SMOKE/dry-i9.sh` with the Write tool and run it with `/bin/bash`: `smoke_ship_project dry shop`, `smoke_ship_issue 201 "$SHOP_RUN/issue.json"`, then in `$P` with `PATH="$SHIM:$PATH" GH_MOCK_DIR="$GHM" CLAUDE_PLUGIN_ROOT="$REPO"`, the I-9 script calls in order: `gh auth status`; `state.sh init 201 --issues 201 --mode single --auto`; `gh-issue.sh fetch 201 .aew/runs/201`; `state.sh set title "$(jq -r .title .aew/runs/201/issue.json)"`; `gh-labels.sh stage 201 analysing`; `git-branch.sh create 201 add-to-basket`; `state.sh set branch <printed name>`; `gh-labels.sh stage 201` with `planning` three times, `building` twice, `testing`, `documenting`; `git-branch.sh push`; `gh-pr.sh create 201 <body file with "Closes #201">`; `gh-issue.sh manual-tests 201 <one-item manual-tests.md from the template>`; `gh-labels.sh flag 201 add manual-test-required`; `gh-retro.sh file <one-item retro.md> acme/static-shop 201`; `gh-labels.sh stage 201 ready-for-review`. Check:

```sh
diff <(expected_s1 0 1 1) <(smoke_norm "$GHM/calls.log")             # no output
git -C "$W/origin.git" rev-parse --verify --quiet refs/heads/feat/201-add-to-basket   # a sha (branch pattern as configured; record)
```

Allowlist hygiene on the dry project's files (`smoke_ship_allow ship > "$W/allow-ship.txt"` and the same for `p0`, `init`):

```sh
grep -h '^Bash(gh ' "$W"/allow-*.txt | sort -u                       # exactly: Bash(gh auth status)
grep -c 'bypassPermissions' "$SMOKE/ship-run.sh" "$W"/allow-*.txt     # 0 for every file
grep -c -- '--permission-prompts none' "$SMOKE/ship-run.sh"           # 1
grep -c 'GH_HOST=aew-smoke.invalid' "$SMOKE/ship-run.sh"              # 1
grep -rl mktemp "$REPO/skills/ship" | wc -l                          # 0 (the Phase B blocked-comment reconciliation is merged)
tests/run-script-tests.sh && claude plugin validate .                 # pass (E1 baseline)
git -C "$REPO" status --porcelain                                     # only tests/agent-smoke/README.md
```

`rm -rf "$SMOKE/ship-dry"` afterwards.

**Step 6: GREEN.** All free checks as expected; §9 has the ten headings and every run row `pending`.

**Step 7: commit.**

```
test(agent-smoke): add the orchestrator harness for the prompt-05 runs

Section 9 adds smoke_ship_project (fixture copy under $SMOKE, local bare
origin, the gh shim with canned replies, retro.repo faked), the per-project
allowlist builder, the ship-run.sh launcher (safety env, explicit allowlist,
--permission-prompts none, budget stop, kill-at-stage poller), the S1
expected gh routes from Phase B's call order, and the free checks: the
real-gh canary is unauthenticated and the I-9 dry-run matches.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task F2 — P0 safety probe (P0a, P0b) and the bad-argument probe P1 (AC-39, AC-45)

- **id:** F2
- **files:** `tests/agent-smoke/README.md` (§9.3 only); fix files only under the fix loop.
- **depends_on:** [F1] (and E1 passing)
- **pattern:** prompt-04 probe 940 (one cheap session, evidence from `system/init` and tool results, not the model's prose); §4 denial and tool-call checks.
- **ACs:** AC-39 (P0), AC-45 (one paid probe, cut 3)
- **Risk:** RISKY in the sense of the phase risk line: these are the first sessions with the real orchestrator. That is why P0a runs no skill and P0b/P1 run only read-only or argument-rejecting paths.
- **Spend cap:** P0a $0.50, P0b $0.50, P1 $1 (total $2).

**Step 1: RED.** §9.3 rows read `pending`.

**Step 2: setup.**

```sh
smoke_ship_project p0 shop && smoke_ship_issue 201 "$SHOP_RUN/issue.json"
P_REAL=$(cd "$P" && pwd -P)
{ printf '%s\n' --model haiku; smoke_ship_allow p0; } > "$W/allow-p0a.txt"
smoke_ship_allow ship > "$W/allow-ship.txt"
```

**Step 3: P0a, the session's own Bash** (haiku). The prompt (verbatim):

```
Run each of these Bash commands exactly as written, one Bash call per command, in this order, and do nothing else:
1. command -v gh
2. type -a gh
3. printenv GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
4. printenv GH_CONFIG_DIR GH_MOCK_DIR GH_HOST
5. git remote get-url origin
6. gh auth status
7. echo "$(jq -r .project .aew/config.json)"
Then use the Write tool to write the single word probe to .aew/runs/p0-write.md.
Finally print one line per step: the step number, the exit status and the output.
```

```sh
"$SMOKE/ship-run.sh" "$REPO" "$W" P0a.1 0.5 "$W/allow-p0a.txt" "$(cat "$W/p0a-prompt.txt")"   # the prompt saved with Write first
```

**Step 4: P0b, `/aew:status`.** `"$SMOKE/ship-run.sh" "$REPO" "$W" P0b.1 0.5 "$W/allow-ship.txt" "/aew:status"`.

**Step 5: P0 checks** (from tool results and `system/init`; record verbatim excerpts):

| # | check | command | expect |
|---|---|---|---|
| 1 | `gh` resolves to the shim | `smoke_bash_results "$W/out/P0a.1"` steps 1–2 | `command -v gh` = `$REPO/tests/scripts/helpers/bin/gh`; the first `type -a gh` line is the shim (a real `gh` may follow; record it) |
| 2 | token variables empty | step 3 result | empty output (exit 1 because all four are unset) |
| 3 | config dir, mock dir, host | step 4 result | `$W/ghcfg`, `$W/gh` and `aew-smoke.invalid` |
| 4 | origin is the local bare repo | step 5 result | `$W/origin.git` (either `/var` or `/private/var` form) |
| 5 | the shim answered `gh auth status` | `cat "$GHM/calls.log"` | exactly one line, `auth status` |
| 6 | (removed: the blocked-comment heredoc is settled by Decision 11, not probed) | | |
| 7 | `$(jq …)` substitution | step 7 result | `static-shop`, no denial |
| 8 | Write inside the gitignored runs area (the blocked-comment form, Decision 11) | `cat "$P/.aew/runs/p0-write.md"` | `probe` |
| 9 | AskUserQuestion absent (V-4) | `smoke_init_evt "$W/out/P0b.1" '.tools | index("AskUserQuestion")'` (and for P0a) | `null` |
| 10 | agent names (V-3) | `smoke_init_evt "$W/out/P0b.1" '.agents'` | contains `aew:spec-analyser`, `aew:brief-compiler`, `aew:standards-setter`, `aew:senior-engineer`, `aew:developer`, `aew:qa-engineer`, `aew:doc-writer`. If the event has no `agents` key, record its keys and the debug-log agent lines, and S1's dispatches become the evidence |
| 11 | skills and mode | `smoke_init_evt "$W/out/P0b.1" '[.slash_commands[]? | select(startswith("aew:"))], .permissionMode, .model'` | `aew:init`, `aew:ship`, `aew:resume`, `aew:status`, `aew:prompt` present; `acceptEdits`; model recorded |
| 12 | `/aew:status` ran in `-p` (V-2) | `smoke_res "$W/out/P0b.1"`; `smoke_main "$W/out/P0b.1"` | the status skill's "no runs" output (only directories under `.aew/runs/` count, so `p0-write.md` is not a run); no write command; calls.log still one line |
| 13 | no denials | `smoke_denials` for P0a and P0b | `[]` for both |
| 14 | hygiene | `ls -A "$W/ghcfg"`; `git -C "$REPO" status --porcelain` | empty; only the README |

**Any failure of checks 1–5, 9 or 10 stops the phase's paid runs.** Fallbacks, each followed by a full P0 re-run as the next attempt:

- **(a) PATH or tokens wrong inside the session** (the Bash tool's shell is initialised from the user's profile). First fetch the current docs for `CLAUDE_ENV_FILE` (code.claude.com/docs, settings environment variables) and, if it is documented as sourced before each Bash command, have the launcher write `$W/session-env.sh` (`export PATH="$REPO/tests/scripts/helpers/bin:$PATH"`, the four `unset`s, `export GH_CONFIG_DIR=… GH_MOCK_DIR=…`) and export `CLAUDE_ENV_FILE` to it; otherwise try the documented `env` block in `--settings`. Record the URL and the result in §9.9 (Task F8 copies the fact into DESIGN §3). If neither works, stop: `BLOCKED`.
- **(b) Check 8 fails** (Write into `.aew/runs/` denied or blocked by a hook): harness fault first (`acceptEdits`, the working directory); if the aew Edit/Write guard is the cause, it is a fix-loop item, because init's scratch files and the blocked comment both depend on this form.
- **(c) An agent name missing**: harness fault first (`enabledPlugins`, `--plugin-dir`); never a renamed dispatch.

**Step 6: P1** (only after P0 passes).

```sh
wc -l < "$GHM/calls.log" > "$W/out/p1-calls.before"
"$SMOKE/ship-run.sh" "$REPO" "$W" P1.1 1 "$W/allow-ship.txt" "/aew:ship 201 --from nowhere"
smoke_res "$W/out/P1.1" | grep -cF 'unknown stage'                                          # >= 1
smoke_res "$W/out/P1.1" | grep -cF 'spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr'   # 1
smoke_res "$W/out/P1.1" | grep -cF 'Usage: /aew:ship <issue> [--auto] [--from <stage>]'    # 1
test ! -e "$P/.aew/runs/201" && test ! -e "$P/.aew/runs/current" && echo none               # none
[ "$(wc -l < "$GHM/calls.log")" -eq "$(cat "$W/out/p1-calls.before")" ] && echo no-gh-call  # no-gh-call
smoke_main "$W/out/P1.1" | grep -E 'state\.sh|gh-|git-branch\.sh|gh auth' | wc -l           # 0
git -C "$P" status --porcelain; smoke_denials "$W/out/P1.1"; ls -A "$W/ghcfg"               # empty, [], empty
```

The message strings are Phase B I-7's; if the merged `SKILL.md` words them differently, use the merged strings (E1 checks them statically). P1 also proves that a `disable-model-invocation` skill expands in `-p` (V-2).

**Step 7: GREEN and record.** §9.3 rows filled with result and notes; each session's cost from `$SMOKE/ledger-05/ship-p0-*.tsv` noted in the row. Hygiene as above.

**Step 8: commit.** `test(agent-smoke): record the P0 safety probe and the bad-argument probe` (body: what P0 proved, P1's three checks, costs; trailer as in Task F1). A fallback (a) or (b) fix is its own commit before this one.

---

### Task F4 — G2: `/aew:ship 201` stops at the plan gate (AC-42, cut 1)

- **id:** F4
- **files:** `tests/agent-smoke/README.md` (§9.5 only); fix files only under the fix loop.
- **depends_on:** [F2]
- **pattern:** §9.2 helpers; prompt-04 §8.3 for the static-shop project.
- **ACs:** AC-42 (G2 only; R1 is dropped by cut 1, and E1 checks statically that resume names the pending-gate re-ask)
- **Risk:** phase risk line only (rails enforced by the launcher).
- **Spend cap:** $8.

**Step 1: RED.** §9.5 rows `pending`.

**Step 2: setup and run.**

```sh
lsof -nP -iTCP:4173 -sTCP:LISTEN                       # record; G2 never starts the app
smoke_ship_project g2 shop && smoke_ship_issue 201 "$SHOP_RUN/issue.json"
P_REAL=$(cd "$P" && pwd -P); smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" G2.1 8 "$W/allow-ship.txt" "/aew:ship 201"
RUN="$P/.aew/runs/201"; O="$W/out/G2.1"
```

**Step 3: checks.**

| # | check | command | expect |
|---|---|---|---|
| 1 | gate state | `jq -r '.stage, .status, .auto' "$RUN/state.json"` | `plan`, `awaiting_plan_approval`, `false` |
| 2 | pending note (PD-1) | the I-5 lookup `jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' "$RUN/state.json"` | `gate:plan-approval 05-plan.md` |
| 3 | run stays current | `cat "$P/.aew/runs/current"` | `201` |
| 4 | label | `grep '^aew:' "$GHM/issues/201/labels"` | exactly `aew:awaiting-approval` |
| 5 | nothing after the gate | `ls "$RUN"/06-dev-report*.md 2>/dev/null | wc -l`; `git -C "$P" rev-list --count main..HEAD` | `0`; `0` (standards reused, no commit; record if a `docs(standards)` commit appears) |
| 6 | gate output | `smoke_res "$O" | grep -cF 'aew ship #201: waiting at the plan-approval gate.'` | `1` |
| 7 | summary of 25 lines or fewer | `smoke_res "$O" | awk '/waiting at the plan-approval gate\./{f=1;next} /\.aew\/runs\/201\/05-plan\.md/{exit} f && NF' | wc -l` | 1–25 |
| 8 | plan path and resume hint | `smoke_res "$O" | grep -cF '.aew/runs/201/05-plan.md'`; `… | grep -cF 'Answer with /aew:resume 201'` | ≥ 1; `1` |
| 9 | AskUserQuestion never attempted | `smoke_main "$O" | grep -c '^AskUserQuestion'` | `0` |
| 10 | QA phase A ∥ plan (AC-7) | `smoke_pair "$O"` | `1` (record the prompts: `phase: A`, `mode: plan`) |
| 11 | reads hygiene (AC-19) | `smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /\.aew\/runs\//'` | only `05-plan.md` (the plan gate's full read) |
| 12 | state valid; denials; config dir | `smoke_state_valid "$RUN/state.json"`; `smoke_denials "$O"`; `ls -A "$W/ghcfg"` | valid; `[]`; empty |
| 13 | gh calls | `smoke_norm "$GHM/calls.log"` | `auth-status`, `issue-fetch`, `issue-edit +aew:analysing`, [revision lines], `issue-edit +aew:planning`, `issue-edit +aew:awaiting-approval` (record) |

**Step 4: snapshot for Task F5** (after the checks pass; these files are the "before" evidence):

```sh
(cd "$RUN" && shasum 00-issue-original.md issue.json 01-spec-analysis.md spec-final.md 02-brief.md 03-standards.md 04-qa-test-plan.md 05-plan.md) > "$W/out/g2-artefacts.sha"
wc -l < "$RUN/log.md" | tr -d ' ' > "$W/out/g2-log.lines"
git -C "$P" status --porcelain > "$W/out/g2-status.txt"     # expect only .claude/agent-memory/ lines (PD-2)
```

**Fallback:** if spec-analyser returns `needs_input` on #201 (the spec's Risk: the out-of-repo email AC), G2 stops at the spec gate instead. That is correct behaviour but fails check 1: record it, then make the harness tweak the spec names, an unambiguous #201 body in the mock store only (AC-4 rewritten as "out of scope: the order service sends the email"), never in the fixture's committed `issue.json`, and re-run as `G2.2`. Apply the same body to S1 (Task F3 setup) and note it in §9.9.

**Step 5: commit.** `test(agent-smoke): record the G2 plan-gate stop` (trailer as in Task F1).

---

### Task F6 — I1 and I2 (init twice), then G1 on init's output (AC-44, AC-41, cut 4)

- **id:** F6
- **files:** `tests/agent-smoke/README.md` (§9.7 and §9.8 only); fix files only under the fix loop.
- **depends_on:** [F2]
- **pattern:** Phase D's verification scaffold and D-C4; §9.2 helpers; §2 `smoke_render` for #103.
- **ACs:** AC-44 (I1/I2), AC-41 (G1)
- **Risk:** phase risk line only. Init's settings proposal is printed, never written, in a headless run (cut 6), and check I1-9 proves it.
- **Spend cap:** I1 $3, I2 $3, G1 $3 (total $9).

**Step 1: RED.** §9.7 and §9.8 rows `pending`.

**Step 2: I1.**

```sh
smoke_ship_project init next
printf '7\n' > "$GHM/responses/pr-list.2.out"     # I2's reuse lookup (D-C4); I1's lookup (call 1) gets nothing
smoke_ship_allow init > "$W/allow-init.txt"
# the D2 reference proposal, copied verbatim from the merged Phase D skill or plan, saved with Write as "$W/ref.json"
"$SMOKE/ship-run.sh" "$REPO" "$W" I1.1 3 "$W/allow-init.txt" "/aew:init"
O="$W/out/I1.1"
```

| # | check | command | expect (D-C4) |
|---|---|---|---|
| 1 | branch and one commit | `git -C "$P" branch --show-current`; `git -C "$P" rev-list --count main..chore/aew-init`; `git -C "$P" log -1 --format=%s chore/aew-init` | `chore/aew-init`; `1`; `chore: set up aew` |
| 2 | pushed to the bare origin | `git -C "$W/origin.git" rev-parse refs/heads/chore/aew-init` vs `git -C "$P" rev-parse chore/aew-init` | equal |
| 3 | config validates | `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "$REPO/templates/config.schema.json" -d "$P/.aew/config.json"` | valid |
| 4 | config = reference | `diff <(jq -S . "$P/.aew/config.json") <(jq -S . "$W/ref.json")` | no output |
| 5 | gitignore | `grep -cxF '.aew/runs/' "$P/.gitignore"`; `grep -cxF '.playwright-mcp/' "$P/.gitignore"` | `1`; `1` |
| 6 | CLAUDE.md section | `grep -cxF '## Agentic workflow' "$P/CLAUDE.md"` | `1` |
| 7 | standards docs | `ls "$P/docs/standards"` | `README.md`, `nextjs.md`, `tailwind.md` |
| 8 | labels and PR calls | `grep -c '^label create' "$GHM/calls.log"`; `grep -c '^pr list'`; `grep -c '^pr create'`; `grep '^pr create' "$GHM/calls.log" | grep -c -- '--base main'` | `11`; `1`; `1`; `1` |
| 9 | no settings written; Playwright skipped | `test ! -e "$P/.claude/settings.json" && test ! -e "$P/.claude/settings.local.json" && echo absent`; `smoke_res "$O"` | `absent`; the report lists the printed permissions proposal (both files), "Playwright skipped" and the defaults used |
| 10 | tree clean; scratch removed | `git -C "$P" status --porcelain`; `ls "$P/.aew/runs" 2>/dev/null` | empty; no `init-*` file |
| 11 | denials, config dir, AskUserQuestion | `smoke_denials "$O"`; `ls -A "$W/ghcfg"`; `smoke_main "$O" | grep -c '^AskUserQuestion'` | `[]`; empty; `0` |
| 12 | standards-setter init mode | `smoke_main "$O" | grep -c $'^Agent\taew:standards-setter'`; the Agent prompt | `1`; exactly `mode: init` (C-2) |

Snapshot: `{ git -C "$P" rev-parse main chore/aew-init; git -C "$W/origin.git" rev-parse main chore/aew-init; } > "$W/out/i1-heads"`, `shasum "$P/.aew/config.json" > "$W/out/i1-config.sha"`, `wc -l < "$GHM/calls.log" | tr -d ' ' > "$W/out/i1-calls.lines"`.

**Step 3: I2** straight after, same project: `"$SMOKE/ship-run.sh" "$REPO" "$W" I2.1 3 "$W/allow-init.txt" "/aew:init"`.

| # | check | command | expect (AC-33, D-C4) |
|---|---|---|---|
| 1 | no file diff | `git -C "$P" status --porcelain` | empty |
| 2 | heads unchanged | the snapshot command again, `diff` with `i1-heads` | no output |
| 3 | config unchanged | `shasum -c "$W/out/i1-config.sha"` | `OK` |
| 4 | calls since I1 | `tail -n +$(( $(cat "$W/out/i1-calls.lines") + 1 )) "$GHM/calls.log" | awk '{print $1, $2}' | sort | uniq -c` | `11 label create`, `1 pr list`; no `pr create` |
| 5 | no push | `smoke_main "$W/out/I2.1" | grep -c 'git-branch.sh.* push'` | `0` |
| 6 | report | `smoke_res "$W/out/I2.1"` | says nothing changed and names PR 7 |
| 7 | denials, config dir | as I1 | `[]`; empty |

If D-C4 as merged differs (for example no `pr list` on I2), the merged D-C4 wins: update this table before I2 runs and note it in §9.9.

**Step 4: G1 preparation** (harness actions, cut 4: as if the init PR merged). Write them to `$SMOKE/g1-prep.sh` with Write and run with `/bin/bash`:

```sh
git -C "$P" branch -f main chore/aew-init                           # local main = the init commit (main is not checked out)
git -C "$W/origin.git" update-ref refs/heads/main refs/heads/chore/aew-init
git -C "$P" switch -q main && git -C "$P" fetch -q origin
jq '.retro.repo = "acme/aew-retro"' "$P/.aew/config.json" > "$P/.aew/config.json.new" && mv "$P/.aew/config.json.new" "$P/.aew/config.json"
git -C "$P" add -- .aew/config.json && git -C "$P" commit -qm "test: point retro at a fake repo (harness)"
git -C "$W/origin.git" fetch -q "$P" main:main                      # origin main follows, without a push
git -C "$P" fetch -q origin && git -C "$P" rev-list --left-right --count main...origin/main   # 0	0
git -C "$P" status --porcelain                                      # empty
mv "$GHM" "$W/gh-init" && mkdir -p "$GHM/responses"                 # G1 gets a fresh mock; init's calls are kept
```

Then seed #103: `smoke_render material-guest-access.md 103 "Let readers save favourite articles"` (it also proves the render is byte-identical) and `smoke_ship_issue 103 "$REPO/tests/tmp/issue-render-103/gh/responses/issue-view.out"`; re-create the four canned replies of `smoke_ship_project` in the new `$GHM`; `smoke_ship_allow ship > "$W/allow-ship.txt"` (with `$P` = this project).

**Step 5: G1.** `"$SMOKE/ship-run.sh" "$REPO" "$W" G1.1 3 "$W/allow-ship.txt" "/aew:ship 103 --auto"`; `RUN="$P/.aew/runs/103"; O="$W/out/G1.1"`.

| # | check | command | expect |
|---|---|---|---|
| 1 | gate state | `jq -r '.stage, .status' "$RUN/state.json"` | `spec_analysis`, `awaiting_input` |
| 2 | pending note | the I-5 lookup | `gate:spec 01-spec-analysis.md` |
| 3 | label | `grep '^aew:' "$GHM/issues/103/labels"` | exactly `aew:awaiting-input` |
| 4 | nothing after the gate | `test ! -e "$RUN/02-brief.md" && echo none` | `none` |
| 5 | questions with recommended answers | `Q=$(grep -c '^### Q[0-9]' "$RUN/01-spec-analysis.md")`; `smoke_res "$O" | grep -c 'recommended'` | `Q` ≥ 1; count ≥ `Q` (record the printed questions' first lines) |
| 6 | gate lines | `smoke_res "$O" | grep -cF 'aew ship #103: waiting at the spec gate.'`; `… | grep -cF 'Answer with /aew:resume 103'` | `1`; `1` |
| 7 | auto does not skip it (AC-8) | `jq -r .auto "$RUN/state.json"`; `smoke_main "$O" | grep -c '^AskUserQuestion'` | `true`; `0` |
| 8 | preflight passed on init's output | `smoke_main "$O" | head` | `gh auth status`, `git fetch origin main` and the rev-list check ran; no stop |
| 9 | branch, current, state | `jq -r .branch "$RUN/state.json"`; `cat "$P/.aew/runs/current"`; `smoke_state_valid "$RUN/state.json"` | a `feat/103-…` style name (record); `103`; valid |
| 10 | hygiene | `smoke_denials "$O"`; `ls -A "$W/ghcfg"`; `git -C "$P" status --porcelain` | `[]`; empty; only `.claude/agent-memory/` lines (PD-2; record) |

**Step 6: commit.** `test(agent-smoke): record init twice and the G1 spec-gate stop on init's output` (trailer as in Task F1).

---

### Task F3 — S1: `/aew:ship 201 --auto` through a mocked PR (AC-40)

- **id:** F3
- **files:** `tests/agent-smoke/README.md` (§9.4 only); fix files only under the fix loop.
- **depends_on:** [F2, F4] (F4 is a budget dependency: G2 proves the shared spec → plan prefix for $8 first)
- **pattern:** §9.2 helpers; §8.3 static-shop QA (port 4173, planted defects give one QA fix cycle and the manual-tests path, Assumption 6); run 961's one-`message.id` evidence form.
- **ACs:** AC-40 (and live evidence for AC-6, AC-7, AC-11, AC-13, AC-16, AC-17, AC-19)
- **Risk:** phase risk line; the only session that reaches `pr` and `gh-retro.sh`, so rails 3 and 6 matter most here.
- **Spend cap:** $25 (a 2x raise only if the launcher accepts it, which the $60 stop will normally refuse).

**Step 1: RED.** §9.4 rows `pending`. Before the run, §9.4 already contains `expected_s1` and `s1_flags` (Task F1) and this sentence: "Expected routes: `expected_s1 $(s1_flags "$RUN")`; the flags come from `spec-revision-v*.md`, `manual-tests.md` and `retro.md`, never from `calls.log`."

**Step 2: setup and run.**

```sh
lsof -nP -iTCP:4173 -sTCP:LISTEN                       # must print nothing (no other QA session)
smoke_ship_project s1 shop && smoke_ship_issue 201 "$SHOP_RUN/issue.json"   # plus G2's body tweak if F4 needed it
P_REAL=$(cd "$P" && pwd -P); smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" S1.1 25 "$W/allow-ship.txt" "/aew:ship 201 --auto"     # run_in_background; about an hour
RUN="$P/.aew/runs/201"; O="$W/out/S1.1"; BR=$(jq -r .branch "$RUN/state.json")
```

**Step 3: checks.**

| # | check | command | expect |
|---|---|---|---|
| 1 | completed | `jq -rR 'fromjson? | select(.type == "result") | .subtype' "$O/stream.jsonl"`; `jq -r '.stage, .status' "$RUN/state.json"` | `success`; `pr`, `done` |
| 2 | state valid | `smoke_state_valid "$RUN/state.json"` | valid |
| 3 | current cleared | `test -s "$P/.aew/runs/current" && echo set || echo cleared` | `cleared` |
| 4 | branch on the bare origin, main untouched | `git -C "$W/origin.git" rev-parse "refs/heads/$BR"` vs `git -C "$P" rev-parse "$BR"`; `git -C "$W/origin.git" rev-parse main` vs `git -C "$P" rev-parse main` | equal; equal (and equal to the fixture commit) |
| 5 | final labels | `grep '^aew:' "$GHM/issues/201/labels"` | `aew:ready-for-review`, plus `aew:manual-test-required` when `manual-tests.md` has items, plus `aew:spec-revised` when a revision was recorded; no other `aew:` stage label |
| 6 | gh route sequence | `diff <(expected_s1 $(s1_flags "$RUN")) <(smoke_norm "$GHM/calls.log")` | no output |
| 7 | only the mock was reached | `smoke_main "$O" | awk -F'\t' '$1 == "Bash" && $2 ~ /(^|[ ;&|(])gh /'`; `grep -- '--repo' "$GHM/calls.log" | grep -vc 'acme/aew-retro'`; `ls -A "$W/ghcfg"` | only `gh auth status`; `0`; empty |
| 8 | QA phase A ∥ plan in one message (AC-7) | `smoke_pair "$O"` | `1`. Overlap is recorded, not required: note whether both `tool_result`s came after both `tool_use` blocks |
| 9 | PR and state | `jq -r .pr "$RUN/state.json"`; `n=$(grep -n '^pr create' "$GHM/calls.log" | cut -d: -f1); grep -c 'Closes #201' "$GHM/files/$(printf %03d "$n")-"*` (the mock saves each `--body-file` as `<call no.>-<name>`) | `7`; ≥ 1 |
| 10 | final report (AC-17) | `smoke_res "$O"` | outcome, `https://github.com/acme/static-shop/pull/7`, `ACs passed <m>/<n>`, review and fix cycles against limits, manual tests outstanding, the `gh-retro.sh` output lines |
| 11 | commits (AC-16) | `git -C "$P" log --format=%s main.."$BR"` | the developer's `<type>(<scope>): … (#201)` commits, QA's evidence commit(s), `docs: … (#201)`, `chore(aew): update agent memory (#201)` when memory changed; a `docs(standards): …` only if standards changed (record) |
| 12 | tree clean at the end | `git -C "$P" status --porcelain` | empty |
| 13 | loops within limits | `jq -r '.review_cycle, .fix_cycle' "$RUN/state.json"`; `ls "$RUN"/08-qa-report-*.md "$RUN"/07-review-*.md` | record (expected one QA fix cycle from the planted defects, Assumption 6); `fix_cycle` ≤ 3, `review_cycle` ≤ 2 |
| 14 | per-report return check (AC-6, CTO-3b) | `smoke_main "$O" | grep -E 'tail -n 4 .*06-dev-report'` | one `tail -n 4` per developer report named in ARTEFACTS |
| 15 | reads hygiene (AC-19) | `smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /\.aew\/runs\//'` | none in auto mode (no plan gate); bounded reads appear as `awk`/`grep -c`/`jq` Bash calls (record them) |
| 16 | superpowers check | `smoke_main "$O" | grep -c 'claude plugin list --json'`; `smoke_res "$O"` | `1`; no version warning with 7.x installed (record the line) |
| 17 | denials, after-run repo status | `smoke_denials "$O"`; `git -C "$REPO" status --porcelain` | `[]` (this also proves the `$(jq …)` title form); README plus intended fixes |

**Fallbacks:** a stop at the spec gate on #201 → the Task F4 fallback. A cap hit → a run failure (raise once to $50 only if the launcher accepts; otherwise `DONE_WITH_CONCERNS`). A QA session that leaves port 4173 bound → `lsof -ti tcp:4173 -sTCP:LISTEN | xargs kill` (harness action, recorded).

**Step 4: commit.** `test(agent-smoke): record the S1 auto run through a mocked PR` (trailer as in Task F1).

---

### Task F5 — Run F1 (killed during develop) and R2 (resume, killed at review) (AC-43, cut 2)

- **id:** F5
- **files:** `tests/agent-smoke/README.md` (§9.6 only); fix files only under the fix loop.
- **depends_on:** [F4, F6] (F4: G2's project, artefact snapshot and log offset; F6: concurrency only, so no more than two paid sessions run at once)
- **pattern:** the launcher's kill-at-stage poller; §4 `valid_return_block`; Assumption 8.
- **ACs:** AC-43 as amended by cut 2
- **Risk:** phase risk line. Killing a session mid-dispatch can leave partial work; Assumption 8's path handles it.
- **Spend cap:** run F1 $2, R2 $10 (killed sessions count the cap).

**Step 1: RED.** §9.6 rows `pending`; `$W/out/g2-artefacts.sha` and `g2-log.lines` exist.

**Step 2: run F1.** Set `W="$SMOKE/ship-g2"; P="$W/p"; GHM="$W/gh"; RUN="$P/.aew/runs/201"`. The kill condition is "stage reads `develop` **and** the `aew:developer` Agent call is in the stream", so the kill lands after the dispatch rather than between Step 4's state write and it (refinement of Assumption 8, recorded).

```sh
"$SMOKE/ship-run.sh" "$REPO" "$W" F1.1 2 "$W/allow-ship.txt" "/aew:ship 201 --auto --from develop" develop aew:developer
O="$W/out/F1.1"; L0=$(cat "$W/out/g2-log.lines")
```

| # | check | command | expect |
|---|---|---|---|
| 1 | killed by the poller during develop | `cat "$O/killed-at"`; `smoke_main "$O" | grep -c $'^Agent\taew:developer'`; `jq -r '.stage, .status' "$RUN/state.json"` | a timestamp; `1`; `develop`, `running` |
| 2 | `--from` recorded, nothing earlier re-entered | `tail -n +$((L0 + 1)) "$RUN/log.md"` | only `develop` lines, one with the note `--from` |
| 3 | auto recorded | `jq -r .auto "$RUN/state.json"` | `true` (if `false`, record: from `develop` on there is no plan gate) |
| 4 | tree after the kill | `git -C "$P" status --porcelain` | record: empty or only `.claude/agent-memory/` → R2 proceeds; anything else → R2 must stop and list it (step 3) |
| 5 | no leftover processes | `pgrep -fl 'playwright/mcp' ` | none from this run (kill and record otherwise) |

**Step 3: R2.**

```sh
"$SMOKE/ship-run.sh" "$REPO" "$W" R2.1 10 "$W/allow-ship.txt" "/aew:resume 201" review
O="$W/out/R2.1"
```

If check 4 showed partial developer work, R2.1 must instead stop and list the dirty paths (AC-21): record that as a pass of "resume refuses a dirty tree", then discard the partial work as a logged harness action (`git -C "$P" checkout -- . && git -C "$P" clean -fd -e .claude/agent-memory/`, in a script file) and run `R2.2` with the same command.

| # | check | command | expect (cut 2) |
|---|---|---|---|
| 1 | killed at review | `cat "$O/killed-at"`; `jq -r .stage "$RUN/state.json"` | a timestamp; `review` |
| 2 | no earlier stage re-entered | `tail -n +$((L0 + 1)) "$RUN/log.md" | awk '{print $3}' | grep -xcE 'spec_analysis|brief|standards|qa_test_plan|plan'` | `0` |
| 3 | 01…05 artefacts byte-identical | `(cd "$RUN" && shasum -c "$W/out/g2-artefacts.sha")` | every line `OK` |
| 4 | one issue fetch in total (G2 + run F1 + R2) | `grep -c '^issue view 201 --json number,title,body' "$GHM/calls.log"` | `1` |
| 5 | a valid developer report | `valid_return_block "$RUN/06-dev-report.md"` (and each `06-dev-report-WP*.md`); heading diff against `templates/artefacts/dev-report.md` as in §8.4 S4/S5 | `ok`; no diff |
| 6 | developer commits on the branch | `git -C "$P" log --format=%s main..HEAD` | the developer's `… (#201)` commits |
| 7 | state valid | `smoke_state_valid "$RUN/state.json"` | valid |
| 8 | resume reused ship by Read (AC-21) | `smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /skills\/ship\/SKILL\.md$/' | wc -l`; `smoke_main "$O" | awk -F'\t' '$1 == "Skill"'` | ≥ 1; no `aew:ship` line |
| 9 | developer re-dispatched once, from develop | `smoke_main "$O" | grep -c $'^Agent\taew:developer'` | `1` |
| 10 | hygiene | `smoke_denials "$O"`; `ls -A "$W/ghcfg"`; `git -C "$REPO" status --porcelain` | `[]`; empty; README plus intended fixes |

"Final state `done`" is not checked here (cut 2): S1 covers it. The SessionStart resume hint in R2's debug log is expected and harmless (record it).

**Step 4: commit.** `test(agent-smoke): record the kill-and-resume runs (run F1, R2)` (trailer as in Task F1).

---

### Task F7 — DESIGN.md and the state machine (AC-47, cut 10, Phase A C-4)

- **id:** F7
- **files:** `docs/DESIGN.md` (§3, §4, §7.1, §8.3, §8.4, §8.7, §9), `skills/run-protocol/references/state-machine.md`, `scripts/git-branch.sh` (header comment only, which `--help` prints)
- **depends_on:** [] (needs only the merged Phases A–D text, which phase F's dependency on E guarantees)
- **pattern:** DESIGN §3's existing bullet style (fact, then the docs page, then the design consequence; "Confirmed …" for live evidence); state-machine.md's existing mermaid arrows and tables. Mirror the merged `skills/ship/references/routing.md` and `gates.md`: **where they differ from the wording below, the merged references win** and this task follows them.
- **ACs:** AC-47 (DESIGN and state-machine halves); AC-35's DESIGN clause; Phase A C-4
- **Risk:** NOT RISKY (documentation).
- **Spend cap:** $0.

**Step 1: RED.**

```sh
grep -c 'headless.md#auto-approve-tools\|tools-reference.md#askuserquestion\|plugins/loading.md\|en/permissions.md' docs/DESIGN.md   # 0
grep -c 'mode: init' docs/DESIGN.md; grep -c 'Revision notes' docs/DESIGN.md; grep -c 'Unanswered gate' docs/DESIGN.md      # 0 0 0
grep -c 'Answer with /aew:resume' skills/run-protocol/references/state-machine.md                                          # 0
```

**Step 2: DESIGN §3** (verified facts V-1…V-7 with URLs; British English; one bullet per fact, edited in place where a bullet exists):

- Intro line: "Checked against code.claude.com/docs on 24 Oct 2026; the skill, headless, subagent, AskUserQuestion, plugin-version and permission-rule facts again on 25 Oct 2026 (build prompt 05)."
- **Namespacing** (V-3), append: the Agent tool's `subagent_type` for a plugin agent is `aew:<agent>`; the docs give the `plugin:agent` naming but not the exact string, so it is live-evidenced (smoke runs since prompt 03; the `system/init` agents list in P0). Up to 20 background subagents run at once; several Agent calls in one message are not documented as concurrent, so aew relies only on them being dispatched together (run 961, S1: two Agent blocks under one `message.id`). https://code.claude.com/docs/en/sub-agents.md
- **Path variables** (V-5): replace "`${CLAUDE_SKILL_DIR}` is untested" with: `${CLAUDE_SKILL_DIR}` and `${CLAUDE_SESSION_ID}` are documented as substituted too, and aew doesn't use them. Only the loaded skill or agent body is substituted; a file read on demand with Read (a skill's `references/`) is not, so `ship/SKILL.md` states the substituted root once and its references spell literal `${CLAUDE_PLUGIN_ROOT}/…` paths, absolute rather than relative links because `resume` and `prompt` read them from another skill. https://code.claude.com/docs/en/skills.md
- New **Skill frontmatter and arguments** (V-1): keys aew uses (`name`, `description`, `argument-hint`, `disable-model-invocation`), unknown keys ignored; `allowed-tools` only pre-approves tools for the invoking turn and restricts nothing, so aew's entry skills don't set it; `$ARGUMENTS` is the whole string, `$ARGUMENTS[N]`/`$N` are 0-based, and with no placeholder the input is appended as `ARGUMENTS: <input>`; ship parses `$ARGUMENTS` whole and uses no `$N` and no `` !`cmd` ``, because `resume` reads it with Read; keep `SKILL.md` under 500 lines. https://code.claude.com/docs/en/skills.md
- **Skill visibility** (V-1), extend: `disable-model-invocation: true` also removes the skill from Claude's context and blocks a Skill-tool call to it, so `resume` and `prompt` reuse `ship` by reading its files with Read, never through the Skill tool.
- New **Headless runs** (V-2): `claude -p "/aew:<skill> …"` expands user-invoked skills, `disable-model-invocation` ones included (P0b and P1, `tests/agent-smoke/README.md` §9). Since v2.1.302 `-p` defaults to Manual mode, which denies approvals, so an unattended run sets a permission mode and an explicit allowlist (aew's harness: `acceptEdits` plus `--allowedTools`, never `bypassPermissions`) https://code.claude.com/docs/en/headless.md#auto-approve-tools. `--permission-prompts none` (v2.1.259+) denies anything that would prompt and removes AskUserQuestion https://code.claude.com/docs/en/headless.md#turn-off-permission-prompts-in-unattended-runs. `--max-turns` errors when reached; `--output-format stream-json` needs `--verbose` https://code.claude.com/docs/en/cli-reference.md.
- New **AskUserQuestion** (V-4): removed from every subagent's tool pool, so only main-thread skills (ship, init, resume, prompt) ask, and agents return `needs_input` instead; no per-call limits and no recommended-option marker are documented, so aew lists the recommended answer first with a label ending ` (recommended)` and batches by the schema the model sees; `Other` is added automatically; with `--permission-prompts none` the tool is absent, so gates are left pending (§9). https://code.claude.com/docs/en/tools-reference.md#askuserquestion-tool-behavior
- New **Plugin versions** (V-6): `claude plugin list --json` prints `[{id: "<name>@<marketplace>", version, installPath, …}]` and `~/.claude/plugins/installed_plugins.json` records the same; for a git source `version` may be a 12-character commit SHA, which ship's superpowers check reports as not comparable. https://code.claude.com/docs/en/plugins/loading.md#find-plugins-on-disk, https://code.claude.com/docs/en/plugins/cli-reference.md
- **Bash tool and permission rules** (V-7), append: `*` matches any text anywhere, and `Bash(git commit *)` matches the bare command too; in a compound command (`&&`, `||`, `;`, pipes, `$(…)`, subshells) every part must match an allow, while deny and ask apply when any part matches; leading env assignments are skipped for allows only when the variable is known-safe (for deny and ask, any assignment); `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob` and bare `xargs` are stripped, `npx` and `docker exec` are not; `git -C <dir>` and `git -c k=v` are not normalised, so `Bash(git <sub> *)` never matches them; deny, then ask, then allow, first match wins; deny rules are not a security boundary around a program, so aew's enforcement stays its Bash guard hook and init's proposal uses anchored per-subcommand rules only (CTO-3a, cut 6). https://code.claude.com/docs/en/permissions.md

**Step 3: DESIGN §4.** "GitHub access" bullet, append: "The one direct call is the read-only `gh auth status` in the `ship` and `init` preflights (no script wraps it; a recorded deviation, prompt 05)." Superpowers bullet, append: "`ship`'s preflight warns, never blocks, when the installed major isn't 7 or the version is a commit SHA (`skills/ship/references/preflight.md`)."

**Step 4: DESIGN §8.3** new last bullet (C-2): "**Init mode.** `/aew:init` dispatches it with `mode: init` and no run dir. There is no brief, so it skips the brief and `03-standards.md`, writes or reuses `docs/standards/` as above (nothing changes when every fingerprint matches), and puts its return block in its final message only. This settles §5.1's 'init generates the first standards docs' against the run-dir inputs above (Conflict C3, prompt 05)."

**Step 5: DESIGN §8.4** (C-1), after the plan list and before "No code beyond…": "**Revision notes.** An optional `notes` dispatch field carries James's change requests from the plan gate, or the developer's `blocked` reason. The senior engineer reads the existing `05-plan.md`, rewrites it, and ends `## Approach` with `Revision notes:`, one line per note saying what changed or why not. A note that needs a material spec change becomes a challenge (`needs_input`)."

**Step 6: DESIGN §8.7** last sentence: "…as it does `docs/standards/` (prompt 05; this overrides the build prompt's 'the doc-writer commits', Conflict C1)."

**Step 7: DESIGN §9** (cut 10: pointers, not restated detail):

- Preflight "the default branch is up to date" → "the default branch is up to date with `origin`: checked after a fetch and never fast-forwarded; behind or diverged stops with a `git pull` hint (preflight writes nothing)"; add "the superpowers major version (warning only)".
- Steps: the first two become "initialise state (this creates the run dir); fetch the issue into it (Conflict C4: the fetch needs the run dir)".
- Gates, new bullet: "**Unanswered gate.** When AskUserQuestion is unavailable (headless runs with `--permission-prompts none`), refused or answered empty, the gate stays pending: state and label are already set, ship prints the questions (or the plan summary and path) and `Answer with /aew:resume <id>`, and stops; nothing after the gate runs. `init` instead uses its recommended defaults and writes no settings."
- Resume, append: "`resume` reads `ship`'s files with Read and enters at the recorded stage's section."
- Context hygiene, append: "The exact reads (the plan in full at the plan gate, and bounded section reads for the gates and QA routing) are the reads table in `skills/ship/SKILL.md`."
- New bullet: "**Procedure detail.** The preflight order and messages, run start, `--from`, dispatch rows and return checks, gate steps, routing table, PR steps and final-report format are in `skills/ship/SKILL.md` and `skills/ship/references/` (`preflight.md`, `dispatch.md`, `gates.md`, `routing.md`, `pr.md`, `final-report.md`); this section doesn't restate them."
- New bullet: "**Recorded deviations (build prompt 05).** C1: the orchestrator commits the doc-writer's outputs (§8.7). C3: standards-setter init mode (§8.3). C4: state before fetch (Steps). C5: the simulated runs ship the static-shop fixture's issue #201, not issue 1 (`tests/agent-smoke/README.md` §9). The direct `gh auth status` (§4). A blocked prompt-mode run posts no report comment and sets no `aew:blocked` label, because prompt mode sets no labels (§7.3's blocked rule; Phase C PC-3)."
- New bullet: "**Prompt mode and resume.** `/aew:prompt` marks its run with the `history` note `prompt` (written before the fetch), and a run is a prompt-mode run when that note exists and `branch` is null; the one check is in `skills/ship/references/gates.md` and is used unchanged by `resume` and `status`. `resume` continues `single` runs only until milestone mode (§10, prompt 06); `status` shows every mode."

**Step 7b: DESIGN §7.1**, one line after the run-dir table: "Flat files directly under `.aew/runs/` are scratch, not runs: init's `init-*` files and ship's blocked comment `blocked-<id>.md` (written with Write, posted with `gh-issue.sh comment`). `status` lists only directories named like a run id."

**Step 8: state-machine.md** (refinements where routing refines an arrow; each label says which gate it is, because `awaiting_input` has several sources):

- Plan `needs_input` (AC-14, cut 8): replace the two arrows "James accepts the spec change" / "James declines…" with one: `awaiting_input --> spec_analysis: plan challenge answered (any answer), revision recorded, the run continues from brief`.
- Plan gate "request changes": label becomes `request changes: senior-engineer re-plans with notes, QA phase A kept`.
- Developer `blocked` (AC-12): `develop --> parallel_planning: blocked (first in the run), senior-engineer re-plans with notes, plan gate unless auto`, plus `develop --> blocked: blocked a second time in the run`.
- Spec ambiguity (AC-13, Assumption 18): replace `awaiting_input --> qa: answered, no material change` with `awaiting_input --> brief: spec ambiguity answered (non-material: brief, then QA phase B; material: every stage from brief)`; add `qa --> awaiting_input: triage needs_input (material by definition)`.
- Gates paragraph: the answers go to spec-analyser first; when it returns `ok` with changes in `spec-changes.json`, the revision is recorded (comment, issue body, `spec-revised`, `spec_revision`) before the next stage. Add after the table: "**Unanswered gate.** If AskUserQuestion is unavailable (headless with `--permission-prompts none`), refused or empty, the gate stays pending (`gate:<id> <file>` note in `history`); ship prints the questions or plan summary and `Answer with /aew:resume <id>`, and stops. `/aew:resume` re-asks it."
- Failure paths, "Agent returns `blocked`" row: "developer in full mode → senior-engineer plan revision with `notes`, once per run (a second full-mode `blocked` → `blocked`); developer in fix mode (review or QA fix) → `blocked` (Phase B PD-3); anything else → `blocked`".
- The mermaid block keeps valid syntax: every new arrow uses existing state names (`spec_analysis`, `brief`, `parallel_planning`, `develop`, `qa`, `awaiting_input`, `blocked`), no transition targets a state nested inside a composite, and labels contain no `:` after the first.

**Step 8b: `scripts/git-branch.sh` help text** (R-7, cut 7). Replace the header's "Local git only; the base branch is updated by preflight, not here." with "Local git only. Preflight checks that the base branch is up to date with origin and never updates it." No behaviour change.

**Step 9: GREEN.**

```sh
grep -c 'updated by preflight' scripts/git-branch.sh                                                                  # 0
grep -c 'Prompt mode and resume' docs/DESIGN.md; grep -c 'blocked-<id>.md' docs/DESIGN.md                              # 1 1
grep -c 'fix mode' skills/run-protocol/references/state-machine.md                                                     # >= 1
grep -c 'headless.md#auto-approve-tools\|tools-reference.md#askuserquestion\|plugins/loading.md\|en/permissions.md' docs/DESIGN.md   # >= 4
grep -c 'mode: init' docs/DESIGN.md; grep -c 'Revision notes' docs/DESIGN.md; grep -c 'Unanswered gate' docs/DESIGN.md      # >= 1 each
grep -c 'is untested' docs/DESIGN.md                                                                                   # 0 for CLAUDE_SKILL_DIR
grep -c 'Answer with /aew:resume' skills/run-protocol/references/state-machine.md                                       # 1
grep -c 'James declines' skills/run-protocol/references/state-machine.md                                                # 0
tests/run-script-tests.sh && claude plugin validate .                                                                  # pass
```

**Step 10: commits** (three: DESIGN, the state machine, and `fix(scripts): say preflight only checks the base branch in git-branch.sh help`):

```
docs(design): record the prompt-05 platform facts, deviations and gate rules

Section 3 gets V-1 to V-7 with their docs URLs (skill arguments and the
Skill-tool block, reference files not substituted, headless Manual mode and
--permission-prompts none, one-message Agent dispatch, AskUserQuestion on
the main thread only, SHA plugin versions, permission-rule matching).
Sections 8.3 and 8.4 record standards-setter init mode and senior-engineer
notes; section 9 adds the unanswered-gate rule, the check-only default
branch and pointers to skills/ship instead of restating its detail, and
lists the recorded deviations C1, C3, C4, C5, the direct gh auth status
and the prompt-mode blocked rule (PC-3), plus the prompt marker (PC-1),
resume's single-run limit (PC-5) and the flat scratch files in .aew/runs.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

```
docs(run-protocol): refine the state machine to match ship's routing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

### Task F8 — Results roll-up, run-observed facts, CHANGELOG, project map, CLAUDE.md (AC-46, AC-47)

- **id:** F8
- **files:** `tests/agent-smoke/README.md` (§9.1 table, §9.9), `docs/DESIGN.md` (§3, only facts the runs established), `CHANGELOG.md`, `docs/superpowers/project-map.md`, `CLAUDE.md` ("Recent changes")
- **depends_on:** [F3, F5, F6, F7]
- **pattern:** §8.1 ledger table format (`| run | id | cost (USD) | running total | cap raised? |`); the CHANGELOG's `[Unreleased]` bullet style; project-map "Key contracts" / "Per-feature learnings" / "Gotchas" one-liners; CLAUDE.md's existing "Recent changes" line format (`date · branch · summary · [spec](…) · [plan](…)`).
- **ACs:** AC-46 (ledger, results), AC-47 (CHANGELOG, project map, CLAUDE.md, final report)
- **Risk:** NOT RISKY.
- **Spend cap:** $0.

**Step 1: RED.** §9.1 has no rows; `grep -c 'prompt 05\|build prompt 05' CHANGELOG.md` is `0`; CLAUDE.md "Recent changes" has no 2026-10-25 line.

**Step 2: ledger.** Render §9.1 from `$SMOKE/ledger-05/*.tsv` in run order (P0a, P0b, P1, G2, I1, I2, G1, S1, run F1, R2, then any re-runs in time order), with the running total, killed sessions marked "cap counted (killed)", and any raise. The total must be ≤ 60.

**Step 3: results.** Every §9.3–§9.8 row reads `pass`, `pass (after fix)`, `recorded` or `flaky` with notes; none `pending` (else the phase reports `DONE_WITH_CONCERNS`). §9.9 lists harness faults, fixes with their commit shas, the cut-driven deviations from the spec's run list (R1 dropped, R2 stops at `review`, one paid bad-argument probe, G1 on init's output, run F1's kill condition refined), and the open items for prompt 07 (interactive gate answers and refusals, the spec-ambiguity, triage, developer-blocked and request-changes routes, and the blocked path, none simulated here). Then `grep -c pending tests/agent-smoke/README.md` counts nothing in §9.

**Step 4: DESIGN §3, run-observed facts only** (each with its run as evidence): whether the Bash tool keeps the launcher's `PATH` and unset tokens (P0; plus the `CLAUDE_ENV_FILE` or settings-`env` fallback and its URL if it was needed); that a killed `-p` session emits no `result` event (run F1, R2); the `system/init` agents-list form (P0b check 10). Skip any fact a fix commit already recorded.

**Step 5: CHANGELOG** `[Unreleased]`:

- `### Added`: the entry skills `init`, `ship` (with `references/` preflight, dispatch, gates, routing, pr, final-report), `resume`, `status` and `prompt`; senior-engineer plan-mode `notes`; standards-setter `mode: init`; `gh-pr.sh open` for run-less PRs; `tests/scripts/skills.bats`; the README command reference and pipeline diagram; simulated orchestrator runs with a mocked `gh` and a local bare origin (`tests/agent-smoke/README.md` §9).
- `### Changed`: the run-protocol state machine follows ship's routing (one rule for a plan challenge, developer `blocked` once, spec-ambiguity re-entry at `brief`, unanswered gates stay pending); DESIGN §3 records the prompt-05 platform facts.

**Step 6: project map** (`## Project knowledge`; append, and correct what is now wrong; don't regenerate the structural part):

- Key contracts: ship's entry points (`## Stage: <stage>` sections, `## Gate pending`, `## Blocked path`) and that `resume`/`prompt` Read them (never the Skill tool); the pending-gate note `gate:<id> <file>` and its `jq` lookup; `gh-pr.sh open` (C-3: stdout is the PR number, reuse makes no create call); init's files and `.aew/runs/init-*` scratch (D-C3); the harness launcher contract (`ship-run.sh <repo> <W> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]`, ledger in `$SMOKE/ledger-05/`).
- Correct the dispatch-field line: standards-setter takes `run_dir`, or `mode: init` with no run dir (Phase A C-4); senior-engineer plan mode takes optional `notes` (last field).
- Mark the CTO-3a and CTO-3b open items resolved (3a: init's anchored per-subcommand proposal, cut 6; 3b: dispatch.md's `tail -n 4` per named report, S1 check 14).
- Per-feature learning: one line for prompt 05 built (what the runs proved, total spend).
- Gotchas: only new ones the runs found (for example the session `PATH` behaviour, the `gh auth token` keychain result from Task F1, killed sessions without a result event, the `Bash(gh *)` deny that would block `gh auth status`).

**Step 7: CLAUDE.md "Recent changes"**, one line in the existing format: `2026-10-25 · <branch from git branch --show-current> · Orchestrator and entry skills (build prompt 05): init, ship (+ six references), resume, status, prompt; senior-engineer notes, standards-setter init mode, gh-pr.sh open; skills.bats; README commands; simulated runs in tests/agent-smoke §9 · [spec](docs/superpowers/specs/2026-10-25-orchestrator-and-entry-skills.md) · [plan](<the consolidated plan's path>)`.

**Step 8: GREEN.** The RED counts are now ≥ 1; `tests/run-script-tests.sh` and `claude plugin validate .` pass; `git -C "$REPO" status --porcelain` shows only this task's five files. Then `rm -rf "$SMOKE"/ship-* "$SMOKE/ledger-05" "$SMOKE/ship-run.sh" "$REPO/tests/tmp/issue-render-"*` (§4's cleanup, deferred until now).

**Step 9: commit.**

```
docs: record the prompt-05 results, changelog, project map and recent changes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

**Step 10: final report** (the phase's report to the caller; AC-47): the checks with results (every §9 table, summarised), the files changed, the deviations from DESIGN (C1, C3, C4, C5, the direct `gh auth status`) and from the spec (cuts 1–5, 10), fixes made during the runs, the total spend, and decisions needed (at least: the commit-attribution policy, still open).

---

## Phase verification (after F1–F8)

1. `tests/run-script-tests.sh` passes; `claude plugin validate .` passes.
2. README §9: the ten headings, no `pending` row, the ledger total ≤ $60, no transcript or stream excerpt longer than a verbatim evidence line.
3. Every paid session in the ledger started through `ship-run.sh` (each has an `$SMOKE/ledger-05` file), P0 passed before the first non-P0 session (ledger timestamps), and every run's `ghcfg` stayed empty.
4. `git log` shows the task commits plus any `fix(…)` commits, each with the trailer.

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-39 helper, rails, P0, invocation, allowlist, ledger | F1 (helper, launcher, allowlists, free canary), F2 (P0a/P0b) | §9.2 code; P0 checks 1–14; `allow-*.txt` hygiene greps |
| AC-40 S1 to a mocked PR | F3 | S1 checks 1–17, incl. `diff` of `expected_s1` and `smoke_pair` |
| AC-41 G1 spec-gate stop | F6 | G1 checks 1–10 |
| AC-42 G2 plan-gate stop (R1 dropped, cut 1) | F4 (live); E1 (resume's re-ask, static) | G2 checks 1–13 |
| AC-43 kill and resume (cut 2) | F5 | run F1 checks 1–5, R2 checks 1–10 |
| AC-44 I1/I2 | F6 | I1 checks 1–12, I2 checks 1–7 |
| AC-45 bad arguments (cut 3) | F2 (P1, live); E1 (all four messages, static) | P1 checks |
| AC-46 results format, repo hygiene, fix loop | F1 (format), F2–F6 (rows, after-run checks), F8 (ledger, roll-up) | §9 tables; `git -C "$REPO" status --porcelain` after each session |
| AC-47 DESIGN, state machine, CHANGELOG, project map, CLAUDE.md, final report | F7, F8 | F7/F8 grep counts; the final report |

## Decisions in this phase (flag if wrong)

1. **P0 is two sessions** (P0a: haiku runs the probe commands; P0b: `/aew:status`), $0.50 each. A slash-command prompt can't also carry probe instructions (they would become `$ARGUMENTS`). Evidence comes from tool results and `system/init`, never the model's prose.
2. **`gh auth status` inside P0a** doubles as proof: the mock logs it, so one `auth status` line in `calls.log` shows the shim answered.
3. **P1 runs in P0's project**, after P0 passes (its "no run dir, no state, no gh call" checks need a project with a config and a seeded issue).
4. **The allowlist drops §8.3's `Bash(gh *)` deny**: deny beats allow, so it would deny the canary itself. Agents are still kept from `gh` by aew's Bash guard hook (`scripts/hooks/guard-bash.sh` `guard_gh` denies every `gh` command when the payload's `agent_type` is `aew:*`); an agent calling a `scripts/gh-*.sh` wrapper by path isn't caught by the guard, but it still reaches only the shim.
5. **Run F1 is killed on "stage `develop` and the developer Agent call in the stream"**, not on the state alone, so the kill falls during develop rather than between `--from`'s state write and the dispatch (refines Assumption 8).
6. **Killed sessions count their cap** in the ledger, since they emit no `result` event.
7. **Ledger files under `$SMOKE/ledger-05/`**, summed by the launcher before each start (reserved caps for sessions still running), so parallel lanes can't overrun $60. The README table is rendered once, by Task F8.
8. **S1 waits for G2** (budget ordering): an $8 failure in the shared prefix is cheaper than a $25 one.
9. **G1 gets a fresh mock dir** (init's is kept as `gh-init`), so its checks read only its own calls.
10. **The retro override is a harness commit** on the fixture copy (static-shop: before the fixture commit; nextjs: after I2, so I2's "nothing changed" stays true).
11. **The blocked comment is written with Write to `.aew/runs/blocked-<id>.md`**, settled now rather than probed (architect review): `mktemp` + a heredoc to `$TMPDIR` writes outside the working directories, which `acceptEdits` would deny headless and prompt for interactively, and it needs a broad `Bash(cat > *)` rule; the blocked path isn't simulated here, so a probe would prove a form no run exercises. The file is gitignored, flat beside init's scratch files (R-6), outside every run dir (Assumption 20 holds; no run-dir row in DESIGN §7.1, whose Step 7b line only names the flat scratch files), and left in place (overwritten on the next block). P0a check 8 proves the Write form. Needs a Phase B reconciliation (cross-phase notes).
12. **Parallel lanes, at most two paid sessions at once**; fixes to a shared skill or agent are merged before the other lane's next launch.
13. **`GH_HOST=aew-smoke.invalid` in every session** (architect review): a keychain-held token isn't hidden by an empty `GH_CONFIG_DIR` for certain, and this one variable sends any real `gh` call to a non-existent host. Task F1's `gh auth token` checks record both cases.

## Cross-phase notes (for the consolidator)

- **Phase B (reconciliation needed, R-8 proposed):** `## Blocked path` steps 1–3 and I-8's "Blocked comment" line change to: write the comment with the Write tool to `.aew/runs/blocked-<id>.md`, then `gh-issue.sh comment <n> .aew/runs/blocked-<id>.md` (no `mktemp`, no heredoc, no removal). Phase B's cross-phase note on "allowlist matching" drops the heredoc half; Phase D's cross-phase item 3 (the `mktemp` form "will prompt interactively") is resolved, because Write inside the project needs no rule. Task F1 checks `grep -rl mktemp skills/ship | wc -l` is `0` before any paid run. `expected_s1` is I-9 verbatim; if B8 changes the call order or the label at any stage, `expected_s1` changes before S1, never after.
- **Phase C:** R2 requires `resume` to handle a `running` run killed mid-stage by re-dispatching the recorded stage (AC-21) and to treat `.claude/agent-memory/`-only changes as clean (PD-2). Phase C's `status` must list only directories under `.aew/runs/` (P0b check 12, Decision 11's file, D-C3's scratch files).
- **Phase D:** this plan follows D-C4 as currently written (I2 = one `pr list` reuse via `responses/pr-list.2.out`, no push, no `pr create`) and copies the D2 reference proposal at run time; the merged D-C4 wins if it changes again.
- **Phase E:** E1 must cover AC-45's four messages and resume's pending-gate re-ask (cut 1), because the live runs no longer do.
- **R-7 items owned here:** PC-1, PC-3, PC-5 (DESIGN §9, Task F7 Step 7), PD-3 (state-machine failure paths, Step 8), and the `git-branch.sh --help` wording (Step 8b).

## Risks

- **A real `gh` reached** (the Bash tool's profile-initialised shell, an exported token in the user's profile). Layered rails 1–8; P0 gates everything; the free canary proves an unauthenticated real `gh` fails `gh auth status`; `ghcfg` must stay empty after every session; fallback (a) re-asserts the environment per Bash call.
- **Budget:** caps total $56 of the $60 stop, so a large re-run (S1) may not fit. The launcher refuses rather than overrun, and the phase then reports `DONE_WITH_CONCERNS` with the open checks.
- **spec-analyser classes #201 as material** (the email AC): G2/S1 stop at the spec gate. The mock-only body tweak fixes the harness, never the check.
- **Kill timing:** the developer may write files before the kill lands. Assumption 8's path (R2 refuses the dirty tree, the harness discards, R2 re-runs) is planned and costs at most one extra R2 session.
- **Long wall-clock** (S1 about an hour): sessions run in the background and are waited for; foreground Bash timeouts don't apply.
- **Procedure drift** in the model-followed skills: every check reads state, labels, `calls.log` and tool calls, not the model's summary, and a failure goes to the fix loop.
- **Merge conflicts between parallel tasks:** each task owns one README subsection, separated by unchanged heading lines; the ledger stays outside the repo until Task F8.

## Approval (Phase F)

- Senior architect: APPROVED 2026-10-25T00:34:05Z (plan-review, with mechanical fixes applied in review: `GH_HOST=aew-smoke.invalid` rail plus the free `gh auth token` keychain checks; allowlist gains `tail -n *`, `grep -c *`, `cat .aew/runs/current` and loses `mktemp`/`cat > *`; blocked comment settled as Write to `.aew/runs/blocked-<id>.md` (Decision 11, Phase B reconciliation R-8 proposed); Task F5 also depends on Task F6; Task F7 owns PC-1, PC-3, PC-5, PD-3, §7.1 scratch files and the `git-branch.sh` help fix)
- Plan format: FULL
- Plan dependency graph: valid (no cycles, no dangling refs). Wave count: 5. Max wave width: 2 tasks; at most 2 paid sessions at once.
- Plan content hash (SHA-256, the document above this trailer): a5e19b7d12a8d962f2fbc84ea7f38835febe5f7ed1e0cb25182bbf1a033575b4

---


## Approval

- Senior architect: APPROVED per phase (trailers inline: see each "## Approval (Phase A…F)" above)
- Plan format: EPIC consolidated (A lean · B full · C lean · D full · E lean · F full)
- Simplicity-challenge: SIMPLER-PATH, 11 cuts adopted
- CTO: APPROVED WITH CONDITIONS on 2026-10-25T00:43:37Z, mode: risk-gate (consolidated; risk-gate on D5 and phase F, routine-signoff on A, B, C, E)
- Conditions: CTO-1 … CTO-5 (section "CTO conditions" above)
- Plan content hash (SHA-256, the document above this section): c798b7baa8f0f2e72770e25bd974a383204b28e4e6d0e35ba927e22913fb8b77
- Human (developer): APPROVED on 2026-10-25T07:36:19Z (with decision: plugin-script rules in gitignored `.claude/settings.local.json`; micro-revision senior-approved)
- Plan content hash at approval: c798b7baa8f0f2e72770e25bd974a383204b28e4e6d0e35ba927e22913fb8b77

---

## Amendments after approval (2026-10-25)

Recorded after the human approval above. This section sits below the approval trailer, so it is outside both
content hashes (`c798b7ba…8b77` covers only the document above the consolidated `## Approval`); neither hash is
recomputed and no approved text above is edited. Where an amendment and the approved text disagree, the amendment
wins for the tasks still to run.

1. **P0.1 finding (Task F2, P0 BLOCKED).** Under `--permission-mode acceptEdits --permission-prompts none`, Claude
   Code denies some Bash forms in a pre-check before any allow rule is consulted: a `$VAR` expansion, a `"$(…)"` or
   backtick substitution, `jq --arg` before the filter (the filter is then path-checked) and jq's file-reading
   flags. P0a steps 4 and 7 and P0b's status listing were denied that way; interactively each such command prompts
   every time. The probes RULES.1 and RULES.2 mapped the forms. **James's decision:** rewrite the skills inline so
   every Bash command is pre-approvable headless; no new scripts. Done in RW1 (ship), RW2 (resume, status,
   prompt), RW3 (init), RW4 (harness) and RW5 (reconciliation and the static guard).
2. **Rules H1 to H8, M1, M2** (the Rewrite guide; DESIGN §3 records them in Task F8, which is then the reference):
   H1 no shell parameter expansion outside single quotes (`${CLAUDE_PLUGIN_ROOT}` and `$ARGUMENTS` are
   substituted at load); H2 no `$(…)` or backticks; H3 jq `--arg`/`--argjson` after the filter; H4 `--arg` values
   plain tokens; H5 no jq `--slurpfile`, `--rawfile`, `-f`, `-L`, `system(`, `include`, `import`; H6 heredoc
   delimiters quoted; H7 no brace expansion; H8 no awk `system(`, `| "cmd"`, `| getline`, `@load`/`@include`; M1 no
   `VAR=value cmd` prefix; M2 every leading form either runs without a rule or has one in init's templates. An
   exact allow rule beats the variable check but not the jq checks. `tests/scripts/skills.bats` test 17 ("every
   skill command is pre-approvable headless") enforces H1 to H8 and M1 over the five entry `SKILL.md` files and
   `skills/ship/references/*.md`; M2 is checked per lane against the allow files (README §9.2).
3. **init's templates (D-C4, D5, AC-31 row).** Template 1 (`.claude/settings.local.json`) keeps 8 rules. Template
   2 (`.claude/settings.json`) has 19: RW3 added `git rev-parse *`, `git check-ignore *`, the exact `git
   symbolic-ref --quiet --short refs/remotes/origin/HEAD`, `git ls-remote --symref origin HEAD` and `git restore --
   .claude/agent-memory/aew-standards-setter/`, `command -v *`, `echo *` and `printf *`; RW5 removed `git rev-list
   --left-right *` (Check 4 now uses two auto-allowed `git rev-list --count` calls, and init never ran it). The D2
   fixture proposal is therefore **25 portable** rules (19 + the 6 config rules) and **8 local**, where D-C4, D5's
   reference list and GREEN, and the AC-31 row say 17 and 8; D5's merged-into-fixture allow count is **26** (was
   18). `test`, `tail -n` and `grep -c` get no rule: the Claude Code 2.1.308 bundle's read-only tables allow them
   (`test` and `grep` safe-flag tables, `tail` in the read-only command list), alongside RULES.2's observed `[`,
   `grep -n`, `tail -c`. `awk`, `node -p` and the `npx … ajv validate` line (its `-c` loads a module) stay
   deliberately not pre-approved and prompt interactively.
4. **D1, D4, D6 expected output (RW3's rewrite).** D1: `run 1 1` prints a `command -v` path per found tool (a
   missing tool prints nothing) and the `node --version` line, instead of `ok …` / `missing …` / `old node …`, and
   the skill judges them; `run 1 2` prints `git rev-parse --show-toplevel --show-prefix` (an empty prefix line at
   the root) then `git remote -v`; the diverged-branch case prints the stop line and exits 0 with the branch
   unchanged (no `exit 1`: the skill stops on the printed line). D4: §9 is two snippets, the first prints `CLAUDE.md
   section missing` or `present`, the second appends and prints `CLAUDE.md section added`. D6: §11's memory discard
   and §12's push decision are read by the model from printed output (`git status --porcelain
   --untracked-files=all`, the untracked memory list removed with literal `rm -f` paths, `unpushed <n>` / `ahead
   <n>` lines). D6's `$W/pass.sh` is stale: use the scratchpad `rw3-pass.sh`, which runs the split snippets.
5. **P0a probe (README §9.3, RW4).** Step 4 is `env | grep -E
   '^(GH_CONFIG_DIR|GH_MOCK_DIR|GH_HOST|GIT_CONFIG_COUNT|GIT_TERMINAL_PROMPT|GIT_SSH_COMMAND)='` (no `$`, no secret
   printed, no audit hit). Step 7 (`"$(jq …)"`) becomes step 7, `jq -r .project .aew/config.json`, and step 8, a
   literal double-quoted `state.sh set title "…"`, the form ship step 3.5 now uses; with no run, step 8 exits 1 and
   writes nothing, and the evidence is the absence of a pre-check denial. P0 re-runs as P0a.2 and P0b.2.
6. **Phase F allowlists and I1 counts.** F1's allowlist text (orchestrator rules list, item 4's init list) is
   superseded by `smoke_ship_allow` as merged in README §9.2 after RW5: every lane gets the scripts and the shared
   forms; `ship`/`p0` add ship's forms and the agents' git reads; `init` adds init's forms, the `npx … ajv validate`
   line included. Allow files: ship 85 lines, p0 90, init 44. I1 check 9 expects the printed proposal to list 25
   portable and 8 local rules; I1 check 11 still expects `permission_denials` `[]`, which now rests on the init lane
   covering every init form.
