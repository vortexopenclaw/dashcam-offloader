import Foundation

extension CardScanner {
    func inferParkingPatterns(in clips: [ClipItem]) -> (clips: [ClipItem], diagnostics: [ScanDiagnosticEntry]) {
        let wolfboxContext = inferWolfboxContextualParkingPatterns(in: clips)
        var inferredByRelativePath = wolfboxContext.inferredByRelativePath
        var diagnostics = wolfboxContext.diagnostics

        for clip in clips {
            if inferredByRelativePath[clip.relativePath] != nil {
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
                inferredByRelativePath[clip.relativePath] == nil
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

            let momentPatterns = inferParkingPatternsByMoment(moments, defaultPattern: defaultPattern ?? .motionDetection)
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
        defaultPattern: ParkingPattern
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
                let pattern: ParkingPattern = medianMomentSize <= 300_000_000 ? .continuousLowBitrate : .timelapse
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
