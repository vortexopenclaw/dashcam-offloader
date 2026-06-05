# Dashcam Detection Workflow

**Goal:** Quickly identify dashcam model when SD card is inserted, with minimal user interaction.

## Detection Strategy: Progressive Refinement

### Phase 1: Fast Pattern Match (< 1 second)
**No OCR, no firmware analysis, no config file reading**

**Checks:**
1. Folder structure (e.g., `Normal/Event/Parking` = Vantrue N4 series)
2. Filename patterns (regex match on first 10-20 files)
3. Channel suffixes present (A/B/C, F/R, etc.)

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
- Weak supporting evidence (volume label, firmware filenames)
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

### VIOFO A Series
**Folder pattern:** `DCIM/Movie/`, `DCIM/Parking/`, `DCIM/Normal/`
**Filename pattern:** Varies by model (e.g., `YYYYMMDDHHMMSS_SEQ`)
**Candidates:** A229 Pro, A229 Plus, A229 Ultra, A139 Pro, A119 series
**Distinguisher:** Model-specific filename patterns, config files
**Confidence without model file:** Depends on pattern uniqueness

## Implementation Notes

### Performance Requirements
- Phase 1 (pattern match): < 1 second for 1000+ files
- Phase 2 (user selection): < 5 seconds user time
- Phase 3 (offload start): Immediate after confirmation

### Caching/Optimization
- Cache folder structure scan (don't re-scan if same card)
- Cache first 20 filenames for pattern matching
- Skip firmware/config file analysis unless explicitly requested
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