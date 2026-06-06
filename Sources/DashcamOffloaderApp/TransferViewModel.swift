import AppKit
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
    @Published var lastOutputDirectory: URL?

    private let scanner = CardScanner()
    private let planner = CopyPlanner()

    init() {
        refreshSources()
        loadProfiles()
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

        if panel.runModal() == .OK, let url = panel.url {
            let source = MountedSource(url: url, name: url.lastPathComponent)
            if !mountedSources.contains(source) {
                mountedSources.insert(source, at: 0)
            }
            selectSource(source, scanImmediately: true)
        }
    }

    func selectSource(_ source: MountedSource, scanImmediately: Bool = true) {
        selectedSource = source
        detectionCandidates = []
        selectedProfile = nil
        clips = []
        copyPlan = nil
        copyResults = []
        scanSummary = ScanSummary(sourcePath: source.url.path)
        statusMessage = "Selected \(source.name)"

        if scanImmediately {
            scanSelectedSource()
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
        scanSummary = ScanSummary(sourcePath: selectedSource.url.path)

        Task { [weak self, profiles, selectedSource] in
            guard let self else { return }
            do {
                let scanResult = try await Task.detached {
                    try CardScanner().scan(sourceURL: selectedSource.url, profiles: profiles)
                }.value
                self.detectionCandidates = scanResult.candidates
                self.selectedProfile = scanResult.selectedProfile
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
                        .mapValues(\.count)
                )
                self.statusMessage = "Scanned \(selectedSource.url.path). Found \(self.eligibleClips.count) copyable items"
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
        clips = scanner.classify(files: clips.map(\.sourceURL), sourceURL: selectedSource.url, profile: profile)
        resetFiltersForCurrentClips()
        rebuildPlan()
    }

    func resetFiltersForCurrentClips() {
        filters.selectedModes = Set(eligibleClips.filter { !$0.isGPS && !$0.isPhoto }.map(\.mode))
        filters.selectedChannels = Set(eligibleClips.filter { !$0.isGPS && !$0.isPhoto }.map(\.channel))
        filters.includePhotos = false
        filters.includeGPS = false
        filters.separateCategoryFolders = true
    }

    func rebuildPlan() {
        guard let selectedSource, let destinationURL, let selectedProfile else {
            copyPlan = nil
            return
        }

        copyPlan = planner.makePlan(
            sourceRoot: selectedSource.url,
            destinationRoot: destinationURL,
            profile: selectedProfile,
            clips: clips,
            filters: filters
        )
    }

    func startCopy() {
        guard let copyPlan, !copyPlan.items.isEmpty else {
            statusMessage = "Nothing selected to copy"
            return
        }

        statusMessage = "Copying..."
        copyResults = []
        let executor = CopyExecutor { [weak self] progress in
            self?.copyProgress = progress
            if !progress.summary.isEmpty {
                self?.statusMessage = progress.summary
            }
        }

        Task {
            copyResults = await executor.copy(plan: copyPlan)
            lastOutputDirectory = copyPlan.destinationRoot
            statusMessage = copyProgress.summary.isEmpty ? "Copy complete" : copyProgress.summary
        }
    }

    func openOutputDirectory() {
        if let lastOutputDirectory {
            NSWorkspace.shared.open(lastOutputDirectory)
        } else if let destinationURL {
            NSWorkspace.shared.open(destinationURL)
        }
    }
}
