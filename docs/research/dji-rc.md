# DJI RC — Research Notes

## Device

- **Model:** DJI RC (RM330)
- **Type:** Smart remote controller (companion device, not a camera)
- **OS:** Android
- **App:** DJI Fly (package identifier: `dji.go.v5`)
- **Compatible drones:** DJI Mini 3 Pro, DJI Mini 3, DJI Air 3, and others
- **Manual:** https://dl.djicdn.com/downloads/DJI_RC/UM/2023/DJI_RC_User_Manual_v1.0_en.pdf

## Card Purpose

The RC's microSD card is used for:
- Caching live-view OcuSync transmission streams during flight (`MediaCaches/`)
- Storing drone footage transferred from the drone in-app (`OriginalFiles/`)
- Screen recordings and screenshots (not observed on sampled card)

Full-resolution drone footage (4K MP4 + SRT sidecar) is stored exclusively on the **drone's own microSD**, which uses the `dji-mini-3-pro` profile.

## Real Card Evidence

Card scanned. Structure confirmed:

- `Android/data/dji.go.v5/` — DJI Fly app data directory present
- `Android/data/dji.go.v5/files/MediaCaches/` — populated with `YYYY_MM_DD_HH_MM_SS_Cache.mp4` files
- `Android/data/dji.go.v5/files/OriginalFiles/Video/` — empty
- `Android/data/dji.go.v5/files/OriginalFiles/Photo/` — empty
- `Android/data/dji.go.v5/files/OriginalFiles/PanoPhoto/` — empty
- `Android/data/dji.go.v5/files/ImageCaches/` — populated with JPG thumbnails referencing `DJI_##` filenames from the drone card
- No `DCIM/` at card root
- `.nomedia` files present in Android directories

## Detection Decision

The `Android/data/dji.go.v5/` path is the definitive detection signal:

- `dji.go.v5` is the Android package identifier for the DJI Fly app
- No DJI drone microSD card contains this path — drone cards use `DCIM/100MEDIA/` at root
- Other dashcam/camera cards do not have an `Android/data/` tree at all
- This single folder is sufficient to classify the card as a DJI RC controller card

The absence of `DCIM/100MEDIA/` at root acts as a negative confirmation against accidental match with the DJI Mini 3 Pro drone card.

## MediaCache Format

Filename: `YYYY_MM_DD_HH_MM_SS_Cache.mp4`

These files are the OcuSync live-view transmission stream cached locally by DJI Fly during flight. They are not high-resolution recordings — the live-view feed is a compressed preview stream used for pilot visibility. Codec and resolution not confirmed from ffprobe (low priority; these files are not primary footage).

## Privacy Notes

MediaCache filenames contain full datetime timestamps. These reflect when flights occurred. As with all camera profiles, no file counts, specific timestamps, or session dates from the sampled card are included in this documentation.
