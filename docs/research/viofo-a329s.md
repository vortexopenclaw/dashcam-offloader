# VIOFO A329S Research Notes

## Official Sources Checked

- Product page: <https://www.viofo.com/products/viofo-a329s-3ch-first-4k-front-2k-wide-210-fov-fisheye-cabin-2k-rear-dash-cam-with-starvis-2-sensor>
- Product blog page: <https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/introducing-viofo-a329s-3ch-with-2k-infrared-fisheye-cabin-camera-your-reliable-road-companion-is-here>
- Firmware and manual hub: <https://www.viofo.com/pages/manual>
- Support product manual index: <https://www.viofo.com/pages/support-product-manual>
- Support manual folder: <https://support.viofo.com/support/solutions/folders/19000151665>

## Other References Checked

- Vortex Radar A329S/T multiplexing walkthrough: <https://www.youtube.com/watch?v=p5WVjVqX1xI>

## Findings

- The official product page confirms the sampled A329S 3CH configuration as a 4K front, 2K cabin, and 2K rear three-channel dash cam.
- The official VIOFO collection page lists A329S 1CH, A329S 2CH, A329S 2CH IR, and A329S 3CH variants.
- The official product page also links to VIOFO's firmware and manual hub.
- During this pass, the official manual index and support folder did not expose a clean A329S PDF manual link in scraped content.
- The profile rules in `docs/card-profiles/viofo-a329s.md` are based primarily on the real card sample, with official pages used for model confirmation.
- VIOFO documents Multiplex Video for A329S as multiple views in one video, and the A329S blog describes exporting either a single perspective or a multi-angle view without manual editing.
- Vortex Radar's A329S/T multiplexing walkthrough describes the default mode as separate per-camera files, plus selectable multiplex modes for two-camera and three-camera combinations.
- The walkthrough describes two-camera multiplex output as side-by-side 7680x2160, and three-camera multiplex output as a front view above two secondary views at 3840x3240.
- The sampled A329S card was not available during the multiplex research pass, so `.dashcamexport` contents and any real multiplex filename suffixes still need card validation.

## Non-Primary References

Search results also showed non-official A329/A329S manual pages. Those were not used as primary evidence for filename, folder, or channel rules.
