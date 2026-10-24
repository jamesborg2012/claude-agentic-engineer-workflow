# Phase B plan: the stack-standards skill and seeds

- **Spec:** `docs/superpowers/specs/2026-10-24-standards-and-planning-agents.md` (hash `d41b2001…bec17599c1`)
- **Phase:** B of the EPIC. It has no phase dependencies and runs in parallel with A and C. Phase D (standards-setter, senior-engineer) depends on it.
- **Depth:** lean (no inline content; each task names its pattern, sources and checks)
- **ACs covered:** AC-7, AC-8, AC-9, AC-10
- **Risk:** none. All new Markdown, no scripts or hooks. The residual risk is seed accuracy, plus context7 availability (spec Risks, A25).
- **Date:** 2026-10-24

## Purpose

Phase B builds `skills/stack-standards/`, the internal reference skill preloaded into standards-setter and senior-engineer (DESIGN §5.2, §5.3). It holds:

- `SKILL.md`, the procedure;
- `references/document-structure.md`, the section contract shared by seeds and generated docs;
- six researched seeds that the standards-setter uses as source 3 (DESIGN §8.3). brief-compiler also reads them in prompt mode (A18).

B creates only files under `skills/stack-standards/`. It edits nothing that A, C, D or E owns.

## Cross-phase contracts B relies on (fixed by the spec, not re-derived)

- `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh [path]` prints a JSON array of `{profile, path, version, evidence}` in deterministic order. Detection rules follow AC-2, depth 3 with pruning follows AC-3, and `[]` means no stacks (AC-1).
- `detect-stack.sh fingerprint <profile> [path]` prints one line, `<profile> <dep>@<major>… cfg:<hash12>`. It exits 1 with `error:` when the profile isn't detected (A6, AC-4).
- The standards doc header is line 1 of `docs/standards/<profile>.md`: `<!-- aew:standards fingerprint="<line>" generated="YYYY-MM-DD" -->`. Reuse means an exact string match on `fingerprint`. A profile found at several paths still gets one doc, fingerprinted from the first path in detection order (A7).
- The statuses reused, updated and generated are defined in A10. The setter never commits.
- An overlay has its own doc that opens with `Overlay on: <base>`. The overlay wins over the base, and the repo's conventions win over both (A9).
- Seeds use the document-structure headings and swap the fingerprint header for a `Versions covered:` line. They mark a rule **[tool]** only where the stack's default or official tooling enforces it (A8).
- `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are substituted in skill bodies but are not exported to the Bash tool (F9). Paths are therefore written literally in the body.

## Decision: seeds depend on B1

Seeds must share the document-structure headings exactly, because the standards-setter merges seed, overlay and repo findings section by section (A8). So **B1 fixes the heading contract first**, and B2–B8 all depend on B1 alone. After B1 there is one wave of seven parallel tasks. Each touches a different file.

**Heading contract** (B1 writes it; every seed and every generated doc uses these `## ` headings, in this order, with this exact text):

1. `## Tooling and commands`
2. `## Project structure`
3. `## Naming`
4. `## Language idioms`
5. `## Framework conventions`
6. `## Error handling`
7. `## Security`
8. `## Accessibility`
9. `## Testing conventions`
10. `## Documentation and comment standards`
11. `## Anti-patterns`

These are DESIGN §8.3's sections in order. The fingerprint header is a first-line comment, not a heading. Other rules for seeds:

- An overlay seed keeps all 11 headings. A section with nothing to add reads "No overlay additions; see the base profile." This keeps the merge uniform, and AC-9 needs the security, accessibility and testing sections in every seed anyway.
- `## Accessibility` opens by stating the target, WCAG 2.2 AA.
- Seeds have no extra headings. Sources go on the `Versions covered:` line (A8).

## Shared check for every seed (B3–B8)

Run from the repo root with `S=skills/stack-standards/references/seeds/<profile>.md`:

