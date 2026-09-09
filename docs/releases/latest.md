# Dashcam Offloader 0.1.11

- Card-learning submissions now preserve anonymous paired file-size and duration
  measurements, so recording-time estimates can include actual file padding,
  audio, and metadata instead of relying only on video bitrate.
- Each measurement retains its resolution and frame rate without filenames,
  timestamps, GPS, or other location information.
- Adds a review-only scan-data extractor that refuses to combine unrelated
  size and duration ranges or use parking clips as driving evidence.
