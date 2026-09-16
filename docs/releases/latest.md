# Dashcam Offloader 0.1.12

- Correctly recognizes exact Blackvue Elite 9 firmware metadata even when
  structurally similar Elite 8/10 profiles score higher.
- Classifies Elite 9 `PF/PR` clips as parking motion detection and `IF/IR`
  clips as parking impact detection instead of inferring time-lapse footage.
- Uses reliable filename recording times in the app and on downloaded files,
  avoiding the Elite 9 card filesystem's seven-hour timestamp shift.
- Speeds up downloads by reading each source file only once during copy,
  hashing that same data for verification, and processing 8 MiB chunks instead
  of issuing a main-thread progress update for every 1 MiB.
- Card-learning submissions preserve anonymous paired file-size and duration
  measurements for more accurate recording-time estimates.
