import Foundation

/// Synthetic names and one-byte files only; not hardware or media validation.
enum DDPAIZ100Verification {
    static func run(profiles: [DashcamProfile]) -> Bool {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ddpai-z100-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        do {
            guard let profile = profiles.first(where: { $0.id == "ddpai-z100-master-main" }),
                  profile.status == "manual_only", profile.maxChannels == 2,
                  profile.displayManufacturer == "DDPAI", profile.osdSpec == nil else { return false }
            let names = [
                "DCIM/200video/front/20300101120000.mp4",
                "DCIM/200video/front/S_20300101120100.mp4",
                "DCIM/200video/inside/20300101120000.mp4",
                "DCIM/200video/inside/S_20300101120100.mp4",
                "DCIM/201photo/inside/S_20300101120100.jpg",
                "DCIM/202thumb/front/S_20300101120100.jpg",
                "Other/inside/S_20300101120100.mp4"
            ]
            for path in names {
                let url = root.appendingPathComponent(path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data([0]).write(to: url)
            }
            try fm.createDirectory(at: root.appendingPathComponent("DCIM/200video/rear"), withIntermediateDirectories: true)
            let scanner = CardScanner()
            let scan = try scanner.scan(sourceURL: root, profiles: profiles, allowNestedCardRootDiscovery: false)
            guard scan.selectedProfile?.id == DashcamProfile.genericNewDashcam.id,
                  !scan.candidates.contains(where: { $0.profile.id == profile.id }),
                  scan.clips.allSatisfy({ $0.channel != "telephoto" && $0.inferredParkingPattern != .timelapse }),
                  scan.diagnostics.contains(where: { $0.stage == "generic_card_shape_hint" && $0.detail.contains("DDPAI numbered") }) else {
                print("DDPAI VERIFY FAIL: shared layout claimed exact identity or exceptional semantics")
                return false
            }
            // Exercise the real manual picker/reclassification path.
            let valid = MainActor.assumeIsolated { () -> Bool in
                let model = TransferViewModel()
                model.profiles = profiles
                model.loadScanResultForVerification(source: MountedSource(url: root, name: "Synthetic"), scanResult: scan)
                guard model.cameraModelsByBrand.contains(where: { $0.brand == "DDPAI" && $0.models.contains(where: { $0.profile?.id == profile.id }) }) else { return false }
                model.selectProfile(profile)
                let clips = Dictionary(uniqueKeysWithValues: model.clips.map { ($0.relativePath, $0) })
                guard clips[names[0]]?.channel == "front", clips[names[0]]?.mode == "continuous",
                      clips[names[1]]?.channel == "front", clips[names[1]]?.inferredParkingPattern == .timelapse,
                      clips[names[1]]?.outputCategory == "Parking", clips[names[1]]?.displayMode == "Parking Timelapse",
                      clips[names[2]]?.channel == "telephoto", clips[names[2]]?.mode == "continuous",
                      clips[names[3]]?.channel == "telephoto", clips[names[3]]?.inferredParkingPattern == nil,
                      clips[names[4]]?.channel == "telephoto", clips[names[4]]?.isPhoto == true,
                      clips[names[5]]?.excludedReason != nil,
                      clips[names[6]]?.channel != "telephoto", clips[names[6]]?.inferredParkingPattern == nil else {
                    print("DDPAI VERIFY FAIL: main-unit mapping / scoped parking / photos")
                    return false
                }
                // Only the two real recording views, never empty rear/photo/thumb roles.
                model.clips.removeAll { $0.relativePath == names[6] }
                guard model.inferredLearningChannelSetup.count == 2,
                      model.inferredLearningChannelSetup.description == "Front / Telephoto",
                      model.makeFeedbackScanSnapshot()?.channelCounts["telephoto"] != nil else { return false }
                model.clips.removeAll { $0.channel == "telephoto" }
                guard model.inferredLearningChannelSetup.count == 1,
                      model.inferredLearningChannelSetup.description == "Front" else { return false }
                model.selectProfile(.genericNewDashcam)
                return model.clips.allSatisfy { $0.channel != "telephoto" }
            }
            guard valid else { print("DDPAI VERIFY FAIL: UI/manual selection/observed channel suggestions"); return false }
            // A sibling profile must retain generic inside and S_ behavior.
            var sibling = profile
            sibling.id = "synthetic-ddpai-sibling"
            let siblingClips = scanner.classifyWithParkingPatterns(files: scan.allFiles, sourceURL: root, profile: sibling).clips
            guard siblingClips.allSatisfy({ $0.channel != "telephoto" && $0.inferredParkingPattern != .timelapse }) else { return false }
            // A separately recording card is not auto-bound even with a misleading model volume label.
            let accessory = root.appendingPathComponent("Z100 Master")
            try fm.createDirectory(at: accessory.appendingPathComponent("DCIM/200video/inside"), withIntermediateDirectories: true)
            try Data([0]).write(to: accessory.appendingPathComponent("DCIM/200video/inside/S_20300101120100.mp4"))
            let accessoryScan = try scanner.scan(sourceURL: accessory, profiles: profiles, allowNestedCardRootDiscovery: false)
            guard accessoryScan.selectedProfile?.id != profile.id,
                  accessoryScan.clips.allSatisfy({ $0.channel != "telephoto" && $0.inferredParkingPattern != .timelapse }) else { return false }
            print("DDPAI Z100 VERIFY PASS: manual main-unit mapping, front-only S_ parking, generic/sibling/accessory negatives, empty rear, incomplete coverage, UI suggestions and feedback")
            return true
        } catch {
            print("DDPAI VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
