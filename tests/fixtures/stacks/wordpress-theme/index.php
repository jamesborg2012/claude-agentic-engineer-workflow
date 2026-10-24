<?php get_header(); ?>
<main><?php while ( have_posts() ) : the_post(); the_title( '<h2>', '</h2>' ); endwhile; ?></main>
<?php get_footer();
