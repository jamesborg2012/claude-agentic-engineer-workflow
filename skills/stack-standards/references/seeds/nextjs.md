# Next.js (React, TypeScript) standards seed

Versions covered: Next.js 16.x (App Router; 16.3 is the latest seen), React 19.2 (19.3 released 2026-09-09; Next.js ships a React canary that includes 19.2 features), TypeScript 6.0 (researched 2026-10-24; sources: context7 unavailable; https://nextjs.org/docs/app/guides/upgrading/version-16, https://nextjs.org/docs/app/getting-started/caching, https://nextjs.org/docs/app/guides/data-security, https://nextjs.org/docs/app/api-reference/config/eslint, https://nextjs.org/docs/app/guides/testing, https://nextjs.org/docs/app/api-reference/functions/generate-metadata, https://react.dev/blog, https://www.typescriptlang.org/docs/handbook/release-notes/typescript-6-0.html)

This seed assumes the App Router. Pages Router projects (`pages/`) follow the base React and TypeScript rules only; check the repo before applying the routing sections.

## Tooling and commands

- **[tool]** Next.js 16 needs Node.js 20.9 or later and TypeScript 5.1 or later; browsers are Chrome, Edge and Firefox 111+ and Safari 16.4+ (`next` engines check).
- **[tool]** `next dev` and `next build` use Turbopack by default. A custom `webpack` config fails `next build`; migrate it to `turbopack` options or opt out with `--webpack` (`next build`).
- **[tool]** Lint with the ESLint CLI and a flat config (`eslint.config.mjs`) that spreads `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`. `next lint` and the `eslint` option in `next.config` were removed in 16 (`eslint-config-next`).
- **[tool]** Type-check with `tsc --noEmit`. Run `npx next typegen` first to generate the global `PageProps`, `LayoutProps` and `RouteContext` helpers (`next typegen`).
- **[convention]** Keep these scripts in `package.json`: `dev` (`next dev`), `build` (`next build`), `start` (`next start`), `lint` (`eslint .`), `typecheck` (`tsc --noEmit`), `test` (unit and component) and `test:e2e`. CI runs lint, typecheck, test, build, then e2e.
- **[convention]** Commit the lockfile for the package manager in use and never mix package managers.
- **[convention]** Configure with `next.config.ts` typed as `NextConfig`. `turbopack` is a top-level option, no longer `experimental.turbopack`.
- **[convention]** Format with Prettier and add `eslint-config-prettier` last in the ESLint config so the two never fight.

## Project structure

- **[convention]** Routes live under `app/` (optionally under `src/`). Only `page`, `route`, `layout`, `loading`, `error`, `not-found`, `default` and `template` files are routable conventions; everything else in `app/` is safe to colocate.
- **[convention]** Colocate components used by one route inside its folder. Share across routes via `components/` (UI), `lib/` (utilities) and `data/` (the data access layer).
- **[convention]** Use route groups `(marketing)` to organise without changing URLs, and private folders `_components` to opt a folder out of routing.
- **[convention]** Put a root `proxy.ts` (formerly `middleware.ts`) next to `app/` only for request-level work such as redirects and header rewrites. Use `proxy`, not `middleware`, in 16 (it runs on the Node.js runtime, not edge).
- **[convention]** Parallel route slots (`@modal`) each need an explicit `default.tsx`, or the build fails.
- **[convention]** Static assets go in `public/`; import images that live beside the code instead so the compiler knows their dimensions.
- **[convention]** Keep database clients, secrets and server-only helpers in modules that start with `import 'server-only'`.

## Naming

- **[convention]** Route folders and route files use the framework names exactly: `page.tsx`, `layout.tsx`, `route.ts`. URL segments are lower-case kebab-case; dynamic segments are `[slug]`, catch-all `[...slug]`.
- **[convention]** Component files are kebab-case (`order-summary.tsx`) with PascalCase exports (`OrderSummary`); hooks are `use-order.ts` exporting `useOrder`.
- **[convention]** Name Server Actions as verbs (`createOrder`, `deletePost`) in files ending `actions.ts`; name DAL functions after what they return (`getProfileDTO`).
- **[convention]** Type and interface names are PascalCase with no `I` prefix; props types are `<Component>Props`.
- **[convention]** Environment variables are SCREAMING_SNAKE_CASE; only values safe for browsers carry the `NEXT_PUBLIC_` prefix.
- **[convention]** Test files sit beside the unit as `<name>.test.ts(x)`; end-to-end specs end `.spec.ts` under `e2e/`.

## Language idioms

- **[tool]** Enable `strict` in `tsconfig.json` (TypeScript 6.0 defaults it to true, but state it explicitly) so `next build` and `tsc` fail on implicit `any` and unchecked nulls (`strict`).
- **[tool]** Declare `types` explicitly (for example `["node", "vitest/globals"]`); TypeScript 6.0 defaults `types` to `[]` and no longer loads every `@types/*` package (`types`).
- **[tool]** Use `moduleResolution: "bundler"` and `paths` without `baseUrl` (deprecated in 6.0); Next.js writes the base config on `next dev` (`moduleResolution`, `paths`).
- **[tool]** No `any`, no unused variables, no non-null assertions without a comment (`@typescript-eslint/no-explicit-any`, `@typescript-eslint/no-unused-vars`).
- **[convention]** Prefer `type` imports for types (`import type { Metadata } from 'next'`) and `unknown` over `any` at boundaries, narrowing with a validator.
- **[convention]** Model state with discriminated unions rather than several optional booleans; use `satisfies` to check a literal without widening it.
- **[convention]** Derive types from a validator schema (`z.infer<typeof schema>`) so runtime and static types cannot drift.
- **[convention]** Prefer `async`/`await` and `const`; avoid enums in favour of string-literal unions.

Do:
```ts
import type { Metadata } from 'next'
const statuses = ['draft', 'live'] as const
type Status = (typeof statuses)[number]
```
Don't:
```ts
import { Metadata } from 'next'
enum Status { Draft, Live }
```

## Framework conventions

- **[convention]** Components are Server Components by default. Add `'use client'` only at the top of a file that needs state, effects, event handlers or browser APIs, and keep that boundary as deep in the tree as possible.
- **[convention]** Everything imported by a `'use client'` file joins the client bundle. Pass Server Components to Client Components as `children` or props rather than importing them.
- **[tool]** Client Components must not be `async` (`@next/next/no-async-client-component`).
- **[tool]** Hooks follow the Rules of Hooks: top level only, never in conditions or loops, and dependency arrays complete (`react-hooks/rules-of-hooks`, `react-hooks/exhaustive-deps`).
- **[convention]** `params` and `searchParams` are Promises; `cookies()`, `headers()` and `draftMode()` are async. Await them, typing props with `PageProps<'/route'>` and `LayoutProps<'/route'>`. Synchronous access was removed in 16.
- **[convention]** Fetch data in Server Components, ideally through a data access layer, and stream slow parts with `<Suspense>`. Use `React.cache` to share a lookup across one request.
- **[convention]** With `cacheComponents: true` (the `create-next-app` default for new apps), nothing is cached implicitly. Mark cacheable work with `'use cache'` plus `cacheLife(...)`, tag it with `cacheTag(...)`, and wrap request-time reads (`cookies()`, `headers()`, uncached fetches) in `<Suspense>`.
- **[convention]** After a mutation call `updateTag(tag)` inside a Server Action for read-your-writes, or `revalidateTag(tag, 'max')` for stale-while-revalidate. The single-argument `revalidateTag` is deprecated. `revalidatePath` is still valid for path-level invalidation.
- **[convention]** Do not call `Math.random()`, `Date.now()` or `crypto.randomUUID()` in prerendered code; call `await connection()` inside `<Suspense>`, or cache the value.
- **[convention]** Mutations use Server Actions (`'use server'`) and `<form action={...}>`. Use `useActionState` for validation errors and `useFormStatus` or `useTransition` for pending state. Do not mutate inside render.
- **[convention]** Use Route Handlers (`route.ts`) for webhooks and public HTTP APIs, not for your own pages to read data.
- **[tool]** Use `next/link` for internal navigation and `next/image` for images (`@next/next/no-html-link-for-pages`, `@next/next/no-img-element`). Give every image `width` and `height` (or `fill` with `sizes`), `priority` only for the LCP image, and remote hosts through `images.remotePatterns` (not the deprecated `domains`).
- **[convention]** Image defaults changed in 16: `qualities` allows only `[75]`, `minimumCacheTTL` is four hours, and local sources with query strings need `images.localPatterns`.
- **[convention]** Use `next/font` for fonts and `next/script` for third-party scripts (`@next/next/no-sync-scripts`).
- **[convention]** Export a static `metadata` object or an async `generateMetadata` from Server Component layouts and pages (not both from one segment). Set `metadataBase` and a `title.template` in the root layout. `viewport`, `themeColor` and `colorScheme` belong in `generateViewport`, not `metadata`.
- **[convention]** Add `loading.tsx`, `error.tsx` (a Client Component) and `not-found.tsx` at meaningful segment levels; call `notFound()` rather than rendering an ad hoc 404.
- **[convention]** Enable the React Compiler (`reactCompiler: true`) only after measuring; until then use `useMemo`/`useCallback` sparingly and only for measured cost or stable identity.
- **[convention]** Derive values during render rather than syncing props into state with an effect; use `useEffectEvent` for non-reactive logic inside effects.

Do:
```tsx
import { Suspense } from 'react'
export default function Page() {
  return <Suspense fallback={<p>Loading…</p>}><LatestPosts /></Suspense>
}
```
Don't:
```tsx
'use client'
export default function Page() {
  const [posts, setPosts] = useState([])
  useEffect(() => { fetch('/api/posts').then(r => r.json()).then(setPosts) }, [])
  return <PostList posts={posts} />
}
```

Do:
```tsx
export default async function Page({ params }: PageProps<'/blog/[slug]'>) {
  const { slug } = await params
  return <h1>{slug}</h1>
}
```
Don't:
```tsx
export default function Page({ params }: { params: { slug: string } }) {
  return <h1>{params.slug}</h1>
}
```

## Error handling

- **[convention]** Expected failures (validation, not found, conflict) are returned values: a Server Action returns `{ ok: false, errors }` that `useActionState` renders. Do not throw for them.
- **[convention]** Unexpected failures throw and are caught by `error.tsx`, which must be a Client Component with a `reset` button; use `global-error.tsx` for the root layout. Use `catchError` for component-level boundaries.
- **[convention]** Use `notFound()` and `redirect()` from `next/navigation`. They work by throwing, so never wrap them in a `try`/`catch` that swallows the error.
- **[convention]** Log errors on the server with context and a request id; show the user a generic message and, in production, the `digest` rather than the stack.
- **[convention]** Never return raw database errors, stack traces or full records from Server Actions or Route Handlers.
- **[convention]** Return correct HTTP status codes from Route Handlers (400 invalid input, 401 unauthenticated, 403 forbidden, 404 missing) with a JSON body of a stable shape.
- **[convention]** Report errors from `error.tsx` and `instrumentation.ts` (`onRequestError`) to the project's error tracker.

## Security

- **[convention]** Treat every Server Action and Route Handler as a public POST endpoint. Authenticate, authorise (does this user own this resource?) and validate input inside each one; a check in the page does not protect the action.
- **[convention]** Validate all external input on the server (form data, `params`, `searchParams`, headers, JSON bodies) with a schema library such as Zod, using `safeParse` and returning field errors.
- **[convention]** Use a server-only data access layer that checks authorisation and returns minimal DTOs. Only that layer reads `process.env` secrets.
- **[tool]** Mark server-only modules with `import 'server-only'`; importing one from a Client Component fails the build (`server-only`).
- **[convention]** Only `NEXT_PUBLIC_`-prefixed variables reach the browser and are inlined at build time. Never put a secret behind that prefix. Commit `.env.example` and gitignore `.env*.local`.
- **[convention]** Do not pass whole records into Client Component props; pass only the fields the UI renders. Optionally enable `experimental.taint` as a second layer.
- **[convention]** Server Actions compare `Origin` with `Host`; set `serverActions.allowedOrigins` only for known proxies, and a shared `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` when self-hosting several instances.
- **[convention]** Return from actions only what the client needs, and rate limit expensive or abusable actions.
- **[convention]** Set security headers (CSP, `X-Content-Type-Options`, `Referrer-Policy`, frame protection) in `next.config` `headers()` or `proxy.ts`. Treat `proxy.ts` and `route.ts` as high-risk code and review them closely.
- **[convention]** Never render untrusted HTML with `dangerouslySetInnerHTML` without sanitising it. Do not build URLs or redirects from unvalidated input (open redirect).
- **[convention]** Keep Next.js, React and `react-dom` on patched versions: React Server Components had critical vulnerabilities fixed in December 2025 (19.0.1, 19.1.2, 19.2.1), so enable dependency alerts and audit in CI (`npm audit`).

Do:
```ts
'use server'
export async function deletePost(postId: string) {
  const session = await auth()
  if (!session?.user) throw new Error('Unauthorized')
  const post = await db.post.findUnique({ where: { id: postId } })
  if (post?.authorId !== session.user.id) throw new Error('Forbidden')
  await db.post.delete({ where: { id: postId } })
}
```
Don't:
```ts
'use server'
export async function deletePost(postId: string) {
  await db.post.delete({ where: { id: postId } }) // no auth, no ownership check
}
```

Do:
```ts
const parsed = schema.safeParse(Object.fromEntries(formData))
if (!parsed.success) return { ok: false, errors: parsed.error.flatten().fieldErrors }
```
Don't:
```ts
const email = formData.get('email') as string // unvalidated cast
```

## Accessibility

Target: WCAG 2.2 AA.

- **[tool]** `eslint-config-next` includes the `react` and `@next/next` rules but not `jsx-a11y` rules by default; add `eslint-plugin-jsx-a11y` to the flat config to enforce alt text, labels and valid ARIA (`jsx-a11y/alt-text`).
- **[convention]** Use semantic elements (`button`, `a`, `nav`, `main`, headings in order) before ARIA. A clickable `div` is a defect.
- **[convention]** Set `lang` on `<html>` in the root layout, give each route a unique `<title>` via metadata, and have one `<h1>` per page.
- **[convention]** Every image has meaningful `alt` text, or `alt=""` when decorative, including `next/image`.
- **[convention]** Label every form control with a visible `<label>`, link errors with `aria-describedby`, and announce validation results in a live region. Do not ask users to re-enter information already given in the same flow (SC 3.3.7 Redundant Entry).
- **[convention]** Focus indicators must be visible and not obscured by sticky headers or banners (SC 2.4.11 Focus Not Obscured). Pointer targets are at least 24 by 24 CSS pixels (SC 2.5.8 Target Size), and anything draggable has a single-pointer alternative (SC 2.5.7 Dragging Movements).
- **[convention]** After client-side navigation, make sure focus and the announced page title reflect the new route; use `loading.tsx` fallbacks that are announced and do not trap focus.
- **[convention]** Do not rely on colour alone; keep contrast at 4.5:1 for text and 3:1 for UI components. Honour `prefers-reduced-motion`, including for View Transitions.
- **[convention]** Modals and menus trap and restore focus and close on Escape; prefer the native `<dialog>` or a tested headless primitive.
- **[convention]** Test accessibility in end-to-end runs with axe (`@axe-core/playwright`) and keep a short manual keyboard and screen-reader pass for new flows.

## Testing conventions

- **[convention]** Follow the official testing guide: Vitest or Jest with React Testing Library for unit and component tests, and Playwright (or Cypress) for end-to-end tests.
- **[convention]** Test `async` Server Components with end-to-end tests; the official guide says unit-test tooling does not fully support them yet. Unit test pure functions, hooks, Client Components and DAL functions.
- **[convention]** Co-locate unit and component tests as `<name>.test.ts(x)` next to the source. Keep Playwright specs in `e2e/` as `<flow>.spec.ts`. Never place test files in `app/` under a routable name.
- **[convention]** Name cases by behaviour: `it('shows a field error when the email is invalid')`. Query by role and label (`getByRole`), not by test id or class.
- **[convention]** Test Server Actions by calling the exported function with `FormData` and a mocked session, and assert both the happy path and the unauthorised path.
- **[convention]** End-to-end tests run against `next build && next start`, not `next dev`, and cover each critical user flow and its error state.
- **[convention]** Mock network at the boundary (MSW or Playwright routing); never call real third-party services in tests.
- **[convention]** Snapshot tests are for small, stable output only. Fix flaky tests instead of retrying them.

Do:
```tsx
render(<LoginForm />)
await user.type(screen.getByLabelText('Email'), 'a@b.co')
expect(screen.getByRole('button', { name: 'Sign in' })).toBeEnabled()
```
Don't:
```tsx
const { container } = render(<LoginForm />)
container.querySelector('.btn-primary')!.click()
```

## Documentation and comment standards

- **[convention]** Comment why, not what. Document non-obvious cache lifetimes, tag names and the reason a file is a Client Component.
- **[convention]** Use TSDoc (`/** ... */`) on exported functions, hooks and DAL functions, including `@throws` for thrown auth errors.
- **[convention]** Keep a `README.md` with setup, required environment variables (names only), scripts and deployment notes, and keep `.env.example` in step with the code.
- **[convention]** Record cache tags and which actions invalidate them in one place, such as `lib/cache-tags.ts`.
- **[convention]** Record decisions that depart from these defaults (for example opting out of Turbopack) in a short note or ADR.
- **[convention]** Update `CHANGELOG.md` for user-visible changes; prose is British English.
- **[convention]** Remove commented-out code; leave `TODO` comments only with an issue reference.

## Anti-patterns

- **[convention]** Marking a whole page or layout `'use client'` to use one hook. Extract the interactive leaf and keep the rest on the server.
- **[convention]** Fetching in `useEffect` what a Server Component can load. Fetch on the server and stream it.
- **[convention]** Trusting the page-level auth check to protect a Server Action. Re-verify inside the action.
- **[convention]** Using `middleware.ts` in 16; rename it to `proxy.ts` and export `proxy`, unless you genuinely need the edge runtime.
- **[convention]** Reading `params` or `cookies()` synchronously. Await them.
- **[convention]** Relying on implicit `fetch` caching from Next.js 14 and earlier. With Cache Components, cache explicitly with `'use cache'`.
- **[convention]** Calling `next lint` or setting the `eslint` key in `next.config`. Both were removed; run `eslint .`.
- **[convention]** Using `<img>`, `<a href>` for internal links, or `NEXT_PUBLIC_` for secrets. Use `next/image`, `next/link` and server-only variables.
- **[convention]** Disabling `exhaustive-deps` to silence a warning. Fix the dependency or restructure the effect.
- **[convention]** Casting with `as` to quiet the compiler (`as any`, `as unknown as T`). Validate or narrow instead.
