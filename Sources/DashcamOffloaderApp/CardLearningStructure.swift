import Foundation

// Keep camera directory vocabulary, never a host path or user-named directory.
// Unknown segments get opaque, per-snapshot labels so their hierarchy survives.
struct CardLearningPaths {
    static let cameraDirectories: Set<String> = [
        "dcim", "movie", "movies", "photo", "photos", "parking", "park", "ro",
        "normal", "event", "events", "emergency", "manual", "protected", "record",
        "recordings", "video", "videos", "front", "rear", "interior", "cabin",
        "telephoto", "side", "continuous", "motion", "impact", "timelapse", "sos",
        "cont_rec", "evt_rec", "manual_rec", "parking_rec", "motion_rec", "sos_rec",
        "incabin_rec", "normal_rec", "event_rec", "park_rec", "inf_rec", "photo_rec",
        "blackvue", "teslacam", "recentclips", "savedclips", "sentryclips", "roadscout",
        "escort_m1", "maxcam360c", "rec", "clip", "inf", "pevent", "lapse", "lockedvideo",
        "secvideo", "safety_box", "bookmark", "originalfiles", "panophoto", "private",
        "avchd", "m4root", "360cardvr", "100", "back_emr", "back_norm", "front_emer",
        "rear_emer", "front_norm", "rear_norm", "emr", "norm", "motion_timelapse_rec"
    ]
    private var aliases: [String: String] = [:]

    mutating func folder(_ path: String) -> String? {
        if path == "." { return path }
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), path.count <= 1024 else { return nil }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 12, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { return nil }
        var prefix = ""
        return parts.map { part in
            prefix += "/" + part
            if Self.cameraDirectories.contains(part.lowercased()) || part.range(of: #"^\d{3}[A-Za-z]{3,8}$"#, options: .regularExpression) != nil {
                return part
            }
            if aliases[prefix] == nil { aliases[prefix] = "folder-\(aliases.count + 1)" }
            return aliases[prefix]!
        }.joined(separator: "/")
    }

    static func acceptedFolder(_ path: String) -> String? {
        if path == "." { return path }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count <= 12, !parts.isEmpty, parts.allSatisfy({ part in
            cameraDirectories.contains(part.lowercased()) ||
            part.range(of: #"^(?:\d{3}[A-Za-z]{3,8}|folder-[1-9]\d{0,3})$"#, options: .regularExpression) != nil
        }) else { return nil }
        return path
    }
}

struct FeedbackMediaFileSample: Codable, Hashable, Sendable {
    var folder: String
    var filename: String
    var mode: String
    var outputCategory: String
    var channel: String
    var fileSizeBytes: Int64
    var permissionBits: Int?
    var filesystemReadOnly: Bool?
    var userImmutable: Bool?
    var systemImmutable: Bool?
    var volumeReadOnly: Bool?
}

enum CardLearningStructure {
    static func mediaSamples(clips: [ClipItem], sourceRoot: URL?, paths: inout CardLearningPaths) -> [FeedbackMediaFileSample] {
        let pattern = try! NSRegularExpression(pattern: #"^(?:\d{4}_\d{4}_\d{6}_\d{1,9}(?:PF|PR|PI|PT|F|R|I|T)|[A-Z]{1,4}\d{6,12}[A-Z0-9]{0,3})\.(?:MP4|MOV|JPG|JPEG)$"#, options: [.caseInsensitive])
        let safe = clips.filter {
            let name = $0.sourceURL.lastPathComponent
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            return pattern.firstMatch(in: name, range: range)?.range == range
        }
        let groups = Dictionary(grouping: safe) { clip in
            [clip.sourceURL.deletingLastPathComponent().path, clip.mode, clip.outputCategory, clip.channel].joined(separator: "|")
        }
        let buckets = groups.keys.sorted().map { groups[$0]!.sorted { $0.relativePath < $1.relativePath } }
        // Round-robin preserves rare protected/photo groups on large cards.
        var selected: [ClipItem] = []
        var offset = 0
        while selected.count < 120 {
            let row = buckets.compactMap { offset < $0.count ? $0[offset] : nil }
            if row.isEmpty { break }
            selected += row.prefix(120 - selected.count)
            offset += 1
        }
        return selected.compactMap { clip in
            let relative = sourceRoot.map { clip.sourceURL.relativePath(from: $0) } ?? clip.relativePath
            let rawFolder = relative.split(separator: "/").dropLast().joined(separator: "/")
            guard let folder = paths.folder(rawFolder.isEmpty ? "." : rawFolder) else { return nil }
            let attributes = try? FileManager.default.attributesOfItem(atPath: clip.sourceURL.path)
            let bits = (attributes?[.posixPermissions] as? NSNumber)?.intValue
            let values = try? clip.sourceURL.resourceValues(forKeys: [.isUserImmutableKey, .isSystemImmutableKey, .volumeIsReadOnlyKey])
            return FeedbackMediaFileSample(folder: folder, filename: clip.sourceURL.lastPathComponent,
                mode: clip.mode, outputCategory: clip.outputCategory, channel: clip.channel,
                fileSizeBytes: clip.size, permissionBits: bits.map { $0 & 0o777 },
                filesystemReadOnly: bits.map { $0 & 0o222 == 0 }, userImmutable: values?.isUserImmutable,
                systemImmutable: values?.isSystemImmutable, volumeReadOnly: values?.volumeIsReadOnly)
        }
    }
}
