import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: TransferViewModel
    @StateObject private var updateViewModel = UpdateViewModel()
    @State private var isShowingUpdates = false

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
            Button {
                isShowingUpdates = true
                updateViewModel.checkForUpdates()
            } label: {
                Label("Updates", systemImage: "arrow.down.circle")
            }
        }
        .sheet(isPresented: $isShowingUpdates) {
            updateSheet
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

            Text(viewModel.showAllVolumes ? "Showing all mounted volumes." : "Hiding Time Machine, backups, system volumes, and folders without dashcam-like media.")
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
                                Text(viewModel.selectedProfile?.displayName ?? "Choose Profile")
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
                        Text(item.clip.displayMode)
                    }
                    TableColumn("Folder") { item in
                        Text(item.clip.outputCategory)
                    }
                    TableColumn("Channel") { item in
                        Text(item.clip.displayChannel)
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
                .transaction { transaction in
                    transaction.animation = nil
                }
            HStack {
                Text(viewModel.copyProgress.percentText)
                    .font(.headline.monospacedDigit())
                Text(viewModel.copyProgress.filesText)
                    .foregroundStyle(.secondary)
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

    private var updateSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Updates")
                        .font(.title2.bold())
                    Text(updateViewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if updateViewModel.isChecking || updateViewModel.isDownloading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let info = updateViewModel.info {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Current version \(info.currentVersion)", systemImage: "app.badge")
                    Label("Latest version \(info.latestVersion)", systemImage: info.isNewer ? "sparkles" : "checkmark.circle")
                    Label(info.releaseName, systemImage: "tag")
                    if let assetName = info.assetName {
                        Label(assetName, systemImage: "archivebox")
                    } else {
                        Label("No app download asset found", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
            } else {
                Text("Check GitHub Releases for the newest Dashcam Offloader build.")
                    .foregroundStyle(.secondary)
            }

            Text("Downloads are opened by macOS after they finish. For current unsigned prototype builds, replace the existing app with the downloaded app bundle when prompted.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    updateViewModel.checkForUpdates()
                } label: {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(updateViewModel.isChecking || updateViewModel.isDownloading)

                Spacer()

                Button {
                    isShowingUpdates = false
                } label: {
                    Text("Close")
                }

                Button {
                    if updateViewModel.info?.assetDownloadURL == nil {
                        updateViewModel.openReleasePage()
                    } else {
                        updateViewModel.downloadAndInstall()
                    }
                } label: {
                    Label(updateViewModel.info?.primaryActionTitle ?? "Open Release Page", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateViewModel.info == nil || updateViewModel.isChecking || updateViewModel.isDownloading)
            }
        }
        .padding(24)
        .frame(width: 520)
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
