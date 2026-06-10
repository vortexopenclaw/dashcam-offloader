@preconcurrency import AppKit
import CryptoKit
import Foundation

struct AppBuildInfo: Equatable, Sendable {
    var version: String
    var build: String
    var commit: String

    var displayString: String {
        [version, build, commit].filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func current(bundle: Bundle = .main) -> AppBuildInfo {
        AppBuildInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            commit: bundle.object(forInfoDictionaryKey: "DashcamOffloaderBuildCommit") as? String ?? ""
        )
    }
}

struct AppUpdateManifest: Codable, Equatable, Sendable {
    var version: String
    var build: String
    var releaseName: String?
    var releaseNotesURL: URL?
    var assetName: String?
    var assetKey: String?
    var downloadURL: URL
    var sha256: String?
    var minimumMacOSVersion: String?
    var publishedAt: String?
    var channel: String?

    var displayName: String {
        releaseName ?? "Dashcam Offloader \(version) (\(build))"
    }
}

enum UpdateInstallMode: Sendable {
    case installAndRelaunch
    case revealDownloadedApp
}

enum UpdateServiceError: LocalizedError {
    case currentAppBundleUnavailable
    case invalidManifestResponse
    case invalidDownloadResponse
    case checksumMismatch(expected: String, actual: String)
    case updateAppNotFound
    case installerLaunchFailed

    var errorDescription: String? {
        switch self {
        case .currentAppBundleUnavailable:
            return "This build is not running from a macOS app bundle."
        case .invalidManifestResponse:
            return "The update server did not return a valid update manifest."
        case .invalidDownloadResponse:
            return "The update download failed."
        case let .checksumMismatch(expected, actual):
            return "The downloaded update did not match the expected checksum. Expected \(expected), got \(actual)."
        case .updateAppNotFound:
            return "The downloaded update did not contain Dashcam Offloader.app."
        case .installerLaunchFailed:
            return "The updater could not launch the installer."
        }
    }
}

struct UpdateService: @unchecked Sendable {
    static let production = UpdateService()
    static let defaultManifestURL = URL(string: "https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/latest.json")!

    var manifestURL: URL = defaultManifestURL
    var session: URLSession = .shared
    var fileManager: FileManager = .default
    var currentBuild: AppBuildInfo = .current()
    var currentBundleURL: URL = Bundle.main.bundleURL

    func fetchManifest() async throws -> AppUpdateManifest {
        let (data, response) = try await session.data(from: manifestURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateServiceError.invalidManifestResponse
        }
        return try JSONDecoder().decode(AppUpdateManifest.self, from: data)
    }

    func isUpdateAvailable(_ manifest: AppUpdateManifest) -> Bool {
        Self.isUpdateAvailable(manifest: manifest, currentBuild: currentBuild)
    }

    static func isUpdateAvailable(manifest: AppUpdateManifest, currentBuild: AppBuildInfo) -> Bool {
        let remoteBuild = manifest.build.trimmingCharacters(in: .whitespacesAndNewlines)
        let localCommit = currentBuild.commit.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remoteBuild.isEmpty, !localCommit.isEmpty {
            return remoteBuild != localCommit
        }

        let remoteVersion = manifest.version.trimmingCharacters(in: .whitespacesAndNewlines)
        let localVersion = currentBuild.version.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remoteVersion.isEmpty, !localVersion.isEmpty {
            return remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending
        }

        return !remoteBuild.isEmpty
    }

    func downloadAndStageUpdate(_ manifest: AppUpdateManifest) async throws -> URL {
        let (downloadedURL, response) = try await session.download(from: manifest.downloadURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateServiceError.invalidDownloadResponse
        }

        let stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("dashcam-offloader-update-\(UUID().uuidString)", isDirectory: true)
        let zipURL = stagingRoot.appendingPathComponent(manifest.assetName ?? "Dashcam-Offloader.zip")
        let extractedURL = stagingRoot.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        try fileManager.moveItem(at: downloadedURL, to: zipURL)

        if let expected = manifest.sha256?.lowercased(), !expected.isEmpty {
            let actual = try sha256Hex(for: zipURL)
            guard actual == expected else {
                throw UpdateServiceError.checksumMismatch(expected: expected, actual: actual)
            }
        }

        try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, extractedURL.path])

        let appURL = extractedURL.appendingPathComponent("Dashcam Offloader.app", isDirectory: true)
        guard fileManager.fileExists(atPath: appURL.path) else {
            throw UpdateServiceError.updateAppNotFound
        }
        return appURL
    }

    func installStagedUpdate(_ stagedAppURL: URL) throws -> UpdateInstallMode {
        guard currentBundleURL.pathExtension == "app",
              fileManager.fileExists(atPath: currentBundleURL.path) else {
            NSWorkspace.shared.activateFileViewerSelecting([stagedAppURL])
            return .revealDownloadedApp
        }

        let installerScript = stagedAppURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("install-update.sh")
        let script = """
        #!/bin/sh
        set -eu
        sleep 1
        rm -rf "\(shellEscapedPath(currentBundleURL.path))"
        /usr/bin/ditto "\(shellEscapedPath(stagedAppURL.path))" "\(shellEscapedPath(currentBundleURL.path))"
        /usr/bin/open "\(shellEscapedPath(currentBundleURL.path))"
        rm -rf "\(shellEscapedPath(stagedAppURL.deletingLastPathComponent().deletingLastPathComponent().path))"
        """

        try script.write(to: installerScript, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installerScript.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [installerScript.path]
        do {
            try process.run()
        } catch {
            throw UpdateServiceError.installerLaunchFailed
        }
        return .installAndRelaunch
    }

    private func sha256Hex(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func runProcess(_ path: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw UpdateServiceError.invalidDownloadResponse
        }
    }

    private func shellEscapedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
