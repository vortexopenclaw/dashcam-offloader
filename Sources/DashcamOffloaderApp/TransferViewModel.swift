@preconcurrency import AppKit
@preconcurrency import AVFoundation
import Foundation

@MainActor
final class TransferViewModel: ObservableObject {
    @Published var profiles: [DashcamProfile] = []
    @Published var mountedSources: [MountedSource] = []
    @Published var selectedSource: MountedSource?
    @Published var destinationURL: URL?
    @Published var detectionCandidates: [DetectionCandidate] = []
    @Published var selectedProfile: DashcamProfile?
    @Published var clips: [ClipItem] = []
    @Published var filters = FilterState()
    @Published var copyPlan: CopyPlan?
    @Published var copyProgress = CopyProgress()
    @Published var scanSummary = ScanSummary()
    @Published var statusMessage = "Ready"
    @Published var isScanning = false
    @Published var showAllVolumes = false
    @Published var copyResults: [CopyPlanItem] = []
    @Published var supportFileResults: [SupportFileItem] = []
    @Published var lastOutputDirectory: URL?
    @Published var openDestinationWhenComplete = false
    @Published var ejectSourceWhenComplete = false
    @Published var outputNamingOptions = OutputNamingOptions()
    @Published var isSubmittingFeedback = false
    @Published var feedbackMessage = ""
    @Published var selectedQueueItemIDs: Set<CopyPlanItem.ID> = []

    private let scanner = CardScanner()
    private let planner = CopyPlanner()
    private let feedbackService = FeedbackService.production
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    private var lastScannedFiles: [URL] = []
    private var lastScanDiagnostics: [ScanDiagnosticEntry] = []
    private var excludedQueueClipIDs: Set<ClipItem.ID> = []
    private var copyTask: Task<Void, Never>?
    private var customSourceNames: [MountedSource.ID: String] = [:]

