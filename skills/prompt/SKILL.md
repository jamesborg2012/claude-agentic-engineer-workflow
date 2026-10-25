---
name: prompt
description: Turn one GitHub issue into a single self-contained prompt (prompt.md) for a plain Claude Code session - spec analysis with the same material-change gate as ship, then the brief compiler in prompt mode. No branch, no commits, no stage labels. Run it as /aew:prompt <issue>.
disable-model-invocation: true
argument-hint: "<issue>"
---

# aew prompt

This is the main-thread procedure that writes `prompt.md`, one self-contained prompt for a plain Claude Code session (DESIGN §8.2, prompt mode). It creates no branch, makes no commit and sets no stage label. Its only GitHub writes are a recorded spec revision and, if James agrees, a comment carrying `prompt.md`.

## Plugin root

The plugin root is `${CLAUDE_PLUGIN_ROOT}`.

- Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names under `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/` with Read, when a step below says so.
- In those files, read every literal `${CLAUDE_PLUGIN_ROOT}` as this root. A bare `state.sh …` or `gh-issue.sh …` is that root's `scripts/` file, called by its absolute path written out in the command.
- Never invoke `ship` with the Skill tool: it sets `disable-model-invocation: true`, which blocks it. Read its files instead.

## Rules

- `SKILL.md` `## Rules` (ship's) apply here, except that this skill creates no branch, makes no commit, sets no stage label (`gates.md` `## Gate ids and pending state`, the prompt-mode rule) and runs no working-tree or default-branch check.
- Run every command from the project root and never `cd`.
- A gate's answer comes only from AskUserQuestion on the main thread. Never take it from an agent, and never invent one.
- Citations: `SKILL.md` is `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md`, and `preflight.md`, `dispatch.md` and `gates.md` are in its `references/` directory.

## Step 1. Parse the argument

The argument is: `$ARGUMENTS`.

It must be exactly one token matching `^[1-9][0-9]*$`. Otherwise print one of these lines, then `Usage: /aew:prompt <issue>`, and stop:

- No token: `aew prompt: missing issue number.`
- First token not a positive integer: `aew prompt: the issue must be a positive integer, got "<token>".`
- A second token: `aew prompt: unexpected argument "<token>".`

Nothing runs and nothing is written in this step. `<n>` is the issue number from here on.

## Step 2. Preflight

Read `preflight.md`. Run `preflight.md` `## Check 1. Config exists`, then `preflight.md` `## Check 3. gh is authenticated`, then `preflight.md` `## Check 5. No other active run`, in that order, each with its own message. Run no other check: nothing is committed or branched.

## Step 3. Start the run

Read ship's `SKILL.md`. Run `SKILL.md` `## Step 3. Start the run` sub-steps 3.1 to 3.5 only, and skip 3.6 to 3.8 (the label, the branch and the stage entry). Overrides:

- 3.1 stops with `Run <n> already exists, and aew prompt only starts new runs: check it with /aew:status <n>.`
- Straight after 3.2 and before 3.3, write the prompt marker: `state.sh stage spec_analysis --note "prompt"`. It is also the state write for D1. Because it comes before the fetch, a run that fails at 3.3 or 3.4 is still marked as a prompt run.
- 3.3 and 3.4 keep their state writes but print `Could not fetch issue #<n>: <reason>. Fix it, remove .aew/runs/<n>, then run /aew:prompt <n> again.` and stop.

Then go to Step 4 at sub-step 2 (the entry is done).

## Step 4. Analyse the spec

1. Entry, on resume only: `state.sh stage spec_analysis --note "resume"`.
2. Check the required files (`dispatch.md` `## Required inputs per stage`). A missing file goes to `## Stopping`, naming it.
3. Dispatch row D1 (`dispatch.md` `## Dispatch table`, `dispatch.md` `## How to dispatch`).
4. Return check: `dispatch.md` `## Return check`, with `dispatch.md` `## Retries`.
5. Exit:
   - `ok`: run `gates.md` `## Recording a spec revision` (it sets the `spec-revised` flag when a revision is recorded), then go to Step 5.
   - `needs_input`: run `gates.md` `## Gate: spec` under the prompt-mode rule. At its step 4 the D2 re-dispatch returns here, to sub-step 4, and never to ship's spec-analysis exit, which would go on to D3. With no answer, follow `SKILL.md` `## Gate pending`: the run stays pending and `/aew:resume` continues it.
   - `blocked` or `failed` after the retry: `## Stopping`.

## Step 5. Compile the prompt

1. Entry: `state.sh stage brief` (D4's state write; add `--note "resume"` on resume). No label.
2. Check the required files: `spec-final.md` and `issue.json`.
3. Dispatch row D4, which sends `mode: prompt`.
4. Return check on the Agent result only (`prompt.md` carries no return block in the file), then `test -f .aew/runs/<n>/prompt.md && echo yes || echo no`, which must print `yes`.
5. `ok` goes to Step 6. Anything else after the retry goes to `## Stopping`.

## Step 6. Finish

1. `state.sh status done --note "prompt written"`, then `state.sh current clear`.
2. Print `Prompt written: .aew/runs/<n>/prompt.md`, the spec version (and whether a revision was recorded), and `To build it with aew instead: /aew:ship <n> --from spec_analysis.`
3. Offer to post it with AskUserQuestion: one question, `Post prompt.md as a comment on issue #<n>?`, with the options `Post it` and `Do not post`. If AskUserQuestion is not among your tools (a headless run), is refused, returns an empty answer or `Do not post`, print `Not posted.` and stop. Do not try to call a tool you do not have.
4. On `Post it`: `gh-issue.sh comment <n> .aew/runs/<n>/prompt.md`, and print the comment URL it prints. A failure prints a warning with the first stderr line; the run stays `done`.

## Stopping

Reached when an agent returns `blocked` or `failed` after the one retry, or when a script fails after Step 3 (for example a `gh-issue.sh revise` refusal).

1. `state.sh status blocked --note "<reason, one line>"`. Keep `current`.
2. Print `aew prompt #<n>: blocked at <stage>: <reason>.` then `Resume with /aew:resume <n>`, and stop.

Post no issue comment and set no label: prompt mode sets no stage labels.

If the failure was at the fetch (`issue.json` is missing), resuming cannot work. Print instead: `Remove .aew/runs/<n> and run /aew:prompt <n> again.`
