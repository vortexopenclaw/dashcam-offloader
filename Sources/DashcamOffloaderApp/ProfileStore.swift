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

        let id = scalar("id", in: lines) ?? url.deletingPathExtension().lastPathComponent
        let manufacturer = scalar("manufacturer", in: lines) ?? "Unknown"
        let model = scalar("model", in: lines) ?? id
        let status = scalar("status", in: lines) ?? "seed"
        let confidence = scalar("confidence", in: lines) ?? "medium"
        let folders = parseFolders(lines)
        let patterns = parseFilenamePatterns(lines)
        let channels = parseChannels(lines, patterns: patterns)
        let highConfidencePaths = parseDetectionPaths(lines)

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
            highConfidencePaths: highConfidencePaths
        )
    }

    private static func scalar(_ key: String, in lines: [String]) -> String? {
        let prefix = "\(key):"
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return cleanValue(String(line.dropFirst(prefix.count)))
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

        guard let range = topLevelBlock(named: "channels", in: lines) else {
            return channels
        }

        var pendingKey: String?
        for line in lines[range] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let pair = parseMapPair(trimmed), !pair.value.isEmpty {
                channels[pair.key] = pair.value
                pendingKey = nil
            } else if trimmed.hasSuffix(":") {
                pendingKey = String(trimmed.dropLast())
            } else if trimmed.hasPrefix("position:"), let pendingKey {
                channels[pendingKey] = cleanValue(String(trimmed.dropFirst("position:".count))) ?? pendingKey
            }
        }

        return channels
    }

    private static func parseDetectionPaths(_ lines: [String]) -> [String] {
        guard let detectionRange = topLevelBlock(named: "detection", in: lines) else { return [] }
        let detectionLines = Array(lines[detectionRange])
        guard let highStart = detectionLines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "high_confidence:" }) else {
            return []
        }

        var paths: [String] = []
        for line in detectionLines[(highStart + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("path:") {
                break
            }
            if trimmed.hasPrefix("- path:") {
                if let value = cleanValue(String(trimmed.dropFirst("- path:".count))) {
                    paths.append(value)
                }
            }
        }
        return paths
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
