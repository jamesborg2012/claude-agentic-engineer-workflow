<?php
defined( 'ABSPATH' ) || exit;

class Fixture_Order_Notes {
	public static function init() {
		add_action( 'woocommerce_checkout_order_processed', array( __CLASS__, 'add_note' ), 10, 1 );
	}

	public static function add_note( $order_id ) {
		$order = wc_get_order( $order_id );
		if ( $order ) {
			$order->add_order_note( 'Placed via fixture extension.' );
		}
	}
}

Fixture_Order_Notes::init();
