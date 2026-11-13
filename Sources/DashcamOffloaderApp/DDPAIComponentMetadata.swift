import Foundation
import Darwin

struct ComponentMetadata: Codable, Hashable, Sendable {
    var manufacturer = "DDPAI"
    var component: String
    var reportedModel: String?
    var model: String?
    var firmwareVersion: String?
    var sourceKind = "ddpai_ui_device_info"
    var sourceFile: String
    var sourceLine: Int
    var identityEstablished: Bool

    enum CodingKeys: String, CodingKey {
        case manufacturer, component, reportedModel, model, firmwareVersion, sourceKind, sourceFile, sourceLine, identityEstablished
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(manufacturer, forKey: .manufacturer)
        try values.encode(component, forKey: .component)
        try values.encode(reportedModel, forKey: .reportedModel)
        try values.encode(model, forKey: .model)
        try values.encode(firmwareVersion, forKey: .firmwareVersion)
        try values.encode(sourceKind, forKey: .sourceKind)
        try values.encode(sourceFile, forKey: .sourceFile)
        try values.encode(sourceLine, forKey: .sourceLine)
        try values.encode(identityEstablished, forKey: .identityEstablished)
    }
}

struct ComponentMetadataCoverage: Codable, Hashable, Sendable {
    var inspectedFiles = 0
    var retainedEntries = 0
    var omittedEntries = 0
    var limited = false
}

/// No log contents escape this reader: only explicitly allowlisted observations.
/// Historical observations are never the owner's current firmware setting.
struct DDPAIComponentMetadata {
    var entries: [ComponentMetadata] = []
    var coverage = ComponentMetadataCoverage()

    var exactLoggingModel: String? {
        guard !coverage.limited else { return nil }
        let main = entries.filter { $0.component == "logging_device" }
        guard !main.isEmpty, main.allSatisfy({ $0.identityEstablished && $0.model != nil }),
              Set(main.compactMap(\.model)).count == 1 else { return nil }
        return main.first?.model
    }

