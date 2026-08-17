# Dashcam Offloader 0.1.3

- Fixed slow card scans on cards with many recordings. The app now reuses
  filename processing during camera detection, substantially reducing scan time.
- Removed the unreleased Vueroid H1 from the manual camera picker. Existing
  read-only detection support remains available for verified card evidence.
- Strengthened update verification so the app accepts only the exact signed
  release it requested.
