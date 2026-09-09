export const CARD_SIZES = [32, 64, 128, 256, 512];
export function recordingRows(setup) {
  if (setup.hours) {
    if (setup.hours.length !== CARD_SIZES.length || setup.hours.some(t => !Number.isFinite(t) || t <= 0)) throw new Error('Invalid chart');
    return CARD_SIZES.map((gb, i) => ({gb, hours:setup.hours[i]}));
  }
  const {minMbps, maxMbps} = setup;
  if (!Number.isFinite(minMbps) || !Number.isFinite(maxMbps) || minMbps <= 0 || maxMbps < minMbps) throw new Error('Invalid recording rate');
  // Prefer a measured mean. With extrema only, use the midpoint RATE, not midpoint time.
  const rate = setup.estimatedMbps ?? (minMbps + maxMbps) / 2;
  if (!Number.isFinite(rate) || rate < minMbps || rate > maxMbps) throw new Error('Invalid estimated rate');
  // Decimal card capacity and bitrate; no hidden reserve factor.
  return CARD_SIZES.map(gb => ({gb, hours:gb / (rate * 0.45)}));
}
export function timeLabel(hours) {
  const minutes = Math.max(5, Math.round(hours * 60 / 5) * 5);
  const h = Math.floor(minutes / 60), m = minutes % 60;
  return h ? `${h} hr${m ? ` ${m} min` : ''}` : `${m} min`;
}
export function rowLabel(row) {
  return timeLabel(row.hours);
}
