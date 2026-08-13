import AppKit
import SwiftUI

private enum AppLinks {
    static let githubRepositoryURL = URL(string: "https://github.com/vortexopenclaw/dashcam-offloader")!
    static let privacyPolicyURL = URL(string: "https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/privacy")!
}

private extension DateFormatter {
    static let dashcamOffloaderCreatedColumn: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel: TransferViewModel
    @State private var isFeedbackPresented = false
    @State private var cardLearningWindow: NSWindow?
    @State private var showDownloadOptions = true
    @State private var showDownloadFilters = true
    @State private var selectedProfileBrand: String?
    @State private var selectedCatalogModel: CameraModelChoice?
    @State private var reviewSortOrder: [KeyPathComparator<CopyPlanItem>] = [
        KeyPathComparator(\CopyPlanItem.mediaKindSortRank),
        KeyPathComparator(\CopyPlanItem.displayFilename)
    ]
    private let createdDateFormatter = DateFormatter.dashcamOffloaderCreatedColumn

    var body: some View {
        NavigationSplitView {
            sourceList
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            mainPanel
        }
        .toolbar {
            Button {
                viewModel.refreshSources(userInitiated: true)
            } label: {
                Label("Refresh Sources", systemImage: "arrow.clockwise")
            }
            .help("Refresh the source list and rescan mounted cards.")
            Button {
                viewModel.chooseDestinationFolder()
            } label: {
                Label("Download Folder", systemImage: "folder")
            }
            .help("Choose where downloaded footage should be saved.")
            Button {
                isFeedbackPresented = true
            } label: {
                Label("Feedback", systemImage: "bubble.left.and.bubble.right")
            }
            .help("Send a bug report, feature request, or other feedback.")
            Button {
                viewModel.checkForUpdates(userInitiated: true)
            } label: {
                Label("Check for Updates", systemImage: "arrow.down.circle")
            }
            .disabled(viewModel.isCheckingForUpdates)
            .help("Check for a newer Dashcam Offloader build.")
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet(viewModel: viewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshSourcesAfterActivation()
            }
        }
        .task {
            viewModel.startInitialSourceDiscovery()
            viewModel.startInitialUpdateCheck()
        }
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources")
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top)

