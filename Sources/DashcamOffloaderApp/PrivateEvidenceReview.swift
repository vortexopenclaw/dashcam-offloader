import SwiftUI

struct PrivateEvidenceReview: View {
    let snapshot: FeedbackScanSnapshot
    var body: some View {
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
