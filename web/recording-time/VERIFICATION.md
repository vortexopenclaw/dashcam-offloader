# Verification

## Stacked desktop/mobile rows and full coverage audit (latest, 2026-09-08)

Quick interface review: native HTML/plain CSS, channel summary and recording-time
table, existing selectors/photo slot. Typography and surfaces inspected in
1100px desktop and 390px phone screenshots, plus the Cansonic range display.
No icons or animations added. Performance reviewed in the CSS/data diff (no new
runtime requests or dependencies). Keep numeric alignment and stable photo slots.
The previous desktop strip required switching reading direction. It is now the
same vertically stacked table as mobile, with larger desktop channel text.
Rejected bar charts (exact values are the task), and additional side-by-side panels
(the user prefers a single vertical reading order). No actionable polish findings
within this requested scope. No new motion, so slowed-motion review not applicable.

Code-quality self-review covered correctness, readability, architecture, security
and performance. The change removes desktop CSS overrides, uses existing mode
schema, preserves submitted-video caveats, and makes no access/publishing changes.
Z4 values were cross-checked against VIDEO-folder entries in its maintained
profile, not PROTECTED parking rows. Report matching preserves distinct Plus/LTE/
Pro/Commercial variants and explicitly lists unmapped rows. Catalog and profile
coverage were reviewed separately; 81 presets are not complete catalog coverage.

Verification: 13 exporter tests and 5 calculation tests pass. Full browser suite
passes all 81 cameras/settings, desktop/mobile row direction at 740/620/375/320px,
photo switching, image failures, four-camera display, embed sizing and error paths.
Fresh Vueroid and Z4 desktop/mobile captures were inspected at 1100/390px.
No horizontal overflow or JS errors in checked paths. `git diff --check` passes.
Verdict: Approve scoped change. Actual WordPress install/theme and physical phones
not verified this revision. No merge or live-site update performed.

## Embed-first layout and exact-setup photos (latest, 2026-09-08)

Supersedes the side-by-side details/time layout below. Recording details are a
compact strip, with five horizontally aligned capacity/time columns on desktop
and ordinary numeric table rows on mobile. Removed the eyebrow brand and
in-widget affiliate disclosure per the site owner; host-post disclosure is outside this
widget. No memory-card links were restored.

Reviewed existing photo contact sheets and seven additional original site assets.
Vueroid S1 4K Front, Front + Rear and 3CH now use distinct exact-setup photos.
Viofo A329T Front + Telephoto and A329S/A229 Pro/Plus/Ultra Front + Rear gained
matching photos. Other kit images are restricted to their reviewed setups.
No image editing or generated product representations. Missing setup photos leave
the fixed slot empty rather than rendering a wrong kit or moving controls.

Browser regression verifies three distinct Vueroid sources, identical control
geometry across all three photos and an unmatched setup, and delayed stale-image
load rejection. All 80 cameras and settings still render, plus table orientation
and overflow checks at 320/375/620/740px, source caveats, image failure, absent
caption/branding/disclosure/card links, and the existing embed-security checks.
12 exporter tests pass, including invalid/duplicate photo mappings and H1 block.
Desktop and phone screenshots inspected, including 3CH and four-channel N5.
The N5 configuration label is compact (Front + Rear + 2 Cabin), with full role
names retained in recording details. No new browser errors.

Design references: NN/G comparison tables and GOV.UK tables, linked in README.
Review: plain CSS, native selects, semantic table roles, safe text DOM updates,
packaged image paths, no network services beyond existing asset fetches.
Typography/surfaces/responsive layout reviewed. No animation or icons added.
Rejected retaining the split detail/time columns, adding graphical bars with
redundant values, and a visible placeholder/caption in the reserved image slot.
Verdict: approve preview revision. Actual WordPress installation remains unverified
and unchanged; these are local-rendering checks, not new staging verification.


## Compact layout and released-model expansion (2026-09-08, latest)

80 cameras: 63 original-file entries, 16 manufacturer-reference entries and one
submitted-video entry. 50 reviewed product images. Previous sections below are
historical and do not describe the current coverage gaps.

Removed the visible photo caption. Rebalanced recording details and the time
table into two desktop columns, stacked below 620px. Resolution/FPS and MB/min
are adjacent within each channel block. Blue/navy/neutral colors match the
existing child-theme palette inspected in local theme inventory and historical
staging screenshots, not a newly authenticated staging session.

Full quality labels replace abbreviated Blackvue choices. No memory-card links
are exported pending the site owner’s capacity-specific URLs. Camera links remain.

15 legacy cameras gained full-file rate probes. New raw-file evidence lives in
video-metadata-reference.md. DOD RC500S combines separate Front/Rear sessions;
Papago 760 1440p/1080p remain separate modes. A119s retains a measured range.
No sample archive paths, filenames, or private submission metadata are exported.

S1 QHD uses the existing public profile’s firmware 1.0.4 stream measurements,
with a visible warning about padding and a distinct submitted-data explanation.
T800 uses https://70mai.pl/faq/70mai-4k-t800/ (checked 2026-09-08): 1 hour/32GB
three-channel baseline, larger sizes scaled, rear-camera variant and FPS unknown.
Conflicting 1CH figures are omitted. No fabricated per-channel MB/min.
Vueroid ZERO confirmed at https://vueroid.com/product/vueroid-zero-2ch/.
H1 explicitly blocked as unreleased per the site owner. No offloader application changes.

Photo review: T800 image is a real existing site product-kit asset. The site’s
S1 2K-labeled image visibly says 4K60fps on its screen, so that mapping was withheld.

