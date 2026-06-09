import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: TransferViewModel
    @State private var isFeedbackPresented = false
    @State private var isCardLearningPresented = false
    @State private var showDownloadOptions = false
    @State private var showDownloadFilters = false

    var body: some View {
        NavigationSplitView {
            sourceList
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            mainPanel
        }
        .toolbar {
            Button {
                viewModel.refreshSources()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button {
                viewModel.chooseDestinationFolder()
            } label: {
                Label("Download Folder", systemImage: "folder")
            }
            Button {
                isFeedbackPresented = true
            } label: {
                Label("Feedback", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isCardLearningPresented) {
            CardLearningSheet(viewModel: viewModel)
        }
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources")
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top)

            Button {
                viewModel.chooseSourceFolder()
            } label: {
                Label("Choose Memory Card...", systemImage: "externaldrive")
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

            Text(viewModel.showAllVolumes ? "Showing all mounted volumes." : "Only showing locations that look like dashcam footage sources.")
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
                    .padding(.horizontal)
                }
            }

            Button {
                viewModel.scanSelectedSource()
            } label: {
                Label(viewModel.isScanning ? "Scanning" : "Rescan Card", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedSource == nil || viewModel.isScanning)
            .padding([.horizontal, .bottom])
        }
    }

    private func sourceRow(_ source: MountedSource) -> some View {
        let isSelected = viewModel.selectedSource == source
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
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    workflowSection
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
        GroupBox("1. Pick Your Memory Card") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedSource?.displayPath ?? "No source selected")
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Text("Choose the card from your dashcam. The app only reads from the card and never changes it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.chooseSourceFolder()
                    } label: {
                        Label("Choose", systemImage: "externaldrive")
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
                title: "Pick card",
                detail: viewModel.selectedSource?.name ?? "Choose the memory card",
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

                    HStack {
                        Spacer()
                        Menu {
                            ForEach(viewModel.profilesByBrand, id: \.brand) { group in
                                Menu(group.brand) {
                                    ForEach(group.profiles) { profile in
                                        Button(profile.model) {
                                            viewModel.selectProfile(profile)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedProfile?.displayName ?? "Choose Profile")
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                            .frame(minWidth: 220, alignment: .trailing)
                        }
                        .menuStyle(.borderlessButton)
                    }

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
                                isCardLearningPresented = true
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

    private var shouldShowLearnCardPrompt: Bool {
        viewModel.scanSummary.hasScan
    }

    private var learnCardPromptTitle: String {
        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id || viewModel.selectedProfile == nil {
            return "Help add support for this card"
        }
        return "Help improve this camera profile"
    }

    private var learnCardPromptDetail: String {
        if viewModel.selectedProfile?.id == DashcamProfile.genericNewDashcam.id || viewModel.selectedProfile == nil {
            return "Optional. Downloading your footage still works first."
        }
        return "Optional. Share sanitized setup details for different channels, parking modes, resolutions, or bitrate settings."
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

                DisclosureGroup("Download options", isExpanded: $showDownloadOptions) {
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

                DisclosureGroup("Filters and extras", isExpanded: $showDownloadFilters) {
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

                        checkboxGrid(title: "Recording Types", values: viewModel.availableModes, selected: $viewModel.filters.selectedModes) {
                            ClipItem.displayLabel(for: $0)
                        }
                        checkboxGrid(title: "Channels", values: viewModel.availableChannels, selected: $viewModel.filters.selectedChannels) {
                            ClipItem.displayLabel(for: $0)
                        }

                        Divider()

                        Toggle("Include photos", isOn: Binding(
                            get: { viewModel.filters.includePhotos },
                            set: { viewModel.filters.includePhotos = $0; viewModel.rebuildPlan() }
                        ))
                        Toggle("Include GPS logs", isOn: Binding(
                            get: { viewModel.filters.includeGPS },
                            set: { viewModel.filters.includeGPS = $0; viewModel.rebuildPlan() }
                        ))
                        Text("Separate GPS files are copied when the card exposes them. Cameras that embed GPS in video files keep that data with the clip.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("Copy camera settings and boot logs", isOn: Binding(
                            get: { viewModel.filters.includeCameraSettings },
                            set: { viewModel.filters.includeCameraSettings = $0; viewModel.rebuildPlan() }
                        ))
                        Text("Copies Config/Settings folders and boot logs into a separate Camera Settings folder for troubleshooting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("Separate folders for driving, parking, protected, photos, and GPS", isOn: Binding(
                            get: { viewModel.filters.separateCategoryFolders },
                            set: { viewModel.filters.separateCategoryFolders = $0; viewModel.rebuildPlan() }
                        ))
                        Text("When off, files copy directly into the chosen download folder. The app no longer creates model, date, or channel folders by default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(8)
            .onChange(of: viewModel.filters.selectedModes) { _, _ in viewModel.rebuildPlan() }
            .onChange(of: viewModel.filters.selectedChannels) { _, _ in viewModel.rebuildPlan() }
        }
    }

    private func checkboxGrid(title: String, values: [String], selected: Binding<Set<String>>, display: @escaping (String) -> String) -> some View {
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

                Table(viewModel.copyPlan?.items.prefix(250).map { $0 } ?? [], selection: $viewModel.selectedQueueItemIDs) {
                    TableColumn("File") { item in
                        Text(item.clip.filename)
                            .lineLimit(1)
                    }
                    TableColumn("Source") { item in
                        Text(item.clip.relativePath)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    TableColumn("Mode") { item in
                        Text(item.clip.displayMode)
                    }
                    TableColumn("Folder") { item in
                        Text(item.clip.outputCategory)
                    }
                    TableColumn("Channel") { item in
                        Text(item.clip.displayChannel)
                    }
                    TableColumn("Download Folder") { item in
                        Text(item.destinationURL.path)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    TableColumn("Size") { item in
                        Text(item.clip.size.formattedBytes)
                    }
                }
                .frame(minHeight: 220)
            }
            .padding(8)
        }
    }

    private var resultsSection: some View {
        Group {
            if !viewModel.copyResults.isEmpty {
                GroupBox("Last Run") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.copyResults.prefix(10)) { item in
                            HStack {
                                Text(item.clip.filename).lineLimit(1)
                                Spacer()
                                Text(item.status.rawValue)
                                    .foregroundStyle(item.status == .failed ? .red : .secondary)
                            }
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
                        Label(viewModel.destinationURL == nil ? "Choose Folder First" : "Download Footage", systemImage: "arrow.down.doc")
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

            Toggle("Include sanitized scan summary", isOn: $includeScan)
                .disabled(!viewModel.scanSummary.hasScan)

            if viewModel.scanSummary.hasScan {
                HStack(spacing: 14) {
                    Label("\(viewModel.scanSummary.scannedFiles) scanned", systemImage: "doc")
                    Label("\(viewModel.scanSummary.copyableItems) downloadable", systemImage: "checkmark.circle")
                    Label(viewModel.selectedProfile?.displayName ?? "No profile selected", systemImage: "camera")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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
            includeScan = viewModel.scanSummary.hasScan
            viewModel.feedbackMessage = ""
        }
    }
}

struct CardLearningSheet: View {
    @ObservedObject var viewModel: TransferViewModel
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
            !channelDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.isSubmittingFeedback
    }

    private var channelSetup: String {
        return "\(selectedChannelCount)CH: \(channelDescription.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Improve Camera Support")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
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
                    .frame(width: 220, alignment: .leading)
                    .onChange(of: selectedChannelCount) { _, newValue in
                        updateChannelDescription(for: newValue)
                    }

                    TextField("Front / rear", text: $channelDescription)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Choose the number of camera views, then describe them however the camera uses them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Examples: front / rear, front / cabin / telephoto, front / front interior / rear / rear interior, 360 exterior.")
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
        if channelDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            channelDescription = inferred.description
        }

        guard let profile = viewModel.selectedProfile,
              profile.id != DashcamProfile.genericNewDashcam.id else { return }

        if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            manufacturer = profile.manufacturer
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model = profile.model
        }
    }

    private func updateChannelDescription(for count: Int) {
        guard channelDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        switch count {
        case 1:
            channelDescription = "Front"
        case 2:
            channelDescription = "Front / rear"
        case 3:
            channelDescription = "Front / cabin / rear"
        case 4:
            channelDescription = "Front / front interior / rear / rear interior"
        default:
            channelDescription = ""
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
            "\(training.manufacturer) \(training.model)",
            "Channels: \(training.channelSetup)",
            training.notes
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
                dismiss()
            }
        )
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
