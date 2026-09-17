@preconcurrency import AVFoundation
import Foundation

enum CardHealthIssueKind: String, Hashable, Sendable {
    case emptyVideo
    case unreadableVideo
    case missingChannel
}

struct CardHealthIssue: Identifiable, Hashable, Sendable {
    var id: String
    var kind: CardHealthIssueKind
    var title: String
    var detail: String
    var affectedFileCount: Int
}

struct CardHealthReport: Hashable, Sendable {
    var didComplete: Bool = false
    var checkedVideoCount: Int = 0
    var skippedContainerCount: Int = 0
    var issues: [CardHealthIssue] = []

    var hasWarnings: Bool { !issues.isEmpty }
}

struct CardHealthAnalyzer {
    private let metadataProbeExtensions: Set<String> = ["mp4", "mov"]

    func analyze(clips: [ClipItem]) -> CardHealthReport {
        let videos = clips.filter { $0.isVideo && $0.excludedReason == nil }
        var emptyFilenames: [String] = []
        var unreadableFilenames: [String] = []
        var checkedCount = 0
        var skippedCount = 0

        for clip in videos {
            if clip.size <= 0 {
                emptyFilenames.append(clip.filename)
                checkedCount += 1
                continue
            }
            guard metadataProbeExtensions.contains(clip.extensionLowercased) else {
                skippedCount += 1
                continue
            }

            checkedCount += 1
            let asset = AVURLAsset(url: clip.sourceURL)
            let duration = asset.duration.seconds
            let hasVideoTrack = !asset.tracks(withMediaType: .video).isEmpty
            if !duration.isFinite || duration <= 0 || !hasVideoTrack {
                unreadableFilenames.append(clip.filename)
            }
        }

        var issues: [CardHealthIssue] = []
        if !emptyFilenames.isEmpty {
            let emptyCount = emptyFilenames.count
            issues.append(CardHealthIssue(
                id: "empty-video",
                kind: .emptyVideo,
                title: "Empty video files",
                detail: emptyCount == 1
                    ? "1 video file is zero bytes and was not written successfully: \(emptyFilenames[0])."
                    : "\(emptyCount) video files are zero bytes and may not have been written successfully: \(filenameSummary(emptyFilenames)).",
                affectedFileCount: emptyCount
            ))
        }
        if !unreadableFilenames.isEmpty {
            let unreadableCount = unreadableFilenames.count
            issues.append(CardHealthIssue(
                id: "unreadable-video",
                kind: .unreadableVideo,
                title: "Unreadable video files",
                detail: "\(unreadableCount) MP4 or MOV file\(unreadableCount == 1 ? " may be" : "s may be") truncated or corrupt because \(unreadableCount == 1 ? "it does" : "they do") not expose a valid video track and duration: \(filenameSummary(unreadableFilenames)).",
                affectedFileCount: unreadableCount
            ))
        }
        issues.append(contentsOf: missingChannelIssues(in: videos))

        return CardHealthReport(
            didComplete: true,
            checkedVideoCount: checkedCount,
            skippedContainerCount: skippedCount,
            issues: issues
        )
    }

    func missingChannelIssues(in videos: [ClipItem]) -> [CardHealthIssue] {
        let timestamped = videos.filter {
            $0.timestampSource == .filename &&
                $0.timestamp != nil &&
                !$0.hasSuspiciousTimestamp &&
                normalizedChannel($0.channel) != nil
        }
        let groupsByMode = Dictionary(grouping: timestamped, by: \.mode)
        var issues: [CardHealthIssue] = []

        for (mode, modeClips) in groupsByMode {
            let timestampGroups = Dictionary(grouping: modeClips) {
                Int($0.timestamp!.timeIntervalSince1970)
            }.values.map { clips in
                Set(clips.compactMap { normalizedChannel($0.channel) })
            }
            // Treat a channel as established only when it appears throughout at
            // least half of a meaningful run. This avoids interpreting a briefly
            // connected optional camera as a card-wide expectation.
            guard timestampGroups.count >= 4 else { continue }

            let appearanceCounts = timestampGroups.reduce(into: [String: Int]()) { counts, channels in
                for channel in channels { counts[channel, default: 0] += 1 }
            }
            let minimumExpectedAppearances = max(3, Int(ceil(Double(timestampGroups.count) * 0.50)))
            let expectedChannels = Set(appearanceCounts.compactMap { channel, count in
                count >= minimumExpectedAppearances ? channel : nil
            })
            guard expectedChannels.count >= 2 else { continue }

            for channel in expectedChannels.sorted() {
                let missingCount = timestampGroups.filter { !$0.contains(channel) }.count
                guard missingCount > 0 else { continue }
                issues.append(CardHealthIssue(
                    id: "missing-channel-\(mode)-\(channel)",
                    kind: .missingChannel,
                    title: "Missing \(displayChannel(channel)) recordings",
                    detail: "\(missingCount) of \(timestampGroups.count) \(displayMode(mode)) timestamp group\(timestampGroups.count == 1 ? "" : "s") are missing the \(displayChannel(channel).lowercased()) channel while other camera channels continue recording.",
                    affectedFileCount: missingCount
                ))
            }
        }

        return issues.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func normalizedChannel(_ value: String) -> String? {
        let normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized {
        case "", "unknown", "primary", "360_primary":
            return nil
        case "f", "front", "parking_front", "pf", "nf", "mf":
            return "front"
        case "r", "rear", "parking_rear", "pr", "nr":
            return "rear"
        case "i", "interior", "inside", "cabin", "parking_interior", "pi":
            return "interior"
        case "t", "telephoto", "parking_telephoto", "pt":
            return "telephoto"
        default:
            return normalized
        }
    }

    private func displayChannel(_ channel: String) -> String {
        channel.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func filenameSummary(_ filenames: [String]) -> String {
        let examples = filenames.prefix(3).joined(separator: ", ")
        let remaining = filenames.count - min(filenames.count, 3)
        return remaining > 0 ? "\(examples), and \(remaining) more" : examples
    }

    private func displayMode(_ mode: String) -> String {
        mode.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
