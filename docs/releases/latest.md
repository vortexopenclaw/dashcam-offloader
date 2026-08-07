# Dashcam Offloader 0.1.1

- Fixes the in-app update check for earlier 0.1.0 installs. The NAS folder-scope update is now offered from within the app.
- Fixed NAS folder scans: the app now stays in the folder you chose and never
  automatically switches to another dashcam directory found below it.
- Updates are now always verified against their published checksum before installing.
- Clearer error message when a downloaded update cannot be unpacked.
- Every published build now passes full verification during the release process before it goes out.
- The ZIP still includes only the main app.
