# Plan — e2e-validation (EPIC · 5 phases)

Build prompt 07: prove `aew` on real GitHub, fix what breaks, triage the retro items and release 0.1.0.
Spec: [`docs/superpowers/specs/2026-10-26-e2e-validation.md`](../specs/2026-10-26-e2e-validation.md)
(senior APPROVED, NOVEL / EPIC). No issue. Execution is phase by phase, serial in the main checkout
on `feature/e2e-validation`; every human checkpoint is a STOP-for-James step.

## Context manifest

**Reference files** (downstream agents read these first):

- `docs/build-prompts/07-e2e-validation.md`: steps, scenarios and ACs.
- `docs/DESIGN.md` §3 (platform facts to re-verify; the dependency tag format), §4 (dependencies, prerequisites, why superpowers has no version range), §6 and §6.1 (project files and config, for the README), §7.4 (labels), §9 (preflight, gates, the unanswered gate, every run ends in a PR), §10 (milestone rules and stacking), §11 (the guard list, so a false-positive fix keeps every protection) and §12 (the quality bar).
- `tests/agent-smoke/README.md` §9 (rails 1 to 9, the §9.1 ledger rules, the §9.2 launcher reference copy, the kill-stage trigger, the post-session audit) and §10 (the milestone harness, the §10.6 roll-up format, and §10.7's prompt-07 carry-overs). This is the pattern for `e2e-run.sh` and for the record format of `tests/e2e-validation.md`.
- `docs/superpowers/project-map.md` `## Project knowledge`: the headless pre-check rules (H1 to H8, M1, M2), the CTO conditions C2 and C3, and the open items carried to prompt 07.
- `README.md` (Install, Dependencies, Commands done; Config reference, Labels and Uninstall still "to be written"), `CHANGELOG.md` (`[Unreleased]` only, never released), `.claude-plugin/plugin.json` (version `0.1.0`, untagged) and `.claude-plugin/marketplace.json` (`jamesborg-plugins`, source `./`, cross-marketplace allow).
- `scripts/hooks/guard-bash.sh`, `guard-edit.sh` and `tests/scripts/fixtures/hooks/bash-cases.tsv`: where a guard false positive is fixed and pinned.
- `skills/github-ops/SKILL.md:75`: the real-issue-body limitation that AC-20 removes.
- `skills/init/SKILL.md` (507 lines, over the 500-line guidance) and `skills/ship/references/*.md`: likely fix sites.
- `docs/superpowers/specs/2026-10-26-milestone-mode.md`: the format analog.

**Key facts learned from the codebase and machine (2026-10-26):**

- Claude Code is 2.1.308, Node 26.12.1 and gh 2.103.
- superpowers 7.0.0, context7 and frontend-design (`58267944f921`), dev-workflow, figma and warp are all installed and enabled at user scope. `claude-plugins-official` is already a configured marketplace. `jamesborg-plugins` is **not** added yet. The `jamesborg` marketplace is the separate dev-workflow repo, so the names don't clash.
- The git remote is `jamesborg2012/claude-agentic-engineer-workflow`. It has no tags. `aew-sandbox` doesn't exist. No retro issues are open.
- Docker is installed at `/usr/local/bin/docker`, but its daemon is not running.
- No ancestor `CLAUDE.md` exists above the sibling sandbox path.
- The prompt-05 and prompt-06 `$SMOKE` launchers were deleted, so the launcher is rebuilt from the README reference copy.
- The C3 condition requires a PAT scoped to the sandbox only. Retro items are therefore filed in a sandbox retro repo, then transferred to the plugin repo at step 6 (Assumption 4).
- The plugin's own Bash guard (and dev-workflow's) blocks commands whose text contains `git push`. Launches and harness steps therefore go in script files run with `/bin/bash`. `git-branch.sh push` is not affected.
- A killed `-p` session emits no `result` event, so its cost is charged at the cap. `--max-budget-usd` includes subagent spend, and the model budgets against its own cap, so each cap must cover the whole scenario (§10.7).


## Assumptions

Copied from the spec. Two are amended by the simplicity-challenge (marked **Amended**).

1. **Assumed:** this spec plans the protocol, not the fixes. Each fix is a separate conventional commit on `feature/e2e-validation`, through AC-28. Reason: fixes can't be known before the runs.
2. **Amended:** S6 now runs headless with `--sequential --auto` (simplicity-challenge cut 2), so attended sessions are init, S1, S3 and S5. Original: the drive mode per scenario is the one in the CP-1 table. Attended interactive sessions are used only where a question must be answered (init, S1, S3, S5, S6). Everything else runs headless through the rebuilt launcher (S2, S4, S7, S8), which is cheaper of James's time and reproducible. Reason: AskUserQuestion is absent headless (DESIGN §3), and headless runs are the proven harness. **Flag if wrong.**
3. **Assumed:** dependency auto-install is proven in an isolated, throwaway Claude config, not by uninstalling James's user-scope superpowers, context7 and frontend-design (which other plugins and sessions use). Reason: it is the same proof and touches nothing of his. **Flag if wrong**, if a real uninstall-and-reinstall at user scope is wanted.
4. **Decided at spec review (keeps C3):** the PAT selects only the sandbox repos (`aew-sandbox`, `aew-sandbox-retro`, and `aew-sandbox-woo` for S9).
   - `retro.repo` is `jamesborg2012/aew-sandbox-retro`, which still exercises `gh-retro.sh`'s cross-repo `--repo` path and its "Seen again" de-duplication on real GitHub.
   - At step 6 the executor transfers the items to the plugin repo under its own keychain token (AC-29).
   - Reason: a fine-grained PAT's permissions apply to every selected repo. Adding the plugin repo would hand agents contents and pull-request write on it, and widening the PAT would change a CTO condition, which is not the executor's call.
