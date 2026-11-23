# Dashcam Offloader 0.1.47

- Crashes, app hangs, and errors are now reported to Sentry so problems can be diagnosed and fixed. Reports and their logs are scrubbed on your Mac before sending: home-folder paths and usernames are removed, video and photo filenames are replaced with a one-way hash, and camera serial numbers, GPS coordinates, network share names, and IP addresses are stripped. Videos, photos, and card contents are never included.
- The privacy policy has been updated to describe crash and error reporting.

Existing signed in-app updates are unchanged. This macOS build is ad-hoc signed, not notarized; a first installation may require normal macOS Open Anyway approval.
