# Tailwind CSS standards seed

Versions covered: Tailwind CSS 4.x (docs at 4.3; Node.js 20+ for the upgrade tool), prettier-plugin-tailwindcss (researched 2026-10-24; sources: context7 unavailable, https://tailwindcss.com/docs/upgrade-guide, https://tailwindcss.com/docs/theme, https://tailwindcss.com/docs/styling-with-utility-classes, https://tailwindcss.com/docs/detecting-classes-in-source-files, https://tailwindcss.com/docs/functions-and-directives, https://tailwindcss.com/docs/hover-focus-and-other-states, https://tailwindcss.com/docs/outline-style, https://github.com/tailwindlabs/prettier-plugin-tailwindcss, https://www.w3.org/TR/WCAG22/)
Overlay on: any base profile (nextjs, react, laravel, wordpress)

## Tooling and commands

- **[convention]** Tailwind v4 is CSS-first. Configuration lives in the main stylesheet, not in `tailwind.config.js`: `@import "tailwindcss";` replaces the `@tailwind base/components/utilities` directives.
- **[convention]** Do not add `tailwind.config.js` to a v4 project. Load a legacy one only while migrating, with `@config "../../tailwind.config.js";`. The v3 options `corePlugins`, `safelist` and `separator` no longer exist.
- **[tool]** Wire Tailwind in through the package that matches the build: `@tailwindcss/vite` (preferred), `@tailwindcss/postcss` or `@tailwindcss/cli`. `postcss-import` and `autoprefixer` are no longer needed (upgrade guide).
- **[tool]** Migrate v3 projects with `npx @tailwindcss/upgrade` on a fresh branch and review the diff (official upgrade tool).
- **[tool]** Sort classes with `prettier-plugin-tailwindcss`, listed last in the Prettier `plugins` array, with `tailwindStylesheet` pointing at the CSS entry point (the plugin's README). Use `tailwindFunctions` for `clsx`, `cva` and similar helpers.
- **[convention]** Keep exactly one CSS entry point that imports Tailwind. Use `@import "tailwindcss" source("../src");` or `@source` only when automatic detection misses a path.
- **[convention]** Target browsers are Safari 16.4+, Chrome 111+ and Firefox 128+. If the project must support older browsers, stay on v3.4 and say so in the project docs.

## Project structure

- **[convention]** One stylesheet holds `@import "tailwindcss";`, the `@theme` block, `@utility` and `@custom-variant` definitions. In a larger project split design tokens into a `theme.css` that the entry point imports.
- **[convention]** Reusable markup lives in framework components (React, Vue, Svelte) or template partials (Blade, Twig), next to the feature that uses it. Do not create a global "components.css" of look-alike classes.
- **[convention]** Third-party UI under `node_modules` or ignored paths is added with `@source`. Legacy folders without Tailwind are excluded with `@source not`.
- **[convention]** In Vue or Svelte `<style>` blocks and CSS modules, start with `@reference "../../app.css";` so `@apply` and `@variant` see the theme without duplicating CSS.

## Naming

- **[convention]** Theme variables follow the namespace that creates the utility: `--color-brand-500` gives `bg-brand-500`, `--breakpoint-3xl` gives `3xl:`. Name by role (`--color-surface`, `--color-danger`) rather than by appearance (`--color-light-red`).
- **[convention]** Custom utilities declared with `@utility` use lowercase kebab-case names and behave like built-ins, including variants.
- **[convention]** Extracted components are named for what they are (`PrimaryButton`, `ProductCard`), not for their styling (`BlueRoundedBox`).
- **[convention]** Use the `prefix(tw)` import option only to avoid collisions with existing CSS. Prefixed classes are written `tw:flex`, with the prefix first.

## Language idioms

- **[convention]** Write the important modifier at the end, `bg-red-500!`, and use it sparingly. The v3 form `!bg-red-500` is outdated.
- **[convention]** Reference a CSS variable with parentheses, `bg-(--brand-color)`. The v3 form `bg-[--brand-color]` is outdated. Spaces in arbitrary values are underscores: `grid-cols-[max-content_auto]`.
- **[convention]** Use the v4 names: `shadow-xs`, `rounded-xs`, `outline-hidden`, `ring-3`, `shrink-*`, `grow-*`, and opacity by slash (`bg-black/50`). The `*-opacity-*` utilities are gone.
- **[convention]** Order variants left to right as they apply: `*:first:pt-0`. State the border and ring colour explicitly, because both now default to `currentColor`.
- **[convention]** Do not combine two utilities that set the same property. The one later in the stylesheet wins, not the one later in `class`. Choose in code.

Do:
```jsx
<div className={gridLayout ? "grid" : "flex"} />
```
Don't:
```jsx
<div className={`flex ${gridLayout ? "grid" : ""}`} />
```

## Framework conventions

- **[convention]** Define design tokens in `@theme`. Every token becomes a CSS variable and the matching utilities, so tokens are the single source of truth.
- **[convention]** Use `:root` for plain CSS variables that should not generate utilities. `@theme` must be top-level, never nested in a selector or media query.
- **[convention]** Use `@theme inline` when a token references another variable, such as a font loaded by a framework. Use `@theme static` when a token must be emitted even if unused.
- **[convention]** To replace a whole default scale, reset the namespace first (`--color-*: initial;`) and then define the tokens. Reset everything with `--*: initial;` only for a full custom system.
- **[convention]** Use a theme-backed utility whenever a token exists. Arbitrary values (`[#1da1f2]`, `[13px]`) are for genuine one-offs. Add a token when a value appears twice.
- **[convention]** Class soup rule 1: first try a loop or one multi-cursor edit. A list rendered in a loop is written once.
- **[convention]** Class soup rule 2: extract a component or partial when the same class list appears three times across files, or when one element carries more than 12 utilities. Variants, states and responsive prefixes count as separate utilities.
- **[convention]** Class soup rule 3: for a single small element such as a button, a rule in `@layer components` that uses theme variables is acceptable. Anything more complex than one element becomes a component or partial (Tailwind docs).
- **[convention]** Use `@apply` only to restyle markup you cannot edit, such as a third-party widget, or inside `<style>` blocks via `@reference`. Do not use it to rebuild a CSS framework from utilities.
- **[convention]** Define reusable single-purpose styles with `@utility`, not `@layer utilities`. In v4 a plain `@layer utilities` rule no longer creates a utility with variants.
- **[convention]** Map props to complete class strings. Never assemble class names from fragments.

Do:
```jsx
const variants = {
  blue: "bg-blue-600 hover:bg-blue-500",
  red: "bg-red-600 hover:bg-red-500",
};
<button className={`${variants[color]} px-4 py-2`}>{children}</button>
```
Don't:
```jsx
<button className={`bg-${color}-600 hover:bg-${color}-500 px-4 py-2`}>{children}</button>
```

Do:
```css
@theme {
  --color-brand-500: oklch(0.62 0.19 259);
  --breakpoint-3xl: 120rem;
}
```
Don't:
```html
<a class="bg-[#3b82f6] text-[#ffffff] min-[1920px]:p-[13px]">Buy</a>
```

Do:
```jsx
<button style={{ "--bg": userColour }} className="bg-(--bg) px-4 py-2">Save</button>
```
Don't:
```jsx
<button className={`bg-[${userColour}] px-4 py-2`}>Save</button>
```

## Error handling

- **[convention]** An unknown class produces no CSS and no error. When a style is missing, check first that the full class name appears literally in a scanned file.
- **[convention]** Scanned files exclude `.gitignore` paths, `node_modules`, binaries, CSS files and lockfiles. A class that exists only in one of those needs `@source` or `@source inline()`.
- **[convention]** Safelist with `@source inline("{hover:,}bg-red-{50,{100..900..100},950}")` for classes that come from a CMS or database. Prefer inline CSS variables for arbitrary runtime values.
- **[convention]** Keep a visible fallback for runtime-supplied colours so a missing value still leaves readable text (for example `bg-(--bg,var(--color-surface))`).

## Security

- **[convention]** Never let user input or CMS content decide class names, and never put it into a class attribute unescaped. Whitelist values and map them to complete classes. The framework's output escaping still applies.
- **[convention]** Pass runtime values through inline CSS variables set by the framework's style binding, not by concatenating strings into `style` or `<style>`.
- **[convention]** Do not paste user-supplied CSS into `@theme`, `@source` or `@plugin`. `@plugin` and `@config` execute JavaScript at build time, so load only reviewed local files or pinned packages.
- **[tool]** Pin `tailwindcss`, `@tailwindcss/*` and `prettier-plugin-tailwindcss` in the lockfile and audit them with the package manager's audit command (`npm audit`, `pnpm audit`, `composer audit` for PHP-side tooling).
- **[convention]** Do not load Tailwind from a CDN script in production. Build the CSS and serve it from your own origin so a strict Content Security Policy needs no extra sources.

## Accessibility

Target: WCAG 2.2 AA. Tailwind provides the variants; the markup and the colour choices still have to be right.

- **[convention]** Never remove the focus indicator. Use `outline-hidden`, not `outline-none`, when replacing it, so forced-colours mode still shows an outline. Always add your own `focus-visible:` style alongside it (WCAG 2.4.7).
- **[convention]** Focus styles need 3:1 contrast against adjacent colours (1.4.11). Use `focus-visible:outline-2 focus-visible:outline-offset-2` with a token colour that passes in light and dark themes.
- **[convention]** Fixed or sticky headers must not hide the focused element (2.4.11 Focus Not Obscured). Add `scroll-mt-*` or `scroll-pt-*` equal to the header height.
- **[convention]** Interactive targets are at least 24 by 24 CSS pixels (2.5.8). With the default spacing scale that is `min-h-6 min-w-6`. Aim for `min-h-11 min-w-11` on touch UI.
- **[convention]** Body text contrast is at least 4.5:1 and large text at least 3:1 (1.4.3). Check every `text-*` against its background token, including disabled and placeholder states and each `dark:` pair. Add `contrast-more:` overrides where a subtle palette is used.
- **[convention]** Respect reduced motion. Gate animation and large transitions with `motion-safe:` or neutralise them with `motion-reduce:` (`motion-reduce:animate-none`, `motion-reduce:transition-none`) (2.3.3 guidance, 2.2.2).
- **[convention]** Use `sr-only` for text that screen readers need and sighted users do not, such as an icon button label. Pair it with `focus:not-sr-only` for skip links. Do not use it to hide interactive content.
- **[convention]** Hover styles are not the only cue. Mirror them with `focus-visible:` and use `aria-*` and `data-*` variants (`aria-expanded:`, `aria-disabled:`) so styling follows real state.
- **[convention]** Do not rely on colour alone to convey state (1.4.1). Add an icon, text or underline. Use `forced-colors:` variants for custom controls that remove native appearance.
- **[convention]** Dragging must have a non-dragging alternative (2.5.7) and a repeated form field must not demand re-entry (3.3.7). Utilities do not provide either, so build both into the component.

Do:
```html
<button class="rounded px-4 py-2 min-h-11 outline-hidden focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-700">Save</button>
```
Don't:
```html
<button class="rounded px-3 py-1 outline-none">Save</button>
```

Do:
```html
<svg class="size-5 animate-spin motion-reduce:animate-none" aria-hidden="true"></svg>
<span class="sr-only">Loading</span>
```
Don't:
```html
<svg class="size-5 animate-spin"></svg>
```

## Testing conventions

- **[convention]** Do not test that a class exists on an element when the test only restates the markup. Assert behaviour and accessible state instead, such as role, name, `aria-expanded` and focus.
- **[convention]** Where class names are the observable contract of a shared component (a variant map), test the mapping function or the component's variants once, in the component's own test file, using the base profile's test framework and naming.
- **[convention]** Cover visual regressions with the project's existing screenshot or Storybook tooling, in light, dark and `forced-colors` where supported, at the project's breakpoints. Tailwind adds no test framework of its own.
- **[convention]** Add an automated accessibility check (for example axe) to component or end-to-end tests and run it with keyboard-only navigation for focus order and focus visibility.
- **[convention]** Otherwise follow the base profile's test layout, file naming and case naming.

## Documentation and comment standards

- **[convention]** Document the token set in the theme stylesheet with short comments grouped by namespace (colour roles, spacing, type). Say which tokens are the public design system.
- **[convention]** Record in the project README the Tailwind major, the CSS entry point, the Prettier setup and the supported browsers.
- **[convention]** Comment any `@apply`, `!` modifier, `@source` or `@plugin` with the reason it is needed. Uncommented ones are treated as accidents.
- **[convention]** Note v3-to-v4 migration decisions (kept `@config`, renamed utilities) in `CHANGELOG.md` or the migration PR.

## Anti-patterns

- **[convention]** Keeping a `tailwind.config.js` and `@tailwind base;` directives in a v4 project. Use `@import "tailwindcss";` and `@theme`.
- **[convention]** Using `outline-none` to hide focus. Use `outline-hidden` plus a `focus-visible:` style.
- **[convention]** Building class names by string concatenation or template fragments. Map to complete class names, or use inline CSS variables.
- **[convention]** Arbitrary values for colours, spacing and breakpoints that exist or should exist as tokens. Add a token to `@theme`.
- **[convention]** Class soup: the same long class list copied across files. Extract a component or partial.
- **[convention]** Heavy `@apply` to recreate Bootstrap-style classes. Use components, or `@layer components` for one small element.
- **[convention]** Putting `!` on utilities to win specificity fights. Fix the conflict, or use `@import "tailwindcss" important;` only when embedding in legacy CSS.
- **[convention]** Leaving animations unguarded. Add `motion-reduce:` or use `motion-safe:`.
- **[convention]** Leaving Prettier unconfigured so class order differs between files. Add `prettier-plugin-tailwindcss` last in `plugins`.
