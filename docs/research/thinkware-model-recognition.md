# Thinkware Model Recognition Catalog

Updated 2026-08-13 from Thinkware's official US comparison page, current
official product listings, and the ARC manuals already used for the bundled
ARC profiles. This is a recognition catalog, not a claim that every model has
a trained card profile.

## Recognition Boundary

The scanner records a Thinkware catalog hint only from exact evidence, in this
order:

1. `.SETTING/dashcam.inf` `model` value (ARC family)
2. `SETTING/lang/ver.dat` device-name/model value
3. A model-coded `SETTING/*_Setting.exe` filename
4. A model-coded root firmware/support filename (`.bin`, `.pkg`, `.zip`, or
   `.exe`)

The first two are settings metadata. Filename evidence can be present after a
manual firmware update, so it is never sufficient to select a bundled profile.
An exact catalog match without a profile remains a generic import.

## Official Current Comparison Models

Thinkware's US comparison page currently presents U3000 Pro, U3000, ARC 900,
ARC 700, U1000 Plus, ARC, Q1000, Q850, Q200, F200 Pro, F790, and F70 Pro.
The app now stores common compact model spellings such as `U3000PRO`,
`U1000PLUS`, `F200PRO`, and `F70PRO`, plus documented channel and resolution
hints where the product/manual evidence is explicit.

- U3000 Pro: 2CH, 4K front / 2K QHD rear
- U3000: 2CH, 4K front / 2K QHD rear
- U1000 Plus: 2CH, 4K HDR front / FHD rear
- Q1000 and Q850: 2CH, 2K QHD front/rear
- Q200: 2CH, 2K QHD front / FHD rear
- F200 Pro and F790: 2CH, FHD front/rear
- F70 Pro: 1CH, FHD 1080p front
- ARC 700, ARC 800, and ARC 900 retain their dedicated profile evidence and
  documented resolution variants.

## Additional Preliminary Thinkware Coverage

The catalog also now has exact-name recognition entries for F200, FA200, F800,
F800 Pro, F770, F750, X700, X550, X500, X350, QA100, FA700, QN300, QN200 /
QN200LX, and QN100. Their channels and high-level resolution class come from
official/legacy support references already collected in the broader catalog.
They are deliberately not profile-supported until a card scan validates their
folders, filenames, channel tokens, and parking behavior.

## Sources

- Thinkware US comparison: <https://thinkwarestore.com/dash-cam-comparison/>
- U3000 Pro: <https://thinkwarestore.com/product/u3000-pro-front-rear/>
- U3000: <https://thinkwarestore.com/product/u3000-front-rear-dash-cam-bundle-us/>
- U1000 Plus: <https://thinkwarestore.com/product/u1000-plus-front-rear-dash-cam-bundle-us/>
- Q850: <https://thinkwarestore.com/product/q850-front-rear-dash-cam-bundle-us/>
- Q200: <https://thinkwarestore.com/product/q200-front-rear-dash-cam-bundle-us/>
- F790: <https://thinkwarestore.com/product/f790-front-rear-dash-cam-bundle-us/>
- F70 Pro: <https://thinkwarestore.com/product/f70-pro-us/>
- ARC 700 manual: <https://download2.inavi.com/dashcam/ARC700/manual/arc700_manual_english_20250411.pdf>
- ARC 800 manual: <https://download2.inavi.com/dashcam/ARC800/manual/arc800_manual_english_20260623.pdf>
- ARC 900 manual: <https://download2.inavi.com/dashcam/ARC900/manual/arc900_manual_english_20251031.pdf>
