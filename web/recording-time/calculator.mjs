export const CARD_SIZES = [32, 64, 128, 256, 512];
export function recordingRows(setup) {
  if (setup.hours) {
    if (setup.hours.length !== CARD_SIZES.length || setup.hours.some(t => !Number.isFinite(t) || t <= 0)) throw new Error('Invalid chart');
    return CARD_SIZES.map((gb, i) => ({gb, minHours:setup.hours[i], maxHours:setup.hours[i]}));
  }
  const {minMbps, maxMbps} = setup;
  if (!Number.isFinite(minMbps) || !Number.isFinite(maxMbps) || minMbps <= 0 || maxMbps < minMbps) throw new Error('Invalid recording rate');
  // Decimal card capacity and bitrate; no hidden reserve factor.
  return CARD_SIZES.map(gb => ({gb, minHours:gb / (maxMbps * 0.45), maxHours:gb / (minMbps * 0.45)}));
}
export function timeLabel(hours) {
  const minutes = Math.max(5, Math.round(hours * 60 / 5) * 5);
  const h = Math.floor(minutes / 60), m = minutes % 60;
  return h ? `${h} hr${m ? ` ${m} min` : ''}` : `${m} min`;
}
export function rowLabel(row) {
  const low = timeLabel(row.minHours), high = timeLabel(row.maxHours);
  return low === high ? low : `${low} – ${high}`;
}
