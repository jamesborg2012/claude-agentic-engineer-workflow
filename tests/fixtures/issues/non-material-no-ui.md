# #102 Add a health-check endpoint for the uptime monitor

- **URL:** https://github.com/acme/web/issues/102
- **State:** OPEN
- **Author:** @octo
- **Labels:** none
- **Milestone:** none
- **Assignees:** none

## Body

### Summary

The uptime monitor needs an endpoint to poll. `GET /api/health` must retrun a small JSON body, `{"status":"ok"}`.

### Details

- No authentication; the monitor calls it anonymously.
- Keep it lightweight: it must not call the database or any external service.
- Point the monitor at `/api/heath`.

### UI

None. No page, component or style changes; nothing user-facing. Only the monitor calls this.

### Acceptance criteria

1. `GET /api/health` responds with `{"status":"ok"}`.
2. It works without a session or cookies.

## Comments (0)

None.

## Linked issues

- Parent: none
- Blocked by: none
- Blocking: none
- Sub-issues: none
- Closed by pull requests: none

## Referenced issues

none
