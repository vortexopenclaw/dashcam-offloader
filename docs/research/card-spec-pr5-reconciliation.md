# Historical card-spec draft PR #5 reconciliation

## Scope and evidence boundary

This record reconciles [draft PR #5](https://github.com/vortexopenclaw/dashcam-offloader/pull/5), `feature/card-spec-docs` at `d3b7d664ed2e8f61b2b05869523ed1404587df48`, against main at `efb6b72`. The original diff starts at merge base `00b86b8b795d48d37023b72a9f63cf3cc0589879` and changes 17 files. Review covered that full diff, the current versions of those files, all four issue comments, and the empty review/inline-comment lists.

The historical PR added two narrative documents and an analyzer. This reconciliation preserves only the narrative leads and provenance; the analyzer is rejected and must not be executed. The historical additions do not include raw probe JSON, a sanitized measurement manifest, source media, or captured analyzer output. The PR body and comments report successful mounted-card runs; this reconciliation verifies what the branch reports, not the measurements themselves. No card or NAS access, analyzer execution, or new media measurement took place. The absence of corroboration here does not establish that the historical observations were false.

No historical measurement is promoted to `ffprobe`, `real_card_sampled`, a new default, or a storage-rate estimate. Current profiles, observed counts, and later submission evidence remain unchanged. Existing MAXcam 1080p assumptions also remain assumptions, not a rejection of the branch's 1440p claim.

## Useful findings retained with provenance

### MAXcam measurements pending corroboration

The June 8 branch commit `87f7d21` and [June 8 comment](https://github.com/vortexopenclaw/dashcam-offloader/pull/5#issuecomment-4653439127) report the following single-channel MOV samples. These are **unverified historical branch claims**:

| Reported mode | Codec | Resolution | FPS | Reported bitrate | Reported duration |
|---|---|---|---|---|---|
| Normal / `VID` | H.264 | 2560x1440 | 30 | about 28.6 Mbps | 60.1 seconds |
| Locked/event / `SOS` | H.264 | 2560x1440 | 30 | about 28.4 Mbps | 60.1 seconds |

The branch reports 65 normal clips and one event clip. It does not retain the probe output needed to corroborate these values. Its analyzer chooses stream bitrate when available and otherwise container bitrate; the prose does not establish which supplied each MAXcam value. Do not treat these numbers as whole-file storage rates or factory defaults. Original recording filenames and dates are intentionally omitted here.

Commit `fddc837` explicitly corrects the initial firmware-evidence interpretation: `MasterVersionInfo_SW_v1.13_HW_v1.01.bin` reportedly reached the card through a manual firmware-update copy. Preserve that provenance as a warning, not a normal-card requirement or proof of installed firmware. A copied update file cannot establish recorder identity or installed version by itself.

The privacy guidance is independently useful: the current MAXcam documents already describe `DATA/serial_num.txt` as a serial-number file and `DATA/gps_userdb.bin` as a user GPS-lockout database. Prefer the documented model-named recording folders and clip patterns; do not read or publish those private file contents for detection. This is documentation guidance, not a claim that this replacement changes runtime handling or YAML presence-only signals.

### Unresolved contradictions and other historical leads

All values in the following list are branch-reported leads, not newly validated facts:

- **Thinkware U3000 Pro cabin:** commit `d3b7d66` and the [June 9 comment](https://github.com/vortexopenclaw/dashcam-offloader/pull/5#issuecomment-4655112201) claim `incabin_rec/EXT_YYYYMMDD_HHMMSS_I.MP4`, H.264 1920x1080 at 30 fps, about 8 Mbps stream bitrate and 12.3 Mbps container bitrate. Current main retains a manual-confirmed folder with a missing real cabin sample and unknown suffix. Keep that status. The [October 7 review comment](https://github.com/vortexopenclaw/dashcam-offloader/pull/5#issuecomment-6031131155) explicitly flags this conflict.
- **Thinkware parking:** the draft reports 15 fps parking-event and motion/time-lapse samples, while the current metadata reference includes 30 fps parking rows. The draft also reports hidden secondary `PAS` recordings at 1280x720, 15 fps, about 0.6 Mbps. Different samples/settings might explain the difference; no retained probe evidence resolves it. Do not replace current rows or infer a new cabin parser from these statements.
- **BlackVue Elite 9 counts:** the draft reports 1,154 normal, 281 parking and 90 impact/event front/rear pairs. Current profile counts are 538, 531 and 456 respectively. Preserve current counts and later parking classification evidence. Draft bitrate ranges of about 56.5-60.0 Mbps front and 23.9-25.1 Mbps rear broadly overlap current metadata; the exact historical endpoints remain uncorroborated here.
- **VIOFO A229 Pro:** the draft reports 208 driving triplets, versus current main's 210; parking and locked counts agree. Current main already documents the useful roughly 36/15.6/24 Mbps driving and roughly 4 Mbps parking observations, along with separate sample provenance. Its later follow-up also records that the card was not mounted during that follow-up. Do not overwrite counts or conflate passes.
- **VIOFO A329S:** the draft reports H.264 4K30 front and 2K30 interior/rear, about 65.5/27/27 Mbps driving and 12.3/8.2/8.2 Mbps parking, plus 2,927 parsed clips. Current card-profile notes retain later 2CH submission evidence and the 3CH resolution layout. Some older current metadata rows differ, including an interior 1080p row. Preserve the discrepancy for a future provenance-backed pass rather than silently correcting either source from the draft.
- **Vueroid S1 4K Infinite:** the draft reports 1,082 parsed clips, H.264 4K30/1080p30/1440p30 and roughly 48/13-15/22 Mbps, plus config-string firmware `S1-4K V1.04.2`. Main has later firmware 1.6.0 submission and direct whole-file storage-rate notes. Keep those sources and their time-lapse caveats; the old config-string claim does not validate a new extraction method.
- **BlackVue DR970X LTE Plus:** commits `12acd77` and `908a62b` report firmware 2.007/rev1584, three driving and two parking front/rear pairs, HEVC 4K30 front at about 60.9-62.1 Mbps and 1080p30 rear at about 10.9-11.6 Mbps. Main's dedicated profile already retains the model/version, approximate 61/11 Mbps media, and modem privacy exclusions. Keep that profile. The draft additionally claims absent HDR metadata and infers in-camera processing, but its analyzer does not request color-transfer, color-primaries, pixel-format, or profile fields. That analyzer cannot substantiate the HDR conclusion; do not carry it forward.
- **Config settings across models:** specific historical file sizes, version strings and setting values remain textual reports. Known-file names and a sensitive-key denylist do not establish that every printable value is safe. Do not import timezone or arbitrary strings into public/default submissions. Future extraction requires bounded, field-specific allowlisting and privacy tests.

## Disposition of all 17 original files

“Retained” below means a narrowed documentation replacement or an explicitly unverified lead in this record. It never means wholesale copying of the old file.

| Original path | Disposition against current main | Reason |
|---|---|---|
| `README.md` | Skipped | The added config-reference link would advertise a document whose extraction safety and current-card claims are not established. Link this reconciliation from the research index instead. |
| `docs/card-profiles/blackvue-elite-9.md` | Superseded; historical lead retained here | Preserve later validated status, mode/time-lapse distinctions, timestamps and counts; approximate media already appears in the metadata reference. |
| `docs/card-profiles/escort-maxcam-360c.md` | Retained narrowly | Add privacy-focused detection guidance and a link here; keep codec/resolution/FPS assumptions unconfirmed. Preserve unique 1440p claims only above. |
| `docs/card-profiles/thinkware-u3000-pro.md` | Skipped; contradiction retained here | Cabin suffix remains sample-missing. Other media/config additions lack retained probe evidence. |
| `docs/card-profiles/viofo-a229-pro.md` | Superseded | Current measurements and sample-specific caveats cover useful media findings. Do not restore old counts or remove open questions. |
| `docs/card-profiles/viofo-a329s.md` | Superseded; discrepancy retained here | Preserve newer hardware and 2CH submission notes. Old parking bitrates and conflicting metadata need corroboration. |
| `docs/card-profiles/vueroid-s1-4k-infinite.md` | Superseded | Later firmware/submission and storage evidence cover the useful media baselines; retain time-lapse caveats. |
| `docs/config-settings-reference.md` | Skipped; privacy lesson retained here | No new config extractor or blanket printable-string safety claim. Current DR970X LTE Plus profile already excludes modem identifiers. |
| `docs/research/blackvue-elite-9.md` | Superseded | Preserve newer per-clip parking evidence; old counts and overlapping bitrates do not justify replacement. |
| `docs/research/escort-maxcam-360c.md` | Retained narrowly | Add a provenance link to the pending MAXcam measurements and manual-copy warning; do not remove existing unconfirmed status. |
| `docs/research/mounted-card-spec-pass-2026-06-08.md` | Replaced by this record | Its “four cards” introduction lists seven sample entries, reuses a mount path for two BlackVues, calls historic data current, and overclaims analyzer privacy. Preserve leads without that framing or repeat command. |
| `docs/research/thinkware-u3000-pro.md` | Skipped; contradiction retained here | Preserve the current manual-only cabin conclusion pending corroboration. |
| `docs/video-metadata-reference.md` | Unchanged; unique leads retained here | Do not label branch prose as a fresh `ffprobe` source or overwrite later measurements. Existing cross-model inconsistencies require separate evidence. |
| `profiles/blackvue-elite-9.yaml` | Superseded; unchanged | Preserve validated status, expanded mode tokens and newer counts. |
| `profiles/escort-maxcam-360c.yaml` | Skipped; unchanged | No retained measurement evidence supports changing defaults or setting codec confirmation true. |
| `profiles/thinkware-u3000-pro.yaml` | Skipped; unchanged | Do not promote `EXT`/`I` to real-card validation or remove unknown-channel evidence. |
| `scripts/analyze-mounted-card-specs.py` | Rejected | Hardcoded mount/model associations, unbounded recursive enumeration and subprocesses, raw sample filenames/errors, and arbitrary printable strings after a denylist do not meet bounded/private research requirements. Do not execute it. |

## Follow-up and integration decision

A future measurement upgrade needs authorized direct samples or retained sanitized probe output with model attribution, mode/channel, codec, dimensions, rational frame rate, duration, separate stream/container bitrate, and complete-file size when making storage claims. Preserve sample/session provenance without recording filenames or recording timestamps. Cabin validation additionally needs a corroborated folder/pattern relationship. Resolve the historical conflicts explicitly rather than copying their validation flags.

After this replacement is integrated, close PR #5 as superseded with a link to this record. Keep its commit links as historical provenance. This reconciliation does not close the PR, delete its branch, push, merge, or publish a release.
