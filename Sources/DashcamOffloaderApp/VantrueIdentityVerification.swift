import Foundation

/// Synthetic fixtures only. Parent verification runner supplies loaded profiles.
enum VantrueIdentityVerification {
    static func run(profiles: [DashcamProfile]) -> Bool {
        struct Failure: LocalizedError { let errorDescription: String? }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("vantrue-identity-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        do {
            func require(_ condition: Bool, _ message: String) throws {
                if !condition { throw Failure(errorDescription: message) }
            }
            let scanner = CardScanner()
            let siblings = profiles.filter { ["vantrue-e1-pro", "vantrue-e1-pro-s"].contains($0.id) }
            try require(siblings.count == 2, "Both distinct trained E1 profiles must load")
            try require(siblings.first { $0.id == "vantrue-e1-pro" }?.model == "E1 Pro", "Preserve canonical E1 Pro spacing")
            try require(siblings.first { $0.id == "vantrue-e1-pro-s" }?.model == "E1 Pro S", "Preserve canonical E1 Pro S spacing")
            try require(siblings.first { $0.id == "vantrue-e1-pro-s" }?.folders.first { $0.path == "GPS" }?.importable == false,
                        "E1 Pro S GPS support folder must parse as non-importable")
            let mediaPaths = [
                "Normal/20300101_120000_00001_N_A.MP4",
                "Parking/20300101_120100_00002_P_A.MP4",
                "Parking/20300101_120200_00003_E_A.MP4",
                "Parking/20300101_120300_00004_T_A.MP4",
                "Event/20300101_120400_00005_E_A.MP4",
                "Photo/20300101_120500_00006_P_A.JPG"
            ]
            func fixture(_ label: String, markers: [String]) throws -> URL {
                let card = root.appendingPathComponent(label, isDirectory: true)
                for folder in ["Normal", "Parking", "Event", "Photo", "GPS"] {
                    try fm.createDirectory(at: card.appendingPathComponent(folder), withIntermediateDirectories: true)
                }
                for path in mediaPaths {
                    try Data(repeating: 0, count: 64).write(to: card.appendingPathComponent(path))
                }
                for marker in markers {
                    // Deliberately invalid private-looking content: identity must use only basename.
                    try Data("DO_NOT_READ_SETTINGS_VALUES=synthetic-private-sentinel".utf8)
                        .write(to: card.appendingPathComponent("GPS/\(marker)"))
                }
                return card
            }
            for (label, marker, id, model) in [
                ("s-marker", "E1PROS_Settings.ini", "vantrue-e1-pro-s", "E1 Pro S"),
                ("pro-marker", "E1PRO_Settings.ini", "vantrue-e1-pro", "E1 Pro"),
                ("lowercase-s", "e1pros_settings.ini", "vantrue-e1-pro-s", "E1 Pro S")
            ] {
                let card = try fixture(label, markers: [marker])
                let info = scanner.safeVantrueModelMetadataInfo(sourceURL: card)
                try require(info?.modelText == model && info?.firmwareVersion == nil, "Exact marker identity failed: \(marker)")
                try require(info?.diagnosticSummary.contains("synthetic-private-sentinel") == false, "Settings values leaked")
                let scan = try scanner.scan(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
                try require(scan.selectedProfile?.id == id && scan.identifiedCamera?.model == model, "Marker selected wrong profile: \(marker)")
                let clips = Dictionary(uniqueKeysWithValues: scan.clips.map { ($0.relativePath, $0) })
                try require(clips.count == mediaPaths.count && clips.values.allSatisfy { $0.channel == "front" }, "Lost media/front channel classification")
                try require(clips[mediaPaths[0]]?.outputCategory == "Driving" && clips[mediaPaths[0]]?.isParkingFootage == false, "N front driving classification")
                try require(clips[mediaPaths[1]]?.outputCategory == "Parking" && clips[mediaPaths[1]]?.isParkingFootage == true, "P parking classification")
                try require(clips[mediaPaths[2]]?.mode == "event" && clips[mediaPaths[2]]?.isParkingFootage == true, "Parking E token must retain event label and parking context")
                try require(clips[mediaPaths[3]]?.mode == "timelapse" && clips[mediaPaths[3]]?.outputCategory == "Parking", "T timelapse classification")
                try require(clips[mediaPaths[4]]?.mode == "event" && clips[mediaPaths[4]]?.isParkingFootage == false, "Event-folder E must not imply parking")
                try require(clips[mediaPaths[5]]?.outputCategory == "Photos", "Photo classification")
            }
            for (label, markers) in [
                ("unknown-suffix", ["E1PROSX_Settings.ini"]),
                ("unknown-pro-suffix", ["E1PROX_Settings.ini"]),
                ("other-pro-suffix", ["N4PROSX_Settings.ini"]),
                ("trailing-extension", ["E1PROS_Settings.ini.bak"]),
                ("trailing-newline", ["E1PROS_Settings.ini\n"]),
                ("conflict-pro-first", ["E1PRO_Settings.ini", "E1PROS_Settings.ini"]),
                ("conflict-s-first", ["E1PROS_Settings.ini", "E1PRO_Settings.ini"]),
                ("known-plus-unknown", ["E1PRO_Settings.ini", "E1PROSX_Settings.ini"]),
                ("bare-family", [])
            ] {
                let card = try fixture(label, markers: markers)
                try require(scanner.safeVantrueModelMetadataInfo(sourceURL: card) == nil, "Unsafe marker accepted: \(label)")
                for candidates in [siblings, profiles] {
                    let scan = try scanner.scan(sourceURL: card, profiles: candidates, allowNestedCardRootDiscovery: false)
                    try require(scan.selectedProfile?.id == DashcamProfile.genericNewDashcam.id && scan.identifiedCamera == nil, "Shared/unsafe evidence selected exact model: \(label)")
                }
            }
            // Require explicit evidence even if only one sibling profile is installed.
            for label in ["E1 Pro", "E1 Pro S"] {
                let card = try fixture(label, markers: ["E1PRO_Settings.ini", "E1PROS_Settings.ini"])
                let scan = try scanner.scan(sourceURL: card, profiles: siblings, allowNestedCardRootDiscovery: false)
                try require(scan.selectedProfile?.id == DashcamProfile.genericNewDashcam.id && scan.identifiedCamera == nil,
                            "Volume-label hint bypassed conflicting markers: \(label)")
            }
            let bare = try fixture("bare-single-profile", markers: [])
            for profile in siblings {
                let scan = try scanner.scan(sourceURL: bare, profiles: [profile], allowNestedCardRootDiscovery: false)
                try require(scan.selectedProfile?.id == DashcamProfile.genericNewDashcam.id, "Bare layout selected lone \(profile.id)")
            }
            let directoryMarker = try fixture("directory-marker", markers: [])
            try fm.createDirectory(at: directoryMarker.appendingPathComponent("GPS/E1PROS_Settings.ini"), withIntermediateDirectories: true)
            let symlinkMarker = try fixture("symlink-marker", markers: [])
            try fm.createSymbolicLink(at: symlinkMarker.appendingPathComponent("GPS/E1PROS_Settings.ini"), withDestinationURL: directoryMarker.appendingPathComponent(mediaPaths[0]))
            for card in [directoryMarker, symlinkMarker] {
                try require(scanner.safeVantrueModelMetadataInfo(sourceURL: card) == nil, "Nonregular settings marker accepted")
                let scan = try scanner.scan(sourceURL: card, profiles: siblings, allowNestedCardRootDiscovery: false)
                try require(scan.selectedProfile?.id == DashcamProfile.genericNewDashcam.id, "Path-exists rule bypassed regular-file guard")
            }
            let symlinkGPS = try fixture("symlink-gps-folder", markers: [])
            try fm.removeItem(at: symlinkGPS.appendingPathComponent("GPS"))
            let validCard = try fixture("symlink-target-card", markers: ["E1PROS_Settings.ini"])
            try fm.createSymbolicLink(at: symlinkGPS.appendingPathComponent("GPS"), withDestinationURL: validCard.appendingPathComponent("GPS"))
            try require(scanner.safeVantrueModelMetadataInfo(sourceURL: symlinkGPS) == nil, "Symlink GPS directory accepted")
            // Whole-token lookup applies to other Vantrue Pro variants too.
            let n4 = try fixture("n4-pro", markers: ["N4PRO_Settings.ini"])
            try require(scanner.safeVantrueModelMetadataInfo(sourceURL: n4)?.modelText == "N4 Pro", "Exact N4 Pro support marker regressed")
            print("VANTRUE IDENTITY VERIFY PASS: exact sibling markers, case policy, unknown suffixes, conflicts, regular files, family-only fallback, front channels and mode/context labels")
            return true
        } catch {
            print("VANTRUE IDENTITY VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
