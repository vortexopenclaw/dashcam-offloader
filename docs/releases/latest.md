# Dashcam Offloader 0.1.29

- Identify VIOFO T330W by the exact `VIOFO T330W` model stamp in a front-channel video frame during ambiguous VIOFO scans.
- Include an experimental T330W profile for F/I/R and PF/PI/PR channel mapping and the card's Movie, Parking, RO, and Photo folders. Shared VIOFO folder layouts alone remain insufficient for exact identification; T330W RO/PF clips no longer become impact events solely from their location.
- List T330 and T330W as a family with differing rear-camera variants; the non-W model stamp has not yet been validated.
- Scanning and OCR remain local and read-only; video frames are not uploaded with scan feedback.
