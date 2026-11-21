# Dashcam Offloader 0.1.46

- Empty reserved photo slots (such as the placeholder files on DDPAI Z100 cards) are no longer listed or copied as photos. A file is only treated as an empty slot after its entire contents are verified; anything unreadable or changed stays a normal photo.
- Scan details show how many photo files were checked for empty slots.

Existing signed in-app updates are unchanged. This macOS build is ad-hoc signed, not notarized; a first installation may require normal macOS Open Anyway approval.
