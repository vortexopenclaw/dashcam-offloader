# Dashcam Offloader 0.1.13

- Distinguishes Blackvue parking motion from parking time-lapse using the
  camera's allowlisted parking-mode setting instead of guessing from the shared
  `P` filename code.
- Keeps Blackvue `P` clips labeled **Parking Motion Or Timelapse** when that
  safe setting is missing or unknown.
- Continues to classify `I` clips separately as parking impact recordings in
  either Blackvue parking mode.
- Applies the safer Blackvue rule across the supported Elite 8, Elite 9,
  Elite 10, DR770X Box, DR970X Plus, and DR970X LTE Plus profiles.
- Restores the automated Cloudflare release path with a validated GitHub
  Actions credential that has both Worker and R2 access.
