import SwiftUI

@main
struct DashcamOffloaderApp: App {
    init() {
        if CommandLine.arguments.contains("--osd-probe") {
            let result = OSDDiagnostic.run(arguments: CommandLine.arguments)
            Foundation.exit(result ? 0 : 1)
        }
        if CommandLine.arguments.contains("--scan-source") {
            let result = ScanDiagnostic.run(arguments: CommandLine.arguments)
            Foundation.exit(result ? 0 : 1)
        }
        if CommandLine.arguments.contains("--probe-video-specs") {
            let result = VideoSpecDiagnostic.run(arguments: CommandLine.arguments)
            Foundation.exit(result ? 0 : 1)
        }
        if CommandLine.arguments.contains("--smoke-test") {
            let result = SmokeTest.run()
            Foundation.exit(result ? 0 : 1)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: TransferViewModel())
                .frame(minWidth: 1180, minHeight: 720)
        }
        .windowStyle(.titleBar)
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
            guard let selected = result.selectedProfile else {
                if let identified = result.identifiedCamera {
                    print("SCAN NEW_DASHCAM: \(identified.displayName) supported \(identified.isSupported)")
                    for diagnostic in result.diagnostics {
                        let profile = diagnostic.profileID ?? "none"
                        print("SCAN DIAGNOSTIC: \(diagnostic.stage) \(profile) \(diagnostic.outcome) - \(diagnostic.detail)")
                    }
                    return true
                }
                print("SCAN FAIL: no selected profile")
                return false
            }

            let confidence = result.candidates.first?.confidence.rawValue ?? "None"
            let score = result.candidates.first?.score ?? 0
            let evidence = result.candidates.first?.evidence.joined(separator: "; ") ?? ""
            print("SCAN PASS: \(selected.id) \(confidence) score \(score)")
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

enum VideoSpecDiagnostic {
    static func run(arguments: [String]) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let state = VideoSpecDiagnosticState()
        Task.detached {
            state.result = await runAsync(arguments: arguments)
            semaphore.signal()
        }
        semaphore.wait()
        return state.result
    }

    private static func runAsync(arguments: [String]) async -> Bool {
        guard let commandIndex = arguments.firstIndex(of: "--probe-video-specs"),
              arguments.count > commandIndex + 1 else {
            print("VIDEO SPECS FAIL: usage --probe-video-specs <source-path>")
            return false
        }

        let sourceURL = URL(fileURLWithPath: arguments[commandIndex + 1], isDirectory: true)
        guard let profilesDirectory = ProfileStore.defaultProfilesDirectory() else {
            print("VIDEO SPECS FAIL: profiles directory unavailable")
            return false
        }

        do {
            let profiles = try ProfileStore(profilesDirectory: profilesDirectory).loadProfiles()
            let scan = try CardScanner().scanWithOSD(sourceURL: sourceURL, profiles: profiles)
            let clips = scan.clips.filter { $0.excludedReason == nil && $0.isVideo }
            let samples = await VideoMetadataProbe().probe(clips: clips, sourceRoot: sourceURL)
            guard !samples.isEmpty else {
                print("VIDEO SPECS FAIL: no video specs found")
                return false
            }

            print("VIDEO SPECS PASS: \(samples.count) samples")
            for sample in samples {
                print("VIDEO SPECS SAMPLE: \(sample.channel) \(sample.mode) \(sample.codec) \(sample.dimensionsText) \(sample.frameRateText) \(sample.bitrateText) \(sample.relativePath)")
            }
            return true
        } catch {
            print("VIDEO SPECS FAIL: \(error.localizedDescription)")
            return false
        }
    }
}

private final class VideoSpecDiagnosticState: @unchecked Sendable {
    var result = false
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
