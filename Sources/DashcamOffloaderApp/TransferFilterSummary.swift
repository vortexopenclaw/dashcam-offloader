import Foundation

/// Selection state, not queue counts or a promise that every selected file will copy.
enum TransferFilterSummary {
    static func lines(
        filters: FilterState,
        hasVideos: Bool,
        hasPhotos: Bool,
        hasGPS: Bool,
        modes: [String],
        channels: [String]
    ) -> [String] {
        func state(_ label: String, _ included: Bool) -> String {
            "\(label) \(included ? "included" : "excluded")"
        }
        var types: [String] = []
        if hasVideos {
            types.append(state("Videos", !filters.selectedModes.isEmpty && !filters.selectedChannels.isEmpty))
        }
        if hasPhotos { types.append(state("Photos", filters.includePhotos)) }
        if hasGPS { types.append(state("GPS logs", filters.includeGPS)) }
        var lines = ["File types: " + (types.isEmpty ? "No selectable footage found" : types.joined(separator: " · "))]
        if !modes.isEmpty {
            lines.append("Recording types: " + modes.map {
                state(ClipItem.displayLabel(for: $0), filters.selectedModes.contains($0))
            }.joined(separator: " · "))
        }
        if !channels.isEmpty {
            lines.append("Channels: " + channels.map {
                state(ClipItem.displayLabel(for: $0), filters.selectedChannels.contains($0))
            }.joined(separator: " · "))
        }
        if filters.datePreset != .allTime {
            if filters.datePreset == .custom {
                let start = filters.startDate.formatted(date: .abbreviated, time: .omitted)
                let end = filters.endDate.formatted(date: .abbreviated, time: .omitted)
                lines.append("Date range: Custom · From \(start) through \(end)")
            } else {
                lines.append("Date range: \(filters.datePreset.label)")
            }
        }
        return lines
    }
}
