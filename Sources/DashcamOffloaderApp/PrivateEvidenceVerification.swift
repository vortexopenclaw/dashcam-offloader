import Foundation

enum PrivateEvidenceVerification {
    @MainActor static func run(arguments: [String]) -> Bool {
        guard let index = arguments.firstIndex(of: "--verify-private-evidence"), arguments.count > index + 2 else { return false }
        let root = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let output = URL(fileURLWithPath: arguments[index + 2], isDirectory: true)
        do {
            // Developer-created fixture marker; never discover/read an owner's mounted card.
            guard try String(contentsOf: root.appendingPathComponent("synthetic-fixture.txt"), encoding: .utf8) == "synthetic private evidence fixture\n" else { return false }
            let cases = try JSONDecoder().decode([String: [String]].self, from:
                Data(contentsOf: root.appendingPathComponent("media-basename-cases.json")))
            guard let rejected = cases["rejected"], let accepted = cases["accepted"] else { return false }
            for unsafe in rejected {
                guard !CardLearningStructure.safeMediaBasename(unsafe) else { print("Unexpected accepted basename: \(unsafe.debugDescription)"); return false }
            }
            for name in accepted {
                guard CardLearningStructure.safeMediaBasename(name) else { print("Unexpected rejected basename: \(name.debugDescription)"); return false }
            }
            print("PRIVATE BASENAME SAFETY PASS")
            guard let profilesDirectory = ProfileStore.defaultProfilesDirectory() else { return false }
            let profiles = try ProfileStore(profilesDirectory: profilesDirectory).loadProfiles()
            guard try DDPAIMetadataVerification.run(root: root, output: output, profiles: profiles) else { return false }
            let generic = try GenericDiscoveryVerification.run(root: root)
            let genericCard = root.appendingPathComponent("generic-discovery")
            let genericScan = try CardScanner().scan(sourceURL: genericCard, profiles: profiles, allowNestedCardRootDiscovery: false)
            guard genericScan.discovery == generic, genericScan.identifiedCamera == nil else { return false }
            let genericModel = TransferViewModel()
            genericModel.loadScanResultForVerification(source: MountedSource(url: genericCard, name: "Synthetic unknown"), scanResult: genericScan)
            guard let genericSnapshot = genericModel.makeFeedbackScanSnapshot(), genericSnapshot.discovery == generic,
                  genericSnapshot.forPublicExport().discovery == nil else { return false }
            let disclosure = PrivateEvidenceReview.discoveryDisclosure(generic).joined(separator: "\n")
            guard disclosure.contains("NovaCam QX7"), disclosure.contains("framed_json"),
                  disclosure.contains("Multiple model declarations"), disclosure.contains("no model recognition inferred") else { return false }
            let genericSubmission = FeedbackSubmission(kind: .bug, message: "Synthetic generic discovery regression", contact: "", appVersion: "synthetic-test", createdAt: "2030-01-01T00:00:00Z", training: nil, scan: genericSnapshot)
            let genericBytes = try JSONEncoder().encode(genericSubmission)
            let genericText = String(decoding: genericBytes, as: UTF8.self)
            guard !genericText.contains("CANARY"), !genericText.contains("private_parent"), !genericText.contains("settings.weird"),
                  genericSnapshot.settingSnapshots.allSatisfy({ $0.keys.allSatisfy { GenericCardDiscovery.field($0) == "setting" } }) else { return false }
            try genericBytes.write(to: output.appendingPathComponent("generic-private.json"), options: .withoutOverwriting)
            try JSONEncoder().encode(genericSnapshot.forPublicExport()).write(to: output.appendingPathComponent("generic-public.json"), options: .withoutOverwriting)
            let coverageCard = root.appendingPathComponent("generic-coverage")
            try FileManager.default.createDirectory(at: coverageCard, withIntermediateDirectories: true)
            try Data("<synthetic/>".utf8).write(to: coverageCard.appendingPathComponent("unknown"))
            let coverageScan = try CardScanner().scan(sourceURL: coverageCard, profiles: profiles, allowNestedCardRootDiscovery: false)
            genericModel.loadScanResultForVerification(source: MountedSource(url: coverageCard, name: "Synthetic coverage"), scanResult: coverageScan)
            guard let coverageSnapshot = genericModel.makeFeedbackScanSnapshot(),
                  coverageSnapshot.discovery?.observations.isEmpty == true,
                  coverageSnapshot.discovery?.coverage.reasons["unsupported_format"] == 1 else { return false }
            let coverageDisclosure = PrivateEvidenceReview.discoveryDisclosure(coverageSnapshot.discovery!).joined(separator: "\n")
            guard coverageDisclosure.contains("0 declarations retained"), coverageDisclosure.contains("unsupported_format: 1"),
                  coverageDisclosure.contains("xml"), coverageDisclosure.contains("Coverage limited") else { return false }
            let coverageSubmission = FeedbackSubmission(kind: .bug, message: "Synthetic coverage-only discovery", contact: "", appVersion: "synthetic-test", createdAt: "2030-01-01T00:00:00Z", training: nil, scan: coverageSnapshot)
            try JSONEncoder().encode(coverageSubmission).write(to: output.appendingPathComponent("generic-coverage-private.json"), options: .withoutOverwriting)
            var paths = CardLearningPaths()
            guard paths.folder("Family Trip/inside/200video") == "folder-1/inside/200video",
                  paths.folder("Family Trip/201photo") == "folder-1/201photo",
                  paths.folder("Other Trip/200video") == "folder-2/200video",
                  paths.folder("../DCIM") == nil, paths.folder("DCIM/inside\n") == nil else { return false }
            for (label, expectedCount) in [("small", 4), ("large", 140), ("structural", 1)] {
                let card = root.appendingPathComponent(label)
                let scan = try CardScanner().scan(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
                let model = TransferViewModel()
                model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic card"), scanResult: scan)
                // This is a retention test, not a classifier change: explicit fixture views/context.
                for index in model.clips.indices {
                    model.clips[index].channel = model.clips[index].relativePath.contains("inside") ? "telephoto" : "front"
                    model.clips[index].mode = model.clips[index].relativePath.contains("inside") ? "parking" : "continuous"
                }
                guard let snapshot = model.makeFeedbackScanSnapshot(), let counts = snapshot.evidenceCounts,
                      counts.inventoriedVideos == expectedCount else { return false }
                let pairs = snapshot.videoSpecSummaries.flatMap { $0.storageRateSamples ?? [] }
                if label == "structural" {
                    guard pairs.isEmpty, counts.measuredVideos == 0, counts.omittedMeasurements == 1 else { return false }
                } else {
                    guard pairs.count == (label == "small" ? 4 : 64),
                          pairs.allSatisfy({ $0.sourceIdentifier != nil && $0.filename != nil && $0.folder != nil }),
                          counts.retainedMeasurements == pairs.count,
                          counts.omittedMeasurements == expectedCount - pairs.count else { return false }
                }
                if label == "small" {
                    guard counts.inventoriedMedia == 5, counts.retainedIdentities == 5,
                          snapshot.mediaFileSamples.contains(where: { $0.filename == "照片2030.jpg" && $0.folder == "DCIM/201photo" && $0.sourceIdentifier != nil }) else { return false }
                    let duplicate = pairs.filter { $0.filename == "N_20300102123456_0001.MP4" }
                    guard duplicate.count == 2, Set(duplicate.compactMap(\.sourceIdentifier)).count == 2,
                          Set(duplicate.compactMap(\.folder)) == ["DCIM/200video", "DCIM/inside/200video"] else { return false }
                }
                if label == "small", let index = model.clips.firstIndex(where: { $0.isVideo }) {
                    model.clips[index].excludedReason = "Synthetic exclusion"
                    let excluded = model.makeFeedbackScanSnapshot()
                    guard excluded?.evidenceCounts?.inventoriedVideos == 4,
                          excluded?.evidenceCounts?.retainedMeasurements == 3,
                          excluded?.evidenceCounts?.omittedMeasurements == 1 else { return false }
                    model.clips[index].excludedReason = nil
                }
                let data = try JSONEncoder().encode(snapshot)
                guard data.count <= 180_000, !String(decoding: data, as: UTF8.self).contains(card.path),
                      try JSONDecoder().decode(FeedbackScanSnapshot.self, from: data) == snapshot else { return false }
                // Exact reviewed evidence; these rejection tests cannot reach the network.
                model.submitFeedback(kind: .bug, message: "Synthetic", contact: "", includeScan: true)
                guard !model.isSubmittingFeedback, model.feedbackMessage.contains("incomplete") else { return false }
                model.submitFeedback(kind: .bug, message: "Synthetic", contact: "", includeScan: true,
                                     scanSnapshot: snapshot, scanRevisionAtPreview: model.scanRevision - 1)
                guard !model.isSubmittingFeedback else { return false }
                let submission = FeedbackSubmission(kind: .bug, message: "Synthetic private evidence regression", contact: "",
                    appVersion: "synthetic-test", createdAt: "2030-01-01T00:00:00Z", training: nil, scan: snapshot)
                try JSONEncoder().encode(submission).write(to: output.appendingPathComponent("\(label).json"), options: .withoutOverwriting)
                var overBudget = snapshot
                if let summary = snapshot.videoSpecSummaries.first, label == "small" {
                    overBudget.videoSpecSummaries = Array(repeating: summary, count: 120)
                    overBudget.videoSpecSummaries = overBudget.videoSpecSummaries.map { item in
                        var large = item
                        large.sampleCodecs = [String(repeating: "x", count: 2000)]
                        return large
                    }
                    overBudget.finishPrivateEvidence(inventoriedMedia: 1000, inventoriedVideos: 1000, measuredVideos: 1000)
                    guard try JSONEncoder().encode(overBudget).count <= 180_000,
                          overBudget.evidenceCounts!.omittedMeasurements > 0,
                          overBudget.evidenceCounts!.retainedMeasurements == overBudget.videoSpecSummaries.flatMap({ $0.storageRateSamples ?? [] }).count else { return false }
                }
                let publicSnapshot = snapshot.forPublicExport()
                let publicData = try JSONEncoder().encode(publicSnapshot)
                guard !String(decoding: publicData, as: UTF8.self).contains("source-"),
                      !String(decoding: publicData, as: UTF8.self).contains("20300102"),
                      publicSnapshot.videoSpecSummaries.flatMap({ $0.storageRateSamples ?? [] }).count == pairs.count else { return false }
                try publicData.write(to: output.appendingPathComponent("\(label)-public.json"), options: .withoutOverwriting)
                print("PRIVATE EVIDENCE NATIVE PASS: \(label) inventoried=\(expectedCount) measured=\(counts.measuredVideos) pairs=\(pairs.count) identities=\(counts.retainedIdentities) bytes=\(data.count)")
            }
            return true
        } catch { print("PRIVATE EVIDENCE NATIVE FAIL: \(error)"); return false }
    }
}
