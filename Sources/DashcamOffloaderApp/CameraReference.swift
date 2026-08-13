import Foundation

struct CameraReferenceIndex: Codable, Sendable {
    var schemaVersion: Int
    var cameras: [CameraReference]
}

struct CameraReference: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var manufacturer: String
    var model: String
    var status: String
    var confidence: String
    var confidenceNote: String?
    var channelVariants: [CameraReferenceChannelVariant]
    var folders: [CameraReferenceFolder]
    var filenamePatterns: [CameraReferenceFilenamePattern]
    var technicalFacts: [CameraReferenceFact]
    var videoSamples: [CameraReferenceVideoSample]
    var parkingModes: [String]
    var sourceLinks: [CameraReferenceLink]
    var notes: [String]

    var displayManufacturer: String {
        ManufacturerDisplayFormatter.displayName(for: manufacturer)
    }

    var displayName: String {
        "\(displayManufacturer) \(model)"
    }

    var drivingFolders: [CameraReferenceFolder] {
        folders.filter { !$0.isParking && $0.isFootage }
    }

    var parkingFolders: [CameraReferenceFolder] {
        folders.filter(\.isParking)
    }

    var otherFolders: [CameraReferenceFolder] {
        folders.filter { !$0.isParking && !$0.isFootage }
    }

    var manualLinks: [CameraReferenceLink] {
        sourceLinks.filter { $0.kind == "manual" }
    }

    var parkingRecordingModes: [String] {
        let folderModes = parkingFolders.map(\.mode)
        let tokenModes = filenamePatterns.flatMap { $0.modes.values }.filter {
            $0.lowercased().contains("parking")
        }
        return Array(Set(parkingModes + folderModes + tokenModes)).sorted()
    }

    var evidenceLabel: String {
        let normalized = status.lowercased()
        if normalized.contains("validated") || normalized.contains("sampled") {
            return "Card observed"
        }
        if normalized.contains("experimental") {
            return "Experimental"
        }
        if normalized == "reference_only" {
            return "Measured video reference"
        }
        return "Research profile"
    }
}

struct CameraReferenceChannelVariant: Codable, Hashable, Sendable {
    var channels: Int?
    var variant: String?
    var roles: [String]
    var validation: String?
}

struct CameraReferenceFolder: Codable, Hashable, Sendable {
    var path: String
    var mode: String
    var importable: Bool
    var validation: String?
    var notes: [String]

    var isParking: Bool {
        mode.lowercased().contains("parking") || path.lowercased().contains("park")
    }

    var isFootage: Bool {
        let normalized = mode.lowercased()
        return !["photo", "still_image", "gps", "settings", "metadata"].contains(normalized)
    }
}

struct CameraReferenceFilenamePattern: Codable, Hashable, Sendable {
    var pattern: String
    var appliesTo: [String]
    var modes: [String: String]
    var channels: [String: String]
    var defaultChannel: String?
    var timestampFormat: String?
}

struct CameraReferenceFact: Codable, Hashable, Sendable {
    var label: String
    var value: String
}

struct CameraReferenceVideoSample: Codable, Hashable, Sendable {
    var channel: String
    var mode: String
    var codec: String
    var resolution: String
    var fps: String
    var bitrate: String
    var container: String
    var source: String
}

struct CameraReferenceLink: Codable, Hashable, Sendable {
    var label: String
    var url: String
    var kind: String

    var destination: URL? { URL(string: url) }
}

enum CameraReferenceStore {
    static func load() throws -> [CameraReference] {
        guard let url = defaultIndexURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        let index = try JSONDecoder().decode(CameraReferenceIndex.self, from: data)
        guard index.schemaVersion == 1 else {
            throw CocoaError(.coderInvalidValue)
        }
        return index.cameras.sorted {
            if $0.displayManufacturer != $1.displayManufacturer {
                return $0.displayManufacturer.localizedStandardCompare($1.displayManufacturer) == .orderedAscending
            }
            return $0.model.localizedStandardCompare($1.model) == .orderedAscending
        }
    }

    static func defaultIndexURL() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("CameraReference/cameras.json"))
        }

        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        candidates.append(current.appendingPathComponent("reference/cameras.json"))
        candidates.append(current.deletingLastPathComponent().appendingPathComponent("reference/cameras.json"))

        let executable = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
        let executableDirectory = executable.deletingLastPathComponent()
        candidates.append(executableDirectory.appendingPathComponent("reference/cameras.json"))
        candidates.append(executableDirectory.deletingLastPathComponent().appendingPathComponent("reference/cameras.json"))
        candidates.append(executableDirectory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("reference/cameras.json"))

        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }
}
