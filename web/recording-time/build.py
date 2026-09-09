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
            if len(row) != 8 or not any(mode in row[1].split(' / ') for mode in policy.get('recordingModes', ['driving'])):
                continue
            role = re.fullmatch(r'[A-Z] \((front|rear|interior|telephoto|interior_front|interior_rear|panoramic_front)\)', row[0])
            mapped_role = policy.get('rowRoles', {}).get(row[0]) or (role[1] if role else None)
            rate = re.fullmatch(r'~?(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))? Mbps', row[5])
            if not mapped_role or not rate or row[7] != '`ffprobe`':
                raise ValueError(f'Unusable driving measurement: {name}: {row}')
            low = float(rate[1])
            high = float(rate[2] or rate[1])
            if not 0 < low <= high < 1000:
                raise ValueError(f'Invalid bitrate: {name}')
            previous = next((c for c in channels if c['role'] == mapped_role), None)
            if previous:
                if not policy.get('mergeRepeatedSamples', False):
                    raise ValueError('Duplicate channel requires reviewed sample merging')
                if (previous['resolution'], previous['fps']) != (row[3], row[4]):
                    raise ValueError('Different recording settings require separate modes')
                previous['minMbps'] = min(previous['minMbps'], low)
                previous['maxMbps'] = max(previous['maxMbps'], high)
            else:
                channels.append(dict(role=mapped_role, codec=row[2], resolution=row[3], fps=row[4], minMbps=low, maxMbps=high))
        if [c['role'] for c in channels] != policy['channels']:
            raise ValueError(f'Missing, duplicate, or changed channel set: {name}')
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
        cameras.append(dict(id=slug, name=policy.get('displayName', name), channels=channels,
                            allocationRequired=policy.get('allocationRequired', False),
                            sourceAnchor=slug, setups=make_setups(name, channels, manufacturer, policy.get('setups'))))
    if not cameras:
        raise ValueError('No measured presets')
    return dict(schemaVersion=3, sourceSha256=hashlib.sha256(reference.encode()).hexdigest(),
                sourceUrl='https://github.com/vortexopenclaw/dashcam-offloader/blob/main/docs/video-metadata-reference.md',
                cameras=cameras)


def make_setups(name, channels, manufacturer, reviewed_groups=None):
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
                               sourceUrl=manufacturer['sourceUrl'], basis='Manufacturer recording-time chart · Normal quality'))
        return setups
    available = {c['role']: c for c in channels}
    roles = [r for r in ['front', 'panoramic_front', 'rear', 'interior', 'interior_front', 'interior_rear', 'telephoto'] if r in available]
    groups = [roles]
    if len(roles) > 1:
        groups = [[roles[0]]] + [[roles[0], r] for r in roles[1:]]
        if len(roles) > 2:
            groups.append(roles)
    if reviewed_groups:
        groups = reviewed_groups
    return [dict(id='-'.join(group), roles=group,
                 minMbps=sum(available[r]['minMbps'] for r in group),
                 maxMbps=sum(available[r]['maxMbps'] for r in group),
                 basis='Measured from original dashcam recording files' if group == roles else 'Estimated by adding measured recording rates for the selected cameras')
            for group in groups]