Review scope: plain HTML/CSS/JS, calculator data and exporter. Typography,
surfaces, spacing and responsive states checked. No icons or animation changed.
Rejected adding motion, color heatmaps, or a second styling framework. Retained
native accessible selects, text-only DOM rendering and existing build/export path.


### Verification and verdict for this revision

11 exporter tests and 5 calculation tests pass. PHP lint and shortcode contract
pass. The browser suite passed all 80 cameras and every setup/setting, plus
320/375/620/740px layout boundaries, source-type wording, absent card links and
captions, image failure, missing data, and iframe security/resizing checks.
The excluded-H1 regression fails closed. No JavaScript errors.
Desktop Blackvue, mobile S1 QHD and T800, and general desktop/mobile screenshots
were inspected. No clipped controls or horizontal overflow. T800’s published
normal-recording duration is not flagged as an unpartitioned full-card figure.
Review verdict: approve preview revision. Actual staging installation/theme
integration and live publication remain unverified and were not performed.

## Expanded catalog and brand/model revision (2026-09-08)

63 cameras (48 recorded-file measurement entries and 15 manufacturer-only entries),
up from 31. 49 source-mapped product images from the existing public site media
library are bundled locally. Production access was read-only WP-CLI attachment
metadata. No WordPress writes, credential changes or external authentication apps.

### Observed checks

10 Python exporter tests, 5 Node calculation tests and the PHP shortcode contract
pass. Local browser tests exercise every exported brand/model/setup/setting,
numeric Elite ordering, hidden single-setting selector, four-channel N5,
per-channel Elite 10 MB/min, 70mai 60fps, photos and missing-image fallback,
mobile overflow, iframe resizing, delayed loader and message-origin protection.
No JavaScript errors. Desktop/mobile and both photo contact sheets visually
inspected. New image assets are present and packaged in the WordPress ZIP.

### New sources and scope

Blackvue’s official recording-time manual index provided DR900X/Plus,
DR750X/Plus/LTE Plus, DR970X/Plus/LTE/LTE Plus/Box Plus, DR770X, DR590X/Plus,
and Elite 8 rates. Exact individual URLs are stored on each recording mode.
Front-only extrapolation was withheld where the cited page only documented 2CH.
DR590X front-only is 60fps and its two-channel setup is 30fps per camera.
Manufacturer bitrates are used for full-card estimates, not presented as the
manual’s exact rounded duration table.

New raw-file checks covered Thinkware U1000, Vantrue N5, Rove R2-4K Dual,
70mai 4K Omni, Blackvue DR750 LTE, Nextbase 622GW, Cobra SC 200D and the older
Viofo A229, A329, WM1 and VS1. Source metadata is recorded in the canonical
reference. N5 resolution variants use matched complete four-camera sets.
70mai’s 30/60fps clips came from different sessions, not a controlled FPS test.
Its combined-camera estimate adds separately measured Front/Rear rates.
Nextbase uses a matching 45-second protected-driving pair and identifies that
basis. Later front clips vary, so no constant file-size guarantee is made.

Existing usable measurements now also include the front-only Q800 Pro/F800 Pro,
Cansonic Z3+, Escort M1/M2, and Vantrue N4/E360. Specific Vantrue driving-event
rows are explicitly opted in. Parking remains excluded. Repeated Escort M1
samples have explicit merge authorization, otherwise duplicate rows fail.

No guessed per-channel MB/min from manufacturer whole-system duration charts.
Our test footage is offered separately for the A229 models to show their
measured per-channel rates. File-rate figures use decimal Mbps × 7.5 MB/min.
The user’s usual maximum-quality practice is acknowledged, but is not relabeled
as a confirmed menu setting for every archived sample.

### Remaining gaps

Thinkware FA200 and Rove R2-4K have parking-only measurements. Vantrue X4’s
Driving Clips folder was empty. The Vueroid QHD and 70mai T800 records still
lack an approved driving-rate set in the reviewed reference. Ambiguous
Blackvue Elite 8 4K sample data was not used over its official QHD specification.
Not every archive directory is a dashcam or an original driving recording.

This is still a local preview. Fresh authenticated staging installation,
server MIME handling and a live WordPress draft are not verified. Existing
source measurement links target main and gain new rows when this PR is merged.
Affiliate URLs remain existing owner destinations, not current stock claims.

### Review

Reviewed correctness, source provenance, readable static UI structure, safe
text rendering, constrained image paths and no runtime data/API expansion.
Plain-CSS layout retains native selectors. No new motion or icon system.
Rejected guessed photos and prominent sales buttons. Photos use existing
assets and descriptive kit captions. Shopping copy uses normal sentences,
not Shop labels or bullet separators. No blocking preview issues remain.

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

## Complete-file recovery, September 8 follow-up

85 presets. Original 50-record feedback archive audited privately. Full-file evidence saved without filenames, timestamps, paths, contacts or notes. New FA200 regression checks equal allocated storage despite different encoded bitrates. ARC 800 checks constant allocation divided by observed full-loop duration. Browser source attribution distinguishes complete-file measurements from manufacturer data. Scanner/receiver logging changes are on a separate review branch, not deployed by this calculator update.

### Single-time revision

14 exporter tests, 6 calculation tests, and the full 85-camera browser suite passed. Tests distinguish midpoint bitrate from midpoint duration, prefer measured mean rates, reject invalid means, and verify no time range is rendered. Updated desktop/mobile previews show the G980H four-channel setup with one time per capacity.
