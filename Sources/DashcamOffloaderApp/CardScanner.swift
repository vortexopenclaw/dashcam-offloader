import Foundation

struct CardScanner {
    private let fileManager = FileManager.default

    func discoverMountedSources(showAllVolumes: Bool = false) -> [MountedSource] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .volumeIsBrowsableKey]
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) ?? fallbackVolumeDirectoryURLs(resourceKeys: resourceKeys)

        return urls
            .filter { url in
                let standardizedURL = url.standardizedFileURL
                guard standardizedURL.path.hasPrefix("/Volumes/") else { return false }
                let values = try? standardizedURL.resourceValues(forKeys: Set(resourceKeys))
                guard values?.isDirectory == true else { return false }
                guard values?.volumeIsBrowsable != false else { return false }
                return shouldShowMountedSource(standardizedURL, showAllVolumes: showAllVolumes)
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MountedSource(url: $0.standardizedFileURL, name: $0.lastPathComponent) }
    }

    private func fallbackVolumeDirectoryURLs(resourceKeys: [URLResourceKey]) -> [URL] {
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        return (try? fileManager.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    func mountedSource(forUserSelectedURL url: URL) -> MountedSource {
        let standardizedURL = url.standardizedFileURL
        if let volumeURL = mountedVolumeRoot(containing: standardizedURL) {
            return MountedSource(url: volumeURL, name: volumeURL.lastPathComponent)
        }

        return MountedSource(url: standardizedURL, name: standardizedURL.lastPathComponent)
    }

    func shouldShowMountedSource(_ url: URL, showAllVolumes: Bool) -> Bool {
        if isSystemVolume(url) { return false }
        if showAllVolumes { return true }
        if isObviousNonDashcamVolume(url) { return false }
        return hasDashcamLikeEvidence(url)
    }

    func scan(sourceURL: URL, profiles: [DashcamProfile]) throws -> ScanResult {
        let allFiles = try enumerateFiles(sourceURL: sourceURL)
        let candidates = detectProfiles(sourceURL: sourceURL, allFiles: allFiles, profiles: profiles)
        let topCandidate = candidates.first
        let selectionIssue = topCandidate.flatMap(profileSelectionIssue)
        let selectedProfile: DashcamProfile?
        if let topCandidate, topCandidate.confidence != .low, selectionIssue == nil {
            selectedProfile = topCandidate.profile
        } else if topCandidate != nil {
            selectedProfile = DashcamProfile.genericNewDashcam
        } else {
            selectedProfile = nil
        }
        let rawClips: [ClipItem]
        if let selectedProfile, selectedProfile.id != DashcamProfile.genericNewDashcam.id {
            rawClips = classify(files: allFiles, sourceURL: sourceURL, profile: selectedProfile)
        } else {
            rawClips = classifyGenerically(files: allFiles, sourceURL: sourceURL)
        }
        let parkingPatternResult = inferParkingPatterns(in: rawClips)
        let clips = parkingPatternResult.clips

        var diagnostics = candidates.first.map {
            [
                ScanDiagnosticEntry(
                    stage: "profile_scoring",
                    profileID: $0.profile.id,
                    profileName: $0.profile.displayName,
                    outcome: "selected_initial",
                    detail: "top score \($0.score), confidence \($0.confidence.rawValue), candidates \(candidates.count)"
                )
            ]
        } ?? [
            ScanDiagnosticEntry(
                stage: "profile_scoring",
                profileID: nil,
                profileName: nil,
                outcome: "no_candidates",
                detail: "No profile scored above zero"
            )
        ]
        if let selectionIssue, let topCandidate {
            diagnostics.append(ScanDiagnosticEntry(
                stage: "profile_selection_guard",
                profileID: topCandidate.profile.id,
                profileName: topCandidate.profile.displayName,
                outcome: "selected_generic_new_card",
                detail: selectionIssue
            ))
        }
        if selectedProfile?.id == DashcamProfile.genericNewDashcam.id {
            diagnostics.append(ScanDiagnosticEntry(
                stage: "generic_fallback",
                profileID: DashcamProfile.genericNewDashcam.id,
                profileName: DashcamProfile.genericNewDashcam.displayName,
                outcome: "classified_generic_clips",
                detail: "Used filename dates and folder semantics because no reliable supported profile was selected"
            ))
        }
        diagnostics.append(contentsOf: parkingPatternResult.diagnostics)

        return ScanResult(
            sourceURL: sourceURL,
            allFiles: allFiles,
            candidates: candidates,
            selectedProfile: selectedProfile,
            clips: clips,
            diagnostics: diagnostics
        )
    }

    private func profileSelectionIssue(_ candidate: DetectionCandidate) -> String? {
        if candidate.confidence == .low {
            return "Top candidate scored only low confidence, so the card was treated as unrecognized"
        }

        let hasModelEvidence = candidate.evidence.contains { evidence in
            evidence.hasPrefix("model text ") || evidence.hasPrefix("model evidence ")
        }
        let hasFilenameEvidence = candidate.evidence.contains { $0.hasPrefix("filename pattern match ") }
        if hasModelEvidence || hasFilenameEvidence {
            return nil
        }

        return "Top candidate matched only shared folder/volume structure, with no model text or filename-pattern verification. Treating this as an unrecognized/new camera instead of assuming \(candidate.profile.displayName)."
    }

    /// Async scan that augments folder/filename detection with OSD OCR to
    /// disambiguate sibling models (e.g. VIOFO A229 Pro vs Plus vs Ultra).
    ///
    /// OSD probing runs when the folder/filename result is ambiguous, or when
    /// several sibling candidates have OSD specs. VIOFO A229/A329 siblings can
    /// score high from identical folders and filename patterns, so confidence
    /// alone is not enough to skip OCR. A confirmed OSD match bumps that
    /// profile's score by 80, re-sorts the candidates, and re-selects the
    /// winner. OSD probing is best-effort, a failed probe leaves the original
    /// result unchanged.
    func scanWithOSD(sourceURL: URL, profiles: [DashcamProfile]) throws -> ScanResult {
        var result = try scan(sourceURL: sourceURL, profiles: profiles)

        guard let top = result.candidates.first else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "osd_ocr_gate",
                profileID: nil,
                profileName: nil,
                outcome: "skipped_no_candidates",
                detail: "No profile candidates available for OSD OCR"
            ))
            return result
        }

        // Disambiguation only matters when another candidate is close behind.
        let hasCompetition = result.candidates.dropFirst().contains { abs(top.score - $0.score) <= 15 }
        let osdCandidateCount = result.candidates.filter { $0.profile.osdSpec?.containsModelName == true }.count
        let hasOSDSiblingCompetition = top.profile.osdSpec?.containsModelName == true && osdCandidateCount >= 2
        guard hasCompetition || hasOSDSiblingCompetition else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "osd_ocr_gate",
                profileID: top.profile.id,
                profileName: top.profile.displayName,
                outcome: "skipped_no_ocr_competition",
                detail: "Top score \(top.score), confidence \(top.confidence.rawValue); closeCompetition \(hasCompetition), osdSiblingCandidates \(osdCandidateCount)"
            ))
            return result
        }

        result.diagnostics.append(ScanDiagnosticEntry(
            stage: "osd_ocr_gate",
            profileID: top.profile.id,
            profileName: top.profile.displayName,
            outcome: "running",
            detail: "Top score \(top.score), confidence \(top.confidence.rawValue); closeCompetition \(hasCompetition), osdSiblingCandidates \(osdCandidateCount)"
        ))

        let probe = OSDProbe()
        var updatedCandidates = result.candidates

        for index in updatedCandidates.indices {
            let candidate = updatedCandidates[index]
            guard candidate.profile.id == top.profile.id || abs(top.score - candidate.score) <= 15 else {
                if candidate.profile.osdSpec?.containsModelName == true {
                    result.diagnostics.append(ScanDiagnosticEntry(
                        stage: "osd_ocr_probe",
                        profileID: candidate.profile.id,
                        profileName: candidate.profile.displayName,
                        outcome: "skipped_not_competitive",
                        detail: "Candidate score \(candidate.score) was more than 15 points below top score \(top.score)"
                    ))
                }
                continue
            }
            guard let spec = candidate.profile.osdSpec, spec.containsModelName else {
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "skipped_no_osd_spec",
                    detail: "Profile has no OSD OCR spec"
                ))
                continue
            }

            let sampleVideos = sampleVideos(
                for: spec,
                allFiles: result.allFiles
            )
            let probeChannelList = spec.probeChannels.joined(separator: ",")
            guard !sampleVideos.isEmpty else {
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "skipped_no_sample_videos",
                    detail: "No video matched probe channels \(probeChannelList)"
                ))
                continue
            }

            var frameCount = 0
            var framesWithText = 0
            var textCandidateCount = 0
            var matchedString: String?
            var videosChecked = 0

            for videoURL in sampleVideos {
                videosChecked += 1
                let probeResult = probe.probeWithDiagnostics(videoURL: videoURL, spec: spec)
                frameCount += probeResult.framesExtracted
                framesWithText += probeResult.framesWithText
                textCandidateCount += probeResult.textCandidateCount
                if let matched = probeResult.matchedString {
                    matchedString = matched
                    break
                }
            }

            let detail = "videos \(videosChecked), frames \(frameCount), framesWithText \(framesWithText), textCandidates \(textCandidateCount)"
            if let matched = matchedString {
                updatedCandidates[index].score += 80
                var evidence = updatedCandidates[index].evidence
                evidence.append("OSD OCR match \"\(matched)\"")
                updatedCandidates[index].evidence = Array(evidence.prefix(6))
                updatedCandidates[index].confidence = confidenceLevel(for: updatedCandidates[index].score)
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "matched",
                    detail: detail
                ))
            } else {
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "no_match",
                    detail: detail
                ))
            }
        }

        updatedCandidates.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.profile.displayName < rhs.profile.displayName
        }

        result.candidates = updatedCandidates

        // Re-select and re-classify if the winner changed.
        if let newTop = updatedCandidates.first,
           newTop.confidence != .low,
           newTop.profile.id != result.selectedProfile?.id {
            result.selectedProfile = newTop.profile
            result.clips = classifyWithParkingPatterns(files: result.allFiles, sourceURL: sourceURL, profile: newTop.profile).clips
        } else if result.selectedProfile == nil {
            if let newTop = updatedCandidates.first, newTop.confidence != .low {
                result.selectedProfile = newTop.profile
            }
        }

        return result
    }

    /// Finds front-channel sample videos matching the OSD spec's channels.
    /// VIOFO front clips end in a channel suffix (e.g. `..._F.MP4`). Falls
    /// back to early videos if no channel-suffixed clip is found.
    private func sampleVideos(for spec: OSDSpec, allFiles: [URL]) -> [URL] {
        let videos = allFiles.filter { ["mp4", "mov"].contains($0.pathExtension.lowercased()) }
        guard !videos.isEmpty else { return [] }

        var matches: [URL] = []
        for channel in spec.probeChannels {
            let suffix = channel.uppercased()
            matches.append(contentsOf: videos.filter { url in
                let stem = url.deletingPathExtension().lastPathComponent.uppercased()
                return stem.hasSuffix(suffix)
            })
        }

        // No channel-suffixed clip; the OSD is still likely on early clips.
        let candidates = matches.isEmpty ? videos : matches
        return Array(candidates.prefix(5))
    }

    private func confidenceLevel(for score: Int) -> DetectionConfidence {
        if score >= 70 {
            return .high
        } else if score >= 25 {
            return .medium
        } else {
            return .low
        }
    }

    func classify(files: [URL], sourceURL: URL, profile: DashcamProfile) -> [ClipItem] {
        let folders = profile.folders.sorted { $0.path.count > $1.path.count }
        let compiledPatterns = profile.filenamePatterns.compactMap { pattern -> (FilenamePattern, NSRegularExpression)? in
            guard let regex = try? NSRegularExpression(pattern: pattern.regexPattern) else { return nil }
            return (pattern, regex)
        }

        return files.compactMap { fileURL in
            let relativePath = fileURL.relativePath(from: sourceURL)
            let filename = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            guard isCandidateExtension(ext) else { return nil }

            var mode = "recording"
            var channel = profile.channels.count == 1 ? (profile.channels.values.first ?? "front") : "unknown"
            var timestamp: Date?
            var excludedReason: String?

            if shouldExclude(relativePath: relativePath, extensionLowercased: ext) {
                excludedReason = "Excluded by safety rules"
            }

            if let folder = folders.first(where: { relativePath == $0.path || relativePath.hasPrefix($0.path + "/") }) {
                mode = folder.mode
                if !folder.importable {
                    excludedReason = "Profile marks this folder as non-importable"
                }
            }

            for (pattern, regex) in compiledPatterns {
                var matchedName: String?
                var matchedResult: NSTextCheckingResult?
                for candidateName in filenameCandidates(for: filename) {
                    let nsCandidate = candidateName as NSString
                    let range = NSRange(location: 0, length: nsCandidate.length)
                    if let match = regex.firstMatch(in: candidateName, range: range), match.range.location != NSNotFound {
                        matchedName = candidateName
                        matchedResult = match
                        break
                    }
                }

                guard let matchedName, let match = matchedResult else { continue }
                let nsFilename = matchedName as NSString

                let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
                    let matchRange = match.range(at: index)
                    guard matchRange.location != NSNotFound else { return nil }
                    return nsFilename.substring(with: matchRange)
                }

                if let mappedMode = firstMappedValue(in: groups, map: pattern.modeMap) {
                    mode = mappedMode
                }
                if let mappedChannel = firstMappedValue(in: groups.sorted { $0.count > $1.count }, map: mergedChannelMap(profile: profile, pattern: pattern)) {
                    channel = physicalChannelLabel(from: mappedChannel)
                }
                if channel == "unknown", profile.channels.count == 1, let onlyChannel = profile.channels.values.first {
                    channel = physicalChannelLabel(from: onlyChannel)
                }
                timestamp = parseTimestamp(groups: groups, format: pattern.timestampFormat)
                break
            }

            if ext == "dat" || relativePath.hasPrefix("GPS/") {
                mode = "gps"
                channel = "gps"
                if ext != "dat" {
                    excludedReason = "GPS/settings sidecar excluded by default"
                }
            }

            let timestampResult = bestTimestamp(filenameTimestamp: timestamp, fileURL: fileURL)
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

            return ClipItem(
                sourceURL: fileURL,
                relativePath: relativePath,
                filename: filename,
                mode: mode,
                channel: channel,
                timestamp: timestampResult.date,
                timestampSource: timestampResult.source,
                size: size,
                extensionLowercased: ext,
                excludedReason: excludedReason,
                inferredParkingPattern: nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
    }

    func classifyWithParkingPatterns(files: [URL], sourceURL: URL, profile: DashcamProfile) -> (clips: [ClipItem], diagnostics: [ScanDiagnosticEntry]) {
        inferParkingPatterns(in: classify(files: files, sourceURL: sourceURL, profile: profile))
    }

    func classifyGenerically(files: [URL], sourceURL: URL) -> [ClipItem] {
        files.compactMap { fileURL in
            let relativePath = fileURL.relativePath(from: sourceURL)
            let filename = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            guard isCandidateExtension(ext) else { return nil }

            var mode = genericMode(relativePath: relativePath, filename: filename, extensionLowercased: ext)
            var channel = genericChannel(relativePath: relativePath, filename: filename)
            var excludedReason: String?

            if shouldExclude(relativePath: relativePath, extensionLowercased: ext) {
                excludedReason = "Excluded by safety rules"
            }

            if ext == "dat" || relativePath.localizedCaseInsensitiveContains("/gps/") || relativePath.lowercased().hasPrefix("gps/") {
                mode = "gps"
                channel = "gps"
                if ext != "dat" {
                    excludedReason = "GPS/settings sidecar excluded by default"
                }
            }

            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            let timestampResult = bestTimestamp(filenameTimestamp: parseGenericTimestamp(filename: filename), fileURL: fileURL)
            return ClipItem(
                sourceURL: fileURL,
                relativePath: relativePath,
                filename: filename,
                mode: mode,
                channel: channel,
                timestamp: timestampResult.date,
                timestampSource: timestampResult.source,
                size: size,
                extensionLowercased: ext,
                excludedReason: excludedReason,
                inferredParkingPattern: nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
    }

    private func inferParkingPatterns(in clips: [ClipItem]) -> (clips: [ClipItem], diagnostics: [ScanDiagnosticEntry]) {
        var inferredByRelativePath: [String: ParkingPattern] = [:]
        var diagnostics: [ScanDiagnosticEntry] = []

        for clip in clips {
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

    private func explicitParkingPattern(for clip: ClipItem) -> ParkingPattern? {
        guard clip.excludedReason == nil, clip.isVideo else { return nil }

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

        if isProtectedFolder && hasParkingChannelSuffix(clip.filename) {
            return .impactDetection
        }

        return nil
    }

    private static func isParkingOutputCategory(_ category: String) -> Bool {
        category == "Parking" || category == "Parking Events"
    }

    private func defaultParkingPattern(for clips: [ClipItem]) -> ParkingPattern? {
        if clips.contains(where: { $0.outputCategory == "Parking Events" }) {
            return .motionOrImpact
        }
        return nil
    }

    private func hasParkingChannelSuffix(_ filename: String) -> Bool {
        let stem = URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return ["PF", "PI", "PR", "PT"].contains { stem.hasSuffix($0) }
    }

    private func hasParkingFilenamePrefix(_ filename: String) -> Bool {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return stem.range(of: #"^P20\d{6}[_-]?\d{6}"#, options: .regularExpression) != nil
    }

    private func inferParkingPatternsByMoment(
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

    private func regularTimelapsePattern(for moments: [(key: Int, timestamp: Date, totalBytes: Int64)]) -> ParkingPattern? {
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

    private func groupedRecordingMoments(_ clips: [ClipItem]) -> [(key: Int, timestamp: Date, totalBytes: Int64)] {
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

    private func relativeFolderPath(for relativePath: String) -> String {
        guard let slashIndex = relativePath.lastIndex(of: "/") else {
            return "."
        }
        return String(relativePath[..<slashIndex])
    }

    private func recordingMomentKey(for timestamp: Date) -> Int {
        Int((timestamp.timeIntervalSince1970 / 2).rounded())
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func enumerateFiles(sourceURL: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.relativePath(from: sourceURL)
            if shouldSkipTraversal(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                files.append(fileURL)
            }
        }
        return files
    }

    private func isSystemVolume(_ url: URL) -> Bool {
        let name = normalizedName(url.lastPathComponent)
        return name == "macintosh hd" ||
            name == "system" ||
            name == "data" ||
            name.hasPrefix("com.apple.")
    }

    private func mountedVolumeRoot(containing url: URL) -> URL? {
        let components = url.standardizedFileURL.pathComponents
        guard components.count >= 3, components[1] == "Volumes" else {
            return nil
        }

        return URL(fileURLWithPath: "/Volumes/\(components[2])", isDirectory: true)
    }

    private func isObviousNonDashcamVolume(_ url: URL) -> Bool {
        let name = normalizedName(url.lastPathComponent)
        let blockedNameFragments = [
            "time machine",
            "timemachine",
            "backup",
            "backups",
            "carbon copy",
            "superduper",
            "clone",
            "start9",
            "bitcoin"
        ]
        if blockedNameFragments.contains(where: { name.contains($0) }) {
            return true
        }

        let blockedRootItems = [
            "Backups.backupdb",
            ".HFS+ Private Directory Data",
            ".com.apple.timemachine.donotpresent"
        ]
        return blockedRootItems.contains { item in
            fileManager.fileExists(atPath: url.appendingPathComponent(item).path)
        }
    }

    private func hasDashcamLikeEvidence(_ url: URL) -> Bool {
        let rootIndicators: Set<String> = [
            "blackvue",
            "bookmark",
            "config",
            "cont_rec",
            "dcim",
            "event",
            "evt_rec",
            "gps",
            "incabin_rec",
            "inf",
            "manual_rec",
            "motion_timelapse_rec",
            "movie",
            "normal",
            "parking",
            "parking_rec",
            "park",
            "pevent",
            "photo",
            "record",
            "rec",
            "setting",
            "settings",
            "sos_rec",
            "user"
        ]

        if let rootItems = try? fileManager.contentsOfDirectory(atPath: url.path) {
            for item in rootItems {
                let normalized = normalizedName(item)
                if rootIndicators.contains(normalized) {
                    return true
                }
            }
        }

        return hasShallowMediaFile(in: url, depth: 0, maxDepth: 2, remainingBudget: 400)
    }

    private func hasShallowMediaFile(in url: URL, depth: Int, maxDepth: Int, remainingBudget: Int) -> Bool {
        guard depth <= maxDepth, remainingBudget > 0 else { return false }
        guard let items = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var budget = remainingBudget
        for item in items {
            guard budget > 0 else { return false }
            budget -= 1

            let relativeName = item.lastPathComponent
            if shouldSkipTraversal(relativePath: relativeName) { continue }

            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isRegularFile == true, isCandidateExtension(item.pathExtension.lowercased()) {
                return true
            }
            if values?.isDirectory == true, hasShallowMediaFile(in: item, depth: depth + 1, maxDepth: maxDepth, remainingBudget: budget) {
                return true
            }
        }
        return false
    }

    private func normalizedName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func detectProfiles(sourceURL: URL, allFiles: [URL], profiles: [DashcamProfile]) -> [DetectionCandidate] {
        profiles.compactMap { profile in
            var score = 0
            var evidence: [String] = []

            if profile.disqualifyingRules.contains(where: { disqualifyingRuleMatches($0, sourceURL: sourceURL) }) {
                return nil
            }

            for rule in profile.detectionRules {
                if detectionRuleMatches(rule, sourceURL: sourceURL) {
                    score += rule.score
                    if let path = rule.path, let contains = rule.contains {
                        evidence.append("model text \(contains) in \(path)")
                    } else if let path = rule.path {
                        evidence.append("model evidence \(path)")
                    } else if let volumeLabel = rule.volumeLabel {
                        evidence.append("volume label \(volumeLabel)")
                    }
                }
            }

            for folder in profile.folders {
                let folderURL = sourceURL.appendingPathComponent(folder.path)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    score += folder.importable ? 8 : 3
                    evidence.append("folder \(folder.path)")
                }
            }

            if volumeLabel(sourceURL.lastPathComponent, matchesProfile: profile) {
                score += 10
                evidence.append("volume label \(sourceURL.lastPathComponent)")
            }

            let sampleNames = representativeDetectionFilenames(from: allFiles)
            var totalFilenameMatches = 0
            for pattern in profile.filenamePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern.regexPattern) else { continue }
                let matchCount = sampleNames.reduce(0) { count, name in
                    let matched = filenameCandidates(for: name).contains { candidateName in
                        let range = NSRange(location: 0, length: (candidateName as NSString).length)
                        return regex.firstMatch(in: candidateName, range: range) != nil
                    }
                    return count + (matched ? 1 : 0)
                }
                totalFilenameMatches += matchCount
            }
            if totalFilenameMatches > 0 {
                score += min(90, 15 + totalFilenameMatches)
                evidence.append("filename pattern match (\(totalFilenameMatches))")
            }

            guard score > 0 else { return nil }
            let confidence = confidenceLevel(for: score)

            return DetectionCandidate(profile: profile, score: score, confidence: confidence, evidence: Array(evidence.prefix(8)))
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.profile.displayName < rhs.profile.displayName
        }
    }

    private func representativeDetectionFilenames(from allFiles: [URL]) -> [String] {
        let candidateFiles = allFiles.filter { isCandidateExtension($0.pathExtension.lowercased()) }
        guard candidateFiles.count > 2_000 else {
            return candidateFiles.map(\.lastPathComponent)
        }

        var result: [String] = []
        var seen = Set<String>()
        let groupedByFolder = Dictionary(grouping: candidateFiles) { fileURL in
            fileURL.deletingLastPathComponent().path
        }
        for folder in groupedByFolder.keys.sorted() {
            for fileURL in groupedByFolder[folder, default: []].prefix(250) {
                let name = fileURL.lastPathComponent
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }

        return Array(result.prefix(5_000))
    }

    private func detectionRuleMatches(_ rule: DetectionRule, sourceURL: URL) -> Bool {
        if let volumeLabel = rule.volumeLabel {
            return compactModelToken(sourceURL.lastPathComponent) == compactModelToken(volumeLabel)
        }

        guard let path = rule.path else { return false }
        let evidenceURL = sourceURL.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: evidenceURL.path) else { return false }

        if rule.exists == true || rule.contains == nil {
            return true
        }

        guard let contains = rule.contains else { return false }
        return evidenceText(at: evidenceURL)?.localizedCaseInsensitiveContains(contains) == true
    }

    private func disqualifyingRuleMatches(_ rule: DetectionRule, sourceURL: URL) -> Bool {
        guard let path = rule.path else { return false }
        let evidenceURL = sourceURL.appendingPathComponent(path)
        let exists = fileManager.fileExists(atPath: evidenceURL.path)

        if rule.mustNotExist == true, exists {
            return true
        }
        if let mustNotContain = rule.mustNotContain,
           exists,
           evidenceText(at: evidenceURL)?.localizedCaseInsensitiveContains(mustNotContain) == true {
            return true
        }

        return false
    }

    private func evidenceText(at url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize,
              fileSize <= 1_000_000,
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func isCandidateExtension(_ ext: String) -> Bool {
        ClipItem.videoExtensions.contains(ext) ||
            ClipItem.photoExtensions.contains(ext) ||
            ClipItem.gpsExtensions.contains(ext)
    }

    private func filenameCandidates(for filename: String) -> [String] {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension
        guard !ext.isEmpty else { return [filename] }

        let stem = url.deletingPathExtension().lastPathComponent
        guard let firstSpace = stem.firstIndex(of: " ") else { return [filename] }

        let rawStem = String(stem[..<firstSpace])
        guard !rawStem.isEmpty else { return [filename] }

        let rawFilename = "\(rawStem).\(ext)"
        return rawFilename == filename ? [filename] : [filename, rawFilename]
    }

    private func shouldSkipTraversal(relativePath: String) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        return parts.contains { part in
            part == ".Spotlight-V100" ||
            part == ".fseventsd" ||
            part == ".Trashes" ||
            part == ".TemporaryItems" ||
            part == ".dashcamexport" ||
            part == ".TWSYS" ||
            part == "System Volume Information"
        }
    }

    private func shouldExclude(relativePath: String, extensionLowercased: String) -> Bool {
        let filename = URL(fileURLWithPath: relativePath).lastPathComponent
        if filename.hasPrefix("._") { return true }
        if ["bin", "exe", "ini", "cfg", "txt"].contains(extensionLowercased) { return true }
        if relativePath.localizedCaseInsensitiveContains("device.uid") { return true }
        if relativePath.localizedCaseInsensitiveContains("thumbnail") { return true }
        if relativePath.localizedCaseInsensitiveContains("setting/") { return true }
        if relativePath.hasPrefix(".TWSYS/") { return true }
        return false
    }

    private func mergedChannelMap(profile: DashcamProfile, pattern: FilenamePattern) -> [String: String] {
        var map = profile.channels
        map.merge(pattern.channelMap) { _, new in new }
        return map
    }

    private func physicalChannelLabel(from value: String) -> String {
        switch value.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") {
        case "parking_front", "pf":
            return "front"
        case "parking_interior", "parking_cabin", "pi":
            return "interior"
        case "parking_rear", "pr":
            return "rear"
        case "parking_telephoto", "pt":
            return "telephoto"
        default:
            return value
        }
    }

    private func volumeLabel(_ label: String, matchesProfile profile: DashcamProfile) -> Bool {
        let normalizedLabel = compactModelToken(label)
        guard !normalizedLabel.isEmpty else { return false }
        return normalizedLabel == compactModelToken(profile.model) ||
            normalizedLabel == compactModelToken(profile.displayName)
    }

    private func compactModelToken(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func firstMappedValue(in groups: [String], map: [String: String]) -> String? {
        for group in groups {
            if let value = map[group] {
                return value
            }
        }
        return nil
    }

    private func genericMode(relativePath: String, filename: String, extensionLowercased: String) -> String {
        if ClipItem.photoExtensions.contains(extensionLowercased) {
            return "photo"
        }

        let pathTokens = genericTokens(from: relativePath)
        let filenameTokens = genericTokens(from: filenameCandidates(for: filename).last ?? filename)
        let tokens = pathTokens + filenameTokens

        if (tokens.contains("protected") || tokens.contains("ro")) && hasParkingFilenamePrefix(filename) {
            return "parking_event"
        }

        if tokens.contains("pevent") ||
            tokens.contains("parkingevent") ||
            containsOrdered(tokens, first: "parking", second: "event") ||
            containsOrdered(tokens, first: "park", second: "event") {
            return "parking_event"
        }

        if tokens.contains("evt") ||
            tokens.contains("event") ||
            tokens.contains("sos") ||
            tokens.contains("emergency") ||
            tokens.contains("locked") ||
            tokens.contains("protected") ||
            tokens.contains("ro") ||
            tokens.contains("manual") ||
            tokens.contains("impact") ||
            filenameModeToken(filename).map(["e", "i"].contains) == true {
            return "driving_event"
        }

        if tokens.contains("parking") ||
            tokens.contains("park") ||
            tokens.contains("prk") ||
            tokens.contains("motion") ||
            tokens.contains("timelapse") ||
            tokens.contains("lapse") ||
            tokens.contains("mot") ||
            filenameModeToken(filename).map(["p", "t"].contains) == true {
            return "parking"
        }

        return "continuous"
    }

    private func bestTimestamp(filenameTimestamp: Date?, fileURL: URL) -> (date: Date?, source: TimestampSource) {
        if let filenameTimestamp {
            return (filenameTimestamp, .filename)
        }

        let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        if let modified = values?.contentModificationDate {
            return (modified, .filesystemModified)
        }
        if let created = values?.creationDate {
            return (created, .filesystemCreated)
        }
        return (nil, .none)
    }

    private func genericChannel(relativePath: String, filename: String) -> String {
        let tokens = genericTokens(from: relativePath) + genericTokens(from: filenameCandidates(for: filename).last ?? filename)

        if tokens.contains("front") || tokens.contains("frontcam") || tokens.contains("frontcamera") {
            return "front"
        }
        if tokens.contains("rear") || tokens.contains("back") || tokens.contains("rearcam") || tokens.contains("rearcamera") {
            return "rear"
        }
        if tokens.contains("interior") || tokens.contains("inside") || tokens.contains("cabin") || tokens.contains("incabin") {
            return "interior"
        }

        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        let compactStem = stem.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        if let last = compactStem.last {
            switch last {
            case "F":
                return "front"
            case "R":
                return "rear"
            case "I":
                return "interior"
            default:
                break
            }
        }

        return "unknown"
    }

    private func genericTokens(from value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func containsOrdered(_ tokens: [String], first: String, second: String) -> Bool {
        guard let firstIndex = tokens.firstIndex(of: first) else { return false }
        return tokens[(firstIndex + 1)...].contains(second)
    }

    private func filenameModeToken(_ filename: String) -> String? {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        let compactStem = stem.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        // BlackVue-like suffixes: NF/NR, EF/ER, IF/IR, PF/PR.
        if compactStem.count >= 2 {
            let suffix = String(compactStem.suffix(2))
            if ["NF", "NR", "NI", "EF", "ER", "EI", "IF", "IR", "II", "PF", "PR", "PI", "TF", "TR", "TI"].contains(suffix),
               let first = suffix.first {
                return String(first).lowercased()
            }
        }

        let tokens = genericTokens(from: stem)
        return tokens.reversed().first { ["n", "e", "i", "p", "t", "vid", "sos"].contains($0) }
    }

    private func parseGenericTimestamp(filename: String) -> Date? {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent

        let patterns: [(String, String)] = [
            ("(20\\d{6})[^0-9]?(\\d{6})", "yyyyMMddHHmmss"),
            ("(20\\d{2})[^0-9]?(\\d{4})[^0-9]?(\\d{6})", "yyyyMMddHHmmss"),
            ("(20\\d{2})[^0-9]?(\\d{2})[^0-9]?(\\d{2})[^0-9]+(\\d{2})[^0-9]?(\\d{2})[^0-9]?(\\d{2})", "yyyyMMddHHmmss")
        ]

        for (pattern, format) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsStem = stem as NSString
            let range = NSRange(location: 0, length: nsStem.length)
            guard let match = regex.firstMatch(in: stem, range: range) else { continue }
            let value = (1..<match.numberOfRanges).compactMap { index -> String? in
                let matchRange = match.range(at: index)
                guard matchRange.location != NSNotFound else { return nil }
                return nsStem.substring(with: matchRange)
            }
            .joined()
            if let date = parseDate(value, format: format) {
                return date
            }
        }

        // Date-only filenames can still help day filtering/grouping, but leave
        // time unknown at midnight rather than inventing a sequence-derived time.
        if let regex = try? NSRegularExpression(pattern: "(20\\d{6})") {
            let nsStem = stem as NSString
            let range = NSRange(location: 0, length: nsStem.length)
            if let match = regex.firstMatch(in: stem, range: range),
               match.range(at: 1).location != NSNotFound {
                return parseDate(nsStem.substring(with: match.range(at: 1)), format: "yyyyMMdd")
            }
        }

        return nil
    }

    private func parseTimestamp(groups: [String], format: TimestampFormat) -> Date? {
        switch format {
        case .yyyymmddHhmmss:
            // Some patterns have a mode-prefix group before the date
            // (e.g. Thinkware: ["REC", "20230427", "154533", "F"]).
            // Only use the explicit groups[0]+groups[1] path when groups[0]
            // is already an 8-char date string; otherwise fall back to the
            // heuristic which scans for the first 8-char/6-char pair.
            guard groups.count >= 2 else { return nil }
            if groups[0].count == 8, groups[1].count == 6 {
                return parseDate(groups[0] + groups[1], format: "yyyyMMddHHmmss")
            }
            return parseTimestampHeuristically(groups: groups)
        case .yyyyMmddHhmmss:
            guard groups.count >= 3 else { return nil }
            return parseDate(groups[0] + groups[1] + groups[2], format: "yyyyMMddHHmmss")
        case .yyyymmddDashHhmmss:
            guard groups.count >= 6 else { return nil }
            return parseDate(groups[1] + groups[2] + groups[3] + groups[4] + groups[5] + groups[6], format: "yyyyMMddHHmmss")
        case .unknown:
            return parseTimestampHeuristically(groups: groups)
        }
    }

    private func parseTimestampHeuristically(groups: [String]) -> Date? {
        for index in groups.indices {
            let value = groups[index]
            if value.count == 8, index + 1 < groups.count, groups[index + 1].count == 6 {
                return parseDate(value + groups[index + 1], format: "yyyyMMddHHmmss")
            }
            if value.count == 4, index + 2 < groups.count, groups[index + 1].count == 4, groups[index + 2].count == 6 {
                return parseDate(value + groups[index + 1] + groups[index + 2], format: "yyyyMMddHHmmss")
            }
        }
        return nil
    }

    private func parseDate(_ value: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter.date(from: value)
    }
}

struct ScanResult {
    var sourceURL: URL
    var allFiles: [URL]
    var candidates: [DetectionCandidate]
    var selectedProfile: DashcamProfile?
    var clips: [ClipItem]
    var diagnostics: [ScanDiagnosticEntry]
}

extension URL {
    func relativePath(from baseURL: URL) -> String {
        let base = baseURL.standardizedFileURL.path
        let full = standardizedFileURL.path
        if full == base { return lastPathComponent }
        if full.hasPrefix(base + "/") {
            return String(full.dropFirst(base.count + 1))
        }
        return lastPathComponent
    }
}