def add_recording_modes(data, extras):
    data['cameras'].extend(extras.get('additionalCameras', []))
    excluded = set(extras.get('excludedCameras', {}))
    if any(c['id'] in excluded for c in data['cameras']):
        raise ValueError('Excluded or unreleased camera cannot enter the public chart')
    for camera in data['cameras']:
        for setup in camera['setups']:
            selected = [c for c in camera['channels'] if c['role'] in setup['roles']]
            default = {k: v for k, v in setup.items() if k not in ['roles', 'id']}
            default.update(id='normal' if 'hours' in setup else 'measured',
                           label='Normal Quality' if 'hours' in setup else 'Our test footage',
                           channels=selected)
            if camera['id'] in extras.get('defaultLabels', {}):
                default['label'] = extras['defaultLabels'][camera['id']]
            setup['modes'] = [default] + extras.get('modes', {}).get(camera['id'], {}).get(setup['id'], [])
            override = extras.get('replaceModes', {}).get(camera['id'], {}).get(setup['id'])
            if override:
                setup['modes'] = override
            elif 'hours' in default:
                setup['modes'].append(dict(
                    id='measured', label='Our test footage', channels=selected,
                    minMbps=sum(c['minMbps'] for c in selected),
                    maxMbps=sum(c['maxMbps'] for c in selected),
                    basis='Estimated from the recording rates of original dashcam files.'))
            for mode in setup['modes']:
                mode['label'] = mode['label'].replace(' · ', ', ').replace('highest listed', 'High')
                mode['basis'] = mode['basis'].replace(' · ', ', ').replace('; ', '. ')
                if set(c['role'] for c in mode['channels']) != set(setup['roles']):
                    raise ValueError('Mode resolution details do not match channel setup')
                if 'hours' in mode:
                    times = mode['hours']
                    if len(times) != 5 or any(t <= 0 for t in times) or any(b < a for a,b in zip(times,times[1:])):
                        raise ValueError('Invalid mode recording times')
                elif not 0 < mode['minMbps'] <= mode['maxMbps'] < 1000:
                    raise ValueError('Invalid mode storage rate')
            if len({m['id'] for m in setup['modes']}) != len(setup['modes']):
                raise ValueError('Duplicate recording setting')
        camera['links'] = extras.get('links', {}).get(camera['id'], {})
        camera['note'] = extras.get('notes', {}).get(camera['id'], '')
        primary_photo = extras.get('images', {}).get(camera['id'])
        camera['setupImages'] = ([primary_photo] if primary_photo else []) + extras.get('setupImages', {}).get(camera['id'], [])
        used_setups = set()
        for photo in camera['setupImages']:
            photo_path = Path(photo['path'])
            if photo_path.parts[0] != 'images' or len(photo_path.parts) != 2 or not (HERE / photo_path).is_file():
                raise ValueError('Image must be a packaged local asset')
            for setup_id in photo.get('setups', []):
                if setup_id not in {s['id'] for s in camera['setups']} or setup_id in used_setups:
                    raise ValueError('Invalid or duplicate image setup mapping')
                used_setups.add(setup_id)
        camera['brand'], camera['model'] = camera['name'].split(' ', 1)
        if camera['name'].startswith('Street Guardian '):
            camera['brand'], camera['model'] = 'Street Guardian', camera['name'][16:]
        camera['model'] = re.sub(r'-[1234]CH(?=$| )', '', camera['model'])
    data['cardLinks'] = extras.get('cardLinks', [])
    data['cameras'].sort(key=lambda c: [int(part) if part.isdigit() else part.lower() for part in re.split(r'(\d+)', c['name'])])
    return data


def build():
    reference = (ROOT / 'docs/video-metadata-reference.md').read_text()
    data = extract(reference, json.loads((HERE / 'catalog.json').read_text()),
                   json.loads((HERE / 'manufacturer-times.json').read_text()))
    data = add_recording_modes(data, json.loads((HERE / 'recording-modes.json').read_text()))
    out = HERE / 'dist'
    out.mkdir(exist_ok=True)
    for name in ['index.html', 'calculator.mjs', 'widget.mjs', 'style.css', 'embed.js', 'demo.html']:
        shutil.copyfile(HERE / name, out / name)
    if (HERE / 'images').exists():
        shutil.copytree(HERE / 'images', out / 'images', dirs_exist_ok=True)
    (out / 'cameras.json').write_text(json.dumps(data, indent=2) + '\n')
    with zipfile.ZipFile(out / 'vortex-recording-time.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(HERE / 'wordpress/vortex-recording-time.php', 'vortex-recording-time/vortex-recording-time.php')
        for name in ['index.html', 'calculator.mjs', 'widget.mjs', 'style.css', 'embed.js', 'cameras.json']:
            archive.write(out / name, 'vortex-recording-time/calculator/' + name)
        for image in sorted((out / 'images').glob('*')):
            archive.write(image, 'vortex-recording-time/calculator/images/' + image.name)
    print(f'Built {len(data["cameras"])} camera presets in {out.relative_to(ROOT)}')


if __name__ == '__main__':
    build()
