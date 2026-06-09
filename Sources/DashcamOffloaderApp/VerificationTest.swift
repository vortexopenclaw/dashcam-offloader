import Foundation

enum VerificationTest {
    static func run() -> Bool {
        do {
            guard let profilesURL = ProfileStore.defaultProfilesDirectory() else {
                print("VERIFY FAIL: profiles directory not found")
                return false
            }

            let profiles = try ProfileStore(profilesDirectory: profilesURL).loadProfiles()
            guard profiles.contains(where: { $0.id == "vantrue-e1-pro" }) else {
                print("VERIFY FAIL: missing Vantrue E1 Pro profile")
                return false
            }
            guard profiles.contains(where: { $0.id == "vueroid-s1-4k-infinite" }) else {
                print("VERIFY FAIL: missing Vueroid S1 4K Infinite profile")
                return false
            }
            let requiredDisplayNames = [
                "BlackVue Elite 9",
                "70mai M310",
                "Cansonic UltraDash Z3+ Standard Edition",
                "Rove R2-4K Pro",
                "Vantrue N4 Pro S"
            ]
            for displayName in requiredDisplayNames {
                guard profiles.contains(where: { $0.displayName == displayName }) else {
                    print("VERIFY FAIL: missing display name \(displayName)")
                    return false
                }
            }

            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("dashcam-offloader-verify-\(UUID().uuidString)", isDirectory: true)
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
            let blackVueCardSource = scanner.mountedSource(
                forUserSelectedURL: URL(fileURLWithPath: "/Volumes/BLACKVUE/BlackVue/Record", isDirectory: true)
            )
            guard blackVueCardSource.url.path == "/Volumes/BLACKVUE",
                  blackVueCardSource.name == "BLACKVUE" else {
                print("VERIFY FAIL: nested volume selection did not normalize to card root: \(blackVueCardSource.url.path)")
                return false
            }
            let manualFolderSource = scanner.mountedSource(forUserSelectedURL: source)
            guard manualFolderSource.url == source.standardizedFileURL else {
                print("VERIFY FAIL: non-volume manual folder should keep exact source path")
                return false
            }
            guard scanner.shouldShowMountedSource(source, showAllVolumes: false) else {
                print("VERIFY FAIL: dashcam-like source was filtered")
                return false
            }
            guard !scanner.shouldShowMountedSource(backupSource, showAllVolumes: false) else {
                print("VERIFY FAIL: backup source was not filtered")
                return false
            }
            guard !scanner.shouldShowMountedSource(emptySource, showAllVolumes: false) else {
                print("VERIFY FAIL: empty storage source was not filtered")
                return false
            }
            guard scanner.shouldShowMountedSource(backupSource, showAllVolumes: true) else {
                print("VERIFY FAIL: show all did not reveal backup source")
                return false
            }
            let emptyScan = try scanner.scan(sourceURL: emptySource, profiles: profiles)
            guard emptyScan.selectedProfile == nil, emptyScan.candidates.isEmpty else {
                print("VERIFY FAIL: empty source selected a profile")
                return false
            }

            let unknownSource = temp.appendingPathComponent("unsupported-card", isDirectory: true)
            try FileManager.default.createDirectory(at: unknownSource.appendingPathComponent("Driving", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: unknownSource.appendingPathComponent("Parking/Event", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: unknownSource.appendingPathComponent("Events", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: unknownSource.appendingPathComponent("Photo", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 10, count: 1024).write(to: unknownSource.appendingPathComponent("Driving/20260608_101112_F.MP4"))
            try Data(repeating: 11, count: 1024).write(to: unknownSource.appendingPathComponent("Driving/20260608_101112_R.MP4"))
            try Data(repeating: 12, count: 1024).write(to: unknownSource.appendingPathComponent("Parking/Event/20260608_111213_PR.MP4"))
            try Data(repeating: 13, count: 1024).write(to: unknownSource.appendingPathComponent("Events/REC_20260608_121314_SOS.MOV"))
            let roughDateVideo = unknownSource.appendingPathComponent("Driving/NO_DATE_FRONT.AVI")
            try Data(repeating: 14, count: 1024).write(to: roughDateVideo)
            if let roughDate = ISO8601DateFormatter().date(from: "2026-06-07T09:30:00Z") {
                try FileManager.default.setAttributes([.modificationDate: roughDate], ofItemAtPath: roughDateVideo.path)
            }
            try Data(repeating: 15, count: 1024).write(to: unknownSource.appendingPathComponent("Photo/IMG_0001.PNG"))
            try Data(repeating: 16, count: 1024).write(to: unknownSource.appendingPathComponent("Parking/20120101_010101_F.TS"))

            let unknownScan = try scanner.scan(sourceURL: unknownSource, profiles: profiles)
            guard unknownScan.selectedProfile?.id == "generic-new-dashcam" else {
                print("VERIFY FAIL: unsupported card did not use generic fallback: \(unknownScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard unknownScan.clips.count == 7, unknownScan.clips.allSatisfy({ $0.timestamp != nil }) else {
                print("VERIFY FAIL: unsupported card did not parse generic timestamps")
                return false
            }
            guard Set(unknownScan.clips.map(\.channel)) == ["front", "rear", "unknown"] else {
                print("VERIFY FAIL: unsupported card channels wrong: \(Set(unknownScan.clips.map(\.channel)).sorted())")
                return false
            }
            guard unknownScan.clips.contains(where: { $0.filename == "NO_DATE_FRONT.AVI" && $0.timestampSource == .filesystemModified }) else {
                print("VERIFY FAIL: unsupported AVI did not fall back to file modified date")
                return false
            }
            guard unknownScan.clips.contains(where: { $0.filename == "20120101_010101_F.TS" && $0.hasSuspiciousTimestamp }) else {
                print("VERIFY FAIL: suspicious unset-clock timestamp was not flagged")
                return false
            }
            guard unknownScan.clips.contains(where: { $0.filename == "IMG_0001.PNG" && $0.isPhoto }) else {
                print("VERIFY FAIL: unsupported PNG photo was not treated as a photo")
                return false
            }
            let unknownCategories = Dictionary(
                grouping: unknownScan.clips.filter { $0.excludedReason == nil },
                by: \.outputCategory
            )
            .mapValues(\.count)
            guard unknownCategories["Driving"] == 3,
                  unknownCategories["Parking"] == 1,
                  unknownCategories["Parking Events"] == 1,
                  unknownCategories["Protected"] == 1,
                  unknownCategories["Photos"] == 1 else {
                print("VERIFY FAIL: unsupported card categories wrong: \(unknownCategories)")
                return false
            }
            guard unknownScan.diagnostics.contains(where: { $0.stage == "generic_fallback" }) else {
                print("VERIFY FAIL: unsupported card generic diagnostic missing")
                return false
            }
            var unknownFilters = FilterState()
            unknownFilters.selectedModes = Set(unknownScan.clips.map(\.mode))
            unknownFilters.selectedChannels = Set(unknownScan.clips.map(\.channel))
            unknownFilters.includePhotos = true
            let unknownPlan = CopyPlanner().makePlan(
                sourceRoot: unknownSource,
                destinationRoot: destination,
                profile: unknownScan.selectedProfile ?? .genericNewDashcam,
                clips: unknownScan.clips,
                filters: unknownFilters
            )
            guard unknownPlan.items.contains(where: { $0.destinationURL.path.contains("/Driving/") && $0.destinationURL.lastPathComponent == "NO_DATE_FRONT.AVI" }) else {
                print("VERIFY FAIL: unsupported AVI was not planned in the Driving folder")
                return false
            }
            guard !unknownPlan.items.contains(where: { $0.destinationURL.path.contains("/rough-2026-06-07/") || $0.destinationURL.path.contains("/camera-clock-suspect-2012-01-01/") }) else {
                print("VERIFY FAIL: unsupported plan still creates date folders")
                return false
            }
            guard unknownPlan.items.contains(where: { $0.destinationURL.path.contains("/Parking/") && $0.destinationURL.lastPathComponent == "20120101_010101_F.TS" }) else {
                print("VERIFY FAIL: suspect camera-clock TS was not planned in the Parking folder")
                return false
            }
            var dateFilteredUnknownFilters = unknownFilters
            dateFilteredUnknownFilters.useStartDate = true
            dateFilteredUnknownFilters.useEndDate = true
            let futureFilterDate = Calendar.current.date(from: DateComponents(year: 2030, month: 1, day: 1)) ?? Date()
            dateFilteredUnknownFilters.startDate = futureFilterDate
            dateFilteredUnknownFilters.endDate = futureFilterDate
            let dateFilteredUnknownPlan = CopyPlanner().makePlan(
                sourceRoot: unknownSource,
                destinationRoot: destination,
                profile: unknownScan.selectedProfile ?? .genericNewDashcam,
                clips: unknownScan.clips,
                filters: dateFilteredUnknownFilters
            )
            guard dateFilteredUnknownPlan.items.contains(where: { $0.clip.filename == "20120101_010101_F.TS" }) else {
                print("VERIFY FAIL: date filter dropped a suspicious camera-clock clip")
                return false
            }

            let parkingPatternSource = temp.appendingPathComponent("parking-patterns", isDirectory: true)
            let parkingSamples: [(String, [String])] = [
                ("Parking/LowBitrate", ["20260608_100000_F.MP4", "20260608_100100_F.MP4", "20260608_100200_F.MP4", "20260608_100300_F.MP4"]),
                ("Parking/Lapse", ["20260608_110000_F.MP4", "20260608_111000_F.MP4", "20260608_112000_F.MP4", "20260608_113000_F.MP4"]),
                ("Parking/Motion", ["20260608_120000_F.MP4", "20260608_120700_F.MP4", "20260608_124400_F.MP4", "20260608_140200_F.MP4"])
            ]
            for (folder, filenames) in parkingSamples {
                try FileManager.default.createDirectory(at: parkingPatternSource.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
                for filename in filenames {
                    try Data(repeating: 17, count: 2048).write(to: parkingPatternSource.appendingPathComponent("\(folder)/\(filename)"))
                }
            }
            let parkingPatternScan = try scanner.scan(sourceURL: parkingPatternSource, profiles: profiles)
            let inferredPatterns = Set(parkingPatternScan.clips.compactMap(\.inferredParkingPattern))
            guard inferredPatterns == [.continuousLowBitrate, .timelapse, .motionOrImpact] else {
                print("VERIFY FAIL: parking pattern inference wrong: \(inferredPatterns.map(\.rawValue).sorted())")
                return false
            }
            let inferredDisplayModes = Set(parkingPatternScan.clips.map(\.displayMode))
            guard inferredDisplayModes == ["Parking Continuous / Low Bitrate", "Parking Motion / Impact", "Parking Timelapse"] else {
                print("VERIFY FAIL: parking pattern display modes wrong: \(inferredDisplayModes.sorted())")
                return false
            }

            let scan = try scanner.scanWithOSD(sourceURL: source, profiles: profiles)
            guard scan.candidates.first?.profile.id == "vantrue-e1-pro" else {
                print("VERIFY FAIL: E1 Pro was not top candidate")
                return false
            }
            guard scan.candidates.first?.confidence == .high else {
                print("VERIFY FAIL: E1 Pro did not score high confidence")
                return false
            }
            guard scan.diagnostics.contains(where: { $0.stage == "osd_ocr_gate" && $0.outcome == "skipped_no_ocr_competition" }) else {
                print("VERIFY FAIL: OSD gate diagnostic missing")
                return false
            }

            let a329sSource = temp.appendingPathComponent("A329S", isDirectory: true)
            try FileManager.default.createDirectory(at: a329sSource.appendingPathComponent("DCIM/Movie/Parking", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: a329sSource.appendingPathComponent("DCIM/Movie/RO", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 21, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/2026_0528_130000_000001F.MP4"))
            try Data(repeating: 22, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/2026_0528_130000_000001I.MP4"))
            try Data(repeating: 23, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/2026_0528_130000_000001R.MP4"))
            try Data(repeating: 24, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/Parking/2026_0528_131000_000002PF.MP4"))
            try Data(repeating: 25, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/Parking/2026_0528_131000_000002PI.MP4"))
            try Data(repeating: 26, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/Parking/2026_0528_131000_000002PR.MP4"))
            try Data(repeating: 27, count: 1024).write(to: a329sSource.appendingPathComponent("DCIM/Movie/RO/2026_0528_132000_000003PF.MP4"))

            let a329sScan = try scanner.scan(sourceURL: a329sSource, profiles: profiles)
            guard a329sScan.candidates.first?.profile.id == "viofo-a329s" else {
                print("VERIFY FAIL: A329S volume-label tie did not beat A229 Plus: \(a329sScan.candidates.prefix(3).map { "\($0.profile.id)=\($0.score)" })")
                return false
            }
            guard Set(a329sScan.clips.map(\.channel)) == ["front", "interior", "rear"] else {
                print("VERIFY FAIL: A329S parking channels leaked into physical channels: \(Set(a329sScan.clips.map(\.channel)).sorted())")
                return false
            }
            var a329sFilters = FilterState()
            a329sFilters.selectedModes = Set(a329sScan.clips.map(\.mode))
            a329sFilters.selectedChannels = Set(a329sScan.clips.map(\.channel))
            let a329sProfile = a329sScan.selectedProfile ?? .genericNewDashcam
            let allA329sPlan = CopyPlanner().makePlan(
                sourceRoot: a329sSource,
                destinationRoot: destination,
                profile: a329sProfile,
                clips: a329sScan.clips,
                filters: a329sFilters
            )
            guard allA329sPlan.items.count == 7 else {
                print("VERIFY FAIL: A329S plan should include all fixtures before filtering: \(allA329sPlan.items.count)")
                return false
            }
            a329sFilters.selectedModes.remove("parking")
            let noParkingA329sPlan = CopyPlanner().makePlan(
                sourceRoot: a329sSource,
                destinationRoot: destination,
                profile: a329sProfile,
                clips: a329sScan.clips,
                filters: a329sFilters
            )
            guard noParkingA329sPlan.items.count == 3,
                  noParkingA329sPlan.items.allSatisfy({ !$0.clip.isParkingFootage }) else {
                print("VERIFY FAIL: deselecting parking did not remove all A329S parking footage: \(noParkingA329sPlan.items.map { $0.clip.relativePath })")
                return false
            }

            var filters = FilterState()
            filters.selectedModes = Set(scan.clips.map(\.mode))
            filters.selectedChannels = Set(scan.clips.map(\.channel))

            guard let profile = scan.selectedProfile else {
                print("VERIFY FAIL: selected profile missing")
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
                print("VERIFY FAIL: unexpected plan \(plan.items.count) files \(plan.selectedBytes) bytes")
                return false
            }
            guard plan.items.contains(where: { $0.destinationURL.lastPathComponent == "20260101_120000_00001_N_A Opp traffic up Maltby cloudy.MP4" }) else {
                print("VERIFY FAIL: video filename suffix was not inserted before the extension")
                return false
            }
            guard !plan.items.contains(where: { $0.destinationURL.lastPathComponent.hasSuffix(".MP4 Opp traffic up Maltby cloudy") }) else {
                print("VERIFY FAIL: video filename suffix changed the extension")
                return false
            }
            guard plan.supportItems.isEmpty else {
                print("VERIFY FAIL: settings files were included by default")
                return false
            }
            guard !plan.items.contains(where: { $0.destinationURL.path.contains(profile.displayName) }) else {
                print("VERIFY FAIL: plan still creates a model-name folder by default")
                return false
            }
            guard !plan.items.contains(where: { $0.destinationURL.path.contains("/2026-01-01/") || $0.destinationURL.path.contains("/front/") || $0.destinationURL.path.contains("/rear/") }) else {
                print("VERIFY FAIL: plan still creates date or channel folders by default")
                return false
            }
            guard plan.items.contains(where: { $0.destinationURL.path.contains("/Driving/") }) else {
                print("VERIFY FAIL: driving output folder missing")
                return false
            }
            guard plan.items.contains(where: { $0.destinationURL.path.contains("/Parking/") }) else {
                print("VERIFY FAIL: parking output folder missing")
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
                print("VERIFY FAIL: Config settings file was not planned")
                return false
            }
            guard settingsPlan.supportItems.first?.destinationURL.path.contains("/Camera Settings/") == true else {
                print("VERIFY FAIL: settings file destination folder missing")
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
                print("VERIFY FAIL: Vueroid S1 was not top candidate")
                return false
            }

            let modes = Set(vueroidScan.clips.map(\.mode))
            guard modes.contains("parking"), modes.contains("parking_event") else {
                print("VERIFY FAIL: Vueroid parking modes not split: \(modes.sorted())")
                return false
            }
            guard vueroidScan.clips.contains(where: { $0.mode == "parking_event" && $0.outputCategory == "Parking Events" }) else {
                print("VERIFY FAIL: Vueroid parking event category missing")
                return false
            }
            guard vueroidScan.clips.contains(where: { $0.mode == "continuous" && $0.outputCategory == "Driving" }) else {
                print("VERIFY FAIL: Vueroid continuous category missing")
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
                print("VERIFY FAIL: Vueroid output groups wrong: \(vueroidCategoryCounts)")
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
                    print("VERIFY FAIL: Vueroid boot log was not planned")
                    return false
                }
            }

            let thinkwareSource = temp.appendingPathComponent("thinkware-u3000-pro", isDirectory: true)
            try FileManager.default.createDirectory(at: thinkwareSource.appendingPathComponent("SETTING/lang", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareSource.appendingPathComponent("cont_rec", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareSource.appendingPathComponent(".TWSYS/PIV", isDirectory: true), withIntermediateDirectories: true)
            try Data("Device Name:U3000PRO".utf8).write(to: thinkwareSource.appendingPathComponent("SETTING/lang/ver.dat"))
            try Data(repeating: 6, count: 2048).write(to: thinkwareSource.appendingPathComponent("cont_rec/REC_20260528_175357_F.MP4"))
            try Data(repeating: 7, count: 1024).write(to: thinkwareSource.appendingPathComponent("cont_rec/REC_20260528_175357_R.MP4"))
            try Data(repeating: 8, count: 512).write(to: thinkwareSource.appendingPathComponent(".TWSYS/PIV/PLOC_1_1.JPG"))
            try Data(repeating: 9, count: 512).write(to: thinkwareSource.appendingPathComponent(".TWSYS/PIV/PLOC_2_1.JPG"))

            let thinkwareScan = try scanner.scan(sourceURL: thinkwareSource, profiles: profiles)
            guard thinkwareScan.candidates.first?.profile.id == "thinkware-u3000-pro" else {
                print("VERIFY FAIL: Thinkware U3000 Pro was not top candidate")
                return false
            }
            let thinkwareDownloadableClips = thinkwareScan.clips.filter { $0.excludedReason == nil }
            guard Set(thinkwareDownloadableClips.map(\.channel)) == ["front", "rear"] else {
                print("VERIFY FAIL: Thinkware channels not mapped to front/rear: \(Set(thinkwareDownloadableClips.map(\.channel)).sorted())")
                return false
            }
            guard Set(thinkwareDownloadableClips.map(\.displayChannel)) == ["Front", "Rear"] else {
                print("VERIFY FAIL: Thinkware channel labels wrong: \(Set(thinkwareDownloadableClips.map(\.displayChannel)).sorted())")
                return false
            }
            guard Set(thinkwareDownloadableClips.map(\.displayMode)) == ["Driving"] else {
                print("VERIFY FAIL: Thinkware recording type should display as Driving: \(Set(thinkwareDownloadableClips.map(\.displayMode)).sorted())")
                return false
            }
            guard !thinkwareScan.clips.contains(where: { $0.relativePath.hasPrefix(".TWSYS/") }) else {
                print("VERIFY FAIL: Thinkware hidden .TWSYS internals were scanned")
                return false
            }

            let thinkwareNonProSource = temp.appendingPathComponent("thinkware-u3000", isDirectory: true)
            try FileManager.default.createDirectory(at: thinkwareNonProSource.appendingPathComponent("SETTING/lang", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thinkwareNonProSource.appendingPathComponent("cont_rec", isDirectory: true), withIntermediateDirectories: true)
            try Data("Device Name:U3000".utf8).write(to: thinkwareNonProSource.appendingPathComponent("SETTING/lang/ver.dat"))
            try Data(repeating: 10, count: 2048).write(to: thinkwareNonProSource.appendingPathComponent("cont_rec/REC_20260528_180000_F.MP4"))

            let thinkwareNonProScan = try scanner.scan(sourceURL: thinkwareNonProSource, profiles: profiles)
            guard thinkwareNonProScan.candidates.first?.profile.id == "thinkware-u3000" else {
                print("VERIFY FAIL: Thinkware U3000 was not top candidate")
                return false
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
                print("VERIFY FAIL: progress speed or ETA unavailable")
                return false
            }

            print("VERIFY PASS: \(scan.candidates.first?.profile.displayName ?? "unknown") \(plan.items.count) files; Vueroid parking split OK")
            return true
        } catch {
            print("VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
