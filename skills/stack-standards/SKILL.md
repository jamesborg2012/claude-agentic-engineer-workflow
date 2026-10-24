---
name: stack-standards
description: How aew detects a project's stacks, fingerprints them, and reads or writes the per-stack standards docs in docs/standards/. Use it when running detect-stack.sh, deciding whether a standards doc is reused, updated or generated, merging a base profile with overlays, or reading the plugin's seed references.
user-invocable: false
---

# aew stack standards

Shared procedure for the standards-setter (writes `docs/standards/`) and the senior-engineer and
brief-compiler (read it). The section contract for every doc and seed is in
[references/document-structure.md](references/document-structure.md).

## 1. Detection

Run from the project root:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" [path]
```

`path` (default `.`) is the root to scan. Stdout is one JSON array, for example
`[{"profile":"nextjs","path":".","version":"16.0.1","evidence":["package.json: next ^16.0.1"]}]`.

- Keys: `profile`, `path` (relative, `.` for the root), `version` (or `"unknown"`), `evidence`.
- Order: by `path` (`.` first), then base before overlay, then profile name.
- Base profiles: `nextjs`, `react`, `laravel`, `wordpress`, `dotnet`. Overlays: `tailwind`, `woocommerce`.
- `[]` means no stack was detected: write no standards docs and say so in `03-standards.md`.
- Exit 1 with `error:` on stderr is a real failure. Warnings on stderr are not.

## 2. Fingerprint

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" fingerprint <profile> .
```

Run once per profile, from the project root, with the same root as detection. It prints one line,
`<profile> <dep>@<major>… cfg:<hash12>`, for example `nextjs next@16 react@19 typescript@5 cfg:1a2b3c4d5e6f`.
The `cfg` hash covers the profile's tool configs, never the manifests, so a minor dependency bump
does not change the line.

Line 1 of `docs/standards/<profile>.md` is the header:

```
<!-- aew:standards fingerprint="<line>" generated="YYYY-MM-DD" -->
```

- Reuse means an exact string match between the header's `fingerprint` and the new line.
- A profile found at several paths gets one doc, fingerprinted from its first path in detection order.
  The script does this, so never pass an entry's `path`.
- Tailwind churn: the `tailwind` hash includes the CSS file holding `@import "tailwindcss"`, so any
  edit to that file marks `tailwind.md` as updated. That fails safe (no stale doc) and is accepted.

## 3. Reuse, update or generate

| Status | When | What you write |
|---|---|---|
| `reused` | Doc exists and the fingerprint matches | Nothing in the doc. |
| `updated` | Doc exists and the fingerprint differs | Re-derive [tool] rules from the configs. Keep [convention] rules and hand edits unless a new config or major contradicts them. Refresh the header. |
| `generated` | No doc for the profile | A new doc from the sources in section 5, with the header. |

The setter never commits; the orchestrator or init commits the docs. Always keep
`docs/standards/README.md` current: one row per doc with its profile, fingerprint and status.

## 4. Merging a base with overlays

- An overlay (`tailwind`, `woocommerce`) has its own doc, opening with `Overlay on: <base>`, holding
  only additions and overrides.
- Precedence: the overlay beats the base, and the repo's own conventions beat both.
- Merge section by section using the headings in the document-structure reference.
- `03-standards.md` lists the base and overlay docs together, with the sections that apply to the brief.

## 5. Source priority

Use these four sources, in this order (DESIGN §8.3). Earlier sources win.

1. repo tool configs (eslint, prettier, tsconfig, phpcs.xml, pint.json, phpstan, stylelint, .editorconfig, Directory.Build.props, .csharpierrc…)
2. patterns sampled from existing code
3. the plugin's seed reference for the profile
4. context7 for version-specific guidance

A seed rule keeps its **[tool]** marker only if the repo's configs enforce it; otherwise re-mark it
**[convention]**. Repo patterns beat seeds. If context7 is unavailable, say so in `03-standards.md`.

## 6. Seeds

Give the path in full; `${CLAUDE_SKILL_DIR}` is equivalent to `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards`.

| Profile | Seed |
|---|---|
| `nextjs` | `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/nextjs.md` |
| `react` | `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/react.md` |
| `laravel` | `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/laravel.md` |
| `wordpress` | `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/wordpress.md` |
| `woocommerce` | `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/woocommerce.md` |
| `tailwind` | `${CLAUDE_PLUGIN_ROOT}/skills/stack-standards/references/seeds/tailwind.md` |

`dotnet` has no seed. Generate its doc from sources 1, 2 and 4 only (DESIGN §8.3, §13).

A seed has a `Versions covered:` line instead of the fingerprint header. Copy its rules into the
generated doc, never the line.

## 7. References

- [references/document-structure.md](references/document-structure.md): headings, rule markers, examples, sizes.
