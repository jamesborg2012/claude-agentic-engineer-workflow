# #101 Newsletter sign-up in the site footer

- **URL:** https://github.com/acme/web/issues/101
- **State:** OPEN
- **Author:** @octo
- **Labels:** none
- **Milestone:** none
- **Assignees:** none

## Body

### Summary

Visitors can leave their email address to hear about new articles. Add a sign-up form to the existing site footer, which the root layout already renders on every page.

### Who can use it

Open to anyone, signed in or not. There is no login.

### Behaviour

- The field has a visible label, "Email address", with `type="email"` and `autocomplete="email"`, plus a "Subscribe" button.
- Leading and trailing whitespace is trimmed. The value must then have one `@`, a non-empty local part, a dot in the domain part, and 254 characters or fewer. The browser and the route use this same rule, from one shared module.
- Invalid input, whether caught in the browser or returned as a 400, shows the exact error copy "Enter a valid email address" below the field, linked with `aria-describedby`. The input gets `aria-invalid="true"` and keeps focus. Invalid input caught in the browser is not submitted.
- A valid submission POSTs `{ "email": "ada@example.com" }` (the trimmed address) to a new route, `POST /api/newsletter`. Its responses are:
  - `201 { "status": "subscribed" }` for a valid address;
  - `400 { "error": "invalid_email" }` for a missing or invalid email;
  - `413` for a request body over 1 KB;
  - `405` for any method other than POST.

  Nothing is stored in any case.
- While the request is pending, the button is disabled and reads "Subscribing…".
- On a 201, the form is replaced by "Thanks, you're subscribed." On a network error or a 5xx, the message is "Something went wrong. Please try again." and the input keeps its value.
- Resubmitting the same address is allowed and gives the same success.

### Accessibility

- WCAG 2.2 AA.
- Error and success messages are announced through an `aria-live="polite"` region.
- The form is fully keyboard operable, with a visible focus indicator, and text meets 4.5:1 contrast.
- An axe scan shows no serious or critical violations at the 1440×900 and 390×844 viewports.

### Constraints

- No new runtime dependency.
- Tailwind utilities only, with no new CSS file.

### Out of scope

- storing or forwarding addresses (the route validates and responds only, and logs nothing);
- any mailing provider;
- double opt-in;
- rate limiting;
- analytics;
- translations (English copy only).

### Acceptance criteria

1. Every page's footer shows a form with a visible "Email address" label, an email input and a "Subscribe" button.
2. A valid address (after trimming) is accepted by `POST /api/newsletter`, which returns `201 { "status": "subscribed" }`, including for an address that was already submitted.
3. A missing or invalid email returns `400 { "error": "invalid_email" }`, a body over 1 KB returns `413`, any method other than POST returns `405`, and nothing is stored.
4. Invalid input shows "Enter a valid email address" below the field, linked with `aria-describedby`, with `aria-invalid="true"` set and focus kept on the input.
5. While the request is pending, the button is disabled and reads "Subscribing…"; after a 201, the form is replaced by "Thanks, you're subscribed.", announced through a polite live region.
6. After a network error or a 5xx, "Something went wrong. Please try again." is announced through the polite live region and the input keeps its value.
7. The form is keyboard operable with a visible focus indicator and 4.5:1 text contrast, and an axe scan shows no serious or critical violations at the 1440×900 and 390×844 viewports.

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
