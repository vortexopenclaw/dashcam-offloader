import Foundation

/// Pass the Vantrue model labels from TransferViewModel.cameraModelsByBrand
/// after profiles have loaded, so the check covers the actual picker merge.
enum VantrueNamingVerification {
    static func run(vantruePickerModels: [String]) -> Bool {
        struct Failure: LocalizedError {
            let errorDescription: String?
        }
        do {
            func require(_ condition: Bool, _ message: String) throws {
                if !condition { throw Failure(errorDescription: message) }
            }
            func compact(_ value: String) -> String {
                value.lowercased().filter { $0.isLetter || $0.isNumber }
            }
            let spellings: [(String, [String])] = [
                ("E1", ["Element 1", "Element1"]),
                ("E1 Pro", ["Element 1 Pro", "Element1Pro", "Element 1Pro", "E1 Pro"]),
                ("E1 Pro S", ["E1 Pro S", "E1 ProS"]),
                ("E2", ["Element 2", "Element2"]),
                ("E3", ["Element 3", "Element3"]),
                ("S1", ["Sonnet 1", "Sonnet1"]),
                ("S1 Pro", ["Sonnet 1 Pro", "Sonnet1Pro", "S1 Pro"]),
                ("N5", ["Nexus 5", "Nexus5"]),
                ("N5S", ["Nexus 5S", "Nexus5S"]),
                ("N4", ["OnDash N4", "OnDashN4"]),
                ("N4 Pro", ["Nexus 4 Pro", "Nexus4Pro"]),
                ("N2X", ["Nexus 2X", "Nexus2X"]),
                ("F1", ["Falcon 1", "Falcon1"])
            ]
            let catalog = KnownDashcamCatalog.models.filter { $0.manufacturer == "Vantrue" }
            for (canonical, aliases) in spellings {
                try require(catalog.filter { $0.model == canonical }.count == 1,
                            "Missing or duplicate canonical Vantrue \(canonical)")
                try require(vantruePickerModels.filter { $0 == canonical }.count == 1,
                            "Picker must contain exactly one Vantrue \(canonical)")
                for spelling in [canonical] + aliases {
                    for name in [spelling, "Vantrue \(spelling)"] {
                        try require(KnownDashcamCatalog.exactModelMatch(manufacturer: "Vantrue", modelText: name)?.model == canonical,
                                    "Exact model alias failed: \(name)")
                    }
                }
            }
            // Exercise model mentions separately from manufacturer-scoped exact aliases.
            for name in ["E1 Pro", "E1 Pro S"] {
                try require(KnownDashcamCatalog.exactVolumeLabelMatch(name)?.model == name,
                            "Volume label collapsed \(name)")
                try require(KnownDashcamCatalog.exactModelMention("model=\(name)", manufacturer: "Vantrue")?.model == name,
                            "Model mention collapsed \(name)")
            }
            try require(KnownDashcamCatalog.exactModelMatch(manufacturer: "Vantrue", modelText: "E1 Pro") !=
                        KnownDashcamCatalog.exactModelMatch(manufacturer: "Vantrue", modelText: "E1 Pro S"),
                        "E1Pro and E1ProS must be distinct identities")
            try require(KnownDashcamCatalog.exactModelMention("E1PRO_Settings.ini", manufacturer: "Vantrue")?.model == "E1 Pro",
                        "Settings suffix must not turn E1 Pro into E1 Pro S")
            try require(KnownDashcamCatalog.exactModelMention("E1PROS_Settings.ini", manufacturer: "Vantrue")?.model == "E1 Pro S",
                        "Exact E1 Pro S settings basename must retain S")
            try require(KnownDashcamCatalog.exactModelMention("E1PROSX_Settings.ini", manufacturer: "Vantrue") == nil,
                        "Unknown settings suffix must not downgrade to a known sibling")
            // Resolve labels back to canonical identities to catch alias duplicates,
            // not just identical strings or spacing differences.
            let pickerIdentities = vantruePickerModels.map {
                compact(KnownDashcamCatalog.exactModelMatch(manufacturer: "Vantrue", modelText: $0)?.model ?? $0)
            }
            try require(Set(pickerIdentities).count == pickerIdentities.count,
                        "Duplicate Vantrue picker identities after profile/catalog merge")
            for label in catalog.map(\.model) + vantruePickerModels {
                try require(!label.lowercased().contains("element") && !label.lowercased().contains("sonnet"),
                            "Expanded family remains a Vantrue picker label: \(label)")
            }
            print("VANTRUE NAMING VERIFY PASS: canonical labels, compatibility aliases, distinct E1Pro/E1ProS, unique merged picker identities")
            return true
        } catch {
            print("VANTRUE NAMING VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
