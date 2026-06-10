# Dashcam Detection Workflow

**Goal:** Quickly identify dashcam model when SD card is inserted, with minimal user interaction.

## Detection Strategy: Progressive Refinement

### Phase 1: Fast Pattern Match (< 1 second)
**No OCR, no firmware downloads, no unzipping, no binary analysis, no deep config reading**

The Mac app must never download firmware files as part of model detection. Firmware package research is a maintainer-only workflow used to learn public filename patterns ahead of time.

**Checks:**
1. Folder structure (e.g., `Normal/Event/Parking` = Vantrue N4 series)
2. Filename patterns (regex match on first 10-20 files)
3. Channel suffixes present (A/B/C, F/R, etc.)
4. Optional root filename check for already-present firmware update files (bonus evidence only)

**Output:** Ranked list of candidate models with confidence levels

**Example output:**
```
Detected: Vantrue N4 series (confidence: HIGH)
  - N4 S (confidence: MEDIUM) - volume label match
  - N4 Pro S (confidence: LOW) - pattern match only
  - N4 (confidence: LOW) - pattern match only
  - N4 Pro (confidence: LOW) - pattern match only

Action required: Select your camera model from the list above
```

### Phase 2: User Confirmation (< 5 seconds)
**Present top 3-5 candidates, user selects one**

UI shows:
- Detected folder pattern: "Vantrue N4 series pattern detected"
- Top candidates (sorted by confidence):
  - ✓ **N4 S** (3-channel, 2.5K front/interior/rear)
  - N4 Pro S (3-channel, 4K front, 1080P interior, 2.5K rear)
  - N4 Pro (3-channel, 4K front, 1080P interior/rear)
- "Not listed? Browse all models"

**User action:** Click/tap confirmed model

**Time budget:** < 5 seconds for user to confirm

### Phase 3: Profile Lock-In
**Once confirmed:**
- Load confirmed model profile
- Apply channel mapping, folder rules, exclusions
- Begin offload immediately

**No further analysis needed** unless:
- Card content doesn't match profile (error)
- User manually overrides

## Confidence Levels

### HIGH Confidence
- Explicit model metadata file present AND matches pattern
  - Example: `SETTING/lang/ver.dat` contains "Device Name:U3000"
  - Example: `BlackVue/Config/version.bin` contains "model = DR970X Plus"
- **Action:** Auto-confirm, no user interaction needed (with override option)

### MEDIUM Confidence
- Folder + filename pattern match to specific model family
- Weak supporting evidence (volume label, already-present firmware filenames)
- **Action:** Present top 2-3 candidates, user selects one

### LOW Confidence
- Folder structure matches multiple model families
- Filename pattern is generic (shared across brands)
- **Action:** Present top 5 candidates or prompt for manual selection

### NO CONFIDENCE (Unrecognized)
- Folder structure doesn't match any known profile
- Filename patterns don't match
- **Action:** "Unknown dashcam format. Please select manufacturer and model."

## Detection Rules by Manufacturer

### Vantrue N4 Series
**Folder pattern:** `Normal/`, `Event/`, `Parking/`, `Photo/`, `GPS/`
**Filename pattern:** `YYYYMMDD_HHMMSS_SEQ_MODE_CH.MP4` (SEQ = 5 digits)
**Candidates:** N4 S, N4 Pro S, N4, N4 Pro
**Distinguisher:** Requires explicit model file or user confirmation
**Confidence without model file:** MEDIUM (family), LOW (specific model)

### Thinkware U3000 Series
**Folder pattern:** `cont_rec/`, `evt_rec/`, `parking_rec/`, etc.
**Filename pattern:** `PREFIX_YYYYMMDD_HHMMSS_CH.MP4`
**Candidates:** U3000 (1CH/2CH), U3000 Pro (1CH/2CH/3CH)
**Distinguisher:** `SETTING/lang/ver.dat` → "Device Name:U3000" or "U3000PRO"
**Confidence without model file:** MEDIUM (U3000 series), requires confirmation

### BlackVue DR970X Series
**Folder pattern:** `BlackVue/Record/`, `BlackVue/Config/`
**Filename pattern:** `YYYYMMDD_HHMMSS_MODE_CH.mp4`
**Candidates:** DR970X Plus, DR970X, DR770X, DR900X Plus, etc.
**Distinguisher:** `BlackVue/Config/version.bin` → "model = DR970X Plus"
**Confidence without model file:** MEDIUM (BlackVue family), LOW (specific model)

### GoPro HERO / MAX / Mission Family
**Folder pattern:** `DCIM/*GOPRO` plus optional `MISC/version.txt`
**Filename pattern:** `G[HXP]######_MP4-style` GoPro chaptered video names, `GOPR####` photos, and grouped `G###` photo sets
**Candidates:** HERO4-HERO13, HERO compact/LIT HERO, MAX/MAX2, Fusion, Mission cameras
**Distinguisher:** safe `MISC/version.txt` fields, especially `camera type` and `firmware version`
**Confidence without model file:** MEDIUM (GoPro family), LOW (specific model)

