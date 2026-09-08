# Verification

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