```bash
[ "$(wc -l < "$S")" -le 300 ] && echo "lines ok"                                   # AC-9
diff <(grep '^## ' "$S") <(printf '%s\n' '## Tooling and commands' '## Project structure' '## Naming' '## Language idioms' '## Framework conventions' '## Error handling' '## Security' '## Accessibility' '## Testing conventions' '## Documentation and comment standards' '## Anti-patterns') && echo "headings ok"
head -5 "$S" | grep -cE '^Versions covered: .*\(researched [0-9]{4}-[0-9]{2}-[0-9]{2}; sources: .+\)'   # = 1
grep -cE '\*\*\[(tool|convention)\]\*\*' "$S"                                       # >= 25 marked rules
grep -c '^Do:$' "$S"; grep -c "^Don't:$" "$S"                                       # each >= 6, and equal
grep -c 'WCAG 2\.2 AA' "$S"                                                         # >= 1: the target
grep -cE '2\.4\.11|2\.5\.7|2\.5\.8|3\.2\.6|3\.3\.7|3\.3\.8' "$S"                     # >= 1: an A/AA criterion new in 2.2
```

(The do/don't format is whatever B1 defines. The `^Do:$` / `^Don't:$` lines shown here are the format B1 must adopt so this grep works: a label line followed by a fenced code block.)

Every seed task also has these requirements:

- **Research protocol (A25).** Use context7 `resolve-library-id` → `query-docs` first, then the official docs. Find the **current** major on the research date, and don't take versions from memory.
  - If context7 is unavailable or rate-limited, use the official docs alone. Write `context7 unavailable` in the sources and mention it in the task report.
  - Every [tool] claim names the tool or rule that enforces it.
  - For the accessibility section, use the WCAG 2.2 Recommendation (w3.org/TR/WCAG22) and the stack's own accessibility guidance.
- **Content.** Write concrete, stack-specific do/don't examples, and no generic advice that would fit any stack.
  - Testing conventions name the framework, how tests are organised (directory or co-location) and how test files and cases are named.
  - The security section covers the stack's real attack surface.
  - Prose is in British English; code identifiers stay as the API spells them.
- **Review gate.** Beyond the greps, the senior per-task review checks the content against the cited sources. A plausible-looking but outdated rule is a major finding.

## Tasks

### B1: `references/document-structure.md`

- **files:** `skills/stack-standards/references/document-structure.md`
- **depends_on:** []
- **pattern:** `skills/run-protocol/references/artefacts.md` (reference-file tone and table style). DESIGN §8.3 for the section list. `templates/artefacts/standards-run.md` for the status vocabulary.
- **covers AC-8.** The file defines:
  - the fingerprint header (A7, line 1);
  - the 11 required headings in the contract above, each with one line on what belongs in it;
  - **[tool]** (in a generated doc: enforced by a linter, formatter or type checker that the repo's configs actually run; in a seed: enforced by the stack's default or official tooling (A8); either way, name the tool) and **[convention]** (everything else);
  - the rule-bullet form, starting with the marker;
  - the do/don't example format (`Do:` / `Don't:` label lines, each followed by a fenced block);
  - the size limit: about 400 lines for a generated doc, and 300 or fewer for a seed;
  - the seed variant: a `Versions covered: <versions> (researched YYYY-MM-DD; sources: …)` line instead of the header, and `Overlay on: <base>` for overlays;
  - the overlay rule: all 11 headings, with "No overlay additions" where empty;
  - the `docs/standards/README.md` index format: a table of Profile | Doc | Path(s) | Overlay on | Fingerprint | Generated, plus one line on precedence (repo > overlay > base).
- **Checks:**
  - `wc -l` is 150 or fewer;
  - the 11 contract headings appear once each and in order (`grep -n` each heading string; line numbers ascend);
  - the file contains `[tool]`, `[convention]`, `aew:standards fingerprint=`, `Versions covered:`, `Overlay on:`, `docs/standards/README.md` and `400`;
  - no `TODO`.
- **Commit:** `feat(stack-standards): add the standards document structure reference`

### B2: `SKILL.md`

- **files:** `skills/stack-standards/SKILL.md`
- **depends_on:** [B1]
- **pattern:** `skills/run-protocol/SKILL.md` (frontmatter shape, imperative reference tone, tables). Literal `${CLAUDE_PLUGIN_ROOT}/…` paths, as in `skills/github-ops/SKILL.md`.
- **covers AC-7.** The file has:
  - **frontmatter:** `name: stack-standards`, a `description` (when to use it: detecting stacks, fingerprinting, reading or writing `docs/standards/`), and `user-invocable: false`. It has **no** `disable-model-invocation`.
  - **Sections:**
    1. **Detection:** the literal command `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh [path]`, the output shape and order, base and overlay profiles, and `[]`.
    2. **Fingerprint:** the `fingerprint` subcommand, the line format (A6), the header format (A7), the exact-match rule, and the multi-path rule. It includes the Tailwind-churn note from spec-review note 3: editing the CSS file that holds `@import "tailwindcss"` marks the doc "updated". That fails safe.
    3. **Reuse, update or generate:** the A10 statuses and what each writes. The setter never commits. `docs/standards/README.md` is always kept current.
    4. **Merging a base with overlays:** the A9 rules, section-by-section merge by the B1 headings, and `03-standards.md` listing base and overlay sections together.
    5. **Source priority:** DESIGN §8.3's four sources quoted in order. It adds that a seed rule is re-marked [tool] only if the repo's configs enforce it, otherwise [convention] (A8). Repo patterns beat seeds (principle 6).
    6. **Seeds:** a table of profile → `${CLAUDE_SKILL_DIR}/references/seeds/<profile>.md`. `dotnet` has no seed, so it is generated from sources 1, 2 and 4 (DESIGN §8.3, §13).
    7. **References:** a link to `references/document-structure.md`.
- **Checks:**
  - `wc -l` is 150 or fewer;
  - `head -5` contains `name: stack-standards` and `user-invocable: false`;
  - `grep -c disable-model-invocation` = 0;
  - `grep -c 'CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh'` ≥ 1;
  - the file contains `aew:standards fingerprint=`, `reused`, `updated`, `generated` and `Overlay on:`;
  - DESIGN §8.3's four source lines appear in order (`grep -n` on "repo tool configs", "patterns sampled from existing code", "seed reference for the profile", "context7 for version-specific guidance", with ascending line numbers);
  - the six seed paths are named (`for p in nextjs react laravel wordpress woocommerce tailwind; do grep -q "seeds/$p.md" "$F" || echo "missing $p"; done` prints nothing, with `F=skills/stack-standards/SKILL.md`) and `dotnet` is called out as having no seed;
  - `claude plugin validate .` passes.
- **Commit:** `feat(stack-standards): add the stack-standards internal skill`

### B3: `seeds/nextjs.md`

- **files:** `skills/stack-standards/references/seeds/nextjs.md`
- **depends_on:** [B1]
- **pattern:** B1's structure, and AC-10: it includes React and TypeScript (DESIGN §8.3).
- **Research:** context7 for Next.js, React and TypeScript. Official docs at nextjs.org/docs, react.dev and typescriptlang.org. Defaults from eslint-config-next and the `next lint` / ESLint flat config, as current docs describe them.
- **Must cover:**
  - the router model of the current major (server and client components, `'use client'` boundaries);
  - data fetching and caching as the current major defines them;
  - validating Server Actions and route handlers on the server, and authorising inside them;
  - keeping environment and secret handling server-only;
  - `next/image`, `next/link` and metadata;
  - TypeScript strictness;
  - React hooks rules;
  - the testing stack the official docs recommend (unit and component, plus end to end), with file placement and naming.
- **Checks:**
  - the shared seed check;
  - `grep -c "'use client'"` ≥ 1;
  - `grep -ci typescript` ≥ 3;
  - `grep -ci 'server action'` ≥ 1.
- **Commit:** `feat(stack-standards): add the Next.js seed`

### B4: `seeds/react.md`

- **files:** `skills/stack-standards/references/seeds/react.md`
- **depends_on:** [B1]
- **pattern:** B1's structure. This is plain React with TypeScript on a client build tool (the `react-vite` fixture), with no framework router assumptions.
- **Research:** context7 for React and Vite. react.dev (rules of React, hooks, the current major's changes), vite.dev and vitest.dev, and the Testing Library docs. eslint-plugin-react-hooks for the [tool] rules.
- **Must cover:**
  - component and hook naming;
  - the rules of hooks, and effects only for syncing with external systems;
  - state placement, and keys in lists;
  - XSS: `dangerouslySetInnerHTML` and untrusted URLs;
  - `VITE_`-prefixed environment variables, which are public;
  - accessible forms and labels;
  - Vitest with React Testing Library, queried by role, with file naming and placement.
- **Checks:**
  - the shared seed check;
  - `grep -c dangerouslySetInnerHTML` ≥ 1;
  - `grep -ci 'testing library'` ≥ 1;
  - `grep -c 'next/'` = 0, so no Next.js leakage.
- **Commit:** `feat(stack-standards): add the React seed`

### B5: `seeds/laravel.md`

- **files:** `skills/stack-standards/references/seeds/laravel.md`
- **depends_on:** [B1]
- **pattern:** B1's structure.
- **Research:** context7 for Laravel. laravel.com/docs for the current major (structure, validation, authorisation, Eloquent, queues, testing), and the Pint and Larastan (PHPStan) docs for the [tool] rules. php.net for the PHP version the current major requires.
- **Must cover:**
  - Form Requests for validation;
  - policies and gates for authorisation;
  - mass-assignment protection, plus Eloquent N+1 and eager loading;
  - CSRF, and Blade escaping (`{{ }}` against `{!! !!}`);
  - config and environment access (`config()` rather than `env()` outside config files);
  - exceptions and logging;
  - migrations;
  - the testing framework the current docs default to (Pest or PHPUnit), feature against unit directories, `RefreshDatabase`, and naming.
- **Checks:**
  - the shared seed check;
  - `grep -cE 'FormRequest|Form Request'` ≥ 1;
  - `grep -ci polic` ≥ 1;
  - `grep -c '{!!'` ≥ 1;
  - `grep -ci pint` ≥ 1.
- **Commit:** `feat(stack-standards): add the Laravel seed`

### B6: `seeds/wordpress.md`

- **files:** `skills/stack-standards/references/seeds/wordpress.md`
- **depends_on:** [B1]
- **pattern:** B1's structure, and AC-10's wordpress list.
- **Research:** context7 for WordPress. The official sources are:
  - developer.wordpress.org/coding-standards (PHP, JavaScript, CSS and HTML standards, plus the accessibility standard);
  - the Plugin and Theme Handbooks (security: escaping, sanitising, nonces, capabilities; i18n; enqueueing);
  - WPCS (`WordPress-Coding-Standards` for phpcs) for the [tool] rules;
  - `@wordpress/scripts` for JS and CSS linting and tests.
- **Must cover:**
  - PHP, JS and CSS per the WPCS;
  - sanitising early and escaping late (`esc_html`, `esc_attr`, `esc_url`, `wp_kses`);
  - nonces (`wp_nonce_field` / `check_admin_referer` / `wp_verify_nonce`) together with `current_user_can`;
  - `$wpdb->prepare`;
  - hooks, filters and child themes rather than core edits;
  - i18n functions with a literal text domain;
  - `wp_enqueue_script` / `wp_enqueue_style`, with no hard-coded `<script>`;
  - the prefixing or namespacing convention;
  - PHPUnit with the WP test scaffold (or the testing approach the handbook currently recommends), plus `@wordpress/scripts` tests, with naming.
- **Checks:**
  - the shared seed check;
  - each of `esc_html`, `wp_verify_nonce` (or `check_admin_referer`), `current_user_can`, `wp_enqueue_script`, `prepare(`, `add_action` and `__(` appears at least once;
  - `grep -ci 'text domain'` ≥ 1;
  - `grep -ci 'core'` ≥ 1, for the "hooks rather than core edits" rule.
- **Commit:** `feat(stack-standards): add the WordPress seed`

### B7: `seeds/woocommerce.md` (overlay)

- **files:** `skills/stack-standards/references/seeds/woocommerce.md`
- **depends_on:** [B1]
- **pattern:** B1's structure in the overlay variant (`Overlay on: wordpress`), and AC-10's woocommerce list. It holds only additions and overrides to wordpress.md. It must not repeat the WordPress basics.
- **Research:** context7 for WooCommerce. developer.woocommerce.com:
  - CRUD objects and data stores;
  - HPOS and the compatibility declaration;
  - extension guidelines and the plugin header (`WC requires at least`, `WC tested up to`, `Requires Plugins`);
  - template structure and overriding guidance;
  - Store API and blocks extensibility, where the current docs make it the default;
  - the WooCommerce testing docs.
- **Must cover:**
  - `wc_get_order` / `wc_get_product` with getters and setters plus `save()`, and `get_meta` / `update_meta_data`, rather than `get_post_meta` on orders;
  - declaring HPOS compatibility through `FeaturesUtil` on `before_woocommerce_init`, as currently documented;
  - hooks and filters rather than template overrides, and what an override has to track if one is unavoidable;
  - checking that WooCommerce is active, and the dependency headers;
  - security for order, customer and payment data (capabilities such as `manage_woocommerce`; never log PII);
  - accessibility of checkout and cart additions;
  - the testing approach.
- **Checks:**
  - the shared seed check;
  - `head -5 | grep -c '^Overlay on: wordpress'` = 1;
  - `declare_compatibility`, `custom_order_tables`, `wc_get_order`, `update_meta_data` and `get_post_meta` (as a don't) each appear at least once;
  - `grep -ci 'template override'` ≥ 1.
- **Commit:** `feat(stack-standards): add the WooCommerce overlay seed`

### B8: `seeds/tailwind.md` (overlay)

- **files:** `skills/stack-standards/references/seeds/tailwind.md`
- **depends_on:** [B1]
- **pattern:** B1's structure in the overlay variant. Tailwind is standalone-capable (A5), so its line is `Overlay on: any base profile (nextjs, react, laravel, wordpress)`. Add AC-10's tailwind list.
- **Research:** context7 for Tailwind CSS, and tailwindcss.com/docs for the current major. Find out how the current major configures itself (CSS-first theme variables against a JS config file) from the docs; don't assume. The official Prettier plugin for class sorting is the [tool] rule. Also the docs on reusing styles and extracting components.
- **Must cover:**
  - the current major's configuration approach and where it lives;
  - design tokens as theme variables, with no arbitrary values (`[#…]`, `[13px]`) when a token exists;
  - the class-soup rules: extract a component (framework component or partial) when a class list repeats N times (state N) or goes past a stated length; `@apply` only under the docs' guidance; never build class names dynamically by string concatenation;
  - focus-visible styles, contrast, and target size;
  - the `sr-only` / `motion-reduce` variants;
  - testing (visual and class-level conventions, if any; otherwise defer to the base).
- **Checks:**
  - the shared seed check;
  - `head -5 | grep -c '^Overlay on:'` = 1;
  - `grep -ci 'class soup'` ≥ 1;
  - `grep -ci 'extract'` ≥ 1;
  - `grep -ci 'prettier-plugin-tailwindcss'` ≥ 1;
  - `grep -c 'focus-visible'` ≥ 1;
  - the configuration mechanism named by the research appears at least once (for example `@theme` if the current major is CSS-first).
- **Commit:** `feat(stack-standards): add the Tailwind overlay seed`

## Phase exit check (run after B8; no separate task)

```bash
ls skills/stack-standards/references/seeds/ | sort | tr '\n' ' '      # = laravel.md nextjs.md react.md tailwind.md woocommerce.md wordpress.md (AC-9; AC-10 no C#)
ls skills/stack-standards/references/seeds/ | grep -ciE 'dotnet|csharp|c#'   # = 0
for s in skills/stack-standards/references/seeds/*.md; do printf '%s %s\n' "$(wc -l < "$s")" "$s"; done   # all <= 300
claude plugin validate .                                               # passes
```

## AC → task matrix

| AC | Tasks |
|---|---|
| AC-7 | B2 |
| AC-8 | B1 |
| AC-9 | B3–B8 (plus the phase exit check) |
| AC-10 | B3 (nextjs: React and TS), B6 (wordpress), B7 (woocommerce), B8 (tailwind), exit check (no C#) |

## Notes for Phase D and Phase E

- standards-setter and senior-engineer (Phase D) preload `aew:stack-standards`. Their prompts point to the B1 headings and the B2 statuses, and do not restate them.
- Phase E records in CHANGELOG and the project map:
  - the research date and whether context7 was available for each seed;
  - the heading contract, as a durable contract.

  B does not edit those files.
- No DECOMPOSE is needed: 8 tasks, no risk lines, and one wave of 7 parallel tasks after B1.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T13:56:58Z (plan-review, lean)
- Plan format: LEAN
- Plan dependency graph: valid. Wave count: 2. Max wave width: 7 tasks parallel.
- Plan content hash (SHA-256): c96474be6a818375fe8621e78d02b3011439dc4dde7a4c25d945e4b059912929 (of this doc before this trailer)
