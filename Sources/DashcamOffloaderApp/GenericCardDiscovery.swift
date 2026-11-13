import Foundation
import CoreFoundation
import Darwin

/// Private, unbound declarations only. This is not an identity recognizer.
struct GenericCardDiscovery: Codable, Hashable, Sendable {
    struct Source: Codable, Hashable, Sendable {
        var id: String
        var format: String
        var encoding: String
        var sizeBytes: Int
    }
    struct Observation: Codable, Hashable, Sendable {
        var sourceId: String
        var field: String
        var key: String
        var value: String
        var line: Int
        var record: Int
        var scope = "unbound"
    }
    struct Coverage: Codable, Hashable, Sendable {
        var inventoriedCandidates = 0
        var inspectedFiles = 0
        var uninspectedFiles = 0
        var retainedObservations = 0
        var omittedObservations = 0
        var bytesRead = 0
        var limited = false
        var multipleModelValues = false
        var reasons: [String: Int] = [:]
    }
    var version = 1
    var sources: [Source] = []
    var observations: [Observation] = []
    var coverage = Coverage()

    static let groups: [String: [String]] = [
        "manufacturer": ["manufacturer", "make", "vendor", "brand"],
        "model": ["model", "model_name", "camera_model", "device_model", "product_model", "dev_model", "rear_model", "inside_model", "front_model", "rc_model"],
        "firmware": ["firmware", "firmware_version", "fw_version", "fw", "soft_version", "software_version", "rear_version", "inside_version", "micom_version"],
        "build": ["build", "build_version", "version", "hardware_version"],
        "setting": ["resolution", "width", "height", "fps", "frame_rate", "bitrate", "quality", "hdr", "parking_mode", "time_lapse", "codec"]
    ]
    static func canonicalKey(_ key: String) -> String {
        key.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
    }
    static func field(_ key: String) -> String? { groups.first { $0.value.contains(key) }?.key }
    static func safeValue(_ value: String, key: String) -> Bool {
        func matches(_ pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
        guard !value.isEmpty, value.count <= 80,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !matches(#"[^\x20-\x7e]"#),
              !matches(#"(?i)(password|passwd|secret|token|@|http|www\.|wifi|ssid|gps|serial|latitude|longitude|address|credential|canary|email)"#),
              !matches(#"^(?:10\.|127\.|169\.254\.|192\.168\.|172\.(?:1[6-9]|2[0-9]|3[01])\.)[0-9.]+$"#) else { return false }
        let kind = field(key)
        if (kind == "model" || kind == "manufacturer") && matches(#"(?:[0-9]{7,}|[A-Fa-f0-9]{12,}|(?:[A-Fa-f0-9]{2}[-:]){5}[A-Fa-f0-9]{2}|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"#) { return false }
        // Deliberately conservative: all-letter retail names and unknown multiword
        // manufacturers can be false negatives. This is not a privacy oracle;
        // declarations remain unbound and require explicit private review.
        switch kind {
        case "firmware", "build":
            return matches(#"^[vV]?[0-9]{1,4}(?:\.[0-9]{1,6}){1,5}(?:[_+\-][A-Za-z0-9.\-]{1,32})?$"#)
        case "manufacturer":
            return matches(#"^[A-Za-z][A-Za-z0-9_\-]{1,31}$"#)
        case "model":
            return matches(#"^[A-Za-z0-9][A-Za-z0-9._()+\-]{0,31}(?: [A-Za-z0-9][A-Za-z0-9._()+\-]{0,23}){0,3}$"#) && value.split(separator: " ").contains { token in
                token.range(of: "[A-Za-z]", options: .regularExpression) != nil && token.range(of: "[0-9]", options: .regularExpression) != nil
            }
        case "setting":
            let enums: [String: [String]] = ["codec": ["h264", "h265", "hevc", "av1", "mjpeg", "mpeg4"], "quality": ["low", "normal", "medium", "high", "maximum", "extreme"], "hdr": ["on", "off", "auto", "0", "1"], "parking_mode": ["on", "off", "buffered", "time-lapse", "low-bitrate", "motion", "impact", "radar"]]
            if let allowed = enums[key] { return allowed.contains(value.lowercased()) }
            if key == "resolution" { return matches(#"^[1-9][0-9]{1,4}[xX][1-9][0-9]{1,4}$"#) }
            guard matches(#"^\+?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+\-]?[0-9]+)?$"#), let number = Double(value), number > 0 else { return false }
            if ["width", "height", "bitrate"].contains(key) {
                return matches(#"^\+?[0-9]+$"#) && number <= (key == "bitrate" ? 1_000_000_000 : 16384)
            }
            return ["fps", "frame_rate", "time_lapse"].contains(key) && number <= 240
        default: return false
        }
    }
    private mutating func reason(_ key: String, _ count: Int = 1) {
        guard count > 0 else { return }
        coverage.reasons[key, default: 0] += count
        coverage.limited = true
    }

    /// Inventory is descriptor-relative; tests may inject a bounded candidate list.
    /// Each absolute ancestor and relative component is opened no-follow.
    static func read(source: URL, files: [URL]? = nil, cancelled: () -> Bool = { Task.isCancelled }, afterRead: (() -> Void)? = nil) -> Self {
        var result = Self()
        let root = source.standardizedFileURL.path
        let inventory = files ?? result.inventory(source: source, cancelled: cancelled)
        let candidates = inventory.compactMap { file -> String? in
            let path = file.standardizedFileURL.path
            guard path.hasPrefix(root + "/") else { return nil }
            return String(path.dropFirst(root.count + 1))
        }.sorted {
            let left = inspectionPriority($0), right = inspectionPriority($1)
            return left == right ? $0 < $1 : left < right
        }
        result.coverage.inventoriedCandidates = candidates.count
        var models = Set<String>()
        for (index, relative) in candidates.enumerated() {
            if cancelled() { result.reason("file_limit", candidates.count - index); break }
            if result.coverage.inspectedFiles >= 256 { result.reason("file_limit", candidates.count - index); break }
            if result.coverage.bytesRead >= 4 * 1024 * 1024 { result.reason("byte_limit", candidates.count - index); break }
            let fd = openFile(root: source, relative: relative)
            guard fd >= 0 else { result.reason("read_error"); continue }
            defer { close(fd) }
            var before = stat()
            guard fstat(fd, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG, before.st_size >= 0 else { result.reason("read_error"); continue }
            guard before.st_size <= 65536 else { result.reason("oversize"); continue }
            guard Int(before.st_size) <= 4 * 1024 * 1024 - result.coverage.bytesRead else { result.reason("byte_limit"); continue }
            result.coverage.inspectedFiles += 1
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 8192)
            var failed = false
            while data.count < Int(before.st_size) {
                if cancelled() { failed = true; result.reason("file_limit"); break }
                let count = Darwin.read(fd, &buffer, min(buffer.count, Int(before.st_size) - data.count))
                if count <= 0 { failed = true; result.reason("read_error"); break }
                data.append(contentsOf: buffer.prefix(count))
            }
            result.coverage.bytesRead += data.count
            afterRead?()
            let current = openFile(root: source, relative: relative)
            var pathInfo = stat()
            let unchangedPath = current >= 0 && fstat(current, &pathInfo) == 0 && pathInfo.st_dev == before.st_dev && pathInfo.st_ino == before.st_ino
            if current >= 0 { close(current) }
            var after = stat()
            guard unchangedPath, fstat(fd, &after) == 0, before.st_dev == after.st_dev, before.st_ino == after.st_ino,
                  before.st_size == after.st_size, before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
                  before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else { result.reason("changed_source"); continue }
            guard !failed else { continue }
            let id = "support-\(index + 1)"
            var sourceInfo = Source(id: id, format: "unknown", encoding: "unknown", sizeBytes: data.count)
            let parsed = result.parse(data, source: &sourceInfo)
            // Structural-only evidence cannot displace later declarations.
            if !parsed.isEmpty && result.sources.count == 128,
               let reclaim = result.sources.firstIndex(where: { candidate in !result.observations.contains { $0.sourceId == candidate.id } }) {
                result.sources.remove(at: reclaim)
                result.reason("file_limit")
            }
            let retainedSource = result.sources.count < 128
            if retainedSource { result.sources.append(sourceInfo) } else { result.reason("file_limit") }
            for observation in parsed {
                if observation.field == "model" { models.insert(observation.value.lowercased()) }
                if retainedSource && result.observations.count < 128 { result.observations.append(observation) }
                else { result.coverage.omittedObservations += 1; result.reason("observation_limit") }
            }
        }
        result.coverage.multipleModelValues = models.count > 1
        result.coverage.retainedObservations = result.observations.count
        result.coverage.uninspectedFiles = candidates.count - result.coverage.inspectedFiles
        return result
    }
    private static func inspectionPriority(_ path: String) -> Int {
        let url = URL(fileURLWithPath: path.lowercased())
        let ext = url.pathExtension
        if ["json", "ini", "cfg", "conf", "txt", "log", "xml"].contains(ext) || ["version.bin", "version"].contains(url.lastPathComponent) { return 0 }
        if ["mp4", "mov", "avi", "mkv", "jpg", "jpeg", "png", "heic", "ts"].contains(ext) { return 2 }
        return 1 // Unfamiliar extensions remain eligible, before media.
    }
    /// Descriptor-relative inventory includes hidden and unfamiliar support files.
    /// Symlinks are inventoried as unreadable candidates, never traversed.
    private mutating func inventory(source: URL, cancelled: () -> Bool) -> [URL] {
        let fd = Self.openFile(root: URL(fileURLWithPath: "/"), relative: String(source.standardizedFileURL.path.dropFirst()))
        guard fd >= 0 else { reason("read_error"); return [] }
        defer { close(fd) }
        var files: [URL] = []
        func visit(_ directory: Int32, _ relative: String, _ depth: Int) {
            guard depth <= 64, !cancelled() else { reason("file_limit"); return }
            guard let stream = fdopendir(dup(directory)) else { reason("read_error"); return }
            defer { closedir(stream) }
            var names: [String] = []
            errno = 0
            while let entry = readdir(stream) {
                if cancelled() { reason("file_limit"); break }
                let name = withUnsafePointer(to: entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
                }
                if name != "." && name != ".." { names.append(name) }
                errno = 0
            }
            if errno != 0 { reason("read_error") }
            for name in names.sorted() {
                guard !cancelled() else { reason("file_limit"); return }
                let path = relative.isEmpty ? name : relative + "/" + name
                var info = stat()
                guard fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { reason("read_error"); continue }
                if (info.st_mode & S_IFMT) == S_IFDIR {
                    let child = openat(directory, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    if child >= 0 { visit(child, path, depth + 1); close(child) } else { reason("read_error") }
                } else { files.append(source.appendingPathComponent(path)) }
            }
        }
        visit(fd, "", 0)
        return files
    }
    private static func openFile(root: URL, relative: String) -> Int32 {
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { return -1 }
        let parts = root.standardizedFileURL.path.split(separator: "/").map(String.init) + relative.split(separator: "/").map(String.init)
        for (index, part) in parts.enumerated() {
            guard part != ".", part != ".." else { close(fd); return -1 }
            let flags = O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC | (index == parts.count - 1 ? 0 : O_DIRECTORY)
            let next = openat(fd, part, flags)
            close(fd)
            guard next >= 0 else { return -1 }
            fd = next
        }
        return fd
    }

    private mutating func parse(_ data: Data, source: inout Source) -> [Observation] {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0xff, 0xd8, 0xff]) { source.format = "jpeg" }
        else if bytes.count >= 262 && String(bytes: bytes[257..<262], encoding: .ascii) == "ustar" { source.format = "tar" }
        else if bytes.count >= 12 && String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" { source.format = "isobmff" }
        if source.format != "unknown" { source.encoding = "binary"; reason("unsupported_format"); return [] }
        var encoding: String.Encoding = .utf8
        var payload = data
        source.encoding = "utf8"
        if bytes.starts(with: [0xef, 0xbb, 0xbf]) { payload = data.dropFirst(3) }
        else if bytes.starts(with: [0xff, 0xfe]) { encoding = .utf16LittleEndian; source.encoding = "utf16le"; payload = data.dropFirst(2) }
        else if bytes.starts(with: [0xfe, 0xff]) { encoding = .utf16BigEndian; source.encoding = "utf16be"; payload = data.dropFirst(2) }
        guard let text = String(data: payload, encoding: encoding), !text.contains("\0") else {
            source.encoding = "binary"; source.format = "binary"; reason("invalid_encoding"); reason("unsupported_format"); return []
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<") { source.format = "xml"; reason("unsupported_format"); return [] }
        var output: [Observation] = []
        var record = 0
        func observation(_ key: String, _ value: Any, line: Int, record: Int) -> Observation? {
            guard let field = Self.field(key) else { return nil }
            let string: String
            if let value = value as? String { string = value }
            else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { string = number.stringValue }
            else { return nil }
            guard Self.safeValue(string, key: key) else { return nil }
            return Observation(sourceId: source.id, field: field, key: key, value: string, line: line, record: record)
        }
        func walkJSON(_ text: String, line: Int) {
            let declarations = Self.jsonScalars(text)
            for (rawKey, value, sourceLine, sourceRecord) in declarations.entries {
                let key = Self.canonicalKey(rawKey)
                guard Self.field(key) != nil else { continue }
                if let entry = observation(key, value, line: line + sourceLine - 1, record: record + sourceRecord) { output.append(entry) }
                else { reason("unsafe_value") }
            }
            record += declarations.records
        }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let startsSection = firstLine.range(of: #"^\[[A-Za-z0-9 _().+\-]+\]$"#, options: .regularExpression) != nil
        if trimmed.hasPrefix("{") || (trimmed.hasPrefix("[") && !startsSection) {
            source.format = "json"
            if Self.json(trimmed) != nil {
                let leadingLines = text.prefix { $0.isWhitespace }.filter { $0 == "\n" }.count
                walkJSON(trimmed, line: leadingLines + 1); return output
            }
            // A multi-record log may start with an undecorated JSON record.
            if !trimmed.components(separatedBy: .newlines).filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).allSatisfy({ Self.framedJSON($0) != nil && Self.json(Self.framedJSON($0)!) != nil }) { reason("malformed"); return [] }
        }
        var section: Int?
        var sectionKeys = Set<String>()
        var foundJSON = false
        var foundKV = false
        for (offset, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if let framed = Self.framedJSON(line) {
                section = nil; sectionKeys.removeAll()
                foundJSON = true; source.format = "framed_json"
                if Self.json(framed) != nil { walkJSON(framed, line: offset + 1) } else { reason("malformed") }
                continue
            }
            if line.contains("{") || line.hasPrefix("[") && !line.hasSuffix("]") { reason("malformed"); continue }
            if line.hasPrefix("["), line.hasSuffix("]") { section = record; record += 1; sectionKeys.removeAll(); source.format = "ini"; continue }
            guard let separator = line.firstIndex(where: { $0 == "=" || $0 == ":" }) else { continue }
            let key = Self.canonicalKey(line[..<separator].trimmingCharacters(in: .whitespaces))
            if key.range(of: #"^[a-z][a-z0-9_]{0,47}$"#, options: .regularExpression) != nil { foundKV = true }
            guard Self.field(key) != nil else { continue }
            if section == nil || sectionKeys.contains(key) {
                section = record; record += 1; sectionKeys.removeAll()
            }
            sectionKeys.insert(key)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if let entry = observation(key, value, line: offset + 1, record: section!) { output.append(entry) }
            else { reason("unsafe_value") }
        }
        if source.format == "unknown" { source.format = foundKV ? "key_value" : "unknown" }
        if !foundKV && !foundJSON && source.format != "ini" { reason("unsupported_format") }
        return output
    }

    /// Called only after complete duplicate-guarded JSON validation. Walk lexical
    /// scalar declarations so line numbers and nested record boundaries remain exact.
    private static func jsonScalars(_ text: String) -> (entries: [(String, Any, Int, Int)], records: Int) {
        let chars = Array(text)
        var entries: [(String, Any, Int, Int)] = []
        var stack: [Int?] = []
        var records = 0
        var index = 0
        var line = 1
        func stringEnd(_ start: Int) -> Int {
            var end = start + 1
            var escaped = false
            while end < chars.count {
                if !escaped && chars[end] == "\"" { return end }
                if !escaped && chars[end] == "\\" { escaped = true } else { escaped = false }
                end += 1
            }
            return chars.count - 1
        }
        while index < chars.count {
            let c = chars[index]
            if c == "\n" { line += 1 }
            else if c == "{" { stack.append(records); records += 1 }
            else if c == "[" { stack.append(nil) }
            else if c == "}" || c == "]" { stack.removeLast() }
            else if c == "\"" {
                let end = stringEnd(index)
                var colon = end + 1
                while colon < chars.count && chars[colon].isWhitespace { colon += 1 }
                if colon < chars.count && chars[colon] == ":", let current = stack.last ?? nil {
                    let keyData = Data(String(chars[index...end]).utf8)
                    if let key = try? JSONSerialization.jsonObject(with: keyData, options: [.fragmentsAllowed]) as? String {
                        var start = colon + 1
                        while start < chars.count && chars[start].isWhitespace { start += 1 }
                        if start < chars.count {
                            if chars[start] == "{" || chars[start] == "[" { entries.append((key, NSNull(), line, current)) }
                            else {
                                var last = start
                                if chars[start] == "\"" { last = stringEnd(start) + 1 }
                                else { while last < chars.count && !chars[last].isWhitespace && chars[last] != "," && chars[last] != "}" && chars[last] != "]" { last += 1 } }
                                if let scalar = try? JSONSerialization.jsonObject(with: Data(String(chars[start..<last]).utf8), options: [.fragmentsAllowed]) { entries.append((key, scalar, line, current)) }
                            }
                        }
                    }
                }
                index = end
            }
            index += 1
        }
        return (entries, records)
    }

    /// Reject duplicate object keys before Foundation's last-wins JSON conversion.
    /// Track decoded keys (including escaped aliases) separately for every object.
    static func json(_ text: String) -> Any? {
        let chars = Array(text)
        var stack: [Set<String>?] = []
        var index = 0
        while index < chars.count {
            let c = chars[index]
            if c == "{" { stack.append(Set<String>()); if stack.count > 32 { return nil } }
            else if c == "[" { stack.append(nil); if stack.count > 32 { return nil } }
            else if c == "}" || c == "]" { if stack.isEmpty { return nil }; stack.removeLast() }
            else if c == "\"" {
                let start = index
                index += 1
                var escaped = false
                while index < chars.count {
                    let current = chars[index]
                    if !escaped && current == "\"" { break }
                    if !escaped && current == "\\" { escaped = true } else { escaped = false }
                    index += 1
                }
                guard index < chars.count else { return nil }
                var next = index + 1
                while next < chars.count && chars[next].isWhitespace { next += 1 }
                if next < chars.count && chars[next] == ":" {
                    guard !stack.isEmpty, var keys = stack[stack.count - 1],
                          let data = String(chars[start...index]).data(using: .utf8),
                          let key = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String,
                          keys.insert(key).inserted else { return nil }
                    stack[stack.count - 1] = keys
                }
            }
            index += 1
        }
        guard stack.isEmpty, let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
    static func framedJSON(_ line: String) -> String? {
        guard let opening = line.range(of: #"\{\s*\""#, options: .regularExpression) else { return nil }
        let start = opening.lowerBound
        let prefix = String(line[..<start]).replacingOccurrences(of: #"\x1B\[[0-9;]*m"#, with: "", options: .regularExpression)
        guard !prefix.contains("\u{1b}") else { return nil }
        var enclosingArrays = 0
        for c in prefix {
            if c == "[" { enclosingArrays += 1 }
            else if c == "]" { enclosingArrays = max(0, enclosingArrays - 1) }
        }
        guard enclosingArrays == 0 else { return nil }
        var depth = 0; var quoted = false; var escaped = false
        for index in line[start...].indices {
            let c = line[index]
            if quoted {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { quoted = false }
            } else if c == "\"" { quoted = true }
            else if c == "{" || c == "[" { depth += 1 }
            else if c == "}" || c == "]" {
                depth -= 1
                if depth == 0 {
                    let suffix = String(line[line.index(after: index)...]).replacingOccurrences(of: #"\x1B\[[0-9;]*m"#, with: "", options: .regularExpression)
                    guard suffix.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                    return String(line[start...index])
                }
            }
        }
        return nil
    }
}
