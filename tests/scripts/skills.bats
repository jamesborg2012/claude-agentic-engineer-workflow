#!/usr/bin/env bats
# Static contract checks over the five entry skills (init, ship, resume, status,
# prompt) and the agents' frontmatter: paths, names, frontmatter, stage coverage,
# bad-argument messages and the citations between skill files. It reads files in
# the repo only (no gh, no git, no fixtures). Each test collects every offender
# and fails once, naming them.

load helpers/common

ENTRY="init ship resume status prompt"

setup() {
  common_setup
}

# report_offenders <what> <offenders>: list them on stderr; return 1 if any.
report_offenders() {
  if [ -n "$2" ]; then
    printf 'violations (%s):\n%s\n' "$1" "$2" >&2
    return 1
  fi
  return 0
}

# entry_files: every file under the five entry skills, absolute paths.
entry_files() {
  local s
  for s in $ENTRY; do find "$REPO_ROOT/skills/$s" -type f; done
}

# frontmatter <file>: the lines between the first two --- lines.
frontmatter() {
  awk 'NR==1{if($0!="---")exit; next} $0=="---"{exit} {print}' "$1"
}

# count <fixed-string> <file>: number of matching lines (prints 0, never fails).
count() { grep -cF -- "$1" "$2" || true; }

# load_stages: STAGES from the schema; asserts there are ten.
load_stages() {
  STAGES=$(jq -r '.["$defs"].stage.enum[]' "$REPO_ROOT/templates/state.schema.json")
  [ "$(printf '%s\n' "$STAGES" | wc -l | tr -d ' ')" -eq 10 ]
}

# present <file> <strings, one per line>: list every string missing from the file.
present() {
  local f=$1 line bad=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$(count "$line" "$f")" -ge 1 ] || bad="$bad${f#"$REPO_ROOT"/}: missing: $line"$'\n'
  done <<<"$2"
  printf '%s' "$bad"
}

# absent_fixed / absent_regex <file> <patterns, one per line>: list every pattern that matches.
absent_fixed() {
  local f=$1 line bad=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$(count "$line" "$f")" -eq 0 ] || bad="$bad${f#"$REPO_ROOT"/}: must not contain: $line"$'\n'
  done <<<"$2"
  printf '%s' "$bad"
}
absent_regex() {
  local f=$1 line bad="" n
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$(grep -cE -- "$line" "$f" || true)
    [ "$n" -eq 0 ] || bad="$bad${f#"$REPO_ROOT"/}: must not match: $line"$'\n'
  done <<<"$2"
  printf '%s' "$bad"
}

# headings_equal <file> <expected headings, one per line>: # and ## lines outside
# column-0 code fences must equal the list, in order.
headings_equal() {
  local got
  got=$(awk '/^```/{f=!f;next} !f && /^(# |## )/' "$1")
  if [ "$got" != "$2" ]; then
    printf 'headings differ in %s\n--- got\n%s\n--- want\n%s\n' "${1#"$REPO_ROOT"/}" "$got" "$2"
    return 1
  fi
}

@test "entry skills: name and description frontmatter, no allowed-tools" {
  local s f fm bad=""
  for s in $ENTRY; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    [ -f "$f" ] || { bad="$bad$s: SKILL.md missing"$'\n'; continue; }
    fm=$(frontmatter "$f")
    [ "$(printf '%s\n' "$fm" | grep -cx "name: $s" || true)" -eq 1 ] || bad="$bad$s: no 'name: $s' line"$'\n'
    [ "$(printf '%s\n' "$fm" | grep -c '^description: .\+' || true)" -eq 1 ] || bad="$bad$s: no description"$'\n'
    [ "$(printf '%s\n' "$fm" | grep -c '^allowed-tools:' || true)" -eq 0 ] || bad="$bad$s: has allowed-tools"$'\n'
  done
  report_offenders "entry skill frontmatter" "$bad"
}

@test "entry skills: disable-model-invocation on init, ship, resume and prompt, not status" {
  local s fm bad=""
  for s in init ship resume prompt; do
    fm=$(frontmatter "$REPO_ROOT/skills/$s/SKILL.md")
    [ "$(printf '%s\n' "$fm" | grep -cxF 'disable-model-invocation: true' || true)" -eq 1 ] || bad="$bad$s: needs disable-model-invocation: true"$'\n'
  done
  fm=$(frontmatter "$REPO_ROOT/skills/status/SKILL.md")
  [ "$(printf '%s\n' "$fm" | grep -c '^disable-model-invocation:' || true)" -eq 0 ] || bad="${bad}status: must not set disable-model-invocation"$'\n'
  report_offenders "disable-model-invocation" "$bad"
}

@test "entry skills: no injection or positional placeholders; one ARGUMENTS placeholder and the argument hints" {
  local s f fm n bad="" want
  for s in $ENTRY; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    grep -nF '!`' "$f" | sed "s|^|$s: injection: |" > "$BATS_TEST_TMPDIR/o" || true
    grep -nE '\$[0-9]|\$ARGUMENTS\[' "$f" | sed "s|^|$s: positional: |" >> "$BATS_TEST_TMPDIR/o" || true
    bad="$bad$(cat "$BATS_TEST_TMPDIR/o")"
  done
  for s in ship resume status prompt; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    case $s in
      ship) want='argument-hint: "<issue> [--auto] [--from <stage>]"' ;;
      resume | status) want='argument-hint: "[<run-id>]"' ;;
      prompt) want='argument-hint: "<issue>"' ;;
    esac
    fm=$(frontmatter "$f")
    [ "$(printf '%s\n' "$fm" | grep -cxF -- "$want" || true)" -eq 1 ] || bad="$bad"$'\n'"$s: argument-hint is not $want"
    n=$(grep -o '\$ARGUMENTS' "$f" | wc -l | tr -d ' ')
    [ "$n" = 1 ] || bad="$bad"$'\n'"$s: $n \$ARGUMENTS placeholders (want 1)"
  done
  report_offenders "placeholders and hints" "$bad"
}

