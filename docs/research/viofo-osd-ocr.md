# VIOFO OSD OCR Model Detection

**Purpose:** Capture the VIOFO front-camera frame OCR workflow used during explicit review or learning-mode analysis.

This is not part of the default fast insert workflow. Use it only when a user asks for deeper analysis, when the learning tool is ingesting a sample card, or when VIOFO folder and filename evidence leaves multiple plausible model candidates.

## When To Use OCR

Use VIOFO OSD OCR when:

- The card matches a VIOFO A-series family pattern, but folder and filename rules do not identify the exact model.
- The user explicitly requests model review or learning-mode analysis.
- The candidate models are known to stamp the camera model name into the bottom of the front-camera video.

Do not use OCR when:

- A high-confidence metadata file already identifies the model.
- The default fast scan only needs to rank candidates for user confirmation.
- The user disabled the camera model stamp in settings.

## Current Model Signals

- `A229 Pro`: bottom-center OSD text `VIOFO A229 Pro`; bottom 8 percent crop; half-max brightness threshold; scale 4x; `tesseract --psm 6`.
- `A329S`: bottom-center OSD text `VIOFO A329S`; bottom 8 percent crop; half-max brightness threshold; scale 4x; `tesseract --psm 6`.
- `A229 Plus`: bottom-center OSD text `VIOFO A229 Plus`; bottom 8 percent crop; half-max brightness threshold; scale 4x; `tesseract --psm 6`.
- `A229 Ultra`: bottom-center OSD text `VIOFO A229 Ultra`; bottom 8 percent crop; half-max brightness threshold; scale 4x; `tesseract --psm 6`.
- `A139 Pro`: bottom-center OSD text `VIOFO A139 PRO`; bottom 8 percent crop; half-max brightness threshold; scale 4x; `tesseract --psm 6`; compare case-insensitively.
- `A119M Pro`: bottom-center OSD text `VIOFO A119M Pro`; bottom 8 percent crop; half-max brightness threshold; scale 4x; `tesseract --psm 6`; retry multiple frames on bright footage.
- `A119 Mini 2`: bottom-center OSD text `VIOFO A119 Mini 2`; use adaptive thresholding and fuzzy matching because light-gray OSD text on bright scenes can confuse OCR.

## Front-Channel Selection

Prefer front-channel clips:

- A229, A329, and related multi-channel models: `F` or `PF` suffixes.
- A139 Pro: `_F` style front-channel suffix.
- A119 family: single-channel clips are front-channel clips.

Avoid interior, rear, telephoto, and parking-only clips unless the profile notes confirm the same model stamp appears there.

## Extraction Procedure

1. Pick one to three front-channel MP4 files.
2. Extract frames at a few timestamps, such as 1s, 5s, and 10s.
3. Crop the bottom 8 percent of the frame.
4. Upscale the crop 4x before OCR.
5. Apply model-specific preprocessing:
   - A229, A329, A139, and A119M Pro: threshold at 50 percent of the maximum brightness when implementing in the app.
   - A119 Mini 2: use adaptive thresholding and fuzzy matching.
6. Run Tesseract with page segmentation mode 6.
7. Match only known VIOFO model strings. If no model string is found, fall back to pattern matching and user confirmation.

Quick CLI baseline:

```bash
ffmpeg -y -ss 00:00:05 -i INPUT.MP4 -frames:v 1 \
  -vf "crop=iw:ih*0.08:0:ih*0.92,scale=iw*4:ih*4,format=gray" \
  /tmp/viofo-osd.png
tesseract /tmp/viofo-osd.png stdout --psm 6
```

The CLI baseline proves the toolchain and often reads the stamp directly. Production code should add the thresholding rules above and retry several frames before giving up.

## Scoring

Treat a recognized model stamp as high-confidence evidence for the model name, with caveats:

- It depends on the user-configurable camera model stamp being enabled.
- It should not override a stronger explicit metadata file.
- It should not use GPS, speed, date, time, license plate text, or other private OSD data.
- OCR frames and intermediate images must be temporary analysis artifacts and must not be committed to the repo.

## Fuzzy Matching For A119 Mini 2

Known OCR problems include reading `119` as similar-looking text such as `1TA`. Accept the model only when the rest of the text strongly matches VIOFO and Mini 2 wording.

Suggested app-side regex:

```text
VIOFO\s+A1(?:19|[0-9T][A-Z0-9]*)\s+Mini\s+2
```

Keep the raw OCR result in local debug logs only when needed. Do not publish or commit screenshots or real OSD text from user footage.
