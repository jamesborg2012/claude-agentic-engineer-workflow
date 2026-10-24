# WordPress (themes and plugins) standards seed

Versions covered: WordPress 7.1 (7.1.3 current), PHP 8.3 recommended with 7.4 as the legacy floor, MariaDB 10.11+ or MySQL 8.0+ (researched 2026-10-24; sources: context7 unavailable, official docs only: https://wordpress.org/download/releases/, https://wordpress.org/about/requirements/, https://developer.wordpress.org/coding-standards/wordpress-coding-standards/php/, https://developer.wordpress.org/themes/advanced-topics/security/, https://developer.wordpress.org/themes/global-settings-and-styles/, https://developer.wordpress.org/block-editor/getting-started/devenv/get-started-with-wp-scripts/, https://make.wordpress.org/core/handbook/testing/automated-testing/phpunit/)

Seed for hand-written WordPress themes and plugins. The repo's own conventions and tooling win over this seed.

## Tooling and commands

- **[tool]** Lint PHP with PHP_CodeSniffer and the WordPress ruleset: `composer require --dev wp-coding-standards/wpcs`, then `vendor/bin/phpcs` with a committed `.phpcs.xml.dist` (WordPress, WordPress-Extra, WordPress-Docs).
- **[tool]** Auto-fix PHP style with `vendor/bin/phpcbf` before committing (WPCS).
- **[tool]** Lint JS, CSS and format with `@wordpress/scripts`: `npm run lint-js`, `npm run lint-style`, `npm run format`, and `npm run build` for production assets (`wp-scripts`).
- **[tool]** Set `testVersion` in `.phpcs.xml.dist` to the plugin's declared minimum PHP so PHPCompatibilityWP flags newer syntax (PHPCompatibilityWP).
- **[convention]** Declare `Requires at least`, `Requires PHP` and `Tested up to` in the plugin header and `readme.txt` (or `style.css` for themes), and keep them truthful.
- **[convention]** Develop against a local `wp-env` (`npx wp-env start`) so everyone runs the same WordPress, PHP and database versions.
- **[convention]** Pin PHP dev tools in `composer.json` and JS tools in `package-lock.json`; commit both lock files.

## Project structure

- **[convention]** Plugin: one main file `my-plugin.php` with the header and bootstrap only; logic in `includes/` (or `src/`), admin code in `admin/`, front-end in `public/`, built assets in `build/`, translations in `languages/`.
- **[convention]** Block theme: `theme.json`, `style.css` (header only), `functions.php`, `templates/`, `parts/`, `patterns/`, `styles/` (style variations), `assets/`.
- **[convention]** Classic theme: `functions.php`, `header.php`, `footer.php`, `template-parts/`, `inc/`; put features that must outlive the theme in a plugin, not the theme.
- **[convention]** Customise a third-party theme through a child theme (`style.css` with `Template:`, plus `functions.php`), never by editing the parent.
- **[convention]** Guard every PHP file against direct access with `defined( 'ABSPATH' ) || exit;`.
- **[convention]** Keep `vendor/`, `node_modules/` and `build/` out of version control unless the release process requires built assets.

## Naming

- **[tool]** Functions, variables and hooks use `lowercase_with_underscores`; constants are `UPPERCASE` (WordPress.NamingConventions.ValidFunctionName, ValidVariableName).
- **[tool]** Classes, interfaces and traits use `Capitalised_Words_With_Underscores`, with acronyms in capitals (`WP_HTTP`) (WordPress.NamingConventions).
- **[tool]** Class files are `class-my-thing.php`: lowercase, hyphens, `class-` prefix, one class per file (WordPress.Files.FileName).
- **[convention]** Prefix every global (functions, classes, options, hooks, post meta keys, script handles) with a unique 4+ character slug, or use one namespace such as `Vendor\Project_Name`. Never use the reserved `wp`, `WordPress` or `__` prefixes.
- **[convention]** Prefix option names, transients and custom post type, taxonomy and REST namespace slugs (for example `acme_settings`, `acme/v1`).

## Language idioms

- **[tool]** Use Yoda conditions: `if ( 'draft' === $status )` (WordPress.PHP.YodaConditions).
- **[tool]** Use long array syntax `array( 1, 2 )`, always use braces, `elseif` not `else if`, and full `<?php` tags (WordPress-Core).
- **[tool]** Indent with tabs; put spaces inside parentheses and around operators; no assignments in conditions (WordPress-Core).
- **[tool]** Compare strictly (`===`) and pass `true` as the strict argument to `in_array()` (WordPress.PHP.StrictInArray).
- **[convention]** JS follows the WordPress JS standards (ESLint via `@wordpress/eslint-plugin`): tabs, single quotes, spaces inside brackets, `const`/`let` only.
- **[tool]** CSS follows the WordPress CSS standards via Stylelint (`@wordpress/stylelint-config`): tabs, lowercase hyphenated classes, one selector per line, no ID selectors for styling.
- **[convention]** Declare `declare( strict_types=1 );` only in new code that does not call untyped WordPress APIs loosely; use type declarations and return types within the declared minimum PHP.

Do:
```php
if ( 'publish' === $post->post_status && ! empty( $items ) ) {
	$ids = array( 1, 2, 3 );
}
```
Don't:
```php
if ($post->post_status == 'publish' && !empty($items)) $ids = [1, 2, 3];
```

## Framework conventions

- **[convention]** Extend WordPress through hooks (`add_action`, `add_filter`) and the public API. Never edit WordPress core, bundled plugins or a parent theme; the change is lost on update.
- **[convention]** Register hooks in one bootstrap per feature, named callbacks or class methods, with an explicit priority only when order matters. Unhook with `remove_action` using the same priority.
- **[convention]** Load assets only through `wp_enqueue_script()` and `wp_enqueue_style()` on `wp_enqueue_scripts` or `admin_enqueue_scripts`, with a handle, dependencies, a version, and `strategy`/`in_footer` arguments. Never print `<script>` or `<link>` tags by hand.
- **[convention]** Pass data to scripts with `wp_add_inline_script()` or `wp_localize_script()`/script modules data, never by echoing inline JS.
- **[convention]** Make every user-facing string translatable with a literal text domain matching the plugin or theme slug; load it with `load_plugin_textdomain()`/`load_theme_textdomain()` where required.
- **[tool]** The text domain argument must be a string literal, never a variable or constant (WordPress.WP.I18n).
- **[tool]** Use translator comments for placeholders and `_n()` for plurals, and number placeholders (`%1$s`) when there are several (WordPress.WP.I18n).
- **[convention]** Store settings with the Settings API (`register_setting`, `add_settings_field`) and expose data with REST routes via `register_rest_route` with a `permission_callback`.
- **[convention]** Block themes: define colours, typography, spacing and layout in `theme.json` rather than ad hoc CSS; use block patterns and template parts instead of PHP templates.
- **[convention]** Run activation, deactivation and uninstall work through `register_activation_hook`, `register_deactivation_hook` and `uninstall.php`; uninstall removes the plugin's options and tables.
- **[convention]** Cache expensive queries with the transients or object cache API and give each entry an expiry.

Do:
```php
function acme_enqueue_assets() {
	wp_enqueue_script( 'acme-app', plugins_url( 'build/app.js', __FILE__ ), array( 'wp-element' ), ACME_VERSION, array( 'in_footer' => true ) );
}
add_action( 'wp_enqueue_scripts', 'acme_enqueue_assets' );
```
Don't:
```php
echo '<script src="/wp-content/plugins/acme/app.js"></script>';
```

Do:
```php
$label = __( 'Save changes', 'acme-plugin' );
```
Don't:
```php
$label = __( 'Save changes', $text_domain );
```

## Error handling

- **[convention]** Return `WP_Error` from functions that can fail, and check with `is_wp_error()`; do not `die()` or `exit` outside of AJAX/REST handlers.
- **[convention]** In REST callbacks return `WP_Error` with a status in `data`, or a `WP_REST_Response`; in AJAX use `wp_send_json_error()`.
- **[convention]** Log with `error_log()` only behind `WP_DEBUG`/`WP_DEBUG_LOG`; never leave `var_dump`, `print_r` or `error_log` calls in released code.
- **[tool]** Do not use the error suppression operator `@` or debug functions in production code (WordPress.PHP.NoSilencedErrors, WordPress.PHP.DevelopmentFunctions).
- **[convention]** Show users a translated, generic message; keep stack traces and SQL out of the output. Use `wp_die()` only with a safe message and a response code.
- **[convention]** Check the result of `wp_remote_get()`/`wp_remote_post()` with `is_wp_error()` and `wp_remote_retrieve_response_code()` before using the body.

## Security

- **[convention]** Sanitise early (on input), validate, and escape late (on output). Treat all of `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_SERVER` and remote data as untrusted.
- **[tool]** Escape every dynamic value at the point of output with the function matching the context: `esc_html()`, `esc_attr()`, `esc_url()`, `esc_js()`, `esc_textarea()`, or `wp_kses_post()`/`wp_kses()` with an allowlist where HTML is intended (WordPress.Security.EscapeOutput).
- **[tool]** Sanitise input with `sanitize_text_field()`, `sanitize_email()`, `absint()`, `sanitize_key()`, `wp_unslash()` first, and so on (WordPress.Security.ValidatedSanitizedInput).
- **[tool]** Protect every state-changing form or link with a nonce: `wp_nonce_field()` and `check_admin_referer()` for admin forms, `wp_verify_nonce()` for AJAX and custom handlers, `wp_create_nonce()` for URLs (WordPress.Security.NonceVerification).
- **[convention]** A nonce proves intent, not authority. Always pair it with a capability check: `current_user_can( 'manage_options' )` or the narrowest capability that fits; check against a specific object (`current_user_can( 'edit_post', $id )`) when one exists.
- **[convention]** Every REST route and AJAX handler has a `permission_callback` or capability check; `__return_true` is allowed only for genuinely public data.
- **[tool]** Build SQL with `$wpdb->prepare()` and placeholders `%s`, `%d`, `%f`; use `$wpdb->insert()`/`update()` where they suffice; `%i` for identifiers (WordPress.DB.PreparedSQL).
- **[convention]** Never store secrets in the repo or in options in plain text; read them from `wp-config.php` constants or environment variables.
- **[convention]** Validate uploads with `wp_check_filetype_and_ext()` and handle them through `wp_handle_upload()`.
- **[convention]** Redirect with `wp_safe_redirect()` and `exit` after it; validate redirect targets with `wp_validate_redirect()`.
- **[convention]** Keep Composer and npm dependencies patched; run `composer audit` and `npm audit`.

Do:
```php
if ( ! isset( $_POST['acme_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['acme_nonce'] ) ), 'acme_save' ) || ! current_user_can( 'manage_options' ) ) {
	wp_die( esc_html__( 'Not allowed.', 'acme-plugin' ), '', array( 'response' => 403 ) );
}
$name = sanitize_text_field( wp_unslash( $_POST['name'] ?? '' ) );
```
Don't:
```php
update_option( 'acme_name', $_POST['name'] );
```

Do:
```php
echo '<a href="' . esc_url( $url ) . '">' . esc_html( $title ) . '</a>';
$rows = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->posts} WHERE post_author = %d", $author_id ) );
```
Don't:
```php
echo '<a href="' . $url . '">' . $title . '</a>';
$rows = $wpdb->get_results( "SELECT * FROM {$wpdb->posts} WHERE post_author = $author_id" );
```

## Accessibility

Target: WCAG 2.2 AA, plus the WordPress accessibility-ready requirements for themes.

- **[convention]** Use semantic landmarks (`header`, `nav`, `main`, `footer`) and one `h1` per page; do not skip heading levels.
- **[convention]** Provide a "Skip to content" link as the first focusable element, visible on focus, and keep the `screen-reader-text` utility class.
- **[convention]** Every interactive element is keyboard operable with a visible focus indicator (2.4.7) that is not hidden behind sticky headers (2.4.11 Focus Not Obscured).
- **[convention]** Targets are at least 24 by 24 CSS pixels or adequately spaced (2.5.8 Target Size Minimum); drag interactions have a single-pointer alternative (2.5.7).
- **[convention]** Authentication and forms do not rely on cognitive tests (3.3.8); do not ask for the same information twice in a flow (3.3.7); keep help in a consistent place (3.2.6).
- **[convention]** Text contrast is at least 4.5:1 (3:1 for large text and UI components); configure colour palettes in `theme.json` to meet it.
- **[convention]** Every `<img>` has meaningful `alt` text, or `alt=""` when decorative; form fields have associated `<label>`s and error messages tied by `aria-describedby`.
- **[convention]** Use ARIA only where native HTML cannot express the role, and use `wp.a11y.speak()` to announce dynamic updates.
- **[convention]** Respect `prefers-reduced-motion` and let content reflow at 320px width and 200% zoom.

Do:
```html
<button type="button" class="menu-toggle" aria-expanded="false" aria-controls="primary-menu">Menu</button>
```
Don't:
```html
<div class="menu-toggle" onclick="toggleMenu()">Menu</div>
```

## Testing conventions

- **[tool]** PHP tests use PHPUnit with the WordPress test scaffold: `WP_UnitTestCase`, the Yoast PHPUnit Polyfills (`WP_TESTS_PHPUNIT_POLYFILLS_PATH`), and a separate test database (wp-tests-config).
- **[convention]** Run PHP tests inside `wp-env` (`npx wp-env run tests-cli --env-cwd=wp-content/plugins/my-plugin vendor/bin/phpunit`) so the environment matches CI.
- **[convention]** Keep PHP tests in `tests/phpunit/`, named `test-*.php` or `*Test.php` per `phpunit.xml.dist`, class `Acme_Feature_Test`, methods `test_<behaviour>`.
- **[convention]** Use the factory (`self::factory()->post->create()`) and `set_up()`/`tear_down()` (calling the parent) instead of hand-made data; tests must not depend on order.
- **[convention]** Test multisite code with a separate `multisite.xml` configuration and tag slow groups with `@group`.
- **[tool]** JS unit tests run with `npm run test-unit-js` (`wp-scripts`) and live beside the source as `*.test.js` or in `__tests__/`.
- **[tool]** End-to-end tests use `npm run test-e2e` with Playwright and `@wordpress/e2e-test-utils-playwright`, under `tests/e2e/`.
- **[convention]** CI runs `phpcs`, PHPUnit on the minimum and latest supported PHP, `lint-js`, `lint-style`, JS tests and `build` before merge.

## Documentation and comment standards

- **[tool]** Document every function, class, method, hook and file with a PHPDoc block per the WordPress inline documentation standards (WordPress-Docs).
- **[convention]** Document each custom action and filter with a docblock above `do_action()`/`apply_filters()`: description, `@since`, `@param`.
- **[convention]** Use `@since` with the plugin version, and keep `readme.txt` (`== Changelog ==`, `Stable tag`) in step with releases.
- **[convention]** Write comments in sentences, explain why rather than what, and keep inline comments on their own line above the code.
- **[convention]** Keep a changelog (Keep a Changelog) and note hook or option changes under their own heading.

## Anti-patterns

- **[convention]** Editing core, a parent theme or another plugin's files; use hooks, filters or a child theme instead.
- **[convention]** Hard-coded `<script>`/`<link>` tags in templates; use the enqueue functions.
- **[convention]** Echoing unescaped or unsanitised request data; sanitise on input and escape on output.
- **[convention]** Checking a nonce without a capability check, or a capability check without a nonce on state changes.
- **[convention]** Raw SQL with interpolated variables; use `$wpdb->prepare()`.
- **[convention]** Unprefixed globals and generic names such as `function get_data()`; prefix or namespace everything.
- **[convention]** Variable text domains or concatenated translation strings; use literal domains and placeholders with `sprintf()`.
- **[convention]** Heavy work on every request (queries in loops, `get_posts()` with `numberposts => -1`, remote calls on page load); cache and paginate.
- **[convention]** Using `extract()`, `eval()`, `query_posts()`, `$_REQUEST` or the `@` operator.
- **[convention]** Putting site-critical features in a theme; move them into a plugin so a theme switch does not remove them.
