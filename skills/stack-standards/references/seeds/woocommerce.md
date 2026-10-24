# WooCommerce standards seed

Versions covered: WooCommerce 11.2 (11.2.1 current stable; 11.6 will require PHP 8.1) on the wordpress base profile (researched 2026-10-24; sources: context7 unavailable, https://developer.woocommerce.com/2026/, https://developer.woocommerce.com/docs/features/high-performance-order-storage/recipe-book/, https://developer.woocommerce.com/docs/block-development/extensible-blocks/cart-and-checkout-blocks/, https://developer.woocommerce.com/docs/theming/theme-development/template-structure/)
Overlay on: wordpress

## Tooling and commands

- **[convention]** Develop against the current stable WooCommerce, and test against the development version before each release, so HPOS and block changes surface early.
- **[tool]** Run the WordPress coding standards with `phpcs` using the `WordPress` ruleset plus `woocommerce/woocommerce-sniffs`, which is the ruleset WooCommerce core uses (phpcs.xml).
- **[tool]** Run `phpcs` with `PHPCompatibilityWP` and set `testVersion` to the minimum PHP you declare, which WooCommerce 11.6 raises to 8.1 (PHPCompatibilityWP).
- **[convention]** Provide `composer lint`, `composer test` and `composer fix` scripts so the commands do not depend on a global install.
- **[convention]** Run unit tests with PHPUnit on the WordPress test suite, with WooCommerce loaded as a dependency, and run `wp-env` or an equivalent container for integration and end-to-end tests.

## Project structure

- **[convention]** Keep one main plugin file that holds the headers, the HPOS and blocks declarations, and the bootstrap. Put logic in `includes/` or `src/` classes, not in the main file.
- **[convention]** Keep plugin templates in `templates/`, mirroring WooCommerce's own paths so a theme can override them, and load them through `wc_get_template()` or `wc_get_template_part()`.
- **[convention]** Keep block code under `blocks/` or `assets/js/blocks/`, with the build output in a gitignored `build/` directory.
- **[convention]** Keep the unit tests in `tests/`, mirroring `src/`.

## Naming

- **[tool]** Prefix functions, hooks, options, meta keys and global names with a unique prefix, or use a namespace (WordPress.NamingConventions.PrefixAllGlobals).
- **[convention]** Never use the `wc_` or `woocommerce_` prefix for your own functions, hooks or options. Those belong to WooCommerce core.
- **[convention]** Name custom order statuses, product types and endpoints with your own prefix. Custom order statuses are stored as `wc-<slug>` and the slug must be 17 characters or fewer.
- **[convention]** Name the text domain after the plugin slug, matching the `Text Domain` header.

## Language idioms

No overlay additions; see the base profile.

## Framework conventions

- **[convention]** Declare `Requires Plugins: woocommerce`, `WC requires at least` and `WC tested up to` in the main plugin header, and keep `WC tested up to` current each release.
- **[convention]** Also check that WooCommerce is active at runtime, on `plugins_loaded`, before touching any `WC_*` class, and show an admin notice rather than a fatal error if it is not.
- **[convention]** Declare HPOS compatibility on `before_woocommerce_init` with `FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true )`. Declare `false` honestly if the extension is not compatible.
- **[convention]** Declare `cart_checkout_blocks` compatibility in the same way if the extension touches the cart or checkout. Extensions unrelated to checkout need no declaration.
- **[convention]** Read and write orders, products, coupons and customers through CRUD objects: `wc_get_order()`, `wc_get_product()`, their getters and setters, then `save()`.
- **[convention]** Store extension data with `$order->update_meta_data()` and `$order->save()`, and read it with `$order->get_meta()`. This works with both HPOS and post storage.
- **[convention]** Save once per object after batching changes, because `save()` is expensive. Do not call it in a loop for one object.
- **[convention]** Query orders with `wc_get_orders()` and products with `wc_get_products()`, using `WC_Order_Query` arguments, not `WP_Query` or SQL on `wp_posts` or `wp_postmeta`.
- **[convention]** Check order types with `OrderUtil::is_order()` or `OrderUtil::get_order_type()`, not `get_post_type()`.
- **[convention]** If a custom data store is unavoidable, extend the CRUD data store classes and register it with the `woocommerce_data_stores` filter. Never write directly to WooCommerce tables.
- **[convention]** Customise through actions and filters (`woocommerce_*`) before overriding a template. Hooks survive WooCommerce upgrades; overrides drift.
- **[convention]** If a template override is unavoidable, copy only that file into `yourtheme/woocommerce/`, keep its `@version` docblock tag, and diff it against core on every WooCommerce release. WooCommerce flags outdated overrides in its status report.
- **[convention]** Extend the Cart and Checkout blocks through the Store API (`ExtendSchema`), the `IntegrationInterface` and the Additional Checkout Fields API. Do not rely on classic checkout hooks, which do not run in blocks.
- **[convention]** Register payment gateways as `WC_Payment_Gateway` subclasses, and add a blocks payment method integration so the gateway works in block checkout.
- **[convention]** Use WooCommerce's own settings API and `WC_Settings_Page` for settings screens, and its `wc_get_logger()` for logging.
- **[convention]** Use `wc_get_price_decimals()` and `wc_price()` for money. Do not hard-code decimals or currency symbols.

Do:
```php
add_action( 'before_woocommerce_init', function () {
	if ( class_exists( \Automattic\WooCommerce\Utilities\FeaturesUtil::class ) ) {
		\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
	}
} );
```
Don't:
```php
// No declaration: WooCommerce shows the extension as incompatible with HPOS.
register_activation_hook( __FILE__, 'acme_activate' );
```

Do:
```php
$order = wc_get_order( $order_id );
$order->update_meta_data( '_acme_ref', $ref );
$order->save();
```
Don't:
```php
update_post_meta( $order_id, '_acme_ref', $ref );
$ref = get_post_meta( $order_id, '_acme_ref', true );
```

Do:
```php
foreach ( wc_get_orders( array( 'status' => 'processing', 'limit' => 50 ) ) as $order ) {
	$total = $order->get_total();
}
```
Don't:
```php
$orders = get_posts( array( 'post_type' => 'shop_order', 'post_status' => 'wc-processing' ) );
```

Do:
```php
woocommerce_store_api_register_endpoint_data( array(
	'endpoint'        => 'cart',
	'namespace'       => 'acme',
	'data_callback'   => 'acme_cart_data',
	'schema_callback' => 'acme_cart_schema',
) );
```
Don't:
```php
add_action( 'woocommerce_after_order_notes', 'acme_gift_field' ); // not rendered by block checkout
```

Do:
```php
add_action( 'woocommerce_before_add_to_cart_button', 'acme_render_engraving_field' );
```
Don't:
```php
// Copying single-product/add-to-cart/simple.php into the theme to add one field.
```

## Error handling

- **[convention]** Return `WP_Error` from your own functions, and throw `WC_Data_Exception` from setters. Catch it where the user input enters.
- **[convention]** Report checkout validation problems with `wc_add_notice( $message, 'error' )` in classic checkout, and by throwing `\Automattic\WooCommerce\StoreApi\Exceptions\RouteException` or a `woocommerce_store_api_*` validation hook in block checkout.
- **[convention]** Log through `wc_get_logger()` with a `source` context, at the right level. Never use `error_log()` or `var_dump()` in shipped code.
- **[convention]** Do not log personal data: no names, emails, addresses, card data or full request bodies. Log order IDs instead.
- **[convention]** Check `$order` for `false` after `wc_get_order()` before calling methods on it. A refund or a missing order returns a different object or `false`.
- **[convention]** Show customers a plain message and log the technical detail. Payment errors must not leak gateway responses.

Do:
```php
$logger = wc_get_logger();
$logger->error( 'Capture failed', array( 'source' => 'acme-gateway', 'order_id' => $order->get_id() ) );
```
Don't:
```php
error_log( 'Capture failed for ' . $order->get_billing_email() . ' card ' . $card );
```

## Security

- **[convention]** Gate admin actions with `current_user_can( 'manage_woocommerce' )` or a narrower capability such as `edit_shop_orders`, never only `is_admin()`.
- **[tool]** Verify nonces on every state-changing request and escape every output, sanitising input at entry (WordPress.Security.NonceVerification, WordPress.Security.EscapeOutput).
- **[convention]** Treat order, customer and payment data as personal data. Collect the minimum, keep it out of logs and URLs, and register exporters and erasers with the WordPress privacy hooks.
- **[convention]** Never store card numbers, CVVs or raw gateway secrets. Use the gateway's tokens through `WC_Payment_Tokens`, and take API keys from settings or environment variables, never from source.
- **[convention]** Do not trust client-sent prices, totals or shipping values. Recalculate on the server from the product and the cart.
- **[convention]** Authenticate REST and Store API routes with `permission_callback`. Use `woocommerce_rest_check_permissions` for WooCommerce REST extensions, and never return `__return_true` on a route that exposes orders or customers.
- **[convention]** Verify webhook and gateway callbacks by signature, and make the handler idempotent so a replay cannot double-complete an order.
- **[convention]** Use `$wpdb->prepare()` for any custom query, and prefer CRUD or `wc_get_orders()` so HPOS table changes do not break the query.

Do:
```php
if ( ! current_user_can( 'manage_woocommerce' ) ) {
	wp_die( esc_html__( 'Not allowed.', 'acme' ), '', array( 'response' => 403 ) );
}
check_admin_referer( 'acme_refund' );
```
Don't:
```php
if ( is_admin() ) { acme_issue_refund( absint( $_POST['order_id'] ) ); }
```

## Accessibility

Target: WCAG 2.2 AA.

- **[convention]** Cart and checkout additions must work with the keyboard alone, with a visible focus indicator that is not hidden by sticky headers or mini-cart drawers (2.4.11 Focus Not Obscured).
- **[convention]** Make controls at least 24 by 24 CSS pixels, such as quantity steppers and remove-item buttons, or give them equivalent spacing (2.5.8 Target Size).
- **[convention]** Offer a non-drag way to reorder or adjust anything, such as a slider for quantity or a sortable list (2.5.7 Dragging Movements).
- **[convention]** Do not ask customers to re-enter details they gave earlier in the same checkout, such as billing to shipping, and offer to reuse them (3.3.7 Redundant Entry).
- **[convention]** Do not rely on a CAPTCHA or a cognitive test to sign in or pay without an alternative (3.3.8 Accessible Authentication).
- **[convention]** Put help in a consistent place across cart, checkout and account pages (3.2.6 Consistent Help).
- **[convention]** Label every field, link errors to fields with `aria-describedby` or `aria-invalid`, and announce notices through a live region, which `wc_add_notice` output and block notices already provide.
- **[convention]** Update the cart and totals without a focus loss, and announce changes such as "Item added" to assistive technology.
- **[convention]** Do not convey stock, sale or error state by colour alone.

## Testing conventions

- **[convention]** Unit tests extend `WC_Unit_Test_Case` and use the `WC_Helper_*` factories (such as `WC_Helper_Product`) from the WooCommerce test suite, or `wc_create_order()` and `WC_Product_Simple` when the helpers are not available.
- **[convention]** Run the same test suite twice, once with HPOS on and once with HPOS off and compatibility mode on, to prove storage independence.
- **[convention]** Name test files `test-<class>.php` or `<Class>Test.php` to match the repo's PHPUnit configuration, and name cases `test_<behaviour>`.
- **[convention]** Cover cart, checkout and payment flows with end-to-end tests, in classic and block checkout, using Playwright in `wp-env`. Never hit a live gateway; use its sandbox.
- **[convention]** Test refunds, partial refunds, coupons with limits, tax-inclusive and tax-exclusive prices, and a zero-total order. These are where extensions break.
- **[convention]** Reset state between tests with the WooCommerce test suite's teardown, and do not rely on the order tests run in.

## Documentation and comment standards

- **[tool]** Write docblocks for every public function, class and hook, with `@since` and `@param` tags (Squiz.Commenting, WordPress-Docs).
- **[convention]** Document every action and filter you fire with a docblock above `do_action()` and `apply_filters()` that lists its arguments and `@since`.
- **[convention]** Keep `readme.txt` current: `Requires at least`, `Tested up to`, `Requires PHP`, `WC requires at least`, `WC tested up to` and a changelog.
- **[convention]** State the HPOS and Cart and Checkout blocks compatibility in the readme.
- **[convention]** Keep `@version` tags in plugin templates and bump them whenever the template changes.

## Anti-patterns

- **[convention]** Reading or writing order data with `get_post_meta`, `update_post_meta` or `get_post_type` breaks under HPOS. Use the order object.
- **[convention]** Querying `shop_order` through `WP_Query`, `get_posts` or SQL on `wp_posts` returns nothing under HPOS. Use `wc_get_orders()`.
- **[convention]** Overriding templates for small changes breaks on upgrade. Use a hook, and override only when you must.
- **[convention]** Adding classic checkout hooks to a store that uses block checkout has no effect. Use the Store API and block integrations.
- **[convention]** Using the `woocommerce_` prefix for your own hooks or functions collides with core. Use your own prefix.
- **[convention]** Calling `save()` repeatedly inside a loop is slow. Batch the setters and save once.
- **[convention]** Running code on `init` that needs `WC()->cart` or `WC()->session` fails in admin and cron. Check `WC()->cart` is set, or use `woocommerce_init`.
- **[convention]** Loading WooCommerce classes before WooCommerce is active is a fatal error. Check and wait for `plugins_loaded`.
