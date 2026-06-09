import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: TransferViewModel
    @State private var isFeedbackPresented = false
    @State private var isCardLearningPresented = false

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
            .help("Refresh mounted memory cards and dashcam sources")
            Button {
                viewModel.chooseDestinationFolder()
            } label: {
                Label("Destination", systemImage: "folder")
            }
            .help("Choose where copied videos will be saved")
            Button {
                isFeedbackPresented = true
            } label: {
                Label("Feedback", systemImage: "bubble.left.and.bubble.right")
            }
            .help("Submit a bug report, feature request, or app feedback")
            Button {
                isCardLearningPresented = true
            } label: {
                Label("Learn Card", systemImage: "graduationcap")
            }
            .help("Send sanitized card details to help add or improve dashcam support")
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
                Label("Choose MicroSD Card...", systemImage: "externaldrive")
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
                Label(viewModel.isScanning ? "Scanning" : "Rescan Source", systemImage: "waveform.path.ecg")
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
        GroupBox("Source Scan") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedSource?.displayPath ?? "No source selected")
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Text("Choosing a source scans it automatically.")
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
                        Label("\(viewModel.scanSummary.copyableItems) copyable", systemImage: "checkmark.circle")
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
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }

    private var detectionSection: some View {
        GroupBox("Camera Profile") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.profiles.isEmpty {
                    Text("No profiles loaded")
                        .foregroundStyle(.secondary)
                } else {
                    if let identified = viewModel.identifiedCamera, !identified.isSupported {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("New Dashcam: \(identified.displayName)", systemImage: "sparkles")
                                .font(.headline)
                            Text("This card has exact model metadata, but there is not a supported profile yet. Submit a learning package so it can be added without guessing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                isCardLearningPresented = true
                            } label: {
                                Label("Submit Learning Package", systemImage: "paperplane")
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack {
                        Text("Selected Profile")
                            .font(.headline)
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
                                Text(viewModel.selectedProfile?.displayName ?? viewModel.identifiedCamera.map { "New Dashcam - \($0.displayName)" } ?? "Choose Profile")
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                            .frame(minWidth: 220, alignment: .trailing)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
            }
            .padding(8)
        }
    }

    private var destinationSection: some View {
        GroupBox("Destination") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.destinationURL?.path ?? "No output directory selected")
                        .lineLimit(1)
                    Text("Source cards are never modified. Copies go only to this folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("Video filename suffix")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "Optional text appended before the extension",
                            text: Binding(
                                get: { viewModel.outputNamingOptions.videoFilenameSuffix },
                                set: { viewModel.setVideoFilenameSuffix($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Open destination when copy completes", isOn: $viewModel.openDestinationWhenComplete)
                            .disabled(viewModel.destinationURL == nil)
                        Toggle("Eject card when copy completes", isOn: $viewModel.ejectSourceWhenComplete)
                            .disabled(viewModel.selectedSource == nil)
                    }
                    .font(.caption)
                }
                Spacer()
                HStack {
                    Button {
                        viewModel.openOutputDirectory()
                    } label: {
                        Label("Open Directory", systemImage: "folder.fill")
                    }
                    .disabled(viewModel.destinationURL == nil)

                    Button {
                        viewModel.chooseDestinationFolder()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                }
            }
            .padding(8)
        }
    }

    private var filtersSection: some View {
        GroupBox("Filters") {
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
                Toggle("Separate output folders for driving, parking, protected, photos, and GPS", isOn: Binding(
                    get: { viewModel.filters.separateCategoryFolders },
                    set: { viewModel.filters.separateCategoryFolders = $0; viewModel.rebuildPlan() }
                ))
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
        GroupBox("Copy Plan") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(viewModel.copyPlan?.selectedFileCount ?? 0) files")
                    Text(viewModel.copyPlan?.selectedBytes.formattedBytes ?? "0 bytes")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.rebuildPlan()
                    } label: {
                        Label("Preview", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(viewModel.destinationURL == nil || viewModel.selectedProfile == nil)
                }

                Table(viewModel.copyPlan?.items.prefix(250).map { $0 } ?? []) {
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
                    TableColumn("Destination") { item in
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
                    Label("Open Directory", systemImage: "folder.fill")
                }
                .disabled(viewModel.destinationURL == nil)

                Button {
                    viewModel.startCopy()
                } label: {
                    Label("Copy Selected", systemImage: "arrow.down.doc")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.copyPlan?.items.isEmpty ?? true || viewModel.copyProgress.isRunning)
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
                ForEach(FeedbackKind.generalFeedbackCases, id: \.self) { kind in
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
                    Label("\(viewModel.scanSummary.copyableItems) copyable", systemImage: "checkmark.circle")
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
    @State private var channelSetup = ""
    @State private var notes = ""
    @State private var contact = ""

    private var canSubmit: Bool {
        viewModel.scanSummary.hasScan &&
            !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !channelSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.isSubmittingFeedback
    }

    private var learningSnapshot: FeedbackScanSnapshot? {
        viewModel.makeFeedbackScanSnapshot()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Teach a New Card")
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
                    Label("\(viewModel.scanSummary.scannedFiles) scanned", systemImage: "doc")
                    Label("\(viewModel.scanSummary.copyableItems) copyable", systemImage: "checkmark.circle")
                    Label(viewModel.selectedProfile?.displayName ?? viewModel.identifiedCamera.map { "New Dashcam: \($0.displayName)" } ?? "No profile match", systemImage: "camera")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Scan the card first, then submit the learning package.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Manufacturer", text: $manufacturer)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Channel setup, e.g. front/rear/interior or 3CH", text: $channelSetup)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $notes)
                .font(.body)
                .frame(minHeight: 120)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                }

            TextField("Contact email or handle (optional)", text: $contact)
                .textFieldStyle(.roundedBorder)

            Text("Sends folder names, filename samples, candidate scores, and counts. It does not upload video files, GPS traces, or unique device IDs.")
                .font(.caption)
                .foregroundStyle(.secondary)

            learningPackagePreview

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
            if let identified = viewModel.identifiedCamera {
                manufacturer = identified.displayManufacturer
                model = identified.model
                if channelSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    channelSetup = "Unknown"
                }
                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notes = "Auto-identified from card metadata as \(identified.displayName)."
                }
            }
        }
    }

    private func submitLearningPackage() {
        let training = CardTrainingDetails(
            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            channelSetup: channelSetup.trimmingCharacters(in: .whitespacesAndNewlines),
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
            training: training
        )
    }

    @ViewBuilder
    private var learningPackagePreview: some View {
        if let snapshot = learningSnapshot {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    Label("\(snapshot.sampleRelativePaths.count) sample paths", systemImage: "list.bullet.rectangle")
                    Label("\(snapshot.filenameSamples.count) filename samples", systemImage: "text.page")
                    Label("\(snapshot.settingSnapshots.count) settings files", systemImage: "gearshape")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if snapshot.sampleRelativePaths.isEmpty {
                    Text("No safe sample paths were selected from this scan. Rescan the card before submitting so the learning package includes useful file examples.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("The app selects safe examples automatically. These are path names only, not uploaded video files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(snapshot.sampleRelativePaths.prefix(12)), id: \.self) { path in
                                Text(path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 96)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
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
