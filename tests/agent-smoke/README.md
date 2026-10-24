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
