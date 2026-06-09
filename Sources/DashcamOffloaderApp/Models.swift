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
    var highConfidenceEvidence: [ProfileEvidence]
    var osdSpec: OSDSpec?

    var displayName: String {
        "\(displayManufacturer) \(model)"
    }

    var displayManufacturer: String {
        switch manufacturer.lowercased() {
        case "viofo":
            return "Viofo"
        case "blackvue":
            return "BlackVue"
        case "70mai":
            return "70mai"
        case "new":
            return "New"
        default:
            return manufacturer.capitalized
        }
    }

    static let genericNewDashcam = DashcamProfile(
        id: "generic-new-dashcam",
        manufacturer: "New",
        model: "Dashcam",
        status: "generic",
        confidence: "low",
        folders: [],
        filenamePatterns: [],
        channels: [:],
        highConfidenceEvidence: [],
        osdSpec: nil
    )
}

struct ProfileEvidence: Hashable, Sendable {
    var path: String
    var contains: [String]
}

struct IdentifiedCamera: Codable, Hashable, Sendable {
    var manufacturer: String
    var model: String
    var evidence: [String]
    var isSupported: Bool

    var displayName: String {
        "\(displayManufacturer) \(model)"
    }

    var displayManufacturer: String {
        switch manufacturer.lowercased() {
        case "blackvue":
            return "BlackVue"
        case "viofo":
            return "Viofo"
        case "70mai":
            return "70mai"
        default:
            return manufacturer.capitalized
        }
    }
}

/// Describes the burned-in on-screen-display (OSD) model-name signal for a
/// profile. Some dashcams (notably VIOFO) stamp their model name into every
/// frame, which lets us disambiguate sibling models that are otherwise
/// identical by folder/filename structure.
struct OSDSpec: Hashable, Sendable {
    var containsModelName: Bool
    var matchStrings: [String]   // e.g. ["VIOFO A229 Pro"]
    var stripPercent: Double     // fraction of frame height from bottom, e.g. 0.08
    var probeChannels: [String]  // channel letters to try, e.g. ["F"] for front channel clips only
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

struct ScanDiagnosticEntry: Codable, Hashable, Sendable {
    var stage: String
    var profileID: String?
    var profileName: String?
    var outcome: String
    var detail: String
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
        ["mp4", "mov", "avi", "mkv", "ts", "m2ts", "mts", "3gp"].contains(extensionLowercased)
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
        if normalized.contains("parking_event") ||
            normalized.contains("parking event") ||
            normalized.contains("pevent") {
            return "Parking Events"
        }
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
            normalized.contains("continuous") ||
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
        switch value.lowercased() {
        case "continuous":
            return "Driving"
        case "driving_event":
            return "Driving Event"
        case "parking_event":
            return "Parking Event"
        case "parking_event_secondary":
            return "Parking Event"
        case "parking_motion_or_timelapse":
            return "Parking Motion Or Timelapse"
        case "in_cabin":
            return "Interior"
        case "front":
            return "Front"
        case "rear":
            return "Rear"
        case "interior":
            return "Interior"
        default:
            break
        }

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
    var supportItems: [SupportFileItem] = []

    var selectedBytes: Int64 {
        items.reduce(0) { $0 + $1.clip.size } + supportItems.reduce(0) { $0 + $1.size }
    }

    var selectedFileCount: Int {
        items.count + supportItems.count
    }
}

struct CopyPlanItem: Identifiable, Hashable, Sendable {
    var id: String { clip.id }
    var clip: ClipItem
    var destinationURL: URL
    var status: CopyStatus
    var message: String?
}

struct SupportFileItem: Identifiable, Hashable, Sendable {
    var id: String { "support:\(relativePath)" }
    var sourceURL: URL
    var relativePath: String
    var filename: String
    var size: Int64
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
    var startedAt: Date?
    var updatedAt: Date?

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

    var speedBytesPerSecond: Double {
        guard let startedAt else { return 0 }
        let referenceDate = updatedAt ?? Date()
        let elapsed = referenceDate.timeIntervalSince(startedAt)
        guard elapsed > 0.25, copiedBytes > 0 else { return 0 }
        return Double(copiedBytes) / elapsed
    }

    var speedText: String {
        guard isRunning, speedBytesPerSecond > 0 else { return "" }
        return String(format: "%.1f MB/s", speedBytesPerSecond / 1_000_000)
    }

    var estimatedRemainingSeconds: TimeInterval? {
        guard isRunning, totalBytes > 0 else { return nil }
        let speed = speedBytesPerSecond
        guard speed > 0 else { return nil }
        let remaining = max(0, totalBytes - copiedBytes)
        return TimeInterval(Double(remaining) / speed)
    }

