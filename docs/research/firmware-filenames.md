# Firmware Filename Reference

**Purpose:** Reference known dashcam firmware package and file naming patterns for **bonus identification only**.

**Core rule:** Firmware files are manually downloaded and copied to the SD card for updates. They are usually absent from normal recording cards, and they can be stale, wrong, or left over from another camera. Treat them as a tie-breaker after folder and filename pattern detection, not as primary model identification.

## Detection Usage

During the fast card scan, it is acceptable to list root-level filenames and compare them against known firmware names already present on the card. Do not download firmware, unzip archives, OCR video, inspect binary contents, or wait on deep analysis during model identification.

Use firmware evidence as:

- A bonus hint when a known model-coded firmware filename is already present.
- A tie-breaker between otherwise identical candidates.
- A user-visible explanation, such as `Firmware file VT-N4S.bin found - likely N4 S`.

Do not use firmware evidence as:

- A primary detection method.
- A sole reason to auto-confirm a model.
- A replacement for folder structure, recording filename pattern, and explicit metadata files.

## Vantrue Firmware Filenames

Vantrue official pages expose direct `.bin` files. These are copied manually to the card root and are not present by default.

| Model | Main firmware filename | Accessory or rear firmware files | Notes |
|---|---|---|---|
| N4 S | `VT-N4S.bin` | `VT-RC09.bin`, `VT-RC18.bin` | Main file is model-coded. Rear/cabin accessory files are weaker because they may be shared. |
| N4 Pro S | `VT-N4PS.bin` | `VT-RC09.bin`, `VT-RC18.bin` | Main file is model-coded. |
| N4 Pro | `VT-N4P.bin` | `VT-RC04.bin` | Main file is model-coded. |

Notes:

- Vantrue instructs users to copy the firmware file to the microSD card root and not rename it.
- Vantrue notes the firmware file cannot be opened or read on a PC.
- These files should boost confidence only if the card also matches the Vantrue folder and filename pattern.

Sources:

- https://www.vantrue.com/pages/n4s-manual-firmware
- https://www.vantrue.com/pages/n4pros-manual-firmware
- https://www.vantrue.com/pages/n4pro-manual-firmware

## VIOFO Firmware Filenames

VIOFO official firmware links use model-coded main `.bin` names. Shared accessory or rear-camera firmware such as `EthcamTxFW.bin` and `LD98530A.bin` is not model-specific by itself.

| Model or family | Main firmware filename | Shared or secondary firmware files | Notes |
|---|---|---|---|
| A329TC | `FWA329TC.bin` | `LD98530A.bin` | Model-coded main file. |
| A329WW | `FWA329WW.bin` | `LD98530A.bin` | Model-coded main file. |
| A329T | `FWA329T.bin` | `LD98530A.bin` | Model-coded main file. |
| A329S | `FWA329S.bin` | `LD98530A.bin` | Model-coded main file. |
| A329 | `FWA329.bin` | - | Model-coded main file. |
| A229 Ultra | `FWA229U.bin` | `EthcamTxFW.bin` | Main file uses `U` suffix. |
| A229 Pro Tele | `FWA229PT.bin` | `EthcamTxFW.bin` | Main file uses `PT` suffix. |
| A229 Pro | `FWA229P.bin` | `EthcamTxFW.bin` | Main file uses `P` suffix. |
| A229 Plus | `FWA229S.bin` | `EthcamTxFW.bin` | Main file uses `S` suffix despite Plus branding. |
| A229 | `FWA229A.bin` | - | Older A229 package. |
| A119M Pro | `FWA119MP.bin` | - | Model-coded main file. |
| A119 Mini 2 | `FWA119MN.bin`, `FWA119M2.bin` | - | Official page lists both names for this model family. |
| A119 Mini | `FWA119M.bin` | - | Model-coded main file. |
| A119 V3 | `FWA119V3.bin` | - | Model-coded main file. |
| A139 Pro | `FWA139P.bin` | - | Model-coded main file. |
| A139 | `FWA139A.bin` | - | Model-coded main file. |
| T130 | `FWT130A.bin` | `EthcamTxFW.bin` | Model-coded main file plus shared secondary file. |
| A129 Pro | `FWA129P.bin` | - | Model-coded main file. |
| A129 Plus | `FWA129SN.bin`, `FWA129S.bin` | - | Official page lists both names. |
| A129 | `FWA129N.bin`, `FWA129.bin` | - | Official page lists both names. |
| VS1 | `FWVS1.bin` | - | Model-coded main file. |
| WM1 | `FWA_WM1.bin` | - | Model-coded main file. |
| MT1 | `FWMT1A.bin` | - | Model-coded main file. |

Source: https://www.viofo.com/pages/firmware

## Thinkware Firmware Filenames

Thinkware downloads are ZIP packages. Users unzip the package and copy all contents to the microSD card root. The ZIP and internal file names can be useful bonus evidence when present, but normal recording cards will usually not contain these files.

| Model | Official package inspected | Internal firmware files | Notes |
|---|---|---|---|
| U3000 | `u3000_0_1.02.04.zip` | `U3000_boot.bin`, `U3000_pkg.bin` | Model-coded internal files. |
| U3000 Pro | `u3000pro_0_1.00.04.zip` | `U3000PRO_boot.bin`, `U3000PRO_pkg.bin` | Model-coded internal files. |
| IU100C | `iu100c_1.1.02.zip` | not inspected | Action cam package listed on downloads page. |
| IU100G | `iu100g_1.00.09.zip` | not inspected | Action cam package listed on downloads page. |

Additional Thinkware model evidence:

