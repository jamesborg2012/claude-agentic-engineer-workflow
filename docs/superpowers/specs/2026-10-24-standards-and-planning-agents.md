# Brainstorm — Standards system and planning-side agents (build prompt 03)

- **Issue:** no issue — build prompt 03 (`docs/build-prompts/03-planning-agents.md`; DESIGN.md wins on conflict)
- **Date:** 2026-10-24

## Problem

The plugin now has its deterministic layer (state, git, GitHub I/O, hooks), but nothing that thinks. Every stage before code is written (spec analysis, brief, standards and planning, plus review and triage later on) depends on four agents and on a standards system that can detect a project's stacks, fingerprint them, and produce or reuse per-stack standards docs. These agents set the quality of everything downstream. Their prompts must be precise, opinionated and testable, and they must be proven by headless smoke tests against fixtures.

## Acceptance criteria

Every acceptance criterion from the prompt is kept and marked **[P]**. The rest turn the prompt's deliverables and the DESIGN.md requirements into testable criteria.

**Stack detection (`scripts/detect-stack.sh`)**

1. **AC-1** `detect-stack.sh [path]` (default `.`) prints a JSON array of `{profile, path, version, evidence}` to stdout and exits 0. `path` is relative to the scanned root (`.` for the root itself). `version` is a string (`"unknown"` when nothing declares one). `evidence` is a non-empty array of short strings such as `"package.json: next ^16.0.1"`. The order is deterministic: by path, then base profiles before overlays, then by profile name. A directory with no stacks prints `[]` and exits 0. A missing or unreadable path exits 1 with `error:` on stderr.
2. **AC-2** The detection rules are applied exactly as follows:
   - `next` in `dependencies` or `devDependencies` of a `package.json` → `nextjs`;
   - `react` in a `package.json` that does not declare `next` → `react`;
   - a `tailwindcss` dependency, a `tailwind.config.*` file, or `@import "tailwindcss"` in a CSS file → `tailwind` (overlay);
   - `laravel/framework` in `composer.json` `require` → `laravel`;
   - a `style.css` with a `Theme Name:` header, a PHP file with a `Plugin Name:` header (within the first 8 KB, as WordPress reads it), or `wp-config.php` / `wp-content/` → `wordpress`;
   - a `WC requires at least` or `WC tested up to` header, a `woocommerce` dependency, or `woocommerce_` hooks passed to `add_action`/`add_filter` in a plugin → `woocommerce` (overlay);
   - `*.csproj` or `*.sln` → `dotnet`.
3. **AC-3** Scanning goes to depth 3 (`find -maxdepth 3` semantics, so `apps/web/package.json` is found). It prunes `node_modules`, `vendor`, `.git` and build output (`dist`, `build`, `out`, `.next`, `.turbo`, `coverage`, `bin`, `obj`). In a monorepo it emits one entry per (profile, path). Matches inside a pruned directory created at test time (for example `node_modules/next/package.json`) are not reported.
4. **AC-4** `detect-stack.sh fingerprint <profile> [path]` prints one line: the profile, the major versions it depends on, and a 12-hex-character hash of the relevant tool configs (format in Assumption 6). It is deterministic, and changes when a relevant config file's content or a tracked major version changes, but not when an unrelated file changes. If the profile is not detected at that path it exits 1 with `error:` on stderr.
5. **AC-5 [P]** A bats file (`tests/scripts/detect-stack.bats`) asserts the expected profiles for every stack fixture (AC-14). It also covers depth and pruning, `[]` for an empty directory, the bad-path error, and fingerprint stability and sensitivity.
6. **AC-6 [P]** The script is bash 3.2-compatible, uses `set -euo pipefail` (via `lib/common.sh`), is shellcheck-clean, and supports `--help`. `tests/scripts/conventions.bats` and `tests/run-script-tests.sh` pass with it included (see Assumption 2 on the no-argument rule).

**Standards skill (`skills/stack-standards/`)**

7. **AC-7** `skills/stack-standards/SKILL.md` has the frontmatter `name: stack-standards`, a `description`, and `user-invocable: false`. It must not set `disable-model-invocation`, because that would stop it being preloaded. It covers: how to run detection (`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`); the fingerprint header format; when to reuse, update or generate; how to merge a base profile with overlays; and the source priority from DESIGN §8.3, quoted in order.
8. **AC-8** `references/document-structure.md` lists the required sections of a standards doc in the order of DESIGN §8.3 (fingerprint header, tooling and commands, project structure, naming, language idioms, framework conventions, error handling, security, accessibility, testing conventions, documentation and comment standards, anti-patterns). It defines the **[tool]** and **[convention]** markers, the do/don't example format, the size limit of about 400 lines, and the `docs/standards/README.md` index format.
9. **AC-9 [P]** There are six seeds: `references/seeds/{nextjs,react,laravel,wordpress,woocommerce,tailwind}.md`. Each one states the versions it covers at the top. Each is 300 lines or fewer (`wc -l`) and has concrete do/don't examples, a WCAG 2.2 AA section, a security section, and testing conventions (which framework, how tests are organised and named). Each is researched for the **current** major version with context7 and the official docs, and the sources are listed in the seed.
10. **AC-10 [P]** Seed-specific content:
    - **wordpress:** PHP, JS and CSS per the WordPress Coding Standards; escaping, sanitising and nonces; capabilities; hooks rather than core edits; i18n; enqueueing.
    - **woocommerce:** CRUD objects and data stores rather than direct post meta; the HPOS compatibility declaration; hooks rather than template overrides; extension conventions.
    - **tailwind:** the current major's configuration approach, design tokens, and avoiding class soup (rules for extracting components).
    - **nextjs:** includes React and TypeScript (DESIGN §8.3).
    - No C# seed (DESIGN §8.3, §13).

**Agents (`agents/*.md`)**

