@preconcurrency import AVFoundation
import Foundation

extension CardScanner {
    func inferParkingPatterns(
        in clips: [ClipItem],
        profileID: String? = nil,
        sourceURL: URL? = nil
    ) -> (clips: [ClipItem], diagnostics: [ScanDiagnosticEntry]) {
        let wolfboxContext = inferWolfboxContextualParkingPatterns(in: clips)
        var inferredByRelativePath = wolfboxContext.inferredByRelativePath
        var diagnostics = wolfboxContext.diagnostics
        let blackVueParkingClips = clips.filter {
            isBlackVueParkingFilename($0.filename, profileID: profileID)
        }
        let blackVueParkingPaths = Set(blackVueParkingClips.map(\.relativePath))
        let blackVueConfiguredPattern = blackVueParkingPattern(
            sourceURL: sourceURL,
            profileID: profileID
        )

        if !blackVueParkingClips.isEmpty {
            let blackVueContext = inferBlackVueParkingPatterns(
                in: blackVueParkingClips,
                configuredPattern: blackVueConfiguredPattern
            )
            inferredByRelativePath.merge(blackVueContext.inferredByRelativePath) { current, _ in current }
            diagnostics.append(ScanDiagnosticEntry(
                stage: "blackvue_parking_mode",
                profileID: profileID,
                profileName: nil,
                outcome: blackVueContext.outcome,
                detail: blackVueContext.detail
            ))
        }

        for clip in clips {
            if inferredByRelativePath[clip.relativePath] != nil {
                continue
            }
            if blackVueParkingPaths.contains(clip.relativePath) {
                continue
            }
            if let explicitPattern = explicitParkingPattern(for: clip) {
                inferredByRelativePath[clip.relativePath] = explicitPattern
            }
        }

        let parkingClips = clips.filter { clip in
            clip.excludedReason == nil &&
                clip.isVideo &&
                Self.isParkingOutputCategory(clip.outputCategory) &&
                clip.timestamp != nil &&
                !clip.hasSuspiciousTimestamp &&
                inferredByRelativePath[clip.relativePath] == nil &&
                !blackVueParkingPaths.contains(clip.relativePath)
        }

        let groupedByFolder = Dictionary(grouping: parkingClips) { clip in
            relativeFolderPath(for: clip.relativePath)
        }

        for (folder, folderClips) in groupedByFolder {
            let moments = groupedRecordingMoments(folderClips)
            let defaultPattern = defaultParkingPattern(for: folderClips)
            guard moments.count >= 4 else {
                if let defaultPattern {
                    for clip in folderClips {
                        inferredByRelativePath[clip.relativePath] = defaultPattern
                    }
                    diagnostics.append(ScanDiagnosticEntry(
                        stage: "parking_pattern_inference",
                        profileID: nil,
                        profileName: nil,
                        outcome: "classified_default",
                        detail: "\(folder.isEmpty ? "." : folder): \(moments.count) recording moments, default=\(defaultPattern.rawValue)"
                    ))
                }
                continue
            }

            let momentPatterns = inferParkingPatternsByMoment(
                moments,
                defaultPattern: defaultPattern ?? .motionDetection,
                profileID: profileID
            )
            let patternCounts = Dictionary(grouping: momentPatterns.values, by: { $0 })
                .mapValues(\.count)

            for clip in folderClips {
                guard let timestamp = clip.timestamp else { continue }
                let key = recordingMomentKey(for: timestamp)
                if let pattern = momentPatterns[key] {
                    inferredByRelativePath[clip.relativePath] = pattern
                }
            }

            diagnostics.append(ScanDiagnosticEntry(
                stage: "parking_pattern_inference",
                profileID: nil,
                profileName: nil,
                outcome: "classified",
                detail: "\(folder.isEmpty ? "." : folder): \(moments.count) recording moments, \(patternCounts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: ", "))"
            ))
        }

        guard !inferredByRelativePath.isEmpty else {
            return (clips, diagnostics)
        }

        let annotated = clips.map { clip in
            guard let inferred = inferredByRelativePath[clip.relativePath] else { return clip }
            var copy = clip
            copy.inferredParkingPattern = inferred
            copy.mode = inferred.modeValue
            return copy
        }
        return (annotated, diagnostics)
    }

