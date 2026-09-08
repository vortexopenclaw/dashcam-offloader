# Vortex Radar recording-time calculator

## Objective and scope

Embed a simple driving-footage chart in a website post. Choose a dashcam and
channel setup and a supported recording setting; compare approximate recording times for 32, 64, 128, 256, and
512 GB cards. There are no inverse modes, bitrate inputs, allocation inputs,
or headroom controls. The catalog covers 31 dashcams.

Use the offloader's existing measured data, supplemented by verified VIOFO
quality charts and Blackvue Elite 10 specifications. No app runtime changes, paid APIs, analytics, cookies,
raw footage access, or frontend build dependencies. An optional lightweight
WordPress plugin packages the same static calculator with a shortcode.

The canonical bitrate source remains `docs/video-metadata-reference.md`.
`catalog.json` is a reviewed eligibility list, not a second bitrate database.
Only complete, explicitly mapped driving channel sets measured with ffprobe
are exported. The exporter fails if an approved camera loses a channel or has
an unsupported measurement format. It never exports free-form source notes,
local paths, footage filenames, or submission metadata. Manufacturer chart
transcriptions, source image URLs, quality, and check dates live separately in
`manufacturer-times.json`. These override bitrate-derived estimates for the
three reviewed VIOFO models. Exported JSON uses schema version 3.

## Recording settings and public links

`recording-modes.json` supplies reviewed quality/FPS variants and manufacturer-only
cameras, plus exact-configuration affiliate destinations. Each setup exports a
`modes` array with its own recording rate or times, per-channel resolution/FPS,
and source description. Never reuse resolution or rate data from another mode.
Manufacturer quality names and measured samples are distinct: a high sampled
rate does not establish a Maximum menu setting. Normal in a quality chart is
not the same as normal/driving recording mode.

Vueroid uses complete-file storage rates because its recording containers are
preallocated. A119 Mini 2 has separately identified 60fps direct-file samples;
its menu quality is unknown. These are not a controlled 30fps/60fps comparison.
Do not derive an unmeasured 2K60 setting by scaling a 4K30 bitrate.

Brand display names use first-letter capitalization; source names and IDs stay
stable. Public explanations follow the current camera and setting. Existing
owner affiliate links are shown only for the exact selected package; unmatched
configurations get no camera shopping link. Card links are brand-specific,
with a compatibility reminder and affiliate disclosure. No live prices or
stock claims are made. Purchase destinations still require editorial review
before a public launch.

## Build and verify

```sh
python3 -m unittest discover -s web/recording-time -p 'test_*.py'
node --test web/recording-time/calculator.test.mjs
python3 web/recording-time/build.py
php -l web/recording-time/wordpress/vortex-recording-time.php
php web/recording-time/test_shortcode.php
```

Optional browser checks use an existing Playwright installation:

```sh
node web/recording-time/browser.test.mjs /path/to/playwright/index.mjs
```

This launches a separate headless browser and temporary loopback server, tests
the generated bundle, and saves desktop/mobile/embed screenshots in the ignored
`evidence/` directory. It does not use an authenticated shared browser.

The static deliverable is `web/recording-time/dist/`. `demo.html` demonstrates
an actual post-style embed. Serve the directory over HTTP(S); opening HTML
directly from disk does not support the JSON fetch/module imports reliably.

## Install into a website post

### WordPress package (preferred for staging)

The build produces `dist/vortex-recording-time.zip`. Upload and activate this
plugin on the authorized staging site, then add a Shortcode block containing:

```text
[vortex_recording_time]
```

The shortcode enqueues its own resize script and serves its calculator assets
from the plugin directory. No theme edit or unfiltered HTML capability is
required for the post author. The loader handles delayed footer execution and
checks resize-message origins and frame identity. Its WordPress script version
uses the deployed file modification time to invalidate the loader cache.

No activation hook or database migration runs. Deactivation removes the shortcode
handler but leaves post content intact. For rollback, back up the exact existing
plugin directory with the site's approved backup mechanism before replacement,
then restore that directory if the rendered checks fail. Do not change unrelated
plugins, global security headers, or cache settings.

The staging site requires an authenticated browser for rendered acceptance.
Check iframe height expansion/contraction, 375px mobile overflow, dropdown and
channel selections, and neighboring post content in the actual theme. Confirm `.mjs`
assets have a JavaScript MIME type. This repository's local browser test does
not prove server MIME types, authentication propagation, or WordPress rendering.

### Standalone static hosting

After approving deployment, host the six calculator assets from `dist/` together at a stable
HTTPS path, for example `/tools/recording-time/` on the website (exclude the ZIP and demo). Keep that path
stable so existing post embeds pick up future deployments.

Add this to a WordPress Custom HTML block (the path is proposed, not deployed):

```html
<script src="/tools/recording-time/embed.js"></script>
```

The loader inserts a titled iframe and adjusts its height using messages
validated against both the frame window and hosting origin. Parent themes do
not leak into the calculator. If WordPress removes scripts, enqueue the loader
through the site's existing approved asset mechanism. A basic iframe can also
be used with a fixed height and scrolling, but does not auto-resize by itself.

Serve `.mjs` as JavaScript, JSON as JSON, and permit framing by the website.
Use short cache lifetimes/revalidation for index, scripts, and cameras.json.
Deploy all files atomically; preserve the previous build for rollback.
No hosting, WordPress, cache, or production configuration is changed by this work.

## Camera updates

1. Add/update measured driving rows in `docs/video-metadata-reference.md` using
   its existing table format. Record all simultaneously recording channels.
2. For a new camera, add its exact section name and ordered channel roles to
   `catalog.json` after confirming the sample is a complete configuration.
   A filename-recognition profile alone is not recording-rate evidence.
3. Mark `allocationRequired: true` where normal-driving capacity must be checked.
   This adds a short partition note, not an input or an assumed percentage.
4. Run the checks/build. The included GitHub workflow produces the static build
   artifact whenever the measurements or calculator change.
5. Deploy that artifact to the same stable hosting path after release approval.

Already-approved models pick up bitrate corrections automatically on rebuild.
New models need one eligibility entry, not calculator code or a post edit.
Automatic **builds** are wired; automatic **production deployment** is not enabled.
The latter should be connected to the chosen site's approved deployment route,
not to raw unreviewed submissions or arbitrary branch pushes.

## Driving versus parking

No blended driving/parking bitrate. Bitrate-derived rows use nominal decimal
card capacity without a hidden reserve factor. Parking, protected files, and
fixed partitions can reduce actual driving retention; the UI explains this
briefly without making the user configure storage assumptions.

Manufacturer rows retain the published durations for each verified quality setting. Other rows
sum measured simultaneous channel bitrates. Front-only and reduced-channel
choices are estimates derived from those channel measurements, not separate
tests or guarantees of supported hardware configurations. Disconnecting a
camera can change the remaining bitrate. The collapsed methodology explains
this limitation. Quality and firmware were not consistently recorded.
Times are rounded to five minutes, preserving measured ranges. Card sizes are
comparison points, not model-specific compatibility recommendations.

## Success checks and rollback

Verify unit conversions, simultaneous-channel totals, ranges, manufacturer rows,
channel selection, invalid data, exclusion of parking/provisional rows,
data-update propagation, mobile sizing, missing-data fallback, and iframe
resize behavior. Reverting this feature commit removes the build workflow and
tool without touching scanner/copy behavior. For a deployed version, restore
the previous static build at the same path.
