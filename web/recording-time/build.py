"""Export reviewed driving rows only; no archive access or video uploads."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def extract(reference, catalog, manufacturer=None):
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
        cameras.append(dict(id=slug, name=policy.get('displayName', name), channels=channels,
                            allocationRequired=policy.get('allocationRequired', False),
                            sourceAnchor=slug, setups=make_setups(name, channels, manufacturer)))
    if not cameras:
        raise ValueError('No measured presets')
    return dict(schemaVersion=2, sourceSha256=hashlib.sha256(reference.encode()).hexdigest(),
                sourceUrl='https://github.com/vortexopenclaw/dashcam-offloader/blob/main/docs/video-metadata-reference.md',
                cameras=cameras)


def make_setups(name, channels, manufacturer):
    official = (manufacturer or {}).get('cameras', {}).get(name)
    if official:
        setups = []
        for setup in official['setups']:
            roles, times = setup['roles'], setup['hours']
            if len(times) != 5 or any(not isinstance(t, (int, float)) or t <= 0 for t in times):
                raise ValueError('Invalid manufacturer recording times')
            if len(set(roles)) != len(roles) or not set(roles) <= {c['role'] for c in channels}:
                raise ValueError('Invalid manufacturer channel set')
            setups.append(dict(id='-'.join(roles), roles=roles, hours=times,
                               sourceUrl=manufacturer['sourceUrl'], basis='VIOFO chart · Normal recording quality'))
        return setups
    available = {c['role']: c for c in channels}
    roles = [r for r in ['front', 'rear', 'interior', 'telephoto'] if r in available]
    groups = [roles]
    if len(roles) > 1:
        groups = [['front']] + [['front', r] for r in roles[1:]]
        if len(roles) > 2:
            groups.append(roles)
    return [dict(id='-'.join(group), roles=group,
                 minMbps=sum(available[r]['minMbps'] for r in group),
                 maxMbps=sum(available[r]['maxMbps'] for r in group),
                 basis='Offloader measured bitrates' if group == roles else 'Estimated from measured channel bitrates')
            for group in groups]


def build():
    reference = (ROOT / 'docs/video-metadata-reference.md').read_text()
    data = extract(reference, json.loads((HERE / 'catalog.json').read_text()),
                   json.loads((HERE / 'manufacturer-times.json').read_text()))
    out = HERE / 'dist'
    out.mkdir(exist_ok=True)
    for name in ['index.html', 'calculator.mjs', 'widget.mjs', 'style.css', 'embed.js', 'demo.html']:
        shutil.copyfile(HERE / name, out / name)
    (out / 'cameras.json').write_text(json.dumps(data, indent=2) + '\n')
    with zipfile.ZipFile(out / 'vortex-recording-time.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(HERE / 'wordpress/vortex-recording-time.php', 'vortex-recording-time/vortex-recording-time.php')
        for name in ['index.html', 'calculator.mjs', 'widget.mjs', 'style.css', 'embed.js', 'cameras.json']:
            archive.write(out / name, 'vortex-recording-time/calculator/' + name)
    print(f'Built {len(data["cameras"])} measured presets in {out.relative_to(ROOT)}')


if __name__ == '__main__':
    build()
