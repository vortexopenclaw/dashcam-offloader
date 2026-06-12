import Foundation

struct CopyPlanner {
    func makePlan(
        sourceRoot: URL,
        destinationRoot: URL,
        profile: DashcamProfile,
        clips: [ClipItem],
        filters: FilterState,
        namingOptions: OutputNamingOptions = OutputNamingOptions()
    ) -> CopyPlan {
        let selected = clips.filter { clip in
            guard clip.excludedReason == nil else { return false }
            if clip.isPhoto && !filters.includePhotos { return false }
            if clip.isGPS && !filters.includeGPS { return false }
            if clip.isVideo {
                if filters.selectedModes.isEmpty { return false }
                if filters.selectedChannels.isEmpty { return false }
                if filters.selectedModes.allSatisfy({ !ClipItem.isParkingMode($0) }),
                   clip.isParkingFootage {
                    return false
                }
                if !filters.selectedModes.contains(clip.mode) { return false }
                if !filters.selectedChannels.contains(clip.channel) { return false }
            }
            if filters.useStartDate, clip.canUseTimestampForDateFiltering, let timestamp = clip.timestamp, timestamp < Calendar.current.startOfDay(for: filters.startDate) {
                return false
            }
            if filters.useEndDate, clip.canUseTimestampForDateFiltering, let timestamp = clip.timestamp {
                let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: filters.endDate)) ?? filters.endDate
                if timestamp >= end { return false }
            }
            return true
        }

        let items = groupedDownloadItems(
            from: selected,
            destinationRoot: destinationRoot,
            profile: profile,
            filters: filters,
            namingOptions: namingOptions
        ).map { itemClips in
            let representative = representativeClip(for: itemClips)
            return CopyPlanItem(
                clip: representative,
                sourceClips: itemClips.count > 1 ? itemClips : [],
                destinationURL: destinationURL(
                    for: representative,
                    destinationRoot: destinationRoot,
                    filters: filters,
                    namingOptions: namingOptions
                ),
                status: .planned,
                message: nil
            )
        }
        let supportItems = filters.includeCameraSettings ? settingsItems(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
        ) : []

        return CopyPlan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            profile: profile,
            clips: selected,
            items: items,
            supportItems: supportItems
        )
    }

    private func destinationURL(
        for clip: ClipItem,
        destinationRoot: URL,
        filters: FilterState,
        namingOptions: OutputNamingOptions
    ) -> URL {
        let outputFilename = filename(for: clip, namingOptions: namingOptions)
        guard filters.separateCategoryFolders else {
            return destinationRoot.appendingPathComponent(outputFilename)
        }

        return destinationRoot
            .appendingPathComponent(safePathComponent(clip.outputCategory), isDirectory: true)
            .appendingPathComponent(outputFilename)
    }

    private func groupedDownloadItems(
        from clips: [ClipItem],
        destinationRoot: URL,
        profile: DashcamProfile,
        filters: FilterState,
        namingOptions: OutputNamingOptions
    ) -> [[ClipItem]] {
        guard profile.manufacturer.caseInsensitiveCompare("GoPro") == .orderedSame else {
            return clips.map { [$0] }
        }

        var groupedItems: [[ClipItem]] = []
        let grouped = Dictionary(grouping: clips) { clip in
            [
                clip.relativePath.split(separator: "/").dropLast().joined(separator: "/"),
                clip.mode,
                clip.channel,
                goProLoopGroupKey(for: clip.filename) ?? clip.id
            ].joined(separator: "\u{1f}")
        }

        for key in grouped.keys.sorted() {
            let bucket = grouped[key, default: []].sorted { lhs, rhs in
                let left = goProSequenceNumber(for: lhs.filename) ?? Int.max
                let right = goProSequenceNumber(for: rhs.filename) ?? Int.max
                if left != right { return left < right }
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            guard bucket.count > 1,
                  bucket.allSatisfy({ $0.mode == "looping" && $0.isVideo }) else {
                groupedItems.append(contentsOf: bucket.map { [$0] })
                continue
            }
            switch filters.goProLoopGroupOutput {
            case .originalsOnly:
                groupedItems.append(contentsOf: bucket.map { [$0] })
            case .originalsAndMerged:
                groupedItems.append(contentsOf: bucket.map { [$0] })
                groupedItems.append(bucket)
            case .mergedOnly:
                groupedItems.append(bucket)
            }
        }

        return groupedItems
    }

    func hasGoProLoopGroups(profile: DashcamProfile, clips: [ClipItem]) -> Bool {
        var probeFilters = FilterState()
        probeFilters.goProLoopGroupOutput = .mergedOnly
        return groupedDownloadItems(
            from: clips,
            destinationRoot: URL(fileURLWithPath: "/", isDirectory: true),
            profile: profile,
            filters: probeFilters,
            namingOptions: OutputNamingOptions()
        ).contains { $0.count > 1 }
    }

    private func representativeClip(for clips: [ClipItem]) -> ClipItem {
        guard clips.count > 1,
              var first = clips.first,
              let last = clips.last,
              let groupKey = goProLoopGroupKey(for: first.filename) else {
            return clips.first!
        }

        let ext = URL(fileURLWithPath: first.filename).pathExtension
        let firstSequence = goProSequenceNumber(for: first.filename) ?? 0
        let lastSequence = goProSequenceNumber(for: last.filename) ?? firstSequence
        let outputName = String(format: "%@%04d-%04d.%@", groupKey, firstSequence, lastSequence, ext.isEmpty ? "MP4" : ext)
        first.filename = outputName
        first.size = clips.reduce(Int64(0)) { $0 + $1.size }
        first.sourceURL = clips[0].sourceURL
        first.relativePath = clips[0].relativePath
        return first
    }

    private func goProLoopGroupKey(for filename: String) -> String? {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent.uppercased()
        guard stem.range(of: #"^G[HXP][A-Z0-9]{2}\d{4}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return String(stem.prefix(4))
    }

    private func goProSequenceNumber(for filename: String) -> Int? {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent.uppercased()
        guard stem.count == 8 else { return nil }
        return Int(stem.suffix(4))
    }

    private func filename(for clip: ClipItem, namingOptions: OutputNamingOptions) -> String {
        guard clip.isVideo else { return clip.filename }

        let suffix = normalizedFilenameSuffix(namingOptions.videoFilenameSuffix)
        guard !suffix.isEmpty else { return clip.filename }

        let filenameURL = URL(fileURLWithPath: clip.filename)
        let fileExtension = filenameURL.pathExtension
        guard !fileExtension.isEmpty else {
            return "\(clip.filename)\(suffix)"
        }

        let stem = filenameURL.deletingPathExtension().lastPathComponent
        return "\(stem)\(suffix).\(fileExtension)"
    }

    private func normalizedFilenameSuffix(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let suffix = value
            .unicodeScalars
            .map { invalidCharacters.contains($0) ? Character("-") : Character($0) }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = suffix.first else { return "" }
        if first == " " || first == "-" || first == "_" {
            return suffix
        }
        return " \(suffix)"
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_+"))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func settingsItems(
        sourceRoot: URL,
        destinationRoot: URL
    ) -> [SupportFileItem] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        let volumeFolder = safePathComponent(sourceRoot.lastPathComponent)
        var items: [SupportFileItem] = []

        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.relativePath(from: sourceRoot)
            if shouldSkipSettingsTraversal(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }
            guard shouldPreserveSettingsFile(relativePath: relativePath, fileURL: fileURL) else {
                continue
            }

            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            let destinationURL = destinationRoot
                .appendingPathComponent("Camera Settings", isDirectory: true)
                .appendingPathComponent(volumeFolder.isEmpty ? "source" : volumeFolder, isDirectory: true)
                .appendingPathComponent(relativePath)

            items.append(SupportFileItem(
                sourceURL: fileURL,
                relativePath: relativePath,
                filename: fileURL.lastPathComponent,
                size: size,
                destinationURL: destinationURL,
                status: .planned,
                message: nil
            ))
        }

        return items.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    private func shouldPreserveSettingsFile(relativePath: String, fileURL: URL) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        let lowerParts = parts.map { $0.lowercased() }
        let filename = fileURL.lastPathComponent.lowercased()
        let ext = fileURL.pathExtension.lowercased()
        guard !isSensitiveSupportFile(relativePath: relativePath, filename: filename),
              !["app", "dmg", "dll", "exe", "pkg"].contains(ext) else {
            return false
        }

        if lowerParts.contains("config") || lowerParts.contains("settings") || lowerParts.contains("setting") {
            return !isMediaOrGpsExtension(ext)
        }

        if filename == ".boot.log" || filename == "boot.log" {
            return true
        }

        return false
    }

    private func isSensitiveSupportFile(relativePath: String, filename: String) -> Bool {
        let combined = "\(relativePath) \(filename)".lowercased()
        let sensitiveFragments = [
            "bt_ssid",
            "ssid",
            "wifi",
            "wi-fi",
            "password",
            "passwd",
            "pwd",
            "cloud",
            "account",
            "serial",
            "imei",
            "uuid",
            "uid",
            "deviceid",
            "device id",
            "bluetooth",
            "token",
            "secret"
        ]
        return sensitiveFragments.contains { combined.contains($0) }
    }

    private func shouldSkipSettingsTraversal(relativePath: String) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        return parts.contains { part in
            part == ".Spotlight-V100" ||
            part == ".fseventsd" ||
            part == ".Trashes" ||
            part == ".TemporaryItems" ||
            part == ".dashcamexport" ||
            part == "System Volume Information"
        }
    }

    private func isMediaOrGpsExtension(_ ext: String) -> Bool {
        ClipItem.videoExtensions.contains(ext) ||
            ClipItem.photoExtensions.contains(ext) ||
            ClipItem.gpsExtensions.contains(ext)
    }

}
