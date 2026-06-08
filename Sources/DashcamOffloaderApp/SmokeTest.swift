import Foundation

enum SmokeTest {
    static func run() -> Bool {
        do {
            guard let profilesURL = ProfileStore.defaultProfilesDirectory() else {
                print("SMOKE FAIL: profiles directory not found")
                return false
            }

            let profiles = try ProfileStore(profilesDirectory: profilesURL).loadProfiles()
            let expectedProfileIDs = [
                "70mai-4k-omni",
                "70mai-m310",
                "blackvue-dr970x-plus",
                "blackvue-elite-8",
                "blackvue-elite-9",
                "cansonic-ultradash-z3plus-standard",
                "cobra-road-scout",
                "dji-mini-3-pro",
                "escort-m1",
                "escort-m2",
                "escort-maxcam-360c",
                "nextbase-622gw",
                "sony-a7-iii",
                "thinkware-u1000",
                "thinkware-u1000-plus",
                "thinkware-u3000",
                "thinkware-u3000-pro",
                "vantrue-e1-pro",
                "vantrue-e360",
                "vantrue-n4",
                "vantrue-n4-pro-s",
                "vantrue-n4-s",
                "vantrue-n5",
                "viofo-a119-mini-2",
                "viofo-a119m-pro",
                "viofo-a129-duo",
                "viofo-a129-plus-duo",
                "viofo-a129-pro",
                "viofo-a139-pro",
                "viofo-a229-plus",
                "viofo-a229-pro",
                "viofo-a229-ultra",
                "viofo-a329s",
                "viofo-a329t",
                "viofo-t130",
                "viofo-vs1",
                "viofo-wm1",
                "vueroid-s1-4k-infinite"
            ]
            let loadedProfileIDs = Set(profiles.map(\.id))
            guard loadedProfileIDs.count >= expectedProfileIDs.count else {
                print("SMOKE FAIL: expected at least \(expectedProfileIDs.count) profiles, loaded \(loadedProfileIDs.count)")
                return false
            }
            for profileID in expectedProfileIDs {
                guard loadedProfileIDs.contains(profileID) else {
                    print("SMOKE FAIL: missing profile \(profileID)")
                    return false
                }
            }
            let requiredDisplayNames = [
                "70mai M310",
                "BlackVue Elite 8",
                "Cansonic UltraDash Z3+ Standard Edition",
                "Escort M1",
                "Escort M2",
                "Vantrue N4 Pro S"
            ]
            for displayName in requiredDisplayNames {
                guard profiles.contains(where: { $0.displayName == displayName }) else {
                    print("SMOKE FAIL: missing display name \(displayName)")
                    return false
                }
            }

            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("dashcam-offloader-smoke-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: temp) }

            let source = temp.appendingPathComponent("source", isDirectory: true)
            let destination = temp.appendingPathComponent("destination", isDirectory: true)
            try FileManager.default.createDirectory(at: source.appendingPathComponent("GPS", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: source.appendingPathComponent("Normal", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: source.appendingPathComponent("Parking", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: source.appendingPathComponent("Photo", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            try Data("model=E1PRO".utf8).write(to: source.appendingPathComponent("GPS/E1PRO_Settings.ini"))
            try Data(repeating: 1, count: 2048).write(to: source.appendingPathComponent("Normal/20260101_120000_00001_N_A.MP4"))
            try Data(repeating: 2, count: 1024).write(to: source.appendingPathComponent("Parking/20260101_121000_00002_P_A.MP4"))

            let backupSource = temp.appendingPathComponent("Time Machine Backups", isDirectory: true)
            let emptySource = temp.appendingPathComponent("Generic Storage", isDirectory: true)
            try FileManager.default.createDirectory(at: backupSource.appendingPathComponent("Backups.backupdb", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: emptySource, withIntermediateDirectories: true)

            let scanner = CardScanner()
            guard scanner.shouldShowMountedSource(source, showAllVolumes: false) else {
                print("SMOKE FAIL: dashcam-like source was filtered")
                return false
            }
            guard !scanner.shouldShowMountedSource(backupSource, showAllVolumes: false) else {
                print("SMOKE FAIL: backup source was not filtered")
                return false
            }
            guard !scanner.shouldShowMountedSource(emptySource, showAllVolumes: false) else {
                print("SMOKE FAIL: empty storage source was not filtered")
                return false
            }
            guard scanner.shouldShowMountedSource(backupSource, showAllVolumes: true) else {
                print("SMOKE FAIL: show all did not reveal backup source")
                return false
            }

            let scan = try scanner.scan(sourceURL: source, profiles: profiles)
            guard scan.candidates.first?.profile.id == "vantrue-e1-pro" else {
                print("SMOKE FAIL: E1 Pro was not top candidate")
                return false
            }
            guard scan.candidates.first?.confidence == .high else {
                print("SMOKE FAIL: E1 Pro did not score high confidence")
                return false
            }

            var filters = FilterState()
            filters.selectedModes = Set(scan.clips.map(\.mode))
            filters.selectedChannels = Set(scan.clips.map(\.channel))

            guard let profile = scan.selectedProfile else {
                print("SMOKE FAIL: selected profile missing")
                return false
            }

            let plan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: filters
            )

            guard plan.items.count == 2, plan.selectedBytes == 3072 else {
                print("SMOKE FAIL: unexpected plan \(plan.items.count) files \(plan.selectedBytes) bytes")
                return false
            }
            guard plan.items.contains(where: { $0.destinationURL.path.contains("/Driving/") }) else {
                print("SMOKE FAIL: driving output folder missing")
                return false
            }
            guard plan.items.contains(where: { $0.destinationURL.path.contains("/Parking/") }) else {
                print("SMOKE FAIL: parking output folder missing")
                return false
            }

            print("SMOKE PASS: \(scan.candidates.first?.profile.displayName ?? "unknown") \(plan.items.count) files")
            return true
        } catch {
            print("SMOKE FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
