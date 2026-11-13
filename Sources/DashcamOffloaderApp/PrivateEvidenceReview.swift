import SwiftUI

struct PrivateEvidenceReview: View {
    let snapshot: FeedbackScanSnapshot
    var body: some View {
        if let observations = snapshot.componentMetadata, !observations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Extracted log observations (may be historical)").font(.caption.bold())
                Text("Separate from owner-entered firmware. Rear/inside are protocol component labels, not confirmed physical views.").font(.caption)
                ForEach(Array(observations.enumerated()), id: \.offset) { _, entry in
                    Text("\(entry.component): \(entry.reportedModel ?? "Unbound component") · \(entry.firmwareVersion ?? "No firmware") — \(entry.sourceFile):\(entry.sourceLine)")
                        .font(.caption).textSelection(.enabled)
                    if let reported = entry.reportedModel, entry.model == nil {
                        let candidates = DDPAIOfficialModels.matches(reported)
                        Text(candidates.isEmpty ? "Unrecognized exact model; no SKU or family alias inferred." : "Unresolved region/revision candidates: " + candidates.map { "\($0.model) [\($0.region)]" }.joined(separator: "; "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let coverage = snapshot.componentMetadataCoverage {
                    Text("\(coverage.inspectedFiles) logs inspected; \(coverage.retainedEntries) observations retained; \(coverage.omittedEntries) known observations omitted\(coverage.limited ? "; coverage limited (unread evidence unknown)" : "").").font(.caption)
                }
            }
        }
        DisclosureGroup("Exact private scan evidence (including linked filenames)") {
            ScrollView {
                Text(json).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 180)
        }
    }
    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(snapshot)).map { String(decoding: $0, as: UTF8.self) } ?? "Unavailable"
    }
}
