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
        "\(displayManufacturer) \(model)"
    }

    var displayManufacturer: String {
        switch manufacturer.lowercased() {
        case "viofo":
            return "Viofo"
        case "blackvue":
            return "Blackvue"
        case "70mai":
            return "70mai"
        default:
            return manufacturer.capitalized
        }
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

    var outputCategory: String {
        if isGPS { return "GPS Logs" }
        if isPhoto { return "Photos" }

        let normalized = mode.lowercased()
        if normalized.contains("event") ||
            normalized.contains("locked") ||
            normalized.contains("protected") ||
            normalized.contains("emergency") ||
            normalized == "e" {
            return "Protected"
        }
        if normalized.contains("parking") ||
            normalized.contains("motion") ||
            normalized.contains("lapse") ||
            normalized == "p" ||
            normalized == "t" {
            return "Parking"
        }
        if normalized.contains("normal") ||
            normalized.contains("driving") ||
            normalized == "n" {
            return "Driving"
        }
        return "Other"
    }

    var displayMode: String {
        Self.displayLabel(for: mode)
    }

    var displayChannel: String {
        Self.displayLabel(for: channel)
    }

    static func displayLabel(for value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return value }
        return normalized
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                if ["gps", "ir", "dms"].contains(lower) {
                    return lower.uppercased()
                }
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
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
        var percent = Int((fraction * 100).rounded())
        if isRunning && totalFiles > 0 && completedFiles < totalFiles {
            percent = min(percent, 99)
        }
        return "\(percent)%"
    }

    var filesText: String {
        guard totalFiles > 0 else { return "" }
        return "\(completedFiles) of \(totalFiles) files"
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
    var separateCategoryFolders: Bool = true
}

struct ScanSummary: Hashable, Sendable {
    var sourcePath: String = ""
    var scannedFiles: Int = 0
    var copyableItems: Int = 0
    var excludedItems: Int = 0
    var samplePaths: [String] = []
    var categoryCounts: [String: Int] = [:]
    var modeCounts: [String: Int] = [:]

    var hasScan: Bool {
        !sourcePath.isEmpty
    }

    var sortedCategoryCounts: [(String, Int)] {
        let preferredOrder = ["Driving", "Parking", "Protected", "Photos", "GPS Logs", "Other"]
        return categoryCounts.sorted { lhs, rhs in
            let lhsIndex = preferredOrder.firstIndex(of: lhs.0) ?? preferredOrder.count
            let rhsIndex = preferredOrder.firstIndex(of: rhs.0) ?? preferredOrder.count
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.0.localizedStandardCompare(rhs.0) == .orderedAscending
        }
    }

    var sortedModeCounts: [(String, Int)] {
        modeCounts.sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1 > rhs.1 }
            return lhs.0.localizedStandardCompare(rhs.0) == .orderedAscending
        }
    }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
