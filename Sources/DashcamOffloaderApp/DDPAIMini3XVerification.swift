import Foundation

/// Synthetic fixtures only. No mounted card or network access.
enum DDPAIMini3XVerification {
    static func run(profiles: [DashcamProfile]) -> Bool {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: fm.currentDirectoryPath).resolvingSymlinksInPath().appendingPathComponent("mini3x-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        do {
            guard let profile = profiles.first(where: { $0.id == "ddpai-mini3x" }),
                  profile.displayName == "DDPAI MINI3X",
                  profile.folders.first(where: { $0.path == "DCIM/202thumb" })?.importable == false,
                  profile.folders.first(where: { $0.path == "DCIM/207log" })?.importable == false else { print("MINI3X FAIL at line \(#line)"); return false }
            let video = root.appendingPathComponent("DCIM/200video/20300101120000_000.mp4")
            let log = root.appendingPathComponent("DCIM/207log/20300101120000_000.log")
            try fm.createDirectory(at: video.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([0, 0, 0, 24] + Array("ftypisom".utf8)).write(to: video)
            func record(_ sku: String) -> String {
                "WEBGetProductInfo:pJsonData={\"model\":\"\(sku)\",\"version\":\"v9.0.1.10\"}\n"
            }
            let known = record("DDPAI DM003_Overseas_V2")
            try Data(known.utf8).write(to: log)

            let scanner = CardScanner()
            let scan = try scanner.scan(sourceURL: root, profiles: profiles, allowNestedCardRootDiscovery: false)

            guard scan.selectedProfile?.id == profile.id,
                  scan.identifiedCamera?.model == "MINI3X",
                  scan.componentMetadata.entries.first?.firmwareVersion == "v9.0.1.10",
                  scan.clips.filter({ $0.isVideo }).allSatisfy({ $0.channel == "unknown" && $0.mode == "recording" && $0.outputCategory != "Driving" }) else { print("MINI3X FAIL at line \(#line)"); return false }
            for sku in ["DDPAI DM003_Overseas_V3", "DDPAI MINI3X", "DDPAI Synthetic", "DDPAI Z100 Pro"] {
                try Data(record(sku).utf8).write(to: log)
                let unknown = try scanner.scan(sourceURL: root, profiles: profiles, allowNestedCardRootDiscovery: false)
                guard unknown.selectedProfile?.id != profile.id,
                      unknown.clips.allSatisfy({ $0.channel != "telephoto" }) else { print("MINI3X FAIL at line \(#line)"); return false }
            }
            try Data((known + record("DDPAI Z100 Master")).utf8).write(to: log)
            guard try scanner.scan(sourceURL: root, profiles: profiles, allowNestedCardRootDiscovery: false).selectedProfile?.id != profile.id else { print("MINI3X FAIL at line \(#line)"); return false }
            try Data((known + "WEBGetProductInfo:pJsonData={bad}\n").utf8).write(to: log)
            guard try scanner.scan(sourceURL: root, profiles: profiles, allowNestedCardRootDiscovery: false).selectedProfile?.id != profile.id else { print("MINI3X FAIL at line \(#line)"); return false }
            try Data(known.utf8).write(to: log)
            let realLog = root.appendingPathComponent("real.log")
            try fm.moveItem(at: log, to: realLog)
            try fm.createSymbolicLink(at: log, withDestinationURL: realLog)
            guard try scanner.scan(sourceURL: root, profiles: profiles, allowNestedCardRootDiscovery: false).selectedProfile?.id != profile.id else { print("MINI3X FAIL at line \(#line)"); return false }
            try fm.removeItem(at: log)
            try fm.moveItem(at: realLog, to: log)
            let linkedRoot = root.appendingPathExtension("linked")
            try fm.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
            defer { try? fm.removeItem(at: linkedRoot) }
            guard DDPAIComponentMetadata.read(source: linkedRoot).exactLoggingModel == nil else { print("MINI3X FAIL at line \(#line)"); return false }
            // Shared inside folder is never a MINI3X telephoto/cabin hardcode.
            let inside = root.appendingPathComponent("DCIM/200video/inside/S_20300101120000.mp4")
            let clips = scanner.classify(files: [inside], sourceURL: root, profile: profile)
            guard clips.first?.channel == "unknown", clips.first?.mode == "recording" else { print("MINI3X FAIL at line \(#line)"); return false }
            print("MINI3X PASS: exact SKU, generic revision, unknown physical role/context, exclusions, unknown/sibling/conflict and symlink guards")
            return true
        } catch { print("MINI3X FAIL: \(error)"); return false }
    }
}
