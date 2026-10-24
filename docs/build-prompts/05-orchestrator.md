# Prompt 05 — Orchestrator and entry skills

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. That includes:
  - skill frontmatter (`disable-model-invocation`, argument handling and `$ARGUMENTS`, allowed tools);
  - how a skill dispatches plugin agents, including parallel dispatch in one message;
  - AskUserQuestion behaviour.

  Use the claude-code-guide agent; don't rely on memory. If the docs contradict DESIGN.md, follow the docs, update DESIGN.md in the same commit, and call it out.
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
Build the user-facing skills that tie the scripts and agents into the pipeline in DESIGN §7.3 and §9: `init`, `ship`, `resume`, `status` and `prompt`.

## Deliverables
1. **`skills/init/`** (`disable-model-invocation: true`). Idempotent: re-running updates rather than duplicates.
   1. Check prerequisites:
      - git;
      - `gh auth status`;
      - jq;
      - Node ≥ 20;
      - the stack tools for each detected profile.

      Say what's missing and how to install it; don't install global tools yourself.
   2. Create the `chore/aew-init` branch.
   3. Detect the stacks (`detect-stack.sh`). Discover commands from `package.json` scripts, composer scripts, `artisan`, wp-env or ddev config, and `.csproj`.
   4. Propose the config values. Confirm the uncertain ones with me in one AskUserQuestion round.
   5. Write `.aew/config.json` and validate it against the schema.
   6. Run `gh-labels.sh ensure`.
   7. Add `.aew/runs/` to `.gitignore`.
   8. If the project has UI and no Playwright, offer to set it up per the ui-qa skill. Ask before installing dependencies.
   9. Add a short "Agentic workflow" section to CLAUDE.md that points at `docs/standards/` and `docs/specs/`.
   10. Propose a project `.claude/settings.json` permissions allowlist for this workflow (git, gh, the project's package managers and test commands). Show it and ask before writing.
   11. Run standards-setter.
   12. Commit, push the branch, and open the PR.
2. **`skills/ship/`**, the orchestrator (`disable-model-invocation: true`).
   - Keep `SKILL.md` as the procedure, and put the detail in `references/`:
     - `preflight.md`
     - `dispatch.md` (exact inputs per agent)
     - `gates.md`
     - `routing.md` (the triage table and cycle limits)
     - `pr.md`
     - `final-report.md`
   - It must:
     - parse `$ARGUMENTS`: an issue number (required), `--auto`, and `--from <stage>`, with clear errors on bad input;
     - run the preflight in DESIGN §9;
     - also in preflight: warn, without blocking, if the installed superpowers major version differs from the one this plugin was built against (DESIGN §4). Superpowers can't be range-pinned, so this is the early warning for upstream changes.
     - fetch the issue, initialise state, set `current`, set the stage labels, and create the branch;
     - dispatch each agent with explicit file inputs, reading only its return block. Run QA phase A and the senior engineer's plan **in parallel** (one message, two agent calls).
     - **Material spec change gate** (always on): ask via AskUserQuestion with the recommended answers, then send the answers back to the spec-analyser to finalise. Record the result with `gh-issue.sh revise`, `comment` and the `spec-revised` flag.
     - **Plan gate**, unless `--auto` or `gates.plan_approval: false`: a plan summary of 25 lines or fewer plus the file path, with options approve / request changes (back to the senior engineer with my notes) / stop.
     - run the review loop, up to `max_review_cycles`;
     - run the QA loop with triage routing, up to `max_fix_cycles`;
     - on blocked: post a report comment, set the blocked label and stop cleanly with state saved;
     - at the end:
       - the doc-writer commits;
       - `git-branch.sh push`;
       - `gh-pr.sh create` with `pr-body.md`;
       - `gh-issue.sh manual-tests` plus its flag, if needed;
       - `gh-retro.sh file`;
       - the `ready-for-review` label;
       - state set to `done` and `current` cleared;
     - finish with the final report in DESIGN §9.
   - **Context hygiene:** the orchestrator never reads full artefacts except the plan (for the gate) and failure lists (for routing).
3. **`skills/resume/`:** reads the state, verifies the branch and a clean tree (or explains what's dirty), and continues `ship` from the recorded stage, re-asking any pending gate.
4. **`skills/status/`:** read-only. Shows the state, the last 10 lines of the log, the cycles used, and the next action. Without an argument it lists every run under `.aew/runs/`.
5. **`skills/prompt/`:** fetch → spec-analyser (with the same material-change gate and recording) → brief-compiler in prompt mode. It prints the path to `prompt.md` and offers to post the prompt to the issue as a comment.
6. **README:** add the command reference and a Mermaid flow diagram of the pipeline.

## Acceptance criteria
- **Static checks:**
  - every agent, script, template and reference these skills mention exists;
  - every stage in DESIGN §7.3 has an entry, an exit and a failure path in `ship`;
  - bad arguments give clear messages.
- **Simulated run.** Use the `gh` PATH shim from prompt 02 and a local fixture git repo. `/aew:ship 1 --auto` on the clean fixture issue must:
  - complete every stage through PR creation (mocked);
  - record the expected `gh` calls;
  - leave a valid `state.json` with status `done`.
- **Simulated gates:** the material-ambiguity fixture stops at the spec gate, and a run without `--auto` stops at the plan gate.
- **Simulated resume:** kill a run during `develop` and resume it. It continues from `develop` without redoing earlier stages.
- **init:** run on the nextjs-tailwind fixture repo, it produces a config that validates, and a second run changes nothing.
- Record the results in `tests/agent-smoke/README.md`. Real GitHub runs happen in prompt 07.
