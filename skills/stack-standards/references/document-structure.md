# Standards document structure

The section contract shared by generated standards docs (`docs/standards/<profile>.md`) and the
plugin's seeds (`skills/stack-standards/references/seeds/<profile>.md`). The standards-setter merges
seed, overlay and repo findings section by section, so the headings below are fixed: same text, same
order, no extras.

## Header

A generated doc starts with this comment on line 1. It is not a heading.

```
<!-- aew:standards fingerprint="<profile> <dep>@<major>… cfg:<hash12>" generated="YYYY-MM-DD" -->
```

Reuse means an exact string match on `fingerprint`. A seed has no such header (see Seeds).

Directly below line 1, before the first `##` heading, come these plain lines (none of them is a
heading), in this order:

- `Overlay on: <base>`, for an overlay only;
- `Sources: <the configs read>; sampled <the files sampled>; seed <profile> (or "no seed"); context7 <libraries queried> (or "not used" or "unavailable")`;
- `Changes (YYYY-MM-DD): <old rule> → <new rule>, because <config or major>; …`, for an updated doc
  only. It replaces any earlier `Changes` line, and reads `Changes (YYYY-MM-DD): none` when nothing
  was replaced.

## Required headings

Every doc uses these level-2 headings, once each, in this order, and no other level-2 headings.
(The headings of this file itself are not part of the contract.)

| Heading | What belongs in it |
|---|---|
| `## Tooling and commands` | Build, lint, format, type-check and test commands, and the config files behind them. |
| `## Project structure` | Directory layout, where each kind of file lives, module boundaries. |
| `## Naming` | Files, symbols, routes, tests, branches where the stack has a norm. |
| `## Language idioms` | Language-level style and features to prefer or avoid. |
| `## Framework conventions` | Framework-specific patterns: routing, data access, components, hooks, lifecycle. |
| `## Error handling` | How errors are raised, caught, logged and shown. |
| `## Security` | The stack's real attack surface: input, output, auth, secrets, dependencies. |
| `## Accessibility` | Opens by stating the target, WCAG 2.2 AA, then stack-specific practice. |
| `## Testing conventions` | Framework, test organisation (directory or co-location), file and case naming. |
| `## Documentation and comment standards` | What to document, comment style, docblocks, changelog expectations. |
| `## Anti-patterns` | Common mistakes in this stack, each with the correct alternative. |

## Rules

Each rule is a bullet that starts with its marker:

- **[tool]**: in a generated doc, enforced by a linter, formatter or type checker that the repo's
  configs actually run. In a seed, enforced by the stack's default or official tooling. Either way,
  name the tool or rule.
- **[convention]**: everything else.

Form: `- **[tool]** <rule> (<tool or rule id>)` or `- **[convention]** <rule>`.

## Examples

Give a concrete, stack-specific example where a rule is easy to get wrong. Each example is a pair:
a `Do:` line, then a fenced code block, then a `Don't:` line, then a fenced code block. Each label
stands alone on its line, so `Do:` and `Don't:` lines appear in equal numbers.

````
Do:
```ts
const total = items.reduce((sum, i) => sum + i.price, 0);
```
Don't:
```ts
let total = 0; for (var i in items) total += items[i].price;
```
````

## Size

About 400 lines for a generated doc. 300 or fewer for a seed. Prose is British English; code
identifiers stay as the API spells them.

## Seeds

A seed replaces the fingerprint header with a line near the top (within the first five lines):

```
Versions covered: <versions> (researched YYYY-MM-DD; sources: <urls or "context7">)
```

An overlay seed (for example `woocommerce`, `tailwind`) adds `Overlay on: <base>` and keeps all 11
headings. A section with nothing to add reads "No overlay additions; see the base profile." Seeds
mark **[tool]** only where the stack's default or official tooling enforces the rule.

## Overlays in generated docs

An overlay has its own doc, with `Overlay on: <base>` directly below the header. All 11 headings
stay, with "No overlay additions" where empty. Precedence: repo conventions > overlay > base.

## Index: `docs/standards/README.md`

One row per doc:

| Profile | Doc | Path(s) | Overlay on | Fingerprint | Generated |
|---|---|---|---|---|---|

Followed by one line: precedence is repo conventions, then overlay, then base.
