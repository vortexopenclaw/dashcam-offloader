import Foundation

extension FeedbackScanSnapshot {
    mutating func finishPrivateEvidence(inventoriedMedia: Int, inventoriedVideos: Int, measuredVideos: Int) {
        func updateCounts() {
            let pairs = videoSpecSummaries.flatMap { $0.storageRateSamples ?? [] }
            let identities = Set(mediaFileSamples.compactMap(\.sourceIdentifier) + pairs.compactMap(\.sourceIdentifier)).count
            evidenceCounts = FeedbackEvidenceCounts(inventoriedMedia: inventoriedMedia, inventoriedVideos: inventoriedVideos,
                measuredVideos: measuredVideos, retainedIdentities: identities, omittedIdentities: max(0, inventoriedMedia - identities),
                retainedMeasurements: pairs.count, omittedMeasurements: max(0, inventoriedVideos - pairs.count))
        }
        updateCounts()
        // Leave headroom under the receiver's unchanged 1 MiB request cap for the form.
        while (try? JSONEncoder().encode(self).count) ?? Int.max > 180_000 {
            if !directorySummaries.isEmpty { directorySummaries.removeLast() }
            else if !folderSummaries.isEmpty { folderSummaries.removeLast() }
            else if !mediaFileSamples.isEmpty { mediaFileSamples.removeLast() }
            else if !videoSpecSummaries.isEmpty { videoSpecSummaries.removeLast() }
            else { break }
            updateCounts()
        }
    }

    /// Separate anonymous export. Never reuse the private learning envelope publicly.
    func forPublicExport() -> Self {
        var result = self
        result.volumeName = ""
        result.requestedSourceName = nil
        result.effectiveSourceName = nil
        result.effectiveSourceRelativePath = nil
        result.sampleRelativePaths = []
        result.folderSamples = []
        result.filenamePatternSummaries = []
        result.filenameSequenceSummaries = []
        result.supportFileSamples = []
        result.ignoredSupportFileSamples = []
        result.clipGroupSummaries = []
        result.videoSpecSamples = videoSpecSamples.map { sample in
            var anonymous = sample
            anonymous.relativePath = ""
            return anonymous
        }
        result.identifiedCamera?.evidence = []
        result.candidates = candidates.map { candidate in
            var anonymous = candidate
            anonymous.evidence = []
            return anonymous
        }
        result.scanDiagnostics = []
        result.componentMetadata = nil
        result.componentMetadataCoverage = nil
        result.filenameSamples = []
        result.mediaFileSamples = []
        result.directorySummaries = []
        result.folderSummaries = []
        result.rootFolders = []
        result.videoSpecSummaries = videoSpecSummaries.map { summary in
            var anonymous = summary.forSubmission()
            anonymous.folder = "."
            anonymous.storageRateSamples = summary.storageRateSamples?.map { sample in
                var pair = sample
                pair.sourceIdentifier = nil; pair.filename = nil; pair.folder = nil
                return pair
            }
            return anonymous
        }
        return result
    }
}
