# Firmware Filename Reference

**Purpose:** Reference for dashcam firmware filename patterns. **Bonus identification only** - firmware files won't be present on cards by default.

**Warning:** Firmware files are manually added by users for updates. They provide **bonus confirmation** when present but **cannot be relied upon** for automatic detection.

---

## Vantrue Firmware Filenames

**Pattern:** `VT_<MODEL>.bin`

| Model | Firmware Filename | Notes |
|-------|-------------------|-------|
| N4 S | `VT_N4S.bin` | Confirmed from official Vantrue site |
| N4 Pro S | `VT_N4PS.bin` | Confirmed from official Vantrue site |
| N4 Pro | `VT_N4P.bin` | Confirmed from official Vantrue site |
| N4 | `VT_N4.bin` | Expected pattern |
| E1 Pro | `VT_E1P.bin` | Expected pattern |
| S1 Pro | `VT_S1P.bin` | Expected pattern |

**Source:** Vantrue official firmware pages (https://www.vantrue.com/pages/n4s-manual-firmware, etc.)

**Notes:**
- Firmware files are **not readable on PC** - just copy to card
- User must manually copy firmware file to SD card root
- Camera reads firmware on boot, updates, then deletes or keeps file
- **Not present by default** - only appears when user initiates update

---

## Thinkware Firmware Filenames

**Pattern:** Varies by model, typically in versioned folder

| Model | Firmware Files | Notes |
|-------|----------------|-------|
| U3000 | `U3000_boot.bin`, `U3000_pkg.bin` | In `u3000_0_<ver>/` folder |
| U3000 Pro | `U3000PRO_Setting.exe` | In `SETTING/` folder |
| Q1000 | `pkg.bin` | Single file only |

**Source:** Thinkware downloads, observed on sample cards

**Notes:**
- U3000 uses folder structure: `u3000_0_1.02.03/U3000_boot.bin`
- U3000 Pro places `U3000PRO_Setting.exe` in `SETTING/` folder
- Q1000 and some models use single `pkg.bin` file
- Firmware folders only present after user downloads/places on card

---

## BlackVue Firmware Filenames

**Pattern:** Model-specific, versioned

| Model | Firmware Version Pattern | Example |
|-------|-------------------------|---------|
| DR970X Plus (II) | v2.008_YYYY.MM.DD | DR970X Plus (II) (v.2.008_2026.02.09) |
| DR970X-2CH LTE Plus (II) | v2.007_YYYY.MM.DD | DR970X-2CH LTE Plus (II) (v.2.007_2026.04.29) |
| DR970X Box Plus | v1.010_YYYY.MM.DD | DR970X Box Plus (v.1.010_2026.01.28) |
| DR770X (II) | v2.006_YYYY.MM.DD | DR770X (II) (v.2.006_2026.04.29) |
| DR590X-2CH Plus | v1.001_YYYY.MM.DD | DR590X-2CH Plus (v.1.001_2026.01.09) |
| DR590X-1CH Plus | v1.001_YYYY.MM.DD | DR590X-1CH Plus (v.1.001_2026.01.09) |
| ELITE 9 | v1.008_YYYY.MM.DD | ELITE 9 (v.1.008_2026.04.29) |
| ELITE 8 | v1.012_YYYY.MM.DD | ELITE 8 (v.1.012_2026.04.29) |

**Source:** BlackVue firmware download page (https://media.blackvue.com/firmware-download/)

**Notes:**
- BlackVue firmware typically downloaded via mobile app or cloud
- Manual firmware files may have different naming when downloaded
- Version numbers indicate release date and revision

---

## VIOFO Firmware Filenames

**Pattern:** TBD - requires research

| Model | Firmware Filename | Notes |
|-------|-------------------|-------|
| A229 Pro | TBD | Needs research |
| A229 Plus | TBD | Needs research |
| A229 Ultra | TBD | Needs research |
| A139 Pro | TBD | Needs research |
| A329S | TBD | Needs research |
| A329T | TBD | Needs research |

**Source:** https://www.viofo.com/pages/firmware (requires manual inspection)

---

## Vueroid Firmware Filenames

**Pattern:** TBD - requires research

| Model | Firmware Filename | Notes |
|-------|-------------------|-------|
| S1 4K Infinite | TBD | Needs research |

**Source:** https://vueroid.com/support/firmware/ (requires manual inspection)

---

## Detection Usage

### When Firmware Files ARE Present

**HIGH confidence bonus confirmation:**
- `VT_N4S.bin` in root → N4 S (Vantrue)
- `VT_N4PS.bin` in root → N4 Pro S (Vantrue)
- `SETTING/lang/ver.dat` contains "Device Name:U3000" → U3000 (Thinkware)
- `BlackVue/Config/version.bin` contains "model = DR970X Plus" → DR970X Plus (BlackVue)

**Workflow:**
1. Fast pattern match (folder + filename) → candidate list
2. **Check for firmware files** → if present, boost confidence for matching model
3. Present candidates (or auto-confirm if HIGH confidence)
4. User confirms or overrides

### When Firmware Files Are NOT Present (Typical Case)

**Rely on:**
- Folder structure patterns
- Filename patterns (regex match)
- **NOT** bitrates/resolutions/channel count (user-configurable)

**Present candidates for user confirmation.**

---

## Important Reminders

⚠️ **Firmware files are NOT reliable for automatic detection because:**
- Not present on cards by default
- Only appear when user manually adds them for updates
- User may have firmware for wrong model (downloaded incorrectly)
- User may have old firmware file from previous camera

✅ **Use firmware files as:**
- Bonus confirmation when present
- Tie-breaker between otherwise identical candidates
- User-visible hint: "Firmware file VT_N4S.bin found - likely N4 S"

❌ **Do NOT use firmware files as:**
- Primary detection method
- Sole reason to auto-confirm without user verification
- Replacement for folder/filename pattern matching

---

## References

- Vantrue firmware: https://www.vantrue.com/pages/n4s-manual-firmware
- Vantrue N4 Pro S firmware: https://www.vantrue.com/pages/n4pros-manual-firmware
- Vantrue N4 Pro firmware: https://www.vantrue.com/pages/n4pro-manual-firmware
- Thinkware downloads: https://thinkwarestore.com/downloads/
- BlackVue firmware: https://media.blackvue.com/firmware-download/
- VIOFO firmware: https://www.viofo.com/pages/firmware
- Vueroid firmware: https://vueroid.com/support/firmware/