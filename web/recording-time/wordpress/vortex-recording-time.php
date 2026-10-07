<?php
/**
 * Plugin Name: Vortex Radar Recording Time
 * Description: Embed the measured dashcam recording-time calculator with [vortex_recording_time].
 * Version: 0.1.0
 * Requires at least: 6.0
 * Requires PHP: 7.4
 * License: MIT
 */

if (!defined('ABSPATH')) {
    exit;
}

add_shortcode('vortex_recording_time', static function () {
    $base = plugin_dir_url(__FILE__) . 'calculator/';
    $version = (string) filemtime(__DIR__ . '/calculator/embed.js');
    wp_enqueue_script('vortex-recording-time-embed', $base . 'embed.js', array(), $version, true);
    return '<iframe data-vr-recording-time src="' . esc_url($base . 'index.html') . '"'
        . ' title="Vortex Radar dashcam recording time calculator" loading="lazy"'
        . ' style="display:block;width:100%;height:1100px;border:0;max-width:100%;"></iframe>';
});
