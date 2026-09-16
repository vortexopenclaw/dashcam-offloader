# Dashcam Offloader 0.1.14

- Classifies each BlackVue `P` clip independently, so one card can contain both
  parking motion and parking time-lapse history.
- Uses audio presence, encoded duration, and filename cadence: BlackVue
  time-lapse is silent and compresses about 30 minutes of real time into each
  one-minute playback clip.
- Avoids bitrate, resolution, nominal frame-rate, and file-size guesses because
  real Elite 9 motion and time-lapse samples overlap on those attributes.
- Uses the card's current parking-mode setting only as a fallback and keeps
  genuinely unresolved historical clips labeled **Parking Motion Or
  Timelapse**.
- Continues to classify BlackVue `I` clips as parking impact recordings.
