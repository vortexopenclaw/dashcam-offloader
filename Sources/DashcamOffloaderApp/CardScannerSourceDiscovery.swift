import Foundation

extension CardScanner {
    func discoverMountedSources(showAllVolumes: Bool = false) -> [MountedSource] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .volumeIsBrowsableKey, .volumeIsLocalKey]
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) ?? fallbackVolumeDirectoryURLs(resourceKeys: resourceKeys)

        return urls
            .filter { url in
                let standardizedURL = url.standardizedFileURL
                guard standardizedURL.path.hasPrefix("/Volumes/") else { return false }
                let values = try? standardizedURL.resourceValues(forKeys: Set(resourceKeys))
                guard values?.isDirectory == true else { return false }
                guard values?.volumeIsBrowsable != false else { return false }
                return shouldShowMountedSource(standardizedURL, showAllVolumes: showAllVolumes)
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MountedSource(url: $0.standardizedFileURL, name: $0.lastPathComponent) }
    }

    func fallbackVolumeDirectoryURLs(resourceKeys: [URLResourceKey]) -> [URL] {
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        return (try? fileManager.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    func mountedSource(forUserSelectedURL url: URL) -> MountedSource {
        let standardizedURL = url.standardizedFileURL
        if let volumeURL = mountedVolumeRoot(containing: standardizedURL) {
            return MountedSource(url: volumeURL, name: volumeURL.lastPathComponent)
        }

        return MountedSource(url: standardizedURL, name: standardizedURL.lastPathComponent)
    }

    func shouldShowMountedSource(_ url: URL, showAllVolumes: Bool) -> Bool {
        if isSystemVolume(url) { return false }
        if showAllVolumes { return true }
        if isNetworkMountedVolume(url) { return false }
        if isObviousNonDashcamVolume(url) { return false }
        return hasDashcamLikeEvidence(url)
    }


    func enumerateFiles(sourceURL: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.relativePath(from: sourceURL)
            if shouldSkipTraversal(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                files.append(fileURL)
            }
        }
        return files
    }

    func isSystemVolume(_ url: URL) -> Bool {
        let name = normalizedName(url.lastPathComponent)
        return name == "macintosh hd" ||
            name == "system" ||
            name == "data" ||
            name.hasPrefix("com.apple.")
    }

    func mountedVolumeRoot(containing url: URL) -> URL? {
        let components = url.standardizedFileURL.pathComponents
        guard components.count >= 3, components[1] == "Volumes" else {
            return nil
        }

        return URL(fileURLWithPath: "/Volumes/\(components[2])", isDirectory: true)
    }

    func isObviousNonDashcamVolume(_ url: URL) -> Bool {
        let name = normalizedName(url.lastPathComponent)
        let blockedNameFragments = [
            "time machine",
            "timemachine",
            "backup",
            "backups",
            "carbon copy",
            "superduper",
            "clone",
            "start9",
            "bitcoin"
        ]
        if blockedNameFragments.contains(where: { name.contains($0) }) {
            return true
        }

        let blockedRootItems = [
            "Backups.backupdb",
            ".HFS+ Private Directory Data",
            ".com.apple.timemachine.donotpresent"
        ]
        return blockedRootItems.contains { item in
            fileManager.fileExists(atPath: url.appendingPathComponent(item).path)
        }
    }

    func isNetworkMountedVolume(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey])
        return values?.volumeIsLocal == false
    }

    func hasDashcamLikeEvidence(_ url: URL) -> Bool {
        let rootIndicators: Set<String> = [
            "blackvue",
            "bookmark",
            "config",
            "cont_rec",
            "dcim",
            "event",
            "evt_rec",
            "gps",
            "incabin_rec",
            "inf",
            "manual_rec",
            "motion_timelapse_rec",
            "movie",
            "normal",
            "parking",
            "parking_rec",
            "park",
            "pevent",
            "photo",
            "record",
            "rec",
            "setting",
            "settings",
            "sos_rec",
            "360cardvr",
            "misc",
            "private",
            "video",
            "user"
        ]

        if let rootItems = try? fileManager.contentsOfDirectory(atPath: url.path) {
            for item in rootItems {
                let normalized = normalizedName(item)
                if rootIndicators.contains(normalized) {
                    return true
                }
            }
        }

        return hasShallowMediaFile(in: url, depth: 0, maxDepth: 5, remainingBudget: 2_000)
    }

    func hasShallowMediaFile(in url: URL, depth: Int, maxDepth: Int, remainingBudget: Int) -> Bool {
        guard depth <= maxDepth, remainingBudget > 0 else { return false }
        guard let items = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var budget = remainingBudget
        for item in items {
            guard budget > 0 else { return false }
            budget -= 1

            let relativeName = item.lastPathComponent
            if shouldSkipTraversal(relativePath: relativeName) { continue }

            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isRegularFile == true, isCandidateExtension(item.pathExtension.lowercased()) {
                return true
            }
            if values?.isDirectory == true, hasShallowMediaFile(in: item, depth: depth + 1, maxDepth: maxDepth, remainingBudget: budget) {
                return true
            }
        }
        return false
    }

    func normalizedName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

}
