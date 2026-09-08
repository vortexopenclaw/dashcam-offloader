import json
from pathlib import Path
import unittest
from build import extract, HERE, ROOT


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.reference = (ROOT / 'docs/video-metadata-reference.md').read_text()
        self.catalog = json.loads((HERE / 'catalog.json').read_text())

    def test_real_measurements_exclude_parking_and_incomplete_cameras(self):
        data = extract(self.reference, self.catalog)
        camera = next(c for c in data['cameras'] if c['name'] == 'VIOFO A229 Pro')
        self.assertEqual([c['minMbps'] for c in camera['channels']], [36, 15.6, 24])
        self.assertNotIn('BlackVue Elite 8', [c['name'] for c in data['cameras']])
        self.assertNotIn('/Volumes/', json.dumps(data))

    def test_missing_or_assumed_channels_fail_build(self):
        for reference in [self.reference.replace('| I (interior) | driving | H.264 | 1920x1080 | 30 | ~15.6 Mbps', '| I (interior) | parking | H.264 | 1920x1080 | 30 | ~15.6 Mbps'), self.reference.replace('`ffprobe`', '`assumed`')]:
            with self.assertRaises(ValueError):
                extract(reference, self.catalog)

    def test_measurement_update_flows_through_without_copying_bitrates(self):
        updated = self.reference.replace('~65.5 Mbps', '~66.5 Mbps')
        data = extract(updated, self.catalog)
        camera = next(c for c in data['cameras'] if c['name'] == 'VIOFO A329T')
        self.assertEqual(camera['channels'][0]['maxMbps'], 66.5)

    def test_new_reviewed_camera_exports_automatically(self):
        reference = self.reference + '\n## Test Camera\n| F (front) | driving | HEVC | 1920x1080 | 30 | ~10 Mbps | MP4 | `ffprobe` |\n'
        data = extract(reference, {**self.catalog, 'Test Camera':{'channels':['front']}})
        self.assertEqual(len(data['cameras']), len(self.catalog) + 1)

    def test_official_channel_sets_use_official_times(self):
        manufacturer = json.loads((HERE / 'manufacturer-times.json').read_text())
        data = extract(self.reference, self.catalog, manufacturer)
        camera = next(c for c in data['cameras'] if c['name'] == 'VIOFO A229 Pro')
        self.assertEqual([len(s['roles']) for s in camera['setups']], [1, 2, 3])
        self.assertEqual(camera['setups'][1]['hours'], [1.5, 2.5, 5.5, 10.5, 21])

    def test_channel_subsets_add_only_selected_streams(self):
        data = extract(self.reference, self.catalog)
        camera = next(c for c in data['cameras'] if c['name'] == 'Vantrue N4 Pro S')
        setup = next(s for s in camera['setups'] if s['id'] == 'front-rear')
        self.assertAlmostEqual(setup['maxMbps'], 46.2)
        self.assertIn('Estimated', setup['basis'])


if __name__ == '__main__':
    unittest.main()