    func blackVueParkingPattern(sourceURL: URL?, profileID: String?) -> ParkingPattern? {
        guard profileID?.hasPrefix("blackvue-") == true,
              let sourceURL else {
            return nil
        }

        let configURL = sourceURL.appendingPathComponent("BlackVue/Config/config.ini")
        guard let values = try? configURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= 512 * 1024,
              let data = try? Data(contentsOf: configURL),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2,
                  parts[0].caseInsensitiveCompare("EV_PARKING_MODE") == .orderedSame else {
                continue
            }
            switch parts[1] {
            case "0":
                return .motionDetection
            case "1":
                return .timelapse
            default:
                return nil
            }
        }
        return nil
    }

    func isBlackVueParkingFilename(_ filename: String, profileID: String?) -> Bool {
        guard profileID?.hasPrefix("blackvue-") == true else { return false }
        let stem = URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return stem.range(
            of: #"^\d{8}_\d{6}_P[FROI](?:[SL])?$"#,
            options: .regularExpression
        ) != nil
    }

    struct BlackVueParkingMediaHint {
        var durationSeconds: Double?
        var hasAudio: Bool?
    }

    private struct BlackVueParkingMoment {
        var timestamp: Date
        var clips: [ClipItem]
        var mediaHint: BlackVueParkingMediaHint
    }

    func inferBlackVueParkingPatterns(
        in clips: [ClipItem],
        configuredPattern: ParkingPattern?,
        mediaHintsByRelativePath: [String: BlackVueParkingMediaHint] = [:]
    ) -> (
        inferredByRelativePath: [String: ParkingPattern],
        outcome: String,
        detail: String
    ) {
        let eligible = clips.filter {
            $0.excludedReason == nil && $0.isVideo && $0.timestamp != nil && !$0.hasSuspiciousTimestamp
        }
        let grouped = Dictionary(grouping: eligible) { clip in
            recordingMomentKey(for: clip.timestamp!)
        }
        let moments = grouped.compactMap { _, momentClips -> BlackVueParkingMoment? in
            guard let timestamp = momentClips.compactMap(\.timestamp).min() else { return nil }
            let preferredClip = momentClips.first(where: { $0.channel == "front" }) ?? momentClips.first
            guard let preferredClip else { return nil }
            let hint = mediaHintsByRelativePath[preferredClip.relativePath] ??
                blackVueParkingMediaHint(for: preferredClip.sourceURL)
            return BlackVueParkingMoment(timestamp: timestamp, clips: momentClips, mediaHint: hint)
        }
        .sorted { $0.timestamp < $1.timestamp }

        var patternByMoment: [Int: ParkingPattern] = [:]
        for (index, moment) in moments.enumerated() where moment.mediaHint.hasAudio == true {
            patternByMoment[index] = .motionDetection
        }

        enum CadencePattern: Equatable {
            case motion
            case timelapse

            var parkingPattern: ParkingPattern {
                switch self {
                case .motion: return .motionDetection
                case .timelapse: return .timelapse
                }
            }
        }

        var edgePatterns: [CadencePattern?] = []
        if moments.count >= 2 {
            for index in 0..<(moments.count - 1) {
                let current = moments[index]
                let next = moments[index + 1]
                let gap = next.timestamp.timeIntervalSince(current.timestamp)
                guard let duration = current.mediaHint.durationSeconds,
                      duration.isFinite,
                      duration >= 5,
                      duration <= 180,
                      gap > 0 else {
                    edgePatterns.append(nil)
                    continue
                }

                let timelapseSpan = duration * 30
                let timelapseTolerance = max(90, timelapseSpan * 0.20)
                if current.mediaHint.hasAudio == false,
                   next.mediaHint.hasAudio == false,
                   abs(gap - timelapseSpan) <= timelapseTolerance {
                    edgePatterns.append(.timelapse)
                    continue
                }

                let motionTolerance = max(15, duration * 0.35)
                if abs(gap - duration) <= motionTolerance {
                    edgePatterns.append(.motion)
                } else {
                    edgePatterns.append(nil)
                }
            }
        }

        var edgeStart = 0
        while edgeStart < edgePatterns.count {
            guard let pattern = edgePatterns[edgeStart] else {
                edgeStart += 1
                continue
            }
            var edgeEnd = edgeStart
            while edgeEnd + 1 < edgePatterns.count, edgePatterns[edgeEnd + 1] == pattern {
                edgeEnd += 1
            }
            if edgeEnd - edgeStart + 1 >= 2 {
                for momentIndex in edgeStart...(edgeEnd + 1) {
                    if patternByMoment[momentIndex] == nil || pattern == .motion {
                        patternByMoment[momentIndex] = pattern.parkingPattern
                    }
                }
            }
            edgeStart = edgeEnd + 1
        }

        let strongPatterns = Set(patternByMoment.values)
        if strongPatterns.isEmpty, let configuredPattern {
            for index in moments.indices where patternByMoment[index] == nil {
                patternByMoment[index] = configuredPattern
            }
        } else if strongPatterns.count == 1, let configuredPattern,
                  !strongPatterns.contains(configuredPattern) {
            for index in moments.indices where patternByMoment[index] == nil {
                patternByMoment[index] = configuredPattern
            }
        }

        var inferredByRelativePath: [String: ParkingPattern] = [:]
        for (index, pattern) in patternByMoment {
            for clip in moments[index].clips {
                inferredByRelativePath[clip.relativePath] = pattern
            }
        }

        let counts = Dictionary(grouping: patternByMoment.values, by: { $0 }).mapValues(\.count)
        let unresolvedCount = moments.count - patternByMoment.count
        let evidence = counts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: ", ")
        let settingText = configuredPattern?.rawValue ?? "unavailable"
        let outcome: String
        let finalPatterns = Set(patternByMoment.values)
        if finalPatterns.count > 1 {
            outcome = unresolvedCount == 0 ? "classified_mixed_per_clip" : "classified_mixed_with_ambiguity"
        } else if !strongPatterns.isEmpty {
            outcome = "classified_per_clip"
        } else if configuredPattern != nil {
            outcome = "classified_from_safe_setting"
        } else {
            outcome = "kept_ambiguous"
        }
        let detail = "BlackVue P recordings: \(evidence.isEmpty ? "no per-clip evidence" : evidence), unresolved=\(unresolvedCount), current_setting=\(settingText); audio and duration-aware cadence override the card-wide setting"
        return (inferredByRelativePath, outcome, detail)
    }

    private func blackVueParkingMediaHint(for fileURL: URL) -> BlackVueParkingMediaHint {
        let asset = AVURLAsset(url: fileURL)
        let duration = asset.duration.seconds
        let validDuration = duration.isFinite && duration > 0 ? duration : nil
        let hasVideo = !asset.tracks(withMediaType: .video).isEmpty
        let hasAudio = hasVideo ? !asset.tracks(withMediaType: .audio).isEmpty : nil
        return BlackVueParkingMediaHint(durationSeconds: validDuration, hasAudio: hasAudio)
    }

    func inferWolfboxContextualParkingPatterns(in clips: [ClipItem]) -> (
        inferredByRelativePath: [String: ParkingPattern],
        diagnostics: [ScanDiagnosticEntry]
    ) {
        let videos = clips.filter { clip in
            clip.excludedReason == nil &&
                clip.isVideo &&
                clip.timestamp != nil &&
                !clip.hasSuspiciousTimestamp
        }
        let folders = Set(videos.map { relativeFolderPath(for: $0.relativePath).lowercased() })
        guard folders.contains("front_norm"),
              folders.contains("rear_norm"),
              folders.contains("front_emer"),
              folders.contains("rear_emer") else {
            return ([:], [])
        }

        let normalClips = videos.filter {
            $0.relativePath.lowercased().hasPrefix("front_norm/") ||
                $0.relativePath.lowercased().hasPrefix("rear_norm/")
        }
        let normalMoments = wolfboxGroupedRecordingMoments(normalClips)
        let timelapseMoments = wolfboxTimelapseMoments(in: normalMoments)
        guard !timelapseMoments.isEmpty,
              let firstTimelapseTimestamp = timelapseMoments.map(\.timestamp).min() else {
            return ([:], [])
        }

        var inferredByRelativePath: [String: ParkingPattern] = [:]
        for moment in timelapseMoments {
            for relativePath in moment.relativePaths {
                inferredByRelativePath[relativePath] = .timelapse
            }
        }

        let emergencyClips = videos.filter {
            $0.relativePath.lowercased().hasPrefix("front_emer/") ||
                $0.relativePath.lowercased().hasPrefix("rear_emer/")
        }
        let emergencyMoments = wolfboxGroupedRecordingMoments(emergencyClips)
        let parkingContextLeadTime: TimeInterval = 4 * 60
        let parkingContextStart = firstTimelapseTimestamp.addingTimeInterval(-parkingContextLeadTime)
        let parkingEmergencyPaths = Set(emergencyMoments.filter { moment in
            moment.timestamp >= parkingContextStart
        }.flatMap(\.relativePaths))

        for relativePath in parkingEmergencyPaths {
            inferredByRelativePath[relativePath] = .impactDetection
        }

        guard !inferredByRelativePath.isEmpty else {
            return ([:], [])
        }

        let parkingEmergencyCount = emergencyClips.filter { parkingEmergencyPaths.contains($0.relativePath) }.count
        let drivingEmergencyCount = emergencyClips.count - parkingEmergencyCount
        return (
            inferredByRelativePath,
            [
                ScanDiagnosticEntry(
                    stage: "wolfbox_context_inference",
                    profileID: nil,
                    profileName: nil,
                    outcome: "classified",
                    detail: "front/rear normal + emergency layout: timelapse_moments=\(timelapseMoments.count), parking_emergency_clips=\(parkingEmergencyCount), driving_emergency_clips=\(drivingEmergencyCount)"
                )
            ]
        )
    }

    struct ContextRecordingMoment {
        var timestamp: Date
        var totalBytes: Int64
        var relativePaths: [String]
    }

    func wolfboxGroupedRecordingMoments(_ clips: [ClipItem]) -> [ContextRecordingMoment] {
        let sortedClips = clips
            .compactMap { clip -> (clip: ClipItem, timestamp: Date)? in
                guard let timestamp = clip.timestamp else { return nil }
                return (clip, timestamp)
            }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.clip.relativePath.localizedStandardCompare(rhs.clip.relativePath) == .orderedAscending
            }

        var moments: [ContextRecordingMoment] = []
        for item in sortedClips {
            if var current = moments.last,
               item.timestamp.timeIntervalSince(current.timestamp) <= 3 {
                current.totalBytes += item.clip.size
                current.relativePaths.append(item.clip.relativePath)
                current.timestamp = min(current.timestamp, item.timestamp)
                moments[moments.count - 1] = current
            } else {
                moments.append(ContextRecordingMoment(
                    timestamp: item.timestamp,
                    totalBytes: item.clip.size,
                    relativePaths: [item.clip.relativePath]
                ))
            }
        }

        return moments
    }

    func wolfboxTimelapseMoments(in moments: [ContextRecordingMoment]) -> [ContextRecordingMoment] {
        guard moments.count >= 3 else { return [] }

        var bestRun: [ContextRecordingMoment] = []
        var currentRun: [ContextRecordingMoment] = []
        for moment in moments {
            guard let previous = currentRun.last else {
                currentRun = [moment]
                continue
            }

            let interval = moment.timestamp.timeIntervalSince(previous.timestamp)
            if interval >= 300, interval <= 7_200 {
                currentRun.append(moment)
            } else {
                if currentRun.count > bestRun.count {
                    bestRun = currentRun
                }
                currentRun = [moment]
            }
        }
        if currentRun.count > bestRun.count {
            bestRun = currentRun
        }

        guard bestRun.count >= 3 else { return [] }
        let intervals = zip(bestRun, bestRun.dropFirst()).map { lhs, rhs in
            rhs.timestamp.timeIntervalSince(lhs.timestamp)
        }
        guard let medianInterval = median(intervals) else { return [] }
        let consistentIntervalCount = intervals.filter { interval in
            abs(interval - medianInterval) <= max(60, medianInterval * 0.20)
        }.count
        let consistency = intervals.isEmpty ? 0 : Double(consistentIntervalCount) / Double(intervals.count)
        guard medianInterval >= 300, medianInterval <= 7_200, consistency >= 0.65 else {
            return []
        }

        return bestRun
    }

    func explicitParkingPattern(for clip: ClipItem) -> ParkingPattern? {
        guard clip.excludedReason == nil, clip.isVideo else { return nil }

        switch clip.mode {
        case "parking_timelapse":
            return .timelapse
        case "parking_motion_detection":
            return .motionDetection
        case "parking_impact_detection":
            return .impactDetection
        case "parking_motion_or_impact":
            return .motionOrImpact
        case "parking_continuous_low_bitrate":
            return .continuousLowBitrate
        default:
            break
        }

        let lowerPath = clip.relativePath.lowercased()
        let isProtectedFolder = lowerPath.contains("/ro/") ||
            lowerPath.hasPrefix("ro/") ||
            lowerPath.contains("/event/") ||
            lowerPath.hasPrefix("event/") ||
            lowerPath.contains("/pevent/") ||
            lowerPath.hasPrefix("pevent/")

        if lowerPath.contains("/pevent/") || lowerPath.hasPrefix("pevent/") {
            return .impactDetection
        }

        let tokens = genericTokens(from: clip.relativePath)
        if tokens.contains("motion") || tokens.contains("mot") {
            return .motionDetection
        }

        if isProtectedFolder && hasParkingChannelSuffix(clip.filename) {
            return .impactDetection
        }

        return nil
    }

    static func isParkingOutputCategory(_ category: String) -> Bool {
        category == "Parking" || category == "Parking Events"
    }

    func defaultParkingPattern(for clips: [ClipItem]) -> ParkingPattern? {
        let tokens = clips.flatMap { genericTokens(from: $0.relativePath) }
        if tokens.contains("motion") || tokens.contains("mot") {
            return .motionDetection
        }
        if tokens.contains("impact") || tokens.contains("event") || tokens.contains("evt") {
            return .impactDetection
        }
        if clips.contains(where: { $0.outputCategory == "Parking Events" }) {
            return .motionOrImpact
        }
        if clips.contains(where: { clip in
            clip.relativePath.lowercased().contains("cardv/movie/park")
        }) {
            return .motionOrImpact
        }
        return nil
    }

    func hasParkingChannelSuffix(_ filename: String) -> Bool {
        let stem = URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return ["PF", "PI", "PR", "PT"].contains { stem.hasSuffix($0) }
    }

    func hasParkingFilenamePrefix(_ filename: String) -> Bool {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return stem.range(of: #"^P20\d{6}[_-]?\d{6}"#, options: .regularExpression) != nil
    }

    func inferParkingPatternsByMoment(
        _ moments: [(key: Int, timestamp: Date, totalBytes: Int64)],
        defaultPattern: ParkingPattern,
        profileID: String? = nil
    ) -> [Int: ParkingPattern] {
        var inferred: [Int: ParkingPattern] = [:]

        var runStart = 0
        while runStart < moments.count {
            var runEnd = runStart
            while runEnd + 1 < moments.count {
                let gap = moments[runEnd + 1].timestamp.timeIntervalSince(moments[runEnd].timestamp)
                guard gap > 0, gap <= 210 else { break }
                runEnd += 1
            }

            if runEnd - runStart + 1 >= 4 {
                let runMoments = Array(moments[runStart...runEnd])
                let medianMomentSize = median(runMoments.map(\.totalBytes).map(Double.init)) ?? 0
                let pattern: ParkingPattern
                if profileID == "thinkware-arc-800" {
                    // ARC 800 has motion detection, low-power impact events,
                    // and timelapse parking, but no continuous low-bitrate
                    // parking mode. Its compact recurring MOT clips are its
                    // timelapse variant, not a generic low-bitrate stream.
                    pattern = .timelapse
                } else {
                    pattern = medianMomentSize <= 300_000_000 ? .continuousLowBitrate : .timelapse
                }
                for index in runStart...runEnd {
                    inferred[moments[index].key] = pattern
                }
            }

            runStart = max(runEnd + 1, runStart + 1)
        }

        let remainingMoments = moments.filter { inferred[$0.key] == nil }
        if remainingMoments.count >= 4,
           let timelapsePattern = regularTimelapsePattern(for: remainingMoments) {
            for moment in remainingMoments {
                inferred[moment.key] = timelapsePattern
            }
        }

        for moment in moments where inferred[moment.key] == nil {
            inferred[moment.key] = defaultPattern
        }

        return inferred
    }

    func regularTimelapsePattern(for moments: [(key: Int, timestamp: Date, totalBytes: Int64)]) -> ParkingPattern? {
        let intervals = zip(moments, moments.dropFirst()).map { lhs, rhs in
            rhs.timestamp.timeIntervalSince(lhs.timestamp)
        }
        guard let medianInterval = median(intervals), medianInterval > 0 else { return nil }

        let consistentIntervalCount = intervals.filter { interval in
            abs(interval - medianInterval) <= max(30, medianInterval * 0.25)
        }.count
        let consistency = intervals.isEmpty ? 0 : Double(consistentIntervalCount) / Double(intervals.count)
        let medianMomentSize = median(moments.map(\.totalBytes).map(Double.init)) ?? 0

        if medianInterval >= 300, medianInterval <= 7_200, consistency >= 0.55, medianMomentSize <= 300_000_000 {
            return .timelapse
        }
        return nil
    }

    func groupedRecordingMoments(_ clips: [ClipItem]) -> [(key: Int, timestamp: Date, totalBytes: Int64)] {
        let grouped = Dictionary(grouping: clips) { clip -> Int in
            guard let timestamp = clip.timestamp else { return 0 }
            return recordingMomentKey(for: timestamp)
        }
        return grouped.compactMap { key, clips -> (key: Int, timestamp: Date, totalBytes: Int64)? in
            guard let timestamp = clips.compactMap(\.timestamp).min() else { return nil }
            return (key, timestamp, clips.reduce(Int64(0)) { $0 + $1.size })
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    func relativeFolderPath(for relativePath: String) -> String {
        guard let slashIndex = relativePath.lastIndex(of: "/") else {
            return "."
        }
        return String(relativePath[..<slashIndex])
    }

    func recordingMomentKey(for timestamp: Date) -> Int {
        Int((timestamp.timeIntervalSince1970 / 2).rounded())
    }

    func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

}
