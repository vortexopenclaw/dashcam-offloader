import Foundation

enum CardLearningVideoSampler {
    static let maximumSamples = 64

    static func select(_ clips: [ClipItem]) -> [ClipItem] {
        let videos = clips.filter { $0.isVideo && $0.excludedReason == nil }
        let grouped = Dictionary(grouping: videos) { clip in
            let folder = clip.relativePath.split(separator: "/").dropLast().joined(separator: "/")
            return [clip.outputCategory, clip.displayMode, clip.channel,
                    clip.inferredParkingPattern?.rawValue ?? "none", folder,
                    clip.extensionLowercased].joined(separator: "|")
        }
        var covered: Set<String> = []
        var priority: [String] = []
        var remaining: [String] = []
        for key in grouped.keys.sorted() {
            guard let clip = grouped[key]?.first else { continue }
            let modeChannel = [clip.outputCategory, clip.displayMode, clip.channel].joined(separator: "|")
            if covered.insert(modeChannel).inserted { priority.append(key) }
            else { remaining.append(key) }
        }

        let candidates = (priority + remaining).map { key -> [ClipItem] in
            let ordered = grouped[key, default: []].sorted(by: earlier)
            let sizes = Dictionary(grouping: ordered, by: \.size)
            // A stopped recording may be the newest and smallest clip. Include
            // the newest repeated file-size cohort as well, so recent complete
            // recordings survive a setting change followed by a short tail.
            let repeated = sizes.values.filter { $0.count >= 2 && $0[0].size > 0 }
                .compactMap(\.last).sorted { earlier($1, $0) }
            let frequent = sizes.values.sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return earlier(rhs.last!, lhs.last!)
            }.prefix(4).compactMap(\.last)
            var result: [ClipItem] = []
            var seen: Set<String> = []
            func append(_ clip: ClipItem?) {
                guard let clip, seen.insert(clip.id).inserted else { return }
                result.append(clip)
            }
            append(ordered.first)
            append(repeated.first)
            append(ordered.last)
            if ordered.count > 1 { append(ordered[ordered.count - 2]) }
            for clip in repeated.prefix(4) { append(clip) }
            for clip in frequent { append(clip) }
            if !ordered.isEmpty { append(ordered[ordered.count / 2]) }
            append(ordered.max { $0.size < $1.size })
            append(ordered.min { $0.size < $1.size })
            return result
        }

        // Share the inspection budget across modes/channels before taking
        // extra representatives from any one group. No media is opened here.
        var selected: [ClipItem] = []
        var seen: Set<String> = []
        for round in 0..<(candidates.map(\.count).max() ?? 0) {
            for bucket in candidates where round < bucket.count {
                let clip = bucket[round]
                if seen.insert(clip.id).inserted { selected.append(clip) }
                if selected.count == maximumSamples { return selected }
            }
        }
        return selected
    }

    private static func earlier(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
        }
        return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
    }
}
