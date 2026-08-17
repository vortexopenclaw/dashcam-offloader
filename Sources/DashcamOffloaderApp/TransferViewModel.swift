@preconcurrency import AppKit
@preconcurrency import AVFoundation
import Foundation

@MainActor
final class TransferViewModel: ObservableObject {
    @Published var importMode: ImportMode = .dashcamFootage
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
    @Published var selectedQueueItemIDs: Set<CopyPlanItem.ID> = []
    @Published var automaticUpdateChecksEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticUpdateChecksEnabled, forKey: Self.automaticUpdateChecksKey)
        }
    }
    @Published var updateStatusMessage = ""
    @Published var isCheckingForUpdates = false
    @Published var availableUpdate: AppUpdateManifest?
    @Published private(set) var hiddenSourceVolumePaths: Set<String> = []

    private let scanner = CardScanner()
    private let planner = CopyPlanner()
    private let feedbackService = FeedbackService.production
    private let updateService = UpdateService.production
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    private var didStartInitialSourceDiscovery = false
    private var didStartInitialUpdateCheck = false
    private var canRunAutomaticSourceDiscovery = false
    private var lastScannedFiles: [URL] = []
    private var lastScanDiagnostics: [ScanDiagnosticEntry] = []
    private var lastEffectiveScanSourceURL: URL?
    private var excludedQueueClipIDs: Set<ClipItem.ID> = []
    private var copyTask: Task<Void, Never>?
    private var customSourceNames: [MountedSource.ID: String] = [:]
    private var scanGeneration = 0
    private var profileSelectionRevision = 0
    private static let automaticUpdateChecksKey = "DashcamOffloaderAutomaticUpdateChecksEnabled"
    private static let hiddenSourceVolumePathsKey = "DashcamOffloaderHiddenSourceVolumePaths"
    nonisolated private static let lastDownloadDestinationPathKey = "DashcamOffloaderLastDownloadDestinationPath"

    init() {
        if UserDefaults.standard.object(forKey: Self.automaticUpdateChecksKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.automaticUpdateChecksKey)
        }
        automaticUpdateChecksEnabled = UserDefaults.standard.bool(forKey: Self.automaticUpdateChecksKey)
        hiddenSourceVolumePaths = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenSourceVolumePathsKey) ?? [])
        destinationURL = Self.restoredLastDownloadDestination()
        loadProfiles()
        startVolumeObservation()
        statusMessage = "Ready. Looking for mounted cards..."
    }

    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        for token in workspaceNotificationTokens {
            notificationCenter.removeObserver(token)
        }
    }

    var availableModes: [String] {
        Array(Set(footageClips.map(\.mode))).sorted { lhs, rhs in
            let preferred = [
                "regular_recording",
                "continuous",
                "looping",
                "driving_event",
                "time_lapse",
                "time_warp",
                "time_lapse_or_timewarp",
                "parking",
                "parking_continuous_low_bitrate",
                "parking_timelapse",
                "parking_motion_detection",
                "parking_impact_detection",
                "parking_motion_or_impact",
                "parking_event"
            ]
            let lhsIndex = preferred.firstIndex(of: lhs) ?? preferred.count
            let rhsIndex = preferred.firstIndex(of: rhs) ?? preferred.count
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    var availableChannels: [String] {
        Array(Set(footageClips.map(\.channel))).sorted()
    }

    var shouldShowChannelFilter: Bool {
        guard !availableChannels.isEmpty else { return false }
        return !isSingleLensNonDashcamProfile
    }

    private var isSingleLensNonDashcamProfile: Bool {
        guard let selectedProfile else { return false }
        let nonDashcamTypes = ["action_camera", "drone", "mirrorless_camera", "camera"]
        guard nonDashcamTypes.contains((selectedProfile.cameraType ?? "").lowercased()) else {
            return false
        }
        let normalizedChannels = Set(eligibleClips.filter { !$0.isGPS }.map { $0.channel.lowercased() })
        return normalizedChannels.isEmpty || normalizedChannels.isSubset(of: ["unknown", "primary", "front", "360_primary"])
    }

    var eligibleClips: [ClipItem] {
        clips.filter { $0.excludedReason == nil }
    }

    var footageClips: [ClipItem] {
        eligibleClips.filter { !$0.isGPS && !$0.isPhoto }
    }

    var hasVideoItems: Bool {
        !footageClips.isEmpty
    }

    var hasPhotoItems: Bool {
        eligibleClips.contains { $0.isPhoto }
    }

    var hasGPSItems: Bool {
        eligibleClips.contains { $0.isGPS }
    }

    var areVideosIncluded: Bool {
        !filters.selectedModes.isEmpty && !filters.selectedChannels.isEmpty
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

    var inferredLearningCameraIdentity: (manufacturer: String, model: String)? {
        if let selectedProfile, selectedProfile.id != DashcamProfile.genericNewDashcam.id {
            return (selectedProfile.manufacturer, selectedProfile.model)
        }

        if let selectedSource,
           let catalogMatch = KnownDashcamCatalog.exactVolumeLabelMatch(selectedSource.name) {
            return (catalogMatch.manufacturer, catalogMatch.model)
        }

        if let volumeMatchedCandidate = detectionCandidates.first(where: { candidate in
            candidate.confidence != .low &&
                candidate.profile.id != DashcamProfile.genericNewDashcam.id &&
                candidate.evidence.contains { $0.hasPrefix("volume label ") }
        }) {
            return (volumeMatchedCandidate.profile.manufacturer, volumeMatchedCandidate.profile.model)
        }

        return nil
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

    var cameraModelsByBrand: [(brand: String, models: [CameraModelChoice])] {
        var grouped: [String: [String: CameraModelChoice]] = [:]

        for profile in profiles {
            guard !KnownDashcamCatalog.isManualSelectorExcluded(
                manufacturer: profile.manufacturer,
                model: profile.model
            ) else { continue }
            let brand = profile.displayManufacturer
            let key = Self.cameraModelKey(profile.model)
            let knownModel = KnownDashcamCatalog.exactModelMatch(
                manufacturer: profile.manufacturer,
                modelText: profile.model
            )
            grouped[brand, default: [:]][key] = CameraModelChoice(
                brand: brand,
                model: profile.model,
                profile: profile,
                knownModel: knownModel,
                isCatalogOnly: false
            )
        }

        for model in KnownDashcamCatalog.models {
            guard !KnownDashcamCatalog.isManualSelectorExcluded(
                manufacturer: model.manufacturer,
                model: model.model
            ) else { continue }
            let brand = ManufacturerDisplayFormatter.displayName(for: model.manufacturer)
            let key = Self.cameraModelKey(model.model)
            if grouped[brand, default: [:]][key] == nil {
                grouped[brand, default: [:]][key] = CameraModelChoice(
                    brand: brand,
                    model: model.model,
                    profile: nil,
                    knownModel: model,
                    isCatalogOnly: true
                )
            }
        }

        if let identifiedCamera,
           !identifiedCamera.isSupported,
           KnownDashcamCatalog.exactModelMatch(
               manufacturer: identifiedCamera.manufacturer,
               modelText: identifiedCamera.model
           ) == nil {
            let brand = identifiedCamera.displayManufacturer
            let key = Self.cameraModelKey(identifiedCamera.model)
            if grouped[brand, default: [:]][key] == nil {
                grouped[brand, default: [:]][key] = CameraModelChoice(
                    brand: brand,
                    model: identifiedCamera.model,
                    profile: nil,
                    knownModel: nil,
                    isCatalogOnly: true
                )
            }
        }

        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { brand in
                (
                    brand,
                    grouped[brand, default: [:]].values.sorted {
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

        let preferred = ["front", "rear", "left", "right", "interior", "telephoto"]
        return labels.sorted { lhs, rhs in
            let lhsIndex = preferred.firstIndex(of: lhs) ?? preferred.count
            let rhsIndex = preferred.firstIndex(of: rhs) ?? preferred.count
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map(ClipItem.displayLabel(for:))
    }

    private static func cameraModelKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
        case "l", "left", "left_side", "parking_left", "pl":
            return "left"
        case "right", "right_side", "parking_right":
            return "right"
        case "t", "telephoto", "parking_telephoto", "pt":
            return "telephoto"
        case "channel_a", "channela":
            return "channel_a"
        case "channel_b", "channelb":
            return "channel_b"
        case "channel_c", "channelc":
            return "channel_c"
        case "channel_d", "channeld":
            return "channel_d"
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
            return "Front / rear / left / right"
        default:
            return ""
        }
    }

    func defaultLearningChannelDescription(for count: Int) -> String {
        defaultChannelDescription(for: count)
    }

    func refreshSources(userInitiated: Bool = false) {
        let previousSource = selectedSource
        let discoveredSources = scanner.discoverMountedSources(showAllVolumes: showAllVolumes)
            .filter { !isOutputDirectorySource($0) }
            .filter { !isHiddenSourceVolume($0) }
            .map(sourceWithCustomName)
        let discoveredIDs = Set(discoveredSources.map(\.id))
        let manualSources = mountedSources
            .filter { !isMountedVolumeSource($0) }
            .filter { !isOutputDirectorySource($0) }
            .filter { !isHiddenSourceVolume($0) }
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
            .filter { !discoveredIDs.contains($0.id) }
            .map(sourceWithCustomName)

        mountedSources = (discoveredSources + manualSources).sorted { lhs, rhs in
            if isMountedVolumeSource(lhs) != isMountedVolumeSource(rhs) {
                return isMountedVolumeSource(lhs)
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let selectedSourceBeforeRefresh = selectedSource
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
        scanSelectedSourceIfNeeded(previousSource: selectedSourceBeforeRefresh, userInitiated: userInitiated)
    }

    func startInitialSourceDiscovery() {
        guard !didStartInitialSourceDiscovery else { return }
        didStartInitialSourceDiscovery = true
        canRunAutomaticSourceDiscovery = true
        refreshSources()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.refreshSources()
        }
    }

    func startInitialUpdateCheck() {
        guard automaticUpdateChecksEnabled, !didStartInitialUpdateCheck else { return }
        didStartInitialUpdateCheck = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.checkForUpdates(userInitiated: false)
        }
    }

    func checkForUpdates(userInitiated: Bool = true) {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        if userInitiated {
            updateStatusMessage = "Checking for updates..."
        }

        Task { [weak self, updateService] in
            do {
                let manifest = try await updateService.fetchManifest()
                await MainActor.run {
                    self?.handleUpdateManifest(manifest, userInitiated: userInitiated)
                }
            } catch {
                await MainActor.run {
                    if userInitiated {
                        self?.updateStatusMessage = "Update check failed: \(error.localizedDescription)"
                    }
                    self?.isCheckingForUpdates = false
                }
            }
        }
    }

    private func handleUpdateManifest(_ manifest: AppUpdateManifest, userInitiated: Bool) {
        isCheckingForUpdates = false
        guard updateService.isUpdateAvailable(manifest) else {
            availableUpdate = nil
            if userInitiated {
                updateStatusMessage = "Dashcam Offloader is up to date."
            }
            return
        }

        availableUpdate = manifest
        updateStatusMessage = "Update available: \(manifest.displayName)"
        presentUpdatePrompt(for: manifest)
    }

    private func presentUpdatePrompt(for manifest: AppUpdateManifest) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "\(manifest.displayName) is ready to install. The app will quit, replace itself, and reopen."
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        if manifest.releaseNotesURL != nil {
            alert.addButton(withTitle: "Release Notes")
        }

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            installUpdate(manifest)
        case .alertThirdButtonReturn:
            if let releaseNotesURL = manifest.releaseNotesURL {
                NSWorkspace.shared.open(releaseNotesURL)
            }
        default:
            break
        }
    }

    func installAvailableUpdate() {
        guard let availableUpdate else {
            checkForUpdates(userInitiated: true)
            return
        }
        installUpdate(availableUpdate)
    }

    private func installUpdate(_ manifest: AppUpdateManifest) {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateStatusMessage = "Downloading \(manifest.displayName)..."

        Task { [weak self, updateService] in
            do {
                let stagedAppURL = try await updateService.downloadAndStageUpdate(manifest)
                let installMode = try await MainActor.run {
                    try updateService.installStagedUpdate(stagedAppURL)
                }
                await MainActor.run {
                    self?.isCheckingForUpdates = false
                    switch installMode {
                    case .installAndRelaunch:
                        self?.updateStatusMessage = "Installing update and relaunching..."
                        NSApplication.shared.terminate(nil)
                    case .revealDownloadedApp:
                        self?.updateStatusMessage = "Update downloaded. Install it from the Finder window."
                    }
                }
            } catch {
                await MainActor.run {
                    self?.isCheckingForUpdates = false
                    self?.updateStatusMessage = "Update failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshSourcesAfterActivation() {
        guard canRunAutomaticSourceDiscovery else {
            startInitialSourceDiscovery()
            return
        }
        refreshSources()
    }

    private func scanSelectedSourceIfNeeded(previousSource: MountedSource?, userInitiated: Bool) {
        guard !copyProgress.isRunning, !isScanning else { return }
        guard let selectedSource else { return }

        let sourceChanged = previousSource?.id != selectedSource.id
        let scanMissing = !scanSummary.hasScan ||
            scanSummary.sourcePath != selectedSource.url.path ||
            selectedProfile == nil

        guard sourceChanged || scanMissing || userInitiated else { return }
        scanSelectedSource()
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
                    self?.refreshSourcesAfterActivation()
                }
            }
        }
    }

    func setShowAllVolumes(_ value: Bool) {
        showAllVolumes = value
        refreshSources()
    }

    func setIncludeVideos(_ include: Bool) {
        if include {
            filters.selectedModes = Set(footageClips.map(\.mode)).filter { mode in
                !Self.isDeselectedByDefaultMode(mode)
            }
            filters.selectedChannels = Set(footageClips.map(\.channel))
        } else {
            filters.selectedModes = []
            filters.selectedChannels = []
        }
        rebuildPlan()
    }

    func setIncludePhotos(_ include: Bool) {
        filters.includePhotos = include
        rebuildPlan()
    }

    func setIncludeGPS(_ include: Bool) {
        filters.includeGPS = include
        rebuildPlan()
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

    func setImportMode(_ mode: ImportMode) {
        guard importMode != mode else { return }
        importMode = mode
        selectedSource = nil
        clearSourceDerivedState(for: nil)
        statusMessage = mode == .dashcamFootage
            ? "Choose a dashcam card or folder"
            : "Choose a folder containing regular camera video"
    }

    func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.title = importMode.sourcePickerTitle
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedSource?.url ?? (importMode == .dashcamFootage
            ? URL(fileURLWithPath: "/Volumes", isDirectory: true)
            : FileManager.default.homeDirectoryForCurrentUser)

        if panel.runModal() == .OK, let url = panel.url {
            let source = sourceWithCustomName(scanner.mountedSource(forUserSelectedURL: url))
            guard !isOutputDirectorySource(source) else {
                statusMessage = "Choose a different source. The download folder is not shown as a card source."
                return
            }
            restoreSourceVolume(source)
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

    func hideSourceVolume(_ source: MountedSource) {
        let volumePath = sourceVolumeURL(for: source.url).standardizedFileURL.path
        hiddenSourceVolumePaths.insert(volumePath)
        persistHiddenSourceVolumes()
        removeSourceFromList(source, status: "Hidden \(source.name) from Sources")
    }

    func restoreSourceVolume(at volumePath: String) {
        guard hiddenSourceVolumePaths.remove(volumePath) != nil else { return }
        persistHiddenSourceVolumes()
        refreshSources(userInitiated: true)
        statusMessage = "Restored \(URL(fileURLWithPath: volumePath).lastPathComponent) to Sources"
    }

    var hiddenSourceVolumeNames: [(path: String, name: String)] {
        hiddenSourceVolumePaths
            .map { (path: $0, name: URL(fileURLWithPath: $0).lastPathComponent) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func ejectSource(_ source: MountedSource) {
        guard !copyProgress.isRunning else {
            statusMessage = "Stop the download before ejecting a source"
            return
        }

        let volumeURL = sourceVolumeURL(for: source.url)
        if isEjectableRemovableVolume(volumeURL) {
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

    private func restoreSourceVolume(_ source: MountedSource) {
        let volumePath = sourceVolumeURL(for: source.url).standardizedFileURL.path
        guard hiddenSourceVolumePaths.remove(volumePath) != nil else { return }
        persistHiddenSourceVolumes()
    }

    private func isHiddenSourceVolume(_ source: MountedSource) -> Bool {
        hiddenSourceVolumePaths.contains(sourceVolumeURL(for: source.url).standardizedFileURL.path)
    }

    private func persistHiddenSourceVolumes() {
        UserDefaults.standard.set(hiddenSourceVolumePaths.sorted(), forKey: Self.hiddenSourceVolumePathsKey)
    }

    private func clearSourceDerivedState(for source: MountedSource?) {
        scanGeneration += 1
        profileSelectionRevision += 1
        isScanning = false
        copyProgress = CopyProgress()
        detectionCandidates = []
        identifiedCamera = nil
        selectedProfile = nil
        clips = []
        lastScannedFiles = []
        lastScanDiagnostics = []
        lastEffectiveScanSourceURL = nil
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
        panel.directoryURL = destinationURL ?? Self.restoredLastDownloadDestination()

        if panel.runModal() == .OK, let url = panel.url {
            setDestinationURL(url.standardizedFileURL)
            removeOutputDirectorySources()
            rebuildPlan()
        }
    }

    func scanSelectedSource() {
        guard let selectedSource else {
            statusMessage = "Choose a source first"
            return
        }

        scanGeneration += 1
        let generation = scanGeneration
        let profileRevisionAtStart = profileSelectionRevision
        isScanning = true
        statusMessage = "Scanning \(selectedSource.name)..."
        copyPlan = nil
        copyProgress = CopyProgress()
        copyResults = []
        supportFileResults = []
        excludedQueueClipIDs = []
        selectedQueueItemIDs = []
        scanSummary = ScanSummary(sourcePath: selectedSource.url.path)

        Task { [weak self, profiles, selectedSource] in
            guard let self else { return }
            do {
                let scanResult = try await Task.detached {
                    try CardScanner().scanWithOSD(
                        sourceURL: selectedSource.url,
                        profiles: profiles,
                        allowNestedCardRootDiscovery: false
                    )
                }.value
                guard generation == self.scanGeneration,
                      self.selectedSource?.id == selectedSource.id else { return }
                let manuallySelectedProfile = Self.profileAfterCompletedScan(
                    detectedProfile: scanResult.selectedProfile,
                    currentProfile: self.selectedProfile,
                    profileRevisionAtScanStart: profileRevisionAtStart,
                    currentProfileRevision: self.profileSelectionRevision
                )
                self.detectionCandidates = scanResult.candidates
                self.identifiedCamera = scanResult.identifiedCamera
                self.selectedProfile = manuallySelectedProfile
                self.lastScannedFiles = scanResult.allFiles
                self.lastScanDiagnostics = scanResult.diagnostics
                self.lastEffectiveScanSourceURL = scanResult.sourceURL
                if self.profileSelectionRevision != profileRevisionAtStart,
                   let manuallySelectedProfile {
                    self.clips = self.classifiedClips(
                        files: scanResult.allFiles,
                        sourceURL: scanResult.sourceURL,
                        profile: manuallySelectedProfile
                    )
                } else {
                    self.clips = scanResult.clips
                }
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
                guard generation == self.scanGeneration else { return }
                self.statusMessage = "Scan failed: \(error.localizedDescription)"
            }
            if generation == self.scanGeneration {
                self.isScanning = false
            }
        }
    }

    nonisolated static func profileAfterCompletedScan(
        detectedProfile: DashcamProfile?,
        currentProfile: DashcamProfile?,
        profileRevisionAtScanStart: Int,
        currentProfileRevision: Int
    ) -> DashcamProfile? {
        currentProfileRevision == profileRevisionAtScanStart ? detectedProfile : currentProfile
    }

    private func classifiedClips(files: [URL], sourceURL: URL, profile: DashcamProfile) -> [ClipItem] {
        if profile.id == DashcamProfile.genericNewDashcam.id {
            return scanner.classifyGenericallyWithParkingPatterns(
                files: files,
                sourceURL: sourceURL
            ).clips
        }
        return scanner.classifyWithParkingPatterns(
            files: files,
            sourceURL: sourceURL,
            profile: profile
        ).clips
    }

    func loadScanResultForVerification(source: MountedSource, scanResult: ScanResult) {
        selectedSource = source
        detectionCandidates = scanResult.candidates
        identifiedCamera = scanResult.identifiedCamera
        selectedProfile = scanResult.selectedProfile
        lastScannedFiles = scanResult.allFiles
        lastScanDiagnostics = scanResult.diagnostics
        lastEffectiveScanSourceURL = scanResult.sourceURL
        clips = scanResult.clips
        resetFiltersForCurrentClips()
        scanSummary = ScanSummary(
            sourcePath: source.url.path,
            scannedFiles: scanResult.allFiles.count,
            copyableItems: eligibleClips.count,
            excludedItems: scanResult.clips.filter { $0.excludedReason != nil }.count,
            samplePaths: [],
            categoryCounts: Dictionary(grouping: eligibleClips, by: \.outputCategory)
                .mapValues(\.count),
            modeCounts: Dictionary(grouping: footageClips, by: \.displayMode)
                .mapValues(\.count)
        )
    }

    func selectProfile(_ profile: DashcamProfile) {
        profileSelectionRevision += 1
        selectedProfile = profile
        guard let selectedSource else { return }
        guard !lastScannedFiles.isEmpty else {
            statusMessage = isScanning
                ? "Selected \(profile.displayName). The current scan will use this camera."
                : "Selected \(profile.displayName)"
            return
        }
        let sourceRoot = lastEffectiveScanSourceURL ?? selectedSource.url
        clips = classifiedClips(files: lastScannedFiles, sourceURL: sourceRoot, profile: profile)
        resetFiltersForCurrentClips()
        rebuildPlan()
    }

    func resetFiltersForCurrentClips() {
        filters.selectedModes = Set(footageClips.map(\.mode)).filter { mode in
            !Self.isDeselectedByDefaultMode(mode)
        }
        filters.selectedChannels = Set(footageClips.map(\.channel))
        filters.includePhotos = shouldIncludePhotosByDefault
        filters.includeGPS = false
        filters.includeCameraSettings = false
        filters.outputOrganizationMode = .byClipType
        filters.goProLoopGroupOutput = .mergedOnly
    }

    private static func isDeselectedByDefaultMode(_ mode: String) -> Bool {
        switch mode.lowercased() {
        case "time_lapse", "timelapse_video", "time_warp", "timewarp", "time_lapse_or_timewarp":
            return true
        default:
            return false
        }
    }

    private var shouldIncludePhotosByDefault: Bool {
        guard let selectedProfile else { return false }
        let photoFirstTypes = ["mirrorless_camera", "camera"]
        return photoFirstTypes.contains((selectedProfile.cameraType ?? "").lowercased())
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
        case .lastThreeDays:
            filters.useStartDate = true
            filters.useEndDate = true
            filters.startDate = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            filters.endDate = today
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

    func setGoProLoopGroupOutput(_ value: GoProLoopGroupOutput) {
        filters.goProLoopGroupOutput = value
        rebuildPlan()
    }

    func setOutputOrganizationMode(_ value: OutputOrganizationMode) {
        filters.outputOrganizationMode = value
        rebuildPlan()
    }

    var shouldShowGoProLoopGroupOption: Bool {
        guard let selectedProfile else { return false }
        return planner.hasGoProLoopGroups(profile: selectedProfile, clips: eligibleClips)
    }

    func startCopy(retryingItemIDs: Set<CopyPlanItem.ID>? = nil) {
        guard destinationURL != nil else {
            statusMessage = "Choose a download folder first"
            return
        }
        guard let copyPlan else {
            statusMessage = "Nothing selected to download"
            return
        }
        let limitIDs = retryingItemIDs ?? selectedQueueItemIDs
        let runPlan = copyPlan.limitedToMediaItemIDs(limitIDs)
        guard !runPlan.items.isEmpty else {
            statusMessage = limitIDs.isEmpty ? "Nothing selected to download" : "Selected files are no longer in the queue"
            return
        }
        guard !copyProgress.isRunning else { return }

        if retryingItemIDs != nil {
            statusMessage = "Retrying \(runPlan.items.count) failed files..."
        } else {
            statusMessage = selectedQueueItemIDs.isEmpty ? "Downloading..." : "Downloading \(runPlan.items.count) selected files..."
        }
        copyResults = []
        supportFileResults = []
        let executor = CopyExecutor { [weak self] progress in
            self?.copyProgress = progress
            if !progress.summary.isEmpty {
                self?.statusMessage = progress.summary
            }
        }

        copyTask = Task { [weak self] in
            let result = await executor.copy(plan: runPlan)
            guard let self else { return }
            copyResults = result.mediaItems
            supportFileResults = result.supportItems
            lastOutputDirectory = runPlan.destinationRoot
            saveLastDownloadDestination(runPlan.destinationRoot)
            let baseMessage = copyProgress.summary.isEmpty ? "Download complete" : copyProgress.summary
            var finalMessage = baseMessage
            if !Task.isCancelled && openDestinationWhenComplete {
                openOutputDirectory()
            }
            if !Task.isCancelled && ejectSourceWhenComplete {
                let ejectMessage = await ejectCopiedSource(runPlan.sourceRoot, failedCount: result.failedCount)
                if !ejectMessage.isEmpty {
                    finalMessage = "\(baseMessage). \(ejectMessage)"
                }
            }
            statusMessage = finalMessage
            copyTask = nil
            rebuildPlan()
        }
    }

    func retryFailedItems() {
        let failedIDs = Set(copyResults.filter { $0.status == .failed }.map(\.id))
        guard !failedIDs.isEmpty else { return }
        startCopy(retryingItemIDs: failedIDs)
    }

    var failedResultCount: Int {
        copyResults.filter { $0.status == .failed }.count +
            supportFileResults.filter { $0.status == .failed }.count
    }

    var lastRunSummaryLine: String {
        let copied = copyResults.filter { $0.status == .copied }
        let copiedSupport = supportFileResults.filter { $0.status == .copied }
        let copiedBytes = copied.reduce(Int64(0)) { $0 + $1.totalSize } + copiedSupport.reduce(Int64(0)) { $0 + $1.size }
        let skippedCount = copyResults.filter { $0.status == .skipped }.count +
            supportFileResults.filter { $0.status == .skipped }.count
        var parts = ["Copied \(copied.count + copiedSupport.count) (\(copiedBytes.formattedBytes))"]
        if skippedCount > 0 {
            parts.append("\(skippedCount) already in destination")
        }
        if failedResultCount > 0 {
            parts.append("\(failedResultCount) failed")
        }
        return parts.joined(separator: " • ")
    }

    var queueAlreadyExistingCount: Int {
        guard destinationURL != nil else { return 0 }
        return copyPlan?.items.filter(\.alreadyExistsAtDestination).count ?? 0
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
        copyProgress = CopyProgress()
        copyResults = []
        supportFileResults = []
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
        guard isEjectableRemovableVolume(volumeURL) else {
            return "Auto-eject skipped because the source is not a removable card volume"
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

    private func isEjectableRemovableVolume(_ volumeURL: URL) -> Bool {
        guard volumeURL.path.hasPrefix("/Volumes/"),
              let values = try? volumeURL.resourceValues(forKeys: [.volumeIsLocalKey, .volumeIsRemovableKey]),
              values.volumeIsLocal == true,
              values.volumeIsRemovable == true else {
            return false
        }
        return true
    }

    private func isOutputDirectorySource(_ source: MountedSource) -> Bool {
        guard let destinationURL else { return false }
        return source.url.standardizedFileURL.path == destinationURL.standardizedFileURL.path
    }

    private func removeOutputDirectorySources() {
        guard destinationURL != nil else { return }
        let removedSelectedSource = selectedSource.map(isOutputDirectorySource) == true
        mountedSources.removeAll(where: isOutputDirectorySource)
        if removedSelectedSource {
            selectedSource = mountedSources.first
            clearSourceDerivedState(for: selectedSource)
        }
    }

    private func setDestinationURL(_ url: URL) {
        destinationURL = url.standardizedFileURL
        saveLastDownloadDestination(url)
    }

    private func saveLastDownloadDestination(_ url: URL) {
        UserDefaults.standard.set(url.standardizedFileURL.path, forKey: Self.lastDownloadDestinationPathKey)
    }

    nonisolated static func restoredLastDownloadDestination(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let path = defaults.string(forKey: lastDownloadDestinationPathKey),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    func submitFeedback(
        kind: FeedbackKind,
        message: String,
        contact: String,
        includeScan: Bool,
        scanSnapshot: FeedbackScanSnapshot? = nil,
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
            // The learning window has already built the user-reviewed snapshot.
            // Reusing it avoids reopening and inspecting the card a second time
            // when the user presses Submit.
            scan: includeScan ? (scanSnapshot ?? makeFeedbackScanSnapshot()) : nil
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

        let requestedSourceRoot = selectedSource?.url
        let sourceRoot = lastEffectiveScanSourceURL ?? requestedSourceRoot
        let safeFiles = lastScannedFiles.filter { isSafeTrainingSample($0, sourceRoot: sourceRoot) }

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
        let displayModeCounts = Dictionary(grouping: eligibleClips) { clip in
            clip.displayMode
        }
            .mapValues(\.count)
        let outputCategoryCounts = Dictionary(grouping: eligibleClips) { clip in
            clip.outputCategory
        }
            .mapValues(\.count)
        let channelCounts = Dictionary(grouping: eligibleClips) { clip in
            clip.channel
        }
            .mapValues(\.count)
        let inferredParkingPatternCounts = Dictionary(grouping: eligibleClips.compactMap(\.inferredParkingPattern)) { pattern in
            pattern.rawValue
        }
            .mapValues(\.count)

        let safeClipSourcePaths = Set(safeFiles.map(\.standardizedFileURL.path))
        let safeEligibleClips = eligibleClips.filter { clip in
            safeClipSourcePaths.contains(clip.sourceURL.standardizedFileURL.path)
        }
        let videoSpecSamples = makeVideoSpecSamples(
            from: representativeVideoClips(safeEligibleClips),
            sourceRoot: sourceRoot
        )
        let videoSpecSummaries = makeVideoSpecSummaries(
            from: safeEligibleClips.filter(\.isVideo),
            samples: videoSpecSamples,
            sourceRoot: sourceRoot
        ).map { summary in
            FeedbackVideoSpecSummary(
                folder: ".",
                extensionLowercased: summary.extensionLowercased,
                mode: summary.mode,
                displayMode: summary.displayMode,
                outputCategory: summary.outputCategory,
                channel: summary.channel,
                inferredParkingPattern: summary.inferredParkingPattern,
                fileCount: summary.fileCount,
                totalFileSizeBytes: summary.totalFileSizeBytes,
                minFileSizeBytes: summary.minFileSizeBytes,
                maxFileSizeBytes: summary.maxFileSizeBytes,
                firstTimestamp: nil,
                lastTimestamp: nil,
                timestampSourceCounts: summary.timestampSourceCounts,
                sampleRelativePaths: [],
                sampleCodecs: summary.sampleCodecs,
                sampleResolutions: summary.sampleResolutions,
                sampleFrameRates: summary.sampleFrameRates,
                sampleBitrateMin: summary.sampleBitrateMin,
                sampleBitrateMax: summary.sampleBitrateMax,
                sampleDurationMin: summary.sampleDurationMin,
                sampleDurationMax: summary.sampleDurationMax
            )
        }
        let settingSnapshots = safeFiles
            .filter { isPotentialSettingsFile($0, sourceRoot: sourceRoot) }
            .prefix(20)
            .compactMap { makeSettingSnapshot(for: $0, sourceRoot: sourceRoot) }
            .map { snapshot in
                FeedbackSettingSnapshot(relativePath: "", keys: snapshot.keys, safeValues: snapshot.safeValues)
            }

        let candidates = detectionCandidates.prefix(8).map { candidate in
            FeedbackCandidateSnapshot(
                profileID: candidate.profile.id,
                profileName: candidate.profile.displayName,
                score: candidate.score,
                confidence: candidate.confidence.rawValue,
                evidence: []
            )
        }

        let feedbackIdentifiedCamera = identifiedCamera.map { camera in
            IdentifiedCamera(
                manufacturer: camera.manufacturer,
                model: camera.model,
                evidence: [],
                isSupported: camera.isSupported
            )
        }
        let feedbackDiagnostics = lastScanDiagnostics.prefix(40).map { diagnostic in
            ScanDiagnosticEntry(
                stage: diagnostic.stage,
                profileID: diagnostic.profileID,
                profileName: diagnostic.profileName,
                outcome: diagnostic.outcome,
                detail: ""
            )
        }

        return FeedbackScanSnapshot(
            // Feedback must never transmit user-controlled source names,
            // folder paths, or filenames. Structure is represented by counts.
            volumeName: "",
            requestedSourceName: nil,
            effectiveSourceName: nil,
            effectiveSourceRelativePath: nil,
            identifiedCamera: feedbackIdentifiedCamera,
            selectedProfileID: selectedProfile?.id,
            selectedProfileName: selectedProfile?.displayName,
            scannedFiles: scanSummary.scannedFiles,
            copyableItems: scanSummary.copyableItems,
            excludedItems: scanSummary.excludedItems,
            categoryCounts: scanSummary.categoryCounts,
            modeCounts: scanSummary.modeCounts,
            displayModeCounts: displayModeCounts,
            outputCategoryCounts: outputCategoryCounts,
            channelCounts: channelCounts,
            extensionCounts: extensionCounts,
            mediaExtensionCounts: mediaExtensionCounts,
            unrecognizedExtensionCounts: unrecognizedExtensionCounts,
            timestampSourceCounts: timestampSourceCounts,
            suspiciousTimestampItems: eligibleClips.filter(\.hasSuspiciousTimestamp).count,
            inferredParkingPatternCounts: inferredParkingPatternCounts,
            sampleRelativePaths: [],
            rootFolders: [],
            folderSamples: [],
            directorySummaries: [],
            folderSummaries: [],
            filenameSamples: [],
            filenamePatternSummaries: [],
            filenameSequenceSummaries: [],
            supportFileSamples: [],
            ignoredSupportFileSamples: [],
            clipGroupSummaries: [],
            videoSpecSamples: [],
            videoSpecSummaries: videoSpecSummaries,
            settingSnapshots: Array(settingSnapshots),
            candidates: Array(candidates),
            scanDiagnostics: Array(feedbackDiagnostics)
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

    private func effectiveSourceRelativePath(requestedSourceRoot: URL?, effectiveSourceRoot: URL?) -> String? {
        guard let requestedSourceRoot, let effectiveSourceRoot else { return nil }
        let requestedPath = requestedSourceRoot.standardizedFileURL.path
        let effectivePath = effectiveSourceRoot.standardizedFileURL.path
        guard requestedPath != effectivePath else { return "." }
        return effectiveSourceRoot.relativePath(from: requestedSourceRoot)
    }

    private func isSafeTrainingSample(_ fileURL: URL, sourceRoot: URL?) -> Bool {
        let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
        let lowerPath = relativePath.lowercased()
        let filename = fileURL.lastPathComponent
        if filename.hasPrefix("._") { return false }
        if filename.hasPrefix("."), filename != ".boot.log", !isKnownPlaceholderFile(filename) { return false }
        if lowerPath.contains("device.uid") { return false }
        if lowerPath.contains("thumbnail") { return false }
        if lowerPath.contains("/gps/") || lowerPath.hasPrefix("gps/") { return false }
        if containsSensitiveTrainingPath(lowerPath) { return false }
        if ["gpx", "nmea"].contains(fileURL.pathExtension.lowercased()) { return false }
        return true
    }

    private func isSafeTrainingDirectory(relativePath: String) -> Bool {
        let lowerPath = relativePath.lowercased()
        let components = lowerPath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return true }

        let ignoredDirectories = [
            ".spotlight-v100",
            ".fseventsd",
            ".trashes",
            ".temporaryitems",
            ".documentrevisions-v100",
            "system volume information"
        ]
        if components.contains(where: { ignoredDirectories.contains($0) }) {
            return false
        }
        if containsSensitiveTrainingPath(lowerPath) {
            return false
        }
        return true
    }

    private func isKnownPlaceholderFile(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.hasPrefix(".preallocfile") || lower.hasPrefix(".prealloc_file")
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
            return lowerPath.contains("config") ||
                lowerPath.contains("setting") ||
                lowerPath.contains("settings") ||
                lowerPath.contains("version") ||
                lowerPath.contains("firmware")
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
                let sizes = folderFiles.compactMap(fileSizeBytes)
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
                    totalFileSizeBytes: sizes.reduce(Int64(0), +),
                    minFileSizeBytes: sizes.min(),
                    maxFileSizeBytes: sizes.max(),
                    extensionCounts: extensionCounts
                )
            }
    }

    private func makeDirectorySummaries(sourceRoot: URL?) -> [FeedbackDirectorySummary] {
        guard let sourceRoot else { return [] }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var directFilesByDirectory: [String: [URL]] = [:]
        var childDirectoryCounts: [String: Int] = [:]
        var directories: Set<String> = ["."]

        for case let url as URL in enumerator {
            let relativePath = sanitizedRelativePath(for: url, sourceRoot: sourceRoot)
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory == true

            if isDirectory {
                guard isSafeTrainingDirectory(relativePath: relativePath) else {
                    enumerator.skipDescendants()
                    continue
                }

                directories.insert(relativePath)
                let parent = parentDirectoryPath(for: relativePath)
                childDirectoryCounts[parent, default: 0] += 1
            } else if isSafeTrainingSample(url, sourceRoot: sourceRoot) {
                let directory = parentDirectoryPath(for: relativePath)
                if isSafeTrainingDirectory(relativePath: directory) {
                    directories.insert(directory)
                    directFilesByDirectory[directory, default: []].append(url)
                }
            }
        }

        return directories
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(160)
            .map { path in
                let files = directFilesByDirectory[path, default: []]
                let mediaFiles = files.filter(isMediaLikeFile)
                let sizes = files.compactMap(fileSizeBytes)
                let extensionCounts = Dictionary(grouping: files) { fileURL in
                    let ext = fileURL.pathExtension.lowercased()
                    return ext.isEmpty ? "[none]" : ext
                }
                .mapValues(\.count)
                let sampleFilenames = files
                    .map(\.lastPathComponent)
                    .filter { !$0.hasPrefix("._") }
                    .uniquedPreservingOrder()
                    .prefix(8)

                return FeedbackDirectorySummary(
                    path: path,
                    depth: path == "." ? 0 : path.split(separator: "/").count,
                    childDirectoryCount: childDirectoryCounts[path, default: 0],
                    directFileCount: files.count,
                    directMediaFileCount: mediaFiles.count,
                    directSupportFileCount: files.count - mediaFiles.count,
                    directHiddenFileCount: files.filter { $0.lastPathComponent.hasPrefix(".") }.count,
                    directPlaceholderFileCount: files.filter { isKnownPlaceholderFile($0.lastPathComponent) }.count,
                    directTotalFileSizeBytes: sizes.reduce(Int64(0), +),
                    extensionCounts: extensionCounts,
                    sampleFilenames: Array(sampleFilenames)
                )
            }
    }

    private func parentDirectoryPath(for relativePath: String) -> String {
        guard let slashIndex = relativePath.lastIndex(of: "/") else {
            return "."
        }
        return String(relativePath[..<slashIndex])
    }

    private func makeFilenamePatternSummaries(from files: [URL], sourceRoot: URL?) -> [FeedbackFilenamePatternSummary] {
        let grouped = Dictionary(grouping: files) { fileURL in
            let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
            let folder = videoSpecFolder(for: relativePath)
            let ext = fileURL.pathExtension.lowercased()
            let redactedPattern = redactedFilenamePattern(fileURL.lastPathComponent)
            return [folder, ext.isEmpty ? "[none]" : ext, redactedPattern].joined(separator: "\u{1f}")
        }

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(160)
            .compactMap { key in
                guard let bucket = grouped[key], let first = bucket.first else { return nil }
                let firstRelativePath = sanitizedRelativePath(for: first, sourceRoot: sourceRoot)
                let folder = videoSpecFolder(for: firstRelativePath)
                let ext = first.pathExtension.lowercased()
                let sizes = bucket.compactMap(fileSizeBytes)
                let paths = bucket
                    .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

                return FeedbackFilenamePatternSummary(
                    folder: folder,
                    extensionLowercased: ext.isEmpty ? "[none]" : ext,
                    redactedPattern: redactedFilenamePattern(first.lastPathComponent),
                    fileCount: bucket.count,
                    totalFileSizeBytes: sizes.reduce(Int64(0), +),
                    sampleRelativePaths: representativePathStrings(from: paths)
                )
            }
    }

    private func makeFilenameSequenceSummaries(from files: [URL], sourceRoot: URL?) -> [FeedbackFilenameSequenceSummary] {
        let grouped = Dictionary(grouping: files.filter(isMediaLikeFile)) { fileURL in
            let relativePath = sanitizedRelativePath(for: fileURL, sourceRoot: sourceRoot)
            let folder = videoSpecFolder(for: relativePath)
            let ext = fileURL.pathExtension.lowercased()
            let prefix = filenameSequencePrefix(fileURL.lastPathComponent)
            return [folder, ext.isEmpty ? "[none]" : ext, prefix].joined(separator: "\u{1f}")
        }

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(240)
            .compactMap { key in
                guard let bucket = grouped[key], let first = bucket.first else { return nil }
                let relativePath = sanitizedRelativePath(for: first, sourceRoot: sourceRoot)
                let folder = videoSpecFolder(for: relativePath)
                let ext = first.pathExtension.lowercased()
                let prefix = filenameSequencePrefix(first.lastPathComponent)
                let sizes = bucket.compactMap(fileSizeBytes)
                let sequences = bucket.compactMap { filenameSequenceNumber($0.lastPathComponent) }
                let paths = bucket
                    .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

                return FeedbackFilenameSequenceSummary(
                    folder: folder,
                    prefix: prefix,
                    extensionLowercased: ext.isEmpty ? "[none]" : ext,
                    fileCount: bucket.count,
                    firstSequence: sequences.min(),
                    lastSequence: sequences.max(),
                    totalFileSizeBytes: sizes.reduce(Int64(0), +),
                    sampleRelativePaths: representativePathStrings(from: paths)
                )
            }
    }

    private func filenameSequencePrefix(_ filename: String) -> String {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent.uppercased()
        if stem.range(of: #"^G[HXP][A-Z0-9]{2}\d{4}$"#, options: .regularExpression) != nil {
            return String(stem.prefix(4))
        }
        let withoutDigits = stem.map { character in
            character.isNumber ? "0" : character
        }
        .reduce(into: "") { $0.append($1) }
        return withoutDigits
    }

    private func filenameSequenceNumber(_ filename: String) -> Int? {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent.uppercased()
        if stem.range(of: #"^G[HXP][A-Z0-9]{2}\d{4}$"#, options: .regularExpression) != nil {
            return Int(stem.suffix(4))
        }
        guard let match = stem.range(of: #"\d+$"#, options: .regularExpression) else {
            return nil
        }
        return Int(stem[match])
    }

    private func redactedFilenamePattern(_ filename: String) -> String {
        filename.map { character in
            character.isNumber ? "0" : String(character)
        }
        .joined()
    }

    private func makeClipGroupSummaries(from clips: [ClipItem], sourceRoot: URL?) -> [FeedbackClipGroupSummary] {
        let grouped = Dictionary(grouping: clips) { clip in
            [
                videoSpecFolder(for: clip.relativePath),
                clip.extensionLowercased,
                clip.mode,
                clip.displayMode,
                clip.outputCategory,
                clip.channel,
                clip.inferredParkingPattern?.rawValue ?? "none"
            ].joined(separator: "\u{1f}")
        }

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(160)
            .compactMap { key in
                guard let bucket = grouped[key], let first = bucket.first else { return nil }
                let paths = bucket
                    .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                let sizes = bucket.map(\.size)

                return FeedbackClipGroupSummary(
                    folder: videoSpecFolder(for: first.relativePath),
                    extensionLowercased: first.extensionLowercased,
                    mode: first.mode,
                    displayMode: first.displayMode,
                    outputCategory: first.outputCategory,
                    channel: first.channel,
                    displayChannel: first.displayChannel,
                    inferredParkingPattern: first.inferredParkingPattern?.rawValue,
                    fileCount: bucket.count,
                    totalFileSizeBytes: sizes.reduce(Int64(0), +),
                    minFileSizeBytes: sizes.min(),
                    maxFileSizeBytes: sizes.max(),
                    firstTimestamp: feedbackTimestamp(bucket.compactMap(\.timestamp).min()),
                    lastTimestamp: feedbackTimestamp(bucket.compactMap(\.timestamp).max()),
                    timestampSourceCounts: Dictionary(grouping: bucket, by: { $0.timestampSource.rawValue })
                        .mapValues(\.count),
                    sampleRelativePaths: representativePathStrings(from: paths)
                )
            }
    }

    private func representativePathStrings(from sortedPaths: [String]) -> [String] {
        var selected: [String] = []
        func append(_ path: String?) {
            guard let path, !selected.contains(path) else { return }
            selected.append(path)
        }

        append(sortedPaths.first)
        append(sortedPaths[safe: sortedPaths.count / 2])
        append(sortedPaths.last)
        for path in sortedPaths where selected.count < 8 {
            append(path)
        }
        return Array(selected.prefix(8))
    }

    private func representativeVideoClips(_ clips: [ClipItem]) -> [ClipItem] {
        let videoClips = clips.filter(\.isVideo)
        guard !videoClips.isEmpty else { return [] }

        var selected: [ClipItem] = []
        var seenKeys: Set<String> = []
        let maximumSamples = 64

        // Do not open every video merely to decide which ones to inspect. On a
        // large card that turns a small, privacy-safe submission into thousands
        // of synchronous AVFoundation reads. Choose bounded representatives by
        // already-scanned mode/channel/folder data, then inspect only those.
        let grouped = Dictionary(grouping: videoClips) { clip in
            let folder = clip.relativePath.split(separator: "/").dropLast().joined(separator: "/")
            let pattern = clip.inferredParkingPattern?.rawValue ?? "none"
            return "\(clip.outputCategory)|\(clip.displayMode)|\(clip.channel)|\(pattern)|\(folder)|\(clip.extensionLowercased)"
        }

        for key in grouped.keys.sorted() {
            let bucket = grouped[key, default: []]
            let byTimestamp = bucket.sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            let bucketSamples = [
                byTimestamp.first,
                byTimestamp[safe: byTimestamp.count / 2],
                byTimestamp.last,
                bucket.max(by: { (fileSizeBytes(for: $0.sourceURL) ?? 0) < (fileSizeBytes(for: $1.sourceURL) ?? 0) }),
                bucket.min(by: { (fileSizeBytes(for: $0.sourceURL) ?? 0) < (fileSizeBytes(for: $1.sourceURL) ?? 0) })
            ]
            for sample in bucketSamples.compactMap({ $0 }) {
                guard seenKeys.insert(sample.id).inserted else { continue }
                selected.append(sample)
                if selected.count >= maximumSamples { break }
            }
            if selected.count >= maximumSamples { break }
        }

        if selected.count < 8 {
            for clip in videoClips where !selected.contains(clip) {
                selected.append(clip)
                if selected.count >= maximumSamples { break }
            }
        }

        return selected
    }

    private func videoClipOrder(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
        }
        return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
    }

    private func makeVideoSpecSamples(from clips: [ClipItem], sourceRoot: URL?) -> [FeedbackVideoSpecSample] {
        clips.compactMap { clip in
            let fileURL = clip.sourceURL
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
                fileSizeBytes: fileSizeBytes(for: fileURL),
                mode: clip.mode,
                displayMode: clip.displayMode,
                outputCategory: clip.outputCategory,
                channel: clip.channel,
                inferredParkingPattern: clip.inferredParkingPattern?.rawValue,
                codec: codecName(for: videoTrack),
                width: width > 0 ? width : nil,
                height: height > 0 ? height : nil,
                nominalFrameRate: frameRate,
                estimatedBitrate: bitrate,
                durationSeconds: duration
            )
        }
    }

    private func makeVideoSpecSummaries(
        from clips: [ClipItem],
        samples: [FeedbackVideoSpecSample],
        sourceRoot: URL?
    ) -> [FeedbackVideoSpecSummary] {
        let samplesByPath = Dictionary(samples.map { ($0.relativePath, $0) }, uniquingKeysWith: { current, _ in current })
        let grouped = Dictionary(grouping: clips) { clip in
            videoSpecBucketKey(for: clip)
        }

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(120)
            .compactMap { key in
                guard let bucket = grouped[key], let first = bucket.first else { return nil }
                let paths = bucket
                    .map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) }
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                let sizes = bucket.map(\.size)
                let bucketSamples = paths.compactMap { samplesByPath[$0] }
                let bitrates = bucketSamples.compactMap(\.estimatedBitrate)
                let durations = bucketSamples.compactMap(\.durationSeconds)
                let resolutions = bucketSamples.compactMap { sample -> String? in
                    guard let width = sample.width, let height = sample.height else { return nil }
                    return "\(width)x\(height)"
                }
                let frameRates = bucketSamples.compactMap(\.nominalFrameRate)

                return FeedbackVideoSpecSummary(
                    folder: videoSpecFolder(for: first.relativePath),
                    extensionLowercased: first.extensionLowercased,
                    mode: first.mode,
                    displayMode: first.displayMode,
                    outputCategory: first.outputCategory,
                    channel: first.channel,
                    inferredParkingPattern: first.inferredParkingPattern?.rawValue,
                    fileCount: bucket.count,
                    totalFileSizeBytes: sizes.reduce(Int64(0), +),
                    minFileSizeBytes: sizes.min(),
                    maxFileSizeBytes: sizes.max(),
                    firstTimestamp: feedbackTimestamp(bucket.compactMap(\.timestamp).min()),
                    lastTimestamp: feedbackTimestamp(bucket.compactMap(\.timestamp).max()),
                    timestampSourceCounts: Dictionary(grouping: bucket, by: { $0.timestampSource.rawValue })
                        .mapValues(\.count),
                    sampleRelativePaths: representativePaths(from: paths, bucket: bucket, sourceRoot: sourceRoot),
                    sampleCodecs: Array(bucketSamples.compactMap(\.codec).uniquedPreservingOrder().prefix(6)),
                    sampleResolutions: Array(resolutions.uniquedPreservingOrder().prefix(6)),
                    sampleFrameRates: Array(frameRates.uniquedPreservingOrder().prefix(6)),
                    sampleBitrateMin: bitrates.min(),
                    sampleBitrateMax: bitrates.max(),
                    sampleDurationMin: durations.min(),
                    sampleDurationMax: durations.max()
                )
            }
    }

    private func representativePaths(from sortedPaths: [String], bucket: [ClipItem], sourceRoot: URL?) -> [String] {
        var selected: [String] = []
        func append(_ path: String?) {
            guard let path, !selected.contains(path) else { return }
            selected.append(path)
        }

        append(sortedPaths.first)
        append(sortedPaths[safe: sortedPaths.count / 2])
        append(sortedPaths.last)

        let bySize = bucket.sorted { $0.size < $1.size }
        append(bySize.first.map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) })
        append(bySize.last.map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) })

        let byTimestamp = bucket
            .filter { $0.timestamp != nil }
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        append(byTimestamp.first.map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) })
        append(byTimestamp[safe: byTimestamp.count / 2].map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) })
        append(byTimestamp.last.map { sanitizedRelativePath(for: $0, sourceRoot: sourceRoot) })

        for path in sortedPaths where selected.count < 10 {
            append(path)
        }
        return Array(selected.prefix(10))
    }

    private func feedbackTimestamp(_ date: Date?) -> String? {
        guard let date else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

    private func videoSpecBucketKey(for clip: ClipItem) -> String {
        [
            videoSpecFolder(for: clip.relativePath),
            clip.extensionLowercased,
            clip.mode,
            clip.displayMode,
            clip.outputCategory,
            clip.channel,
            clip.inferredParkingPattern?.rawValue ?? "none"
        ].joined(separator: "\u{1f}")
    }

    private func videoSpecFolder(for relativePath: String) -> String {
        guard let slashIndex = relativePath.lastIndex(of: "/") else {
            return "."
        }
        return String(relativePath[..<slashIndex])
    }

    private func fileSizeBytes(for fileURL: URL) -> Int64? {
        guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return Int64(size)
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

    private func appVersionString() -> String {
        AppBuildInfo.current().displayString
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
