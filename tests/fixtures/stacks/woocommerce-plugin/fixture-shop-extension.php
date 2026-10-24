<?php
/**
 * Plugin Name: Fixture Shop Extension
 * Description: Adds an order note when an order is placed.
 * Version: 1.0.0
 * Requires at least: 6.5
 * Requires PHP: 8.1
 * WC requires at least: 9.0
 * WC tested up to: 9.4
 * Text Domain: fixture-shop-extension
 */
defined( 'ABSPATH' ) || exit;
add_action( 'before_woocommerce_init', function () {
	\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
} );
require_once __DIR__ . '/includes/class-order-notes.php';
