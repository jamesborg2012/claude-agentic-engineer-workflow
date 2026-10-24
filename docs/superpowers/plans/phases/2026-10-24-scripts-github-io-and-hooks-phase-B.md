# Phase B plan — Issue body and labels

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** B of the EPIC. Phase-level dependency: A (built on A's "Interface contract", as revised after senior review). Runs in parallel with C and D.
- **Depth:** full
- **ACs covered:** AC-5 (amended by the CTO simplicity cut, below), AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12. AC-25 and AC-28 are picked up automatically by A's glob-driven `conventions.bats`.
- **Risk:** data-integrity. B2 and B3 rewrite author-owned GitHub issue bodies and are RISKY. B1 and B4 are NOT RISKY.
- **Date:** 2026-10-24

## Purpose

Phase B builds the two scripts the orchestrator uses for issue I/O:

- `scripts/gh-issue.sh`, with the subcommands `fetch`, `comment`, `revise` and `manual-tests`.
- `scripts/gh-labels.sh`, with the subcommands `ensure`, `stage` and `flag`.

The hard part is the issue-body format behind `revise` and `manual-tests`. The "Issue-body format contract" section below is authoritative. It is written so that preserving v1 byte for byte (AC-7) and idempotency (AC-6) both follow from how the format is built, not from careful coding.

## Facts verified while planning (gh 2.103.2, jq 1.7.1)

- **`gh issue view --json` fields** (`gh issue view 1 -R cli/cli --json nosuchfield`): `assignees author blockedBy blocking body closed closedAt closedByPullRequestsReferences comments createdAt id isPinned issueType labels milestone number parent projectCards projectItems reactionGroups state stateReason subIssues subIssuesSummary title updatedAt url`.
- **Shapes** (from a real public issue):
  - `blockedBy`, `blocking` and `subIssues` are **connection objects** `{"nodes": [...], "totalCount": n}`, not arrays.
  - `parent` is `null` or an issue object.
  - `closedByPullRequestsReferences` is an array of `{id, number, url, repository: {name, owner: {login}}}`.
  - `author` is `{id, is_bot, login, name}`, and `milestone` is `null` or an object.
  - Labels are `{id, name, description, color}`.
  - Comments are `{id, author: {login}, authorAssociation, body, createdAt, url, …}`.
  - **Comment bodies written in the web editor use CRLF.**
  - I could not find a public issue with a non-empty `subIssues`, `blockedBy` or `parent`. Renderers must therefore read node fields defensively (`.number`, `.title // ""`, `.state // ""`, `.url // ""`). B1's fixture assumes nodes are shaped like `{number, title, state, url}`.
- `gh label create <name> --color <6-hex, no #> --description <d> --force` updates an existing label. `gh issue edit <n>` accepts `--body-file f` (`-F`), `--add-label a,b` and `--remove-label a,b`. `gh issue comment <n> --body-file f` posts a comment and prints its URL.
- **jq:**
  - `"" | split("\n")` is `[]`, and `"a\n" | split("\n")` is `["a",""]`.
  - `split("\n") | join("\n")` round-trips exactly, keeping every `\r`.
  - `length` on a string counts codepoints (`"é😀" | length` = 2).
  - `halt_error(5)` prints a string to stderr and exits 5.
  - `--rawfile` and `-j` keep the bytes exact, including CRLF.
- **Data-loss traps that every B task must avoid:**
  - `$(…)` strips trailing newlines, so an issue body or file content must **never** pass through command substitution or a shell variable. Bodies always go file → jq → file.
  - `gh … --jq .body` appends a newline. Use `--json body` and extract with `jq -j`.

## How B uses the Phase A contract (as revised)

- Every script starts like this:
  - `#!/usr/bin/env bash`;
  - a `# Usage:` header block (which is the `--help` text);
  - `# shellcheck source=lib/common.sh`;
  - `. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`.

  Then: `-h|--help` → `print_usage "$0"; exit 0`; an unknown `-*` as `$1` → `die`; no arguments → `die "missing subcommand (see --help)"`. Only after that does it call `require_cmd gh jq`.
- **Strict-mode caveat (A, revised).** `set -e` is off inside `$(…)` and inside functions called from `if`, `while`, `!`, `&&` or `||`. Every value capture and every conditionally called function checks failures explicitly: `labels=$(gh issue view …) || die …`, `jq … >"$out" 2>"$err" || …`, `parse_args "$@" || return 1`. Never use `local x=$(…)`; write `local x; x=$(…) || return 1`. Top-level code may rely on errexit.
- No B script needs `repo_root`, `config_get`, `run_dir` or `state.sh`. `fetch` takes the run dir explicitly, and `gh` infers the repository from the cwd. So `--help` and bad-input handling never need git.
- Scripts call `gh <subcommand> …` with the subcommand first, so the shim's routes are `issue-view`, `issue-edit`, `issue-comment` and `label-create`. Failures are injected with `gh_mock_respond <route> - <code> [k]`.
- Body files are passed to `gh` as **existing regular files** in a `mktemp -d` work dir, never as `-`, so the shim captures them (`gh_captured_file`). The work dir is removed by `trap 'rm -rf "$work"' EXIT`, which is set straight after `mktemp -d "${TMPDIR:-/tmp}/aew-gh-issue.XXXXXX"`.
- Tests: `load helpers/common`, `common_setup` in `setup()`, then `gh_mock_issue`, `gh_mock_body`, `gh_mock_labels`, `gh_call_count`, `assert_gh_called`, `refute_gh_called`, `gh_captured_file`, `assert_json` and `run --separate-stderr`. Tests run in `$BATS_TEST_TMPDIR`, which is not a git repo; no B script needs one.
- **A-interface requests: none.** B adds scripts, `scripts/lib/issue-body.jq` (not matched by the `*.sh` globs, so neither the convention checks nor shellcheck touch it) and fixtures under `tests/scripts/fixtures/issue/`. B edits no A-owned file. `fixtures/labels/` stays unused: B4 seeds label state with `gh_mock_issue --labels`.

## Issue-body format contract (authoritative for B2 and B3)

### Markers

Each marker is a whole line. A trailing `\r` is tolerated, and the version numbers are `[1-9][0-9]*`.

| Name | Line regex |
|---|---|
| `SPEC_OPEN` | `^<!-- aew:spec v(N) -->\r?$` |
| `SPEC_CLOSE` | `^<!-- /aew:spec -->\r?$` |
| `MT_OPEN` / `MT_CLOSE` | `^<!-- aew:manual-tests -->\r?$` / `^<!-- /aew:manual-tests -->\r?$` |
| `PREV_OPEN` / `PREV_CLOSE` | `^<!-- aew:spec-prev v(K) -->\r?$` / `^<!-- /aew:spec-prev v(K) -->\r?$` (same K) |
| `ANY_MARKER` | `^<!-- /?aew:[a-z-]+( v[0-9]+)? -->\r?$` |

### Canonical serialisation

Bodies are worked on as `L = body | split("\n")`. The content of a block is **exactly the lines strictly between its two marker lines, joined with `\n`**. That is the inverse of how blocks are written, so recovering the content is byte-exact by construction.

```
spec_block     = "<!-- aew:spec vN -->\n" + S + "\n<!-- /aew:spec -->"
manual_block   = "<!-- aew:manual-tests -->\n" + M + "\n<!-- /aew:manual-tests -->"
prev_block(K)  = "<!-- aew:spec-prev vK -->\n<details>\n<summary>Spec vK" + (K==1 ? " (original)" : "")
                 + "</summary>\n\n" + C_K + "\n\n</details>\n<!-- /aew:spec-prev vK -->"

managed body   = join([spec_block, manual_block?, prev_block(N-1), …, prev_block(1), O?], "\n\n") + "\n"
unmanaged body with a manual block
               = (V == "" ? "" : V + "\n\n") + manual_block + "\n"
```

- `S` is the spec file's bytes, `M` is the manual-tests file's bytes, and `C_K` is spec vK's bytes (with `C_1` = the author's original body).
- `V` is the author's whole body when it has no spec marker.
- `O` is author content found outside aew blocks in a managed body.
- There are no timestamps or other variable text, so the same inputs always give the same bytes.
- The blank line after `</summary>` makes GitHub render the Markdown inside `<details>`.