Rules:

- Import every numbered `DCIM/*GOPRO` media folder, including overflow folders such as `101GOPRO`.
- Never trust mutable card volume labels for exact GoPro identity.
- Never submit private `version.txt` fields such as serial or Wi-Fi identifiers.
- Treat regular video and looping as selected-by-default transfer categories; time-lapse/time-warp/photos remain visible but can be unchecked by default.
- Use `Regular Recording`, not `Driving`, for GoPro and other non-dashcam camera profiles such as Sony mirrorless and DJI drone cards.
- Hide the channel filter for single-lens action camera, mirrorless, and drone profiles. Keep it for actual dashcams, including 1-channel dashcams where the user-facing channel is `Front`.
- Group GoPro loop chunks with the same folder, four-character prefix, and adjacent sequence numbers into one download item, then copy them via passthrough concatenation.
- Filename alone cannot reliably separate regular video from Time Lapse or TimeWarp, so prefer safe sampled metadata and duration/run evidence.

### VIOFO A Series
**Folder pattern:** `DCIM/Movie/`, `DCIM/Parking/`, `DCIM/Normal/`
**Filename pattern:** Varies by model (e.g., `YYYYMMDDHHMMSS_SEQ`)
**Candidates:** A229 Pro, A229 Plus, A229 Ultra, A139 Pro, A119 series
**Distinguisher:** Model-specific filename patterns, config files, or optional front-camera OSD OCR during explicit review
**Confidence without model file:** Depends on pattern uniqueness

### Optional VIOFO OSD OCR Review
VIOFO OCR is an explicit review or learning-mode tool, not part of the default fast scan. Use it when VIOFO folder and filename patterns leave several plausible models and the user wants deeper analysis.

Current documented OCR method:

- Select a front-channel video (`F`, `PF`, `_F`, or a single-channel A119 clip).
- Extract one or more frames.
- Crop the bottom 8 percent of the frame where the camera model stamp appears.
- Scale the crop 4x.
- Run `tesseract --psm 6`.
- Match known model stamps such as `VIOFO A329S`, `VIOFO A229 Pro`, `VIOFO A229 Plus`, `VIOFO A229 Ultra`, `VIOFO A139 PRO`, `VIOFO A119M Pro`, or `VIOFO A119 Mini 2`.

Preprocessing notes:

- A229, A329, A139, and A119M Pro profiles use a half-max brightness threshold.
- A119 Mini 2 needs adaptive thresholding and fuzzy matching because the light-gray OSD can be low contrast on bright scenes.
- If the user disabled Camera Model Stamp, OCR cannot identify the model.

See `docs/research/viofo-osd-ocr.md` for the detailed workflow.

## Implementation Notes

### Performance Requirements
- Phase 1 (pattern match): < 1 second for 1000+ files
- Phase 2 (user selection): < 5 seconds user time
- Phase 3 (offload start): Immediate after confirmation

### Caching/Optimization
- Cache folder structure scan (don't re-scan if same card)
- Cache first 20 filenames for pattern matching
- Allow only a fast root filename check for known firmware names already on the card
- Never download firmware files from the Mac app
- Skip archive extraction, binary inspection, OCR, and deeper config analysis unless explicitly requested
- Allow optional VIOFO front-camera OSD OCR in learning mode or explicit review mode only
- Pre-load candidate profiles for fast presentation

### Error Handling
- **Wrong profile selected:** User notices mismatched channel count/resolution → allow override
- **Multiple models match:** Present all matches, user selects
- **Card content changes mid-offload:** Detect new files, verify pattern still matches
- **User selects wrong model:** Offload proceeds anyway (user's choice), log discrepancy if found

### User Experience Goals
- **Best case (HIGH confidence):** "Detected Thinkware U3000. Proceed?" → 1 click
- **Typical case (MEDIUM confidence):** "Vantrue N4 series. Which model?" → 1 click from 2-3 options
- **Worst case (LOW confidence):** "Unknown format. Select manufacturer → model" → manual selection

## Profile Schema Extensions

Add to each profile:
```yaml
detection:
  folder_pattern: "Normal|Event|Parking|Photo|GPS"
  filename_regex: "^\\d{8}_\\d{6}_\\d{5}_[NEP]_[ABC]\\.MP4$"
  confidence_without_metadata: "MEDIUM"  # HIGH|MEDIUM|LOW
  candidates_if_uncertain:
    - vantrue-n4-s
    - vantrue-n4-pro-s
    - vantrue-n4
    - vantrue-n4-pro
  quick_description: "3-channel Vantrue N4 series (2.5K/2.5K/2.5K)"
```

## Open Questions

- Should we ever read config files automatically (with user permission)?
- How to handle firmware updates that change filename patterns?
- Should we cache per-card fingerprints (volume ID + detected model)?
- How to handle cards with content from multiple cameras (shared cards)?
