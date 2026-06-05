import Foundation

struct CopyPlanner {
    func makePlan(sourceRoot: URL, destinationRoot: URL, profile: DashcamProfile, clips: [ClipItem], filters: FilterState) -> CopyPlan {
        let selected = clips.filter { clip in
            guard clip.excludedReason == nil else { return false }
            if clip.isPhoto && !filters.includePhotos { return false }
            if clip.isGPS && !filters.includeGPS { return false }
            if !filters.selectedModes.isEmpty && !filters.selectedModes.contains(clip.mode) { return false }
            if !filters.selectedChannels.isEmpty && !filters.selectedChannels.contains(clip.channel) { return false }
            if filters.useStartDate, let timestamp = clip.timestamp, timestamp < Calendar.current.startOfDay(for: filters.startDate) {
                return false
            }
            if filters.useEndDate, let timestamp = clip.timestamp {
                let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: filters.endDate)) ?? filters.endDate
                if timestamp >= end { return false }
            }
            return true
        }

        let items = selected.map { clip in
            CopyPlanItem(
                clip: clip,
                destinationURL: destinationURL(for: clip, destinationRoot: destinationRoot, profile: profile, filters: filters),
                status: .planned,
                message: nil
            )
        }

        return CopyPlan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            profile: profile,
            clips: selected,
            items: items
        )
    }

    private func destinationURL(for clip: ClipItem, destinationRoot: URL, profile: DashcamProfile, filters: FilterState) -> URL {
        let day = clip.timestamp.map(Self.dayFormatter.string(from:)) ?? "undated"
        let modelFolder = safePathComponent(profile.displayName)
        let categoryFolder = safePathComponent(filters.separateCategoryFolders ? clip.outputCategory : clip.mode)
        let channelFolder = safePathComponent(clip.channel)

        return destinationRoot
            .appendingPathComponent(modelFolder, isDirectory: true)
            .appendingPathComponent(categoryFolder, isDirectory: true)
            .appendingPathComponent(day, isDirectory: true)
            .appendingPathComponent(channelFolder, isDirectory: true)
            .appendingPathComponent(clip.filename)
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_+"))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