11. **AC-11** Each of the four agents is a complete system prompt. It covers role, inputs (explicit paths in the run dir, plus the dispatch fields it expects from the orchestrator), a step-by-step process, outputs (each one starting from its template at `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/…`), the return contract (DESIGN §7.5), guardrails, autonomy rules, and what "done" means (DESIGN §12). Its frontmatter follows DESIGN §5.3, with these values:

    | Agent | model | effort | memory | skills | tools (minimum) |
    |---|---|---|---|---|---|
    | spec-analyser | opus | high | project | aew:run-protocol | Read, Grep, Glob, Write |
    | brief-compiler | opus | medium | — | aew:run-protocol | Read, Grep, Glob, Write |
    | standards-setter | sonnet | medium | project | aew:run-protocol, aew:stack-standards | Read, Grep, Glob, Write, Edit, Bash, context7 MCP |
    | senior-engineer | opus | high | project | aew:run-protocol, aew:stack-standards, superpowers:systematic-debugging | Read, Grep, Glob, Write, Bash, context7 MCP |

    Each `description` says the agent is dispatched by the aew orchestrator only, so Claude does not auto-delegate to it in ordinary sessions. `claude plugin validate .` passes.
12. **AC-12** No agent can or may call `gh`. spec-analyser and brief-compiler get no Bash at all. standards-setter and senior-engineer keep Bash, because the docs say a `disallowedTools` entry such as `Bash(gh *)` removes the whole Bash tool. So for these two the ban is in the prompt's guardrails, and is enforced by the Bash guard hook for every `aew:*` agent (Assumption 11). Each prompt states the rule from `run-protocol`: no `gh`, no push, no merge, no PR.
13. **AC-13** Agent-specific behaviour:
    - **spec-analyser:**
      - The prompt contains the materiality rubric from DESIGN §8.1 verbatim.
      - It explores the repo read-only for feasibility.
      - It writes `01-spec-analysis.md`, `spec-final.md` and `spec-changes.json`.
      - Each material change gets a question with a recommended answer and alternatives.
      - When nothing needs changing it says so explicitly: "No changes needed" in the SUMMARY, `changes: []`, and `spec-final.md` equal to the analysed spec.
      - It returns `needs_input` when any change is material.
      - On a re-run with James's answers it applies the confirmed material changes (`source: confirmed`).
    - **brief-compiler:**
      - It has two modes, pipeline and prompt (DESIGN §8.2), chosen by a `mode` field in the dispatch.
      - Every AC is `AC-n`, atomic, testable and tagged.
      - Vague words ("fast", "nice", "intuitive", "user-friendly", "secure" and the like) become measurable criteria, or are listed under Open risks as flagged.
      - It sets `UI changes: yes/no`.
      - Prompt mode writes a `prompt.md` that works as-is in a fresh session with no plugin installed.
    - **standards-setter:**
      - It follows DESIGN §8.3 and runs `detect-stack.sh` and `fingerprint`.
      - When the header fingerprint matches, it reuses the doc unchanged (`STATUS: ok`, "reused").
      - Otherwise it writes `docs/standards/<profile>.md` and `docs/standards/README.md`.
      - It always writes the run's `03-standards.md`, listing only the sections relevant to this brief.
    - **senior-engineer:**
      - It has three modes (plan, review, triage) per DESIGN §8.4, chosen by the dispatch's `mode`.
      - **Plan:** at least one alternative with the reason it was rejected; challenges; WPs with file ownership, `depends_on` and `parallelisable`; standards references per WP; guardrails; unit tests per WP; risks; an AC→WP matrix covering every AC. `needs_input` when a challenge is material.
      - **Review:** numbered findings with a severity (blocker / major / minor / nit) and a `file:line` location. `changes_required` if and only if there is at least one blocker or major.
      - **Triage:** names where the divergence started (spec / brief / plan / implementation) and gives fix instructions specific enough for a Sonnet developer (file, change, test to re-run), or a test ruling for QA.

**Fixtures**

14. **AC-14** `tests/fixtures/stacks/` holds minimal trees, each with its expected detection output:

    | Fixture | Expected profiles |
    |---|---|
    | `nextjs-tailwind` | `nextjs`, `tailwind` |
    | `react-vite` | `react` |
    | `laravel` | `laravel` |
    | `wordpress-theme` | `wordpress` |
    | `woocommerce-plugin` | `wordpress`, `woocommerce` |
    | `dotnet-api` | `dotnet` |
    | `monorepo` | `nextjs` at `apps/web`, `laravel` at `apps/api` |
15. **AC-15** `tests/fixtures/issues/` holds three issue markdowns, in the shape of `00-issue-original.md`, targeted at the `nextjs-tailwind` fixture:
    - a clean, complete spec with a UI change;
    - a spec with only non-material gaps, with no UI change;
    - a spec with a material ambiguity: whether guests or only logged-in users can use the feature.

    `tests/fixtures/briefs/` holds one brief in `02-brief.md` form. It has at least four ACs, and they naturally split into at least two WPs, at least one of which can run in parallel.

**Headless agent smoke tests**

