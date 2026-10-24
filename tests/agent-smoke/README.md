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
  "Bash(mkdir -p *)" "Bash(file -b *)" "Bash(jq *)"
  "Bash(git status *)" "Bash(git diff *)" "Bash(git log *)" "Bash(git rev-parse *)" "Bash(git add *)" "Bash(git commit *)"
  "${T}_navigate" "${T}_snapshot" "${T}_click" "${T}_type" "${T}_press_key" "${T}_select_option"
  "${T}_hover" "${T}_resize" "${T}_console_messages" "${T}_wait_for" "${T}_close"
  --disallowedTools "Bash(gh *)" "Bash(git add -A*)" "Bash(git add .)" "Bash(git reset *)" "Bash(git checkout *)" "Bash(git push *)")
```

The `AEW_EVIDENCE_DIR=` env-prefixed rules are **unverified**: Claude Code strips only a fixed set of env vars before
matching, so the prefix may need its own pattern. There are two because a trailing ` *` matches the bare command only
when it is the rule's only wildcard, and the §8 evidence run is the bare `commands.test_e2e` (`npx playwright test`).
`nohup` is a wrapper Claude Code strips before matching, so `Bash(sh -c *)` is the documented match for the app start
(the app is started by one Bash call with `run_in_background: true` and no trailing `&`: a command with the `&` operator needs interactive approval and is refused headless, run 951 attempt 1; the `app.log` redirect is checked as a write inside the project). A denial of the evidence run or of the `kill` stop in C6 is a
harness fault: add the narrowest matching rule and record the denied command verbatim in the Notes. Dispatch fields:

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

Notes for run 951 cycle 1 (kept state for Phase E):

- Project `$SMOKE/smoke-shop-loop` (stage `qa`, `fix_cycle` 0, branch `feat/201-add-to-basket`, QA's cycle-1 commit); outputs in `$SMOKE/out-951-qa1` (`screens.cycle1`, `head.cycle1` = `828ba57e6359d6d5eef76d9d26578a4d58927f40`).
- TCs per AC: AC-1 TC-1; AC-2 TC-2, TC-3; AC-4 TC-5 (manual); TC-4 passes.
- Triage rows: TC-1 AC-1 `impl_bug`; TC-2 AC-2 `impl_bug`; TC-3 AC-2 `impl_bug`.
- `screens.cycle1` mtimes (epoch seconds): TC-1 1792875850, TC-2 1792875855, TC-3 and TC-4 1792875856, desktop and mobile alike.
- Attempt 1 final message came from a run that lost nothing else: its `out-951-qa1` is not kept (attempt 2 overwrote it).
