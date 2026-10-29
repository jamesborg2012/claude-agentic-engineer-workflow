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

@test "developer: leftover clean-up salvages uncommitted work before removing a worktree" {
  local step
  step=$(awk '/^### Mode: full$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/developer.md" | awk '/^2\. Clear leftovers/{f=1; print; next} /^3\. /{f=0} f')
  [ -n "$step" ] || { echo "developer full mode has no leftover clean-up step" >&2; return 1; }
  grep -qF 'salvage blocked attempt' <<< "$step" || { echo "leftover clean-up does not commit the uncommitted work" >&2; return 1; }
  grep -qF 'wp-<n>-salvage-<k>' <<< "$step" || { echo "leftover clean-up does not keep the attempt on a salvage branch" >&2; return 1; }
  ! grep -qF 'remove it (`git worktree remove --force' <<< "$step" || { echo "leftover clean-up still force-removes first" >&2; return 1; }
}

@test "senior-engineer: guarded files are owner hand-offs, and the plan's list matches the edit guard's" {
  local f="$REPO_ROOT/agents/senior-engineer.md" names n bad=""
  grep -qF 'Name it in Risks as `Owner hand-off: <path>' "$f" || { echo "plan mode has no owner hand-off rule" >&2; return 1; }
  grep -qF '`guard.allow_paths`)' "$f" || { echo "plan mode does not read guard.allow_paths" >&2; return 1; }
  # Every basename pattern in guard-edit.sh's case list, deny rows and exceptions alike.
  names=$(awk '/case "\$b" in/{f=1; next} /esac/{f=0} f' "$REPO_ROOT/scripts/hooks/guard-edit.sh" | sed -E 's/^ *//; s/\).*//' | tr '|' '\n' | sed -E 's/^ *//; s/ *$//')
  [ -n "$names" ] || { echo "no patterns read from guard-edit.sh" >&2; return 1; }
  while IFS= read -r n; do
    grep -qF "\`$n\`" "$f" || bad="$bad  $n"$'\n'
  done <<< "$names"
  report_offenders "guard pattern missing from senior-engineer.md" "$bad"
}

@test "ship: the plan-approval summary quotes owner hand-offs" {
  awk '/^## Gate: plan-approval$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/skills/ship/references/gates.md" | grep -qF 'every `Owner hand-off:` and `Unverified:` line verbatim' ||
    { echo "plan-approval summary does not quote owner hand-offs" >&2; return 1; }
}

@test "developer: a block names its cause, and an environment block can be picked up in place" {
  local f="$REPO_ROOT/agents/developer.md" bad=""
  grep -qx 'Block cause: none / plan / environment' "$REPO_ROOT/templates/artefacts/dev-report.md" || bad="${bad}dev-report template has no Block cause line"$'\n'
  grep -qF 'The `Block cause:` line holds exactly one of' "$f" || bad="${bad}developer does not define Block cause"$'\n'
  grep -qF 'left uncommitted: WP-<n>' "$f" || bad="${bad}a sequential environment block does not record its unfinished WP"$'\n'
  awk '/^Step 0, for every mode:$/{f=1; next} /^## /{f=0} f' "$f" | grep -qF 'left uncommitted: WP-<n>' || bad="${bad}Step 0 does not allow picking up the unfinished WP"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "ship: an environment block in full mode goes to the environment gate, not a re-plan" {
  local g="$REPO_ROOT/skills/ship/references/gates.md" sec bad=""
  awk '/^## Developer blocked$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/skills/ship/references/routing.md" | grep -qF '`gates.md` `## Gate: environment`' ||
    bad="${bad}routing.md Developer blocked does not route to the environment gate"$'\n'
  grep -qE '^The gate ids are .*`environment`' "$g" || bad="${bad}environment is not a listed gate id"$'\n'
  grep -qF '| `environment` | `state.sh status awaiting_input --note "gate:environment 06-dev-report.md"`' "$g" || bad="${bad}no pending-state row for environment"$'\n'
  grep -qF 'The six `awaiting_input` gates never skip' "$g" || bad="${bad}the environment gate is not counted among the unskippable gates"$'\n'
  sec=$(awk '/^## Gate: environment$/{f=1; next} /^## /{f=0} f' "$g")
  [ -n "$sec" ] || bad="${bad}gates.md has no Gate: environment section"$'\n'
  grep -qF 'Fixed, continue (recommended)' <<< "$sec" || bad="${bad}environment gate has no continue option"$'\n'
  grep -qF 'never consumes the re-plan' <<< "$sec" || bad="${bad}continue does not keep the re-plan allowance"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "ship: check-env.sh runs before D8 and at the plan gate, and a failure is the environment gate" {
  local s="$REPO_ROOT/skills/ship" sec bad=""
  sec=$(awk '/^## Stage: develop$/{f=1; next} /^## /{f=0} f' "$s/SKILL.md")
  grep -qE '^3\. Environment check, D8 only\..*`check-env\.sh \.aew/runs/<id>/05-plan\.md`.*`gates\.md` `## Gate: environment`' <<< "$sec" || bad="${bad}develop does not run check-env.sh before D8"$'\n'
  awk '/^## Gate: plan-approval$/{f=1; next} /^## /{f=0} f' "$s/references/gates.md" | grep -qF 'run `check-env.sh <rd>/05-plan.md`' || bad="${bad}plan-approval summary has no environment check"$'\n'
  awk '/^## Gate: environment$/{f=1; next} /^## /{f=0} f' "$s/references/gates.md" | grep -qF '`gate:environment check-env`' || bad="${bad}environment gate has no check source"$'\n'
  grep -qF '"Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-env.sh *)"' "$REPO_ROOT/skills/init/SKILL.md" || bad="${bad}init does not pre-approve check-env.sh"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "senior-engineer: the plan's Environment lines use only the forms check-env.sh reads" {
  local f="$REPO_ROOT/agents/senior-engineer.md"
  grep -qx '## Environment' "$REPO_ROOT/templates/artefacts/plan.md" || { echo "plan template has no Environment section" >&2; return 1; }
  grep -qF '13. **Environment**' "$f" || { echo "plan mode has no Environment step" >&2; return 1; }
  grep -qF -- '- `- tool: <command> <major>`' "$f" && grep -qF -- '- `- service: docker`' "$f" || { echo "plan mode does not give the check's line forms" >&2; return 1; }
}

@test "review: a finding only a material spec change can fix goes to the review-decision gate" {
  local se="$REPO_ROOT/agents/senior-engineer.md" g="$REPO_ROOT/skills/ship/references/gates.md" sec bad=""
  grep -qx '## Questions for James' "$REPO_ROOT/templates/artefacts/review.md" || bad="${bad}review template has no Questions for James"$'\n'
  awk '/^### Mode: review$/{f=1; next} /^### /{f=0} f' "$se" | grep -qF '`## Questions for James`' || bad="${bad}review mode does not ask material questions"$'\n'
  grep -qE '^- review: `ok` for both verdicts, or `needs_input`' "$se" || bad="${bad}review return contract has no needs_input"$'\n'
  grep -qF 'senior-engineer in review mode (gate `review-decision`)' "$REPO_ROOT/skills/ship/references/routing.md" || bad="${bad}routing does not accept needs_input from review"$'\n'
  grep -qE '^The gate ids are .*`review-decision`' "$g" || bad="${bad}review-decision is not a listed gate id"$'\n'
  sec=$(awk '/^## Gate: review-decision$/{f=1; next} /^## /{f=0} f' "$g")
  [ -n "$sec" ] || bad="${bad}gates.md has no Gate: review-decision section"$'\n'
  grep -qF 'state.sh bump review_cycle' <<< "$sec" || bad="${bad}the gate does not keep the review artefact by bumping the cycle"$'\n'
  grep -qF 'as `## Gate: plan-challenge` step 4' <<< "$sec" || bad="${bad}the answer does not go through spec re-analysis"$'\n'
  grep -qF '`gates.md` `## Gate: review-decision`' "$REPO_ROOT/skills/ship-milestone/references/bulk.md" || bad="${bad}bulk re-analysis does not cover review-decision"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "review: a fix cycle fixes minors, and open minors and nits reach the PR body" {
  local bad=""
  grep -qF 'fix the blocker, major and minor findings, and list nits under Deviations' "$REPO_ROOT/agents/developer.md" || bad="${bad}developer fix mode does not fix minors"$'\n'
  grep -qx '## Follow-ups' "$REPO_ROOT/templates/artefacts/pr-body.md" || bad="${bad}PR body template has no Follow-ups"$'\n'
  grep -qF 'Follow-ups: every minor and nit finding of the highest-numbered `07-review-<n>.md`' "$REPO_ROOT/agents/doc-writer.md" || bad="${bad}doc-writer does not fill Follow-ups"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "plan: an unverified tool behaviour is confirmed or proved first, and quoted at the gate (#42)" {
  local bad=""
  grep -qF 'Risks line `Unverified: <behaviour>: <how WP-<n> proves it first>`' "$REPO_ROOT/agents/senior-engineer.md" || bad="${bad}plan mode has no Unverified rule"$'\n'
  awk '/^## Gate: plan-approval$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/skills/ship/references/gates.md" | grep -qF 'every `Owner hand-off:` and `Unverified:` line verbatim' || bad="${bad}plan-approval summary does not quote Unverified lines"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "plan: a mitigation the code can carry is built in the first pass, not left to QA (#19)" {
  grep -E '^10\. \*\*Risks\*\*' "$REPO_ROOT/agents/senior-engineer.md" | grep -qF 'never leave it as a QA check' ||
    { echo "plan Risks step does not build code mitigations in" >&2; return 1; }
}

@test "plan: an AC met by a tool setting gets a test of its effect, not of its presence (#41)" {
  awk '/^14\. \*\*Tool assumptions\*\*/{f=1; next} /^[0-9]+\. /{f=0} f' "$REPO_ROOT/agents/senior-engineer.md" | grep -qF 'a unit test of the effect' ||
    { echo "plan step 14 has no setting-effect rule" >&2; return 1; }
}

@test "plan: a pinned version is confirmed, with @latest as the named fallback (#47)" {
  awk '/^14\. \*\*Tool assumptions\*\*/{f=1; next} /^[0-9]+\. /{f=0} f' "$REPO_ROOT/agents/senior-engineer.md" | grep -qF 'name `@latest` as the fallback' ||
    { echo "plan step 14 has no version fallback rule" >&2; return 1; }
}

@test "plan: a health check probes what the code uses, never a socket (#48)" {
  awk '/^14\. \*\*Tool assumptions\*\*/{f=1; next} /^[0-9]+\. /{f=0} f' "$REPO_ROOT/agents/senior-engineer.md" | grep -qF 'never a socket or process check' ||
    { echo "plan step 14 has no readiness-probe rule" >&2; return 1; }
}

@test "plan: stateful endpoints get one isolation pattern that the developer and QA share (#15)" {
  local bad=""
  grep -E '^9\. \*\*Unit tests per work package\*\*' "$REPO_ROOT/agents/senior-engineer.md" | grep -qF 'name one isolation pattern' || bad="${bad}plan has no isolation-pattern rule"$'\n'
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF "the plan's isolation pattern" || bad="${bad}QA phase B does not use the plan's isolation pattern"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "brief: standards overrides are recorded once and followed downstream (#7)" {
  local bad=""
  grep -qx '## Standards overrides' "$REPO_ROOT/templates/artefacts/brief.md" || bad="${bad}brief template has no Standards overrides"$'\n'
  grep -qx '## Standards overrides' "$REPO_ROOT/templates/artefacts/standards-run.md" || bad="${bad}standards-run template has no Standards overrides"$'\n'
  grep -qF '**Standards overrides**' "$REPO_ROOT/agents/brief-compiler.md" || bad="${bad}brief-compiler does not fill overrides"$'\n'
  grep -qF '"Standards overrides":' "$REPO_ROOT/agents/standards-setter.md" || bad="${bad}standards-setter does not carry overrides"$'\n'
  grep -qF '`## Standards overrides` of `03-standards.md`' "$REPO_ROOT/agents/senior-engineer.md" || bad="${bad}review and plan do not follow overrides"$'\n'
  grep -qF '`## Standards overrides` of `03-standards.md`' "$REPO_ROOT/agents/developer.md" || bad="${bad}developer does not follow overrides"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "brief: a spec criteria map traces every AC to its spec criterion, into the snapshot (#22)" {
  local bad=""
  grep -qx '## Spec criteria map' "$REPO_ROOT/templates/artefacts/brief.md" || bad="${bad}brief template has no Spec criteria map"$'\n'
  grep -qF '**Spec criteria map**' "$REPO_ROOT/agents/brief-compiler.md" || bad="${bad}brief-compiler does not fill the map"$'\n'
  grep -qF 'AC appears in exactly one row of the spec criteria map' "$REPO_ROOT/agents/brief-compiler.md" || bad="${bad}brief self-check does not check the map"$'\n'
  grep -qF '`| Spec criterion | AC | TC | Test | Result |`' "$REPO_ROOT/agents/doc-writer.md" || bad="${bad}snapshot traceability does not show the spec criterion"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "brief: forbidden literals are listed once and never written by any agent (#17, #23)" {
  local f bad=""
  grep -qx '## Forbidden literals' "$REPO_ROOT/templates/artefacts/brief.md" || bad="${bad}brief template has no Forbidden literals"$'\n'
  grep -qF '**Forbidden literals**' "$REPO_ROOT/agents/brief-compiler.md" || bad="${bad}brief-compiler does not fill forbidden literals"$'\n'
  grep -qF 'Forbidden literal: <literal> (<test file>)' "$REPO_ROOT/agents/senior-engineer.md" || bad="${bad}plan cannot add a forbidden literal"$'\n'
  for f in developer qa-engineer doc-writer; do
    awk '/^## Guardrails$/{g=1; next} /^## /{g=0} g' "$REPO_ROOT/agents/$f.md" | grep -qF "the brief's \`## Forbidden literals\`" || bad="${bad}$f has no forbidden-literal guardrail"$'\n'
  done
  awk '/^## 3\. Never include$/{g=1; next} /^## /{g=0} g' "$REPO_ROOT/skills/claude-md-curation/SKILL.md" | grep -qF 'Forbidden literals' || bad="${bad}curation never-include list has no forbidden literals"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "repository-search tests stay narrow, and a needed literal narrows the guard (#16)" {
  local bad=""
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF 'never test files' || bad="${bad}QA has no narrow-search rule"$'\n'
  grep -qF 'plan narrowing that guard test' "$REPO_ROOT/agents/senior-engineer.md" || bad="${bad}plan does not narrow a guard the work must cross"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "plan: notes for QA live in the plan, and QA phase B applies them (#59)" {
  local bad=""
  grep -qx '## Notes for QA' "$REPO_ROOT/templates/artefacts/plan.md" || bad="${bad}plan template has no Notes for QA"$'\n'
  grep -qF '15. **Notes for QA**' "$REPO_ROOT/agents/senior-engineer.md" || bad="${bad}plan mode has no Notes for QA step"$'\n'
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF '`## Notes for QA` of `05-plan.md`' || bad="${bad}QA phase B does not read the notes"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "manual tests that need a GitHub event carry one tag, listed once (#60)" {
  local bad=""
  grep -qF '`[needs GitHub]`' "$REPO_ROOT/skills/run-protocol/SKILL.md" || bad="${bad}run protocol does not define the tag"$'\n'
  grep -qF '[needs GitHub]' "$REPO_ROOT/templates/artefacts/manual-tests.md" || bad="${bad}manual-tests template has no tag"$'\n'
  grep -E '^7\. Manual-only cases' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF '`[needs GitHub]`' || bad="${bad}QA phase A does not tag GitHub-event cases"$'\n'
  grep -qF 'Manual tests outstanding: <count> (<k> need GitHub)' "$REPO_ROOT/skills/ship/references/final-report.md" || bad="${bad}final report does not count them"$'\n'
  grep -qF '`[needs GitHub]` items together' "$REPO_ROOT/agents/doc-writer.md" || bad="${bad}doc-writer does not group them"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "review and QA hand docs follow-ups to the doc-writer in a section, not NEXT (#18)" {
  local bad=""
  grep -qx '## Docs follow-ups' "$REPO_ROOT/templates/artefacts/review.md" || bad="${bad}review template has no Docs follow-ups"$'\n'
  grep -qx '## Docs follow-ups' "$REPO_ROOT/templates/artefacts/qa-report.md" || bad="${bad}QA report template has no Docs follow-ups"$'\n'
  awk '/^### Mode: review$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/senior-engineer.md" | grep -qF '`## Docs follow-ups`' || bad="${bad}review mode does not write docs follow-ups"$'\n'
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF '`## Docs follow-ups`' || bad="${bad}QA phase B does not write docs follow-ups"$'\n'
  grep -qF 'Apply every `## Docs follow-ups` line' "$REPO_ROOT/agents/doc-writer.md" || bad="${bad}doc-writer does not apply docs follow-ups"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "every QA test title carries its TC id, and the report names each TC's test file (#8, #30)" {
  local bad=""
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF 'at every level, has a title that starts `TC-<n>: `' || bad="${bad}QA titles do not carry TC ids at every level"$'\n'
  grep -qF '| TC | AC | Test | Result |' "$REPO_ROOT/templates/artefacts/qa-report.md" || bad="${bad}QA report Results has no Test column"$'\n'
  grep -qF "its Test from the passing QA report's Results" "$REPO_ROOT/agents/doc-writer.md" || bad="${bad}snapshot does not take the test file from the QA report"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "developer: look-alike fixtures are escapes, asserted and read back before the report says so (#31)" {
  awk '/^### Every work package$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/developer.md" | grep -qF "grep -n '[^ -~]' <file>" ||
    { echo "developer has no non-ASCII read-back for fixtures" >&2; return 1; }
}

@test "standards: every generated doc's testing conventions cover look-alike fixtures (#32)" {
  grep -qF 'is written as an escape, never the raw character, and its test asserts the code point' "$REPO_ROOT/skills/stack-standards/references/document-structure.md" ||
    { echo "document structure has no look-alike fixture rule" >&2; return 1; }
}

@test "developer: an escape-sensitive fix is tested on the output it produces (#49)" {
  awk '/^### Mode: fix$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/developer.md" | grep -qF 'test asserts the string it generates' ||
    { echo "fix mode has no escape-sensitive rule" >&2; return 1; }
}

@test "developer: prose added to a config or doc is re-read against the file's own values (#58)" {
  awk '/^### Every work package$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/developer.md" | grep -qF "against the values in the same file" ||
    { echo "developer has no prose read-back rule" >&2; return 1; }
}

@test "ui-qa: a state with no data seam is built by rewriting the response, not by editing the live page (#27)" {
  awk '/^## 5\. Writing specs$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/skills/ui-qa/SKILL.md" | grep -qF 'document response with `page.route` and abort the page'"'"'s scripts' ||
    { echo "ui-qa has no response-rewrite rule" >&2; return 1; }
}

@test "qa: stub call logs keep one argument per line, and assertions follow what a tool prints (#54)" {
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF 'one argument per line' ||
    { echo "QA has no stub-log rule" >&2; return 1; }
}

@test "qa: tests of config files match keys with comments stripped, not free text (#57)" {
  awk '/^### Phase B$/{f=1; next} /^### /{f=0} f' "$REPO_ROOT/agents/qa-engineer.md" | grep -qF 'anchors on keys with comments stripped' ||
    { echo "QA has no config-file matching rule" >&2; return 1; }
}

@test "final reports name retro.repo for retro items, never the project repo (#36)" {
  local f bad=""
  for f in skills/ship/references/final-report.md skills/ship-milestone/SKILL.md; do
    grep -qF 'Retro items filed: <count> in <retro.repo> (' "$REPO_ROOT/$f" || bad="${bad}$f does not name retro.repo"$'\n'
  done
  grep -qF "jq -r '.retro.repo' .aew/config.json" "$REPO_ROOT/skills/ship/references/final-report.md" || bad="${bad}final-report does not say where retro.repo comes from"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "spec-analyser: a prompt-mode run writes no agent memory (#34)" {
  awk '/^## Memory$/{f=1; next} /^## /{f=0} f' "$REPO_ROOT/agents/spec-analyser.md" | grep -qF 'write no memory' ||
    { echo "spec-analyser still writes memory in prompt mode" >&2; return 1; }
}

@test "init: Next.js 16 gets typegen before tsc, and an && command becomes one rule per part (#35)" {
  local bad=""
  grep -qF 'typecheck `npx next typegen && npx tsc --noEmit`' "$REPO_ROOT/skills/init/SKILL.md" || bad="${bad}init does not infer typegen for Next.js 16"$'\n'
  grep -qF 'joined by ` && ` becomes one rule per part' "$REPO_ROOT/skills/init/references/permissions.md" || bad="${bad}permissions do not split && commands"$'\n'
  [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "init: proposes git.branch_pattern from the project's branch convention (#56)" {
  grep -E '^\| `git\.branch_pattern` \|' "$REPO_ROOT/skills/init/SKILL.md" | grep -qF '`{spec}-{issue}-{slug}`' ||
    { echo "init has no branch-convention row" >&2; return 1; }
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

@test "retro fixes from prompt 07 stay in their prompts" {
  local bad=""
  grep -qF 'The count is the last line number the Read' "$REPO_ROOT/skills/claude-md-curation/SKILL.md" || bad="$badskills/claude-md-curation/SKILL.md"$'\n'
  grep -qF 'Copy test counts from the runner'\''s output' "$REPO_ROOT/agents/developer.md" || bad="$badagents/developer.md"$'\n'
  grep -qF 'reuse the exact strings the brief gives' "$REPO_ROOT/agents/developer.md" || bad="$badagents/developer.md"$'\n'
  grep -qF 'give the repeat count and the result in the report' "$REPO_ROOT/agents/developer.md" || bad="$badagents/developer.md"$'\n'
  grep -qF 'check it serves the current change' "$REPO_ROOT/skills/ui-qa/SKILL.md" || bad="$badskills/ui-qa/SKILL.md"$'\n'
  grep -qF 'From here on `spec-final.md` is the spec' "$REPO_ROOT/skills/ship/references/gates.md" || bad="$badskills/ship/references/gates.md"$'\n'
  grep -qF 'so the two numbering schemes never mix' "$REPO_ROOT/agents/brief-compiler.md" || bad="$badagents/brief-compiler.md"$'\n'
  grep -qF 'put the table inside a `<details>` block' "$REPO_ROOT/agents/doc-writer.md" || bad="$badagents/doc-writer.md"$'\n'
  grep -qF 'compare HTML attribute names case-insensitively' "$REPO_ROOT/agents/qa-engineer.md" || bad="$badagents/qa-engineer.md"$'\n'
  report_offenders "retro rule missing from" "$bad"
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
