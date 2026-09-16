# Dashcam Offloader 0.1.15

- Recognizes BlackVue parking-motion sequences even when the dashcam microphone
  is disabled and every clip is silent.
- Uses encoded duration and filename cadence as the primary per-clip sequence
  evidence; audio presence is only supporting evidence for motion.
- Never treats audio absence by itself as proof of time-lapse.
- Keeps isolated or conflicting silent clips labeled **Parking Motion Or
  Timelapse** unless other sequence or safe setting evidence resolves them.
- Preserves mixed-card classification and BlackVue parking-impact handling.
