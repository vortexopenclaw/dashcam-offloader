import Foundation

struct DashcamProfile: Identifiable, Hashable, Sendable {
    var id: String
    var manufacturer: String
    var model: String
    var status: String
    var confidence: String
    var folders: [ProfileFolder]
    var filenamePatterns: [FilenamePattern]
    var channels: [String: String]
    var highConfidencePaths: [String]

    var displayName: String {
        "\(manufacturer) \(model)"
    }
}

struct ProfileFolder: Hashable, Sendable {
    var path: String
    var mode: String
    var importable: Bool
}

struct FilenamePattern: Hashable, Sendable {
    var rawPattern: String
    var regexPattern: String
    var modeMap: [String: String]
    var channelMap: [String: String]
    var timestampFormat: TimestampFormat
}

enum TimestampFormat: Hashable, Sendable {
    case yyyymmddHhmmss
    case yyyyMmddHhmmss
    case yyyymmddDashHhmmss
    case unknown
}

struct MountedSource: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    var url: URL
    var name: String

    var displayPath: String {
        url.path
    }
}

struct DetectionCandidate: Identifiable, Hashable, Sendable {
    var id: String { profile.id }
    var profile: DashcamProfile
    var score: Int
    var confidence: DetectionConfidence
    var evidence: [String]
}

enum DetectionConfidence: String, CaseIterable, Hashable, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case none = "None"
}

struct ClipItem: Identifiable, Hashable, Sendable {
    var id: String { sourceURL.path }
    var sourceURL: URL
    var relativePath: String
    var filename: String
    var mode: String
    var channel: String
    var timestamp: Date?
    var size: Int64
    var extensionLowercased: String
    var excludedReason: String?

    var isVideo: Bool {
        ["mp4", "mov"].contains(extensionLowercased)
    }

    var isPhoto: Bool {
        ["jpg", "jpeg"].contains(extensionLowercased)
    }

    var isGPS: Bool {
        ["dat", "gpx", "nmea"].contains(extensionLowercased) || mode == "gps"
    }
}

struct CopyPlan: Hashable, Sendable {
    var sourceRoot: URL
    var destinationRoot: URL
    var profile: DashcamProfile
    var clips: [ClipItem]
    var items: [CopyPlanItem]

    var selectedBytes: Int64 {
        items.reduce(0) { $0 + $1.clip.size }
    }
}

struct CopyPlanItem: Identifiable, Hashable, Sendable {
    var id: String { clip.id }
    var clip: ClipItem
    var destinationURL: URL
    var status: CopyStatus
    var message: String?
}

enum CopyStatus: String, Hashable, Sendable {
    case planned
    case copied
    case skipped
    case failed
}

struct CopyProgress: Hashable, Sendable {
    var totalBytes: Int64 = 0
    var copiedBytes: Int64 = 0
    var totalFiles: Int = 0
    var completedFiles: Int = 0
    var currentFile: String = ""
    var isRunning: Bool = false
    var summary: String = ""

    var fraction: Double {
        guard totalBytes > 0 else { return completedFiles > 0 ? 1 : 0 }
        return min(1, max(0, Double(copiedBytes) / Double(totalBytes)))
    }

    var percentText: String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

struct FilterState: Hashable, Sendable {
    var selectedModes: Set<String> = []
    var selectedChannels: Set<String> = []
    var useStartDate: Bool = false
    var useEndDate: Bool = false
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var endDate: Date = Date()
    var includePhotos: Bool = false
    var includeGPS: Bool = false
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
