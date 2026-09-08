# Verification

## Observed checks

- Python exporter tests: 4 passed (driving-only provenance, fail-closed missing/
  assumed channels, corrected bitrate propagation, new reviewed camera export).
- Node calculation tests: 5 passed (decimal units, simultaneous channels,
  allocations/headroom, ranges/inverse, invalid inputs).
- Static build: 15 camera presets; seven output files totaling approximately
  23 KB uncompressed. No runtime third-party requests except the user-opened
  measurement-reference link.
- Playwright Chromium: desktop 1024px and mobile 375px; no JavaScript errors.
  Tested camera changes, inverse mode, missing allocation, valid allocation,
  invalid input, bitrate ranges, custom mode, unavailable-JSON fallback,
  actual iframe embedding and height expansion. No horizontal page overflow.
- Manually inspected mobile calculator and expanded embedded-mobile screenshots.
- No production deployment or real WordPress rendering was performed.

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
