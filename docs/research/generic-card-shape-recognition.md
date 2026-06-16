# Generic Card Shape Recognition

This note tracks folder layouts that are useful for unknown-card intake. These signals should identify a brand or family only. Do not promote them to exact model support without safe metadata, OSD proof, direct sample-card training, or user confirmation.

## Implemented Family Hints

- BlackVue: `BlackVue/Record` plus `BlackVue/Config`. Exact model can come from safe version/config metadata when present.
- Thinkware: `cont_rec` with one or more of `evt_rec`, `manual_rec`, `motion_timelapse_rec`, `parking_rec`, `sos_rec`, `SETTING`.
- VIOFO: `DCIM/Movie` with `RO`, `Parking`, or `Photo` subfolders. A-series siblings still need OSD or sample-card evidence for exact model selection.
- Garmin: numbered folders under `DCIM`, especially `100EVENT`, `101PHOTO`, `102SAVED`, `103PARKM`, `104TLPSE`, `104UNSVD`, `105UNSVD`.
- Nextbase: `Videos`/`Protected`, or `Video`/`Protected`/`Photo`.
- Miofive: `CarDV/Movie/Normal`, `CarDV/Movie/Park`, optional `LOG/DEVLOG`.
- Vantrue: root `Normal`, `Event` or `Parking`, and `GPS`.
- 70mai: root `Normal`, `Parking` or `Lapse`, plus `.formated` or `.sstar.format` markers.
- Vueroid: `INF` with `PARK` or `PEVENT`, and optional `EVENT`, `USER`, `CONFIG`.
- Cansonic: `VIDEO` and `PROTECTED` with `L/R/B` channel-suffix filenames.
- Botslab: `360CARDVR/REC` with `360CARDVR/PARKING` or `360CARDVR/SECVIDEO`, plus optional `360CARDVR/GPS`.
- Escort: `Escort_M1/MOVIE` and `Escort_M1/LockedVideo`.
- Cobra: `DCIM/RoadScout`.
- DDPAI: `DCIM/NormalVideo`, `DCIM/EventVideo`, `DCIM/ParkingVideo`, `DCIM/Photo`.
- Rove: root `Video` with Rove-style numeric timestamp filenames. This stays low confidence because a single `Video` folder is weak evidence.

## Source Notes

- Garmin documents `DCIM` storage with numbered folders for event, photo, saved, parked, Travelapse, and unsaved clips.
- Thinkware documents memory-card folders `cont_rec`, `evt_rec`, `manual_rec`, `motion_timelapse_rec`, `parking_rec`, and `sos_rec`.
- VIOFO support/manual material documents `DCIM/Movie`, locked `RO`, parking modes, and photo storage under `DCIM/Photo`.
- Nextbase support documents card folders such as `Photo`, `Protected`, and `Video`.
- DDPAI manuals describe multiple mode folders under `DCIM`; exact folder names should still be validated by real cards.

## Guardrails

- Folder-only matches produce `generic_card_shape_hint` diagnostics.
- These diagnostics help feedback analysis and intake routing, but do not set `identifiedCamera` by themselves.
- Exact known untrained models still require safe metadata parsed through `KnownDashcamCatalog`.
- Trained exact profiles can still win when their folder, filename, model-text, channel, and media evidence is specific enough.
