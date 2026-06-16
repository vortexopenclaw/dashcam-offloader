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
            guard profiles.contains(where: { $0.id == "vueroid-h1" }) else {
                print("VERIFY FAIL: missing Vueroid H1 profile")
                return false
            }
            guard profiles.first(where: { $0.id == "70mai-x800" })?.maxChannels == 2,
                  profiles.contains(where: { $0.id == "70mai-4k-omni" }) == false else {
                print("VERIFY FAIL: 70mai 4K Omni X800 canonical profile or duplicate removal failed")
                return false
            }
            let currentBuild = AppBuildInfo(version: "0.1.0", build: "1", commit: "abc1234")
            let matchingManifest = AppUpdateManifest(
                version: "0.1.0",
                build: "abc1234",
                releaseName: nil,
                releaseNotes: nil,
                releaseNotesURL: nil,
                assetName: "Dashcam-Offloader-abc1234.zip",
                assetKey: "dashcam-offloader/releases/Dashcam-Offloader-abc1234.zip",
                downloadURL: URL(string: "https://example.com/download/latest")!,
                sha256: nil,
                minimumMacOSVersion: "14.0",
                publishedAt: nil,
                channel: "latest"
            )
            var newerManifest = matchingManifest
            newerManifest.build = "def5678"
            guard !UpdateService.isUpdateAvailable(manifest: matchingManifest, currentBuild: currentBuild),
                  UpdateService.isUpdateAvailable(manifest: newerManifest, currentBuild: currentBuild) else {
                print("VERIFY FAIL: update availability comparison is wrong")
                return false
            }
            var headedReleaseNotesManifest = matchingManifest
            headedReleaseNotesManifest.releaseNotes = """
            ## What's New

            - Easier update notes.
            - Includes bug fixes.
            """
            guard headedReleaseNotesManifest.releaseNotesSummary == "- Easier update notes.\n- Includes bug fixes." else {
                print("VERIFY FAIL: release notes summary did not strip duplicate What's New heading")
                return false
            }
            let destinationDefaultsName = "DashcamOffloaderVerify-\(UUID().uuidString)"
            guard let destinationDefaults = UserDefaults(suiteName: destinationDefaultsName) else {
                print("VERIFY FAIL: could not create isolated destination defaults")
                return false
            }
            defer { destinationDefaults.removePersistentDomain(forName: destinationDefaultsName) }
            let restoredDestinationRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("dashcam-offloader-restored-destination-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: restoredDestinationRoot) }
            try FileManager.default.createDirectory(at: restoredDestinationRoot, withIntermediateDirectories: true)
            destinationDefaults.set(restoredDestinationRoot.path, forKey: "DashcamOffloaderLastDownloadDestinationPath")
            guard TransferViewModel.restoredLastDownloadDestination(defaults: destinationDefaults)?.path == restoredDestinationRoot.standardizedFileURL.path else {
                print("VERIFY FAIL: last download destination did not restore an existing folder")
                return false
            }
            destinationDefaults.set(restoredDestinationRoot.appendingPathComponent("missing", isDirectory: true).path, forKey: "DashcamOffloaderLastDownloadDestinationPath")
            guard TransferViewModel.restoredLastDownloadDestination(defaults: destinationDefaults) == nil else {
                print("VERIFY FAIL: last download destination should ignore missing folders")
                return false
            }
            let installerScript = UpdateService.installerScript(
                stagedAppPath: "/tmp/Dashcam Offloader.app",
                currentAppPath: "/Users/example/Downloads/Dashcam Offloader.app",
                stagingRootPath: "/tmp/dashcam update",
                currentProcessID: 12345
            )
            guard installerScript.contains("while kill -0 \"$CURRENT_PID\""),
                  installerScript.contains("mv \"$CURRENT_APP\" \"$BACKUP_APP\""),
                  installerScript.contains("/usr/bin/ditto \"$STAGED_APP\" \"$CURRENT_APP\""),
                  installerScript.contains("/usr/bin/open -n \"$CURRENT_APP\"") else {
                print("VERIFY FAIL: update installer script does not replace and relaunch in place")
                return false
            }
            let normalInstallTarget = UpdateService.installTargetBundleURL(
                currentBundleURL: URL(fileURLWithPath: "/Users/example/Downloads/Dashcam Offloader.app"),
                bundleIdentifier: "com.vortexopenclaw.dashcam-offloader",
                fileExists: { ["/Users/example/Downloads", "/Users/example/Downloads/Dashcam Offloader.app"].contains($0) },
                isWritableDirectory: { $0 == "/Users/example/Downloads" },
                applicationURLForBundleIdentifier: { _ in URL(fileURLWithPath: "/Applications/Dashcam Offloader.app") }
            )
            guard normalInstallTarget?.path == "/Users/example/Downloads/Dashcam Offloader.app" else {
                print("VERIFY FAIL: update installer should prefer the current writable app bundle")
                return false
            }
            let translocatedInstallTarget = UpdateService.installTargetBundleURL(
                currentBundleURL: URL(fileURLWithPath: "/private/var/folders/example/AppTranslocation/12345/d/Dashcam Offloader.app"),
                bundleIdentifier: "com.vortexopenclaw.dashcam-offloader",
                fileExists: { ["/Applications", "/Applications/Dashcam Offloader.app"].contains($0) },
                isWritableDirectory: { $0 == "/Applications" },
                applicationURLForBundleIdentifier: { _ in URL(fileURLWithPath: "/Applications/Dashcam Offloader.app") }
            )
            guard translocatedInstallTarget?.path == "/Applications/Dashcam Offloader.app" else {
                print("VERIFY FAIL: update installer should resolve translocated apps to the original bundle")
                return false
            }
            let commandLineInstallTarget = UpdateService.installTargetBundleURL(
                currentBundleURL: URL(fileURLWithPath: "/Users/example/dashcam-offloader/.build/debug/DashcamOffloader"),
                bundleIdentifier: "com.vortexopenclaw.dashcam-offloader",
                fileExists: { ["/Applications", "/Applications/Dashcam Offloader.app"].contains($0) },
                isWritableDirectory: { $0 == "/Applications" },
                applicationURLForBundleIdentifier: { _ in URL(fileURLWithPath: "/Applications/Dashcam Offloader.app") }
            )
            guard commandLineInstallTarget == nil else {
                print("VERIFY FAIL: command-line builds should not update an installed app bundle")
                return false
            }
            let requiredDisplayNames = [
                "Blackvue Elite 9",
                "70mai M310",
                "Cansonic UltraDash Z3+ Standard Edition",
                "GoPro HERO / MAX Camera",
                "GoPro HERO9 Black",
                "Rove R2-4K Pro",
                "Vantrue N4 Pro S"
            ]
            for displayName in requiredDisplayNames {
                guard profiles.contains(where: { $0.displayName == displayName }) else {
                    print("VERIFY FAIL: missing display name \(displayName)")
                    return false
                }
            }
            guard ManufacturerDisplayFormatter.displayName(for: "BlackVue") == "Blackvue",
                  ManufacturerDisplayFormatter.displayName(for: "blackvue") == "Blackvue",
                  ManufacturerDisplayFormatter.displayName(for: "VIOFO") == "Viofo",
                  ManufacturerDisplayFormatter.displayName(for: "DJI") == "DJI",
                  IdentifiedCamera(manufacturer: "BlackVue", model: "Elite 9", evidence: [], isSupported: true).displayName == "Blackvue Elite 9" else {
                print("VERIFY FAIL: manufacturer display casing regression")
                return false
            }
            guard let n4ProSProfile = profiles.first(where: { $0.id == "vantrue-n4-pro-s" }),
                  n4ProSProfile.channels["A"] == "front",
                  n4ProSProfile.channels["B"] == "interior",
                  n4ProSProfile.channels["C"] == "rear" else {
                print("VERIFY FAIL: Vantrue N4 Pro S profile did not load A/B/C channel labels")
                return false
            }
            guard KnownDashcamCatalog.models.count >= 140,
                  KnownDashcamCatalog.exactVolumeLabelMatch("N4 Pro S")?.model == "N4 Pro S",
                  KnownDashcamCatalog.exactVolumeLabelMatch("Nexus 4 Pro S")?.model == "N4 Pro S",
                  KnownDashcamCatalog.exactVolumeLabelMatch("E360 ACE")?.channelRoles == ["panoramic_front", "rear"],
                  KnownDashcamCatalog.exactVolumeLabelMatch("4K Omni")?.model == "4K Omni X800",
                  KnownDashcamCatalog.exactVolumeLabelMatch("70MAI_X800")?.model == "4K Omni X800",
                  KnownDashcamCatalog.exactVolumeLabelMatch("Dash Cam Omni")?.model == "X200",
                  KnownDashcamCatalog.exactVolumeLabelMatch("ELITE 10")?.model == "Elite 10",
                  KnownDashcamCatalog.exactBlackVueModelMention("model = ELITE 10 v1.000(rev100)")?.model == "Elite 10",
                  KnownDashcamCatalog.exactModelMention("Device Name:U3000PRO", manufacturer: "Thinkware")?.model == "U3000 Pro",
                  KnownDashcamCatalog.exactModelMention("E1PRO_Settings.ini", manufacturer: "Vantrue")?.model == "Element 1 Pro",
                  KnownDashcamCatalog.exactModelMention("systemKind=\"ILCE-7M3\"", manufacturer: "Sony")?.model == "Alpha A7 III",
                  KnownDashcamCatalog.exactVolumeLabelMatch("NO NAME") == nil,
                  KnownDashcamCatalog.exactVolumeLabelMatch("Untitled") == nil,
                  KnownDashcamCatalog.exactVolumeLabelMatch("BLACKVUE") == nil,
                  KnownDashcamCatalog.exactVolumeLabelMatch("F17 Plus")?.channels == 4,
                  KnownDashcamCatalog.exactVolumeLabelMatch("F17 Plus")?.channelSensors["front"] == "Sony IMX675",
                  KnownDashcamCatalog.exactVolumeLabelMatch("F17 Elite")?.channelSensors["interior"] == "Sony IMX307 STARVIS",
                  KnownDashcamCatalog.exactVolumeLabelMatch("VC70")?.channelSensors["rear"] == "OmniVision OS04J10",
                  KnownDashcamCatalog.exactVolumeLabelMatch("F77")?.channelSensors["front"] == "Sony IMX678",
                  KnownDashcamCatalog.exactVolumeLabelMatch("F77")?.sensorNotes.contains("eMMC") == true,
                  KnownDashcamCatalog.exactVolumeLabelMatch("VS10 4G LTE")?.channelResolutions["front"] == "2K",
                  KnownDashcamCatalog.exactVolumeLabelMatch("F7NT")?.model == "F7NT",
                  KnownDashcamCatalog.exactVolumeLabelMatch("VP40")?.channelResolutions["left"] == "1080p",
                  KnownDashcamCatalog.exactVolumeLabelMatch("G900 TriPro Bumper")?.channelRoles == ["front", "rear", "bumper"],
                  KnownDashcamCatalog.exactVolumeLabelMatch("G850Pro")?.model == "G850 Pro",
                  KnownDashcamCatalog.exactVolumeLabelMatch("G850Pro")?.channelResolutions["rear"] == "2K",
                  KnownDashcamCatalog.exactVolumeLabelMatch("G840H")?.parkingModes.contains("reverse parking guide lines") == true,
                  KnownDashcamCatalog.exactVolumeLabelMatch("HERO9 Black")?.manufacturer == "GoPro",
                  KnownDashcamCatalog.exactVolumeLabelMatch("Hero 9 Black")?.parkingModes.contains("looping 5/20/60/120 minutes/max") == true,
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "MISSION 1")?.channelSensors["primary"] == "1-inch",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "MISSION 1 PRO")?.channelResolutions["primary"] == "8K60, 8K Open Gate 30, 4K240, 1080p480, 1440p480",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "Mission 1 Pro ILS")?.parkingModes.contains("endurance") == true,
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "HERO13 Creator Edition")?.model == "HERO13 Black Creator Edition",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "HERO13 Ultra Wide Edition")?.model == "HERO13 Black Ultra Wide Edition",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "LIT HERO")?.channelResolutions["primary"] == "4K60, 4:3 video, photo",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "HERO12 Black")?.channelResolutions["primary"] == "5.3K60, 4K120, 2.7K240",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "HERO")?.channelResolutions["primary"] == "4K30, 2.7K60, 1080p60",
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "MAX2")?.channelRoles == ["360_primary"],
                  KnownDashcamCatalog.exactModelMatch(manufacturer: "GoPro", modelText: "MAX2")?.channelResolutions["360_primary"]?.contains("4K100 360") == true else {
                print("VERIFY FAIL: internal known dashcam catalog missing expected aliases or channel hints")
                return false
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
            try FileManager.default.createDirectory(at: source.appendingPathComponent("SETTING", isDirectory: true), withIntermediateDirectories: true)
            try Data("resolution=4k".utf8).write(to: source.appendingPathComponent("Config/settings.ini"))
            try Data("private bluetooth id".utf8).write(to: source.appendingPathComponent("Config/bt_ssid.bin"))
            try Data("password=secret".utf8).write(to: source.appendingPathComponent("Config/wifi_password.ini"))
            try Data("unique-device-id".utf8).write(to: source.appendingPathComponent("SETTING/device.uid"))
            try Data("not a settings file".utf8).write(to: source.appendingPathComponent("Config/helper.exe"))

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

            let unsupportedKnownSource = temp.appendingPathComponent("E360 ACE", isDirectory: true)
            try FileManager.default.createDirectory(at: unsupportedKnownSource.appendingPathComponent("Normal", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 31, count: 1024).write(to: unsupportedKnownSource.appendingPathComponent("Normal/20260610_101112_00001_N_A.MP4"))
            let unsupportedKnownScan = try scanner.scan(sourceURL: unsupportedKnownSource, profiles: [])
            guard unsupportedKnownScan.selectedProfile?.id == "generic-new-dashcam",
                  unsupportedKnownScan.identifiedCamera == nil,
                  KnownDashcamCatalog.exactVolumeLabelMatch(unsupportedKnownSource.lastPathComponent)?.model == "E360 ACE" else {
                print("VERIFY FAIL: internal catalog label should stay a private hint, not a detected camera")
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

            let sonySource = temp.appendingPathComponent("A7III 128", isDirectory: true)
            try FileManager.default.createDirectory(at: sonySource.appendingPathComponent("PRIVATE/M4ROOT/CLIP", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: sonySource.appendingPathComponent("PRIVATE/M4ROOT/THMBNL", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: sonySource.appendingPathComponent("DCIM/100MSDCF", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 51, count: 2048).write(to: sonySource.appendingPathComponent("PRIVATE/M4ROOT/CLIP/C0001.MP4"))
            try Data(repeating: 52, count: 1024).write(to: sonySource.appendingPathComponent("PRIVATE/M4ROOT/THMBNL/C0001T01.JPG"))
            let sonyRaw = sonySource.appendingPathComponent("DCIM/100MSDCF/A7307789.ARW")
            let sonyJPEG = sonySource.appendingPathComponent("DCIM/100MSDCF/A7307790.JPG")
            try Data(repeating: 53, count: 4096).write(to: sonyRaw)
            try Data(repeating: 54, count: 3072).write(to: sonyJPEG)
            let today = Date()
            try FileManager.default.setAttributes([.modificationDate: today], ofItemAtPath: sonyRaw.path)
            try FileManager.default.setAttributes([.modificationDate: today], ofItemAtPath: sonyJPEG.path)
            let sonyScan = try scanner.scan(sourceURL: sonySource, profiles: profiles)
            guard sonyScan.selectedProfile?.id == "sony-a7-iii" else {
                print("VERIFY FAIL: Sony A7 III card was not selected: \(sonyScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard let sonyRawClip = sonyScan.clips.first(where: { $0.filename == "A7307789.ARW" }),
                  sonyRawClip.isPhoto,
                  sonyRawClip.mode == "raw",
                  sonyRawClip.displayMode == "RAW",
                  sonyRawClip.outputCategory == "Photos",
                  sonyRawClip.timestampSource == .filesystemModified else {
                print("VERIFY FAIL: Sony ARW was not classified as a RAW photo")
                return false
            }
            guard let sonyVideoClip = sonyScan.clips.first(where: { $0.filename == "C0001.MP4" }),
                  sonyVideoClip.isVideo,
                  sonyVideoClip.mode == "video",
                  sonyVideoClip.displayMode == "Video",
                  sonyVideoClip.outputCategory == "Video" else {
                print("VERIFY FAIL: Sony video should display as Video, got \(sonyScan.clips.first(where: { $0.filename == "C0001.MP4" })?.displayMode ?? "nil")")
                return false
            }
            guard let sonyJPEGClip = sonyScan.clips.first(where: { $0.filename == "A7307790.JPG" }),
                  sonyJPEGClip.isPhoto,
                  sonyJPEGClip.mode == "jpeg",
                  sonyJPEGClip.displayMode == "JPEG",
                  sonyJPEGClip.outputCategory == "Photos" else {
                print("VERIFY FAIL: Sony full-size JPEG was not classified as a JPEG photo")
                return false
            }
            guard sonyScan.clips.first(where: { $0.filename == "C0001T01.JPG" })?.excludedReason != nil else {
                print("VERIFY FAIL: Sony clip thumbnail should be excluded from downloads")
                return false
            }
            guard sonyScan.clips.filter({ $0.excludedReason == nil }).map(\.filename).sorted() == ["A7307789.ARW", "A7307790.JPG", "C0001.MP4"] else {
                print("VERIFY FAIL: Sony downloadable items should include real media only: \(sonyScan.clips.filter({ $0.excludedReason == nil }).map(\.filename).sorted())")
                return false
            }
            var sonyFilters = FilterState()
            sonyFilters.selectedModes = Set(sonyScan.clips.filter(\.isVideo).map(\.mode))
            sonyFilters.selectedChannels = Set(sonyScan.clips.filter(\.isVideo).map(\.channel))
            sonyFilters.includePhotos = true
            sonyFilters.useStartDate = true
            sonyFilters.useEndDate = true
            sonyFilters.startDate = today
            sonyFilters.endDate = today
            let sonyPlan = CopyPlanner().makePlan(
                sourceRoot: sonySource,
                destinationRoot: destination,
                profile: sonyScan.selectedProfile ?? .genericNewDashcam,
                clips: sonyScan.clips,
                filters: sonyFilters
            )
            guard sonyPlan.items.contains(where: { $0.displayFilename == "A7307789.ARW" }),
                  sonyPlan.items.contains(where: { $0.displayFilename == "A7307790.JPG" }),
                  !sonyPlan.items.contains(where: { $0.displayFilename == "C0001T01.JPG" }) else {
                print("VERIFY FAIL: Sony Today filter plan should include full images but not thumbnails: \(sonyPlan.items.map(\.displayFilename).sorted())")
                return false
            }
            let sonyPlanFilenames = sonyPlan.items.map(\.displayFilename)
            guard let videoIndex = sonyPlanFilenames.firstIndex(of: "C0001.MP4"),
                  let rawIndex = sonyPlanFilenames.firstIndex(of: "A7307789.ARW"),
                  let jpegIndex = sonyPlanFilenames.firstIndex(of: "A7307790.JPG"),
                  videoIndex < rawIndex,
                  videoIndex < jpegIndex else {
                print("VERIFY FAIL: Sony review plan should group videos before photos by default: \(sonyPlanFilenames)")
                return false
            }
            let sonyCameraUI = MainActor.assumeIsolated { () -> (showChannelFilter: Bool, includePhotos: Bool) in
                let viewModel = TransferViewModel()
                viewModel.selectedProfile = sonyScan.selectedProfile
                viewModel.clips = sonyScan.clips
                viewModel.resetFiltersForCurrentClips()
                return (viewModel.shouldShowChannelFilter, viewModel.filters.includePhotos)
            }
            guard !sonyCameraUI.showChannelFilter, sonyCameraUI.includePhotos else {
                print("VERIFY FAIL: single-lens Sony camera should hide channel controls and include photos by default")
                return false
            }

            let unknownVantrueSource = temp.appendingPathComponent("unknown-vantrue-family", isDirectory: true)
            try FileManager.default.createDirectory(at: unknownVantrueSource.appendingPathComponent("Normal", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: unknownVantrueSource.appendingPathComponent("Parking", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 21, count: 1024).write(to: unknownVantrueSource.appendingPathComponent("Normal/20260610_101112_00001_N_A.MP4"))
            try Data(repeating: 22, count: 1024).write(to: unknownVantrueSource.appendingPathComponent("Normal/20260610_101112_00001_N_B.MP4"))
            try Data(repeating: 23, count: 1024).write(to: unknownVantrueSource.appendingPathComponent("Normal/20260610_101112_00001_N_C.MP4"))
            try Data(repeating: 24, count: 1024).write(to: unknownVantrueSource.appendingPathComponent("Parking/20260610_111213_00002_P_A.MP4"))
            let unknownVantrueScan = try scanner.scan(sourceURL: unknownVantrueSource, profiles: profiles)
            guard unknownVantrueScan.selectedProfile?.id == "generic-new-dashcam" else {
                print("VERIFY FAIL: unknown Vantrue-style card should stay generic, got \(unknownVantrueScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard Set(unknownVantrueScan.clips.map(\.channel)) == ["channel_a", "channel_b", "channel_c"] else {
                print("VERIFY FAIL: unknown Vantrue-style channels wrong: \(Set(unknownVantrueScan.clips.map(\.channel)).sorted())")
                return false
            }
            guard Set(unknownVantrueScan.clips.map(\.displayChannel)) == ["Channel A", "Channel B", "Channel C"] else {
                print("VERIFY FAIL: unknown Vantrue-style channel labels wrong: \(Set(unknownVantrueScan.clips.map(\.displayChannel)).sorted())")
                return false
            }

            let n4ProSSource = temp.appendingPathComponent("N4 Pro S", isDirectory: true)
            try FileManager.default.createDirectory(at: n4ProSSource.appendingPathComponent("Normal", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: n4ProSSource.appendingPathComponent("Event", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: n4ProSSource.appendingPathComponent("Parking", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 31, count: 1024).write(to: n4ProSSource.appendingPathComponent("Normal/20260610_101112_00001_N_A.MP4"))
            try Data(repeating: 32, count: 1024).write(to: n4ProSSource.appendingPathComponent("Normal/20260610_101112_00001_N_B.MP4"))
            try Data(repeating: 33, count: 1024).write(to: n4ProSSource.appendingPathComponent("Normal/20260610_101112_00001_N_C.MP4"))
            let n4ProSClips = scanner.classifyWithParkingPatterns(
                files: [
                    n4ProSSource.appendingPathComponent("Normal/20260610_101112_00001_N_A.MP4"),
                    n4ProSSource.appendingPathComponent("Normal/20260610_101112_00001_N_B.MP4"),
                    n4ProSSource.appendingPathComponent("Normal/20260610_101112_00001_N_C.MP4")
                ],
                sourceURL: n4ProSSource,
                profile: n4ProSProfile
            ).clips
            let n4ProSDisplayChannels = Set(n4ProSClips.map { $0.displayChannel })
            guard n4ProSDisplayChannels == ["Front", "Interior", "Rear"] else {
                print("VERIFY FAIL: N4 Pro S channel labels wrong: \(n4ProSDisplayChannels.sorted())")
                return false
            }

            let botslabSource = temp.appendingPathComponent("NO NAME", isDirectory: true)
            for folder in [
                "MISC",
                "360CARDVR/REC/FRONT",
                "360CARDVR/REC/REAR",
                "360CARDVR/REC/LEFT",
                "360CARDVR/REC/RIGHT",
                "360CARDVR/PARKING/FRONT",
                "360CARDVR/PARKING/REAR",
                "360CARDVR/PARKING/LEFT",
                "360CARDVR/PARKING/RIGHT",
                "360CARDVR/SECVIDEO/FRONT",
                "360CARDVR/SECVIDEO/REAR",
                "360CARDVR/SECVIDEO/LEFT"
            ] {
                try FileManager.default.createDirectory(at: botslabSource.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
            }
            try Data().write(to: botslabSource.appendingPathComponent("MISC/G980HMCN5291.TXT"))
            let botslabSamples: [(String, String)] = [
                ("360CARDVR/REC/FRONT", "AA"),
                ("360CARDVR/REC/REAR", "AB"),
                ("360CARDVR/REC/LEFT", "AC"),
                ("360CARDVR/REC/RIGHT", "AD"),
                ("360CARDVR/PARKING/FRONT", "AA"),
                ("360CARDVR/PARKING/REAR", "AB"),
                ("360CARDVR/PARKING/LEFT", "AC"),
                ("360CARDVR/PARKING/RIGHT", "AD"),
                ("360CARDVR/SECVIDEO/FRONT", "AA"),
                ("360CARDVR/SECVIDEO/REAR", "AB"),
                ("360CARDVR/SECVIDEO/LEFT", "AC")
            ]
            for (folder, suffix) in botslabSamples {
                try Data(repeating: 31, count: 2048).write(
                    to: botslabSource.appendingPathComponent("\(folder)/20260609135005_000001\(suffix).MP4")
                )
            }
            guard scanner.shouldShowMountedSource(botslabSource, showAllVolumes: false) else {
                print("VERIFY FAIL: Botslab-style 360CARDVR card was filtered from sources")
                return false
            }
            let botslabScan = try scanner.scan(sourceURL: botslabSource, profiles: profiles)
            guard botslabScan.selectedProfile?.id == "botslab-g980h" else {
                print("VERIFY FAIL: Botslab G980H fixture selected \(botslabScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard Set(botslabScan.clips.map(\.channel)) == ["front", "rear", "left", "right"] else {
                print("VERIFY FAIL: Botslab channels wrong: \(Set(botslabScan.clips.map(\.channel)).sorted())")
                return false
            }
            guard botslabScan.clips.contains(where: { $0.channel == "left" && $0.outputCategory == "Driving" }),
                  botslabScan.clips.contains(where: { $0.channel == "right" && $0.isParkingFootage }) else {
                print("VERIFY FAIL: Botslab mode/channel classification wrong")
                return false
            }
            guard botslabScan.clips.contains(where: { $0.relativePath.hasPrefix("360CARDVR/SECVIDEO/") && $0.displayMode == "Parking Timelapse" }) else {
                print("VERIFY FAIL: Botslab SECVIDEO clips should be Parking Timelapse")
                return false
            }

            let unknown360Source = temp.appendingPathComponent("unknown-360cardvr", isDirectory: true)
            try FileManager.default.createDirectory(at: unknown360Source.appendingPathComponent("360CARDVR/REC/FRONT", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: unknown360Source.appendingPathComponent("360CARDVR/REC/LEFT", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 32, count: 2048).write(to: unknown360Source.appendingPathComponent("360CARDVR/REC/FRONT/20260609135005_000001AA.MP4"))
            try Data(repeating: 33, count: 2048).write(to: unknown360Source.appendingPathComponent("360CARDVR/REC/LEFT/20260609135005_000002AC.MP4"))
            guard scanner.shouldShowMountedSource(unknown360Source, showAllVolumes: false) else {
                print("VERIFY FAIL: unknown 360CARDVR card was filtered from sources")
                return false
            }
            let unknown360Scan = try scanner.scan(sourceURL: unknown360Source, profiles: profiles)
            guard unknown360Scan.selectedProfile?.id == "generic-new-dashcam" else {
                print("VERIFY FAIL: unknown 360CARDVR card should stay generic, got \(unknown360Scan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard Set(unknown360Scan.clips.map(\.channel)) == ["front", "left"] else {
                print("VERIFY FAIL: unknown 360CARDVR generic channels wrong: \(Set(unknown360Scan.clips.map(\.channel)).sorted())")
                return false
            }

            let goProSource = temp.appendingPathComponent("HERO9 Black", isDirectory: true)
            try FileManager.default.createDirectory(at: goProSource.appendingPathComponent("DCIM/100GOPRO", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: goProSource.appendingPathComponent("DCIM/101GOPRO", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: goProSource.appendingPathComponent("MISC", isDirectory: true), withIntermediateDirectories: true)
            try Data("""
            {
            "info version":"2.0",
            "firmware version":"HD9.01.01.72.00",
            "wifi mac":"001122334455",
            "camera type":"HERO9 Black",
            "camera serial number":"C0000000000000",
            }
            """.utf8).write(to: goProSource.appendingPathComponent("MISC/version.txt"))
            try Data(repeating: 41, count: 2048).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/GX010273.MP4"))
            try Data(repeating: 42, count: 2048).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/GX020273.MP4"))
            try Data(repeating: 45, count: 2048).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/GXAA0277.MP4"))
            for sequence in 9565...9570 {
                try Data(repeating: UInt8(50 + (sequence - 9565)), count: 2048).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/GXAD\(sequence).MP4"))
            }
            try Data(repeating: 43, count: 1024).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/GOPR0274.JPG"))
            try Data(repeating: 44, count: 1024).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/G0010275.JPG"))
            try Data("GoPro TimeWarp sample metadata".utf8).write(to: goProSource.appendingPathComponent("DCIM/100GOPRO/GX010276.MP4"))
            try Data(repeating: 46, count: 2048).write(to: goProSource.appendingPathComponent("DCIM/101GOPRO/GX010278.MP4"))
            guard scanner.shouldShowMountedSource(goProSource, showAllVolumes: false) else {
                print("VERIFY FAIL: GoPro HERO9 fixture was filtered from sources")
                return false
            }
            let goProScan = try scanner.scan(sourceURL: goProSource, profiles: profiles)
            guard goProScan.selectedProfile?.id == "gopro-hero9-black" else {
                print("VERIFY FAIL: GoPro HERO9 fixture selected \(goProScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard goProScan.candidates.first?.confidence == .high,
                  goProScan.candidates.first?.evidence.contains(where: { $0.contains("MISC/version.txt") }) == true else {
                print("VERIFY FAIL: GoPro HERO9 MISC/version.txt did not produce high-confidence model evidence")
                return false
            }
            guard goProScan.identifiedCamera?.model == "HERO9 Black",
                  goProScan.identifiedCamera?.isSupported == true,
                  goProScan.identifiedCamera?.evidence.contains(where: { $0.lowercased().contains("serial") || $0.lowercased().contains("wifi") }) == false else {
                print("VERIFY FAIL: GoPro HERO9 safe version.txt identification wrong: \(String(describing: goProScan.identifiedCamera))")
                return false
            }
            guard goProScan.clips.count == 13,
                  Set(goProScan.clips.map(\.channel)) == ["primary"],
                  goProScan.clips.filter(\.isVideo).count == 11,
                  goProScan.clips.filter(\.isPhoto).count == 2 else {
                print("VERIFY FAIL: GoPro media classification wrong: clips=\(goProScan.clips.count), channels=\(Set(goProScan.clips.map(\.channel)).sorted())")
                return false
            }
            guard goProScan.clips.contains(where: { $0.relativePath == "DCIM/101GOPRO/GX010278.MP4" && $0.mode == "regular_recording" }) else {
                print("VERIFY FAIL: GoPro overflow folder DCIM/101GOPRO was not imported")
                return false
            }
            guard goProScan.clips.contains(where: { $0.filename == "GXAA0277.MP4" && $0.mode == "regular_recording" && $0.outputCategory == "Regular Recording" }) else {
                print("VERIFY FAIL: GoPro letter-token MP4 was not classified as regular recording")
                return false
            }
            guard goProScan.clips.filter({ $0.filename.hasPrefix("GXAD") && $0.mode == "looping" }).count == 6 else {
                print("VERIFY FAIL: GoPro same-prefix one-minute loop chunks were not classified as looping")
                return false
            }
            guard goProScan.clips.contains(where: { $0.filename == "GX010276.MP4" && $0.mode == "time_warp" && $0.outputCategory == "TimeWarp" }) else {
                print("VERIFY FAIL: GoPro TimeWarp hint was not classified separately")
                return false
            }
            let goProDefaultModes = Set(goProScan.clips.filter { $0.isVideo }.map(\.mode)).filter { mode in
                !["time_lapse", "timelapse_video", "time_warp", "timewarp", "time_lapse_or_timewarp"].contains(mode.lowercased())
            }
            var goProFilters = FilterState()
            goProFilters.selectedModes = goProDefaultModes
            goProFilters.selectedChannels = Set(goProScan.clips.filter { $0.isVideo }.map(\.channel))
            let goProPlan = CopyPlanner().makePlan(
                sourceRoot: goProSource,
                destinationRoot: temp.appendingPathComponent("GoPro Output", isDirectory: true),
                profile: goProScan.selectedProfile ?? .genericNewDashcam,
                clips: goProScan.clips,
                filters: goProFilters
            )
            guard goProPlan.items.map(\.clip.relativePath).sorted() == ["DCIM/100GOPRO/GX010273.MP4", "DCIM/100GOPRO/GX020273.MP4", "DCIM/100GOPRO/GXAA0277.MP4", "DCIM/100GOPRO/GXAD9565.MP4", "DCIM/101GOPRO/GX010278.MP4"],
                  goProPlan.items.contains(where: { $0.displayFilename == "GXAD9565-9570.MP4" && $0.sourceFileCount == 6 && $0.displaySource.contains("GXAD9565.MP4 ... GXAD9570.MP4") }) else {
                print("VERIFY FAIL: GoPro default-style plan should exclude photos and TimeWarp, got \(goProPlan.items.map(\.clip.filename).sorted())")
                return false
            }
            guard CopyPlanner().hasGoProLoopGroups(profile: goProScan.selectedProfile ?? .genericNewDashcam, clips: goProScan.clips),
                  !CopyPlanner().hasGoProLoopGroups(profile: .genericNewDashcam, clips: goProScan.clips) else {
                print("VERIFY FAIL: GoPro loop-group option visibility detection wrong")
                return false
            }

            var goProOriginalsFilters = goProFilters
            goProOriginalsFilters.goProLoopGroupOutput = .originalsOnly
            let goProOriginalsPlan = CopyPlanner().makePlan(
                sourceRoot: goProSource,
                destinationRoot: temp.appendingPathComponent("GoPro Output", isDirectory: true),
                profile: goProScan.selectedProfile ?? .genericNewDashcam,
                clips: goProScan.clips,
                filters: goProOriginalsFilters
            )
            guard goProOriginalsPlan.items.count == 10,
                  goProOriginalsPlan.items.allSatisfy({ $0.sourceFileCount == 1 }),
                  goProOriginalsPlan.items.filter({ $0.displayFilename.hasPrefix("GXAD") }).count == 6,
                  !goProOriginalsPlan.items.contains(where: { $0.displayFilename == "GXAD9565-9570.MP4" }),
                  goProOriginalsPlan.selectedBytes == 10 * 2048 else {
                print("VERIFY FAIL: GoPro originals-only plan should keep each loop clip separate, got \(goProOriginalsPlan.items.map(\.displayFilename).sorted())")
                return false
            }

            var goProBothFilters = goProFilters
            goProBothFilters.goProLoopGroupOutput = .originalsAndMerged
            let goProBothPlan = CopyPlanner().makePlan(
                sourceRoot: goProSource,
                destinationRoot: temp.appendingPathComponent("GoPro Output", isDirectory: true),
                profile: goProScan.selectedProfile ?? .genericNewDashcam,
                clips: goProScan.clips,
                filters: goProBothFilters
            )
            guard goProBothPlan.items.count == 11,
                  goProBothPlan.items.filter({ $0.sourceFileCount == 1 && $0.displayFilename.hasPrefix("GXAD") }).count == 6,
                  goProBothPlan.items.contains(where: { $0.displayFilename == "GXAD9565-9570.MP4" && $0.sourceFileCount == 6 }),
                  Set(goProBothPlan.items.map(\.id)).count == goProBothPlan.items.count,
                  Set(goProBothPlan.items.map(\.destinationURL)).count == goProBothPlan.items.count,
                  goProBothPlan.selectedBytes == 10 * 2048 + 6 * 2048 else {
                print("VERIFY FAIL: GoPro originals+merged plan should include each loop clip plus the merged clip, got \(goProBothPlan.items.map(\.displayFilename).sorted())")
                return false
            }

            guard DateFilterPreset.allCases == [.today, .yesterday, .lastThreeDays, .lastWeek, .allTime, .custom],
                  DateFilterPreset.lastThreeDays.label == "Last 3 days" else {
                print("VERIFY FAIL: date filter presets should include Last 3 days in order")
                return false
            }
            guard OutputOrganizationMode.allCases == [.oneFolder, .byClipType, .byDate, .byCamera],
                  OutputOrganizationMode.byClipType.label == "By clip type" else {
                print("VERIFY FAIL: output organization modes should include one folder, clip type, date, and camera")
                return false
            }

            let existingDestination = temp.appendingPathComponent("GoPro Existing Output", isDirectory: true)
            try FileManager.default.createDirectory(at: existingDestination.appendingPathComponent("Regular Recording", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 7, count: 64).write(to: existingDestination.appendingPathComponent("Regular Recording/GX010273.MP4"))
            let existingPlan = CopyPlanner().makePlan(
                sourceRoot: goProSource,
                destinationRoot: existingDestination,
                profile: goProScan.selectedProfile ?? .genericNewDashcam,
                clips: goProScan.clips,
                filters: goProFilters
            )
            guard existingPlan.items.filter(\.alreadyExistsAtDestination).map(\.displayFilename) == ["GX010273.MP4"],
                  existingPlan.items.filter({ !$0.alreadyExistsAtDestination }).count == existingPlan.items.count - 1 else {
                print("VERIFY FAIL: planner should flag only the file already present at the destination, got \(existingPlan.items.filter(\.alreadyExistsAtDestination).map(\.displayFilename))")
                return false
            }

            let goPro12Source = temp.appendingPathComponent("U3000PRO", isDirectory: true)
            try FileManager.default.createDirectory(at: goPro12Source.appendingPathComponent("DCIM/100GOPRO", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: goPro12Source.appendingPathComponent("MISC", isDirectory: true), withIntermediateDirectories: true)
            try Data("""
            {
            "firmware version":"H23.01.02.32.00",
            "camera type":"HERO12 Black",
            "wifi mac":"001122334455",
            "camera serial number":"C9999999999999",
            }
            """.utf8).write(to: goPro12Source.appendingPathComponent("MISC/version.txt"))
            try Data(repeating: 48, count: 2048).write(to: goPro12Source.appendingPathComponent("DCIM/100GOPRO/GX010001.MP4"))
            let goPro12Scan = try scanner.scan(sourceURL: goPro12Source, profiles: profiles)
            guard goPro12Scan.selectedProfile?.id == "gopro-hero-action-camera",
                  goPro12Scan.identifiedCamera?.manufacturer == "GoPro",
                  goPro12Scan.identifiedCamera?.model == "HERO12 Black",
                  goPro12Scan.identifiedCamera?.isSupported == false,
                  goPro12Scan.identifiedCamera?.evidence.contains(where: { $0.lowercased().contains("serial") || $0.lowercased().contains("wifi") }) == false,
                  goPro12Scan.clips.count == 1,
                  goPro12Scan.clips.first?.channel == "primary" else {
                print("VERIFY FAIL: generic GoPro version.txt support wrong: selected=\(goPro12Scan.selectedProfile?.id ?? "nil"), identified=\(String(describing: goPro12Scan.identifiedCamera))")
                return false
            }

            let unknownDeepSource = temp.appendingPathComponent("unknown-deep-camera", isDirectory: true)
            try FileManager.default.createDirectory(at: unknownDeepSource.appendingPathComponent("MEDIA/CLIPS/SESSION001/FRONT", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 47, count: 2048).write(to: unknownDeepSource.appendingPathComponent("MEDIA/CLIPS/SESSION001/FRONT/20260610_103000_front.MP4"))
            guard scanner.shouldShowMountedSource(unknownDeepSource, showAllVolumes: false) else {
                print("VERIFY FAIL: deep unknown camera media tree was filtered from sources")
                return false
            }
            let unknownDeepScan = try scanner.scan(sourceURL: unknownDeepSource, profiles: profiles)
            guard unknownDeepScan.selectedProfile?.id == "generic-new-dashcam",
                  unknownDeepScan.clips.count == 1,
                  unknownDeepScan.clips.first?.channel == "front",
                  unknownDeepScan.clips.first?.outputCategory == "Driving" else {
                print("VERIFY FAIL: deep unknown camera generic scan lost media metadata")
                return false
            }

            let unknownSiblingSource = temp.appendingPathComponent("unknown-sibling-family", isDirectory: true)
            try FileManager.default.createDirectory(at: unknownSiblingSource.appendingPathComponent("VIDEO", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 18, count: 1024).write(to: unknownSiblingSource.appendingPathComponent("VIDEO/20260609_141500_F.MP4"))
            try Data(repeating: 19, count: 1024).write(to: unknownSiblingSource.appendingPathComponent("VIDEO/20260609_141500_R.MP4"))
            let siblingPattern = FilenamePattern(
                rawPattern: "^(\\d{8})_(\\d{6})_([FR])\\.MP4$",
                regexPattern: "^(\\d{8})_(\\d{6})_([FR])\\.MP4$",
                modeMap: [:],
                channelMap: ["F": "front", "R": "rear"],
                timestampFormat: .yyyymmddHhmmss
            )
            let siblingProfiles = [
                DashcamProfile(
                    id: "examplecam-alpha",
                    manufacturer: "ExampleCam",
                    model: "Alpha",
                    status: "test",
                    confidence: "medium",
                    cameraType: nil,
                    folders: [ProfileFolder(path: "VIDEO", mode: "continuous", importable: true)],
                    filenamePatterns: [siblingPattern],
                    channels: ["F": "front", "R": "rear"],
                    detectionRules: [],
                    disqualifyingRules: [],
                    osdSpec: nil
                ),
                DashcamProfile(
                    id: "examplecam-beta",
                    manufacturer: "ExampleCam",
                    model: "Beta",
                    status: "test",
                    confidence: "medium",
                    cameraType: nil,
                    folders: [ProfileFolder(path: "VIDEO", mode: "continuous", importable: true)],
                    filenamePatterns: [siblingPattern],
                    channels: ["F": "front", "R": "rear"],
                    detectionRules: [],
                    disqualifyingRules: [],
                    osdSpec: nil
                )
            ]
            let unknownSiblingScan = try scanner.scan(sourceURL: unknownSiblingSource, profiles: siblingProfiles)
            guard unknownSiblingScan.selectedProfile?.id == "generic-new-dashcam" else {
                print("VERIFY FAIL: ambiguous sibling card selected exact model \(unknownSiblingScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard unknownSiblingScan.identifiedCamera == nil else {
                print("VERIFY FAIL: ambiguous sibling card should not identify exact camera")
                return false
            }
            guard unknownSiblingScan.clips.count == 2,
                  Set(unknownSiblingScan.clips.map(\.channel)) == ["front", "rear"],
                  unknownSiblingScan.clips.allSatisfy({ $0.outputCategory == "Driving" }) else {
                print("VERIFY FAIL: ambiguous sibling card generic import lost clip metadata")
                return false
            }
            guard unknownSiblingScan.diagnostics.contains(where: { $0.stage == "profile_selection_guard" && $0.outcome == "selected_generic_new_card" }) else {
                print("VERIFY FAIL: ambiguous sibling card did not record selection guard")
                return false
            }

            guard profiles.contains(where: { $0.id == "70mai-t800" && $0.maxChannels == 3 }),
                  profiles.contains(where: { $0.id == "70mai-x800" && $0.maxChannels == 2 }) else {
                print("VERIFY FAIL: 70mai T800/X800 profile missing or max channel metadata missing")
                return false
            }

            let t800LikeSource = temp.appendingPathComponent("70MAI_T800", isDirectory: true)
            for folder in ["Normal/Front", "Normal/Rear", "Normal/Cabin"] {
                try FileManager.default.createDirectory(at: t800LikeSource.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
            }
            try Data(repeating: 20, count: 1024).write(to: t800LikeSource.appendingPathComponent("Normal/Front/NO20260615-093309-000000F.MP4"))
            try Data(repeating: 21, count: 1024).write(to: t800LikeSource.appendingPathComponent("Normal/Rear/NO20260615-093309-000000R.MP4"))
            try Data(repeating: 22, count: 1024).write(to: t800LikeSource.appendingPathComponent("Normal/Cabin/NO20260615-093309-000000C.MP4"))
            let t800LikeScan = try scanner.scan(sourceURL: t800LikeSource, profiles: profiles)
            guard t800LikeScan.selectedProfile?.id == "70mai-t800" else {
                print("VERIFY FAIL: T800-like 3CH 70mai card was not recognized as T800: \(t800LikeScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard Set(t800LikeScan.clips.map(\.channel)) == ["front", "interior", "rear"],
                  t800LikeScan.clips.allSatisfy({ $0.outputCategory == "Driving" }) else {
                print("VERIFY FAIL: T800 profile import lost channels: \(Set(t800LikeScan.clips.map(\.channel)).sorted())")
                return false
            }

            let x800LikeSource = temp.appendingPathComponent("70MAI_X800", isDirectory: true)
            for folder in ["Normal/Front", "Normal/Rear", "Normal/.s_Front", "Parking/Front", "Parking/Rear", "Lapse/Front", "Lapse/Rear"] {
                try FileManager.default.createDirectory(at: x800LikeSource.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
            }
            try Data(repeating: 31, count: 1024).write(to: x800LikeSource.appendingPathComponent("Normal/Front/NO20260616-095000-000000F.MP4"))
            try Data(repeating: 32, count: 1024).write(to: x800LikeSource.appendingPathComponent("Normal/Rear/NO20260616-095000-000000R.MP4"))
            try Data(repeating: 33, count: 1024).write(to: x800LikeSource.appendingPathComponent("Parking/Front/PA20260616-095100-000001F.MP4"))
            try Data(repeating: 34, count: 1024).write(to: x800LikeSource.appendingPathComponent("Parking/Rear/PA20260616-095100-000001R.MP4"))
            try Data(repeating: 35, count: 1024).write(to: x800LikeSource.appendingPathComponent("Lapse/Front/LA20260616-095200-000002F.MP4"))
            try Data(repeating: 36, count: 1024).write(to: x800LikeSource.appendingPathComponent("Lapse/Rear/LA20260616-095200-000002R.MP4"))
            let x800LikeScan = try scanner.scan(sourceURL: x800LikeSource, profiles: profiles)
            guard x800LikeScan.selectedProfile?.id == "70mai-x800" else {
                print("VERIFY FAIL: X800-like 2CH 70mai card was not recognized as X800: \(x800LikeScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard x800LikeScan.identifiedCamera?.model == "4K Omni X800",
                  Set(x800LikeScan.clips.map(\.channel)) == ["front", "rear"],
                  x800LikeScan.clips.contains(where: { $0.mode == "parking_timelapse" }),
                  x800LikeScan.clips.contains(where: { $0.mode == "parking_motion_or_impact" }) else {
                let channels = Set(x800LikeScan.clips.map(\.channel)).sorted()
                let modes = Set(x800LikeScan.clips.map(\.mode)).sorted()
                print("VERIFY FAIL: X800 profile import lost identity, channels, or parking modes: identified=\(String(describing: x800LikeScan.identifiedCamera)), channels=\(channels), modes=\(modes)")
                return false
            }

            let untrainedElite10Source = temp.appendingPathComponent("BLACKVUE", isDirectory: true)
            try FileManager.default.createDirectory(at: untrainedElite10Source.appendingPathComponent("BlackVue/Config", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: untrainedElite10Source.appendingPathComponent("BlackVue/Record", isDirectory: true), withIntermediateDirectories: true)
            try Data("model = ELITE 10 v1.000(rev100)\nversion = 1.000\n".utf8).write(to: untrainedElite10Source.appendingPathComponent("BlackVue/Config/version.bin"))
            try Data(repeating: 37, count: 1024).write(to: untrainedElite10Source.appendingPathComponent("BlackVue/Record/20260616_102800_NF.mp4"))
            try Data(repeating: 38, count: 1024).write(to: untrainedElite10Source.appendingPathComponent("BlackVue/Record/20260616_102800_NR.mp4"))
            let untrainedElite10Scan = try scanner.scan(sourceURL: untrainedElite10Source, profiles: profiles)
            guard untrainedElite10Scan.selectedProfile?.id == "generic-new-dashcam",
                  untrainedElite10Scan.identifiedCamera?.manufacturer == "BlackVue",
                  untrainedElite10Scan.identifiedCamera?.model == "Elite 10",
                  untrainedElite10Scan.identifiedCamera?.isSupported == false,
                  Set(untrainedElite10Scan.clips.map(\.channel)) == ["front", "rear"] else {
                print("VERIFY FAIL: untrained BlackVue Elite 10 metadata should identify known model while staying generic: profile=\(untrainedElite10Scan.selectedProfile?.id ?? "nil"), identified=\(String(describing: untrainedElite10Scan.identifiedCamera)), channels=\(Set(untrainedElite10Scan.clips.map(\.channel)).sorted())")
                return false
            }
            guard untrainedElite10Scan.diagnostics.contains(where: {
                $0.stage == "blackvue_config_metadata" &&
                    $0.outcome == "parsed_safe_fields" &&
                    $0.detail.localizedCaseInsensitiveContains("Elite 10")
            }),
            untrainedElite10Scan.diagnostics.contains(where: {
                $0.stage == "profile_selection_guard" &&
                    $0.outcome == "selected_generic_new_card" &&
                    $0.detail.contains("BlackVue Elite 10")
            }) else {
                print("VERIFY FAIL: untrained BlackVue Elite 10 scan did not record metadata and guard diagnostics: \(untrainedElite10Scan.diagnostics.map { "\($0.stage):\($0.outcome):\($0.detail)" })")
                return false
            }

            let untrainedThinkwareSource = temp.appendingPathComponent("THINKWARE", isDirectory: true)
            try FileManager.default.createDirectory(at: untrainedThinkwareSource.appendingPathComponent("SETTING/lang", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: untrainedThinkwareSource.appendingPathComponent("cont_rec", isDirectory: true), withIntermediateDirectories: true)
            try Data("Device Name:U3000PRO\nVersion:1.00\n".utf8).write(to: untrainedThinkwareSource.appendingPathComponent("SETTING/lang/ver.dat"))
            try Data(repeating: 39, count: 1024).write(to: untrainedThinkwareSource.appendingPathComponent("cont_rec/REC_20260616_103000_F.MP4"))
            let untrainedThinkwareScan = try scanner.scan(sourceURL: untrainedThinkwareSource, profiles: [])
            guard untrainedThinkwareScan.selectedProfile?.id == "generic-new-dashcam",
                  untrainedThinkwareScan.identifiedCamera?.manufacturer == "Thinkware",
                  untrainedThinkwareScan.identifiedCamera?.model == "U3000 Pro",
                  untrainedThinkwareScan.identifiedCamera?.isSupported == false,
                  untrainedThinkwareScan.diagnostics.contains(where: {
                      $0.stage == "safe_model_metadata" &&
                          $0.detail.contains("SETTING/lang/ver.dat") &&
                          $0.detail.contains("U3000PRO")
                  }) else {
                print("VERIFY FAIL: untrained Thinkware safe metadata should identify known catalog model while staying generic: profile=\(untrainedThinkwareScan.selectedProfile?.id ?? "nil"), identified=\(String(describing: untrainedThinkwareScan.identifiedCamera)), diagnostics=\(untrainedThinkwareScan.diagnostics.map { "\($0.stage):\($0.outcome):\($0.detail)" })")
                return false
            }

            let untrainedVantrueSource = temp.appendingPathComponent("VANTRUE", isDirectory: true)
            try FileManager.default.createDirectory(at: untrainedVantrueSource.appendingPathComponent("GPS", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: untrainedVantrueSource.appendingPathComponent("Normal", isDirectory: true), withIntermediateDirectories: true)
            try Data("placeholder=settings\n".utf8).write(to: untrainedVantrueSource.appendingPathComponent("GPS/E1PRO_Settings.ini"))
            try Data(repeating: 40, count: 1024).write(to: untrainedVantrueSource.appendingPathComponent("Normal/20260616_103100_00001_N_A.MP4"))
            let untrainedVantrueScan = try scanner.scan(sourceURL: untrainedVantrueSource, profiles: [])
            guard untrainedVantrueScan.selectedProfile?.id == "generic-new-dashcam",
                  untrainedVantrueScan.identifiedCamera?.manufacturer == "Vantrue",
                  untrainedVantrueScan.identifiedCamera?.model == "Element 1 Pro",
                  untrainedVantrueScan.identifiedCamera?.isSupported == false,
                  untrainedVantrueScan.diagnostics.contains(where: {
                      $0.stage == "safe_model_metadata" &&
                          $0.detail.contains("GPS/E1PRO_Settings.ini") &&
                          $0.detail.contains("Element 1 Pro")
                  }) else {
                print("VERIFY FAIL: untrained Vantrue model-coded settings filename should identify known catalog model while staying generic: profile=\(untrainedVantrueScan.selectedProfile?.id ?? "nil"), identified=\(String(describing: untrainedVantrueScan.identifiedCamera)), diagnostics=\(untrainedVantrueScan.diagnostics.map { "\($0.stage):\($0.outcome):\($0.detail)" })")
                return false
            }

            let untrainedSonySource = temp.appendingPathComponent("SONY", isDirectory: true)
            try FileManager.default.createDirectory(at: untrainedSonySource.appendingPathComponent("PRIVATE/M4ROOT", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: untrainedSonySource.appendingPathComponent("DCIM/100MSDCF", isDirectory: true), withIntermediateDirectories: true)
            try Data(#"<MediaProfile><Properties><System systemKind="ILCE-7M3"/></Properties></MediaProfile>"#.utf8).write(to: untrainedSonySource.appendingPathComponent("PRIVATE/M4ROOT/MEDIAPRO.XML"))
            try Data(repeating: 41, count: 1024).write(to: untrainedSonySource.appendingPathComponent("DCIM/100MSDCF/A7300001.ARW"))
            let untrainedSonyScan = try scanner.scan(sourceURL: untrainedSonySource, profiles: [])
            guard untrainedSonyScan.selectedProfile?.id == "generic-new-dashcam",
                  untrainedSonyScan.identifiedCamera?.manufacturer == "Sony",
                  untrainedSonyScan.identifiedCamera?.model == "Alpha A7 III",
                  untrainedSonyScan.identifiedCamera?.isSupported == false,
                  untrainedSonyScan.diagnostics.contains(where: {
                      $0.stage == "safe_model_metadata" &&
                          $0.detail.contains("PRIVATE/M4ROOT/MEDIAPRO.XML") &&
                          $0.detail.contains("ILCE-7M3")
                  }) else {
                print("VERIFY FAIL: untrained Sony XML metadata should identify known catalog model while staying generic: profile=\(untrainedSonyScan.selectedProfile?.id ?? "nil"), identified=\(String(describing: untrainedSonyScan.identifiedCamera)), diagnostics=\(untrainedSonyScan.diagnostics.map { "\($0.stage):\($0.outcome):\($0.detail)" })")
                return false
            }

            let impossibleT800LikeSource = temp.appendingPathComponent("unknown-70mai-4ch-like", isDirectory: true)
            for folder in ["Normal/Front", "Normal/Rear", "Normal/Cabin", "Normal/Side"] {
                try FileManager.default.createDirectory(at: impossibleT800LikeSource.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
            }
            try Data(repeating: 27, count: 1024).write(to: impossibleT800LikeSource.appendingPathComponent("Normal/Front/NO20260615-093309-000000F.MP4"))
            try Data(repeating: 28, count: 1024).write(to: impossibleT800LikeSource.appendingPathComponent("Normal/Rear/NO20260615-093309-000000R.MP4"))
            try Data(repeating: 29, count: 1024).write(to: impossibleT800LikeSource.appendingPathComponent("Normal/Cabin/NO20260615-093309-000000C.MP4"))
            try Data(repeating: 30, count: 1024).write(to: impossibleT800LikeSource.appendingPathComponent("Normal/Side/NO20260615-093309-000000D.MP4"))
            let impossibleT800LikeScan = try scanner.scan(sourceURL: impossibleT800LikeSource, profiles: profiles)
            guard impossibleT800LikeScan.selectedProfile?.id == "generic-new-dashcam" else {
                print("VERIFY FAIL: impossible 4CH 70mai-style card selected exact profile \(impossibleT800LikeScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard impossibleT800LikeScan.diagnostics.contains(where: {
                $0.stage == "profile_selection_guard" &&
                    $0.outcome == "selected_generic_new_card" &&
                    ($0.detail.contains("exceeds") || $0.detail.contains("outside"))
            }) else {
                print("VERIFY FAIL: impossible 4CH 70mai-style card did not record extra-channel guard")
                return false
            }

            let knownVolumeLabelSource = temp.appendingPathComponent("70mai A800", isDirectory: true)
            try FileManager.default.createDirectory(at: knownVolumeLabelSource.appendingPathComponent("Normal", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 23, count: 1024).write(to: knownVolumeLabelSource.appendingPathComponent("Normal/NO20260615-093309-000000F.MP4"))
            let knownVolumeLabelScan = try scanner.scan(sourceURL: knownVolumeLabelSource, profiles: [])
            guard knownVolumeLabelScan.selectedProfile?.id == "generic-new-dashcam",
                  knownVolumeLabelScan.identifiedCamera == nil,
                  knownVolumeLabelScan.diagnostics.contains(where: {
                      $0.stage == "known_catalog_volume_hint" &&
                          $0.outcome == "matched_known_model_label" &&
                          $0.detail.contains("70mai A800")
                  }),
                  knownVolumeLabelScan.diagnostics.contains(where: {
                      $0.stage == "known_catalog_capability_check" &&
                          $0.outcome == "observed_within_catalog_capability" &&
                          $0.detail.contains("supports up to 2 channel")
                  }) else {
                print("VERIFY FAIL: known volume label should create a private 70mai A800 hint without selecting a profile")
                return false
            }

            let impossibleKnownVolumeLabelSource = temp.appendingPathComponent("70mai A800", isDirectory: true)
            try FileManager.default.removeItem(at: knownVolumeLabelSource)
            try FileManager.default.createDirectory(at: impossibleKnownVolumeLabelSource.appendingPathComponent("Normal/Front", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: impossibleKnownVolumeLabelSource.appendingPathComponent("Normal/Rear", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: impossibleKnownVolumeLabelSource.appendingPathComponent("Normal/Cabin", isDirectory: true), withIntermediateDirectories: true)
            try Data(repeating: 24, count: 1024).write(to: impossibleKnownVolumeLabelSource.appendingPathComponent("Normal/Front/NO20260615-093309-000000F.MP4"))
            try Data(repeating: 25, count: 1024).write(to: impossibleKnownVolumeLabelSource.appendingPathComponent("Normal/Rear/NO20260615-093309-000000R.MP4"))
            try Data(repeating: 26, count: 1024).write(to: impossibleKnownVolumeLabelSource.appendingPathComponent("Normal/Cabin/NO20260615-093309-000000C.MP4"))
            let impossibleKnownVolumeLabelScan = try scanner.scan(sourceURL: impossibleKnownVolumeLabelSource, profiles: [])
            guard impossibleKnownVolumeLabelScan.selectedProfile?.id == "generic-new-dashcam",
                  impossibleKnownVolumeLabelScan.identifiedCamera == nil,
                  impossibleKnownVolumeLabelScan.diagnostics.contains(where: {
                      $0.stage == "known_catalog_capability_check" &&
                          $0.outcome == "observed_exceeds_catalog_capability" &&
                          $0.detail.contains("70mai A800 supports up to 2 channel") &&
                          $0.detail.contains("card shows 3 channel")
                  }) else {
                print("VERIFY FAIL: catalog max-channel capability should flag impossible 70mai A800 evidence")
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
            var unknownDateFolderFilters = unknownFilters
            unknownDateFolderFilters.outputOrganizationMode = .byDate
            let unknownDateFolderPlan = CopyPlanner().makePlan(
                sourceRoot: unknownSource,
                destinationRoot: destination,
                profile: unknownScan.selectedProfile ?? .genericNewDashcam,
                clips: unknownScan.clips,
                filters: unknownDateFolderFilters
            )
            guard unknownDateFolderPlan.items.contains(where: { $0.destinationURL.path.contains("/rough-2026-06-07/") && $0.destinationURL.lastPathComponent == "NO_DATE_FRONT.AVI" }),
                  unknownDateFolderPlan.items.contains(where: { $0.destinationURL.path.contains("/camera-clock-suspect-2012-01-01/") && $0.destinationURL.lastPathComponent == "20120101_010101_F.TS" }) else {
                print("VERIFY FAIL: date organization should label rough and suspicious unknown-card timestamps")
                return false
            }
            var unknownCameraFolderFilters = unknownFilters
            unknownCameraFolderFilters.outputOrganizationMode = .byCamera
            let unknownCameraFolderPlan = CopyPlanner().makePlan(
                sourceRoot: unknownSource,
                destinationRoot: destination,
                profile: unknownScan.selectedProfile ?? .genericNewDashcam,
                clips: unknownScan.clips,
                filters: unknownCameraFolderFilters
            )
            guard unknownCameraFolderPlan.items.allSatisfy({ $0.destinationURL.path.contains("/unsupported-card/") }) else {
                print("VERIFY FAIL: generic camera organization should fall back to the source folder name")
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
                ("Parking/Mixed", ["20260608_100000_F.MP4", "20260608_100100_F.MP4", "20260608_100200_F.MP4", "20260608_100300_F.MP4", "20260608_101900_F.MP4", "20260608_124400_F.MP4"]),
                ("Parking/Lapse", ["20260608_110000_F.MP4", "20260608_111000_F.MP4", "20260608_112000_F.MP4", "20260608_113000_F.MP4"]),
                ("Movie/RO", ["20260608_130000_000100PF.MP4"])
            ]
            for (folder, filenames) in parkingSamples {
                try FileManager.default.createDirectory(at: parkingPatternSource.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
                for filename in filenames {
                    try Data(repeating: 17, count: 2048).write(to: parkingPatternSource.appendingPathComponent("\(folder)/\(filename)"))
                }
            }
            let parkingPatternScan = try scanner.scan(sourceURL: parkingPatternSource, profiles: profiles)
            let inferredPatterns = Set(parkingPatternScan.clips.compactMap(\.inferredParkingPattern))
            guard inferredPatterns == [.continuousLowBitrate, .timelapse, .motionDetection, .impactDetection] else {
                print("VERIFY FAIL: parking pattern inference wrong: \(inferredPatterns.map(\.rawValue).sorted())")
                return false
            }
            let inferredDisplayModes = Set(parkingPatternScan.clips.map(\.displayMode))
            guard inferredDisplayModes == ["Parking Continuous / Low Bitrate", "Parking Impact Detection", "Parking Motion Detection", "Parking Timelapse"] else {
                print("VERIFY FAIL: parking pattern display modes wrong: \(inferredDisplayModes.sorted())")
                return false
            }
            let inferredRawModes = Set(parkingPatternScan.clips.map(\.mode))
            guard inferredRawModes == ["parking_continuous_low_bitrate", "parking_impact_detection", "parking_motion_detection", "parking_timelapse"] else {
                print("VERIFY FAIL: parking pattern raw modes wrong: \(inferredRawModes.sorted())")
                return false
            }

            let z4TimelapseSource = temp.appendingPathComponent("z4-timelapse", isDirectory: true)
            try FileManager.default.createDirectory(at: z4TimelapseSource.appendingPathComponent("VIDEO", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: z4TimelapseSource.appendingPathComponent("PROTECTED", isDirectory: true), withIntermediateDirectories: true)
            for suffix in ["L", "R", "B"] {
                try createSparseFile(
                    at: z4TimelapseSource.appendingPathComponent("VIDEO/20260609_130000_\(suffix).MP4"),
                    size: suffix == "B" ? 120_000_000 : 400_000_000
                )
            }
            for minute in 0..<4 {
                let timestamp = String(format: "20260609_130%d00", minute)
                for suffix in ["L", "R", "B"] {
                    try createSparseFile(
                        at: z4TimelapseSource.appendingPathComponent("PROTECTED/P\(timestamp)_\(suffix).MP4"),
                        size: suffix == "B" ? 120_000_000 : 400_000_000
                    )
                }
            }
            for suffix in ["L", "R", "B"] {
                try createSparseFile(
                    at: z4TimelapseSource.appendingPathComponent("PROTECTED/P20260609_140000_\(suffix).MP4"),
                    size: suffix == "B" ? 120_000_000 : 400_000_000
                )
            }
            let z4TimelapseScan = try scanner.scan(sourceURL: z4TimelapseSource, profiles: profiles)
            guard z4TimelapseScan.candidates.first?.profile.id == "cansonic-ultradash-z4-standard" else {
                print("VERIFY FAIL: Z4 timelapse fixture did not select Z4")
                return false
            }
            let z4PatternCounts = Dictionary(grouping: z4TimelapseScan.clips.compactMap(\.inferredParkingPattern), by: { $0 })
                .mapValues(\.count)
            guard z4PatternCounts[.timelapse] == 12,
                  z4PatternCounts[.motionOrImpact] == 3,
                  z4PatternCounts[.impactDetection] == nil else {
                print("VERIFY FAIL: Z4 protected P clips mislabeled: \(z4PatternCounts.map { "\($0.key.rawValue)=\($0.value)" }.sorted())")
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
            a329sFilters.selectedModes = a329sFilters.selectedModes.filter { !ClipItem.isParkingMode($0) }
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

            let a329tSource = temp.appendingPathComponent("A329T", isDirectory: true)
            try FileManager.default.createDirectory(at: a329tSource.appendingPathComponent("DCIM/Movie/Parking", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: a329tSource.appendingPathComponent("DCIM/Movie/RO", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: a329tSource.appendingPathComponent("DCIM/Photo", isDirectory: true), withIntermediateDirectories: true)
            for index in 1...30 {
                let sequence = String(format: "%06d", 314000 + index)
                let second = String(format: "%02d", index % 60)
                for suffix in ["F", "R", "T"] {
                    try Data(repeating: UInt8(index), count: 1024).write(
                        to: a329tSource.appendingPathComponent("DCIM/Movie/2026_0609_1022\(second)_\(sequence)\(suffix).MP4")
                    )
                }
                for suffix in ["PF", "PR", "PT"] {
                    try Data(repeating: UInt8(index), count: 512).write(
                        to: a329tSource.appendingPathComponent("DCIM/Movie/Parking/2026_0609_1122\(second)_\(sequence)\(suffix).MP4")
                    )
                    try Data(repeating: UInt8(index), count: 256).write(
                        to: a329tSource.appendingPathComponent("DCIM/Movie/RO/2026_0609_1222\(second)_\(sequence)\(suffix).MP4")
                    )
                }
                for suffix in ["F", "R", "T", "PF", "PR", "PT"] {
                    try Data(repeating: UInt8(index), count: 128).write(
                        to: a329tSource.appendingPathComponent("DCIM/Photo/2026_0609_1322\(second)_\(sequence)\(suffix).JPG")
                    )
                }
            }

            let a329tScan = try scanner.scan(sourceURL: a329tSource, profiles: profiles)
            guard a329tScan.candidates.first?.profile.id == "viofo-a329t" else {
                print("VERIFY FAIL: A329T-specific T/PT evidence did not beat A229 siblings: \(a329tScan.candidates.prefix(4).map { "\($0.profile.id)=\($0.score):\($0.evidence.joined(separator: "|"))" })")
                return false
            }
            guard a329tScan.selectedProfile?.id == "viofo-a329t" else {
                print("VERIFY FAIL: A329T fixture selected \(a329tScan.selectedProfile?.id ?? "nil"); candidates \(a329tScan.candidates.prefix(6).map { "\($0.profile.id)=\($0.score):\($0.evidence.joined(separator: "|"))" }); diagnostics \(a329tScan.diagnostics.map { "\($0.stage):\($0.outcome):\($0.detail)" })")
                return false
            }

            let cansonicZ4Source = temp.appendingPathComponent("ULTRADASH", isDirectory: true)
            try FileManager.default.createDirectory(at: cansonicZ4Source.appendingPathComponent("VIDEO", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: cansonicZ4Source.appendingPathComponent("PROTECTED", isDirectory: true), withIntermediateDirectories: true)
            for suffix in ["L", "R", "B"] {
                try Data(repeating: 41, count: 1024).write(
                    to: cansonicZ4Source.appendingPathComponent("VIDEO/20260609_114113_\(suffix).MP4")
                )
                try Data(repeating: 42, count: 1024).write(
                    to: cansonicZ4Source.appendingPathComponent("PROTECTED/P20260609_114525_\(suffix).MP4")
                )
            }

            let cansonicZ4Scan = try scanner.scan(sourceURL: cansonicZ4Source, profiles: profiles)
            guard cansonicZ4Scan.selectedProfile?.id == "cansonic-ultradash-z4-standard" else {
                print("VERIFY FAIL: Cansonic Z4 selected \(cansonicZ4Scan.selectedProfile?.id ?? "nil"); candidates \(cansonicZ4Scan.candidates.prefix(3).map { "\($0.profile.id)=\($0.score):\($0.evidence.joined(separator: "|"))" })")
                return false
            }
            guard !cansonicZ4Scan.candidates.contains(where: { $0.profile.id == "cansonic-ultradash-z3plus-standard" }) else {
                print("VERIFY FAIL: Cansonic Z3+ should be disqualified by Z4 VIDEO/PROTECTED card layout")
                return false
            }
            let cansonicCategories = Dictionary(grouping: cansonicZ4Scan.clips, by: \.outputCategory).mapValues(\.count)
            guard cansonicCategories["Driving"] == 3,
                  cansonicCategories["Parking Events"] == 3 else {
                print("VERIFY FAIL: Cansonic Z4 output groups wrong: \(cansonicCategories)")
                return false
            }
            guard Set(cansonicZ4Scan.clips.map(\.displayMode)).contains("Parking Motion / Impact") else {
                print("VERIFY FAIL: Cansonic Z4 protected clips were not labeled as parking motion/impact")
                return false
            }
            guard Set(cansonicZ4Scan.clips.map(\.channel)) == ["front", "front_telephoto", "rear"] else {
                print("VERIFY FAIL: Cansonic Z4 channels wrong: \(Set(cansonicZ4Scan.clips.map(\.channel)).sorted())")
                return false
            }

            var filters = FilterState()
            filters.selectedModes = Set(scan.clips.map(\.mode))
            filters.selectedChannels = Set(scan.clips.map(\.channel))

            guard let profile = scan.selectedProfile else {
                print("VERIFY FAIL: selected profile missing")
                return false
            }

            let selectableVideoClips = scan.clips.filter { $0.excludedReason == nil && $0.isVideo }
            guard selectableVideoClips.allSatisfy({ filters.selectedModes.contains($0.mode) && filters.selectedChannels.contains($0.channel) }) else {
                print("VERIFY FAIL: some downloadable videos are not represented by recording type/channel selections")
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
            guard Set(plan.items.map(\.clip.id)) == Set(selectableVideoClips.map(\.id)) else {
                print("VERIFY FAIL: fully selected recording type/channel filters did not plan exactly all downloadable videos")
                return false
            }
            guard let firstQueueItem = plan.items.first else {
                print("VERIFY FAIL: copy plan had no selectable queue item")
                return false
            }
            let selectedRunPlan = plan.limitedToMediaItemIDs([firstQueueItem.id])
            guard selectedRunPlan.items.map(\.id) == [firstQueueItem.id],
                  selectedRunPlan.selectedFileCount == 1,
                  selectedRunPlan.selectedBytes == firstQueueItem.clip.size else {
                print("VERIFY FAIL: selected queue rows did not limit the run plan")
                return false
            }
            var emptyModeFilters = filters
            emptyModeFilters.selectedModes = []
            let emptyModePlan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: emptyModeFilters
            )
            guard emptyModePlan.items.isEmpty else {
                print("VERIFY FAIL: deselecting all recording types should clear the download queue")
                return false
            }
            var emptyChannelFilters = filters
            emptyChannelFilters.selectedChannels = []
            let emptyChannelPlan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: emptyChannelFilters
            )
            guard emptyChannelPlan.items.isEmpty else {
                print("VERIFY FAIL: deselecting all channels should clear the download queue")
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
            var oneFolderFilters = filters
            oneFolderFilters.outputOrganizationMode = .oneFolder
            let oneFolderPlan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: oneFolderFilters
            )
            guard oneFolderPlan.items.allSatisfy({ $0.destinationURL.deletingLastPathComponent().standardizedFileURL == destination.standardizedFileURL }) else {
                print("VERIFY FAIL: one-folder organization should copy media directly to the download folder")
                return false
            }
            var dateFolderFilters = filters
            dateFolderFilters.outputOrganizationMode = .byDate
            let dateFolderPlan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: dateFolderFilters
            )
            guard dateFolderPlan.items.allSatisfy({ $0.destinationURL.path.contains("/2026-01-01/") }) else {
                print("VERIFY FAIL: date organization should use clip timestamp folders")
                return false
            }
            var cameraFolderFilters = filters
            cameraFolderFilters.outputOrganizationMode = .byCamera
            let cameraFolderPlan = CopyPlanner().makePlan(
                sourceRoot: source,
                destinationRoot: destination,
                profile: profile,
                clips: scan.clips,
                filters: cameraFolderFilters
            )
            guard cameraFolderPlan.items.allSatisfy({ $0.destinationURL.path.contains("/Vantrue E1 Pro/") }) else {
                print("VERIFY FAIL: camera organization should use the detected camera folder")
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
            let sensitiveSupportPaths = Set(settingsPlan.supportItems.map(\.relativePath))
            guard !sensitiveSupportPaths.contains("Config/bt_ssid.bin"),
                  !sensitiveSupportPaths.contains("Config/wifi_password.ini"),
                  !sensitiveSupportPaths.contains("SETTING/device.uid"),
                  !sensitiveSupportPaths.contains("Config/helper.exe") else {
                print("VERIFY FAIL: sensitive/private support files were planned: \(sensitiveSupportPaths.sorted())")
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

            let unknownVueroidSource = temp.appendingPathComponent("unknown-vueroid-family", isDirectory: true)
            for folder in ["EVENT", "INF", "PARK", "PEVENT", "USER"] {
                try FileManager.default.createDirectory(
                    at: unknownVueroidSource.appendingPathComponent(folder, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
            try Data(repeating: 41, count: 1024).write(to: unknownVueroidSource.appendingPathComponent("INF/20260101-120000-INF-N.mp4"))
            try Data(repeating: 42, count: 1024).write(to: unknownVueroidSource.appendingPathComponent("PARK/20260101-121000-PRK-N.mp4"))
            try Data(repeating: 43, count: 1024).write(to: unknownVueroidSource.appendingPathComponent("PEVENT/20260101-122000-PVT-N.mp4"))

            let unknownVueroidScan = try scanner.scan(sourceURL: unknownVueroidSource, profiles: profiles)
            guard unknownVueroidScan.selectedProfile?.id == "generic-new-dashcam" else {
                print("VERIFY FAIL: unknown Vueroid-style card should use generic fallback, got \(unknownVueroidScan.selectedProfile?.id ?? "nil")")
                return false
            }
            guard unknownVueroidScan.diagnostics.contains(where: { $0.stage == "profile_selection_guard" && $0.outcome == "selected_generic_new_card" }) else {
                print("VERIFY FAIL: unknown Vueroid-style card did not record profile selection guard")
                return false
            }

            let modes = Set(vueroidScan.clips.map(\.mode))
            guard modes.contains("parking"), modes.contains("parking_impact_detection") else {
                print("VERIFY FAIL: Vueroid parking modes not split: \(modes.sorted())")
                return false
            }
            guard vueroidScan.clips.contains(where: { $0.mode == "parking_impact_detection" && $0.outputCategory == "Parking Events" }) else {
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

            let vueroidH1Source = temp.appendingPathComponent("H1-QHD-INF", isDirectory: true)
            try FileManager.default.createDirectory(at: vueroidH1Source.appendingPathComponent("CONFIG", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidH1Source.appendingPathComponent("EVENT", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidH1Source.appendingPathComponent("INF", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidH1Source.appendingPathComponent("PARK", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidH1Source.appendingPathComponent("PEVENT", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vueroidH1Source.appendingPathComponent("USER", isDirectory: true), withIntermediateDirectories: true)
            try Data("H1-QHD-INFINITE V0.5.9\u{0}May 13 2026, 12:23:13\u{0}H1-QHD-INFINITE".utf8).write(to: vueroidH1Source.appendingPathComponent("CONFIG/config.bin"))
            try Data("[2026/06/09-16:31:03] BOOT 12.6V 030`C 1CH".utf8).write(to: vueroidH1Source.appendingPathComponent("CONFIG/.boot.log"))
            try Data(repeating: 31, count: 1024).write(to: vueroidH1Source.appendingPathComponent("INF/20260515_214744_INF_N.mp4"))
            try Data(repeating: 32, count: 1024).write(to: vueroidH1Source.appendingPathComponent("EVENT/20260515_215208_EVT_N.mp4"))
            try Data(repeating: 33, count: 1024).write(to: vueroidH1Source.appendingPathComponent("PARK/20260609_163241_PRK_N.mp4"))
            try Data(repeating: 34, count: 1024).write(to: vueroidH1Source.appendingPathComponent("PEVENT/20260609_163325_PVT_N.mp4"))
            try Data(repeating: 35, count: 1024).write(to: vueroidH1Source.appendingPathComponent("USER/20260609_163354_USR_N.mp4"))

            let vueroidH1Scan = try scanner.scan(sourceURL: vueroidH1Source, profiles: profiles)
            guard vueroidH1Scan.candidates.first?.profile.id == "vueroid-h1" else {
                print("VERIFY FAIL: Vueroid H1 was not top candidate: \(vueroidH1Scan.candidates.prefix(3).map { "\($0.profile.id)=\($0.score)" })")
                return false
            }
            guard vueroidH1Scan.candidates.first?.confidence == .high else {
                print("VERIFY FAIL: Vueroid H1 did not score high confidence")
                return false
            }
            let h1DownloadableClips = vueroidH1Scan.clips.filter { $0.excludedReason == nil }
            guard Set(h1DownloadableClips.map(\.channel)) == ["front"] else {
                print("VERIFY FAIL: Vueroid H1 should be front-only: selected \(vueroidH1Scan.selectedProfile?.id ?? "nil"), candidates \(vueroidH1Scan.candidates.prefix(3).map { "\($0.profile.id)=\($0.score):\($0.evidence.joined(separator: "|"))" }), channels \(Set(h1DownloadableClips.map(\.channel)).sorted())")
                return false
            }
            let h1CategoryCounts = Dictionary(grouping: h1DownloadableClips, by: \.outputCategory).mapValues(\.count)
            guard h1CategoryCounts["Driving"] == 1,
                  h1CategoryCounts["Protected"] == 1,
                  h1CategoryCounts["Parking"] == 1,
                  h1CategoryCounts["Parking Events"] == 1,
                  h1CategoryCounts["Other"] == 1 else {
                print("VERIFY FAIL: Vueroid H1 output groups wrong: \(h1CategoryCounts)")
                return false
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

    private static func createSparseFile(at url: URL, size: UInt64) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: size)
        try handle.close()
    }
}
