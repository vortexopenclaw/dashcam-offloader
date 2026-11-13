import Foundation

/// Stylized synthetic technical records, not proof of any manufacturer's format.
enum GenericDiscoveryVerification {
    struct Failure: Error { let message: String }
    static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw Failure(message: message) }
    }
    @discardableResult static func run(root: URL) throws -> GenericCardDiscovery {
        let fm = FileManager.default
        let card = root.appendingPathComponent("generic-discovery")
        try fm.createDirectory(at: card, withIntermediateDirectories: true)
        func put(_ name: String, _ data: Data) throws -> URL {
            let file = card.appendingPathComponent(name)
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file)
            return file
        }
        let json = try put("unfamiliar/settings.weird", Data(#"{"private_parent_canary":{"model":"NovaCam QX7","firmware":"8.0.0.16","password":"NEVER-UPLOAD-CANARY","url":"https://private.invalid","resolution":"3840x2160","fps":30},"accessory":{"rear_model":"Aux R2","version":"2.3"}}"#.utf8))
        let ini = try put(".git", Data("[private section canary]\nmodel=RoadEye A3\nmodel=RoadEye A4\nfirmware_version=3.7.2\nssid=NEVER-UPLOAD-CANARY\n[aux]\nhardware_version=1.2\nquality=high\n".utf8))
        let utf16 = "model=StarView S8\nfw=4.5.6\n"
        _ = try put("arbitrary/extensionless", Data([0xff,0xfe]) + utf16.data(using: .utf16LittleEndian)!)
        _ = try put("other/version.bin", Data([0xfe,0xff]) + "version=6.1\n".data(using: .utf16BigEndian)!)
        _ = try put("tmp", Data("\u{1b}[32mT ui notice {\"dev_model\":\"Orbit X9\",\"soft_version\":\"5.6.7\",\"wifi_pwd\":\"NEVER-UPLOAD-CANARY\"}\u{1b}[0m\n".utf8))
        let result = GenericCardDiscovery.read(source: card)
        try require(result.coverage.inventoriedCandidates == 5 && result.coverage.inspectedFiles == 5, "unknown/hidden/extensionless inventory")
        try require(result.observations.contains { $0.value == "NovaCam QX7" && $0.scope == "unbound" }, "unknown model retained")
        try require(result.observations.contains { $0.value == "8.0.0.16" && $0.field == "firmware" }, "firmware retained")
        try require(result.observations.contains { $0.key == "version" && $0.field == "build" }, "bare version is build")
        try require(result.observations.contains { $0.key == "hardware_version" && $0.field == "build" }, "hardware not firmware")
        try require(result.observations.filter { $0.sourceId == result.observations.first(where: { $0.value == "NovaCam QX7" })?.sourceId }.map(\.record).max()! > 0, "nested record context")
        try require(result.observations.filter { ["RoadEye A3","RoadEye A4"].contains($0.value) }.count == 2, "INI duplicate values retained")
        try require(Set(result.sources.map(\.format)).isSuperset(of: ["json","ini","key_value","framed_json"]), "text formats")
        try require(Set(result.sources.map(\.encoding)).isSuperset(of: ["utf8","utf16le","utf16be"]), "strict BOM encodings")
        try require(result.coverage.multipleModelValues, "multiple models sticky")
        let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        for privateToken in ["NEVER-UPLOAD", "private_parent", "private section", "private.invalid", "settings.weird", "extensionless", "wifi_pwd"] {
            try require(!encoded.contains(privateToken), "private source/value leaked: " + privateToken)
        }
        func single(_ data: Data) throws -> GenericCardDiscovery {
            let file = try put("probe", data)
            return GenericCardDiscovery.read(source: card, files: [file])
        }
        let framedLog = try single(Data("\u{1b}[32m[logger] {source.cpp:14} {\"model\":\"Unknown-Log9\",\"soft_version\":\"5.6.7\"}\u{1b}[0m\n".utf8))
        try require(framedLog.observations.count == 2 && framedLog.observations.contains { $0.value == "Unknown-Log9" }, "balanced logger framing and ANSI retain both declarations")
        let enclosedFrame = try single(Data("logger [ {\"model\":\"False F1\"} ]\n".utf8))
        try require(enclosedFrame.observations.isEmpty, "framed extraction does not salvage an enclosing array")
        let structured = try single(Data([0xef,0xbb,0xbf]) + Data("\n{\n  \"records\": [\n    {\"Model-Name\":\"Alpha A1\"},\n    {\"model\":\"Beta B2\",\"fps\":true}\n  ]\n}".utf8))
        try require(structured.observations.count == 2 && structured.observations[0].key == "model_name" && structured.observations[0].line == 4 && structured.observations[1].line == 5 && structured.observations[0].record != structured.observations[1].record, "nested lexical line/record and canonical keys")
        let lineJSON = try single(Data("{\"model\":\"Line A1\"}\n{\"model\":\"Line B2\"}\n".utf8))
        try require(lineJSON.observations.count == 2 && lineJSON.observations[1].line == 2 && lineJSON.observations[1].record == 1, "line JSON separated records")
        let repeatedINI = try single(Data("[camera]\nmodel=Alpha A1\nfw=1.2\nmodel=FutureCam X9\nfw=2.3\nnotice {\"model\":\"Mixed M3\"}\nmodel=Tail T4\nfw=3.4\n".utf8))
        try require(repeatedINI.observations.map(\.record) == [0,0,1,1,2,3,3], "repeated INI declarations and mixed JSON use distinct records")
        for (key, value) in [("model", "Call Alice at home"), ("manufacturer", "John Smith"), ("model", "AB12CD34EF56"), ("model", "AA-BB-CC-DD-EE-FF"), ("model", "A1-B2-C3-D4-E5-F6"), ("model", "A123456789"), ("firmware", "127.0.0.1"), ("firmware", "169.254.1.2"), ("firmware", "10.1.2.3"), ("width", "0"), ("height", "16385"), ("fps", "241"), ("bitrate", "1000000001")] {
            let rejected = try single(Data("\(key)=\(value)".utf8))
            try require(rejected.observations.isEmpty && rejected.coverage.reasons["unsafe_value"] == 1, "P1 typed rejection: \(key)=\(value)")
        }
        for (key, value) in [("model", "Alpha A1"), ("model", "FutureCam X9"), ("model", "DDPAIDZ2602 Master"), ("manufacturer", "FutureCam"), ("firmware", "8.0.0.23"), ("firmware", "9.0.1.10"), ("codec", "av1"), ("parking_mode", "on"), ("parking_mode", "off"), ("width", "16384"), ("fps", "240"), ("fps", "+30"), ("fps", "1e2"), ("bitrate", "1000000000")] {
            try require(try single(Data("\(key)=\(value)".utf8)).observations.count == 1, "valid typed declaration: \(key)=\(value)")
        }
        let controls = try single(Data("\u{1b}[32mnotice {\"model\":\"Bad\u{1b}[0mModel\"}\u{1b}[0m".utf8))
        try require(controls.observations.isEmpty && controls.coverage.reasons["malformed"] != nil, "ANSI inside payload never cleaned")
        let controlsEscaped = try single(Data(#"notice {"model":"Bad\u001bModel"}"#.utf8))
        try require(controlsEscaped.observations.isEmpty, "escaped payload control rejected")
        for malformed in [#"{"model":"A1","model":"B2"}"#, #"{"model":"A1","\u006dodel":"B2"}"#, "{\n\"model\":\"A1\",\n\"model\":\"B2\"\n}", #"{"nested":{"model":"A1","model":"B2"}}"#] {
            let rejected = try single(Data(malformed.utf8))
            try require(rejected.observations.isEmpty && rejected.coverage.reasons["malformed"] != nil, "duplicate guard")
        }
        for unsafe in ["person@example.org", "https://example.org", "192.168.1.1", "51.123,-1.123", "secret-canary", String(repeating: "X", count: 81)] {
            let rejected = try single(Data(("model=" + unsafe).utf8))
            try require(rejected.observations.isEmpty, "unsafe typed value")
        }
        for badEncoding in [Data([0xff,0x00,0xfe]), Data([0xff,0xfe,0x00,0xd8]), Data([0xfe,0xff,0xd8,0x00])] {
            try require(try single(badEncoding).observations.isEmpty, "invalid encoding")
        }
        let xml = try single(Data("<!DOCTYPE x [<!ENTITY y SYSTEM 'file:///private'>]><x/>".utf8))
        try require(xml.sources.first?.format == "xml" && xml.coverage.reasons["unsupported_format"] == 1, "XML honestly unsupported")
        let jpeg = try single(Data([0xff,0xd8,0xff,0x00]))
        try require(jpeg.sources.first?.format == "jpeg" && jpeg.observations.isEmpty, "JPEG hint only")
        var tar = Data(repeating: 0, count: 512); tar.replaceSubrange(257..<262, with: Data("ustar".utf8))
        try require(try single(tar).sources.first?.format == "tar", "TAR hint only")
        try require(try single(Data([0,0,0,12]) + Data("ftypisom".utf8)).sources.first?.format == "isobmff", "ISO hint only")
        let oversized = try single(Data(repeating: 65, count: 65537))
        try require(oversized.coverage.bytesRead == 0 && oversized.coverage.reasons["oversize"] == 1, "pre-read size bound")
        let linked = card.appendingPathComponent("linked")
        try fm.createSymbolicLink(atPath: linked.path, withDestinationPath: json.path)
        let symlink = GenericCardDiscovery.read(source: card, files: [linked])
        try require(symlink.coverage.reasons["read_error"] == 1 && symlink.coverage.bytesRead == 0, "symlink file rejected")
        let ancestor = card.appendingPathComponent("linked-dir")
        try fm.createSymbolicLink(atPath: ancestor.path, withDestinationPath: json.deletingLastPathComponent().path)
        let parentLink = GenericCardDiscovery.read(source: card, files: [ancestor.appendingPathComponent(json.lastPathComponent)])
        try require(parentLink.coverage.reasons["read_error"] == 1, "symlink ancestor rejected")
        let missing = GenericCardDiscovery.read(source: card, files: [card.appendingPathComponent("missing")])
        try require(missing.coverage.reasons["read_error"] == 1, "missing read error")
        let cancelled = GenericCardDiscovery.read(source: card, files: [ini], cancelled: { true })
        try require(cancelled.coverage.bytesRead == 0 && cancelled.coverage.uninspectedFiles == 1 && cancelled.coverage.limited, "cancellation")
        let mutationFile = try put("mutation", Data("model=Before A1".utf8))
        let mutation = GenericCardDiscovery.read(source: card, files: [mutationFile], afterRead: { try! Data("model=After A2 longer".utf8).write(to: mutationFile) })
        try require(mutation.observations.isEmpty && mutation.coverage.reasons["changed_source"] == 1, "mutation drops observations")
        let replacement = GenericCardDiscovery.read(source: card, files: [mutationFile], afterRead: {
            try! fm.removeItem(at: mutationFile); try! Data("model=Replacement B3".utf8).write(to: mutationFile)
        })
        try require(replacement.coverage.reasons["changed_source"] == 1, "replacement identity check")
        let many = (0..<150).map { "model=\($0 == 149 ? "Last B2" : "First A1")" }.joined(separator: "\n")
        let truncated = try single(Data(many.utf8))
        try require(truncated.observations.count == 128 && truncated.coverage.omittedObservations == 22 && truncated.coverage.multipleModelValues, "sticky conflict before fact trim")
        var files: [URL] = []
        for index in 0..<260 { files.append(try put(String(format: "budget/%03d", index), Data("model=\(index == 255 ? "Last Minority B2" : "Budget A1")\n".utf8))) }
        let capped = GenericCardDiscovery.read(source: card, files: files)
        try require(capped.coverage.inventoriedCandidates == 260 && capped.coverage.inspectedFiles == 256 && capped.coverage.uninspectedFiles == 4 && capped.sources.count == 128 && capped.observations.count == 128 && capped.coverage.omittedObservations == 128 && capped.coverage.limited && capped.coverage.multipleModelValues, "candidate/source/fact caps")
        let inventoriedBudget = GenericCardDiscovery.read(source: card.appendingPathComponent("budget"))
        try require(inventoriedBudget.coverage.inventoriedCandidates == 260 && inventoriedBudget.coverage.uninspectedFiles == 4 && inventoriedBudget.coverage.multipleModelValues, "real directory inventory counts beyond cap")
        let full = try put("full-budget", Data(repeating: 32, count: 65536))
        let bytes = GenericCardDiscovery.read(source: card, files: Array(repeating: full, count: 66))
        try require(bytes.coverage.bytesRead == 4194304 && bytes.coverage.inspectedFiles == 64 && bytes.coverage.reasons["byte_limit"] == 2, "aggregate byte cap")
        var largeVideos: [URL] = []
        for index in 0..<256 { largeVideos.append(try put(String(format: "starvation/%03d.mp4", index), Data(repeating: 0, count: 65537))) }
        let lateConfig = try put("starvation/zzz/version.txt", Data("model=Late L9\nfw=9.0.1.10\n".utf8))
        let late = GenericCardDiscovery.read(source: card, files: largeVideos + [lateConfig])
        try require(late.coverage.inspectedFiles == 1 && late.coverage.reasons["oversize"] == 256 && late.observations.count == 2, "256 oversized videos cannot starve late version.txt")
        // Same-priority unknown extensions exercise reclaim, not just sorting.
        var pictures: [URL] = []
        for index in 0..<128 { pictures.append(try put(String(format: "starvation-jpeg/%03d.odd", index), Data([0xff,0xd8,0xff,0x00]))) }
        let lateUnknown = try put("starvation-jpeg/zzz.unknown", Data("model=Later L8\nfw=8.0.0.23\n".utf8))
        let reclaimed = GenericCardDiscovery.read(source: card, files: pictures + [lateUnknown])
        try require(reclaimed.coverage.inspectedFiles == 129 && reclaimed.sources.count == 128 && reclaimed.observations.count == 2 && reclaimed.coverage.limited && reclaimed.observations.allSatisfy { observation in reclaimed.sources.contains { $0.id == observation.sourceId } }, "128 structural-only sources cannot block late unknown-extension facts")
        let mediaConfig = try put("starvation/zzz/support.mp4", Data("model=Fallback F7\n".utf8))
        let fallback = GenericCardDiscovery.read(source: card, files: largeVideos + [mediaConfig])
        try require(fallback.observations.first?.value == "Fallback F7" && fallback.coverage.inspectedFiles == 1 && fallback.coverage.reasons["oversize"] == 256 && fallback.observations.first?.sourceId == "support-257" && fallback.coverage.uninspectedFiles == 256, "oversize files do not consume inspections even within media priority")
        // Keep the roundtrip fixture narrowly synthetic and restore only its original five files.
        for name in ["starvation", "starvation-jpeg", "probe","linked","linked-dir","mutation","budget","full-budget"] { try fm.removeItem(at: card.appendingPathComponent(name)) }
        print("GENERIC DISCOVERY NATIVE PASS: unknown paths, nested/duplicate JSON, INI, UTF16, framing, privacy, bounds, symlinks, mutation, cancellation")
        return result
    }
}
