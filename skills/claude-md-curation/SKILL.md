---
name: claude-md-curation
description: Rules and procedure for curating a project's CLAUDE.md after a run - what belongs in it, what never does, the entry format, the size cap and the prune steps. Use it when the doc-writer updates CLAUDE.md or when deciding whether a learning is worth recording.
user-invocable: false
---

# CLAUDE.md curation

Shared procedure for the doc-writer, which curates the target project's `CLAUDE.md` at the end of a run.
CLAUDE.md is loaded into every session, so each line costs context. It is curated as a whole file, not
appended to.

## 1. Rules

- Record only durable, non-obvious, project-specific learnings: commands, gotchas, architecture
  decisions and discovered conventions.
- Edit and prune before appending. Fix or remove an existing entry before adding a new one.
- Stay within the size cap (section 4).
- Link to `docs/` for detail. An entry states the fact in one line and points to where to read more.
- Never duplicate the standards docs in `docs/standards/`. If a rule lives there, link to it or omit it.

## 2. Entry format

One bullet per learning: a fact, then where to read more. Group bullets under these headings:

- `## Commands`: how to build, test, run or deploy when it is not obvious.
- `## Gotchas`: traps that cost time and cannot be seen from the code.
- `## Architecture decisions`: a choice and the reason, with a link to the spec or doc.
- `## Conventions`: discovered, project-specific habits that differ from the standards.

Keep the project's existing headings. Do not rename or reorder them. Add a heading from the list above
only when an entry needs one and no existing heading fits.

## 3. Never include

- Secrets: keys, tokens, passwords, connection strings, personal data.
- Run logs: test output, command transcripts, stack traces, anything from `.aew/runs/`.
- Anything already in the standards docs.
- Anything obvious from the code: file layouts, names, what a function does.
- Anything time-bound: dates, "currently", ticket status, temporary workarounds with no removal condition.

## 4. Size cap

The cap is `claude_md.max_lines` from `.aew/config.json`, or 300 when it is unset (the schema default).
Count lines by reading the file; the doc-writer has no Bash. The cap applies to the whole file after
curation, not to the new entries.

## 5. Examples

Good:

1. `- E2E tests need the dev server on port 4173; start it with npm run preview before npm run test:e2e. See docs/standards/web.md for the test layout.`
   Good because it is a command that cannot be guessed, and the entry links out for detail.
2. `- Orders are soft-deleted; queries must use withTrashed() for reports (see docs/specs/12-order-archive.md).`
   Good because it is a gotcha invisible from a single file, with a pointer to the reasoning.
3. `- Prices are stored as integer pence and converted only in the view layer (decision: docs/specs/8-pricing.md).`
   Good because it records an architecture decision with its reason's location, and one line holds it.

Bad:

1. `- Use strict TypeScript and avoid any.`
   Bad because it restates a standards rule that already lives in `docs/standards/`.
2. `- As of March the staging API is flaky, so retry failed requests.`
   Bad because it is time-bound: it will be wrong soon and nobody will know when to delete it.
3. `- The components live in src/components and each has a test next to it.`
   Bad because it is obvious from the code; reading the tree tells the same thing for free.
4. `- Last run: 42 tests passed, 3 skipped (output pasted below).`
   Bad because it is a run log; it goes stale immediately and belongs in the run artefacts.

## 6. Prune procedure

Follow these steps in order. Every file is curated whole, including entries a human wrote.

1. Read the whole file.
2. Drop every item on the never-include list.
3. Merge duplicates and near-duplicates into one entry.
4. Rewrite stale entries against the code. If an entry is wrong and cannot be corrected, remove it.
5. Only then append the new learnings from this run, in the entry format.
6. Recount against the cap. While it is over, drop the least durable entries (time-sensitive first,
   then the most obvious from code) until it fits.

## 7. Reporting

Never remove or rewrite silently. Return to the caller a list of every removed or rewritten entry: the
original text, what happened to it (removed, merged, rewritten) and the reason. The doc-writer copies
this list into `10-summary.md`.
