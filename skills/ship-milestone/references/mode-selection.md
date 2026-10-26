# Mode selection

Read at `ship-milestone/SKILL.md` `## Step 4. Choose the mode`, after `select` has run and nothing has been written. This file writes nothing: no state, label, branch, run directory or `gh` write. Read every `${CLAUDE_PLUGIN_ROOT}` in this file as the plugin root stated in `ship-milestone/SKILL.md` `## Plugin root`. `<m>`, `<mn>`, `<title>`, `mode`, `auto` and the `select` output are the run variables of `ship-milestone/SKILL.md` `## Run variables`.

## The script's recommendation

Start from `select`'s `recommend` and `reasons`. The script has already applied the criteria (more than five open issues, an issue with more than five acceptance criteria or no list at all, a blocking dependency). Never recompute them, and never count acceptance criteria yourself. `reasons` is empty exactly when `recommend` is `bulk`.

## Judgement

Only when `recommend` is `bulk`. Otherwise skip this section.

Judge "same area" and "low risk" from the issue titles and labels in `select`'s `issues`, and from nothing else: open no issue body and run no spec analysis. Each judgement can only turn bulk into sequential, never the other way, and only on a clear signal:

- Same area: the labels or titles name different parts of the product, for example two different `area:` labels.
- Low risk: a title or label names a risky change, such as authentication, payments, security, a data migration or schema change, deleting data, infrastructure or deployment, or a dependency upgrade.

Missing labels or vague titles never change the recommendation. Three small, related issues with no labels stay bulk.

Each signal that fires switches `recommend` to `sequential` and adds one reason, starting `judgement:`, for example `judgement: #12 and #14 carry different area labels` or `judgement: #15 is a payments change`.

## Rationale

Print this block before any question or mode line, in this order:

1. `aew ship-milestone m-<mn> <title>: <count> open issue(s), recommended mode <bulk|sequential>.`, where `<count>` is the length of `issues` and the mode is the one after `## Judgement`.
2. One paragraph in plain English naming every reason (the script's and any `judgement:` ones), or, for bulk, why bulk fits: few issues, each small, no blocking dependencies. When `cycle` is non-null or `stack_conflicts` is non-empty, name it here and add that sequential mode would stop here.
3. When the recommendation is sequential: `Order: #a → #b → #c` from `order` (or `Order: none (dependency cycle)` when `order` is null), then `Stacked: #b on #a, …` from the issues whose `stack_on` is set (or `Stacked: none`).
4. When `closed` is non-empty: `Closed and left out: #x, …`.

## Ask

Ask only when AskUserQuestion is among your tools. It exists on the main thread only and is removed in headless runs; do not try to call a tool you do not have. If it is absent, go to `## No answer`.

Call it once, with one question:

- Question: `How should aew run milestone m-<mn> <title>?`
- Header: `Mode`
- Options, in this order. The recommended mode first, its label ending ` (recommended)`:
  1. `Bulk (recommended)` or `Sequential (recommended)`. For bulk the description is "One branch, one pipeline, one PR closing every issue." For sequential it is "One ship run per issue in order, with stacked PRs where one builds on another."
  2. The other mode, with its description from the line above and no suffix.
  3. `Stop`: "Stop now. Nothing has been written."

The tool adds free-text "Other" itself. `--auto` does not answer this question: it only skips plan gates.

Apply the answer, the chosen label without ` (recommended)`:

- `Bulk` or `Sequential`: set `mode` and go on to `## Cycles and stack conflicts`.
- `Stop`: print `aew ship-milestone m-<mn>: stopped at the mode question; nothing was written.` and stop.
- Free text, a refusal or an empty answer: go to `## No answer`. Never guess a mode from free text.

## No answer

The tool is absent (headless), refused, or the answer was empty or free text. Print, then stop:

`Rerun with /aew:ship-milestone <mn> --<recommended> (or --<other>).`

Put ` --auto` after each flag when `auto` is true. The line uses the milestone number, so a title never needs quoting. Nothing has been written.

## Mode given

When `--bulk` or `--sequential` was given, `mode` is already set. Print `Mode: <mode> (given)`.

With `--bulk` and a script `recommend` of `sequential`, also print one line per script reason, none for `judgement:` reasons (judgement does not run when a flag is given):

`Warning: <reason>; --bulk was given, so the run goes ahead in bulk.`

Keep each warning for the final report. Ask no question and run no judgement. Then go on to `## Cycles and stack conflicts`.

## Cycles and stack conflicts

Runs after `mode` is fixed, because bulk runs every issue on one branch and ignores both.

**Sequential.** A non-null `cycle` or a non-empty `stack_conflicts` stops the run before anything is written. Print every matching line, then stop. This is the stop that asks James to fix GitHub, in its message and not through AskUserQuestion, since no answer could fix the links from inside the run.

- For a non-null `cycle`, with `#a, #b` the numbers in `cycle`:
  `aew ship-milestone m-<mn>: dependency cycle between #a, #b. Break one of these dependency links on GitHub, then rerun /aew:ship-milestone <mn> --sequential.`
- For each entry of `stack_conflicts`, with `#a and #b` its `deps`:
  `aew ship-milestone m-<mn>: #<k> depends on #a and #b, which are not one chain, so one branch cannot hold both. Add a dependency link between them (or remove one) on GitHub, then rerun /aew:ship-milestone <mn> --sequential.`

**Bulk.** Print one warning each, keep them for the final report, then continue to `ship-milestone/SKILL.md` `## Step 5. Start the run`:

- For a non-null `cycle`: `Warning: dependency cycle between #a, #b is ignored: bulk runs every issue on one branch.`
- For each entry of `stack_conflicts`: `Warning: #<k>'s stack conflict is ignored: bulk runs every issue on one branch.`

With neither present, continue to Step 5 without output.