            Picker("Import", selection: Binding(
                get: { viewModel.importMode },
                set: { viewModel.setImportMode($0) }
            )) {
                ForEach(ImportMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button {
                viewModel.chooseSourceFolder()
            } label: {
                Label(viewModel.importMode == .dashcamFootage
                    ? "Choose Memory Card..."
                    : "Choose Video Folder...",
                    systemImage: viewModel.importMode == .dashcamFootage
                        ? "externaldrive" : "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Toggle("Show all volumes", isOn: Binding(
                get: { viewModel.showAllVolumes },
                set: { viewModel.setShowAllVolumes($0) }
            ))
            .font(.caption)
            .padding(.horizontal)
            .disabled(viewModel.importMode == .regularVideo)

            Text(viewModel.importMode == .regularVideo
                ? "Choose a folder of camera footage. The app only copies from it."
                : (viewModel.showAllVolumes ? "Showing all mounted volumes." : "Only showing locations that look like dashcam footage sources."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if viewModel.mountedSources.isEmpty {
                Text(viewModel.showAllVolumes ? "No mounted sources found. Choose a card or folder manually." : "No dashcam-like sources found. Use Show all volumes or choose a card manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.mountedSources) { source in
                            sourceRow(source)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
            }

            VStack(spacing: 8) {
                Button {
                    viewModel.refreshSources(userInitiated: true)
                } label: {
                    Label("Refresh Sources", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.scanSelectedSource()
                } label: {
                    Label(viewModel.isScanning ? "Scanning" : "Rescan Selected Card", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedSource == nil || viewModel.isScanning)
            }
            .padding([.horizontal, .bottom])
        }
    }

    private func sourceRow(_ source: MountedSource) -> some View {
        let isSelected = viewModel.selectedSource?.id == source.id
        let iconName = isSelected ? "checkmark.circle.fill" : "externaldrive"
        let iconColor = isSelected ? Color.accentColor : Color.secondary
        let backgroundColor = isSelected ? Color.accentColor.opacity(0.12) : Color.clear

        return Button {
            viewModel.selectSource(source)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(.headline)
                    Text(source.displayPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button {
                viewModel.renameSource(source)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                viewModel.ejectSource(source)
            } label: {
                Label("Eject", systemImage: "eject")
            }
            .disabled(viewModel.copyProgress.isRunning)
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    workflowSection
                    updateSection
                    aboutSection
                    sourceSection
                    detectionSection
                    destinationSection
                    filtersSection
                    planSection
                    resultsSection
                }
                .padding(24)
            }

            footer
        }
    }

    private var sourceSection: some View {
        GroupBox(viewModel.importMode == .dashcamFootage ? "1. Pick Your Memory Card" : "1. Pick Your Video Folder") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedSource?.displayPath ?? "No source selected")
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Text(viewModel.importMode == .dashcamFootage
                            ? "Choose the card from your dashcam. The app only reads from the card and never changes it."
                            : "Choose a folder of regular camera footage. The app only reads from it and never changes it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.chooseSourceFolder()
                    } label: {
                        Label("Choose", systemImage: viewModel.importMode == .dashcamFootage ? "externaldrive" : "folder")
                    }
                }

                if viewModel.scanSummary.hasScan {
                    Divider()
                    HStack(spacing: 16) {
                        Label("\(viewModel.scanSummary.scannedFiles) scanned", systemImage: "doc")
                        Label("\(viewModel.scanSummary.copyableItems) downloadable", systemImage: "checkmark.circle")
                        Label("\(viewModel.scanSummary.excludedItems) excluded", systemImage: "nosign")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if !viewModel.scanSummary.sortedCategoryCounts.isEmpty {
                        countChips(title: "Output Groups", counts: viewModel.scanSummary.sortedCategoryCounts)
                    }

                    if !viewModel.scanSummary.sortedModeCounts.isEmpty {
                        countChips(title: "Recording Types", counts: viewModel.scanSummary.sortedModeCounts)
                    }

                    fileTypeToggles
                }
            }
            .padding(8)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dashcam Offloader")
                    .font(.largeTitle.bold())
                Text("Download dashcam footage from a memory card to a folder on your computer.")
                    .foregroundStyle(.secondary)
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }

    private var workflowSection: some View {
        HStack(spacing: 12) {
            workflowStep(
                number: 1,
                title: viewModel.importMode == .dashcamFootage ? "Pick card" : "Pick video folder",
                detail: viewModel.selectedSource?.name ?? (viewModel.importMode == .dashcamFootage ? "Choose the memory card" : "Choose the video folder"),
                complete: viewModel.selectedSource != nil
            )
            workflowStep(
                number: 2,
                title: "Choose folder",
                detail: viewModel.destinationURL?.lastPathComponent ?? "Where downloads go",
                complete: viewModel.destinationURL != nil
            )
            workflowStep(
                number: 3,
                title: "Download",
                detail: viewModel.destinationURL == nil ? "Choose folder first" : "\(viewModel.copyPlan?.selectedFileCount ?? 0) files ready",
                complete: !(viewModel.copyPlan?.items.isEmpty ?? true)
            )
        }
    }

    private var updateSection: some View {
        GroupBox("App Updates") {
            HStack(alignment: .center, spacing: 12) {
                Toggle("Check for updates automatically", isOn: $viewModel.automaticUpdateChecksEnabled)
                    .toggleStyle(.checkbox)
                Spacer()
                if viewModel.isCheckingForUpdates {
                    ProgressView()
                        .controlSize(.small)
                }
                if viewModel.availableUpdate != nil {
                    Button {
                        viewModel.installAvailableUpdate()
                    } label: {
                        Label("Install Update", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isCheckingForUpdates)
                }
                Button {
                    viewModel.checkForUpdates(userInitiated: true)
                } label: {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isCheckingForUpdates)
            }
            .padding(8)

            if !viewModel.updateStatusMessage.isEmpty {
                Text(viewModel.updateStatusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.updateStatusMessage.localizedCaseInsensitiveContains("failed") ? .red : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }

            if let update = viewModel.availableUpdate,
               let releaseNotesURL = update.releaseNotesURL {
                HStack {
                    Label("Release notes are available for this update.", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(releaseNotesURL)
                    } label: {
                        Label("Open Release Notes", systemImage: "arrow.up.right.square")
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private var aboutSection: some View {
        GroupBox("About") {
            HStack {
                Text("Dashcam Offloader is open source.")
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: AppLinks.githubRepositoryURL) {
                    Label("View on GitHub", systemImage: "arrow.up.right.square")
                }
            }
            .padding(8)
        }
    }

    private func workflowStep(number: Int, title: String, detail: String, complete: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(complete ? Color.accentColor : Color.secondary.opacity(0.18))
                    .frame(width: 28, height: 28)
                if complete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var detectionSection: some View {
        GroupBox("Camera Detection") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.profiles.isEmpty {
                    Text("No profiles loaded")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cameraDetectionTitle)
                            .font(.headline)
                        Text(cameraDetectionDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        compactProfileMenu(
                            title: activeProfileBrand ?? "Brand",
                            placeholder: "Brand",
                            options: viewModel.cameraModelsByBrand.map(\.brand)
                        ) { brand in
                            selectedProfileBrand = brand
                            selectedCatalogModel = nil
                        }

                        compactProfileMenu(
                            title: activeProfileModelTitle,
                            placeholder: "Model",
                            options: modelsForActiveBrand.map(\.model),
                            footerOptions: ["New model..."]
                        ) { model in
                            if model == "New model..." {
                                selectedCatalogModel = nil
                                viewModel.selectProfile(.genericNewDashcam)
                                return
                            }
                            guard let choice = modelsForActiveBrand.first(where: { $0.model == model }) else {
                                return
                            }
                            selectedProfileBrand = choice.brand
                            if let profile = choice.profile {
                                selectedCatalogModel = nil
                                viewModel.selectProfile(profile)
                            } else {
                                selectedCatalogModel = choice
                                viewModel.selectProfile(.genericNewDashcam)
                            }
                        }
                        .disabled(activeProfileBrand == nil)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    if shouldShowLearnCardPrompt {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(learnCardPromptTitle)
                                    .font(.subheadline.bold())
                                Text(learnCardPromptDetail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                presentCardLearningWindow()
                            } label: {
                                Label("Submit Learning Data", systemImage: "graduationcap")
                            }
                            .disabled(!viewModel.scanSummary.hasScan)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var cameraDetectionTitle: String {
        guard viewModel.scanSummary.hasScan else {
            return "Waiting for a card scan"
        }
        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id {
            return "Unrecognized dashcam, generic download ready"
        }
        if let profile = viewModel.selectedProfile {
            return "Detected \(profile.displayName)"
        }
        return "No camera profile selected"
    }

    private var cameraDetectionDetail: String {
        guard viewModel.scanSummary.hasScan else {
            return "Choose a memory card and the app will look for videos and photos automatically."
        }
        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id {
            return "The app can still download common dashcam videos and photos. Teaching the card is optional."
        }
        if viewModel.selectedProfile != nil {
            return "The app will organize footage using the detected camera profile. Learning data is optional if this setup has modes, channels, or settings we have not seen yet."
        }
        return "You can choose a profile manually, but the priority is still getting your footage copied."
    }

    private var activeProfileBrand: String? {
        if let selectedCatalogModel {
            return selectedCatalogModel.brand
        }
        if let selectedProfile = viewModel.selectedProfile,
           selectedProfile.id != DashcamProfile.genericNewDashcam.id {
            return selectedProfile.displayManufacturer
        }
        if let identifiedCamera = viewModel.identifiedCamera,
           !identifiedCamera.isSupported {
            return identifiedCamera.displayManufacturer
        }
        if let selectedProfileBrand,
           viewModel.cameraModelsByBrand.contains(where: { $0.brand == selectedProfileBrand }) {
            return selectedProfileBrand
        }
        if let selectedProfile = viewModel.selectedProfile {
            return selectedProfile.displayManufacturer
        }
        return nil
    }

    private var modelsForActiveBrand: [CameraModelChoice] {
        guard let activeProfileBrand else { return [] }
        return viewModel.cameraModelsByBrand.first(where: { $0.brand == activeProfileBrand })?.models ?? []
    }

    private var activeProfileModelTitle: String? {
        if let selectedCatalogModel,
           selectedCatalogModel.brand == activeProfileBrand {
            return selectedCatalogModel.model
        }
        guard let selectedProfile = viewModel.selectedProfile,
              selectedProfile.displayManufacturer == activeProfileBrand else {
            if let identifiedCamera = viewModel.identifiedCamera,
               !identifiedCamera.isSupported,
               identifiedCamera.displayManufacturer == activeProfileBrand {
                return identifiedCamera.model
            }
            return nil
        }
        return selectedProfile.model
    }

    private func compactProfileMenu(
        title: String?,
        placeholder: String,
        options: [String],
        footerOptions: [String] = [],
        action: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    action(option)
                }
            }
            if !footerOptions.isEmpty {
                Divider()
                ForEach(footerOptions, id: \.self) { option in
                    Button(option) {
                        action(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title ?? placeholder)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .menuStyle(.borderlessButton)
    }

    private func presentCardLearningWindow() {
        if let cardLearningWindow, cardLearningWindow.isVisible {
            cardLearningWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Improve Camera Support"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: CardLearningSheet(
            viewModel: viewModel,
            selectedBrand: activeProfileBrand,
            selectedCatalogModel: selectedCatalogModel,
            onClose: { [weak window] in
                window?.close()
            }
        ))
        cardLearningWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var shouldShowLearnCardPrompt: Bool {
        viewModel.scanSummary.hasScan
    }

    private var learnCardPromptTitle: String {
        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id || viewModel.selectedProfile == nil {
            return "Help add support for this dashcam"
        }
        return "Help improve this camera profile"
    }

    private var learnCardPromptDetail: String {
        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id || viewModel.selectedProfile == nil {
            return "Optional. Downloading still works. Sharing this helps the app better understand this dashcam, including its recording modes, channels, and clip types."
        }
        return "Optional. Sharing this setup helps improve compatibility for this dashcam, including its channels, parking modes, resolutions, and clip types."
    }

    private var destinationSection: some View {
        GroupBox("2. Choose Download Folder") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.destinationURL?.path ?? "No download folder selected")
                            .lineLimit(1)
                        Text("Source cards are never modified. Copies go only to this folder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack {
                        Button {
                            viewModel.openOutputDirectory()
                        } label: {
                            Label("Open Folder", systemImage: "folder.fill")
                        }
                        .disabled(viewModel.destinationURL == nil)

                        Button {
                            viewModel.chooseDestinationFolder()
                        } label: {
                            Label("Choose Folder", systemImage: "folder")
                        }
                    }
                }

                if viewModel.destinationURL == nil {
                    Label("Choose a download folder before downloading. The preview below will populate after the card scan, but copying stays disabled until a folder is selected.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle("Open download folder when complete", isOn: $viewModel.openDestinationWhenComplete)
                    .disabled(viewModel.destinationURL == nil)

                expandableSection("Download options", isExpanded: $showDownloadOptions) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Video filename suffix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField(
                                "Optional text appended to the end of the file name",
                                text: Binding(
                                    get: { viewModel.outputNamingOptions.videoFilenameSuffix },
                                    set: { viewModel.setVideoFilenameSuffix($0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                        Toggle("Eject card when complete", isOn: $viewModel.ejectSourceWhenComplete)
                            .disabled(viewModel.selectedSource == nil)
                    }
                    .font(.caption)
                    .padding(.top, 6)
                }
            }
            .padding(8)
        }
    }

    private var filtersSection: some View {
        GroupBox("What to Download") {
            VStack(alignment: .leading, spacing: 12) {
                Text("All detected videos are selected by default. Photos and extra logs stay off unless you choose them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                expandableSection("Filters and extras", isExpanded: $showDownloadFilters) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Date range", selection: Binding(
                            get: { viewModel.filters.datePreset },
                            set: { viewModel.setDatePreset($0) }
                        )) {
                            ForEach(DateFilterPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)

                        if viewModel.filters.datePreset == .custom {
                            DatePicker("From", selection: Binding(
                                get: { viewModel.filters.startDate },
                                set: { viewModel.setCustomStartDate($0) }
                            ), displayedComponents: .date)
                            DatePicker("Through", selection: Binding(
                                get: { viewModel.filters.endDate },
                                set: { viewModel.setCustomEndDate($0) }
                            ), displayedComponents: .date)
                        }

                        Divider()

                        fileTypeToggles

                        Divider()

                        checkboxGrid(
                            title: "Recording Types",
                            values: viewModel.availableModes,
                            selected: $viewModel.filters.selectedModes,
                            display: { ClipItem.displayLabel(for: $0) },
                            onChange: { viewModel.rebuildPlan() }
                        )
                        if viewModel.shouldShowChannelFilter {
                            checkboxGrid(
                                title: "Channels",
                                values: viewModel.availableChannels,
                                selected: $viewModel.filters.selectedChannels,
                                display: { ClipItem.displayLabel(for: $0) },
                                onChange: { viewModel.rebuildPlan() }
                            )
                        }

                        if viewModel.shouldShowGoProLoopGroupOption {
                            Picker("Looping videos", selection: Binding(
                                get: { viewModel.filters.goProLoopGroupOutput },
                                set: { viewModel.setGoProLoopGroupOutput($0) }
                            )) {
                                ForEach(GoProLoopGroupOutput.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            Text("GoPro records long looping videos as chained segments. The merged clip combines each chain into one video.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Text("Separate GPS files are copied when the card exposes them. Cameras that embed GPS in video files keep that data with the clip.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Organize downloads", selection: Binding(
                            get: { viewModel.filters.outputOrganizationMode },
                            set: { viewModel.setOutputOrganizationMode($0) }
                        )) {
                            ForEach(OutputOrganizationMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        Text(viewModel.filters.outputOrganizationMode.helpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Copy camera settings and boot logs", isOn: Binding(
                            get: { viewModel.filters.includeCameraSettings },
                            set: { viewModel.filters.includeCameraSettings = $0; viewModel.rebuildPlan() }
                        ))
                        Text("Copies Config/Settings folders and boot logs into a separate Camera Settings folder for troubleshooting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(8)
        }
    }

    private func expandableSection<Content: View>(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    Text(title)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    private func checkboxGrid(
        title: String,
        values: [String],
        selected: Binding<Set<String>>,
        display: @escaping (String) -> String,
        onChange: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if values.isEmpty {
                Text("Scan a source to populate this filter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading) {
                    ForEach(values, id: \.self) { value in
                        Toggle(display(value), isOn: Binding(
                            get: { selected.wrappedValue.contains(value) },
                            set: { isOn in
                                if isOn {
                                    selected.wrappedValue.insert(value)
                                } else {
                                    selected.wrappedValue.remove(value)
                                }
                                onChange()
                            }
                        ))
                    }
                }
            }
        }
    }

    private var planSection: some View {
        GroupBox("3. Review and Download") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(viewModel.copyPlan?.selectedFileCount ?? 0) files")
                    Text(viewModel.copyPlan?.selectedBytes.formattedBytes ?? "0 bytes")
                        .foregroundStyle(.secondary)
                    if !viewModel.selectedQueueItemIDs.isEmpty {
                        Text("\(viewModel.selectedQueueItemIDs.count) selected")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.removeSelectedQueueItems()
                    } label: {
                        Label("Remove Selected", systemImage: "minus.circle")
                    }
                    .disabled(viewModel.selectedQueueItemIDs.isEmpty || viewModel.copyProgress.isRunning)

                    Button {
                        viewModel.restoreQueuedFiles()
                    } label: {
                        Label("Reset Queue", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.copyProgress.isRunning)

                    Button {
                        viewModel.rebuildPlan()
                    } label: {
                        Label("Refresh Preview", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(viewModel.selectedProfile == nil || viewModel.copyProgress.isRunning)
                }

                if viewModel.destinationURL == nil {
                    Label("Download folder required before copying", systemImage: "folder.badge.questionmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.queueAlreadyExistingCount > 0 {
                    Label("\(viewModel.queueAlreadyExistingCount) of these files are already in the download folder and will be skipped", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                reviewTable
                    .frame(minHeight: 220)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var reviewTable: some View {
        let allItems = viewModel.copyPlan?.items ?? []
        let items = Array(allItems.sorted(using: reviewSortOrder).prefix(250))
        let shouldShowCreatedColumn = allItems.contains { $0.displayCreatedAt != nil }
        if viewModel.shouldShowChannelFilter && shouldShowCreatedColumn {
            Table(items, selection: $viewModel.selectedQueueItemIDs, sortOrder: $reviewSortOrder) {
                TableColumn("File", value: \.displayFilename) { item in
                    Text(item.displayFilename)
                        .lineLimit(1)
                        .foregroundStyle(item.alreadyExistsAtDestination ? .secondary : .primary)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Source", value: \.displaySource) { item in
                    Text(item.displaySource)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Mode", value: \.displayModeLabel) { item in
                    Text(item.displayModeLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Folder", value: \.displayFolderLabel) { item in
                    Text(item.displayFolderLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Channel", value: \.displayChannelLabel) { item in
                    Text(item.displayChannelLabel)
                }
                .width(min: 80, ideal: 110)

                TableColumn("Created", value: \.createdAtSortValue) { item in
                    Text(item.displayCreatedAt.map(createdDateFormatter.string(from:)) ?? "-")
                        .font(.caption)
                }
                .width(min: 120, ideal: 150)

                TableColumn("Download Folder", value: \.displayDownloadFolder) { item in
                    Text(item.displayDownloadFolder)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 130, ideal: 180)

                TableColumn("Size", value: \.displaySize) { item in
                    Text(item.displaySize.formattedBytes)
                }
                .width(min: 80, ideal: 95)
            }
        } else if viewModel.shouldShowChannelFilter {
            Table(items, selection: $viewModel.selectedQueueItemIDs, sortOrder: $reviewSortOrder) {
                TableColumn("File", value: \.displayFilename) { item in
                    Text(item.displayFilename)
                        .lineLimit(1)
                        .foregroundStyle(item.alreadyExistsAtDestination ? .secondary : .primary)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Source", value: \.displaySource) { item in
                    Text(item.displaySource)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Mode", value: \.displayModeLabel) { item in
                    Text(item.displayModeLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Folder", value: \.displayFolderLabel) { item in
                    Text(item.displayFolderLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Channel", value: \.displayChannelLabel) { item in
                    Text(item.displayChannelLabel)
                }
                .width(min: 80, ideal: 110)

                TableColumn("Download Folder", value: \.displayDownloadFolder) { item in
                    Text(item.displayDownloadFolder)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 130, ideal: 180)

                TableColumn("Size", value: \.displaySize) { item in
                    Text(item.displaySize.formattedBytes)
                }
                .width(min: 80, ideal: 95)
            }
        } else if shouldShowCreatedColumn {
            Table(items, selection: $viewModel.selectedQueueItemIDs, sortOrder: $reviewSortOrder) {
                TableColumn("File", value: \.displayFilename) { item in
                    Text(item.displayFilename)
                        .lineLimit(1)
                        .foregroundStyle(item.alreadyExistsAtDestination ? .secondary : .primary)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Source", value: \.displaySource) { item in
                    Text(item.displaySource)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Mode", value: \.displayModeLabel) { item in
                    Text(item.displayModeLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Folder", value: \.displayFolderLabel) { item in
                    Text(item.displayFolderLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Created", value: \.createdAtSortValue) { item in
                    Text(item.displayCreatedAt.map(createdDateFormatter.string(from:)) ?? "-")
                        .font(.caption)
                }
                .width(min: 120, ideal: 150)

                TableColumn("Download Folder", value: \.displayDownloadFolder) { item in
                    Text(item.displayDownloadFolder)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 130, ideal: 180)

                TableColumn("Size", value: \.displaySize) { item in
                    Text(item.displaySize.formattedBytes)
                }
                .width(min: 80, ideal: 95)
            }
        } else {
            Table(items, selection: $viewModel.selectedQueueItemIDs, sortOrder: $reviewSortOrder) {
                TableColumn("File", value: \.displayFilename) { item in
                    Text(item.displayFilename)
                        .lineLimit(1)
                        .foregroundStyle(item.alreadyExistsAtDestination ? .secondary : .primary)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Source", value: \.displaySource) { item in
                    Text(item.displaySource)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Mode", value: \.displayModeLabel) { item in
                    Text(item.displayModeLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Folder", value: \.displayFolderLabel) { item in
                    Text(item.displayFolderLabel)
                }
                .width(min: 90, ideal: 130)

                TableColumn("Download Folder", value: \.displayDownloadFolder) { item in
                    Text(item.displayDownloadFolder)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 130, ideal: 180)

                TableColumn("Size", value: \.displaySize) { item in
                    Text(item.displaySize.formattedBytes)
                }
                .width(min: 80, ideal: 95)
            }
        }
    }

    private var fileTypeToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Types")
                .font(.headline)
            HStack(spacing: 18) {
                Toggle("Videos", isOn: Binding(
                    get: { viewModel.areVideosIncluded },
                    set: { viewModel.setIncludeVideos($0) }
                ))
                .disabled(!viewModel.hasVideoItems)

                Toggle("Photos", isOn: Binding(
                    get: { viewModel.filters.includePhotos },
                    set: { viewModel.setIncludePhotos($0) }
                ))
                .disabled(!viewModel.hasPhotoItems)

                Toggle("GPS logs", isOn: Binding(
                    get: { viewModel.filters.includeGPS },
                    set: { viewModel.setIncludeGPS($0) }
                ))
                .disabled(!viewModel.hasGPSItems)
            }
            .font(.caption)

            if !viewModel.scanSummary.hasScan {
                Text("Scan a source to choose file types.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var resultsSection: some View {
        Group {
            if !viewModel.copyResults.isEmpty {
                GroupBox("Last Run") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(viewModel.lastRunSummaryLine)
                                .font(.callout)
                            Spacer()
                            if viewModel.failedResultCount > 0 {
                                Button {
                                    viewModel.retryFailedItems()
                                } label: {
                                    Label("Retry Failed", systemImage: "arrow.clockwise")
                                }
                                .disabled(viewModel.copyProgress.isRunning)
                            }
                        }
                        if let outputPath = viewModel.lastOutputDirectory?.path {
                            Text("Saved to \(outputPath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Divider()
                        ForEach(viewModel.copyResults.prefix(10)) { item in
                            HStack {
                                Text(item.displayFilename).lineLimit(1)
                                Spacer()
                                Text(resultLabel(for: item))
                                    .foregroundStyle(item.status == .failed ? .red : .secondary)
                            }
                        }
                        if viewModel.copyResults.count > 10 {
                            Text("and \(viewModel.copyResults.count - 10) more files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !viewModel.supportFileResults.isEmpty {
                            Divider()
                            Text("\(viewModel.supportFileResults.count) settings/log files processed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func resultLabel(for item: CopyPlanItem) -> String {
        if item.status == .skipped {
            return "already in destination"
        }
        return item.status.rawValue
    }

    private var footer: some View {
        VStack(spacing: 10) {
            ProgressView(value: viewModel.copyProgress.fraction)
                .progressViewStyle(.linear)
                .transaction { transaction in
                    transaction.animation = nil
                }
            HStack {
                Text(viewModel.copyProgress.percentText)
                    .font(.headline.monospacedDigit())
                Text(viewModel.copyProgress.filesText)
                    .foregroundStyle(.secondary)
                if !viewModel.copyProgress.speedText.isEmpty {
                    Text(viewModel.copyProgress.speedText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if !viewModel.copyProgress.estimatedRemainingText.isEmpty {
                    Text(viewModel.copyProgress.estimatedRemainingText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(viewModel.copyProgress.currentFile)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.openOutputDirectory()
                } label: {
                    Label("Open Folder", systemImage: "folder.fill")
                }
                .disabled(viewModel.destinationURL == nil)

                if viewModel.copyProgress.isRunning {
                    Button {
                        viewModel.cancelCopy()
                    } label: {
                        Label("Stop Downloading", systemImage: "stop.circle")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        viewModel.startCopy()
                    } label: {
                        Label(downloadButtonTitle, systemImage: "arrow.down.doc")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.destinationURL == nil || (viewModel.copyPlan?.items.isEmpty ?? true))
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var downloadButtonTitle: String {
        if viewModel.destinationURL == nil {
            return "Choose Folder First"
        }
        if viewModel.selectedQueueItemIDs.isEmpty {
            return "Download Footage"
        }
        return "Download Selected"
    }

    private func countChips(title: String, counts: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
            FlowLayout(spacing: 8) {
                ForEach(counts, id: \.0) { name, count in
                    Text("\(name) \(count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func confidenceColor(_ confidence: DetectionConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .yellow
        case .none: return .secondary
        }
    }
}

struct FeedbackSheet: View {
    @ObservedObject var viewModel: TransferViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: FeedbackKind = .bug
    @State private var message = ""
    @State private var contact = ""
    @State private var includeScan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Submit Feedback")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            Picker("Type", selection: $kind) {
                ForEach(FeedbackKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            TextEditor(text: $message)
                .font(.body)
                .frame(minHeight: 150)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                }

            TextField("Contact email or handle (optional)", text: $contact)
                .textFieldStyle(.roundedBorder)

            Toggle("Include anonymous scan statistics", isOn: $includeScan)
                .disabled(!viewModel.scanSummary.hasScan)

            Text("Optional statistics exclude source names, folder paths, and filenames.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.scanSummary.hasScan {
                HStack(spacing: 14) {
                    Label("\(viewModel.scanSummary.scannedFiles) scanned", systemImage: "doc")
                    Label("\(viewModel.scanSummary.copyableItems) downloadable", systemImage: "checkmark.circle")
                    Label(viewModel.selectedProfile?.displayName ?? "No profile selected", systemImage: "camera")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Link("Privacy Policy", destination: AppLinks.privacyPolicyURL)
                .font(.caption)

            if !viewModel.feedbackMessage.isEmpty {
                Text(viewModel.feedbackMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.feedbackMessage.contains("failed") ? .red : .secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button {
                    viewModel.submitFeedback(
                        kind: kind,
                        message: message,
                        contact: contact,
                        includeScan: includeScan && viewModel.scanSummary.hasScan
                    )
                } label: {
                    Label(viewModel.isSubmittingFeedback ? "Submitting" : "Submit", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmittingFeedback || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
        .onAppear {
            includeScan = false
            viewModel.feedbackMessage = ""
        }
    }
}

struct CardLearningSheet: View {
    @ObservedObject var viewModel: TransferViewModel
    var selectedBrand: String?
    var selectedCatalogModel: CameraModelChoice?
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var selectedChannelCount = 1
    @State private var channelDescription = ""
    @State private var notes = ""
    @State private var contact = ""

    private var canSubmit: Bool {
        viewModel.scanSummary.hasScan &&
            !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.isSubmittingFeedback
    }

    private var channelSetup: String {
        let description = channelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(selectedChannelCount)CH: \(description.isEmpty ? channelPlaceholder : description)"
    }

    private var channelPlaceholder: String {
        let inferred = viewModel.inferredLearningChannelSetup
        if inferred.count == selectedChannelCount, !inferred.description.isEmpty {
            return inferred.description
        }
        return viewModel.defaultLearningChannelDescription(for: selectedChannelCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Improve Camera Support")
                    .font(.title2.bold())
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            if viewModel.scanSummary.hasScan {
                HStack(spacing: 14) {
                    Label("Card scan ready", systemImage: "checkmark.circle")
                    Label(viewModel.selectedProfile?.displayName ?? "No profile match", systemImage: "camera")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Scan the card first, then submit the learning package.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Use this for a new camera, or for a known camera with a setup we have not seen yet, like different channels, parking modes, resolution options, or bitrate settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Manufacturer", text: $manufacturer)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Camera channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 10) {
                    Picker("Camera channels", selection: $selectedChannelCount) {
                        ForEach(1...4, id: \.self) { count in
                            Text("\(count)CH").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Camera channels")
                    .frame(width: 220, alignment: .leading)

                    TextField(channelPlaceholder, text: $channelDescription)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Choose the number of camera views, then describe them however the camera uses them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Examples: front / rear, front / interior / telephoto, front / interior / rear / telephoto, 360 interior.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Anything else we should know? (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 92)
                    if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Examples: parking mode is enabled, one camera is disconnected, or the camera clock is wrong.")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                }
            }

            TextField("Contact email or handle (optional)", text: $contact)
                .textFieldStyle(.roundedBorder)

            Text("This sends only a sanitized description of the card structure so we can add support for your camera. It does not upload your videos, photos, GPS traces, serial numbers, Wi-Fi details, device IDs, or other personally identifying information.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("Privacy Policy", destination: AppLinks.privacyPolicyURL)
                .font(.caption)

            if !viewModel.feedbackMessage.isEmpty {
                Text(viewModel.feedbackMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.feedbackMessage.contains("failed") ? .red : .secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    close()
                }
                Button {
                    submitLearningPackage()
                } label: {
                    Label(viewModel.isSubmittingFeedback ? "Submitting" : "Submit Learning Package", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding(24)
        .frame(width: 620)
        .onAppear {
            viewModel.feedbackMessage = ""
            prefillFromScanIfNeeded()
        }
    }

    private func prefillFromScanIfNeeded() {
        let inferred = viewModel.inferredLearningChannelSetup
        selectedChannelCount = inferred.count

        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id {
            if let selectedCatalogModel {
                if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    manufacturer = selectedCatalogModel.brand
                }
                if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model = selectedCatalogModel.model
                }
                return
            }
            if let identity = viewModel.inferredLearningCameraIdentity {
                if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    manufacturer = identity.manufacturer
                }
                if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model = identity.model
                }
                return
            }
            if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let selectedBrand,
               selectedBrand != DashcamProfile.genericNewDashcam.displayManufacturer {
                manufacturer = selectedBrand
            }
            return
        }

        guard let profile = viewModel.selectedProfile else { return }

        if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            manufacturer = profile.manufacturer
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model = profile.model
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func submitLearningPackage() {
        let training = CardTrainingDetails(
            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            channelSetup: channelSetup,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let message = [
            "Camera: \(training.manufacturer) \(training.model)",
            "Camera channels: \(training.channelSetup)",
            learningScanSummary(),
            training.notes.isEmpty ? "" : "User notes: \(training.notes)"
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")

        viewModel.submitFeedback(
            kind: .training,
            message: message,
            contact: contact,
            includeScan: true,
            training: training,
            successMessage: "Learning package submitted successfully.",
            onSuccess: {
                close()
            }
        )
    }

    private func learningScanSummary() -> String {
        guard viewModel.scanSummary.hasScan else {
            return "App scan: No card scan available"
        }

        let selectedName = viewModel.selectedProfile?.displayName ?? "No profile selected"
        let selectedID = viewModel.selectedProfile?.id ?? "none"
        guard let topCandidate = viewModel.detectionCandidates.first else {
            return "App scan: \(selectedName) (\(selectedID)); no profile candidates"
        }

        let topLine = "top candidate \(topCandidate.profile.displayName), \(topCandidate.confidence.rawValue), score \(topCandidate.score)"
        if selectedID == DashcamProfile.genericNewDashcam.id {
            return "App scan: New/unrecognized card; rejected \(topLine)"
        }

        return "App scan: \(selectedName) (\(selectedID)); \(topLine)"
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if maxWidth > 0, currentX > 0, currentX + size.width > maxWidth {
                currentY += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            totalWidth = max(totalWidth, currentX + size.width)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth > 0 ? maxWidth : totalWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