5. **Assumed:** at init, James accepts the Playwright offer. Reason: the prompt says "No Playwright yet" for the sandbox, which reads as "let init or `ui-qa` set it up", and S2 needs committed specs. **Flag if wrong**, if `ui-qa`'s own setup during S2's QA should do the install instead.
6. **Assumed:** dev-workflow, figma and warp are disabled for the sandbox only (AC-8). Reason: dev-workflow's own guard and session skill would otherwise act in aew's runs and blur the guard false-positive AC. James's normal use may have them on, so the README's troubleshooting notes the interaction. **Flag if wrong.**
7. **Assumed:** the launchers, the token file, the ledger and the streams live in `/Users/jamesborg/Documents/Development/aew-e2e` (a sibling, not a repo), not in `$TMPDIR`. Reason: this prompt spans days, and `$TMPDIR` may be cleared. Nothing there is ever committed, and the ledger is copied into `tests/e2e-validation.md` after each session. This is minor.
8. **Assumed:** S7 "Ctrl-C" is reproduced by the launcher sending SIGINT to a headless `--auto` run at `develop` (the F1/R2 precedent), and status, the hint and resume are proven headless. Reason: it is deterministic, it needs no plan gate, and it leaves the same state as an interactive Ctrl-C. **Flag if wrong**, if James wants to press Ctrl-C himself in an attended run.
9. **Assumed:** S8's plugin-less session runs headless with `prompt.md` as its prompt (the equivalent of pasting), in a separate local worktree beside the sandbox (`aew-sandbox-s8`). It has no `GH_TOKEN` and no `git push` or `gh` in its allowlist, and it is never pushed. Its local branch and worktree are removed afterwards, which is a local cleanup, not a GitHub deletion. Reason: it keeps `main` clean for the next scenario and costs none of James's time. **Flag if wrong.**
10. **Assumed:** `plugin.json` stays `0.1.0`. The fixes land inside the unreleased 0.1.0, because nothing was released before it, and the CHANGELOG's `[Unreleased]` becomes `[0.1.0]`. Reason: "bump if anything changed" refers to an already-released version. A fixed version through the validation also keeps the cached `installPath` stable for init's settings (V-3). **Flag if wrong.**
11. **Amended:** caps restated in Phase A (A5) to $150.50 plus a $49.50 reserve after the cuts; the $200 stop is unchanged. Original: the spend envelope is $151.50 of caps plus a $48.50 reserve, with a **stop of $200** and S9 extra only if $25 remains (CP-1). Reason: the scaled prompt-05 and prompt-06 measurements. **Flag if wrong** (the budget is James's call).
12. **Assumed:** each ship-style scenario waits for its predecessor's merge, and only S8 (and S9) run in parallel with a pending merge. Reason: every PR curates `CLAUDE.md`, and aew never rebases.
13. **Assumed:** the scenario issues are created up front (AC-13). S3's body is deliberately ambiguous, and any fixture tuning (the §9.5 and §10.7 precedent) is recorded beside the body, never hidden.


## Phase graph

- Phase A (depth: full · risk: credentials/infra) — Platform checks, real install, sandbox repos and rails — depends_on: []
- Phase B (depth: full · risk: real issue-body rewrites) — init, fixtures and the serial scenarios S1 to S7 — depends_on: [A]
- Phase D (depth: lean · risk: none) — Prompt mode and plugin-less build (S8) — depends_on: [B1 init merge, B2 fixtures]
- Phase E (depth: lean · risk: none) — Optional WooCommerce sandbox (S9) — depends_on: [A]; its CP-5 question is asked only once S1–S8 are recorded
- Phase F (depth: full · risk: release tag) — Retro triage and the 0.1.0 release — depends_on: [B, D, E]

Waves: 1=[A]  2=[B (D starts once B1+B2 are done; D's sessions run while a B merge is pending)]  3=[E]  4=[F].
Phase C no longer exists (merged into B by the simplicity-challenge).

**One launcher interface for every phase** (defined in A4):
`e2e-run.sh [--plugin-less] <project> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]`,
`e2e-run.sh [--plugin-less] --env-check <project> <cmd…>`, `e2e-session.sh <project> <run> <cap>`.

## Phase A — Platform checks, real install, sandbox repos and rails

- **ACs:** AC-1 to AC-10 (spec `docs/superpowers/specs/2026-10-26-e2e-validation.md`). **depends_on:** none. **Depth:** full. **Risk:** credentials/infra.
- **Simplicity-challenge decisions applied here (they override the spec):**
  - **Cut 6.** All the Claude Code facts (V-1 to V-6, V-8, V-9, V-12, V-13) go in **one** batched claude-code-guide dispatch (A1).
  - **Cut 6.** V-10 (token and credential precedence) and V-11 (`gh repo create --source --push`) are proved by running them: in A3 (repo create) and A6 (canary), with the command and its output recorded. V-11 milestones are proved by Phase B's fixtures. V-10's `gh issue transfer` is proved in Phase F.
  - **Cut 1, partly.** V-7 (SessionStart output in a headless stream) is recorded from Phase B's headless `/aew:status` stream, not from a probe. A1 records it as "runtime, Phase B".
  - **Cut 4.** AC-10 records the changed env lines plus the C3 broad-lines decision, **not** a launcher diff.
  - **Cut 2 and Cut 1.** The CP-1 ledger that James approves in A5 carries S6 as headless (`--sequential --auto`) and has no separate hint probe.
- **Paths used throughout:**
  - `REPO=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow`
  - `SB=/Users/jamesborg/Documents/Development/aew-sandbox` (its own git repo; neither it nor `$E2E` exists today)
  - `E2E=/Users/jamesborg/Documents/Development/aew-e2e` (plain directory, mode 700, never a repo, never committed)
- **For the CTO risk gate (named so it is ruled on now, not discovered at A6):** canary row 9 is expected to show the keychain `gh` token still reachable with `GH_TOKEN` removed (`docs/superpowers/project-map.md` gotcha: an empty `GH_CONFIG_DIR` does not hide it; §9.2 rail 3). C3 says "make the keychain token unreachable", so option (a) below is a C3 deviation. The CTO states whether (a) is acceptable before A5; James still makes the call at A6 and it is recorded.
- **Execution conventions:**
  - Before A1, create the branch in the main checkout: `git -C "$REPO" switch -c feature/e2e-validation` (the uncommitted spec and project-map edits come with it).
  - Every plugin-repo commit is made in the **main checkout** on `feature/e2e-validation`, never in a worktree. The marketplace is added from the main checkout's path, and the launcher's git guard hashes that checkout.
  - Commit trailer is `Co-Authored-By: Claude <noreply@anthropic.com>` only (repo CLAUDE.md overrides the session line). This applies to the sandbox commits too.
  - Any command whose text contains `git push` goes in a script file written with the Write tool and run with `/bin/bash`, because aew's and dev-workflow's Bash guards block it (§9.2 note).
  - The token value is never printed, echoed, cat-ed, recorded or passed through the executor's own session.
- **Nothing in Phase A pushes the plugin repo.** The only GitHub writes are A3's two `gh repo create` calls and the sandbox's initial push, all under the executor's own keychain `gh`. That is not a session (AC-9 governs sessions).

### Order and parallelism

| Wave | Tasks (concurrent within a wave) | Why |
|---|---|---|
| 1 | **A1** ∥ **A3** | A1 is docs research. A3 is local scaffolding plus repo creation, and needs no V-fact (V-11 is proved by running it). |
| 2 | **A2** ∥ **A4** (A3 may still be running) | A2 needs V-1/V-2 from A1. A4 needs V-8/V-9 from A1. |
| 3 | **A5 STOP (CP-1 + CP-2)** ∥ **A8** | A5 needs A3's repos (a PAT can only select repos that exist) and A4's ledger. A8 needs A1 and A2. |
| 4 | **A6** canary | Needs the PAT (A5) and the launcher (A4). |
| 5 | **A7** install probe (first paid session) | Needs A2, A3 (incl. the AC-8 file), A6 clean, CP-1 approved and A8's refresh finished (no plugin refresh may run during a paid session). |
| 6 | **A9** record and commit | Needs everything above. |

Commits touch shared files, so they are serialised by the executor:

- A1 creates `tests/e2e-validation.md`.
- A2 and A9 edit it.
- A8 edits `README.md`.

**Phase exit (handed to Phase B):**

- the recorded `installPath` and the proven refresh commands;
- a working `e2e-run.sh` / `e2e-session.sh` with an approved ledger;
- a clean canary;
- the allow-file rule for ship runs (the C3 decision, A9);
- `$SB` on `main`, pushed, with the AC-8 file in place.

---

### A1 — Verify the platform facts (one batched claude-code-guide dispatch)

- **id:** A1
- **files:**
  - `tests/e2e-validation.md` (new)
  - `docs/DESIGN.md` (only if a fact contradicts §3 or §11)
- **depends_on:** []
- **ACs:** AC-1
- **risk:** none
- **pattern:** `tests/agent-smoke/README.md` §9.2 "Platform facts the harness relies on (checked 2026-10-25)". Same form: the fact, a short quote, the doc URL and the date checked.

**Steps**

1. Dispatch **one** `claude-code-guide` agent with the ten questions **V-1 to V-6, V-8, V-9, V-12 and V-13**, copied verbatim from the spec's "Platform facts to verify" list. Ask for each answer:
   - a direct quote;
   - the code.claude.com/docs URL;
   - "not documented" where that is the case (never an inference).
2. Create `tests/e2e-validation.md` with this skeleton, in this order (AC-26 as trimmed by Cut 4; later phases fill their sections in place and add one `## S<n>` section per scenario between `## Sandbox fixtures` and `## Guard false positives`):
   - `# End-to-end validation on real GitHub (build prompt 07)`, with one line pointing at the spec;
   - `## Environment`;
   - `## Platform facts`;
   - `## Rails and launchers`;
   - `## Spend ledger`;
   - `## Sandbox fixtures`;
   - `## Guard false positives`;
   - `## Fix log`;
   - `## Retro triage`;
   - `## Roll-up`.
3. Fill `## Environment` from these commands:
   - `claude --version`;
   - `gh --version | head -n 1`;
   - `node --version`;
   - `claude plugin list --json | jq -r '.[] | "\(.id) \(.version) \(.enabled) \(.scope)"'`.

   Expected now (2026-10-26): Claude Code 2.1.308 or later, gh 2.103, Node 26.12.1, and the six user-scope plugins (context7 and frontend-design `58267944f921`, superpowers `7.0.0`, `dev-workflow@jamesborg`, `figma@claude-plugins-official`, `warp@claude-code-warp`). aew is not listed yet.
4. Fill `## Platform facts` with one table row per V-1 to V-13: `| V-n | question | answer (quote) | doc URL | checked | DESIGN impact |`.
   - The V-7 row reads "runtime: recorded from Phase B's headless `/aew:status` stream (Cut 1)".
   - The V-10 and V-11 rows read "proved by running: A3 / A6 (repo create, canary); milestones in Phase B; `gh issue transfer` in Phase F (Cut 6)".
5. Compare against DESIGN §3 and §11, chiefly:
   - V-1 against the install line;
   - V-4 against §3 line 61 ("tags named `<plugin>--v<version>` on the dependency's repo");
   - V-13 against §3 line 42.

   Where the docs contradict DESIGN, edit DESIGN §3/§11 in this same commit and name the change in the row's "DESIGN impact" cell.

**Verification**

```sh
grep -cE '^\| V-([1-9]|1[0-3]) \|' "$REPO/tests/e2e-validation.md"        # 13
grep -E '^\| V-(1|2|3|4|5|6|8|9|12|13) \|' "$REPO/tests/e2e-validation.md" | grep -vc 'https://code.claude.com/docs'   # 0 (each Claude Code fact cites the docs)
grep -E '^\| V-' "$REPO/tests/e2e-validation.md" | grep -c '2026-'        # 13 (every row dated)
grep -c '^## ' "$REPO/tests/e2e-validation.md"                           # 9
git -C "$REPO" diff --stat                                                # tests/e2e-validation.md (+ docs/DESIGN.md only if a contradiction was found)
```

- **Decision recorded for later tasks:**
  - V-1 → the commands A2 runs.
  - V-2 → A2's isolation mechanism.
  - V-3 → A8's refresh commands.
  - V-6 → A7's MCP check.
  - V-8 → whether A4's attended mode passes `--max-budget-usd`.
  - V-9 → A4's kill signal.
  - V-13 → A3's AC-8 file.
- **Commit:** `docs(e2e): verify the platform facts before the real install` (add `and correct DESIGN §3` to the subject if DESIGN changed).

---

### A2 — Real user-scope install and the isolated dependency proof

- **id:** A2
- **files:**
  - `tests/e2e-validation.md` (`## Environment`: an "Install checks" table)
  - outside the repo: `$E2E/iso-config/` (throwaway, removed at the end)
- **depends_on:** [A1]
- **ACs:** AC-2, AC-3
- **risk:** **infra**. It changes James's user-scope Claude config: aew becomes enabled in every session. Its hooks are inert outside a repo with `.aew/config.json` (`scripts/hooks/guard-bash.sh` line 9: "Active only in repos with .aew/config.json; every failure allows"). The rollback is the V-12 uninstall commands.
- **pattern:** the commands V-1 and V-2 confirmed. The expected shapes are below; if A1's facts differ, use A1's and record the difference.

**Steps**

1. Write `git -C "$REPO" rev-parse HEAD` and `git -C "$REPO" status --porcelain` into the table. The cached copy is a snapshot of the working tree at this moment.
2. Run the real install:
   - `claude plugin marketplace add "$REPO"`
   - `claude plugin install aew@jamesborg-plugins --scope user`
3. Record `installPath` (V-3). Phase B depends on it, because init's `.claude/settings.local.json` names the scripts by that path:

   ```sh
   claude plugin list --json | jq -r '.[] | select(.id=="aew@jamesborg-plugins") | .installPath'
   ```
4. Run the isolated proof (AC-3), with the mechanism V-2 confirmed (expected `CLAUDE_CONFIG_DIR`):
   1. `mkdir -m 700 -p "$E2E"`.
   2. Hash the real plugin list first: `claude plugin list --json | shasum`.
   3. `ISO="$E2E/iso-config"; rm -rf "$ISO"; mkdir -p "$ISO"`.
   4. Confirm the isolated config starts empty: `CLAUDE_CONFIG_DIR="$ISO" claude plugin list --json`.
   5. `CLAUDE_CONFIG_DIR="$ISO" claude plugin marketplace add "$REPO"`.
   6. `CLAUDE_CONFIG_DIR="$ISO" claude plugin install aew@jamesborg-plugins --scope user`.
   7. List again, as in the verification below.

   If V-2 says `claude-plugins-official` must already be a known marketplace in a fresh config, add it first with the command V-2 gives and record that. The proof still holds: none of the three dependencies is installed by its own command.
5. Check that the real config was untouched: `claude plugin list --json | shasum` must equal the hash from step 4.2. Then `rm -rf "$ISO"` (local scratch only).
6. **Conditional STOP-for-James** (only if the isolated config demands an interactive login for `plugin` commands). Ask James: *"The isolated dependency proof needs a login in a throwaway config at `$E2E/iso-config`. Log in there once (I'll give you the exact command), or accept AC-3 as proven by the docs quote in V-2 plus the user-scope list?"* Recommend the login: AC-3 says "proven, not inferred".

**Verification**

```sh
claude plugin list --json | jq -r '.[] | select(.id|test("^(aew@jamesborg-plugins|superpowers@claude-plugins-official|context7@claude-plugins-official|frontend-design@claude-plugins-official)$")) | "\(.id) \(.version) \(.enabled) \(.scope)"' | sort
#   aew@jamesborg-plugins 0.1.0 true user
#   context7@claude-plugins-official 58267944f921 true user
#   frontend-design@claude-plugins-official 58267944f921 true user
#   superpowers@claude-plugins-official 7.0.0 true user
CLAUDE_CONFIG_DIR="$ISO" claude plugin list --json | jq -r '.[] | "\(.id) \(.enabled)"' | sort    # (before rm) exactly 4 lines, the same 4 ids, all true
test -d "$(claude plugin list --json | jq -r '.[] | select(.id=="aew@jamesborg-plugins") | .installPath')" && echo ok   # ok
```

- The table records all of this: the installPath, the HEAD at install, the four ids and versions, both hashes (equal), and the isolated list.
- **Commit:** `docs(e2e): record the real install and the isolated dependency proof`

---

### A3 — Sandbox app, the two private repos and the AC-8 settings file

- **id:** A3
- **files** (all outside the repo):
  - committed in the sandbox: `$SB/` (`package.json`, `package-lock.json`, `app/page.tsx`, `app/layout.tsx`, `app/globals.css`, `app/api/contact/route.ts`, `app/api/contact/route.test.ts`, `eslint.config.mjs`, `tsconfig.json`, `next.config.ts`, `postcss.config.mjs`, `.gitignore`, `README.md`, plus whatever else the generator writes);
  - never committed: `$SB/.claude/settings.local.json` (gitignored).
- **depends_on:** [] (the version checks use npm/context7, not A1)
- **ACs:** AC-6, AC-7, AC-8 (the V-11 `--source --push` half is proved here)
- **risk:** **infra**. It creates two private GitHub repos and pushes the sandbox's `main`. Repos are never deleted (CP-6).
- **pattern:**
  - spec AC-7 (the app's shape);
  - DESIGN §3 line 42 (disable only unrelated plugins; a disabled dependency stops aew loading);
  - V-13 (the `enabledPlugins` override).
- **UI note:** the page is a deliberately plain test fixture. frontend-design is exercised by aew's own agents in S1/S2, not here.

**Steps**

1. Pre-checks:
   - `gh repo view jamesborg2012/aew-sandbox` and `gh repo view jamesborg2012/aew-sandbox-retro` both fail (absent);
   - `test ! -e "$SB"`;
   - no ancestor `CLAUDE.md`: `ls /Users/jamesborg/Documents/Development/CLAUDE.md /Users/jamesborg/Documents/CLAUDE.md /Users/jamesborg/CLAUDE.md 2>/dev/null` prints nothing.
2. Look up the current releases (never from memory):
   - `npm view create-next-app version`, `npm view next version`, `npm view vitest version`;
   - the create-next-app flags from context7 (`/vercel/next.js` docs): TypeScript, Tailwind, ESLint, App Router, no `src/`, npm.
3. Scaffold, from `/Users/jamesborg/Documents/Development`: `npx --yes create-next-app@<exact> aew-sandbox <flags from step 2>`.
   - If the generator writes `AGENTS.md` or `CLAUDE.md`, delete them and record it. The sandbox starts with no `CLAUDE.md`, so init's section is the only curated content.
4. Build the app to AC-7:
   - `app/page.tsx`: a client form with labelled name, email and message fields. It POSTs JSON to `/api/contact` and shows a short success line on `{ok:true}`.
   - `app/api/contact/route.ts`: `export async function POST(request: Request)` returns `Response.json({ ok: true })` (status 200) and stores nothing.
   - `app/api/contact/route.test.ts` (Vitest, node environment): calls `POST(new Request('http://localhost/api/contact', { method: 'POST', body: JSON.stringify({...}) }))` and asserts status 200 and body `{ ok: true }`.
   - `npm i -D -E vitest@<exact>`.
   - Scripts: `dev`, `build`, `start`, `lint` (ESLint, the form the generator's version uses) and `test` = `vitest run`.
   - Rewrite every range in `dependencies` and `devDependencies` to the exact installed version (from `npm ls --depth=0 --json`), then `npm install` to refresh the lock.
   - Append `.claude/settings.local.json` to `.gitignore`.
   - Write a short `README.md` (what the sandbox is for, that aew's e2e validation drives it, that nothing is stored).
   - `git branch -M main`.
5. Commit in `$SB`: `chore: scaffold the aew sandbox (Next.js contact form)`.
6. Create the repos (one script file, run with `/bin/bash`, under the executor's own `gh`). This also proves V-11:

   ```sh
   gh repo create aew-sandbox --private --source "$SB" --remote origin --push
   gh repo create aew-sandbox-retro --private
   ```

   - If `git -C "$SB" remote get-url origin` is not the HTTPS form, set it to `https://github.com/jamesborg2012/aew-sandbox.git`. The PAT path (A6) is HTTPS-only and the launcher refuses an SSH origin; gh's `git_protocol` is `https` today.
   - `aew-sandbox-retro` stays empty: no labels. `gh-retro.sh` creates its `retro` label best-effort (lines 111 to 112).
7. Write the AC-8 file `$SB/.claude/settings.local.json`, using the ids taken from `claude plugin list --json`:

   ```json
   {"enabledPlugins": {"dev-workflow@jamesborg": false, "figma@claude-plugins-official": false, "warp@claude-code-warp": false}}
   ```

   aew, superpowers, context7 and frontend-design are not named, so they stay enabled. The runtime proof is A7's `system/init`.

**Verification**

```sh
cd "$SB" && npm run lint; echo "lint=$?"                                  # lint=0
cd "$SB" && npm test 2>&1 | grep -E 'Tests? .*1 passed'; echo "test=$?"  # a "1 passed" line, test=0
cd "$SB" && npm run build > /dev/null; echo "build=$?"                   # build=0
jq '[(.dependencies // {}), (.devDependencies // {}) | to_entries[] | select(.value | test("^[0-9]") | not)] | length' "$SB/package.json"   # 0 (every pin exact)
jq -r '.scripts | keys[]' "$SB/package.json" | sort | tr '\n' ' '         # build dev lint start test
ls "$SB"/playwright.config.* "$SB/.aew" "$SB/CLAUDE.md" 2> /dev/null | wc -l    # 0
grep -c playwright "$SB/package.json"                                    # 0
gh repo view jamesborg2012/aew-sandbox --json visibility,defaultBranchRef --jq '"\(.visibility) \(.defaultBranchRef.name)"'   # PRIVATE main
gh repo view jamesborg2012/aew-sandbox-retro --json visibility,hasIssuesEnabled --jq '"\(.visibility) \(.hasIssuesEnabled)"'   # PRIVATE true
git -C "$SB" remote get-url origin                                       # https://github.com/jamesborg2012/aew-sandbox.git
[ "$(git -C "$SB" ls-remote origin refs/heads/main | cut -f1)" = "$(git -C "$SB" rev-parse HEAD)" ] && echo pushed   # pushed
git -C "$SB" check-ignore -q .claude/settings.local.json; echo "ignored=$?"   # ignored=0
jq -c '.enabledPlugins' "$SB/.claude/settings.local.json"               # the three false entries, nothing else
git -C "$SB" status --porcelain                                          # empty
```

- **Commit:** in `$SB` only (step 5). Nothing in the plugin repo. The evidence goes into `## Sandbox fixtures` in A9.

---

### A4 — Launchers `e2e-run.sh` and `e2e-session.sh` (rebuilt from §9.2), with a free stub self-test

- **id:** A4
- **files** (outside the repo, never committed):
  - `$E2E/e2e-run.sh`, `$E2E/e2e-session.sh`
  - `$E2E/ghcfg/` (empty)
  - `$E2E/audit-allow.json` (`[]`)
  - `$E2E/ledger-07/`
  - `$E2E/out/`
  - scratch `$E2E/selftest/`
- **depends_on:** [A1] (V-8 decides the attended budget flag; V-9 decides the kill signal)
- **ACs:** AC-10 (and the launcher half of AC-9)
- **risk:** **credentials**. The launcher reads the PAT file.
- **pattern:**
  - `tests/agent-smoke/README.md` §9.2 "Launcher" reference copy, extracted as §10.2 does (`awk '/^#### Launcher$/…'`);
  - §10.2's `<run-id>:<stage>` kill form;
  - `smoke_ship_allow` group 5 (README lines 1240 to 1247) for the fixed denies.

  No new mechanism: every line not listed below stays as in §9.2.

**Changes from the §9.2 copy** (this list is what A9 records, Cut 4):

1. **Interface.**
   - `e2e-run.sh <project> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]`
   - `e2e-run.sh --env-check <project> <command> [<arg>...]`
   - `e2e-run.sh --attended <project> <run> <cap>`
   - `e2e-session.sh <project> <run> <cap>` is a few-line wrapper that does `exec "$HERE/e2e-run.sh" --attended "$@"`. That gives two launchers but **one** copy of the rails.
   - **This is the one interface for every phase.** `<project>` is the session's working directory (the launcher `cd`s into it), so Phase D's S8 worktree (`$S8WT`) and Phase E's `$WOO` are passed as `<project>`; nobody adds a separate `cwd` or path argument. Phase D (D2) adds exactly one leading flag, `--plugin-less`, in the same position as `--attended` / `--env-check` and combinable with `--env-check` (`e2e-run.sh --plugin-less [--env-check] <project> …`).
   - `REPO` becomes a constant (the plugin checkout: git guard, HEAD check, Edit deny). `W` is gone. Outputs go to `$HERE/out/<run>`, gh config to `$HERE/ghcfg`, the ledger to `$HERE/ledger-07`. The **stop is 200**, in the test and in its message. The usage comment says prompt-07.
2. **Preconditions (refuse, exit 2):**
   - `<project>` is a git work tree whose `pwd -P` is not under `$REPO`;
   - its only remote is `origin` and matches `^https://github\.com/jamesborg2012/aew-sandbox(-[a-z0-9]+)?(\.git)?$` (covers S9's `aew-sandbox-woo` and S8's worktree with no code change);
   - `$HERE/ghcfg` exists and is empty;
   - `$HERE/.pat` exists, is non-empty, has mode `600` (`stat -f %Lp`) and is owned by `$USER`;
   - the real `gh` is found (`command -v gh`).

   The shim and bare-origin checks are removed.
3. **Environment** (replaces the §9.2 `SAFE_ENV`; these are the "changed env lines" A9 records):

   ```text
   env -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN -u GH_HOST -u SSH_AUTH_SOCK
       -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID
       GH_TOKEN=<read from $HERE/.pat inside the script> GH_CONFIG_DIR="$HERE/ghcfg"
       GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=
       GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1="!<real gh path> auth git-credential"
       GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND=false
   ```

   Removed from the §9.2 copy: `PATH="$SHIM:$PATH"`, `GH_MOCK_DIR`, `GH_HOST=aew-smoke.invalid`. The empty `credential.helper` resets inherited helpers such as `osxkeychain`. A6 proves that it also covers any URL-scoped helper.
4. **Session flags.**
   - **Dropped:** `--plugin-dir "$REPO"` (the session must load the *installed* copy), `--add-dir "$REPO"`, and `--settings` (AC-8's project file disables the unrelated plugins, and the sandbox has no ancestor `CLAUDE.md` to exclude).
   - **Kept:** stream-json, `--verbose`, `--forward-subagent-text`, `--include-hook-events`, `--max-budget-usd`, `--debug-file`, `--permission-mode acceptEdits --permission-prompts none`, the allow-file lines, `< /dev/null`.
5. **Fixed denies, appended by the launcher** (so no allow file can forget them): `--disallowedTools`, then `smoke_ship_allow` group 5 verbatim:
   - `Bash(git push *)`, `Bash(git reset *)`, `Bash(git checkout *)`, `Bash(git add -A*)`, `Bash(git add .)`;
   - `Edit(/$REPO/**)`;
   - the six user-connector denies (`mcp__notion`, `mcp__claude_ai_Claude_Docs`, `…Google_Drive`, `…Gmail`, `…Google_Calendar`, `…Figma`).

   The allow-file refusal rules stay as in §9.2: no `gh` rule but `Bash(gh auth status)`, no bare `Bash`, no launcher flag or permission mode.
6. **Kill.**
   - The §10.2 `<run-id>:<stage>` form is added.
   - The poller sends **SIGINT** first (Assumption 8; the V-9 answer, recorded). It sends TERM after 30 s if the process is still alive, then KILL after a further 30 s.
   - `killed-at` records the time and the signal that ended it.
7. **Audit (C3).**
   - `GH_HOST=` becomes `GH_HOST` (any mention), and `unset ` and `PATH=` are added.
   - `REALGH` is the real `gh` path from `command -v gh`.
   - Everything else is kept: `github\.com`, `--hostname`, `GH_TOKEN`, `GITHUB_TOKEN`, `GH_CONFIG_DIR=`, `security `, `credential`, `remote (add|set-url)`, the `claude` command rule with its `claude plugin list --json` exception, and the MCP check allowing only `mcp__plugin_aew_playwright__` / `mcp__plugin_context7_context7__`.
   - **File contents are audited too** (C3 detect-only must cover code that runs through an allowed test, lint or build command, which the Bash-command audit cannot see). The same post-session pass scans the `input` of every `Write`, `Edit`, `MultiEdit` and `NotebookEdit` `tool_use` on any thread for a narrower set: `GH_TOKEN`, `GITHUB_TOKEN`, `GH_HOST`, `GH_CONFIG_DIR`, `GH_ENTERPRISE`, `auth token`, `git-credential`, `osxkeychain`, `security find-` and `REALGH`. (`credential` and `github\.com` are left out here: app code legitimately writes `credentials: 'same-origin'` and links.) A hit is exit 4, `AUDIT HIT`, like a command hit.
8. **Attended mode (`--attended`):**
   - the same preconditions, environment, lock and reservation (`cap`, empty cost, start);
   - `cd <project>`, then interactive `claude` with the change 5 fixed denies as `--disallowedTools` (the same list as headless), and `--max-budget-usd <cap>` only if V-8 says it applies interactively. Otherwise it prints `check /cost at each gate; stop at $<cap>` before starting.
   - After exit: the git guard, the plugin-repo HEAD check and the `ghcfg` check (exit 4 on failure). The cost stays reserved at the cap until the executor writes James's `/cost` figure into column 2 of that `.tsv` row.
   - The stream audit does not apply (there is no stream). A9 records this as a known gap.
9. **Kept unchanged:** the CTO-5 spin lock, the port-4173 stop, the CTO-3 git guard, the `out/<run>` / ledger-file "use the next attempt name" refusal, and the cost read from the last `result` event (a killed or crashed session counts its cap).
10. The token is read into a variable once and only ever placed in the `env` argument list. The script has no `set -x`, no `echo`/`printf` of it, and it is never written to `out/`.

**Verification (free, no API call)**

```sh
/bin/bash -n "$E2E/e2e-run.sh" && /bin/bash -n "$E2E/e2e-session.sh" && npx --yes shellcheck "$E2E/e2e-run.sh" "$E2E/e2e-session.sh"   # no output
"$E2E/e2e-run.sh" --help && "$E2E/e2e-session.sh" --help               # usage lines, exit 0
grep -c -- '--permission-prompts none' "$E2E/e2e-run.sh"                # 1
grep -cE -- '--plugin-dir|--add-dir|GH_HOST=aew-smoke|GH_MOCK_DIR' "$E2E/e2e-run.sh"   # 0
grep -cE 'set -x|bypassPermissions' "$E2E/e2e-run.sh" "$E2E/e2e-session.sh"            # 0 and 0
grep -c '"unset "' "$E2E/e2e-run.sh"; grep -c '"PATH="' "$E2E/e2e-run.sh"              # 1 and 1
stat -f '%Lp' "$E2E"; ls -A "$E2E/ghcfg" | wc -l                        # 700 and 0
```

**Stub self-test.** This is the §9.2 precedent: "exercised once against a copy of it in a scratch directory with a stub `claude` first on `PATH`".

- **Set-up.** Everything runs from one script file in `$E2E/selftest/`:
  - copy both launchers in;
  - a dummy `.pat` holding `DUMMY-NOT-A-TOKEN`, mode 600;
  - a throwaway git project with `origin` = `https://github.com/jamesborg2012/aew-sandbox.git` (never contacted);
  - a stub `claude` first on `PATH`. The stub prints its argv, the env *names* matching `^(GH_|GITHUB_|GIT_|SSH_AUTH_SOCK)`, and `${#GH_TOKEN}` (the length only). It then emits a canned `system/init` and `result` stream. Its Bash `tool_use` commands come from a fixture file.
- **Expected:**
  - normal session: exit 0, a `cap cost start` ledger row, `audit clean`;
  - the same run name again: exit 2;
  - 199 already in the ledger plus cap 2: exit 3, nothing started;
  - lock contention as in §9.2: one launch starts, the others exit 3;
  - **audit hits** (exit 4, `AUDIT HIT`): `unset GH_HOST`, `echo $GH_HOST`, `PATH=/tmp:$PATH claude -p x`, `env -u GH_TOKEN gh auth token`, `<real gh path> api user`, `git remote set-url origin x`, `curl https://github.com/x`;
  - **audit non-hits:** `claude plugin list --json | jq .`, `"<installPath>/scripts/state.sh" get stage`, `npm test`;
  - **file-content audit:** a `Write` whose content contains `process.env.GH_TOKEN` is a hit (exit 4); a `Write` containing `credentials: 'same-origin'` is not;
  - a file written into `ghcfg` during the session: exit 4;
  - **refusals** (exit 2): an allow file with `Bash(gh *)`, `Bash`, or `--permission-mode=default`; an SSH or non-sandbox origin; a project inside `$REPO`; `.pat` at mode 644;
  - the stub's argv contains every fixed deny and no `--plugin-dir`, in both normal and `--attended` mode;
  - the env names include `GH_TOKEN` and `GH_CONFIG_DIR`, and not `GITHUB_TOKEN`, `GH_HOST` or `SSH_AUTH_SOCK`;
  - kill poller with a fake `state.json` at `develop`: `killed-at` names `INT`, and the ledger counts the cap;
  - `--attended`: a reservation row, the stub run interactively, the post-checks run, exit 0.
- **Leak check:** `grep -rc 'DUMMY-NOT-A-TOKEN' "$E2E/selftest/out" "$E2E/selftest/"*.log 2> /dev/null | grep -v ':0$'` prints nothing.
- **Clean-up:** `rm -rf "$E2E/selftest"`. The real `ledger-07/` is still empty.

- **Commit:** none (launchers are never committed; AC-10). The evidence goes into `## Rails and launchers` in A9.

---

### A5 — STOP-for-James: CP-1 (spend) and CP-2 (the PAT), asked together

- **id:** A5
- **files:** outside the repo, `$E2E/.pat` (written by **James**, never by the executor)
- **depends_on:** [A3, A4] (the repos must exist before a fine-grained PAT can select them; the ledger is shown as A4 enforces it)
- **ACs:** AC-9 (the PAT half), and CP-1 for the spend envelope
- **risk:** **credentials**
- **pattern:** spec "Execution-time human checkpoints" CP-1 and CP-2

**STOP. The executor asks James exactly this, then waits:**

> **CP-1, spend.** Approve this ledger before the first paid session (the A7 install probe, $0.50 on haiku).
>
> | Item | Cap (USD) | Attended | Drive |
> |---|---|---|---|
> | Install probe | 0.50 | no | headless (haiku) |
> | init | 5 | yes | interactive |
> | S1 | 15 | yes | interactive |
> | S2 | 20 | no | headless |
> | S3 | 10 | yes | interactive |
> | S4 | 12 | no | headless (attended resume if it gates) |
> | S5 | 25 | yes (mode question) | interactive |
> | S6 | 30 | no (`--sequential --auto`, Cut 2; attended resume if a child gates) | headless |
> | S7 kill + status probe + resume | 8 (charged at cap) + 1 + 12 | no | headless (no separate hint probe, Cut 1) |
> | S8 prompt + plugin-less build | 4 + 8 | no | headless |
> | **Subtotal** | **150.50** | | |
> | Re-run reserve | 49.50 | | |
> | **Stop** | **200** | | S9 (cap 25) only if 25 or more remains |
>
> After this I ask again only if a session would pass the stop, a cap would rise above 2×, or a re-run would go into the reserve. *(The subtotal is $1 lower than the spec's because the hint probe was cut.)*
>
> **CP-2, the PAT.** Please create a **fine-grained** personal access token at github.com → Settings → Developer settings → Fine-grained tokens:
> - **Resource owner:** jamesborg2012.
> - **Repository access:** *Only select repositories*, choosing **`aew-sandbox` and `aew-sandbox-retro` only**. Do **not** select `claude-agentic-engineer-workflow`: the permissions apply to every selected repo, so agents would get write on the plugin (C3).
> - **Repository permissions:** Contents read and write, Issues read and write, Pull requests read and write, Metadata read (mandatory). Nothing else.
> - **Expiry:** your choice. Covering the validation (about two weeks) is enough.
>
> Then, **in your own terminal** (so the token never passes through my session), with the token on the clipboard:
> `umask 077; pbpaste | tr -d '\n' > /Users/jamesborg/Documents/Development/aew-e2e/.pat; chmod 600 /Users/jamesborg/Documents/Development/aew-e2e/.pat`
>
> Reply **"ledger approved, PAT saved"**, or tell me what to change.

**Verification after James replies** (the executor reads the metadata only, never the contents):

```sh
stat -f '%Lp %Su' "$E2E/.pat"                       # 600 jamesborg
[ -s "$E2E/.pat" ] && echo non-empty                 # non-empty
```

- James's answer and the approval time are recorded in A9 (`## Spend ledger` header).
- **Commit:** none.

---

### A6 — Canary: the PAT reaches only the sandbox, and the keychain token is unreachable

- **id:** A6
- **files:** outside the repo, `$E2E/canary.sh` (a script file, because the text contains `git push`), `$E2E/out/canary-<n>.txt`
- **depends_on:** [A4, A5]
- **ACs:** AC-9 (also proves V-10 by running: `GH_TOKEN` precedence, and `gh auth git-credential` serving it with an empty `GH_CONFIG_DIR`)
- **risk:** **credentials**
- **pattern:** §9.2 "Harness checks", with the real-gh canary and the keychain check adapted from a mock host to real GitHub. All commands go through `e2e-run.sh --env-check "$SB" …`. Outputs are filtered so that nothing token-shaped is printed.

**Free pre-check (executor shell):**

```sh
git config --show-origin --get-regexp '^credential' | sed 's/ .*//'
```

This lists the helper *keys* only. Record them: a URL-scoped `credential.https://github.com.helper` is not reset by the empty `credential.helper`, so the negative git checks below are the proof.

**Canary** (run once now, and again after **any** launcher change, per AC-9). Each line is `"$E2E/e2e-run.sh" --env-check "$SB" /bin/bash -c '<cmd>'`:

| # | command (in the session environment) | expected |
|---|---|---|
| 1 | `env \| cut -d= -f1 \| grep -E '^(GH_\|GITHUB_\|GIT_\|SSH_AUTH_SOCK)' \| sort` | exactly `GH_CONFIG_DIR GH_TOKEN GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_0 GIT_CONFIG_VALUE_1 GIT_SSH_COMMAND GIT_TERMINAL_PROMPT` (names only) |
| 2 | `gh auth status 2>&1 \| grep -c '(GH_TOKEN)'` | `1` (V-10: `GH_TOKEN` wins over the keychain) |
| 3 | `gh api user --jq .login` | `jamesborg2012` |
| 4 | `gh repo view jamesborg2012/aew-sandbox --json name --jq .name; gh repo view jamesborg2012/aew-sandbox-retro --json name --jq .name` | `aew-sandbox`, `aew-sandbox-retro` |
| 5 | `gh repo view jamesborg2012/claude-agentic-engineer-workflow --json name > /dev/null 2>&1; echo "exit=$?"` | non-zero (a PRIVATE repo outside the PAT, checked 2026-10-26) |
| 6 | `git ls-remote origin refs/heads/main \| cut -f1` | the sandbox `main` sha (V-10: the gh credential helper serves the PAT) |
| 7 | `git push --dry-run origin main 2>&1 \| tail -n 1; echo "exit=${PIPESTATUS[0]}"` | `Everything up-to-date`, exit 0 (write auth on receive-pack; nothing created) |
| 8 | `git ls-remote https://github.com/jamesborg2012/claude-agentic-engineer-workflow.git > /dev/null 2>&1; echo "exit=$?"` | non-zero, with no prompt (no helper reaches the keychain credential; C3) |
| 9 | `env -u GH_TOKEN gh api user > /dev/null 2>&1; echo "exit=$?"` and `env -u GH_TOKEN gh auth token > /dev/null 2>&1; echo "exit=$?"` | **non-zero** for both: the keychain token is unreachable even after removing `GH_TOKEN` (C3 "make the keychain token unreachable"). Output discarded. |
| 10 | (executor shell) `ls -A "$E2E/ghcfg" \| wc -l` | `0` (gh wrote nothing) |

- **Any of rows 1 to 8 or row 10 failing stops the phase.** No session starts. Fix the launcher, re-run the A4 self-test and re-run the canary.
- **Conditional STOP-for-James (row 9 exits 0).** §9.2 found the keychain token visible despite an empty `GH_CONFIG_DIR`, so this is likely. The executor stops and asks James:

  > *"With `GH_TOKEN` removed, a session can still reach your keychain gh token (`env -u GH_TOKEN gh api user` exits 0). C3 asks for it to be unreachable. Options:*
  > *(a) accept detect-only. The audit flags `GH_TOKEN`, `unset ` and the real gh path, so any attempt fails the run with exit 4 after the fact, and this is recorded in writing under Rails as a C3 deviation you approved.*
  > *(b) you run `gh auth logout` for github.com for the duration of the validation and log back in afterwards. That makes it truly unreachable, but my own GitHub steps (issue fixtures, the Phase F transfer, the release) then need you to log in again first.*
  > *I recommend (a). Which?"*

  The answer is recorded in A9. If (b), row 9 is re-run and must exit non-zero.

- **Commit:** none. The outputs (filtered as above, no token) go into `## Rails and launchers` in A9.

---

### A7 — Install probe: the first paid session (haiku, cap $0.50)

- **id:** A7
- **files** (outside the repo):
  - `$E2E/allow-probe.txt`
  - `$E2E/out/probe.<n>/` (stream, debug log, exit)
  - `$E2E/ledger-07/<project>-probe.<n>.tsv`
- **depends_on:** [A2, A3, A5, A6, A8] (A8 because its step 6 refreshes the installed copy; the probe must see the final one)
- **ACs:** AC-4. Also the runtime proofs of AC-8 / V-13 (unrelated plugins disabled), V-6 (MCP status) and V-13 (Cut 6).
- **risk:** spend ($0.50, inside the CP-1 approval)
- **pattern:**
  - §9.3 P0b checks (`smoke_init_evt "$O" '.agents'` and `[.slash_commands[]? | select(startswith("aew:"))]`, README lines 1648 to 1649);
  - §8.2's `mcp_servers` check (line 560);
  - P0a's allow file, which starts with `--model` / `haiku`.

**Steps**

1. Write `$E2E/allow-probe.txt` as two lines, `--model` and `haiku`. It needs no Bash rule; the fixed denies come from the launcher.
2. From a script file, run in the background (`run_in_background`):

   ```sh
   "$E2E/e2e-run.sh" "$SB" probe.1 0.50 "$E2E/allow-probe.txt" 'Reply with the single word OK. Do not use any tools.'
   ```

**Verification** (`smoke_init_evt` is copied into the check script from README line 1259; evidence comes from `system/init`, never from prose):

```sh
O="$E2E/out/probe.1"
cat "$O/exit"                                                                    # 0
smoke_init_evt "$O" '[.slash_commands[]? | select(startswith("aew:"))] | sort'   # ["aew:init","aew:prompt","aew:resume","aew:ship","aew:ship-milestone","aew:status"]
smoke_init_evt "$O" '[.agents[]? | select(startswith("aew:"))] | sort'           # the seven: aew:brief-compiler, developer, doc-writer, qa-engineer, senior-engineer, spec-analyser, standards-setter
smoke_init_evt "$O" '.mcp_servers[] | select(.name == "plugin:aew:playwright") | .status'   # "connected" (field per V-6)
smoke_init_evt "$O" '[.plugins[]?.name] | sort'                                  # aew, context7, frontend-design, superpowers; NOT dev-workflow, figma, warp (AC-8 / V-13)
smoke_init_evt "$O" '.plugins[]? | select(.name == "aew") | .path'               # equals the current installPath (A2's, or A8's if the refresh changed it; the installed copy, not $REPO)
smoke_init_evt "$O" '.permissionMode, .model'                                    # "acceptEdits", a haiku model id
jq -rR 'fromjson? | select(.type == "result") | .total_cost_usd' "$O/stream.jsonl" | tail -n 1   # ≤ 0.50 (recorded)
ls "$O"/audit.txt "$O"/git-guard.txt "$O"/repo-head.txt 2> /dev/null | wc -l    # 0 (launcher printed "audit clean")
ls -A "$E2E/ghcfg" | wc -l                                                       # 0
git -C "$REPO" status --porcelain                                                # unchanged from before the probe
```

- If a `system/init` field name differs (for example `.plugins` carries `id`, not `name`), use the documented field (V-6), record it, and keep the expectation.
- If the MCP status is not `connected`, look in `$O/debug.log` for the Playwright start. This is an AC-4 failure: it goes to the fix loop (Phase B's AC-28 protocol) before Phase B starts.
- New connector names in `.mcp_servers` that aren't denied are added to the launcher's fixed denies, and the canary (A6) is re-run, because the launcher changed.
- **Commit:** none here. A9 records the result.

---

### A8 — README `## Install`: the commands that worked, the dependency check, and a proven refresh

- **id:** A8
- **files:** `README.md` (`## Install` only)
- **depends_on:** [A1, A2]
- **ACs:** AC-5
- **risk:** none
- **pattern:**
  - the existing `README.md` `## Install`, edited in place (lines 11 to 21);
  - A2's commands as run;
  - V-3's refresh commands from A1.

**Steps**

1. Replace the two install lines with the exact pair that worked in A2, including `--scope user`. Keep the generic `/path/to/claude-agentic-engineer-workflow`.
2. Add a short "Check the dependencies installed" troubleshooting paragraph: A2's isolated-config check, in its generic form with a throwaway `CLAUDE_CONFIG_DIR`, and the expected four ids.
3. Add "Refresh after a change", using V-3's commands (expected shape: `claude plugin marketplace update jamesborg-plugins`, then `claude plugin update aew@jamesborg-plugins`). Include V-3's note on an unchanged `version`.
4. Keep the `--plugin-dir` paragraph.
5. Commit.
6. **Prove the refresh against this very commit:**
   1. run the step 3 commands;
   2. `cmp "$(claude plugin list --json | jq -r '.[] | select(.id=="aew@jamesborg-plugins") | .installPath')/README.md" "$REPO/README.md"` → identical (exit 0);
   3. record whether `installPath` changed (init's settings name scripts by it, so a change matters for Phase B).
7. If the documented refresh does not pick the commit up:
   - find the sequence that does (for example, uninstall and reinstall, per V-3 and V-12);
   - correct README in a follow-up commit `docs(readme): correct the refresh steps`;
   - record the finding for Phase B's AC-28 step 6.

**Verification**

```sh
grep -c 'claude plugin install aew@jamesborg-plugins --scope user' "$REPO/README.md"   # 1
grep -c 'CLAUDE_CONFIG_DIR' "$REPO/README.md"                                           # ≥ 1
sed -n '/^## Install/,/^## /p' "$REPO/README.md" | grep -cE 'marketplace update|plugin update'   # ≥ 2 (or the corrected sequence)
cmp "<installPath>/README.md" "$REPO/README.md"; echo "cmp=$?"                        # cmp=0 after the refresh
```

- **Commit:** `docs(readme): install commands proven on a real user-scope install` (plus the conditional correction commit above).

---

### A9 — Record the rails, the canary, the probe and the ledger; brief and decision log

- **id:** A9
- **files:**
  - `tests/e2e-validation.md` (`## Rails and launchers`, `## Spend ledger`, `## Sandbox fixtures`, and `## Environment`'s install-probe row)
  - `docs/superpowers/project-map.md` (`## Project knowledge`, append only)
  - `CLAUDE.md` (`## Project decisions`, append only, if that section exists; skip otherwise)
- **depends_on:** [A2, A3, A4, A5, A6, A7, A8]
- **ACs:** AC-9 and AC-10 (recorded); closes AC-1 to AC-8 evidence
- **risk:** none (the doc must contain no token)
- **pattern:** the §9.2 results table form (`| check | result | notes |`) and the §9.1 ledger table (`| run | attempt | cap | cost | running total | cap raised? |`), with the attended and cost-source columns that AC-26 adds.

**Content**

- **`## Rails and launchers`:**
  - the launcher interface and file locations (paths, not contents);
  - **the changed env lines verbatim from A4 change 3**, with the PAT shown as `<from $E2E/.pat>`;
  - the fixed denies;
  - the new audit patterns;
  - the SIGINT kill;
  - the attended-mode gap (no stream audit);
  - the A4 self-test results table;
  - the A6 canary table (rows 1 to 10 with their outputs, plus the credential-key list);
  - James's row-9 decision, if one was needed.
- **The C3 broad-lines decision, in writing:**
  - The ship-run allow files (built in Phase B) start from init's anchored `.claude/settings*.json` and add only narrowed harness lines: `npx` only as the sandbox's own tools (`npx vitest *`, `npx eslint *`, `npx next *`, `npx playwright *`), and `curl` only against `http://localhost:*`.
  - `node *` and `sh -c *` are **not** added.
  - A broad line is added only after a recorded denial shows it is needed (the §10.2 "widen only after a recorded denial" rule). Any such line is recorded here as **detect-only**: the audit flags `GH_TOKEN`, `GH_HOST`, `unset `, `PATH=`, `credential`, the real gh path and `claude` commands after the fact, and does not prevent them.
- **`## Spend ledger`:**
  - the CP-1 table as approved, with the time and James's words;
  - the stop of $200;
  - the first row from `$E2E/ledger-07/*.tsv`: `probe | probe.1 | 0.50 | <cost> | <total> | no | no | result`.
- **`## Sandbox fixtures`:**
  - the AC-6 / AC-7 / AC-8 evidence from A3 (pinned versions, the scripts, the lint/test/build exits, the repo views, `main` pushed, the ignored settings file);
  - a note that the issue and milestone fixtures follow in Phase B.
- **`## Environment`:** an "Install probe (AC-4)" row block with A7's results (slash commands, agents, MCP status, plugin list, plugin path = installPath, model, cost).
- **Project brief (`project-map.md`, append, one line each):**
  - the installPath form, and whether a refresh changes it (V-3);
  - the launcher location and interface;
  - the keychain-reachability finding and decision;
  - "the PAT never selects the plugin repo".
- **Decision log (`CLAUDE.md` `## Project decisions`, only if present):** "2026-10-2x: e2e sessions start only through `$E2E/e2e-run.sh` / `e2e-session.sh` (PAT env, fixed denies, ledger stop $200)".

**Verification**

```sh
grep -c '^## ' "$REPO/tests/e2e-validation.md"                                       # 9 (skeleton intact)
grep -cE 'github_pat_|ghp_|gho_' "$REPO/tests/e2e-validation.md" "$REPO/docs/superpowers/project-map.md"   # 0 and 0
grep -c 'GIT_CONFIG_VALUE_1' "$REPO/tests/e2e-validation.md"                          # ≥ 1 (changed env lines recorded)
grep -ciE 'detect-only|narrow' "$REPO/tests/e2e-validation.md"                       # ≥ 1 (C3 decision in writing)
grep -c '^| probe |' "$REPO/tests/e2e-validation.md"                                  # 1
tests/run-script-tests.sh && claude plugin validate .                                 # pass (nothing under scripts/ changed; baseline still green)
git -C "$REPO" status --porcelain                                                     # only the three files above before the commit; empty after
```

- **Commit:** `docs(e2e): record the rails, the canary and the install probe`

---

### Phase A acceptance map

| AC | Task(s) | Proof |
|---|---|---|
| AC-1 | A1 (and A6 / A3 for V-10 / V-11, Phase B for V-7) | `## Platform facts` table, 13 dated rows, doc URLs |
| AC-2 | A2 | `claude plugin list --json`: aew 0.1.0 plus the three dependencies, enabled, user scope |
| AC-3 | A2 | the isolated config lists all four after installing aew alone; the real config hash is unchanged |
| AC-4 | A7 | `system/init`: the six slash commands, the seven agents, `plugin:aew:playwright` connected, aew loaded from installPath |
| AC-5 | A8 | README `## Install` commands, the isolated check, the refresh proven by `cmp` |
| AC-6 | A3 | both repos PRIVATE, `main` pushed, sibling clone, no ancestor `CLAUDE.md` |
| AC-7 | A3 | lint / test (1 passed) / build exit 0, exact pins, no Playwright, no `.aew/` |
| AC-8 | A3, A7 | the gitignored file with three `false` entries; the probe's plugin list excludes them |
| AC-9 | A5, A6 | sandbox-only PAT (mode 600); canary rows 1 to 10; keychain decision recorded |
| AC-10 | A4, A9 | the launchers built and self-tested; the changed env lines and the C3 decision recorded |

### Human checkpoints in this phase

- **A5:** CP-1 (spend) and CP-2 (PAT), always.
- **A2 step 6:** only if the isolated config needs a login.
- **A6 row 9:** only if the keychain token is still reachable. This is a C3 deviation, James's call.

## Phase B — init, fixtures and the serial scenarios S1 to S7

- **Depth:** full. **Depends on:** Phase A. **Risk:** real issue-body rewrites (S3 `revise`, S4 `manual-tests`), plus the AC-20 lift of the sandbox-only limit.
- **ACs:** 11, 12, 13, 14, 15 (CR-1 to CR-8), 16, 17, 18, 19, 20, 21, 22, 23, and 26, 27, 28 as they apply to these runs.
- **Simplicity-challenge decisions applied here (they override the spec where they differ):**
  - S6 runs **headless** as `/aew:ship-milestone <M-S6> --sequential --auto` (cut 2). The AC-22 stacked-merge protocol is unchanged. Attended sessions in this phase are init, S1, S3 and S5 only (plus any gate fallback).
  - Old phases B and C are one serial phase (cut 3).
  - The record is trimmed (cut 4): the introduction verdict (AC-14) and the guard and permission denials (CR-6, CR-7) go **inline** in each scenario's expectation table. There is one short top-level `## Guard false positives` list (AC-27). The roll-up is Phase F's.
  - CR-9 is gone from this phase (cut 5): the retro items are listed once, in Phase F's AC-29 transfer. Common checks are CR-1 to CR-8.
  - V-11 (milestones through `gh`) is proved by running the fixture commands, with command and output recorded (cut 6).
  - There is no separate SessionStart hint probe: the S7 `/aew:status` session's stream carries it (cut 1, partly). S7 itself stays a separate run.
- **Task count:** 10 (B1 to B10), one strictly serial chain apart from B2 and B7. That is over the ~8 heuristic by design: CTO cut 3 merged two phases, and every task is one run plus its record, not new code.

### Entry conditions (from Phase A; checked once before B1, free)

Run in the executor's own session. Any failure stops Phase B and goes back to Phase A.

| check | command | expected |
|---|---|---|
| plugin branch | `git -C "$REPO" branch --show-current` | `feature/e2e-validation`, clean apart from `tests/e2e-validation.md` |
| install | `claude plugin list --json` | `aew@jamesborg-plugins` `0.1.0`, enabled, plus the three dependencies (AC-2) |
| sandbox | `git -C "$SB" status --porcelain; git -C "$SB" rev-parse main origin/main` | clean, with both hashes equal; no `.aew/` |
| launchers and ledger | `ls "$E2E"` | `e2e-run.sh`, `e2e-session.sh`, the token file (mode 600, never printed), the ledger, `out/` |
| canary | the latest AC-9 canary row in `tests/e2e-validation.md` `## Rails and launchers` | passed, and no launcher change after it |
| spend | the ledger | CP-1 approved in Phase A; the total spent so far is recorded |
| record skeleton | `grep -n '^## ' "$REPO/tests/e2e-validation.md"` | Environment, Platform facts (V-3, V-8 and V-9 answered; V-7 marked "runtime, Phase B", filled by B10), Rails and launchers, Spend ledger |
| keychain decision | `## Rails and launchers`, James's row-9 answer (A6) | recorded. If he chose (b) (`gh auth logout`), every executor `gh` call and every executor `git fetch`/`pull` on `$SB` in this phase runs as `"$E2E/e2e-run.sh" --env-check "$SB" …` (PAT environment, token read inside the script) |

**Names used below:**
- `REPO=/Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow`
- `SB=/Users/jamesborg/Documents/Development/aew-sandbox`
- `E2E=/Users/jamesborg/Documents/Development/aew-e2e`
- `GHR=jamesborg2012/aew-sandbox`
- `$E2E/fixtures.env` holds the real numbers B2 creates (`S1=…`, `S5a=…`, `M_S5=…`, …).
- `$O` is the launcher's output directory for one session (`$E2E/out/<run>`, as Phase A built it).
- Attempts are named `<scenario>.<k>` (`S1.1`, `S1.2`, …) in the ledger and as record sub-headings.

**Interface (Phase A, A4 change 1).** Headless: `"$E2E/e2e-run.sh" "$SB" <run> <cap> <allow-file> "<prompt>" [<kill-stage> [<kill-agent>]]`. Attended: `"$E2E/e2e-session.sh" "$SB" <run> <cap>`, then the slash command typed in the session. Free checks: `"$E2E/e2e-run.sh" --env-check "$SB" <command> [<arg>...]`. The launcher appends the fixed denies itself (git push/reset/checkout, `git add -A`/`.`, `Edit` on the plugin checkout, the user MCP connectors) and sends SIGINT first on a kill. Commits to `tests/e2e-validation.md` are serialised by the executor in the main checkout (B1 and B2 may overlap in time, never in a commit). Headless launches take longer than the Bash tool's 10-minute limit, so the executor starts each one with `run_in_background: true` and waits for the exit notification.

### Standing procedures (each scenario task applies them; they are not tasks)

**P1 Headless session.**
- Start: the launcher command above, with the scenario's cap.
- After it:
  - the launcher exit is 0, with `audit clean`, no git-guard file and an empty gh config dir (exit 4 is a P0 stop, as in §9.2);
  - the ledger row is copied into `## Spend ledger` (cost from the stream's `result`, or the cap if the session was killed);
  - `git -C "$REPO" status --porcelain` shows only the record and any intended fix.
- `system/init` is checked for: `acceptEdits`; the model; and that the only MCP tools are `mcp__plugin_aew_playwright__*` and `mcp__plugin_context7_context7__*` (context7 is an enabled dependency; the launcher's MCP audit allows exactly these two).

**P2 Attended session (CP-4, STOP for James).**
- The executor first snapshots `$SB/.claude/settings.json` and `$SB/.claude/settings.local.json` to `$E2E/out/<run>/settings-before/`. Then it gives James three things:
  1. the exact line to type: `"$E2E/e2e-session.sh" "$SB" <run> <cap>`, then the slash command;
  2. the cap, and the reminder to run `/cost` at each gate and stop the session once the cap is reached (CP-1 fallback, unless V-8 showed that `--max-budget-usd` applies interactively);
  3. what he will be asked, and the scenario's suggested answer.
- **James is asked:** to run the session, answer its questions, and then report three things: the `/cost` figure, every permission prompt he saw (with the command it named), and anything odd.
- After it:
  - the executor diffs the settings files against the snapshot (an "always allow" James clicked shows up here and is recorded under CR-7);
  - it finds the transcript with `ls -t ~/.claude/projects/-Users-jamesborg-Documents-Development-aew-sandbox/*.jsonl | head -n 1`, and confirms it by its first user prompt;
  - it copies the ledger row, with the cost source `/cost`.

**P3 Common checks CR-1 to CR-8**, recorded as rows in the scenario's table. `<id>` is the run id and `<n>` each issue.

| CR | command (executor's session; sandbox reads use `--repo "$GHR"`) | pass when |
|---|---|---|
| CR-1 | `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "$REPO/templates/state.schema.json" -d "$SB/.aew/runs/<id>/state.json"`; `jq -r .status "$SB/.aew/runs/<id>/state.json"`; `cat "$SB/.aew/runs/current" 2>/dev/null` | `valid`; `done` (or the designed stop); `current` empty or absent |
| CR-2 | `gh issue view <n> --repo "$GHR" --json labels -q '[.labels[].name] \| sort \| join(" ")'` | exactly one stage label, `aew:ready-for-review`, plus only the scenario's expected flags |
| CR-3 | `gh pr view <pr> --repo "$GHR" --json baseRefName,body -q '.baseRefName, .body' \| grep -E '^(main\|feat/.*)$\|Closes #'` | the expected base, and one `Closes #<n>` for every issue |
| CR-4 | `git -C "$SB" fetch origin && git -C "$SB" switch --detach origin/<branch>`, then the four `commands` from `.aew/config.json` (`npm --prefix "$SB" ci` first, `CI=1` so Vitest doesn't watch), then `git -C "$SB" switch main` | lint, unit tests and build exit 0 |
| CR-5 | `for c in $(git -C "$SB" rev-list origin/main..origin/<branch>); do git -C "$SB" log -1 --format=%B "$c" \| grep -i 'co-authored-by'; done \| sort \| uniq -c` | one line only, `N Co-Authored-By: Claude <noreply@anthropic.com>`, with N equal to the commit count; no model name |
| CR-6 | headless: `grep -o 'aew guard:[^"]*' "$O/stream.jsonl"`; attended: the same grep over the transcript | every hit listed inline and classified true or false positive (AC-27). A false positive also goes in `## Guard false positives` and into the fix loop |
| CR-7 | headless: `jq -cR 'fromjson? \| select(.type == "result") \| .permission_denials' "$O/stream.jsonl"` and `grep -c 'Permission for this tool use was denied' "$O/stream.jsonl"`; attended: James's prompt list and the settings diff | every denial or prompt listed inline. One on a command the plugin prescribes is a plugin defect (fix loop). An improvised command is recorded, and fixed in the agent prompt if it recurs |
| CR-8 | the final report (headless `result` text or James's copy), plus `jq -r '.review_cycle, .fix_cycle, .started_at, .updated_at'` on `state.json`, plus wall-clock from the ledger | printed; the cycles and both durations recorded |

**P4 Introduction review (AC-14), every PR.**
1. `gh pr view <pr> --repo "$GHR" --json body -q .body > "$O/pr-body.md"`, then `"$REPO/scripts/check-pr-intro.sh" "$O/pr-body.md" [--issues <k>]`. It must exit 0.
2. The executor reads the `## In plain English` section against the run's `state.json` history, `log.md`, `10-summary.md`, the QA report, `manual-tests.md` and the cycles.
3. It writes the verdict `accurate` or `fail`, with one line of reasons, as a row in the scenario table. A `fail` (one that is generic, contradicted by the artefacts, or that doesn't let a reader understand the run on its own) counts even when the script passes. It goes into the fix loop as a doc-writer prompt defect.

**P5 Merge and fast-forward (CP-3, STOP for James; AC-12).**
- **James is asked:** "PR #<pr> (<title>) is checked: <one-line result>. Please merge it in the GitHub UI with the method of your choice, then tell me the method and whether you deleted the branch." S6 uses its own protocol (B9).
- After it:
  - `gh pr view <pr> --repo "$GHR" --json state,mergedAt,mergeCommit` shows `MERGED`;
  - `git -C "$SB" switch main && git -C "$SB" pull --ff-only` succeeds;
  - `git -C "$SB" rev-parse main origin/main` gives equal hashes;
  - `git -C "$SB" status --porcelain` is empty, apart from any `.claude/agent-memory/` lines (recorded).
- Record the merge method and whether the branch was deleted. The executor **never** runs `gh pr merge`.

**P6 Record and commit (AC-26).** This is written straight after the scenario, before the next one starts. Insert `## <scenario>` (`## init`, `## S1`, …) in `$REPO/tests/e2e-validation.md` immediately before `## Guard false positives` (A1's skeleton order: scenario sections sit between `## Sandbox fixtures` and `## Guard false positives`), in the §9.4 and §10.4 form:
- one `### <scenario>.<k>` per attempt;
- the expectation table (`expectation | result | evidence`), with every [P] expectation, CR-1 to CR-8, and the AC-14 verdict inline;
- the cycles, the rough duration and the problems found.

Fix-log rows go in `## Fix log`. No stream, transcript or token is ever committed. Commit only that file, by explicit path, on `feature/e2e-validation`, as `test(e2e): record <scenario>, <one-line outcome>` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>` and no model name (repo CLAUDE.md overrides the session's attribution line).

### Fix loop (protocol; any task may enter it; no fix is pre-planned)

Entered on any failed expectation, `fail` verdict or guard false positive. No session runs while a fix is in progress.

1. **Classify** the failure as one of:
   - plugin defect;
   - sandbox or fixture issue: fix the fixture and record the tuning beside the body in `## Sandbox fixtures` (the §9.5 and §10.7 precedent);
   - platform behaviour: record it, and list it for README troubleshooting in Phase F;
   - operator error: record it, and don't count the attempt against the plugin.

   Only a plugin defect changes the plugin.
2. **Diagnose** it with `superpowers:systematic-debugging` from the run dir, `log.md`, the stream or transcript and the debug log, before any edit.
3. **Fix** it on `feature/e2e-validation`:
   - **Scriptable defect:** write a failing bats test first (show the red), then the fix.
   - **Guard false positive (AC-27):** add a new row to `tests/scripts/fixtures/hooks/bash-cases.tsv` or `edit-cases.tsv` (red first), then narrow the pattern in `scripts/hooks/guard-*.sh`. Never remove a protection DESIGN §11 lists.
   - **Agent or skill defect:** improve the prompt. Never weaken the scenario's expectation or the check.
   - **A change to designed behaviour:** update DESIGN in the same commit, under a "Recorded deviations (prompt 07)" entry.
   - **An init fix:** first move content to `skills/init/references/` so that `wc -l skills/init/SKILL.md` is under 500.
   - **A fix outside DESIGN that is expensive to reverse, or anything that would delete a GitHub resource:** STOP for James (CP-6). He is asked to approve the specific change, with the reason, the alternative and the cost of reversing it.
4. **Commit** each fix on its own, as `fix(<scope>): <summary>` with the plain Claude trailer.
5. **Check:** `"$REPO/tests/run-script-tests.sh"` passes and `claude plugin validate "$REPO"` passes.
6. **Refresh** the install by V-3's recorded method, then:
   - `cmp "$REPO/<changed file>" "<installPath>/<changed file>"` exits 0 for every changed file;
   - the `installPath` is unchanged, or the paths that init wrote into `$SB/.claude/settings.local.json` still exist. If not, classify it (platform behaviour or plugin defect) and STOP for James before any further session.
7. **Re-run** as attempt `<scenario>.<k+1>`, out of the reserve. A re-run that would pass the reserve, a cap above 2× the original, or a session that would pass the $200 stop is a **STOP for James (CP-1)**: he is asked to approve the extra spend, given the ledger total.
   - **Re-run form:** prefer `/aew:ship <n> [--auto] --from <stage>` (or `/aew:resume <id>`), with the stage set to the earliest one whose output the fix changes. That keeps the run dir and updates the existing PR (DESIGN §9).
   - **If the run can't be continued:** file a fresh copy of the fixture issue (recorded as `<scenario>-r<k>` in `## Sandbox fixtures`) and close the old PR unmerged with a comment naming the re-run. Closing is not a deletion; no branch or issue is deleted. If `.aew/runs/current` still names the abandoned run, clear it with `bash "<installPath>/scripts/state.sh" current clear` run from `$SB`, logged as a harness action.
8. **Log** one row in `## Fix log`: the commit, the problem, the scenario, the re-run attempt and its result.

---

### B1 — init in the sandbox, its PR, the merge and the headless allow file

- **files:**
  - `tests/e2e-validation.md` (`## init`, the ledger row);
  - outside the repo: `$E2E/allow-ship.txt`;
  - in the sandbox (written by init): `.aew/config.json`, `.gitignore`, `CLAUDE.md`, `docs/standards/`, `.claude/settings.json`, `.claude/settings.local.json`.
- **depends_on:** [] (Phase A done)
- **pattern:**
  - `tests/agent-smoke/README.md` §9.7 (I1 init checks) and §9.10 Run C (introduction on the init PR);
  - `skills/init/SKILL.md` §§5 to 12 (what it asks and writes);
  - §9.2 `smoke_ship_allow ship` and §10.2's `grep -v '^$'` rule (the allow-file shape).
- **ACs:** 11, 12, 14 (the init PR), CR-6 and CR-7 for this session; AC-10's "allowlist starts from init's settings".
- **risk:** medium. This is the first plugin write to a real repo: it creates labels, pushes a branch and opens a PR.
- **steps:**
  1. **P2, STOP for James (CP-4).** Cap $5. Command: `/aew:init`. **James is asked** to:
     - confirm the config values, with `retro.repo` = `jamesborg2012/aew-sandbox-retro` and the rest as detected;
     - accept the Playwright offer (Assumption 5);
     - accept the permissions proposal;
     - then report `/cost` and any prompts.
  2. Checks, run on the local `chore/aew-init` checkout:
     - `ajv validate … -s "$REPO/templates/config.schema.json" -d "$SB/.aew/config.json"` gives `valid`;
     - `jq -c '.stacks, .commands, .retro.repo, .ui' "$SB/.aew/config.json"`: the stacks include `nextjs` and `tailwind`; `commands` names lint, unit-test, build and dev, and matches `jq .scripts "$SB/package.json"`; `retro.repo` is right;
     - `comm -23 <(awk -F'|' '/^(stage|flag)\|aew:/{print $2}' "$REPO/scripts/gh-labels.sh" | sort) <(gh label list --repo "$GHR" --limit 100 --json name -q '.[].name' | sort)` prints nothing (all 11 DESIGN §7.4 labels exist);
     - `git -C "$SB" diff origin/main..chore/aew-init --stat` shows the `.gitignore` lines, the `## Agentic workflow` section in `CLAUDE.md`, and `docs/standards/*.md`, where `head -n 5` of each shows the fingerprint header;
     - both `.claude/settings*.json` files exist, and `jq '.enabledPlugins' "$SB/.claude/settings.local.json"` still holds AC-8's three `false` entries, merged with init's entries;
     - `gh pr list --repo "$GHR" --head chore/aew-init --json number,baseRefName` shows one PR on `main`;
     - CR-5 on the branch; CR-6 and CR-7 from the transcript.
  3. P4 on the init PR (`--issues` omitted).
  4. **P5, STOP for James (CP-3)**, then fast-forward `main`.
  5. **Build `$E2E/allow-ship.txt`** from the merged `$SB/.claude/settings.json` and `settings.local.json` allow rules:
     - add only what the harness needs, mirroring §9.2 `smoke_ship_allow ship` with §10.2's exact `Bash(grep -v '^$' *)`;
     - no MCP denies or git denies (the launcher appends the fixed denies itself, A4 change 5);
     - **no** `awk 'NF'` rule (C2 dropped);
     - the broad lines follow Phase A's recorded C3 decision (A9): `npx` only as `Bash(npx vitest *)`, `Bash(npx eslint *)`, `Bash(npx next *)`, `Bash(npx playwright *)`; `curl` only as `Bash(curl http://localhost:*)`; **no** `Bash(node *)`, `Bash(sh -c *)`, `Bash(npx *)` or `Bash(curl *)`. A broader line is added only after a recorded denial, and is then recorded as detect-only.

     Record in `## Rails and launchers` which lines came from init and which the harness added. Verify with `grep -E '^(Bash\(gh |Bash$|Bash\(\*\))' "$E2E/allow-ship.txt"`, which prints only `Bash(gh auth status)`, and `grep -cE '^Bash\((node|sh -c|npx|curl) \*\)$' "$E2E/allow-ship.txt"`, which gives `0`. The launcher's allow-file refusal is the second proof, and it is free: it runs before any spend at the first headless launch (B4), where a refusal is exit 2 with nothing started. (`--env-check` takes no allow file, so it cannot prove this.)
  6. P6. Commit: `test(e2e): record init on the sandbox and its merged PR`.
- **verification:** every step-2 check passes; the P4 verdict is `accurate`; `main` is fast-forwarded with the merge; the allow file is built; the record section is committed.

### B2 — issue and milestone fixtures (S1 to S8)

- **files:**
  - `tests/e2e-validation.md` (`## Sandbox fixtures`);
  - outside the repo: `$E2E/bodies/*.md`, `$E2E/fixtures.env`.
- **depends_on:** [] (it can run while B1's PR waits for the merge; it must finish before B3)
- **pattern:**
  - the spec's "Scenario fixtures" table (the shapes, fixed);
  - §10.2 `smoke_ms_bodies` (the body format: `### Summary`, `### Acceptance criteria`, `### Out of scope`; numbered, testable ACs).
- **ACs:** 13 (with V-11 proved by running it, cut 6).
- **risk:** low (it creates issues and milestones; nothing is deleted).
- **steps:**
  1. Draft every body with the Write tool into `$E2E/bodies/`, in the sandbox's real context (the route and page names from `$SB`):
     - **S1:** 4 ACs, no UI.
     - **S2:** inline errors, the live-region summary, focus to the first invalid field, WCAG 2.2 AA, both viewports.
     - **S3:** deliberately leaves out the limit, the key and the response.
     - **S4:** `ADMIN_EMAIL` sent through a transport the route can be given in tests. "The admin receives the email" is the one non-automatable AC; the transport call and the 200 still holding on a failure are automatable.
     - **S5a to S5c:** each 3 ACs or fewer, same page, no dependencies.
     - **S6a to S6c:** the chain, where S6b's and S6c's bodies end with `Depends on #<prev>`.
     - **S7:** trim the fields and lowercase the email.
     - **S8:** a request id. It is created now for Phase D, so that AC-13's "before the first scenario" holds for every fixture.
  2. Milestones:
     - first `gh help milestone >/dev/null 2>&1; echo $?` (V-11: is there a built-in command?);
     - then `gh api repos/$GHR/milestones -f title='Contact page polish'` and `-f title='Submissions log'` (or the built-in command if one exists);
     - record each command and the returned `number` (V-11 evidence).
  3. Issues, in this order: S1, S2, S3, S4, S5a, S5b, S5c, S6a, then S6b with S6a's real number substituted, then S6c with S6b's, then S7 and S8.
     - Each one is `gh issue create --repo "$GHR" --title '<title>' --body-file "$E2E/bodies/<s>.md" [--milestone '<title>']`.
     - Write the numbers into `$E2E/fixtures.env`.
  4. Read back every body with `gh issue view <n> --repo "$GHR" --json body -q .body > "$E2E/bodies/<s>.github.md"` and `cmp` it against the draft. Record any GitHub normalisation (a trailing newline, CRLF) as platform behaviour. This read-back is the baseline for S3's byte-for-byte v1 check.
  5. `## Sandbox fixtures`: for each scenario, the number, title and milestone, and the body verbatim in a fenced block (the GitHub read-back), plus the V-11 commands and their output.
  6. Commit: `test(e2e): record the sandbox issue and milestone fixtures`.
- **verification:**
  - `gh issue list --repo "$GHR" --state open --json number,title,milestone` lists 12 issues;
  - `gh api repos/$GHR/milestones -q '.[] | "\(.title) \(.open_issues)"'` gives `Contact page polish 3` and `Submissions log 3`;
  - `gh issue view <S6c> --repo "$GHR" --json body -q .body | grep -x "Depends on #<S6b>"` matches;
  - the record holds 12 bodies.

### B3 — S1: non-UI, gates on, attended

- **files:** `tests/e2e-validation.md` (`## S1`, the ledger row)
- **depends_on:** [B1, B2]
- **pattern:** `tests/agent-smoke/README.md` §9.4 (the S1 check list) and §9.5 (the plan-gate form)
- **ACs:** 16, 14, 15 (CR-1 to CR-8), and C2 interactively
- **risk:** low
- **steps:**
  1. **P2, STOP for James (CP-4).** Cap $15. Command: `/aew:ship <S1>` (no `--auto`).
     - **James is asked:** at the plan gate, to check that it is an AskUserQuestion with approve, request changes and stop, and that the summary is 25 lines or fewer plus the path; then to approve. Afterwards he reports any permission prompt, especially on `grep -v '^$' … | tail -n 4` (C2), and `/cost`.
  2. Checks:
     - **The plan gate**, from the transcript: the AskUserQuestion `tool_use` input has three options, and its summary is 25 lines or fewer (`jq` over the transcript; count the lines) plus the `05-plan.md` path.
     - **AC tracing:** in `08-qa-report*.md`, the TC → AC table covers every spec AC (`grep` the AC ids from `spec-final.md` against the table), and `10-summary.md` shows `n/n` ACs passed.
     - **C2:** no prompt or denial on ship's return-check form (James's report, plus the settings diff showing no new allow rule).
     - **The PR is opened:** CR-3 with base `main` and `Closes #<S1>`.
  3. P3 (CR-1 to CR-8; the CR-2 flags are none), then P4.
  4. **P5, STOP for James (CP-3).**
  5. P6. Commit: `test(e2e): record S1, a gated non-UI run to a merged PR`.
- **verification:** every row passes, or has a fix-loop attempt that ends in a pass.

### B4 — S2: UI with an accessibility requirement, `--auto`, headless

- **files:** `tests/e2e-validation.md` (`## S2`)
- **depends_on:** [B3] (needs S1's 422 shape on `main`)
- **pattern:** §9.4 headless S1; §8.3 and §8.4 run 951 (the QA phase B evidence: specs, screenshots, axe)
- **ACs:** 17, 14, 15
- **risk:** low
- **steps:**
  1. P1: `"$E2E/e2e-run.sh" "$SB" S2.1 20 "$E2E/allow-ship.txt" "/aew:ship <S2> --auto"`.
  2. Checks:
     - **No plan gate:** no AskUserQuestion in the stream, and `log.md` goes from `plan` to `develop` with no `awaiting-approval` stop.
     - **Specs committed:** `E=$(jq -r .ui.e2e_dir "$SB/.aew/config.json"); git -C "$SB" ls-tree -r --name-only origin/<branch> -- "$E"` lists at least one spec file.
     - **Screenshots:** `git -C "$SB" ls-tree -r --name-only origin/<branch> -- docs/qa/<S2>/` shows desktop (1440×900) and mobile (390×844) files for each screen. The dimensions are confirmed with `sips -g pixelWidth -g pixelHeight` on a checked-out copy.
     - **axe:** `grep -n -i 'axe' "$SB/.aew/runs/<S2>/08-qa-report"*.md` shows results against `jq -r .ui.axe_standard "$SB/.aew/config.json"`.
     - **For information:** whether the developer thread made a `Skill` call to `frontend-design` (`jq` over the stream, on any thread), and whether a QA fix cycle ran (`fix_cycle` > 0, or a QA-to-develop line in `log.md`).
     - **If a material spec gate stops the run under `--auto`:** STOP for James (CP-4). Run an attended `/aew:resume <S2>` through P2, and record the fixture note (Risk 4).
  3. P3 and P4.
  4. **P5, STOP for James (CP-3).**
  5. P6. Commit: `test(e2e): record S2, an accessible UI run with Playwright, screenshots and axe`.
- **verification:** all four [P] rows pass; the two information rows are recorded.

### B5 — S3: deliberate material ambiguity, `--auto`, attended

- **files:** `tests/e2e-validation.md` (`## S3`)
- **depends_on:** [B4]
- **pattern:**
  - §9.8 G1 (a spec-gate stop);
  - `tests/scripts/gh-issue-body.bats:20` `prev_of` (the jq that extracts v1 between `<!-- aew:spec-prev v1 -->` markers) and `:110` (the `<summary>Spec v1 (original)</summary>` line).
- **ACs:** 18, 14, 15
- **risk:** **real issue-body rewrite** (`gh-issue.sh revise` on a real GitHub issue). Rollback: GitHub's edit history, or `$SB/.aew/runs/<S3>/00-issue-original.md`.
- **steps:**
  1. Save `gh issue view <S3> --repo "$GHR" --json body -q .body > "$E2E/out/S3.1/body-before.md"` (it must `cmp` equal to B2's read-back).
  2. **P2, STOP for James (CP-4).** Cap $10. Command: `/aew:ship <S3> --auto`.
     - **James is asked:** to check that the spec gate appears even with `--auto`, and to answer its questions. The suggested answer is "5 submissions per IP per 10 minutes; over the limit, return 429 with `Retry-After`; in-memory store", but the answer is his. Then he reports `/cost`.
     - His answer is recorded verbatim.
  3. Checks:
     - **The gate fired:** `log.md` has an `awaiting-input` (spec gate) line, and `state.json` `auto` is `true`.
     - **v2 on top:** `gh issue view <S3> --repo "$GHR" --json body -q .body > "$E2E/out/S3.1/body-after.md"`; the first spec block is v2, and `grep -qxF '<summary>Spec v1 (original)</summary>'` matches.
     - **v1 byte for byte:** the `prev_of` jq expression from `gh-issue-body.bats:20`, with k=1, applied to `body-after.md`, then `cmp` against `body-before.md` and against `00-issue-original.md`. Both exit 0.
     - **The comment and the flag:** a revision comment lists the changes (`gh issue view <S3> --repo "$GHR" --json comments -q '.comments[].body' | grep -n 'Spec revision v2'`), and CR-2 shows the flag `aew:spec-revised`.
     - **The run continues to a PR:** CR-3.
  4. P3 (the CR-2 expected flags are `aew:spec-revised`) and P4. The introduction must mention the clarification.
  5. **P5, STOP for James (CP-3).**
  6. P6. Commit: `test(e2e): record S3, a spec gate under --auto and a revised real issue body`.
- **verification:** `cmp` exits 0 on both v1 comparisons; the gate, comment, flag and PR rows pass.

### B6 — S4: one non-automatable check, `--auto`, headless

- **files:** `tests/e2e-validation.md` (`## S4`)
- **depends_on:** [B5]
- **pattern:** §9.4 (S1's manual-test variant, `expected_s1 … <manual 1>`); `skills/ship/references/pr.md` `## Manual tests`
- **ACs:** 19, 14, 15
- **risk:** **real issue-body rewrite** (`gh-issue.sh manual-tests`). Rollback as in B5.
- **steps:**
  1. P1: `"$E2E/e2e-run.sh" "$SB" S4.1 12 "$E2E/allow-ship.txt" "/aew:ship <S4> --auto"`.
  2. **If the spec analyser gates** (the run stops at `awaiting-input`): STOP for James (CP-4). Run an attended `/aew:resume <S4>` through P2, from the reserve. Record the fixture note (the §9.5 precedent). This is not a failure.
  3. Checks:
     - **The manual-tests block:** the issue body has a `<!-- aew:manual-tests -->` block, the rest of the body is intact (no line of B2's read-back is lost, by the `assert_no_line_lost` logic with `--except-manual`), and CR-2 shows the flag `aew:manual-test-required`.
     - **The PR lists the manual test**, and the final report counts it as outstanding: `grep -c '^- \[ \]' "$SB/.aew/runs/<S4>/manual-tests.md"` gives 1, with the same count in the report.
     - **Everything else is automated:** every other spec AC has a passing TC in the QA report.
  4. P3 and P4. The introduction must say a person still has to check the email.
  5. **P5, STOP for James (CP-3).**
  6. P6. Commit: `test(e2e): record S4, a manual test added to a real issue and listed on the PR`.
- **verification:** the block, flag, PR listing and outstanding count all pass, and the other ACs are automated.

### B7 — AC-20: lift the real-issue-body limitation

- **files:** `skills/github-ops/SKILL.md` (line 75), `CHANGELOG.md` (line 21), `tests/e2e-validation.md` (one fix-log-style row)
- **depends_on:** [B5, B6]. **Only if** S3's v1 `cmp` and S4's manual-tests rows both pass. Otherwise the limitation stays and the gap is recorded.
- **pattern:** the limitation text itself; the CHANGELOG `[Unreleased]` `### Added` list
- **ACs:** 20
- **risk:** medium. It removes a safety note, and is gated on the B5 and B6 evidence. Rollback: revert the commit.
- **steps:**
  1. Delete the line `- No rewrite of a real issue body (\`revise\`, \`manual-tests\`) until prompt 07's sandbox end-to-end run passes. Sandbox issues only until then.` from `skills/github-ops/SKILL.md`. Keep line 76 (the rollback for a bad rewrite still applies) and the lost-update race line.
  2. Delete `- Limitation: no rewrite of a real issue body …` from `CHANGELOG.md` `[Unreleased]`. It never shipped, so there is nothing to mark as changed; Phase F writes `[0.1.0]`.
  3. `grep -rn "prompt 07's sandbox\|no rewrite of a real issue body" "$REPO/skills" "$REPO/CHANGELOG.md" "$REPO/README.md" "$REPO/docs/DESIGN.md"` prints nothing.
  4. Fix-loop steps 5 and 6: run `tests/run-script-tests.sh` and `claude plugin validate .`, refresh the install, and `cmp` `skills/github-ops/SKILL.md` against `installPath`. This is done between sessions only, before B8 starts.
  5. Commit: `docs(github-ops): lift the sandbox-only limit on real issue-body rewrites`, with a body naming the S3 and S4 evidence and the plain Claude trailer. Then add a row to `## Fix log` (the commit, "AC-20 limitation lifted", S3 and S4, no re-run).
- **verification:** the grep is empty; the suite and validate pass; the installed copy matches.

### B8 — S5: bulk milestone, attended (mode question)

- **files:** `tests/e2e-validation.md` (`## S5`)
- **depends_on:** [B6, B7] (B7 always completes before S5: it either lifts the limitation and refreshes the install, or records the gap; no refresh may run during S5's session)
- **pattern:** §10.3 M1 (the bulk recommendation) and §10.4 B1.2 (checks 1, 8 to 11: one PR, `--issues 3`, `ready-for-review` on all three, the milestone report comment)
- **ACs:** 21, 14, 15
- **risk:** low
- **steps:**
  1. **P2, STOP for James (CP-4).** Cap $25. Command: `/aew:ship-milestone <M_S5> --auto` (no mode flag).
     - **James is asked:** to check that the skill recommends **bulk** with its rationale, and to confirm it. The run then continues on its own (`--auto`). He reports `/cost`.
  2. Checks:
     - **Recommendation:** the transcript shows "bulk" and its reasons, and James's confirmation.
     - **One PR:** `gh pr list --repo "$GHR" --state open --json number,body` gives one PR, with `Closes #<S5a>`, `#<S5b>` and `#<S5c>`.
     - **Introduction:** P4 with `--issues 3`; it must read as the bulk variant.
     - **Each issue:** CR-2 shows `aew:ready-for-review`, and one comment equals `.aew/runs/m-<M_S5>/milestone-report.md` (compare `gh issue view <k> --json comments -q '.comments[-1].body'` with that file).
     - **CR-1** on `m-<M_S5>`; **CR-3** with base `main` and all three closes.
  3. P3 and P4.
  4. **P5, STOP for James (CP-3).** Afterwards `gh issue view <k> --json state` gives `CLOSED` for all three.
  5. P6. Commit: `test(e2e): record S5, a bulk milestone to one PR closing three issues`.
- **verification:** the recommendation, one PR with three closes, the `--issues 3` intro, and the labels and report on all three all pass.

### B9 — S6: sequential chain, headless `--sequential --auto`, stacked merges

- **files:** `tests/e2e-validation.md` (`## S6`)
- **depends_on:** [B8]
- **pattern:**
  - §10.5 Q3.2 (stacked PR bases, `merge-base --is-ancestor`, index statuses);
  - `skills/ship-milestone/references/sequential.md`;
  - the spec's AC-22 stacked merge protocol, unchanged.
- **ACs:** 22 (as amended by cut 2), 14 (each child PR), 15
- **risk:** medium. A stacked merge done wrong leaves an issue open, or replays child 1's commits into child 2. The protocol below mitigates it, and nothing is automated.
- **steps:**
  1. P1: `"$E2E/e2e-run.sh" "$SB" S6.1 30 "$E2E/allow-ship.txt" "/aew:ship-milestone <M_S6> --sequential --auto"`.
     - **If a child stops at a material spec gate:** STOP for James (CP-4), for an attended `/aew:resume m-<M_S6>` through P2.
     - **If the model stops itself between children on budget** (the §10.7 Q1.1 precedent): a headless `/aew:resume m-<M_S6>` as `S6.2`, from the reserve (CP-1 if past it).
  2. Checks:
     - **Order:** `jq -c '.order, [.children[] | .status]' "$SB/.aew/runs/m-<M_S6>/index.json"` gives `[S6a,S6b,S6c]` and `["done","done","done"]`.
     - **Bases:** `gh pr list --repo "$GHR" --state open --json number,headRefName,baseRefName` shows child 1 on `main`, child 2 on child 1's branch and child 3 on child 2's. `git -C "$SB" merge-base --is-ancestor origin/<child1-branch> origin/<child2-branch>` is true, and likewise for 2 and 3.
     - **Introductions:** P4 on each child PR; children 2 and 3 carry the stacked variant, naming the PR they must follow.
     - **Milestone report** on all three issues, as in B8.
     - CR-1 on `m-<M_S6>` and on each child's run; CR-2 to CR-8 per child, with CR-4 run on each child branch.
  3. **Stacked merge protocol, STOP for James (CP-3) three times, in order.**
     - **Child 1.** **James is asked:** "Merge PR #<c1> with **Create a merge commit** (not squash). Tell me whether you deleted the branch." (The new sandbox repo has `deleteBranchOnMerge` false, like the plugin repo, so GitHub retargets #<c2> to `main` only if James deletes child 1's branch; otherwise expect "James retargeted" below. Either is a pass.)
     - **Before child 2.** The executor runs `gh pr view <c2> --repo "$GHR" --json baseRefName -q .baseRefName`.
       - If it is `main`, it records "GitHub retargeted".
       - Otherwise, **James is asked** to retarget #<c2> to `main` in the GitHub UI, and the executor re-checks until it reads `main` (recording "James retargeted").
       - Then **James is asked** to merge #<c2> with **Create a merge commit**.
       - The executor checks that `gh pr view <c2> --json files` lists only child 2's own files.
     - **Before child 3.** The same base check and retarget, then **James is asked** to merge #<c3> (any method; record it).
     - **After all three:**
       - `gh issue view <k> --repo "$GHR" --json state` gives `CLOSED` for S6a, S6b and S6c;
       - after `git -C "$SB" switch main && git -C "$SB" pull --ff-only`, `main` holds the store module, `app/api/submissions/route.ts` and the `/submissions` page (`git -C "$SB" ls-tree -r --name-only main | grep -E 'submissions'`).
     - Record per child: the merge method, whether the branch was deleted, and whether GitHub or James retargeted the next PR (prompt 06's Risk 3).
  4. P6. Commit: `test(e2e): record S6, a sequential chain with three stacked PRs merged in order`.
- **verification:** the order and bases are correct; the index reads `done, done, done`; the report is on all three; the three issues are closed and `main` holds all three changes; the per-child merge record is complete.

### B10 — S7: interrupt during `develop`, then status and resume, headless

- **files:** `tests/e2e-validation.md` (`## S7`, and the V-7 row in `## Platform facts`).
- **depends_on:** [B9]
- **pattern:** `tests/agent-smoke/README.md` §9.6 runs F1 and R2 (the kill with kill-agent, the artefact `shasum` snapshot, "no earlier stage", the dirty-tree path)
- **ACs:** 23, 14, 15; V-7 and V-9 evidence
- **risk:** medium. A killed session can leave partial work or a stray process, which is handled by the R2 dirty-tree path and the process check.
- **steps:**
  1. **Precondition (free).** `grep -n 'kill -INT\|kill -s INT' "$E2E/e2e-run.sh"` confirms the poller's first signal is SIGINT (Phase A built it so and self-tested it; AC-23). A miss is a Phase A defect: stop and go back to A4.
  2. **Kill.** P1: `"$E2E/e2e-run.sh" "$SB" S7.1 8 "$E2E/allow-ship.txt" "/aew:ship <S7> --auto" develop aew:developer`. A killed session is charged at its cap.
     - **Checks:**
       - `cat "$O/killed-at"` gives a timestamp; `jq -r '.stage, .status' "$SB/.aew/runs/<S7>/state.json"` gives `develop`, `running`;
       - V-9: whether the session exited on SIGINT or needed TERM or KILL (its exit code, and whether any `result` event was emitted);
       - `pgrep -fl 'playwright/mcp'` shows nothing from this run;
       - `git -C "$SB" status --porcelain` is recorded.
     - **Snapshot:** `(cd "$SB/.aew/runs/<S7>" && shasum 00-issue-original.md issue.json 01-spec-analysis.md spec-final.md 02-brief.md 03-standards.md 04-qa-test-plan.md 05-plan.md) > "$E2E/out/S7.1/artefacts.sha"`, then `wc -l < "$SB/.aew/runs/<S7>/log.md" > "$E2E/out/S7.1/log.lines"`.
  3. **Status and the hint.** P1: `"$E2E/e2e-run.sh" "$SB" S7.2 1 "$E2E/allow-ship.txt" "/aew:status <S7>"`.
     - `jq -rR 'fromjson? | select(.type == "result") | .result' "$O/stream.jsonl"` shows `develop` and `running`.
     - The same stream (hook events, per V-7) carries `Active aew run <S7> at stage develop (running). Use /aew:resume.`. If not, `grep -F 'Active aew run' "$O/debug.log"`. Record which source held it, and fill the V-7 row of `## Platform facts` with that runtime result (Cut 1).
     - `state.json` is unchanged (status is read-only).
  4. **Resume.** P1: `"$E2E/e2e-run.sh" "$SB" S7.3 12 "$E2E/allow-ship.txt" "/aew:resume <S7>"`.
     - **If step 2 left partial developer work and resume stops on the dirty tree:** record it as a pass of "resume refuses a dirty tree". Then discard the partial work as a logged harness action (a script file run with `/bin/bash`: `git -C "$SB" checkout -- . && git -C "$SB" clean -fd -e .claude/agent-memory/`) and run `S7.4` with the same command (the R2 precedent).
     - **Checks:**
       - `(cd "$SB/.aew/runs/<S7>" && shasum -c "$E2E/out/S7.1/artefacts.sha")` gives every line `OK`;
       - `tail -n +$(( $(cat "$E2E/out/S7.1/log.lines") + 1 )) "$SB/.aew/runs/<S7>/log.md" | awk '{print $3}' | grep -xcE 'spec_analysis|brief|standards|qa_test_plan|plan'` gives `0`;
       - there is no main-thread `Agent` call to `aew:spec-analyser`, `aew:brief-compiler` or `aew:standards-setter` in the resume stream;
       - the run reaches a PR (CR-3).
  5. P3 (on the final state) and P4. The introduction should mention the interruption, if `10-summary.md` does.
  6. **P5, STOP for James (CP-3).**
  7. P6. Commit: `test(e2e): record S7, a run interrupted in develop and resumed to a PR`.
- **verification:** the kill landed at `develop`; status and the hint are recorded with their source; the `shasum -c` is all `OK`; there are 0 earlier-stage lines; a PR is opened and merged.

### Hand-offs

- **To Phase D:** after B1's merge and B2, D has `main` with `.aew/config.json` and the S8 issue number in `$E2E/fixtures.env`. S8 opens no PR, so D may run while any Phase B PR waits for James.
- **To Phase F:** `tests/e2e-validation.md` holds, ready for the roll-up and AC-34's re-read:
  - `## init`, `## S1` to `## S7`, each with inline introduction verdicts and denials;
  - `## Sandbox fixtures`;
  - `## Guard false positives`;
  - `## Fix log`;
  - every ledger row.

  Also handed over:
  - the list of platform behaviours found, for README troubleshooting;
  - `retro.repo` items, untouched, for the AC-29 transfer.
- **Phase B spend:** init 5, S1 15, S2 20, S3 10, S4 12, S5 25, S6 30, S7 8 + 1 + 12, which is **$138 of caps**. The spec's $1 hint probe is cut, and re-runs come from the shared reserve under the $200 stop.

## Phase D — Prompt mode and plugin-less build (S8)

- **AC:** AC-24 (plus AC-26's per-scenario record, AC-27's guard log and AC-28's fix loop, as they apply to S8).
- **Depth:** lean. **Risk:** none.
- **Cross-phase prerequisites:** Phase B's init PR merged and `main` fast-forwarded (AC-12), **and** Phase B's fixture task done (AC-13), because the S8 issue number comes from it. Phase A's launchers, canary and V-5 record (`--bare` or the plugin-less profile) are in place. Nothing else from B, so D runs in any gap where no run is active in the sandbox (typically while a PR waits for James's merge).
- **Paths:** `$SB` = `/Users/jamesborg/Documents/Development/aew-sandbox`, `$S8WT` = `/Users/jamesborg/Documents/Development/aew-sandbox-s8`, `$E2E` = `/Users/jamesborg/Documents/Development/aew-e2e`, `<S8>` = the S8 issue number from `## Sandbox fixtures`.
- **Spend (CP-1 table):** D1 cap $4, D4 cap $8. Before each session, the ledger must show that the cap fits under the $200 stop; otherwise ask James (CP-1). A re-run comes out of the reserve.
- **No human checkpoint** in the normal path: both sessions are headless. James is only asked if the spend rule above trips, D1 stops at the spec gate (D1's gate fallback), or a fix hits CP-6.

### D1 — Headless `/aew:prompt <S8>` in the sandbox

- **files:** none in the plugin repo. Writes only `$SB/.aew/runs/<S8>/` (gitignored) and the ledger and stream in `$E2E`.
- **depends_on:** [] (the cross-phase prerequisites above).
- **pattern:** a headless `e2e-run.sh` session as in Phase B's S2 and S4 runs, with the allowlist built the same way (init's `.claude/settings*.json` plus the harness lines; the `smoke_ship_allow` shape in `tests/agent-smoke/README.md` §9.2). The skill under test is `skills/prompt/SKILL.md` (Steps 1 to 6; Step 6.3 prints `Not posted.` when AskUserQuestion is absent).
- **pre-checks (executor, before the session):**
  - `$SB/.aew/runs/current` is absent or empty (Preflight Check 5: one active run per project). If a B run is active, wait.
  - Snapshot for the "nothing changed" checks: `git -C $SB rev-parse HEAD` and `git -C $SB branch --list` on every local branch; `git -C $SB ls-remote --heads origin`; `gh issue view <S8> -R jamesborg2012/aew-sandbox --json labels,comments,body` (label names, comment count, body hash).
- **run:** `e2e-run.sh` with cap 4 and the prompt `/aew:prompt <S8>`.
- **verification (expected):**
  - `test -f $SB/.aew/runs/<S8>/prompt.md` → exists and is non-empty.
  - `state.json` validates against `templates/state.schema.json` (ajv command in the repo `CLAUDE.md`), `status` is `done`, its `branch` is `null`, its history's first entry is `state.sh init`'s note-less `spec_analysis` entry and its second is the `spec_analysis` entry with note `prompt` (prompt skill Step 3, written straight after 3.2), and `$SB/.aew/runs/current` is cleared.
  - The stream's result text contains `Prompt written: .aew/runs/<S8>/prompt.md` and `Not posted.`.
  - No branch and no commit: local branch list, `HEAD` and `ls-remote --heads` all equal the snapshot.
  - No stage label: the issue's labels hold no `aew:<stage>` label. `aew:spec-revised` appears only if a revision was recorded (none is expected, since S8 is drafted with no material gap); if it appears, record why.
  - Nothing posted: the comment count and the body hash are unchanged. The one allowed exception is a recorded spec revision (`gates.md` `## Recording a spec revision`), which adds exactly one `## Spec revision v<N>` comment, rewrites the body and sets `aew:spec-revised`; if that happens, record all three and why.
  - The stream holds no `AskUserQuestion` call and no `gh-issue.sh comment`.
  - The launcher's post-session audit is clean, and any guard or permission denial is listed and classified (AC-27; CR-6 and CR-7 rules).
- **gate fallback (not a failure):** `/aew:prompt` has ship's spec gate and no `--auto`. If the run stops `awaiting_input` at `gate:spec`, that is a fixture issue, not a plugin defect: James resumes it attended (`/aew:resume <S8>` through `e2e-session.sh`, CP-4, the S4 precedent and spec Risk 4), the fixture tuning is recorded, and the expectations above are checked after the resume. `current` stays set until then, so no B run starts in the meantime.
- **on failure:** D6.

### D2 — Plugin-less mode in `e2e-run.sh`, and its fence check

- **files:** `$E2E/e2e-run.sh` (outside every repo, never committed).
- **depends_on:** [].
- **pattern:** Phase A's `e2e-run.sh` and its `--env-check` form (the §9.2 reference copy's `ship-run.sh --env-check`). The mechanism comes from the V-5 record in `## Platform facts`: `claude --bare -p` if it works under James's login, otherwise the profile with every installed plugin disabled.
- **change:** add one plugin-less switch, the leading flag `--plugin-less` (Phase A, A4 change 1: same position as `--attended` / `--env-check`, combinable with `--env-check`). It (a) exports **no** `GH_TOKEN` (nor `GITHUB_TOKEN`), keeps `GH_CONFIG_DIR` pointed at an empty directory, sets `GH_HOST=aew-smoke.invalid` (an empty config dir alone does **not** hide the keychain token; `GH_HOST=<invalid>` is what makes `gh` fail, project-map gotcha and §9.2 rail 3; a plugin-less session needs no GitHub at all), sets `GIT_CONFIG_COUNT=1` with only the empty `credential.helper` reset (the normal mode's second helper, `gh auth git-credential`, would otherwise serve the keychain token to git because git asks for `github.com` regardless of `GH_HOST`), and sets `GIT_TERMINAL_PROMPT=0` so a credential-less git fails instead of waiting for input, (b) adds `--bare` or the plugin-less profile, (c) uses Phase A's existing `<project>` argument as the session's `cwd` (here `$S8WT`; A's origin check already accepts the worktree), so no new path argument is added, and (d) uses an allowlist with **no** `git push` and **no** `gh` (D4's list). Invocation: `"$E2E/e2e-run.sh" --plugin-less "$S8WT" <run> <cap> <allow-file> "<prompt>"`. Everything else stays: the cap, `--permission-mode acceptEdits`, `--permission-prompts none`, the MCP connector denies, the ledger and stop, and the post-session audit.
- **verification (no paid session):**
  - Plugin-less `--env-check`: `gh api user` **fails** (no token), and `git ls-remote https://github.com/jamesborg2012/aew-sandbox.git` **fails** (no credential reaches a private repo). Record both commands with their exit codes. Never print the token. If either one **succeeds** (for example, git finds James's credential through a global `credential.helper` such as the macOS keychain), the fence does not hold: fix the plugin-less environment (for example, a credential-free git config for the session) and repeat the check. D4 does not start until both fail.
  - Normal-mode canary re-run (AC-9, "after any launcher change"): Phase A's canary rows 1 to 10 give the same results as recorded in A9 (row 9 as James decided at A6).
  - The changed environment lines go into `## Rails and launchers` (cut 4: changed lines only, not a diff).

### D3 — Separate worktree beside the sandbox

- **files:** `$S8WT` (a local git worktree of `$SB`, on a local-only branch `s8-plugin-less`). Nothing is pushed.
- **depends_on:** [D1] (so that the `prompt.md` it reads exists).
- **pattern:** none in the repo. These are plain `git worktree` commands, run as `git -C $SB …`. Any command whose text a guard blocks goes in a script file run with `/bin/bash` (the project-map gotcha).
- **steps:**
  - `git -C $SB fetch origin`, then create the worktree from `origin/main` with the new local branch and `--no-track` (so the branch has no upstream to push to). Record the base commit.
  - Install dependencies in `$S8WT` with the sandbox's lockfile install (so the session does not need the network). Then run the sandbox's unit tests and lint once as the baseline.
  - If `prompt.md` names any `.aew/` file by path, copy exactly those files to the same relative path under `$S8WT` (it is gitignored there too), and record which ones. A pasted prompt in the real project would see them. Nothing else from `.aew/` is copied.
- **verification:** `git -C $SB worktree list` shows `$S8WT` on `s8-plugin-less`. The baseline tests and lint pass. `git -C $SB ls-remote --heads origin` has no `s8-plugin-less`.

### D4 — Plugin-less headless session with `prompt.md` as its only input

- **files:** writes only inside `$S8WT` (local commits on `s8-plugin-less`), plus the ledger and stream in `$E2E`.
- **depends_on:** [D2, D3].
- **pattern:** the D2 plugin-less mode of `e2e-run.sh`. The allowlist covers Read, Edit and Write, the sandbox's own `npm run` scripts and test runner, and local git (`status`, `diff`, `log`, `add`, `commit`, `checkout -b`). It has no `git push`, no `gh` and no network installers. The user MCP connectors stay denied.
- **run:** `e2e-run.sh` in plugin-less mode, cap 8, `cwd` `$S8WT`, with the full text of `$SB/.aew/runs/<S8>/prompt.md` as the prompt (the headless equivalent of pasting it; Assumption 9).
- **verification (expected):**
  - The stream's `system/init` lists **no** plugin: no `aew:` skill or agent, no plugin MCP server (`plugin:aew:playwright` absent), and no plugin hook output in the stream. This proves the session really ran without the plugin.
  - Its output includes a plan. The executor then runs the sandbox's unit tests and lint in `$S8WT`, and both pass. `git -C $S8WT log <base>..HEAD` shows the first work package's commit(s), with its tests.
  - Nothing aew-specific was needed: the stream holds no `Skill` or `Agent` call naming `aew:`, no `/aew:` command, and no read of a `.aew/` path other than the ones D3 copied.
  - The fences held: the stream holds no `git push` and no `gh` call, or only their denials; `ls-remote --heads origin` is still free of `s8-plugin-less`.
  - The audit is clean. Every permission denial is listed (CR-7 rules). A denial of a command `prompt.md` itself prescribes is a gap in the prompt.
  - The executor's verdict (`pass` or `fail`, plus a list of gaps hit, such as missing context, wrong commands or an ambiguous work package) is written for D5.
- **on failure:** D6. A `prompt.md` that isn't self-sufficient is a plugin defect in the brief-compiler's prompt mode, not a fixture issue.

### D5 — Record S8, then clean up locally

- **files:** `tests/e2e-validation.md` (`## S8` section and spend ledger rows), plugin repo branch `feature/e2e-validation`.
- **depends_on:** [D4].
- **pattern:** the per-scenario record form of `tests/agent-smoke/README.md` §9 and §10, trimmed per cut 4. The expectation table holds pass or fail with evidence for each D1 and D4 expectation. Guard and permission denials are inline. Any false positive also goes in the top-level guard list. There are two ledger rows (D1 and D4, each with cap, cost from the stream's `result`, running total, `attended: no`), plus the duration, problems found and one sub-heading per attempt. Written straight after S8, before the next scenario starts (AC-26).
- **cleanup (after the evidence is captured):** remove the `$S8WT` worktree and delete the local `s8-plugin-less` branch. This is a local cleanup, not a GitHub deletion (Assumption 9). Check that `git -C $SB worktree list` no longer lists `$S8WT`. The S8 issue stays open with no labels, by design: prompt mode never closes or labels an issue. Record this.
- **verification:** the S8 section has a row for every AC-24 expectation, and none is blank. `tests/run-script-tests.sh` still passes (the commit touches no script).
- **commit:** `test(e2e): record S8 prompt mode and plugin-less build` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.

### D6 — Fix loop (only if a D1 or D4 expectation fails)

- **files:** whatever the diagnosis names (likely `skills/prompt/SKILL.md`, `agents/brief-compiler.md` prompt mode, or `templates/artefacts/` for `prompt.md`), plus the bats tests for any scriptable defect.
- **depends_on:** [D1] or [D4], whichever failed.
- **pattern:** AC-28, steps 1 to 7, unchanged:
  - classify the failure;
  - diagnose it with `superpowers:systematic-debugging` from the stream and artefacts;
  - fix it on `feature/e2e-validation`, with a failing bats test first for a script, or by improving the prompt for an agent or skill, never by weakening an expectation;
  - commit each fix on its own;
  - check that `tests/run-script-tests.sh` and `claude plugin validate .` pass;
  - refresh the install by V-3's method and prove the cached copy matches;
  - re-run as a new attempt.

  A D4 re-run first removes and recreates `$S8WT` (D3) and reruns D1 only if the fix changed what `prompt.md` contains (that is, remove `$SB/.aew/runs/<S8>` and run `/aew:prompt <S8>` again).
- **verification:** the re-run attempt passes, and the fix log row (commit, problem, S8, re-run, result) is filled in.
- **commit:** one conventional commit per fix (for example `fix(brief-compiler): …`), with the plain Claude trailer. A re-run beyond the reserve asks James first (CP-1).

## Phase E — Optional WooCommerce sandbox (S9)

- **AC:** AC-25. When S9 runs, AC-14 and AC-15 (CR-1 to CR-8, per cut 5) apply to its PRs, and AC-26 to AC-28 apply to its record and fixes.
- **Depth:** lean. **Risk:** none.
- **Cross-phase prerequisites:** Phase A only (launchers, canary, PAT, AC-8 pattern, V-list record). E touches neither `aew-sandbox` nor its run, so it never blocks B or D.
- **When to ask CP-5:** once S1 to S8 are recorded. Only then is the rule "S9 (cap 25) only if 25 or more remains under the stop" measurable from the ledger. If James wants to ask earlier, S9 then comes out of the re-run reserve, and he is told so.
- **Paths:** `$WOO` = `/Users/jamesborg/Documents/Development/aew-sandbox-woo` (a sibling of `aew-sandbox` and its own git repo, never inside the plugin tree), and `$E2E` as in Phase A.
- **Spend:** S9 cap $25 in total, split as init $5 plus ship $20. An attended resume, if one is needed, comes out of what remains. If a session would pass the stop, ask James (CP-1).

### E1 — STOP for James: CP-5, run S9 or skip it

- **files:** none.
- **depends_on:** [].
- **pattern:** CP-5 in the spec. The default comes from the simplicity-challenge decision.
- **executor first runs (free):**
  - `docker info`. On 2026-10-26 the daemon is down, so this is expected to exit non-zero with "Cannot connect to the Docker daemon".
  - The ledger's remaining amount under the $200 stop.
- **then asks James** with the facts:
  - the Docker state;
  - the remaining amount against the $25 needed;
  - that running S9 also needs him to start Docker Desktop and add `aew-sandbox-woo` to the PAT (E4).

  The options are **"Skip S9 and record the reason" (default)** and "Start Docker and run S9".
- **routing:**
  - Skip, or less than $25 remaining (with no CP-1 approval to go over), goes to E2 and ends the phase.
  - Run goes to E3, but only once `docker info` exits 0 after James starts Docker Desktop.
- **verification:** James's answer and the `docker info` result (exit code and first line) are recorded for E2 or E7.

### E2 — Record S9 as skipped (skip branch, terminal)

- **files:** `tests/e2e-validation.md` (`## S9` section, roll-up row), on plugin repo branch `feature/e2e-validation`.
- **depends_on:** [E1 → skip].
- **pattern:** the per-scenario record form, as in Phase D's D5.
- **content:**
  - `S9: skipped`;
  - the reason (for example "Docker daemon not running on <date>; James chose skip at CP-5", or the budget reason) and the `docker info` evidence;
  - a note that the PAT was not widened and no `aew-sandbox-woo` repo was created.

  The roll-up marks AC-25 `skipped` with that reason, which satisfies the build prompt's "S9 passes or is documented as skipped, with the reason".
- **verification:** the `## S9` section and the roll-up row are present and agree.
- **commit:** `test(e2e): record S9 as skipped` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.

### E3 — Create `aew-sandbox-woo` with a minimal WooCommerce extension

- **files:** a new repo `jamesborg2012/aew-sandbox-woo` (private) and its clone `$WOO`:
  - the plugin's main PHP file;
  - one small PHP class or function file;
  - its unit test and test config;
  - `.wp-env.json`;
  - `package.json` (with `@wordpress/env` pinned) and `composer.json` if the test runner needs it;
  - lint config;
  - `README.md`, `.gitignore`;
  - `.claude/settings.local.json` (gitignored).
- **depends_on:** [E1 → run].
- **pattern:** Phase A's AC-6 and AC-7 tasks, the same way: the repo is created by the executor with `gh repo create --private` under its own keychain token, the PAT can't create repos, and the clone sits beside the sandbox. Phase A's AC-8 task is mirrored for `.claude/settings.local.json` (dev-workflow, figma and warp disabled for this project only). Detection rules: `scripts/detect-stack.sh` (a `Plugin Name:` header gives `wordpress` at that dir; `WC requires at least:` gives the `woocommerce` overlay).
- **shape:**
  - one plugin with `Plugin Name:`, `Requires at least:`, `Requires PHP:` and `WC requires at least:` headers;
  - one WooCommerce hook (`add_action` or `add_filter` on a `woocommerce_` hook) calling one pure function that can be unit tested;
  - `.wp-env.json` maps the plugin and WooCommerce, at a WooCommerce version pinned at creation time;
  - a `lint` command, one passing unit test, and a dev command (`npx wp-env start`).

  Every version is an exact pin, taken at creation time from npm, Packagist or wordpress.org (checked with context7 or the registry, not memory). The lint and test commands are chosen to run on this machine: host `php` and `composer` if `php -v` and `composer -V` work, otherwise inside wp-env's `tests-cli` container. The choice is recorded in the sandbox README. There is no `.aew/`. Push to `main` through a script file run with `/bin/bash`, because the guards match the text `git push`.
- **verification:**
  - `scripts/detect-stack.sh $WOO` prints entries for `wordpress` and `woocommerce` at `.`;
  - `npx wp-env start` comes up on `http://localhost:8888`, with WooCommerce active;
  - lint and the unit test pass;
  - `gh repo view jamesborg2012/aew-sandbox-woo --json visibility` shows `PRIVATE`;
  - no ancestor `CLAUDE.md` exists above `$WOO`.
- **commit (sandbox):** `chore: minimal WooCommerce extension sandbox for aew S9` with the plain Claude trailer.

### E4 — STOP for James: widen the PAT to `aew-sandbox-woo`; re-run the canary

- **files:** none. Phase A's launchers already take the project as their first argument (`e2e-run.sh "$WOO" …`, `e2e-session.sh "$WOO" <run> <cap>`), and their origin check already accepts `aew-sandbox-woo` (A4 change 2), so no launcher change and no new path argument. The canary below is re-run because the PAT changed, not the launcher.
- **depends_on:** [E3] (a fine-grained PAT can only select a repo that exists).
- **pattern:** CP-5 and the AC-9 canary, as in Phase A.
- **James:**
  - adds `aew-sandbox-woo` to the PAT's selected repositories, with the same permissions and no other repo;
  - confirms when it is done.

  The executor never sees the token.
- **verification (in the session environment, via `--env-check`):**
  - `gh api user` names James;
  - `gh repo view jamesborg2012/aew-sandbox-woo` succeeds;
  - `git ls-remote https://github.com/jamesborg2012/aew-sandbox-woo.git` succeeds (the run's push goes through git, not `gh`);
  - `gh repo view` of the out-of-scope private repo **fails**;
  - `git ls-remote` of that out-of-scope repo **fails**.

  The commands and their exit codes are recorded, never the token. Any failure stops S9 here, and it is recorded.

### E5 — STOP for James: attended `/aew:init` in `$WOO` (CP-4), then the init PR

- **files:** in `$WOO`, whatever init writes (`.aew/config.json`, `docs/standards/`, `.claude/settings*.json`, `.gitignore`, the `CLAUDE.md` section) on `chore/aew-init`.
- **depends_on:** [E4].
- **pattern:** Phase B's AC-11 and AC-12 init tasks, as they are, pointed at `$WOO` through `e2e-session.sh`, cap $5.
- **James answers:**
  - the config values, with `retro.repo` = `jamesborg2012/aew-sandbox-retro` (in the PAT's scope, so Phase F's transfer picks up any S9 retro items);
  - the Playwright offer: the recommended answer is decline, because S9's issue is non-UI;
  - the permissions: accept.
- **verification (executor, afterwards):**
  - `.aew/config.json` validates against `templates/config.schema.json`;
  - `stacks` includes `wordpress` and `woocommerce`;
  - `docs/standards/wordpress.md` and `docs/standards/woocommerce.md` exist, each with the `aew:standards fingerprint=` header on line 1, and the fingerprints match `scripts/detect-stack.sh fingerprint <profile> $WOO`;
  - the environment is `env_type` `wp-env`, with start `npx wp-env start` and `base_url` `http://localhost:8888` (init's detection table);
  - `commands` names the lint, test and dev commands from E3;
  - every DESIGN §7.4 label exists on `aew-sandbox-woo`;
  - the settings files merge with E3's `settings.local.json`;
  - the init PR has `## In plain English`, `check-pr-intro.sh` exits 0, and the AC-14 accuracy verdict is `accurate`.
- **James merges** the init PR (CP-3), using the merge method of his choice, which is recorded. The executor never calls `gh pr merge`. The executor then fast-forwards local `main` (`git -C $WOO pull --ff-only`).

### E6 — Fixture issue and a headless `/aew:ship <S9> --auto`

- **files:** the S9 issue on `aew-sandbox-woo`, and the run in `$WOO/.aew/runs/<S9>/` (gitignored). The PR branch is made by the run.
- **depends_on:** [E5].
- **pattern:**
  - Phase B's AC-13 fixture task (the body is drafted in the sandbox's real context and recorded verbatim in `## Sandbox fixtures`);
  - Phase B's headless ship runs (S2, S4) through `e2e-run.sh`, cap $20, with the allowlist from init's settings plus the harness lines;
  - S4's fallback: a material spec gate is resumed attended (CP-4), and the fixture tuning is recorded.
- **fixture shape:** one small, non-UI issue on the extension's hook logic, with 3 ACs or fewer, each unit-testable through the pure function (for example, a minimum order total enforced at checkout). It has no material gap, so `--auto` does not gate.
- **pre-step:** the executor starts wp-env (`npx wp-env start` in `$WOO`) and checks that it is ready before the session, so the session does not pay for start-up. The start is recorded.
- **verification (expected):**
  - a PR is opened from the run's branch to `main`;
  - CR-1 to CR-8 pass (cut 5: there is no per-run CR-9), with CR-4 being E3's lint and unit test, run by the executor on the PR branch;
  - AC-14: `check-pr-intro.sh` exits 0 on the PR body, and the accuracy verdict is `accurate`;
  - the run's brief and plan cite `docs/standards/wordpress.md` and `docs/standards/woocommerce.md` (a grep of `$WOO/.aew/runs/<S9>/` artefacts);
  - the post-session audit is clean, and denials are listed and classified inline (AC-27).

  Merging the S9 PR is not required: S9 is terminal in its own repo. James may merge it or leave it open, and his choice is recorded.
- **on failure:** E8.

### E7 — Record S9; stop wp-env

- **files:** `tests/e2e-validation.md` (`## S9` section, the S9 fixture under `## Sandbox fixtures`, ledger rows, roll-up row), on plugin repo branch `feature/e2e-validation`.
- **depends_on:** [E6].
- **pattern:** the per-scenario record form, as in Phase D's D5 (cut 4: intro verdicts and denials inline). It covers:
  - the E1 decision;
  - the E4 canary;
  - the E5 init checks;
  - the E6 expectation table;
  - the ledger rows (init attended, from `/cost` or the session's usage per V-8; ship headless, from the stream's `result`);
  - the duration, the problems and one sub-heading per attempt.
- **cleanup:** `npx wp-env stop` in `$WOO`. The repo and its clone stay, because sandbox repos are never deleted (CP-6). James may stop Docker Desktop afterwards.
- **verification:** every AC-25 bullet has a row with evidence, and the roll-up marks AC-25 `pass`.
- **commit:** `test(e2e): record S9 WooCommerce sandbox run` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.

### E8 — Fix loop (only if an E5 or E6 expectation fails)

- **files:** whatever the diagnosis names. Likely sites:
  - `scripts/detect-stack.sh` with `tests/scripts/detect-stack.bats`;
  - `skills/init/SKILL.md`, which is over 500 lines, so content moves to `skills/init/references/` first (AC-28);
  - `skills/stack-standards/`;
  - the agent prompts.
- **depends_on:** [E5] or [E6], whichever failed.
- **pattern:** AC-28, steps 1 to 7, as in Phase D's D6. A fixture issue (for example, an extension shape that the detection heuristic is not meant to catch) is fixed in `$WOO` and recorded, not in the plugin.
- **verification:** the re-run attempt passes, and the fix log row is filled in. `tests/run-script-tests.sh` and `claude plugin validate .` pass.
- **commit:** one conventional commit per fix, with the plain Claude trailer. A re-run beyond what remains under the stop asks James first (CP-1).

## Phase F — Retro triage and the 0.1.0 release

- **ACs:** 29, 30, 31, 32, 33, 34, 35 (plus CR-9, moved here by simplicity-challenge Cut 5).
- **Depends on:** B (init and S1 to S7, all merged), D (S8), E (S9 run or recorded as skipped). Every scenario section of `tests/e2e-validation.md` is written before F1 starts.
- **Depth:** full. **Risk:** release tag (F8). F1 and F2 also write to GitHub in the plugin repo (issue transfer, labels, comments): non-destructive, and nothing is ever deleted.
- **Where it runs:** the executor's **own** session in this repo, on `feature/e2e-validation`, under the **keychain** `gh` token. Never in a run session, never through `e2e-run.sh` or `e2e-session.sh`, never with the PAT. Phase F has no paid sessions.
- **Fixed names used below:** plugin repo `jamesborg2012/claude-agentic-engineer-workflow` (`$PLUGIN`), retro repo `jamesborg2012/aew-sandbox-retro` (`$RETRO`), scratch `$E2E` = `/Users/jamesborg/Documents/Development/aew-e2e` (never committed). The `$PLUGIN`/`$RETRO` names are shorthand in this plan; commands are run with the literal values.
- **Commit trailer:** every commit ends with exactly `Co-Authored-By: Claude <noreply@anthropic.com>`, no model name.
- **`git push` text:** dev-workflow's Bash guard (enabled for James at user scope) blocks any command whose text contains `git push`, so every push goes through a script file in `$E2E` run with `/bin/bash` (spec Key facts). aew's own guard is inert here (no `.aew/config.json` in this repo).

### F1 — List the retro items (CR-9) and transfer them to the plugin repo

- **id:** F1
- **files:** `tests/e2e-validation.md` (`## Retro triage`; and one line in `## Platform facts` for the transfer behaviour)
- **depends_on:** []
- **ACs:** AC-29 steps 1 to 4; CR-9 (Cut 5); V-10's `gh issue transfer` facts (Cut 6)
- **risk:** GitHub write in the plugin repo (label create, issue transfer). A transfer is a move, not a deletion.
- **pattern:** `scripts/gh-retro.sh` lines 52 and 65 to 69 (label colour `0E8A16`, description "Retro item filed by aew"; body footer `Filed by aew from <src> run <id>.`; comment `Seen again in <src> run <id>`). Record format: `tests/agent-smoke/README.md` §10 tables.

Steps:

1. **Keychain check.** Prove the session is not under the PAT:
   `[ -z "${GH_TOKEN:-}" ] && [ -z "${GH_CONFIG_DIR:-}" ] && echo keychain-env` prints `keychain-env`, and `gh auth status --hostname github.com` names `jamesborg2012` with the keyring as the source. Never pass `--show-token`.
2. **Visibility check (one command).** `gh repo view jamesborg2012/claude-agentic-engineer-workflow --json visibility --jq .visibility` prints `PRIVATE` (verified on 2026-10-26; the retro repo is private by AC-6, so a private-to-private transfer applies). **STOP for James** only if it prints anything else; do not pre-design a fallback.
3. **List every item (CR-9).** `gh issue list --repo jamesborg2012/aew-sandbox-retro --state all --limit 200 --json number,title,state,labels,body,comments > $E2E/retro-before.json` (all states and no label filter, because `gh-retro.sh` may file without the label when it can't create it). From the body footer and the `Seen again` comments, build the table in `## Retro triage` → `### Items filed by the runs`: `| Sandbox # | Title | State | Filed by run | Seen again in runs |`. If the list is empty, write "No retro items were filed by any run" and skip to step 7.
4. **Ensure the label.** `gh label list --repo jamesborg2012/claude-agentic-engineer-workflow --search retro --json name`; if no `retro`, `gh label create retro --repo jamesborg2012/claude-agentic-engineer-workflow --color 0E8A16 --description "Retro item filed by aew"`.
5. **Transfer each open item, one at a time.** `gh issue transfer <n> jamesborg2012/claude-agentic-engineer-workflow` (prints the new URL). Closed sandbox items are listed in step 3 but not transferred.
   - After the **first** transfer, check what moved: `gh issue view <new> --repo jamesborg2012/claude-agentic-engineer-workflow --json labels,milestone,comments,state` against the sandbox's `retro-before.json` entry. Record in `## Platform facts` (V-10, Cut 6): the command, whether the label, comments and milestone survived, and the date.
   - If the label was dropped: `gh issue edit <new> --repo jamesborg2012/claude-agentic-engineer-workflow --add-label retro` (AC-29 step 4), on every transferred item.
6. **Mapping.** Add `### Transfer` to `## Retro triage`: `| Sandbox # | Plugin # | Label kept on transfer | Label re-added |`.
7. **Commit** `tests/e2e-validation.md`.

Verification:

- `gh issue list --repo jamesborg2012/aew-sandbox-retro --state open --json number --jq length` prints `0`.
- `gh issue list --repo jamesborg2012/claude-agentic-engineer-workflow --label retro --state open --json number --jq length` equals the transferred count (none were open on 2026-10-26).
- Every row of `### Transfer` has a plugin number that `gh issue view` resolves.

**Commit:** `docs(e2e): list the runs' retro items and their transfer to the plugin repo`

### F2 — Triage the retro items and fix the small ones

- **id:** F2
- **files:** `tests/e2e-validation.md` (`## Retro triage` → `### Triage`, and `## Fix log`); per small fix, the plugin files that fix needs (named per item at triage time) plus its test (`tests/scripts/*.bats` or a fixture under `tests/scripts/fixtures/`); `CHANGELOG.md` (`### Fixed` under `[Unreleased]`, one line per fix)
- **depends_on:** [F1]
- **ACs:** AC-29 (triage, small fixes, comments)
- **risk:** none beyond the fixes themselves. A fix that turns out to need a design decision is not small (below).
- **pattern:** AC-28's fix loop (spec): failing bats first for a scriptable defect; an agent or skill defect fixed by improving the prompt; `skills.bats` and `conventions.bats` as the static checks for skill text. Bats style: the nearest existing file (for example `tests/scripts/gh-retro.bats`, `tests/scripts/fixtures/hooks/bash-cases.tsv` for a guard case). CHANGELOG line style: the existing `### Fixed` bullets ("…(found by <run>)").

Steps:

1. **Classify** every open `retro` issue in the plugin repo (`gh issue list --repo jamesborg2012/claude-agentic-engineer-workflow --label retro --state open --json number,title,body,comments`). Write `### Triage`: `| Plugin # | Title | Seen in runs | Class | Decision |`.
   - **Small:** a one-commit fix that needs no design decision.
   - **Not small:** anything else, including a fix that would change designed behaviour, needs a new option, or touches init's `SKILL.md` while it is still over 500 lines and the move to `references/` would itself be the bigger change.
2. **Not small:** comment on the issue (`gh issue comment <n> --repo jamesborg2012/claude-agentic-engineer-workflow --body-file $E2E/retro-<n>.md`) with "Triage (build prompt 07): left open. Why: … What it would take: …". Leave it open. Decision column: `open: <one-line reason>`.
3. **Small, one commit each:**
   - Scriptable: write the failing bats test, run it, keep the red output; fix; run it green.
   - Agent or skill text: improve the prompt; run `bats tests/scripts/skills.bats tests/scripts/conventions.bats`.
   - An init fix first brings `skills/init/SKILL.md` under 500 lines by moving content to `skills/init/references/` (AC-28), unless Phase B already did.
   - Add the `### Fixed` line under `[Unreleased]` in `CHANGELOG.md`, ending "(retro #<n>)".
   - Run `tests/run-script-tests.sh` and `claude plugin validate .`.
   - Commit with `Refs #<plugin n>` in the body. Decision column: `fixed: <short sha>`. Add a `## Fix log` row (commit, problem, "retro #<n>", re-run: "none: tests only", result).
   - **No paid re-run** for a retro fix (spend). The installed copy is not refreshed for it.
   - **STOP for James (CP-6)** if a fix not covered by DESIGN is expensive to reverse. Otherwise, if the fix grows past one commit or needs a design call, reclassify it as not small (step 2) instead.
4. Closing happens through the PR: F7 adds `Closes #<n>` for each fixed item and a comment naming the commit; F8 checks they closed on merge. (Closing on merge keeps an issue open until its fix is on `main`.) This departs from AC-29's wording ("closed with a comment naming the commit" at fix time) with the same end state by F8; record it as one line under `## Retro triage` and in the final summary's DESIGN-conflicts/deviations list.
5. **Commit** the triage table (after the fix commits, so the Decision column holds their SHAs).

Verification:

- For each scriptable fix: the captured red (failing assertion) and then green, in the task report.
- `tests/run-script-tests.sh` exits 0 with `0 failures` and shellcheck clean; `claude plugin validate .` passes.
- `gh issue list --repo jamesborg2012/claude-agentic-engineer-workflow --label retro --state open --json number,comments` shows every not-small item with the triage comment.
- `### Triage` has one row per open `retro` issue, none without a Decision.

**Commits:** one per fix, `fix(<scope>): <what was wrong>` with `Refs #<n>`; then `docs(e2e): triage the retro items`.

### F3 — Finalise the README

- **id:** F3
- **files:** `README.md`; `tests/e2e-validation.md` (`## Platform facts`, the V-12 uninstall output from step 9)
- **depends_on:** [F2]
- **ACs:** AC-30 (and re-checks AC-5's Install section written in Phase A)
- **risk:** none. Net-new text over 50 lines is justified: AC-30 fills sections that are "to be written" today.
- **pattern:** the README's own `## Commands` and `### /aew:*` sections (tone and table style); DESIGN §6 and §6.1 (files and config), §7.4 (labels); `templates/config.schema.json` (defaults); the sandbox's merged init PR (`git -C /Users/jamesborg/Documents/Development/aew-sandbox show <init merge sha> --stat` and its `.gitignore`, `.claude/settings.json`, `CLAUDE.md` section) as the ground truth for "files the plugin creates"; `tests/e2e-validation.md` (`## Platform facts`, `## Fix log`, the per-scenario problems) as the source for troubleshooting.

Sections, in this order:

1. **Purpose.** Keep the opening paragraph. Remove the "**Status: in development.**" line; link the record instead ("Validated end to end on real GitHub; see `tests/e2e-validation.md`").
2. **Install** (and the existing `## Dependencies` section, kept as is unless a fix changed it). Confirm Phase A's section still matches the commands that worked (AC-2, `--scope user`), the isolated dependency check (AC-3) and the refresh method (V-3). Edit only if a later fix changed them.
3. **Prerequisites.** Add what the runs showed is needed: the Claude Code version tested (from `## Environment`), gh authenticated with the scopes the scripts used, jq, Node 20 or later, and the `retro.repo` the token must reach.
4. **Commands.** Re-check each `### /aew:*` block against what the runs did (flags, gate behaviour, `--sequential`/`--bulk`, resume). Edit only what is wrong.
5. **Config reference.** Replace "_Field reference to be written._" with one table, one row per schema field: `| Field | Type | Default | Meaning |`, dotted paths (`ui.axe_standard`, `limits.max_fix_cycles`, `retro.label`). Defaults come from the schema, not from DESIGN.
6. **Labels.** Replace "_To be written._" with the nine stage labels and the two flags from DESIGN §7.4, each with what it means and who sets it, and a line on the `retro` label in `retro.repo`.
7. **Files aew creates in a project** (new `##` section after Labels): the DESIGN §6 tree; `.aew/runs/<run-id>/` and `.aew/runs/current` (gitignored); init's `.gitignore` lines, `CLAUDE.md` section, `docs/standards/`, `.claude/settings.json` (portable rules) and `.claude/settings.local.json` (plugin-script rules naming the install path, gitignored); the QA evidence and e2e directories. Exact lines are taken from the sandbox, not invented.
8. **Troubleshooting.** Keep the dependency entry. Add one entry per problem actually hit that a user could hit too (from the fix log and scenario sections), for example: a stale install after an update (V-3 refresh); `main` behind origin stops preflight (`git pull --ff-only`); a gate left pending under `--auto` headless (resume attended); stacked PRs and `Closes #n` (merge with a merge commit, check the base); other user plugins' guards (dev-workflow) intercepting a session; a retro label dropped. Only problems recorded in `tests/e2e-validation.md`.
9. **Uninstall.** Replace "_To be written._" with the V-12 commands (expected shape `claude plugin uninstall aew@jamesborg-plugins --scope user`, then `claude plugin marketplace remove jamesborg-plugins`), whether the cache is cleaned, and what stays in a project (config, labels, settings entries naming the old install path) for the user to remove by hand if wanted. **Prove them** by running both in the AC-3 isolated config (`CLAUDE_CONFIG_DIR=<that scratch dir> claude plugin uninstall …`, then `… marketplace remove …`, then `claude plugin list --json`), never against James's real config; record the output in `## Platform facts`.

Verification:

- `grep -nE 'to be written|in development' README.md` prints nothing.
- Config rows cover the schema (run with `/bin/bash`; expected no output):
  `jq -r 'paths(type == "object" and has("properties")) as $p | getpath($p).properties | keys[] as $k | ($p | map(select(. != "properties" and . != "items" and (type == "string"))) + [$k]) | join(".")' templates/config.schema.json | sort -u | while read -r f; do grep -qF "\`$f\`" README.md || echo "missing: $f"; done`
  (container paths such as `ui` may be listed as their own row or covered by their children; adjust the filter once, and record the command used.)
- All eleven DESIGN §7.4 labels are present: `for l in analysing awaiting-input planning awaiting-approval building testing documenting ready-for-review blocked spec-revised manual-test-required; do grep -qF "aew:$l" README.md || echo "missing $l"; done` prints nothing.
- **Command audit:** list every command in a fenced block (`grep -n '^claude \|^gh \|^git \|^/aew:' README.md`) and tick each against `tests/e2e-validation.md` (run in a session, or the documented form of one that was). Any that wasn't run is removed or run. The audit list goes in the task report, not the README.

**Commit:** `docs(readme): finalise the README for 0.1.0 from the validation runs`

### F4 — CHANGELOG `[0.1.0]`

- **id:** F4
- **files:** `CHANGELOG.md`; `skills/github-ops/SKILL.md` (only if step 4 finds the AC-20 line still there)
- **depends_on:** [F2]
- **ACs:** AC-31 (and re-checks AC-20's removal)
- **risk:** none
- **pattern:** the existing `CHANGELOG.md` (Keep a Changelog 1.1.0, `### Added|Changed|Fixed` order and bullet style). No link references are added; the file has none.

Steps:

1. `## [Unreleased]` becomes `## [0.1.0] - <YYYY-MM-DD>`, the date F7 opens the PR (write today's date; F7 step 1 corrects it if the PR opens on a later day). Add a new, empty `## [Unreleased]` above it.
2. Under `[0.1.0]` → `### Fixed`: one line per commit in `tests/e2e-validation.md` `## Fix log` (Phase B to E fixes and F2's retro fixes), each ending with the scenario or retro number that found it. Lines already added with their fixes are kept, not duplicated.
3. Under `### Added`: the validation record (`tests/e2e-validation.md`) and the README's config, labels, files and uninstall sections. Under `### Changed`: DESIGN §3/§12 re-verification (F5) and any DESIGN "Recorded deviations (prompt 07)".
4. **AC-20 check.** If S3 and S4 passed (record), `grep -n 'no rewrite of a real issue body' CHANGELOG.md skills/github-ops/SKILL.md` must print nothing. If Phase B left either line, remove it here and say so in the task report.
5. `plugin.json` is not touched (Assumption 10).

Verification:

- `grep -nE '^## \[' CHANGELOG.md` prints exactly `## [Unreleased]` then `## [0.1.0] - <date>`.
- `awk '/^## \[Unreleased\]/{u=1;next} /^## \[/{u=0} u && NF' CHANGELOG.md` prints nothing (empty `[Unreleased]`).
- Every `## Fix log` commit subject has a `### Fixed` line (checked by eye against `git log --oneline main..HEAD -- . ':!tests/e2e-validation.md'`).
- `jq -r .version .claude-plugin/plugin.json` prints `0.1.0`; `git diff main -- .claude-plugin/` is empty.

**Commit:** `docs(changelog): release 0.1.0`

### F5 — DESIGN, CLAUDE.md and project map

- **id:** F5
- **files:** `docs/DESIGN.md` (§3, §12), `CLAUDE.md`, `docs/superpowers/project-map.md`
- **depends_on:** [F2]
- **ACs:** AC-33
- **risk:** none
- **pattern:** DESIGN §3's opening "Checked against code.claude.com/docs on …" line and its fact bullets (each with the doc URL); DESIGN §9 and §10 "Recorded deviations" style for any missing prompt-07 entry; `CLAUDE.md` `## Recent changes` line format (`- <date> · <branch> · <summary> · [spec](…) · [plan](…)`); project map `### Per-feature learnings` and `### Gotchas` bullet style (append, one line each).

Steps:

1. **DESIGN §3.** Extend the opening line with "and V-1 to V-13 again on <date> (build prompt 07)". For each re-verified fact in `tests/e2e-validation.md` `## Platform facts`, update the matching §3 bullet (or add one where §3 has none: local-marketplace install and scope, dependency auto-install, `installPath` and refresh, the `<plugin>--v<version>` tag form, `--bare`, plugin MCP status, SessionStart output in a stream, interactive budget, SIGINT in `-p`, settings-local plugin disable). Facts that contradict DESIGN were already changed by Phase A in the commit that needed them; do not re-edit those beyond the date.
2. **DESIGN §12.** "The sandbox scenarios in build prompt 07 pass." becomes "pass: S1 to S8 on <date>, S9 <passed | skipped: reason> (`tests/e2e-validation.md`)."
3. **DESIGN deviations.** Check that every fix-log entry that changed designed behaviour has its "Recorded deviations (prompt 07)" entry in the relevant section; add any missing one.
4. **CLAUDE.md.**
   - Append to `## Recent changes`: `- <date> · feature/e2e-validation · End-to-end validation on real GitHub and the 0.1.0 release (build prompt 07): real install, sandbox scenarios S1 to S8 (S9 <passed|skipped>), <n> fixes, retro triage, finalised README, tag aew--v0.1.0 · [spec](docs/superpowers/specs/2026-10-26-e2e-validation.md) · [plan](docs/superpowers/plans/2026-10-26-e2e-validation.md) · [record](tests/e2e-validation.md)`. If curation needs it, the oldest line may be trimmed per the repo's convention; otherwise append only.
   - "It is in development and is being built in stages from the prompts …" becomes past tense with 0.1.0 released (one sentence). Beyond AC-33's list: the sentence is false once 0.1.0 is tagged, and this file is already being edited; no other `CLAUDE.md` text changes.
5. **Project map.**
   - Correct "init's SKILL.md is at 498 of 500 lines" in the C2/C3/C4 bullet to the count from `wc -l skills/init/SKILL.md` on the release date, with the date.
   - Append one `### Per-feature learnings` line: "2026-10-<dd> e2e validation built (prompt 07): …" (what was proven, the fix count, where the record is).
   - Append one `### Gotchas` line per platform gotcha actually found (for example: `gh issue transfer` label behaviour from F1; the `git push` text guard and script files; the PAT launcher rails; the refresh method for a local-marketplace install). Only ones in the record.

Verification:

- `grep -n 'build prompt 07' docs/DESIGN.md` shows the §3 line and the §12 line.
- `grep -n '498 of 500' docs/superpowers/project-map.md` prints nothing; the new count equals `wc -l < skills/init/SKILL.md`.
- `grep -c 'feature/e2e-validation' CLAUDE.md` prints `1`; both linked files exist (`test -f` each path).
- British English: `grep -nE '\b(behavior|color(ed)?|initialize|recognize|artifact)\b' docs/DESIGN.md CLAUDE.md docs/superpowers/project-map.md README.md CHANGELOG.md` shows only quoted code, flags or command text (for example `--color`).

**Commit:** `docs: record prompt-07 platform facts, the quality bar, recent changes and project-map learnings`

### F6 — Verification before completion and the record's roll-up

- **id:** F6
- **files:** `tests/e2e-validation.md` (`## Roll-up`, any gap found)
- **depends_on:** [F3, F4, F5]
- **ACs:** AC-34 (verification part); completes AC-26's record (Cut 4 roll-up)
- **risk:** none
- **pattern:** `superpowers:verification-before-completion` (invoke it; evidence before claims); the commands in this repo's `CLAUDE.md` `## Commands`; the roll-up format of `tests/agent-smoke/README.md` §10.6.

Steps:

1. **Roll-up.** Complete `## Roll-up` with the build-prompt ACs (S1 to S8 pass; S9 passed or skipped with its reason; no unresolved guard false positive; the record complete and the README accurate; the final summary's contents) and the scenario expectations, each `pass`, `fail` or `skipped` with its evidence link (Cut 4: not all 35 spec ACs).
2. **Re-read** `tests/e2e-validation.md` against every spec AC (1 to 35, with Cut 2 to Cut 6 applied). The AC-by-AC checklist goes into the task report and the final summary, not the record. Any gap is fixed in the record, or, if it is a real failure, stops here and goes back to the fix loop.
3. **Run** each check fresh and read its output before claiming anything:

| Command | Expected |
|---|---|
| `tests/run-script-tests.sh` | exit 0; bats `N tests, 0 failures`; shellcheck reports nothing |
| `claude plugin validate .` | passes, exit 0 (any warning is recorded and explained) |
| `npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s templates/config.schema.json -d templates/config.example.json` | `templates/config.example.json valid` |
| same with `-s templates/state.schema.json -d templates/state.example.json` | `templates/state.example.json valid` |
| same config check with `-d /Users/jamesborg/Documents/Development/aew-sandbox/.aew/config.json` | `… valid` (the real init output still fits the schema after the fixes) |
| `git diff main...HEAD \| grep -cE 'github_pat_[A-Za-z0-9_]{20,}\|gh[opsu]_[A-Za-z0-9]{30,}'` | `0` (no token committed) |
| `git diff --name-only main...HEAD` | no launcher, stream, transcript, ledger or token file; only plugin files, docs and `tests/e2e-validation.md` |
| `git log --format='%h%x09%(trailers:key=Co-Authored-By,valueonly,separator=;)' main..HEAD \| awk -F'\t' '$2 != "Claude <noreply@anthropic.com>"'` | nothing (every commit has exactly the plain trailer; a commit with none, or with a model name, is listed) |
| `git status --porcelain` | empty after the commit |

4. **Commit** the roll-up.

**STOP condition:** any red check is a real failure. Fix it through the AC-28 loop (or F2 for a retro fix) and re-run this task; never edit an expectation to make it pass.

**Commit:** `docs(e2e): complete the validation record's roll-up`

### F7 — Push the branch and open the plugin PR (then STOP for James's merge, CP-7)

- **id:** F7
- **files:** none in the repo. `$E2E/push-plugin-branch.sh` and `$E2E/plugin-pr-body.md` (scratch, never committed).
- **depends_on:** [F6]
- **ACs:** AC-34 (executor opens the PR itself); AC-29 (fixed items close on merge)
- **risk:** GitHub write (branch push, PR) under the keychain token.
- **pattern:** PR #6 (`gh pr view 6 --repo jamesborg2012/claude-agentic-engineer-workflow --json title,body`): title form `feat: … (build prompt NN)` and body structure. James's standing preference: open the PR with `gh pr create`, never just give a link.

Steps:

1. **Base check.** `git fetch origin main` then `git merge-base --is-ancestor origin/main HEAD && echo based-on-main`. **STOP for James** if it doesn't print `based-on-main`: `main` moved, and the executor never rebases or merges onto the base.
   - **Tag form (V-4).** The V-4 entry in `tests/e2e-validation.md` `## Platform facts` (doc URL and date, recorded in Phase A) confirms the `<plugin>--v<version>` form, so the tag is `aew--v0.1.0`. **STOP for James** if V-4 is missing or records a different form; the tag name is never asserted from DESIGN or memory alone.
   - **CHANGELOG date.** `grep -c "^## \[0.1.0\] - $(date +%F)$" CHANGELOG.md` prints `1`; if not, correct the date in a `docs(changelog): date 0.1.0` commit (plain trailer) before pushing.
2. **Push** through a script file (dev-workflow's guard matches the text `git push`). `$E2E/push-plugin-branch.sh`:

   ```bash
   #!/bin/bash
   set -euo pipefail
   cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
   git push -u origin feature/e2e-validation
   ```

   Run `/bin/bash /Users/jamesborg/Documents/Development/aew-e2e/push-plugin-branch.sh`. Under the keychain credential, in the executor's own environment (F1 step 1 still holds).
3. **PR body** (`$E2E/plugin-pr-body.md`), mirroring PR #6: `## In plain English` (what was validated, what broke and was fixed, that merging releases 0.1.0); summary; the fixes (from `## Fix log`); retro triage (fixed and left-open counts, with numbers); verification (F6's commands and results); "After merge: the executor tags `aew--v0.1.0` on the merge commit"; one `Closes #<n>` line per retro item fixed in F2; the standard Claude Code attribution line at the end. British English, no secrets.
4. `gh pr create --repo jamesborg2012/claude-agentic-engineer-workflow --base main --head feature/e2e-validation --title "feat: end-to-end validation on real GitHub and the 0.1.0 release (build prompt 07)" --body-file /Users/jamesborg/Documents/Development/aew-e2e/plugin-pr-body.md`.
5. On each retro item fixed in F2: `gh issue comment <n> --repo jamesborg2012/claude-agentic-engineer-workflow --body "Fixed in <sha> (<subject>) on feature/e2e-validation, PR #<pr>. Closes when the PR merges."`
6. Record the branch's commit list now (`git log --oneline main..feature/e2e-validation`): if James squashes, these SHAs are not on `main`, and the final summary needs them.

Verification:

- `git ls-remote origin refs/heads/feature/e2e-validation` equals `git rev-parse HEAD`.
- `gh pr view <pr> --json state,baseRefName,headRefName,closingIssuesReferences` shows `OPEN`, `main`, `feature/e2e-validation`, and every F2-fixed retro issue under `closingIssuesReferences`.

**STOP for James (CP-7):** give him the PR link and ask him to merge it (method his choice; he has squashed these branches before). The executor never calls `gh pr merge`. Wait for his confirmation before F8.

### F8 — Tag `aew--v0.1.0` after the merge, then the final summary

- **id:** F8
- **files:** none in the repo. `$E2E/push-release-tag.sh` (scratch).
- **depends_on:** [F7] and James's merge (CP-7)
- **ACs:** AC-32, AC-35; AC-29 (fixed items closed)
- **risk:** **release tag.** A pushed tag is never moved or deleted by the executor; any problem with it stops for James (CP-6: deleting a GitHub resource).
- **pattern:** DESIGN §3 "Dependencies" (`<plugin>--v<version>` form), as confirmed by the V-4 record that F7 step 1 checked; the name is not asserted from DESIGN alone.

Steps:

1. **Merged?** `gh pr view <pr> --repo jamesborg2012/claude-agentic-engineer-workflow --json state,mergeCommit --jq '.state + " " + .mergeCommit.oid'` prints `MERGED <sha>`. Otherwise stop and tell James.
2. `git checkout main` then `git pull --ff-only`; `git merge-base --is-ancestor <sha> HEAD && echo merged-in`.
3. **Content at `<sha>`.** `git show <sha>:.claude-plugin/plugin.json | jq -r .version` prints `0.1.0`; `git show <sha>:CHANGELOG.md | grep -c '^## \[0.1.0\] - '` prints `1`.
4. **No tag yet.** `git tag -l 'aew--v*'` and `git ls-remote --tags origin 'aew--v*'` both print nothing. **STOP for James** if either shows a tag: never move, overwrite or delete one.
5. **Tag the merge commit** (not `HEAD`, in case `main` moved after the merge): `git tag -a aew--v0.1.0 <sha> -m "aew 0.1.0: first release, validated end to end on real GitHub (build prompt 07)"`.
6. **Push** through `$E2E/push-release-tag.sh`, run with `/bin/bash`:

   ```bash
   #!/bin/bash
   set -euo pipefail
   cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
   git push origin refs/tags/aew--v0.1.0
   ```

   No GitHub release object (out of scope).
7. **Retro items closed.** Each F2-fixed item: `gh issue view <n> --repo jamesborg2012/claude-agentic-engineer-workflow --json state --jq .state` prints `CLOSED`. If one didn't close on merge, close it with `gh issue close <n> --repo jamesborg2012/claude-agentic-engineer-workflow --comment "Fixed in <sha on main>, released in aew--v0.1.0."`.
8. **Final summary to James** (chat, not a file), AC-35:
   - **Fixed during validation:** every fix commit (branch SHAs from F7 step 6 and, if squashed, the `main` SHA), with the scenario or retro item that found it.
   - **Known limitations:** from `skills/github-ops/SKILL.md` `## Known limitations` after AC-20, the guard as a heuristic (DESIGN §11), the C3 broad-harness-lines decision, prompt 06's sequential-child gap (unless S6 hit and fixed it), no LICENSE or icon, the dev-workflow interplay (Assumption 6), S9 if skipped.
   - **Open retro items:** `gh issue list --repo jamesborg2012/claude-agentic-engineer-workflow --label retro --state open --json number,title`, each with its triage reason.
   - **DESIGN conflicts found** (the spec found none that change behaviour; list any the runs found, and the C3/retro-transfer note).
   - **Scenarios:** S1 to S8 passed (with attempt counts); S9 passed or skipped with its reason.
   - **Spend:** the ledger total against the $200 stop, and the reserve used.
   - **Release:** tag `aew--v0.1.0` on `<sha>`, and the `gh issue transfer` behaviour found in F1.
   - The F6 AC-by-AC checklist (AC-1 to AC-35).

Verification:

- `git cat-file -t aew--v0.1.0` prints `tag` (annotated); `git rev-parse 'aew--v0.1.0^{commit}'` equals `<sha>`.
- `git ls-remote --tags origin 'aew--v0.1.0*'` prints two lines: the tag object and `refs/tags/aew--v0.1.0^{}` at `<sha>`.
- `gh issue list --repo jamesborg2012/claude-agentic-engineer-workflow --label retro --state open` matches the summary's open list.

**Commit:** none (the tag is the release; nothing is committed after the merge, so `main` and the tag agree).

### Phase F task graph

```
F1 → F2 → F3 ┐
         F4 ├→ F6 → F7 →(STOP: James merges, CP-7)→ F8
         F5 ┘
```

F3, F4 and F5 touch different files and may run in either order; the executor is one session, so they run in sequence.

### STOP-for-James points in Phase F

| Where | Trigger | What James decides |
|---|---|---|
| F1 step 2 | the plugin repo is no longer private (it was on 2026-10-26) | how the retro items reach the plugin repo |
| F2 step 3 | a retro fix outside DESIGN that is expensive to reverse (CP-6) | go ahead, or leave it open |
| F7 step 1 | `origin/main` is not an ancestor of the branch | how to bring the branch up to date (the executor never rebases or merges) |
| F7 step 1 | V-4 is missing or records a tag form other than `<plugin>--v<version>` | the release tag name |
| F7 end | always (CP-7) | merges the plugin PR, method his choice |
| F8 step 4 | an `aew--v*` tag already exists locally or on origin | what to do with it (the executor never moves or deletes a tag) |


## Simplicity-challenge

The spec (`docs/superpowers/specs/2026-10-26-e2e-validation.md`) is approved and unchanged; these
decisions override it where they differ and every phase plan must follow them.

Adopted:
- **Cut 2 — S6 headless, `--sequential --auto`.** The prompt asks only for correct order and stacked
  PRs; S1 proves the plan gate live. The AC-22 stacked-merge protocol (CP-3 base check, merge commits
  for children 1 and 2, issues closed + main holds all three) is unchanged. Fallback as S4: a child
  that hits a material spec gate is resumed attended. Attended sessions become init, S1, S3, S5.
- **Cut 3 — phases B and C merged** into one serial phase B: "init and serial scenarios S1–S7".
- **Cut 4 — record trimmed.** Introduction verdicts (AC-14) and guard/permission denials (CR-6/CR-7)
  go inline in each scenario's expectation table; one short top-level list of guard false positives
  only (AC-27). The roll-up covers the build-prompt ACs and scenario expectations, not all 35 spec
  ACs. AC-10: record the changed env lines plus the C3 broad-lines decision, not a launcher diff.
- **Cut 5 — CR-9 moved to Phase F.** Retro items are listed once (with any "Seen again" notes)
  during the AC-29 transfer and triage, not per run. Common checks drop to CR-1..CR-8.
- **Cut 6 — gh facts proved by running them.** V-10 (token/credential precedence) and V-11
  (milestones) are proved by the AC-9 canary and fixture creation, with command + output recorded.
  V-10's `gh issue transfer` behaviour is checked when it runs in Phase F (AC-29 step 4 already
  handles a dropped label). The Claude Code facts (V-1..V-6, V-8, V-9, V-12, V-13) stay in ONE
  batched claude-code-guide dispatch — the build prompt requires every Claude Code feature relied on
  to be verified against the docs; V-13's runtime proof (the AC-4 probe's `system/init`) is recorded
  as well.
- **Cut 1, partly — no separate SessionStart "hint probe".** The headless `/aew:status` session's
  stream carries the SessionStart hook output; record it from there.

Declined:
- **Cut 1 (fold S7 into S1) — declined.** The build prompt lists S7 as its own scenario ("an
  S1-style run"), and S1's expectations plus its PR-introduction accuracy check need an
  uninterrupted baseline; folding them means a resume defect fails both and confounds the
  diagnosis. S7 stays a separate headless run with a launcher SIGINT at `develop` (Assumption 8, V-9
  kept).

Resulting phase graph: A (full, credentials/infra) → B (full: init, fixtures, S1–S7 serial) ;
D (lean: S8, needs only B's init merge) ; E (lean: S9 optional, needs A) ; F (full: retro + release,
needs B, D, E). Phase C no longer exists. S9 at CP-5: offer "skip" as the default while the Docker
daemon is down; James decides.

## Review notes carried into execution

Per-phase plan-review verdicts: A APPROVED WITH NOTES, B APPROVED WITH NOTES, D APPROVED WITH NOTES,
E APPROVED WITH NOTES, F APPROVED WITH NOTES. Mechanical fixes were applied in place. Non-mechanical
notes that the executor applies:

- **A5/A6, row 9 (MINOR 1, 2).** Fold the row-9 (a)/(b) choice into A5's single stop, conditional on
  the A6 result. Describe (b) accurately: sandbox-side `gh` work can run through
  `e2e-run.sh --env-check` with the PAT, so only Phase F's transfer and release need James to log back
  in; the git channel (`env -u GH_TOKEN git …` through the gh credential helper) is just as reachable.
- **Attended audit (MINOR 3).** After every `--attended` session, run the same post-session audit
  over the newest transcript `.jsonl` and any subagent transcripts that P2 already locates.
- **A6 pre-check (MINOR 4).** Record `jq '.permissions.allow' ~/.claude/settings*.json`, since
  user-scope rules apply to the sessions.
- **A4 self-test (NIT).** Grep for `unset ` with any quoting, not the literal `"unset "`.
- **A4 audit pattern set.** The Write/Edit/MultiEdit/NotebookEdit content scan uses
  `GH_TOKEN|GITHUB_TOKEN|GH_HOST|GH_CONFIG_DIR|GH_ENTERPRISE|auth token|git-credential|osxkeychain|security find-|REALGH`
  (`credential` and `github.com` deliberately excluded); confirmed at the CTO pass.
- **D4 / V-5 (MINOR).** If V-5 selects `--bare`, the same claude-code-guide dispatch checks whether
  `--bare` skips `CLAUDE.md` auto-discovery; record whether the sandbox `CLAUDE.md` was in context, and
  treat a gap caused only by that as a test-setup artefact, not a `prompt.md` defect.
- **Record edits (MINOR).** B, D5, E2 and E7 all edit `tests/e2e-validation.md`: serially, in the
  main checkout, ledger rows in time order.
- **E3 (MINOR).** Plain PHPUnit with no WordPress test-library bootstrap for the pure function.
- **D1/D2 (NIT).** Do not change `e2e-run.sh` (D2) while D1's session is running.
- **D4 (NIT).** Pass `prompt.md` on stdin if the launcher supports it; otherwise as an argument.
- **F2 (NIT).** An init fix classed "small" always moves content to `references/` first (step 3).

## CTO conditions (risk-gate, 2026-10-26)

Row-9 ruling: option (a) — detect-only — is accepted **as an amendment to C3, not compliance**, and
only with C-1 to C-3. James approves it at A5 (he may still choose (b), `gh auth logout`; then E3's
repo creation needs a temporary login or James creates that repo himself). The record calls it
"C3 amended (detect-only for the keychain channel)".

- **C-1 (A6 pre-check, B1 step 5, P1, P2).** Before every headless session, a free `jq` check of the
  effective allow rules — user scope, `$SB/.claude/settings.json`, `$SB/.claude/settings.local.json`
  and the allow file — must find no `gh` rule except exactly `Bash(gh auth status)`, no `git push`
  rule, and no interpreter or wildcard rule (`node`, `sh`, `bash`, `zsh`, `env`, `python*`, `npx *`,
  `curl *`, bare `Bash`, `Bash(*)`). An "always allow" clicked in an attended session that adds such
  a rule is reverted before the next headless session and recorded under CR-7. The A-phase rule
  "widen after a recorded denial, record as detect-only" becomes a **STOP for James**: any broader
  line re-opens the approved deviation.
- **C-2 (A4 audit pattern set).** One set, applied to Bash command text and to
  Write/Edit/MultiEdit/NotebookEdit input on every thread:
  `GH_TOKEN|GITHUB_TOKEN|GH_HOST|GH_CONFIG_DIR|GH_ENTERPRISE|auth token|git-credential|osxkeychain|security find-|REALGH|GIT_CONFIG|GIT_ASKPASS|credential fill|credential\.helper|find-(generic|internet)-password|\.config/gh|env -i`
  plus the spawn pattern
  ``(exec|spawn|popen|passthru|proc_open|system)[A-Za-z_]*\s*\(\s*\[?\s*['"`](gh|git|security|env)\b``.
  `credential` and `github\.com` are excluded for file contents only; the command audit keeps them.
  A4 self-tests: a Write of `execSync('gh api user', {env:{}})` and the command
  `env -i PATH=/usr/bin gh api user` must hit; a Write containing `credentials: 'same-origin'` plus
  `fetch('/api/contact')` must not. Grep `unset ` with any quoting. The same audit runs over attended
  transcripts (review note MINOR 3).
- **C-3 (A6 canary, A9).** Add row 9b,
  `env -u GH_TOKEN git ls-remote https://github.com/jamesborg2012/claude-agentic-engineer-workflow.git`.
  Rows 9 and 9b assert the decided result ("exit 0, accepted deviation") so any later change shows on
  a canary re-run.
- **C-4 (A9 `## Rails and launchers`, fix-loop note).** An audit hit on a credential pattern (exit 4)
  is a P0 STOP for James: (1) no further sessions; (2) James revokes the PAT; (3) if the hit could
  have reached the keychain token, James revokes the GitHub CLI OAuth grant (github.com → Settings →
  Applications) and logs in again; (4) James checks the GitHub security log; (5) the executor lists
  every `gh`/`git` remote call from the stream. The executor never revokes anything.
- **C-5 (F1 step 0, CP-7 ask).** After the last paid session the executor runs `rm -P "$E2E/.pat"`.
  The CP-7 merge request also asks James to delete the PAT on GitHub (his deletion; no extra stop).
- **C-6 (F8).** Tag rollback: blast radius is near zero (the marketplace installs from source `./`;
  nothing depends on aew). If the tag is wrong the executor stops; James runs
  `git push origin :refs/tags/aew--v0.1.0` and `git tag -d aew--v0.1.0`, then F8 re-runs from step 4.
  The executor never moves or deletes a tag.
- **C-7 (F1, before step 5).** Grep `retro-before.json` for token shapes
  (`github_pat_|gh[opsu]_[A-Za-z0-9]{30,}`); any hit is a STOP. Rollback for a wrong transfer:
  `gh issue transfer <new> jamesborg2012/aew-sandbox-retro` (a move, not a deletion), recorded.
- **C-8 (A2 record, A9).** Name A's real blast radius: with aew enabled at user scope, its Playwright
  MCP server and SessionStart hook load in every one of James's sessions during the validation.
  Rollback in seconds: `claude plugin disable aew@jamesborg-plugins` (uninstall per V-12 if needed).
  The private sandbox repos carry no blast radius.
- **C-9 (F8 final summary).** Under known limitations, list the F2 retro fixes that ship in 0.1.0
  verified only by bats and static checks, never re-run live.

---

## Approval

- Senior architect: APPROVED on 2026-10-26 — per phase: A APPROVED WITH NOTES, B APPROVED WITH NOTES, D APPROVED WITH NOTES, E APPROVED WITH NOTES, F APPROVED WITH NOTES (plan-review; mechanical fixes applied in place)
- Plan format: FULL (A, B, F) · LEAN (D, E)
- Simplicity-challenge: SIMPLER-PATH — cuts 2–6 adopted, cut 1 declined (see `## Simplicity-challenge`)
- CTO: APPROVED WITH CONDITIONS on 2026-10-26T15:32:32Z, mode: risk-gate (A, B, F) + routine-signoff (D, E)
- Conditions: C-1 to C-9 (see `## CTO conditions`)
- Phase graph: A → B → {D (after B1+B2), E} → F
- Plan content hash (SHA-256): 9db018724e07bb6f85bc9807e93abfdbcb4de57ad5a7fcc09fa2b46f704609fe (the file before this Approval section was appended)
- Human (developer): APPROVED on 2026-10-26T16:12:33Z
- Plan content hash at approval: f034bd87b8b9b1ad6a05a97367e976ba7dacc0f35414767d2e1da997dc9ee2de
