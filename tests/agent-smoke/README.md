# Headless smoke runs for the planning agents

Manual, paid verification that `aew:spec-analyser`, `aew:brief-compiler`, `aew:standards-setter` and
`aew:senior-engineer` (plan mode) behave in a real headless Claude Code session. There is no runner
script: this file holds copy-paste commands and the results table. Everything below runs in bash or zsh.

Never commit or log transcripts. Streams, debug logs and temp projects live under `$SMOKE`
(`${TMPDIR%/}/aew-smoke`), **outside the repo** (see section 5: a temp project inside the plugin tree makes every
subagent Write denied). Each run's stream, debug log, `final.txt` and recorded values go in `$O`
(`$SMOKE/out-<run-id>/`), outside the temp project, so the agent never sees them and the temp
project's own commits never include them. Only this README is committed (plus any intentional `fix(agents)` prompt fix).

## 1. Prerequisites

In an interactive zsh, run this first: without it `#` does not start a comment, so a line such as
`CAP=5   # …` leaves `CAP` unset. bash needs nothing.

```sh
setopt interactivecomments
```

```sh
claude --version                 # record it in the notes
claude plugin list               # record which other plugins are enabled: they load in headless sessions too
```

- superpowers and context7 must be installed (the agents preload `superpowers:systematic-debugging` and
  call the context7 MCP tools).
- `CONTEXT7_API_KEY` is optional for the checks, but without it the context7 server reported `needs-auth`
  in the recorded headless runs, so no context7 tool resolved and the agents fell back to the seeds (see
  the AC-18 row). Set it to observe the context7 tool names.
- `jq`, `shasum`, `git` and `/bin/bash` (3.2) are assumed.

### Spend ledger (CTO condition E-1)

Take the cost of every run from the stream's final `result` event and add a row here, counting every run
and re-run:

```sh
jq -r 'select(.type=="result") | .total_cost_usd' "$O/stream.jsonl"
```

- Default cap per run: `--max-budget-usd 5`. Standards-setter run 1 (921): `10`.
- A run that hits its cap is a run failure, not a check failure. Raise the cap **once**, to **exactly 2x**
  the default cap for that run (10, or 20 for run 921), and log the raise in the table below.
- The two accidental runs have no recorded cost: ~116k Opus tokens each, estimated at about $1.50 each
  (mostly cached input at Opus rates; an upper bound is about $1.75 if all of it was uncached input).
- **Stop at $75 total spend.** As soon as the running total passes $75, stop and report
  `DONE_WITH_CONCERNS`.

| run | id | cost (USD) | running total | cap raised? |
|---|---|---|---|---|
| accidental x2 (E1 review, senior-engineer, blocked, no cap) | n/a | 3.00 (estimate) | 3.00 | no |
| 901 attempt 1 (harness fault: `frontend-design` disabled, `aew` plugin did not load) | 901 | 0.17 | 3.17 | no |
| 901 attempt 2 (harness fault: reads outside cwd denied; `.aew` Writes denied inside the plugin tree) | 901 | 0.58 | 3.75 | no |
| 901 attempt 3 (harness fault: `--add-dir` added, Writes still denied) | 901 | 0.45 | 4.20 | no |
| Write-denial and E-3 probes (10 haiku one-liners about 0.10 in total, one opus `aew:spec-analyser` stub 0.31) | n/a | 0.41 | 4.61 | no |
| 901 pass (temp project moved outside the repo) | 901 | 0.60 | 5.21 | no |
| 901 re-run after the memory-path `fix(agents)` | 901 | 0.55 | 5.76 | no |
| 902 spec-analyser non-material | 902 | 0.49 | 6.25 | no |
| 903 spec-analyser material | 903 | 0.58 | 6.83 | no |
| 911 brief-compiler pipeline | 911 | 0.77 | 7.60 | no |
| 912 brief-compiler prompt | 912 | 0.61 | 8.21 | no |
| 921 attempt 1 standards-setter (agent fault: Bash `cat` loop denied) | 921 | 0.47 | 8.69 | no |
| 921 attempt 2 after the Bash-guardrail `fix(agents)` | 921 | 0.47 | 9.16 | no |
| 921 re-run on a fresh `$P` after the find/grep `fix(agents)` (72497e2) | 921 | 0.42 | 9.58 | no |
| 922 standards-setter reuse | 922 | 0.24 | 9.82 | no |
| 931 senior-engineer plan | 931 | 1.06 | 10.88 | no |

## 2. Setup per case

Set `REPO` once per shell, then paste the helper functions. They are the only setup code; each case below
calls them.

```sh
REPO=$(git rev-parse --show-toplevel)
SMOKE="${TMPDIR:-/tmp}"; SMOKE="${SMOKE%/}/aew-smoke"; mkdir -p "$SMOKE"   # NOT under $REPO
cd "$REPO"
```

### Fixtures

| fixture | path | issue | title |
|---|---|---|---|
| clean UI | `tests/fixtures/issues/clean-ui.md` | #101 | Newsletter sign-up in the site footer |
| non-material, non-UI | `tests/fixtures/issues/non-material-no-ui.md` | #102 | Add a health-check endpoint for the uptime monitor |
| material | `tests/fixtures/issues/material-guest-access.md` | #103 | Let readers save favourite articles |
| brief | `tests/fixtures/briefs/newsletter-signup.md` | #101 | (the compiled brief of `clean-ui.md`) |
| stack | `tests/fixtures/stacks/nextjs-tailwind/` (`app/layout.tsx`, `app/page.tsx`, `app/articles.ts`, `app/globals.css`, `package.json`, plus the tool configs `eslint.config.mjs`, `next.config.ts`, `postcss.config.mjs`, `tsconfig.json`) | | |

Run ids are numeric because the state schema requires it:

| agent | run ids |
|---|---|
| spec-analyser | 901 (clean), 902 (non-material), 903 (material) |
| brief-compiler | 911 (pipeline, UI), 912 (prompt mode, non-UI) |
| standards-setter | 921 (run 1), 922 (reuse run) |
| senior-engineer | 931 (plan) |

### Helpers

`smoke_project` creates the temp project, makes it a git repo with `.aew/` gitignored (as in a real
target project), enables the hooks (config), and initialises script-owned state. State is never
hand-written. If `state.sh` insists that the run id equals the issue number, that is a harness fault:
record it and adjust this command, keeping the run ids above. `smoke_use` re-points `P`, `RUN` and `O` at
a case that is already set up; call it before each invocation.

```sh
# smoke_project <agent> <case> <run-id> <issue-number> <title> <stage>
smoke_project() {
  P="$SMOKE/smoke-$1-$2"
  rm -rf "$P" && mkdir -p "$P" || return 1
  cp -R "$REPO/tests/fixtures/stacks/nextjs-tailwind/." "$P" && printf '.aew/\n' > "$P/.gitignore" || return 1
  git -C "$P" init -q && git -C "$P" add -A && git -C "$P" commit -qm fixture || return 1
  mkdir -p "$P/.aew" && cp "$REPO/templates/config.example.json" "$P/.aew/config.json" || return 1
  (cd "$P" && "$REPO/scripts/state.sh" init "$3" --issues "$4" --mode single --title "$5" \
     && "$REPO/scripts/state.sh" stage "$6") || return 1
  smoke_use "$1" "$2" "$3"
}

# smoke_use <agent> <case> <run-id>   (sets P, RUN and O for that run; creates O)
smoke_use() {
  P="$SMOKE/smoke-$1-$2"; RUN="$P/.aew/runs/$3"; O="$SMOKE/out-$3"
  mkdir -p "$O"
  echo "P=$P"; echo "RUN=$RUN"; echo "O=$O"
}

# smoke_render <fixture-file> <issue-number> <title>
# Phase C's C3 render check: renders the fixture body through scripts/gh-issue.sh fetch and the mocked gh,
# and cmp proves the render is byte-identical to the fixture. Output: $REPO/tests/tmp/issue-render-<n>/run/
smoke_render() {
  local file=$1 n=$2 title=$3 t="tests/tmp/issue-render-$2"
  (cd "$REPO" || exit 1
   rm -rf "$t"; mkdir -p "$t/gh/responses" "$t/run"
   awk 'p && /^## Comments \(/{exit} p{print} /^## Body$/{p=1}' "tests/fixtures/issues/$file" | sed '1d;$d' > "$t/body.md"
   jq -n --rawfile body "$t/body.md" --argjson n "$n" --arg t "$title" '{number:$n,title:$t,state:"OPEN",url:"https://github.com/acme/web/issues/\($n)",author:{login:"octo"},body:$body,labels:[],comments:[],milestone:null,assignees:[],blockedBy:{nodes:[]},blocking:{nodes:[]},parent:null,subIssues:{nodes:[]},closedByPullRequestsReferences:[]}' > "$t/gh/responses/issue-view.out"
   printf 0 > "$t/gh/responses/issue-view.code"
   PATH="$PWD/tests/scripts/helpers/bin:$PATH" GH_MOCK_DIR="$PWD/$t/gh" scripts/gh-issue.sh fetch "$n" "$t/run" >/dev/null \
     && cmp "$t/run/00-issue-original.md" "tests/fixtures/issues/$file" \
     && test "$(jq -r '.referenced_issues | length' "$t/run/issue.json")" = 0) \
    || { echo "smoke_render $1: render failed or is not byte-identical to the fixture" >&2; return 1; }
}

# smoke_seed_issue <issue-number>   (copies the rendered issue into $RUN; one render per fixture is enough)
smoke_seed_issue() {
  cp "$REPO/tests/tmp/issue-render-$1/run/00-issue-original.md" "$REPO/tests/tmp/issue-render-$1/run/issue.json" "$RUN/"
}
```

### Per-case setup

Each case uses `smoke_project`, then `smoke_render` once per fixture, then `smoke_seed_issue`, then the
extra seeds. The input file names come from each agent's Inputs block in `agents/<agent>.md`.

```sh
# spec-analyser: needs 00-issue-original.md and issue.json only
smoke_render clean-ui.md 101 "Newsletter sign-up in the site footer"
smoke_project spec-analyser clean 901 101 "Newsletter sign-up in the site footer" spec_analysis && smoke_seed_issue 101

smoke_render non-material-no-ui.md 102 "Add a health-check endpoint for the uptime monitor"
smoke_project spec-analyser nonmaterial 902 102 "Add a health-check endpoint for the uptime monitor" spec_analysis && smoke_seed_issue 102

smoke_render material-guest-access.md 103 "Let readers save favourite articles"
smoke_project spec-analyser material 903 103 "Let readers save favourite articles" spec_analysis && smoke_seed_issue 103

# brief-compiler, pipeline mode (run c): spec-final.md, issue.json (+ 00-issue-original.md)
smoke_project brief-compiler pipeline 911 101 "Newsletter sign-up in the site footer" brief \
  && smoke_seed_issue 101 && cp "$REPO/tests/fixtures/issues/clean-ui.md" "$RUN/spec-final.md"

# brief-compiler, prompt mode (run d): leave docs/standards/ absent
smoke_project brief-compiler prompt 912 102 "Add a health-check endpoint for the uptime monitor" brief \
  && smoke_seed_issue 102 && cp "$REPO/tests/fixtures/issues/non-material-no-ui.md" "$RUN/spec-final.md"

# standards-setter run 1 (run e); senior-engineer reuses this same project afterwards
smoke_project standards-setter newsletter 921 101 "Newsletter sign-up in the site footer" standards \
  && cp "$REPO/tests/fixtures/briefs/newsletter-signup.md" "$RUN/02-brief.md"
```

Standards-setter run 2 (E4) and the senior-engineer plan run (E5) reuse run 921's `$P`; they do not call
`smoke_project`:

