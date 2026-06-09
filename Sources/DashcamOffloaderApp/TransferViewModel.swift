@preconcurrency import AppKit
import Foundation

@MainActor
final class TransferViewModel: ObservableObject {
    @Published var profiles: [DashcamProfile] = []
    @Published var mountedSources: [MountedSource] = []
    @Published var selectedSource: MountedSource?
    @Published var destinationURL: URL?
    @Published var detectionCandidates: [DetectionCandidate] = []
    @Published var identifiedCamera: IdentifiedCamera?
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

    private let scanner = CardScanner()
    private let planner = CopyPlanner()
    private let feedbackService = FeedbackService.production
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    private var lastScannedFiles: [URL] = []
    private var lastScanDiagnostics: [ScanDiagnosticEntry] = []

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
        Array(Set(clips.filter { $0.excludedReason == nil }.map(\.mode))).sorted()
    }

    var availableChannels: [String] {
        Array(Set(clips.filter { $0.excludedReason == nil }.map(\.channel))).sorted()
    }

    var eligibleClips: [ClipItem] {
        clips.filter { $0.excludedReason == nil }
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

    func refreshSources() {
        let previousSource = selectedSource
        mountedSources = scanner.discoverMountedSources(showAllVolumes: showAllVolumes)
        if let previousSource, mountedSources.contains(previousSource) {
            selectedSource = previousSource
        } else {
            selectedSource = mountedSources.first
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
            let source = scanner.mountedSource(forUserSelectedURL: url)
            upsertMountedSource(source)
            selectSource(source, scanImmediately: true)
        }
    }

    func selectSource(_ source: MountedSource, scanImmediately: Bool = true) {
        selectedSource = source
        detectionCandidates = []
        identifiedCamera = nil
        selectedProfile = nil
        clips = []
        lastScannedFiles = []
        lastScanDiagnostics = []
        copyPlan = nil
        copyResults = []
        supportFileResults = []
        scanSummary = ScanSummary(sourcePath: source.url.path)
        statusMessage = "Selected \(source.name)"

        if scanImmediately {
            scanSelectedSource()
        }
    }

    private func upsertMountedSource(_ source: MountedSource) {
        if let existingIndex = mountedSources.firstIndex(where: { $0.id == source.id }) {
            mountedSources[existingIndex] = source
        } else {
            mountedSources.insert(source, at: 0)
        }
    }

    func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose output directory"
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
        identifiedCamera = nil
        selectedProfile = nil
        scanSummary = ScanSummary(sourcePath: selectedSource.url.path)

        Task { [weak self, profiles, selectedSource] in
            guard let self else { return }
            do {
                let scanResult = try await Task.detached {
                    try CardScanner().scanWithOSD(sourceURL: selectedSource.url, profiles: profiles)
                }.value
                self.detectionCandidates = scanResult.candidates
                self.identifiedCamera = scanResult.identifiedCamera
                self.selectedProfile = scanResult.selectedProfile
                self.lastScannedFiles = scanResult.allFiles
                self.lastScanDiagnostics = scanResult.diagnostics
                self.clips = scanResult.clips
                self.resetFiltersForCurrentClips()
                self.scanSummary = ScanSummary(
                    sourcePath: selectedSource.url.path,
                    scannedFiles: scanResult.allFiles.count,
                    copyableItems: self.eligibleClips.count,
                    excludedItems: scanResult.clips.filter { $0.excludedReason != nil }.count,
                    samplePaths: [],
                    categoryCounts: Dictionary(grouping: self.eligibleClips, by: \.outputCategory)
                        .mapValues(\.count),
                    modeCounts: Dictionary(grouping: self.eligibleClips, by: \.displayMode)
                        .mapValues(\.count),
                    identifiedCamera: scanResult.identifiedCamera
                )
                if let identified = scanResult.identifiedCamera, !identified.isSupported {
                    self.statusMessage = "Identified unsupported dashcam: \(identified.displayName). Submit a learning package to add it."
                } else {
                    self.statusMessage = "Scanned \(selectedSource.url.path). Found \(self.eligibleClips.count) copyable items"
                }
                self.rebuildPlan()
            } catch {
                self.statusMessage = "Scan failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    func selectProfile(_ profile: DashcamProfile) {
        identifiedCamera = nil
        selectedProfile = profile
        guard let selectedSource else { return }
        clips = scanner.classify(files: lastScannedFiles, sourceURL: selectedSource.url, profile: profile)
        resetFiltersForCurrentClips()
        rebuildPlan()
    }

    func resetFiltersForCurrentClips() {
        filters.selectedModes = Set(eligibleClips.filter { !$0.isGPS && !$0.isPhoto }.map(\.mode))
        filters.selectedChannels = Set(eligibleClips.filter { !$0.isGPS && !$0.isPhoto }.map(\.channel))
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

        copyPlan = planner.makePlan(
            sourceRoot: selectedSource.url,
            destinationRoot: destinationURL ?? Self.previewDestinationRoot,
            profile: selectedProfile,
            clips: clips,
            filters: filters,
            namingOptions: outputNamingOptions
        )
    }

    func setVideoFilenameSuffix(_ value: String) {
        outputNamingOptions.videoFilenameSuffix = value
        rebuildPlan()
    }

    func startCopy() {
        guard destinationURL != nil else {
            statusMessage = "Choose an output directory before copying"
            return
        }
        guard let copyPlan, !copyPlan.items.isEmpty else {
            statusMessage = "Nothing selected to copy"
            return
        }

        statusMessage = "Copying..."
        copyResults = []
        supportFileResults = []
        let executor = CopyExecutor { [weak self] progress in
            self?.copyProgress = progress
            if !progress.summary.isEmpty {
                self?.statusMessage = progress.summary
            }
        }

        Task {
            let result = await executor.copy(plan: copyPlan)
            copyResults = result.mediaItems
            supportFileResults = result.supportItems
            lastOutputDirectory = copyPlan.destinationRoot
            let baseMessage = copyProgress.summary.isEmpty ? "Copy complete" : copyProgress.summary
            var finalMessage = baseMessage
            if openDestinationWhenComplete {
                openOutputDirectory()
            }
            if ejectSourceWhenComplete {
                let ejectMessage = await ejectCopiedSource(copyPlan.sourceRoot, failedCount: result.failedCount)
                if !ejectMessage.isEmpty {
                    finalMessage = "\(baseMessage). \(ejectMessage)"
                }
            }
            statusMessage = finalMessage
        }
    }

    private static let previewDestinationRoot = URL(fileURLWithPath: "/Dashcam Offloader Preview", isDirectory: true)

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
        training: CardTrainingDetails? = nil
    ) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            feedbackMessage = "Add a short note before submitting"
            return
        }

        if kind == .training {
            guard training != nil, includeScan, scanSummary.hasScan, makeFeedbackScanSnapshot() != nil else {
                feedbackMessage = "Scan a card first, then use Learn Card to submit dashcam training data."
                return
            }
        }

        isSubmittingFeedback = true
        feedbackMessage = "Submitting feedback..."

        let scanSnapshot = includeScan ? makeFeedbackScanSnapshot() : nil

        let submission = FeedbackSubmission(
            kind: kind,
            message: trimmedMessage,
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
            appVersion: appVersionString(),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            training: training,
            scan: scanSnapshot
        )

        Task { [weak self, feedbackService] in
            do {
                let id = try await feedbackService.submit(submission)
                self?.feedbackMessage = "Feedback submitted: \(id)"
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
            identifiedCamera: identifiedCamera,
            selectedProfileID: selectedProfile?.id,
            selectedProfileName: selectedProfile?.displayName,
            scannedFiles: scanSummary.scannedFiles,
            copyableItems: scanSummary.copyableItems,
            excludedItems: scanSummary.excludedItems,
            categoryCounts: scanSummary.categoryCounts,
            modeCounts: scanSummary.modeCounts,
            extensionCounts: extensionCounts,
            sampleRelativePaths: Array(safeSamples),
            rootFolders: Array(rootFolders.prefix(40)),
            folderSamples: Array(folderSamples),
            filenameSamples: Array(filenameSamples),
            supportFileSamples: Array(supportFileSamples),
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
        if filename.hasPrefix("._") || filename.hasPrefix(".") { return false }
        if lowerPath.contains("device.uid") { return false }
        if lowerPath.contains("thumbnail") { return false }
        if lowerPath.contains("/gps/") || lowerPath.hasPrefix("gps/") { return false }
        if ["gpx", "nmea"].contains(fileURL.pathExtension.lowercased()) { return false }
        return true
    }

    private func isMediaLikeFile(_ fileURL: URL) -> Bool {
        ["mp4", "mov", "jpg", "jpeg", "dat"].contains(fileURL.pathExtension.lowercased())
    }

    private func isPotentialSettingsFile(_ fileURL: URL, sourceRoot: URL?) -> Bool {
        let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
        let lowerPath = relativePath.lowercased()
        let ext = fileURL.pathExtension.lowercased()

        guard !isMediaLikeFile(fileURL), !["gpx", "nmea", "bin", "exe"].contains(ext) else {
            return false
        }

        if lowerPath.contains("config") ||
            lowerPath.contains("setting") ||
            lowerPath.contains("settings") ||
            lowerPath.hasSuffix(".boot.log") ||
            lowerPath.hasSuffix("/boot.log") {
            return true
        }

        return ["ini", "cfg", "conf", "json", "txt", "log"].contains(ext)
    }

    private func makeSettingSnapshot(for fileURL: URL, sourceRoot: URL?) -> FeedbackSettingSnapshot? {
        guard let text = readSmallTextFile(fileURL) else { return nil }
        let parsedSettings = extractSettings(from: text)
        guard !parsedSettings.isEmpty else { return nil }

        let safePairs = parsedSettings
            .filter { isUsefulSettingKey($0.key) && !isSensitiveSetting(key: $0.key, value: $0.value) }
            .prefix(40)

        guard !safePairs.isEmpty else { return nil }

        var safeValues: [String: String] = [:]
        for pair in safePairs.prefix(20) {
            safeValues[pair.key] = sanitizedSettingValue(pair.value)
        }

        return FeedbackSettingSnapshot(
            relativePath: sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot),
            keys: safePairs.map(\.key),
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

    private func isUsefulSettingKey(_ key: String) -> Bool {
        let lowerKey = key.lowercased()
        let usefulFragments = [
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
