import Foundation

/// Deterministic synthetic inventory, never owner footage or bitrate evidence.
enum ObservedChannelVerification {
    static func run(profiles: [DashcamProfile]) -> Bool {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("observed-channels-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        do {
            guard let profile = profiles.first(where: { $0.id == "viofo-a329t" }),
                  profile.maxChannels == 3,
                  profile.osdSpec?.matchStrings == ["VIOFO A329T"] else { return false }
            let cases: [(String, [String], Int, String)] = [
                ("front", ["F", "PF"], 1, "Front"),
                ("rear", ["R", "PR"], 1, "Rear"),
                ("dual", ["F", "R", "PF"], 2, "Front / Rear"),
                ("triple", ["F", "R", "T", "PT"], 3, "Front / Rear / Telephoto"),
                ("empty", [], 0, "")
            ]
            for (label, suffixes, count, description) in cases {
                let card = root.appendingPathComponent(label)
                try fm.createDirectory(at: card.appendingPathComponent("DCIM/Movie"), withIntermediateDirectories: true)
                try fm.createDirectory(at: card.appendingPathComponent("DCIM/Photo"), withIntermediateDirectories: true)
                for suffix in suffixes {
                    try Data([0]).write(to: card.appendingPathComponent("DCIM/Movie/2030_0101_120000_000001\(suffix).MP4"))
                }
                // Non-video roles must never add recording channels.
                try Data([0]).write(to: card.appendingPathComponent("DCIM/Photo/2030_0101_120000_000001T.JPG"))
                let scan = try CardScanner().scan(sourceURL: card, profiles: [profile], allowNestedCardRootDiscovery: false)
                let valid = MainActor.assumeIsolated { () -> Bool in
                    let model = TransferViewModel()
                    model.profiles = profiles
                    model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic card"), scanResult: scan)
                    // Simulate the owner's exact model selection. Front filenames alone do not establish identity.
                    model.selectedProfile = .genericNewDashcam
                    model.identifiedCamera = IdentifiedCamera(manufacturer: "VIOFO", model: "A329T", evidence: ["Synthetic owner label"], isSupported: false)
                    let inferred = model.inferredLearningChannelSetup
                    guard inferred.count == count, inferred.description == description else {
                        print("OBSERVED CHANNEL VERIFY FAIL: \(label) expected \(count) / \(description), got \(inferred)")
                        return false
                    }
                    model.selectedProfile = profile
                    guard model.inferredLearningChannelSetup.count == count else { return false }
                    var selection = LearningChannelSelection()
                    selection.prefill(inferred.count)
                    let setup = selection.reportSetup(description: "", placeholder: inferred.description)
                    guard setup == (count == 0 ? "Unknown" : "\(count)CH: \(description)") else { return false }
                    let training = CardTrainingDetails(manufacturer: "VIOFO", model: "A329T", channelSetup: setup, notes: "Synthetic fixture only")
                    guard let snapshot = model.makeFeedbackScanSnapshot(),
                          snapshot.videoSpecSummaries.allSatisfy({ $0.sampleBitrateMin == nil }),
                          let encoded = try? JSONEncoder().encode(training),
                          let decoded = try? JSONDecoder().decode(CardTrainingDetails.self, from: encoded),
                          decoded.model == "A329T", decoded.channelSetup == setup else { return false }
                    // Reappearance/rescan must preserve explicit owner choices, even Unknown.
                    selection.choose(2)
                    selection.prefill(1)
                    guard selection.count == 2,
                          selection.reportSetup(description: "Owner setup", placeholder: "Front") == "2CH: Owner setup" else { return false }
                    selection.choose(0)
                    selection.prefill(3)
                    guard selection.count == 0 else { return false }
                    // Unknown IDs and primary/multiplex streams do not establish a physical setup.
                    for role in ["unknown", "channel_a", "channel_b", "primary", "360_primary", "multiplexed"] {
                        model.clips = [ClipItem(sourceURL: card.appendingPathComponent("synthetic.MP4"), relativePath: "synthetic.MP4", filename: "synthetic.MP4", mode: "continuous", channel: role, timestamp: nil, size: 1, extensionLowercased: "mp4", excludedReason: nil)]
                        guard model.inferredLearningChannelSetup.count == 0 else { return false }
                    }
                    for roles in [["front", "interior"], ["front", "rear", "interior"]] {
                        model.clips = roles.enumerated().map { index, role in ClipItem(sourceURL: card.appendingPathComponent("synthetic\(index).MP4"), relativePath: "synthetic\(index).MP4", filename: "synthetic\(index).MP4", mode: "continuous", channel: role, timestamp: nil, size: 1, extensionLowercased: "mp4", excludedReason: nil) }
                        guard model.inferredLearningChannelSetup.count == roles.count else { return false }
                        model.isScanning = true
                        guard model.inferredLearningChannelSetup.count == 0 else { return false }
                        model.isScanning = false
                    }
                    return true
                }
                if !valid { return false }
            }
            if let receiptPath = ProcessInfo.processInfo.environment["DASHCAM_PRIVATE_CHANNEL_RECEIPT"] {
                let data = try Data(contentsOf: URL(fileURLWithPath: receiptPath))
                guard let receipts = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let record = receipts.first?["record"] as? [String: Any],
                      let scan = record["scan"] as? [String: Any],
                      let identity = scan["identifiedCamera"] as? [String: Any],
                      let manufacturer = identity["manufacturer"] as? String,
                      let cameraModel = identity["model"] as? String,
                      let summaries = scan["videoSpecSummaries"] as? [[String: Any]] else { return false }
                // Aggregate replay only. Never read receipt paths, notes, names, or settings.
                let valid = MainActor.assumeIsolated { () -> Bool in
                    let model = TransferViewModel()
                    model.selectedProfile = .genericNewDashcam
                    model.identifiedCamera = IdentifiedCamera(manufacturer: manufacturer, model: cameraModel, evidence: [], isSupported: false)
                    model.clips = summaries.enumerated().flatMap { bucket, summary -> [ClipItem] in
                        guard let channel = summary["channel"] as? String, let count = summary["fileCount"] as? Int, (0...100_000).contains(count) else { return [] }
                        return (0..<count).map { index in
                            let name = "synthetic-\(bucket)-\(index).MP4"
                            return ClipItem(sourceURL: root.appendingPathComponent(name), relativePath: name, filename: name, mode: "continuous", channel: channel, timestamp: nil, size: 1, extensionLowercased: "mp4", excludedReason: nil)
                        }
                    }
                    let inferred = model.inferredLearningChannelSetup
                    guard inferred.count == 1, inferred.description == "Front" else { return false }
                    var selection = LearningChannelSelection()
                    selection.prefill(inferred.count)
                    return selection.reportSetup(description: "", placeholder: inferred.description) == "1CH: Front"
                }
                guard valid else { return false }
                print("PRIVATE RECEIPT REPLAY PASS: aggregate video roles -> observed 1CH -> learning-sheet report label; no source-video validation")
            }
            if let fixtureRoot = ProcessInfo.processInfo.environment["DASHCAM_SYNTHETIC_VIDEO_FIXTURES"] {
                for (label, expectedID) in [("a329t", "viofo-a329t"), ("a329s", "viofo-a329s"), ("unmarked", DashcamProfile.genericNewDashcam.id), ("a329tc", DashcamProfile.genericNewDashcam.id), ("a329tw", DashcamProfile.genericNewDashcam.id)] {
                    let card = URL(fileURLWithPath: fixtureRoot).appendingPathComponent(label)
                    let scan = try CardScanner().scanWithOSD(sourceURL: card, profiles: profiles)
                    guard scan.selectedProfile?.id == expectedID else {
                        print("OBSERVED VIDEO VERIFY FAIL: synthetic \(label) selected \(scan.selectedProfile?.id ?? "nil")")
                        return false
                    }
                    let valid = MainActor.assumeIsolated { () -> Bool in
                        let model = TransferViewModel()
                        model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic video"), scanResult: scan)
                        guard model.inferredLearningChannelSetup.count == 1,
                              let snapshot = model.makeFeedbackScanSnapshot(),
                              snapshot.videoSpecSummaries.reduce(0, { $0 + $1.fileCount }) == 2 else { return false }
                        let codecs = Set(snapshot.videoSpecSummaries.flatMap(\.sampleCodecs))
                        guard codecs == ["H.264", "H.265 / HEVC"],
                              snapshot.videoSpecSummaries.allSatisfy({ $0.sampleBitrateMin != nil }),
                              let encoded = try? JSONEncoder().encode(snapshot),
                              let decoded = try? JSONDecoder().decode(FeedbackScanSnapshot.self, from: encoded),
                              Set(decoded.videoSpecSummaries.flatMap(\.sampleCodecs)) == codecs else { return false }
                        if label == "a329t" {
                            guard scan.identifiedCamera?.model == "A329T", scan.identifiedCamera?.isSupported == true else { return false }
                        }
                        if label == "a329tc" || label == "a329tw" {
                            guard scan.identifiedCamera?.model != "A329T" else { return false }
                        }
                        return true
                    }
                    guard valid else { print("OBSERVED VIDEO VERIFY FAIL: codec/report \(label)"); return false }
                }
                let multiplexCard = URL(fileURLWithPath: fixtureRoot).appendingPathComponent("multitrack")
                let multiplexScan = try CardScanner().scan(sourceURL: multiplexCard, profiles: profiles)
                let multiplexSafe = MainActor.assumeIsolated { () -> Bool in
                    let model = TransferViewModel()
                    model.loadScanResultForVerification(source: MountedSource(url: multiplexCard, name: "Synthetic multitrack"), scanResult: multiplexScan)
                    _ = model.makeFeedbackScanSnapshot() // Same metadata-before-prefill order as the sheet.
                    return model.inferredLearningChannelSetup.count == 0
                }
                guard multiplexSafe else { print("OBSERVED VIDEO VERIFY FAIL: multitrack must remain Unknown"); return false }
                print("OBSERVED VIDEO VERIFY PASS: native A329T OCR, A329S sibling, unmarked ambiguity, 1CH, and H264+HEVC report round-trip")
            }
            print("OBSERVED CHANNEL VERIFY PASS: synthetic scanner -> UI inference -> feedback snapshot")
            return true
        } catch {
            print("OBSERVED CHANNEL VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
