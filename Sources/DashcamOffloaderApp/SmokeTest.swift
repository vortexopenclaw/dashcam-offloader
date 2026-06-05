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

            let scan = try CardScanner().scan(sourceURL: source, profiles: profiles)
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

            print("SMOKE PASS: \(scan.candidates.first?.profile.displayName ?? "unknown") \(plan.items.count) files")
            return true
        } catch {
            print("SMOKE FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
