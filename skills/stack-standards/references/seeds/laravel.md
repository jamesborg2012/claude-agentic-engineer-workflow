# Laravel standards seed

Versions covered: Laravel 13.x (requires PHP 8.3+; Laravel 12.x on PHP 8.2+ remains supported, bug fixes to 2026-08-13, security fixes to 2027-02-24) (researched 2026-10-24; sources: context7 unavailable, https://laravel.com/docs/13.x/releases, /validation, /eloquent, /csrf, /configuration, /testing, /database-testing, /pint, https://laravel.com/docs/master/*)

Seed for the standards-setter. Rules marked **[tool]** are enforced by Laravel's default or official tooling (Pint, Artisan, the framework itself). Larastan/PHPStan is not part of a default install, so rules that rely on it are **[convention]**. Where Laravel 12 and 13 differ, the difference is stated.

## Tooling and commands

- **[tool]** Run `composer install`, then `cp .env.example .env && php artisan key:generate` for a fresh checkout (Artisan).
- **[tool]** Format with `./vendor/bin/pint`; check in CI with `./vendor/bin/pint --test`, or `--dirty` locally for changed files (Laravel Pint, `laravel` preset by default).
- **[tool]** Run tests with `php artisan test` (or `./vendor/bin/pest` / `./vendor/bin/phpunit`); add `--parallel` with `brianium/paratest`, and `--coverage --min=<n>` to enforce a threshold (Artisan test runner).
- **[tool]** Inspect the app with `php artisan about`, `php artisan route:list` and `php artisan config:show <file>` (Artisan).
- **[tool]** Generate classes with `php artisan make:*` (`make:request`, `make:policy`, `make:model -mfc`, `make:job`) rather than hand-creating them (Artisan).
- **[tool]** Run `php artisan config:cache`, `route:cache`, `view:cache` and `event:cache` (or `php artisan optimize`) on deploy, never in local development (Artisan).
- **[convention]** Add Larastan (`larastan/larastan`, PHPStan level 5 or higher, raised over time) with a committed `phpstan.neon`, and run it in CI beside Pint and the test suite.
- **[convention]** Pin the framework with a caret constraint, for example `"laravel/framework": "^13.0"`, and commit `composer.lock`.
- **[convention]** Keep a `composer` script (for example `composer test`) that runs Pint `--test`, static analysis and the suite, so agents and CI use one command.

## Project structure

- **[convention]** Follow the stock layout: `app/Http/Controllers`, `app/Http/Requests`, `app/Models`, `app/Policies`, `app/Jobs`, `app/Providers`, `routes/`, `resources/views`, `database/{migrations,factories,seeders}`, `tests/{Feature,Unit}`.
- **[convention]** Bootstrap middleware, routing and exceptions in `bootstrap/app.php` (the Laravel 11+ skeleton has no `Http/Kernel.php`).
- **[convention]** Keep controllers thin: validate through a Form Request, authorise through a policy, delegate to an action or service class, return a response or resource.
- **[convention]** Put business logic in single-purpose action classes (`app/Actions`) or services, not in models, controllers or Blade views.
- **[convention]** Register route files in `bootstrap/app.php`; group routes by middleware, and name every route.
- **[convention]** One migration per schema change; never edit a migration that has run in a shared environment.

## Naming

- **[tool]** Pint's `laravel` preset enforces PSR-12-based formatting, import ordering and trailing commas (Pint `laravel` preset).
- **[convention]** Classes `StudlyCase`, methods and variables `camelCase`, config keys and database columns `snake_case`.
- **[convention]** Models are singular (`Invoice`), tables plural snake case (`invoices`), pivot tables the two singular names in alphabetical order (`post_tag`).
- **[convention]** Controllers are `{Resource}Controller`; Form Requests `{Action}{Resource}Request` (`StorePostRequest`); policies `{Model}Policy`; jobs are imperative (`ProcessPodcast`).
- **[convention]** Use resource routes and standard action names (`index`, `create`, `store`, `show`, `edit`, `update`, `destroy`); route names are dotted (`posts.show`).
- **[convention]** Migration files use the Artisan timestamp prefix and a descriptive verb (`add_status_to_orders_table`).

## Language idioms

- **[convention]** Start every PHP file with `declare(strict_types=1);` unless the repo's existing code does not.
- **[convention]** Type every parameter, return and property; use `: void`, `: never`, union types and readonly properties (PHP 8.3).
- **[convention]** Use constructor property promotion and enums (backed enums with Eloquent casts) instead of class constants and magic strings.
- **[convention]** Prefer collections and Eloquent query methods over manual loops that build arrays.
- **[convention]** Use named arguments for your own code, but with caution for framework calls: parameter names are not covered by Laravel's backwards-compatibility promise.
- **[convention]** Laravel 13 offers first-party PHP attributes (`#[Middleware]`, `#[Authorize]`, `#[Tries]`, `#[Fillable]`, `#[Table]`). Follow what the repo already uses; do not mix attribute and property styles on one class.

## Framework conventions

- **[convention]** Validate with a Form Request (`php artisan make:request StorePostRequest`) and read input with `$request->validated()` or `$request->safe()`, never `$request->all()`.
- **[convention]** Keep `authorize()` in the Form Request calling a policy or gate (`$this->user()->can('update', $this->post)`); return `true` only when authorisation is handled elsewhere.
- **[convention]** Authorise through policies (`php artisan make:policy`) and gates; call `$this->authorize()`, `Gate::authorize()`, the `can` middleware or, in Laravel 13, `#[Authorize]`.
- **[tool]** Protect against mass assignment: declare `$fillable` (or `#[Fillable([...])]` in Laravel 13) on every model; never unguard globally (Eloquent).
- **[tool]** Call `Model::preventLazyLoading(! app()->isProduction())` and `Model::preventSilentlyDiscardingAttributes()` in `AppServiceProvider::boot()` to surface N+1 queries and dropped attributes in development (Eloquent strictness).
- **[convention]** Eager load relationships with `with()` (or `load()`), select only the columns you need, and use `chunkById`/`lazy()` for large result sets.
- **[convention]** Wrap multi-write operations in `DB::transaction()` and dispatch queued work with `afterCommit` so jobs never run against uncommitted rows.
- **[convention]** Queue slow work (mail, webhooks, exports) as jobs implementing `ShouldQueue`; make them idempotent, and set tries, backoff and timeout (`$tries`, or `#[Tries]`/`#[Backoff]`/`#[Timeout]` in Laravel 13).
- **[convention]** Return API output through API Resources (`JsonResource`); Laravel 13 also ships JSON:API resources.
- **[tool]** Read configuration with `config('app.name')` everywhere except `config/*.php`; `env()` returns `null` once `config:cache` has run (Laravel configuration).
- **[convention]** Put model casts, relationships and scopes on the model; keep factories in `database/factories` and use them in tests and seeders.

Do:
```php
public function store(StorePostRequest $request): RedirectResponse
{
    $post = Post::create($request->validated());

    return to_route('posts.show', $post);
}
```
Don't:
```php
public function store(Request $request)
{
    $post = Post::create($request->all());
    return redirect('/posts/'.$post->id);
}
```

Do:
```php
$posts = Post::with('author')->latest()->paginate(20);
```
Don't:
```php
$posts = Post::all();
foreach ($posts as $post) { echo $post->author->name; }
```

Do:
```php
// config/services.php
'stripe' => ['secret' => env('STRIPE_SECRET')],
// app code
$secret = config('services.stripe.secret');
```
Don't:
```php
$secret = env('STRIPE_SECRET'); // null after config:cache
```

## Error handling

- **[convention]** Render and report exceptions in `bootstrap/app.php` via `->withExceptions(function (Exceptions $exceptions) { ... })`; use `$exceptions->report()` and `->render()` for domain exceptions.
- **[convention]** Throw domain-specific exceptions; give them `report()`/`render()` methods or implement `Responsable` when they own their HTTP response.
- **[convention]** Use `abort_if()`, `abort_unless()` and `findOrFail()`/`firstOrFail()` for HTTP-level failures; let the framework turn them into 404/403 responses.
- **[tool]** Validation failures return a redirect with flashed errors, or a 422 JSON response for XHR/JSON requests; do not hand-roll these (Validator).
- **[convention]** Log with `Log::` and structured context arrays (`Log::warning('Payment failed', ['order' => $order->id])`); never log secrets, tokens or full request bodies.
- **[tool]** Keep `APP_DEBUG=false` in production; debug mode exposes configuration values (Laravel configuration).
- **[convention]** Failed jobs: define `failed()` or `$exceptions->throttle()`, and monitor the `failed_jobs` table.

## Security

- **[tool]** Keep CSRF protection on: `@csrf` in every non-GET Blade form, `X-CSRF-TOKEN`/`X-XSRF-TOKEN` for AJAX. Laravel 13 names the middleware `PreventRequestForgery` and checks `Sec-Fetch-Site` first (Laravel 12: `ValidateCsrfToken`); exclude only webhook routes, ideally by routing them outside the `web` group (CSRF middleware).
- **[tool]** Escape output with `{{ $value }}`; `{!! $value !!}` is unescaped and only allowed for content that is already sanitised or fully trusted (Blade).
- **[tool]** Use Eloquent or the query builder with bindings; never concatenate user input into `DB::raw()`, `whereRaw()` or `orderByRaw()` without bindings (PDO bindings).
- **[tool]** Hash passwords with `Hash::make()`/the `hashed` cast; never store or compare plain text (Hash facade).
- **[tool]** Never commit `.env`; keep `.env.example` with placeholders, or use `php artisan env:encrypt` for committed secrets (Laravel configuration).
- **[tool]** Use `Route::middleware('auth')` (or `auth:sanctum` for APIs), `throttle` for login and public APIs, and signed URLs for one-off links (Laravel middleware).
- **[convention]** Authorise every action on every model with a policy, including API and queue entry points; do not rely on hidden UI.
- **[convention]** Validate file uploads (`file`, `mimes`, `max`), store them on a non-public disk, and never trust the client file name.
- **[convention]** Use Sanctum for first-party SPA/mobile tokens; set `secure`, `http_only` and `same_site` session cookie options for production.
- **[convention]** Run `composer audit` in CI and keep the framework on a supported release line.

Do:
```blade
<p>{{ $comment->body }}</p>
```
Don't:
```blade
<p>{!! $comment->body !!}</p>
```

## Accessibility

Target: WCAG 2.2 AA. Laravel renders HTML on the server, so accessibility lives in Blade templates and the component library you choose (Livewire/Flux, Inertia with React/Vue/Svelte, or plain Blade).

- **[convention]** Associate every input with a `<label for>`; show `$errors` text next to the field, link it with `aria-describedby` and set `aria-invalid="true"` on the input.
- **[convention]** Render a validation summary after a failed submit and move focus to it (or the first invalid field) so errors are announced; WCAG 3.3.1 and 3.3.3.
- **[convention]** Avoid forcing users to re-enter information already provided in the same flow; use `old()` and autocomplete attributes (WCAG 2.2: 3.3.7 Redundant Entry).
- **[convention]** Authentication must not depend on a cognitive test: allow paste into password fields, `autocomplete` hints and password managers, and offer passkeys or magic links (WCAG 2.2: 3.3.8 Accessible Authentication).
- **[convention]** Pointer targets are at least 24 by 24 CSS pixels (WCAG 2.2: 2.5.8 Target Size) and drag-only interactions have a click or keyboard alternative (2.5.7 Dragging Movements).
- **[convention]** Focused elements must not be hidden by sticky headers or cookie banners (WCAG 2.2: 2.4.11 Focus Not Obscured).
- **[convention]** Use semantic landmarks (`header`, `nav`, `main`, `footer`), one `h1` per page and a "skip to content" link in the layout.
- **[convention]** Set `lang` on `<html>` from `app()->getLocale()`, and give meaningful `alt` text to images (empty `alt=""` for decorative ones).
- **[convention]** Flash messages from `session('status')` go in a container with `role="status"` (or `role="alert"` for errors).
- **[convention]** Test pages with keyboard-only navigation and an automated checker such as axe in the browser test suite (Dusk or Pest browser tests).

Do:
```blade
<label for="email">Email</label>
<input id="email" name="email" type="email" value="{{ old('email') }}" autocomplete="email"
       @error('email') aria-invalid="true" aria-describedby="email-error" @enderror>
@error('email') <p id="email-error">{{ $message }}</p> @enderror
```
Don't:
```blade
<input name="email" placeholder="Email">
@error('email') <span style="color:red"></span> @enderror
```

## Testing conventions

- **[tool]** Laravel supports Pest and PHPUnit equally, with `phpunit.xml` preconfigured; follow whichever the repo already uses and do not mix them in one suite (Laravel testing docs).
- **[tool]** Feature tests live in `tests/Feature` (full HTTP, database, container) and unit tests in `tests/Unit` (no application boot, so no database or facades); write mostly feature tests (Laravel testing docs).
- **[tool]** Use `RefreshDatabase` on tests that touch the database (`pest()->use(RefreshDatabase::class)` or `use RefreshDatabase`); it wraps each test in a transaction (Illuminate testing traits).
- **[tool]** Create data with model factories (`User::factory()->create()`), not hand-written inserts or shared fixtures (Eloquent factories).
- **[tool]** Tests run with `APP_ENV=testing`, array session and cache drivers, and CSRF disabled; override extra values in `phpunit.xml` or `.env.testing` and run `config:clear` first (Laravel testing docs).
- **[convention]** Name Pest tests as sentences (`it('rejects a post without a title')`) and PHPUnit methods `test_snake_case_describing_behaviour` in `{Subject}Test` classes mirroring the source path.
- **[convention]** Assert behaviour through HTTP and the database: `assertStatus`, `assertRedirect`, `assertSessionHasErrors`, `assertDatabaseHas`, `assertForbidden` for policy denials.
- **[convention]** Fake side effects with `Queue::fake()`, `Mail::fake()`, `Event::fake()` and `Http::fake()`; assert on the dispatched job or event, not the internals.
- **[convention]** Test authorisation both ways: the permitted user succeeds, an unprivileged user and a guest are refused.
- **[convention]** Add a regression test with every bug fix; keep tests independent of order and of each other's data.

Do:
```php
it('rejects a post without a title', function () {
    $this->actingAs(User::factory()->create())
        ->post('/posts', ['body' => 'x'])
        ->assertSessionHasErrors('title');
});
```
Don't:
```php
it('works', function () {
    DB::table('users')->insert(['id' => 1, 'name' => 'a']); // shared state, no RefreshDatabase
    expect(true)->toBeTrue();
});
```

## Documentation and comment standards

- **[convention]** Do not add docblocks that restate the type signature; document intent, side effects and thrown exceptions.
- **[convention]** Use generic-array docblocks where native types cannot express shape, for example `@return array<string, ValidationRule|array<mixed>|string>` on `rules()`; static analysis relies on them.
- **[convention]** Comment the "why" (business rule, workaround, ticket reference), not the "what".
- **[convention]** Keep `.env.example` complete and commented for every variable the app reads, and describe required services in the README.
- **[convention]** Record schema decisions in the migration name and, when non-obvious, a short comment; record API changes in the changelog and OpenAPI/Scribe docs if used.
- **[convention]** Update `README` setup steps and `CHANGELOG.md` (Keep a Changelog) in the same PR as the behaviour change.

## Anti-patterns

- **[convention]** Fat controllers and fat models: move orchestration to action or service classes.
- **[convention]** `Model::unguard()` or `protected $guarded = []` as a shortcut: list `$fillable` and pass `validated()` data.
- **[convention]** `env()` outside `config/`: read `config()` instead.
- **[convention]** Querying inside Blade or loops: eager load in the controller and pass the data.
- **[convention]** Validating in the controller with `$request->validate()` for non-trivial rules: use a Form Request so rules, messages and authorisation live together.
- **[convention]** Skipping authorisation because "the route is behind `auth`": authentication is not authorisation.
- **[convention]** Dispatching jobs inside an open transaction without `afterCommit`.
- **[convention]** Running destructive Artisan database resets or wipes against shared databases; add a new migration instead.
- **[convention]** Disabling CSRF for a whole route group to make a form or client "work": fix the token or move only the webhook route.

Do:
```php
DB::transaction(function () use ($order) {
    $order->markPaid();
    SendReceipt::dispatch($order)->afterCommit();
});
```
Don't:
```php
DB::transaction(function () use ($order) {
    $order->markPaid();
    SendReceipt::dispatch($order); // may run before the commit
});
```
