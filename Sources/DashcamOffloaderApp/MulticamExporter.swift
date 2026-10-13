@preconcurrency import AVFoundation
import Foundation

/// Local, filename-aligned FCPXML. Never reads audio samples or changes originals.
enum MulticamExporter {
    static let channels = ["F", "I", "R", "T"]
    static let labels = ["F": "Front Cam", "I": "Interior Cam", "R": "Rear Cam", "T": "Telephoto Cam"]

    struct Identity: Equatable, Sendable {
        let stamp: String
        let date: Date
        let channel: String
        let parking: Bool
        let annotation: String
    }

    struct Input: Sendable {
        let url: URL
        let identity: Identity
        let namespace: String
    }

    struct Video: Sendable {
        let input: Input
        let duration: Double
        let width: Int
        let height: Int
        let frameDuration: CMTime
        let audioChannels: Int
        let audioRate: Int
    }

    struct Result: Sendable {
        let url: URL
        let multicamCount: Int
        let recordingCount: Int
    }

    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case let .message(text) = self { return text }
            return nil
        }
    }

    static func identify(_ filename: String) -> Identity? {
        guard URL(fileURLWithPath: filename).pathExtension.lowercased() == "mp4",
              let regex = try? NSRegularExpression(pattern: "^(\\d{4}_\\d{4}_\\d{6})_\\d+(P?[FIRT])(?=$|[ ._-])", options: .caseInsensitive),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
              let stampRange = Range(match.range(at: 1), in: filename),
              let channelRange = Range(match.range(at: 2), in: filename) else { return nil }
        let stamp = String(filename[stampRange])
        let suffix = String(filename[channelRange]).uppercased()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy_MMdd_HHmmss"
        formatter.isLenient = false
        guard let date = formatter.date(from: stamp), formatter.string(from: date) == stamp else { return nil }
        guard let matchedRange = Range(match.range, in: filename) else { return nil }
        let basename = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let suffixStart = filename.distance(from: filename.startIndex, to: matchedRange.upperBound)
        let annotation = String(basename.dropFirst(suffixStart)).trimmingCharacters(in: CharacterSet(charactersIn: " ._-"))
        return Identity(stamp: stamp, date: date, channel: String(suffix.suffix(1)), parking: suffix.hasPrefix("P"), annotation: annotation)
    }

    static func inputs(urls: [URL]) -> [Input] {
        urls.compactMap { url in
            guard let identity = identify(url.lastPathComponent) else { return nil }
            return Input(url: url, identity: identity, namespace: url.deletingLastPathComponent().standardizedFileURL.path)
        }
    }

    static func folderInputs(_ root: URL) throws -> [Input] {
        var urls: [URL] = []
        var enumerationFailure: Error?
        guard let enumerator = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, error in
                enumerationFailure = error
                return false
            }) else { throw Failure.message("The footage folder could not be opened.") }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isRegularFile == true && values.isSymbolicLink != true { urls.append(url) }
        }
        if let enumerationFailure { throw enumerationFailure }
        return inputs(urls: urls)
    }

    static func key(_ input: Input) -> String {
        "\(input.namespace)|\(input.identity.parking ? "Parking" : "Driving")|\(input.identity.stamp.prefix(9))"
    }

    static func validate(_ inputs: [Input]) throws {
        guard !inputs.isEmpty else { throw Failure.message("No matching VIOFO F/I/R/T MP4 filenames were found.") }
        let groups = Dictionary(grouping: inputs) { "\(key($0))|\($0.identity.stamp)" }
        for group in groups.values {
            let counts = Dictionary(grouping: group, by: { $0.identity.channel })
            guard counts.values.allSatisfy({ $0.count == 1 }) else {
                throw Failure.message("Duplicate camera files at \(group[0].identity.stamp). Select a folder containing one camera recording set.")
            }
            let missing = channels.filter { counts[$0] == nil }
            guard missing.isEmpty else {
                throw Failure.message("Recording \(group[0].identity.stamp) is missing \(missing.compactMap { labels[$0] }.joined(separator: ", ")). Include all four channels before creating a multicam.")
            }
        }
    }

    static func create(inputs: [Input], output: URL) async throws -> Result {
        try validate(inputs)
        var videos: [Video] = []
        for input in inputs.sorted(by: { $0.url.path < $1.url.path }) {
            try Task.checkCancellation()
            let asset = AVURLAsset(url: input.url)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw Failure.message("No video track in \(input.url.lastPathComponent).")
            }
            // Audio encoder padding must not extend a video past the next filename timestamp.
            let duration = try await track.load(.timeRange).duration.seconds
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let frameDuration = try await track.load(.minFrameDuration)
            let oriented = size.applying(transform)
            guard duration.isFinite, duration > 0, frameDuration.isNumeric, frameDuration.seconds > 0,
                  abs(oriented.width) > 0, abs(oriented.height) > 0,
                  transform == .identity else {
                throw Failure.message("Unsupported duration, frame rate, or rotation in \(input.url.lastPathComponent).")
            }
            var audioChannels = 0
            var audioRate = 0
            if let audio = try await asset.loadTracks(withMediaType: .audio).first,
               let description = try await audio.load(.formatDescriptions).first,
               let format = CMAudioFormatDescriptionGetStreamBasicDescription(description) {
                audioChannels = Int(format.pointee.mChannelsPerFrame)
                audioRate = Int(format.pointee.mSampleRate)
            }
            videos.append(Video(input: input, duration: duration, width: Int(abs(oriented.width)),
                height: Int(abs(oriented.height)), frameDuration: frameDuration,
                audioChannels: audioChannels, audioRate: audioRate))
        }
        let document = try render(videos)
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw Failure.message("That XML file already exists. Choose a new filename.")
        }
        // Move a completed staging file without replacing an existing XML, including on non-APFS destinations.
        let staging = output.deletingLastPathComponent().appendingPathComponent(".multicam-\(UUID().uuidString).fcpxml")
        defer { try? FileManager.default.removeItem(at: staging) }
        try Data(document.utf8).write(to: staging, options: .withoutOverwriting)
        try FileManager.default.moveItem(at: staging, to: output)
        return Result(url: output, multicamCount: Set(inputs.map(key)).count, recordingCount: inputs.count / 4)
    }

    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func time(frames: Int64, frameDuration: CMTime) -> String {
        "\(frames * frameDuration.value)/\(frameDuration.timescale)s"
    }

    static func render(_ videos: [Video]) throws -> String {
        try validate(videos.map(\.input))
        var resources: [String] = []
        var event: [String] = []
        var nextID = 0
        func id() -> String { nextID += 1; return "r\(nextID)" }
        for (index, entry) in Dictionary(grouping: videos, by: { key($0.input) }).sorted(by: { $0.key < $1.key }).enumerated() {
            let sorted = entry.value.sorted { $0.input.identity.date < $1.input.identity.date }
            let front = sorted.first { $0.input.identity.channel == "F" }!
            let fd = front.frameDuration
            guard sorted.allSatisfy({ abs($0.frameDuration.seconds - fd.seconds) < 0.000001 }) else {
                throw Failure.message("Mixed frame rates in one recording session. Export matching-rate footage separately.")
            }
            let base = sorted[0].input.identity.date
            let formatID = id()
            resources.append("<format id=\"\(formatID)\" frameDuration=\"\(time(frames: 1, frameDuration: fd))\" width=\"\(front.width)\" height=\"\(front.height)\" colorSpace=\"1-1-1 (Rec. 709)\"/>")
            let groups = Dictionary(grouping: sorted, by: { $0.input.identity.stamp }).sorted { $0.key < $1.key }
            var starts: [String: Int64] = [:]
            var total: Int64 = 0
            for group in groups {
                let start = Int64((group.value[0].input.identity.date.timeIntervalSince(base) / fd.seconds).rounded())
                let durations = group.value.map { Int64(($0.duration / fd.seconds).rounded()) }
                guard let shortest = durations.min(), let longest = durations.max(), shortest > 0 else {
                    throw Failure.message("Invalid camera duration at \(group.key). Check the recording files.")
                }
                guard start >= total else {
                    throw Failure.message("Overlapping filename timestamps at \(group.key). Export those recordings separately.")
                }
                starts[group.key] = start
                total = start + longest
            }
            let duration = time(frames: total, frameDuration: fd)
            let folderLabel = URL(fileURLWithPath: front.input.namespace).lastPathComponent
            func marker(_ label: String, start: Int64) -> String {
                "<marker start=\"\(time(frames: start, frameDuration: fd))\" duration=\"\(time(frames: 1, frameDuration: fd))\" value=\"\(escape(label))\"/>"
            }
            var sectionStarts = Set<URL>()
            for channel in channels {
                var previousNote = ""
                var previousEnd: Int64 = -1
                for video in sorted.filter({ $0.input.identity.channel == channel }) {
                    let note = video.input.identity.annotation
                    let start = starts[video.input.identity.stamp]!
                    if !note.isEmpty && (note != previousNote || abs(start - previousEnd) > 1) {
                        sectionStarts.insert(video.input.url)
                    }
                    previousNote = note
                    previousEnd = start + Int64((video.duration / fd.seconds).rounded())
                }
            }
            let sectionMarkers = marker("Folder: \(folderLabel)", start: 0) + groups.map { group in
                let notes = group.value.filter { sectionStarts.contains($0.input.url) }.sorted {
                    $0.input.identity.channel < $1.input.identity.channel
                }.map { "\(labels[$0.input.identity.channel]!): \($0.input.identity.annotation)" }
                return notes.isEmpty ? "" : marker(notes.joined(separator: " | "), start: starts[group.key]!)
            }.joined()
            var compounds: [String: String] = [:]
            for channel in channels {
                let compound = id()
                compounds[channel] = compound
                var spine: [String] = []
                var cursor: Int64 = 0
                for video in sorted.filter({ $0.input.identity.channel == channel }) {
                    let stamp = video.input.identity.stamp
                    let start = starts[stamp]!
                    let length = Int64((video.duration / fd.seconds).rounded())
                    if start > cursor {
                        spine.append("<gap name=\"Recording gap\" offset=\"\(time(frames: cursor, frameDuration: fd))\" start=\"0s\" duration=\"\(time(frames: start - cursor, frameDuration: fd))\"/>")
                    }
                    let sourceFormat = id()
                    let asset = id()
                    resources.append("<format id=\"\(sourceFormat)\" frameDuration=\"\(time(frames: 1, frameDuration: fd))\" width=\"\(video.width)\" height=\"\(video.height)\" colorSpace=\"1-1-1 (Rec. 709)\"/>")
                    let audio = video.audioChannels > 0 ? " hasAudio=\"1\" audioSources=\"1\" audioChannels=\"\(video.audioChannels)\" audioRate=\"\(video.audioRate)\"" : ""
                    resources.append("<asset id=\"\(asset)\" name=\"\(escape(video.input.url.deletingPathExtension().lastPathComponent))\" start=\"0s\" duration=\"\(time(frames: Int64((video.duration / fd.seconds).rounded()), frameDuration: fd))\" hasVideo=\"1\" format=\"\(sourceFormat)\"\(audio)><media-rep kind=\"original-media\" src=\"\(escape(video.input.url.absoluteString))\"/></asset>")
                    let note = video.input.identity.annotation
                    let annotation = sectionStarts.contains(video.input.url) ? marker(note, start: 0) : ""
                    spine.append("<asset-clip ref=\"\(asset)\" offset=\"\(time(frames: start, frameDuration: fd))\" start=\"0s\" duration=\"\(time(frames: length, frameDuration: fd))\" format=\"\(sourceFormat)\"><adjust-conform type=\"fit\"/>\(annotation)</asset-clip>")
                    cursor = start + length
                }
                if cursor < total {
                    spine.append("<gap name=\"Camera stopped\" offset=\"\(time(frames: cursor, frameDuration: fd))\" start=\"0s\" duration=\"\(time(frames: total - cursor, frameDuration: fd))\"/>")
                }
                resources.append("<media id=\"\(compound)\" name=\"\(labels[channel]!)\"><sequence format=\"\(formatID)\" duration=\"\(duration)\" tcStart=\"0s\" tcFormat=\"NDF\" audioLayout=\"stereo\" audioRate=\"48k\"><spine>\(spine.joined())</spine></sequence></media>")
            }
            let grid = id()
            let positions = ["F": "-44.4444 25", "I": "44.4444 25", "R": "44.4444 -25", "T": "-44.4444 -25"]
            func gridRef(_ channel: String, lane: Int?) -> String {
                let laneText = lane.map { " lane=\"\($0)\"" } ?? ""
                let mute = channel == "F" ? "" : "<adjust-volume amount=\"-96dB\"/>"
                return "<ref-clip ref=\"\(compounds[channel]!)\"\(laneText) offset=\"0s\" name=\"\(labels[channel]!)\" duration=\"\(duration)\"><adjust-transform position=\"\(positions[channel]!)\" scale=\"0.5 0.5\"/>\(mute)\(channel == "F" ? ["I", "R", "T"].enumerated().map { gridRef($0.element, lane: $0.offset + 1) }.joined() + sectionMarkers : "")</ref-clip>"
            }
            resources.append("<media id=\"\(grid)\" name=\"4CH Grid\"><sequence format=\"\(formatID)\" duration=\"\(duration)\" tcStart=\"0s\" tcFormat=\"NDF\" audioLayout=\"stereo\" audioRate=\"48k\"><spine>\(gridRef("F", lane: nil))</spine></sequence></media>")
            let multicam = id()
            let name = "\(folderLabel) - VIOFO 4CH \(front.input.identity.parking ? "Parking" : "Driving") \(front.input.identity.stamp) (\(index + 1))"
            let angles = [("grid", "4CH Grid", grid)] + channels.map { ($0, labels[$0]!, compounds[$0]!) }
            resources.append("<media id=\"\(multicam)\" name=\"\(escape(name))\"><multicam format=\"\(formatID)\" tcStart=\"0s\" tcFormat=\"NDF\">\(angles.map { "<mc-angle name=\"\($0.1)\" angleID=\"\(multicam)-\($0.0)\"><ref-clip ref=\"\($0.2)\" offset=\"0s\" duration=\"\(duration)\"/></mc-angle>" }.joined())</multicam></media>")
            event.append("<mc-clip ref=\"\(multicam)\" name=\"\(escape(name))\" offset=\"0s\" start=\"0s\" duration=\"\(duration)\"><mc-source angleID=\"\(multicam)-grid\" srcEnable=\"all\"/>\(sectionMarkers)</mc-clip>")
        }
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE fcpxml>\n<fcpxml version=\"1.11\"><resources>\(resources.joined(separator: "\n"))</resources><library><event name=\"Dashcam Multicams\">\(event.joined(separator: "\n"))</event></library></fcpxml>\n"
    }
}
