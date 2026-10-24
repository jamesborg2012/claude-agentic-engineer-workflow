# Phase D plan — Hooks

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** D of the EPIC (runs in parallel with B and C after A; E closes)
- **Depth:** full
- **ACs covered:** AC-17, AC-18, AC-19, AC-20, AC-21, AC-22, AC-23
- **Risk:** safety-guards. Hooks fire in every session where the plugin is enabled; a bug either bricks sessions or silently removes protection. D2, D3, D4 and D6 are RISKY.
- **Builds on:** Phase A "Interface contract" (as revised after senior review) and `docs/superpowers/plans/phases/2026-10-24-scripts-github-io-and-hooks-platform-facts.md` (verified against code.claude.com/docs, 2026-10-24). This plan does not re-verify the docs.
- **Date:** 2026-10-24

## Purpose

Phase D builds DESIGN §11: two `PreToolUse` guards (Bash, Edit/Write), one `SubagentStop` gate (developer and qa-engineer), the `SessionStart` resume hint, the shared preamble `scripts/lib/hooks.sh`, `hooks/hooks.json`, and the DESIGN §3/§11 and `state-machine.md` corrections those platform facts require. D edits no A-owned file. Its tests are `tests/scripts/hooks-*.bats` and its fixtures live only under `tests/scripts/fixtures/hooks/`.

## Facts verified while planning (not assumptions)

Checked on this machine (`/bin/bash` 3.2.57, jq 1.7.1, Claude Code 2.1.308):

- **`[ a -nt b ]` is whole-second on bash 3.2.** A file written 0.2 s after another is *not* `-nt` it. So "report modified at or after the state write" is `! [ "$state" -nt "$report" ]`, which is true for the same second and later. No `stat`, no `perl`, no extra spawn. Tests make a report stale with `touch -t 202001010000 <report>` (portable on BSD and GNU).
- `read -r -a toks <<< "$seg"` word-splits on IFS **without** glob expansion (`*` survives as a literal token), and quotes stay in the token (`"main"`). So the Bash guard tokenises with `read -r -a` and strips `'` and `"` per token. No `set -f` needed.
- `${s//&&/$'\n'}` works on bash 3.2.
- `shopt -s nocasematch` works with `case` on bash 3.2 (`.ENV` matches `.env)`).
- **IFS-whitespace collapse:** with `IFS=$'\t' read -r a b <<< $'\tfalse'`, `a` becomes `false` (a leading empty field is collapsed, because tab is IFS whitespace). So when one jq `@tsv` line carries several fields, the field that is never empty goes **first** (`[stop_hook_active, cwd]`).
- jq exits 5 on a non-object payload (`[]`), and exits **0 with no output** on empty stdin. So the preamble rejects an empty payload explicitly; it can't rely on jq's status.
- An EXIT trap set inside a function under `set -e` fires on a failing `x=$(exit 3)` with `$?` = 3, and `exit 0` in the trap makes the shell exit 0. This is the fail-open mechanism.
- **(Added at architect review, verified on `/bin/bash` 3.2.57.)** After an **unbound variable** (`set -u`) or a **syntax error** later in the file, bash 3.2 still runs the EXIT trap and the hook exits 0, but `$?` in the trap is **0**, so `_hook_exit` prints no "failing open" warning. These paths fail open *silently*. In the Bash guard that means an empty-array expansion such as `"${toks[@]}"` on a blank segment silently **allows the whole command**. Hence the empty-segment and empty-token rules in D2 and the `${a[@]+"${a[@]}"}` rule below.
- **(Added at architect review, verified.)** `IFS=$'\t' read -r a b <<<"$(jq … bad-file)"` returns 0 with empty fields when jq fails: a failure inside a here-string's `$(…)` is invisible. Capture first (`x=$(jq …) || …`), then `read <<<"$x"`.
- **(Added at architect review, verified.)** In `case` patterns, `[a-z]*` means *one* letter followed by *anything*, not "zero or more letters". So the glob `-[a-zA-Z]*f[a-zA-Z]*` does **not** match `-uf` or `-f`. Short-option clusters are therefore defined in D2 as tokens matching `-[!-]*`, tested with `*f*`.
- `claude plugin validate .` passes on the current tree (exit 0, "passed with warnings" from the directory profile). It **does** validate `hooks/hooks.json`, but an unknown event name is only a warning (`❯ hooks: hooks.PreToolUze: unknown hook event; entry ignored at runtime`) and still exits 0. The hooks.json test therefore also asserts there is no `hooks:` finding in the output.

## Corrections to the spec's assumptions (from the platform facts)

| Spec | Change in this plan | Why |
|---|---|---|
| A4 (accept `developer` and `aew:developer`) | Accept only `aew:developer` and `aew:qa-engineer`. The `SubagentStop` matcher is the anchored regex `^aew:(developer\|qa-engineer)$`, so a bare name never reaches the script; accepting it would be dead code. Any other `agent_type` → exit 0 silently. | Platform facts 3: the matcher matches `agent_type`, and plugin agents are `aew:<agent>`. |
| A2 / A3 / A5 | Confirmed as written: PreToolUse deny is `hookSpecificOutput.permissionDecision: "deny"` on exit 0, SubagentStop block is top-level `{"decision":"block","reason":…}` on exit 0, SessionStart uses `hookSpecificOutput.additionalContext`. No hook ever exits 2. | Platform facts 4–6. |
| A7 | Confirmed: exit-0 stderr is never shown to Claude (debug log only). Per the architect's note, hooks are still **silent** when there is no `.aew/` at all, and warn only when `.aew/` exists without `config.json`. | Platform facts 7. |
| A17 | The return-block validator moves from `hooks.sh` into `gate-subagent.sh`, its only caller (CTO cut). | CTO cut. |
| AC-18 (`MultiEdit`/`NotebookEdit` "if the docs list them") | Matcher is `Edit\|Write` only. `MultiEdit` is not a documented current tool, and `NotebookEdit` edits only `.ipynb` files, which can't be a `.env*`, a secret file or a `.git/` path in practice. | Platform facts 2 ("not documented"); simplicity. |
| AC-22 ("an ERR trap forces exit 0") | An **EXIT** trap, installed after `$1` handling. | Phase A contract: ERR never fires for `die`'s `exit`, nor inside functions without `set -E`. |
| AC-19 ("modified at or after the run's `updated_at`") | Implemented as "not older than `state.json`" (`! [ state.json -nt report ]`). `state.sh` writes `updated_at = now` and renames `state.json` in the same second, and only `state.sh` writes it, so the two are equivalent at bash 3.2's whole-second resolution without a date parse or a `stat`. | Facts above; A lint bans `stat -c`/`stat -f`. |

