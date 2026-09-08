function positive(value, name) {
  if (!Number.isFinite(value) || value <= 0) throw new Error(`Enter a valid ${name}.`);
  return value;
}

export function calculate({cardGB, targetHours, minMbps, maxMbps, allocationPercent, reservePercent}) {
  positive(minMbps, 'bitrate');
  positive(maxMbps, 'bitrate');
  if (maxMbps < minMbps) throw new Error('Maximum bitrate must be at least the minimum.');
  positive(allocationPercent, 'driving allocation');
  if (allocationPercent > 100) throw new Error('Driving allocation cannot exceed 100%.');
  if (!Number.isFinite(reservePercent) || reservePercent < 0 || reservePercent >= 100) {
    throw new Error('Headroom must be from 0 to less than 100%.');
  }
  // Card labels use decimal GB. Mbps * 0.45 = decimal GB per hour.
  const fraction = allocationPercent / 100 * (1 - reservePercent / 100);
  if (cardGB !== undefined) {
    positive(cardGB, 'card capacity');
    return {minHours: cardGB * fraction / (maxMbps * 0.45),
      maxHours: cardGB * fraction / (minMbps * 0.45)};
  }
  positive(targetHours, 'recording duration');
  return {minGB: targetHours * minMbps * 0.45 / fraction,
    maxGB: targetHours * maxMbps * 0.45 / fraction};
}

export function rates(camera) {
  return camera.channels.reduce((sum, channel) => ({
    minMbps: sum.minMbps + channel.minMbps,
    maxMbps: sum.maxMbps + channel.maxMbps,
  }), {minMbps: 0, maxMbps: 0});
}

export function hoursLabel(hours) {
  if (hours < 1 / 60) return 'less than 1 min';
  const minutes = Math.round(hours * 60);
  return `${Math.floor(minutes / 60)} hr ${minutes % 60} min`;
}
