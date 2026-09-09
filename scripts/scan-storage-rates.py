#!/usr/bin/env python3
"""Extract review candidates from private scanner records; never publish raw scans.

Only paired measurements establish complete-file rates. Summary size/duration
extrema are intentionally not combined: they need not describe the same clips.
Output omits paths, timestamps, notes, settings, contacts and location data.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path


def positive(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value > 0


def driving(sample):
    values = [str(sample.get(k, '')).lower() for k in ('mode', 'displayMode', 'outputCategory', 'inferredParkingPattern')]
    if any(any(t in v for t in ('park', 'sentry', 'timelapse', 'time_lapse')) for v in values):
        return False
    return any(v in ('driving', 'continuous', 'normal', 'driving_event') for v in values)


def measurement(sample):
    size, duration = sample.get('fileSizeBytes'), sample.get('durationSeconds')
    if not positive(size) or not positive(duration) or size > 1e12 or duration > 86400:
        return None
    return {k: sample.get(k) for k in ('width', 'height', 'nominalFrameRate', 'videoBitrate')} | {
        'fileSizeBytes': size, 'durationSeconds': duration,
        'storageBytesPerSecond': size / duration,
    }


def extract(record):
    payload = record.get('payload', record)
    learning = payload.get('training') or payload.get('cardLearning') or payload.get('learning') or {}
    scan = payload.get('scan') or payload.get('scanSummary') or learning.get('scanSummary') or {}
    result = {'manufacturer': learning.get('manufacturer'), 'model': learning.get('model'),
              'completeFileSamples': [], 'videoOnlyGroups': 0, 'unmeasuredDrivingGroups': 0}
    for group in scan.get('videoSpecSummaries', []):
        if not driving(group):
            continue
        valid = [m for s in group.get('storageRateSamples', []) if (m := measurement(s))]
        for m in valid:
            # Shape/format stay with their own size-duration pair.
            result['completeFileSamples'].append({'channel': group.get('channel'), **m})
        if not valid:
            if positive(group.get('sampleBitrateMin')):
                result['videoOnlyGroups'] += 1
            else:
                result['unmeasuredDrivingGroups'] += 1
    for sample in scan.get('videoSpecSamples', []):
        if not driving(sample):
            continue
        m = measurement({**sample, 'videoBitrate': sample.get('estimatedBitrate')})
        if m:
            result['completeFileSamples'].append({'channel': sample.get('channel'), **m})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input_directory', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    records = []
    for file in sorted(args.input_directory.glob('*.json')):
        record = json.loads(file.read_text())
        if not isinstance(record, dict):
            continue
        candidate = extract(record)
        candidate['sourceDigest'] = hashlib.sha256(file.read_bytes()).hexdigest()
        records.append(candidate)
    args.output.write_text(json.dumps({'reviewRequired': True, 'records': records}, indent=2) + '\n')
    args.output.chmod(0o600)
    print(f'Examined {len(records)} records; {sum(len(r["completeFileSamples"]) for r in records)} paired driving-file samples. Review candidates only.')


if __name__ == '__main__':
    main()