For run 921, record the fingerprints before the run (the call standards-setter itself makes; the `[path]` is
the project root, `.`, never an entry's `path`):

```sh
smoke_use standards-setter newsletter 921
for pr in nextjs tailwind; do (cd "$P" && "$REPO/scripts/detect-stack.sh" fingerprint "$pr" .); done | tee "$O/fingerprints.before"
```

```sh
# E4: standards-setter run 2 (reuse check), same $P as run 921
smoke_use standards-setter newsletter 922
(cd "$P" && "$REPO/scripts/state.sh" init 922 --issues 101 --mode single --title "Newsletter sign-up in the site footer" \
   && "$REPO/scripts/state.sh" stage standards)
cp "$REPO/tests/fixtures/briefs/newsletter-signup.md" "$RUN/02-brief.md"
(cd "$P" && shasum -a 256 docs/standards/*) > "$O/standards.sha.before"
for pr in nextjs tailwind; do (cd "$P" && "$REPO/scripts/detect-stack.sh" fingerprint "$pr" .); done > "$O/fingerprints.before"
diff "$SMOKE/out-921/fingerprints.before" "$O/fingerprints.before"   # must print nothing, else a harness fault
# after run 922: both must print nothing
(cd "$P" && shasum -a 256 docs/standards/*) | diff "$O/standards.sha.before" -
git -C "$P" status --porcelain docs/standards

# E5: senior-engineer plan run, same $P
smoke_use standards-setter newsletter 931
(cd "$P" && "$REPO/scripts/state.sh" init 931 --issues 101 --mode single --title "Newsletter sign-up in the site footer" \
   && "$REPO/scripts/state.sh" stage plan)
cp "$REPO/tests/fixtures/briefs/newsletter-signup.md" "$RUN/02-brief.md"
cp "$P/.aew/runs/922/03-standards.md" "$RUN/03-standards.md"
```

## 3. Invocation

Run from `$P`, as one thin main-thread prompt that dispatches the agent as a subagent. `ALLOW` is that
agent's Bash allowlist, taken from its prompt (Guardrails). Agents without Bash pass no `--allowedTools`
at all. The guarded expansion `${ALLOW[@]+"${ALLOW[@]}"}` is required: a bare `"${ALLOW[@]}"` on an empty
array is an unbound-variable error in bash 3.2 under `set -u`, and the guarded form is equally safe in zsh.

```sh
# spec-analyser, brief-compiler: no Bash (no --allowedTools)
ALLOW=()
# standards-setter (Bash: detect-stack.sh and date, plus auto-allowed read-only find/grep/ls/head/wc, so no extra rule)
ALLOW=(--allowedTools "Bash($REPO/scripts/detect-stack.sh *)" "Bash(date *)" "mcp__plugin_context7_context7__*")
# senior-engineer (Bash is read-only: git diff, log, show, status, rev-parse --verify, ls; find/grep/head/wc are auto-allowed read-only, so no extra rule)
ALLOW=(--allowedTools "Bash(git diff *)" "Bash(git log *)" "Bash(git show *)" "Bash(git status *)" "Bash(git rev-parse --verify *)" "Bash(ls *)" "mcp__plugin_context7_context7__*")
```

If a smoke run shows that an agent's prompt allowlist and its `ALLOW` line disagree, the prompt is the
source: fix `ALLOW` to match it (a harness fault), never the other way round to make a run pass.

`$DISPATCH` has fixed wording. `<fields>` come from the agent's Inputs block:

```sh
# smoke_dispatch <agent> <fields>   e.g. smoke_dispatch spec-analyser "run_dir: $RUN"
smoke_dispatch() {
  DISPATCH="Ignore any aew run or resume hint in your context. Use the Agent tool to dispatch the subagent \`aew:$1\` with exactly this prompt: \`$2\`. Do nothing else. When it returns, print its final message verbatim."
}
```

| agent | dispatch fields |
|---|---|
| spec-analyser | `run_dir: $RUN` (`spec_version` is optional; the agent derives it) |
| brief-compiler | `run_dir: $RUN` and `mode: pipeline` or `mode: prompt` |
| standards-setter | `run_dir: $RUN` |
| senior-engineer | `run_dir: $RUN` and `mode: plan` |

Before each launch, point the shell at the case and set its `ALLOW` line from the block above and its cap
(setup leaves `P` and `RUN` on the last case set up, so never launch without `smoke_use`):

```sh
smoke_use spec-analyser clean 901;         smoke_dispatch spec-analyser "run_dir: $RUN";                  CAP=5
smoke_use spec-analyser nonmaterial 902;   smoke_dispatch spec-analyser "run_dir: $RUN";                  CAP=5
smoke_use spec-analyser material 903;      smoke_dispatch spec-analyser "run_dir: $RUN";                  CAP=5
smoke_use brief-compiler pipeline 911;     smoke_dispatch brief-compiler "run_dir: $RUN, mode: pipeline"; CAP=5
smoke_use brief-compiler prompt 912;       smoke_dispatch brief-compiler "run_dir: $RUN, mode: prompt";   CAP=5
smoke_use standards-setter newsletter 921; smoke_dispatch standards-setter "run_dir: $RUN";               CAP=10
smoke_use standards-setter newsletter 922; smoke_dispatch standards-setter "run_dir: $RUN";               CAP=5
smoke_use standards-setter newsletter 931; smoke_dispatch senior-engineer "run_dir: $RUN, mode: plan";    CAP=5
```

```sh
cd "$P" && claude --plugin-dir "$REPO" -p "$DISPATCH" \
  --output-format stream-json --verbose --forward-subagent-text --include-hook-events \
  --max-budget-usd "$CAP" --debug-file "$O/debug.log" \
  --settings "{\"claudeMdExcludes\":[\"$REPO/CLAUDE.md\"],\"enabledPlugins\":{\"dev-workflow@jamesborg\":false,\"figma@claude-plugins-official\":false}}" \
  --add-dir "$REPO" --permission-mode acceptEdits \
  ${ALLOW[@]+"${ALLOW[@]}"} \
  > "$O/stream.jsonl"
```

`enabledPlugins` switches off user-level plugins that would otherwise run in the headless session (the
`dev-workflow` SessionStart hook writes `docs/superpowers/project-map.md` into the temp project). Do **not**
disable `frontend-design`: aew depends on it, and a disabled dependency stops the whole `aew` plugin loading
(`Agent type 'aew:spec-analyser' not found`). `--add-dir "$REPO"` is needed so subagents may Read the plugin's
templates and `skills/run-protocol/references/`. The temp project must live outside `$REPO` (`$SMOKE`).

Several runs may be launched concurrently as background processes (each has its own `$P` and `$O`, so
set `P`, `RUN`, `O`, `DISPATCH`, `ALLOW` and `CAP` per launch, for example inside a subshell). Prompt-fix loops are per agent.

### After every run (CTO condition E-2, mandatory)

```sh
git -C "$REPO" status --porcelain
```

It may show only `tests/agent-smoke/README.md` and an intentional prompt-fix file (`agents/*.md`,
`skills/stack-standards/**`, `docs/DESIGN.md` under the rule below). Any other change fails the run and is
reverted before continuing. This check is mandatory if the `--add-dir "$REPO"` fallback is adopted.

## 4. Check commands (shared by all runs)

**Subagent final message.** The text of the last `assistant` event with a non-null `parent_tool_use_id`
and a `text` content block (a trailing tool_use-only event has no text), written to `final.txt`. E2
confirms the field name; if it is unreliable, take the Agent tool's `tool_result` content instead and
record which source was used.

```sh
jq -rs '[.[] | select(.type=="assistant" and .parent_tool_use_id != null)
         | select(any(.message.content[]?; .type=="text"))] | last
        | [.message.content[] | select(.type=="text") | .text] | join("\n")' \
  "$O/stream.jsonl" > "$O/final.txt"
```

**Return block.** Load the canonical function without running the hook. Use `eval`, not `source <(...)`:
macOS `/bin/bash` 3.2 sources an empty process substitution silently, so the function would never be
defined. The guard makes a reformatted hook fail loudly. It uses `command -v`, not `declare -F`: in zsh
`declare -F` declares a float variable and always succeeds, so the guard would never fire. Run it on `final.txt` and on every artefact whose
template ends in a return block; it prints the STATUS value.

```sh
eval "$(sed -n '/^valid_return_block() {/,/^}/p' "$REPO/scripts/hooks/gate-subagent.sh")"
command -v valid_return_block >/dev/null || echo 'valid_return_block: extraction failed'
valid_return_block "$O/final.txt" && grep -E '^STATUS:' "$O/final.txt" | tail -1
valid_return_block "$RUN/01-spec-analysis.md"   # and each other artefact that ends in a return block
```

**Template conformance.** Must print nothing. Template to artefact: `spec-analysis.md` to
`01-spec-analysis.md`, `brief.md` to `02-brief.md`, `standards-run.md` to `03-standards.md`, `plan.md` to
`05-plan.md`, `prompt.md` to `prompt.md`. For `spec-analysis.md` the fixed `### ` Findings sub-headings are
compared too. Repeating headings (`### Q<n>`, `### WP-<n>`) are checked for their pattern, not their count.

```sh
diff <(grep -E '^## ' "$REPO/templates/artefacts/brief.md" | sed -E 's/: yes\/no$//') \
     <(grep -E '^## ' "$RUN/02-brief.md" | sed -E 's/: (yes|no)$//')
# spec-analysis: also compare the fixed Findings sub-headings (drop the repeating ### Q<n>)
diff <(grep -E '^##+ ' "$REPO/templates/artefacts/spec-analysis.md" | grep -vE '^### Q' | sed -E 's/: yes\/no$//') \
     <(grep -E '^##+ ' "$RUN/01-spec-analysis.md" | grep -vE '^### Q' | sed -E 's/: (yes|no)$//')
```

**Preload (AC-18).** No hit for `aew:run-protocol`, `aew:stack-standards` or
`superpowers:systematic-debugging` (senior-engineer must show none for any of the three). Record any
positive load line too.

```sh
grep -inE 'skill' "$O/debug.log" | grep -iE 'skip|not found|missing|unknown'
grep -inE 'skill' "$O/debug.log" | grep -iE 'run-protocol|stack-standards|systematic-debugging'   # positive loads
```

**Permission denials.** Must print `[]`.

```sh
jq -c 'select(.type=="result") | .permission_denials' "$O/stream.jsonl"
```

**Tool calls in the stream** (Bash commands, Read paths, MCP tool names):

```sh
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
       | [.name, (.input.command // .input.file_path // .input.path // "")] | @tsv' "$O/stream.jsonl"
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$O/stream.jsonl" \
  | grep '^mcp__' | sort -u
```

**Subagent identity (CTO condition E-3).** Live evidence that a `PreToolUse` payload inside a subagent
carries `agent_type` as `aew:<agent>`. Look for a hook line in the debug log or in the `--include-hook-events`
stream. The hook events in the stream may carry only the hook's output, not its input payload, so the
debug log is the first place to look. Record one such line verbatim, or failing that the docs citation. If there is no live evidence, the
final report says the agent `gh` deny is tested in bats only, not live.

```sh
grep -n 'agent_type' "$O/debug.log" | head
jq -c 'select(.type=="system" and (.subtype // "" | test("hook"))) | select(tostring | test("agent_type"))' "$O/stream.jsonl" | head -3
```

**Cleanup.** `rm -rf "$SMOKE" "$REPO/tests/tmp/issue-render-"*` once the results are recorded.

### Loop on failure

- *Harness fault* (wrong command, missing seed, jq path): fix the command here and re-run. No prompt change.
- *Agent fault*: fix `agents/<agent>.md` (or the `stack-standards` skill), commit as
  `fix(agents): <what the prompt now says>`, then re-run the failing case **and** every case of the same
  agent that passed before. A prompt fix keeps the `##` headings in order (`Role`, `Inputs`, `Process`,
  `Outputs`, `Return contract`, `Guardrails`, `Autonomy`, `Definition of done`; agent-specific sections only
  between `Inputs` and `Process`; `## Memory` only between `Autonomy` and `Definition of done`), and adds no
  new `##` line. Check with `awk '/^```/{f=!f;next} !f && /^## /' agents/<agent>.md`.
- The check is never weakened. Three fix rounds per check at most; then stop and report
  `DONE_WITH_CONCERNS`.
- A check that passed once and failed once is recorded as `flaky` (both outcomes in the notes). A prompt fix
  targets it, and the last recorded run must pass.
- If a prompt fix changes something DESIGN §3 states (the `skills:` name form, the context7 tool names),
  the same `fix(agents)` commit also corrects §3.

## 5. Isolation findings

Filled in by E2 (isolation probe) and E3 (seed path resolution).

| finding | result | notes |
|---|---|---|
| Isolation 1: `$REPO/CLAUDE.md` not loaded (debug log) | pass (by relocation) | Deviation from A22: temp projects now live in `$SMOKE` (`${TMPDIR%/}/aew-smoke`), outside the repo, so no repo `CLAUDE.md` is an ancestor (debug: `found 0 of 8 directories`, no `aew-wt-E/CLAUDE.md` line). Reason: a project inside the plugin tree makes every subagent Write denied ("sensitive file"). `claudeMdExcludes` is kept as belt and braces. |
| Isolation 2: agent read `$REPO/templates/artefacts/spec-analysis.md`, no denial (else add `--add-dir "$REPO"`) | pass with `--add-dir` | Without it: Read denied for `templates/artefacts/*` and `skills/run-protocol/references/artefacts.md`. With `--add-dir "$REPO"`: reads allowed, `permission_denials` is `[]`. E-2 is therefore mandatory for every run. |
| Isolation 3: SessionStart resume hint present, `aew:spec-analyser` still dispatched, no `aew:resume` call | pass | Debug log: `Active aew run 901 at stage spec_analysis (running). Use /aew:resume.` The only main-thread tool call was `Agent aew:spec-analyser`; no Skill call. |
| Stream shape: final-message jq filter returns the subagent's message (source used) | pass | The filter on the last assistant event with a non-null `parent_tool_use_id` and a text block returns the subagent's own message (starts with its summary, ends in the return block); the Agent `tool_result` is not needed. |
| Preload form: `aew:run-protocol` loads (else bare `run-protocol`) | pass | Debug: `[Agent: aew:spec-analyser] Preloaded skill 'aew:run-protocol'`; no skip warning. The qualified form works, so DESIGN §3 needs no change. |
| Seed path resolution: `${CLAUDE_SKILL_DIR}` substituted in a subagent-preloaded skill; any unexpanded `${` | pass for `${CLAUDE_PLUGIN_ROOT}`; `${CLAUDE_SKILL_DIR}` untested | standards-setter (run 921) read seeds at the absolute `$REPO/skills/stack-standards/references/seeds/<profile>.md`; the preloaded skill and the agent prompt both spell it `${CLAUDE_PLUGIN_ROOT}/...`, so substitution of that variable works in both. No skill uses `${CLAUDE_SKILL_DIR}`, so nothing shows whether it expands in a subagent-preloaded skill (E6 need not add it to F9). No unexpanded `${` in any Read input or debug line. |
| E-3: `PreToolUse` payload in a subagent carries `agent_type` `aew:<agent>` (live line or docs citation) | pass (live) | Neither the debug log nor the `--include-hook-events` stream carries hook input. A probe session with a `--settings` PreToolUse hook (`cat >> payloads.jsonl`) recorded: `{"tool":"Glob","agent_type":"aew:spec-analyser","agent_id":"af0b9886062461f6d","hook_event_name":"PreToolUse"}`; the main thread's own `Agent` call had `agent_type` null. The agent `gh` deny can therefore key on `aew:<agent>` live. |

## 6. Results

Each row records its outcome. Cost goes in the notes (and the ledger in section 1).

| check | result | notes |
|---|---|---|
| **E2 run 901, spec-analyser clean** | | |
| 901 Isolation 1 to 3, stream shape | pass | See section 5. |
| 901 Preload (no skip warning for `aew:run-protocol`) | pass | `Preloaded skill 'aew:run-protocol'`; no skip line. |
| 901 Permission denials empty | pass | `[]` with `--add-dir "$REPO"` and the project outside the repo. |
| 901 final.txt valid return block, `STATUS: ok`, SUMMARY says no material changes | pass | `valid_return_block` ok; SUMMARY starts "No changes needed." |
| 901 `spec-changes.json` has 0 material changes | pass | `changes: []`. |
| 901 `01-spec-analysis.md` follows template, ends in valid return block | pass | Heading diff empty; `valid_return_block` ok. |
| 901 `spec-final.md` exists; if `changes` is `[]`, SUMMARY has "No changes needed" and spec-final equals the analysed spec (AC-13) | pass | `diff` against `issue.json` `.body` differs only by one trailing blank line (the body ends in a newline). |
| 901 `git -C "$REPO" status --porcelain` clean (E-2) | pass | Only this README (and the committed fix files) differ. No foreign file in `$P` (no `docs/`); `.claude/agent-memory/aew-spec-analyser/` created. Cost 0.55 for the last run; see ledger. |
| **E3 run a 902, spec-analyser non-material** | | |
| 902 `STATUS: ok` | pass | `STATUS: ok`; `valid_return_block` ok. |
| 902 at least one change, all `type: non-material`, `source: auto` | pass | 4 changes, all `non-material`/`auto`: typo "retrun", reference `/api/heath`, implied AC 3 (200 + JSON), AC 4 (no DB/external). |
| 902 changes applied in `spec-final.md` (spot-checked) | pass | Spot-check: `diff` of `issue.json` body against `spec-final.md` shows all 4 applied (2 fixes, 2 ACs added). |
| 902 Classification table has no `material` row | pass | 4 rows, all `non-material`. |
| 902 artefacts follow templates, valid return blocks | pass | Heading diff empty; both blocks valid. |
| 902 Preload, permission denials, final.txt return block, E-2 | pass | `Preloaded skill 'aew:run-protocol'`; denials `[]`; E-2 clean: only the README (and the committed fix) differ. Cost 0.49. |
| **E3 run b 903, spec-analyser material** | | |
| 903 `STATUS: needs_input` | pass | Final message and artefact both `needs_input`. |
| 903 Classification has a `material` row | pass | 2 `material` rows (storage location; navigation link), 5 non-material. |
| 903 `### Q<n>` with non-empty `**Recommended answer:**` and `**Alternatives:**`, about guest vs logged-in access | pass | Q1 localStorage vs signed-in account (guest vs logged-in), Q2 link placement; both have a non-empty Recommended answer and Alternatives. |
| 903 `spec-changes.json` holds no material change (A15) | pass | 5 changes, all `non-material`/`auto`; the 2 material ones are only in Classification and Questions. |
| 903 artefacts follow templates, valid return blocks | pass | Heading diff empty; both blocks valid. |
| 903 Preload, permission denials, final.txt return block, E-2 | pass | Preload ok, denials `[]`, E-2 clean: only the README (and the committed fix) differ. Cost 0.58. |
| **E3 run c 911, brief-compiler pipeline, UI** | | |
| 911 `02-brief.md` follows template | pass | Heading diff empty (only the H1 placeholder differs). |
| 911 ACs `AC-1..AC-n` contiguous, atomic, observable (per-AC judgement in notes) | pass | AC-1..AC-38 contiguous (checked by extraction). Each is a Given/When/Then with a concrete observable and a tag; AC-9 (both import one module), AC-10 (value table) and AC-36 (contrast in five states) bundle several inputs under one rule, judged acceptable. Vague words: 0, none listed under Open risks. |
| 911 exactly one `UI changes:` line in `02-brief.md`, value `yes` | pass | `## UI changes: yes`, one line. |
| 911 artefact and final.txt end in valid return block, `STATUS: ok` | pass | `STATUS: ok`; both blocks valid. |
| 911 Preload, permission denials, E-2 | pass | Preload ok, denials `[]`, E-2 clean: only the README (and the committed fix) differ. Cost 0.77. |
| **E3 run d 912, brief-compiler prompt mode, non-UI** | | |
| 912 `prompt.md` exists, no `02-brief.md` written | pass | `prompt.md` written, no `02-brief.md`; `docs/` absent so the A18 inlining path ran (Standards section inlines nextjs/tailwind essentials). |
| 912 `prompt.md` `## ` headings match `templates/artefacts/prompt.md` | pass | Heading diff against the template empty. |
| 912 no aew words in `prompt.md` (`grep -cE 'aew\|\.aew/\|/aew:\|run-protocol\|CLAUDE_PLUGIN_ROOT'` is 0) | pass | Count 0. |
| 912 no HTML comments in `prompt.md` (`grep -c '<!--'` is 0) | pass | Count 0. |
| 912 exactly one `UI changes:` line in `prompt.md`, value `no` | pass | `### UI changes: no`, one line, under `## Brief`. |
| 912 every source requirement maps to a contiguous `AC-n` (mapping in notes) | pass | Spec AC1 (body) -> AC-1 status, AC-2 body, AC-3 content type; AC2 / no-auth -> AC-4; no DB -> AC-5; no external service -> AC-6; typo `/api/heath` surfaced under Open risks. Numbering AC-1..AC-6 contiguous. |
| 912 `prompt.md` has no return block; final.txt passes `valid_return_block` | pass | `valid_return_block prompt.md` fails as intended, no `STATUS:` line; `final.txt` valid, `STATUS: ok`. |
| 912 Preload, permission denials, E-2 | pass | Preload ok, denials `[]`, E-2 clean: only the README (and the committed fix) differ. Cost 0.61. |
| **E3 run e 921, standards-setter run 1** | | |
| 921 agent fingerprint calls are `... detect-stack.sh" fingerprint <profile> .` and equal the recorded values | pass | Attempt 2: `"$REPO/scripts/detect-stack.sh" fingerprint nextjs .` and `... tailwind .`; output equals the recorded `nextjs next@16 react@19 typescript@5 cfg:388ef4ff81b7` and `tailwind tailwindcss@4 cfg:3f0744e5bcde`. |
| 921 allow-rule match: `detect-stack.sh` calls in quoted form, root equals `$REPO`, none denied (one command verbatim in notes) | pass | Quoted form matched `Bash($REPO/scripts/detect-stack.sh *)`, none denied. Verbatim: `"/Users/jamesborg/Documents/Development/aew-wt-E/scripts/detect-stack.sh" fingerprint nextjs .`. A compound `a; b; date ...` command (attempt 1) also matched. No `ALLOW` change needed. |
| 921 seed path resolution recorded (section 5), no unexpanded `${` | pass | Seeds read at `$REPO/skills/stack-standards/references/seeds/<profile>.md` (absolute, substituted). The skill and prompt both use `${CLAUDE_PLUGIN_ROOT}`, no `${CLAUDE_SKILL_DIR}`, so that variable is untested. No unexpanded `${` in any Read or debug line (the only `${` is document content written to `tailwind.md`). See section 5. |
| 921 `docs/standards/nextjs.md`, `tailwind.md`, `README.md` exist | pass | All three exist (155, 87, 8 lines). |
| 921 first line of each profile doc matches the `aew:standards fingerprint=... generated=...` header | pass | Both match the regex with the recorded fingerprints, `generated="2026-10-24"`. |
| 921 `README.md` follows the index format and lists both docs and fingerprints | pass | Index table with both docs, paths, overlay and fingerprints, plus the precedence line. |
| 921 each doc 400 lines or fewer; `tailwind.md` opens with "Overlay on: nextjs" | pass | 155 and 87 lines; `tailwind.md` line 2 is `Overlay on: nextjs`. |
| 921 `03-standards.md` follows template, ends in valid return block, both rows `generated`, section rows name existing sections | pass | Heading diff empty; both rows `generated`; all 12 section rows resolve to an existing `## ` heading in the named doc. |
| 921 `STATUS: ok` | pass | Final message and artefact. |
| 921 AC-18: no skip warning for `aew:stack-standards`; context7 tool names called recorded verbatim | partial: preload pass, context7 names not observable | No skip warning; `aew:stack-standards` and `aew:run-protocol` preloaded. context7 was never called: in this headless session the server is `plugin:context7:context7` with status `needs-auth` (no `CONTEXT7_API_KEY`), so the debug log warns `Agent tools entry "mcp__plugin_context7_context7__*" takes no tool`. The agent fell back as designed ("context7 unavailable" in the docs). The server key matches the `mcp__plugin_context7_context7__` form, so no `tools:` change; the call names stay unverified for E6. |
| 921 Preload, permission denials, final.txt return block, E-2 | pass | Attempt 1 failed here (agent fault): a `for f in ...; do cat $f; done` Bash loop was denied. Fix `dcac6f4` (Guardrails name them off limits) told it to use Glob/Grep, which do not exist for an agent with Bash (see notes); fix `72497e2` replaced that with `find`/`grep`. Re-run on a fresh `$P` after `72497e2`: denials `[]`, no `No such tool` line, `valid_return_block` ok on final.txt and the artefact, E-2 clean (nothing differs in `$REPO`). Cost 0.42. |
| 921 re-check after `72497e2` (fresh `$P`): fingerprint calls, headers, README, line counts, `Overlay on: nextjs`, `03-standards.md` rows `generated`, section rows resolve, `STATUS: ok`, no Glob error | pass | Fingerprints equal the recorded values (`nextjs ... cfg:388ef4ff81b7`, `tailwind ... cfg:3f0744e5bcde`); headers match the format; docs 140 and 91 lines; all 11 section rows resolve to existing `## ` headings; the agent searched with `find docs/standards -type f` and `find . -path ./node_modules -prune ...`, both allowed. |
| 921 post-pass: `git -C $P add -A && git -C $P commit -qm standards` done | pass | `git commit -qm standards` in the fresh `$P` (commit `e64c740`, replacing `62d5ac3`): clean tree for E4. |
| **E4 run 922, standards-setter reuse** | | |
| 922 fingerprint calls from the project root equal the setup values (setup values equal run 921's: the setup `diff` prints nothing) | pass | Setup `diff` printed nothing. Agent calls: `"$REPO/scripts/detect-stack.sh" fingerprint nextjs .` and `... tailwind .`, output equal to the setup values. |
| 922 `STATUS: ok`, SUMMARY contains "reused" | pass | `STATUS: ok`; SUMMARY "nextjs: reused; tailwind: reused. Both fingerprints matched exactly, so nothing under docs/standards/ was written." |
| 922 `03-standards.md` Status `reused` on both rows | pass | Both rows `reused`; the 11 section rows resolve to existing headings. |
| 922 checksums after the run byte-identical to before | pass | `shasum -a 256 docs/standards/*` diff prints nothing. |
| 922 `git -C $P status --porcelain docs/standards` empty | pass | Empty. |
| 922 artefact follows template, both return blocks valid | pass | Heading diff empty; both blocks valid. |
| 922 Preload, permission denials, E-2 | pass | Preload ok (`aew:run-protocol`, `aew:stack-standards`); denials `[]`; E-2 clean. Cost 0.24. The agent used `ls` and a `grep -n "^## "` of both docs (read-only, allowed). |
| **E5 run 931, senior-engineer plan** | | |
| 931 `05-plan.md` follows template, both return blocks valid; STATUS `ok` or `needs_input` with a listed material challenge (record which) | pass | Heading diff against the template empty (`### WP-<n>` pattern); both blocks valid; `STATUS: ok` (no material challenge; 7 non-material ones listed). |
| 931 "Alternatives considered" has at least one alternative with a rejection reason | pass | 4 alternatives, each with a reason: Server Action instead of Route Handler, native browser validation, separate error element plus hidden live region, one WP for everything. |
| 931 AC to WP matrix covers every AC; every WP id in the matrix has a `### WP-<n>` block | pass | `grep -oE 'AC-[0-9]+' 02-brief.md | sort -u` (AC-1..AC-7) equals the matrix AC column; WP-1, WP-2, WP-3 all have blocks. |
| 931 at least one WP `parallelisable: yes`; every WP's value correct under PD-7; no file in two WPs unless the later depends on the earlier (per-WP reasoning in notes) | pass | WP-1 `no`: foundation, both others depend on it, nothing runs alongside it. WP-2 `yes` and WP-3 `yes`: each `depends_on` only WP-1, neither depends on the other, and files are disjoint (`app/api/newsletter/route*.ts` against `components/newsletter-form*.tsx` and `app/layout.tsx`). `package.json` is owned by WP-1 alone. Matches the fixture's designed split (shared validator, then server and client in parallel). |
| 931 every WP has standards references that exist in `docs/standards/`, and unit tests listed | pass | 17 references; every doc file exists and every section name (`tooling-and-commands`, `framework-conventions`, `error-handling`, `security`, `accessibility`, `testing-conventions`) is an existing `## ` heading in that doc. Unit-test table has WP-1, WP-2 and WP-3 rows. |
| 931 Preload: none skipped for `aew:run-protocol`, `aew:stack-standards`, `superpowers:systematic-debugging` | pass | Debug: `[Agent: aew:senior-engineer] Preloaded skill` for all three; no skip line. |
| 931 permission denials empty, E-2 | pass | `[]`; E-2 clean. No `No such tool`. The agent used `ls`, and `find ... -type f` (allowed). Cost 1.06. |

## 7. Notes

Cap raises (exactly 2x, once per run), prompt fixes, flaky checks and deviations from the commands above
are logged here, newest last.

- E2 harness faults, all fixed in this README: (1) `enabledPlugins` must not disable `frontend-design`, which
  `aew` depends on: the plugin then fails to load and `aew:spec-analyser` is "not found". (2) Reads outside
  the temp project were denied until `--add-dir "$REPO"` was added. (3) With the temp project under
  `$REPO/tests/tmp`, every Write by a subagent into `.aew/` was denied as a "sensitive file" (the plugin
  hook allowed it; a plugin-less session or a project outside the plugin tree writes fine, bisected with
  haiku probes), so projects and outputs moved to `$SMOKE` outside the repo. A scoped `Write(...)` allow rule
  did not help.
- E2 agent fault (prompt fix `48c1a8d`): plugin agents with `memory: project` use
  `.claude/agent-memory/aew-<agent>/`, not `<agent>/`. Fixed in `spec-analyser`, `standards-setter`,
  `senior-engineer` and DESIGN §3 line 37 (E6: already present). Run 901 re-run afterwards and passed.
- macOS note: `$TMPDIR` is a symlink (`/var/...` to `/private/var/...`); agents may report either form.
  The user-level `dev-workflow` SessionStart hook is switched off in `--settings` and wrote nothing into `$P`.
- E3 command shapes: use `$SMOKE`, the invocation block above verbatim (`enabledPlugins` without
  `frontend-design`, `--add-dir "$REPO"`), and no `Write(...)` allow rules. To capture hook payloads (E-3) add
  `"hooks":{"PreToolUse":[{"matcher":".*","hooks":[{"type":"command","command":"cat >> $O/payloads.jsonl; echo >> $O/payloads.jsonl"}]}]}`
  to `--settings`.
- E3 batch (Claude Code 2.1.308): five runs launched concurrently from one wrapper per run, about 3 minutes wall clock; all five `result` events `success`. Runs a to d passed first time.
- E3 agent fault (prompt fix `dcac6f4`): standards-setter attempt 1 broke its two-command Bash allowlist (a `cat` loop, denied; `ls` and `git ls-files` ran because read-only commands are auto-allowed). Guardrails now forbid `cat`, `ls`, `git`, loops and pipes. Attempt 2 clean. standards-setter had no earlier passing case to re-run; spec-analyser was untouched.
- E3 environment facts for E6: (1) in this headless session `Glob` and `Grep` are not in the tool list (`No such tool available: Glob ... find files with find via the Bash tool`), although the agents list them in `tools:`. The docs explain it (see the E4 note below): corrected in DESIGN section 3 by `72497e2`. (2) context7 is `needs-auth` here (see the AC-18 row). (3) The fingerprint and `date +%Y-%m-%d` calls were allowed under the `Bash(date *)` and quoted-path rules, including in a `;`-joined command.
- Run 921's `$P` (`$SMOKE/smoke-standards-setter-newsletter`) is committed (`standards`) and untouched for E4 and E5; attempt 1's stream is kept as `$SMOKE/out-921-attempt1`.
- E4 agent and DESIGN fault (prompt fix `72497e2`): the docs (tools-reference, sub-agents, permissions, fetched 2026-10-24) say `Glob` and `Grep` are absent by default on macOS/Linux/WSL, that a subagent gets them back only if it lists them **and leaves out `Bash`**, and that read-only Bash commands (`ls`, `cat`, `head`, `tail`, `grep`, `find`, `wc`, `diff`, `stat`, read-only `git`) run without a prompt in every mode (`find` with `-exec`, `-delete` or `-fprint` prompts). So `dcac6f4` was wrong to tell standards-setter to use Glob/Grep. Now standards-setter and senior-engineer (both have Bash) drop `Glob, Grep` from `tools:` and use read-only `find`, `grep`, `ls`, `head`, `wc` (Read for contents); spec-analyser and brief-compiler (no Bash) keep `Glob, Grep`. DESIGN section 3 has a new "Search tools" bullet in the same commit. Run 921 re-run on a fresh `$P` and passed all rows; it is the only passing case of standards-setter, so no further re-runs.
- E4/E5 ran sequentially in the same `$P`; run 931 seeded `03-standards.md` from 922 and did not seed `spec-final.md` (optional context for plan mode). The headless `ALLOW` lines needed no change for `find`/`grep`/`head`/`wc` because they are auto-allowed read-only commands.

## 8. Build agents (prompt 04)

Smoke runs for `aew:developer`, `aew:qa-engineer` and `aew:doc-writer`, and the Playwright MCP probe they rely on.
The conventions of sections 1 to 4 apply (`$SMOKE` outside the repo, `--settings` `enabledPlugins` disabling only
`dev-workflow` and `figma`, `--debug-file`, the after-run `git -C "$REPO" status --porcelain`).

### 8.1 Spend ledger (prompt 04, stop at $60)

Separate from the prompt-03 ledger in section 1. Take each cost from the stream's final `result` event. Caps
(Assumption 27): $5 per run, $8 for QA phase B, $10 for the fan-out run, $2 for gate checks, one raise to exactly 2x
per run, **stop at $60 total**. Before each paid run add its cap to the total below; if the sum would exceed $60, do
not start the run (record its checks as `open`). Apply the same test before any 2x raise.

| run | id | cost (USD) | running total | cap raised? |
|---|---|---|---|---|
| 940 Playwright MCP probe (haiku) | 940 | 0.01 | 0.01 | no |
| 941 qa-engineer phase A blindness (cap 5; 0.01 + 5 = 5.01, under 60) | 941 | 0.37 | 0.38 | no |
| 951 cycle 1 attempt 1 (cap 8; 0.38 + 8 = 8.38, under 60) | 951 | 0.61 | 0.99 | no |
| 951 cycle 1 attempt 2, after fix 719f13e (cap 8; 0.99 + 8 = 8.99, under 60) | 951 | 0.57 | 1.56 | no |
| 941 re-run after fix 719f13e (cap 5; 1.56 + 5 = 6.56, under 60) | 941 | 0.35 | 1.91 | no |
| 961 fan-out attempt 1 (cap 10; 1.91 + 10 = 11.91, under 60) | 961 | 0.65 | 2.56 | no |
| 961 fan-out attempt 2, after the git -C fix (cap 10; 2.56 + 10 = 12.56, under 60) | 961 | 0.80 | 3.36 | no |
| 961 fan-out attempt 3, after the main-checkout git fix (cap 10; 3.36 + 10 = 13.36, under 60) | 961 | 0.79 | 4.15 | no |
| 951 developer fix, cycle 1 (cap 5; 4.15 + 5 = 9.15, under 60) | 951 | 0.47 | 4.62 | no |
| 951 QA cycle 2 attempt 1 (cap 8; 4.62 + 8 = 12.62, under 60) | 951 | 0.54 | 5.16 | no |
| 951 QA cycle 2 attempt 2, after fix d4b2c86 (cap 8; 5.16 + 8 = 13.16, under 60) | 951 | 0.36 | 5.52 | no |
| 941 re-run after fix d4b2c86 (cap 5; 5.52 + 5 = 10.52, under 60) | 941 | 0.34 | 5.86 | no |
| 951 doc-writer (cap 5; 5.86 + 5 = 10.86, under 60) | 951 | 0.44 | 6.30 | no |
| 951 doc-writer re-run 1, after fix f2df416 (cap 5; 6.30 + 5 = 11.30, under 60) | 951 | 0.33 | 6.63 | no |
| 951 doc-writer re-run 2, after fix 48cb638 (cap 5; 6.63 + 5 = 11.63, under 60) | 951 | 0.31 | 6.94 | no |
| 971 report-less developer gate probe (cap 2; 6.94 + 2 = 8.94, under 60) | 971 | 0.30 | 7.24 | no |
| 972 report-less qa-engineer gate probe (cap 2; 7.24 + 2 = 9.24, under 60) | 972 | 0.28 | 7.52 | no |

### 8.2 Playwright MCP tool names (AC-2, probe 940)

One Haiku session, `--plugin-dir "$REPO"`, in an empty git project under `$SMOKE`. It records the init tool list
and drives the bundled server once, so it also settles the browser, files written into the cwd and the focus marker.
Claude Code 2.1.308. Cap `--max-budget-usd 1`.

```sh
setopt interactivecomments 2>/dev/null || true
REPO=$(git rev-parse --show-toplevel)
SMOKE="${TMPDIR:-/tmp}"; SMOKE="${SMOKE%/}/aew-smoke"; mkdir -p "$SMOKE"
PROBE="$SMOKE/probe-playwright"; O="$SMOKE/out-940"
rm -rf "$PROBE" "$O" && mkdir -p "$PROBE" "$O"
git -C "$PROBE" init -q && git -C "$PROBE" commit -q --allow-empty -m probe
claude --version > "$O/claude-version.txt"
URL='data:text/html,<title>aew-probe</title><button>One</button><button>Two</button>'
T=mcp__plugin_aew_playwright__browser
cd "$PROBE" && claude --plugin-dir "$REPO" -p "Use only the Playwright MCP tools, in this order: 1) browser_navigate to $URL 2) browser_press_key Tab 3) browser_snapshot 4) browser_console_messages with level error 5) browser_close. Then print four lines: TITLE: the page title; FOCUS: the snapshot line for the button that has focus, verbatim; CONSOLE: the console errors, or none; ERRORS: the exact text of any failed tool call, or none." \
  --model haiku --output-format stream-json --verbose --max-budget-usd 1 --debug-file "$O/debug.log" \
  --settings '{"enabledPlugins":{"dev-workflow@jamesborg":false,"figma@claude-plugins-official":false}}' \
  --allowedTools "${T}_navigate" "${T}_press_key" "${T}_snapshot" "${T}_console_messages" "${T}_close" \
  > "$O/stream.jsonl"
cd "$REPO"
```

Checks:

```sh
S='select(.type=="system" and .subtype=="init")'
jq -r "$S | .mcp_servers[] | select(.name|test(\"playwright\")) | \"\(.name) \(.status)\"" "$O/stream.jsonl"
jq -r "$S | .tools[] | select(startswith(\"mcp__plugin_aew_playwright__\"))" "$O/stream.jsonl" | LC_ALL=C sort > "$O/playwright-tools.txt"
wc -l < "$O/playwright-tools.txt"
for t in navigate snapshot click type press_key select_option hover resize console_messages wait_for close; do
  grep -qx "mcp__plugin_aew_playwright__browser_$t" "$O/playwright-tools.txt" || echo "MISSING browser_$t"
done
jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | "\(.is_error // false) \(.content|tostring|.[0:160])"' "$O/stream.jsonl"
jq -r 'select(.type=="result") | .result' "$O/stream.jsonl"
jq -r 'select(.type=="result") | .total_cost_usd' "$O/stream.jsonl"
git -C "$PROBE" status --porcelain --untracked-files=all    # anything here = the server writes into the project cwd
git -C "$REPO" status --porcelain                           # only this task's edits
grep -i 'playwright' "$O/debug.log" | head -20
```

| check | result | notes |
|---|---|---|
| Server entry and status | pass | `plugin:aew:playwright connected` (init `mcp_servers`); debug: connected over stdio in 1309 ms, server version `1.64.0-alpha-1790635538000` (the bundled playwright). |
| Tool count | pass | 25 `mcp__plugin_aew_playwright__*` names in init (expected at least 11). |
| The eleven expected names present | pass | No `MISSING` line; no renamed tool (fallback 5e not needed). |
| Tool results | pass | Five results, all `is_error` false. The first is a `tool_reference` result (the tools were deferred and loaded by ToolSearch before the first call). |
| Title, focus, console | pass | `TITLE: aew-probe`; `FOCUS: - button "One" [active] [ref=e2]`; `CONSOLE: none`; `ERRORS: none`. |
| Focus marker | `[active]` | After one `Tab`, `browser_snapshot` marks the focused element with `[active]` in its YAML line. No `browser_evaluate` needed (fallback 5c not needed). |
| Browser | default channel (installed Google Chrome) | Navigation succeeded with no browser-not-found error and Google Chrome is installed on this machine (so this does not prove the server works without Chrome). Playwright's own chromium builds also exist in `~/Library/Caches/ms-playwright`. Fallback 5a not taken. |
| Files written to the project cwd | **yes: `.playwright-mcp/`** | `browser_navigate` wrote `.playwright-mcp/page-<timestamp>.yml` into the probe project (its result links it). The probe git status showed only that file. Fallback 5d applies: `ui-qa` setup and the fixture `.gitignore` must ignore `.playwright-mcp/`. |
| Repo `git status --porcelain` after the run | pass | Empty before the docs edits: the server's cwd is the session cwd, not the plugin root. |
| Cost | 0.007 | Ledger row 940. |

Full `mcp__plugin_aew_playwright__*` list (init, 0.0.83):

```
mcp__plugin_aew_playwright__browser_click
mcp__plugin_aew_playwright__browser_close
mcp__plugin_aew_playwright__browser_console_messages
mcp__plugin_aew_playwright__browser_drag
mcp__plugin_aew_playwright__browser_drop
mcp__plugin_aew_playwright__browser_emulate_media
mcp__plugin_aew_playwright__browser_evaluate
mcp__plugin_aew_playwright__browser_file_upload
mcp__plugin_aew_playwright__browser_fill_form
mcp__plugin_aew_playwright__browser_find
mcp__plugin_aew_playwright__browser_handle_dialog
mcp__plugin_aew_playwright__browser_hover
mcp__plugin_aew_playwright__browser_navigate
mcp__plugin_aew_playwright__browser_navigate_back
mcp__plugin_aew_playwright__browser_network_request
mcp__plugin_aew_playwright__browser_network_requests
mcp__plugin_aew_playwright__browser_press_key
mcp__plugin_aew_playwright__browser_resize
mcp__plugin_aew_playwright__browser_run_code_unsafe
mcp__plugin_aew_playwright__browser_select_option
mcp__plugin_aew_playwright__browser_snapshot
mcp__plugin_aew_playwright__browser_tabs
mcp__plugin_aew_playwright__browser_take_screenshot
mcp__plugin_aew_playwright__browser_type
mcp__plugin_aew_playwright__browser_wait_for
```

**qa-engineer Playwright tools**

```
mcp__plugin_aew_playwright__browser_navigate
mcp__plugin_aew_playwright__browser_snapshot
mcp__plugin_aew_playwright__browser_click
mcp__plugin_aew_playwright__browser_type
mcp__plugin_aew_playwright__browser_press_key
mcp__plugin_aew_playwright__browser_select_option
mcp__plugin_aew_playwright__browser_hover
mcp__plugin_aew_playwright__browser_resize
mcp__plugin_aew_playwright__browser_console_messages
mcp__plugin_aew_playwright__browser_wait_for
mcp__plugin_aew_playwright__browser_close
```

### 8.3 Static-shop harness (941, 951)

The harness for the qa-engineer runs (941, 951), reused by the fan-out run (961, D2) and the later runs on 951's
project (E3 to E5). Run section 2's `REPO`/`SMOKE` lines and section 3's `smoke_dispatch` first. Everything
below runs in bash or zsh.

**Prerequisites delta.** Node 20 or later, `npx`, Google Chrome (probe 940: the Playwright MCP uses the installed
Chrome, so it needs no browser install of its own) and a free port 4173. The helper installs the fixture's
dependencies and `@playwright/test`'s chromium itself.

```sh
node --version                         # 20 or later
lsof -nP -iTCP:4173 -sTCP:LISTEN       # must print nothing
```

`smoke_shop` builds a project from the static-shop fixture. It installs dependencies **before** the fixture commit,
so the lock file is committed and `node_modules/` stays ignored (the fixture `.gitignore` covers `node_modules/`,
`.aew/runs/`, `test-results/`, `playwright-report/` and `.playwright-mcp/`). The fixture's `run/` and `run-fanout/`
are removed from the copy; they are the seeds, read from `$SHOP_RUN` and `$SHOP/run-fanout`.

```sh
SHOP="$REPO/tests/fixtures/apps/static-shop"; SHOP_RUN="$SHOP/run"
# smoke_shop <agent> <case> <run-id> <issue> <title> <branch> <stage>   (sets P, RUN, O and P_REAL; leaves $P on <branch>)
smoke_shop() {
  P="$SMOKE/smoke-$1-$2"
  rm -rf "$P" && mkdir -p "$P" || return 1
  cp -R "$SHOP/." "$P" && rm -rf "$P/run" "$P/run-fanout" "$P/node_modules" || return 1   # keep the fixture .gitignore
  (cd "$P" && npm install --no-audit --no-fund --silent && npx playwright install chromium) || return 1
  git -C "$P" init -q -b main && git -C "$P" add -A && git -C "$P" commit -qm fixture || return 1
  git -C "$P" switch -q -c "$6" || return 1
  (cd "$P" && "$REPO/scripts/state.sh" init "$3" --issues "$4" --mode single --title "$5" \
     && "$REPO/scripts/state.sh" set branch "$6" && "$REPO/scripts/state.sh" stage "$7") || return 1
  smoke_use "$1" "$2" "$3" && P_REAL=$(cd "$P" && pwd -P)   # /var symlink
}
TITLE_201=$(jq -r .title "$SHOP_RUN/issue.json")
```

After it runs, `git -C "$P" status --porcelain` must print nothing: that proves the fixture `.gitignore` covers
`node_modules/` and `.aew/runs/`, and that the lock file is committed.

**Fixture ids and table helpers.** TCs are always resolved from the plan at check time, never hard-coded.

```sh
AC_COUNT=AC-1; AC_A11Y=AC-2; AC_EMAIL=AC-4   # confirm against: grep -n 'AC-' "$SHOP_RUN/02-brief.md"; correcting these is a harness fix
# table_col <file> <section title> <column>: cells of that column on TC rows of that section
table_col() { awk -F'|' -v h="## $2" -v c="$3" '/^## /{f=($0==h)} f && $2 ~ /TC-[0-9]+/ {x=$(c+1); gsub(/^[[:space:]]+|[[:space:]]+$/,"",x); print x}' "$1"; }
# tc_for <AC-id> <plan>: TCs in "Test cases" mapped to that AC
tc_for() { awk -F'|' -v ac="$1" '/^## /{f=($0=="## Test cases")} f && $2 ~ /TC-[0-9]+/ && $3 ~ (ac "([^0-9]|$)") {x=$2; gsub(/[[:space:]]/,"",x); print x}' "$2"; }
# qa_failures_complete <report>: exit 0 = QA failures, report complete (as in skills/run-protocol/references/state-machine.md;
# needs valid_return_block, loaded with the eval line in section 4)
qa_failures_complete() {
  [ -f "$1" ] && [ "$(valid_return_block "$1")" = failed ] &&
    awk '/^## /{f=($0=="## Failures")} f && /^\|[[:space:]]*TC-[0-9]+[[:space:]]*\|/{n++} END{exit !(n>0)}' "$1"
}
```

**qa-engineer invocation.** The `ALLOW` line follows `agents/qa-engineer.md` Guardrails (the prompt is the source).
Set it after `smoke_shop` (or `smoke_use`, as E3 does), so `$P` is this project's; the block recomputes `$P_REAL`. `ls`, `find`, `grep`, `head`, `wc` and the
`find test-results ...` read are auto-allowed read-only commands, so they have no rule. The port and issue are the
fixture's 4173 and 201. The `ready_check` is a URL, so the `for i in $(seq 1 60)` loop form is not allowed. The
`--disallowedTools` rules stop `git add *` reaching `-A` and `.`, and block `reset`, `checkout`, pushes and `gh`
(the plugin hook denies `gh` too).

```sh
# phase A (run 941): ls and find are auto-allowed read-only commands, and phase A has no browser, so no rule at all
ALLOW=()
# phase B (run 951 and later); set after smoke_shop or smoke_use (smoke_use does not set P_REAL, so recompute it)
T=mcp__plugin_aew_playwright__browser; P_REAL=$(cd "$P" && pwd -P)
ALLOW=(--allowedTools
  "Bash(npm install *)" "Bash(node --test *)" "Bash(npx playwright *)" "Bash(pnpm add -D -E *)" "Bash(yarn add -D -E *)"
  "Bash(curl *)" "Bash(nohup sh -c *)" "Bash(sh -c *)" "Bash(tail -n 20 *)" "Bash(lsof -ti tcp:4173 -sTCP:LISTEN)" "Bash(kill *)"
  "Bash(rm -rf $P/docs/qa/201/screenshots)" "Bash(rm -rf $P_REAL/docs/qa/201/screenshots)"
  "Bash(AEW_EVIDENCE_DIR=* npx playwright test)" "Bash(AEW_EVIDENCE_DIR=* npx playwright test *)"
  "Bash(mkdir -p *)" "Bash(file -b *)" "Bash(jq *)" "Bash(cp *)"
  "Bash(git status *)" "Bash(git diff *)" "Bash(git log *)" "Bash(git rev-parse *)" "Bash(git add *)" "Bash(git commit *)"
  "${T}_navigate" "${T}_snapshot" "${T}_click" "${T}_type" "${T}_press_key" "${T}_select_option"
  "${T}_hover" "${T}_resize" "${T}_console_messages" "${T}_wait_for" "${T}_close"
  --disallowedTools "Bash(gh *)" "Bash(git add -A*)" "Bash(git add .)" "Bash(git reset *)" "Bash(git checkout *)" "Bash(git push *)")
```

The `AEW_EVIDENCE_DIR=` env-prefixed rules are **unverified**: Claude Code strips only a fixed set of env vars before
matching, so the prefix may need its own pattern. There are two because a trailing ` *` matches the bare command only
when it is the rule's only wildcard, and the §8 evidence run is the bare `commands.test_e2e` (`npx playwright test`).
`nohup` is a wrapper Claude Code strips before matching, so `Bash(sh -c *)` is the documented match for the app start
(the `app.log` redirect is checked as a write inside the project). The app is started by one Bash call with
`run_in_background: true` and no trailing `&`: a command with the `&` operator needs interactive approval and is
refused headless (run 951 attempt 1). A denial of the evidence run or of the `kill` stop in C6 is a harness fault: add
the narrowest matching rule and record the denied command verbatim in the Notes. Dispatch fields:

```sh
smoke_dispatch qa-engineer "run_dir: $RUN, phase: A"        # run 941, CAP=5
smoke_dispatch qa-engineer "run_dir: $RUN, phase: B, n: 1"  # run 951 cycle 1, CAP=8
```

Both use the section 3 invocation block unchanged (`cd "$P" && claude --plugin-dir "$REPO" -p "$DISPATCH" ...`), then
the section 4 checks. Add the CAP to the 8.1 ledger total before starting; if it would pass $60, do not start.

**Per-case setup.**

```sh
# run 941: qa-engineer phase A blindness (cap 5). 05-plan.md, 06-dev-report.md and spec-final.md are traps.
smoke_shop shop phase-a 941 201 "$TITLE_201" feat/201-add-to-basket plan
cp "$SHOP_RUN"/{issue.json,spec-final.md,02-brief.md,03-standards.md,05-plan.md,06-dev-report.md} "$RUN/"   # no 04-qa-test-plan.md
smoke_dispatch qa-engineer "run_dir: $RUN, phase: A"; CAP=5; ALLOW=()

# run 951 cycle 1: qa-engineer phase B (cap 8). Never run another phase-B run at the same time (port 4173).
lsof -nP -iTCP:4173 -sTCP:LISTEN        # must print nothing before the run
smoke_shop shop loop 951 201 "$TITLE_201" feat/201-add-to-basket qa   # fix_cycle 0, so the gate expects 08-qa-report-1.md
cp "$SHOP_RUN"/{issue.json,spec-final.md,02-brief.md,03-standards.md,04-qa-test-plan.md,05-plan.md,06-dev-report.md} "$RUN/"
O="$SMOKE/out-951-qa1"; mkdir -p "$O"
smoke_dispatch qa-engineer "run_dir: $RUN, phase: B, n: 1"; CAP=8      # then set the phase B ALLOW line above
PLAN="$RUN/04-qa-test-plan.md"; R="$RUN/08-qa-report-1.md"; S="$P/docs/qa/201/screenshots"
```

Run 951's project (`$SMOKE/smoke-shop-loop`) is left as the run leaves it for E3 to E5; the cleanup line in section 4
is not run until E7. The fan-out run (D2) calls `smoke_shop` the same way, sets its own `T`/`BR`, and copies
`$SHOP_RUN/03-standards.md` plus `$SHOP/run-fanout/{02-brief,05-plan}.md`.

### 8.4 Results (prompt 04)

Rows are listed `pending` and updated by the task that runs them (C5 941, C6 951 cycle 1). D and E append their own
rows below.

| run | check | result | notes |
|---|---|---|---|
| 940 | MCP tool names, focus marker, files written | pass | See 8.2. |
| 941 | 1 return blocks and template headings | pass | `valid_return_block` prints `ok` for `final.txt` and for `04-qa-test-plan.md`; the `^## ` heading diff against `templates/artefacts/qa-test-plan.md` (ending in `## Files read`) is empty. |
| 941 | 2 AC coverage equals the brief's | pass | The brief's AC set equals the Test cases AC set (diff empty). |
| 941 | 3 test levels valid | pass | No level outside `unit|integration|e2e|UI|manual`. |
| 941 | 4 UI tests cover desktop and mobile | pass | Every UI/e2e TC is in the UI table; every viewport cell names desktop and mobile. |
| 941 | 5 manual-only is exactly `AC-4`, with reasons | pass | Manual-only is exactly `AC-4`; the reason cell is non-empty (order service outside the repo, no email test hook). |
| 941 | 6 accessibility section names axe and the tags | pass | Section names axe at `wcag22aa` expanded to the cumulative tags (`wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`). |
| 941 | 7 blindness: reads (allowlist, traps) | pass | Read attempts (`reads.all`): `.aew/config.json`, `.aew/runs/941/02-brief.md`, `03-standards.md`, `docs/standards/web.md`, `tests/unit/basket.test.js`, plus the plugin template (absolute, under `$REPO`). Outside-project, allowlist and trap greps all empty; no `site/`, `05-plan`, `06-dev-report` or `spec-final` read attempt. |
| 941 | 8 blindness: Bash and browser | pass | Two Bash calls: `find <P>/tests <P>/docs -type f` and `ls <P>`. Neither matches the non-ls/find or forbidden-word greps. No `mcp__plugin_aew_playwright__` tool_use (tools used: Bash 2, Read 6, Write 1). |
| 941 | 9 `## Files read` equals the successful reads | pass | Declared list equals `reads.ok` (diff empty). |
| 941 | 10 shared rows (preload, denials, gate, status, cost) | pass | Preloaded skill lines for `aew:run-protocol`, `aew:ui-qa` and `superpowers:verification-before-completion`; no skip/missing line for them (the only skip lines are unrelated `synced` dir entries). `permission_denials` `[]`. SubagentStop hook: exit 0, outcome success, no `"decision":"block"`. `git -C $REPO status --porcelain` shows only this README; `$P` status clean (apart from `.claude/`). Cost 0.37 (ledger row 941). |
| 951 c1 | 1 `failed`, report complete, headings, SUMMARY | pass | `valid_return_block` prints `failed` for `final.txt` and `08-qa-report-1.md`; `qa_failures_complete` exits 0; the `^## ` headings equal the template's; SUMMARY starts `1/4 automated TCs pass`. |
| 951 c1 | 2 basket bug is `impl_bug` | pass | `tc_for AC-1` is TC-1; its triage row is `impl_bug`. |
| 951 c1 | 3 accessibility defect, email TC untriaged | pass | AC-2 maps to TC-2 and TC-3, both `impl_bug`. `## Accessibility` row `/`: Critical 2, Serious 0 (`button-name`, one node per viewport); `button-name` appears 5 times; TC-5 (AC-4) has no triage row. |
| 951 c1 | 4 triage table in the final message | pass (after fix) | Attempt 1 failed: the final message reworded and extended the Summary cells. Agent fault, fixed in 719f13e (copy rows character for character). Attempt 2: header hit; rows identical to the report's. |
| 951 c1 | 5 `manual-tests.md` format and TC set | pass | Line 1 `## Manual testing required`, no `<!--`, one line matching the TC-5 pattern; TC set equals the plan's Manual-only set (TC-5). |
| 951 c1 | 6 screenshots (names, JPEG) | pass | Exactly TC-{1..4}-{desktop,mobile}.jpg (diff against `screens.expected` empty); all start `ffd8ff`. |
| 951 c1 | 7 specs (titles, no skip/only, evidence env, axe tags) | pass | `tests/e2e/201-add-to-basket.spec.ts` and `aew.ts`; every `test(` is titled `TC-<n>: `; no only/skip/fixme/`waitForTimeout`; `AEW_EVIDENCE_DIR` in `aew.ts`; all five cumulative tags present. |
| 951 c1 | 8 no `report.md` yet | pass | `docs/qa/201/report.md` absent. |
| 951 c1 | 9 QA commit (A14) | pass | One commit `test(e2e): QA specs and evidence for add to basket (#201)`; no file outside the allowed set; nothing under `site/`; `$P` status clean apart from `.claude/`. |
| 951 c1 | 10 app lifecycle (port freed) | pass | Reuse `curl` (exit 7), start, ready `curl --retry`, then `lsof -ti`, `kill <pid>`, `lsof -ti` (empty); port 4173 free after the run. Decision 9: the app started with `run_in_background: true` survived across tool calls (ready check, tests and MCP all reached it). |
| 951 c1 | 11 exploratory MCP checks | pass | Subagent used `browser_navigate` (2), `browser_resize` (2), `browser_console_messages`, `browser_snapshot`, `browser_press_key`, `browser_close`; the report has the `**Exploratory checks (Playwright MCP)**` label. Server `plugin:aew:playwright connected`. |
| 951 c1 | 12 commands recorded | pass | `## Commands and output` has `node --test` (1 test, 0 fail) and the `npx playwright test` evidence run (6 failed, 2 passed), each with an excerpt. |
| 951 c1 | 13 shared rows (preload, denials, gate 08-qa-report-1, status, cost) | pass (after fix) | Preload: `aew:run-protocol`, `aew:ui-qa`, `superpowers:verification-before-completion`, no skip/missing lines. `permission_denials` `[]` on attempt 2. SubagentStop: exit 0, success, no block. Return block valid; template headings match. `git -C $REPO status` shows README only. Cost 0.57 (attempt 2). Attempt 1 failed here: two denials of the `nohup ... &` form (`&` needs interactive approval headless; the agent recovered with `run_in_background`). Agent/skill fault, fixed in 719f13e (ui-qa section 3 and qa-engineer Guardrails: no trailing `&`). |
| 941 | re-run after fix 719f13e | pass | Checks 1 to 10 re-run: `ok` return blocks, headings, AC coverage, manual-only AC-4, blindness allowlist and Bash (one `find`), Files read equal, preload, `[]` denials, gate success. Cost 0.35. |
| 941 | re-run after fix d4b2c86 | pass | The E3 review required this re-run because d4b2c86 edited a Guardrails bullet (a shared section). Fresh `smoke_shop shop phase-a 941`, checks 1 to 10 as in C5: `ok` return blocks and empty heading diff; AC coverage equal; levels valid; every UI TC (TC-1 to TC-4) in the UI table with desktop and mobile; manual-only exactly `AC-4` with a reason; accessibility names axe and the cumulative tags; reads (`reads.all`) are `.aew/config.json`, `02-brief.md`, `03-standards.md`, `docs/standards/web.md`, `tests/unit/basket.test.js` and the plugin template, with the outside-project, allowlist and trap greps empty; one Bash call (`find <P>/tests <P>/docs -type f`), no `mcp__plugin_aew_playwright__` use (Bash 1, Read 6, Write 1); Files read equals `reads.ok`; preload lines for the three skills and no skip line; `permission_denials` `[]`; SubagentStop hook success, exit 0, no block; `$REPO` and `$P` status clean. Cost 0.34. |

Notes for run 951 cycle 1 (kept state for Phase E):

- Project `$SMOKE/smoke-shop-loop` (stage `qa`, `fix_cycle` 0, branch `feat/201-add-to-basket`, QA's cycle-1 commit); outputs in `$SMOKE/out-951-qa1` (`screens.cycle1`, `head.cycle1` = `828ba57e6359d6d5eef76d9d26578a4d58927f40`).
- TCs per AC: AC-1 TC-1; AC-2 TC-2, TC-3; AC-4 TC-5 (manual); TC-4 passes.
- Triage rows: TC-1 AC-1 `impl_bug`; TC-2 AC-2 `impl_bug`; TC-3 AC-2 `impl_bug`.
- `screens.cycle1` mtimes (epoch seconds): TC-1 1792875850, TC-2 1792875855, TC-3 and TC-4 1792875856, desktop and mobile alike.
- Attempt 1's outputs are not kept: attempt 2 wrote to the same `out-951-qa1`. Its two failures are recorded in rows 4
  and 13. Likewise `out-941` now holds the 941 re-run, not the run recorded in the first 941 rows.

#### 961: developer `full` mode fan-out (D2)

Setup, dispatch and invocation are section 8.3's `smoke_shop` and section 3's command, with these differences. Write the run into a script file and execute that file: the plugin's Bash safety hook blocks any command whose text contains `git push`, and redirect stdin with `< /dev/null`. `smoke_use` does not clear `$O`, so `rm -rf "$O"` first when re-running.

```sh
T="Add shop helpers"; BR=feat/202-add-shop-helpers
smoke_shop developer fanout 961 202 "$T" "$BR" develop
cp "$SHOP_RUN/03-standards.md" "$SHOP/run-fanout/02-brief.md" "$SHOP/run-fanout/05-plan.md" "$RUN/"
git -C "$P" rev-parse main > "$O/main.sha"; (cd "$P" && pwd -P) > "$O/p.real"
# Harness-only; not safe to copy into user settings (see project-map open items for prompt 05).
# ALLOW follows agents/developer.md Guardrails. No bare "Bash(git -C *)": one scoped rule per subcommand.
ALLOW=(--allowedTools "Bash(git status *)" "Bash(git diff *)" "Bash(git log *)" "Bash(git show *)"
  "Bash(git add *)" "Bash(git commit *)" "Bash(git worktree *)" "Bash(git cherry-pick *)"
  "Bash(git branch *)" "Bash(git rev-parse *)"
  "Bash(git -C * status *)" "Bash(git -C * diff *)" "Bash(git -C * log *)" "Bash(git -C * show *)"
  "Bash(git -C * add *)" "Bash(git -C * commit *)" "Bash(git -C * rev-parse *)"
  "Bash(cd *)" "Bash(node *)" "Bash(npm *)" "Bash(npx *)" "mcp__plugin_context7_context7__*")
smoke_dispatch developer "run_dir: $RUN, mode: full"; CAP=10
SETTINGS=$(jq -nc --arg ex "$REPO/CLAUDE.md" --arg cap "cat >> '$O/stop-payloads.jsonl'; echo >> '$O/stop-payloads.jsonl'" \
  '{claudeMdExcludes:[$ex], enabledPlugins:{"dev-workflow@jamesborg":false,"figma@claude-plugins-official":false},
    hooks:{SubagentStop:[{hooks:[{type:"command",command:$cap}]}]}}')
# then section 3's claude -p command with --settings "$SETTINGS" in place of the inline JSON, and < /dev/null
```

The capture hook has no matcher, so it records every `SubagentStop`; it runs alongside the plugin's gate, which still decides. The `node --test` summary in Node 26 is `ℹ pass <n>` (the spec reporter), not the TAP `# pass <n>` line, so count with `grep -E '^ℹ (pass|fail)'`.

Attempts: 1 failed S3 (`cd <worktree> && git …` refused), 2 failed S13 (two `git -C <main checkout>` denials), 3 passed all checks. Final run ids and costs are in the 8.1 ledger.

| run | check | result | notes |
|---|---|---|---|
| 961 | S1 fan-out in one message | pass | The developer's own tool calls are in the stream (source: stream, `parent_tool_use_id` = the main Agent call). Two `Agent` blocks under the same `message.id`, both `aew:developer`, `isolation` absent, prompts `run_dir: <abs>, mode: package, wp: WP-1\|WP-2, worktree: $RUN/worktrees/WP-<n>, branch: aew/961/wp-<n>`. |
| 961 | S2 worktree commands | pass | `git worktree add -b aew/961/wp-1 $RUN/worktrees/WP-1 HEAD` and the same for `wp-2`. Caveat: the feature branch equals `main` at dispatch, so only this verbatim command evidences "from HEAD"; S4 to S7 cannot tell a HEAD worktree from a default-branch one. |
| 961 | S3 sub-developer command form | pass (after fix) | Attempt 1: all four `cd <worktree> && git …` commands were denied although `Bash(cd *)` and the git rules were allowed. The Bash tool's built-in check ("changes directory before a version-control command, which can pick up untrusted hooks or repository configuration") cannot be allowlisted. Both sub-developers returned `blocked`. Agent fault, fixed in 7960b92: git runs as `git -C <worktree> <subcommand>`, other commands as `cd <worktree> && <command>`. Attempt 3: 0 `cd … && git` commands; git via `git -C <worktree> status\|rev-parse\|add\|commit`; `cd <worktree> && node --test` ran without denial; nothing ran outside a worktree. **Open item for prompt 05's permission proposal: the per-subcommand `git -C` fallback is in force (`Bash(git -C * status *)`, `diff`, `log`, `show`, `add`, `commit`, `rev-parse`; never a bare `Bash(git -C *)`).** |
| 961 | S4 WP reports | pass | `06-dev-report-WP1.md` and `-WP2.md`: `Mode: package`, valid return block `ok`, template headings match, filled `## Commands run`. WP shas `3efa42a` and `7d8d435` are commit objects whose subjects equal the integrated commits'. |
| 961 | S5 parent report | pass | `06-dev-report.md`: `Mode: full`, `ok`, headings match, newest `06-dev-report*.md`; WP rows carry `3da7027` and `53aab59` (the `main..HEAD` shas); `node --test` row passes (3 tests). |
| 961 | S6 commits | pass | Exactly two commits in WP order: `feat(price): add formatPrice helper (#202)`, `feat(basket): add clampQuantity helper (#202)`. Non-matching subjects 0, `cherry picked from` 0, each commit touches exactly its WP's files (both diffs empty). |
| 961 | S7 clean-up | pass | One worktree (the main one, equal to `p.real`), no `aew/*` branch, no `$RUN/worktrees` content, status empty, HEAD `feat/202-add-shop-helpers`, `main` unchanged. |
| 961 | S8 harness re-run | pass | `node --test`: pass 3, fail 0 (basket, formatPrice, clampQuantity); status still empty. |
| 961 | S9 final message | pass | `final.txt` (narrowed to the main Agent call) is a valid block, `STATUS: ok`, ARTEFACTS `.aew/runs/961/06-dev-report.md`. |
| 961 | S10 gate (AC-23) | pass | Six `SubagentStop` hook responses (three stops, two hooks each: the capture hook and the plugin gate), all `outcome: success`, exit 0, none with `"decision":"block"`. The parent's stop, which followed a valid report written last, was allowed. No mis-block, so **D3 is not triggered**. |
| 961 | S11 nested `SubagentStop` | recorded | See the table below. |
| 961 | S12 agent hygiene | pass | No `isolation`; no Agent call under either sub-developer; no Bash command with `gh`, a push, merge, rebase, reset, checkout, switch, `cherry-pick -x` or `rm -r`. |
| 961 | S13 per-run rows | pass (after fix) | Preload: `aew:run-protocol`, `superpowers:test-driven-development`, `superpowers:verification-before-completion` and `superpowers:systematic-debugging` each appear 3 times under `[Agent: aew:developer]` (parent plus both sub-developers preload them); no skip or missing line for them. `permission_denials` `[]` (attempt 2 had two `git -C <main checkout>` denials, agent fault, fixed in db2dc9e: plain `git` in the main checkout). `git -C $REPO status --porcelain` shows only this README, DESIGN and the prompt fixes. Cost 0.79 (ledger). |

Nested `SubagentStop` observation (A29, AC-23), from `stop-payloads.jsonl` (Claude Code 2.1.308, attempt 3):

| stop | `agent_type` | `agent_id` | `stop_hook_active` | ARTEFACTS in `last_assistant_message` | gate decision |
|---|---|---|---|---|---|
| sub-developer WP-1 | `aew:developer` | `a1c63030e4d8602e2` | false | absolute path to `06-dev-report-WP1.md` | allowed (exit 0) |
| sub-developer WP-2 | `aew:developer` | `a0580a63bc10e2c52` | false | absolute path to `06-dev-report-WP2.md` | allowed (exit 0) |
| parent developer | `aew:developer` | `a38ccb8541a2446b8` | false | `.aew/runs/961/06-dev-report.md` | allowed (exit 0) |

Nested sub-developers do fire `SubagentStop`, with the same `agent_type` as the parent and distinct `agent_id`s; the debug log shows the plugin gate running for each of the three stops. The gate resolves the main worktree's run dir and each sub-developer wrote its own report before stopping, so the newest-report rule did not mis-block anyone in this run (the WP reports were written at different times, each before its own stop; the parent's report came last). A29's fallback (gate the report named in ARTEFACTS) is not needed.

#### 951: developer fix, then QA cycle 2 (E3)

Both steps run from `smoke_use shop loop 951` on the kept cycle-1 project. `smoke_use` sets `O=out-951` and does not clear it, so each step sets `O` itself (`out-951-fix1`, `out-951-qa2`). Each step is a script file (not inline Bash: the plugin hook blocks command text containing `git push`) with `< /dev/null`; it snapshots `$P` with `cp -Rp` to `snap-951-fix1` / `snap-951-qa2` first, so a re-run restores the same state, and it checks that port 4173 is free. Step 1 records `C1=$(git rev-parse HEAD)` (`828ba57`) and runs `state.sh bump fix_cycle` then `state.sh stage develop`; step 2 runs `state.sh stage qa`.

```sh
# step 1: developer ALLOW = the 961 developer line above, plus the ui-qa app lifecycle (the Skill call to aew:ui-qa needed no allow entry)
ALLOW+=("Bash(curl *)" "Bash(nohup sh -c *)" "Bash(sh -c *)" "Bash(tail -n 20 *)" "Bash(lsof -ti tcp:4173 -sTCP:LISTEN)" "Bash(kill *)")
smoke_dispatch developer "run_dir: $RUN, mode: fix, n: 1, fix_from: 08-qa-report-1.md"; CAP=5
# step 2: the phase B ALLOW line of section 8.3 (it now includes "Bash(cp *)"), P_REAL recomputed
smoke_dispatch qa-engineer "run_dir: $RUN, phase: B, n: 2"; CAP=8
```

Both used the 961 `SETTINGS` capture hook for `SubagentStop` payloads.

| run | check | result | notes |
|---|---|---|---|
| 951 fix | F1 fix commits | pass | `C1..HEAD` is two commits, both matching `^fix\([^)]+\): .+ \(#201\)$`: `54d1046 fix(basket): write the count into the status text (#201)` (`site/app.js`, TC-1) and `004fd43 fix(basket): name the icon-only basket button (#201)` (`site/index.html`, TC-2 and TC-3). One commit per root cause. |
| 951 fix | F2 no `tests/e2e/` change | pass | `git diff --name-only C1 HEAD` is `site/app.js`, `site/index.html` only. |
| 951 fix | F3 report | pass | `06-dev-report.md` has `Mode: fix (cycle 1)`, filled `## Commands run` (node --test pass; `npx playwright test tests/e2e/201-add-to-basket.spec.ts` without `AEW_EVIDENCE_DIR`: 8 passed), headings equal the template's, valid return block `ok`; `final.txt` is `ok` with NEXT `qa-engineer phase B (cycle 2)`. |
| 951 fix | F4 fix-mode process | pass | Read `08-qa-report-1.md`; the `aew:ui-qa` Skill call worked headless with no allow entry; app started with `nohup sh -c` (no trailing `&`), ready `curl --retry`, `lsof -ti` then `kill <pid>`; port free after. No `frontend-design` call, no Agent call. |
| 951 fix | F5 gate allow (AC-23) | pass | `stop-payloads.jsonl`: one `SubagentStop`, `agent_type` `aew:developer`; the plugin gate finished with status 0; no `"decision":"block"` in the debug log or stream. |
| 951 fix | F6 shared rows | pass | Preloaded `aew:run-protocol` and the three superpowers skills; no skip line; `permission_denials` `[]`; `$REPO` status clean; cost 0.47. |
| 951 c2 | Q1 return blocks and headings | pass (after fix) | Attempt 1: `final.txt` and `08-qa-report-2.md` valid `ok`, headings equal the template's, all four automated TCs pass at both viewports, but `docs/qa/201/report.md` was missing. Cause: Claude Code refuses a subagent's `Write` of a file named `report.md` ("Subagents should return findings as text, not write report files"); `08-qa-report-2.md` is not refused. Agent fault, fixed in d4b2c86: step 13 copies with one `cp`, the Guardrails allow that `cp`, ui-qa section 10 says why; the harness `ALLOW` gains `Bash(cp *)`. Attempt 2 (restored `snap-951-qa2`): valid `ok`, headings equal. |
| 951 c2 | Q2 report content | pass | Results: TC-1 to TC-4 `pass (desktop, mobile)`, TC-5 `manual`; 8 passed in the evidence run; axe 0 violations at `wcag22aa` on both viewports; the `Exploratory checks (Playwright MCP)` label is present. |
| 951 c2 | Q3 `docs/qa/201/report.md` | pass (after fix) | Present after attempt 2 and `cmp`-identical to `08-qa-report-2.md`; part of QA's commit. |
| 951 c2 | Q4 `manual-tests.md` | pass | Still one TC-5 line (the confirmation email), unchanged format. |
| 951 c2 | Q5 overwrite (CTO cut 1) | pass | Screenshot names equal cycle 1's (`TC-{1..4}-{desktop,mobile}.jpg`, no stale file); `find ... ! -newer out-951-qa1/stream.jsonl` prints nothing; all eight are JPEGs by `file -b` (four 1440x900, four 390x844). |
| 951 c2 | Q6 commit and tree | pass | `36fd498 test(e2e): QA pass and final evidence for add to basket (#201)`; changes `docs/qa/201/report.md` and the four JPEGs of the TCs the fix changed (TC-1, TC-2; the others were byte-identical); no `tests/e2e/` or `site/` change; `$P` status clean; HEAD to `C1` is the two fix commits plus this one. |
| 951 c2 | Q7 app lifecycle and gate | pass | Reuse `curl`, start, ready `curl`, `lsof -ti`, `kill`, `lsof -ti` (empty); port free. qa-engineer `SubagentStop`: gate status 0, no block; `permission_denials` `[]`; preload shows the three skills, no skip line; `$REPO` status clean. Cost 0.36 (attempt 2); attempt 1 cost 0.54. |

Notes for E4 and E5:

- Final state of `$SMOKE/smoke-shop-loop` (kept for the doc-writer): stage `qa`, `fix_cycle` 1, HEAD `36fd498`, branch `feat/201-add-to-basket`, `docs/qa/201/report.md` present, `.aew/runs/951` holds `06-dev-report.md` (fix), `08-qa-report-1.md`, `08-qa-report-2.md`, `manual-tests.md`. Outputs: `out-951-fix1`, `out-951-qa2` (attempt 2; attempt 1's was overwritten by the script's `rm -rf "$O"`). Snapshots `snap-951-fix1` (cycle-1 state) and `snap-951-qa2` (after the developer fix, stage `develop`).
- The two fix commits and QA's commit carry a `Co-Authored-By: Claude Sonnet 5.5` trailer. The developer prompt says no co-author trailer, but the headless session's harness attribution instruction asked for one and the developer followed it, noting the conflict in its Deviations. The trailer sits in a second `-m`, so the allowlisted command form held and the subjects match. Open item for prompt 05 (attribution policy), not a check failure.
- A subagent's `Write` of a file named `report.md` is refused by Claude Code. In 2.1.308 the check sits in the Write tool's input validation, applies only to subagents, and refuses any basename matching `/^(REPORT|SUMMARY|FINDINGS|ANALYSIS).*\.md$/i` (so `08-qa-report-2.md` passes); Edit and Bash carry no such check. The doc-writer's outputs (`10-summary.md`, `pr-body.md`, `retro.md`, `<issue>-<slug>.md`, `CLAUDE.md`) do not match, so E4 needs no fallback.
- The `Mode: fix` developer needed no `Bash(git -C ...)` rule: it works in the main checkout.
- Fix d4b2c86 edits qa-engineer's phase B step 13 and one phase B bullet of its Guardrails. Because Guardrails is a shared section, run 941 (phase A, which has no Bash) was re-run after it: see the `941 | re-run after fix d4b2c86` row (pass). Cycle 1 is never re-run for E's sake.

#### 951: doc-writer (E4)

Runs on the kept `smoke-shop-loop` project: `smoke_use shop loop 951`, then `O="$SMOKE/out-951-docs"` (cleared first), `cp -Rp "$P" "$SMOKE/snap-951-docs"` (a re-run restores that copy to `$P`), `H=$(git -C "$P" rev-parse HEAD)` (`36fd498`), `claude_md.max_lines` from `$P/.aew/config.json` (40), `state.sh stage docs`, then `smoke_dispatch doc-writer "run_dir: $RUN"` with `ALLOW=()` (no Bash, so no `--allowedTools`) and `CAP=5`. The section 3 command is used unchanged, from a script file with `< /dev/null`. The `CLAUDE.md` before the run is copied to `$O/CLAUDE.before` for the diff checks. The planted lines are the two the B2 fixture put in `CLAUDE.md`: ``- Prefer `const` over `let`, and never use `var`.`` (a `web.md` duplicate) and `- Until 2026-11-30 the sale banner copy is frozen, so do not edit it.` (time-bound).

Note for the removed-lines check: a removed bullet shows in `git diff -U0` as `-- text`, so the extraction is `grep -E '^-' | grep -v '^--- ' | sed 's/^-//'`, not `grep -E '^-[^-]'`.

| run | check | result | notes |
|---|---|---|---|
| 951 docs | D1 `CLAUDE.md` size and change | pass | `wc -l` 19 (was 37), cap 40; `git diff --quiet -- CLAUDE.md` exits 1 (4 insertions, 22 deletions). |
| 951 docs | D2 planted lines gone | pass | `grep -Fx` finds neither planted line. |
| 951 docs | D3 no added line restates a standards rule | fail | `grep -Fxf` of the four added lines against `docs/standards/*` prints nothing. Per-line verdicts against `web.md`: the intro line (existing sentence plus a link to `web.md`) is a pointer, fine; the `AEW_EVIDENCE_DIR` capture command is in neither `web.md` nor the code, so it is a real learning; the no-order-flow line (rewritten, now linking the spec) is not in `web.md`. Fail: "Unit tests: `node --test`. End-to-end specs: `npx playwright test` (the app must be running)." restates two `web.md` Tooling rules ("Run unit tests with `node --test`", "Run end-to-end specs with `npx playwright test`"); only "the app must be running" is new (true: `playwright.config.ts` has no `webServer`). The curator merged two standards duplicates (skill section 6 step 3) instead of dropping them under step 2. Agent/skill fault; fix and re-run from `snap-951-docs`. |
| 951 docs | D4 every removal listed in `10-summary.md` | fail | 20 removed non-blank lines. 19 are listed in the Summary verbatim or reworded with a reason (one merged pair, one whole Conventions section). The intro sentence "Project memory for the static-shop site. Keep it under 40 lines." was kept but rewritten (a pointer to `web.md` added), so the diff shows it removed, and the Summary does not list it. `claude-md-curation` section 7 requires every removed or rewritten entry to be reported with its original text, so this is an agent fault, not a judgement call: the doc-writer prompt says only "removal" (Process steps 3 and 4, Definition of done). Fix and re-run from `snap-951-docs`. |
| 951 docs | D5 no over-pruning | pass | What went: lines that `web.md` states (install, Node 22, ES modules over HTTP, spec naming, integer pence, landmarks, accessible names, comments, const/var, file layout), `serve` caching (obvious) and the dated freeze. What stayed: no `npm install` in `site/`, the separate `playwright install chromium`, screenshots to `docs/qa/`, and the order-service fact, none of which `web.md` has. Nothing `web.md` lacks was dropped. Under-pruning, not a planned check: the kept "Serve the site: `npm start` (`serve -l 4173 site`), then open `http://localhost:4173`." restates `web.md`'s "serve the site with `npm start` (`serve -l 4173 site`), which listens on port 4173", although the curator dropped the install half of the same `web.md` bullet. |
| 951 docs | D6 spec snapshot | pass | Exactly one `docs/specs/201-add-to-basket.md`, equal to `201-` plus the kebab-cased title "Add to basket"; its `##` headings are Spec, Revision history, Key decisions, Traceability, Outstanding manual tests, in order; the brief's AC bullets (AC-1 to AC-4) equal the Traceability AC column (diff empty); the AC-4 row points to `manual-tests.md`. |
| 951 docs | D7 `pr-body.md` | pass | `grep -c '<!--'` is 0; `Closes #201`; eight screenshot links, all matching `https://github.com/acme/static-shop/blob/feat/201-add-to-basket/docs/qa/201/screenshots/TC-<n>-(desktop\|mobile).jpg?raw=true` (owner and repo from `issue.json` `.url`, branch from `state.json`); the linked file set equals the eight files in `docs/qa/201/screenshots/`. |
| 951 docs | D8 `10-summary.md` and `retro.md` | pass | `^## ` headings equal the templates' (summary, pr-body, retro). `valid_return_block` prints `ok` for `final.txt` and `10-summary.md`; ARTEFACTS lists the five paths. `retro.md` has three `###` items, all plugin-not-project: the developer agent not checking its diff against the plan and the standards anti-patterns, the developer commit trailer versus the harness attribution reminder, and the doc-writer templates having no checkbox rule for a manual AC. The first reads close to a run-specific mistake but its improvement targets the developer prompt, so it passes. |
| 951 docs | D9 no commit, scoped writes | pass | `git rev-parse HEAD` equals `36fd498`. `git status --porcelain --untracked-files=all` shows ` M CLAUDE.md`, `?? docs/specs/201-add-to-basket.md` and the two files under `.claude/agent-memory/aew-doc-writer/`, and nothing else. |
| 951 docs | D10 shared rows | pass | Preloaded skill lines for `aew:run-protocol` and `aew:claude-md-curation`, no skip or missing line; `permission_denials` `[]`; no `Write` was refused (no fallback needed, so the Write basename rule from the E3 notes did not bite); tools used: Read 17, Write 7, Glob 2 (no Bash, Edit or Agent); the plugin's `SubagentStop` matcher is `^aew:(developer\|qa-engineer)$`, so no gate ran for the doc-writer, as designed; `$REPO` status clean. Cost 0.44 (ledger). |

Re-runs, each restored from `snap-951-docs` into `$P`, output to a fresh `out-951-docs`, same dispatch and cap 5. The removed-lines extraction for D4 is the one in the note above, with blank lines dropped, and each line is looked up with `grep -F` in the Summary of `10-summary.md`.

Re-run 1 (after fix `f2df416`: doc-writer reports removed, merged or rewritten entries; curation step 3 re-checks merged entries):

| run | check | result | notes |
|---|---|---|---|
| 951 docs re-run 1 | D1 | pass | `wc -l` 24 (was 37), cap 40; diff non-empty. |
| 951 docs re-run 1 | D2 | fail | The dated freeze line "Until 2026-11-30 the sale banner copy is frozen..." was kept (the Summary justified it by its expiry date). The skill's never-include list says "dates" are time-bound, but the curator read "no removal condition" as excusing it. Skill fault. The const/var line went. |
| 951 docs re-run 1 | D3 | pass | No added line is in `docs/standards/*`; the added evidence-dir line is not in `web.md`. |
| 951 docs re-run 1 | D4 | fail (mechanical) | Line count stated (24) equals `wc -l`, and the rewritten intro line is now listed. But with `grep -F` on the lines as extracted (leading `- `), 17 of 18 are not found, because the Summary quoted them without the bullet marker; the content was all listed. The mechanical check is kept as written, so the fix makes the skill require the exact original line. |
| 951 docs re-run 1 | D5 to D10 | pass | D6 to D10 as in the first run (`pr-body` 0 comments, `Closes #201`, 8 links; headings equal; HEAD unchanged; scoped writes; `permission_denials` `[]`; cost 0.33). |

Re-run 2 (after fix `48cb638`: curation drops any entry carrying a date or expiry; section 7 quotes each original entry exactly including its leading `- `, and reports a moved entry as rewritten):

| run | check | result | notes |
|---|---|---|---|
| 951 docs re-run 2 | D1 | pass | `wc -l` 27 (was 37), cap 40; `git diff --quiet -- CLAUDE.md` exits 1. |
| 951 docs re-run 2 | D2 | pass | `grep -Fx` finds neither planted line. |
| 951 docs re-run 2 | D3 | pass | `grep -Fxf` of the added lines against `docs/standards/*` prints nothing. Added: the `web.md` pointer line, a rewritten order-flow line (adds the manual-test consequence and the spec link) and the `AEW_EVIDENCE_DIR` capture line (not in `web.md`; it names `npx playwright test` only as the command the variable applies to, not as a rule). |
| 951 docs re-run 2 | D4 | pass | 13 removed non-blank lines by the mechanical extraction, every one found with `grep -F` in the Summary; stated count 27 equals `wc -l`. Entries are quoted with their `- ` and the two rewrites show the new text. |
| 951 docs re-run 2 | D5 | pass | Nothing `web.md` lacks was dropped (removed: ES modules, spec naming, file layout, integer pence, const/var, landmarks, accessible names, comments, the update-this-file line, the dated freeze). Under-pruning remains: the curator kept the Install, Serve, `node --test`, `npx playwright test` and Node 22 lines, which `web.md` Tooling states; not a planned check, recorded as a concern. |
| 951 docs re-run 2 | D6 | pass | One `docs/specs/201-add-to-basket.md`; five `##` headings in order; AC diff empty; AC-4 row points to `manual-tests.md`. |
| 951 docs re-run 2 | D7 | pass | 0 template comments; `Closes #201`; eight links all matching the `blob/<branch>/...?raw=true` form; link set equals the eight files. |
| 951 docs re-run 2 | D8 | pass | Headings equal for summary, pr-body and retro; `valid_return_block` `ok` for `final.txt` and `10-summary.md`; ARTEFACTS lists the five paths; three plugin-level `###` retro items. |
| 951 docs re-run 2 | D9 | pass | HEAD unchanged; status shows ` M CLAUDE.md`, `docs/specs/201-add-to-basket.md` and two files under `.claude/agent-memory/aew-doc-writer/`, nothing else. |
| 951 docs re-run 2 | D10 | pass | Preloaded `aew:run-protocol` and `aew:claude-md-curation`; `permission_denials` `[]`; no `"decision":"block"`; tools Read 16, Write 7, Glob 2, Grep 1; `$REPO` status clean. Cost 0.31 (ledger). |

Notes for E5:

- The first-run rows above are history. The final state is re-run 2: every D row passes.
- (First run) D3 and D4 failed in the senior review. E4 is open until a `fix(agents)` commit to `agents/doc-writer.md` and `skills/claude-md-curation/SKILL.md` and a re-run restored from `snap-951-docs` pass every D row; the rows above record the first run. The first run's Summary also says the curated file "now has 20 lines" (and SUMMARY "37 to 20"); it has 19.
- `smoke-shop-loop` is left as the doc-writer left it: stage `docs`, HEAD `36fd498`, uncommitted `CLAUDE.md`, `docs/specs/201-add-to-basket.md` and the agent memory, plus `10-summary.md`, `pr-body.md` and `retro.md` under `.aew/runs/951/`. Snapshot `snap-951-docs` holds the pre-run state (stage `qa`); outputs are in `out-951-docs`.
- The doc-writer's `ARTEFACTS` order differs from the template's but lists exactly the five paths.

#### 971 and 972: report-less gate probes (E5, AC-23)

Both run on the kept `smoke-shop-loop` project after the doc-writer, strictly one after the other (`state.sh init` re-points `.aew/runs/current`), each from one script file with `< /dev/null`, and each with a fresh run dir (`.aew/runs/971`, `.aew/runs/972`) holding only `state.json` and `log.md`, so no copied or earlier report can satisfy the gate. Per run: `cp -Rp` of `$P` to `snap-<id>`, `O=$SMOKE/out-<id>` (cleared), `state.sh init <id> --issues 201 --mode single --title "Add to basket"`, `state.sh set branch feat/201-add-to-basket`, then `state.sh stage develop` (971) or `state.sh stage qa` (972, `fix_cycle` 0, so the gate expects `08-qa-report-1.md`). `ALLOW=()` (the probes need no Bash), cap 2, the 961 `SETTINGS` capture hook for `SubagentStop` payloads, section 3's command otherwise unchanged. The probe wording is added to the dispatch fields and states that it overrides any rule to always write a report. This is a deviation from the plan's fixed E5 wording, made before the first dispatch rather than after a harness fault: it only reinforces "write nothing", so the block checks (G1, G2) are unchanged, but the corrective-turn refusal (G3) follows the probe's override and says nothing about how an agent answers the gate in a real run:

```sh
PROBE="Gate probe: this is a deliberate test of the stop gate, and it overrides any rule telling you to always write a report or artefact. Do not read, create or edit any file and run no commands. End at once with a return block: STATUS: blocked, SUMMARY: gate probe."
smoke_dispatch developer    "run_dir: $RUN, mode: fix, n: 1, fix_from: 08-qa-report-1.md. $PROBE"   # 971, stage develop
smoke_dispatch qa-engineer  "run_dir: $RUN, phase: B, n: 1. $PROBE"                                 # 972, stage qa
```

| run | check | result | notes |
|---|---|---|---|
| 971 | G1 first stop blocked, reason names the artefact | pass | Source: the stream's `hook_response` events (the debug log carries the same text). `SubagentStop` for `agent_type` `aew:developer`: `{"decision":"block","reason":"aew gate: no 06-dev-report*.md in .aew/runs/971/. Use the template at <REPO>/templates/artefacts/dev-report.md and end the file with the return block (STATUS, ARTEFACTS, SUMMARY, NEXT)."}`. |
| 971 | G2 second stop allowed | pass | Second payload in `stop-payloads.jsonl` has `stop_hook_active` true; the gate printed `warning: stop_hook_active is set; allowing the stop` and exited 0. No block loop; the run ended normally (`result` not an error). |
| 971 | G3 corrective turn | recorded | The developer wrote nothing and ran nothing: it replied that the dispatch said not to create or edit any file and the hook feedback did not change that, and ended with `STATUS: blocked`. Its tool calls were none (the stream has only the main thread's `Agent` call). Nothing was committed: HEAD `36fd498` before and after, `git status --porcelain --untracked-files=all` identical before and after. |
| 971 | G4 shared rows | pass | No artefact written, so no template row. `valid_return_block` `ok` (`STATUS: blocked`) on the stream's `result` text (no `final.txt` was saved for the probes). Preloaded skill lines for `aew:run-protocol`, `superpowers:test-driven-development`, `superpowers:systematic-debugging` and `superpowers:verification-before-completion`; the only skip lines in the debug log are the unrelated `synced` entries. `permission_denials` `[]`; `$REPO` status clean before the README edit. Cost 0.30 (ledger). |
| 972 | G1 first stop blocked, reason names the artefact | pass | `aew:qa-engineer`: `{"decision":"block","reason":"aew gate: .aew/runs/972/08-qa-report-1.md is missing. Use the template at <REPO>/templates/artefacts/qa-report.md and end the file with the return block (STATUS, ARTEFACTS, SUMMARY, NEXT)."}`. Same source as 971. |
| 972 | G2 second stop allowed | pass | Second payload has `stop_hook_active` true; the gate allowed it (same warning, exit 0). One `stop_hook_active is set` line in the debug log. |
| 972 | G3 corrective turn | recorded | The qa-engineer wrote nothing and ran nothing: it said it was leaving `08-qa-report-1.md` unwritten because the dispatch forbade creating files, and ended `STATUS: blocked`. No tool calls from it, HEAD `36fd498` unchanged, status identical before and after, port 4173 untouched. |
| 972 | G4 shared rows | pass | No artefact written, so no template row. `valid_return_block` `ok` (`STATUS: blocked`) on the stream's `result` text, as for 971. Preloaded skill lines for `aew:run-protocol`, `aew:ui-qa` and `superpowers:verification-before-completion`; the only skip lines are the unrelated `synced` entries. `permission_denials` `[]`; `$REPO` status clean before the README edit. Cost 0.28 (ledger). |

AC-23 notes:

- **Block half:** proven by 971 (developer, `06-dev-report*.md` missing) and 972 (qa-engineer at stage `qa`, `08-qa-report-1.md` missing), above. The stage `plan|qa_test_plan` branch (`04-qa-test-plan.md`) is covered by the bats suite, not by a paid run.
- **Allow half:** earlier runs, all with a valid artefact written before the stop and no `"decision":"block"`: 941 (qa-engineer phase A, row 10), 951 cycle 1 (row 13), 951 fix F5, 951 cycle 2 Q7, and the three 961 stops (S10, above). E4's doc-writer is outside the gate's matcher by design.
- **Nested sub-developers (A29, from 961 S11):** they do fire `SubagentStop`, with the same `agent_type` (`aew:developer`) as the parent and distinct `agent_id`s, and none was mis-blocked, so the A29 fallback was not needed.
- **Repeated stops:** each blocked probe produced exactly two stops (first `stop_hook_active` false, second true), so the one corrective turn is what the gate promises. The agents refused to write the report, as the probe told them to, and the second stop was still allowed.

## 9. Orchestrator (prompt 05)

Headless sessions of the five entry skills (`/aew:init`, `/aew:ship`, `/aew:resume`, `/aew:status`, `/aew:prompt`)
with only `gh` (the stateful mock) and `origin` (a local bare repo) faked. The conventions of sections 1 to 4 and 8
apply. Every paid session starts through the launcher `$SMOKE/ship-run.sh` (9.2), which enforces the rails below,
the explicit allowlist, `--permission-prompts none` and the $60 stop; no session is started any other way. Each run
records its results in its own subsection, so parallel lanes edit disjoint lines. Never commit transcripts, streams,
debug logs or anything under `$SMOKE`.

The prompt-05 `$SMOKE` directory (streams, snapshots, the ledger files and the launcher) was deleted on 2026-10-26 at
James's request. The results and spend recorded below are the surviving record; rebuild the launcher from the
reference copy in 9.2 before the next paid run.

Real-GitHub rails (every paid session):

1. The `gh` shim is first on `PATH`, with `GH_MOCK_DIR` set (the shim exits 99 without it).
2. `GH_TOKEN`, `GITHUB_TOKEN`, `GH_ENTERPRISE_TOKEN` and `GITHUB_ENTERPRISE_TOKEN` are unset.
3. `GH_CONFIG_DIR` is the empty `$W/ghcfg` (checked before and after each session), and `GH_HOST=aew-smoke.invalid`:
   on this machine an empty config dir alone does not hide the keychain token (9.2, harness checks).
4. `origin` is the local bare `$W/origin.git`. git gets no credential helper (`GIT_CONFIG_COUNT=1
   GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=`), no terminal prompt (`GIT_TERMINAL_PROMPT=0`) and no ssh
   (`GIT_SSH_COMMAND=false`, `SSH_AUTH_SOCK` unset).
5. `gh auth status` is the canary: ship's and init's first `gh` call, answered by the shim.
6. `retro.repo` is the fake `acme/aew-retro` in every config a session reads.
7. One explicit allowlist per project (`smoke_ship_allow`): no `gh` rule except exactly `Bash(gh auth status)`;
   `--permission-mode acceptEdits`; `--permission-prompts none`, so anything unlisted is denied and AskUserQuestion is
   absent; a deny on editing the plugin checkout (`Edit(//<repo>/**)`). Never `bypassPermissions`.
8. After each session the launcher re-hashes the repo's shared git `config` and `hooks/`, checks that `$W/ghcfg` is
   still empty, and audits every Bash command on every thread. Any failure exits 4 and is a P0 failure.
9. P0 (9.3) runs first. Any P0 failure stops every paid run until it is fixed and P0 re-run; P0 is also re-run
   whenever the launcher's environment lines change.

After every session: `git -C "$REPO" status --porcelain` shows only this README and intended fix files, and
`ls -A "$W/ghcfg"` prints nothing.

### 9.1 Spend ledger (prompt 05, stop at $60)

Separate from the ledgers in sections 1 and 8.1. Caps (cut 5): P0a 0.50 (haiku), P0b 0.50, P1 1, G2 8, I1 3, I2 3,
G1 3, S1 25, run F1 2, R2 10, which is 56 in total and leaves 4 for a re-probe or one small re-run.

- The launcher reserves a session's cap before starting it and refuses (exit 3) when the costs and reservations
  already in the ledger plus that cap pass $60. **Stop at $60**: a refused session is not started, its checks stay
  `open`, and the task reports `DONE_WITH_CONCERNS`.
- One raise per session, to exactly 2x its cap, as the next attempt, and only if the launcher accepts it.
- The cost is the stream's last `result` event's `total_cost_usd`. A killed session counts its cap, and so does a
  crashed one with no `result` event. Spend can pass the cap (9.2), so a recorded cost may exceed it.
- The ledger is `$SMOKE/ledger-05/`: one `<project>-<run>.tsv` per session (cap, cost, start time; an empty cost is a
  reservation). Every lane shares it, because the launcher finds it beside itself, outside any worktree. Task F8 fills
  the table below from it; nothing else writes the table.

Rendered by Task F8 from `$SMOKE/ledger-05/*.tsv`, one row per session in start-time order, so the running total is
what the launcher saw at each reservation. RULES.1 and RULES.2 are the permission probes of 9.9 (Task RW4), paid
from the 4 left over.

| run | attempt | cap (USD) | cost (USD) | running total | cap raised? |
|---|---|---|---|---|---|
| P0a | P0a.1 | 0.50 | 0.0092 | 0.0092 | no |
| P0b | P0b.1 | 0.50 | 0.2333 | 0.2425 | no |
| RULES | RULES.1 | 0.30 | 0.0132 | 0.2557 | no |
| RULES | RULES.2 | 0.30 | 0.0226 | 0.2783 | no |
| P0a | P0a.2 | 0.50 | 0.0096 | 0.2879 | no (re-run after the rewrite) |
| P0b | P0b.2 | 0.50 | 0.2160 | 0.5038 | no (re-run after the rewrite) |
| P1 | P1.1 | 1 | 0.2086 | 0.7124 | no |
| G2 | G2.1 | 8 | 1.2173 | 1.9298 | no |
| I1 | I1.1 | 3 | 0.9736 | 2.9034 | no |
| G2 | G2.2 | 6.75 | 0.3488 | 3.2522 | no (G2's 8 less G2.1) |
| G2 | G2.3 | 6.43 | 2.6318 | 5.8840 | no (G2's 8 less G2.1 and G2.2) |
| I1 | I1.2 | 3 | 0.9362 | 6.8202 | no (re-run after the fix) |
| I2 | I2.1 | 3 | 0.6379 | 7.4580 | no |
| G1 | G1.1 | 3 | 1.9678 | 9.4258 | no |
| S1 | S1.1 | 25 | 4.4236 | 13.8494 | no |
| run F1 | F1.1 | 2 | 2.0000, cap counted (killed) | 15.8494 | no |
| R2 | R2.1 | 10 | 10.0000, cap counted (killed) | 25.8494 | no |
| G1 | G1.2 | 4 | 0.9741 | **26.8236** | yes, 3 to 4 (below the 2x limit of 6) |

Total **$26.82** of the $60 stop (18 sessions; no refusal, no cap hit). The two killed sessions are charged at their
caps ($12); their real spend is unknown, because a killed `-p` session emits no `result` event.

**Results roll-up (build prompt 05's acceptance criteria).** Every 9.3 to 9.8 row is `pass` except G2 check 7
(`fail (as written)`, an ordering deviation; `gates.md` now puts the plan path on its own line after the summary,
`0bc414f`, not re-run live).

| build-prompt AC | evidence |
|---|---|
| Static checks: every agent, script, template and reference mentioned exists; every DESIGN §7.3 stage has an entry, an exit and a failure path in `ship` | `tests/scripts/skills.bats`, 18 tests (paths and script names, `aew:<name>`, ship's stage sections and routing rows, citations, frontmatter, test 17 pre-approvable commands, test 18 printed checks) |
| Static checks: bad arguments give clear messages | `skills.bats` "ship: every bad-argument case has its message"; P1.1 (9.3): the unknown-stage message and usage line verbatim, no tool call |
| Simulated `--auto` run through PR creation, expected `gh` calls, valid `state.json` with status `done` | S1.1 (9.4): checks 1 to 17 pass, `diff` against `expected_s1 0 0 5` empty, PR 7, `current` cleared |
| Material-ambiguity fixture stops at the spec gate | G1.2 (9.8), on init's output (#103 with the mock-only AC 5); `--auto` kept the gate |
| A run without `--auto` stops at the plan gate | G2.3 (9.5) |
| Kill during `develop`, resume continues from `develop` without redoing earlier stages | F1.1 and R2.1 (9.6): 01 to 05 artefacts byte-identical, one issue fetch in total, the developer re-dispatched once |
| init on the nextjs-tailwind fixture validates; a second run changes nothing | I1.2 and I2.1 (9.7) |

**Open items (carried to prompt 07).** QA's fix-cycle route and the manual-tests route were not exercised live: in S1
the developer fixed every planted defect on the first pass (`fix_cycle` 0, S1 check 13), and no `manual-tests.md`
was written, because the mock-only body puts #201's AC-4 (the confirmation email) out of scope (S1 check 5). The interactive gate answers and refusals, the
spec-ambiguity, triage, developer-blocked and request-changes routes and the blocked path were not simulated either
(spec scope); prompt 07 covers them against real GitHub.

### 9.2 Harness

Run section 2's `REPO`/`SMOKE` lines and its `smoke_render`, and section 4's `valid_return_block` eval line, first.
The Bash tool keeps no functions between calls, so a script loads the helpers from this README instead of a pasted
copy (bash or zsh):

```sh
eval "$(awk '/^#### Helpers \(section 9\)$/{f=1;next} f&&!b&&/^#+ /{exit} f&&/^```sh$/{b=1;next} f&&b&&/^```$/{b=0;next} f&&b' "$REPO/tests/agent-smoke/README.md")"
command -v smoke_ship_project >/dev/null || echo 'section 9 helpers: extraction failed'
```

The plugin's and dev-workflow's Bash guards block any command whose text contains `git push`, so every launch and
every multi-step harness action goes in a script file written with the Write tool and run with `/bin/bash`. Long
sessions (S1 can take an hour) are started with the Bash tool's `run_in_background: true` and waited for, never
polled in a foreground loop. macOS `/var` is `/private/var`.

#### Helpers (section 9)

`smoke_ship_project` copies a fixture to `$SMOKE/ship-<name>/p`, fakes `retro.repo` in the static-shop copy before
the fixture commit (the nextjs fixture has no config until init writes one), installs the static-shop dependencies
before that commit as section 8.3 does, makes `$W/origin.git` a bare clone with `main` as HEAD and sets the upstream,
and cans the replies the scripts parse. `smoke_ship_allow <kind>` prints one launcher argument per line (kinds `ship`,
`p0`, `init`) and must be called with `$P` set to the project: (1) for every lane, the plugin scripts and the forms
the skills share (`gh auth status`, `git status`, `git switch`, `git add`, `git commit`, `jq`, `printf`, `echo`),
and for `ship` and `p0` also the forms of ship, resume, status and prompt (Phase B I-8 and Phase C K-4 as rewritten
by RW1 and RW2: `claude plugin list --json`, `git fetch origin main`, `awk`, `test`, `tail -n`, `grep -c`); (2) for
`ship` and `p0`, the agents' git reads and the agent lines already recorded in this README (961's developer line,
8.3's QA phase B line with this project's paths, the eleven Playwright MCP names), but not 8.3's `--disallowedTools
"Bash(gh *)"`, because a deny beats every allow and would deny the canary; (3) for `p0`, the probe's commands; (4)
for `init`, every leading form of `skills/init/SKILL.md` sections 1 to 13 that RULES.2 did not see run without a
rule (9.9), the `npx … ajv validate` line included; (5) the denials. A form RULES.2 saw run without a rule (`cat
.aew/runs/current`, `ls`, `grep`, `tail -c`, `[ … ]`, `node --version`, `mkdir -p .aew`, `rm -f` of project files,
`git branch --show-current`, `git rev-list --count`, `git merge-base --is-ancestor`, `true`) gets none. The
`<cmd> *` wildcards are harness-only; init's user template stays anchored.

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

# Harness-only: the developer and QA lines are broad (`cd *`, `npx *`, `cp *`, `sh -c *`) and are never a template
# for user settings; init's own proposal (AC-31, cut 6) is anchored.
# smoke_ship_allow ship|p0|init   (prints one ship-run.sh argument per line; needs $REPO, and $P set to the project)
smoke_ship_allow() {
  local k=$1 s PR T=mcp__plugin_aew_playwright__browser
  case $k in ship | p0 | init) ;; *) echo "smoke_ship_allow: ship, p0 or init" >&2; return 1 ;; esac
  PR=$(cd "$P" && pwd -P) || return 1
  # 1. every lane: the scripts by absolute path, bare (ship) and quoted (init), the skills' shared forms, and the
  #    standards-setter's date (it runs in both lanes)
  echo --allowedTools
  for s in state gh-issue gh-labels git-branch gh-pr gh-retro detect-stack check-pr-intro; do
    printf '%s\n' "Bash($REPO/scripts/$s.sh *)" "Bash(\"$REPO/scripts/$s.sh\" *)"
  done
  printf '%s\n' "Bash(gh auth status)" "Bash(git status *)" "Bash(git switch *)" "Bash(git add *)" "Bash(git commit *)" \
    "Bash(jq *)" "Bash(printf *)" "Bash(echo *)" "Bash(date *)" \
    "mcp__plugin_context7_context7__*"
  # 1a. ship, resume, status and prompt (preflight, the bounded reads); test, tail -n and grep -c are kept although
  #     the bundle's read-only tables list them (not observed in a session, RULES.2)
  if [ "$k" != init ]; then
    printf '%s\n' "Bash(claude plugin list --json)" "Bash(git fetch origin main)" \
      "Bash(awk *)" "Bash(test *)" "Bash(tail -n *)" "Bash(grep -c *)"
  fi
  # 2. agent lines already recorded in this README (961 developer, 8.3 QA phase B, 951 developer additions), and the
  #    developer's, qa-engineer's and senior-engineer's git reads
  if [ "$k" != init ]; then
    printf '%s\n' "Bash(git rev-parse *)" "Bash(git branch *)" "Bash(git diff *)" "Bash(git log *)" "Bash(git show *)" \
      "Bash(git worktree *)" "Bash(git cherry-pick *)" \
      "Bash(git -C * status *)" "Bash(git -C * diff *)" "Bash(git -C * log *)" "Bash(git -C * show *)" \
      "Bash(git -C * add *)" "Bash(git -C * commit *)" "Bash(git -C * rev-parse *)" \
      "Bash(cd *)" "Bash(node *)" "Bash(npm *)" "Bash(npx *)" \
      "Bash(npm install *)" "Bash(node --test *)" "Bash(npx playwright *)" "Bash(pnpm add -D -E *)" "Bash(yarn add -D -E *)" \
      "Bash(curl *)" "Bash(nohup sh -c *)" "Bash(sh -c *)" "Bash(tail -n 20 *)" "Bash(lsof -ti tcp:4173 -sTCP:LISTEN)" "Bash(kill *)" \
      "Bash(rm -rf $P/docs/qa/201/screenshots)" "Bash(rm -rf $PR/docs/qa/201/screenshots)" \
      "Bash(AEW_EVIDENCE_DIR=* npx playwright test)" "Bash(AEW_EVIDENCE_DIR=* npx playwright test *)" \
      "Bash(mkdir -p *)" "Bash(file -b *)" "Bash(cp *)"
    for s in navigate snapshot click type press_key select_option hover resize console_messages wait_for close; do echo "${T}_$s"; done
  fi
  # 3. P0a probe commands (section 9.3; macOS printenv takes one name, so steps 3 and 4 pipe env through cut and grep)
  if [ "$k" = p0 ]; then
    printf '%s\n' "Bash(command -v gh)" "Bash(type -a gh)" "Bash(env)" "Bash(cut -d= -f1)" "Bash(git remote get-url origin)"
  fi
  # 4. init: every leading form of skills/init/SKILL.md sections 1-13 not observed to run without a rule (RULES.2)
  if [ "$k" = init ]; then
    printf '%s\n' "Bash(command -v *)" "Bash(git rev-parse *)" "Bash(git remote -v)" \
      "Bash(git symbolic-ref *)" "Bash(git ls-remote *)" "Bash(git check-ignore *)" "Bash(git ls-files *)" \
      "Bash(git restore -- *)" "Bash(npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate *)" \
      "Bash(cat *)" "Bash(mkdir -p *)" "Bash(rm -f .claude/agent-memory/aew-standards-setter/*)"
  fi
  # 5. denials (a deny beats every allow, so never "Bash(gh *)": it would deny the canary). CTO-3: "//" plus the
  #    absolute path anchors at the filesystem root (/en/permissions), so no file tool or redirect may write the plugin.
  #    The user-level MCP connectors this machine loads into every session (seen in G2.3's system/init) are denied by
  #    server name: a session must never reach the user's Notion, Drive, Docs, Gmail, Calendar or Figma. The launcher's
  #    audit also flags any MCP call outside plugin:aew:playwright and plugin:context7.
  printf '%s\n' --disallowedTools "Bash(git push *)" "Bash(git reset *)" "Bash(git checkout *)" "Bash(git add -A*)" "Bash(git add .)" \
    "Edit(/$REPO/**)" "mcp__notion" "mcp__claude_ai_Claude_Docs" "mcp__claude_ai_Google_Drive" "mcp__claude_ai_Gmail" \
    "mcp__claude_ai_Google_Calendar" "mcp__claude_ai_Figma"
}
```

Check helpers. Evidence comes from tool results, `system/init` and artefacts, never from the model's prose.

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

S1's expected `gh` routes (AC-40), written before S1 from Phase B I-9 and the scripts' `gh` calls. Label reads
(`issue view --json labels`, one per `gh-labels.sh` call) are dropped, so a no-op stage label leaves no line. The
free I-9 dry-run below proves both functions against the real scripts and the mock.

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

#### Launcher

`$SMOKE/ship-run.sh` is kept outside the repo, never committed, written with the Write tool and `chmod +x`; the text
below is the reference copy. `<repo>` is an argument, not baked in, because parallel lanes run from different
worktrees; the ledger (`$SMOKE/ledger-05/`) and the audit allowlist (`$SMOKE/audit-allow.json`, a JSON array of exact
command strings) sit beside the launcher, so every lane shares them. `<W>` must be under `$SMOKE`.

```
"$SMOKE/ship-run.sh" <repo> <W> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]
"$SMOKE/ship-run.sh" --env-check <repo> <W> <command> [<arg>...]   # free: one command in the session env, from $W/p
```

- Refuses (exit 2) unless `$W/p` is a git project whose only remote is `origin` = the bare `$W/origin.git`,
  `$W/ghcfg` exists and is empty, `$W/out/<run>` and its ledger file don't exist yet, and the allow file has no `gh`
  rule other than `Bash(gh auth status)` (in either wildcard form, `gh *` or `gh:*`) and no bare `Bash` or `Bash(*)`
  rule, and doesn't touch the permission mode or a launcher flag (`--flag` or `--flag=…`). P0a's allow file
  starts with `--model` / `haiku`, which is just another argument; every other session uses the default model,
  recorded from `system/init`.
- CTO-5: the spent read and the reservation write sit inside a `mkdir "$L/.lock"` spin lock, released before `claude`
  starts; over $60 exits 3.
- Before the session: stops a QA app server still listening on port 4173 whose working directory is inside this
  project (`lsof -ti tcp:4173 -sTCP:LISTEN`, then `kill <pid>`, logged to `$W/out/port-4173.log`), and hashes
  `$(git -C "$REPO" rev-parse --git-common-dir)/config` and that directory's `hooks/` (CTO-3).
- The session: the environment of the rails, `--plugin-dir "$REPO"`, stream-json with subagent text and hook events,
  `--max-budget-usd <cap>`, `--debug-file`, the `--settings` JSON of section 8.3, `--add-dir "$REPO"`,
  `--permission-mode acceptEdits --permission-prompts none`, the allow file's lines, `< /dev/null`. With a
  `<kill-stage>`, a poller kills the session once `.aew/runs/<current>/state.json` reads that stage (and, with a
  `<kill-agent>`, once that `subagent_type` is in the stream), writing `$O/killed-at`.
- After it: `$O/exit`, the ledger cost, the port-4173 stop again, then the safety checks. A changed git hash
  (`$O/git-guard.txt`), a non-empty `$W/ghcfg` (`$O/ghcfg.txt`) or an audit hit (`$O/audit.txt`, `AUDIT HIT`) exits 4.
  The audit (CTO-4) covers every Bash `tool_use` on every thread for `github\.com`, `--hostname`, `GH_HOST=`,
  `GH_TOKEN`, `GITHUB_TOKEN`, `GH_CONFIG_DIR=`, `security `, `credential`, `remote (add|set-url)`, the real `gh`'s
  path, and any `claude` command other than exactly `claude plugin list --json`. A genuine false positive is added
  to `$SMOKE/audit-allow.json` by its exact string and recorded in 9.9, never by loosening a pattern.

```bash
#!/bin/bash
# Harness-only launcher for tests/agent-smoke/README.md section 9. Every paid prompt-05 session starts here.
# usage: ship-run.sh <repo> <W> <run> <cap> <allow-file> <prompt> [<kill-stage> [<kill-agent>]]
#        ship-run.sh --env-check <repo> <W> <command> [<arg>...]   (no session: one command in the session env, from $W/p)
# It lives in $SMOKE, beside the one shared ledger ($SMOKE/ledger-05) and the audit allowlist, outside every
# repo and worktree, so parallel lanes share one $60 budget whichever worktree they run from.
# Exit: 0 session finished (its own exit is in $O/exit); 2 refused (usage, setup); 3 budget refused or ledger lock busy;
# 4 safety failure (git config/hooks changed, audit hit, gh config dir written): a P0 failure, paid runs stop.
set -uo pipefail
usage() { sed -n '3,4p' "$0" | sed 's/^# //'; }
case ${1:-} in -h | --help) usage; exit 0 ;; esac
CHECK=0; [ "${1:-}" = --env-check ] && { CHECK=1; shift; }
if [ "$CHECK" = 1 ]; then
  [ $# -ge 3 ] || { usage >&2; exit 2; }
  REPO=$1 W=$2; shift 2
else
  [ $# -ge 6 ] || { usage >&2; exit 2; }
  REPO=$1 W=$2 RUN=$3 CAP=$4 ALLOWF=$5 PROMPT=$6 KSTAGE=${7:-} KAGENT=${8:-}
fi
HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 2
L="$HERE/ledger-05"; OKF="$HERE/audit-allow.json"
P="$W/p"; SHIM="$REPO/tests/scripts/helpers/bin"
refuse() { echo "ship-run: $*; not started" >&2; exit 2; }

# preconditions (rails 1, 3, 4): the project sits under $SMOKE, gh is the shim, origin is the local bare repo
WP=$(cd "$W" 2> /dev/null && pwd -P) || refuse "no directory $W"
case $WP in "$HERE"/*) ;; *) refuse "$W is not under $HERE" ;; esac
[ -x "$SHIM/gh" ] || refuse "no gh shim at $SHIM"
[ -d "$P/.git" ] || refuse "$P is not a project"
[ -d "$W/ghcfg" ] && [ -z "$(ls -A "$W/ghcfg")" ] || refuse "$W/ghcfg missing or not empty"
[ "$(git -C "$P" remote)" = origin ] && [ "$(git -C "$P" remote get-url origin)" = "$W/origin.git" ] &&
  [ "$(git -C "$W/origin.git" rev-parse --is-bare-repository 2> /dev/null)" = true ] ||
  refuse "origin is not the local bare repo $W/origin.git"

# rails 1-3, R-9 and CTO-2: shim first, tokens unset, empty gh config dir, unresolvable gh host, no git credential
# helper, no terminal prompt, no ssh
SAFE_ENV=(env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN -u SSH_AUTH_SOCK
  -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID
  PATH="$SHIM:$PATH" GH_MOCK_DIR="$W/gh" GH_CONFIG_DIR="$W/ghcfg" GH_HOST=aew-smoke.invalid
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0= GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND=false)
if [ "$CHECK" = 1 ]; then
  cd "$P" || exit 2
  exec "${SAFE_ENV[@]}" "$@"
fi

# rail 7: the allow file adds rules (and P0a's --model) only
O="$W/out/$RUN"; LF="$L/${W##*/}-$RUN.tsv"
case $CAP in '' | *[!0-9.]*) refuse "cap $CAP is not a number" ;; esac
[ -e "$O" ] || [ -e "$LF" ] && refuse "$O or $LF exists; use the next attempt name"
[ -f "$ALLOWF" ] || refuse "no allow file $ALLOWF"
grep -qiE 'bypass|dangerously|^--(permission-mode|permission-prompts|settings|plugin-dir|add-dir)(=|$)' "$ALLOWF" &&
  refuse "$ALLOWF overrides a launcher flag or the permission mode"
grep -E '^Bash(\((\*|gh([ :*].*)?)\))?$' "$ALLOWF" | grep -qvxF 'Bash(gh auth status)' &&
  refuse "a gh rule other than Bash(gh auth status), or a bare Bash rule, in $ALLOWF"
[ -f "$OKF" ] || printf '[]\n' > "$OKF"
jq -e 'type == "array" and all(.[]; type == "string")' "$OKF" > /dev/null || refuse "$OKF is not a JSON array of strings"
REALGH=$(type -ap gh | grep -vxF "$SHIM/gh" | head -n 1 || true)   # audited below; the shim is not on the caller's PATH

# CTO-3: the repo's shared git config and hooks must not change during the session
GCD=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir) || refuse "cannot find the git dir of $REPO"
git_guard() {
  (cd "$GCD" || exit 1
   shasum config
   find hooks \( -type f -o -type l \) 2> /dev/null | LC_ALL=C sort | while IFS= read -r f; do
     if [ -x "$f" ]; then echo "x $f"; else echo "- $f"; fi
     if [ -L "$f" ]; then readlink "$f"; fi
     shasum "$f" 2>&1
   done) | shasum | awk '{print $1}'
}

# a QA app server left on port 4173 by a session in this project (its cwd inside $P) is stopped, before and after
P_REAL=$(cd "$P" && pwd -P)
stop_4173() {
  local pid cwd
  for pid in $(lsof -ti tcp:4173 -sTCP:LISTEN 2> /dev/null); do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2> /dev/null | sed -n 's/^n//p')
    case "$cwd" in "$P_REAL" | "$P_REAL"/*) echo "$1 $pid $cwd" >> "$W/out/port-4173.log"; kill "$pid" 2> /dev/null ;; esac
  done
}

# CTO-5: the spent read and the reservation write under one lock, released before claude starts
mkdir -p "$L" "$W/out" || exit 2
i=0
until mkdir "$L/.lock" 2> /dev/null; do
  i=$((i + 1)); [ "$i" -lt 120 ] || { echo "ship-run: ledger lock busy for 60s ($L/.lock); remove it only if no launcher runs" >&2; exit 3; }
  sleep 0.5
done
spent=$(cat "$L"/*.tsv 2> /dev/null | awk -F'\t' '{s += ($2 != "" ? $2 : $1)} END {printf "%.2f", s + 0}')
if awk -v s="$spent" -v c="$CAP" 'BEGIN {exit !(s + c > 60)}'; then
  rmdir "$L/.lock"; echo "ship-run: $spent spent or reserved + cap $CAP passes 60; not started" >&2; exit 3
fi
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\t\t%s\n' "$CAP" "$START" > "$LF"                          # reserved until the cost is known
rmdir "$L/.lock"

mkdir -p "$O" || exit 2
ALLOW=(); while IFS= read -r a || [ -n "$a" ]; do [ -n "$a" ] && ALLOW+=("$a"); done < "$ALLOWF"
SETTINGS=$(jq -nc --arg ex "$REPO/CLAUDE.md" '{claudeMdExcludes: [$ex], enabledPlugins: {"dev-workflow@jamesborg": false, "figma@claude-plugins-official": false}}')
stop_4173 before
G0=$(git_guard)
H0=$(git -C "$REPO" rev-parse HEAD)                                  # plugin repo HEAD: a session must not commit into it
cd "$P" || exit 2
"${SAFE_ENV[@]}" claude --plugin-dir "$REPO" -p "$PROMPT" \
    --output-format stream-json --verbose --forward-subagent-text --include-hook-events \
    --max-budget-usd "$CAP" --debug-file "$O/debug.log" --settings "$SETTINGS" \
    --add-dir "$REPO" --permission-mode acceptEdits --permission-prompts none \
    ${ALLOW[@]+"${ALLOW[@]}"} > "$O/stream.jsonl" 2> "$O/stderr.txt" < /dev/null &
pid=$!
if [ -n "$KSTAGE" ]; then
  while kill -0 "$pid" 2> /dev/null; do
    id=$(cat .aew/runs/current 2> /dev/null || true)
    s=$(jq -r '.stage' ".aew/runs/$id/state.json" 2> /dev/null || true)
    if [ -n "$id" ] && [ "$s" = "$KSTAGE" ] && { [ -z "$KAGENT" ] || grep -Eq "\"subagent_type\": ?\"$KAGENT\"" "$O/stream.jsonl"; }; then
      date -u +%Y-%m-%dT%H:%M:%SZ > "$O/killed-at"
      pkill -TERM -P "$pid" 2> /dev/null; kill -TERM "$pid" 2> /dev/null
      i=0; while kill -0 "$pid" 2> /dev/null && [ "$i" -lt 30 ]; do sleep 1; i=$((i + 1)); done
      kill -KILL "$pid" 2> /dev/null
      break
    fi
    sleep 1
  done
fi
wait "$pid"; echo "$?" > "$O/exit"
cost=$(jq -rR 'fromjson? | select(.type == "result") | .total_cost_usd' "$O/stream.jsonl" | tail -n 1)
[ -n "$cost" ] && [ "$cost" != null ] || cost=$CAP                  # crashed: no result event, count the cap
[ -e "$O/killed-at" ] && cost=$CAP                                   # killed sessions always count their cap (9.1)
printf '%s\t%s\t%s\n' "$CAP" "$cost" "$START" > "$LF.new" && mv "$LF.new" "$LF"
stop_4173 after
echo "ship-run: $RUN exit $(cat "$O/exit") cost $cost"

# post-session safety checks: any failure is a P0 failure (exit 4)
fail=0
G1=$(git_guard)
if [ "$G0" != "$G1" ]; then
  printf 'git config or hooks changed: %s before, %s after (%s)\n' "$G0" "$G1" "$GCD" > "$O/git-guard.txt"
  echo "ship-run: GIT GUARD: $GCD/config or hooks/ changed during $RUN" >&2; fail=1
fi
H1=$(git -C "$REPO" rev-parse HEAD)
if [ "$H0" != "$H1" ]; then
  printf 'plugin repo HEAD moved: %s before, %s after\n' "$H0" "$H1" > "$O/repo-head.txt"
  echo "ship-run: REPO HEAD moved during $RUN" >&2; fail=1
fi
if [ -n "$(ls -A "$W/ghcfg")" ]; then
  ls -A "$W/ghcfg" > "$O/ghcfg.txt"; echo "ship-run: GH CONFIG DIR written during $RUN" >&2; fail=1
fi
# CTO-4: every Bash tool_use on any thread; a false positive is allowed only by its exact command in $OKF
jq -cR --slurpfile ok "$OKF" --arg real "$REALGH" '
  fromjson? | select(.type == "assistant") | (.parent_tool_use_id // "main") as $t
  | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | (.input.command // "") as $c
  | select(($ok[0] | any(.[]; . == $c)) | not)
  | ([("github\\.com", "--hostname", "GH_HOST=", "GH_TOKEN", "GITHUB_TOKEN", "GH_CONFIG_DIR=", "security ", "credential",
       "remote (add|set-url)") as $p | select($c | test($p)) | $p]
     + (if $real != "" and ($c | contains($real)) then [$real] else [] end)
     + (if ($c | gsub("claude plugin list --json(?=\\s*($|[|;&)]))"; "") | test("(^|[^A-Za-z0-9_.-])claude(\\s|$)"))
        then ["claude command"] else [] end)) as $hits
  | select($hits | length > 0) | {thread: $t, hits: $hits, command: $c}' "$O/stream.jsonl" > "$O/audit.txt"
# any MCP call outside the plugin's own servers (the user's connectors are denied, this catches a new one)
jq -cR 'fromjson? | select(.type == "assistant") | (.parent_tool_use_id // "main") as $t
  | .message.content[]? | select(.type == "tool_use") | .name as $n
  | select(($n | startswith("mcp__")) and ($n | test("^mcp__plugin_(aew_playwright|context7_context7)__") | not))
  | {thread: $t, hits: ["mcp tool"], command: $n}' "$O/stream.jsonl" >> "$O/audit.txt"
if [ -s "$O/audit.txt" ]; then
  echo "ship-run: AUDIT HIT: $(wc -l < "$O/audit.txt" | tr -d ' ') Bash command(s) in $O/audit.txt" >&2; echo "AUDIT HIT"; fail=1
else
  rm -f "$O/audit.txt"
  echo "ship-run: audit clean ($(jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | 1' "$O/stream.jsonl" | wc -l | tr -d ' ') Bash commands)"
fi
[ "$fail" = 0 ] || exit 4
```

#### Harness checks (free, no Claude session)

```sh
claude --version                                                    # 2.1.308 or later
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

The I-9 dry-run is a script file, `$SMOKE/dry-i9.sh` (written with the Write tool, run as `/bin/bash "$SMOKE/dry-i9.sh"
"$REPO"`). It loads the helpers with the loader above, runs `smoke_ship_project dry shop`, `smoke_ship_issue 201
"$SHOP_RUN/issue.json"` and `smoke_ship_allow` for the three kinds, then, through `ship-run.sh --env-check` (the
session environment, CTO-2 included) from `$P` with `CLAUDE_PLUGIN_ROOT="$REPO"`, the I-9 script calls in order:
`gh auth status`; `state.sh init 201 --issues 201 --mode single --auto`; `gh-issue.sh fetch 201 .aew/runs/201`;
`state.sh set title "$(jq -r .title .aew/runs/201/issue.json)"`; `gh-labels.sh stage 201 analysing`;
`git-branch.sh create 201 add-to-basket`; `state.sh set branch <printed name>`; `gh-labels.sh stage 201` with
`planning` three times, `building` twice, `testing`, `documenting`; `git-branch.sh push`; `gh-pr.sh create 201 <body
file with "Closes #201">`; `gh-issue.sh manual-tests 201 <one-item manual-tests.md>`; `gh-labels.sh flag 201 add
manual-test-required`; `gh-retro.sh file <one-item retro.md> acme/static-shop 201`; `gh-labels.sh stage 201
ready-for-review`. Then:

```sh
diff <(expected_s1 0 1 1) <(smoke_norm "$GHM/calls.log")             # no output
git -C "$W/origin.git" rev-parse --verify --quiet refs/heads/feat/201-add-to-basket   # a sha: the push reached the bare origin
"$SMOKE/ship-run.sh" --env-check "$REPO" "$W" /bin/bash -c "printf 'protocol=https\nhost=github.com\n\n' | git credential fill > /dev/null 2>&1"; echo "exit=$?"   # non-zero (CTO-2; output discarded, never printed)
grep -h '^Bash(gh ' "$W"/allow-*.txt | sort -u                       # exactly: Bash(gh auth status)
grep -c 'bypassPermissions' "$SMOKE/ship-run.sh" "$W"/allow-*.txt     # 0 for every file
grep -h '^Edit(' "$W"/allow-*.txt | sort -u                          # exactly: Edit(//<repo>/**)
grep -c -- '--permission-prompts none' "$SMOKE/ship-run.sh"           # 1
grep -c 'GH_HOST=aew-smoke.invalid' "$SMOKE/ship-run.sh"              # 1
grep -rl mktemp "$REPO/skills/ship" | wc -l                          # 0 (R-8: else no paid run starts)
tests/run-script-tests.sh && claude plugin validate .                 # pass (E1 baseline)
git -C "$REPO" status --porcelain                                     # only tests/agent-smoke/README.md
rm -rf "$SMOKE/ship-dry"
```

The launcher's own paths (budget refusal, the lock, the audit, the git guard, the `ghcfg` check, the kill poller) were
exercised once against a copy of it in a scratch directory with a stub `claude` first on `PATH` (no API call, so no
cost and nothing in the shared ledger).

| check | result | notes |
|---|---|---|
| Claude Code version | pass | `2.1.308 (Claude Code)`. |
| CLI flags present | pass | `claude --help` count 4 (`--permission-prompts`, `--permission-mode`, `--max-budget-usd`, `--forward-subagent-text`). |
| launcher syntax and shellcheck | pass | `/bin/bash -n` and `npx shellcheck` print nothing. |
| superpowers version | pass | `7.0.0`, so S1 expects no superpowers warning. |
| real-gh canary (rail 5) | pass | Real `gh` is `/opt/homebrew/bin/gh`. With the four token variables unset and an empty config dir: `You are not logged into any GitHub hosts. To log in, run: gh auth login`, exit 1. |
| keychain check (rail 3) | pass, with a finding | `gh auth token` with only the empty config dir: **exit 0**, so the keychain token is visible despite it (output discarded, never printed). With `GH_HOST=aew-smoke.invalid` as well: exit 1. Rail 3 holds because of `GH_HOST`, not the config dir. The canary dir stayed empty (0 entries). |
| I-9 dry-run routes | pass | `smoke_ship_project dry shop` left a clean status; the I-9 calls ran through `ship-run.sh --env-check`; `diff <(expected_s1 0 1 1) <(smoke_norm "$GHM/calls.log")` printed nothing. Helpers loaded from this README with the loader above (and the same functions in zsh print the same three allow files). |
| I-9 dry-run push (CTO-2) | pass | `git-branch.sh push` reached the bare origin in the session environment: `refs/heads/feat/201-add-to-basket` resolves to a sha (branch name from the default `git.branch_pattern`). |
| git credentials (CTO-2) | pass | `git credential fill` for `https://github.com` in the session environment: exit 128 (output discarded). In that environment `gh` is the shim, `GH_CONFIG_DIR`, `GH_MOCK_DIR`, `GH_HOST`, `GIT_CONFIG_COUNT`, `GIT_TERMINAL_PROMPT`, `GIT_SSH_COMMAND` read `$W/ghcfg $W/gh aew-smoke.invalid 1 0 false`, and none of the four token variables nor `SSH_AUTH_SOCK` is set (the caller's shell has `SSH_AUTH_SOCK`). |
| allowlist hygiene | pass | The only `gh` rule in the three allow files is `Bash(gh auth status)`; `bypassPermissions` count 0 in the launcher and all three files; the one Edit rule is `Edit(//<repo>/**)` (the absolute `//` form). Allow files: ship 87 lines, p0 93, init 76. |
| launcher greps | pass | `--permission-prompts none` 1; `GH_HOST=aew-smoke.invalid` 1; the CTO-2 git variables 1; `-u SSH_AUTH_SOCK` 1. |
| R-8: no `mktemp` in `skills/ship` | pass | `grep -rl mktemp skills/ship` finds nothing (0). |
| launcher paths (stub `claude`, scratch copy) | pass | Normal session: exit 0, ledger row `cap, cost, start`, audit clean. Same run name again: refused, exit 2. Budget: 58 spent + 0.36 + cap 3 refused, exit 3, nothing started. Lock: three launches at once with 57.56 spent and cap 2: one started, two refused (each saw 59.56 including the first's reservation). Audit: `/opt/homebrew/bin/gh auth status` on a subagent thread is a hit (exit 4, `AUDIT HIT`); P0a's step 3 passes as the one allowed string; `claude plugin list --json \| jq …`, `.claude/` paths and the repo path are not hits; `claude -p`, `/usr/local/bin/claude --version`, `git remote add`, `github.com`, `credential` and `security ` are. Git guard: a `git config` write and a new `hooks/pre-commit` in the repo each exit 4. A file written into `$W/ghcfg` during the session exits 4; one there before is refused. Kill poller: killed 2 s after the stage and `aew:developer` appeared, `killed-at` and exit 143 recorded, the ledger counts the cap. An allow file with `Bash(gh *)` or `--permission-mode` is refused; after review, so are `Bash(gh:*)`, `Bash`, `Bash(*)`, `--permission-mode=default` and `--settings={}` (each exit 2), while the three generated allow files still pass. |
| suite and validation (E1 baseline) | pass | `tests/run-script-tests.sh`: 321 tests, all `ok` (includes `skills.bats`). `claude plugin validate .`: passed, with the existing directory-profile warnings only. |
| repo status | pass | `git -C "$REPO" status --porcelain`: only ` M tests/agent-smoke/README.md`. `$SMOKE/ship-dry` removed; `$SMOKE/ledger-05/` does not exist yet (no paid session). |

#### Platform facts the harness relies on (checked 2026-10-25)

- `--max-budget-usd` counts subagent spend: "Spend from subagents counts toward the cap. Spend can pass the cap"
  ([cli-reference](https://code.claude.com/docs/en/cli-reference), `--max-budget-usd`). So one cap covers a whole
  orchestrator session, and the ledger still records `total_cost_usd`, which can exceed the cap.
- `Edit(//<abs>/**)`: in Read and Edit rules `//path` is an absolute path from the filesystem root, while a single
  leading `/` anchors at the settings source ([permissions](https://code.claude.com/docs/en/permissions), "Read and
  Edit"). An Edit deny also covers Write, the file commands Claude Code recognises in Bash and the targets of Bash
  redirections, but not a subprocess that writes files itself, so the after-run `git -C "$REPO" status` stays the
  backstop. P0 confirms the rule loads (no startup warning in `stderr.txt` or the debug log).
- Bash allow rules match each subcommand of a compound command (separators `&&`, `||`, `;`, `|`, `|&`, `&`,
  newlines); deny and ask rules also reach into subshells, substitutions and `for` bodies (permissions, "Compound
  commands"). How an allow rule treats the `for … do … done` header itself is not documented: status's corrupt-file
  fallback (a `for` loop over `jq` and `printf 'corrupt\t%s\n' "$f"`) is covered by `Bash(jq *)` and
  `Bash(printf 'corrupt\t%s\n' *)`, unverified. No planned run has a corrupt `state.json`; a denial there is a harness
  fault (narrowest rule, recorded in 9.9).
- macOS `/usr/bin/printenv` prints only its first name argument, so a multi-name `printenv` proves nothing about the
  later names (P0a uses `env | cut` and `echo` instead, 9.3).

### 9.3 P0 safety probe and the bad-argument probe (P0a, P0b, P1)

Task F2 (AC-39, AC-45). Caps: P0a 0.50 (haiku), P0b 0.50, P1 1. **Any failure of checks 1 to 5, 9 or 10 stops
every paid run.** P1 runs only after P0 passes.

```sh
smoke_ship_project p0 shop && smoke_ship_issue 201 "$SHOP_RUN/issue.json"
P_REAL=$(cd "$P" && pwd -P)
{ printf '%s\n' --model haiku; smoke_ship_allow p0; } > "$W/allow-p0a.txt"
smoke_ship_allow ship > "$W/allow-ship.txt"
# the P0a prompt below, saved with the Write tool as "$W/p0a-prompt.txt"; then, from a script file:
"$SMOKE/ship-run.sh" "$REPO" "$W" P0a.1 0.5 "$W/allow-p0a.txt" "$(cat "$W/p0a-prompt.txt")"
"$SMOKE/ship-run.sh" "$REPO" "$W" P0b.1 0.5 "$W/allow-ship.txt" "/aew:status"
```

P0a prompt (verbatim). Steps 3 and 4 replace the plan's two `printenv` lines (see 9.2, platform facts); step 3's
exact text is the one entry of `$SMOKE/audit-allow.json` (9.9); step 4 needs no entry (its text has no `GH_CONFIG_DIR=`
or `GH_HOST=`, because `)=` follows the alternation). Save the prompt with `$REPO` replaced by its absolute path in
step 8, and with no `$` anywhere else (the pre-check denies every `$VAR`, 9.9).

```text
Run each of these Bash commands exactly as written, one Bash call per command, in this order, and do nothing else:
1. command -v gh
2. type -a gh
3. env | cut -d= -f1 | grep -xE 'GH_TOKEN|GITHUB_TOKEN|GH_ENTERPRISE_TOKEN|GITHUB_ENTERPRISE_TOKEN|SSH_AUTH_SOCK'
4. env | grep -E '^(GH_CONFIG_DIR|GH_MOCK_DIR|GH_HOST|GIT_CONFIG_COUNT|GIT_TERMINAL_PROMPT|GIT_SSH_COMMAND)='
5. git remote get-url origin
6. gh auth status
7. jq -r .project .aew/config.json
8. <REPO>/scripts/state.sh set title "Static shop probe"
Then use the Write tool to write the single word probe to .aew/runs/p0-write.md.
Finally print one line per step: the step number, the exit status and the output.
```

Checks (from tool results and `system/init`; record verbatim excerpts):

```sh
smoke_bash_results "$W/out/P0a.1"
#  1 steps 1-2: command -v gh is $REPO/tests/scripts/helpers/bin/gh; the first type -a gh line is the shim (record any real gh after it)
#  2 step 3: empty output, exit 1 (no token variable and no SSH_AUTH_SOCK in the session)
#  3 step 4: six lines, any order: GH_CONFIG_DIR=$W/ghcfg, GH_MOCK_DIR=$W/gh, GH_HOST=aew-smoke.invalid, GIT_CONFIG_COUNT=1,
#            GIT_TERMINAL_PROMPT=0, GIT_SSH_COMMAND=false (none is a secret; no token variable can match)
#  4 step 5: $W/origin.git (the /var or the /private/var form)
#  7 steps 7-8: step 7 prints static-shop; step 8 (a literal double-quoted argument to state.sh, the form ship step 3.5 now
#    uses) is NOT denied: it runs and exits 1 with a "no current run" style message (there is no run in P0), nothing written
cat "$GHM/calls.log"                                     #  5 exactly one line: auth status
cat "$P/.aew/runs/p0-write.md"                           #  8 probe (the Write form of the blocked comment, Decision 11)
for r in P0a.1 P0b.1; do smoke_init_evt "$W/out/$r" '.tools | index("AskUserQuestion")'; done   #  9 null, null
smoke_init_evt "$W/out/P0b.1" '.agents'                  # 10 the seven aew:<agent> names
smoke_init_evt "$W/out/P0b.1" '[.slash_commands[]? | select(startswith("aew:"))], .permissionMode, .model'   # 11 aew:init, ship, resume, status, prompt; acceptEdits; the model
smoke_res "$W/out/P0b.1"; smoke_main "$W/out/P0b.1"     # 12 "No aew runs in this project." (p0-write.md is not a run); no write; calls.log still one line
smoke_denials "$W/out/P0a.1"; smoke_denials "$W/out/P0b.1"   # 13 [] and []
ls -A "$W/ghcfg"; git -C "$REPO" status --porcelain     # 14 empty; only this README
```

Check 6 (the blocked-comment heredoc) is removed: Decision 11 settles it, and check 8 proves the Write form. Check 10:
if `system/init` has no `agents` key, record its keys and the debug-log agent lines; S1's dispatches become the
evidence. Fallbacks, each followed by a full P0 re-run as the next attempt: (a) PATH or tokens wrong inside the
session: fetch the current docs for `CLAUDE_ENV_FILE` and, if it is sourced before each Bash command, have the
launcher export one; otherwise try an `env` block in `--settings`; record the URL and result in 9.9; if neither works,
`BLOCKED`. (b) Check 8 fails: harness fault first (`acceptEdits`, the working directory); if the aew Edit/Write guard
causes it, it is a fix-loop item. (c) An agent name missing: harness fault first (`enabledPlugins`, `--plugin-dir`),
never a renamed dispatch.

P1, after P0 passes:

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

The message strings are Phase B I-7's; if the merged `skills/ship/SKILL.md` words them differently, the merged
strings win (E1 checks them statically). P1 also proves that a `disable-model-invocation` skill expands in `-p`.

| run | check | result | notes |
|---|---|---|---|
| P0a | 1 `gh` resolves to the shim | pass | Attempt P0a.2 (haiku, `claude-haiku-5-5`), cost 0.0096, project `$SMOKE/ship-p0b`: `command -v gh`: `$REPO/tests/scripts/helpers/bin/gh`. `type -a gh`: `gh is $REPO/tests/scripts/helpers/bin/gh`, then `gh is /opt/homebrew/bin/gh` (the real `gh`, second). History, P0a.1 (cost 0.0092): pass, the same two lines. |
| P0a | 2 token variables and `SSH_AUTH_SOCK` absent | pass | P0a.2 step 3: `(Bash completed with no output)`, `is_error` false. Claude Code does not report grep's no-match exit 1 as an error, so the exit status is not visible; the empty output is the evidence. History, P0a.1: pass, the same. |
| P0a | 3 config dir, mock dir, host, git env | pass | P0a.2 step 4 (`env \| grep -E '^(GH_CONFIG_DIR\|…)='`) ran, not denied; six lines: `GH_MOCK_DIR=$SMOKE/ship-p0b/gh`, `GH_CONFIG_DIR=$SMOKE/ship-p0b/ghcfg`, `GH_HOST=aew-smoke.invalid`, `GIT_CONFIG_COUNT=1`, `GIT_TERMINAL_PROMPT=0`, `GIT_SSH_COMMAND=false`. History, P0a.1: **fail**. Step 4 was then an `echo` of six `$VAR`s and was denied, never run: `Permission for this tool use was denied. … What required approval: A variable in this command can't be checked before it runs`. `Bash(echo *)` does not cover a command with a `$VAR` expansion under `--permission-prompts none`. Harness fault in the probe text, fixed by RW4 (9.9). |
| P0a | 4 origin is the local bare repo | pass | P0a.2 step 5: `$SMOKE/ship-p0b/origin.git` (the `/var` form). History, P0a.1: pass, `$SMOKE/ship-p0/origin.git`. |
| P0a | 5 the shim answered `gh auth status` | pass | P0a.2 step 6: `(Bash completed with no output)`. `$GHM/calls.log` is exactly one line, `auth status`. History, P0a.1: pass, the same. |
| P0a | 7 read-then-literal argument (replaces `$(jq …)`) | pass | P0a.2 step 7 (`jq -r .project .aew/config.json`): `static-shop`. Step 8 (`$REPO/scripts/state.sh set title "Static shop probe"`, the literal double-quoted form of ship step 3.5) ran, not denied: `Exit code 1`, `state.sh: error: no current run (.aew/runs/current not set)`. Afterwards `ls -A "$P/.aew/runs"` is only `p0-write.md` and `git -C "$P" status --porcelain` is empty, so nothing was written. History, P0a.1: **fail**; step 7 was then `echo "$(jq -r .project .aew/config.json)"` and was denied, never run: `… What required approval: Quoted text in this command can't be checked before it runs` (a `"$(…)"` substitution is denied headless whatever the allow rules, 9.9). |
| P0a | 8 Write inside `.aew/runs/` | pass | P0a.2: `cat "$P/.aew/runs/p0-write.md"`: `probe`. The Write call went to the `/private/var` path, with no denial and no hook block. History, P0a.1: pass, the same. |
| P0a, P0b | 9 AskUserQuestion absent | pass | P0a.2, P0b.2: `.tools \| index("AskUserQuestion")`: `null`, `null`. History, P0.1: pass. |
| P0b | 10 agent names | pass | Attempt P0b.2, cost 0.2160. `system/init` `.agents`: `aew:brief-compiler`, `aew:developer`, `aew:doc-writer`, `aew:qa-engineer`, `aew:senior-engineer`, `aew:spec-analyser`, `aew:standards-setter`, plus the built-ins `claude`, `Explore`, `general-purpose`, `Plan`, `statusline-setup`. The same list in P0a.2. History, P0b.1 (cost 0.2333): pass, the same list. |
| P0b | 11 skills, mode, model | pass | P0b.2: `aew:init`, `aew:prompt`, `aew:resume`, `aew:ship`, `aew:status`; `acceptEdits`; model `claude-opus-5-5` (P0a.2: `acceptEdits`, `claude-haiku-5-5`). History, P0.1: pass, the same. |
| P0b | 12 `/aew:status` ran in `-p` | pass | P0b.2: the skill expanded in `-p` and ran exactly its own two commands, in order, with no other tool call: `cat .aew/runs/current` (`Exit code 1`, `No such file or directory`, so `<cur>` is `-`), then the step 2 read verbatim with `--arg cur -` after the filter and the glob `.aew/runs/*/state.json` (`Exit code 1`, `(eval):1: no matches found: .aew/runs/*/state.json`, the zsh case of step 4). Not denied. No fallback, no `ls`, no write; `calls.log` still one line. Result: `There are no aew runs in this project.` (the skill's line is `No aew runs in this project.`; the model reworded it slightly, 9.9). History, P0b.1: **fail** (partial); the listing read, then `jq -r --arg cur … '…' .aew/runs/*/state.json` with `--arg` before the filter, was denied (`… Shell expansion syntax in paths requires manual approval`) and the model improvised `ls .aew/runs` (9.9). |
| P0a, P0b | 13 no denials | pass | P0a.2: `[]`. P0b.2: `[]`. No `Permission for this tool use was denied` text anywhere in either stream. History, P0.1: **fail**. P0a.1: 2 (steps 4 and 7). P0b.1: 1 (the status listing `jq`). |
| P0a, P0b | 14 hygiene and launcher safety checks | pass | P0a.2 and P0b.2: launcher exit 0, `audit clean` (8 and 2 Bash commands), no `git-guard.txt`, `repo-head.txt` or `ghcfg.txt`. After each: `ls -A "$W/ghcfg"` empty; `git -C "$REPO" status --porcelain` empty; HEAD `a1d8273` unchanged. `stderr.txt` empty; the debug log's only `[WARN]` lines are the seven `Bash(git -C * …)` wildcard-position warnings and `[Stall]` lines for the non-zero exits (P0a.2: step 8; P0b.2: `cat .aew/runs/current` and the no-match `jq`). History, P0.1: pass (7 and 3 Bash commands, HEAD `73c43cc`). |
| P1 | 1 unknown-stage message, stage list, usage line | pass | Attempt P1.1, cost 0.2086, model `claude-opus-5-5`, `acceptEdits`, one turn. Result, verbatim: `aew ship: unknown stage "nowhere". Stages: spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr.` then `Usage: /aew:ship <issue> [--auto] [--from <stage>]`. The three `grep -cF` counts: 1, 1, 1. The `disable-model-invocation` skill expanded in `-p`. |
| P1 | 2 no run dir, no `current` | pass | `test ! -e "$P/.aew/runs/201" && test ! -e "$P/.aew/runs/current"`: `none`; `ls -A "$P/.aew/runs"` is only P0a's `p0-write.md`. |
| P1 | 3 no `gh` call, no script call | pass | `calls.log` still one line (`auth status`, from P0a.2): `no-gh-call`. The session made no tool call at all (`smoke_main` empty, so the script-call count is 0): the error came before preflight and before any write. |
| P1 | 4 hygiene | pass | `git -C "$P" status --porcelain` empty; the project's branch list unchanged (only `main`); `smoke_denials`: `[]`; `ls -A "$W/ghcfg"` empty. Launcher exit 0, `audit clean (0 Bash commands)`, no guard files; plugin repo HEAD `a1d8273` and clean. |

### 9.4 S1: `/aew:ship 201 --auto` to a mocked PR

Task F3 (AC-40; live evidence for AC-6, AC-7, AC-11, AC-13, AC-16, AC-17, AC-19). Cap 25. The only session that
reaches `pr` and `gh-retro.sh`. Port 4173 must be free (no other QA session). Expected routes: `expected_s1
$(s1_flags "$RUN")` (both in 9.2's helpers); the flags come from `spec-revision-v*.md`, `manual-tests.md` and
`retro.md`, never from `calls.log`.

```sh
lsof -nP -iTCP:4173 -sTCP:LISTEN                       # must print nothing
smoke_ship_project s1 shop && smoke_ship_issue 201 "$SHOP_RUN/issue.json"   # plus G2's body tweak if 9.5 needed it
P_REAL=$(cd "$P" && pwd -P); smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" S1.1 25 "$W/allow-ship.txt" "/aew:ship 201 --auto"     # run_in_background; about an hour
RUN="$P/.aew/runs/201"; O="$W/out/S1.1"; BR=$(jq -r .branch "$RUN/state.json")
```

```sh
jq -rR 'fromjson? | select(.type == "result") | .subtype' "$O/stream.jsonl"; jq -r '.stage, .status' "$RUN/state.json"   #  1 success; pr, done
smoke_state_valid "$RUN/state.json"                                                       #  2 valid
test -s "$P/.aew/runs/current" && echo set || echo cleared                                #  3 cleared
git -C "$W/origin.git" rev-parse "refs/heads/$BR"; git -C "$P" rev-parse "$BR"            #  4 equal; and origin main = local main = the fixture commit
git -C "$W/origin.git" rev-parse main; git -C "$P" rev-parse main
grep '^aew:' "$GHM/issues/201/labels"                                                     #  5 aew:ready-for-review, + manual-test-required if manual-tests.md has items, + spec-revised if a revision was recorded; no other stage label
diff <(expected_s1 $(s1_flags "$RUN")) <(smoke_norm "$GHM/calls.log")                     #  6 no output
smoke_main "$O" | awk -F'\t' '$1 == "Bash" && $2 ~ /(^|[ ;&|(])gh /'                      #  7 only gh auth status
grep -- '--repo' "$GHM/calls.log" | grep -vc 'acme/aew-retro'; ls -A "$W/ghcfg"           #  7 0; empty
smoke_pair "$O"                                                                           #  8 1 (record whether both tool_results came after both tool_use blocks)
jq -r .pr "$RUN/state.json"                                                               #  9 7
n=$(grep -n '^pr create' "$GHM/calls.log" | cut -d: -f1); grep -c 'Closes #201' "$GHM/files/$(printf %03d "$n")-"*   #  9 >= 1
smoke_res "$O"                                                                            # 10 outcome, https://github.com/acme/static-shop/pull/7, ACs passed <m>/<n>, cycles against limits, manual tests outstanding, the gh-retro.sh lines
git -C "$P" log --format=%s main.."$BR"                                                   # 11 developer (#201) commits, QA evidence, docs: … (#201), chore(aew): update agent memory (#201) if memory changed; docs(standards) only if standards changed (record)
git -C "$P" status --porcelain                                                            # 12 empty
jq -r '.review_cycle, .fix_cycle' "$RUN/state.json"; ls "$RUN"/08-qa-report-*.md "$RUN"/07-review-*.md   # 13 record; fix_cycle <= 3, review_cycle <= 2
smoke_main "$O" | grep -E "awk 'NF' .*06-dev-report.*tail -n 4"                           # 14 one per developer report named in ARTEFACTS
smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /\.aew\/runs\//'                       # 15 none (auto: no plan gate); record the bounded awk/grep -c/jq reads
smoke_main "$O" | grep -c 'claude plugin list --json'; smoke_res "$O"                     # 16 1; no superpowers version warning with 7.x (record the line)
smoke_denials "$O"; git -C "$REPO" status --porcelain                                     # 17 []; this README plus intended fixes
```

Fallbacks: a stop at the spec gate on #201 takes 9.5's fallback. A cap hit is a run failure (one raise to 50, only if
the launcher accepts it; otherwise `DONE_WITH_CONCERNS`). A QA app server left on port 4173 is stopped by the
launcher (`$W/out/port-4173.log`); record it.

| run | check | result | notes |
|---|---|---|---|
| S1 | 1 completed | pass | Attempt S1.1 (cap 25, cost 4.4236, `claude-opus-5-5`, `acceptEdits`, 102 turns, 855 s), fresh project `$SMOKE/ship-s1` with 9.5's mock-only AC-4 body (`4. Out of scope: the order service sends the email.` in `$GHM/issues/201/body`; the fixture's `issue.json` untouched), allow file regenerated from the current helpers (91 lines: G2's 85 plus the six MCP connector denials). Result `success`; `state.json` `pr`, `done`. All ten stages ran once, in order (`log.md`: `spec_analysis`, `brief`, `standards`, `plan`, `develop`, `review`, `qa`, `docs`, `pr` running, then `pr done`; `qa_test_plan` ran as QA phase A beside `plan`). One attempt. |
| S1 | 2 state valid | pass | `smoke_state_valid`: `… state.json valid`. `spec_revision` 1, `fix_cycle` 0, `review_cycle` 0, `pr` 7, `auto` true. |
| S1 | 3 current cleared | pass | `cleared`; `.aew/runs/` holds only `201/` (`state.sh current clear` ran after `state.sh status done`). |
| S1 | 4 branch on the bare origin, main untouched | pass | `feat/201-add-to-basket`: origin and local both `7956602` (pushed by `git-branch.sh push`, the only push). `main`: origin and local both `21dc4c4`, the fixture commit. Origin has only `main` and the feature branch. |
| S1 | 5 final labels | pass | `$GHM/issues/201/labels` is exactly `aew:ready-for-review`. No `aew:spec-revised` (no revision was recorded: `spec-changes.json` has 0 changes) and no `aew:manual-test-required` (no `manual-tests.md`). |
| S1 | 6 `gh` route sequence | pass | `s1_flags`: `0 0 5`. `diff <(expected_s1 0 0 5) <(smoke_norm "$GHM/calls.log")`: empty (exit 0). Routes: `auth-status`, `issue-fetch`, `issue-edit +aew:analysing`, `+aew:planning`, `+aew:building`, `+aew:testing`, `+aew:documenting`, `pr-create`, `retro-label-create`, `retro-list`, five `retro-create`, `+aew:ready-for-review`. The standards, plan and review `gh-labels.sh stage` calls were no-ops (a label read only). |
| S1 | 7 only the mock was reached | pass | The only `gh` command on any thread is `gh auth status` (main thread, once). `--repo` calls outside `acme/aew-retro`: 0. `$W/ghcfg` empty. `system/init` tools: no `mcp__notion__*` and no `mcp__claude_ai_*` tool (the servers `notion`, `claude.ai Claude Docs`, `… Google Drive`, `… Gmail`, `… Google Calendar`, `… Figma` are still listed in `mcp_servers`, but their tools are removed by the denials); the MCP tools present are the plugin's Playwright set (context7 `needs-auth`, no tools). MCP calls on any thread: Playwright only (11: navigate 2, snapshot 2, press_key 3, resize 2, console_messages 1, close 1). |
| S1 | 8 QA phase A and plan in one message (AC-7) | pass | `smoke_pair` 1. Message `msg_011CgPTGbp8RJNWUY8DV4dn7` holds `aew:qa-engineer` (`toolu_01KRvZmTZydgKeGzQAt1TbNP`, `run_dir: .aew/runs/201` / `phase: A`) and `aew:senior-engineer` (`toolu_01UmFThhB7uNTwEMWccpcJ4A`, `mode: plan`). They overlapped: both `tool_use` blocks at stream lines 350 and 353, both `tool_result`s after them (448, 488). Every other dispatch had a message of its own (spec-analyser `spec_version: 2`, brief-compiler `mode: pipeline`, standards-setter, developer `mode: full`, senior-engineer `mode: review` / `n: 1` / `base: main`, qa-engineer `phase: B` / `n: 1`, doc-writer). |
| S1 | 9 PR and state | pass | `jq -r .pr`: `7`. `gh-pr.sh create 201 .aew/runs/201/pr-body.md` was call 16 (`pr create --head feat/201-add-to-basket --base main --title Add to basket --body-file …`); `grep -c 'Closes #201' "$GHM/files/016-aew-pr."*`: 1. |
| S1 | 10 final report (AC-17) | pass | Verbatim block: `aew ship #201 Add to basket: done`, `PR: https://github.com/acme/static-shop/pull/7`, `ACs passed: 10/10`, `Review cycles: 0/2`, `Fix cycles: 0/3`, `Manual tests outstanding: 0`, `Retro items filed: 5 (created #1, created #1, created #1, created #1, created #1)`, `Next: review and merge the PR`, then a prose summary. Every `gh-retro.sh` line says `created #1` because the mock's canned `issue-create.out` is one URL (harness, not a defect; the model itself flagged the repeat). The model also warned that the doc-writer removed the fixture's unexpired `Until 2026-11-30 the sale banner copy is frozen …` line (see the S1 notes below). |
| S1 | 11 commits (AC-16) | pass | `main..feat/201-add-to-basket`: `775e2d0 feat(basket): show live count and name basket button (#201)` (developer: `site/app.js`, `site/index.html`, `tests/unit/basket.test.js`); `00e0370 test(e2e): cover add-to-basket status, button name, a11y and layout (#201)` (QA evidence: `docs/qa/201/report.md`, 17 screenshots, `playwright.config.ts`, `tests/e2e/201-add-to-basket.spec.ts`, `tests/e2e/aew.ts`); `e0b1aeb docs: add the issue spec, and update CLAUDE.md (#201)` and `7956602 chore(aew): update agent memory (#201)` (6 files under `.claude/agent-memory/`), both committed by the orchestrator on the main thread with explicit paths (`git add -- …`). No `docs(standards)` commit: `git status --porcelain -- docs/standards` was empty. |
| S1 | 12 tree clean | pass | `git -C "$P" status --porcelain`: empty, on `feat/201-add-to-basket`. |
| S1 | 13 loops within limits | pass (no loop exercised) | `review_cycle` 0, `fix_cycle` 0; `07-review-1.md` (approved, no findings) and `08-qa-report-1.md` (11/11 TCs, Playwright 16 passed and 4 planned single-viewport skips, axe clean). The expected QA fix cycle did not happen: the real developer fixed the fixture's planted defects (the live basket count, the basket button's accessible name) in its first pass, so review and QA passed first time, and with AC-4 out of scope there was no manual test. S1 therefore gives no live evidence for the fix-cycle route or the manual-tests route (`gh-issue.sh manual-tests`, the flag). |
| S1 | 14 per-report return check (AC-6) | pass (check text fixed after the run) | The check's original `grep -E 'tail -n 4 .*06-dev-report'` prints nothing, because RW1 moved the form to `awk 'NF' <file> \| tail -n 4` (`skills/ship/SKILL.md` line 57, `references/dispatch.md` line 74), so the file name comes before `tail`. The main thread ran exactly one such read per developer report named in ARTEFACTS: `awk 'NF' .aew/runs/201/06-dev-report.md \| tail -n 4` (one report), plus `awk 'NF' .aew/runs/201/08-qa-report-1.md \| tail -n 4` for QA. Task F8 put the matching check, `grep -E "awk 'NF' .*06-dev-report.*tail -n 4"`, in the block above; on S1.1's stream it prints that one line. |
| S1 | 15 reads hygiene (AC-19) | pass | No main-thread Read under `.aew/runs/` (the only Reads are the plugin's `preflight.md`, `dispatch.md`, `routing.md`, `gates.md`, `pr.md` and `final-report.md`). Bounded reads, all Bash: `jq -r .state`, `jq -r .title`, the slug `jq` and the `.url` repo and PR `jq`s on `issue.json`; `jq '.changes \| length' spec-changes.json`; the `spec-ambiguity` history `jq` and the final `jq -r '.title, .pr, .stage, .review_cycle, .fix_cycle'` on `state.json`; the two `awk 'NF' … \| tail -n 4`; `grep -c '^- \[ \]' manual-tests.md` (file absent, exit 2, treated as 0 as `pr.md` says); two `grep -c` AC counts on `10-summary.md`; every existence check printed `yes`/`no` or `exists`/`absent`. |
| S1 | 16 superpowers check | pass | `claude plugin list --json` count 1 (`… \| jq -r '.[] \| select(.id == "superpowers@claude-plugins-official") \| .version'`: `7.0.0`); no superpowers warning in the result. |
| S1 | 17 denials, repo status | pass | `smoke_denials` `[]`; no `Permission for this tool use was denied` text in the stream. Launcher exit 0, `audit clean (128 Bash commands)` (MCP audit included), no `audit.txt`, `git-guard.txt`, `repo-head.txt` or `ghcfg.txt`; port 4173 free after (QA stopped its own server; no `port-4173.log`). Plugin repo HEAD `0bc414f` before and after; `git -C "$REPO" status --porcelain` only ` M tests/agent-smoke/README.md`. Writes only under `$P` (`.aew/runs/201/`, `.claude/agent-memory/`, `CLAUDE.md`, `docs/specs/`, `site/`, `tests/`, `playwright.config.ts`). Debug log: eight context7 "takes no tool" warnings and four `[Stall] … outcome=error` lines for expected non-zero exits (`cat .aew/runs/current` with no run, QA's `curl` and `lsof` probes of port 4173 when nothing listened, the absent `manual-tests.md`). |

S1 notes (Task F3):

- The doc-writer's `CLAUDE.md` curation removed the fixture line `- Until 2026-11-30 the sale banner copy is frozen,
  so do not edit it.` (`10-summary.md`: "Time-bound, and the banner does not exist in `site/index.html`"). That follows
  `skills/claude-md-curation/SKILL.md` line 75 ("An entry with a date or an expiry in it is time-bound, so drop" it)
  and the 951 docs check D2 (8.4), which plants the line to be dropped; but on 2026-10-25 the freeze has not expired,
  so the rule drops a live constraint. ship's final report raised it as a warning. A design question for the
  curation rule (drop only an expired date?), not a harness or permission fault; not changed here.
- The retro (five items, filed to the fake `acme/aew-retro`) repeats G2.3's standards-setter finding ("no stack
  detected" although `.aew/config.json` declares `web` and `docs/standards/web.md` exists) and reports that the
  developer's precondition `git status --porcelain` sees the untracked `.claude/agent-memory/` of earlier agents.
  Both are the agents' own reports, recorded here unverified.

### 9.5 G2: plan-gate stop

Task F4 (AC-42; R1 is dropped by cut 1). Cap 8. G2 never starts the app.

```sh
lsof -nP -iTCP:4173 -sTCP:LISTEN                       # record
smoke_ship_project g2 shop && smoke_ship_issue 201 "$SHOP_RUN/issue.json"
P_REAL=$(cd "$P" && pwd -P); smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" G2.1 8 "$W/allow-ship.txt" "/aew:ship 201"
RUN="$P/.aew/runs/201"; O="$W/out/G2.1"
```

```sh
jq -r '.stage, .status, .auto' "$RUN/state.json"                                          #  1 plan, awaiting_plan_approval, false
jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' "$RUN/state.json"   #  2 gate:plan-approval 05-plan.md
cat "$P/.aew/runs/current"                                                                #  3 201
grep '^aew:' "$GHM/issues/201/labels"                                                     #  4 exactly aew:awaiting-approval
ls "$RUN"/06-dev-report*.md 2>/dev/null | wc -l; git -C "$P" rev-list --count main..HEAD  #  5 0; 0 (record a docs(standards) commit if one appears)
smoke_res "$O" | grep -cF 'aew ship #201: waiting at the plan-approval gate.'             #  6 1
smoke_res "$O" | awk '/waiting at the plan-approval gate\./{f=1;next} /\.aew\/runs\/201\/05-plan\.md/{exit} f && NF' | wc -l   #  7 1 to 25
smoke_res "$O" | grep -cF '.aew/runs/201/05-plan.md'; smoke_res "$O" | grep -cF 'Answer with /aew:resume 201'   #  8 >= 1; 1
smoke_main "$O" | grep -c '^AskUserQuestion'                                              #  9 0
smoke_pair "$O"                                                                           # 10 1 (record the prompts: phase: A, mode: plan)
smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /\.aew\/runs\//'                       # 11 only 05-plan.md
smoke_state_valid "$RUN/state.json"; smoke_denials "$O"; ls -A "$W/ghcfg"                 # 12 valid; []; empty
smoke_norm "$GHM/calls.log"                                                               # 13 auth-status, issue-fetch, issue-edit +aew:analysing, [revision lines], issue-edit +aew:planning, issue-edit +aew:awaiting-approval (record)
```

Snapshot for 9.6, after the checks pass:

```sh
(cd "$RUN" && shasum 00-issue-original.md issue.json 01-spec-analysis.md spec-final.md 02-brief.md 03-standards.md 04-qa-test-plan.md 05-plan.md) > "$W/out/g2-artefacts.sha"
wc -l < "$RUN/log.md" | tr -d ' ' > "$W/out/g2-log.lines"
git -C "$P" status --porcelain > "$W/out/g2-status.txt"     # expect only .claude/agent-memory/ lines (PD-2)
```

Fallback: if spec-analyser returns `needs_input` on #201 (the out-of-repo email AC), G2 stops at the spec gate and
fails check 1. Record it, rewrite AC-4 of #201's body **in the mock store only** (`$GHM/issues/201/body`) as "out of
scope: the order service sends the email", never in the fixture's committed `issue.json`, and re-run as `G2.2`; S1
uses the same body; note it in 9.9.

| run | check | result | notes |
|---|---|---|---|
| G2 | 1 gate state | pass | Attempt G2.3 (cap 6.43, so G2 stays within its 8; cost 2.6318, `claude-opus-5-5`, 64 turns, 436 s), after the silent-test fix (`e5a01fb`, `8378c33`, `b3684c1`), in G2.2's project (no run in it, the mock-only AC-4 body, the allow file regenerated from the current helpers: unchanged, 85 lines): `plan`, `awaiting_plan_approval`, `false`. Step 3.1 printed `absent` and the run started. History: G2.1 (cap 8, cost 1.2173, 37 turns) is the fallback case: spec-analyser returned `needs_input` on AC-4 (the email) with four non-material changes and ship stopped at the spec gate (`spec_analysis`, `awaiting_input`, `false`), correct behaviour, kept as `$SMOKE/ship-g2-g21`. G2.2 (cap 6.75, cost 0.3488, 12 turns), fresh `ship-g2` project with AC-4 rewritten in `$GHM/issues/201/body` only, stopped at step 3.1 with no run: the bare `test -e .aew/runs/<n>` was false, the model saw `(Bash completed with no output)` and printed `Run 201 already exists: …` (the silent-test finding, 9.9). |
| G2 | 2 pending note | pass | G2.3: `gate:plan-approval 05-plan.md`. History: G2.1 `gate:spec 01-spec-analysis.md`; G2.2 no run. |
| G2 | 3 run stays current | pass | G2.3: `201`. History: G2.1 `201`; G2.2 no `current`. |
| G2 | 4 label | pass | G2.3: the one stage label is `aew:awaiting-approval` (`issue edit 201 --add-label aew:awaiting-approval --remove-label aew:planning`), plus the flag `aew:spec-revised` that the revision lines set (spec v2). History: G2.1 exactly `aew:awaiting-input`; G2.2 none. |
| G2 | 5 nothing after the gate | pass | G2.3: 0 dev reports; on `feat/201-add-to-basket`, `main..HEAD` 0 commits, `main` unchanged at the fixture commit, origin has only `main`. No `docs(standards)` commit: standards-setter found no stack and `git status --porcelain -- docs/standards` was empty. Project tree: only `?? .claude/` (4 files under `aew-spec-analyser/` and `aew-senior-engineer/`, PD-2). History: G2.1 the same with 2 memory files; G2.2 nothing written. |
| G2 | 6 gate output | pass | G2.3: `grep -cF 'aew ship #201: waiting at the plan-approval gate.'` 1 (the result's first line). History: G2.1 printed the spec gate's line; G2.2 no gate. |
| G2 | 7 summary of 25 lines or fewer | fail (as written) | G2.3: the check's awk prints 0, because the model put the path in the summary's heading (line 3, `` **Plan for #201, "Add to basket"** (`.aew/runs/201/05-plan.md`) ``) instead of after the summary, as `gates.md` `## Gate: plan-approval` step 3 says ("Then print the path"). The limit itself holds: 16 non-blank lines of plan summary (approach, one work package WP-1 and no parallel work, no spec challenges, three risks, "all 15 (AC-1 to AC-15) map to WP-1"), then a 4-line "Status so far" and the question, 22 non-blank lines between the gate line and the resume hint. An ordering deviation by the model, not a permission or skill-text defect. |
| G2 | 8 plan path and resume hint | pass | G2.3: `.aew/runs/201/05-plan.md` 1; `Answer with /aew:resume 201` 1 (the last line). The question `Approve the plan for #201?` with `Approve (recommended)`, `Request changes`, `Stop` is printed, not asked. History: G2.1 the spec gate's hint 1; G2.2 0 and 0. |
| G2 | 9 AskUserQuestion never attempted | pass | G2.3, G2.1, G2.2: `smoke_main \| grep -c '^AskUserQuestion'` 0; `system/init` `.tools \| index("AskUserQuestion")` `null`. |
| G2 | 10 QA phase A and plan in one message (AC-7) | pass | G2.3: `smoke_pair` 1. One assistant message `msg_011CgPRjR2mP9fyRuHebjdt4` holds both Agent calls: `aew:senior-engineer` (`toolu_01BxGVE54fioBmNqbyGgxWsH`, prompt `run_dir: .aew/runs/201` / `mode: plan`) and `aew:qa-engineer` (`toolu_01LPumWWRJ9GwgxGLLew8NCD`, prompt `run_dir: .aew/runs/201` / `phase: A`). The other dispatches each had a message of their own: spec-analyser, brief-compiler, standards-setter. History: G2.1 and G2.2 0 (not reached). |
| G2 | 11 reads hygiene (AC-19) | pass | G2.3: one main-thread Read under `.aew/runs/`, `05-plan.md` (the plan gate's full read, after the pending state and label were set). Every other run-dir check is a printing `test -f … && echo yes \|\| echo no` or a bounded `jq`. History: G2.1 and G2.2 none. |
| G2 | 12 state valid, denials, config dir | pass | G2.3: `state.json` valid; `smoke_denials` `[]`, no `Permission for this tool use was denied` text in the stream; `$W/ghcfg` empty. Launcher exit 0, `audit clean (57 Bash commands)`, no guard files, plugin repo HEAD `b3684c1` and clean before and after; Write/Edit only under the project's `.aew/runs/201/` and `.claude/agent-memory/`. Debug log: one QA Read of a not-yet-existing `aew-qa-engineer/MEMORY.md` and four `mcp__plugin_context7_context7__*` "takes no tool" warnings (context7 is `needs-auth` here), nothing else. History: G2.1 and G2.2 the same (31 and 10 Bash commands, HEAD `a7180e0`). |
| G2 | 13 `gh` calls | pass | G2.3: `auth-status`, `issue-fetch`, `issue-edit +aew:analysing`, `issue-view-body`, `issue-edit-body`, `issue-comment`, `issue-edit +aew:spec-revised`, `issue-edit +aew:planning`, `issue-edit +aew:awaiting-approval`: the first 8 lines of `expected_s1 1 0 0`, then the gate label (`diff` empty). The standards and plan stages' `planning` calls are no-ops. `calls.log` is shared with G2.2 (same `$W/gh`), so its first line, G2.2's `auth status`, is dropped. History: G2.1 had `auth-status` twice (the model re-ran its silent checks with `&& echo`, the same finding), then `issue-fetch`, `issue-edit +aew:analysing`, `issue-edit +aew:awaiting-input`; G2.2 `auth-status` only. |

### 9.6 Run F1 and R2: kill during develop, resume to review

Task F5 (AC-43 as amended by cut 2). Caps: run F1 2, R2 10 (killed sessions count their cap). Both reuse G2's project
and its snapshot. Run F1's kill condition is "stage `develop` and the `aew:developer` Agent call in the stream", so the
kill lands after the dispatch.

```sh
W="$SMOKE/ship-g2"; P="$W/p"; GHM="$W/gh"; RUN="$P/.aew/runs/201"
"$SMOKE/ship-run.sh" "$REPO" "$W" F1.1 2 "$W/allow-ship.txt" "/aew:ship 201 --auto --from develop" develop aew:developer
O="$W/out/F1.1"; L0=$(cat "$W/out/g2-log.lines")
```

```sh
cat "$O/killed-at"; smoke_main "$O" | grep -c $'^Agent\taew:developer'; jq -r '.stage, .status' "$RUN/state.json"   # F1-1 a timestamp; 1; develop, running
tail -n +$((L0 + 1)) "$RUN/log.md"                                                        # F1-2 only develop lines, one with the note --from
jq -r .auto "$RUN/state.json"                                                             # F1-3 true (if false, record it)
git -C "$P" status --porcelain                                                            # F1-4 record: empty or only .claude/agent-memory/ lines -> R2 proceeds; anything else -> R2 must stop and list it
pgrep -fl 'playwright/mcp'                                                                # F1-5 none from this run (kill and record otherwise)
```

```sh
"$SMOKE/ship-run.sh" "$REPO" "$W" R2.1 10 "$W/allow-ship.txt" "/aew:resume 201" review
O="$W/out/R2.1"
```

If F1-4 showed partial developer work, R2.1 must stop and list the dirty paths (AC-21): record that as a pass of
"resume refuses a dirty tree", discard the partial work as a logged harness action (`git -C "$P" checkout -- . &&
git -C "$P" clean -fd -e .claude/agent-memory/`, in a script file) and run `R2.2` with the same command.

```sh
cat "$O/killed-at"; jq -r .stage "$RUN/state.json"                                        # R2-1 a timestamp; review
tail -n +$((L0 + 1)) "$RUN/log.md" | awk '{print $3}' | grep -xcE 'spec_analysis|brief|standards|qa_test_plan|plan'   # R2-2 0
(cd "$RUN" && shasum -c "$W/out/g2-artefacts.sha")                                        # R2-3 every line OK
grep -c '^issue view 201 --json number,title,body' "$GHM/calls.log"                       # R2-4 1 (G2, run F1 and R2 together)
valid_return_block "$RUN/06-dev-report.md"                                                # R2-5 ok (and each 06-dev-report-WP*.md); heading diff against templates/artefacts/dev-report.md as in 8.4 S4/S5 empty
git -C "$P" log --format=%s main..HEAD                                                    # R2-6 the developer's (#201) commits
smoke_state_valid "$RUN/state.json"                                                       # R2-7 valid
smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /skills\/ship\/SKILL\.md$/' | wc -l; smoke_main "$O" | awk -F'\t' '$1 == "Skill"'   # R2-8 >= 1; no aew:ship line
smoke_main "$O" | grep -c $'^Agent\taew:developer'                                        # R2-9 1
smoke_denials "$O"; ls -A "$W/ghcfg"; git -C "$REPO" status --porcelain                   # R2-10 []; empty; this README plus intended fixes
```

"Final state `done`" is not checked here (cut 2): S1 covers it. The SessionStart resume hint in R2's debug log is
expected and harmless (record it).

| run | check | result | notes |
|---|---|---|---|
| run F1 | 1 killed by the poller during develop | pass | Attempt F1.1 (cap 2, counted in full as a killed session; `claude-opus-5-5`), in G2.3's project at the plan gate, allow file regenerated from the current helpers (91 lines: G2.3's 85 plus the six user-connector denials). `killed-at` `2026-10-25T18:43:03Z`, 4 s after `state.sh stage develop --note "--from"` (18:42:59Z); session exit 143, no `result` event. One main-thread `Agent` call, `aew:developer` with `run_dir: .aew/runs/201` / `mode: full`; the developer made no tool call before the kill. State `develop`, `running`. Before the dispatch: preflight (Check 2 restart form, Check 3 `gh auth status`, Check 4 `git fetch origin main` and the two `rev-list --count`, Check 5, Check 6), the restart checks (`state.json`, branch, `02-brief.md`, `03-standards.md`, `05-plan.md` present), `state.sh current set 201`, `state.sh set auto true`, the branch already `feat/201-add-to-basket`, then the label and the stage write: the model ran `gh-labels.sh stage 201 building` just before `state.sh stage develop` (SKILL.md `## Stage: develop` step 1 says state first; harmless here, recorded). |
| run F1 | 2 `--from` recorded, nothing earlier re-entered | pass | `log.md` after G2's 5 lines: exactly one line, `- 2026-10-25T18:42:59Z develop running — --from`. |
| run F1 | 3 auto recorded | pass | `true` (was `false` at the plan gate; Step 4.3's `state.sh set auto true`). |
| run F1 | 4 tree after the kill | pass | Only `.claude/agent-memory/` (the same four untracked files as after G2), no commit on the branch (`main..HEAD` empty), so R2 proceeds without the dirty-tree path; 01 to 05 artefacts still match the G2 snapshot. |
| run F1 | 5 no leftover processes | pass | No `claude` or Playwright MCP process from F1.1 after the kill; the one `@playwright/mcp` process (pid 30925) belongs to S1's parallel session (its parent is S1's `claude -p /aew:ship 201 --auto`, cwd `ship-s1/p`) and was there before F1.1 started. Port 4173 free before and after. Launcher exit 0, `audit clean (20 Bash commands)`, no guard files, plugin repo HEAD `0bc414f` and clean before and after, `$W/ghcfg` empty. `system/init`: `acceptEdits`, AskUserQuestion absent, and the only MCP tools are the 25 `mcp__plugin_aew_playwright__*` ones: the user connectors (`notion`, `claude.ai Claude Docs`, `Figma`, `Google Drive`, `Gmail`, `Google Calendar`) are listed in `mcp_servers` but expose no tool, context7 is `needs-auth`. No denial text in the stream. |
| R2 | 1 killed at review | pass | Attempt R2.1 (cap 10, counted in full as a killed session; `claude-opus-5-5`), straight after F1.1 with no harness action in between (F1-4 clean, so no dirty-tree stop and no R2.2). `killed-at` `2026-10-25T18:45:06Z`, 1 s after `state.sh stage review` (18:45:05Z), before any review dispatch; session exit 143, no `result` event (about 80 s of session). State `review`, `running`. QA never reached (no `qa`, `docs` or `pr` line in `log.md`). |
| R2 | 2 no earlier stage re-entered | pass | `0`. `log.md` after G2's 5 lines: F1's `develop running — --from`, then `develop running — resume` (18:44:07Z) and `review running` (18:45:05Z). |
| R2 | 3 01 to 05 artefacts byte-identical | pass | `shasum -c` against `g2-artefacts.sha`: all eight lines `OK` (`00-issue-original.md`, `issue.json`, `01-spec-analysis.md`, `spec-final.md`, `02-brief.md`, `03-standards.md`, `04-qa-test-plan.md`, `05-plan.md`). |
| R2 | 4 one issue fetch in total | pass | `1` (G2.3's fetch). F1.1 and R2.1 added only `auth status`, label reads and `issue edit 201 --add-label aew:building --remove-label aew:awaiting-approval` (F1.1; R2.1's `building` was a no-op). |
| R2 | 5 a valid developer report | pass | `06-dev-report.md`: `valid_return_block` `ok`, `## ` headings equal `templates/artefacts/dev-report.md`'s, `Mode: full`, NEXT `senior-engineer review`, `node --test` pass (2 tests). No `06-dev-report-WP*.md`: WP-1 ran sequentially, no fan-out. Deviations it records: the untracked `.claude/` at start, no red run (the new test covers existing behaviour), and no browser check of the plan's viewport mitigation (the developer has no browser tool; left to QA). SubagentStop gate: exit 0, `success`. Ship's return check was `awk 'NF' … \| tail -n 4` on the report. |
| R2 | 6 developer commits on the branch | pass | `main..HEAD`: one commit, `c2207f1 feat(basket): show live count and name basket button (#201)` (`site/app.js`, `site/index.html`, `tests/unit/basket.test.js`; explicit-path `git add`). |
| R2 | 7 state valid | pass | `smoke_state_valid`: valid. `auto` `true`, `review_cycle` 0, `fix_cycle` 0, `branch` `feat/201-add-to-basket`. |
| R2 | 8 resume reused ship by Read (AC-21) | pass | One main-thread Read of `skills/ship/SKILL.md`, then `preflight.md`, `dispatch.md` and `routing.md`; no Skill-tool call on any thread. Resume's checks: Step 1/2 in one compound Bash (`test -f … ; jq … ; jq …`, not denied), Check 1, Check 3 (`gh auth status`), Check 5 (`cat .aew/runs/current`), Check 2 restart form, branch already current, `state.sh current set 201`, then `## Stage: develop` step 1 in order (`state.sh stage develop --note "resume"`, then `gh-labels.sh stage 201 building`), `state.sh get review_cycle` (0, so full mode, D8) and `ls .aew/runs/201` for the required inputs (instead of one `test -f` per file; recorded). |
| R2 | 9 developer re-dispatched once, from develop | pass | `1`: the only main-thread Agent call is `aew:developer` (`mode: full`). Developer Bash: `git status --porcelain`, `node --test`, `git add …`, `git commit -m …`; no app start, no port-4173 or Playwright command, no MCP call on any thread. |
| R2 | 10 hygiene | pass | No `result` event, so `smoke_denials` prints nothing; no `Permission for this tool use was denied` text in the stream (0). `$W/ghcfg` empty. Launcher exit 0, `audit clean (18 Bash commands)`, no guard files, plugin repo HEAD `0bc414f` before and after, `git -C "$REPO" status` only this README. `system/init` as in F1.1 (25 `mcp__plugin_aew_playwright__*` tools, no user-connector tool). Project tree after the kill: only the four `.claude/agent-memory/` files. Debug log: the SessionStart resume hint ran as expected and harmless (`Active aew run 201 at stage develop (running). Use /aew:resume.`), plus two context7 "takes no tool" warnings. |

### 9.7 I1 and I2: init twice

Task F6 (AC-44). Caps: I1 3, I2 3. Expectations are Phase D's D-C4 as merged; if it differs from the rows below,
update them before I2 runs and note it in 9.9. Init's settings proposal is printed, never written, headless.

```sh
smoke_ship_project init next
printf '7\n' > "$GHM/responses/pr-list.2.out"     # I2's reuse lookup (D-C4); I1's lookup (call 1) gets nothing
smoke_ship_allow init > "$W/allow-init.txt"
# the D2 reference proposal, copied verbatim from the merged Phase D skill or plan, saved with the Write tool as "$W/ref.json"
"$SMOKE/ship-run.sh" "$REPO" "$W" I1.1 3 "$W/allow-init.txt" "/aew:init"
O="$W/out/I1.1"
```

```sh
git -C "$P" branch --show-current; git -C "$P" rev-list --count main..chore/aew-init; git -C "$P" log -1 --format=%s chore/aew-init   # I1-1 chore/aew-init; 1; chore: set up aew
git -C "$W/origin.git" rev-parse refs/heads/chore/aew-init; git -C "$P" rev-parse chore/aew-init   # I1-2 equal
npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "$REPO/templates/config.schema.json" -d "$P/.aew/config.json"   # I1-3 valid
diff <(jq -S . "$P/.aew/config.json") <(jq -S . "$W/ref.json")                            # I1-4 no output
grep -cxF '.aew/runs/' "$P/.gitignore"; grep -cxF '.playwright-mcp/' "$P/.gitignore"      # I1-5 1; 1
grep -cxF '## Agentic workflow' "$P/CLAUDE.md"                                            # I1-6 1
ls "$P/docs/standards"                                                                    # I1-7 README.md, nextjs.md, tailwind.md
grep -c '^label create' "$GHM/calls.log"; grep -c '^pr list' "$GHM/calls.log"; grep -c '^pr create' "$GHM/calls.log"; grep '^pr create' "$GHM/calls.log" | grep -c -- '--base main'   # I1-8 11; 1; 1; 1
test ! -e "$P/.claude/settings.json" && test ! -e "$P/.claude/settings.local.json" && echo absent; smoke_res "$O"   # I1-9 absent; the report lists the printed proposal (both files), "Playwright skipped" and the defaults used
git -C "$P" status --porcelain; ls "$P/.aew/runs" 2>/dev/null                             # I1-10 empty; no init-* file
smoke_denials "$O"; ls -A "$W/ghcfg"; smoke_main "$O" | grep -c '^AskUserQuestion'        # I1-11 []; empty; 0
smoke_main "$O" | grep -c $'^Agent\taew:standards-setter'                                 # I1-12 1, and its prompt is exactly mode: init (C-2)
{ git -C "$P" rev-parse main chore/aew-init; git -C "$W/origin.git" rev-parse main chore/aew-init; } > "$W/out/i1-heads"
shasum "$P/.aew/config.json" > "$W/out/i1-config.sha"; wc -l < "$GHM/calls.log" | tr -d ' ' > "$W/out/i1-calls.lines"
```

I2 straight after, same project:

```sh
"$SMOKE/ship-run.sh" "$REPO" "$W" I2.1 3 "$W/allow-init.txt" "/aew:init"
git -C "$P" status --porcelain                                                            # I2-1 empty
diff "$W/out/i1-heads" <({ git -C "$P" rev-parse main chore/aew-init; git -C "$W/origin.git" rev-parse main chore/aew-init; })   # I2-2 no output
shasum -c "$W/out/i1-config.sha"                                                          # I2-3 OK
tail -n +$(( $(cat "$W/out/i1-calls.lines") + 1 )) "$GHM/calls.log" | awk '{print $1, $2}' | sort | uniq -c   # I2-4 11 label create, 1 pr list; no pr create
smoke_main "$W/out/I2.1" | grep -c 'git-branch.sh.* push'                                # I2-5 0
smoke_res "$W/out/I2.1"                                                                   # I2-6 says nothing changed and names PR 7
smoke_denials "$W/out/I2.1"; ls -A "$W/ghcfg"                                             # I2-7 []; empty
```

| run | check | result | notes |
|---|---|---|---|
| I1 | 1 branch and one commit | pass | Attempt I1.2 (cost 0.9362, 29 turns, `claude-opus-5-5`, `acceptEdits`, a fresh `$SMOKE/ship-init`, plugin HEAD `b3684c1`): `chore/aew-init`; `1`; `chore: set up aew` (commit `ffa8a46` on the fixture commit `286d9ba`). History, I1.1 (cost 0.9736, HEAD `a7180e0`): pass, commit `65bde80`. |
| I1 | 2 pushed to the bare origin | pass | I1.2: both `ffa8a46ad0cba7d512deb7bf16577e0b1d0e746b`, through `git-branch.sh push` after section 12's snippet printed `unpushed 1` and `ahead 1`. History, I1.1: pass. |
| I1 | 3 config validates | pass | I1.2: `.aew/config.json valid`. Section 6's first snippet ran as written and printed `config changed`, then the second printed ajv's `valid` and `config written`. History, I1.1: pass, but section 6's first snippet was not run. |
| I1 | 4 config equals the reference | pass | I1.2: `diff` against the D2 reference proposal prints nothing (`retro.repo` is the plugin repo, Assumption 23). History, I1.1: pass. |
| I1 | 5 gitignore | pass | I1.2: `1`; `1`; no `.claude/settings.local.json` line. The model ran section 3's snippet as written, which printed `0`, `missing .aew/runs/` and `missing .playwright-mcp/`. It then appended literally with `printf '%s\n' '.aew/runs/' >> .gitignore` and `printf '%s\n' '.playwright-mcp/' >> .gitignore` (count 0, so no newline repair). There was no Write-tool workaround. History, I1.1: pass, with a deviation (the snippet was denied and the model wrote the file with the Write tool). |
| I1 | 6 CLAUDE.md section | pass | I1.2: `1`. Section 9's snippets ran as written. The first printed `CLAUDE.md section missing` and `0`, then the heredoc append printed `CLAUDE.md section added`. There was no Write-tool workaround. History, I1.1: pass, with a deviation (the model wrote the file with the Write tool). |
| I1 | 7 standards docs | pass | I1.2: `README.md`, `nextjs.md`, `tailwind.md`, with the same fingerprints as I1.1 (`nextjs next@16 react@19 typescript@5 cfg:388ef4ff81b7`, `tailwind tailwindcss@4 cfg:3f0744e5bcde`). History, I1.1: pass. |
| I1 | 8 labels and PR calls | pass | I1.2: `11`; `1`; `1`; `1`. `calls.log` has the same 14 lines as I1.1: `auth status`, the 11 `label create … --force`, `pr list --head chore/aew-init --state open …`, then `pr create --head chore/aew-init --title chore: set up aew --body-file .aew/runs/init-pr-body.md --base main`. PR #7. History, I1.1: pass. |
| I1 | 9 no settings written, Playwright skipped | pass | I1.2: `absent`; `.claude/` holds only an empty `agent-memory/aew-standards-setter/`. The report lists 25 portable rules and the 8 local script rules (again as one path pattern plus the eight script names), the not pre-approved list, "Playwright skipped" and "Defaults used" (install, typecheck, app, `retro.repo`, Playwright, permissions). History, I1.1: pass. |
| I1 | 10 tree clean, scratch removed | pass | I1.2: `git status --porcelain` empty; `.aew/runs/` empty. History, I1.1: pass. |
| I1 | 11 denials, config dir, AskUserQuestion | pass | I1.2: `smoke_denials` `[]`, and no `Permission for this tool use was denied` text in the stream. `ls -A "$W/ghcfg"` empty; AskUserQuestion calls `0` (it is also absent from `system/init` tools). History, I1.1: **fail**, with one denial (the section 3 snippet; see the note below this table). |
| I1 | 12 standards-setter init mode | pass | I1.2: `1`; the prompt is exactly `mode: init`. The agent ran `detect-stack.sh .`, `fingerprint nextjs .`, `fingerprint tailwind .`, one `find` and `ls docs/standards`, and generated nextjs and tailwind. Launcher exit 0, `audit clean (30 Bash commands)`, no guard files, `stderr.txt` empty. History, I1.1: pass. |
| I2 | 1 no file diff | pass | Attempt I2.1 (cost 0.6379, 26 turns, `claude-opus-5-5`), straight after I1.2: `git status --porcelain` empty (and with `--untracked-files=all --ignored`). History: not run after I1.1 (the lane stopped). |
| I2 | 2 heads unchanged | pass | `diff` with `i1-heads` prints nothing: local and origin `main` are `286d9ba…`, `chore/aew-init` is `ffa8a46…`. Still on `chore/aew-init` (`Already on 'chore/aew-init'`). |
| I2 | 3 config unchanged | pass | `shasum -c`: `OK`. Section 6 printed `config unchanged`, and section 5's re-run comparison printed nothing. |
| I2 | 4 calls since I1 | pass | `1 auth status`, `11 label create`, `1 pr list`, no `pr create`. The `auth status` line is init's section 1 canary, which the expectation leaves out. |
| I2 | 5 no push | pass | `0`. Section 12's snippet printed `unpushed 0` and `ahead 1`, and `gh-pr.sh open` printed `7` (the canned `pr-list.2.out`). |
| I2 | 6 report | pass | "The project was already set up, so this re-run changed no files and made no commit. It reused the open PR, **#7**." Section 3 printed `0` and `present` twice; section 9 printed `CLAUDE.md section present` and `0`; standards reused; the standards-setter memory did not change (nothing to discard). |
| I2 | 7 denials, config dir | pass | `[]`, and no denial text in the stream; `ls -A "$W/ghcfg"` empty; AskUserQuestion `0`. Launcher exit 0, `audit clean (25 Bash commands)`, no guard files, plugin repo HEAD `b3684c1` before and after. |

I1.1 finding (skill fault, not fixed here): under `--permission-prompts none`, Claude Code refuses init section 3's
gitignore snippet as a compound command whose parts need approval, although every leading form in it (`grep`,
`tail -c`, `printf`, `echo`) runs without a rule or has one. The section 2 branch snippet (a multi-line `if` with `||`
and redirects but no pipe in a condition) ran in the same session. Likely cause, inferred and not verified: a
pipeline inside an `if` condition (`if tail -c 1 .gitignore 2> /dev/null | grep -q .; then … >> .gitignore; fi`); the
denial text shows the parts split at the pipe and lost their redirects. `tests/scripts/skills.bats` test 17 (H1 to
H8, M1) does not catch this form. The same form appears in section 9's second snippet (line 298, which the model did
not run) and section 10's first snippet (line 407, which runs only on a yes). After the denial the model also skipped
section 6's first snippet (it ran its `else` branch, `jq . .aew/runs/init-config.json > .aew/runs/init-config-merged.json`,
and printed no `config changed`) and section 12's push snippet (it ran `git rev-list --count main..HEAD` and printed
no `unpushed`/`ahead` lines). It reached the right result both times, but not through the skill's text. I2 and G1 wait
for the fix and an I1 re-run (I1.2) on a fresh `ship-init` project.
Fixed in `e5a01fb`, `8378c33` and `b3684c1`: sections 3, 9, 10 and 11 no longer put a pipe inside an `if`, and
every check prints its outcome. I1.2 ran every init snippet as written, with no denial and no workaround, and I2.1
followed.

### 9.8 G1: spec-gate stop on init's output

Task F6 (AC-41, cut 4). Cap 3. G1 runs on init's project after the init PR is treated as merged. The preparation is a
harness action in a script file, `$SMOKE/g1-prep.sh` (written with the Write tool, run with `/bin/bash`):

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

Then seed #103 (the render also proves it is byte-identical to the fixture), re-create `smoke_ship_project`'s four
canned replies in the new `$GHM` (owner `acme`, repo `web`), and build the allow file with `$P` = this project:

```sh
smoke_render material-guest-access.md 103 "Let readers save favourite articles"
smoke_ship_issue 103 "$REPO/tests/tmp/issue-render-103/gh/responses/issue-view.out"
smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" G1.1 3 "$W/allow-ship.txt" "/aew:ship 103 --auto"
RUN="$P/.aew/runs/103"; O="$W/out/G1.1"
```

```sh
jq -r '.stage, .status' "$RUN/state.json"                                                 #  1 spec_analysis, awaiting_input
jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' "$RUN/state.json"   #  2 gate:spec 01-spec-analysis.md
grep '^aew:' "$GHM/issues/103/labels"                                                     #  3 exactly aew:awaiting-input
test ! -e "$RUN/02-brief.md" && echo none                                                 #  4 none
Q=$(grep -c '^### Q[0-9]' "$RUN/01-spec-analysis.md"); echo "$Q"; smoke_res "$O" | grep -c 'recommended'   #  5 Q >= 1; count >= Q (record the printed questions' first lines)
smoke_res "$O" | grep -cF 'aew ship #103: waiting at the spec gate.'; smoke_res "$O" | grep -cF 'Answer with /aew:resume 103'   #  6 1; 1
jq -r .auto "$RUN/state.json"; smoke_main "$O" | grep -c '^AskUserQuestion'               #  7 true; 0 (auto does not skip the gate, AC-8)
smoke_main "$O" | head                                                                    #  8 gh auth status, git fetch origin main and the rev-list check ran; no stop
jq -r .branch "$RUN/state.json"; cat "$P/.aew/runs/current"; smoke_state_valid "$RUN/state.json"   #  9 a feat/103-… name (record); 103; valid
smoke_denials "$O"; ls -A "$W/ghcfg"; git -C "$P" status --porcelain                      # 10 []; empty; only .claude/agent-memory/ lines (PD-2; record)
```

| run | check | result | notes |
|---|---|---|---|
| G1 | 1 gate state | pass | Attempt G1.2 (cap 4, cost 0.9741, 32 turns, `claude-opus-5-5`, plugin HEAD `eac8af4`), after `g1-reset.sh` (G1.1 undone, #103 re-seeded with mock AC 5, see 9.9): `spec_analysis`, `awaiting_input`. spec-analyser returned `STATUS: needs_input` with 5 non-material and 2 material changes. History, G1.1 (cost 1.9678): `plan`, `running` (spec-analyser `ok`, 0 material; see the G1.1 note). |
| G1 | 2 pending note | pass | G1.2: `gate:spec 01-spec-analysis.md` (`log.md`: `spec_analysis awaiting_input — gate:spec 01-spec-analysis.md`). History, G1.1 (cost 1.9678): `null`. |
| G1 | 3 label | pass | G1.2: exactly `aew:awaiting-input` (`issue edit 103 --add-label aew:awaiting-input --remove-label aew:analysing`). History, G1.1 (cost 1.9678): `aew:planning`, `aew:spec-revised`. |
| G1 | 4 nothing after the gate | pass | G1.2: `none`. The run dir holds only `00-issue-original.md`, `01-spec-analysis.md`, `issue.json`, `log.md`, `spec-changes.json`, `spec-final.md` and `state.json`. Nothing was posted to the issue as a revision (`spec_revision` is still 1), and the session made 1 Agent call (`aew:spec-analyser`). History, G1.1 (cost 1.9678): `02-brief.md` and `03-standards.md` existed. |
| G1 | 5 questions with recommended answers | pass | G1.2: `Q=2`; `recommended` count `2`. Q1: "Should AC 5 (cross-device sync) be replaced by per-device persistence in the reader's browser, with cross-device sync moved to a follow-up issue? (change #6)". Q2: "Should a "Favourites" link be added to the footer navigation next to About and Contact? (change #7)". Each is printed with "Yes (recommended)" and two alternatives. History, G1.1 (cost 1.9678): `Q=0`. |
| G1 | 6 gate lines | pass | G1.2: `1`; `1` (`aew ship #103: waiting at the spec gate.` and `Answer with /aew:resume 103`). History, G1.1 (cost 1.9678): `0`; `0`. |
| G1 | 7 auto does not skip it (AC-8) | pass | G1.2: `true`; AskUserQuestion `0`, and it is absent from `system/init` tools. `--auto` kept the material gate (AC-8); the result says "I don't have AskUserQuestion in this session, so the gate stays pending and the run stops here." History, G1.1 (cost 1.9678): unproven (no gate). |
| G1 | 8 preflight passed on init's output | pass | G1.2: the same preflight as G1.1 (`gh auth status`, `git fetch origin main`, both `git rev-list --count` checks, `claude plugin list --json \| jq …`), with no stop. History, G1.1 (cost 1.9678): pass. |
| G1 | 9 branch, current, state | pass | G1.2: `feat/103-let-readers-save-favourite-articles`; `103`; `state.json` valid. History, G1.1 (cost 1.9678): pass. |
| G1 | 10 hygiene | pass | G1.2: `[]`, and no denial text in the stream; `ls -A "$W/ghcfg"` empty. Status shows only `?? .claude/agent-memory/aew-spec-analyser/MEMORY.md` and `?? …/project_gap_patterns.md` (PD-2). Launcher exit 0, `audit clean (26 Bash commands)`, no guard files, plugin repo HEAD `eac8af4` before and after. `system/init` tools have no `mcp__notion` or `mcp__claude_ai_*` entry (the only MCP tools are the 25 `mcp__plugin_aew_playwright__*`); `mcp_servers` still lists the user connectors as connected, but their tools are denied by server name. History, G1.1 (cost 1.9678): pass (`audit clean (46 Bash commands)`). |

G1.1 finding (agent judgement, not fixed here): on #103 spec-analyser classified every change as non-material.
Change 1 ("saved articles persist across reloads and return visits in the same browser") is "an implied AC made
explicit", because "per-browser is the only scope the repo supports without adding accounts or a data store". A
link to `/favourites` "would be material, and the issue doesn't ask for one", so the agent left it out instead of
asking. Prompt 03's run 903, on the same fixture, found 2 material rows (storage location, navigation link) and
returned `needs_input` (section 6). So the fixture does not reliably produce a material change, and AC-41 (and the
`--auto` half of AC-8) is not proven by G1.1. Ship then did what the skill says for `ok`: it recorded spec v2
(`gh-issue.sh revise`, the revision comment, `spec-revised`), then ran brief and standards. At `plan` the main
thread stopped on its own: "paused run 103 at the plan stage because the session's spending limit is nearly used up.
About $1.07 of the $3 is left". It wrote the stage note `standards ok; paused before dispatch (session budget)` and
left `plan` / `running` with no gate and no blocked label. That self-pause is not in `skills/ship/`. It is harmless
here (`/aew:resume 103` would continue at `plan`), but it is a deviation from the skill. G1 stays open. A G1.2
re-run needs the project reset first: remove `.aew/runs/103` and `current`, switch to `main`, delete the
`feat/103-…` branch, re-seed #103 in the mock, discard the spec-analyser memory. It also needs a decision on making
#103 reliably material. Resolved by G1.2: #103's AC 5 was made material in the mock store only (9.9), and the run
stopped at the spec gate.

### 9.9 Notes (prompt 05)

Cap raises, harness faults, fixes and deviations, newest last.

- 2026-10-25 Task F1, harness fault found free: macOS `/usr/bin/printenv` prints only its first name argument
  (`printenv HOME USER` prints one line), so the plan's P0a steps 3 and 4 would not have proven the later variables.
  Step 3 is now `env | cut -d= -f1 | grep -xE '…'` (names only, so a token is never printed; it also covers
  `SSH_AUTH_SOCK`), step 4 one `echo` of the six values; the `p0` allow rules are `Bash(env)` and
  `Bash(cut -d= -f1)` instead of `Bash(printenv *)`.
- 2026-10-25 Task F1, audit allowlist: `$SMOKE/audit-allow.json` holds exactly one string, P0a's step 3 command,
  because it names `GH_TOKEN` and `GITHUB_TOKEN` by design. Any other false positive is added the same way, by its
  exact string, after it is classified.
- 2026-10-25 Task F1, keychain: on this machine a real `gh` with an empty `GH_CONFIG_DIR` still finds the keychain
  token (`gh auth token` exit 0); `GH_HOST=aew-smoke.invalid` makes it fail (exit 1). Rail 3 rests on `GH_HOST`.
- 2026-10-25 Task F1, launcher beyond the plan's reference text (all in the direction of the rails): the session
  environment is one array, also used by `--env-check` so the free CTO-2 checks run in exactly that environment; it
  refuses a `<W>` outside `$SMOKE`, a project whose remotes are not exactly the bare `origin`, a non-numeric cap and
  an allow file that adds a `gh` rule, the bypass mode or a launcher flag; the ledger and the audit allowlist are found
  beside the launcher (one path for every lane); a killed session always counts its cap, and is sent SIGKILL 30 s after
  SIGTERM; the port-4173 stop kills only a listener whose working directory is inside this project, so a kill in one
  lane can't stop another lane's QA server; the audit treats any path ending in `/claude` as a `claude` command.
- 2026-10-25 Task F1, placement: S1's `expected_s1` and `s1_flags` live in 9.2's helpers (so the loader defines them);
  9.4 names them and carries the sentence on where the flags come from.
- 2026-10-25 Task F1, open for P0: the CTO-3 deny `Edit(//<repo>/**)` follows the documented absolute form; P0a and
  P0b confirm it loads without a startup warning. The git guard hashes the shared `config` of the plugin checkout, so
  nothing in `$REPO` (or any of its worktrees) may change git config while a session runs (for example
  `git branch -u` or `git config`); a mismatch is still a P0 failure until classified.
- 2026-10-25 Task F2, P0 BLOCKED (P0a.1 0.0092, P0b.1 0.2333; P1 not run). Platform fact: with
  `--permission-prompts none`, Claude Code denies a Bash command before matching the allow rules when it holds a
  `$VAR` expansion (`A variable in this command can't be checked before it runs`), a `"$(…)"` substitution (`Quoted
  text in this command can't be checked before it runs`) or a glob in a path argument (`Shell expansion syntax in
  paths requires manual approval`); interactively each one prompts. Harness fault: P0a steps 4 and 7 are denied, so
  check 3 is unproven inside the session; a re-probe needs step 4 without `$` (for example `env | grep -E
  '^(GH_CONFIG_DIR|GH_MOCK_DIR|GH_HOST|GIT_CONFIG_COUNT|GIT_TERMINAL_PROMPT|GIT_SSH_COMMAND)='`, none of them a secret,
  checked against the audit patterns first) and a decision on step 7, then a full P0 re-run as P0a.2 and P0b.2.
- 2026-10-25 Task F2, skill defects exposed (not fixed here, reported to the fix loop): `skills/status/SKILL.md`
  line 32 (the listing `jq … .aew/runs/*/state.json`, denied in P0b.1) and line 40 (the fallback `for f in
  .aew/runs/*/state.json; do … "$f" …`); `skills/ship/SKILL.md` line 129 (step 3.5, `state.sh set title "$(jq -r
  .title …)"`, the form P0a step 7 shows is denied); `skills/init/SKILL.md` lines 134, 303, 410, 446 and 447 (`"$(…)"`
  and `$var` in `if` tests). Each would be denied in every headless session and prompt in every interactive one.
- 2026-10-25 Task F2, warnings: every session's debug log carries seven `[WARN] [permissions]` lines, one per
  `Bash(git -C * <sub> *)` allow rule (a wildcard before the subcommand also approves options such as `-c`). These
  are the harness-only developer rules of 961; they are not a startup error and the `Edit(//<repo>/**)` deny loads
  without one.
- 2026-10-25 Task RW4, P0.1 outcome as a finding: under `--permission-mode acceptEdits --permission-prompts none` the
  pre-check denies, whatever the allow rules, any `$VAR` / `"$VAR"` / `$?`, any `$(…)` or backtick substitution, any
  glob in a non-`ls` path argument, and `jq --arg name value` placed before the filter or `jq --slurpfile`. The full
  rule table (probe RULES.1, rewrites per form) is recorded in DESIGN §3 by F8; the skills are being rewritten to it
  (RW1 to RW3). Rule misses are separate: a command whose leading form has no rule (an env prefix, `git rev-parse`,
  `command -v`, `node -p`, …) is denied as "requires approval".
- 2026-10-25 Task RW4, P0a probe rewritten (P0a.2 and P0b.2 re-run pending, paid, not run here): step 4 is now
  `env | grep -E '^(GH_CONFIG_DIR|GH_MOCK_DIR|GH_HOST|GIT_CONFIG_COUNT|GIT_TERMINAL_PROMPT|GIT_SSH_COMMAND)='`, so
  there is no `$` and no secret is printed (none of the six is one). Audit check: the CTO-4 patterns `GH_HOST=` and
  `GH_CONFIG_DIR=` need the literal `=` right after the name, and here `)` sits between, so the command does not hit
  and needs no `audit-allow.json` entry (it stays at the one step-3 string; verified with the launcher's own filter).
  The step 4 output is a tool result, which the audit does not scan. Step 7 (`"$(jq …)"`, denied by design) becomes
  two steps: 7 reads the value (`jq -r .project .aew/config.json`) and 8 passes a literal double-quoted argument to
  `state.sh set title`, the form ship step 3.5 now uses (read, then a literal argument). In P0 there is no run, so
  step 8 exits 1 and writes nothing; the evidence is the absence of a pre-check denial. The `p0` allow rules lose
  `Bash(echo *)` (no longer used).
- 2026-10-25 Task RW4, `smoke_ship_allow` (ship, p0, init) gained `git rev-list --left-right *`, `git check-ignore *`,
  `git symbolic-ref *`, `git ls-remote *`, `command -v *` and `node -p *`; the status `for`-loop `printf` rule is gone.
  TODO for the orchestrator to reconcile once RW1 to RW3 report (do not guess): further leading forms their rewrites
  run that are not auto-allowed (candidates from RULES.2 M2: `exit`, `wc`, `x=` forms, anything RW2 adds for the
  status listing, anything RW3 keeps in init sections 1 to 13); V-7 anchoring of the new rules (they are
  `<cmd> *` wildcards, broader than a user-settings template should be); whether the init list's remaining entries
  (`rm -f "$f"`, `read -r f`, `[ *`, `true`, `exit 1`, `continue`) still apply after RW3 removes `$var` and loops.
- 2026-10-25 Task RW5, RW4's TODO reconciled against the merged RW1 to RW3 skills (scanned, not guessed):
  `smoke_ship_allow` now gives every lane only the scripts and the shared forms (`gh auth status`, `git status`,
  `git switch`, `git add`, `git commit`, `jq`, `printf`, `echo`, `date`); `ship` and `p0` add ship's forms
  (`claude plugin list --json`, `git fetch origin main`, `awk`, `test`, `tail -n`, `grep -c`) and the agents' git
  reads (`git rev-parse`, `git branch`, `git diff`, `git log`, `git show`); `init` adds `command -v`, `git rev-parse`,
  `git remote -v`, `git symbolic-ref`, `git ls-remote`, `git check-ignore`, `git ls-files`, `git restore --`, the
  `npx … ajv validate` line, `cat` (the quoted-heredoc append), `mkdir -p` (`.claude`) and the agent-memory `rm -f`.
  Dropped: `git rev-list --left-right *` (nothing runs it now), `node -p *`, `cat .aew/runs/current`, `ls *`, and the
  init entries `git --version`, `jq --version`, `node --version`, `touch`, `grep`, `tail`, `rm -f .aew/runs/init-*`,
  `pwd -P`, `git remote get-url origin`, `git merge-base --is-ancestor`, `git rev-list --count`, `cp`,
  `rm -f "$f"`, `read -r f`, `[ *`, `true`, `exit 1`, `continue` (unused, or seen running without a rule in
  RULES.2). `test`, `tail -n` and `grep -c` are in the Claude Code 2.1.308 bundle's read-only tables (`test` and
  `grep` safe-flag tables, `tail` in the read-only command list), so init's template has no rule for them; the
  harness keeps its wildcards because no session has run them without one. Allow files: ship 85 lines, p0 90,
  init 44. The free I-9 dry-run passes with them (`diff-exit=0`, the only `gh` rule `Bash(gh auth status)`,
  `bypassPermissions` 0, `Edit(//<repo>/**)`). `tests/scripts/skills.bats` test 17 now checks every entry-skill
  command against the Rewrite guide (H1 to H8, M1) statically.
- 2026-10-25 Task F2 re-run, P0 passes and P1 passes (P0a.2 0.0096, P0b.2 0.2160, P1.1 0.2086; ledger total 0.7124).
  Fresh project `$SMOKE/ship-p0b`, allow files regenerated from the current `smoke_ship_allow` (p0a 92 lines with
  `--model haiku`, ship 85; the only `gh` rule `Bash(gh auth status)`), the P0a prompt rebuilt from 9.3's text with
  `<REPO>` substituted and no other `$`. No permission denial in any of the three sessions. The RW4 probe rewrite
  holds: step 4 (`env | grep -E '^(…)='`) runs and proves all six values inside the session, and step 8 (a literal
  double-quoted argument to `state.sh`) is not pre-check denied. The RW2 status rewrite holds: the listing `jq` with
  `--arg cur -` after the filter and a glob file path runs headless (`no matches found` under the session's zsh), and
  the model ran only the skill's commands. One wording deviation, not a permission or skill-text defect: P0b.2's
  result reads `There are no aew runs in this project.`, where `skills/status/SKILL.md` step 4 says to print `No aew
  runs in this project.` (P0b.1 printed it verbatim); any later check that greps that exact line should allow for it
  or the skill should say "print exactly". P1.1 made no tool call at all; its result is ship's E8 line and usage line
  verbatim.
- 2026-10-25 Task F4, fallback used (9.5): G2.1 stopped at the spec gate on #201's AC-4 (the confirmation email,
  which the issue's own Out of scope gives to the order service), as the spec's Risk foresaw. AC-4 is rewritten in the
  mock store only, `$GHM/issues/201/body` line `4. Out of scope: the order service sends the email.` (an `awk`
  whole-line replacement in the setup script); the fixture's committed `issue.json` is untouched. G2.2 and G2.3 used
  that body, and S1 (9.4) must apply the same body after `smoke_ship_issue`. With it, spec-analyser made spec v2 with
  non-material changes only, so G2.3 passed the revision lines (`issue-view-body`, `issue-edit-body`,
  `issue-comment`, `issue-edit +aew:spec-revised`) and reached the plan gate.
- 2026-10-25 Task F4, skill defect found and fixed (the silent-test finding): Claude Code 2.1.308 reports a false
  `test` (or `[ … ]`) to the model as `(Bash completed with no output)` with `is_error` false. That is exactly what a
  true one returns; only the stream's `tool_use_result.returnCodeInterpretation` (`"Condition is false"`) and the debug
  log's `outcome=error` differ, and the model sees neither. In G2.2 ship step 3.1's bare `test -e .aew/runs/<n>` was
  false, the model read it as true and stopped with `Run 201 already exists: …` in a project with no run; in G2.1 the
  model noticed the blind spot ("The tool hides silent non-zero exits") and re-ran its checks with `&& echo`, which
  doubled `gh auth status` in `calls.log`. Every bare `test -f`/`test -e` in ship (`SKILL.md`,
  `references/preflight.md`, `references/dispatch.md`), resume, status and prompt had the same blind spot; init's
  `if [ -f … ]; then echo …` forms print and were unaffected. Fixed in `e5a01fb` (every check prints its outcome, for
  example `test -e .aew/runs/<n> && echo exists || echo absent`, and no pipes in conditions), `8378c33`
  (`skills.bats` flags silent checks and pipes in conditions) and `b3684c1`. G2.3 ran on the fix: every run-dir check
  printed `yes`/`no` or `exists`/`absent` and the run reached the plan gate.
- 2026-10-25 Task F4, G2.3 deviation (not a skill-text defect): the model printed the `05-plan.md` path in the
  summary's heading, not after the summary as `gates.md` `## Gate: plan-approval` step 3 says, so 9.5 check 7's awk
  (which stops at the path) counts 0. The summary itself is within 25 lines (22 non-blank lines between the gate line
  and the resume hint). A later check should count the lines between the gate line and `Answer with`, or the skill
  should say the path comes last.
- 2026-10-25 Task F4, harness note: G2.2 and G2.3 share `$SMOKE/ship-g2` and so one `$GHM/calls.log`; G2.3's routes
  are that log without its first line (G2.2's `auth status`). G2.1's project is kept as `$SMOKE/ship-g2-g21`. The
  snapshot for 9.6 is in `$SMOKE/ship-g2/out/` (`g2-artefacts.sha`, 8 files; `g2-log.lines` 5; `g2-status.txt` only
  `?? .claude/`, the agent-memory files of PD-2). The session's `system/init` also lists the user-level MCP servers of
  this machine (claude.ai connectors, notion); none was called.
- 2026-10-25 Task F6, G1.2 mock body (the committed fixture `tests/fixtures/issues/material-guest-access.md` is
  unchanged, the same policy as #201): in G1.1, spec-analyser classified #103 all non-material, with per-browser
  storage counted as "an implied AC made explicit". So before G1.2, `$SMOKE/g1-reset.sh` re-seeded #103 and inserted
  one line into the mock's `$GHM/issues/103/body`, directly after AC 4:
  ``5. A reader's favourites sync across all of their devices: an article saved on their phone appears in
  `/favourites` on their laptop.`` (`diff` against the rendered body: `16a17`, that line only). The app has no
  accounts or data store, so storage scope is a real product decision. G1.2 asked it as Q1 (replace sync with
  per-device browser storage, sync as a follow-up) and asked the footer link as Q2. The reset also removed
  `.aew/runs/103`, `current` and `.claude/agent-memory/aew-spec-analyser/`, switched to `main`, deleted the local
  `feat/103-…` branch (never pushed, so the bare origin was untouched) and started a fresh mock (G1.1's is kept as
  `$W/gh-G1.1`). The tree was clean and `main...origin/main` was `0 0` before the launch.
- 2026-10-25 Task F6, G1.1 self-pause (not a skill-text defect, recorded): with about $1.07 of its $3 cap left, the
  main thread stopped at `plan` on its own, with the stage note `standards ok; paused before dispatch (session
  budget)`. `skills/ship/` does not describe this. G1.2 (cap 4) stopped at the gate with $3.03 unused.
- 2026-10-25 Task F6, G1.2 cosmetic: the result says "`gh auth status` produced no output; the docs expect real
  `gh` to fail that check in this offline simulation". This paraphrases `skills/ship/references/preflight.md`
  line 34 (the canary sentence) for the user. Harmless, but that sentence is simulation detail in a user-facing
  reference.
- 2026-10-25 Task F8, roll-up (no paid session): 9.1's table rendered from the 18 ledger files, total $26.82 of the
  $60 stop. G1.2's cap was raised once, from 3 to 4, below the one-raise limit of 2x (6); G2.2 and G2.3 ran on what
  was left of G2's 8, so G2 stayed within its cap; F1.1 and R2.1 are charged at their caps (killed). S1 check 14's
  command now matches RW1's `awk 'NF' <file> | tail -n 4` form (one line on S1.1's stream). G2 check 7 stays
  `fail (as written)`: `0bc414f` tightened `gates.md` `## Gate: plan-approval` step 3 (the path on its own line after
  the summary), and no later run reached a plan gate to show it live.
- 2026-10-25 Task F8, deviations from the spec's run list (CTO cuts 1 to 5): R1 is not simulated (resume's re-ask of
  a pending gate is checked statically by `skills.bats`); R2 stops at `review` instead of running to the PR; the bad
  arguments get one paid probe (P1), the rest are static; G1 runs on init's output (the nextjs fixture's #103) rather
  than on the static shop; run F1's kill condition is stage `develop` plus the `aew:developer` Agent call in the
  stream, so the kill lands after the dispatch. Fixes made during the runs: `e5a01fb`, `8378c33` and `b3684c1`
  (printed checks, no pipes in conditions, gitignore counts), `0bc414f` (connector denials, the plan-gate path line),
  and the RW1 to RW5 rewrite (`af322b5`, `0d4d711`, `b9d2cc3`, `ce2af3e`, `c0789aa`, `dff7d82`, then `8840a5d` and
  `a1d8273` after review; 9.9 above). Open for prompt 07: 9.1's open items, the P0b.2 status wording, the G1.1
  budget self-pause, and the canary sentence in `preflight.md`.
