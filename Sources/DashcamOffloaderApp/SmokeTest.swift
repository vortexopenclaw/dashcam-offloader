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
            guard profiles.contains(where: { $0.id == "vueroid-s1-4k-infinite" }) else {
                print("SMOKE FAIL: missing Vueroid S1 4K Infinite profile")
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
            try FileManager.default.createDirectory(at: source.appendingPathComponent("Config", isDirectory: true), withIntermediateDirectories: true)
            try Data("resolution=4k".utf8).write(to: source.appendingPathComponent("Config/settings.ini"))

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
            let emptyScan = try scanner.scan(sourceURL: emptySource, profiles: profiles)
            guard emptyScan.selectedProfile == nil, emptyScan.candidates.isEmpty else {
                print("SMOKE FAIL: empty source selected a profile")
                return false
            }

            let scan = try scanner.scanWithOSD(sourceURL: source, profiles: profiles)
            guard scan.candidates.first?.profile.id == "vantrue-e1-pro" else {
                print("SMOKE FAIL: E1 Pro was not top candidate")
                return false
            }
            guard scan.candidates.first?.confidence == .high else {
                print("SMOKE FAIL: E1 Pro did not score high confidence")
                return false
            }
            guard scan.diagnostics.contains(where: { $0.stage == "osd_ocr_gate" && $0.outcome == "skipped_no_ocr_competition" }) else {
                print("SMOKE FAIL: OSD gate diagnostic missing")
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
                filters: filters,
                namingOptions: OutputNamingOptions(videoFilenameSuffix: "Opp traffic up Maltby cloudy")
            )

            guard plan.items.count == 2, plan.selectedBytes == 3072 else {
                print("SMOKE FAIL: unexpected plan \(plan.items.count) files \(plan.selectedBytes) bytes")
                return false
            }
            guard plan.items.contains(where: { $0.destinationURL.lastPathComponent == "20260101_120000_00001_N_A Opp traffic up Maltby cloudy.MP4" }) else {
                print("SMOKE FAIL: video filename suffix was not inserted before the extension")
                return false
            }
            guard !plan.items.contains(where: { $0.destinationURL.lastPathComponent.hasSuffix(".MP4 Opp traffic up Maltby cloudy") }) else {
                print("SMOKE FAIL: video filename suffix changed the extension")
                return false
            }
            guard plan.supportItems.isEmpty else {
                print("SMOKE FAIL: settings files were included by default")
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

            filters.includeCameraSettings = true
            let settingsPlan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: filters
            )
            guard settingsPlan.supportItems.contains(where: { $0.relativePath == "Config/settings.ini" }) else {
                print("SMOKE FAIL: Config settings file was not planned")
                return false
            }
            guard settingsPlan.supportItems.first?.destinationURL.path.contains("/Camera Settings/") == true else {
                print("SMOKE FAIL: settings file destination folder missing")
                return false
            }

            let vueroidSource = temp.appendingPathComponent("vueroid-s1", isDirectory: true)
            try FileManager.default.createDirectory(at: vueroidSource.appendingPathComponent("INF", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidSource.appendingPathComponent("PARK", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidSource.appendingPathComponent("PEVENT", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 3, count: 1024).write(to: vueroidSource.appendingPathComponent("INF/20260101_120000_INF_F_N.mp4"))
            try Data(repeating: 4, count: 1024).write(to: vueroidSource.appendingPathComponent("PARK/20260101_121000_PRK_F_N.mp4"))
            try Data(repeating: 5, count: 1024).write(to: vueroidSource.appendingPathComponent("PEVENT/20260101_122000_PVT_F_N.mp4"))
            try Data("boot ok".utf8).write(to: vueroidSource.appendingPathComponent(".boot.log"))

            let vueroidScan = try scanner.scan(sourceURL: vueroidSource, profiles: profiles)
            guard vueroidScan.candidates.first?.profile.id == "vueroid-s1-4k-infinite" else {
                print("SMOKE FAIL: Vueroid S1 was not top candidate")
                return false
            }

            let modes = Set(vueroidScan.clips.map(\.mode))
            guard modes.contains("parking"), modes.contains("parking_event") else {
                print("SMOKE FAIL: Vueroid parking modes not split: \(modes.sorted())")
                return false
            }
            guard vueroidScan.clips.contains(where: { $0.mode == "parking_event" && $0.outputCategory == "Parking Events" }) else {
                print("SMOKE FAIL: Vueroid parking event category missing")
                return false
            }
            guard vueroidScan.clips.contains(where: { $0.mode == "continuous" && $0.outputCategory == "Driving" }) else {
                print("SMOKE FAIL: Vueroid continuous category missing")
                return false
            }
            let vueroidCategoryCounts = Dictionary(
                grouping: vueroidScan.clips.filter { $0.excludedReason == nil },
                by: \.outputCategory
            )
            .mapValues(\.count)
            guard vueroidCategoryCounts["Driving"] == 1,
                  vueroidCategoryCounts["Parking"] == 1,
                  vueroidCategoryCounts["Parking Events"] == 1,
                  vueroidCategoryCounts["Other", default: 0] == 0 else {
                print("SMOKE FAIL: Vueroid output groups wrong: \(vueroidCategoryCounts)")
                return false
            }
            var vueroidFilters = FilterState()
            vueroidFilters.selectedModes = Set(vueroidScan.clips.map(\.mode))
            vueroidFilters.selectedChannels = Set(vueroidScan.clips.map(\.channel))
            vueroidFilters.includeCameraSettings = true
            if let vueroidProfile = vueroidScan.selectedProfile {
                let vueroidPlan = CopyPlanner().makePlan(
                    sourceRoot: vueroidSource,
                    destinationRoot: destination,
                    profile: vueroidProfile,
                    clips: vueroidScan.clips,
                    filters: vueroidFilters
                )
                guard vueroidPlan.supportItems.contains(where: { $0.relativePath == ".boot.log" }) else {
                    print("SMOKE FAIL: Vueroid boot log was not planned")
                    return false
                }
            }

            let progress = CopyProgress(
                totalBytes: 4_000_000,
                copiedBytes: 2_000_000,
                totalFiles: 4,
                completedFiles: 2,
                currentFile: "sample.mp4",
                isRunning: true,
                startedAt: Date(timeIntervalSinceNow: -2),
                updatedAt: Date()
            )
            guard progress.speedText.hasSuffix("MB/s"), progress.estimatedRemainingText.hasPrefix("ETA ") else {
                print("SMOKE FAIL: progress speed or ETA unavailable")
                return false
            }

            let blackVueSupportedSource = temp.appendingPathComponent("blackvue-elite-8", isDirectory: true)
            try FileManager.default.createDirectory(at: blackVueSupportedSource.appendingPathComponent("BlackVue/Record", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: blackVueSupportedSource.appendingPathComponent("BlackVue/Config", isDirectory: true), withIntermediateDirectories: true)
            try Data("model = ELITE 8".utf8).write(to: blackVueSupportedSource.appendingPathComponent("BlackVue/Config/version.bin"))
            try Data(repeating: 10, count: 1024).write(to: blackVueSupportedSource.appendingPathComponent("BlackVue/Record/20260608_120000_NF.mp4"))
            let blackVueSupportedScan = try scanner.scanWithOSD(sourceURL: blackVueSupportedSource, profiles: profiles)
            guard blackVueSupportedScan.identifiedCamera?.displayName == "BlackVue Elite 8",
                  blackVueSupportedScan.selectedProfile?.id == "blackvue-elite-8" else {
                print("SMOKE FAIL: BlackVue supported metadata did not select Elite 8")
                return false
            }

            let blackVueUnsupportedSource = temp.appendingPathComponent("blackvue-unsupported", isDirectory: true)
            try FileManager.default.createDirectory(at: blackVueUnsupportedSource.appendingPathComponent("BlackVue/Record", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: blackVueUnsupportedSource.appendingPathComponent("BlackVue/Config", isDirectory: true), withIntermediateDirectories: true)
            try Data("model = Future BlackVue".utf8).write(to: blackVueUnsupportedSource.appendingPathComponent("BlackVue/Config/version.bin"))
            try Data(repeating: 11, count: 1024).write(to: blackVueUnsupportedSource.appendingPathComponent("BlackVue/Record/20260608_121000_NF.mp4"))
            let blackVueUnsupportedScan = try scanner.scanWithOSD(sourceURL: blackVueUnsupportedSource, profiles: profiles)
            guard blackVueUnsupportedScan.identifiedCamera?.displayName == "BlackVue Future BlackVue",
                  blackVueUnsupportedScan.identifiedCamera?.isSupported == false,
                  blackVueUnsupportedScan.selectedProfile == nil else {
                print("SMOKE FAIL: unsupported BlackVue metadata should not select nearby profile")
                return false
            }

            let thinkwareSupportedSource = temp.appendingPathComponent("thinkware-u3000-pro", isDirectory: true)
            try FileManager.default.createDirectory(at: thinkwareSupportedSource.appendingPathComponent("SETTING/lang", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareSupportedSource.appendingPathComponent("cont_rec", isDirectory: true), withIntermediateDirectories: true)
            try Data("Device Name:U3000PRO".utf8).write(to: thinkwareSupportedSource.appendingPathComponent("SETTING/lang/ver.dat"))
            try Data(repeating: 12, count: 1024).write(to: thinkwareSupportedSource.appendingPathComponent("cont_rec/REC_20260608_122000_F.MP4"))
            let thinkwareSupportedScan = try scanner.scanWithOSD(sourceURL: thinkwareSupportedSource, profiles: profiles)
            guard thinkwareSupportedScan.identifiedCamera?.displayName == "Thinkware U3000 Pro",
                  thinkwareSupportedScan.selectedProfile?.id == "thinkware-u3000-pro" else {
                print("SMOKE FAIL: Thinkware supported metadata did not select U3000 Pro")
                return false
            }

            let thinkwareUnsupportedSource = temp.appendingPathComponent("thinkware-unsupported", isDirectory: true)
            try FileManager.default.createDirectory(at: thinkwareUnsupportedSource.appendingPathComponent("SETTING/lang", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareUnsupportedSource.appendingPathComponent("cont_rec", isDirectory: true), withIntermediateDirectories: true)
            try Data("Device Name:U4000".utf8).write(to: thinkwareUnsupportedSource.appendingPathComponent("SETTING/lang/ver.dat"))
            try Data(repeating: 13, count: 1024).write(to: thinkwareUnsupportedSource.appendingPathComponent("cont_rec/REC_20260608_123000_F.MP4"))
            let thinkwareUnsupportedScan = try scanner.scanWithOSD(sourceURL: thinkwareUnsupportedSource, profiles: profiles)
            guard thinkwareUnsupportedScan.identifiedCamera?.displayName == "Thinkware U4000",
                  thinkwareUnsupportedScan.identifiedCamera?.isSupported == false,
                  thinkwareUnsupportedScan.selectedProfile == nil else {
                print("SMOKE FAIL: unsupported Thinkware metadata should not select nearby profile")
                return false
            }

            print("SMOKE PASS: \(scan.candidates.first?.profile.displayName ?? "unknown") \(plan.items.count) files; Vueroid parking split OK; generic unsupported guard OK")
            return true
        } catch {
            print("SMOKE FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
