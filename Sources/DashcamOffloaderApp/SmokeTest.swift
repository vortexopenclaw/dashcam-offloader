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
                "dji-rc",
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

            guard UpdateService.compareVersions("0.2.0", "0.1.9") == .orderedDescending else {
                print("SMOKE FAIL: update version comparison failed")
                return false
            }
            let manifestJSON = Data("""
            {
              "version": "0.2.0",
              "releaseName": "Dashcam Offloader 0.2.0",
              "releaseNotesURL": "https://github.com/vortexopenclaw/dashcam-offloader/releases/tag/latest",
              "assetName": "Dashcam-Offloader-0.2.0.zip",
              "downloadURL": "https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/download/latest",
              "sha256": "abc123",
              "minimumMacOSVersion": "14.0",
              "channel": "latest"
            }
            """.utf8)
            let updateInfo = try UpdateService.info(from: manifestJSON, currentVersion: "0.1.0")
            guard updateInfo.isNewer, updateInfo.assetName == "Dashcam-Offloader-0.2.0.zip" else {
                print("SMOKE FAIL: update manifest parsing failed")
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

            let blackVueSupportedSource = temp.appendingPathComponent("blackvue-elite-8", isDirectory: true)
            try FileManager.default.createDirectory(at: blackVueSupportedSource.appendingPathComponent("BlackVue/Record", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: blackVueSupportedSource.appendingPathComponent("BlackVue/Config", isDirectory: true), withIntermediateDirectories: true)
            try Data("model = ELITE 8".utf8).write(to: blackVueSupportedSource.appendingPathComponent("BlackVue/Config/version.bin"))
            try Data("ap_ssid=BlackVueElite8-test".utf8).write(to: blackVueSupportedSource.appendingPathComponent("BlackVue/Config/config.ini"))
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

            print("SMOKE PASS: \(scan.candidates.first?.profile.displayName ?? "unknown") \(plan.items.count) files; Vueroid parking split OK; U3000 filters OK; BlackVue unsupported guard OK")
            return true
        } catch {
            print("SMOKE FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
