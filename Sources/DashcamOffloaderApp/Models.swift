import Foundation

enum ManufacturerDisplayFormatter {
    static func displayName(for manufacturer: String) -> String {
        switch manufacturer.lowercased() {
        case "viofo":
            return "Viofo"
        case "blackvue":
            return "Blackvue"
        case "dji":
            return "DJI"
        case "gopro":
            return "GoPro"
        case "thinkware":
            return "Thinkware"
        case "cansonic":
            return "Cansonic"
        case "70mai":
            return "70mai"
        case "new":
            return "New"
        default:
            return manufacturer.capitalized
        }
    }
}

struct DashcamProfile: Identifiable, Hashable, Sendable {
    var id: String
    var manufacturer: String
    var model: String
    var status: String
    var confidence: String
    var folders: [ProfileFolder]
    var filenamePatterns: [FilenamePattern]
    var channels: [String: String]
    var detectionRules: [DetectionRule]
    var disqualifyingRules: [DetectionRule]
    var osdSpec: OSDSpec?

    var displayName: String {
        "\(displayManufacturer) \(model)"
    }

    var displayManufacturer: String {
        ManufacturerDisplayFormatter.displayName(for: manufacturer)
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
        detectionRules: [],
        disqualifyingRules: [],
        osdSpec: nil
    )
}

struct DetectionRule: Hashable, Sendable {
    var path: String?
    var contains: String?
    var exists: Bool?
    var volumeLabel: String?
    var mustNotContain: String?
    var mustNotExist: Bool?
    var score: Int
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

enum TimestampSource: String, Hashable, Sendable {
    case filename
    case filesystemModified
    case filesystemCreated
    case none

    var displayName: String {
        switch self {
        case .filename:
            return "Filename"
        case .filesystemModified:
            return "File Modified Date"
        case .filesystemCreated:
            return "File Created Date"
        case .none:
            return "None"
        }
    }
}

enum ParkingPattern: String, Codable, Hashable, Sendable {
    case continuousLowBitrate = "continuous_low_bitrate"
    case timelapse = "timelapse"
    case motionDetection = "motion_detection"
    case impactDetection = "impact_detection"
    case motionOrImpact = "motion_or_impact"

    var displayName: String {
        switch self {
        case .continuousLowBitrate:
            return "Parking Continuous / Low Bitrate"
        case .timelapse:
            return "Parking Timelapse"
        case .motionDetection:
            return "Parking Motion Detection"
        case .impactDetection:
            return "Parking Impact Detection"
        case .motionOrImpact:
            return "Parking Motion / Impact"
        }
    }

    var modeValue: String {
        switch self {
        case .continuousLowBitrate:
            return "parking_continuous_low_bitrate"
        case .timelapse:
            return "parking_timelapse"
        case .motionDetection:
            return "parking_motion_detection"
        case .impactDetection:
            return "parking_impact_detection"
        case .motionOrImpact:
            return "parking_motion_or_impact"
        }
    }
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

struct IdentifiedCamera: Codable, Hashable, Sendable {
    var manufacturer: String
    var model: String
    var evidence: [String]
    var isSupported: Bool

    var displayName: String {
        "\(displayManufacturer) \(model)"
    }

    var displayManufacturer: String {
        ManufacturerDisplayFormatter.displayName(for: manufacturer)
    }
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
    static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mts", "m2ts", "ts", "mkv", "3gp"]
    static let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "bmp", "gpr"]
    static let gpsExtensions: Set<String> = ["dat", "gpx", "nmea"]

    var id: String { sourceURL.path }
    var sourceURL: URL
    var relativePath: String
    var filename: String
    var mode: String
    var channel: String
    var timestamp: Date?
    var timestampSource: TimestampSource = .none
    var size: Int64
    var extensionLowercased: String
    var excludedReason: String?
    var inferredParkingPattern: ParkingPattern?

    var isVideo: Bool {
        Self.videoExtensions.contains(extensionLowercased)
    }

