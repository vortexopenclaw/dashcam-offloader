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

    func shouldShowMountedSource(_ url: URL, showAllVolumes: Bool) -> Bool {
        if isSystemVolume(url) { return false }
        if showAllVolumes { return true }
        if isObviousNonDashcamVolume(url) { return false }
        return hasDashcamLikeEvidence(url)
    }

    func scan(sourceURL: URL, profiles: [DashcamProfile]) throws -> ScanResult {
        let allFiles = try enumerateFiles(sourceURL: sourceURL)
        let candidates = detectProfiles(sourceURL: sourceURL, allFiles: allFiles, profiles: profiles)
        let selectedProfile = candidates.first?.profile ?? profiles.first
        let clips = selectedProfile.map { classify(files: allFiles, sourceURL: sourceURL, profile: $0) } ?? []

        return ScanResult(
            sourceURL: sourceURL,
            allFiles: allFiles,
            candidates: candidates,
            selectedProfile: selectedProfile,
            clips: clips
        )
    }

    /// Async scan that augments folder/filename detection with OSD OCR to
    /// disambiguate sibling models (e.g. VIOFO A229 Pro vs Plus vs Ultra).
    ///
    /// OSD probing only runs when the result is genuinely ambiguous: the top
    /// candidate is `.medium` confidence and at least one other candidate
    /// scores within 15 points of it. A confirmed OSD match bumps that
    /// profile's score by 80, re-sorts the candidates, and re-selects the
    /// winner. OSD probing is best-effort — a failed probe leaves the
    /// original result unchanged.
    func scanWithOSD(sourceURL: URL, profiles: [DashcamProfile]) async throws -> ScanResult {
        var result = try scan(sourceURL: sourceURL, profiles: profiles)

        guard let top = result.candidates.first, top.confidence == .medium else {
            return result
        }

        // Disambiguation only matters when another candidate is close behind.
        let hasCompetition = result.candidates.dropFirst().contains { abs(top.score - $0.score) <= 15 }
        guard hasCompetition else { return result }

        let probe = OSDProbe()
        var updatedCandidates = result.candidates

        for index in updatedCandidates.indices {
            guard let spec = updatedCandidates[index].profile.osdSpec, spec.containsModelName else { continue }

            guard let sampleVideo = sampleVideo(
                for: spec,
                allFiles: result.allFiles
            ) else { continue }

            if let matched = await probe.probe(videoURL: sampleVideo, spec: spec) {
                updatedCandidates[index].score += 80
                var evidence = updatedCandidates[index].evidence
                evidence.append("OSD OCR match \"\(matched)\"")
                updatedCandidates[index].evidence = Array(evidence.prefix(6))
                updatedCandidates[index].confidence = confidenceLevel(for: updatedCandidates[index].score)
            }
        }

        updatedCandidates.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.profile.displayName < rhs.profile.displayName
        }

        result.candidates = updatedCandidates

        // Re-select and re-classify if the winner changed.
        if let newTop = updatedCandidates.first, newTop.profile.id != result.selectedProfile?.id {
            result.selectedProfile = newTop.profile
            result.clips = classify(files: result.allFiles, sourceURL: sourceURL, profile: newTop.profile)
        } else if result.selectedProfile == nil {
            result.selectedProfile = updatedCandidates.first?.profile
        }

        return result
    }

    /// Finds a front-channel sample video matching the OSD spec's channels.
    /// VIOFO front clips end in a channel suffix (e.g. `..._F.MP4`). Falls
    /// back to any video if no channel-suffixed clip is found.
    private func sampleVideo(for spec: OSDSpec, allFiles: [URL]) -> URL? {
        let videos = allFiles.filter { ["mp4", "mov"].contains($0.pathExtension.lowercased()) }
        guard !videos.isEmpty else { return nil }

        for channel in spec.probeChannels {
            let suffix = channel.uppercased()
            if let match = videos.first(where: { url in
                let stem = url.deletingPathExtension().lastPathComponent.uppercased()
                return stem.hasSuffix(suffix)
            }) {
                return match
            }
        }

        // No channel-suffixed clip; the OSD is still likely on any front clip.
        return videos.first
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
                let nsFilename = filename as NSString
                let range = NSRange(location: 0, length: nsFilename.length)
                guard let match = regex.firstMatch(in: filename, range: range), match.range.location != NSNotFound else {
                    continue
                }

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

            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

            return ClipItem(
                sourceURL: fileURL,
                relativePath: relativePath,
                filename: filename,
                mode: mode,
                channel: channel,
                timestamp: timestamp,
                size: size,
                extensionLowercased: ext,
                excludedReason: excludedReason
            )
        }
        .sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
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

            for modelEvidence in profile.highConfidenceEvidence {
                let evidenceURL = sourceURL.appendingPathComponent(modelEvidence.path)
                if fileManager.fileExists(atPath: evidenceURL.path) {
                    if modelEvidence.contains.isEmpty || fileContains(evidenceURL, all: modelEvidence.contains) {
                        score += 60
                        evidence.append("model evidence \(modelEvidence.path)")
                    }
                }
            }

            let sampleNames = allFiles.prefix(80).map(\.lastPathComponent)
            for pattern in profile.filenamePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern.regexPattern) else { continue }
                if sampleNames.contains(where: { name in
                    let range = NSRange(location: 0, length: (name as NSString).length)
                    return regex.firstMatch(in: name, range: range) != nil
                }) {
                    score += 20
                    evidence.append("filename pattern match")
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
        ["mp4", "mov", "jpg", "jpeg", "dat"].contains(ext)
    }

    private func fileContains(_ url: URL, all needles: [String]) -> Bool {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return false
        }

        return needles.allSatisfy { needle in
            guard let needleData = needle.data(using: .utf8), !needleData.isEmpty else { return false }
            return data.range(of: needleData) != nil
        }
    }

    private func shouldSkipTraversal(relativePath: String) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        return parts.contains { part in
            part == ".Spotlight-V100" ||
            part == ".fseventsd" ||
            part == ".Trashes" ||
            part == ".TemporaryItems" ||
            part == ".dashcamexport" ||
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

    private func parseTimestamp(groups: [String], format: TimestampFormat) -> Date? {
        switch format {
        case .yyyymmddHhmmss:
            guard groups.count >= 2 else { return nil }
            return parseDate(groups[0] + groups[1], format: "yyyyMMddHHmmss")
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
