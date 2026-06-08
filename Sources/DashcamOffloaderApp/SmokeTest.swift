import Foundation

enum SmokeTest {
    static func run() -> Bool {
        do {
            guard let profilesURL = ProfileStore.defaultProfilesDirectory() else {
                print("SMOKE FAIL: profiles directory not found")
                return false
            }

            let profiles = try ProfileStore(profilesDirectory: profilesURL).loadProfiles()
            guard profiles.contains(where: { $0.id == "vantrue-e1-pro" }) else {
                print("SMOKE FAIL: missing Vantrue E1 Pro profile")
                return false
            }
            let requiredDisplayNames = [
                "70mai M310",
                "Cansonic UltraDash Z3+ Standard Edition",
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

            let thinkwareSource = temp.appendingPathComponent("thinkware-u3000-pro", isDirectory: true)
            try FileManager.default.createDirectory(at: thinkwareSource.appendingPathComponent("SETTING", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareSource.appendingPathComponent("cont_rec", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareSource.appendingPathComponent(".TWSYS/PIV", isDirectory: true), withIntermediateDirectories: true)
            try Data("settings".utf8).write(to: thinkwareSource.appendingPathComponent("SETTING/U3000PRO_Setting.exe"))
            try Data(repeating: 6, count: 2048).write(to: thinkwareSource.appendingPathComponent("cont_rec/REC_20260528_175357_F.MP4"))
            try Data(repeating: 7, count: 1024).write(to: thinkwareSource.appendingPathComponent("cont_rec/REC_20260528_175357_R.MP4"))
            try Data(repeating: 8, count: 512).write(to: thinkwareSource.appendingPathComponent(".TWSYS/PIV/PLOC_1_1.JPG"))
            try Data(repeating: 9, count: 512).write(to: thinkwareSource.appendingPathComponent(".TWSYS/PIV/PLOC_2_1.JPG"))

            let thinkwareScan = try scanner.scan(sourceURL: thinkwareSource, profiles: profiles)
            guard thinkwareScan.candidates.first?.profile.id == "thinkware-u3000-pro" else {
                print("SMOKE FAIL: Thinkware U3000 Pro was not top candidate")
                return false
            }
            guard Set(thinkwareScan.clips.map(\.channel)) == ["front", "rear"] else {
                print("SMOKE FAIL: Thinkware channels not mapped to front/rear: \(Set(thinkwareScan.clips.map(\.channel)).sorted())")
                return false
            }
            guard Set(thinkwareScan.clips.map(\.displayChannel)) == ["Front", "Rear"] else {
                print("SMOKE FAIL: Thinkware channel labels wrong: \(Set(thinkwareScan.clips.map(\.displayChannel)).sorted())")
                return false
            }
            guard Set(thinkwareScan.clips.map(\.displayMode)) == ["Driving"] else {
                print("SMOKE FAIL: Thinkware recording type should display as Driving: \(Set(thinkwareScan.clips.map(\.displayMode)).sorted())")
                return false
            }
            guard !thinkwareScan.clips.contains(where: { $0.relativePath.hasPrefix(".TWSYS/") }) else {
                print("SMOKE FAIL: Thinkware hidden .TWSYS internals were scanned")
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
