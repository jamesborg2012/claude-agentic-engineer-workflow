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
| 9 | no settings written; Playwright skipped | `test ! -e "$P/.claude/settings.json" && echo absent`; `smoke_res "$O"` | `absent`; the report lists the printed permissions proposal, "Playwright skipped" and the defaults used |
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
