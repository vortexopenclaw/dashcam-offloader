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
- A real 3CH card provided by Ariel on 2026-06-08 confirms cabin clips use `incabin_rec/EXT_YYYYMMDD_HHMMSS_I.MP4`.
- A representative cabin clip measured H.264 1920x1080 30 fps at about 8 Mbps stream bitrate.

## Current Conclusion

The in-cabin folder is `incabin_rec`; real-card evidence confirms `EXT` is the in-cabin prefix and `I` is the interior channel token.
