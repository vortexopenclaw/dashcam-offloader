import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('rates', Path(__file__).with_name('scan-storage-rates.py'))
rates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rates)


class StorageRateTests(unittest.TestCase):
    def test_complete_file_size_wins_over_video_bitrate_and_parking_is_excluded(self):
        pair = dict(fileSizeBytes=120000000,durationSeconds=30,estimatedBitrate=16000000)
        record = dict(payload=dict(training=dict(manufacturer='Example',model='Camera'),scan=dict(
            videoSpecSamples=[dict(pair,mode='driving',channel='front',relativePath='private'),
                              dict(pair,mode='parking',channel='rear')],
            videoSpecSummaries=[])))
        result = rates.extract(record)
        self.assertEqual(len(result['completeFileSamples']),1)
        self.assertEqual(result['completeFileSamples'][0]['storageBytesPerSecond'],4000000)
        self.assertNotIn('relativePath',result['completeFileSamples'][0])

    def test_unpaired_summary_extrema_are_not_storage_rates(self):
        result = rates.extract(dict(scan=dict(videoSpecSummaries=[dict(mode='driving',
            minFileSizeBytes=1,maxFileSizeBytes=100000000,sampleDurationMin=1,
            sampleDurationMax=60,sampleBitrateMin=16000000)])))
        self.assertEqual(result['completeFileSamples'],[])
        self.assertEqual(result['videoOnlyGroups'],1)

    def test_new_summary_keeps_pairs_and_rejects_invalid_or_parking(self):
        pair=dict(fileSizeBytes=120000000,durationSeconds=30)
        group=dict(mode='continuous',channel='front',storageRateSamples=[pair,dict(pair,durationSeconds=60),dict(pair,durationSeconds=0)])
        result=rates.extract(dict(scan=dict(videoSpecSummaries=[group,dict(group,outputCategory='parking')])) )
        self.assertEqual([s['storageBytesPerSecond'] for s in result['completeFileSamples']],[4000000,2000000])
        self.assertIsNone(rates.measurement(dict(pair,durationSeconds=float('nan'))))


if __name__ == '__main__': unittest.main()
