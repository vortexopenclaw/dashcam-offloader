# Dashcam Offloader 0.1.39

- Keep original safe video/photo filenames and camera-folder context in voluntarily submitted private card scans, including unfamiliar dashcam filename formats.
- Link each retained video measurement directly to its filename, folder, and source identifier. Show retained and omitted evidence counts when a large card exceeds sampling limits.
- Review the exact frozen scan evidence before sending; disclose that filenames may contain recording dates. A changed scan requires another review.
- Preserve anonymous numeric exports without original filenames, private source identifiers, or recording dates.

- Identify Z100 Master main-unit cards from the verified exact front-video model stamp, regardless of whether the card currently contains front-only, front/telephoto, or front/telephoto/rear footage. Keep main-card views separate from a cabin camera that records on its own card; blank or sibling model stamps do not establish exact identity.
- Put Check for Updates and Feedback directly in the top-right toolbar with separate accessible icons.

- Read bounded model and firmware observations from structured DDPAI logs, including colour-formatted logs. Keep component labels and historical versions separate from owner settings, and include only reviewed technical fields in private submissions.
- Recognize front `S_` and rear `Q_` time-lapse recordings on positively identified or manually selected Z100 Master main-unit cards. Do not apply those rules to telephoto footage, sibling models, or separately recording cabin cards.

This fixes missing evidence in future submissions; it cannot recover names omitted by older submissions. When neither structured logs nor the exact front stamp establish identity, manual model selection remains available. Wake-on-impact recordings with ordinary filenames are not covered by these time-lapse rules; this update does not claim to fix their parking classification.
