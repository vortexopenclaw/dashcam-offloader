# Thinkware U3000 Pro Research Notes

## Official Sources Checked

- Support/download page: <https://thinkware.com/global/support/download/u3000-pro>
- English manual PDF: <https://download2.inavi.com/dashcam/U3000PRO/manual/u3000pro_manual_english_20250924.pdf>

## Findings

- The official support/download page lists the U3000 PRO model and links the English user manual.
- The official manual maps in-cabin recordings to the `incabin_rec` folder.
- The manual says the in-cabin recording feature requires the Interior IR camera.
- The manual says in-cabin videos are recorded during continuous recording mode.
- The manual's filename examples only show front and rear examples:
  - `REC_YYYYMMDD_HHMMSS_F.MP4`
  - `REC_YYYYMMDD_HHMMSS_R.MP4`

## Current Conclusion

The in-cabin folder is confirmed as `incabin_rec`, but the in-cabin filename suffix is not confirmed by the manual. Do not infer `_I`, `_C`, or another channel token until a real U3000 Pro cabin recording sample is available.
