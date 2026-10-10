# Dashcam Offloader 0.1.28

- Prevent a card-learning submission before a complete, nonempty file scan, or after a card rescan changes the reviewed data.
- Refuse learning submissions with unreadable video bitrate metadata rather than silently sending only folder counts. Show an actionable warning in the review window.
- Show every measured video group in the review window; bitrate ranges are samples by folder, recording mode, and camera channel, not one setting assumed for the entire card.
- Scanning remains read-only. Existing footage can be rescanned without formatting the card.
