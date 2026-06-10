import Foundation

struct ProfileStore {
    var profilesDirectory: URL

    func loadProfiles() throws -> [DashcamProfile] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "yaml" || $0.pathExtension.lowercased() == "yml" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try urls.compactMap { url in
            try ProfileParser.parse(url: url)
        }
    }

    static func defaultProfilesDirectory() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("Profiles", isDirectory: true))
        }

        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        candidates.append(current.appendingPathComponent("profiles", isDirectory: true))
        candidates.append(current.deletingLastPathComponent().appendingPathComponent("profiles", isDirectory: true))

        let executable = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
        let executableDirectory = executable.deletingLastPathComponent()
        candidates.append(executableDirectory.appendingPathComponent("profiles", isDirectory: true))
        candidates.append(executableDirectory.deletingLastPathComponent().appendingPathComponent("profiles", isDirectory: true))
        candidates.append(executableDirectory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("profiles", isDirectory: true))

        return candidates.first { candidate in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }
}

enum ProfileParser {
    static func parse(url: URL) throws -> DashcamProfile? {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines)

        let id = scalar("id", in: lines) ?? scalar("slug", in: lines) ?? url.deletingPathExtension().lastPathComponent
        let manufacturer = scalar("manufacturer", in: lines) ??
            scalar("make", in: lines) ??
            nestedScalar("camera", key: "brand", in: lines) ??
            "Unknown"
        let model = scalar("model", in: lines) ??
            nestedScalar("camera", key: "model", in: lines) ??
            id
        let status = scalar("status", in: lines) ?? "seed"
        let confidence = scalar("confidence", in: lines) ?? "medium"
        let folders = parseFolders(lines)
        let patterns = parseFilenamePatterns(lines)
        let channels = parseChannels(lines, patterns: patterns)
        let detectionRules = parseDetectionRules(lines)
        let disqualifyingRules = parseDisqualifyingRules(lines)
        let osdSpec = parseOSDSpec(lines)

        guard !folders.isEmpty || !patterns.isEmpty else { return nil }

