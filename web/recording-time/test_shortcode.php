<?php
// Focused WordPress API contract check, not a substitute for a staging render.
define('ABSPATH', __DIR__);
$registered = array();
$scripts = array();
function add_shortcode($tag, $callback) { $GLOBALS['registered'][$tag] = $callback; }
function plugin_dir_url($file) { return 'https://example.com/wp-content/plugins/vortex-recording-time/'; }
function wp_enqueue_script($handle, $src, $deps, $version, $footer) {
    $GLOBALS['scripts'][$handle] = compact('src', 'deps', 'version', 'footer');
}
function esc_url($url) { return htmlspecialchars($url, ENT_QUOTES, 'UTF-8'); }
$package = new PharData(__DIR__ . '/dist/vortex-recording-time.zip');
$testRoot = sys_get_temp_dir() . '/vr-shortcode-' . bin2hex(random_bytes(6));
$package->extractTo($testRoot);
require $testRoot . '/vortex-recording-time/vortex-recording-time.php';
$html = $registered['vortex_recording_time']();
foreach (array('data-vr-recording-time', '<iframe', 'title=', 'loading="lazy"', '/calculator/index.html') as $required) {
    if (strpos($html, $required) === false) { throw new RuntimeException('Missing shortcode output: ' . $required); }
}
if (strpos($html, '<script') !== false) { throw new RuntimeException('Shortcode must enqueue scripts, not inline them'); }
if (count($scripts) !== 1 || !$scripts['vortex-recording-time-embed']['footer']) {
    throw new RuntimeException('Expected one footer loader');
}
echo "Shortcode contract passed.\n";
