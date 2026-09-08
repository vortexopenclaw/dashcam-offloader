"""Export reviewed driving rows only; no archive access or video uploads."""
import hashlib
import json
from pathlib import Path
import re
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def extract(reference, catalog):
    sections = {}
    section = None
    for line in reference.splitlines():
        if line.startswith('## '):
            section = line[3:].strip()
            sections[section] = []
        elif section and line.startswith('|'):
            sections[section].append([cell.strip() for cell in line.strip('|').split('|')])
    cameras = []
    for name, policy in sorted(catalog.items()):
        channels = []
        for row in sections.get(name, []):
            if len(row) != 8 or 'driving' not in row[1].split(' / '):
                continue
            role = re.fullmatch(r'[A-Z] \((front|rear|interior|telephoto)\)', row[0])
            rate = re.fullmatch(r'~?(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))? Mbps', row[5])
            if not role or not rate or row[7] != '`ffprobe`':
                raise ValueError(f'Unusable driving measurement: {name}: {row}')
            low = float(rate[1])
            high = float(rate[2] or rate[1])
            if not 0 < low <= high < 1000:
                raise ValueError(f'Invalid bitrate: {name}')
            channels.append(dict(role=role[1], codec=row[2], resolution=row[3], fps=row[4], minMbps=low, maxMbps=high))
        if [c['role'] for c in channels] != policy['channels']:
            raise ValueError(f'Missing, duplicate, or changed channel set: {name}')
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
        cameras.append(dict(id=slug, name=name, channels=channels,
                            allocationRequired=policy.get('allocationRequired', False),
                            sourceAnchor=slug))
    if not cameras:
        raise ValueError('No measured presets')
    return dict(schemaVersion=1, sourceSha256=hashlib.sha256(reference.encode()).hexdigest(),
                sourceUrl='https://github.com/vortexopenclaw/dashcam-offloader/blob/main/docs/video-metadata-reference.md',
                cameras=cameras)


def build():
    reference = (ROOT / 'docs/video-metadata-reference.md').read_text()
    data = extract(reference, json.loads((HERE / 'catalog.json').read_text()))
    out = HERE / 'dist'
    out.mkdir(exist_ok=True)
    for name in ['index.html', 'calculator.mjs', 'widget.mjs', 'style.css', 'embed.js', 'demo.html']:
        shutil.copyfile(HERE / name, out / name)
    (out / 'cameras.json').write_text(json.dumps(data, indent=2) + '\n')
    print(f'Built {len(data["cameras"])} measured presets in {out.relative_to(ROOT)}')


if __name__ == '__main__':
    build()