    var isPhoto: Bool {
        Self.photoExtensions.contains(extensionLowercased)
    }

    var isGPS: Bool {
        Self.gpsExtensions.contains(extensionLowercased) || mode == "gps"
    }

    var hasSuspiciousTimestamp: Bool {
        guard let timestamp else { return false }
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: timestamp)
        let currentYear = calendar.component(.year, from: Date())
        return year < 2016 || year > currentYear + 1
    }

    var canUseTimestampForDateFiltering: Bool {
        timestamp != nil && !hasSuspiciousTimestamp
    }

    var outputCategory: String {
        if isGPS { return "GPS Logs" }
        if isPhoto { return "Photos" }

        let normalized = mode.lowercased()
        if normalized == "looping" || normalized == "loop_video" {
            return "Looping"
        }
        if normalized == "time_lapse" || normalized == "timelapse_video" {
            return "Time Lapse"
        }
        if normalized == "time_warp" || normalized == "timewarp" {
            return "TimeWarp"
        }
        if normalized == "time_lapse_or_timewarp" {
            return "Time Lapse"
        }
        if normalized.contains("parking_event") ||
            normalized.contains("parking event") ||
            normalized.contains("pevent") ||
            normalized.contains("parking_impact") ||
            normalized.contains("parking impact") ||
            normalized.contains("parking_motion") ||
            normalized.contains("parking motion") {
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

    var isParkingFootage: Bool {
        if Self.isParkingMode(mode) { return true }

        let normalizedChannel = channel.lowercased()
        if normalizedChannel.contains("parking") { return true }

        let normalizedPath = relativePath.lowercased()
        if normalizedPath.contains("/parking/") ||
            normalizedPath.hasPrefix("parking/") ||
            normalizedPath.contains("/park/") ||
            normalizedPath.hasPrefix("park/") {
            return true
        }

        let stem = URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return ["PF", "PI", "PR", "PT"].contains { stem.hasSuffix($0) }
    }

    var displayMode: String {
        if let inferredParkingPattern {
            return inferredParkingPattern.displayName
        }
        return Self.displayLabel(for: mode)
    }

    var displayChannel: String {
        Self.displayLabel(for: channel)
    }

    static func displayLabel(for value: String) -> String {
        switch value.lowercased() {
        case "continuous":
            return "Driving"
        case "looping", "loop_video":
            return "Looping"
        case "time_lapse", "timelapse_video":
            return "Time Lapse"
        case "time_warp", "timewarp":
            return "TimeWarp"
        case "time_lapse_or_timewarp":
            return "Time Lapse / TimeWarp"
        case "driving_event":
            return "Driving Event"
        case "parking_continuous_low_bitrate":
            return "Parking Continuous / Low Bitrate"
        case "parking_timelapse":
            return "Parking Timelapse"
        case "parking_motion_detection":
            return "Parking Motion Detection"
        case "parking_impact_detection":
            return "Parking Impact Detection"
        case "parking_motion_or_impact":
            return "Parking Motion / Impact"
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
        case "left":
            return "Left"
        case "right":
            return "Right"
        case "front_telephoto":
            return "Front Telephoto"
        case "channel_a":
            return "Channel A"
        case "channel_b":
            return "Channel B"
        case "channel_c":
            return "Channel C"
        case "channel_d":
            return "Channel D"
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

    static func isParkingMode(_ value: String) -> Bool {
        let normalized = value.lowercased()
        if ["time_lapse", "timelapse_video", "time_warp", "timewarp", "time_lapse_or_timewarp", "looping", "loop_video"].contains(normalized) {
            return false
        }
        return normalized.contains("parking") ||
            normalized.contains("motion") ||
            normalized.contains("lapse") ||
            normalized == "p" ||
            normalized == "t"
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

    func limitedToMediaItemIDs(_ ids: Set<CopyPlanItem.ID>) -> CopyPlan {
        guard !ids.isEmpty else { return self }
        let limitedItems = items.filter { ids.contains($0.id) }
        return CopyPlan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            profile: profile,
            clips: limitedItems.map(\.clip),
            items: limitedItems,
            supportItems: supportItems
        )
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
    case cancelled
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
    var displayModeCounts: [String: Int]
    var outputCategoryCounts: [String: Int]
    var channelCounts: [String: Int]
    var extensionCounts: [String: Int]
    var mediaExtensionCounts: [String: Int]
    var unrecognizedExtensionCounts: [String: Int]
    var timestampSourceCounts: [String: Int]
    var suspiciousTimestampItems: Int
    var inferredParkingPatternCounts: [String: Int]
    var sampleRelativePaths: [String]
    var rootFolders: [String]
    var folderSamples: [String]
    var folderSummaries: [FeedbackFolderSummary]
    var filenameSamples: [String]
    var filenamePatternSummaries: [FeedbackFilenamePatternSummary]
    var supportFileSamples: [String]
    var ignoredSupportFileSamples: [String]
    var clipGroupSummaries: [FeedbackClipGroupSummary]
    var videoSpecSamples: [FeedbackVideoSpecSample]
    var videoSpecSummaries: [FeedbackVideoSpecSummary]
    var settingSnapshots: [FeedbackSettingSnapshot]
    var candidates: [FeedbackCandidateSnapshot]
    var scanDiagnostics: [ScanDiagnosticEntry]
}

struct FeedbackFolderSummary: Codable, Hashable, Sendable {
    var path: String
    var fileCount: Int
    var mediaFileCount: Int
    var supportFileCount: Int
    var totalFileSizeBytes: Int64
    var minFileSizeBytes: Int64?
    var maxFileSizeBytes: Int64?
    var extensionCounts: [String: Int]
}

struct FeedbackFilenamePatternSummary: Codable, Hashable, Sendable {
    var folder: String
    var extensionLowercased: String
    var redactedPattern: String
    var fileCount: Int
    var totalFileSizeBytes: Int64
    var sampleRelativePaths: [String]
}

struct FeedbackClipGroupSummary: Codable, Hashable, Sendable {
    var folder: String
    var extensionLowercased: String
    var mode: String?
    var displayMode: String?
    var outputCategory: String?
    var channel: String?
    var displayChannel: String?
    var inferredParkingPattern: String?
    var fileCount: Int
    var totalFileSizeBytes: Int64
    var minFileSizeBytes: Int64?
    var maxFileSizeBytes: Int64?
    var firstTimestamp: String?
    var lastTimestamp: String?
    var timestampSourceCounts: [String: Int]?
    var sampleRelativePaths: [String]
}

struct FeedbackVideoSpecSample: Codable, Hashable, Sendable {
    var relativePath: String
    var extensionLowercased: String
    var fileSizeBytes: Int64?
    var mode: String?
    var displayMode: String?
    var outputCategory: String?
    var channel: String?
    var inferredParkingPattern: String?
    var codec: String?
    var width: Int?
    var height: Int?
    var nominalFrameRate: Double?
    var estimatedBitrate: Int?
    var durationSeconds: Double?
}

struct FeedbackVideoSpecSummary: Codable, Hashable, Sendable {
    var folder: String
    var extensionLowercased: String
    var mode: String?
    var displayMode: String?
    var outputCategory: String?
    var channel: String?
    var inferredParkingPattern: String?
    var fileCount: Int
    var totalFileSizeBytes: Int64
    var minFileSizeBytes: Int64?
    var maxFileSizeBytes: Int64?
    var firstTimestamp: String?
    var lastTimestamp: String?
    var timestampSourceCounts: [String: Int]?
    var sampleRelativePaths: [String]
    var sampleCodecs: [String]
    var sampleResolutions: [String]
    var sampleFrameRates: [Double]
    var sampleBitrateMin: Int?
    var sampleBitrateMax: Int?
    var sampleDurationMin: Double?
    var sampleDurationMax: Double?
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
