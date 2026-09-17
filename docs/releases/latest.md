# Dashcam Offloader 0.1.16

- Automatically runs a read-only card-health check after scanning a dashcam
  card.
- Shows an in-app warning when a video is zero bytes or an MP4/MOV file does
  not expose a valid duration and video track.
- Detects possible missing-camera recordings when an established channel is
  absent from synchronized timestamp groups while other channels continue.
- Requires a channel to appear in at least three groups and at least half of a
  recording mode's groups before treating it as established, avoiding warnings
  for briefly connected optional cameras.
- Keeps the source card read-only and performs no frame, audio, GPS, or private
  content upload.
- Describes clean results as having no *obvious* issues: a valid container
  header cannot prove that every encoded frame is intact.