- U3000 Pro real-card profile already uses `SETTING/lang/ver.dat` with `Device Name:U3000PRO` as stronger model metadata.
- Speed-camera data such as `smartguidepoint.dx2` is not model firmware and should not identify the dashcam model.

Sources:

- https://thinkwarestore.com/downloads/
- https://thinkwarestore.com/u3000-2/
- https://thinkwarestore.com/U3000PRO/

## BlackVue Firmware Packages

BlackVue firmware pages mostly expose model and version package titles. Manual firmware package filenames were not directly exposed by the scraped pages, but the model-specific download pages are still useful as a reference for naming and versions.

| Model or family | Official firmware page title pattern | Notes |
|---|---|---|
| ELITE 10 | `BlackVue ELITE 10 Firmware (v.X_YYYY.MM.DD)` | Versioned package title. |
| ELITE 9 | `BlackVue ELITE 9 Firmware (v.X_YYYY.MM.DD)` | Versioned package title. |
| ELITE 8 | `BlackVue ELITE 8 Firmware (v.X_YYYY.MM.DD)` | Versioned package title. |
| DR970X Plus / DR970X Plus II | `DR970X Plus (II) Firmware - Multilanguage` | Page says package supports 1CH and 2CH models. |
| DR970X-2CH LTE Plus / Plus II | `DR970X-2CH LTE Plus (II)` | Versioned package title. |
| DR970X Box Plus | `DR970X Box Plus` | Versioned package title. |
| DR770X / DR770X II | `DR770X (II)` | Versioned package title. |
| DR770X Box Pro | `DR770X Box Pro` | Versioned package title. |
| DR590X Plus | `DR590X-1CH Plus`, `DR590X-2CH Plus` | Versioned package titles. |

BlackVue card metadata is stronger than firmware package names:

- `BlackVue/Config/version.bin` model strings remain high-confidence model evidence when available.
- Firmware package titles and leftover manual update files should be bonus hints only.

Sources:

- https://blackvue.com/pages/firmware-download
- https://media.blackvue.com/firmware-download/
- https://media.blackvue.com/blackvue-dr970x-plus-firmware/
- https://media.blackvue.com/blackvue-elite-9-firmware/

## Vueroid Firmware Filenames

Vueroid official instructions say to unzip the firmware package and copy the `.DAT` file to the microSD card root. The top-level firmware table exposes model/version document titles, but direct attachment filenames were not visible in the scrape.

| Model | Official firmware listing | Expected card evidence |
|---|---|---|
| S1 4K Infinite | `v1.5.5` | A copied `.DAT` file in the card root after user unzip. |
| S1 QHD Infinite | `v.1.0.2` | A copied `.DAT` file in the card root after user unzip. |
| D40-Q2 | `v1.01` | A copied `.DAT` file in the card root after user unzip. |
| D21 4K | `v1.03` | A copied `.DAT` file in the card root after user unzip. |
| D20-Q2 Plus | `v1.04` | A copied `.DAT` file in the card root after user unzip. |
| D20-F2/F2E | `D20-F2E 2CH_firmware_v1.13`, `D20-F2E_1CH_firmware_v1.13`, `D20-F2_firmware_v1.13` | Document title is model-coded; root `.DAT` file name still needs archive inspection. |
| ZERO FHD | `v1.03` | A copied `.DAT` file in the card root after user unzip. |
| D10-F2W | `v1.00` | A copied `.DAT` file in the card root after user unzip. |

Notes:

- A generic `.DAT` file should not identify a Vueroid model unless the filename or surrounding package title is model-coded.
- For S1 4K Infinite, existing profile evidence from card layout remains more important than firmware update files.

Source: https://vueroid.com/support/firmware/?v=dcf0d7d2cd12#tab-id-2

## Redtiger Firmware Filenames

Redtiger official downloads mix model-coded archive names with generic or chipset-coded internal firmware names. Use with extra caution.

| Download or model hint | Archive name | Internal files inspected | Notes |
|---|---|---|---|
| F7N | `F7N_v1.20241014.0_318JPKEY.V112.zip` | `FWQ70A.bin` | Archive name is model-coded; internal file is not obviously model-specific. |
| F8 | `F8-20240802_01.zip` | `SigmastarUpgradeSD_SSC8826.bin` | Archive name is model-coded; internal file is chipset-style and weak. |
| S3-hosted 2026 package | hashed ZIP filename | `SigmastarUpgradeSD_SSC8838G.bin`, `sysVer.txt` | Hashed archive and chipset-style internal file are weak without page context. |
| F7N older package | `F7N_20231117.EN.VE115.7701.7z` | not inspected | 7z inspection tool unavailable locally; archive name is model-coded. |

Source: https://redtigercam.com/pages/firmware-new

## Practical Scoring

Recommended firmware evidence scoring:

- **Strong bonus:** model-coded main firmware filename already on the card, such as `VT-N4S.bin`, `FWA329S.bin`, `U3000PRO_boot.bin`.
- **Medium bonus:** model-coded archive or package title from an official source, useful for docs and research but normally not visible on a card.
- **Weak bonus:** shared accessory firmware, rear-camera firmware, generic `pkg.bin`, generic `.DAT`, or chipset names such as `SigmastarUpgradeSD_SSC8826.bin`.
- **Ignore for model ID:** speed-camera databases, viewer apps, manuals, card-reader software, and files whose only meaning is regional or language support.

## Important Reminders

- Firmware files are not reliable for automatic detection because they are not present by default.
- Users can download the wrong firmware or leave stale firmware from another camera.
- Firmware files should never override a clear explicit metadata file.
- Root filename checks must stay fast and non-blocking.
- Do not inspect or store unique device IDs.