16. **AC-16 [P]** Each agent is run headlessly (`claude --plugin-dir <repo> -p`) in a temporary project under `tests/tmp/` with a seeded run dir. These checks pass:
    - **spec-analyser:** the clean spec gives no material changes; the non-material spec gives auto-applied changes and `STATUS: ok`; the material spec gives `STATUS: needs_input` with at least one question and a recommended answer.
    - **brief-compiler:** every AC is numbered and testable, and the UI flag is correct (checked on one UI and one non-UI spec). Prompt mode produces a self-contained `prompt.md`: no `aew`, `.aew/`, `/aew:`, `run-protocol` or `CLAUDE_PLUGIN_ROOT` references, the template comment removed, and every AC present.
    - **standards-setter:** on `nextjs-tailwind` it generates `nextjs.md`, `tailwind.md` and `README.md` with valid fingerprint headers. A second run reuses them: `STATUS: ok`, "reused", and the docs byte-identical (checksums before and after).
    - **senior-engineer (plan):** on the fixture brief, the plan has at least one alternative and an AC→WP matrix that covers every AC. At least one WP is correctly marked parallelisable or not.
    - **Every run:** every artefact follows its template (the same headings in the same order), and every final message ends with a valid return block (the same rule as `gate-subagent.sh`'s `valid_return_block`).
17. **AC-17 [P]** `tests/agent-smoke/README.md` records the results as a table of check | result | notes, without full transcripts, plus the exact setup and invocation commands so the runs can be repeated. When a check fails, the agent's prompt is improved and the check re-run. The check is never weakened.
18. **AC-18** Preloading is verified, not assumed. Because a missing skill in `skills:` is skipped silently (only a debug-log warning), each smoke run is made with `--debug-file`, and the README records that no skill-skip warning appeared for `aew:run-protocol`, `aew:stack-standards` or `superpowers:systematic-debugging`. It also records the context7 MCP tool names that resolved for standards-setter.

**Closing**

19. **AC-19** `CHANGELOG.md` is updated. DESIGN §3 is updated in the same commit with the facts this pass verified (see "Claude Code facts"), and §11 with the agent `gh` guard, if Assumption 11 stands. `docs/superpowers/project-map.md` gets the new contracts. The final report lists the checks run, the files changed, the deviations from DESIGN and any decisions needed. Everything lands as conventional commits.

## Scope

- **In:**
  - `scripts/detect-stack.sh` and `tests/scripts/detect-stack.bats`;
  - the `skills/stack-standards/` skill: `SKILL.md`, `references/document-structure.md` and the six seeds;
  - the four agents: `agents/spec-analyser.md`, `brief-compiler.md`, `standards-setter.md` and `senior-engineer.md`;
  - `tests/fixtures/{stacks,issues,briefs}/`;
  - the `tests/agent-smoke/README.md` results;
  - the one-rule change to `tests/scripts/conventions.bats` (Assumption 2);
  - the agent `gh` rule in `scripts/hooks/guard-bash.sh` with its table rows (Assumption 11);
  - the DESIGN §3/§11 updates, CHANGELOG and the project-map append.
- **Out:**
  - a C#/.NET seed (generated on demand; DESIGN §8.3, §13);
  - the developer, qa-engineer and doc-writer agents, and the `ui-qa` and `claude-md-curation` skills (prompt 04);
  - the `ship`, `init`, `resume`, `status` and `prompt` skills, the orchestrator dispatch wording, writing `.aew/config.json` `stacks`, and committing the standards docs (prompt 05);
  - milestone mode and bulk `#n-AC-m` handling beyond what the brief-compiler prompt mentions (prompt 06);
  - the sandbox end-to-end run (prompt 07);
  - a smoke-test runner script or CI;
  - README.md updates;
  - Playwright MCP.

## Context manifest

**Reference files** (downstream agents read these first):

- `docs/build-prompts/03-planning-agents.md`: the task, the deliverables and the [P] ACs.
- `docs/DESIGN.md`: §2 (principles, especially 2.3–2.6), §3 (platform facts to update), §5.2–5.3 (the skill and agent tables: model, effort, memory, skills), §6 (`docs/standards/` in the target project), §7.1/7.5 (run-dir writers, return contract), §8.1 (the materiality rubric, to copy verbatim), §8.2 (brief sections, prompt-mode contents), §8.3 (standards: sources, sections, markers, about 400 lines, seed list), §8.4 (senior modes and tools), §12 (agent prompt quality bar).
- `skills/run-protocol/SKILL.md`: the pattern for internal skill frontmatter, file naming (`07-review-<review_cycle+1>.md`, `09-triage-<n>.md`), the return contract, and the "agents never touch GitHub" wording to reuse in each agent.
- `skills/run-protocol/references/artefacts.md`: the reader and template map for every artefact.
- `templates/artefacts/spec-analysis.md`, `spec-changes.example.json`: spec-analyser outputs (classification table, Q-blocks with recommended answer and alternatives; `changes[]` with `type`/`source`; material changes appear only once confirmed).
- `templates/artefacts/brief.md`: brief sections, AC tags, the `UI changes: yes/no` heading, the DoD checklist.
- `templates/artefacts/prompt.md`: the prompt-mode structure. It has no return block, and its comment is removed before use.
- `templates/artefacts/standards-run.md`: the `03-standards.md` tables (Status: reused / generated / updated).
- `templates/artefacts/plan.md`, `review.md`, `triage.md`: senior-engineer outputs (the plan's WP fields, the review findings table, the triage "where the divergence started").
- `templates/config.schema.json`: `stacks[]` items are `{profile, path, version}` with `additionalProperties: false`, so the orchestrator (prompt 05) must drop `evidence` when writing config. The profile pattern is `^[a-z0-9-]+$`.
- `scripts/state.sh` + `scripts/lib/common.sh`: the script pattern (Usage header on line 2 as `--help`, sourcing `lib/common.sh`, `print_usage`, `die`, `require_cmd`).
- `tests/scripts/conventions.bats`: glob-driven checks that pick up `scripts/detect-stack.sh` automatically. These include the "no arguments exits 1" rule, which conflicts (Assumption 2).
- `tests/scripts/helpers/common.bash`: `common_setup`, the assert helpers and `$BATS_TEST_TMPDIR`, for `detect-stack.bats`.
- `scripts/hooks/gate-subagent.sh` → `valid_return_block`: the canonical return-block rule the smoke tests apply. `scripts/hooks/guard-bash.sh` + `tests/scripts/fixtures/hooks/bash-cases.tsv`: where the agent `gh` rule goes, table-driven.
- `docs/superpowers/project-map.md`: contracts and bash/jq gotchas (bash 3.2, `set -e` in `$(...)`, `grep -P` unavailable, `/var` symlink).

**Key facts learned from the codebase and environment:**

- Claude Code is 2.1.308 locally. The installed dependencies are superpowers 7.0.0 (skills dir includes `systematic-debugging`, `test-driven-development`, `verification-before-completion`) and context7, a remote HTTP MCP server at `mcp.context7.com` keyed `context7`. Its tools are `resolve-library-id` and `query-docs`. It is anonymous and rate-limited unless `CONTEXT7_API_KEY` is set.
- `${CLAUDE_PLUGIN_ROOT}` is substituted inline in agent and skill Markdown bodies, but is **not** exported to commands run through the Bash tool. Agent prompts must therefore spell paths as `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh` and `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/<x>.md` in the body text. `${CLAUDE_SKILL_DIR}` resolves to `skills/stack-standards/` inside the skill, for the seed paths.
- The conventions suite runs every `scripts/*.sh` with no arguments from a non-git temp dir and expects exit 1. That holds for subcommand scripts, but not for `detect-stack.sh [path]`.
- `tests/fixtures/` does not exist yet. The existing bats fixtures live in `tests/scripts/fixtures/`. Prompt 03 names `tests/fixtures/` because the stacks are shared by the bats tests and the agent smoke tests.
- Temporary projects under `tests/tmp/` sit inside this repo. Claude Code loads ancestor `CLAUDE.md` files, so this repo's development `CLAUDE.md` would leak into the smoke runs unless it is excluded (`--settings '{"claudeMdExcludes":["<repo>/CLAUDE.md"]}'`).
- Agent memory (`memory: project`) writes `.claude/agent-memory/<agent>/MEMORY.md` in the **target** project, and automatically enables Read, Write and Edit. So even "read-only" agents get Edit once memory is on.

## Assumptions

**Detection and fingerprint**

1. **Assumed:** the `version` field is the declared version, normalised to its lowest concrete version (operators `^ ~ >= v` stripped, `^16.0.1` → `16.0.1`, `^12.0` → `12.0`). The major is its first numeric component. The sources are:
   - `nextjs`, `react`, `tailwind`: the `package.json` dependency;
   - `laravel`: `composer.json` `require`;
   - `wordpress`: the theme or plugin `Requires at least:` header, otherwise `$wp_version` in `wp-includes/version.php`;
   - `woocommerce`: `WC requires at least:`, otherwise the dependency;
   - `dotnet`: `<TargetFramework>netX.Y`;
   - `php` (a fingerprint-only major, Assumption 6): `composer.json` `require.php`, otherwise, for `wordpress`, the `Requires PHP:` header.

   Anything else is `"unknown"`, and its major is `unknown` in the fingerprint. **Flag if wrong**, especially the WordPress choice ("Requires at least" rather than "Tested up to").
2. **Assumed (repo convention conflict):** `conventions.bats`'s "subcommand scripts with no arguments exit 1" rule cannot hold for `detect-stack.sh [path]`, which the prompt makes optional. The smallest fix is to narrow the `subcommand` file kind to scripts whose line-2 Usage names a required argument (the text after the script name does not start with `[`). This is a one-line change to a prompt-02 file whose header says "never edit this file to add one" (that rule is about adding scripts, which the globs already pick up, so narrowing a rule is not a breach of it, but it does reopen reviewed code). The alternative, making `path` required, contradicts the prompt. The bad-option rule (`--definitely-not-an-option` → exit 1, empty stdout) still applies to `detect-stack.sh`. **Flag if wrong.**
3. **Assumed:** depth 3 means `find <root> -maxdepth 3`, so a file at `a/b/file` is found and one at `a/b/c/file` is not. `wp-content/themes/x/style.css` (depth 4) is therefore not seen, but `wp-content/` at depth 1 still detects `wordpress` at its parent. **Flag if wrong.**
4. **Assumed:** an entry's `path` is the nearest package root of its evidence: the directory with the `package.json` or `composer.json`, or the theme or plugin directory. For a `tailwind.config.*` file or a CSS `@import` with no manifest, it is the evidence file's directory. Entries for the same (profile, path) are merged, and their evidence is concatenated.
5. **Assumed:** a `woocommerce` dependency means `woocommerce/woocommerce` or `wpackagist-plugin/woocommerce` in `composer.json`, or any `@woocommerce/*` package in `package.json`. A "WooCommerce hook in a plugin" is a `woocommerce_` hook name inside `add_action(`/`add_filter(` in a PHP file of a detected WordPress plugin path. Overlays only appear alongside their base (`woocommerce` with `wordpress`); `tailwind` is standalone-capable.
6. **Assumed:** the fingerprint line is `<profile> <dep>@<major>[ <dep>@<major>…] cfg:<hash12>`, for example `nextjs next@16 react@19 typescript@5 cfg:1a2b3c4d5e6f`.
   - Majors tracked per profile:
     - `nextjs`: next, react, typescript;
     - `react`: react, typescript;
     - `tailwind`: tailwindcss;
     - `laravel`: laravel/framework, php;
     - `wordpress`: wordpress, php;
     - `woocommerce`: woocommerce;
     - `dotnet`: the target framework.
   - A dependency that is absent is omitted.
   - The hash is the first 12 hex characters of SHA-256 (`shasum -a 256`, falling back to `sha256sum`) over the sorted `relative-path\0content` of the profile's relevant tool configs, found at the stack path and the repo root:
     - eslint (`eslint.config.*`, `.eslintrc*`), prettier, `tsconfig.json`, `phpcs.xml(.dist)`, `pint.json`, `phpstan.neon(.dist)`, stylelint, `.editorconfig`, `Directory.Build.props`, `.csharpierrc*`;
     - `tailwind.config.*` and the CSS file holding `@import "tailwindcss"`, for `tailwind`.

   Manifests (`package.json`, `composer.json`) are excluded, so ordinary dependency bumps don't invalidate docs (majors are tracked separately). **Flag if wrong.**
7. **Assumed:** the fingerprint header is the first line of `docs/standards/<profile>.md`: `<!-- aew:standards fingerprint="<fingerprint line>" generated="YYYY-MM-DD" -->`. Reuse means an exact string match of the `fingerprint` value. If a profile appears at more than one path (two Next.js apps), there is still one doc per profile (DESIGN §6). It is generated from the first path in detection order, and its header fingerprint is for that path. The other paths are listed under Project structure. **Flag if wrong.**

**Standards system**

8. **Assumed:** seeds use the document-structure section headings, so the setter can merge section by section. They replace the fingerprint header with a "Versions covered: … (researched YYYY-MM-DD; sources: …)" line. They mark a rule **[tool]** only where the stack's default or official tooling enforces it (eslint-config-next, WPCS through phpcs, Pint, Prettier). The standards-setter re-marks each rule against the repo's actual configs, so a rule is only [tool] if the repo enforces it. The "current major" versions are whatever research finds on the day; this spec deliberately does not name them.
9. **Assumed:** each overlay (`tailwind`, `woocommerce`) gets its own `docs/standards/<overlay>.md` (one doc per profile, DESIGN §6). It holds only the overlay's additions and overrides, and opens with "Overlay on: <base>". On a conflict, the overlay's rule wins over the base's, and the repo's own conventions win over both (DESIGN principle 6). `03-standards.md` lists the base and overlay sections together.
10. **Assumed:** the three statuses mean this:
    - **reused:** the fingerprint matches, so no write.
    - **updated:** the doc exists but the fingerprint differs. **[tool]** rules are re-derived from the configs. **[convention]** rules, and any edits James made by hand, are kept unless a new config or major version contradicts them, in which case they are replaced and noted.
    - **generated:** no doc exists yet.

    The standards-setter never commits; the orchestrator or init commits `docs/standards/` (prompt 05). **Flag if wrong.**

**Agents**

11. **Assumed (resolves a prompt-versus-docs gap; flag if wrong):** "deny `gh` explicitly where the docs allow" cannot be done in frontmatter for agents that need Bash, because the docs say `disallowedTools: Bash(gh *)` removes all of Bash, and plugins cannot ship `permissions.deny` (a plugin `settings.json` honours only `agent` and `subagentStatusLine`). The docs do allow it through hooks, because a `PreToolUse` payload inside a subagent carries `agent_type`. So `guard-bash.sh` gets one rule: when `agent_type` starts with `aew:`, deny any command segment whose command is `gh`. It has table rows (blocked: an `aew:senior-engineer` `gh issue view 3`, an `aew:developer` `cd x && gh pr list`; allowed: the main thread's `gh issue view 3` with an empty `agent_type`). DESIGN §11's blocked list gets one bullet. spec-analyser and brief-compiler additionally have no Bash. If the reviewer prefers not to touch a prompt-02 hook, the fallback is instruction-only, recorded as a deviation.
12. **Assumed:** dependency and own-plugin skills are listed fully qualified in `skills:` (`aew:run-protocol`, `aew:stack-standards`, `superpowers:systematic-debugging`). Plugin skills are namespaced `<plugin>:<skill>`, but the docs give no example inside `skills:`. Preloading is checked through the debug log (AC-18). If a qualified name is skipped, try the bare name and record the result in DESIGN §3. **Flag if wrong.**
13. **Assumed:** the context7 tools are granted with the wildcard `mcp__plugin_context7_context7__*` in `tools`, following DESIGN §3's `mcp__plugin_<plugin>_<server>__<tool>` and the server key `context7`. Verify in the standards-setter smoke run. WebFetch is not granted, because DESIGN §8.3 names context7 as source 4 and nothing else.
14. **Assumed:** each agent prompt defines the dispatch fields it expects as a short "Inputs" block, and prompt 05's orchestrator adopts them verbatim:
    - all four agents: `run_dir`;
    - spec-analyser: `spec_version` (the version to produce) and, on a re-run, `answers`;
    - brief-compiler: `mode: pipeline | prompt`;
    - senior-engineer: `mode: plan | review | triage`, `n` (the cycle number) and `base` (the base branch, for review).

    This is a cross-prompt contract, recorded in the project map. **Flag if wrong.**
15. **Assumed:** spec-analyser works out the version itself when `spec_version` is absent. If the body has a `<!-- aew:spec vN -->` marker, the new version is N+1; otherwise it is 2. With no changes it still writes `spec-changes.json` with `changes: []` and NEXT "no revision to record". For a material spec, `spec-final.md` and `spec-changes.json` hold only the non-material changes until James answers (as in `spec-changes.example.json`).
16. **Assumed:** senior-engineer needs the "Material (ask first)" list to decide when a plan challenge means `needs_input`. Agents can't read DESIGN.md in a target project, so its prompt carries that list verbatim too (eight bullets), instead of moving the rubric into `run-protocol`. That keeps `run-protocol` unchanged, and the prompt asks for the rubric to be verbatim in spec-analyser. **Flag if wrong.**
17. **Assumed:** senior-engineer's Bash is limited by instruction to read-only commands: `git diff/log/show/status`, `ls`, and `cat`/`grep` equivalents. It does not run tests, lint or builds in review; running them is the developer's and QA's job, and they can write caches. It writes only in the run dir. Review gives STATUS `ok` for both verdicts; the verdict is the first word of the SUMMARY (review template). `needs_input` is reserved for material spec challenges, and `blocked` for an unreadable diff or plan.
18. **Assumed:** prompt mode writes only `prompt.md`, with the brief inline, and no `02-brief.md` (run-protocol: "Prompt mode stops after brief"). `prompt.md` has **no** return block, because it is pasted into a session as-is and the template has none. The return block goes in the final message only. In prompt mode the standards stage has not run, so if `docs/standards/` is missing it inlines the essentials from the matching seeds (`${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/<profile>.md`, with the profiles from `.aew/config.json` `stacks`). **Flag if wrong.**
19. **Assumed:** memory instructions are concrete and bounded:
    - spec-analyser records recurring gap patterns in this project's issues;
    - standards-setter records conventions it discovered and why it chose them;
    - senior-engineer records recurring review findings and architecture decisions;
    - none of them records secrets, run-specific detail, or anything already in the standards docs.

    They are only active if auto memory is enabled (per the docs).

**Fixtures and smoke tests**

20. **Assumed:** stack fixtures are minimal manifests and config files, plus one or two source files each, so the senior engineer has something to plan against in `nextjs-tailwind`. Pruned directories (`node_modules/`, `vendor/`) are created at test time in a copy under `$BATS_TEST_TMPDIR`, never committed (`node_modules/` is gitignored anyway).
21. **Assumed:** the issue fixtures are markdown only, in the `00-issue-original.md` shape. The smoke setup derives a minimal `issue.json` (`number`, `title`, `body`, `labels: []`, `comments: []`) with jq. Example themes:
    - clean: a footer newsletter sign-up form with full ACs (UI);
    - non-material: a `/api/health` endpoint with an implied status code, a typo and a missing edge case (no UI);
    - material: "save favourite articles", with guest access unspecified.
22. **Assumed:** each smoke run uses a fresh copy of a stack fixture under `tests/tmp/smoke-<agent>-<case>/`. The copy is `git init` and committed once, and gets `.aew/config.json` (from `templates/config.example.json`, so the hooks, including the agent `gh` guard, are live) and a seeded `.aew/runs/<id>/`. The seeding creates `state.json`, `log.md` and `.aew/runs/current` with `scripts/state.sh init` (state is script-owned, so it is never hand-written) and copies the fixture inputs (`00-issue-original.md`, the derived `issue.json`, and later-stage inputs such as `spec-final.md` or `02-brief.md`).
    - Agents run as **subagents** dispatched by a thin `-p` main-thread prompt, because that is how the orchestrator uses them.
    - Flags: `--output-format stream-json --verbose --forward-subagent-text`, so the agent's own final message is checked rather than the parent's echo. Also `--max-budget-usd`, `--debug-file`, `--settings` with `claudeMdExcludes` for this repo's `CLAUDE.md`, `--permission-mode acceptEdits`, and a narrow `--allowedTools` for Bash (`detect-stack.sh`, read-only `git`).
    - The senior-engineer plan run reuses the standards-setter's temp project (the generated standards and `03-standards.md`), with the brief fixture as `02-brief.md`.
    - Only the README results are committed. **Flag if wrong.**
23. **Assumed:** there is no runner script, because DESIGN and the prompt don't call for one. The README holds copy-paste setup, invocation and check commands. The checks are template heading order and `valid_return_block`, run by sourcing `gate-subagent.sh`'s function or using an equivalent `tail`/`grep` one-liner. **Flag if wrong**, because re-running after prompt fixes is manual.
24. **Assumed:** smoke coverage is the prompt's minimum plus one brief run on the non-UI spec, to make the UI-flag check meaningful. That is eight agent runs: spec-analyser ×3, brief-compiler ×3 (pipeline UI, pipeline non-UI, prompt), standards-setter ×2 (and the second one is the reuse check) and senior-engineer plan ×1. Review and triage modes are not smoke-run, because the prompt only asks for plan and they need a real diff and QA report (prompt 07 covers them end to end).

**Process**

25. **Assumed:** seed research uses context7 (`resolve-library-id` → `query-docs`) first, then the official docs (nextjs.org, react.dev, laravel.com/docs, developer.wordpress.org/coding-standards, developer.woocommerce.com, tailwindcss.com). Each seed lists its sources and the research date. If context7 is unavailable or rate-limited, the official docs alone are used, and this is noted in the seed and the final report.
26. **Assumed:** like prompt 02, the prompt asks for one conventional commit, but dw-implement commits per task. Squashing is raised at human review, not done autonomously.

## Claude Code facts (verified 2026-10-24 against code.claude.com/docs `/en/sub-agents`, `/en/plugins-reference`, `/en/skills`, `/en/memory`, `/en/hooks`, `/en/cli-reference`; Claude Code 2.1.308)

| # | Fact | Result | DESIGN action |
|---|---|---|---|
| F1 | Plugin agent frontmatter honours `name, description, model, effort, maxTurns, autoCompactWindow, tools, disallowedTools, skills, memory, background, omitClaudeMd, isolation (worktree), color, experimental.cacheTtl`, and ignores `hooks, mcpServers, permissionMode` (`initialPrompt` only applies to `--agent`). | Verified, matches §3 | none |
| F2 | `model`: `sonnet, opus, haiku, fable`, a full ID, or `inherit`. | Verified, matches §3 | none |
| F3 | `effort`: `low, medium, high, xhigh, max`, with the levels available depending on the model. | Verified, not in §3 | add a line to §3 |
| F4 | `memory`: `user` (`~/.claude/agent-memory/<name>/`), `project` (`.claude/agent-memory/<name>/`), `local` (`.claude/agent-memory-local/<name>/`). The first 200 lines or 25 KB of MEMORY.md are loaded. **Memory automatically enables Read, Write and Edit**, and has no effect when auto memory is off. | Verified; the last two points are new | add to §3 |
| F5 | `skills:` injects the full content of each listed skill (up to 32). Skills with `disable-model-invocation: true` can't be preloaded. **A missing skill is skipped silently**, with a debug-log warning. | Verified | add the silent-skip point to §3 |
| F6 | Namespaced form inside `skills:` for plugin skills (`aew:run-protocol`, `superpowers:systematic-debugging`). | **Not documented**: verify in the smoke runs (AC-18) | record the result in §3 |
| F7 | A `disallowedTools` entry with a specifier (`Bash(gh *)`) removes the **whole** tool. Per-command denial needs `permissions.deny`, which a plugin can't ship (a plugin `settings.json` honours only `agent` and `subagentStatusLine`). | Verified, not in §3 | add to §3 |
| F8 | `PreToolUse` inside a subagent carries `agent_id` and `agent_type`. | Verified | add to §3; basis for Assumption 11 |
| F9 | `${CLAUDE_PLUGIN_ROOT}` (and `${CLAUDE_SKILL_DIR}` in skills) is substituted in agent and skill Markdown bodies, and is **not** exported to Bash-tool commands. | Verified, not in §3 | add to §3 |
| F10 | An agent `name` can't contain `:`. Plugin agents appear as `aew:<name>`. | Verified, matches §3 | none |
| F11 | Subagents never get `AskUserQuestion`. Background subagents (the default) keep Read, Grep, Glob, Bash, Edit, Write, WebFetch, Skill and the rest, plus every MCP tool. The `tools` allowlist excludes MCP tools unless they are listed (`mcp__<server>__*` wildcard). | Verified | none (informs the tool lists) |
| F12 | context7 server key `context7`, tools `resolve-library-id` and `query-docs`, so the expected names are `mcp__plugin_context7_context7__*`. | Tool names verified from the plugin README; the **prefixed name needs verifying** in the smoke run | correct §3 if it differs |
| F13 | CLI: `-p`, `--plugin-dir`, `--agent`, `--output-format json/stream-json`, `--forward-subagent-text`, `--max-budget-usd`, `--max-turns`, `--permission-mode`, `--allowedTools`, `--debug-file`, `--settings`. Ancestor `CLAUDE.md` files load, and `claudeMdExcludes` can skip them. | Verified | none |

No doc contradicts DESIGN §3/§5/§11 in a way that changes behaviour. F3–F5 and F7–F9 are additions that §3 should carry. F7 is the only one that changes how a prompt instruction can be met (Assumption 11).

## DESIGN.md and prompt conflicts found

1. **The `gh` deny (prompt vs docs).** The prompt says to deny `gh` in agents "where the docs allow". Frontmatter can't do that without removing Bash (F7). Resolved by Assumption 11 (a hook rule, plus no Bash for two agents). It adds one bullet to DESIGN §11, which is a behaviour addition, so it is flagged for James.
2. **The no-argument convention (prompt vs repo test).** `detect-stack.sh [path]` versus `conventions.bats`'s no-argument rule. Resolved by Assumption 2.
3. **`stacks` config shape (prompt vs schema).** `detect-stack.sh` adds `evidence`, but `config.schema.json` forbids extra properties. This is not a conflict in this prompt: prompt 05 must drop `evidence` when it writes config. It is noted in the project map.
4. **Memory on read-only agents (docs vs DESIGN §8.4).** DESIGN gives senior-engineer "read tools, Bash read-only, Write". `memory: project` adds Edit automatically (F4). This is accepted (DESIGN §5.3 asks for memory), and the prompt restricts edits to the memory dir and the run dir.

No conflict changes the four agents' models, effort, memory or preloaded skills from DESIGN §5.3.

## Risks

- **Headless smoke-test cost and non-determinism** (high). There are eight runs, five of them on Opus at high or medium effort, and LLM output varies between runs. A check can pass once and fail on a re-run. Mitigations:
  - `--max-budget-usd` per run, with the cost recorded in the notes;
  - checks are structural (headings, return block, matrix coverage, STATUS) rather than prose;
  - a failure leads to a prompt fix and a re-run, never a weaker check;
  - a flaky pass is recorded as such.
- **Silent preload failure** (high). A wrong skill name in `skills:` is skipped with only a debug-log warning. The agent then lacks `run-protocol`, and the return block or file naming drifts. Mitigation: AC-18 checks the debug log in every smoke run.
- **context7 availability.** It is anonymous and rate-limited, it might not be loaded in the implementing session, and it could be slow across six seeds. Mitigation: official docs as the fallback (Assumption 25). Seed accuracy remains the residual risk, because seeds are opinionated guidance on fast-moving majors (Next.js, Tailwind, WooCommerce).
- **Docs drift.** The facts above were checked today. Undocumented behaviour (F6, F12) is verified empirically and recorded in DESIGN §3.
- **Smoke-test isolation.** The repo's `CLAUDE.md` and the user's other installed plugins and hooks (for example dev-workflow) load in headless sessions and can steer agents. Mitigations: `claudeMdExcludes`; noting other enabled plugins in the README; not using `--bare`, because it would also skip the dependency plugins.
- **Prompt quality is the product.** Agents that pass the structural checks can still produce shallow analysis. The prompts must be opinionated (rubric verbatim, explicit "done" checks, concrete examples). The senior architect should review them as code.
- **Cross-prompt contracts.** The dispatch fields (Assumption 14), the fingerprint header (Assumption 7) and `evidence` in the detect output become inputs to prompt 05. A later change ripples outward. Mitigation: record them in the project map and in each agent's Inputs block.
- **Detection heuristics.** The WordPress `Plugin Name:` scan, the WooCommerce hook grep and the depth-3 limit can give false positives or negatives in real repos. Mitigation: deterministic rules, fixture tests, and evidence strings so James can see why a profile was chosen.
- **Touching prompt-02 files.** The changes to `conventions.bats` and `guard-bash.sh` reopen reviewed code. Mitigation: one rule each, table and fixture rows added, and the full suite re-run.
- **Scale.** About 25 files: a script and its tests, a skill with eight references (six of them researched seeds), four long agent prompts, about 11 fixtures and eight smoke runs. A phased plan is expected.

## Open questions for human

(none: every decision was made from DESIGN.md, the docs and the repo. The high-leverage defaults are flagged above, especially Assumptions 2, 6, 7, 11, 12, 18 and 22)

## Spec-review notes (for the plan)

Verified against the live docs (`/en/sub-agents`, `/en/hooks`, `/en/memory`) and `claude --help` (2.1.308): F4 (memory enables Read, Write and Edit, and has no effect with auto memory off), F5 (a missing skill is skipped with a debug-log warning), F7 (a `disallowedTools` entry with a specifier removes the whole tool; per-command denial is `permissions.deny`), F8 (`PreToolUse` inside a subagent carries `agent_type`, which for plugin agents is the scoped `aew:<name>`), `claudeMdExcludes`, and the F13 flags including `--forward-subagent-text`. Assumption 11 stands: the prompt asks for an explicit deny "where the docs allow", and a `PreToolUse` rule is the only documented way to do that while keeping Bash.

Carry these into the plan (none of them blocks approval):

1. **A11 test harness.** `tests/scripts/fixtures/hooks/bash-cases.tsv` has no `agent_type` column (`expect branch cwd command`). The plan must say how the agent rows are expressed: an optional fifth column that defaults to empty, or three dedicated `@test` blocks. Either way, the existing rows must still pass unchanged.
2. **A11 scope.** The rule denies the `gh` command only. An agent calling the plugin's `gh-*.sh` wrappers by absolute path is not covered. That is acceptable, because agent prompts never name those paths, but record it in the Limits paragraph of the script header so the gap is documented rather than discovered.
3. **A6 Tailwind churn.** Hashing the whole CSS file that holds `@import "tailwindcss"` means any style edit in that file turns `tailwind.md` into "updated" on the next run. This fails safe (no stale doc), so it is accepted for v1. Note it in the SKILL.md fingerprint section.
4. **A14 `answers`.** Answers arrive in the dispatch, which a resumed run cannot replay. spec-analyser should record the answers it applied in `01-spec-analysis.md`, against their question ids, so the run dir alone shows what was confirmed. No new artefact is needed.
5. **A18 profile fallback.** If `.aew/config.json` has no `stacks` in prompt mode, brief-compiler (which has no Bash) infers the profiles from the manifests with Glob and Read, using the AC-2 rules, rather than failing.
6. **Smoke isolation checks (A22).** In the first smoke run, confirm three things from the debug file and record them in the README:
   - this repo's `CLAUDE.md` did not load (`claudeMdExcludes` works through `--settings`);
   - reading `${CLAUDE_PLUGIN_ROOT}/templates/…` and `…/references/seeds/…` from a project outside the plugin dir needed no extra permission;
   - the live `SessionStart` hint ("Use /aew:resume") appears in the thin main thread, so the dispatch prompt must be worded to ignore it.
7. **A1 WordPress major.** WordPress calls `6.7` a major release. Taking the first numeric component (`6`) means 6.x bumps never invalidate the doc. That is the lower-churn choice, and it stays flagged.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T13:47:53Z
- Complexity: NOVEL
- Scale: EPIC
- Reason: there is no in-repo analog for agent prompts, seeds or headless smoke tests; the work runs to about 25 files and well over 8 tasks across four independently shippable slices (detection script, standards skill, agents, smoke verification); and it reopens a prompt-02 safety hook.
- Spec content hash (SHA-256): d41b2001758424bf948bffabadca37c76a0abd16f339eed4fb2725bec17599c1 (of this doc up to and including "Spec-review notes", before this trailer)

<spec-summary>
- Topic: standards-and-planning-agents
- Issue: no issue (build prompt `docs/build-prompts/03-planning-agents.md`; DESIGN.md wins on conflict)
- Problem: the plugin has a deterministic layer but no thinking agents. Spec analysis, brief, standards and planning need four precise agents plus a standards system that detects stacks, fingerprints them, and reuses or generates per-stack docs. All of it must be proven by headless smoke tests.
- ACs (testable): AC-1–AC-6 cover `detect-stack.sh` (JSON output, rules, depth 3 with pruning, fingerprint, bats tests, conventions). AC-7–AC-10 cover the `stack-standards` skill (SKILL.md, document-structure, six seeds of 300 lines or fewer with a11y, security and testing sections). AC-11–AC-13 cover the four agents (DESIGN §5.3 frontmatter, the no-`gh` rule, mode-specific behaviour). AC-14–AC-15 cover the fixtures (7 stacks, 3 issues, 1 brief). AC-16–AC-18 cover 8 headless smoke runs, the README results table, and preloads verified in the debug log. AC-19 covers CHANGELOG, DESIGN §3/§11, the project map and the final report.
- Scope in: detect-stack.sh + bats; skills/stack-standards (SKILL.md, document-structure.md, 6 seeds); 4 agents; tests/fixtures/{stacks,issues,briefs}; tests/agent-smoke/README.md; the conventions.bats no-arg narrowing (A2); the guard-bash.sh agent `gh` rule + DESIGN §11 bullet (A11); DESIGN §3, CHANGELOG, project map.
- Scope out: C# seed; developer/qa/doc-writer agents and ui-qa/claude-md-curation (prompt 04); ship/init/resume/status/prompt skills, writing config `stacks`, committing standards docs (prompt 05); milestone mode (06); sandbox e2e (07); a smoke runner script or CI; README; Playwright MCP.
- Context manifest (key references):
  - docs/DESIGN.md §3, §5.3, §7.5, §8.1–8.4, §11, §12: source of truth (rubric verbatim from §8.1)
  - scripts/state.sh + scripts/lib/common.sh: script pattern (Usage line 2, die, lib_main)
  - tests/scripts/conventions.bats: the no-arg rule to narrow; tests/scripts/helpers/common.bash for bats
  - scripts/hooks/guard-bash.sh + tests/scripts/fixtures/hooks/bash-cases.tsv: where the agent gh rule goes (the TSV has no agent_type column)
  - scripts/hooks/gate-subagent.sh valid_return_block: the canonical return-block check
  - skills/run-protocol/SKILL.md: internal-skill frontmatter, file naming, the no-GitHub wording
  - templates/artefacts/{spec-analysis,spec-changes.example.json,brief,prompt,standards-run,plan,review,triage}.md: agent outputs
  - templates/config.schema.json: stacks items are {profile,path,version}, additionalProperties false, so prompt 05 drops evidence
- Assumptions (high-stakes only, marked "flag if wrong"):
  - A2: narrow conventions.bats no-arg rule to scripts whose Usage names a required arg
  - A6/A7: fingerprint `<profile> dep@major… cfg:<hash12>`; header `<!-- aew:standards fingerprint="…" generated="YYYY-MM-DD" -->`; exact-match reuse
  - A11: no Bash for spec-analyser/brief-compiler; guard-bash denies `gh` when agent_type starts with `aew:` (docs-verified)
  - A12: qualified names in `skills:` (aew:run-protocol, superpowers:systematic-debugging), verified in the debug log
  - A14: dispatch fields run_dir; spec_version/answers; brief mode; senior mode/n/base (contract for prompt 05)
  - A18: prompt mode writes only prompt.md, with no return block in the file
  - A22–A24: subagent under a thin -p prompt, claudeMdExcludes, live hooks, budget cap, no runner script, 8 runs
- Complexity: NOVEL
- Scale: EPIC
- Spec content hash: d41b2001758424bf948bffabadca37c76a0abd16f339eed4fb2725bec17599c1
</spec-summary>

<epic-decomposition>
- phase: A
  title: Deterministic layer changes (detection, fingerprint, conventions, agent gh guard)
  scope: detect-stack.sh + fingerprint, tests/fixtures/stacks, detect-stack.bats, conventions.bats no-arg narrowing, guard-bash.sh aew-agent gh rule + test rows + DESIGN §11 bullet
  acs: [1, 2, 3, 4, 5, 6, 12, 14]
  depends_on: []
  depth: full
  risk: reopens prompt-02 safety hook and convention test
- phase: B
  title: stack-standards skill and seeds
  scope: SKILL.md (detection, fingerprint header, reuse/update/generate, overlay merge, source priority), document-structure.md, six researched seeds
  acs: [7, 8, 9, 10]
  depends_on: []
  depth: lean
  risk: none
- phase: C
  title: spec-analyser and brief-compiler agents
  scope: both agent prompts (no Bash), issue fixtures (clean UI, non-material non-UI, material guest-access)
  acs: [11, 12, 13, 15]
  depends_on: []
  depth: full
  risk: none
- phase: D
  title: standards-setter and senior-engineer agents
  scope: both agent prompts (Bash, context7, stack-standards preload, three senior modes), brief fixture
  acs: [11, 12, 13, 15]
  depends_on: [A, B]
  depth: full
  risk: none
- phase: E
  title: Headless smoke verification and closing docs
  scope: 8 smoke runs with prompt fixes, tests/agent-smoke/README.md, preload and MCP-name checks in the debug log, DESIGN §3 facts, CHANGELOG, project map
  acs: [16, 17, 18, 19]
  depends_on: [A, C, D]
  depth: lean
  risk: none
</epic-decomposition>
