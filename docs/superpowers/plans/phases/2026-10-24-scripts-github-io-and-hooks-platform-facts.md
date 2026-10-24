# Platform facts for Phase D (hooks), verified 2026-10-24

Source pages: H = https://code.claude.com/docs/en/hooks, S = https://code.claude.com/docs/en/sub-agents,
C = https://code.claude.com/docs/en/plugins/components. "Not documented" = not found in those pages.

1. **hooks.json shape (C, H).** `hooks/hooks.json` at the plugin root, top-level `"hooks"` key, same shape
   as settings.json: `{"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "...", "timeout": N}]}]}}`.
   Matcher optional. Optional top-level `description` allowed. `${CLAUDE_PLUGIN_ROOT}` is substituted in
   `command`, `args`, `env` (quote it in shell form). `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT` and
   `CLAUDE_PLUGIN_DATA` are exported to the hook process. Hook cwd: "the current directory" — exact cwd
   **not documented**; use stdin `cwd` / `CLAUDE_PROJECT_DIR` (project root where the session started).
2. **Events and matchers (H).** `PreToolUse`, `SubagentStop`, `SessionStart` spelled correctly. Matchers of
   only letters, digits, `_`, `-`, space, `,`, `|` are exact; anything else is an unanchored JS regex.
   `Bash` and `Edit|Write` are exact. `Edit.*` would also match `NotebookEdit` — anchor regexes. Whether
   `Write` covers `MultiEdit`/`NotebookEdit`: **not documented**. SessionStart `source` values:
   `startup`, `resume`, `clear`, `compact`, `fork`.
3. **SubagentStop (H, S).** Matcher matches `agent_type`. Plugin agents use the plugin-scoped identifier,
   e.g. `aew:developer` (not bare `developer`). A colon makes the matcher a regex, so anchor it:
   `^aew:developer$`. Stdin: common fields (`session_id`, `transcript_path`, `cwd`, `hook_event_name`,
   `permission_mode`, …) plus `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path`,
   `last_assistant_message`. Plugin agents ignore `hooks`, `mcpServers`, `permissionMode` frontmatter.
4. **PreToolUse (H).** Stdin: common fields plus `tool_name`, `tool_input`, `tool_use_id`. Bash:
   `tool_input.command`. Edit/Write: `tool_input.file_path` (always absolute). Preferred deny, on exit 0:
   `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}`.
   `permissionDecision`: `allow|deny|ask|defer`. Exit 2 also blocks (stderr = reason). Top-level
   `decision`/`reason` are **deprecated** for PreToolUse.
5. **SubagentStop block (H, S).** Stdout `{"decision":"block","reason":"..."}` on exit 0 keeps the subagent
   running with `reason` as its next instruction. Exit 2 also blocks. `stop_hook_active` is true when
   already continuing because of a stop hook. Documented cap: after 8 consecutive stop-hook continuations
   the next block is overridden (count resets on each tool call; `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises
   it). Stated for Stop; SubagentStop-specific wording **not documented**, same loop protections apply.
6. **SessionStart (H).** `hookSpecificOutput.additionalContext` (with `hookEventName: "SessionStart"`) is
   added as context; plain-text stdout is also added as context.
7. **Exit codes and stderr (H).** Exit 0: "Claude never sees stderr from a hook that exits 0"; stdout goes
   to the debug log (except SessionStart/UserPromptSubmit plain stdout → context). Exit 2: blocking,
   stderr shown to Claude. Other non-zero: non-blocking error, action proceeds, user sees first stderr
   line. So a fail-open warning on exit 0 is visible only in debug logs.
8. **Timeouts and parallelism (H).** Default `command` timeout 600 s (set an explicit small `timeout`).
   Matching hooks for an event run in parallel; ordering not documented.

Implications for the spec's assumptions: A4 (gate accepts both `aew:developer` and `developer`) is
harmless but the documented form is `aew:developer`; the hooks.json matcher should be anchored regex.
DESIGN §3's "eight consecutive blocks" matches the documented Stop cap.
