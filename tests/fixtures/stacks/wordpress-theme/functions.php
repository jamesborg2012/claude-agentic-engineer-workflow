<?php
add_action( 'wp_enqueue_scripts', function () {
	wp_enqueue_style( 'fixture-theme', get_stylesheet_uri(), array(), '1.0.0' );
} );
