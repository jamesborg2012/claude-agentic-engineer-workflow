# Phase C plan — PR, branch, milestone and retro I/O

- **Spec:** `docs/superpowers/specs/2026-10-24-scripts-github-io-and-hooks.md` (hash `12eb8c0d…fa918`)
- **Phase:** C of the EPIC. Depends on A (built on A's "Interface contract"). Runs in parallel with B and D.
- **Depth:** lean (one section per task, no inline code; the implementer writes the code from the contracts named here)
- **ACs covered:** AC-13, AC-14, AC-15, AC-16 (AC-25 and AC-28 are picked up automatically by A's `conventions.bats` globs)
- **Risk:** none. All four tasks are NOT RISKY: new files only, no edits to A-owned files, no schema or template changes, no network in tests (`gh` is the A shim; `git push` goes to a local bare remote).
- **Date:** 2026-10-24

## Shared ground rules for C1–C4 (from A's contract; not repeated per task)

- Each script is `scripts/<name>.sh`, mode `+x`, `#!/usr/bin/env bash`, then a `#` header block starting `Usage:` (the `--help` text, printed via `print_usage`), then `# shellcheck source=lib/common.sh` and `. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`.
- Order inside every script: handle `-h`/`--help` first (no `require_cmd`, git, config or stdin before it), then `require_cmd`, then subcommand dispatch. No arguments → `die "missing subcommand (see --help)"`. Unknown subcommand or option → `die` (exit 1, nothing on stdout). Every positional is validated before any `gh` or `git` call. A bad-input test always asserts **no `gh` call was made** (`gh_call_count` is 0) or the repo is unchanged.
- Machine output goes to stdout only (a PR number, a branch name, one line per retro item, a JSON array). `git` and `gh` chatter goes to stderr (`>&2`). A failing `gh`/`git` call makes the script exit non-zero with the tool's stderr passed through and nothing on stdout.
- bash 3.2: optional `gh` arguments are built in an array and expanded as `${args[@]+"${args[@]}"}`. Text parsing uses jq (Oniguruma regex) or POSIX/BSD `awk` (no gawk extensions such as `IGNORECASE`, `gensub`, `\y`). No `sed -i`, no `grep -P` (both banned by convention 6). Inputs may have CRLF line endings: strip a trailing `\r` before matching.
- Strict-mode caveat (A contract): bash 3.2 does not apply `set -e` inside `$(…)` or inside a function called from `if`/`while`/`!`/`&&`/`||`. Every captured value whose failure matters is checked explicitly (`state=$(jq … "$d/state.json") || die …`, `n=$(parse_pr_number …) || die …`, `root=$(repo_root) || exit 1`), and helper functions use `|| return 1` internally. Never `local x=$(…)` (SC2155): declare, then assign.
- Run state is **read**, never written: `gh-pr.sh` reads `d=$(run_dir "$id") || exit 1`, then `jq … "$d/state.json"` directly (never via `state.sh get`, which only sees the current run) (`state.sh` has no `--run` option, and only the orchestrator writes state). `gh-pr.sh` and `git-branch.sh` print their result; the orchestrator calls `state.sh set` (spec scope-out).
- Every bats file starts with `load helpers/common` and calls `common_setup` in `setup()`. Canned `gh` output goes through `gh_mock_respond <route>`. Asserting what was sent uses `assert_gh_called`, `gh_call_count` and `gh_captured_file`. Fixture files live only in this phase's subdirectories (`tests/scripts/fixtures/{pr,milestone,retro,branch}/`), and tests create small inputs inline with heredocs where that is clearer.
- TDD: write the bats file first, run it, and capture the RED (every test fails on the missing script). Then implement until green. Then run `bats tests/scripts/conventions.bats` (the new script must pass `--help`, bad option, no-arg and the bash 3.2 lint) and the full `tests/run-script-tests.sh` (shellcheck clean).

## Decisions made in this phase (flag if wrong)

1. **`gh-pr.sh create` closing keywords.** A body line already "covers" issue `n` when it matches a GitHub closing keyword (`close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`, case-insensitive) followed by `#n` with a number boundary, so `Closes #123` does not cover `#12`. Placeholder lines `Closes #<issue>` (the `pr-body.md` template's last line) are **removed**. Each uncovered issue gets one `Closes #n` line appended at the end of the body, in `state.issues` order, using the body's existing line ending (CRLF if the body is CRLF, else LF). With the template, the appended lines therefore land under its `## Closes` heading. The input body file is never modified: the normalised body goes to a temp file that is passed to `gh`.
2. **`gh-pr.sh create` needs `state.branch` and a non-empty `state.title`.** It passes `--head <branch> --base <base> --title <title> --body-file <tmp>` explicitly, so it is independent of the current checkout. A null branch or an empty title dies with a hint (`state.sh set branch|title …`). The PR number is parsed from the `…/pull/<n>` URL that `gh pr create` prints. Per the adopted CTO cut, there is no "PR already exists" lookup: a second create fails loudly in `gh`.
3. **`gh-pr.sh update <pr> <body-file> [--run <id>]`.** With `--run <id>` it applies the same closing-line fix as `create` (Decision 1): the placeholder is stripped and a `Closes #n` line is appended for each run issue not already covered. It calls the same internal function as `create` (no duplication), validates the run id and `state.json` first, and never modifies the input file (the fixed body goes to a temp file). Without `--run` it stays a plain `gh pr edit` wrapper. *Note for phase E (github-ops skill):* when the orchestrator re-posts a re-rendered `pr-body.md` via `update`, it should pass `--run <id>`; without it the placeholder `Closes #<issue>` stays in the body.
4. **`gh-milestone.sh` parses issue bodies only, not comments** (DESIGN §10 names body phrases and task lists). Dependency phrases are `blocked by` and `depends on` (case-insensitive, optional `:`), followed by a list of `#n` joined by commas, `and`, `&` or whitespace. Task-list references count only when `#n` is the first token after the checkbox (`- [ ] #7 …`, `* [x] #8`). `- [ ] Fix login (#7)` does not count. References qualified with a repo (`acme/other#3`) and issue URLs are not counted. Native `blockedBy` numbers are merged in. Output is sorted by issue number.
5. **`gh-retro.sh` ensures the retro label best-effort: `gh label create <label> --repo <retro.repo> --color … --description …` (no `--force`); any non-zero exit → `warn` with gh's message and continue.** *(Architect amendment at plan-review; the author's original choice was `--force`.)* This is spec A31's "ignore already exists" without error-string matching. It also does not reset colour/description on a repo aew does not own on every run, and it does not abort filing when the user lacks label permission on the retro repo (the default `retro.repo` is the plugin maintainer's repo, where most users are not collaborators; a label 403 must not block filing). If the label is genuinely missing and could not be created, the later `issue create --label` fails loudly. `gh-labels.sh ensure` (AC-10) keeps `--force` because it owns the project repo's labels; the retro repo is not aew's to rewrite. Every `gh` call in `gh-retro.sh` carries `--repo <retro.repo>`, so retro I/O can never touch the project repo.
6. **`gh-retro.sh` title match** is normalised equality, done in jq: lower-case, then each `[[:punct:]]` character replaced by a space, then whitespace collapsed and trimmed (spec A31). Replacing rather than deleting makes `stale-report` equal `stale report`; checked with jq 1.7 while planning (re-checked at plan-review on jq 1.7.1: `dev gate — Stale REPORT passes!`, `Dev gate: stale report passes` and `  dev   gate: stale-report passes. ` all normalise to `dev gate stale report passes`; the em dash is matched by `[[:punct:]]`). Lower-casing uses `ascii_downcase`, so non-ASCII letters keep their case. If several open issues match, the lowest number wins. An issue created earlier in the same run is added to the in-memory list, so a duplicate heading later in the same `retro.md` comments on it instead of creating a second issue. A re-run after a partial failure can post a second "Seen again" comment on items it already filed. That is accepted (noisy, not lossy).
7. **`git-branch.sh create` creates the branch with `git switch --no-track -c <branch> <base>`.** `--no-track` stops a remote-tracking base such as `origin/main` from becoming the upstream; `push -u` sets the real upstream later. The result is checked with `git check-ref-format --branch`. A pattern that still holds an unresolved `{…}` placeholder after substitution dies (for example `{issue}` in a milestone pattern). Only local branches count as "existing". `push` prints the branch name on stdout after a successful push.

## A-interface requests

None. C uses only the documented contract: `common.sh` (`die`, `info`, `warn`, `require_cmd`, `repo_root`, `config_get`, `is_run_id`, `run_dir`, `print_usage`), the helpers (`setup_project`, `write_config`, `seed_run`, `gh_mock_respond` with call-number sequencing, `gh_calls`, `assert_gh_called`, `refute_gh_called`, `gh_call_count`, `gh_captured_file`, the `assert_*` helpers), `state.sh set` for test setup, and the shim's default "unknown route → exit 0" for `label create`, `issue comment`, `pr edit`, `pr ready` and `pr comment`. One shim property is relied on and worth keeping: the route is `<arg1>-<arg2>`, so scripts must put `--repo` and other flags **after** the subcommand (`gh issue list --repo R …`), never before it.

## Tasks

The four tasks are independent (`depends_on: []`), touch disjoint files, and can run in parallel worktrees.

---

### C1 — `scripts/gh-pr.sh` (create, update, ready, comment)

- **files:** `scripts/gh-pr.sh` (new, `+x`), `tests/scripts/gh-pr.bats` (new), `tests/scripts/fixtures/pr/` (only if a case is clearer as a file than a heredoc; the real `templates/artefacts/pr-body.md` is used directly as the template-body input)
- **depends_on:** []
- **pattern:** A's script conventions and `common.sh` contract. Spec AC-13, A29 as amended by the CTO cut (no existing-PR branch). `templates/artefacts/pr-body.md` (ends with `## Closes` / `Closes #<issue>`). `templates/state.schema.json` (`issues`, `title`, `branch`, `base_branch`). No in-repo analog; a new file is justified because DESIGN deliverable 5 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-13
- **behaviour:** `create <run-id> <body-file> [--base <b>] [--draft]` (options in any order after the positionals; an unknown option dies) validates the run id (`is_run_id`), that the body file exists and is non-empty, and that `$(run_dir <id>)/state.json` exists. It reads `issues`, `title`, `branch` and `base_branch` in one jq call, normalises the closing lines (Decision 1), runs `gh pr create --head … --base <--base or base_branch> --title … --body-file <tmp> [--draft]`, and prints only the PR number. `update <pr> <body-file> [--run <id>]` → `gh pr edit <pr> --body-file <f>`; with `--run <id>` the body first goes through the same closing-line normaliser as `create` (shared internal function; the run id and `state.json` are validated before any `gh` call; the fixed body goes to a temp file, the input is never modified; an unknown option or `--run` without a value dies). `ready <pr>` → `gh pr ready <pr>`. `comment <pr> <file>` → `gh pr comment <pr> --body-file <f>`. `<pr>` must match `^[1-9][0-9]*$`, and the files must exist and be non-empty. These three print nothing on success. Temp files are removed by a `trap` on EXIT.
- **test scenarios (`gh-pr.bats`):** each test uses `setup_project`, `seed_run`, then `state.sh set branch feat/12-add-widget`, with `gh_mock_respond pr-create` serving `https://github.com/acme/widgets/pull/7`.
  1. `create 12 <pr-body.md template>` prints exactly `7`. The call has `--head feat/12-add-widget --base main --title Test run`. The captured body file contains `Closes #12` exactly once and no `#<issue>`. The rest of the template is unchanged (compare it with the template minus the placeholder line). The input file is byte-identical afterwards (`cmp`).
  2. Bulk run (`seed_run m-3 --issues 4,5 --mode bulk`) with a body already containing `Closes #4`: the captured body has `Closes #4` once, then `Closes #5` added once, in that order.
  3. Other keywords and case count as coverage. `fixes #4` and `RESOLVED #5` → nothing added. `Closes #123` does not cover `#12`, so `Closes #12` is added.
  4. Running the normaliser twice is stable. Feed the captured body from test 1 back in as the input: the next captured body is byte-identical.
  5. `--base develop` → the call has `--base develop`. With no `--base`, it uses `state.base_branch` (after `state.sh set base_branch trunk` → `--base trunk`). `--draft` → the call has `--draft`. With no `--draft`, the call does not contain `--draft`.
  6. CRLF body: placeholder detection and coverage still work, and no stray `\r`-only duplicates appear. Appended `Closes` lines use the body's existing line ending: for a CRLF body the appended line ends in `\r\n` (assert with `od`/`grep` on the captured file, and that no bare-LF line was added); for an LF body they end in `\n` only.
  7. `gh` failure (`gh_mock_respond pr-create - 1` with `a pull request for branch … already exists`) → non-zero exit, empty stdout, and gh's message on stderr.
  8. Output with no `/pull/<n>` URL → exit 1 with a clear message.
  9. Refusals, each with exit 1, `error:` on stderr, and `gh_call_count` 0:
     - run id `abc`;
     - a run with no `state.json`;
     - a missing or empty body file;
     - `branch` null (no `state.sh set branch`);
     - an empty title (`state.sh set title ""`);
     - `--base` without a value;
     - `--bogus`;
     - missing positionals.
  9a. `update 7 <rendered pr-body.md with the placeholder> --run 12` posts a body (`gh_captured_file 'pr edit 7'`) that contains `Closes #12` exactly once and no `#<issue>`; the rest of the template is unchanged and the input file is byte-identical (`cmp`). `update 7 f --run abc` and `--run` without a value → exit 1 with no gh call.
  10. `update 7 f` (no `--run`) records `pr edit 7 --body-file …`, and `gh_captured_file 'pr edit 7'` is a byte copy of `f`. `ready 7` records `pr ready 7`. `comment 7 f` records `pr comment 7 --body-file …` with a byte-exact capture. `update abc f`, `ready 0`, `comment 7 <missing>` → exit 1 with no gh call. None of the three prints anything on stdout.
- **verify:** `bats tests/scripts/gh-pr.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add gh-pr.sh for PR create, update, ready and comment`

---

### C2 — `scripts/git-branch.sh` (create, push)

- **files:** `scripts/git-branch.sh` (new, `+x`), `tests/scripts/git-branch.bats` (new). No fixture files are expected (`tests/scripts/fixtures/branch/` stays unused unless needed).
- **depends_on:** []
- **pattern:** A's conventions. `common.sh` (`config_get git.branch_pattern`, `git.milestone_branch_pattern`, `default_branch`; `is_run_id`). Spec AC-16 and A32. DESIGN §6.1 (`git` patterns, placeholders `{issue}`, `{milestone}`, `{slug}`), §9 (preflight updates the base, not this script), §10 (stacked PRs branch from another feature branch via `--base`). No in-repo analog; a new file is justified because DESIGN deliverable 8 names it.
- **RISKY:** NOT RISKY (local git only; the push goes to whatever `origin` is, and tests use a local bare repo)
- **AC verified:** AC-16
- **behaviour:** `create <run-id> <slug> [--base <b>]`:
  - Validates the run id and the slug (`^[a-z0-9]+(-[a-z0-9]+)*$`, refused, not transformed).
  - Picks the pattern: a numeric id uses `git.branch_pattern`, with `{issue}` replaced by the id. `m-N` uses `git.milestone_branch_pattern`, with `{milestone}` replaced by `N`. `{slug}` is replaced in both. Substitution is literal (quoted-pattern `${p//"$pat"/$v}`; verify this under bash 3.2 in the tests).
  - Dies if a `{…}` placeholder survives, and dies on `git check-ref-format --branch` failure.
  - Refuses on a dirty tree (`git status --porcelain` non-empty: modified, staged or untracked; gitignored files don't count).
  - Refuses an existing local branch (`git show-ref --verify --quiet refs/heads/<b>`).
  - Refuses a base that doesn't resolve to a commit (base = `--base`, else `config_get default_branch`).
  - Then runs `git switch --no-track -c <branch> <base>` (output to stderr) and prints the branch name.

  `push` takes no further arguments. It dies on a detached HEAD (`git symbolic-ref --quiet --short HEAD` fails) and when the current branch equals `config_get default_branch`. Otherwise it runs `git push -u origin <branch>` (output to stderr) and prints the branch name.
- **test scenarios (`git-branch.bats`):** real temp repos via `setup_project`. For push tests, `git init --bare "$BATS_TEST_TMPDIR/remote.git"` and `git remote add origin` it. After any `write_config`, commit (`git commit -qam cfg`) so the tree is clean again. All path comparisons use `pwd -P` values.
  1. `create 12 add-widget` prints `feat/12-add-widget`. `git symbolic-ref --short HEAD` equals it, and the new branch's commit equals `main`'s.
  2. `create m-3 sprint-four` prints `feat/m3-sprint-four` (milestone pattern).
  3. Custom patterns from config (`git.branch_pattern: "aew/{slug}-{issue}"`) → `aew/add-widget-12`. A config with no `git` key falls back to the schema defaults.
  4. `--base`: create a branch `feat/3-base` with an extra commit, switch back to `main`, then `create 4 child --base feat/3-base` → the new branch's commit equals `feat/3-base`'s (stacked). `--base nosuch` → exit 1, no branch created. Default base follows `default_branch` (config `trunk` with a `trunk` branch present).
  5. No upstream is set after create, even from a remote-tracking base (`--base origin/main` after a push of main to the bare remote): `git rev-parse --abbrev-ref @{u}` fails.
  6. Dirty-tree refusals, each with exit 1, `error:` on stderr, HEAD unchanged and no new branch: a modified tracked file; a staged new file; an untracked file. A file under the gitignored `.aew/runs/` does **not** block create.
  7. An existing branch (`create 12 add-widget` twice, switching back to `main` between) → the second exits 1, and HEAD stays on `main`.
  8. Bad input, exit 1 with no branch created:
     - slugs `Add-Widget`, `add_widget`, `-x`, `x-`, `a--b`, `""`;
     - run ids `0`, `abc`;
     - a pattern with an unknown placeholder (`feat/{ticket}-{slug}`) → `error:` naming the placeholder;
     - a pattern yielding an invalid ref (`feat/{slug}..x`);
     - `--bogus`; missing positionals.
  9. `push` on `feat/12-add-widget` → exit 0, prints `feat/12-add-widget`. The bare remote has `refs/heads/feat/12-add-widget` at HEAD's commit. `@{u}` is `origin/feat/12-add-widget`.
  10. `push` on `main` → exit 1 with an error naming the default branch, and the bare remote has no refs. With `default_branch: trunk` while on `trunk` → also refused.
  11. `push` on a detached HEAD (`git switch --detach`) → exit 1 with `detached`. `push extra` → exit 1. `push` with no `origin` remote → non-zero with git's error on stderr and nothing on stdout.
- **verify:** `bats tests/scripts/git-branch.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add git-branch.sh for run branch create and push`

---

### C3 — `scripts/gh-milestone.sh` (issues)

- **files:** `scripts/gh-milestone.sh` (new, `+x`), `tests/scripts/gh-milestone.bats` (new), `tests/scripts/fixtures/milestone/issues.json` (new: a canned `gh issue list` response, one issue per pattern), `tests/scripts/fixtures/milestone/expected.json` (new: the full expected output)
- **depends_on:** []
- **pattern:** A's conventions. Spec AC-14 and A30. DESIGN §10 (the dependency phrases; ordering and cycle detection are prompt 06, out of scope). The spec's "Key facts": gh 2.103 `--json` fields `blockedBy` and `labels` (`[{name,…}]`), `state` (`OPEN`/`CLOSED`), and `--milestone` taking a number or a title. No in-repo analog; a new file is justified because DESIGN deliverable 6 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-14
- **behaviour:** `issues <milestone>` (a non-empty string, passed through verbatim, whether a number or a title) runs one `gh issue list --milestone <m> --state all --limit 500 --json number,title,labels,state,body,blockedBy`. It then makes one jq pass that emits `[{number, title, labels: [name…], state, depends_on: [n…]}]`, sorted by `number`. `depends_on` is the `unique` (sorted, de-duplicated) union of three sources, minus the issue's own number (Decision 4):
  - phrase references;
  - task-list references;
  - native `blockedBy` numbers. Accept both an array of `{number,…}` and a `{nodes:[…]}` connection shape. If network and auth are available, confirm the real shape once by hand with `gh issue view <n> -R cli/cli --json blockedBy` (read-only; never in tests), and record the result in the report. If the real entries carry the blocking issue's repository and it differs from the listed repo, drop them (same reason as Decision 4: a bare number from another repo is ambiguous); if they carry no repository field, merge all numbers and note that in the report.

  CRLF bodies are handled. A null body counts as empty. Exactly 500 results → `warn` that the list may be truncated. An empty milestone → `[]`. A gh error → non-zero exit with gh's stderr.
- **test scenarios (`gh-milestone.bats`):** `gh_mock_respond issue-list "$FIXTURES/milestone/issues.json"`. One `@test` per pattern, each asserting the `depends_on` of one fixture issue with `jq -e`:
  1. `Blocked by #3` → `[3]`.
  2. `depends on #3, #4 and #5` (lower case) and `DEPENDS ON: #6 & #7` → `[3,4,5]` and `[6,7]` respectively (case-insensitive, list forms, optional colon).
  3. Task list `- [ ] #8` and `- [x] #9` (plus `* [X] #10`) → `[8,9,10]`. `- [ ] Fix login (#11)` and a prose mention `see #12` → not counted.
  4. Native `blockedBy: [{number: 13}]` → `[13]`. The connection shape `{nodes:[{number:14}]}` → `[14]`.
  5. Union, de-duplication and sorting: an issue with `Blocked by #5`, `- [ ] #3` and native `blockedBy` 5 → `[3,5]`.
  6. A self-reference (issue 20 saying `Depends on #20, #2`) → `[2]`.
  7. CRLF body with `Blocked by #4\r\n` → `[4]`. A null body and no `blockedBy` → `[]`.
  8. `acme/other#3` and `https://github.com/acme/widgets/issues/3` → not counted.
  9. The whole output equals `fixtures/milestone/expected.json` (`jq -S` on both sides). Each element has exactly the keys `number,title,labels,state,depends_on`. `labels` is an array of names. The output is sorted by number.
  10. The call is `issue list --milestone 3 --state all --limit 500 --json number,title,labels,state,body,blockedBy`. `issues "Sprint 4"` passes `--milestone Sprint 4` (with the title verbatim).
  11. An empty response `[]` → prints `[]`, exit 0. A gh failure (`gh_mock_respond issue-list - 1` with `could not find milestone`) → non-zero, empty stdout, message on stderr. A 500-item response (generated in-test with jq) → a `warning:` on stderr and still valid output.
  12. Bad input: `issues` with no milestone, `issues ""`, `bogus 3`, `--bogus` → exit 1 with no gh call.
- **verify:** `bats tests/scripts/gh-milestone.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add gh-milestone.sh issue listing with depends_on parsing`

---

### C4 — `scripts/gh-retro.sh` (file)

- **files:** `scripts/gh-retro.sh` (new, `+x`), `tests/scripts/gh-retro.bats` (new), `tests/scripts/fixtures/retro/retro.md` (new), `tests/scripts/fixtures/retro/open-issues.json` (new: a canned `gh issue list` response)
- **depends_on:** []
- **pattern:** A's conventions and `config_get` (`retro.repo` is required with no default and dies through `config_get`; `retro.label` defaults to `retro`). Spec AC-15 and A31 (Decisions 5 and 6 amend it). `templates/artefacts/retro.md`: items are `###` headings under `##` sections, a `### <short title>` heading is a placeholder, `## Cycles used` holds prose, and there is a leading HTML comment. DESIGN §8.7 and §9 (the orchestrator files retro items; never to the project repo). No in-repo analog; a new file is justified because DESIGN deliverable 7 names it.
- **RISKY:** NOT RISKY
- **AC verified:** AC-15
- **behaviour:** `file <retro.md> <source-repo> <run-id>` validates:
  - that the file exists;
  - `source-repo` against `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`;
  - the run id (`is_run_id`).

  It reads `retro.repo` and `retro.label` (two `config_get` calls; a missing `retro.repo` dies before any `gh` call). It parses items with BSD-safe awk into a temp dir, one title and body per item:
  - a `###` heading starts an item;
  - the body runs until the next `#`/`##`/`###` heading, with leading and trailing blank lines trimmed;
  - headings inside fenced code blocks are ignored;
  - `\r` is stripped;
  - titles matching `^<.*>$`, or empty, are skipped.

  No items → `info` and exit 0 with no `gh` calls. Otherwise it:
  1. Ensures the label (Decision 5).
  2. Fetches the open issues once with `gh issue list --repo R --label L --state open --limit 500 --json number,title`.
  3. For each item, in file order:
     - **Match:** `gh issue comment <n> --repo R --body-file <tmp>`, where the body is `Seen again in <source-repo> run <run-id>`, a blank line, then the item body. Prints `commented #n`.
     - **No match:** `gh issue create --repo R --title <title> --label L --body-file <tmp>`, where the body is the item body plus a trailing provenance line `Filed by aew from <source-repo> run <run-id>.` It parses `#n` from the `/issues/<n>` URL and prints `created #n`.

  Normalisation and same-file duplicates follow Decision 6. A gh failure on any item stops with non-zero, and the lines already printed stand.
- **test scenarios (`gh-retro.bats`):** `setup_project` (the example config has `retro.repo jamesborg2012/claude-agentic-engineer-workflow` and label `retro`). `gh_mock_respond issue-list "$FIXTURES/retro/open-issues.json"` holds `{41, "Dev gate: stale report passes"}` and `{42, "Other thing"}`. `issue-create` responses are sequenced per call (`gh_mock_respond issue-create - 0 1` → `…/issues/50`, `… 0 2` → `…/issues/51`). The fixture `retro.md` has:
  - the template's leading comment;
  - a `### <short title>` placeholder;
  - `### dev gate — Stale REPORT passes!` (which must match #41);
  - `### Flaky QA screenshot` (new);
  - a fenced block containing `### not an item`;
  - prose under `## Cycles used`;
  - a second `### flaky qa screenshot` (a same-file duplicate).
  1. Output is exactly three lines, in order: `commented #41`, `created #50`, `commented #50`. There is exactly one `issue create` call and no call for the placeholder or the fenced heading.
  2. Comment body (`gh_captured_file 'issue comment 41'`): its first line is `Seen again in acme/widgets run 12`, then a blank line, then the item body verbatim, with no heading line and no trailing blank lines.
  3. Create call: the calls.log line contains `--title Flaky QA screenshot` and `--label retro`. The captured body holds the item body and the provenance line.
  4. **Every** calls.log line contains `--repo jamesborg2012/claude-agentic-engineer-workflow` (retro I/O never targets the project repo). The label call is `label create retro --repo …` (with `--color` and `--description`, without `--force`) and comes before `issue list`. `issue list` has `--label retro --state open`.
  4a. Label ensure is best-effort: `gh_mock_respond label-create - 1` with `label with name "retro" already exists` (and separately with `HTTP 403`) → a `warning:` on stderr, and stdout and the remaining calls are the same as test 1.
  5. Normalisation table, one in-test case each against `{41, "Dev gate: stale report passes"}`:
     - `DEV GATE STALE REPORT PASSES` → match;
     - `  dev   gate: stale-report passes. ` → match;
     - `dev gate stale report` → **no** match (equality, not prefix).
  6. Lowest number wins when two open issues normalise equal.
  7. A custom label in config (`retro.label: "aew-retro"`, committed) → used in the label, list and create calls. A config with `retro` holding only `repo` → label `retro`.
  8. Config without `retro.repo` (`write_config` with the key removed) → exit 1 with `no value or default for 'retro.repo'` and `gh_call_count` 0.
  9. A retro with only placeholders, or the bare `templates/artefacts/retro.md` → exit 0, empty stdout, no gh calls.
  10. CRLF `retro.md` → same results as test 1. The captured bodies contain no `\r`.
  11. A gh failure on create (`gh_mock_respond issue-create - 1`) → non-zero exit, and `commented #41` was already printed before the failure.
  12. Bad input, exit 1 with no gh call: a missing file; source repo `widgets` (no owner); run id `abc`; missing positionals; `bogus`; `--bogus`.
- **verify:** `bats tests/scripts/gh-retro.bats` green. `bats tests/scripts/conventions.bats` green. `tests/run-script-tests.sh` green.
- **commit:** `feat(scripts): add gh-retro.sh to file retro items to the retro repo`

---

## Phase exit check

- `tests/run-script-tests.sh` exits 0, with shellcheck clean on the four new scripts and `conventions.bats` covering them (`--help`, bad option, no arguments, bash 3.2 lint).
- `git diff --stat` against A's tip touches only `scripts/{gh-pr,git-branch,gh-milestone,gh-retro}.sh`, `tests/scripts/{gh-pr,git-branch,gh-milestone,gh-retro}.bats` and `tests/scripts/fixtures/{pr,milestone,retro,branch}/`. No A-, B- or D-owned file is changed.
- Four commits are planned (one per task). The prompt asks for one conventional commit overall, so squashing is raised at human review (architect constraint 4) and not done autonomously.

## Notes for phase E (github-ops skill) and closing

- Example invocations to document: `gh-pr.sh create <run-id> .aew/runs/<id>/pr-body.md [--draft]` → PR number → `state.sh set pr <n>`. `git-branch.sh create <run-id> <slug> [--base <parent-branch>]` → branch → `state.sh set branch <b>`. `git-branch.sh push`. `gh-milestone.sh issues <m>` (ordering and cycles are the orchestrator's job, prompt 06). `gh-retro.sh file .aew/runs/<id>/retro.md <owner/repo> <run-id>`.
- `gh-pr.sh update <pr> <body-file> --run <id>` for re-rendered bodies (Decision 3); plain `update` leaves the placeholder.
- The orchestrator must check `state.pr` before calling `create` (the CTO cut). A second create fails in `gh`.
- List the CTO cut as a deviation from AC-13 in the final report ("If a PR already exists … updates that PR's body" is not implemented), and the Decision 5 amendment as a deviation from A31's wording.
- Retro filing by a non-collaborator: `gh issue create --label` on a repo where the user lacks triage rights may drop the label or fail. Untestable offline; document it in the github-ops skill as a known limitation.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T10:38:30Z (plan-review, lean)
- Plan format: LEAN
- Risk lines crossed: none
- Plan dependency graph: valid. Wave count: 1. Max wave width: 4 tasks parallel (C1–C4, disjoint files).
- Architect amendments applied: strict-mode and `grep -P` ground rules (A contract update); `run_dir "$id"` read made explicit; Decision 5 changed from `--force` to best-effort create (warn and continue) plus test 4a; cross-repo `blockedBy` handling; normalisation re-check note; closing-report deviations.
- Plan content hash (SHA-256): bc0ec1f4885f41f4214b28f98019d85539db6b35d1a80c36d38097e049584eac (hash of the plan before this section was appended)
- Micro-revision on 2026-10-24T10:39:12Z: C1 update --run closing-line fix (senior MINOR adopted by orchestrator)
