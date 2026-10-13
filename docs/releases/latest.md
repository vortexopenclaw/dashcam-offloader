# Dashcam Offloader 0.1.31

- Create a separate five-angle multicam for each drive: a different recording day or more than five minutes without footage starts a new timeline. Short recording gaps are preserved.
- Keep normal and protected/RO recordings in the same drive across recognized recording-category folders. Camera timestamps and channel identity, not sequence numbers or file permissions, determine placement.
- Recognize explicit Emergency/Event/Locked/RO filename prefixes and E/L camera suffix variants while preserving appended notes. These variants are supported defensively, not a claim that every camera uses them.
- Allow single-channel emergency segments alongside a complete four-camera drive. Overlapping clips switch at the next same-camera timestamp without stretching footage, and normal footage resumes after a short overlapping emergency clip; missing cameras appear as gaps.
- Refuse ambiguous duplicate same-camera timestamps and drives missing an entire camera instead of guessing. Originals remain unchanged.