@test "entry skills: every plugin path and script name exists, with no placeholder" {
  local f t p bad="" tokens=0
  while IFS= read -r f; do
    grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*[<{]' "$f" | sed "s|^|${f#"$REPO_ROOT"/}: placeholder or brace list: |" > "$BATS_TEST_TMPDIR/o" || true
    bad="$bad$(cat "$BATS_TEST_TMPDIR/o")"$'\n'
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      tokens=$((tokens + 1))
      p=$(printf '%s' "$t" | sed 's/[.]*$//; s|^\${CLAUDE_PLUGIN_ROOT}/||')
      [ -e "$REPO_ROOT/$p" ] || bad="$bad${f#"$REPO_ROOT"/}: no such path: $p"$'\n'
    done < <(grep -ohE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*' "$f" || true)
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      [ -e "$REPO_ROOT/scripts/$t" ] || [ -e "$REPO_ROOT/scripts/hooks/$t" ] || bad="$bad${f#"$REPO_ROOT"/}: no such script: $t"$'\n'
    done < <(grep -ohE '[A-Za-z0-9_./-]*\.sh' "$f" | grep -E '^[a-z][a-z0-9-]*\.sh$' || true)
  done < <(entry_files)
  [ "$tokens" -ge 1 ] || bad="${bad}no \${CLAUDE_PLUGIN_ROOT} path found at all"$'\n'
  report_offenders "paths and script names" "$(printf '%s' "$bad" | grep -v '^$' || true)"
}

@test "entry skills: every aew:<name> is an agent or a skill (ship-milestone allowed)" {
  local f n bad=""
  while IFS= read -r f; do
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      n=${n#aew:}
      [ -f "$REPO_ROOT/agents/$n.md" ] || [ -f "$REPO_ROOT/skills/$n/SKILL.md" ] || [ "$n" = ship-milestone ] ||
        bad="$bad${f#"$REPO_ROOT"/}: aew:$n is neither an agent nor a skill"$'\n'
    done < <(grep -ohE 'aew:[a-z][a-z0-9-]*' "$f" | sort -u || true)
  done < <(entry_files)
  report_offenders "aew:<name> references" "$bad"
}

@test "ship: a section for every schema stage and the reads table" {
  load_stages
  local f="$REPO_ROOT/skills/ship/SKILL.md" s bad=""
  for s in $STAGES; do
    [ "$(grep -cxF "## Stage: $s" "$f" || true)" -eq 1 ] || bad="$bad## Stage: $s (want exactly one)"$'\n'
  done
  [ "$(grep -cxF '## What the orchestrator reads' "$f" || true)" -eq 1 ] || bad="$bad## What the orchestrator reads"$'\n'
  report_offenders "ship sections" "$bad"
}

@test "ship: routing Stage table has a complete row for every schema stage" {
  load_stages
  local f="$REPO_ROOT/skills/ship/references/routing.md" s r bad=""
  [ "$(grep -cxF '| Stage | Entry | Exit | Failure |' "$f" || true)" -eq 1 ] || bad="${bad}header row"$'\n'
  for s in $STAGES; do
    r=$(awk -F'|' -v s="\`$s\`" '/^## /{t=($0=="## Stage table")} t && $2 ~ "^[[:space:]]*" s "[[:space:]]*$" { n++; e=$3; x=$4; fl=$5; gsub(/[[:space:]]/,"",e); gsub(/[[:space:]]/,"",x); gsub(/[[:space:]]/,"",fl); if (NF==6 && e!="" && x!="" && fl!="") ok++ } END { printf "rows=%d ok=%d\n", n, ok }' "$f")
    [ "$r" = "rows=1 ok=1" ] || bad="$bad$s: $r"$'\n'
  done
  report_offenders "routing rows" "$bad"
}

@test "ship: every bad-argument case has its message" {
  load_stages
  local f="$REPO_ROOT/skills/ship/SKILL.md" list
  list=$(jq -r '.["$defs"].stage.enum | join(", ")' "$REPO_ROOT/templates/state.schema.json")
  # Cases in order: no issue; non-integer, zero or negative; m-<n>; unknown option;
  # repeated option; extra positional; --from without a value; unknown stage; usage.
  report_offenders "ship bad-argument messages" "$(present "$f" "aew ship: missing issue number.
must be a positive integer
/aew:ship-milestone (coming in a later release)
unknown option
given more than once
unexpected argument
aew ship: --from needs a stage.
unknown stage
Stages: $list.
Usage: /aew:ship <issue> [--auto] [--from <stage>]")"
}

@test "resume: re-asks a pending gate through ship's gates.md" {
  local f="$REPO_ROOT/skills/resume/SKILL.md" bad
  bad=$(headings_equal "$f" '# aew resume
## Plugin root
## Rules
## Step 1. Pick the run
## Step 2. Read the state
## Step 3. Finished runs
## Step 4. Checks
## Step 5. Continue') || true
  bad="$bad$(present "$f" '`gates.md` `## Re-asking a pending gate`
awaiting_input
awaiting_plan_approval
${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md
${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md
with the Skill tool
Steps 1–4
## Stage: <stage>
the note `resume`
`preflight.md` `## Check 2. Clean working tree`
restart form
git status --porcelain --untracked-files=all
state.sh current set <id>
/aew:ship <n> --from <stage>
aew resume: no current run. Name one: /aew:resume <run-id> (/aew:status lists the runs).
aew resume: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).
aew resume: unexpected argument "<token>".
aew resume: no run <id> (.aew/runs/<id>/state.json is missing).
aew resume: run <id> is a <mode> run; milestone runs are resumed by /aew:ship-milestone (coming in a later release).
Usage: /aew:resume [<run-id>]')"
  [ "$(grep -cxF '## Re-asking a pending gate' "$REPO_ROOT/skills/ship/references/gates.md" || true)" -eq 1 ] || bad="${bad}gates.md lacks '## Re-asking a pending gate'"$'\n'
  bad="$bad$(present "$REPO_ROOT/skills/ship/SKILL.md" 'Answer with /aew:resume <id>')"
  report_offenders "resume contract" "$bad"
}

@test "status: reads only, names no script and runs no git or gh" {
  local f="$REPO_ROOT/skills/status/SKILL.md" bad s
  bad=$(headings_equal "$f" '# aew status
## Rules
## Step 1. Parse the argument
## List every run
## Show one run
## Next action') || true
  bad="$bad$(present "$f" '^([1-9][0-9]*|m-[1-9][0-9]*)$
.aew/runs/*/state.json
tail -n 10
max_review_cycles // 2
max_fix_cycles // 3
[.history[] | select((.note // "") | startswith("gate:"))] | last | .note
if ([.history[] | select(.note == "prompt")] | length) > 0 and .branch == null then "prompt" else "ship" end
No aew runs in this project.
aew status: no run <id>.
aew status: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).
aew status: unexpected argument "<token>".
Usage: /aew:status [<run-id>]')"
  for s in running awaiting_input awaiting_plan_approval blocked done failed; do
    [ "$(grep -c "^| \`$s\` |" "$f" || true)" -eq 1 ] || bad="$bad| \`$s\` | row (want exactly one)"$'\n'
  done
  bad="$bad$(absent_fixed "$f" 'state.sh
gh-issue.sh
gh-labels.sh
gh-pr.sh
gh-retro.sh
git-branch.sh')"
  bad="$bad$(absent_regex "$f" '^disable-model-invocation
(^|[^A-Za-z0-9_-])gh (auth|issue|pr|label|api|repo)
(^|[^A-Za-z0-9_-])git (add|commit|switch|checkout|push|merge|rebase|reset|stash|fetch|pull|branch|status)')"
  if grep -rF '${CLAUDE_PLUGIN_ROOT}/scripts/' "$REPO_ROOT/skills/status" > /dev/null; then
    bad="${bad}skills/status names \${CLAUDE_PLUGIN_ROOT}/scripts/"$'\n'
  fi
  report_offenders "status contract" "$bad"
}

@test "prompt: ship's run start and spec gate by citation, then the brief in prompt mode" {
  local f="$REPO_ROOT/skills/prompt/SKILL.md" bad
  bad=$(headings_equal "$f" '# aew prompt
## Plugin root
## Rules
## Step 1. Parse the argument
## Step 2. Preflight
## Step 3. Start the run
## Step 4. Analyse the spec
## Step 5. Compile the prompt
## Step 6. Finish
## Stopping') || true
  bad="$bad$(present "$f" '`preflight.md` `## Check 1. Config exists`
`preflight.md` `## Check 3. gh is authenticated`
`preflight.md` `## Check 5. No other active run`
`SKILL.md` `## Step 3. Start the run`
3.1
3.5
3.6
`gates.md` `## Gate: spec`
`gates.md` `## Recording a spec revision`
`gates.md` `## Gate ids and pending state`
`SKILL.md` `## Gate pending`
D1
D2
D4
mode: prompt
state.sh stage spec_analysis --note "prompt"
gh-issue.sh comment <n> .aew/runs/<n>/prompt.md
AskUserQuestion
Not posted.
/aew:ship <n> --from spec_analysis
aew prompt: missing issue number.
aew prompt: the issue must be a positive integer, got "<token>".
aew prompt: unexpected argument "<token>".
Usage: /aew:prompt <issue>')"
  bad="$bad$(absent_fixed "$f" '`preflight.md` `## Check 2
gh-labels.sh
git-branch.sh')"
  bad="$bad$(absent_regex "$f" '(^|[^A-Za-z0-9_-])git (add|commit|switch|push)')"
  report_offenders "prompt contract" "$bad"
}

@test "init: numbered sections 1 to 13 in order" {
  local got
  got=$(grep -E '^## [0-9]+\. ' "$REPO_ROOT/skills/init/SKILL.md" | sed -E 's/^## ([0-9]+)\..*/\1/' | tr '\n' ' ')
  [ "$got" = "1 2 3 4 5 6 7 8 9 10 11 12 13 " ] || { printf 'init sections: %s\n' "$got" >&2; return 1; }
}

@test "ship, resume and prompt: every file-and-heading citation resolves" {
  local f c cf h p n bad="" total=0 ship_n=0
  while IFS= read -r f; do
    n=0
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      n=$((n + 1))
      cf=${c%%'` `'*}
      cf=${cf#'`'}
      h=${c#*'` `'}
      h=${h%'`'}
      case $cf in
        SKILL.md) p=skills/ship/SKILL.md ;;
        prompt/SKILL.md) p=skills/prompt/SKILL.md ;;
        *) p=skills/ship/references/$cf ;;
      esac
      [ "$(grep -cxF -- "$h" "$REPO_ROOT/$p" 2> /dev/null || true)" -eq 1 ] || bad="$bad${f#"$REPO_ROOT"/}: unresolved: $c"$'\n'
    done < <(grep -oE '`(prompt/SKILL|SKILL|preflight|dispatch|gates|routing|pr|final-report)\.md` `## [^`]+`' "$f" | sort -u || true)
    total=$((total + n))
    [ "$f" != "$REPO_ROOT/skills/ship/SKILL.md" ] || ship_n=$n
  done < <(find "$REPO_ROOT/skills/ship" "$REPO_ROOT/skills/resume" "$REPO_ROOT/skills/prompt" -type f -name '*.md')
  [ "$ship_n" -ge 1 ] || bad="${bad}no citation found in skills/ship/SKILL.md"$'\n'
  [ "$total" -ge 1 ] || bad="${bad}no citation found anywhere"$'\n'
  report_offenders "citations" "$bad"
}

@test "frontmatter: description is valid YAML (no unquoted ': ') in every entry skill and agent" {
  local f v bad="" n=0
  for f in "$REPO_ROOT"/skills/{init,ship,resume,status,prompt}/SKILL.md "$REPO_ROOT"/agents/*.md; do
    n=$((n + 1))
    v=$(frontmatter "$f" | sed -n 's/^description: *//p')
    [ -n "$v" ] || { bad="$bad${f#"$REPO_ROOT"/}: no description"$'\n'; continue; }
    case $v in
      '"'* | "'"*) ;;
      *)
        case $v in
          *': '* | *':') bad="$bad${f#"$REPO_ROOT"/}: unquoted ': ' in description"$'\n' ;;
        esac
        case $v in
          *' #'*) bad="$bad${f#"$REPO_ROOT"/}: ' #' starts a YAML comment in description"$'\n' ;;
        esac
        ;;
    esac
  done
  [ "$n" -ge 12 ] || bad="${bad}only $n files checked"$'\n'
  report_offenders "frontmatter YAML" "$bad"
}

@test "ship: no mktemp anywhere under skills/ship" {
  local n
  n=$(grep -rc mktemp "$REPO_ROOT/skills/ship" | awk -F: '{s+=$NF} END{print s+0}')
  [ "$n" -eq 0 ] || { grep -rn mktemp "$REPO_ROOT/skills/ship" >&2; return 1; }
}

@test "prompt marker is never tested alone: only the combined check with .branch == null" {
  local f bad="" n=0
  while IFS= read -r f; do
    while IFS= read -r line; do
      n=$((n + 1))
      case $line in
        *'.branch == null'*) ;;
        *) bad="$bad${f#"$REPO_ROOT"/}: marker tested alone: $line"$'\n' ;;
      esac
    done < <(grep -F 'select(.note == "prompt")' "$f" || true)
  done < <(find "$REPO_ROOT/skills" -type f -name '*.md')
  [ "$n" -ge 1 ] || bad="${bad}no use of the prompt marker check found"$'\n'
  report_offenders "prompt marker" "$bad"
}
