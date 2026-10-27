#!/usr/bin/env bats
# Static contract checks over the six entry skills (init, ship, ship-milestone,
# resume, status, prompt) and the agents' frontmatter: paths, names, frontmatter, stage coverage,
# bad-argument messages and the citations between skill files. It reads files in
# the repo only (no gh, no git, no fixtures). Each test collects every offender
# and fails once, naming them.

load helpers/common

ENTRY="init ship ship-milestone resume status prompt"

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

# preapprovable_offenders <root> <file>…: one line per Rewrite-guide finding (H1-H8, M1), pipe in a condition
# (C1) or silent check (S1) in the Bash commands
# the files tell Claude to run: fenced sh/bash blocks (quoted-heredoc bodies skipped) and inline code spans whose
# first word is a command word or a plugin script. Single-quoted text is ignored, ${CLAUDE_PLUGIN_ROOT} and
# $ARGUMENTS are substituted before Claude sees the text, and prose spans such as `$ARGUMENTS` are not commands.
preapprovable_offenders() {
  local root=$1
  shift
  awk -v q="'" -v root="$root/" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function stripsq(s) { gsub(q "[^" q "]*" q, q q, s); return s }
    # segs(s, a): split s on && || ; | and newlines outside single quotes; drop leading shell keywords.
    function segs(s, a,   n, cur, inq, i, c, k) {
      n = 0; cur = ""; inq = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == q) inq = !inq
        else if (!inq && (substr(s, i, 2) == "&&" || substr(s, i, 2) == "||")) { a[++n] = cur; cur = ""; i++; continue }
        else if (!inq && (c == ";" || c == "|" || c == "\n")) { a[++n] = cur; cur = ""; continue }
        cur = cur c
      }
      a[++n] = cur
      for (k = 1; k <= n; k++) {
        a[k] = trim(a[k])
        while (match(a[k], /^(then|else|elif|if|do|while|until|!)([ \t]+|$)/)) a[k] = substr(a[k], RLENGTH + 1)
      }
      return n
    }
    function flag(rule) {
      if ((ncmd, rule) in seen) return
      seen[ncmd, rule] = 1
      x = cmd; gsub(/[ \t]*\n[ \t]*/, " ", x)
      out = out where ": " rule " [" kind "] " substr(x, 1, 100) "\n"
    }
    function check(   s, raw, n, i, j, a, t, nt, toks, rest, p) {
      ncmd++
      raw = cmd
      gsub(/\$\{CLAUDE_PLUGIN_ROOT\}/, "ROOT", raw)
      gsub(/\$ARGUMENTS/, "ARGS", raw)
      s = stripsq(raw)
      if (s ~ /(^|[^\\])\$[A-Za-z_{0-9?#@*!$-]/) flag("H1 variable expansion")
      if (s ~ /\$\(/ || s ~ /(^|[^\\])`/) flag("H2 command substitution")
      if (raw ~ /<<-?[[:space:]]*[A-Za-z_]/) flag("H6 unquoted heredoc delimiter")
      if (s ~ /\{[^{}[:space:]]*,[^{}[:space:]]*\}/) flag("H7 brace expansion")
      n = segs(raw, a)
      for (i = 1; i <= n; i++) {
        if (a[i] ~ /^jq([[:space:]]|$)/) {
          if (a[i] ~ ("(^|[[:space:]])jq([[:space:]]+[^" q "[:space:]]+)*[[:space:]]+--(arg|argjson|args|jsonargs|indent|tab)([[:space:]]|$)")) flag("H3 jq --arg before the filter")
          if (a[i] ~ ("--arg(json)?[[:space:]]+[^[:space:]]+[[:space:]]+(" q "[^" q "]*[$`]|[=~/]|[^[:space:]]*[.][.])")) flag("H4 jq --arg value is path-checked")
          nt = split(a[i], toks, /[[:space:]]+/)
          for (j = 1; j <= nt; j++)
            if (toks[j] ~ /^(-[A-Za-z]*[fL]|--(from-file|rawfile|slurpfile|library-path)($|=))/) flag("H5 jq file or exec flag")
          if (a[i] ~ /system[[:space:]]*\(/ || a[i] ~ /(^|[^A-Za-z0-9_])(include|import)($|[^A-Za-z0-9_])/) flag("H5 jq file or exec flag")
        }
        if (a[i] ~ /^awk([[:space:]]|$)/) {
          rest = a[i]
          while (match(rest, q "[^" q "]*" q)) {
            p = substr(rest, RSTART + 1, RLENGTH - 2); rest = substr(rest, RSTART + RLENGTH)
            if (p ~ /system[[:space:]]*\(/ || p ~ /(^|[^|])\|&?[^\/|%";#{}]*"/ || p ~ /(^|[^|])\|&?[[:space:]\\]*getline/ ||
                p ~ /@[[:space:]]*(load|include)/ || p ~ /extension[[:space:]]*\(/ || p ~ /\/inet[46]?\//) flag("H8 awk runs a command")
          }
        }
      }
      n = segs(s, a)
      for (i = 1; i <= n; i++)
        if (a[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+[^[:space:]]/) flag("M1 VAR=value prefix")
      # C1: the checker splits a compound at a pipe in its condition and asks for the broken parts (I1.1).
      t = s; gsub(/"[^"]*"/, "\"\"", t); gsub(/\\\|/, "|", t); gsub(/\|\|/, " OR ", t)
      while (match(t, /(^|[^A-Za-z0-9_])(if|elif|while|until)[[:space:]]/)) {
        t = substr(t, RSTART + RLENGTH); p = t
        if (match(p, /(^|[^A-Za-z0-9_])(then|do)([^A-Za-z0-9_]|$)/)) p = substr(p, 1, RSTART)
        if (p ~ /\|/) flag("C1 pipe inside an if or while condition")
      }
      # S1: a false test, grep -q or git --quiet check returns no output and no error to Claude (G2.2), so
      # each check line prints its outcome, unless it follows a printed message (a deliberate stop).
      nt = split(cmd, toks, "\n"); p = ""
      for (j = 1; j <= nt; j++) {
        t = trim(stripsq(toks[j])); sub(/^!?[[:space:]]*/, "", t)
        if (t == "" || t ~ /^#/) continue
        if ((t ~ /^(test|\[)[[:space:]]/ || (t !~ /&&|\|\|/ && t ~ /^(grep[[:space:]]+-[A-Za-z]*q|git[[:space:]]+(merge-base[[:space:]]+--is-ancestor|diff[[:space:]]+(.*[[:space:]])?--quiet))/)) &&
            t !~ /(&&|\|\|)[[:space:]]*(echo|printf)([[:space:]]|$)/ && p !~ /^(echo|printf)[[:space:]]/) flag("S1 silent check: print its outcome")
        p = t
      }
    }
    FNR == 1 { fence = 0; sh = 0; hd = ""; rel = FILENAME; sub("^" root, "", rel) }
    /^[ \t]*```/ {
      if (!fence) {
        fence = 1; t = $0; sub(/^[ \t]*```/, "", t)
        sh = (trim(t) == "sh" || trim(t) == "bash"); cmd = ""; start = FNR + 1; hd = ""
      } else {
        if (sh) { nblock++; gsub(/\\\n/, " ", cmd); where = rel ":" start; kind = "block"; check() }
        fence = 0; sh = 0
      }
      next
    }
    fence && sh {
      if (hd != "") { if (trim($0) == hd) hd = ""; next }
      if (match($0, "<<-?[[:space:]]*[" q "\"]?[A-Za-z_][A-Za-z0-9_]*")) {
        hd = substr($0, RSTART, RLENGTH); gsub("[-<" q "\"[:space:]]", "", hd)
      }
      cmd = (cmd == "" ? $0 : cmd "\n" $0)
      next
    }
    fence { next }
    {
      line = $0
      while (match(line, /`[^`]+`/)) {
        cmd = substr(line, RSTART + 1, RLENGTH - 2); line = substr(line, RSTART + RLENGTH)
        t = cmd; while (match(t, /^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+/)) t = substr(t, RLENGTH + 1)
        sub(/^"/, "", t); w = t; sub(/[[:space:]].*/, "", w)
        if (w ~ /^(jq|awk|grep|test|\[|cat|ls|head|tail|git|printf|echo|for|if|while|mkdir|rm|touch|node|command|npx|gh|claude)$/ ||
            w ~ /^[a-z][a-z0-9-]*\.sh"?$/ || t ~ /^\$\{CLAUDE_PLUGIN_ROOT\}\/scripts\//) {
          nspan++; where = rel ":" FNR; kind = "span"; check()
        }
      }
    }
    END {
      if (nblock == 0) printf "no fenced sh block found\n"
      if (nspan == 0) printf "no inline command span found\n"
      printf "%s", out
    }
  ' "$@"
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

@test "entry skills: disable-model-invocation on init, ship, ship-milestone, resume and prompt, not status" {
  local s fm bad=""
  for s in init ship ship-milestone resume prompt; do
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
  for s in ship ship-milestone resume status prompt; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    case $s in
      ship) want='argument-hint: "<issue> [--auto] [--from <stage>]"' ;;
      ship-milestone) want='argument-hint: "<milestone> [--bulk|--sequential] [--auto]"' ;;
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

@test "entry skills: every aew:<name> is an agent or a skill" {
  local f n bad=""
  while IFS= read -r f; do
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      n=${n#aew:}
      [ -f "$REPO_ROOT/agents/$n.md" ] || [ -f "$REPO_ROOT/skills/$n/SKILL.md" ] ||
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
use /aew:ship-milestone <n>.
unknown option
given more than once
unexpected argument
aew ship: --from needs a stage.
unknown stage
Stages: $list.
Usage: /aew:ship <issue> [--auto] [--from <stage>]")"
}

@test "ship-milestone: headings, argument errors, mode question and report lines" {
  local f="$REPO_ROOT/skills/ship-milestone/SKILL.md" m="$REPO_ROOT/skills/ship-milestone/references/mode-selection.md" bad
  bad=$(headings_equal "$f" '# aew ship-milestone
## Plugin root
## Rules
## Run variables
## References
## Step 1. Parse the arguments
## Step 2. Preflight
## Step 3. Select the issues
## Step 4. Choose the mode
## Step 5. Start the run
## Milestone report
## Final report') || true
  bad="$bad$(headings_equal "$m" "# Mode selection
## The script's recommendation
## Judgement
## Rationale
## Ask
## No answer
## Mode given
## Cycles and stack conflicts")" || true
  bad="$bad$(present "$f" 'aew ship-milestone: missing milestone.
aew ship-milestone: --bulk and --sequential cannot both be given.
aew ship-milestone: option "<token>" given more than once.
aew ship-milestone: unknown option "<token>".
Usage: /aew:ship-milestone <milestone> [--bulk|--sequential] [--auto]
aew ship-milestone: milestone "<m>" has no open issues.
Run m-<mn> already exists: continue it with /aew:resume m-<mn>.
aew ship-milestone: could not list milestone "<m>": <first stderr line>
## aew milestone m-<mn> <title>: <done | stopped>
- #<k>: shipped, PR <url>
- #<k>: blocked at <stage>: <reason>
- #<k>: failed at <stage>: <reason>
- #<k>: not started
Manual tests outstanding: none
aew ship-milestone m-<mn> <title>: <done | stopped>
Mode: <bulk | sequential>
Not started: <#a, #b | none>
Retro items filed: <count>')"
  bad="$bad$(present "$m" 'recommended mode
Order: 
Stacked: 
Closed and left out: 
(recommended)
Rerun with /aew:ship-milestone
aew ship-milestone m-<mn>: stopped at the mode question; nothing was written.
Mode: <mode> (given)
; --bulk was given, so the run goes ahead in bulk.
dependency cycle between
which are not one chain
Warning: dependency cycle between #a, #b is ignored: bulk runs every issue on one branch.
stack conflict is ignored: bulk runs every issue on one branch.')"
  report_offenders "ship-milestone contract" "$(printf '%s' "$bad" | grep -v '^$' || true)"
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
${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md
${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md
`sequential.md` `## Resume`
sequential-child
startswith("milestone m-")
Run <id> is part of milestone run <parent>: continuing the milestone.
issues/<k>/
remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk
Usage: /aew:resume [<run-id>]')"
  [ "$(grep -cxF '## Re-asking a pending gate' "$REPO_ROOT/skills/ship/references/gates.md" || true)" -eq 1 ] || bad="${bad}gates.md lacks '## Re-asking a pending gate'"$'\n'
  bad="$bad$(present "$REPO_ROOT/skills/ship/SKILL.md" 'Answer with /aew:resume <id>')"
  bad="$bad$(absent_fixed "$f" 'coming in a later release')"
  [ "$(grep -cxF '## Resume' "$REPO_ROOT/skills/ship-milestone/references/sequential.md" || true)" -eq 1 ] || bad="${bad}sequential.md lacks '## Resume'"$'\n'
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
Usage: /aew:status [<run-id>]
.aew/runs/<id>/index.json
| Child | Index | Status | Stage | PR |
startswith("milestone m-")
Part of milestone run m-<n>.
/aew:resume m-<n>')"
  for s in running awaiting_input awaiting_plan_approval blocked done failed; do
    [ "$(grep -c "^| \`$s\` |" "$f" || true)" -eq 1 ] || bad="$bad| \`$s\` | row (want exactly one)"$'\n'
  done
  bad="$bad$(absent_fixed "$f" 'state.sh
gh-issue.sh
gh-labels.sh
gh-pr.sh
gh-retro.sh
git-branch.sh
gh-milestone.sh
coming in a later release')"
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

@test "ship: the plan-approval question itself carries the summary and the plan path" {
  local g
  g=$(awk '/^## Gate: plan-approval$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/skills/ship/references/gates.md")
  grep -q 'question text' <<< "$g" || { echo "plan-approval: the summary is not part of the question text" >&2; return 1; }
  grep -q '05-plan.md' <<< "$g" || { echo "plan-approval: no plan path" >&2; return 1; }
}

@test "init: template 1 pre-approves reading the plugin's own files" {
  local t1
  t1=$(awk '/^Template 1 is/{f=1} /^Template 2 is/{f=0} f' "$REPO_ROOT/skills/init/SKILL.md")
  grep -qF '"Read(/${CLAUDE_PLUGIN_ROOT}/**)"' <<< "$t1" || { echo "template 1 lacks Read(/\${CLAUDE_PLUGIN_ROOT}/**)" >&2; return 1; }
}

@test "doc-writer: the introduction names new dependencies and plan decisions taken under --auto" {
  local pe
  pe=$(awk '/^## In plain English$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/agents/doc-writer.md")
  grep -q 'new dependenc' <<< "$pe" || { echo "doc-writer intro rules do not mention new dependencies" >&2; return 1; }
  grep -q -- '--auto' <<< "$pe" || { echo "doc-writer intro rules do not mention decisions under --auto" >&2; return 1; }
}

@test "doc-writer: the introduction says what the issue left open and what James decided at a gate" {
  local pe
  pe=$(awk '/^## In plain English$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/agents/doc-writer.md")
  grep -q 'left open' <<< "$pe" || { echo "doc-writer intro rules do not ask for what the issue left open" >&2; return 1; }
}

@test "developer: the feature-branch checks include commands.build" {
  local f="$REPO_ROOT/agents/developer.md"
  grep -qE '^9\. .*`commands\.build`' "$f" || { echo "developer step 9 (final checks) does not run commands.build" >&2; return 1; }
  grep -qE '^4\. Run the full unit suite.*build' "$f" || { echo "developer fix mode does not run the build" >&2; return 1; }
}

@test "doc-writer: summary and PR body are rewritten on every dispatch, re-runs included" {
  grep -qE '^4\. Write `10-summary.md` and `pr-body.md` .*every dispatch' "$REPO_ROOT/agents/doc-writer.md" ||
    { echo "doc-writer step 4 does not rewrite on every dispatch" >&2; return 1; }
}

@test "ship: the ARTEFACTS check is one test -f call per path, never a loop" {
  grep -E '^2\. Every comma-separated ARTEFACTS path' "$REPO_ROOT/skills/ship/references/dispatch.md" | grep -q 'one call per path' ||
    { echo "dispatch.md return check does not say one call per path" >&2; return 1; }
}

@test "spec-analyser: ACs state behaviour, never how a criterion is tested" {
  awk '/^Rules for applying it:$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/agents/spec-analyser.md" | grep -q 'Behaviour, not test method' ||
    { echo "spec-analyser has no behaviour-not-test-method rule" >&2; return 1; }
}

@test "doc-writer: the introduction aims well under the length limit, and a retry cuts below it" {
  local f="$REPO_ROOT/agents/doc-writer.md"
  grep -E '^Length:' "$f" | grep -q 'aim for about 200' || { echo "doc-writer length rule has no headroom target" >&2; return 1; }
  awk '/^## Retry$/{f=1; next} /^## /{f=0} f' "$f" | grep -q 'about 200' || { echo "doc-writer retry does not cut to the target" >&2; return 1; }
}

@test "doc-writer: a retry is exempt from the fresh rewrite and cuts relative to the check's maximum" {
  local f="$REPO_ROOT/agents/doc-writer.md"
  grep -qE '^4\. Write `10-summary.md` and `pr-body.md` .*except a retry' "$f" || { echo "step 4 does not exempt the retry" >&2; return 1; }
  awk '/^## Retry$/{f=1; next} /^## /{f=0} f' "$f" | grep -q 'under the maximum' || { echo "retry length target is not relative to the maximum" >&2; return 1; }
}

@test "prompt template: commits carry the plain Claude trailer" {
  awk '/^## Git and PR$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/templates/artefacts/prompt.md" |
    grep -qF 'Co-Authored-By: Claude <noreply@anthropic.com>' || { echo "prompt template has no plain trailer rule" >&2; return 1; }
}

@test "init: numbered sections 1 to 13 in order" {
  local got
  got=$(grep -E '^## [0-9]+\. ' "$REPO_ROOT/skills/init/SKILL.md" | sed -E 's/^## ([0-9]+)\..*/\1/' | tr '\n' ' ')
  [ "$got" = "1 2 3 4 5 6 7 8 9 10 11 12 13 " ] || { printf 'init sections: %s\n' "$got" >&2; return 1; }
}

@test "init: §5 asks every inferred value, retro.repo by name" {
  local s5
  s5=$(awk '/^## 5\. /{f=1; next} /^## 6\. /{f=0} f' "$REPO_ROOT/skills/init/SKILL.md")
  grep -q 'retro.repo' <<< "$s5" || { echo "§5 does not name retro.repo" >&2; return 1; }
  grep -q 'only sensible' <<< "$s5" || { echo "§5 does not forbid skipping an obvious inferred value" >&2; return 1; }
}

@test "init: the §13 clean-up is one line and an exact rule in template 2" {
  local f="$REPO_ROOT/skills/init/SKILL.md" cmd
  cmd=$(awk '/^## 13\. /{f=1} f && /^rm -f \.aew\/runs\/init-/{print; exit}' "$f")
  [ -n "$cmd" ] || { echo "no rm -f line in §13" >&2; return 1; }
  case $cmd in *'\') echo "§13 clean-up continues onto another line" >&2; return 1 ;; esac
  grep -qF "\"Bash($cmd)\"" "$f" || { echo "template 2 lacks the exact rule Bash($cmd)" >&2; return 1; }
}

@test "ship, ship-milestone, resume and prompt: every file-and-heading citation resolves" {
  local f c cf h p n bad="" total=0 ship_n=0 ms_n=0
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
        ship-milestone/SKILL.md) p=skills/ship-milestone/SKILL.md ;;
        ship/SKILL.md | SKILL.md) p=skills/ship/SKILL.md ;;
        mode-selection.md | bulk.md | sequential.md) p=skills/ship-milestone/references/$cf ;;
        prompt/SKILL.md) p=skills/prompt/SKILL.md ;;
        resume/SKILL.md) p=skills/resume/SKILL.md ;;
        *) p=skills/ship/references/$cf ;;
      esac
      [ "$(grep -cxF -- "$h" "$REPO_ROOT/$p" 2> /dev/null || true)" -eq 1 ] || bad="$bad${f#"$REPO_ROOT"/}: unresolved: $c"$'\n'
    done < <(grep -oE '`(prompt/SKILL|resume/SKILL|ship-milestone/SKILL|ship/SKILL|SKILL|mode-selection|bulk|sequential|preflight|dispatch|gates|routing|pr|final-report)\.md` `## [^`]+`' "$f" | sort -u || true)
    total=$((total + n))
    [ "$f" != "$REPO_ROOT/skills/ship/SKILL.md" ] || ship_n=$n
    [ "$f" != "$REPO_ROOT/skills/ship-milestone/SKILL.md" ] || ms_n=$n
  done < <(find "$REPO_ROOT/skills/ship" "$REPO_ROOT/skills/ship-milestone" "$REPO_ROOT/skills/resume" "$REPO_ROOT/skills/prompt" -type f -name '*.md')
  [ "$ship_n" -ge 1 ] || bad="${bad}no citation found in skills/ship/SKILL.md"$'\n'
  [ "$ms_n" -ge 1 ] || bad="${bad}no citation found in skills/ship-milestone/SKILL.md"$'\n'
  [ "$total" -ge 1 ] || bad="${bad}no citation found anywhere"$'\n'
  report_offenders "citations" "$bad"
}

@test "frontmatter: description is valid YAML (no unquoted ': ') in every entry skill and agent" {
  local f v bad="" n=0
  for f in "$REPO_ROOT"/skills/{init,ship,ship-milestone,resume,status,prompt}/SKILL.md "$REPO_ROOT"/agents/*.md; do
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
  [ "$n" -ge 13 ] || bad="${bad}only $n files checked"$'\n'
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

@test "every skill command is pre-approvable headless" {
  local f files=() bad
  for f in "$REPO_ROOT"/skills/{init,ship,ship-milestone,resume,status,prompt}/SKILL.md "$REPO_ROOT"/skills/ship/references/*.md "$REPO_ROOT"/skills/ship-milestone/references/*.md "$REPO_ROOT"/skills/init/references/*.md; do
    [ -f "$f" ] && files+=("$f")
  done
  [ "${#files[@]}" -ge 15 ] || { printf 'only %s skill files found\n' "${#files[@]}" >&2; return 1; }
  bad=$(preapprovable_offenders "$REPO_ROOT" "${files[@]}" | grep -v ': S1 ' || true)
  report_offenders "pre-approvable commands (Rewrite guide H1-H8, M1; C1 pipe in a condition)" "$bad"
}

@test "every existence or condition check prints its outcome" {
  local f files=() bad n=0
  for f in "$REPO_ROOT"/skills/{init,ship,ship-milestone,resume,status,prompt}/SKILL.md "$REPO_ROOT"/skills/ship/references/*.md "$REPO_ROOT"/skills/ship-milestone/references/*.md "$REPO_ROOT"/skills/init/references/*.md; do
    [ -f "$f" ] && files+=("$f") && n=$((n + $(grep -cE '(test|\[) [^`]*&& echo [a-z]+ \\?\|\\?\| echo [a-z]+' "$f" || true)))
  done
  [ "$n" -ge 10 ] || { printf 'only %s printed checks found\n' "$n" >&2; return 1; }
  bad=$(preapprovable_offenders "$REPO_ROOT" "${files[@]}" | grep ': S1 ' || true)
  report_offenders "silent checks (S1)" "$bad"
}

@test "ship-milestone: no stage sections, dispatch rows or gate steps (it reuses ship)" {
  local d="$REPO_ROOT/skills/ship-milestone" f bad="" n=0
  [ -d "$d" ] || { echo "skills/ship-milestone is missing" >&2; return 1; }
  while IFS= read -r f; do
    n=$((n + 1))
    bad="$bad$(absent_regex "$f" '^## Stage: 
^## Gate: 
^\| D[0-9]+ \|
^\| Row \| Agent and mode \|
^[0-9]+\. (Set pending|Apply the answer):')"
  done < <(find "$d" -type f -name '*.md')
  [ "$n" -eq 4 ] || bad="${bad}want 4 files under skills/ship-milestone, found $n"$'\n'
  report_offenders "pipeline copy in ship-milestone (AC-25)" "$bad"
}
