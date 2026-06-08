# DJI RC (RM330) - Card Profile

## Device Overview

The DJI RC (model RM330) is a smart remote controller for DJI drones including the DJI Mini 3 Pro. It runs Android and has DJI Fly pre-installed. Its microSD card is used for screen recordings, screenshots, and caching live-view footage during flight, not for storing full-resolution drone footage, which stays on the drone's own microSD.

This profile is for the RC controller's microSD. For the drone footage card, see `dji-mini-3-pro.yaml`.

## Card Structure

```text
[root]
└── Android/
    └── data/
        └── dji.go.v5/              ← DJI Fly app - primary detection signal
            ├── .nomedia
            └── files/
                ├── MediaCaches/    ← Live-view OcuSync caches (MP4)
                ├── OriginalFiles/
                │   ├── Video/      ← Transferred drone videos (usually empty)
                │   ├── Photo/      ← Transferred drone photos (usually empty)
                │   └── PanoPhoto/  ← Transferred panoramas (usually empty)
                └── ImageCaches/    ← Thumbnails (JPG)
```

No `DCIM/` folder exists at the card root.

## Detection

**Primary signal:** Presence of `Android/data/dji.go.v5/`

The app identifier `dji.go.v5` is specific to the DJI Fly application on Android. No drone microSD card uses this path. Drone cards use `DCIM/100MEDIA/` at the root. This folder uniquely identifies the card as belonging to a DJI Android-based controller.

**Negative signals:**
- No `DCIM/100MEDIA/` at root means this is not a DJI drone card
- No `PRIVATE/M4ROOT/` means this is not Sony
- No `BlackVue/` means this is not BlackVue dashcam

## MediaCaches (Live-View Caches)

During flight, the RC controller receives a live OcuSync video transmission from the drone. If the controller's microSD is inserted, DJI Fly caches this stream as an MP4 file.

**Filename pattern:** `YYYY_MM_DD_HH_MM_SS_Cache.mp4`
**Location:** `Android/data/dji.go.v5/files/MediaCaches/`

These are low-quality live-view previews, not full-resolution recordings. Resolution and codec vary; quality depends on signal strength and OcuSync transmission quality.

## OriginalFiles (Transferred Drone Footage)

The DJI Fly app allows users to transfer individual files from the drone's microSD to the RC's microSD while connected. When populated, these folders would contain files matching the drone's own filename patterns (`DJI_NNNN.MP4`, `DJI_NNNN.JPG`, etc.).

On the sampled card, all three OriginalFiles subdirectories were empty. Transfer must be explicitly triggered by the user in-app.

## Offload Behavior

The app should:

- Detect this as a controller card, not a primary drone footage card
- Alert the user that drone footage is on the drone's microSD
- Check `OriginalFiles/`; if files were transferred, offer to offload them
- Skip `MediaCaches/` by default because they are low-quality previews; offer as opt-in
- Skip `ImageCaches/` because they are thumbnails only

## References

- DJI RC User Manual v1.0 (RM330): https://dl.djicdn.com/downloads/DJI_RC/UM/2023/DJI_RC_User_Manual_v1.0_en.pdf
- DJI Mini 3 Pro drone card profile: `profiles/dji-mini-3-pro.yaml`
