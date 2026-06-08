import AppKit
import Foundation

struct AppUpdateInfo: Hashable, Sendable {
    var currentVersion: String
    var latestVersion: String
    var releaseName: String
    var releasePageURL: URL
    var assetName: String?
    var assetDownloadURL: URL?
    var isNewer: Bool

    var primaryActionTitle: String {
        assetDownloadURL == nil ? "Open Release Page" : "Download and Install"
    }
}

enum UpdateServiceError: LocalizedError {
    case noDownloadAsset
    case invalidDownloadsDirectory

    var errorDescription: String? {
        switch self {
        case .noDownloadAsset:
            return "The latest release does not include a downloadable app asset."
        case .invalidDownloadsDirectory:
            return "Could not find the Downloads folder."
        }
    }
}

struct UpdateService: Sendable {
    private struct GitHubRelease: Decodable, Sendable {
        var tagName: String
        var name: String?
        var htmlURL: URL
        var assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case assets
        }
    }

    private struct GitHubAsset: Decodable, Sendable {
        var name: String
        var browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    var latestReleaseURL = URL(string: "https://api.github.com/repos/vortexopenclaw/dashcam-offloader/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    func checkForUpdates(currentVersion: String = Self.currentVersion) async throws -> AppUpdateInfo {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("DashcamOffloader", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            throw NSError(
                domain: "DashcamOffloader.UpdateService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No GitHub release has been published yet."]
            )
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return Self.info(from: release, currentVersion: currentVersion)
    }

    func downloadReleaseAsset(_ update: AppUpdateInfo) async throws -> URL {
        guard let assetURL = update.assetDownloadURL, let assetName = update.assetName else {
            throw UpdateServiceError.noDownloadAsset
        }

        let (temporaryURL, _) = try await URLSession.shared.download(from: assetURL)
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw UpdateServiceError.invalidDownloadsDirectory
        }

        let safeName = assetName.replacingOccurrences(of: "/", with: "-")
        let destinationURL = downloadsURL.appendingPathComponent(safeName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    static func info(from releaseJSON: Data, currentVersion: String) throws -> AppUpdateInfo {
        let release = try JSONDecoder().decode(GitHubRelease.self, from: releaseJSON)
        return info(from: release, currentVersion: currentVersion)
    }

    private static func info(from release: GitHubRelease, currentVersion: String) -> AppUpdateInfo {
        let latestVersion = normalizedVersion(release.tagName)
        let preferredAsset = release.assets.first { asset in
            let lower = asset.name.lowercased()
            return lower.hasSuffix(".dmg") || lower.hasSuffix(".zip")
        } ?? release.assets.first

        return AppUpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseName: release.name ?? release.tagName,
            releasePageURL: release.htmlURL,
            assetName: preferredAsset?.name,
            assetDownloadURL: preferredAsset?.browserDownloadURL,
            isNewer: compareVersions(latestVersion, currentVersion) == .orderedDescending
        )
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftParts = normalizedVersion(lhs).split(separator: ".").map { Int($0) ?? 0 }
        let rightParts = normalizedVersion(rhs).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(leftParts.count, rightParts.count)

        for index in 0..<count {
            let left = index < leftParts.count ? leftParts[index] : 0
            let right = index < rightParts.count ? rightParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func normalizedVersion(_ version: String) -> String {
        String(version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v"))
    }
}

@MainActor
final class UpdateViewModel: ObservableObject {
    @Published var info: AppUpdateInfo?
    @Published var statusMessage: String
    @Published var isChecking = false
    @Published var isDownloading = false

    private let service = UpdateService()

    init() {
        statusMessage = "Current version \(UpdateService.currentVersion)"
    }

    func checkForUpdates() {
        isChecking = true
        statusMessage = "Checking GitHub Releases..."

        Task {
            do {
                let updateInfo = try await service.checkForUpdates()
                info = updateInfo
                if updateInfo.isNewer {
                    statusMessage = "Version \(updateInfo.latestVersion) is available."
                } else {
                    statusMessage = "You are on the latest version."
                }
            } catch {
                statusMessage = "Update check failed: \(error.localizedDescription)"
            }
            isChecking = false
        }
    }

    func openReleasePage() {
        guard let info else { return }
        NSWorkspace.shared.open(info.releasePageURL)
    }

    func downloadAndInstall() {
        guard let info else { return }
        guard info.assetDownloadURL != nil else {
            openReleasePage()
            return
        }

        isDownloading = true
        statusMessage = "Downloading \(info.assetName ?? "latest release")..."

        Task {
            do {
                let downloadedURL = try await service.downloadReleaseAsset(info)
                NSWorkspace.shared.open(downloadedURL)
                statusMessage = "Downloaded \(downloadedURL.lastPathComponent). The installer is open."
            } catch {
                statusMessage = "Download failed: \(error.localizedDescription)"
            }
            isDownloading = false
        }
    }
}