    init() {
        refreshSources()
        loadProfiles()
        startVolumeObservation()
    }

    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        for token in workspaceNotificationTokens {
            notificationCenter.removeObserver(token)
        }
    }

    var availableModes: [String] {
        Array(Set(footageClips.map(\.mode))).sorted()
    }

    var availableChannels: [String] {
        Array(Set(footageClips.map(\.channel))).sorted()
    }

    var eligibleClips: [ClipItem] {
        clips.filter { $0.excludedReason == nil }
    }

    var footageClips: [ClipItem] {
        eligibleClips.filter { !$0.isGPS && !$0.isPhoto }
    }

    var inferredLearningChannelSetup: (count: Int, description: String) {
        let scannedLabels = orderedChannelLabels(from: footageClips.map(\.channel))
        if !scannedLabels.isEmpty {
            return (min(max(scannedLabels.count, 1), 4), scannedLabels.joined(separator: " / "))
        }

        let profileChannels = selectedProfile?.channels ?? [:]
        if selectedProfile?.id != DashcamProfile.genericNewDashcam.id, !profileChannels.isEmpty {
            let labels = orderedChannelLabels(from: profileChannels.values)
            if !labels.isEmpty {
                return (min(max(labels.count, 1), 4), labels.joined(separator: " / "))
            }
        }

        let groupedCount = inferredSynchronizedChannelCount()
        if groupedCount > 1 {
            return (groupedCount, defaultChannelDescription(for: groupedCount))
        }

        return (1, defaultChannelDescription(for: 1))
    }

    var profilesByBrand: [(brand: String, profiles: [DashcamProfile])] {
        let grouped = Dictionary(grouping: profiles, by: \.displayManufacturer)
        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { brand in
                (
                    brand,
                    grouped[brand, default: []].sorted {
                        $0.model.localizedStandardCompare($1.model) == .orderedAscending
                    }
                )
            }
    }

    private func orderedChannelLabels(from values: some Sequence<String>) -> [String] {
        let ignored = Set(["", "unknown", "gps"])
        let labels = Set(
            values
                .compactMap(normalizedPhysicalChannelLabel)
                .filter { !ignored.contains($0) }
        )

        let preferred = ["front", "interior", "rear", "telephoto"]
        return labels.sorted { lhs, rhs in
            let lhsIndex = preferred.firstIndex(of: lhs) ?? preferred.count
            let rhsIndex = preferred.firstIndex(of: rhs) ?? preferred.count
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map(ClipItem.displayLabel(for:))
    }

    private func normalizedPhysicalChannelLabel(_ value: String) -> String? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "", "unknown", "gps":
            return nil
        case "f", "front", "parking_front", "pf":
            return "front"
        case "i", "interior", "inside", "cabin", "in_cabin", "parking_interior", "parking_cabin", "pi":
            return "interior"
        case "r", "rear", "back", "parking_rear", "pr":
            return "rear"
        case "t", "telephoto", "parking_telephoto", "pt":
            return "telephoto"
        default:
            return normalized
        }
    }

    private func inferredSynchronizedChannelCount() -> Int {
        let groups = Dictionary(grouping: footageClips) { clip in
            if clip.timestampSource == .filename, let timestamp = clip.timestamp {
                return "timestamp:\(Int(timestamp.timeIntervalSince1970))"
            }
            return "stem:\(clip.filenameStemWithoutChannelHint)"
        }
        let count = groups.values.map(\.count).max() ?? 1
        return min(max(count, 1), 4)
    }

    private func defaultChannelDescription(for count: Int) -> String {
        switch count {
        case 1:
            return "Front"
        case 2:
            return "Front / rear"
        case 3:
            return "Front / interior / rear"
        case 4:
            return "Front / interior / rear / telephoto"
        default:
            return ""
        }
    }

    func refreshSources(userInitiated: Bool = false) {
        let previousSource = selectedSource
        let discoveredSources = scanner.discoverMountedSources(showAllVolumes: showAllVolumes)
            .map(sourceWithCustomName)
        let discoveredIDs = Set(discoveredSources.map(\.id))
        let manualSources = mountedSources
            .filter { !isMountedVolumeSource($0) }
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
            .filter { !discoveredIDs.contains($0.id) }
            .map(sourceWithCustomName)

        mountedSources = (discoveredSources + manualSources).sorted { lhs, rhs in
            if isMountedVolumeSource(lhs) != isMountedVolumeSource(rhs) {
                return isMountedVolumeSource(lhs)
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        if let previousSource,
           let refreshedSource = mountedSources.first(where: { $0.id == previousSource.id }) {
            selectedSource = refreshedSource
        } else {
            selectedSource = mountedSources.first
            clearSourceDerivedState(for: selectedSource)
        }

        if userInitiated {
            statusMessage = "Sources refreshed. Found \(mountedSources.count) \(mountedSources.count == 1 ? "source" : "sources")"
        }
    }

    private func startVolumeObservation() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let notifications: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification
        ]

        workspaceNotificationTokens = notifications.map { notificationName in
            notificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshSources()
                }
            }
        }
    }

    func setShowAllVolumes(_ value: Bool) {
        showAllVolumes = value
        refreshSources()
    }

    private func isMountedVolumeSource(_ source: MountedSource) -> Bool {
        sourceVolumeURL(for: source.url).path.hasPrefix("/Volumes/")
    }

    func loadProfiles() {
        guard let profilesDirectory = ProfileStore.defaultProfilesDirectory() else {
            statusMessage = "Could not find profiles directory"
            return
        }

        do {
            profiles = try ProfileStore(profilesDirectory: profilesDirectory).loadProfiles()
            statusMessage = "Loaded \(profiles.count) profiles"
        } catch {
            statusMessage = "Profile load failed: \(error.localizedDescription)"
        }
    }

    func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose dashcam card or folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedSource?.url ?? URL(fileURLWithPath: "/Volumes", isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            let source = sourceWithCustomName(scanner.mountedSource(forUserSelectedURL: url))
            upsertMountedSource(source)
            selectSource(source, scanImmediately: true)
        }
    }

    func selectSource(_ source: MountedSource, scanImmediately: Bool = true) {
        selectedSource = source
        clearSourceDerivedState(for: source)
        statusMessage = "Selected \(source.name)"

        if scanImmediately {
            scanSelectedSource()
        }
    }

    private func upsertMountedSource(_ source: MountedSource) {
        let namedSource = sourceWithCustomName(source)
        if let existingIndex = mountedSources.firstIndex(where: { $0.id == namedSource.id }) {
            mountedSources[existingIndex] = namedSource
        } else {
            mountedSources.insert(namedSource, at: 0)
        }
    }

    private func sourceWithCustomName(_ source: MountedSource) -> MountedSource {
        guard let customName = customSourceNames[source.id] else { return source }
        var renamedSource = source
        renamedSource.name = customName
        return renamedSource
    }

    func renameSource(_ source: MountedSource) {
        let alert = NSAlert()
        alert.messageText = "Rename Source"
        alert.informativeText = "This changes the name shown in Dashcam Offloader. It does not rename the memory card."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = source.name
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let trimmedName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        customSourceNames[source.id] = trimmedName
        var renamedSource = source
        renamedSource.name = trimmedName

        if let index = mountedSources.firstIndex(where: { $0.id == source.id }) {
            mountedSources[index] = renamedSource
        }
        if selectedSource?.id == source.id {
            selectedSource = renamedSource
        }
        statusMessage = "Renamed source to \(trimmedName)"
    }

    func ejectSource(_ source: MountedSource) {
        guard !copyProgress.isRunning else {
            statusMessage = "Stop the download before ejecting a source"
            return
        }

        let volumeURL = sourceVolumeURL(for: source.url)
        if volumeURL.path.hasPrefix("/Volumes/") {
            statusMessage = "Ejecting \(source.name)..."
            Task { [weak self, source, volumeURL] in
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: volumeURL)
                    await MainActor.run {
                        self?.removeSourceFromList(source, status: "Ejected \(source.name)")
                    }
                } catch {
                    await MainActor.run {
                        self?.statusMessage = "Eject failed: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            removeSourceFromList(source, status: "Removed \(source.name)")
        }
    }

    private func removeSourceFromList(_ source: MountedSource, status: String) {
        mountedSources.removeAll { $0.id == source.id }
        customSourceNames.removeValue(forKey: source.id)

        if selectedSource?.id == source.id {
            selectedSource = mountedSources.first
            clearSourceDerivedState(for: selectedSource)
        }

        statusMessage = status
    }

    private func clearSourceDerivedState(for source: MountedSource?) {
        detectionCandidates = []
        selectedProfile = nil
        clips = []
        lastScannedFiles = []
        lastScanDiagnostics = []
        excludedQueueClipIDs = []
        selectedQueueItemIDs = []
        copyPlan = nil
        copyResults = []
        supportFileResults = []
        scanSummary = source.map { ScanSummary(sourcePath: $0.url.path) } ?? ScanSummary()
    }

    func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose download folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            destinationURL = url
            rebuildPlan()
        }
    }

    func scanSelectedSource() {
        guard let selectedSource else {
            statusMessage = "Choose a source first"
            return
        }

        isScanning = true
        statusMessage = "Scanning \(selectedSource.name)..."
        copyPlan = nil
        copyResults = []
        supportFileResults = []
        excludedQueueClipIDs = []
        selectedQueueItemIDs = []
        scanSummary = ScanSummary(sourcePath: selectedSource.url.path)

        Task { [weak self, profiles, selectedSource] in
            guard let self else { return }
            do {
                let scanResult = try await Task.detached {
                    try CardScanner().scanWithOSD(sourceURL: selectedSource.url, profiles: profiles)
                }.value
                self.detectionCandidates = scanResult.candidates
                self.selectedProfile = scanResult.selectedProfile
                self.lastScannedFiles = scanResult.allFiles
                self.lastScanDiagnostics = scanResult.diagnostics
                self.clips = scanResult.clips
                self.resetFiltersForCurrentClips()
                let footageClips = self.footageClips
                self.scanSummary = ScanSummary(
                    sourcePath: selectedSource.url.path,
                    scannedFiles: scanResult.allFiles.count,
                    copyableItems: self.eligibleClips.count,
                    excludedItems: scanResult.clips.filter { $0.excludedReason != nil }.count,
                    samplePaths: [],
                    categoryCounts: Dictionary(grouping: self.eligibleClips, by: \.outputCategory)
                        .mapValues(\.count),
                    modeCounts: Dictionary(grouping: footageClips, by: \.displayMode)
                        .mapValues(\.count)
                )
                self.statusMessage = "Scanned \(selectedSource.url.path). Found \(self.eligibleClips.count) downloadable items"
                self.rebuildPlan()
            } catch {
                self.statusMessage = "Scan failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    func selectProfile(_ profile: DashcamProfile) {
        selectedProfile = profile
        guard let selectedSource else { return }
        clips = scanner.classify(files: lastScannedFiles, sourceURL: selectedSource.url, profile: profile)
        resetFiltersForCurrentClips()
        rebuildPlan()
    }

    func resetFiltersForCurrentClips() {
        filters.selectedModes = Set(footageClips.map(\.mode))
        filters.selectedChannels = Set(footageClips.map(\.channel))
        filters.includePhotos = false
        filters.includeGPS = false
        filters.includeCameraSettings = false
        filters.separateCategoryFolders = true
    }

    func setDatePreset(_ preset: DateFilterPreset) {
        filters.datePreset = preset

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch preset {
        case .today:
            filters.useStartDate = true
            filters.useEndDate = true
            filters.startDate = today
            filters.endDate = today
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            filters.useStartDate = true
            filters.useEndDate = true
            filters.startDate = yesterday
            filters.endDate = yesterday
        case .lastWeek:
            filters.useStartDate = true
            filters.useEndDate = true
            filters.startDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            filters.endDate = today
        case .allTime:
            filters.useStartDate = false
            filters.useEndDate = false
        case .custom:
            filters.useStartDate = true
            filters.useEndDate = true
        }

        rebuildPlan()
    }

    func setCustomStartDate(_ date: Date) {
        filters.datePreset = .custom
        filters.useStartDate = true
        filters.startDate = date
        rebuildPlan()
    }

    func setCustomEndDate(_ date: Date) {
        filters.datePreset = .custom
        filters.useEndDate = true
        filters.endDate = date
        rebuildPlan()
    }

    func rebuildPlan() {
        guard let selectedSource, let selectedProfile else {
            copyPlan = nil
            return
        }

        let previewDestination = destinationURL ?? URL(fileURLWithPath: "/Choose Download Folder", isDirectory: true)
        copyPlan = planner.makePlan(
            sourceRoot: selectedSource.url,
            destinationRoot: previewDestination,
            profile: selectedProfile,
            clips: clips.filter { !excludedQueueClipIDs.contains($0.id) },
            filters: filters,
            namingOptions: outputNamingOptions
        )
        if let itemIDs = copyPlan?.items.map(\.id) {
            selectedQueueItemIDs.formIntersection(Set(itemIDs))
        } else {
            selectedQueueItemIDs = []
        }
    }

    func setVideoFilenameSuffix(_ value: String) {
        outputNamingOptions.videoFilenameSuffix = value
        rebuildPlan()
    }

    func startCopy() {
        guard destinationURL != nil else {
            statusMessage = "Choose a download folder first"
            return
        }
        guard let copyPlan, !copyPlan.items.isEmpty else {
            statusMessage = "Nothing selected to download"
            return
        }
        guard !copyProgress.isRunning else { return }

        statusMessage = "Downloading..."
        copyResults = []
        supportFileResults = []
        let executor = CopyExecutor { [weak self] progress in
            self?.copyProgress = progress
            if !progress.summary.isEmpty {
                self?.statusMessage = progress.summary
            }
        }

        copyTask = Task { [weak self] in
            let result = await executor.copy(plan: copyPlan)
            guard let self else { return }
            copyResults = result.mediaItems
            supportFileResults = result.supportItems
            lastOutputDirectory = copyPlan.destinationRoot
            let baseMessage = copyProgress.summary.isEmpty ? "Download complete" : copyProgress.summary
            var finalMessage = baseMessage
            if !Task.isCancelled && openDestinationWhenComplete {
                openOutputDirectory()
            }
            if !Task.isCancelled && ejectSourceWhenComplete {
                let ejectMessage = await ejectCopiedSource(copyPlan.sourceRoot, failedCount: result.failedCount)
                if !ejectMessage.isEmpty {
                    finalMessage = "\(baseMessage). \(ejectMessage)"
                }
            }
            statusMessage = finalMessage
            copyTask = nil
        }
    }

    func cancelCopy() {
        guard copyProgress.isRunning else { return }
        statusMessage = "Stopping download..."
        copyTask?.cancel()
    }

    func removeSelectedQueueItems() {
        guard !selectedQueueItemIDs.isEmpty else { return }
        excludedQueueClipIDs.formUnion(selectedQueueItemIDs)
        selectedQueueItemIDs = []
        rebuildPlan()
    }

    func restoreQueuedFiles() {
        excludedQueueClipIDs = []
        selectedQueueItemIDs = []
        rebuildPlan()
    }

    func openOutputDirectory() {
        if let lastOutputDirectory {
            NSWorkspace.shared.open(lastOutputDirectory)
        } else if let destinationURL {
            NSWorkspace.shared.open(destinationURL)
        }
    }

    private func ejectCopiedSource(_ sourceURL: URL, failedCount: Int) async -> String {
        guard failedCount == 0 else {
            return "Auto-eject skipped because \(failedCount) files failed"
        }

        let volumeURL = sourceVolumeURL(for: sourceURL)
        guard volumeURL.path.hasPrefix("/Volumes/") else {
            return "Auto-eject skipped because the source is not a mounted card volume"
        }

        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volumeURL)
            return "Ejected \(volumeURL.lastPathComponent)"
        } catch {
            return "Auto-eject failed: \(error.localizedDescription)"
        }
    }

    private func sourceVolumeURL(for sourceURL: URL) -> URL {
        let components = sourceURL.standardizedFileURL.pathComponents
        guard components.count >= 3, components[1] == "Volumes" else {
            return sourceURL
        }
        return URL(fileURLWithPath: "/Volumes/\(components[2])", isDirectory: true)
    }

    func submitFeedback(
        kind: FeedbackKind,
        message: String,
        contact: String,
        includeScan: Bool,
        training: CardTrainingDetails? = nil,
        successMessage: String = "Feedback submitted successfully.",
        onSuccess: (@MainActor () -> Void)? = nil
    ) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            feedbackMessage = "Add a short note before submitting"
            return
        }

        isSubmittingFeedback = true
        feedbackMessage = "Submitting feedback..."

        let submission = FeedbackSubmission(
            kind: kind,
            message: trimmedMessage,
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
            appVersion: appVersionString(),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            training: training,
            scan: includeScan ? makeFeedbackScanSnapshot() : nil
        )

        Task { [weak self, feedbackService] in
            do {
                _ = try await feedbackService.submit(submission)
                self?.feedbackMessage = successMessage
                self?.statusMessage = successMessage
                onSuccess?()
            } catch {
                self?.feedbackMessage = "Feedback failed: \(error.localizedDescription)"
            }
            self?.isSubmittingFeedback = false
        }
    }

    func makeFeedbackScanSnapshot() -> FeedbackScanSnapshot? {
        guard scanSummary.hasScan else { return nil }

        let sourceRoot = selectedSource?.url
        let safeFiles = lastScannedFiles.filter { isSafeTrainingSample($0, sourceRoot: sourceRoot) }
        let safeSamples = safeFiles
            .prefix(80)
            .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }

        let extensionCounts = Dictionary(grouping: safeFiles) { url in
            let ext = url.pathExtension.lowercased()
            return ext.isEmpty ? "[none]" : ext
        }
            .mapValues(\.count)
        let mediaExtensionCounts = Dictionary(grouping: safeFiles.filter(isMediaLikeFile)) { url in
            let ext = url.pathExtension.lowercased()
            return ext.isEmpty ? "[none]" : ext
        }
            .mapValues(\.count)
        let unrecognizedExtensionCounts = Dictionary(grouping: safeFiles.filter { fileURL in
            !isMediaLikeFile(fileURL) && !isPotentialSettingsFile(fileURL, sourceRoot: sourceRoot)
        }) { url in
            let ext = url.pathExtension.lowercased()
            return ext.isEmpty ? "[none]" : ext
        }
            .mapValues(\.count)
        let timestampSourceCounts = Dictionary(grouping: eligibleClips) { clip in
            clip.timestampSource.rawValue
        }
            .mapValues(\.count)
        let inferredParkingPatternCounts = Dictionary(grouping: eligibleClips.compactMap(\.inferredParkingPattern)) { pattern in
            pattern.rawValue
        }
            .mapValues(\.count)

        let rootFolders = Set(safeFiles.compactMap { url -> String? in
            let relativePath = sanitizedRelativePath(for: url, sourceRoot: sourceRoot)
            return relativePath.split(separator: "/").first.map(String.init)
        })
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        let folderSamples = Set(safeFiles.compactMap { url -> String? in
            let relativePath = sanitizedRelativePath(for: url, sourceRoot: sourceRoot)
            guard let slashIndex = relativePath.lastIndex(of: "/") else { return nil }
            return String(relativePath[..<slashIndex])
        })
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        .prefix(80)

        let filenameSamples = safeFiles
            .map(\.lastPathComponent)
            .uniquedPreservingOrder()
            .prefix(80)

        let supportFileSamples = safeFiles
            .filter { !isMediaLikeFile($0) }
            .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }
            .uniquedPreservingOrder()
            .prefix(40)
        let ignoredSupportFileSamples = safeFiles
            .filter { fileURL in
                !isMediaLikeFile(fileURL) || isPotentialSettingsFile(fileURL, sourceRoot: sourceRoot)
            }
            .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }
            .uniquedPreservingOrder()
            .prefix(60)
        let videoSpecSamples = makeVideoSpecSamples(
            from: representativeVideoFiles(safeFiles, sourceRoot: sourceRoot),
            sourceRoot: sourceRoot
        )
        let settingSnapshots = safeFiles
            .filter { isPotentialSettingsFile($0, sourceRoot: sourceRoot) }
            .prefix(20)
            .compactMap { makeSettingSnapshot(for: $0, sourceRoot: sourceRoot) }

        let candidates = detectionCandidates.prefix(8).map { candidate in
            FeedbackCandidateSnapshot(
                profileID: candidate.profile.id,
                profileName: candidate.profile.displayName,
                score: candidate.score,
                confidence: candidate.confidence.rawValue,
                evidence: candidate.evidence.map(sanitizeEvidence)
            )
        }

        return FeedbackScanSnapshot(
            volumeName: selectedSource?.name ?? "Unknown",
            selectedProfileID: selectedProfile?.id,
            selectedProfileName: selectedProfile?.displayName,
            scannedFiles: scanSummary.scannedFiles,
            copyableItems: scanSummary.copyableItems,
            excludedItems: scanSummary.excludedItems,
            categoryCounts: scanSummary.categoryCounts,
            modeCounts: scanSummary.modeCounts,
            extensionCounts: extensionCounts,
            mediaExtensionCounts: mediaExtensionCounts,
            unrecognizedExtensionCounts: unrecognizedExtensionCounts,
            timestampSourceCounts: timestampSourceCounts,
            suspiciousTimestampItems: eligibleClips.filter(\.hasSuspiciousTimestamp).count,
            inferredParkingPatternCounts: inferredParkingPatternCounts,
            sampleRelativePaths: Array(safeSamples),
            rootFolders: Array(rootFolders.prefix(40)),
            folderSamples: Array(folderSamples),
            folderSummaries: makeFolderSummaries(from: safeFiles, sourceRoot: sourceRoot),
            filenameSamples: Array(filenameSamples),
            supportFileSamples: Array(supportFileSamples),
            ignoredSupportFileSamples: Array(ignoredSupportFileSamples),
            videoSpecSamples: videoSpecSamples,
            settingSnapshots: Array(settingSnapshots),
            candidates: Array(candidates),
            scanDiagnostics: Array(lastScanDiagnostics.prefix(40))
        )
    }

    private func sanitizedRelativePath(for clip: ClipItem, sourceRoot: URL?) -> String {
        if let sourceRoot {
            return clip.sourceURL.relativePath(from: sourceRoot)
        }
        return clip.relativePath
    }

    private func sanitizedRelativePath(for fileURL: URL, sourceRoot: URL?) -> String {
        if let sourceRoot {
            return fileURL.relativePath(from: sourceRoot)
        }
        return fileURL.lastPathComponent
    }

    private func isSafeTrainingSample(_ fileURL: URL, sourceRoot: URL?) -> Bool {
        let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
        let lowerPath = relativePath.lowercased()
        let filename = fileURL.lastPathComponent
        if filename.hasPrefix("._") { return false }
        if filename.hasPrefix("."), filename != ".boot.log" { return false }
        if lowerPath.contains("device.uid") { return false }
        if lowerPath.contains("thumbnail") { return false }
        if lowerPath.contains("/gps/") || lowerPath.hasPrefix("gps/") { return false }
        if containsSensitiveTrainingPath(lowerPath) { return false }
        if ["gpx", "nmea"].contains(fileURL.pathExtension.lowercased()) { return false }
        return true
    }

    private func containsSensitiveTrainingPath(_ lowerPath: String) -> Bool {
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
        return sensitiveFragments.contains { lowerPath.contains($0) }
    }

    private func isMediaLikeFile(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ClipItem.videoExtensions.contains(ext) ||
            ClipItem.photoExtensions.contains(ext) ||
            ClipItem.gpsExtensions.contains(ext)
    }

    private func isPotentialSettingsFile(_ fileURL: URL, sourceRoot: URL?) -> Bool {
        let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
        let lowerPath = relativePath.lowercased()
        let ext = fileURL.pathExtension.lowercased()

        guard !isMediaLikeFile(fileURL), !["gpx", "nmea", "exe"].contains(ext) else {
            return false
        }

        if lowerPath.contains("config") ||
            lowerPath.contains("setting") ||
            lowerPath.contains("settings") ||
            lowerPath.hasSuffix(".boot.log") ||
            lowerPath.hasSuffix("/boot.log") {
            return true
        }

        if ext == "bin" {
            return false
        }

        return ["ini", "cfg", "conf", "json", "txt", "log"].contains(ext)
    }

    private func makeFolderSummaries(from files: [URL], sourceRoot: URL?) -> [FeedbackFolderSummary] {
        var grouped: [String: [URL]] = [:]
        for fileURL in files {
            let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
            let folderPath: String
            if let slashIndex = relativePath.lastIndex(of: "/") {
                folderPath = String(relativePath[..<slashIndex])
            } else {
                folderPath = "."
            }
            grouped[folderPath, default: []].append(fileURL)
        }

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(80)
            .map { folderPath in
                let folderFiles = grouped[folderPath, default: []]
                let mediaFiles = folderFiles.filter(isMediaLikeFile)
                let extensionCounts = Dictionary(grouping: folderFiles) { fileURL in
                    let ext = fileURL.pathExtension.lowercased()
                    return ext.isEmpty ? "[none]" : ext
                }
                .mapValues(\.count)

                return FeedbackFolderSummary(
                    path: folderPath,
                    fileCount: folderFiles.count,
                    mediaFileCount: mediaFiles.count,
                    supportFileCount: folderFiles.count - mediaFiles.count,
                    extensionCounts: extensionCounts
                )
            }
    }

    private func representativeVideoFiles(_ files: [URL], sourceRoot: URL?) -> [URL] {
        let videoFiles = files.filter { ClipItem.videoExtensions.contains($0.pathExtension.lowercased()) }
        guard !videoFiles.isEmpty else { return [] }

        var selected: [URL] = []
        var seenKeys: Set<String> = []
        for fileURL in videoFiles {
            let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
            let folder = relativePath.split(separator: "/").dropLast().joined(separator: "/")
            let ext = fileURL.pathExtension.lowercased()
            let key = "\(folder)|\(ext)"
            guard seenKeys.insert(key).inserted else { continue }
            selected.append(fileURL)
            if selected.count >= 16 { break }
        }

        if selected.count < 8 {
            for fileURL in videoFiles where !selected.contains(fileURL) {
                selected.append(fileURL)
                if selected.count >= 16 { break }
            }
        }

        return selected
    }

    private func makeVideoSpecSamples(from files: [URL], sourceRoot: URL?) -> [FeedbackVideoSpecSample] {
        files.compactMap { fileURL in
            let asset = AVURLAsset(url: fileURL)
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                return nil
            }

            let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            let width = Int(abs(naturalSize.width).rounded())
            let height = Int(abs(naturalSize.height).rounded())
            let frameRate = videoTrack.nominalFrameRate > 0 ? Double(videoTrack.nominalFrameRate) : nil
            let bitrate = videoTrack.estimatedDataRate > 0 ? Int(videoTrack.estimatedDataRate.rounded()) : nil
            let duration = asset.duration.seconds.isFinite && asset.duration.seconds > 0 ? asset.duration.seconds : nil

            return FeedbackVideoSpecSample(
                relativePath: sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot),
                extensionLowercased: fileURL.pathExtension.lowercased(),
                codec: codecName(for: videoTrack),
                width: width > 0 ? width : nil,
                height: height > 0 ? height : nil,
                nominalFrameRate: frameRate,
                estimatedBitrate: bitrate,
                durationSeconds: duration
            )
        }
    }

    private func codecName(for track: AVAssetTrack) -> String? {
        guard let rawDescription = track.formatDescriptions.first else { return nil }
        let description = rawDescription as! CMFormatDescription
        let subtype = CMFormatDescriptionGetMediaSubType(description)
        let bytes = [
            UInt8((subtype >> 24) & 0xff),
            UInt8((subtype >> 16) & 0xff),
            UInt8((subtype >> 8) & 0xff),
            UInt8(subtype & 0xff)
        ]
        let fourCC = String(bytes: bytes, encoding: .macOSRoman) ?? ""
        switch fourCC.lowercased() {
        case "avc1", "h264":
            return "H.264"
        case "hvc1", "hev1":
            return "H.265 / HEVC"
        default:
            return fourCC.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fourCC
        }
    }

    private func makeSettingSnapshot(for fileURL: URL, sourceRoot: URL?) -> FeedbackSettingSnapshot? {
        guard let text = readSmallTextFile(fileURL) else { return nil }
        let parsedSettings = extractSettings(from: text)
        let safePairs = parsedSettings
            .filter { isUsefulSettingKey($0.key) && !isSensitiveSetting(key: $0.key, value: $0.value) }
            .prefix(40)

        var safeValues: [String: String] = [:]
        for pair in safePairs.prefix(20) {
            safeValues[pair.key] = sanitizedSettingValue(pair.value)
        }

        for pair in extractSafeOperationalSettings(from: text) where safeValues.count < 20 {
            safeValues[pair.key] = sanitizedSettingValue(pair.value)
        }

        if safeValues.isEmpty {
            let fragments = extractSafeModelFragments(from: text)
            for (index, fragment) in fragments.prefix(8).enumerated() {
                safeValues["modelEvidence\(index + 1)"] = sanitizedSettingValue(fragment)
            }
        }

        if safeValues.isEmpty {
            let fragments = extractSafeOperationalFragments(from: text)
            for (index, fragment) in fragments.prefix(8).enumerated() {
                safeValues["operationEvidence\(index + 1)"] = sanitizedSettingValue(fragment)
            }
        }

        guard !safeValues.isEmpty else { return nil }

        return FeedbackSettingSnapshot(
            relativePath: sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot),
            keys: Array(safeValues.keys).sorted(),
            safeValues: safeValues
        )
    }

    private func readSmallTextFile(_ fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe), data.count <= 64 * 1024 else {
            return nil
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .ascii) {
            return text
        }
        return nil
    }

    private func extractSettings(from text: String) -> [(key: String, value: String)] {
        text.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else {
                return nil
            }

            let separators: [Character] = ["=", ":"]
            guard let separatorIndex = trimmed.firstIndex(where: { separators.contains($0) }) else {
                return nil
            }

            let rawKey = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawKey.isEmpty, !rawValue.isEmpty, rawKey.count <= 80, rawValue.count <= 160 else {
                return nil
            }

            return (rawKey, rawValue)
        }
        .uniquedByKey()
    }

    private func extractSafeModelFragments(from text: String) -> [String] {
        let usefulFragments = [
            "model",
            "firmware",
            "version",
            "fw",
            "qhd",
            "uhd",
            "fhd",
            "4k",
            "2k",
            "1ch",
            "2ch",
            "3ch",
            "4ch",
            "infinite",
            "vueroid",
            "thinkware",
            "viofo",
            "blackvue",
            "vantrue",
            "rove",
            "70mai"
        ]

        return printableRuns(from: text)
            .filter { fragment in
                let lower = fragment.lowercased()
                return usefulFragments.contains { lower.contains($0) } &&
                    !isSensitiveSetting(key: "modelEvidence", value: fragment)
            }
            .uniquedPreservingOrder()
    }

    private func extractSafeOperationalSettings(from text: String) -> [(key: String, value: String)] {
        var settings: [(key: String, value: String)] = []
        let fragments = printableRuns(from: text)

        if let channelCount = fragments.compactMap({ fragment -> String? in
            guard let range = fragment.range(
                of: #"(?i)\b([1-4])CH\b"#,
                options: .regularExpression
            ) else {
                return nil
            }
            return String(fragment[range]).uppercased()
        }).first {
            settings.append(("channelCountEvidence", channelCount))
        }

        if fragments.contains(where: { $0.range(of: #"(?i)\bDRIVE TO PARK\b"#, options: .regularExpression) != nil }) {
            settings.append(("parkingStateEvidence", "DRIVE TO PARK"))
        }

        if fragments.contains(where: { $0.range(of: #"(?i)\bPARK\b"#, options: .regularExpression) != nil }) {
            settings.append(("parkingEvidence", "PARK"))
        }

        return settings.filter { !isSensitiveSetting(key: $0.key, value: $0.value) }
    }

    private func extractSafeOperationalFragments(from text: String) -> [String] {
        let usefulFragments = [
            "parking",
            "drive to park",
            "park",
            "resolution",
            "quality",
            "bitrate",
            "bit rate",
            "fps",
            "frame",
            "codec",
            "encoding",
            "hdr",
            "wdr",
            "loop",
            "audio",
            "motion",
            "impact",
            "event",
            "timelapse",
            "time lapse",
            "low bitrate",
            "record",
            "recording",
            "video",
            "1ch",
            "2ch",
            "3ch",
            "4ch",
            "qhd",
            "uhd",
            "fhd",
            "4k",
            "2k",
            "h264",
            "h.264",
            "h265",
            "h.265",
            "hevc"
        ]

        return printableRuns(from: text)
            .filter { fragment in
                let lower = fragment.lowercased()
                return usefulFragments.contains { lower.contains($0) } &&
                    !isSensitiveSetting(key: "operationEvidence", value: fragment)
            }
            .uniquedPreservingOrder()
    }

    private func printableRuns(from text: String) -> [String] {
        text
            .unicodeScalars
            .reduce(into: [String]()) { runs, scalar in
                let isPrintableASCII = scalar.value >= 32 && scalar.value <= 126
                if isPrintableASCII {
                    if runs.isEmpty {
                        runs.append(String(scalar))
                    } else {
                        runs[runs.count - 1].append(String(scalar))
                    }
                } else if runs.last?.isEmpty == false {
                    runs.append("")
                }
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 && $0.count <= 120 }
    }

    private func isUsefulSettingKey(_ key: String) -> Bool {
        let lowerKey = key.lowercased()
        let usefulFragments = [
            "model",
            "firmware",
            "version",
            "fw",
            "camera",
            "video",
            "record",
            "recording",
            "resolution",
            "quality",
            "bitrate",
            "bit rate",
            "parking",
            "motion",
            "impact",
            "timelapse",
            "time lapse",
            "low bitrate",
            "fps",
            "frame",
            "codec",
            "encoding",
            "hdr",
            "wdr",
            "loop",
            "audio",
            "microphone",
            "gps",
            "speed",
            "gsensor",
            "g-sensor",
            "timezone",
            "time zone",
            "frequency",
            "exposure",
            "ev",
            "channel"
        ]
        return usefulFragments.contains { lowerKey.contains($0) }
    }

    private func isSensitiveSetting(key: String, value: String) -> Bool {
        let combined = "\(key) \(value)".lowercased()
        let sensitiveFragments = [
            "password",
            "passwd",
            "pwd",
            "ssid",
            "wifi",
            "wi-fi",
            "cloud",
            "account",
            "email",
            "token",
            "secret",
            "serial",
            "imei",
            "uuid",
            "uid",
            "device id",
            "deviceid",
            "mac address",
            "bluetooth",
            "latitude",
            "longitude",
            "coordinate",
            "license",
            "plate"
        ]
        return sensitiveFragments.contains { combined.contains($0) } ||
            combined.range(of: #"-?\d{1,3}\.\d{4,}"#, options: .regularExpression) != nil
    }

    private func sanitizedSettingValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' ").union(.newlines))
            .prefix(80)
            .description
    }

    private func sanitizeEvidence(_ evidence: String) -> String {
        guard let selectedSource else { return evidence }
        return evidence.replacingOccurrences(of: selectedSource.url.path, with: "[source]")
    }

    private func appVersionString() -> String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [version, build].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " ")
    }
}

private extension ClipItem {
    var filenameStemWithoutChannelHint: String {
        var stem = URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()

        for suffix in ["PF", "PI", "PR", "PT", "NF", "NI", "NR", "NT", "EF", "EI", "ER", "ET", "MF", "MI", "MR", "MT", "F", "I", "R", "T", "A", "B", "C", "D"] {
            guard stem.hasSuffix(suffix) else { continue }
            let suffixStart = stem.index(stem.endIndex, offsetBy: -suffix.count)
            if suffixStart == stem.startIndex {
                continue
            }
            let previousCharacter = stem[stem.index(before: suffixStart)]
            if previousCharacter.isNumber || previousCharacter == "_" || previousCharacter == "-" || previousCharacter == " " {
                stem.removeSubrange(suffixStart..<stem.endIndex)
                break
            }
        }

        return stem
    }
}

private extension Array where Element == (key: String, value: String) {
    func uniquedByKey() -> [(key: String, value: String)] {
        var seen: Set<String> = []
        var result: [(key: String, value: String)] = []
        for pair in self {
            let normalized = pair.key.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            result.append(pair)
        }
        return result
    }
}