### Parsing (the inverse of serialisation)

1. **Find the blocks.** Scan `L` once, top to bottom, with two states. *Outside:* a `SPEC_OPEN`, `MT_OPEN` or `PREV_OPEN` line enters a block; any other `ANY_MARKER` line (a close marker, an unknown kind such as `<!-- aew:foo -->`, or a bad version such as `v0`/`v01`) is malformed. *Inside:* the **next** `ANY_MARKER` line must be the matching close (same kind and, for prev, the same `K`); anything else (a nested opener, a mismatched close) is malformed. Reaching the end of `L` while inside a block is malformed. *(Architect clarification at plan-review: this is the original rule stated as a state machine, so every edge case has exactly one outcome.)* The same `ANY_MARKER` predicate is used for the content-file check below, which is what makes pairing unambiguous: no recorded content can ever contain a marker line.
2. **Classify the body.** It is *managed* if it has exactly one spec block; more than one is malformed. All prev blocks must have distinct `K`s, and together they must be exactly `{1 … N-1}` (any order); otherwise the body is malformed. There is at most one manual block; more than one is malformed. A body with no spec block may contain only an optional manual block; any prev block there is malformed.
3. **Read the prev blocks.** Prev payload lines `P = L[open+1 : close]` must look like this; otherwise the body is malformed:
   - `P | length >= 6` (the serialiser always emits at least six lines, because even an empty `C_K` contributes one empty line; without this check a hand-trimmed 4- or 5-line payload would make `P[2]` and `P[-2]` overlap and silently yield `""`);
   - `P[0]` matches `^<details>\r?$`;
   - `P[1]` matches `^<summary>.*</summary>\r?$`;
   - `P[2]` matches `^\r?$`;
   - `P[-2]` matches `^\r?$`;
   - `P[-1]` matches `^</details>\r?$`.

   Then `C_K = P[3:-2] | join("\n")`.
4. **Collect the gaps (managed body).** A gap is a run of lines outside the blocks: before the first block, between blocks, or after the last one. A gap whose lines all match `^\s*$` is a separator and is discarded. Any other gap has its leading and trailing blank lines dropped and becomes one piece of `O`. The pieces keep document order and are joined with `"\n\n"`. So author text anywhere outside the blocks is kept, and moved to the end.
5. **Recover `V` (unmanaged body).**
   - With no blocks at all, `V` is the **whole body, unchanged**.
   - With a manual block at line `o`: if `o == 0`, `V` is `""`. Otherwise, if `L[o-1]` matches `^\r?$`, `V = L[0:o-1] | join("\n")`; if not, `V = L[0:o] | join("\n")`. (The serialiser always puts `""` there; tolerating `"\r"` keeps a CRLF re-saved body from growing a stray `\r` line in `V`, consistent with the "trailing `\r` tolerated" marker rule.)
   - Lines after the manual close marker other than the final `""` (an author appended text) are added to `V` after `"\n\n"`, with blank edge lines trimmed.

### Operations and refusals

Every refusal exits 1 with a clear `error:` message, makes **no `issue edit` call**, and leaves the body unchanged.

**Input checks (both operations):**

- Refuse a content file (spec or manual) that is missing, empty or contains an `ANY_MARKER` line. A marker inside the content would break the round trip.
- Refuse a malformed body, with the message `issue #n body has malformed aew blocks; refusing to edit (fix by hand)`.

**`revise N S`.** Run these checks in order:

1. Refuse `N < 2`.
2. Work out the current version: an unmanaged body is `cur = 1`; a managed body is `cur = N` from its spec marker.
3. Refuse `N < cur` as a regression, and `N > cur + 1` as a gap.
4. If `N == cur`: when `S` is byte-identical to the stored spec, the result is the same body re-serialised (a no-op on a canonical body). When `S` differs, **refuse** with `spec vN already recorded with different content; use version N+1`. This is the conservative choice; see assumption B-A2.
5. If `N == cur + 1`, the current spec moves to the history. On an unmanaged body, `C_1 = V` and `O = ""`. On a managed body, prev blocks become `[(cur, S_cur)] + prevs`. The manual block and `O` are carried over unchanged.

**`manual-tests M`:**

- A managed body gets the manual block set or replaced and is re-serialised.
- An unmanaged body becomes `V` + manual block (the unmanaged form above).

