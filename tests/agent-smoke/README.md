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
- `CONTEXT7_API_KEY` is optional. Without it, context7 calls are anonymous and rate-limited.
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
# standards-setter (Bash: detect-stack.sh and date only)
ALLOW=(--allowedTools "Bash($REPO/scripts/detect-stack.sh *)" "Bash(date *)" "mcp__plugin_context7_context7__*")
# senior-engineer (Bash is read-only: git diff, log, show, status, rev-parse --verify, ls)
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
| Seed path resolution: `${CLAUDE_SKILL_DIR}` substituted in a subagent-preloaded skill; any unexpanded `${` | pending | |
| E-3: `PreToolUse` payload in a subagent carries `agent_type` `aew:<agent>` (live line or docs citation) | pass (live) | Neither the debug log nor the `--include-hook-events` stream carries hook input. A probe session with a `--settings` PreToolUse hook (`cat >> payloads.jsonl`) recorded: `{"tool":"Glob","agent_type":"aew:spec-analyser","agent_id":"af0b9886062461f6d","hook_event_name":"PreToolUse"}`; the main thread's own `Agent` call had `agent_type` null. The agent `gh` deny can therefore key on `aew:<agent>` live. |

## 6. Results

Every row starts as `pending`. Cost goes in the notes (and the ledger in section 1).

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
| 902 `STATUS: ok` | pending | |
| 902 at least one change, all `type: non-material`, `source: auto` | pending | |
| 902 changes applied in `spec-final.md` (spot-checked) | pending | |
| 902 Classification table has no `material` row | pending | |
| 902 artefacts follow templates, valid return blocks | pending | |
| 902 Preload, permission denials, final.txt return block, E-2 | pending | |
| **E3 run b 903, spec-analyser material** | | |
| 903 `STATUS: needs_input` | pending | |
| 903 Classification has a `material` row | pending | |
| 903 `### Q<n>` with non-empty `**Recommended answer:**` and `**Alternatives:**`, about guest vs logged-in access | pending | |
| 903 `spec-changes.json` holds no material change (A15) | pending | |
| 903 artefacts follow templates, valid return blocks | pending | |
| 903 Preload, permission denials, final.txt return block, E-2 | pending | |
| **E3 run c 911, brief-compiler pipeline, UI** | | |
| 911 `02-brief.md` follows template | pending | |
| 911 ACs `AC-1..AC-n` contiguous, atomic, observable (per-AC judgement in notes) | pending | |
| 911 exactly one `UI changes:` line in `02-brief.md`, value `yes` | pending | |
| 911 artefact and final.txt end in valid return block, `STATUS: ok` | pending | |
| 911 Preload, permission denials, E-2 | pending | |
| **E3 run d 912, brief-compiler prompt mode, non-UI** | | |
| 912 `prompt.md` exists, no `02-brief.md` written | pending | |
| 912 `prompt.md` `## ` headings match `templates/artefacts/prompt.md` | pending | |
| 912 no aew words in `prompt.md` (`grep -cE 'aew\|\.aew/\|/aew:\|run-protocol\|CLAUDE_PLUGIN_ROOT'` is 0) | pending | |
| 912 no HTML comments in `prompt.md` (`grep -c '<!--'` is 0) | pending | |
| 912 exactly one `UI changes:` line in `prompt.md`, value `no` | pending | |
| 912 every source requirement maps to a contiguous `AC-n` (mapping in notes) | pending | |
| 912 `prompt.md` has no return block; final.txt passes `valid_return_block` | pending | |
| 912 Preload, permission denials, E-2 | pending | |
| **E3 run e 921, standards-setter run 1** | | |
| 921 agent fingerprint calls are `... detect-stack.sh" fingerprint <profile> .` and equal the recorded values | pending | |
| 921 allow-rule match: `detect-stack.sh` calls in quoted form, root equals `$REPO`, none denied (one command verbatim in notes) | pending | |
| 921 seed path resolution recorded (section 5), no unexpanded `${` | pending | |
| 921 `docs/standards/nextjs.md`, `tailwind.md`, `README.md` exist | pending | |
| 921 first line of each profile doc matches the `aew:standards fingerprint=... generated=...` header | pending | |
| 921 `README.md` follows the index format and lists both docs and fingerprints | pending | |
| 921 each doc 400 lines or fewer; `tailwind.md` opens with "Overlay on: nextjs" | pending | |
| 921 `03-standards.md` follows template, ends in valid return block, both rows `generated`, section rows name existing sections | pending | |
| 921 `STATUS: ok` | pending | |
| 921 AC-18: no skip warning for `aew:stack-standards`; context7 tool names called recorded verbatim | pending | |
| 921 Preload, permission denials, final.txt return block, E-2 | pending | |
| 921 post-pass: `git -C $P add -A && git -C $P commit -qm standards` done | pending | |
| **E4 run 922, standards-setter reuse** | | |
| 922 fingerprint calls from the project root equal the setup values (setup values equal run 921's: the setup `diff` prints nothing) | pending | |
| 922 `STATUS: ok`, SUMMARY contains "reused" | pending | |
| 922 `03-standards.md` Status `reused` on both rows | pending | |
| 922 checksums after the run byte-identical to before | pending | |
| 922 `git -C $P status --porcelain docs/standards` empty | pending | |
| 922 artefact follows template, both return blocks valid | pending | |
| 922 Preload, permission denials, E-2 | pending | |
| **E5 run 931, senior-engineer plan** | | |
| 931 `05-plan.md` follows template, both return blocks valid; STATUS `ok` or `needs_input` with a listed material challenge (record which) | pending | |
| 931 "Alternatives considered" has at least one alternative with a rejection reason | pending | |
| 931 AC to WP matrix covers every AC; every WP id in the matrix has a `### WP-<n>` block | pending | |
| 931 at least one WP `parallelisable: yes`; every WP's value correct under PD-7; no file in two WPs unless the later depends on the earlier (per-WP reasoning in notes) | pending | |
| 931 every WP has standards references that exist in `docs/standards/`, and unit tests listed | pending | |
| 931 Preload: none skipped for `aew:run-protocol`, `aew:stack-standards`, `superpowers:systematic-debugging` | pending | |
| 931 permission denials empty, E-2 | pending | |

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
