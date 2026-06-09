import Foundation

struct CardScanner {
    private let fileManager = FileManager.default

    func discoverMountedSources(showAllVolumes: Bool = false) -> [MountedSource] {
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: Set<URLResourceKey>([.isDirectoryKey]))
                guard values?.isDirectory == true else { return false }
                return shouldShowMountedSource(url, showAllVolumes: showAllVolumes)
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MountedSource(url: $0, name: $0.lastPathComponent) }
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
        let selectedProfile = topCandidate?.confidence == .low ? DashcamProfile.genericNewDashcam : topCandidate?.profile
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
            result.clips = classify(files: result.allFiles, sourceURL: sourceURL, profile: newTop.profile)
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
                    channel = mappedChannel
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
        let parkingClips = clips.filter { clip in
            clip.excludedReason == nil &&
                clip.isVideo &&
                clip.outputCategory == "Parking" &&
                clip.timestamp != nil &&
                !clip.hasSuspiciousTimestamp
        }

        guard parkingClips.count >= 4 else {
            return (clips, [])
        }

        let groupedByFolder = Dictionary(grouping: parkingClips) { clip in
            URL(fileURLWithPath: clip.relativePath).deletingLastPathComponent().path
        }

        var inferredByRelativePath: [String: ParkingPattern] = [:]
        var diagnostics: [ScanDiagnosticEntry] = []

        for (folder, folderClips) in groupedByFolder {
            let moments = groupedRecordingMoments(folderClips)
            guard moments.count >= 4 else { continue }

            let intervals = zip(moments, moments.dropFirst()).map { lhs, rhs in
                rhs.timestamp.timeIntervalSince(lhs.timestamp)
            }
            guard let medianInterval = median(intervals), medianInterval > 0 else { continue }

            let consistentIntervalCount = intervals.filter { interval in
                abs(interval - medianInterval) <= max(30, medianInterval * 0.25)
            }.count
            let consistency = intervals.isEmpty ? 0 : Double(consistentIntervalCount) / Double(intervals.count)
            let medianMomentSize = median(moments.map(\.totalBytes).map(Double.init)) ?? 0

            let pattern: ParkingPattern
            if medianInterval <= 210, consistency >= 0.6 {
                pattern = .continuousLowBitrate
            } else if medianInterval >= 300, medianInterval <= 7_200, consistency >= 0.55, medianMomentSize <= 300_000_000 {
                pattern = .timelapse
            } else {
                pattern = .motionOrImpact
            }

            for clip in folderClips {
                inferredByRelativePath[clip.relativePath] = pattern
            }

            diagnostics.append(ScanDiagnosticEntry(
                stage: "parking_pattern_inference",
                profileID: nil,
                profileName: nil,
                outcome: pattern.rawValue,
                detail: "\(folder.isEmpty ? "." : folder): \(moments.count) recording moments, median gap \(Int(medianInterval))s, interval consistency \(Int(consistency * 100))%, median bytes per moment \(Int64(medianMomentSize))"
            ))
        }

        guard !inferredByRelativePath.isEmpty else {
            return (clips, diagnostics)
        }

        let annotated = clips.map { clip in
            guard let inferred = inferredByRelativePath[clip.relativePath] else { return clip }
            var copy = clip
            copy.inferredParkingPattern = inferred
            return copy
        }
        return (annotated, diagnostics)
    }

    private func groupedRecordingMoments(_ clips: [ClipItem]) -> [(timestamp: Date, totalBytes: Int64)] {
        let grouped = Dictionary(grouping: clips) { clip -> Int in
            guard let timestamp = clip.timestamp else { return 0 }
            return Int((timestamp.timeIntervalSince1970 / 2).rounded())
        }
        return grouped.compactMap { _, clips -> (timestamp: Date, totalBytes: Int64)? in
            guard let timestamp = clips.compactMap(\.timestamp).min() else { return nil }
            return (timestamp, clips.reduce(Int64(0)) { $0 + $1.size })
        }
        .sorted { $0.timestamp < $1.timestamp }
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

            for folder in profile.folders {
                let folderURL = sourceURL.appendingPathComponent(folder.path)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    score += folder.importable ? 8 : 3
                    evidence.append("folder \(folder.path)")
                }
            }

            for path in profile.highConfidencePaths {
                let evidenceURL = sourceURL.appendingPathComponent(path)
                if fileManager.fileExists(atPath: evidenceURL.path) {
                    score += 60
                    evidence.append("model evidence \(path)")
                }
            }

            let sampleNames = allFiles.prefix(600).map(\.lastPathComponent)
            for pattern in profile.filenamePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern.regexPattern) else { continue }
                let matchCount = sampleNames.reduce(0) { count, name in
                    let matched = filenameCandidates(for: name).contains { candidateName in
                        let range = NSRange(location: 0, length: (candidateName as NSString).length)
                        return regex.firstMatch(in: candidateName, range: range) != nil
                    }
                    return count + (matched ? 1 : 0)
                }
                if matchCount > 0 {
                    score += min(60, 15 + matchCount)
                    evidence.append("filename pattern match (\(matchCount))")
                    break
                }
            }

            guard score > 0 else { return nil }
            let confidence = confidenceLevel(for: score)

            return DetectionCandidate(profile: profile, score: score, confidence: confidence, evidence: Array(evidence.prefix(5)))
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.profile.displayName < rhs.profile.displayName
        }
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