**Both operations:**

- If the new body's `length` (codepoints) exceeds **65,536**, refuse with `new body would be <len> characters (GitHub limit 65536); not editing`. The body is never truncated.
- If the new body is byte-identical to the current one, skip the `gh issue edit` call and print the info line `issue #n body unchanged`.

### Implementation shape (B2 builds it, B3 extends it)

`scripts/lib/issue-body.jq` is one jq program, run as:

```
jq -n -j --slurpfile view "$work/view.json" --rawfile content "$file" \
   --arg op revise|manual --argjson version "$N" --argjson limit 65536 \
   -f "$lib/issue-body.jq" >"$work/new" 2>"$work/err"
```

- The body is `$view[0].body // ""`.
- Refusals use `halt_error(5)` with the message. The script maps exit 5 to `die "$(cat "$work/err")"` (reading a small error file is fine), and maps any other non-zero exit to `die "internal error in issue-body.jq"`.
- `$lib` is `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib`. It is resolved at the top level and checked with `|| die`.
- jq is chosen because it keeps strings exact (including `\r`), and bash 3.2 cannot hold a body safely. Net-new file: no analog exists, and the format logic does not belong in the shell.

## Tasks

`B1 → B2 → B3` run in sequence because all three edit `scripts/gh-issue.sh`. `B4` is independent and can run in parallel with B1.

---

### B1 — `gh-issue.sh` skeleton, `fetch` and `comment`

- **files:**
  - `scripts/gh-issue.sh` (new, `+x`)
  - `tests/scripts/gh-issue.bats` (new)
  - `tests/scripts/fixtures/issue/view-12.json` (new)
  - `tests/scripts/fixtures/issue/body-12.md` (new)
  - `tests/scripts/fixtures/issue/view-minimal.json` (new)
