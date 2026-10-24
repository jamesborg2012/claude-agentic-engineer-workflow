# React (client-side, Vite) standards seed

Versions covered: React 19.x (19.3), Vite 8 (create-vite 9), Vitest 5, TypeScript 6.0 (the template pins `~6.0`; 7.0 is the current major but `typescript-eslint` supports only TypeScript below 6.1), Oxlint 1 or ESLint 10 with eslint-plugin-react-hooks 7, Testing Library (React 16, user-event 14); context7 unavailable (researched 2026-10-24; sources: https://react.dev/versions, https://react.dev/reference/eslint-plugin-react-hooks, https://react.dev/learn/you-might-not-need-an-effect, https://vite.dev/guide/, https://vite.dev/guide/env-and-mode, https://vitest.dev/guide/, https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/, create-vite@9.3.1 react-ts template, npm registry versions)

Scope: plain React with TypeScript on a client build tool (React + Vite). No framework router or server rendering is assumed.

## Tooling and commands

- **[convention]** Scaffold with `npm create vite@latest -- --template react-ts`. Use the `react-compiler-ts` template only when adopting React Compiler deliberately.
- **[convention]** Require Node.js 22.12 or later (Vite needs 20.19+ or 22.12+; Vitest 5 needs 22.12+). Pin it in `.nvmrc` or `engines`.
- **[convention]** Standard scripts: `dev` (`vite`), `build` (`tsc -b && vite build`), `preview` (`vite preview`), `lint` (`oxlint` or `eslint .`), `test` (`vitest run`), `typecheck` (`tsc -b`).
- **[tool]** Type-check strictly: `strict` is the TypeScript 6.0 default (state it in `tsconfig.app.json` anyway), and the template adds `noUnusedLocals`, `noUnusedParameters` and `verbatimModuleSyntax` (tsc).
- **[convention]** Stay on TypeScript 6.0 while `typescript-eslint` or another tool needs the compiler API. TypeScript 7 can run side by side through the `@typescript/typescript6` npm alias described in its release notes.
- **[tool]** create-vite 9 asks for a linter. The default is Oxlint (`.oxlintrc.json` with `react/rules-of-hooks` and `react/only-export-components`). `--eslint` gives an ESLint flat config (`eslint.config.js`) with `@eslint/js`, `typescript-eslint` and `reactHooks.configs.flat.recommended`, plus `reactRefresh.configs.vite`. Keep whichever the repo uses.
- **[tool]** Enforce the Rules of Hooks and complete dependency arrays (`react-hooks/rules-of-hooks`, `react-hooks/exhaustive-deps` in eslint-plugin-react-hooks; Oxlint's template enables only `react/rules-of-hooks`).
- **[tool]** Keep the compiler-backed rules of the eslint-plugin-react-hooks recommended preset on: `react-hooks/purity`, `react-hooks/refs`, `react-hooks/set-state-in-effect`, `react-hooks/set-state-in-render`, `react-hooks/static-components`, `react-hooks/immutability`.
- **[tool]** Keep fast refresh safe: modules that export components export only components (`react-refresh/only-export-components` in ESLint, `react/only-export-components` in Oxlint).
- **[convention]** Format with Prettier (or the repo's formatter) and run it in CI as a check, not a rewrite.
- **[convention]** Commit the lockfile. Install with `npm ci` in CI.

## Project structure

- **[convention]** Source lives in `src/`; `index.html` sits at the project root and loads `src/main.tsx`.
- **[convention]** Organise by feature: `src/features/<feature>/` holding its components, hooks, API calls, types and tests. Shared code goes in `src/components/`, `src/hooks/` and `src/lib/`.
- **[convention]** Import across features only through the feature's `index.ts`. Do not reach into another feature's internals.
- **[convention]** Static assets imported by code go in `src/assets/`; files served as-is go in `public/`.
- **[convention]** Use one path alias (`@/` to `src/`) configured in both `tsconfig.app.json` and `vite.config.ts`.
- **[convention]** Type `VITE_` variables by augmenting `ImportMetaEnv` in `src/vite-env.d.ts`, with no `import` statements in that file. The template already lists `vite/client` in `types`.
- **[convention]** Keep `main.tsx` thin: create the root, wrap providers, render `<App />` inside `<StrictMode>`.

## Naming

- **[convention]** Components, and the files that hold one primary component, use PascalCase: `UserCard.tsx`.
- **[convention]** Hooks start with `use` and are camelCase: `useDebouncedValue.ts`. A function that does not call hooks must not start with `use`.
- **[tool]** Hooks are recognised by the `use` prefix, so the Rules of Hooks are only enforced for correctly named hooks (react-hooks/rules-of-hooks).
- **[convention]** Props types are `<Component>Props`; event-handler props are `onX`, and the handlers that implement them are `handleX`.
- **[convention]** Booleans read as questions: `isOpen`, `hasError`, `canSubmit`.
- **[convention]** Non-component modules use kebab-case or camelCase consistently with the repo (`format-date.ts`).
- **[convention]** Context objects are `FooContext`, with a `FooProvider` and a `useFoo` hook that throws outside the provider.
- **[convention]** Tests sit beside the code as `<name>.test.tsx` (see Testing conventions).

## Language idioms

- **[tool]** No `any`; use `unknown` and narrow (`@typescript-eslint/no-explicit-any` in the ESLint template's `typescript-eslint` recommended preset).
- **[tool]** Use `import type` for type-only imports (`verbatimModuleSyntax` in the template's `tsconfig.app.json` makes tsc reject a value import of a type).
- **[convention]** Write function components as plain functions with typed props. Do not use `React.FC`.
- **[convention]** Model state with discriminated unions rather than several booleans (`status: 'idle' | 'loading' | 'error'`).
- **[convention]** Prefer `const`, immutable updates (spread, `map`, `filter`, `toSorted`) and early returns.
- **[convention]** Use named exports. Reserve default exports for lazily loaded route modules.
- **[convention]** Handle promises explicitly in handlers and effects. Enforce it with type-aware linting (`@typescript-eslint/no-floating-promises`, or Oxlint with `oxlint-tsgolint`), which the template leaves off.

## Framework conventions

- **[convention]** React 19: pass `ref` as an ordinary prop; do not add `forwardRef` to new components. Render context as `<FooContext value={...}>`.
- **[tool]** Components and hooks must be pure during render: no mutation of props, state or globals, no ref reads or writes (react-hooks/purity, react-hooks/refs, react-hooks/immutability).
- **[convention]** Use effects only to synchronise with external systems (network, subscriptions, timers, non-React widgets, the DOM). Derive values during render and put user-triggered logic in event handlers.
- **[tool]** Do not call `setState` synchronously in an effect or during render (react-hooks/set-state-in-effect, react-hooks/set-state-in-render).
- **[convention]** Every effect that subscribes, listens or fetches returns a cleanup. Fetch effects ignore stale responses or abort with `AbortController`.
- **[convention]** Prefer a data-fetching library (TanStack Query or similar) over hand-rolled fetch effects for server state.
- **[convention]** Keep state as close as possible to where it is used. Lift it only to the nearest shared parent. Keep server state out of global client stores.
- **[convention]** Store the minimum: keep IDs not objects, and never duplicate derived data in state.
- **[convention]** Reset component state by changing its `key`, not by an effect.
- **[convention]** Give list items a stable, unique `key` from the data, never the array index for reorderable lists. React warns about missing keys at runtime; `react/jsx-key` lints it where the repo enables it.
- **[tool]** Define components at module level, never inside another component (react-hooks/static-components).
- **[convention]** Use `<form action={fn}>`, `useActionState` and `useTransition` for async form submissions instead of manual `isLoading` flags.
- **[convention]** Do not add `useMemo`, `useCallback` or `React.memo` speculatively. Measure first, or rely on React Compiler where adopted. Existing memoisation must stay correct (react-hooks/preserve-manual-memoization).
- **[convention]** Split routes and heavy components with `React.lazy` and `<Suspense>`.

Do:
```tsx
function Price({ items }: { items: Item[] }) {
  const total = items.reduce((sum, i) => sum + i.price, 0);
  return <output>{total}</output>;
}
```
Don't:
```tsx
function Price({ items }: { items: Item[] }) {
  const [total, setTotal] = useState(0);
  useEffect(() => setTotal(items.reduce((s, i) => s + i.price, 0)), [items]);
  return <output>{total}</output>;
}
```

Do:
```tsx
{todos.map((todo) => <TodoRow key={todo.id} todo={todo} />)}
```
Don't:
```tsx
{todos.map((todo, index) => <TodoRow key={index} todo={todo} />)}
```

Do:
```tsx
useEffect(() => {
  const controller = new AbortController();
  fetch(url, { signal: controller.signal }).then(setData).catch(ignoreAbort);
  return () => controller.abort();
}, [url]);
```
Don't:
```tsx
useEffect(() => {
  fetch(url).then(setData);
}, [url]);
```

Do:
```tsx
<ProfileForm key={userId} userId={userId} />
```
Don't:
```tsx
useEffect(() => { setDraft(''); }, [userId]);
```

## Error handling

- **[convention]** Wrap route-level and widget-level subtrees in error boundaries (`react-error-boundary` or a class boundary) with a fallback and a retry. Add `onCaughtError` and `onUncaughtError` to `createRoot` to report to monitoring.
- **[tool]** Do not use `try/catch` to catch errors from child rendering; use error boundaries (react-hooks/error-boundaries).
- **[convention]** Error boundaries do not catch event-handler or async errors. Catch those where they occur and set error state.
- **[convention]** Model request state explicitly (`idle`, `loading`, `success`, `error`) and render every state, including empty.
- **[convention]** Show users a short, actionable message; log the technical detail to monitoring, not the UI.
- **[convention]** Throw `Error` instances (never strings) and validate external data at the boundary (for example with Zod) before it enters component state.
- **[convention]** Remove stray `console.log` before merging (`no-console` with `warn` and `error` allowed, where the repo enables it).

## Security

- **[convention]** React escapes interpolated text. Never bypass it with `dangerouslySetInnerHTML` unless the HTML is sanitised with DOMPurify (or equivalent) immediately before use. Add a comment saying why it is safe.
- **[convention]** Validate URLs that come from users or an API before using them in `href`, `src` or `window.location`. Allow only `https:`, `http:`, `mailto:` and `tel:`; reject `javascript:` and `data:`.
- **[convention]** Add `rel="noopener noreferrer"` to external `target="_blank"` links (`react/jsx-no-target-blank` where enabled).
- **[convention]** Forbid `eval`, `new Function` and string timers (`no-eval`, `no-implied-eval`; Oxlint enables `no-eval` by default, ESLint's recommended preset does not).
- **[convention]** Every `VITE_`-prefixed variable is embedded in the public bundle. Never put secrets, API keys with write access or private tokens in one. Keep secrets on a backend.
- **[convention]** Keep `.env*.local` files out of git. Commit a `.env.example` with names only and no values.
- **[convention]** Do not store access tokens in `localStorage`; prefer `HttpOnly`, `Secure`, `SameSite` cookies set by the server. Treat anything in browser storage as readable by injected script.
- **[convention]** Send a restrictive `Content-Security-Policy` from the host and avoid inline scripts, so injected markup cannot run.
- **[convention]** Never trust client-side checks. Authorisation and validation are repeated on the server.
- **[convention]** Run `npm audit` in CI, keep dependencies current, and review new dependencies before adding them.

Do:
```tsx
const safeHtml = DOMPurify.sanitize(post.html);
return <div dangerouslySetInnerHTML={{ __html: safeHtml }} />;
```
Don't:
```tsx
return <div dangerouslySetInnerHTML={{ __html: post.html }} />;
```

Do:
```tsx
const isSafe = (u: string) => ['https:', 'http:'].includes(new URL(u, location.origin).protocol);
return isSafe(url) ? <a href={url}>{label}</a> : <span>{label}</span>;
```
Don't:
```tsx
return <a href={user.website}>{label}</a>;
```

## Accessibility

Target: WCAG 2.2 AA.

- **[convention]** Lint JSX accessibility with `eslint-plugin-jsx-a11y` (recommended or strict preset) or Oxlint's `jsx-a11y` plugin: alt text, labels, valid ARIA, interactive roles. The Vite template enables neither.
- **[convention]** Use semantic elements first (`button`, `a`, `nav`, `main`, `ul`, `label`). Add ARIA only where no native element fits.
- **[convention]** Every form control has a programmatic label: `<label htmlFor>` with `useId()` for the ID, or an `aria-label` for icon-only controls. Never rely on `placeholder` alone.
- **[convention]** Link errors to fields with `aria-invalid` and `aria-describedby`. Announce submit results in an `aria-live` region and move focus to the first invalid field.
- **[convention]** Redundant entry (WCAG 3.3.7): do not make users re-enter information already given in the same flow; keep it in state or pre-fill it. Set `autoComplete` tokens on identity and address fields (1.3.5).
- **[convention]** Authentication (3.3.8): allow password managers and paste; do not block a cognitive test as the only way in.
- **[convention]** Pointer targets are at least 24 by 24 CSS pixels (2.5.8). Any drag interaction has a single-pointer alternative (2.5.7).
- **[convention]** Focus must not be hidden by sticky headers or banners (2.4.11 Focus Not Obscured). Keep a visible focus indicator.
- **[convention]** In a single-page app, move focus to the page heading (or a skip target) and update `document.title` on each route change. Provide a skip link.
- **[convention]** Manage focus in dialogs: trap it while open, close on Escape, and return it to the trigger. Prefer the native `<dialog>` element.
- **[convention]** Colour contrast is at least 4.5:1 for text and 3:1 for UI components. Never use colour alone to convey state.
- **[convention]** Help, if offered, appears in a consistent place across pages (3.2.6).

## Testing conventions

- **[convention]** Use Vitest with React Testing Library (`@testing-library/react`), `@testing-library/user-event` and `@testing-library/jest-dom`.
- **[convention]** Configure `test.environment: 'jsdom'` (or `happy-dom`), `test.setupFiles: ['./src/test/setup.ts']` and `globals: false` in `vite.config.ts`; import `describe`, `it` and `expect` explicitly.
- **[convention]** Co-locate unit and component tests as `Component.test.tsx` beside the source; put shared helpers in `src/test/`. Vitest picks up `*.test.*` and `*.spec.*` by default.
- **[convention]** Name tests by behaviour: `it('shows an error when the email is invalid')`. One `describe` per component or hook.
- **[convention]** Query by what users perceive, in this order: `getByRole` (with `name`), `getByLabelText`, `getByText`, then `getByTestId` as a last resort.
- **[convention]** Create `const user = userEvent.setup()` per test and `await user.click(...)`. Prefer `userEvent` over `fireEvent`.
- **[convention]** Use `findBy*` or `waitFor` for async UI. Assert on `queryBy*` returning `null` for absence. Never use fixed sleeps.
- **[convention]** Mock at the network boundary with MSW rather than mocking `fetch` or your own modules. Reset handlers after each test.
- **[convention]** Test hooks through a component or `renderHook`. Wrap providers in a shared `renderWithProviders` helper.
- **[convention]** Do not test implementation details (internal state, child component calls, class names). Snapshot only small, stable output.
- **[convention]** Fail tests on unexpected console errors by spying in the setup file, and run `vitest run --coverage` in CI with thresholds the repo chooses.
- **[convention]** Cover critical journeys with Playwright end-to-end tests, kept separate from unit tests (`e2e/`).

Do:
```tsx
render(<LoginForm />);
await user.type(screen.getByLabelText(/email/i), 'a@b.co');
await user.click(screen.getByRole('button', { name: /sign in/i }));
```
Don't:
```tsx
const { container } = render(<LoginForm />);
fireEvent.change(container.querySelector('.email-input')!, { target: { value: 'a@b.co' } });
```

## Documentation and comment standards

- **[convention]** Comment why, not what. Delete comments that restate the code.
- **[convention]** Use TSDoc (`/** */`) on exported hooks, shared components and utilities: purpose, parameters, return value and an `@example` where usage is not obvious.
- **[convention]** Types are the props documentation. Add TSDoc on individual props only for non-obvious behaviour or defaults.
- **[convention]** Mark intentional lint suppressions with a reason: `// eslint-disable-next-line react-hooks/exhaustive-deps -- reason`. Prefer fixing the code.
- **[convention]** Keep a README covering setup, scripts, environment variables (names and purpose) and how to run tests.
- **[convention]** Record notable decisions (state library, data fetching, routing) as short ADRs. Update `CHANGELOG.md` for user-visible changes.
- **[convention]** Link TODOs to an issue: `// TODO(#123): ...`.

## Anti-patterns

- **[convention]** Mirroring props into state with an effect. Instead derive during render, or use a `key` to reset.
- **[convention]** Chains of effects that set state for each other. Instead compute the next state in one event handler.
- **[convention]** Fetching in `useEffect` without cleanup, causing races. Instead abort or ignore stale results, or use a data library.
- **[convention]** Index as `key` for dynamic lists. Instead use a stable ID.
- **[convention]** Components defined inside components, which remount each render. Instead define them at module level.
- **[convention]** Prop drilling through many layers, or one giant context. Instead compose with `children`, or split contexts by concern.
- **[convention]** Secrets in `VITE_` variables. Instead call a backend that holds them.
- **[convention]** Clickable `div`s and `span`s. Instead use `button` or `a`.
- **[convention]** Mutating state (`items.push(x); setItems(items)`). Instead `setItems([...items, x])`.
- **[convention]** Casting with `as` to silence the compiler. Instead narrow with type guards or validate at the boundary.
- **[convention]** Wrapping everything in `useMemo`/`useCallback` by habit. Instead profile first.
