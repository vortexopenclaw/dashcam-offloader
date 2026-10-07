import SwiftUI

struct CardLearningStructurePreview: View {
    let directories: [FeedbackDirectorySummary]
    let files: [FeedbackMediaFileSample]

    private func flag(_ value: Bool?) -> String {
        value.map { $0 ? "yes" : "no" } ?? "unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !directories.isEmpty {
                Text("Camera-relative folders (unrecognized names anonymized)").fontWeight(.semibold)
                ForEach(directories, id: \.path) { folder in
                    Text("\(folder.path) · \(folder.directMediaFileCount) media files")
                }
            }
            if !files.isEmpty {
                Text("\(files.count) sampled camera files with recording type, channel and protection flags").fontWeight(.semibold)
                ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(file.folder)/\(file.filename)").textSelection(.enabled)
                        Text("\(file.outputCategory) · \(file.channel) · \(file.fileSizeBytes) bytes")
                        Text("Read-only bits: \(flag(file.filesystemReadOnly)); user/system lock: \(flag(file.userImmutable))/\(flag(file.systemImmutable)); read-only volume: \(flag(file.volumeReadOnly))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Camera filenames may contain recording times. Never shared: host paths, source names, personal folder names, media, GPS, serials, network identifiers or credentials. Source files are never changed.")
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
