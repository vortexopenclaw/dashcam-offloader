import SwiftUI

struct CameraLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let references: [CameraReference]
    @State private var searchText = ""
    @State private var selectedID: String?

    init(references: [CameraReference], initialSelectionID: String? = nil) {
        self.references = references
        _selectedID = State(initialValue: initialSelectionID ?? references.first?.id)
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera Library")
                        .font(.title2.bold())
                    Text("\(references.count) camera reference entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()

                List(selection: $selectedID) {
                    ForEach(groupedReferences, id: \.manufacturer) { group in
                        Section(group.manufacturer) {
                            ForEach(group.cameras) { reference in
                                cameraRow(reference)
                                    .tag(reference.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 310)
        } detail: {
            if let selectedReference {
                cameraDetail(selectedReference)
            } else {
                ContentUnavailableView(
                    "No camera selected",
                    systemImage: "video",
                    description: Text("Choose a researched camera from the library.")
                )
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Brand, model, folder, or mode")
        .toolbar {
            Button("Close") { dismiss() }
        }
        .frame(minWidth: 1120, minHeight: 740)
        .onChange(of: searchText) { _, _ in
            if selectedReference == nil {
                selectedID = filteredReferences.first?.id
            }
        }
    }

    private var filteredReferences: [CameraReference] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return references }
        return references.filter { reference in
            let searchable = [
                reference.displayName,
                reference.status,
                reference.confidence,
                reference.folders.map(\.path).joined(separator: " "),
                reference.folders.map(\.mode).joined(separator: " "),
                reference.filenamePatterns.map(\.pattern).joined(separator: " "),
                reference.videoSamples.map { "\($0.channel) \($0.mode) \($0.codec) \($0.resolution) \($0.bitrate)" }.joined(separator: " ")
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    private var groupedReferences: [(manufacturer: String, cameras: [CameraReference])] {
        let grouped = Dictionary(grouping: filteredReferences, by: \.displayManufacturer)
        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { manufacturer in
            (manufacturer, grouped[manufacturer, default: []])
        }
    }

    private var selectedReference: CameraReference? {
        guard let selectedID else { return nil }
        return references.first { $0.id == selectedID }
    }

    private func cameraRow(_ reference: CameraReference) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(reference.model)
                .fontWeight(.medium)
            HStack(spacing: 5) {
                Text(reference.evidenceLabel)
                if !reference.parkingFolders.isEmpty {
                    Text("• Parking")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func cameraDetail(_ reference: CameraReference) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cameraHeader(reference)

                if let confidenceNote = reference.confidenceNote {
                    referenceCallout(confidenceNote)
                }

                if !reference.channelVariants.isEmpty {
                    referenceSection("Camera configurations", systemImage: "camera.on.rectangle") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(reference.channelVariants.enumerated()), id: \.offset) { _, variant in
                                channelVariantRow(variant)
                            }
                        }
                    }
                }

                if !reference.drivingFolders.isEmpty {
                    referenceSection("Driving recordings", systemImage: "car") {
                        folderList(reference.drivingFolders)
                    }
                }

                if !reference.parkingFolders.isEmpty || !reference.parkingRecordingModes.isEmpty {
                    referenceSection("Parking recordings", systemImage: "parkingsign.circle") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !reference.parkingRecordingModes.isEmpty {
                                labeledValue("Documented modes", reference.parkingRecordingModes.map(displayLabel).joined(separator: ", "))
                            }
                            folderList(reference.parkingFolders)
                        }
                    }
                }

                if !reference.otherFolders.isEmpty {
                    referenceSection("Photos, GPS, and support folders", systemImage: "folder") {
                        folderList(reference.otherFolders)
                    }
                }

                if !reference.filenamePatterns.isEmpty {
                    referenceSection("Filename conventions", systemImage: "textformat.abc") {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(reference.filenamePatterns.enumerated()), id: \.offset) { _, pattern in
                                filenamePatternCard(pattern)
                            }
                        }
                    }
                }

                if !reference.videoSamples.isEmpty {
                    referenceSection("Measured video samples", systemImage: "film.stack") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(reference.videoSamples.enumerated()), id: \.offset) { _, sample in
                                videoSampleCard(sample)
                            }
                        }
                    }
                }

                if !reference.technicalFacts.isEmpty {
                    referenceSection("Video and recording specifications", systemImage: "waveform.path.ecg.rectangle") {
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(Array(reference.technicalFacts.enumerated()), id: \.offset) { _, fact in
                                labeledValue(displayFactPath(fact.label), displayLabel(fact.value))
                            }
                        }
                    }
                }

                if !reference.notes.isEmpty {
                    referenceSection("Known caveats", systemImage: "exclamationmark.bubble") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(reference.notes, id: \.self) { note in
                                Text("• \(note)")
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                referenceSection("Manuals and research sources", systemImage: "book.closed") {
                    if reference.sourceLinks.isEmpty {
                        Text("No direct source link is recorded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(reference.sourceLinks, id: \.url) { link in
                                if let destination = link.destination {
                                    Link(destination: destination) {
                                        Label(link.label, systemImage: link.kind == "manual" ? "doc.text" : "arrow.up.right.square")
                                    }
                                }
                            }
                        }
                    }
                }

                Text("Only documented or observed details are shown. Settings, firmware, regions, and channel configurations can change the files a camera records.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(28)
        }
        .navigationTitle(reference.displayName)
    }

    private func cameraHeader(_ reference: CameraReference) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reference.displayManufacturer.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(reference.model)
                .font(.largeTitle.bold())
            HStack(spacing: 8) {
                statusBadge(reference.evidenceLabel, color: .blue)
                statusBadge("Confidence: \(displayLabel(reference.confidence))", color: .secondary)
                if !reference.manualLinks.isEmpty {
                    statusBadge("Manual linked", color: .green)
                }
            }
            HStack(spacing: 8) {
                coverageBadge("Folder map", available: !reference.folders.isEmpty)
                coverageBadge("Filename rules", available: !reference.filenamePatterns.isEmpty)
                coverageBadge("Measured video", available: !reference.videoSamples.isEmpty)
                coverageBadge("Manual", available: !reference.manualLinks.isEmpty)
            }
            .padding(.top, 2)
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func coverageBadge(_ label: String, available: Bool) -> some View {
        Label(label, systemImage: available ? "checkmark.circle.fill" : "circle.dashed")
            .font(.caption)
            .foregroundStyle(available ? Color.green : Color.secondary)
    }

    private func referenceCallout(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.blue)
            Text(text)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func referenceSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
    }

    private func folderList(_ folders: [CameraReferenceFolder]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(folders, id: \.path) { folder in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(folder.path)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Text(displayLabel(folder.mode))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(folder.importable ? Color.primary : Color.secondary)
                    }
                    if let validation = folder.validation {
                        Text("Evidence: \(displayLabel(validation))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(folder.notes, id: \.self) { note in
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func filenamePatternCard(_ pattern: CameraReferenceFilenamePattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pattern.pattern)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            if !pattern.appliesTo.isEmpty {
                labeledValue("Folders", pattern.appliesTo.joined(separator: ", "))
            }
            if let timestampFormat = pattern.timestampFormat {
                labeledValue("Timestamp", timestampFormat)
            }
            if !pattern.modes.isEmpty {
                labeledValue("Recording tokens", formattedMap(pattern.modes))
            }
            if !pattern.channels.isEmpty {
                labeledValue("Channel tokens", formattedMap(pattern.channels))
            } else if let defaultChannel = pattern.defaultChannel {
                labeledValue("Channel", displayLabel(defaultChannel))
            }
        }
    }

    private func videoSampleCard(_ sample: CameraReferenceVideoSample) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(sample.channel)
                    .font(.headline)
                Text(displayLabel(sample.mode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(sample.source.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text([sample.codec, sample.resolution, "\(sample.fps) FPS", sample.bitrate]
                .filter { !$0.isEmpty && $0 != "—" }
                .joined(separator: "  •  "))
                .textSelection(.enabled)
            if !sample.container.isEmpty && sample.container != "—" {
                Text(sample.container)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func channelVariantRow(_ variant: CameraReferenceChannelVariant) -> some View {
        let channelText = variant.channels.map { "\($0)-channel" } ?? "Channel count not recorded"
        let variantText = variant.variant.map { " • \($0)" } ?? ""
        let roles = variant.roles.isEmpty ? "Positions not recorded" : variant.roles.map(displayLabel).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 3) {
            Text(channelText + variantText)
                .fontWeight(.medium)
            Text(roles)
                .foregroundStyle(.secondary)
            if let validation = variant.validation {
                Text("Evidence: \(displayLabel(validation))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14) {
            GridRow {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 180, alignment: .leading)
                Text(value)
                    .textSelection(.enabled)
            }
        }
    }

    private func formattedMap(_ values: [String: String]) -> String {
        values.keys.sorted().map { "\($0) = \(displayLabel(values[$0] ?? ""))" }.joined(separator: ", ")
    }

    private func displayFactPath(_ value: String) -> String {
        value.split(separator: "›")
            .map { displayLabel(String($0).trimmingCharacters(in: .whitespaces)) }
            .joined(separator: " › ")
    }

    private func displayLabel(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lowered = word.lowercased()
                if ["fps", "gps", "hdr", "hevc", "h264", "h265", "mp4", "qhd", "fhd"].contains(lowered) {
                    return lowered.uppercased()
                }
                return word.prefix(1).uppercased() + String(word.dropFirst())
            }
            .joined(separator: " ")
    }
}
