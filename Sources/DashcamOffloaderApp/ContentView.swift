import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: TransferViewModel

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
                Label("Destination", systemImage: "folder")
            }
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

            if viewModel.mountedSources.isEmpty {
                Text("No mounted sources found. Choose a card or folder manually.")
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
                Label(viewModel.isScanning ? "Scanning" : "Scan Source", systemImage: "waveform.path.ecg")
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
                        Text("Choose a microSD card or mounted folder, then scan it before copying.")
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

                    if !viewModel.scanSummary.samplePaths.isEmpty {
                        Text("Sample files from this source")
                            .font(.caption.bold())
                        ForEach(viewModel.scanSummary.samplePaths, id: \.self) { path in
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
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
        GroupBox("Camera") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.profiles.isEmpty {
                    Text("No profiles loaded")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Selected profile", selection: Binding(
                        get: { viewModel.selectedProfile },
                        set: { profile in
                            if let profile {
                                viewModel.selectProfile(profile)
                            }
                        }
                    )) {
                        ForEach(viewModel.profiles) { profile in
                            Text(profile.displayName).tag(Optional(profile))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if !viewModel.detectionCandidates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection candidates")
                            .font(.headline)
                        ForEach(viewModel.detectionCandidates.prefix(4)) { candidate in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.profile.displayName)
                                        .font(.subheadline.bold())
                                    Text(candidate.evidence.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(candidate.confidence.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(confidenceColor(candidate.confidence).opacity(0.16))
                                    .foregroundStyle(confidenceColor(candidate.confidence))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
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
                }
                Spacer()
                Button {
                    viewModel.chooseDestinationFolder()
                } label: {
                    Label("Choose", systemImage: "folder")
                }
            }
            .padding(8)
        }
    }

    private var filtersSection: some View {
        GroupBox("Filters") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Start date", isOn: Binding(
                    get: { viewModel.filters.useStartDate },
                    set: { viewModel.filters.useStartDate = $0; viewModel.rebuildPlan() }
                ))
                if viewModel.filters.useStartDate {
                    DatePicker("From", selection: Binding(
                        get: { viewModel.filters.startDate },
                        set: { viewModel.filters.startDate = $0; viewModel.rebuildPlan() }
                    ), displayedComponents: .date)
                }

                Toggle("End date", isOn: Binding(
                    get: { viewModel.filters.useEndDate },
                    set: { viewModel.filters.useEndDate = $0; viewModel.rebuildPlan() }
                ))
                if viewModel.filters.useEndDate {
                    DatePicker("Through", selection: Binding(
                        get: { viewModel.filters.endDate },
                        set: { viewModel.filters.endDate = $0; viewModel.rebuildPlan() }
                    ), displayedComponents: .date)
                }

                Divider()

                checkboxGrid(title: "Recording Types", values: viewModel.availableModes, selected: $viewModel.filters.selectedModes)
                checkboxGrid(title: "Channels", values: viewModel.availableChannels, selected: $viewModel.filters.selectedChannels)

                Divider()

                Toggle("Include photos", isOn: Binding(
                    get: { viewModel.filters.includePhotos },
                    set: { viewModel.filters.includePhotos = $0; viewModel.rebuildPlan() }
                ))
                Toggle("Include GPS logs", isOn: Binding(
                    get: { viewModel.filters.includeGPS },
                    set: { viewModel.filters.includeGPS = $0; viewModel.rebuildPlan() }
                ))
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

    private func checkboxGrid(title: String, values: [String], selected: Binding<Set<String>>) -> some View {
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
                        Toggle(value, isOn: Binding(
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
                    Text("\(viewModel.copyPlan?.items.count ?? 0) files")
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
                        Text(item.clip.mode)
                    }
                    TableColumn("Folder") { item in
                        Text(item.clip.outputCategory)
                    }
                    TableColumn("Channel") { item in
                        Text(item.clip.channel)
                    }
                    TableColumn("Destination") { item in
                        Text(item.destinationURL.deletingLastPathComponent().path)
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
            HStack {
                Text(viewModel.copyProgress.percentText)
                    .font(.headline.monospacedDigit())
                Text(viewModel.copyProgress.currentFile)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
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

    private func confidenceColor(_ confidence: DetectionConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .yellow
        case .none: return .secondary
        }
    }
}
