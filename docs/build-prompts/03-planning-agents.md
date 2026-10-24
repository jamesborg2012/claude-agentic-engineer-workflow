# Prompt 03 — Standards system and planning-side agents

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. That includes agent frontmatter fields, valid `model` and `effort` values, `skills:` preloading (including skills from dependency plugins and how they're namespaced), and `memory:` scopes. Use the claude-code-guide agent; don't rely on memory. If the docs contradict DESIGN.md, follow the docs, update DESIGN.md in the same commit, and call it out.
- Work autonomously. Stop and ask me only when:
  - a decision isn't covered by DESIGN.md and is expensive to reverse;
  - the docs contradict the design in a way that changes behaviour;
  - you'd need to act outside this repo in a way this prompt doesn't ask for.
- Simplicity first: no abstractions, options or files the design doesn't call for.
- British English in all prose.
- Use superpowers' verification-before-completion before claiming you're done.
- Finish with:
  1. the checks you ran and their results;
  2. the files created or changed;
  3. any deviations from DESIGN.md, and why;
  4. anything I need to decide.

  Then commit with a conventional commit message.

## Goal
Build the standards system and the four agents that run before any code is written: spec-analyser, brief-compiler, standards-setter and senior-engineer. These agents decide the quality of everything downstream, so their prompts must be precise, opinionated and testable.

## Deliverables
1. **`scripts/detect-stack.sh [path]`.**
   - Outputs a JSON array of `{profile, path, version, evidence}`.
   - **Detection rules:**
     - `next` in package.json dependencies → `nextjs`;
     - `react` without `next` → `react`;
     - a `tailwindcss` dependency, a `tailwind.config.*` file, or a `@import "tailwindcss"` in CSS → `tailwind` overlay;
     - `laravel/framework` in composer.json → `laravel`;
     - a theme `style.css` with a `Theme Name:` header, a PHP file with a `Plugin Name:` header, or `wp-config.php` / `wp-content/` → `wordpress`;
     - WooCommerce headers (`WC requires at least`, `WC tested up to`), a `woocommerce` dependency, or WooCommerce hooks used in a plugin → `woocommerce` overlay;
     - `*.csproj` or `*.sln` → `dotnet`.
   - Scans to depth 3 and skips `node_modules`, `vendor`, `.git` and build output. Supports monorepos.
   - **`detect-stack.sh fingerprint <profile> [path]`:** profile + major versions + a short hash of the relevant tool configs.
   - shellcheck-clean, with tests.
2. **`skills/stack-standards/`:** an internal skill, not a slash command.
   - **`SKILL.md`:** how to run detection; the fingerprint header format; when to reuse versus regenerate; how to merge a base profile with overlays; and the source priority from DESIGN §8.3.
   - **`references/document-structure.md`:** the required sections and the [tool]/[convention] markers.
   - **`references/seeds/{nextjs,react,laravel,wordpress,woocommerce,tailwind}.md`.**
     - Research each seed with context7 and the official docs for the **current** major version, and state the versions covered at the top.
     - Each is 300 lines or fewer, with concrete do/don't examples, a WCAG 2.2 AA section, a security section, and testing conventions (which framework, how tests are organised and named).
     - **WordPress:** PHP, JS and CSS per the WordPress Coding Standards; escaping, sanitising and nonces; capabilities; hooks over core edits; i18n; enqueueing.
     - **WooCommerce overlay:** CRUD and data stores rather than direct post meta; HPOS compatibility declaration; hooks over template overrides; extension conventions.
     - **Tailwind overlay:** the current major's configuration approach, design tokens, and avoiding class soup (component extraction rules).
     - No C# seed; DESIGN says it's generated on demand.
3. **Agents** (`agents/*.md`). Each one is a complete system prompt covering: role, inputs (explicit paths in the run dir), step-by-step process, outputs (using the templates from prompt 01), the return contract (DESIGN §7.5), guardrails, autonomy rules, and what "done" means. Frontmatter follows DESIGN §5.3, with the minimum tool set for each agent; read-only wherever possible. None of them may call `gh`; deny it explicitly where the docs allow.
   - **`spec-analyser`:**
     - Copy the materiality rubric from DESIGN §8.1 verbatim.
     - Read-only exploration of the repo for feasibility.
     - Outputs `01-spec-analysis.md`, `spec-final.md` and `spec-changes.json`.
     - Questions come with recommended answers.
     - Must say explicitly when nothing needs changing.
   - **`brief-compiler`:**
     - Pipeline mode and prompt mode (DESIGN §8.2).
     - Every AC is numbered, atomic and testable. Vague words ("fast", "nice", "intuitive") are turned into measurable criteria, or flagged.
     - Prompt mode output must work as-is in a fresh session with no plugin installed.
   - **`standards-setter`:**
     - Follows DESIGN §8.3 and uses `detect-stack.sh`.
     - Reuses the existing doc when the fingerprint matches.
     - Writes `docs/standards/` and the run's `03-standards.md`, picking only the sections relevant to this brief.
   - **`senior-engineer`:**
     - Three modes (plan, review, triage) per DESIGN §8.4, selected by the orchestrator's input.
     - **Plan:** must include alternatives and challenges; work packages with file ownership, `depends_on` and `parallelisable`; per-package standards references; guardrails; and an AC→WP matrix that covers every AC.
     - **Review:** numbered findings with a severity (blocker / major / minor / nit). Only blockers and majors trigger `changes_required`.
     - **Triage:** names where the divergence started and gives fix instructions specific enough for a Sonnet developer.
4. **Fixtures in `tests/fixtures/`:**
   - `stacks/`: minimal file trees for nextjs-tailwind, react-vite, laravel, wordpress-theme, woocommerce-plugin, dotnet-api, and a monorepo with Next.js and Laravel.
   - `issues/`: three issue markdowns:
     - a clean, complete spec;
     - a spec with only non-material gaps;
     - a spec with a material ambiguity, e.g. unclear whether guests or only logged-in users can use a feature.
   - `briefs/`: one fixture brief for testing the senior engineer.

## Acceptance criteria
- `detect-stack.sh` returns the expected profiles for every stack fixture (scripted test).
- Run each agent headlessly against the fixtures, e.g. `claude --plugin-dir . -p` with a temporary run dir under `tests/tmp/`, and check:
  - **spec-analyser:** the clean spec gives no material changes; the non-material spec gives auto-applied changes and `STATUS: ok`; the material spec gives `STATUS: needs_input` with at least one question and a recommended answer.
  - **brief-compiler:** every AC is numbered and testable, and the UI flag is correct. Prompt mode produces a self-contained `prompt.md`.
  - **standards-setter:** on the nextjs-tailwind fixture it generates the docs, and a second run reuses them (fingerprint match).
  - **senior-engineer (plan):** on the fixture brief, the plan has at least one alternative and an AC→WP matrix that covers every AC. At least one work package is correctly marked parallelisable or not.
  - Every artefact follows its template, and every final message ends with a valid return block.
- Record the results in `tests/agent-smoke/README.md` as a table of check | result | notes, without full transcripts.
- If an agent fails a check, improve its prompt and re-run it. Don't weaken the check.
