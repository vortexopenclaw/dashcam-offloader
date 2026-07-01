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
    var releaseNotes: String?
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

    var releaseNotesSummary: String? {
        guard let releaseNotes else { return nil }
        let trimmedNotes = releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else { return nil }

        let lines = trimmedNotes.components(separatedBy: .newlines)
        let cleanedLines = lines.drop { line in
            let normalizedLine = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "\u{2019}", with: "'")
            return normalizedLine.isEmpty || normalizedLine == "what's new"
        }
        let cleanedNotes = cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedNotes.isEmpty ? nil : cleanedNotes
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
    case manifestMissingChecksum
    case checksumMismatch(expected: String, actual: String)
    case updateExtractionFailed
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
        case .manifestMissingChecksum:
            return "The update could not be verified because the update manifest is missing its checksum."
        case let .checksumMismatch(expected, actual):
            return "The downloaded update did not match the expected checksum. Expected \(expected), got \(actual)."
        case .updateExtractionFailed:
            return "The downloaded update could not be unpacked."
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

    static func requiredChecksum(for manifest: AppUpdateManifest) throws -> String {
        let value = manifest.sha256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !value.isEmpty else {
            throw UpdateServiceError.manifestMissingChecksum
        }
        return value
    }

    func downloadAndStageUpdate(_ manifest: AppUpdateManifest) async throws -> URL {
        let expectedChecksum = try Self.requiredChecksum(for: manifest)

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

        let actualChecksum = try sha256Hex(for: zipURL)
        guard actualChecksum == expectedChecksum else {
            throw UpdateServiceError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
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
        guard let installTargetURL = Self.installTargetBundleURL(
            currentBundleURL: currentBundleURL,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            fileExists: { fileManager.fileExists(atPath: $0) },
            isWritableDirectory: { fileManager.isWritableFile(atPath: $0) },
            applicationURLForBundleIdentifier: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        ) else {
            NSWorkspace.shared.activateFileViewerSelecting([stagedAppURL])
            return .revealDownloadedApp
        }

        let installerScript = stagedAppURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("install-update.sh")
        let script = Self.installerScript(
            stagedAppPath: stagedAppURL.path,
            currentAppPath: installTargetURL.path,
            stagingRootPath: stagedAppURL.deletingLastPathComponent().deletingLastPathComponent().path,
            currentProcessID: ProcessInfo.processInfo.processIdentifier
        )

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

    static func installTargetBundleURL(
        currentBundleURL: URL,
        bundleIdentifier: String?,
        fileExists: (String) -> Bool,
        isWritableDirectory: (String) -> Bool,
        applicationURLForBundleIdentifier: (String) -> URL?
    ) -> URL? {
        let currentURL = currentBundleURL.standardizedFileURL
        if isUsableInstallTarget(currentURL, fileExists: fileExists, isWritableDirectory: isWritableDirectory),
           !isLikelyAppTranslocationURL(currentURL) {
            return currentURL
        }

        guard isLikelyAppTranslocationURL(currentURL),
              let bundleIdentifier,
              let workspaceURL = applicationURLForBundleIdentifier(bundleIdentifier)?.standardizedFileURL,
              workspaceURL.path != currentURL.path,
              isUsableInstallTarget(workspaceURL, fileExists: fileExists, isWritableDirectory: isWritableDirectory) else {
            return nil
        }

        return workspaceURL
    }

    private static func isUsableInstallTarget(
        _ url: URL,
        fileExists: (String) -> Bool,
        isWritableDirectory: (String) -> Bool
    ) -> Bool {
        guard url.pathExtension == "app",
              fileExists(url.path) else {
            return false
        }
        let parent = url.deletingLastPathComponent()
        return fileExists(parent.path) && isWritableDirectory(parent.path)
    }

    private static func isLikelyAppTranslocationURL(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.contains("/AppTranslocation/")
    }

    static func installerScript(
        stagedAppPath: String,
        currentAppPath: String,
        stagingRootPath: String,
        currentProcessID: Int32
    ) -> String {
        let staged = shellSingleQuoted(stagedAppPath)
        let current = shellSingleQuoted(currentAppPath)
        let stagingRoot = shellSingleQuoted(stagingRootPath)
        return """
        #!/bin/sh
        set -eu

        STAGED_APP=\(staged)
        CURRENT_APP=\(current)
        STAGING_ROOT=\(stagingRoot)
        CURRENT_PID=\(currentProcessID)

        i=0
        while kill -0 "$CURRENT_PID" 2>/dev/null && [ "$i" -lt 240 ]; do
          i=$((i + 1))
          sleep 0.25
        done

        if kill -0 "$CURRENT_PID" 2>/dev/null; then
          /usr/bin/open -R "$STAGED_APP"
          exit 70
        fi

        CURRENT_PARENT="$(/usr/bin/dirname "$CURRENT_APP")"
        if [ ! -d "$CURRENT_PARENT" ] || [ ! -w "$CURRENT_PARENT" ]; then
          /usr/bin/open -R "$STAGED_APP"
          exit 71
        fi

        BACKUP_APP="$CURRENT_APP.previous-update"
        rm -rf "$BACKUP_APP"
        if [ -e "$CURRENT_APP" ]; then
          mv "$CURRENT_APP" "$BACKUP_APP"
        fi

        if ! /usr/bin/ditto "$STAGED_APP" "$CURRENT_APP"; then
          rm -rf "$CURRENT_APP"
          if [ -e "$BACKUP_APP" ]; then
            mv "$BACKUP_APP" "$CURRENT_APP"
          fi
          /usr/bin/open -R "$STAGED_APP"
          exit 72
        fi

        /usr/bin/xattr -dr com.apple.quarantine "$CURRENT_APP" 2>/dev/null || true
        /usr/bin/open -n "$CURRENT_APP"
        rm -rf "$BACKUP_APP"
        rm -rf "$STAGING_ROOT"
        """
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
            throw UpdateServiceError.updateExtractionFailed
        }
    }

    private static func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
