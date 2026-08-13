# VIOFO A329T Research Notes

## Official Sources Checked

- Official front and telephoto collection: <https://www.viofo.com/collections/front-telephoto-dashcam>
- A329T 2CH product link from collection: <https://www.viofo.com/products/viofo-a329t-2ch-4k-60fps-2k-telephoto-dashcam>
- A329T 3CH product link from collection: <https://www.viofo.com/products/viofo-a329t-3ch-4k-front-2k-telephoto-camera-2k-rear-camera-sony-starvis-2-sensor>

## Other References Checked

- Vortex Radar A329S/T multiplexing walkthrough: <https://www.youtube.com/watch?v=p5WVjVqX1xI>
- 2026-06-09 Dashcam Offloader app learning scan from a real A329T card.
- VIOFO parking-mode overview: <https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/everything-you-need-to-know-about-parking-mode>
- VIOFO A329S low-power/hybrid parking-mode overview: <https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/highlights-of-the-a329s-series-what-are-low-power-impact-mode-hybrid-parking-mode>

## Findings

- VIOFO lists A329T 2CH under front and telephoto dashcams.
- VIOFO lists A329T 3CH under front, rear, and telephoto dashcams.
- VIOFO describes A329T as a telephoto system with 4x optical zoom.
- The user provided a representative A329T telephoto filename: `2025_0612_055737_000103T.MP4`.
- The 2026-06-09 app learning scan showed A329T folder groups for driving, parking, protected, and photos.
- The same scan showed parking and photo suffixes using the physical camera channel roles: `PF` front, `PR` rear, and `PT` telephoto.
- The scanner should label parking subtype separately from physical channel: parking is a recording type, not a channel.
- VIOFO's parking-mode overview documents auto event detection, time-lapse recording, and low-bitrate recording. It describes low bitrate as continuous small-file recording with audio and auto event detection as motion-triggered buffered recordings.
- VIOFO's A329S parking-mode overview documents low-power impact detection and hybrid parking mode, where normal parking modes can later shift into impact-only low-power mode.
- A public Reddit report for A329S firmware 2.0 describes automatic still photos and first-minute locked recordings when parking starts, but no official VIOFO manual/support page has been found yet that documents this parked-photo behavior.
- No direct full-card A329T inspection has been completed yet, so exact protected-folder behavior and model-detection files remain open.
- VIOFO product pages list Multiplex Video for A329T 2CH and A329T 3CH.
- The A329T 3CH product page says Multiplex Video can combine selected camera views, including telephoto, into one split-screen video file.
- Vortex Radar's A329S/T multiplexing walkthrough describes the default mode as separate per-camera files, plus selectable multiplex modes for two-camera and three-camera combinations.
- The walkthrough describes two-camera multiplex output as side-by-side 7680x2160, and three-camera multiplex output as a front view above two secondary views at 3840x3240.
- Because no direct full-card A329T inspection has been completed yet, multiplex path and filename handling should remain provisional.

## Non-Primary References

Search results also showed retailer and forum references for A329T. Those were not used as primary evidence for filename, folder, or channel rules.