    var estimatedRemainingText: String {
        guard let seconds = estimatedRemainingSeconds else { return "" }
        if seconds < 1 { return "ETA <1s" }

        let roundedSeconds = Int(seconds.rounded())
        if roundedSeconds < 60 {
            return "ETA \(roundedSeconds)s"
        }

        let minutes = roundedSeconds / 60
        let secondsRemainder = roundedSeconds % 60
        if minutes < 60 {
            return "ETA \(minutes)m \(secondsRemainder)s"
        }

        let hours = minutes / 60
        let minutesRemainder = minutes % 60
        return "ETA \(hours)h \(minutesRemainder)m"
    }
}

enum DateFilterPreset: String, CaseIterable, Identifiable, Sendable {
    case today
    case yesterday
    case lastWeek
    case allTime
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .lastWeek:
            return "Last week"
        case .allTime:
            return "All time"
        case .custom:
            return "Custom"
        }
    }
}

struct FilterState: Hashable, Sendable {
    var selectedModes: Set<String> = []
    var selectedChannels: Set<String> = []
    var datePreset: DateFilterPreset = .allTime
    var useStartDate: Bool = false
    var useEndDate: Bool = false
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var endDate: Date = Date()
    var includePhotos: Bool = false
    var includeGPS: Bool = false
    var includeCameraSettings: Bool = false
    var separateCategoryFolders: Bool = true
}

struct OutputNamingOptions: Hashable, Sendable {
    var videoFilenameSuffix: String = ""
}

struct ScanSummary: Hashable, Sendable {
    var sourcePath: String = ""
    var scannedFiles: Int = 0
    var copyableItems: Int = 0
    var excludedItems: Int = 0
    var samplePaths: [String] = []
    var categoryCounts: [String: Int] = [:]
    var modeCounts: [String: Int] = [:]
    var identifiedCamera: IdentifiedCamera?
    var videoSpecSamples: [VideoSpecSnapshot] = []

    var hasScan: Bool {
        !sourcePath.isEmpty
    }

    var sortedCategoryCounts: [(String, Int)] {
        let preferredOrder = ["Driving", "Parking", "Parking Events", "Protected", "Photos", "GPS Logs", "Other"]
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

enum FeedbackKind: String, CaseIterable, Codable, Hashable, Sendable {
    case bug
    case feature
    case training
    case other

    static var generalFeedbackCases: [FeedbackKind] {
        [.bug, .feature, .other]
    }

    var displayName: String {
        switch self {
        case .bug:
            return "Bug Report"
        case .feature:
            return "Feature Request"
        case .training:
            return "Card Learning"
        case .other:
            return "Other Feedback"
        }
    }
}

struct FeedbackSubmission: Codable, Hashable, Sendable {
    var kind: FeedbackKind
    var message: String
    var contact: String
    var appVersion: String
    var createdAt: String
    var training: CardTrainingDetails?
    var scan: FeedbackScanSnapshot?
}

struct CardTrainingDetails: Codable, Hashable, Sendable {
    var manufacturer: String
    var model: String
    var channelSetup: String
    var notes: String
}

struct FeedbackScanSnapshot: Codable, Hashable, Sendable {
    var volumeName: String
    var identifiedCamera: IdentifiedCamera?
    var selectedProfileID: String?
    var selectedProfileName: String?
    var scannedFiles: Int
    var copyableItems: Int
    var excludedItems: Int
    var categoryCounts: [String: Int]
    var modeCounts: [String: Int]
    var extensionCounts: [String: Int]
    var sampleRelativePaths: [String]
    var rootFolders: [String]
    var folderSamples: [String]
    var filenameSamples: [String]
    var supportFileSamples: [String]
    var settingSnapshots: [FeedbackSettingSnapshot]
    var videoSpecSamples: [VideoSpecSnapshot]
    var candidates: [FeedbackCandidateSnapshot]
    var scanDiagnostics: [ScanDiagnosticEntry]
}

struct VideoSpecSnapshot: Codable, Hashable, Sendable, Identifiable {
    var id: String { relativePath }
    var relativePath: String
    var mode: String
    var channel: String
    var codec: String
    var width: Int?
    var height: Int?
    var frameRate: Double?
    var bitrateMbps: Double?
    var durationSeconds: Double?
    var fileSize: Int64

    var dimensionsText: String {
        guard let width, let height else { return "unknown" }
        return "\(width)x\(height)"
    }

    var frameRateText: String {
        guard let frameRate else { return "unknown" }
        return String(format: "%.2g fps", frameRate)
    }

    var bitrateText: String {
        guard let bitrateMbps else { return "unknown" }
        return String(format: "%.1f Mbps", bitrateMbps)
    }

    var durationText: String {
        guard let durationSeconds else { return "unknown" }
        if durationSeconds < 60 {
            return String(format: "%.0fs", durationSeconds)
        }
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return "\(minutes)m \(seconds)s"
    }
}

struct FeedbackSettingSnapshot: Codable, Hashable, Sendable {
    var relativePath: String
    var keys: [String]
    var safeValues: [String: String]
}

struct FeedbackCandidateSnapshot: Codable, Hashable, Sendable {
    var profileID: String
    var profileName: String
    var score: Int
    var confidence: String
    var evidence: [String]
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Sequence where Element: Hashable {
    func uniquedPreservingOrder() -> [Element] {
        var seen: Set<Element> = []
        var result: [Element] = []
        for element in self where seen.insert(element).inserted {
            result.append(element)
        }
        return result
    }
}
