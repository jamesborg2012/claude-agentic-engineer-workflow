# Brief: #101 Newsletter sign-up in the site footer

Source: spec-final.md (v1)

## Goal

Visitors can subscribe to the newsletter from the footer of every page, so they hear about new articles.

## Context

A Next.js App Router site styled with Tailwind (the `nextjs-tailwind` fixture). The root layout in `app/layout.tsx` already renders the footer element on every page. There is no auth and no database, and no email provider yet. This issue stops at a validated subscribe endpoint that a later issue wires to a provider.

## Acceptance criteria

- **AC-1** [UI] Given any page, when it loads, then the footer shows a form with a visible label "Email address", an email input (`type="email"`, `autocomplete="email"`) and a "Subscribe" button.
- **AC-2** [API] Given a valid address (for example `ada@example.com`, including one already submitted), when a client sends `POST /api/newsletter` with the JSON body `{ "email": "ada@example.com" }`, then the response is 201 with `{ "status": "subscribed" }`. Valid means, after trimming leading and trailing whitespace, one `@`, a non-empty local part, a dot in the domain part, and 254 characters or fewer.
- **AC-3** [API] [SEC] Given a missing or invalid `email`, when a client sends `POST /api/newsletter`, then the response is 400 with `{ "error": "invalid_email" }`; a body over 1 KB returns 413; any method other than POST returns 405; and nothing is stored in any case.
- **AC-4** [UI] [A11Y] Given a valid address, when the visitor submits the form, then the button is disabled and reads "Subscribing…" while the request is pending, and after a 201 the form is replaced by "Thanks, you're subscribed." in a polite live region.
- **AC-5** [UI] [A11Y] Given invalid input, whether caught in the browser (and then not submitted) or returned as a 400, when the visitor submits, then the inline error "Enter a valid email address" appears below the input, linked with `aria-describedby` and announced through the polite live region, and the input gets `aria-invalid="true"` and keeps focus.
- **AC-6** [UI] Given a network error or a 5xx response, when the visitor submits a valid address, then "Something went wrong. Please try again." appears in the polite live region and the input keeps its value.
- **AC-7** [A11Y] Given the footer form, when it is used by keyboard and scanned with axe at the 390×844 and 1440×900 viewports, then every control is operable with a visible focus indicator, its text meets 4.5:1 contrast, and the scan shows no serious or critical violations.

## Non-goals

- Storing or forwarding addresses: the route validates and responds only, and logs nothing.
- Any mailing provider.
- Double opt-in.
- Any rate limiting.
- Analytics.
- Any translations (English copy only).

## Constraints

- The client and the server validate with the same rule, from one shared module (one source of truth).
- The API contract in AC-2 and AC-3 is fixed.
- No new runtime dependency.
- Tailwind utilities only, no new CSS file.
- Accessibility target: WCAG 2.2 AA.

## Affected surfaces

- `app/layout.tsx` (the footer element).
- New `app/api/newsletter/route.ts`.
- New shared `lib/newsletter.ts` (validation).
- New `components/newsletter-form.tsx` (client component).

## Test data and accounts needed

None (anonymous visitor). Valid addresses: `ada@example.com`, `  ada@example.com  ` (trimmed). Invalid addresses: an empty string, `ada`, `ada@example`, `@example.com`, `ada@@example.com`, and an address of 255 characters.

## UI changes: yes

## Definition of Done

- [ ] Every AC has a passing test, or a manual test with a reason.
- [ ] Lint, format, typecheck and unit tests pass.
- [ ] UI changes: every automatable UI test passes at every viewport, and the axe scan has no serious or critical violations.
- [ ] Review approved.
- [ ] Docs updated.

## Open risks

- No provider yet, so "subscribed" is not persisted. Accepted for this issue.

STATUS: ok
ARTEFACTS: .aew/runs/101/02-brief.md
SUMMARY: Compiled brief for #101, a footer newsletter sign-up with a validated POST /api/newsletter endpoint, seven testable ACs and shared validation.
NEXT: standards
