# Verification

## Observed checks

- Python exporter tests: 4 passed (driving-only provenance, fail-closed missing/
  assumed channels, corrected bitrate propagation, new reviewed camera export).
- Node calculation tests: 5 passed (decimal units, simultaneous channels,
  allocations/headroom, ranges/inverse, invalid inputs).
- Static build: 15 camera presets, standalone assets and a WordPress plugin ZIP.
  No runtime third-party requests except the user-opened
  measurement-reference link.
- Playwright Chromium: desktop 1024px and mobile 375px; no JavaScript errors.
  Tested camera changes, inverse mode, missing allocation, valid allocation,
  invalid input, bitrate ranges, custom mode, unavailable-JSON fallback,
  actual iframe embedding and height expansion. No horizontal page overflow.
- WordPress package PHP lint and shortcode API-contract test passed. Additional
  Chromium tests cover a footer loader executing after the iframe, rejected
  forged resize messages, and multiple standalone embeds. These are local tests,
  not a WordPress-server acceptance result.
- Manually inspected mobile calculator and expanded embedded-mobile screenshots.
- No production deployment or real WordPress rendering was performed.

## Staging access check

Staging development was authorized after the first draft PR. The managed
browser returned `ERR_INVALID_AUTH_CREDENTIALS` for the separate staging site.
Protected staging credential metadata exists, but its allowed-host routing is
not configured. No credential values were retrieved or exposed. No staging or
production files/posts were written. Installation and real-theme acceptance
remain blocked until protected staging access is restored.

### Browser-only real-theme check

After the outer staging password gate was authenticated, a read-only preview
loaded an actual staging article and inserted the local calculator into its
existing content column using browser request interception. Nothing was
uploaded, installed, published, or saved to WordPress. WordPress administration
remained logged out.

- Viewports 1440, 768, and 375px passed; calculator/content widths were 750,
  720, and 345px respectively.
- No page or calculator horizontal overflow at any tested width.
- Following post content did not overlap the iframe.
- Missing allocation, 50% allocation calculation, and expanded methodology
  passed, with no clipped iframe content and no JavaScript errors.
- Mobile rendered screenshot inspected.

Reproduce with `theme-preview.mjs` using an existing Playwright module, the
authenticated browser's CDP URL, and a staging article URL. This verifies theme
geometry but does not verify installation, server MIME types, or shortcode
execution inside WordPress. Preview changes disappear on reload.

## Code review

Scope: new exporter, calculation module, widget, embed loader, static CI artifact
workflow, and focused tests. Existing desktop app code is unchanged.

- Correctness: sums simultaneous channels; uses only driving measurements;
  accounts separately for partition share and headroom; retains sampled ranges.
- Readability/architecture: no frontend framework or runtime dependency; bitrate
  source remains the existing reference, eligibility policy is separate.
- Security: no dynamic HTML interpolation, secrets, raw submission data, or
  user tracking. Resize messages validate origin, source window, and bounds.
- Performance: one small local JSON fetch; no hosted calculation or AI service.
- Remaining limitations: headroom is an assumption, card compatibility is not
  checked, firmware/quality metadata is incomplete, and fixed percentages are
  user-entered. These are visible in the interface.

## Interface review (quick)

Plain CSS inside an isolated iframe. Scope: primary workflow, expanded storage
and methodology details, error and loading-fallback states.

| Category | Evidence | Result |
| --- | --- | --- |
| Typography | Mobile screenshot, dynamic outputs | Clear; tabular output, readable labels |
| Surfaces | Inputs, results, focus rules, mobile overflow check | Clear; native controls with 44px+ height |
| Animations | Source inspection | No custom animation to review |
| Icons | Native select/disclosure controls | No custom icon system |
| Performance | Built assets, browser errors, iframe resize test | Clear |

Considered but rejected: arbitrary channel toggles would imply unmeasured
configurations; animated result transitions would distract on repeated edits.
No actionable interface-polish findings. Local implementation approved for
review handoff; real WordPress integration and production hosting remain
unverified. Safari/Firefox and assistive-technology walkthroughs not run.