- **depends_on:** []
- **pattern:** `scripts/state.sh` from A4 (the header and Usage block, the `--help` → `die` → `require_cmd` order, and the subcommand `case`). The A contract's `common.sh` functions. DESIGN §7.1 (`issue.json` and `00-issue-original.md` are written by `fetch`). Spec AC-5 as amended and A26 (the current body is written verbatim). New file justified: DESIGN deliverable 3 names it.
- **RISKY:** NOT RISKY (it reads from GitHub and posts a comment; it never edits the issue)
- **AC verified:** AC-5 (amended), AC-9 (the `comment` half), AC-25 and AC-28 (via A's conventions loop)
- **CTO simplicity cut (adopted; AC-5 amended):** there are no per-reference `gh issue view` lookups and no 20-reference cap. Linked issues come from the same single `--json` call. `referenced_issues` is a sorted, de-duplicated array of numbers.
- **implementation notes:**
  - Usage header lists `fetch <n> <run-dir>` and `comment <n> <file>`. B2 and B3 append their lines. The issue number must match `^[1-9][0-9]*$`, otherwise `die "invalid issue number: <x>"`.
  - **`fetch`:**
    1. Validate `<n>` and the run dir. The run dir must be an existing directory (`die "run dir not found: <d>"`); `state.sh init` creates it, and `fetch` never runs `mkdir`.
    2. Make **one** call, captured to a file: `gh issue view "$n" --json number,title,body,state,url,author,comments,labels,milestone,assignees,blockedBy,blocking,parent,subIssues,closedByPullRequestsReferences > "$work/view.json"`, with `|| die "gh issue view #<n> failed"`.
    3. Run one jq program that adds `referenced_issues`:
       - Scan `.body` and every `.comments[].body` for `#n` with the regex `(^|[^A-Za-z0-9_&/#])#([1-9][0-9]*)(?![A-Za-z0-9_])` (this excludes `owner/repo#n`, `&#35;` entities, `abc#1` anchors and, via the trailing lookahead added at plan-review, hex colours such as `#1D76DB`).
       - Also scan for issue URLs whose prefix equals this issue's own `url` with the number removed (`https://github.com/acme/widgets/issues/`). Other repos' URLs and `/pull/` URLs don't match.
       - Convert to numbers, remove the issue's own number, `unique`.
    4. Write `issue.json` (pretty, via `jq .`, fields as gh returns them plus `referenced_issues`) to `$work`, then render `00-issue-original.md` with a second jq call (`-j`, string templates).
    5. `mv -f` both files into the run dir, only after both have been built. A gh or jq failure leaves the run dir untouched.
  - **`00-issue-original.md` layout:**

    ```
    # #<n> <title>
    (blank)
    - **URL:** <url>
    - **State:** <state>
    - **Author:** @<login>
    - **Labels:** <comma-separated names, or "none">
    - **Milestone:** <title> (#<number>), or "none"
    - **Assignees:** @a, @b, or "none"
    (blank)
    ## Body
    (blank)
    <body, byte for byte>
    (one "\n" if the body doesn't end in a newline, then a blank line)
    ## Comments (<count>)
    ```

    - Each comment gets `### @<login> — <createdAt>`, a blank line, the body verbatim, and a blank line. With no comments: `None.`
    - `## Linked issues` has one list line each for `Parent`, `Blocked by`, `Blocking`, `Sub-issues` and `Closed by pull requests`. Items are rendered as `#<number> <title> (<state>)`, joined with `; `, or `none`. Node fields are read defensively, and connections are read through `.nodes // []`.
    - `## Referenced issues` lists `#3, #4, …`, or `none`.
  - **`comment`:**
    - The file must exist and be non-empty (`[ -s ]`), otherwise `die`.
    - Run `gh issue comment "$n" --body-file "$file"`. gh's stdout (the comment URL) passes through, and a non-zero status from gh → `die "gh issue comment #<n> failed"`.
    - The caller's file path is passed straight through (it is an existing file, so the shim captures it).
- **fixtures:**
  - `view-12.json` is the base object for issue 12, in `acme/widgets`:
    - a title, `state` `OPEN`, the URL, and `author` `{login: "octo", …}`;
    - two comments: the first with a **CRLF body written in-fixture as `\r\n` JSON escapes** that mentions `#20`, the second LF, mentioning `#12` (the issue itself) and `other/repo#9`;
    - `milestone` `{number: 2, title: "v1.0"}`, and `assignees` `[{login: "james"}]`;
    - `blockedBy` `{nodes: [{number: 3, title: "Auth", state: "OPEN", url: …}], totalCount: 1}`, and `blocking` `{nodes: [], totalCount: 0}`;
    - `parent` `{number: 1, title: "Epic", state: "OPEN", url: …}`;
    - `subIssues` `{nodes: [{number: 13, …}], totalCount: 1}`;
    - `closedByPullRequestsReferences` `[{number: 6, url: ".../pull/6", repository: {…}}]`.
  - `body-12.md` contains these references:
    - counted: `#3`, the list `#4, #5`, `https://github.com/acme/widgets/issues/7` and the duplicate `#3`;
    - not counted: `https://github.com/other/repo/issues/8`, `https://github.com/acme/widgets/pull/6`, `&#35;99`, `page#10`, the colour `#1D76DB` and `#12` (the issue itself).

    It also has a Markdown heading and a code fence.
  - `view-minimal.json`: no comments, `milestone` null, `assignees` `[]`, empty connections, `parent` null, `closedByPullRequestsReferences` `[]`.
- **test scenarios (`gh-issue.bats`).** Write these first. RED: every test fails with "No such file or directory" on `scripts/gh-issue.sh`. Capture that output.
  1. **fetch, full.** Seed `gh_mock_issue 12 --from view-12.json --body-file body-12.md --labels aew:analysing,bug`, then run `fetch 12 "$d"` (where `$d` is a temporary dir) → exit 0.
     - `issue.json` has every AC-5 key (`number title body state url author comments labels milestone assignees blockedBy blocking parent subIssues closedByPullRequestsReferences referenced_issues`).
     - `jq -j .body issue.json | cmp - body-12.md` succeeds.
     - `.referenced_issues == [3,4,5,7,20]`.
     - The labels are `aew:analysing` and `bug`.
  2. **One gh call (CTO cut).** `gh_call_count` is `1`, and the call line contains `issue view 12 --json` and each of `blockedBy`, `blocking`, `parent`, `subIssues` and `closedByPullRequestsReferences`.
  3. **`00-issue-original.md`:**
     - it starts with `# #12 `;
     - it contains `- **Milestone:** v1.0 (#2)` and `- **Assignees:** @james`;
     - `jq -e -Rs --rawfile b body-12.md 'contains("## Body\n\n" + $b)'` passes, which proves the body is there verbatim;
     - the comments appear in order, and the CRLF comment's `\r` bytes are preserved;
     - `Blocked by: #3 Auth (OPEN)`, `Parent: #1 Epic (OPEN)` and `Sub-issues: #13` are present;
     - `## Referenced issues` lists `#3, #4, #5, #7, #20`.
  4. **fetch, minimal** (`view-minimal.json`, empty body) → `Comments (0)`, `None.`, every linked line `none`, `referenced_issues == []`, `Milestone: none`.
  5. **A body that already has aew markers** (seeded with `--from view-minimal.json --body-file` a body starting `<!-- aew:spec v2 -->…`) is written verbatim (A26). A second fetch overwrites both files.
  6. **fetch refusals**, each with exit 1, `error:` on stderr and the run dir unchanged:
     - the run dir is missing (no gh call);
     - `fetch abc "$d"` and `fetch 0 "$d"` (no gh call);
     - a missing argument;
     - an unseeded issue `fetch 404` (the gh error is propagated, and **no `issue.json` or `00-issue-original.md` exists afterwards**);
     - `gh_mock_respond issue-view - 1` with a message (no files written).
  7. **comment.** With `gh_mock_respond issue-comment - <<<"https://github.com/acme/widgets/issues/12#issuecomment-1"`, `comment 12 "$f"` → exit 0 and stdout is exactly that URL (pass-through). `gh_captured_file 'issue comment 12'` is a byte copy of `$f` (`cmp`). The call line is `issue comment 12 --body-file …`.
  8. **comment refusals** (exit 1, no gh call): an empty file, a missing file, `comment x f`, a missing argument. A failing gh (`gh_mock_respond issue-comment - 1`) → exit 1.
  9. **Dispatch.** `gh-issue.sh nosuch` → exit 1 with `error:`. `--help` lists `fetch` and `comment`.
- **verify:** `bats tests/scripts/gh-issue.bats` passes. `bats tests/scripts/conventions.bats` passes (it now covers `gh-issue.sh`). `tests/run-script-tests.sh` passes, which includes shellcheck.
- **commit:** `feat(scripts): add gh-issue.sh fetch and comment`

---

### B2 — Issue-body format library and `gh-issue.sh revise`

- **files:**
  - `scripts/lib/issue-body.jq` (new)
  - `scripts/gh-issue.sh` (modified: the `revise` subcommand and its Usage line)
  - `tests/scripts/gh-issue-body.bats` (new)
  - these new fixtures under `tests/scripts/fixtures/issue/`: `body-v1.md`, `spec-v2.md`, `spec-v3.md`, `body-v1-stray-marker.md`, `body-v1-manual.md`, `manual-tests.md`, `expected-v2.md`
- **depends_on:** [B1]
- **pattern:** the "Issue-body format contract" above (authoritative). DESIGN §8.1 "Recording" (marker, revised spec on top, earlier versions in collapsed `<details>`, the author's content never deleted). Spec AC-6, AC-7, AC-8 and A24. `templates/artefacts/spec-revision-comment.md` (the wording "Earlier versions are kept below it, collapsed" must stay true). Net-new `issue-body.jq` is justified in the contract section.
- **RISKY:** **RISKY** (data-integrity: it rewrites an author-owned issue body). The senior should review it against the format contract line by line.
- **AC verified:** AC-6, AC-7, AC-8
- **implementation notes:**
  - Usage: `revise <n> <spec-file> <version>`.
  - Validate the arguments before any gh call:
    - `<n>` must be a valid number;
    - `<version>` must match `^(0|[1-9][0-9]*)$` (anything else, including `02`, which `--argjson` would reject as invalid JSON → `die "invalid version: <v>"`), and `N < 2` → `die "version must be >= 2 (v1 is the author's original)"`;
    - the spec file must exist and be non-empty.
  - Then run, at the top level:
    1. `gh issue view "$n" --json body > "$work/view.json"`, with `|| die`.
    2. `jq -j '.body // ""' "$work/view.json" > "$work/old"`.
    3. The jq transform (`op=revise`), producing `$work/new`.
    4. `cmp -s "$work/old" "$work/new"`. If they match: `info "issue #$n body unchanged (spec v$N)"`, exit 0. Otherwise: `gh issue edit "$n" --body-file "$work/new"` (`|| die`), then `info "issue #$n body revised to spec v$N"`.
  - stdout stays empty.
  - **Exit-code capture (strict mode):** run the transform as `rc=0; jq … >"$work/new" 2>"$work/err" || rc=$?`, then branch on `rc` (0 → continue, 5 → refusal, else internal error). A bare `jq …; rc=$?` would abort under errexit at the top level, and inside B3's `rewrite_body` the explicit `|| rc=$?` is required anyway.
  - In `issue-body.jq`, write small `def`s: `markers`, `blocks` (the pairing scan over `L` with indices), `classify`, `prev_content`, `gaps`, `serialise_managed`, `serialise_unmanaged`, and `refuse(msg)` = `msg | halt_error(5)`. Implement **parsing and serialising of the manual block now** (B2's tests need it). B3 only adds `op == "manual"`.
  - **Gotcha:** the content check must run on `$content | split("\n")` per line, so that `ANY_MARKER` (which is line-anchored) catches a marker even in the last line without a newline.
- **fixtures** (all LF in git; the tests build CRLF and no-final-newline variants on the fly, because CRLF in git is unreliable. Build them in this order: first `perl -pe 'chomp if eof'` (drops the final newline), then `perl -pe 's/\n/\r\n/'`. Doing it the other way round leaves a stray `\r` at the end):
  - `body-v1.md`: the tricky original. It contains:
    - an `#` heading, a nested list and a table;
    - a single-line `<!-- author note -->` and a multi-line HTML comment;
    - the author's own `<details><summary>Logs</summary> … </details>` block;
    - a ```` ``` ```` code fence holding `<details>` and `-->` text;
    - non-ASCII text (`café`, `—`, an emoji);
    - a line ending in two spaces (a Markdown line break) and a tab-indented line.
  - `spec-v2.md`, `spec-v3.md`: realistic `spec-final.md` content (headings, ACs, a code fence), different from each other.
  - `body-v1-stray-marker.md`: a v1 body whose code fence contains the line `<!-- /aew:spec -->` (it must be refused).
  - `manual-tests.md`: a filled-in `templates/artefacts/manual-tests.md` (the `## Manual testing required` heading and two `- [ ]` items).
  - `body-v1-manual.md`: the canonical unmanaged form `body-v1.md` + `"\n\n"` + the manual block of `manual-tests.md` + `"\n"`, written by hand to the contract. B3's output is checked against this same file.
  - `expected-v2.md`: the golden canonical body for `body-v1.md` revised with `spec-v2.md`, built by hand from the contract. It pins the on-GitHub format: a change to the format after release would make bodies written by an older plugin version fail to parse, so any change must be deliberate.
- **test-local helpers (in `gh-issue-body.bats`, written from the contract and independent of `issue-body.jq`).** Both read the body file with `jq -Rs` and `split("\n")`, and output with `-j`:
  - `prev_of <body-file> <K>` prints `C_K` (`P[3:-2] | join("\n")`).
  - `spec_of <body-file>` prints the spec block content.
  - `assert_no_line_lost <before-file> <after-file> [--except-manual]` *(added at plan-review; this is what proves AC-7's "no author content is ever lost" beyond the v1 block)*: strips one trailing `\r` from every line of both files, drops blank lines and `ANY_MARKER` lines, and (with `--except-manual`) drops the lines inside the *before* file's manual block. It then asserts that every remaining line of *before* occurs in *after* at least as many times (a multiset check, done in `awk`). It fails with the first missing line. Call it after **every successful edit** in scenarios 1, 3, 6, 7, 8 and 9 below, and in B3's scenarios 1, 3 (with `--except-manual`), 4 and 5.
- **test scenarios (`gh-issue-body.bats`).** Write these first. RED: `revise` → `error: unknown subcommand` (B1's dispatcher), so every test fails. Capture that output.
  1. **v1 → v2 golden.** Seed issue 7 with `body-v1.md` and run `revise 7 spec-v2.md 2` → exit 0.
     - `cmp <(gh_mock_body 7) expected-v2.md` passes, and the first line is `<!-- aew:spec v2 -->`.
     - `spec_of` = `spec-v2.md` and `prev_of 1` = `body-v1.md` (both by `cmp`).
     - There is exactly one `issue edit 7 --body-file` call, and its captured file equals the stored body.
     - The summary line is `<summary>Spec v1 (original)</summary>`.
  2. **AC-6, idempotent.** Run `revise 7 spec-v2.md 2` again → exit 0, the body is byte-identical (`cmp` against a copy taken after run 1), `gh_call_count 'issue edit'` is still `1`, and stderr contains `unchanged`.
  3. **AC-7, v3 with a tricky CRLF v1 (headline test).** Seed `body-v1.crlf` (CRLF throughout, **with no final newline**), then run `revise … 2` and `revise … 3` →
     - `spec_of` = `spec-v3.md`;
     - the prev blocks appear in the order v2, then v1 (by line number);
     - `prev_of 2` = `spec-v2.md`;
     - **`prev_of 1` matches `body-v1.crlf` byte for byte (`cmp`)**;
     - the author's `<details>`, the HTML comments, the code fence and the non-ASCII text are all inside the v1 block.

     Running `revise … 3` again leaves the body identical (AC-6 at v3). The same check also passes with the LF fixture.
  4. **AC-8, refusals** (each: exit 1, `error:` naming the reason, `gh_call_count 'issue edit'` is 0, and the body is unchanged by `cmp`):
     - `N` = `1`, `0` and `abc` (no gh call at all);
     - a gap: a v1 body with `revise … 3`;
     - a regression: a v3 body with `revise … 2`;
     - a v2 body with `revise … 2` and **different** content (B-A2);
     - a missing, empty or marker-bearing spec file (a spec file containing `<!-- aew:spec-prev v1 -->`);
     - a stray marker: `body-v1-stray-marker.md`;
     - malformed managed bodies, built in-test from `expected-v2.md`: the `<!-- /aew:spec -->` line deleted; a second spec block; prev `v1` relabelled `v3` (**both** its open and close lines, so the pairing is well-formed and the `{1 … N-1}` set rule is what refuses it); a prev close whose `K` differs from its open; the `</details>` line removed from a prev block; a prev payload trimmed to five lines; a spec marker nested inside the prev block; an unknown-kind line `<!-- aew:foo -->` between blocks; the spec marker changed to `v0`; a duplicated manual block;
     - marker-bearing spec files in the two edge forms the per-line check must catch: `<!-- /aew:spec -->` as the **last line with no final newline**, and as a CRLF line (`<!-- /aew:spec -->\r`);
     - `gh_mock_respond issue-edit - 1` (the edit fails) → exit 1.
  5. **AC-8, the 65,536 limit, counted in codepoints.**
     - Revise a scratch issue with a one-character spec to measure `B0` = the codepoint length of the result.
     - Build a spec of `65536 - B0 + 1` codepoints, padded with `é` so bytes exceed codepoints → accepted. The stored body's `jq -Rs length` is exactly 65536, and its byte count is larger.
     - One more `é` → refused with `GitHub limit 65536`, and nothing is edited.
  6. **AC-8, manual-tests block preserved.** Seed `body-v1-manual.md` and run `revise 2` →
     - the manual block sits between the spec block and the v1 block, byte-identical to `manual-tests.md`;
     - `prev_of 1` = `body-v1.md` exactly, so the unmanaged `V` recovery is correct and the separator was not absorbed.

     `revise 3` keeps the manual block.

     **Author text after the manual block (step 5, last rule).** Seed `body-v1-manual.md` with `\nAuthor PS\n` appended, then `revise 2` → `prev_of 1` is exactly `body-v1.md` + `"\n\nAuthor PS"`, the manual block is still byte-identical to `manual-tests.md`, and a second `revise 2` changes nothing.
  7. **AC-8, content outside aew blocks is kept.**
     - Take the v2 body, add a line `Author note above` before the spec marker and a paragraph `Author follow-up` at the end, then `revise 3`.
     - Both texts appear exactly once, after the last prev block. `prev_of 1` is still the v1 fixture exactly.
     - A second `revise 3` produces an identical body.
  8. **CRLF re-save tolerance.** Convert the whole v2 body to CRLF, as the web editor would on an author's save, then `revise 3` → exit 0. The markers are still recognised, every v1 line is present in `prev_of 1` (CRLF line endings are accepted), and `prev_of 2` is `spec-v2.md` with `\r` added.
  9. **An empty v1 body** (`""`) with `revise 2` → `prev_of 1` is empty, and running it again changes nothing.
  10. **Dispatch.** `revise` with missing arguments → exit 1. `--help` lists `revise`.
- **verify:**
  - `bats tests/scripts/gh-issue-body.bats` and `bats tests/scripts/gh-issue.bats` pass;
  - `tests/run-script-tests.sh` passes;
  - review step: the diff of `issue-body.jq` against the contract; every refusal path has a test.
- **commit:** `feat(scripts): add gh-issue.sh revise with versioned issue-body blocks`

---

### B3 — `gh-issue.sh manual-tests`

- **files:**
  - `scripts/gh-issue.sh` (modified: the `manual-tests` subcommand and its Usage line)
  - `scripts/lib/issue-body.jq` (modified: `op == "manual"`)
  - `tests/scripts/gh-issue-body.bats` (tests appended)
  - `tests/scripts/fixtures/issue/manual-tests-2.md` (new)
- **depends_on:** [B2]
- **pattern:** B2's `revise` flow (validate → view → transform → `cmp` → edit), reused as is. The only differences are `--arg op manual` and no version argument (pass `--argjson version 0`). The format contract's `manual-tests` rules. Spec AC-9, A24 and A25. `templates/artefacts/manual-tests.md` (the heading inside the block).
- **RISKY:** **RISKY** (data-integrity: it rewrites an author-owned issue body)
- **AC verified:** AC-9 (the `manual-tests` half)
- **implementation notes:**
  - Usage: `manual-tests <n> <file>`. The file must exist, be non-empty and contain no aew marker line.
  - The file content is inserted **verbatim**, including any leading `<!-- Artefact: … -->` template comment, which GitHub doesn't render (B-A4).
  - It never touches labels: setting `aew:manual-test-required` is the orchestrator's separate `gh-labels.sh flag` call.
  - Put the shared view/transform/edit flow in one function, `rewrite_body <n> <op> <file> <version>`, called by both `revise` and `manual-tests`. It must check every step explicitly (`|| return 1`), because callers may run it in a condition. This keeps the edit path in one place instead of two copies.
- **fixture:** `manual-tests-2.md`: a different checklist (three items).
- **test scenarios (appended to `gh-issue-body.bats`).** RED: `manual-tests` → `unknown subcommand`. Capture that output.
  1. **Unmanaged body.** Seed `body-v1.md` and run `manual-tests 7 manual-tests.md` → the body is byte-identical to `body-v1-manual.md` (the same golden B2 consumes). The author's bytes are an exact prefix (`cmp -n <size of body-v1.md>`).
  2. **Idempotent.** Running it again gives an identical body, and `gh_call_count 'issue edit'` stays `1`.
  3. **Replace.** Run `manual-tests 7 manual-tests-2.md` → exactly one `MT_OPEN` line (`grep -c`), the block content = `manual-tests-2.md`, the author's prefix unchanged, and `manual-tests.md`'s items gone.
  4. **Managed body.** From `expected-v2.md` plus a `revise 3`, run `manual-tests` →
     - the block is inserted after the spec block and before the v2 block;
     - `spec_of`, `prev_of 2` and `prev_of 1` are byte-identical to their values before the call (`cmp`);
     - an existing `O` paragraph is kept;
     - replacing the block with `manual-tests-2.md` leaves the spec and history blocks byte-identical.
  5. **End to end with CRLF.** Use a CRLF v1 without a final newline: run `manual-tests`, then `revise 2`, then `revise 3` → `prev_of 1` matches the CRLF v1 byte for byte, and the manual block survives both revisions.
  6. **Refusals** (exit 1, no edit, body unchanged): an empty file, a missing file, a file containing `<!-- /aew:manual-tests -->`, a malformed body (two manual blocks), a body pushed over 65,536 codepoints, and a bad issue number.
  7. **Labels untouched.** After `manual-tests`, `gh_mock_labels` is unchanged, and there is no `--add-label` in `calls.log`.
- **verify:** `bats tests/scripts/gh-issue-body.bats` passes (the B2 tests still pass), and `tests/run-script-tests.sh` passes.
- **commit:** `feat(scripts): add gh-issue.sh manual-tests block`

---

### B4 — `gh-labels.sh ensure`, `stage` and `flag`

- **files:** `scripts/gh-labels.sh` (new, `+x`), `tests/scripts/gh-labels.bats` (new)
- **depends_on:** [] (it can run in parallel with B1)
- **pattern:** `scripts/state.sh` (A4) for the header, `--help` and dispatch. DESIGN §7.4 (the 11 labels). The `skills/run-protocol/SKILL.md` "Labels" table (descriptions). Spec AC-10–12, A27 and A28. New file justified: DESIGN deliverable 4 names it.
- **RISKY:** NOT RISKY (label changes are cosmetic and reversible; it never edits bodies)
- **AC verified:** AC-10, AC-11, AC-12, plus AC-25 and AC-28 via the conventions loop
- **implementation notes:**
  - **One label table.** A function `label_table` prints `kind|name|colour|description` lines from a heredoc (bash 3.2, so no associative arrays). It is the only source for `ensure`, the stage set and the flag set. The table, with cosmetic colours (A28) and descriptions of 100 characters or fewer:

    | kind | name | colour | description |
    |---|---|---|---|
    | stage | aew:analysing | 1D76DB | aew: spec analysis is running |
    | stage | aew:awaiting-input | FBCA04 | aew: waiting for answers to spec questions |
    | stage | aew:planning | 0052CC | aew: brief, standards, test plan and plan in progress |
    | stage | aew:awaiting-approval | E4A11B | aew: plan is waiting for approval |
    | stage | aew:building | 0075CA | aew: development and code review in progress |
    | stage | aew:testing | 006B75 | aew: QA is running |
    | stage | aew:documenting | 5DA9E9 | aew: summary, PR body and retro being written |
    | stage | aew:ready-for-review | 0E8A16 | aew: PR is open and ready for human review |
    | stage | aew:blocked | B60205 | aew: run is blocked and needs a human |
    | flag | aew:spec-revised | 8250DF | aew: the spec on this issue was revised (history kept in the body) |
    | flag | aew:manual-test-required | D93F0B | aew: some tests must be run by hand (see the issue body) |

  - **`norm_label <kind> <arg>`** adds an `aew:` prefix if it is missing, then checks the result against the table for that kind. An unknown name → `die "unknown <kind> label: <arg> (expected one of: …)"`. A flag name passed to `stage`, or a stage name passed to `flag`, is rejected. Validation happens **before** any gh call.
  - **`ensure`** takes no arguments; extra arguments → `die`. For each row, in table order, it runs `gh label create "$name" --color "$colour" --description "$desc" --force`, with the arguments in exactly that order for testability. A failure → `die "gh label create <name> failed"`. This fails fast, and a re-run is safe because `--force` makes the command idempotent. At the end: `info "ensured 11 labels"`.
  - `<n>` (for `stage` and `flag`) is validated with the same `^[1-9][0-9]*$` rule as `gh-issue.sh` (`die "invalid issue number: <x>"`) before any gh call.
  - **`stage <n> <stage>`:**
    1. `labels=$(gh issue view "$n" --json labels --jq '.labels[].name') || die …`.
    2. In bash, `remove` = the current labels that are stage labels other than the target, and `add` = the target if it is absent.
    3. If both are empty: exit 0 (idempotent, no edit call). Otherwise make **one** call: `gh issue edit "$n" [--add-label <target>] [--remove-label <a,b,…>]`, with `|| die`.
    4. Never touch non-stage labels.
    5. Build the argument arrays with the `${arr[@]+"${arr[@]}"}` idiom (A: empty arrays are fatal under `set -u` on bash 3.2).
  - **`flag <n> add|remove <flag>`:** validate the action and the flag, then view the labels the same way, and make **one** `issue edit` call with `--add-label` or `--remove-label` only when that call would change something. A no-op exits 0 without an edit.
  - Labels must exist before `stage` or `flag` adds them. The orchestrator runs `ensure` first, and phase E's github-ops skill documents this. `stage` never creates labels itself.
- **test scenarios (`gh-labels.bats`).** Write these first. RED: missing `scripts/gh-labels.sh`. Capture that output.
  1. **AC-10, ensure.**
     - Exit 0, and `gh_call_count 'label create'` is `11`.
     - The set of created names equals the `aew:[a-z-]+` names extracted from DESIGN §7.4 (`awk` from `### 7.4 Labels` to the next `###` heading in `$REPO_ROOT/docs/DESIGN.md`, then `grep -oE`). This is a drift guard against DESIGN.
     - Every call line matches `label create aew:… --color [0-9A-Fa-f]{6} --description .+ --force`.
     - Each name appears exactly once.
  2. **ensure failure.** `gh_mock_respond label-create - 1 3` → exit 1, stderr names the third label, and there are only 3 `label create` calls. `ensure extra` → exit 1, no gh call.
  3. **AC-11 (headline).** Seed issue 12 with the labels `aew:analysing,aew:planning,aew:spec-revised,enhancement`, then run `stage 12 building` → exit 0. `gh_mock_labels 12` is **exactly** `aew:building`, `aew:spec-revised`, `enhancement`. There is exactly one `issue edit 12` call, which includes both `--add-label aew:building` and `--remove-label`.
  4. `stage 12 aew:building` (with the prefix) gives the same result as the bare name.
  5. **Idempotent.** With only `aew:building` (plus others) present, `stage 12 building` makes no `issue edit` call and leaves the labels unchanged.
  6. **Target present alongside another stage label** → remove only, with no `--add-label` in the call. **No stage label at all** → add only.
  7. **Every one of the 9 stage names** is accepted (a loop over a fresh issue each time; exactly one stage label afterwards).
  8. **AC-12, flag.**
     - `flag 12 add spec-revised` → `aew:spec-revised` added, and the stage label is untouched.
     - `flag 12 add aew:manual-test-required` works.
     - Adding a flag that is already present → no edit call.
     - `flag 12 remove spec-revised` → removed.
     - Removing a flag that is absent → exit 0, no edit call.
  9. **AC-12 rejections** (exit 1, `error:`, **zero gh calls**): `flag 12 add blocked`, `flag 12 add aew:building`, `flag 12 add bug`, `flag 12 add ""`, `flag 12 toggle spec-revised`, and a missing flag argument.
  10. **Stage rejections** (exit 1, zero gh calls): `stage 12 nosuch`, `stage 12 spec-revised` (a flag), `stage x building`, `stage 0 building`, and a missing stage argument.
  11. **gh errors propagate.** An unseeded issue with `stage 404 building` → exit 1 with `error:` and no edit call. `gh_mock_respond issue-edit - 1` → exit 1.
  12. **Dispatch.** `gh-labels.sh nosuch` → exit 1. `--help` lists `ensure`, `stage` and `flag`.
- **verify:** `bats tests/scripts/gh-labels.bats` passes, `bats tests/scripts/conventions.bats` passes, and `tests/run-script-tests.sh` passes.
- **commit:** `feat(scripts): add gh-labels.sh ensure, stage and flag`

---

## Phase B assumptions (beyond the spec; flag if wrong)

- **B-A1:** `revise` and `manual-tests` re-serialise the body into the canonical form. Author text found between or above aew blocks is kept but moved to the end of the body. Nothing is dropped, though its position changes once. This applies to `manual-tests` too, so on a hand-edited managed body AC-9's "author content untouched" holds as "unchanged bytes, possibly relocated". **Flag if wrong**: the alternative is for `manual-tests` to splice its block in place (a second output path in `issue-body.jq`).
- **B-A2:** `revise N` when spec vN is already recorded with **different** content refuses, instead of overwriting the earlier vN draft. The orchestrator must use N+1. This is conservative (it never discards text) and costs nothing on the normal path. **Flag if wrong**: the alternative is to replace vN in place.
- **B-A3:** a body with malformed or stray aew markers is refused, never repaired. James fixes it by hand. This includes an author's code fence that quotes a marker line exactly, which is unlikely.
- **B-A4:** the manual-tests file is inserted verbatim, including any template header comment.
- **B-A5:** the 65,536 limit is counted in codepoints (jq `length`). GitHub's exact counting rule is undocumented; codepoints match its "characters" wording.
- **B-A6:** `fetch` requires the run dir to exist already. It writes both files atomically, overwrites them on re-fetch, and takes all comments from the single `--json comments` call, with no pagination handling. Prompt 07's sandbox e2e checks a long-thread issue.
- **B-A7:** `ensure` fails fast on the first `gh label create` error, because a re-run is idempotent.

## Accepted risks

- **Read-modify-write race.** An author editing the body at the same moment as `revise` could have their edit overwritten. `gh` has no conditional update. Mitigations: the window is a single call, and GitHub keeps the body's edit history. This is noted for the github-ops skill (phase E).
- **Format permanence.** Once released, bodies on GitHub carry this format. `expected-v2.md` and `body-v1-manual.md` pin it, so a format change shows up as a failing golden test.
- **Real-GitHub byte fidelity (added at plan-review).** The mock stores bodies byte for byte. If real GitHub normalised a body we send (for example by dropping the final `\n` or converting line endings), the no-op `cmp` would see a difference and every re-run would make an edit call (content stays correct, but AC-6's "no edit" would not hold in practice). Prompt 07's sandbox e2e must run `revise 2` twice on a real issue and assert the second run reports `unchanged`.

## Phase exit check

- `tests/run-script-tests.sh` exits 0, with shellcheck clean on `gh-issue.sh` and `gh-labels.sh`, and `gh-issue.bats`, `gh-issue-body.bats`, `gh-labels.bats` and `conventions.bats` all passing.
- `git diff --stat` touches only `scripts/gh-issue.sh`, `scripts/gh-labels.sh`, `scripts/lib/issue-body.jq`, the three bats files and `tests/scripts/fixtures/issue/*`. No A-owned file changes.

## Notes for `dw-plan`, phase C and phase E

- **For C (`gh-milestone.sh`):** `blockedBy` is a connection `{nodes: [{number, …}], totalCount}` in `gh issue list` and `gh issue view` JSON, not an array. Read it as `.blockedBy.nodes // [] | map(.number)`.
- **For E (github-ops skill):**
  - `stage` and `flag` need `ensure` to have run.
  - `revise` refuses the same version with different content (bump N instead).
  - Bodies with malformed markers need a human.
  - A 65,536-limit refusal also needs a human (the history grows with each revision, so a long spec revised several times can hit it): set `aew:blocked`, never trim history.
  - Recording order: render the comment → `revise` → `comment` → `flag add spec-revised` → `state.sh set spec_revision`.
  - The project map should get the issue-body format contract summary (the marker set, the canonical layout and the refusal rules).
- Four commits are planned for B. The prompt wants a single commit, so the squash is raised at human review (architect constraint 4).

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:48:40Z (plan-review, full depth)
- Plan format: FULL (phase B of EPIC; risk: data-integrity, B2 and B3 RISKY, so the CTO risk gate applies)
- Plan dependency graph: valid. Wave count: 3 ({B1, B4} → {B2} → {B3}). Max wave width: 2 tasks in parallel. File overlaps (`gh-issue.sh`; `issue-body.jq` and `gh-issue-body.bats`) are serialised by B1 → B2 → B3. No overlap with A-owned files or C/D files.
- Auto-applied at review: state-machine pairing rule (step 1); `length(P) >= 6` prev-payload check; `^\r?$` separator tolerance in unmanaged `V` recovery; version regex `^(0|[1-9][0-9]*)$`; explicit `|| rc=$?` exit-code capture; `#n` trailing lookahead plus a hex-colour fixture case; `assert_no_line_lost` invariant helper wired into every successful-edit scenario; extra malformed-body and marker-edge refusal cases; author-text-after-manual-block case; B1 test 5 seeded `--from view-minimal.json`; comment-URL pass-through assertion; B4 `<n>` validation; B-A1 widened to AC-9 and flagged; phase E note on limit refusals; accepted risk on real-GitHub byte fidelity (prompt 07 e2e).
- Plan content hash (SHA-256): bd80d94ddbe75abdd33663047c538fe97fb3e640e93e8359697982c26c7bf86f (hash before this section was appended)
