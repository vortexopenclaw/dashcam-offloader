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
        if let discovery = snapshot.discovery {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generic support-file declarations (unbound)").font(.caption.bold())
                ForEach(Array(Self.discoveryDisclosure(discovery).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption).textSelection(.enabled)
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
    /// The exact lines rendered above, also exercised by the native regression.
    static func discoveryDisclosure(_ discovery: GenericCardDiscovery) -> [String] {
        var lines = ["Not authenticated identity or current owner settings; no model recognition inferred."]
        lines += discovery.sources.map { "\($0.id): \($0.format), \($0.encoding), \($0.sizeBytes) bytes (format hint only)" }
        lines += discovery.observations.map { "\($0.key): \($0.value) — \($0.sourceId):\($0.line), record \($0.record)" }
        let coverage = discovery.coverage
        lines.append("\(coverage.inspectedFiles)/\(coverage.inventoriedCandidates) candidates inspected; \(coverage.uninspectedFiles) uninspected; \(discovery.sources.count) format records; \(coverage.retainedObservations) declarations retained; \(coverage.omittedObservations) omitted; \(coverage.bytesRead) bytes read. Coverage \(coverage.limited ? "limited" : "within configured bounds").")
        if !coverage.reasons.isEmpty { lines.append(coverage.reasons.keys.sorted().map { "\($0): \(coverage.reasons[$0]!)" }.joined(separator: "; ")) }
        if coverage.multipleModelValues { lines.append("Multiple model declarations; physical roles remain unbound.") }
        return lines
    }
    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(snapshot)).map { String(decoding: $0, as: UTF8.self) } ?? "Unavailable"
    }
}
