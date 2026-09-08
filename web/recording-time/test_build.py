import json
from pathlib import Path
import unittest
from build import extract, add_recording_modes, HERE, ROOT
from copy import deepcopy


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.reference = (ROOT / 'docs/video-metadata-reference.md').read_text()
        self.catalog = json.loads((HERE / 'catalog.json').read_text())

    def test_real_measurements_exclude_parking_and_incomplete_cameras(self):
        data = extract(self.reference, self.catalog)
        camera = next(c for c in data['cameras'] if c['name'] == 'Viofo A229 Pro')
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
        camera = next(c for c in data['cameras'] if c['name'] == 'Viofo A329T')
        self.assertEqual(camera['channels'][0]['maxMbps'], 66.5)

    def test_new_reviewed_camera_exports_automatically(self):
        reference = self.reference + '\n## Test Camera\n| F (front) | driving | HEVC | 1920x1080 | 30 | ~10 Mbps | MP4 | `ffprobe` |\n'
        data = extract(reference, {**self.catalog, 'Test Camera':{'channels':['front']}})
        self.assertEqual(len(data['cameras']), len(self.catalog) + 1)

    def test_official_channel_sets_use_official_times(self):
        manufacturer = json.loads((HERE / 'manufacturer-times.json').read_text())
        data = extract(self.reference, self.catalog, manufacturer)
        camera = next(c for c in data['cameras'] if c['name'] == 'Viofo A229 Pro')
        self.assertEqual([len(s['roles']) for s in camera['setups']], [1, 2, 3])
        self.assertEqual(camera['setups'][1]['hours'], [1.5, 2.5, 5.5, 10.5, 21])

    def test_channel_subsets_add_only_selected_streams(self):
        data = extract(self.reference, self.catalog)
        camera = next(c for c in data['cameras'] if c['name'] == 'Vantrue N4 Pro S')
        setup = next(s for s in camera['setups'] if s['id'] == 'front-rear')
        self.assertAlmostEqual(setup['maxMbps'], 46.2)
        self.assertIn('Estimated', setup['basis'])

    def test_settings_preserve_provenance_resolution_and_storage_rates(self):
        manufacturer = json.loads((HERE / 'manufacturer-times.json').read_text())
        extra = json.loads((HERE / 'recording-modes.json').read_text())
        data = add_recording_modes(extract(self.reference, self.catalog, manufacturer), extra)
        cams = {c['id']:c for c in data['cameras']}
        pro = cams['viofo-a229-pro']['setups'][2]['modes']
        self.assertEqual(pro[0]['hours'][3], 8.5)
        self.assertEqual(pro[1]['hours'][3], 7)
        mini = cams['viofo-a119-mini-2']['setups'][0]['modes']
        self.assertEqual(mini[-1]['channels'][0]['fps'], '60')
        self.assertIn('unknown', mini[-1]['basis'])
        vueroid = cams['vueroid-s1-4k-infinite']['setups'][-1]['modes'][0]
        self.assertAlmostEqual(vueroid['maxMbps'], 97.439)
        elite = cams['blackvue-elite-10']['setups'][1]['modes']
        self.assertEqual(elite[1]['maxMbps'], 90)
        self.assertNotIn('/Volumes/', json.dumps(data))
        self.assertNotIn('20230717', json.dumps(data))

    def test_mode_mismatched_channel_and_bad_time_rejected(self):
        manufacturer = json.loads((HERE / 'manufacturer-times.json').read_text())
        source = json.loads((HERE / 'recording-modes.json').read_text())
        for mutation in ['roles', 'times']:
            extra = deepcopy(source)
            mode = extra['modes']['viofo-a229-pro']['front'][0]
            if mutation == 'roles':
                mode['channels'][0]['role'] = 'rear'
            else:
                mode['hours'] = [1, 2, 4, 3, 16]
            with self.assertRaises(ValueError):
                add_recording_modes(extract(self.reference, self.catalog, manufacturer), extra)

    def test_new_catalog_sort_four_channels_and_image_assets(self):
        extra = json.loads((HERE / 'recording-modes.json').read_text())
        manufacturer = json.loads((HERE / 'manufacturer-times.json').read_text())
        data = add_recording_modes(extract(self.reference, self.catalog, manufacturer), extra)
        cams = {c['id']:c for c in data['cameras']}
        elite = [c['model'] for c in data['cameras'] if c['model'].startswith('Elite')]
        self.assertEqual(elite, ['Elite 8','Elite 9','Elite 10'])
        n5 = cams['vantrue-n5']['setups'][0]
        self.assertEqual(len(n5['roles']),4)
        self.assertEqual(n5['modes'][1]['channels'][0]['resolution'],'2592x1944')
        lte = cams['blackvue-dr970x-lte-plus']['setups'][1]['modes'][0]
        self.assertEqual(lte['maxMbps'],70)
        self.assertEqual(sum(c['maxMbps'] for c in lte['channels']),70)
        for camera in data['cameras']:
            if camera['image']:
                self.assertTrue((HERE / camera['image']['path']).is_file())
            for setup in camera['setups']:
                for mode in setup['modes']:
                    self.assertNotIn(' · ', mode['label'])
                    self.assertNotIn(';', mode['basis'])

    def test_unreleased_camera_cannot_enter_public_catalog(self):
        extra = json.loads((HERE / 'recording-modes.json').read_text())
        extra['additionalCameras'].append({'id':'vueroid-h1'})
        with self.assertRaisesRegex(ValueError, 'unreleased'):
            add_recording_modes(extract(self.reference, self.catalog), extra)

    def test_duplicate_measurement_requires_explicit_review(self):
        reference = self.reference.replace('| F (front) | driving | H.264 | 3840x2160 | 30 | ~36.0 Mbps | MP4 | `ffprobe` |',
            '| F (front) | driving | H.264 | 3840x2160 | 30 | ~36.0 Mbps | MP4 | `ffprobe` |\n| F (front) | driving | H.264 | 3840x2160 | 30 | ~36.0 Mbps | MP4 | `ffprobe` |',1)
        with self.assertRaises(ValueError):
            extract(reference,self.catalog)


if __name__ == '__main__':
    unittest.main()