        return DashcamProfile(
            id: id,
            manufacturer: manufacturer,
            model: model,
            status: status,
            confidence: confidence,
            folders: folders,
            filenamePatterns: patterns,
            channels: channels,
            detectionRules: detectionRules,
            disqualifyingRules: disqualifyingRules,
            osdSpec: osdSpec
        )
    }

    private static func scalar(_ key: String, in lines: [String]) -> String? {
        let prefix = "\(key):"
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return cleanValue(String(line.dropFirst(prefix.count)))
    }

    private static func nestedScalar(_ blockName: String, key: String, in lines: [String]) -> String? {
        guard let range = topLevelBlock(named: blockName, in: lines) else { return nil }
        let prefix = "\(key):"
        guard let line = lines[range].first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }) else {
            return nil
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return cleanValue(String(trimmed.dropFirst(prefix.count)))
    }

    private static func parseFolders(_ lines: [String]) -> [ProfileFolder] {
        guard let range = topLevelBlock(named: "folders", in: lines) else { return [] }
        var folders: [ProfileFolder] = []
        var currentPath: String?
        var currentMode = "recording"
        var importable = true

        func flush() {
            if let path = currentPath {
                folders.append(ProfileFolder(path: path, mode: currentMode, importable: importable))
            }
            currentPath = nil
            currentMode = "recording"
            importable = true
        }

        for line in lines[range] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- path:") {
                flush()
                currentPath = cleanValue(String(trimmed.dropFirst("- path:".count)))
            } else if trimmed.hasPrefix("mode:") {
                currentMode = cleanValue(String(trimmed.dropFirst("mode:".count))) ?? currentMode
            } else if trimmed.hasPrefix("import:") {
                importable = (cleanValue(String(trimmed.dropFirst("import:".count))) ?? "true") != "false"
            }
        }
        flush()
        return folders
    }

    private static func parseFilenamePatterns(_ lines: [String]) -> [FilenamePattern] {
        var patterns: [FilenamePattern] = []
        var inFilenameSection = false
        var currentPattern: String?
        var modeMap: [String: String] = [:]
        var channelMap: [String: String] = [:]
        var currentMap: String?
        var timestampFormat = TimestampFormat.unknown

        func flush() {
            guard let raw = currentPattern else { return }
            let normalized = normalizeRegex(raw)
            patterns.append(FilenamePattern(
                rawPattern: raw,
                regexPattern: normalized,
                modeMap: modeMap,
                channelMap: channelMap,
                timestampFormat: timestampFormat
            ))
            currentPattern = nil
            modeMap = [:]
            channelMap = [:]
            currentMap = nil
            timestampFormat = .unknown
        }

        for line in lines {
            if line.hasPrefix("filename_patterns:") || line.hasPrefix("filename_pattern:") {
                inFilenameSection = true
                continue
            }

            if inFilenameSection && isTopLevel(line), !line.hasPrefix("filename_") {
                flush()
                inFilenameSection = false
            }

            guard inFilenameSection else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- pattern:") || trimmed.hasPrefix("regex:") || trimmed.hasPrefix("pattern:") {
                flush()
                let key = trimmed.hasPrefix("- pattern:") ? "- pattern:" : (trimmed.hasPrefix("pattern:") ? "pattern:" : "regex:")
                currentPattern = cleanValue(String(trimmed.dropFirst(key.count)))
            } else if trimmed == "modes:" {
                currentMap = "modes"
            } else if trimmed == "channels:" {
                currentMap = "channels"
            } else if trimmed.hasPrefix("format:") {
                let value = cleanValue(String(trimmed.dropFirst("format:".count))) ?? ""
                timestampFormat = parseTimestampFormat(value)
            } else if let map = currentMap, let pair = parseMapPair(trimmed) {
                if map == "modes" {
                    modeMap[pair.key] = pair.value
                } else if map == "channels" {
                    channelMap[pair.key] = pair.value
                }
            }
        }
        flush()

        return patterns
    }

    private static func parseChannels(_ lines: [String], patterns: [FilenamePattern]) -> [String: String] {
        var channels: [String: String] = [:]

        for pattern in patterns {
            channels.merge(pattern.channelMap) { current, _ in current }
        }

        channels.merge(parseCameraChannelLabels(lines)) { current, _ in current }

        guard let range = topLevelBlock(named: "channels", in: lines) else {
            return channels
        }

        // Two valid YAML shapes for channels:
        //
        // Flat:   F: front          → direct key:value pair
        //         R: rear
        //
        // Nested: F:                → bare key sets pendingKey
        //           position: front → first position: line under pendingKey wins
        //           bitrate: higher → (other nested fields are ignored)
        //
        // The old code fired parseMapPair on "position: front" before the
        // position: handler could run, storing channels["position"] = "front"
        // and discarding the "F" / "R" keys entirely.
        //
        // Fix: only use parseMapPair when there is no active pendingKey
        // (flat shape), and only accept a bare key-with-no-value (no spaces
        // before the colon, nothing after) as a pendingKey setter.

        var pendingKey: String?
        for line in lines[range] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Bare key (e.g. "F:", "R:") — starts a nested channel entry.
            // Must not contain a space (rules out "position: front" etc.).
            if trimmed.hasSuffix(":") && !trimmed.contains(" ") {
                pendingKey = String(trimmed.dropLast())

            // position: value under a pending channel key → assign the channel.
            } else if trimmed.hasPrefix("position:"), let pk = pendingKey {
                channels[pk] = cleanValue(String(trimmed.dropFirst("position:".count))) ?? pk

            // Flat key: value pair (only when not inside a nested entry).
            } else if pendingKey == nil, let pair = parseMapPair(trimmed), !pair.value.isEmpty {
                channels[pair.key] = pair.value
            }
            // All other nested fields (bitrate:, observed_file_size_bytes:, etc.) are skipped.
        }

        return channels
    }

    private static func parseCameraChannelLabels(_ lines: [String]) -> [String: String] {
        guard let cameraRange = topLevelBlock(named: "camera", in: lines),
              let labelsStart = lines[cameraRange].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "channel_labels:" }) else {
            return [:]
        }

        var labels: [String: String] = [:]
        for line in lines[(labelsStart + 1)..<cameraRange.upperBound] {
            guard line.hasPrefix("    ") else { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let pair = parseMapPair(trimmed), !pair.key.isEmpty, !pair.value.isEmpty else {
                continue
            }
            labels[pair.key] = pair.value
        }
        return labels
    }

    private static func parseDetectionRules(_ lines: [String]) -> [DetectionRule] {
        guard let detectionRange = topLevelBlock(named: "detection", in: lines) else { return [] }
        let detectionLines = Array(lines[detectionRange])
        var rules: [DetectionRule] = []
        var currentSection: String?
        var currentRule: DetectionRule?

        func sectionScore(_ section: String?, for rule: DetectionRule) -> Int {
            if rule.volumeLabel != nil {
                return section == "supporting" ? 8 : 20
            }
            return section == "supporting" ? 18 : 60
        }

        func flush() {
            guard var rule = currentRule else { return }
            if rule.score == 0 {
                rule.score = sectionScore(currentSection, for: rule)
            }
            if rule.path != nil || rule.volumeLabel != nil {
                rules.append(rule)
            }
            currentRule = nil
        }

        for line in detectionLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") && !trimmed.hasPrefix("-") {
                flush()
                currentSection = String(trimmed.dropLast())
                continue
            }

            guard currentSection == "high_confidence" || currentSection == "supporting" else {
                continue
            }

            if trimmed.hasPrefix("- path:") {
                flush()
                currentRule = DetectionRule(
                    path: cleanValue(String(trimmed.dropFirst("- path:".count))),
                    contains: nil,
                    exists: nil,
                    volumeLabel: nil,
                    mustNotContain: nil,
                    mustNotExist: nil,
                    score: 0
                )
            } else if trimmed.hasPrefix("- volume_label:") {
                flush()
                currentRule = DetectionRule(
                    path: nil,
                    contains: nil,
                    exists: nil,
                    volumeLabel: cleanValue(String(trimmed.dropFirst("- volume_label:".count))),
                    mustNotContain: nil,
                    mustNotExist: nil,
                    score: 0
                )
            } else if trimmed.hasPrefix("contains:") {
                currentRule?.contains = cleanValue(String(trimmed.dropFirst("contains:".count)))
            } else if trimmed.hasPrefix("exists:") {
                currentRule?.exists = (cleanValue(String(trimmed.dropFirst("exists:".count))) ?? "true") != "false"
            }
        }
        flush()
        return rules
    }

    private static func parseDisqualifyingRules(_ lines: [String]) -> [DetectionRule] {
        guard let detectionRange = topLevelBlock(named: "detection", in: lines) else { return [] }
        let detectionLines = Array(lines[detectionRange])
        var rules: [DetectionRule] = []
        var currentRule: DetectionRule?

        func flush() {
            guard let rule = currentRule else { return }
            if rule.path != nil && (rule.mustNotContain != nil || rule.mustNotExist == true) {
                rules.append(rule)
            }
            currentRule = nil
        }

        for line in detectionLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- path:") {
                flush()
                currentRule = DetectionRule(
                    path: cleanValue(String(trimmed.dropFirst("- path:".count))),
                    contains: nil,
                    exists: nil,
                    volumeLabel: nil,
                    mustNotContain: nil,
                    mustNotExist: nil,
                    score: 0
                )
            } else if trimmed.hasPrefix("must_not_contain:") {
                currentRule?.mustNotContain = cleanValue(String(trimmed.dropFirst("must_not_contain:".count)))
            } else if trimmed.hasPrefix("must_not_exist:") {
                currentRule?.mustNotExist = (cleanValue(String(trimmed.dropFirst("must_not_exist:".count))) ?? "true") != "false"
            }
        }
        flush()
        return rules
    }

    /// Parses an `osd_ocr` detection entry from `detection.high_confidence`.
    ///
    /// Example YAML:
    /// ```
    /// detection:
    ///   high_confidence:
    ///     - method: osd_ocr
    ///       source: front_channel_video
    ///       strip: bottom_8pct
    ///       threshold_method: half_max_brightness
    ///       matches: "VIOFO A229 Pro"
    /// ```
    ///
    /// Returns `nil` when no `osd_ocr` entry exists. The OSD lives on the
    /// front channel for VIOFO, so `probeChannels` is always `["F"]`.
    private static func parseOSDSpec(_ lines: [String]) -> OSDSpec? {
        guard let detectionRange = topLevelBlock(named: "detection", in: lines) else { return nil }
        let detectionLines = Array(lines[detectionRange])
        guard let highStart = detectionLines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "high_confidence:" }) else {
            return nil
        }

        var foundOSD = false
        var matches: String?
        var stripPercent = 0.08

        for line in detectionLines[(highStart + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at the next top-level (non-list, non-nested) key.
            if trimmed.hasSuffix(":") && !trimmed.hasPrefix("-") {
                let key = String(trimmed.dropLast())
                if key == "medium_confidence" || key == "low_confidence" || key == "negative" {
                    break
                }
            }

            // A new list item starting a non-osd_ocr method ends the current
            // entry; reset so we don't pick up a `matches:` from another item.
            if trimmed.hasPrefix("- method:") {
                let method = cleanValue(String(trimmed.dropFirst("- method:".count)))
                foundOSD = (method == "osd_ocr")
                continue
            }

            guard foundOSD else { continue }

            if trimmed.hasPrefix("matches:") {
                matches = cleanValue(String(trimmed.dropFirst("matches:".count)))
            } else if trimmed.hasPrefix("strip:") {
                let raw = cleanValue(String(trimmed.dropFirst("strip:".count))) ?? ""
                stripPercent = parseStripPercent(raw)
            }
        }

        guard let matched = matches, !matched.isEmpty else { return nil }

        return OSDSpec(
            containsModelName: true,
            matchStrings: [matched],
            stripPercent: stripPercent,
            probeChannels: ["F"]
        )
    }

    /// Parses "bottom_8pct" -> 0.08, "bottom_10pct" -> 0.10. Defaults to 0.08.
    private static func parseStripPercent(_ value: String) -> Double {
        let lowered = value.lowercased()
        let digits = lowered.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        if let percent = Int(digits), percent > 0 {
            return Double(percent) / 100.0
        }
        return 0.08
    }

    private static func topLevelBlock(named name: String, in lines: [String]) -> Range<Int>? {
        guard let start = lines.firstIndex(where: { $0 == "\(name):" }) else { return nil }
        var end = lines.count
        for index in (start + 1)..<lines.count {
            if isTopLevel(lines[index]) {
                end = index
                break
            }
        }
        return (start + 1)..<end
    }

    private static func isTopLevel(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        return !line.first!.isWhitespace && line.hasSuffix(":")
    }

    private static func cleanValue(_ value: String) -> String? {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commentIndex = result.firstIndex(of: "#") {
            result = String(result[..<commentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if (result.hasPrefix("'") && result.hasSuffix("'")) || (result.hasPrefix("\"") && result.hasSuffix("\"")) {
            result = String(result.dropFirst().dropLast())
        }
        result = result.replacingOccurrences(of: "\\\\", with: "\\")
        return result.isEmpty ? nil : result
    }

    private static func parseMapPair(_ value: String) -> (key: String, value: String)? {
        guard let colon = value.firstIndex(of: ":") else { return nil }
        let key = String(value[..<colon]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(value[value.index(after: colon)...])
        guard let clean = cleanValue(rawValue) else { return (key, "") }
        return (key, clean)
    }

    private static func normalizeRegex(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"(?P<[^>]+>"#, with: "(", options: .regularExpression)
    }

    private static func parseTimestampFormat(_ value: String) -> TimestampFormat {
        switch value {
        case "YYYYMMDD_HHMMSS": return .yyyymmddHhmmss
        case "YYYY_MMDD_HHMMSS": return .yyyyMmddHhmmss
        case "YYYYMMDD-HHMMSS": return .yyyymmddDashHhmmss
        default: return .unknown
        }
    }
}
