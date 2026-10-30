import Foundation

/// Editable learning-sheet state. Zero means no observed suggestion, not zero cameras.
struct LearningChannelSelection {
    private(set) var count = 0
    private var ownerEdited = false

    mutating func prefill(_ observedCount: Int) {
        if !ownerEdited { count = observedCount }
    }

    mutating func choose(_ count: Int) {
        self.count = count
        ownerEdited = true
    }

    func reportSetup(description: String, placeholder: String) -> String {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard count > 0 else { return text.isEmpty ? "Unknown" : "Unknown: \(text)" }
        return "\(count)CH: \(text.isEmpty ? placeholder : text)"
    }
}
