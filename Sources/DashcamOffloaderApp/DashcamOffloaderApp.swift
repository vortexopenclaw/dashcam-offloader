import AppKit
import SwiftUI

@main
struct DashcamOffloaderApp: App {
    init() {
        if CommandLine.arguments.contains("--verify-update-manifest") {
            let result = UpdateManifestDiagnostic.run(arguments: CommandLine.arguments)
            Foundation.exit(result ? 0 : 1)
        }
        if CommandLine.arguments.contains("--osd-probe") {
            let result = OSDDiagnostic.run(arguments: CommandLine.arguments)
            Foundation.exit(result ? 0 : 1)
        }
        if CommandLine.arguments.contains("--scan-source") {
            let result = ScanDiagnostic.run(arguments: CommandLine.arguments)
            Foundation.exit(result ? 0 : 1)
        }
        if CommandLine.arguments.contains("--verify") || CommandLine.arguments.contains("--smoke-test") {
            guard VerificationTest.run() && UpdateChecksumVerification.run() else {
                Foundation.exit(1)
            }
            Task {
                let result = await CopyExecutorVerification.run()
                Foundation.exit(result ? 0 : 1)
            }
            RunLoop.current.run()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: TransferViewModel())
                .frame(minWidth: 1180, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Dashcam Offloader") {
                    NSApp.orderFrontStandardAboutPanel(options: [:])
                }
            }
        }
    }
}

enum UpdateManifestDiagnostic {
    static func run(arguments: [String]) -> Bool {
        guard let commandIndex = arguments.firstIndex(of: "--verify-update-manifest"),
              arguments.count > commandIndex + 1 else {
            print("UPDATE MANIFEST FAIL: usage --verify-update-manifest <manifest-path>")
            return false
        }

        do {
            let manifestURL = URL(fileURLWithPath: arguments[commandIndex + 1])
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(AppUpdateManifest.self, from: data)
            let validated = try UpdateService.validatedManifest(manifest)
            guard UpdateService.manifestMatchesPackagedBuild(
                validated,
                bundleIdentifier: Bundle.main.bundleIdentifier,
                currentBuild: .current()
            ) else {
                print("UPDATE MANIFEST FAIL: manifest does not match the packaged app")
                return false
            }
            print("UPDATE MANIFEST PASS")
            return true
        } catch {
            print("UPDATE MANIFEST FAIL: \(error.localizedDescription)")
            return false
        }
    }
}

enum ScanDiagnostic {
    static func run(arguments: [String]) -> Bool {
        guard let commandIndex = arguments.firstIndex(of: "--scan-source"),
              arguments.count > commandIndex + 1 else {
            print("SCAN FAIL: usage --scan-source <source-path>")
            return false
        }

        let sourceURL = URL(fileURLWithPath: arguments[commandIndex + 1], isDirectory: true)
        guard let profilesDirectory = ProfileStore.defaultProfilesDirectory() else {
            print("SCAN FAIL: profiles directory unavailable")
            return false
        }

        do {
            let profiles = try ProfileStore(profilesDirectory: profilesDirectory).loadProfiles()
            let result = try CardScanner().scanWithOSD(sourceURL: sourceURL, profiles: profiles)
            let selected = result.selectedProfile ?? .genericNewDashcam

            let confidence = result.candidates.first?.confidence.rawValue ?? "None"
            let score = result.candidates.first?.score ?? 0
            let evidence = result.candidates.first?.evidence.joined(separator: "; ") ?? ""
            print("SCAN PASS: \(selected.id) \(confidence) score \(score)")
            if let identified = result.identifiedCamera {
                print("SCAN IDENTIFIED: \(identified.displayName) supported=\(identified.isSupported)")
            }
            print("SCAN FILES: \(result.allFiles.count) files, \(result.clips.filter { $0.excludedReason == nil }.count) importable")
            if !evidence.isEmpty {
                print("SCAN EVIDENCE: \(evidence)")
            }
            for diagnostic in result.diagnostics {
                let profile = diagnostic.profileID ?? "none"
                print("SCAN DIAGNOSTIC: \(diagnostic.stage) \(profile) \(diagnostic.outcome) - \(diagnostic.detail)")
            }
            return true
        } catch {
            print("SCAN FAIL: \(error.localizedDescription)")
            return false
        }
    }
}

enum OSDDiagnostic {
    static func run(arguments: [String]) -> Bool {
        guard let commandIndex = arguments.firstIndex(of: "--osd-probe"),
              arguments.count > commandIndex + 2 else {
            print("OSD FAIL: usage --osd-probe <profile-id> <video-path>")
            return false
        }

        let profileID = arguments[commandIndex + 1]
        let videoURL = URL(fileURLWithPath: arguments[commandIndex + 2])

        guard let profilesDirectory = ProfileStore.defaultProfilesDirectory() else {
            print("OSD FAIL: profiles directory unavailable")
            return false
        }

        do {
            let profiles = try ProfileStore(profilesDirectory: profilesDirectory).loadProfiles()
            guard let profile = profiles.first(where: { $0.id == profileID }) else {
                print("OSD FAIL: profile \(profileID) unavailable")
                return false
            }
            guard let spec = profile.osdSpec else {
                print("OSD FAIL: profile \(profileID) has no OSD spec")
                return false
            }
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                print("OSD FAIL: video unavailable")
                return false
            }

            let matched = OSDProbe().probe(videoURL: videoURL, spec: spec)

            if let matched {
                print("OSD PASS: \(profileID) matched \(matched)")
                return true
            }

            print("OSD FAIL: \(profileID) no model match")
            return false
        } catch {
            print("OSD FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
