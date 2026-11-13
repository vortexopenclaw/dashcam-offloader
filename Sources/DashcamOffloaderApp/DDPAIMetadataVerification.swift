import Foundation

/// Developer-only source/snapshot verification. Never discovers or opens owner cards.
enum DDPAIMetadataVerification {
    @MainActor static func run(root: URL, output: URL, profiles: [DashcamProfile]) throws -> Bool {
        let fm = FileManager.default
        let card = root.appendingPathComponent("ddpai-synthetic", isDirectory: true).resolvingSymlinksInPath()
        let enumerator = fm.enumerator(at: root.appendingPathComponent("small"), includingPropertiesForKeys: nil)!
        guard let video = enumerator.compactMap({ $0 as? URL }).first(where: { $0.pathExtension.lowercased() == "mp4" }) else { return false }
        let front = card.appendingPathComponent("DCIM/200video/front/20300101120000_0060.mp4")
        let inside = card.appendingPathComponent("DCIM/200video/inside/20300101120000_0060_B.mp4")
        let log = card.appendingPathComponent("DCIM/207log/ui/ui_20300101120000_000.log")
        for item in [front, inside, log] { try fm.createDirectory(at: item.deletingLastPathComponent(), withIntermediateDirectories: true) }
        try fm.copyItem(at: video, to: front); try fm.copyItem(at: video, to: inside)
        let fixture = root.appendingPathComponent("ddpai-device-info.fixture.json")
        let fixtureData = try Data(contentsOf: fixture)
        var object = try JSONSerialization.jsonObject(with: fixtureData) as! [String: Any]
        object["wifi_pwd"] = "synthetic-secret-canary"; object["sn_code"] = "synthetic-serial-canary"
        func encode(_ o: [String: Any]) throws -> String { String(decoding: try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]), as: UTF8.self) }
        func write(_ text: String) throws { try text.write(to: log, atomically: false, encoding: .utf8) }
        try write("INFO {device.cpp:12} response " + encode(object) + " completed\n")
        let labels = Set(DDPAIOfficialModels.rows.flatMap { [$0.model] + $0.aliases })
        let resolutions: [[String: Any]] = labels.sorted().flatMap { label in
            [label, label.lowercased(), label.lowercased().hasPrefix("ddpai ") ? label : "DDPAI " + label].map { input in
                ["input": input, "model": DDPAIOfficialModels.recognized(input) as Any? ?? NSNull()]
            }
        }
        try JSONSerialization.data(withJSONObject: resolutions, options: [.sortedKeys]).write(to: output.appendingPathComponent("ddpai-model-matches.json"), options: .withoutOverwriting)
        let scanner = CardScanner()
        let scan = try scanner.scanWithOSD(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
        guard scan.identifiedCamera?.model == "Z100 Master", scan.selectedProfile?.id == "ddpai-z100-master-main",
              scan.componentMetadata.entries.count == 3, !scan.componentMetadata.coverage.limited,
              scan.componentMetadata.entries[0].firmwareVersion == "8.0.0.16",
              scan.componentMetadata.entries.dropFirst().allSatisfy({ !$0.identityEstablished && $0.reportedModel == nil && $0.model == nil && $0.firmwareVersion == "v9.0.0.0" }),
              Set(scan.clips.filter(\.isVideo).map(\.channel)) == ["front", "telephoto"],
              scan.diagnostics.contains(where: { $0.stage == "ddpai_ui_device_info" && $0.outcome == "matched" }) else {
            print("DDPAI METADATA FAIL: normal log scan, role mapping or historical components"); return false
        }
        let model = TransferViewModel(); model.profiles = profiles
        model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic"), scanResult: scan)
        guard model.inferredLearningChannelSetup.count == 2, let snapshot = model.makeFeedbackScanSnapshot(),
              snapshot.componentMetadata?.count == 3, snapshot.componentMetadataCoverage?.retainedEntries == 3 else { return false }
        let submission = FeedbackSubmission(kind: .bug, message: "Synthetic DDPAI regression", contact: "", appVersion: "synthetic-test", createdAt: "2030-01-01T00:00:00Z", training: nil, scan: snapshot)
        let privateData = try JSONEncoder().encode(submission)
        guard !String(decoding: privateData, as: UTF8.self).contains("canary") else { return false }
        try privateData.write(to: output.appendingPathComponent("ddpai-private.json"), options: .withoutOverwriting)
        let anonymous = snapshot.forPublicExport()
        guard anonymous.componentMetadata == nil, anonymous.componentMetadataCoverage == nil else { return false }
        try JSONEncoder().encode(anonymous).write(to: output.appendingPathComponent("ddpai-public.json"), options: .withoutOverwriting)
        model.selectProfile(.genericNewDashcam)
        guard model.selectedProfile?.id == DashcamProfile.genericNewDashcam.id,
              model.clips.allSatisfy({ $0.channel != "telephoto" }) else { return false }

        // A sibling or unknown reported identity cannot activate the main-unit exception.
        for name in ["DDPAI Z100 Pro", "DDPAI DZ9999_GLOBAL_Z100 Master", "DDPAI Z100 Master Pro"] {
            var sibling = object; sibling["model"] = name
            try write(encode(sibling) + "\n")
            let result = try scanner.scanWithOSD(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
            guard result.selectedProfile?.id != "ddpai-z100-master-main", result.clips.allSatisfy({ $0.channel != "telephoto" }) else { return false }
        }
        var sibling = object; sibling["model"] = "DDPAI Z100 Pro"
        try write(encode(object) + "\n" + encode(sibling) + "\n")
        let mixed = DDPAIComponentMetadata.read(source: card)
        guard mixed.entries.count == 6, mixed.exactLoggingModel == nil else { return false }
        try write("{\"msgHdr\":{},\"model\":\"DDPAI Z100 Master\",\"model\":\"DDPAI Z100 Pro\",\"soft_version\":\"8.0.0.16\"}\n")
        let duplicate = DDPAIComponentMetadata.read(source: card)
        guard duplicate.coverage.limited, duplicate.exactLoggingModel == nil else { return false }
        try write("INFO {source.cpp:8} unrelated text\n" + encode(object) + "\n")
        guard DDPAIComponentMetadata.read(source: card).exactLoggingModel == "Z100 Master" else { return false }

        try write("[" + encode(object) + "]\n")
        let arrayRoot = DDPAIComponentMetadata.read(source: card)
        guard arrayRoot.entries.isEmpty, arrayRoot.exactLoggingModel == nil else { return false }
        // Real logger framing shape, with wholly synthetic dates, source names
        // and secrets. Two SGR sequences surround the logger level, not JSON.
        var ansiObject = object
        ansiObject["soft_version"] = "8.0.0.23"
        for component in ["rear", "inside"] {
            ansiObject[component + "_model"] = "DDPAI DR4004"
            ansiObject[component + "_version"] = "v9.0.0.17"
        }
        let ansiJSON = try encode(ansiObject)
        let framing = "[01-01 12:00:00:000 \u{1B}[1;32mI\u{1B}[m-device]:1[device.cpp]:response:"
        try write(framing + ansiJSON + "\n" + framing + ansiJSON + "\n")
        let ansi = DDPAIComponentMetadata.read(source: card)
        guard !ansi.coverage.limited, ansi.coverage.retainedEntries == 6,
              ansi.exactLoggingModel == "Z100 Master",
              ansi.entries.filter({ $0.component == "logging_device" }).allSatisfy({ $0.firmwareVersion == "8.0.0.23" }),
              ansi.entries.filter({ $0.component != "logging_device" }).allSatisfy({
                  $0.reportedModel == "DDPAI DR4004" && $0.model == nil && !$0.identityEstablished && $0.firmwareVersion == "v9.0.0.17"
              }), !String(decoding: try JSONEncoder().encode(ansi.entries), as: UTF8.self).contains("canary") else { return false }
        let ansiScan = try scanner.scanWithOSD(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
        guard ansiScan.selectedProfile?.id == "ddpai-z100-master-main",
              ansiScan.diagnostics.contains(where: { $0.stage == "ddpai_ui_device_info" && $0.outcome == "matched" }),
              ansiScan.componentMetadata.entries == ansi.entries else { return false }
        model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic"), scanResult: ansiScan)
        guard let ansiSnapshot = model.makeFeedbackScanSnapshot(),
              ansiSnapshot.componentMetadata?.count == 6,
              ansiSnapshot.componentMetadataCoverage?.limited == false,
              !String(decoding: try JSONEncoder().encode(ansiSnapshot), as: UTF8.self).contains("canary"),
              ansiSnapshot.forPublicExport().componentMetadata == nil else { return false }
        // Decoration is not a license to salvage arrays, nested objects,
        // duplicate keys, non-SGR escapes, or literal controls inside JSON.
        for invalid in [
            framing + "[" + ansiJSON + "]",
            framing + "{\"wrapped\":" + ansiJSON + "}",
            framing + ansiJSON.replacingOccurrences(of: "\"msgHdr\":", with: "\"model\":\"DDPAI Z100 Pro\",\"msgHdr\":"),
            framing + ansiJSON.replacingOccurrences(of: "DR4004", with: "DR\u{1B}[m4004"),
            framing + ansiJSON.replacingOccurrences(of: "DR4004", with: "DR\t4004"),
            "\u{1B}[2J" + framing + ansiJSON
        ] {
            try write(invalid + "\n")
            let rejected = DDPAIComponentMetadata.read(source: card)
            guard rejected.entries.isEmpty, rejected.exactLoggingModel == nil else { return false }
        }
        try write(encode(object) + "\n")
        // Directories and leaf logs must not follow links.
        let savedLog = log.appendingPathExtension("saved")
        try fm.moveItem(at: log, to: savedLog); try fm.createSymbolicLink(at: log, withDestinationURL: savedLog)
        let linked = DDPAIComponentMetadata.read(source: card)
        guard linked.entries.isEmpty, linked.coverage.limited else { return false }
        try fm.removeItem(at: log); try fm.moveItem(at: savedLog, to: log)
        // An AppleDouble sidecar with an MP4 suffix is not front footage.
        let sidecar = front.deletingLastPathComponent().appendingPathComponent("._fake.mp4")
        try fm.moveItem(at: front, to: sidecar)
        guard !DDPAIComponentMetadata.hasSafeMainFrontVideo(source: card, files: [sidecar]) else { return false }
        try fm.moveItem(at: sidecar, to: front)
        print("DDPAI METADATA NATIVE PASS: structured scan -> exact main identity -> UI -> frozen private snapshot; source/privacy/sibling/conflict/duplicate/sidecar guards")
        return true
    }
}
