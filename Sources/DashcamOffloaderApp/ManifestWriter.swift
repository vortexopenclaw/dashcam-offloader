import Foundation

enum ManifestWriter {
    static func write(plan: CopyPlan, results: [CopyPlanItem], supportResults: [SupportFileItem] = []) throws {
        let manifestURL = plan.destinationRoot
            .appendingPathComponent("dashcam-offloader-manifests", isDirectory: true)
            .appendingPathComponent("manifest-\(timestampFormatter.string(from: Date())).json")

        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload = ManifestPayload(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            sourcePath: plan.sourceRoot.path,
            destinationPath: plan.destinationRoot.path,
            profileId: plan.profile.id,
            profileName: plan.profile.displayName,
            files: results.map {
                ManifestFile(
                    sourceRelativePath: $0.clip.relativePath,
                    destinationRelativePath: $0.destinationURL.relativePath(from: plan.destinationRoot),
                    size: $0.clip.size,
                    mode: $0.clip.mode,
                    channel: $0.clip.channel,
                    timestamp: $0.clip.timestamp.map { ISO8601DateFormatter().string(from: $0) },
                    timestampSource: $0.clip.timestampSource.rawValue,
                    timestampSuspect: $0.clip.hasSuspiciousTimestamp,
                    status: $0.status.rawValue,
                    message: $0.message
                )
            },
            supportFiles: supportResults.map {
                ManifestSupportFile(
                    sourceRelativePath: $0.relativePath,
                    destinationRelativePath: $0.destinationURL.relativePath(from: plan.destinationRoot),
                    size: $0.size,
                    status: $0.status.rawValue,
                    message: $0.message
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: manifestURL)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private struct ManifestPayload: Encodable {
    var generatedAt: String
    var sourcePath: String
    var destinationPath: String
    var profileId: String
    var profileName: String
    var files: [ManifestFile]
    var supportFiles: [ManifestSupportFile]
}

private struct ManifestFile: Encodable {
    var sourceRelativePath: String
    var destinationRelativePath: String
    var size: Int64
    var mode: String
    var channel: String
    var timestamp: String?
    var timestampSource: String
    var timestampSuspect: Bool
    var status: String
    var message: String?
}

private struct ManifestSupportFile: Encodable {
    var sourceRelativePath: String
    var destinationRelativePath: String
    var size: Int64
    var status: String
    var message: String?
}