    static func safeModel(_ value: String) -> String? {
        guard !value.isEmpty, value.trimmingCharacters(in: .whitespacesAndNewlines) == value, value.count <= 80, value.utf8.count <= 240,
              value.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || " _().+-".unicodeScalars.contains($0) }) else { return nil }
        return value
    }

    static func safeFirmware(_ value: String) -> String? {
        // Deliberately version-shaped, not arbitrary strings or IP extraction.
        guard value.utf8.count <= 64,
              value.range(of: #"^[vV]?[0-9]{1,4}(?:\.[0-9]{1,6}){1,5}(?:[_+-][A-Za-z0-9.-]{1,32})?\z"#, options: .regularExpression) != nil else { return nil }
        return value
    }

    static func read(source: URL) -> Self {
        var result = read(source: source, parts: ["DCIM", "207log", "ui"], productLog: false)
        let product = read(source: source, parts: ["DCIM", "207log"], productLog: true)
        result.coverage.inspectedFiles += product.coverage.inspectedFiles
        result.coverage.limited = result.coverage.limited || product.coverage.limited
        result.coverage.omittedEntries += product.coverage.omittedEntries
        for entry in product.entries {
            if result.entries.count < 32 { result.entries.append(entry) }
            else { result.coverage.omittedEntries += 1; result.coverage.limited = true }
        }
        result.coverage.retainedEntries = result.entries.count
        return result
    }

    private static func read(source: URL, parts: [String], productLog: Bool) -> Self {
        var result = Self()
        var directory = openDirectory(source)
        guard directory >= 0 else { result.coverage.limited = true; return result }
        defer { close(directory) }
        for part in parts {
            let next = openat(directory, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else {
                if errno != ENOENT { result.coverage.limited = true }
                return result
            }
            close(directory); directory = next
        }
        guard let stream = fdopendir(dup(directory)) else { result.coverage.limited = true; return result }
        defer { closedir(stream) }
        var names: [String] = []
        var count = 0
        errno = 0
        while let item = readdir(stream) {
            count += 1
            if count > 256 { result.coverage.limited = true; break }
            let name = withUnsafePointer(to: item.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(item.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            let pattern = productLog ? #"^[0-9]{14}_[0-9]{3}\.log\z"# : #"^ui_[0-9]{14}_[0-9]{3}\.log\z"#
            if name.range(of: pattern, options: .regularExpression) != nil { names.append(name) }
            errno = 0
        }
        if errno != 0 { result.coverage.limited = true }
        if names.count > 32 { result.coverage.limited = true }
        var budget = 8 * 1024 * 1024
        for name in names.sorted().prefix(32) {
            guard budget > 0 else { result.coverage.limited = true; break }
            let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { result.coverage.limited = true; continue }
            var before = stat()
            guard fstat(fd, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG else {
                close(fd); result.coverage.limited = true; continue
            }
            result.coverage.inspectedFiles += 1
            let maximum = min(budget, 2 * 1024 * 1024)
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 65536)
            while data.count < maximum {
                let amount = Darwin.read(fd, &buffer, min(buffer.count, maximum - data.count))
                if amount < 0 { result.coverage.limited = true; break }
                if amount == 0 { break }
                data.append(contentsOf: buffer.prefix(amount))
            }
            var after = stat()
            if fstat(fd, &after) != 0 || before.st_size != after.st_size || before.st_mtimespec.tv_sec != after.st_mtimespec.tv_sec || before.st_mtimespec.tv_nsec != after.st_mtimespec.tv_nsec {
                result.coverage.limited = true
            }
            close(fd)
            budget -= data.count
            let truncated = before.st_size > data.count
            if truncated { result.coverage.limited = true }
            // Product logs are fixed-size, NUL-padded. Padding is not log content.
            let content = productLog ? data.prefix((data.lastIndex(where: { $0 != 0 }) ?? -1) + 1) : data[...]
            let lines = content.split(separator: 10, omittingEmptySubsequences: false)
            for (index, bytes) in lines.enumerated() {
                if truncated && index == lines.count - 1 { break }
                // Other product-log records are outside this reader's contract.
                // Do not decode binary diagnostics or treat them as identity data.
                if productLog && bytes.range(of: Data("WEBGetProductInfo".utf8)) == nil { continue }
                guard bytes.count <= 16384 else { result.coverage.limited = true; continue }
                guard let line = String(data: Data(bytes), encoding: .utf8) else { result.coverage.limited = true; continue }
                let sourceFile = parts.joined(separator: "/") + "/" + name
                if productLog { result.consumeProduct(line: line, sourceFile: sourceFile, sourceLine: index + 1) }
                else { result.consume(line: line, sourceFile: sourceFile, sourceLine: index + 1) }
            }
        }
        result.coverage.retainedEntries = result.entries.count
        return result
    }

    /// Open every absolute path component relative to a held directory handle.
    /// Checking resolved names alone would leave an ancestor-symlink race.
    private static func openDirectory(_ source: URL) -> Int32 {
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else { return -1 }
        for part in source.standardizedFileURL.path.split(separator: "/") {
            let next = openat(descriptor, String(part), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            close(descriptor)
            guard next >= 0 else { return -1 }
            descriptor = next
        }
        return descriptor
    }

    static func hasSafeMainFrontVideo(source: URL, files: [URL]) -> Bool {
        hasSafeVideo(source: source, files: files, folder: "DCIM/200video/front")
    }

    static func hasSafeVideo(source: URL, files: [URL], folder: String) -> Bool {
        let candidates = files.filter {
            !$0.lastPathComponent.hasPrefix("._") && ["mp4", "mov"].contains($0.pathExtension.lowercased()) &&
                $0.relativePath(from: source).split(separator: "/").dropLast().joined(separator: "/") == folder
        }
        guard !candidates.isEmpty else { return false }
        let directory = openDirectory(source.appendingPathComponent(folder, isDirectory: true))
        guard directory >= 0 else { return false }
        defer { close(directory) }
        for candidate in candidates.prefix(32) {
            let fd = openat(directory, candidate.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            if fd < 0 { continue }
            var attributes = stat()
            let regular = fstat(fd, &attributes) == 0 && (attributes.st_mode & S_IFMT) == S_IFREG && attributes.st_size >= 12
            var header = [UInt8](repeating: 0, count: 12)
            let count = regular ? Darwin.read(fd, &header, header.count) : 0
            close(fd)
            if count == 12 && Array(header[4..<8]) == Array("ftyp".utf8) { return true }
        }
        return false
    }

    private static func payload(in line: String) -> String? {
        guard let opening = line.range(of: #"\{\s*\""#, options: .regularExpression) else { return nil }
        let start = opening.lowerBound
        var enclosingArrays = 0
        // Only known logger SGR decoration outside the JSON may be ignored.
        // In particular, its '[' is not an enclosing JSON array. Never clean
        // the payload: literal controls there must remain invalid JSON.
        let prefix = String(line[..<start]).replacingOccurrences(
            of: #"\x1B\[[0-9;]*m"#, with: "", options: .regularExpression)
        guard !prefix.contains("\u{1B}") else { return nil }
        for c in prefix {
            if c == "[" { enclosingArrays += 1 }
            else if c == "]" { enclosingArrays = max(0, enclosingArrays - 1) }
        }
        guard enclosingArrays == 0 else { return nil }
        var depth = 0; var quoted = false; var escaped = false
        for index in line[start...].indices {
            let c = line[index]
            if quoted {
                guard c.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) else { return nil }
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { quoted = false }
            } else if c == "\"" { quoted = true }
            else if c == "{" || c == "[" { depth += 1 }
            else if c == "}" || c == "]" {
                depth -= 1
                if depth == 0 { return String(line[start...index]) }
            }
        }
        return nil
    }

    mutating func consumeProduct(line: String, sourceFile: String, sourceLine: Int) {
        guard line.contains("WEBGetProductInfo"), line.contains("pJsonData=") else { return }
        guard let json = Self.payload(in: line), !hasDuplicateKeys(json),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawModel = object["model"] as? String, let rawVersion = object["version"] as? String,
              let reported = Self.safeModel(rawModel), let version = Self.safeFirmware(rawVersion) else {
            coverage.limited = true; return
        }
        // Retain the reported SKU, not an inferred retail revision or accessory identity.
        let model = DDPAIOfficialModels.recognized(reported)
        let entry = ComponentMetadata(component: "logging_device", reportedModel: reported, model: model,
            firmwareVersion: version, sourceKind: "ddpai_product_info", sourceFile: sourceFile,
            sourceLine: sourceLine, identityEstablished: model != nil)
        if entries.count < 32 { entries.append(entry) }
        else { coverage.omittedEntries += 1; coverage.limited = true }
    }

    mutating func consume(line: String, sourceFile: String, sourceLine: Int) {
        guard sourceLine > 0, sourceFile.range(of: #"^DCIM/207log/ui/ui_[0-9]{14}_[0-9]{3}\.log\z"#, options: .regularExpression) != nil else {
            coverage.limited = true; return
        }
        guard let json = Self.payload(in: line) else {
            if line.contains("\"model\"") && line.contains("\"soft_version\"") { coverage.limited = true }
            return
        }
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            coverage.limited = true; return
        }
        guard !hasDuplicateKeys(json) else { coverage.limited = true; return }
        guard object["msgHdr"] is [String: Any] else { return }
        guard object["model"] != nil || object["soft_version"] != nil else { return }
        guard let main = object["model"] as? String, let firmware = object["soft_version"] as? String,
              ["rear_model", "rear_version", "inside_model", "inside_version"].allSatisfy({ object[$0] == nil || object[$0] is String }) else {
            coverage.limited = true; return
        }
        for (component, rawModel, rawVersion) in [
            ("logging_device", main, firmware),
            ("rear", object["rear_model"] as? String ?? "", object["rear_version"] as? String ?? ""),
            ("inside", object["inside_model"] as? String ?? "", object["inside_version"] as? String ?? "")
        ] {
            let reported = Self.safeModel(rawModel)
            let version = Self.safeFirmware(rawVersion)
            if !rawModel.isEmpty && reported == nil { coverage.limited = true }
            if !rawVersion.isEmpty && version == nil { coverage.limited = true }
            guard reported != nil || version != nil else { continue }
            let model = reported.flatMap(DDPAIOfficialModels.recognized)
            let entry = ComponentMetadata(component: component, reportedModel: reported, model: model,
                firmwareVersion: version, sourceFile: sourceFile, sourceLine: sourceLine,
                identityEstablished: model != nil)
            if entries.count < 32 { entries.append(entry) }
            else { coverage.omittedEntries += 1; coverage.limited = true }
        }
    }

    /// JSONSerialization accepts duplicate keys; reject them at every object level,
    /// comparing decoded keys (including escaped spellings) before extraction.
    private func hasDuplicateKeys(_ json: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"\"(?:[^\"\\]|\\.)*\"|[{}\[\]:,]"#) else { return true }
        let ns = json as NSString
        let tokens = regex.matches(in: json, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        var stack: [Set<String>?] = []
        for (index, token) in tokens.enumerated() {
            if token == "{" { stack.append([]) }
            else if token == "[" { stack.append(nil) }
            else if token == "}" || token == "]" { if !stack.isEmpty { stack.removeLast() } }
            else if token.hasPrefix("\""), index + 1 < tokens.count, tokens[index + 1] == ":", !stack.isEmpty {
                guard let encoded = ("[" + token + "]").data(using: .utf8),
                      let key = (try? JSONSerialization.jsonObject(with: encoded) as? [String])?.first,
                      var keys = stack[stack.count - 1] else { return true }
                if !keys.insert(key).inserted { return true }
                stack[stack.count - 1] = keys
            }
        }
        return false
    }
}
