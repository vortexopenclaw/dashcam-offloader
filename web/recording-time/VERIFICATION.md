# Verification

## Recording-settings revision (2026-09-08, afternoon)

Supersedes the two-dropdown revision below. 31 cameras, with one additional
recording-setting selector and an always-visible per-channel resolution/FPS line.
Brand display names are Viofo, Blackvue, Rove, etc., per editorial direction.

### Evidence and coverage

- 8 Python export tests, 5 Node calculation tests, and PHP shortcode contract pass.
- Browser checks exercise every exported camera, channel setup, and recording mode.
- Specific regressions: A229 Pro 256GB 3CH Normal 8h30 vs Maximum 7h;
  Thinkware U1000 Plus 4K30 front + 1080p30 rear, with no Viofo source prose;
  Elite 10 medium vs maximum 90Mbps 2CH, dual 4K30; Vueroid cabin metadata;
  A119 Mini 2 60fps source label; exact-package affiliate link.
- Desktop/mobile and embed screenshots visually inspected. No horizontal overflow,
  JavaScript errors, clipped expanded methodology, or resize-message regression.
- This revision was tested locally, not in a newly deployed WordPress post.
  The prior staging-theme geometry checks below are historical, not a fresh test.

### Source decisions and limitations

- A229 Pro/Plus/Ultra Maximum cells read directly from the official source images
  already linked in manufacturer-times.json. Plus 1CH Maximum is omitted:
  its source jumps from 8.5h at 128GB to 32.5h at 256GB. No silent correction.
- A119 Mini 2 and A119M Pro quality options transcribed from Viofo’s same support
  article (image attachment IDs 19149878491 and 19153743038). Manufacturer Medium
  and High names preserved. A119M Pro source explicitly uses 4K30 HDR on.
- Blackvue Elite 10 uses published per-channel rates from
  https://manual.blackvue.com/docs/elite-10-series/11-recording-time/recording-time-elite-10-series/
  Calculated full-card times are labeled as such, not the manual’s rounded times.
- Vueroid S1 4K Infinite now has direct-file storage measurements in the canonical
  reference. Complete-file rates include preallocation; video-only rates would
  overestimate storage duration. Original files were read-only and not uploaded.
- A119 Mini 2 60fps uses two individually probed direct-file samples, documented
  in the reference. Quality unknown; no controlled 30fps/60fps comparison claimed.
- No unmeasured 4K30-to-2K60 conversion. Not every supported menu option has data.
  Vueroid QHD archive lacks verified driving samples in this bounded check.
- Camera/card URLs are existing owner affiliate destinations, with sponsored rel
  and a visible disclosure. Exact camera package matching; no fabricated links,
  prices, stock, or universal card-compatibility claims. Destination stock/product
  landing pages have not been individually re-audited this revision.

### Review

Code review: calculation provenance, mode/channel matching, update behavior,
readability, existing static architecture, safe textContent rendering, no secret
exports, bounded single-JSON load. No new dependencies or app runtime changes.
Interface review: plain CSS; mobile/desktop typography, spacing, focus styles,
select states, and link placement inspected. No new motion/icons; no animations
added to routine selection changes. Kept native selectors and plain shopping
links rather than introducing tabs or prominent purchase buttons.
No blocking issues found for preview; production and live-site draft unchanged.

## Simplified chart revision (2026-09-08)

Supersedes the initial 15-camera calculator. The interface now has two
dropdowns and a five-row recording-time table. Inverse mode, custom bitrate,
allocation, and headroom controls have been removed. The catalog contains
29 cameras, with normalized VIOFO, BlackVue, and ROVE display names.

### Checks observed

- Six Python exporter tests passed: driving-only provenance, channel-set
  validation, corrections/new camera propagation, subset estimates, and
  manufacturer-chart override. Parking rows do not enter driving estimates.
- Five Node calculation tests passed: decimal units, channel totals, measured
  ranges, official durations, and invalid data.
- Build generated schema-2 camera JSON, static assets, and WordPress ZIP.
- PHP lint and shortcode API-contract test passed.
- Playwright checks passed for all 29 camera entries, channel selection,
  five card sizes, single-channel selector state, ranges, desktop/mobile
  layout, missing-data error, iframe resizing, delayed footer loader,
  forged resize-message rejection, and multiple embeds. No JavaScript errors.
- VIOFO A229 Pro Normal-quality 256 GB outputs match the inspected source:
  1CH 17 hours, 2CH 10 hours 30 minutes, 3CH 8 hours 30 minutes.

### Browser-only staging-theme preview

Loaded an authenticated staging article and inserted the local chart into its
actual theme content column through browser request interception. This is
DOM-only preview work: nothing was uploaded, installed, published, or saved
to WordPress. WordPress admin access remains unresolved.

- Viewports 1440, 768, and 375px passed; chart/content widths were 750,
  720, and 345px respectively.
- No page or iframe horizontal overflow, clipping, or overlapping next content.
- Switching 2CH/3CH updated the chart correctly; expanding methodology resized
  the iframe correctly. No JavaScript errors.
- Mobile screenshot visually inspected: two native selectors, five readable
  rows, short caveat, collapsed methodology.

Reproduce with `theme-preview.mjs`, an existing Playwright module, an
authenticated browser CDP URL, and a staging article URL. Changes disappear on
reload. This proves theme geometry, not server MIME handling, deployed assets,
or shortcode execution in an actual WordPress installation.

## Review and limitations

- Scope is the website chart/exporter; desktop application code is unchanged.
- Existing measured reference remains canonical. Reviewed manufacturer charts
  are a separate source with URLs, quality setting, and verification date.
- Reduced-channel estimates add only selected measured rates. They are not
  independently measured configurations or hardware compatibility guarantees.
- Manufacturer figures use Normal quality; Offloader samples do not have
  consistent quality/firmware metadata. Cross-model values are approximate,
  not a controlled quality comparison.
- Full nominal card capacity is used for bitrate estimates. Actual partitions,
  parked/protected recordings, and formatting can reduce retention. The UI
  states this without numeric storage controls or an invented reserve factor.
- Missing incomplete/provisional cameras remain excluded. Common card sizes
  are comparison points, not verified compatibility recommendations.
- No dynamic HTML interpolation, private source notes, credentials, tracking,
  runtime API dependencies, or paid services are added. Resize messages still
  validate origin, source window, and bounds.
- No production changes. Safari/Firefox and assistive-technology walkthroughs
  have not been run. Actual WordPress installation remains unverified.
