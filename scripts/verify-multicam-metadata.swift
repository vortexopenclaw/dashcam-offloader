// Compile with MulticamExporter.swift and MulticamVerification.swift using
// swiftc -parse-as-library -O -sdk <macOS SDK> ... -o <scratch>/verify-multicam
// Run: <scratch>/verify-multicam <footage folder> <scratch output folder>
// Reads footage only; all XML outputs are confined to the separate output folder.
import Foundation

@main struct MulticamMetadataVerification {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            throw MulticamExporter.Failure.message("Expected footage and output folders.")
        }
        let source = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        let destination = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
        guard destination != source, !destination.path.hasPrefix(source.path + "/") else {
            throw MulticamExporter.Failure.message("Output must be outside the footage folder.")
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let inputs = try MulticamExporter.folderInputs(source)
        try MulticamExporter.validate(inputs)
        var reference = ""
        for iteration in 0..<5 {
            // Alternate order to reduce warm-cache bias; this is metadata latency,
            // not uncached card throughput or a Final Cut import/playback benchmark.
            func serial() async throws {
                let start = ContinuousClock.now
                var videos: [MulticamExporter.Video] = []
                for input in inputs.sorted(by: { $0.url.path < $1.url.path }) {
                    videos.append(try await MulticamExporter.loadVideo(input))
                }
                reference = try MulticamExporter.render(videos)
                print("SERIAL \(iteration): \(start.duration(to: .now))")
            }
            func concurrent() async throws -> String {
                let output = destination.appendingPathComponent("multicam-\(UUID().uuidString).fcpxml")
                let start = ContinuousClock.now
                let result = try await MulticamExporter.create(inputs: inputs, output: output)
                print("BOUNDED \(iteration): \(start.duration(to: .now)); files=\(inputs.count); drives=\(result.multicamCount)")
                return try String(contentsOf: output, encoding: .utf8)
            }
            let xml: String
            if iteration % 2 == 0 {
                try await serial()
                xml = try await concurrent()
            } else {
                xml = try await concurrent()
                try await serial()
            }
            guard xml == reference else { fatalError("Concurrent XML differs from serial XML") }
            let document = try XMLDocument(xmlString: xml)
            let multicams = try document.nodes(forXPath: "//multicam").count
            guard try document.nodes(forXPath: "//multicam/mc-angle").count == multicams * 5,
                  try document.nodes(forXPath: "//adjust-transform[@scale='0.5 0.5']").count == multicams * 4 else {
                fatalError("Five original/grid angles not preserved")
            }
        }
        let cancelledOutput = destination.appendingPathComponent("cancelled-\(UUID().uuidString).fcpxml")
        let cancelled = Task {
            // Self-cancel deterministically before probing, without scheduler races.
            withUnsafeCurrentTask { $0?.cancel() }
            return try await MulticamExporter.create(inputs: inputs, output: cancelledOutput)
        }
        do {
            _ = try await cancelled.value
            fatalError("Cancelled export completed")
        } catch is CancellationError {}
        guard !FileManager.default.fileExists(atPath: cancelledOutput.path) else {
            fatalError("Cancelled export published output")
        }
        let existing = destination.appendingPathComponent("existing-\(UUID().uuidString).fcpxml")
        try Data("do not overwrite".utf8).write(to: existing, options: .withoutOverwriting)
        do {
            _ = try await MulticamExporter.create(inputs: inputs, output: existing)
            fatalError("Existing output was overwritten")
        } catch MulticamExporter.Failure.message(let message) {
            guard message.contains("already exists") else { throw MulticamExporter.Failure.message(message) }
        }
        guard try String(contentsOf: existing, encoding: .utf8) == "do not overwrite" else {
            fatalError("Existing output changed")
        }
        guard MulticamVerification.run() else { fatalError("Multicam regressions failed") }
        print("METADATA VERIFY PASS: byte-identical serial/bounded XML, five angles, cancellation, overwrite guard")
    }
}
