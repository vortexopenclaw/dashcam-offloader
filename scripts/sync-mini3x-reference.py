#!/usr/bin/env python3
"""Refresh MINI3X evidence/reference only from clean committed inputs."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
canonical, native = map(Path, sys.argv[1:3])
def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()
for path in (canonical, native):
    assert not git(path, 'status', '--porcelain'), 'Dirty source input'
canonical_commit = git(canonical, 'rev-parse', 'HEAD')
native_commit = git(native, 'rev-parse', 'HEAD')
assert canonical_commit == '32137d9edc95902a63aac82b287f3793b0d6e486'
assert native_commit == '6673d592bb41f775e0c4aae6ae55f140bf67b265'
files = ['docs/data/ddpai-model-reference.json', 'docs/data/ddpai-mini3x-evidence.json']
for name in files:
    (root / name).write_bytes((canonical / name).read_bytes())
reference = json.loads((canonical / files[0]).read_text())
rows = json.dumps(reference['records'], ensure_ascii=False, separators=(',', ':'))
swift = root / 'Sources/DashcamOffloaderApp/DDPAIOfficialModels.swift'
text = swift.read_text()
prefix = text.split(' private static let reference = #"""\n')[0]
swift.write_text(prefix + ' private static let reference = #"""\n' + rows + '\n"""#\n}\n')
worker = root / 'workers/feedback/ddpai-models.js'
text = worker.read_text()
start = text.index('export const ddpaiModels = ')
end = text.index('\nexport function ddpaiCandidates')
worker.write_text(text[:start] + 'export const ddpaiModels = ' + rows + ';' + text[end:])
profile = 'profiles/ddpai-mini3x.yaml'
assert (root / profile).read_bytes() == (native / profile).read_bytes()
provenance = {'canonicalCommit': canonical_commit, 'nativeProfileCommit': native_commit,
              'sha256': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files + [profile]},
              'scope': 'Committed reference/evidence and executable profile inputs; release commit records runtime source.'}
(root / 'docs/data/mini3x-catalog-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
print('Refreshed committed MINI3X reference, evidence and provenance')
