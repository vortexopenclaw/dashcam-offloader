# Dashcam Offloader 0.1.23

- Retain paired file-size and duration measurements, along with video bitrate, for each sampled camera channel and recording mode in submitted card scans. Private paths and timestamps stay excluded.
- Give different modes and channels priority in the bounded media sample so large mixed backups do not consume the sample budget on one channel.
- Keep paired measurements in the private ingestion review records without guessing a recording rate from unrelated minimum and maximum values.

Previously submitted scans cannot recover missing paired measurements. A new scan with this version is needed to verify each camera and each setting. Large backups containing other cameras should be scanned one camera card at a time for unambiguous identification.