## Contract for D2–D5: `scripts/lib/hooks.sh`

A library (the A conventions for `scripts/lib/*.sh` apply: shebang, `Usage:` header, last line `if [ "${BASH_SOURCE[0]}" = "$0" ]; then lib_main "$0" "$@"; fi`). It sources common.sh with `# shellcheck source=common.sh` then `. "$(dirname "${BASH_SOURCE[0]}")/common.sh"`. At source time it only defines functions. It is the shared preamble and nothing else.

Every hook script starts:

```bash
#!/usr/bin/env bash
# Usage: <hook>.sh < payload.json
# …
# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"
hook_init "$@"
```

Sourcing `common.sh` explicitly satisfies A's convention 1 (the executable sources `lib/common.sh`). The double-source guard makes the second source inside `hooks.sh` a no-op.

| Function | Behaviour |
|---|---|
| `hook_init [arg…]` | In this order. **(1)** Arguments: `-h`/`--help` → `print_usage "$0"`, exit 0. Any other non-empty `$1` → `die "unexpected argument: $1 (hooks take their payload on stdin)"`, exit 1 (convention 4; the trap isn't installed yet, so the 1 survives). **(2)** `trap _hook_exit EXIT`. **(3)** `command -v jq` fails → `warn "jq not found; aew hooks are disabled"`, exit 0. **(4)** `HOOK_PAYLOAD=$(cat)`. If it's empty, or `parsed=$(jq -r '[(.stop_hook_active == true \| tostring), (.cwd // "" \| tostring)] \| @tsv' <<<"$HOOK_PAYLOAD" 2>/dev/null)` fails → `warn "unreadable hook payload; failing open"`, exit 0. `IFS=$'\t' read -r HOOK_STOP_ACTIVE HOOK_CWD <<<"$parsed"` (the never-empty field first; see the IFS fact). **(5)** `HOOK_STOP_ACTIVE` = `true` → `warn "stop_hook_active is set; allowing the stop"`, exit 0. **(6)** `dir=${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}` (spec A6 precedence). `HOOK_ROOT=$(repo_root "$dir" 2>/dev/null) \|\| exit 0`: not a git repo, so not an aew project, so **silent**. **(7)** `[ -f "$HOOK_ROOT/.aew/config.json" ]` fails → if `[ -d "$HOOK_ROOT/.aew" ]`, `warn ".aew/config.json is missing; aew hooks are disabled (run /aew:init)"`; exit 0 either way (silent when there's no `.aew/`). **(8)** `cd "$HOOK_ROOT"` (so `config_get`/`run_dir` resolve), and set `HOOK_CWD=${HOOK_CWD:-$dir}`. Globals afterwards: `HOOK_PAYLOAD`, `HOOK_CWD` (where the tool runs; may be a linked worktree), `HOOK_ROOT` (main worktree root, physical), `HOOK_STOP_ACTIVE`. |
| `_hook_exit` (EXIT trap) | `s=$?`; `trap - EXIT`; if `s` ≠ 0, `warn "unexpected error (status $s); failing open"`; `exit 0`. Every path after step (2) therefore exits 0, including `die`, errexit and a failing `$(…)` at top level. |
| `hook_field <jq-path>` | `jq -r "<path> // empty" <<<"$HOOK_PAYLOAD"`. Prints the raw string (empty if absent or null). Callers write `cmd=$(hook_field .tool_input.command) \|\| exit 0`, per the A strict-mode caveat. |

Rules every hook follows (A strict-mode caveat): internal functions are called from `if`/`&&`/`||`, so `set -e` is off inside them. Every command whose failure matters is checked explicitly (`x=$(fn) || return 1`). Never `local x=$(…)`. Never feed `$(…)` straight into `read <<<` (its failure is invisible; capture it first). Every array expansion that can be empty is written `${a[@]+"${a[@]}"}`, and every `${a[0]}` is guarded by a `${#a[@]}` check, because an unbound-variable exit fails open silently (facts above). Output is produced by one `jq -n --arg …` call at the very end, so a failure can't leave partial JSON on stdout. No `|&`, `&>>`, `stat`, `grep -P` or `sed -i` anywhere (A lint), including inside `case` patterns. The redirection pattern is written `'&>'*`, never with a literal `&>>`.

## Tasks

Dependency graph: D1 → {D2, D3, D4, D5} (in parallel; each touches only its own script, bats file and fixtures) → D6 → D7.

---

### D1 — Shared hook preamble `scripts/lib/hooks.sh`

- **files:** `scripts/lib/hooks.sh` (new), `tests/scripts/hooks-lib.bats` (new), `tests/scripts/fixtures/hooks/pretooluse-bash.json`, `pretooluse-edit.json`, `subagentstop.json`, `sessionstart.json` (new)
- **depends_on:** []. Phase A must be complete (`common.sh`, the helpers, `seed_run`).
- **pattern:** The `hooks.sh` contract above. Phase A's `common.sh` (library layout, `lib_main` last line, `print_usage` header). Spec A6, A9 and A10, and the CTO cut. Net-new file: no analog exists, four hooks share the preamble, and the spec's scope names it.
- **RISKY:** NOT RISKY. The library has no effect until a hook uses it. D2–D6 carry the risk.
- **AC verified:** AC-22 (the preamble half: fail open, `stop_hook_active`, EXIT trap), AC-28
- **implementation notes:**
  - Payload fixtures are the documented shapes (platform facts 3, 4 and 6), with the common fields `session_id`, `transcript_path`, `cwd`, `hook_event_name` and `permission_mode`, plus:
    - `pretooluse-bash.json`: `tool_name: "Bash"`, `tool_input.command`, `tool_use_id`;
    - `pretooluse-edit.json`: `tool_name: "Edit"`, `tool_input.file_path` (absolute), `old_string`, `new_string`;
    - `subagentstop.json`: `stop_hook_active: false`, `agent_id`, `agent_type: "aew:developer"`, `agent_transcript_path`, `last_assistant_message`;
    - `sessionstart.json`: `source: "startup"`.
    Tests override fields with `jq -c --arg …`, never by editing the files.
  - In-test stub hook: each test writes `$BATS_TEST_TMPDIR/stub.sh`, with a `Usage:` header, sourcing `$SCRIPTS/lib/common.sh` and `hooks.sh` by absolute path, then calling `hook_init "$@"`, then `printf 'cwd=%s root=%s pwd=%s\n' "$HOOK_CWD" "$HOOK_ROOT" "$PWD"`, then an optional `$STUB_TAIL` evaluated (for example `false`, `die boom` or `x=$(exit 3)`).
- **test scenarios (`hooks-lib.bats`).** RED first: every test fails with "No such file" on `hooks.sh`.
  1. `bash scripts/lib/hooks.sh --help` → exit 0 with `Usage:` on stdout. `bash scripts/lib/hooks.sh foo` → exit 1 with `is a library`.
  2. Stub `--help` from a non-git dir with stdin at `/dev/null` → exit 0 with `Usage:`. Stub `--bogus` → exit **1**, empty stdout, `error:` on stderr. This proves `$1` is handled before the trap.
  3. Happy path in an aew project (`setup_project`; payload `cwd` = `$PROJECT/sub`) → exit 0, `cwd=$PROJECT/sub`, `root=$PROJECT`, `pwd=$PROJECT`.
  4. Precedence: `CLAUDE_PROJECT_DIR=$PROJECT` with payload `cwd` = a non-git temp dir → active (`root=$PROJECT`). No `CLAUDE_PROJECT_DIR` and no `cwd` key → falls back to `$PWD`.
  5. Linked worktree: `git worktree add "$BATS_TEST_TMPDIR/wt" -b feat/x`, payload `cwd` = `wt` → `root=$PROJECT`, `cwd=…/wt`.
  6. Inert and silent: a non-git `cwd` → exit 0, empty stdout, **empty stderr**. A git repo without `.aew/` (`setup_project --no-config`, then `rm -rf .aew`) → exit 0 with empty stdout and stderr.
  7. `.aew/` without `config.json` (`setup_project --no-config`, `mkdir .aew`) → exit 0, empty stdout, stderr has `stub.sh: warning:` and `config.json is missing` (`warn` prefixes `${0##*/}`, which is the stub, not `hooks.sh`).
  8. jq missing: build `$BATS_TEST_TMPDIR/nojq` with symlinks to `bash` and `dirname` only, then run the stub with `PATH=$BATS_TEST_TMPDIR/nojq` → exit 0, empty stdout, stderr has `jq not found`.
  9. Payload `''`, `not json` and `[]` → exit 0, stub tail not reached (no `cwd=` on stdout), stderr has `unreadable hook payload`.
  10. `stop_hook_active: true` → exit 0, not reached, stderr has `stop_hook_active`. `stop_hook_active: false`, or the key absent → reached.
  11. Fail-open trap: `STUB_TAIL='false'`, `'die boom'` and `'x=$(exit 3)'` → each exits 0, and stderr has `failing open` (plus `error: boom` for `die`).
  12. `hook_field .tool_input.command` returns the string. A missing path returns empty with status 0. A `null` returns empty.
- **verify:** `bats tests/scripts/hooks-lib.bats` green. `bats tests/scripts/conventions.bats` green (`hooks.sh` now in the lib set). `tests/run-script-tests.sh` green (shellcheck).
- **commit:** `feat(hooks): add shared hook preamble hooks.sh`

---

### D2 — Bash guard `scripts/hooks/guard-bash.sh`

- **files:** `scripts/hooks/guard-bash.sh` (new, `+x`), `tests/scripts/hooks-guard-bash.bats` (new), `tests/scripts/fixtures/hooks/bash-cases.tsv` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. DESIGN §11 (the Bash guard list). Spec AC-17, A11 and A12. Output shape from platform facts 4. A new file is justified because DESIGN §11 names the hook and nothing in the repo parses shell commands.
- **RISKY:** RISKY. It runs on every Bash call in aew projects. A false negative removes protection; a false positive blocks agent work.
- **AC verified:** AC-17, AC-22 (the guard's timing)
- **implementation notes:**
  - The header block documents the rules and the **limits**: it's a heuristic safety net, not a sandbox. It doesn't look inside `bash -c`/`sh -c`, `eval`, `$(…)` or backtick command substitution, aliases, functions or `xargs`. It doesn't parse `sudo` options that take a value (`sudo -u root rm -rf /` is not caught). Branch-dependent rules use the branch at hook time, plus the conservative `git switch`/`git checkout` rule in the flow below. Quoted text containing `;`, `|` or `&&` is split too, and heredoc lines are scanned as commands, so false positives are possible (spec risk "Bash guard bypass", retro "False-positive hooks").
  - Flow:
    1. `hook_init "$@"`.
    2. `cmd=$(hook_field .tool_input.command) || exit 0`; an empty `cmd` → exit 0.
    3. `ecwd` = `HOOK_CWD` canonicalised with `(cd "$HOOK_CWD" 2>/dev/null && pwd -P)`, falling back to `HOOK_ROOT`.
    4. First delete backslash-newline line continuations (`${cmd//$'\\\n'/ }`, so `git push \⏎ --force` is one command). Then split `cmd` into segments: replace `&&`, `||`, `|`, `;` and newline with newline, in that order, using `${…//…/$'\n'}`. **Skip a segment whose token array is empty**, before or after normalisation (blank lines, `&&⏎`, a lone `}`, `> out.log`). An empty array must never reach an unguarded expansion (facts: that exits 0 silently and allows the whole command).
    5. For each segment: `read -r -a`, then normalise the tokens:
       - strip `'` and `"`;
       - strip leading `(`/`{` from the first token and trailing `)`/`}` from any token, then **drop tokens that are now empty** (`( git push -f )`, `{ git push -f; }`);
       - a standalone `&` token **ends the command**: the tokens before it are checked, and the tokens after it are processed as a new segment (`sleep 1 & git push -f`). A trailing `&` just ends the last command;
       - drop redirections, i.e. tokens matching `'>'*`, `'<'*`, `[0-9]'>'*`, `[0-9]'<'*` or `'&>'*` (glob semantics: one digit, not "any digits"). When the token **ends** with `>` or `<` (`>`, `>>`, `2>`, `2>>`, `&>`, `<`), drop the next token too. Without this, `git push origin >/dev/null` on main reads `>/dev/null` as a refspec and is allowed.
    6. Strip leading prefix words: `VAR=value` assignments, `sudo` (and its `-*` flags), `env` (and its `-*` flags and assignments), `command`, `builtin`, `exec`, `nohup`, `time`, `!`, `if`, `then`, `elif`, `else`, `do`, `while` and `until`.
    7. `cd <dir>` updates `ecwd` for the following segments (relative to `ecwd`; no argument means `$HOME`; `cd -` or a missing dir leaves it unchanged).
    8. Dispatch on the basename of the first token (`/usr/bin/git` → `git`).
    9. The first violation prints the deny JSON and exits 0.
  - **Short-option cluster** (used by push, clean and rm): a token matching the glob `-[!-]*` (one dash, then a non-dash). "Contains `f`" is `*f*` on that token. Long options (`--*`) are never clusters, so `--follow-tags` and `--no-verify` don't count as `f`. Don't use the glob `-[a-zA-Z]*f[a-zA-Z]*`, which matches neither `-f` nor `-uf` (facts).
  - **Branch switch in the same command (conservative).** A `git switch` or `git checkout` segment without a `--` argument, whose branch argument (the value of `-c`/`-C`/`-b`/`-B`, or else the first positional) equals the default branch, sets `switched_to_default=1` for the rest of the command. From then on, the push-without-refspec, `HEAD`/`@` and `reset --hard` rules treat the branch as the default whatever `branch_of` says. This catches `git checkout main && git merge feat/x && git push`. It only ever adds blocks. `git checkout main -- f` (a file checkout) doesn't count.
  - Lazy, cached lookups (only when a rule needs them):
    - `default_branch` from `config_get default_branch`. If that fails, `warn` and exit 0 (fail open).
    - `branch_of <dir>` from `git -C <dir> symbolic-ref --short -q HEAD` (empty if detached or not a repo, which counts as "not the default").
    - `toplevel_of <dir>` from `git -C <dir> rev-parse --show-toplevel`, canonicalised with `pwd -P` (empty outside a repo).
  - **git:**
    - Global options: `-C <d>` (cumulative, relative to the previous dir), `-c <kv>`, `--git-dir=`, `--work-tree=`, `--no-pager`, and any other `-*`. The next non-option token is the subcommand.
    - **push.** Options that take a value: `-o`, `--push-option`, `--receive-pack`, `--exec`, `--repo`. `--` ends the options. Then:
      - **Force:** `--force`, `--force-with-lease*`, `--force-if-includes`, a short-option cluster containing `f` (`-f`, `-uf`, `-fu`), or any refspec starting with `+` → deny "force push".
      - **Everything:** `--all` or `--mirror` → deny "push of every branch includes '<default>'".
      - **Positionals:** the first is the remote and the rest are refspecs. For each refspec, the destination is the part after the last `:` (or the whole refspec), with `refs/heads/` stripped. `HEAD` or `@` means `branch_of <git dir>`.
      - A destination equal to the default branch → deny "push to the default branch". This covers `main`, `HEAD:main`, `x:refs/heads/main`, `:main` and `--delete main`.
      - No refspecs, and `branch_of` equals the default → deny.
    - **reset.** Any `--hard` and `branch_of <git dir>` equal to the default → deny "git reset --hard on the default branch".
    - **clean.** Union of the letters in short clusters, plus `f` for `--force`. If it contains `f`, `d` **and** lower-case `x` → deny "git clean -fdx". `-X` is allowed.
  - **gh:** skip `-*` options (`-R`/`--repo` take a value). The first two positionals `pr merge` → deny. `repo delete` → deny.
  - **rm:**
    - Recursive if any short cluster contains `r` or `R`, or `--recursive` is present (`--` ends the options). Not recursive → allow.
    - For each target:
      - if it contains `$` or a backtick → deny "unexpanded variable or command substitution";
      - `~` and `~/…` expand to `$HOME`; `~user` → deny;
      - a trailing `/*` (or a bare `*`) becomes its directory;
      - normalise lexically against `ecwd` (pure bash: split on `/`, a stack for `.` and `..`, collapse `//`), then canonicalise the nearest existing ancestor with `pwd -P` and re-append the rest (macOS `/var` → `/private/var`). If no ancestor exists, use the lexical result.
    - Deny unless the target is **strictly inside** `toplevel_of "$ecwd"` and is not `$HOME`. This covers `/`, system paths, home, the repo root, its ancestors, and anything outside the repo, including when there is no toplevel.
  - Deny JSON, built with one `jq -n --arg r "$reason"`: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}`. The reason reads `aew guard: blocked <rule> in "<segment>". aew never does this; if it is needed, James runs it himself.`
- **test table `fixtures/hooks/bash-cases.tsv`.** Columns are `expect` (`block`/`allow`), `branch` (`main`/`feat`, where `feat` is `feat/x`), `cwd` (relative to `$PROJECT`: `.`, `sub` or `tests`) and `command`. `@PROJECT@` is substituted with the physical project path, and the `command` column is passed through `printf '%b'`, so `\n` is a newline and `\\` a backslash (no other row contains a backslash). There are 82 rows, listed below.
  - **Prompt-mandated blocked (11):**
    - `git push origin main` (feat)
    - `git push` (main)
    - `git push -f` (feat)
    - `git push --force-with-lease` (feat)
    - `gh pr merge 3`
    - `gh repo delete`
    - `git reset --hard` (main)
    - `rm -rf /`
    - `rm -rf ~`
    - `rm -rf ..` (cwd `.`)
    - `git clean -fdx`
  - **Prompt-mandated allowed (6):**
    - `git push origin feat/x` (feat)
    - `rm -rf node_modules`
    - `rm -rf tests/tmp`
    - `npm test`
    - `git reset --hard` (feat)
    - `gh issue view 3`
  - **Spec-mandated blocked:**
    - compound commands: `cd sub && git push origin main`, `npm test && git push -f`
    - `-C`: `git -C .. push` (cwd `sub`, main)
    - `+refspec` and destination refspecs: `git push origin +feat/x`, `git push origin HEAD:main`, `git push origin feat/x:refs/heads/main`
    - `sudo rm -r /etc`
    - separated and reordered flags: `git clean -xdf`, `git clean -f -d -x`, `rm -r -f /`
  - **Further blocked:**
    - `git push -uf origin feat/x`
    - `git push --force origin feat/x`
    - `git push --force-with-lease=feat/x origin feat/x`
    - `git push origin --delete main`
    - `git push origin :main`
    - `git push origin HEAD` (main)
    - `git push --all`
    - `git push 2>&1` (main; the redirection is stripped)
    - `FOO=1 git push -f`
    - `env GIT_TRACE=1 git push origin main`
    - `/usr/bin/git push origin main`
    - `(git push -f)`
    - `if true; then git push -f; fi`
    - `git push -f &`
    - `rm -rf "$HOME"`
    - `rm -rf $TMPDIR/x`
    - `rm -rf ./*` (cwd `.`)
    - `rm -rf /tmp/build`
    - `rm -rf @PROJECT@`
    - `rm -rf ../..` (cwd `sub`)
    - `rm --recursive --force /`
    - `git reset --hard origin/main` (main)
    - `gh pr merge 3 --squash --auto`
    - `gh repo delete acme/widgets --yes`
    - `git push origin 'main'`
  - **Parser edge cases, added at architect review (blocked, 9):**
    - `sleep 1 & git push -f` (feat; `&` separates commands)
    - `( git push -f )` (standalone `(`/`)` tokens)
    - `{ git push -f; }`
    - `> out.log && git push -f` (a segment that is empty after normalisation)
    - `git status &&\ngit push -f` (feat; a blank segment from `&&` plus a newline)
    - `git push \\\n  --force` (feat; line continuation)
    - `git push origin >/dev/null 2>&1` (main; the redirection is not a refspec)
    - `git checkout main && git push` (feat)
    - `git switch main && git reset --hard origin/main` (feat)
  - **Parser edge cases, added at architect review (allowed, 2):**
    - `git checkout feat/x && git push` (feat)
    - `git checkout main -- README.md && git push` (feat; a file checkout)
  - **Further allowed:**
    - `git push` (feat)
    - `git push -u origin feat/x`
    - `git push origin HEAD` (feat)
    - `git push origin feature-main` (main)
    - `git push --follow-tags origin feat/x`
    - `rm -rf dist/*`
    - `cd tests && rm -rf tmp`
    - `rm -rf ./node_modules`
    - `rm -f /tmp/x` (not recursive)
    - `rm file.txt`
    - `git reset --soft HEAD~1` (main)
    - `git clean -fd`
    - `git clean -fdX`
    - `git commit -m "main"`
    - `echo "git push -f"`
    - `gh pr view 3`
    - `gh pr create --fill`
    - `git status`
    - `ls -la`
- **test scenarios (`hooks-guard-bash.bats`).** RED first: every test fails because `guard-bash.sh` is missing. Record that output.
  1. **Table.** `setup_project`, then `mkdir -p sub tests/tmp node_modules dist`, then `git branch feat/x`. For each row: `git switch -q <branch>`, build the payload from `pretooluse-bash.json` with `.tool_input.command` and `.cwd` overridden, then `run_hook guard-bash.sh "$payload"`. Every run must exit 0. Stdout must be either empty (allow) or JSON with `.hookSpecificOutput.permissionDecision == "deny"`, `hookEventName == "PreToolUse"` and a non-empty `permissionDecisionReason` (block). Collect every mismatch as `expect/branch/cwd/command/got`, and fail once listing them all.
  2. **Table integrity.** The table has at least 20 rows. All 17 prompt-mandated rows are present with the expected outcome, matched exactly by `command` and `expect`, so the table can't erode silently.
  3. The deny reason names the rule: `git push -f` → `force push`; `git push origin main` → `default branch`; `rm -rf /` → `rm`.
  4. A custom default branch: `write_config` with `default_branch: "trunk"`, then `git switch -c trunk`. `git push origin trunk` is blocked and `git push origin main` is allowed.
  5. A linked worktree (`git worktree add ../wt feat/x`, payload `cwd` = `wt`): `rm -rf node_modules` inside `wt` is allowed (the toplevel is `wt`), `rm -rf ../project` is blocked, and `git push` is allowed (the branch is `feat/x`).
  6. Timing: write the worst-case payload (`cd sub && git push origin HEAD && git reset --hard && rm -rf ../tests/tmp`, on feat) to a file, then `elapsed_ms bash -c '"$0" < "$1"' "$SCRIPTS/hooks/guard-bash.sh" "$f"` < 1000.
- **verify:** `bats tests/scripts/hooks-guard-bash.bats` green. `bats tests/scripts/conventions.bats` green (`--help`, bad option, lint). `tests/run-script-tests.sh` green.
- **commit:** `feat(hooks): add PreToolUse Bash guard with an 82-case table`

---

### D3 — Edit/Write guard `scripts/hooks/guard-edit.sh`

- **files:** `scripts/hooks/guard-edit.sh` (new, `+x`), `tests/scripts/hooks-guard-edit.bats` (new), `tests/scripts/fixtures/hooks/edit-cases.tsv` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. The deny JSON from D2 (the same one-line `jq -n` written inline; the CTO cut keeps `hooks.sh` to the preamble). DESIGN §11. Spec AC-18 and A13. Platform facts 4: `file_path` is always absolute.
- **RISKY:** RISKY. It runs on every Edit/Write in aew projects.
- **AC verified:** AC-18, AC-22 (timing)
- **implementation notes:**
  - Flow:
    1. `hook_init "$@"`.
    2. `p=$(hook_field .tool_input.file_path) || exit 0`; empty → exit 0.
    3. A relative path is prefixed with `HOOK_CWD/` (defensive).
    4. `shopt -s nocasematch`.
    5. `.git` component: `case "/$p/" in */.git/*)` → deny. This covers `.git/config`, `.git/hooks/x` and a worktree's `.git` file, but not `.gitignore` or `.github/`.
    6. Basename `b=${p##*/}`. Allowed first: `.env.example`, `.env.sample`, `.env.template`. Then denied: `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `.netrc`, `.npmrc`, `.pgpass` and `auth.json`.
  - Reason: `aew guard: blocked a write to <path> (<rule>). Secrets and git internals are never edited by aew; ask James.`
- **test table `edit-cases.tsv`** (`expect`, `path relative to $PROJECT`). These are written as absolute paths in the payload.
  - **Blocked:** `.env`, `.env.local`, `.git/config`, `.git/hooks/pre-commit`, `config/.env.production`, `.ENV`, `certs/server.pem`, `tls.key`, `id_rsa`, `id_ed25519.pub`, `.netrc`, `.npmrc`, `.pgpass`, `auth.json`, `sub/.git`.
  - **Allowed:** `.env.example`, `.env.sample`, `.env.template`, `.gitignore`, `.github/workflows/ci.yml`, `src/env.ts`, `README.md`, `docs/keys.md`, `environment.md`, `src/.envrc-notes.md`.
- **test scenarios (`hooks-guard-edit.bats`).** RED first: every test fails because the script is missing.
  1. Table loop (as in D2), with both `tool_name: "Edit"` and `tool_name: "Write"` payloads. All rows match, and all exit 0. AC-18's four named paths (`.env`, `.env.local`, `.git/config` blocked; `.env.example` allowed) are asserted present.
  2. The deny JSON shape is the same as D2's. The reason contains the path.
  3. A missing `tool_input.file_path` → allow, exit 0.
  4. Timing on a blocked path is under 1000 ms.
- **verify:** `bats tests/scripts/hooks-guard-edit.bats` green. Conventions and `run-script-tests.sh` green.
- **commit:** `feat(hooks): add PreToolUse Edit/Write guard for secrets and .git`

---

### D4 — Subagent gate `scripts/hooks/gate-subagent.sh`

- **files:** `scripts/hooks/gate-subagent.sh` (new, `+x`), `tests/scripts/hooks-gate-subagent.bats` (new), `tests/scripts/fixtures/hooks/dev-report-ok.md`, `dev-report-blocked.md`, `dev-report-no-commands.md`, `qa-test-plan-ok.md`, `qa-report-ok.md` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. DESIGN §7.1 (file names), §7.5 (the return block) and §11. Spec AC-19, AC-20, A8, A14 and A15. `templates/artefacts/dev-report.md`, `qa-test-plan.md` and `qa-report.md` are what the gate parses. The tests also run the **real templates**, so template drift is caught. Block shape from platform facts 5. Reads state directly (`jq … "$(run_dir)/state.json"`), per the A contract. Only `state.sh` writes it.
- **RISKY:** RISKY. A wrong block traps the developer or QA in a loop; a wrong allow removes the gate.
- **AC verified:** AC-19, AC-20, AC-22 (gate timing and `stop_hook_active` through the preamble)
- **implementation notes:**
  - Flow:
    1. `hook_init "$@"`. `stop_hook_active: true` has already exited 0 there (A8: exactly one corrective block).
    2. `agent=$(hook_field .agent_type) || exit 0`. Case `aew:developer` → `gate_developer`; `aew:qa-engineer` → `gate_qa`; anything else → exit 0 silently.
    3. Both gates: `[ -f .aew/runs/current ]`, else `warn "no current aew run; not gating"` and exit 0. Then `rd=$(run_dir) || exit 0`. The explicit `exit 0` means the trap sees status 0 and adds nothing; `run_dir`'s own `error:` line, for example `invalid run id`, is the stderr message. `[ -f "$rd/state.json" ]`, else warn "state file missing" and exit 0. Then **one** jq call, captured first: `st=$(jq -r '[.stage, (.fix_cycle|tostring)]|@tsv' "$rd/state.json" 2>/dev/null) || { warn "unreadable state file; not gating"; exit 0; }`, then `IFS=$'\t' read -r stage fix_cycle <<<"$st"`. Don't put the jq call inside the here-string, where its failure is invisible (facts). An empty `stage` → the same warning, exit 0.
  - `valid_return_block <file>`. `awk` collects the non-blank lines (with `\r` stripped) and prints the last four. Bash then checks them in order:
    - `^STATUS:[[:space:]]*(ok|needs_input|blocked|failed)[[:space:]]*$`;
    - `^ARTEFACTS:[[:space:]]*[^[:space:]]`;
    - `^SUMMARY:[[:space:]]*[^[:space:]]`;
    - `^NEXT:[[:space:]]*[^[:space:]]`.
    The regexes live in variables for bash 3.2's `[[ =~ ]]`. On failure it prints a one-line reason (`last 4 non-blank lines are not STATUS/ARTEFACTS/SUMMARY/NEXT`, or `STATUS must be one of ok, needs_input, blocked, failed`) and returns 1. On success it prints the status value. The template placeholder `STATUS: ok | needs_input | …` fails the STATUS regex.
  - `gate_developer`:
    1. Find the newest of `"$rd"/06-dev-report*.md` with a pure-bash `-nt` loop (no `ls`). None → block "no 06-dev-report*.md".
    2. `[ "$rd/state.json" -nt "$newest" ]` → block "<file> predates the current run state (an earlier cycle); write this cycle's report".
    3. `valid_return_block` fails → block with its reason.
    4. Status `ok` and `commands_filled "$newest"` fails → block "STATUS ok but the ## Commands run table has no filled-in row (command and result)".
  - `commands_filled`: `awk` over the lines after `^## Commands run` up to the next `^## `. Table rows are `^\|`. Skip the header (first cell `Command`) and the separator (`^\|[-: |]+\|$`). A row counts when both trimmed cells are non-empty and neither matches `^<.*>$`. The template rows `| <lint command> | pass |` don't count.
  - `gate_qa`:
    - Stage `plan` or `qa_test_plan` → `04-qa-test-plan.md`.
    - Stage `qa` → `08-qa-report-$((fix_cycle + 1)).md`.
    - Any other stage → `warn "qa-engineer stopped at stage <stage>; not gating"`, exit 0.
    - Missing → block "<file> is missing". Then `valid_return_block`.
  - Block output, built with one `jq -n --arg r`: `{"decision":"block","reason":$r}`. The reason is prefixed `aew gate:`, names the path relative to the project (`.aew/runs/<id>/…`), and adds `Use the template at <plugin_root>/templates/artefacts/<name>.md and end the file with the return block (STATUS, ARTEFACTS, SUMMARY, NEXT).`
- **test scenarios (`hooks-gate-subagent.bats`).** Setup: `setup_project`, then `seed_run 12`. Payloads come from `subagentstop.json` with `.agent_type` and `.cwd` overridden. Stages are moved with the real `state.sh stage …` and `state.sh bump fix_cycle`. RED first: every test fails because the script is missing.
  - **Developer:**
    1. No report → block. The JSON has `decision == "block"` and `reason` contains `06-dev-report`.
    2. `dev-report-ok.md` copied in after `state.sh stage develop` → allow (empty stdout, exit 0).
    3. The real `templates/artefacts/dev-report.md` copied in → block (the placeholder STATUS).
    4. `dev-report-no-commands.md` (STATUS ok, header-only table) → block naming `Commands run`. A row with only `| <lint command> | pass |` → block.
    5. `dev-report-blocked.md` (STATUS blocked, no rows) → allow (A14).
    6. Stale: the ok report with `touch -t 202001010000` → block naming `earlier cycle`. The same report touched now → allow.
    7. Newest wins: an old invalid `06-dev-report.md` (`touch -t` in the past) plus a fresh valid `06-dev-report-WP2.md` → allow. Swap them → block.
    8. Return-block variants (generated in-test from the ok report):
       - CRLF line endings → allow;
       - trailing blank lines → allow;
       - text after the block → block;
       - `STATUS: done` → block;
       - empty `ARTEFACTS:` → block;
       - lines out of order → block.
    9. A linked worktree: payload `cwd` = `wt` (sub-developer) and `CLAUDE_PROJECT_DIR` unset → the main project's run is used (an ok report → allow; none → block).
  - **QA:**
    10. Stage `plan` and stage `qa_test_plan`, without `04-qa-test-plan.md` → block. With `qa-test-plan-ok.md` → allow. With the real template → block.
    11. Stage `qa` with `fix_cycle` 0: `08-qa-report-1.md` ok → allow. After `bump fix_cycle`, the same file present but `08-qa-report-2.md` missing → block naming `08-qa-report-2.md`.
    12. Stage `develop` → allow, with a stderr warning naming the stage.
  - **Scope and fail-open:**
    13. `agent_type` of `general-purpose`, `developer` (bare) or `other:developer` → allow silently, even with no report.
    14. `stop_hook_active: true` with no report → allow, with the stderr warning (A8).
    15. No `current` → allow with a warning. `current` set but `state.json` deleted → allow with a warning. `state.json` corrupt (`echo x >`) → allow with a warning.
    16. Timing: the developer ok path (every check runs) is under 1000 ms, and so is the QA ok path.
- **verify:** `bats tests/scripts/hooks-gate-subagent.bats` green. Conventions and `run-script-tests.sh` green.
- **commit:** `feat(hooks): add SubagentStop gate for developer and qa-engineer`

---

### D5 — Session-start hint `scripts/hooks/session-start.sh`

- **files:** `scripts/hooks/session-start.sh` (new, `+x`), `tests/scripts/hooks-session-start.bats` (new)
- **depends_on:** [D1]
- **pattern:** The D1 preamble. DESIGN §11 (exact wording). Spec AC-21 and A16. Output shape from platform facts 6.
- **RISKY:** NOT RISKY. It only adds context, and every failure path exits 0 with no output.
- **AC verified:** AC-21, AC-22 (timing)
- **implementation notes:**
  - `hook_init "$@"`. No `.aew/runs/current` → exit 0 **silently** (the normal case). `rd=$(run_dir) || exit 0` (`run_dir`'s own `error:` line is the message; the trap sees status 0). No `state.json` → `warn`, exit 0.
  - One jq call reads `[.run_id, .stage, .status]|@tsv`, captured with `x=$(jq …) || { warn …; exit 0; }` before any `read <<<"$x"`. Status `done` → exit 0 with no output.
  - Otherwise, one `jq -n --arg c "Active aew run $id at stage $stage ($status). Use /aew:resume."` produces `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$c}}`.
  - It doesn't read `source`, because it fires for every source (A5).
- **test scenarios (`hooks-session-start.bats`).** RED first: the script is missing.
  1. `seed_run 12`, then `state.sh stage develop` → stdout JSON has `hookEventName == "SessionStart"` and `additionalContext == "Active aew run 12 at stage develop (running). Use /aew:resume."`.
  2. `state.sh status blocked` → `(blocked)`. `failed` → still shown (A16).
  3. `state.sh status done` → empty stdout, exit 0.
  4. No current run → empty stdout **and** empty stderr. `current` pointing at a missing `state.json` → empty stdout, warning on stderr.
  5. It works for every `source` value (`startup`, `resume`, `clear`, `compact`, `fork`).
  6. An `m-3` run id shows as `m-3`.
  7. Timing is under 1000 ms.
- **verify:** `bats tests/scripts/hooks-session-start.bats` green. Conventions and `run-script-tests.sh` green.
- **commit:** `feat(hooks): add SessionStart active-run hint`

---

### D6 — Wire `hooks/hooks.json`, plus the cross-hook fail-open suite

- **files:** `hooks/hooks.json` (new), `tests/scripts/hooks-json.bats` (new)
- **depends_on:** [D2, D3, D4, D5]
- **pattern:** Platform facts 1, 2, 3 and 8 (shape, matcher semantics, anchored regex, explicit timeouts). DESIGN §3 plugin layout (`hooks/hooks.json` at the plugin root). Spec AC-22 and AC-23.
- **RISKY:** RISKY. This is the step that makes the hooks fire in every session.
- **AC verified:** AC-22 (every hook: fail open, `stop_hook_active`, silent outside aew), AC-23
- **implementation notes:** The exact content:
  ```json
  {
    "description": "aew safety guards (Bash, Edit/Write), subagent artefact gates and the active-run hint",
    "hooks": {
      "PreToolUse": [
        { "matcher": "Bash", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/guard-bash.sh\"", "timeout": 5 }] },
        { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/guard-edit.sh\"", "timeout": 5 }] }
      ],
      "SubagentStop": [
        { "matcher": "^aew:(developer|qa-engineer)$", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/gate-subagent.sh\"", "timeout": 5 }] }
      ],
      "SessionStart": [
        { "hooks": [{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh\"", "timeout": 5 }] }
      ]
    }
  }
  ```
  - `Bash` and `Edit|Write` use only exact-match characters. The SubagentStop matcher contains `:`, so it's a regex and is anchored.
  - A 5 s timeout replaces the 600 s default and leaves headroom over the < 1 s budget for a cold first `git`/`jq`.
  - SessionStart has no matcher, so it fires for every `source`.
- **test scenarios (`hooks-json.bats`).** RED first: `hooks/hooks.json` is missing.
  1. Valid JSON. The event keys are exactly `PreToolUse`, `SubagentStop` and `SessionStart`. Every hook has `type: "command"`, an integer `timeout` from 1 to 10, and a `command` that starts with `"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/`.
  2. Each `command`, with `${CLAUDE_PLUGIN_ROOT}` replaced by `$REPO_ROOT` and the quotes removed, is an existing executable. Every `scripts/hooks/*.sh` is referenced exactly once, so there are no orphans and nothing missing.
  3. Matchers:
     - `Bash` and `Edit|Write` match `^[A-Za-z0-9_|, -]+$` (exact semantics).
     - The SubagentStop matcher, under `grep -Eq`, matches `aew:developer` and `aew:qa-engineer`.
     - It doesn't match `developer`, `qa-engineer`, `aew:developer-x`, `xaew:developer` or `other:qa-engineer`.
  4. **Fail-open matrix, looping over every `scripts/hooks/*.sh`** (glob, non-empty) with its event's payload fixture:
     - jq missing (the `nojq` PATH from D1) → exit 0, empty stdout;
     - not a git repo → exit 0, empty stdout, empty stderr;
     - git repo without `.aew/` → exit 0, empty stdout and stderr, even for the dangerous inputs (`git push -f`, `.env`, and no dev report);
     - `.aew/` without config → exit 0, empty stdout, warning on stderr;
     - empty or invalid payload → exit 0, empty stdout, warning;
     - `stop_hook_active: true` → exit 0, empty stdout.
     This also proves the guards are inert outside aew projects (A9).
  5. No hook ever exits 2 across the matrix and the per-hook suites. Each case asserts `status -eq 0`.
  6. `claude plugin validate "$REPO_ROOT"`, skipped when `claude` is not on `PATH`: exit 0, and the output contains no line matching `hooks:` (unknown events and malformed entries surface there only as warnings).
- **verify:** `bats tests/scripts/hooks-json.bats` green. `claude plugin validate .` run manually, with the output recorded in the report. Full `tests/run-script-tests.sh` green.
- **commit:** `feat(hooks): wire hooks.json with anchored matchers and explicit timeouts`

---

### D7 — DESIGN §3/§11 and state-machine corrections

- **files:** `docs/DESIGN.md` (§3 "Blocking hooks" bullet and §11 only), `skills/run-protocol/references/state-machine.md` (the SubagentStop failure-path row only)
- **depends_on:** [D6]
- **pattern:** The platform-facts file, the "Corrections" table above, and DESIGN's own prose style (British English, bullet lists, no new sections). Spec AC-29 (the DESIGN and state-machine part; E owns the CHANGELOG and the final report).
- **RISKY:** NOT RISKY (docs only)
- **AC verified:** AC-23 (documented verification), AC-29 (partial)
- **changes:**
  - **§3 "Blocking hooks" bullet.** Replace it with these sub-bullets:
    - `PreToolUse` denies with `hookSpecificOutput.permissionDecision: "deny"` and `permissionDecisionReason` on exit 0 (top-level `decision`/`reason` are deprecated for `PreToolUse`).
    - `Stop`/`SubagentStop` block with `{"decision":"block","reason":…}` on exit 0. Exit 2 also blocks, but aew never uses it.
    - `stop_hook_active` is true when a stop hook already continued the agent.
    - The documented cap: after 8 consecutive stop-hook continuations, the next block is overridden. The count resets on each tool call, and `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it. It's stated for `Stop`, and the same protections apply to `SubagentStop`.
  - **§3, new bullet "Hook matching and environment":**
    - `SubagentStop` matchers match `agent_type`, which for plugin agents is `aew:<agent>`.
    - A matcher of only letters, digits, `_`, `-`, space, `,` and `|` is an exact list. Anything else is an unanchored regex, so anchor it (`^aew:developer$`).
    - The default timeout is 600 s, so set explicit timeouts.
    - Exit-0 stderr is never shown to Claude (debug log only).
    - `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` are exported. The hook's cwd is not documented, so use the payload `cwd` or `CLAUDE_PROJECT_DIR`.
    - `SessionStart` adds context through `hookSpecificOutput.additionalContext`.
  - **§11:**
    - Name the matchers (`Bash`; `Edit|Write`; one `SubagentStop` entry with `^aew:(developer|qa-engineer)$`; `SessionStart` with no matcher) and the 5 s timeouts.
    - Gates: one corrective block. When `stop_hook_active` is true, the gate allows the stop and the orchestrator's normal return check decides (spec A8).
    - Developer gate: the newest `06-dev-report*.md`, not older than `state.json`; commands and results required when `STATUS: ok`.
    - QA gate: the stage-to-artefact mapping.
    - "All hooks": inert and silent outside an aew project (no `.aew/`). They warn and stay inert when `.aew/` exists without `config.json`. They fail open (exit 0, stderr warning, visible in the debug log) when jq or the state is missing, or on any unexpected error.
    - Add a one-line note that the Bash guard is a heuristic (no `bash -c`/`eval`), with its limits in the script header.
  - **state-machine.md, the SubagentStop failure row**, reworded to:

    > The gate blocks once, and its reason becomes the agent's next instruction. If the agent stops again (`stop_hook_active` true), the gate allows the stop. The return is then checked as usual: a missing or invalid artefact or return block counts as `failed` (retry once, then `blocked`).

    Delete the "eight consecutive blocks" wording from that row.
- **test scenarios:**
  1. `grep` checks:
     - DESIGN §3 contains `permissionDecision` and `aew:<agent>`;
     - §11 contains `^aew:(developer|qa-engineer)$` and `stop_hook_active`;
     - `state-machine.md` no longer contains `eight consecutive blocks`.
     This is a manual verification step recorded in the report (docs aren't bats-tested).
  2. Diff review: only §3's hook bullets, §11 and that single table row change.
- **verify:** `git diff --stat` shows only the two files. British English throughout.
- **commit:** `docs: align DESIGN §3/§11 and the gate failure path with the verified hook docs`

## Phase exit check

- `tests/run-script-tests.sh` exits 0, including shellcheck over `hooks.sh` and the four hooks, A's convention loops over them, and the six `hooks-*.bats` files.
- Every hook measures under 1000 ms in its timing test. No test observes exit 2.
- `claude plugin validate .` exits 0 with no `hooks:` finding.
- Files added: `hooks/hooks.json`, `scripts/lib/hooks.sh`, `scripts/hooks/{guard-bash,guard-edit,gate-subagent,session-start}.sh`, `tests/scripts/hooks-{lib,guard-bash,guard-edit,gate-subagent,session-start,json}.bats`, and `tests/scripts/fixtures/hooks/*`. Edited: `docs/DESIGN.md` (§3 and §11) and `skills/run-protocol/references/state-machine.md` (one row). No A-owned file is touched.

## Requests to Phase A (additive only; none blocking)

- None needed. D relies on the contract as revised. Two points D depends on, which A's tests should keep true:
  - convention 1's "sources `lib/common.sh`" check must accept `../lib/common.sh`, as a substring match;
  - `elapsed_ms` discards stdin, so D times hooks through `bash -c '"$0" < "$1"' <hook> <payload-file>`.

## Notes for `dw-plan` / closing (E)

- CHANGELOG (E) should list:
  - the hooks;
  - the A4 narrowing to `aew:`-prefixed agent types;
  - the `Edit|Write`-only matcher;
  - inert outside aew projects;
  - one corrective block per gate stop.
- The project map's Gotchas (E) should get:
  - bash 3.2 `-nt` is whole-second;
  - the IFS-tab collapse;
  - `claude plugin validate` only warns on unknown hook events;
  - plugin agent types are `aew:<agent>`.
- `CLAUDE.md` lines 70–71 (the hooks summary) are still accurate; no edit is needed.
- Contract for prompt 05 (orchestrator): write state (`state.sh stage develop` or `bump fix_cycle`) **before** each developer dispatch, or the developer gate rejects a reused report as stale. Also, don't write `state.json` while a developer or sub-developer is still running: a write after the report makes that report look stale (whole-second `-nt`).
- Seven commits are planned for D. The prompt asks for one conventional commit, so raise squashing at human review (architect constraint 4).

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:51:00Z (plan-review, full depth)
- Plan format: FULL
- Mechanical fixes applied at review: the facts on the bash 3.2 EXIT trap with `$?`=0, here-string capture and glob semantics; the empty-array and capture rules; D1 test 7's warn prefix; the D2 parser (line continuations, empty segments and tokens, the `&` separator, redirection globs, the short-option cluster definition, the nearest existing ancestor, the conservative branch-switch rule, documented limits); 11 new table rows (71 → 82); D4/D5 state-read capture and the `run_dir` wording; the prompt-05 contract note.
- Plan dependency graph: valid. Wave count: 4 (D1 → {D2, D3, D4, D5} → D6 → D7). Max wave width: 4 tasks in parallel. No file overlap inside wave 2.
- Risk lines crossed: safety-guards (D2, D3, D4, D6), which the epic already flags; the CTO risk gate applies per the phase's `depth: full`.
- Plan content hash (SHA-256): c95048b9b8b01b16c0fb8a81dff4d9e1f4d2363b90845f111557fe5c1a248b23 (hash of the plan before this section was appended)
