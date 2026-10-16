import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CardHealthFileEvidence: Hashable, Sendable {
    var sourceURL: URL
    var filename: String
    var relativePath: String
    var channel: String

    init(_ clip: ClipItem) {
        sourceURL = clip.sourceURL
        filename = clip.filename
        relativePath = clip.relativePath
        channel = clip.channel
    }
}

struct CardHealthGroupEvidence: Hashable, Sendable {
    var timestamp: Date
    var mode: String
    var unmatchedChannel: String
    var presentFiles: [CardHealthFileEvidence]

    var heading: String {
        "\(timestamp.formatted(.iso8601)) • \(mode) • Potential unmatched \(unmatchedChannel)"
    }
}

extension CardHealthIssue {
    var reportText: String {
        var lines = [title, detail]
        lines += files.map { "  \($0.channel): \($0.relativePath)" }
        for group in unmatchedGroups {
            lines.append(group.heading)
            lines += group.presentFiles.map { "  Present \($0.channel): \($0.relativePath)" }
        }
        return lines.joined(separator: "\n")
    }
}

extension CardHealthReport {
    var fullText: String {
        (["Dashcam Offloader — Card Health Report",
          "\(issues.count) issues; \(checkedVideoCount) video files checked; \(skippedContainerCount) other-container files skipped for metadata probing.",
          "Read-only metadata checks, not a full decode. Unmatched channels use filename timestamps grouped by exact second and classified mode, not proven synchronized events. Start-time offsets and mode/protection classification can separate related recordings. No confirmed loss or corruption is implied. Timestamps below are ISO 8601 UTC.",
          "This private report contains recording filenames and relative folders. Review before sharing."] + issues.map(\.reportText)).joined(separator: "\n\n")
    }

    /// Resolve both sides to prevent a symlinked destination from writing onto the card.
    func save(to destination: URL) throws {
        guard let sourceRoot else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let root = sourceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        // Resolving a nonexistent leaf does not reliably resolve its parent on macOS.
        let target = destination.deletingLastPathComponent().resolvingSymlinksInPath()
            .appendingPathComponent(destination.lastPathComponent).standardizedFileURL.path
        guard target != root, !target.hasPrefix(root.hasSuffix("/") ? root : root + "/") else {
            throw CocoaError(.fileWriteNoPermission)
        }
        // Exclusive creation: even after the save panel, never replace an existing file.
        try Data(fullText.utf8).write(to: destination, options: .withoutOverwriting)
    }

    func revealableURL(for file: CardHealthFileEvidence) -> URL? {
        guard let sourceRoot else { return nil }
        let root = sourceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let url = file.sourceURL.standardizedFileURL
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.path.hasPrefix(root.hasSuffix("/") ? root : root + "/"),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
        return url
    }
}

struct CardHealthDetailsView: View {
    let report: CardHealthReport
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var actionMessage = ""

    private var matchingIssues: [CardHealthIssue] {
        report.issues.filter { query.isEmpty || $0.reportText.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Card Health Details").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("\(report.issues.count) issues • Metadata checks only, not a full video decode.")
            Text("Potential unmatched channels are grouped by exact filename second and mode. Start-time offsets or mode/protection classification can split related recordings. This does not confirm recording loss or corruption.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("Search all issues, channels, timestamps and paths", text: $query)
                .textFieldStyle(.roundedBorder)
            Text("Showing \(matchingIssues.count) of \(report.issues.count) issues. Group times are UTC.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(matchingIssues) { issue in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(issue.title).font(.headline)
                                Text(issue.detail).font(.callout)
                                ForEach(Array(issue.files.enumerated()), id: \.offset) { _, file in
                                    fileRow(file)
                                }
                                ForEach(Array(issue.unmatchedGroups.enumerated()), id: \.offset) { _, group in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.heading).font(.subheadline.bold())
                                        ForEach(Array(group.presentFiles.enumerated()), id: \.offset) { _, file in
                                            fileRow(file)
                                        }
                                    }.padding(.top, 6)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                        }
                    }
                    if matchingIssues.isEmpty { Text("No matching issues.") }
                }.padding(4)
            }
            HStack {
                Button("Copy Full Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report.fullText, forType: .string)
                    actionMessage = "Full report copied. Filenames and folders are private; review before sharing."
                }
                Button("Save Full Report…", action: saveReport)
                Spacer()
            }
            Text(actionMessage.isEmpty ? "Copy and Save include every issue, regardless of search. The source card is never modified." : actionMessage)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 720, idealWidth: 900, minHeight: 520, idealHeight: 680)
    }

    private func fileRow(_ file: CardHealthFileEvidence) -> some View {
        HStack(alignment: .top) {
            Text("\(file.channel): \(file.relativePath)").font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Reveal") {
                guard let url = report.revealableURL(for: file) else {
                    actionMessage = "File unavailable or outside the scanned source. Reconnect the source and rescan."
                    return
                }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .help("Reveal this existing source file in Finder without opening or changing it.")
        }
    }

    private func saveReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Dashcam Card Health Report.txt"
        panel.message = "Choose a new file outside the source card. Existing files will not be replaced."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try report.save(to: url)
            actionMessage = "Full report saved. Review private filenames and folders before sharing."
        } catch {
            actionMessage = "Could not save: choose a new filename outside the source card. Existing files are never overwritten. \(error.localizedDescription)"
        }
    }
}
