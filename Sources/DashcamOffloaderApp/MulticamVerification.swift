import AVFoundation
import Foundation

enum MulticamVerification {
    static func run() -> Bool {
        do {
            func require(_ condition: Bool, _ message: String) throws {
                if !condition { throw MulticamExporter.Failure.message(message) }
            }
            let names = ["2026_0101_120000_000001F.MP4", "2026_0101_120000_000002T.MP4",
                         "2026_0101_120000_000003I.MP4", "2026_0101_120000_000004R.MP4"]
            let inputs = MulticamExporter.inputs(urls: names.map { URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0)") })
            try MulticamExporter.validate(inputs)
            try require(Set(inputs.map { $0.identity.stamp }).count == 1, "different sequence numbers did not group")
            try require(MulticamExporter.identify("2026_0101_120000_000001PF Notes.MP4")?.parking == true,
                        "parking suffix or renamed destination not recognized")
            try require(MulticamExporter.identify("2026_0101_120000_000003I Parked at sample lot, interior cam, HDR On.MP4")?.annotation == "Parked at sample lot, interior cam, HDR On",
                        "filename annotation not preserved")
            try require(MulticamExporter.identify("2026_0230_120000_000001F.MP4") == nil
                        && MulticamExporter.identify("2026_0101_120000_000001F.JPG") == nil,
                        "invalid date or photo accepted")
            do {
                try MulticamExporter.validate(inputs + [inputs[0]])
                throw MulticamExporter.Failure.message("duplicate channel was accepted")
            } catch MulticamExporter.Failure.message(let text) {
                try require(text.contains("Duplicate"), text)
            }
            let next = names.map { $0.replacingOccurrences(of: "120000", with: "120004") }
            let allInputs = inputs + MulticamExporter.inputs(urls: next.map { URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0)") })
            func videos(_ inputs: [MulticamExporter.Input]) -> [MulticamExporter.Video] {
                inputs.map { input in
                    MulticamExporter.Video(input: input, duration: 2,
                        width: input.identity.channel == "F" ? 3840 : 2560,
                        height: input.identity.channel == "F" ? 2160 : 1440,
                        frameDuration: CMTime(value: 1, timescale: 30), audioChannels: 1, audioRate: 48000)
                }
            }
            do {
                _ = try MulticamExporter.render(videos(Array(inputs.dropLast())))
                throw MulticamExporter.Failure.message("missing channel was accepted")
            } catch MulticamExporter.Failure.message(let text) {
                try require(text.contains("missing Rear"), text)
            }
            let xml = try MulticamExporter.render(videos(allInputs))
            let doc = try XMLDocument(xmlString: xml)
            try require(try doc.nodes(forXPath: "//multicam/mc-angle").count == 5, "five angles missing")
            try require(try doc.nodes(forXPath: "//asset").count == 8, "original assets duplicated or dropped")
            try require(try doc.nodes(forXPath: "//gap[@duration='60/30s']").count == 4, "recording gaps not preserved")
            try require(try doc.nodes(forXPath: "//adjust-transform[@scale='0.5 0.5']").count == 4, "grid scale missing")
            try require(try doc.nodes(forXPath: "//adjust-volume[@amount='-96dB']").count == 3, "grid audio mixed")
            try require(try doc.nodes(forXPath: "//mc-clip[@duration='180/30s']").count == 1, "wrong rational duration")
            try require(!xml.contains("conform-rate") && xml.contains("Camera%20&amp;%20Clips"), "rate altered or URL not escaped")
            let tagged = names.map { $0.replacingOccurrences(of: ".MP4", with: " HDR Off & night <test>.MP4") }
            let taggedInputs = MulticamExporter.inputs(urls: tagged.map { URL(fileURLWithPath: "/synthetic/Night Sample, Talking/\($0)") })
            let taggedDoc = try XMLDocument(xmlString: MulticamExporter.render(videos(taggedInputs)))
            let outerMarkers = try taggedDoc.nodes(forXPath: "//mc-clip/marker").compactMap { $0 as? XMLElement }
            try require(outerMarkers.filter { ($0.attribute(forName: "value")?.stringValue ?? "").contains("HDR Off & night <test>")
                        && $0.attribute(forName: "start")?.stringValue == "0/30s" }.count == 1,
                        "filename notes not visible on multicam")
            let sourceMarkers = try taggedDoc.nodes(forXPath: "//asset-clip/marker").compactMap { $0 as? XMLElement }
            try require(sourceMarkers.filter { $0.attribute(forName: "value")?.stringValue == "HDR Off & night <test>" }.count == 4,
                        "original per-angle labels not preserved")
            try require(try taggedDoc.nodes(forXPath: "//mc-clip[contains(@name, 'Night Sample, Talking')]").count == 1,
                        "folder organization lost")
            let parkingInputs = MulticamExporter.inputs(urls: names.map {
                URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0.replacingOccurrences(of: "1F", with: "1PF").replacingOccurrences(of: "2T", with: "2PT").replacingOccurrences(of: "3I", with: "3PI").replacingOccurrences(of: "4R", with: "4PR"))")
            })
            let modes = try XMLDocument(xmlString: MulticamExporter.render(videos(inputs + parkingInputs)))
            try require(try modes.nodes(forXPath: "//multicam").count == 2, "parking and driving mixed")
            var shortVideos = videos(inputs)
            let original = shortVideos[0]
            shortVideos[0] = MulticamExporter.Video(input: original.input, duration: 1,
                width: original.width, height: original.height, frameDuration: original.frameDuration,
                audioChannels: 0, audioRate: 0)
            let stopped = try XMLDocument(xmlString: MulticamExporter.render(shortVideos))
            try require(try stopped.nodes(forXPath: "//gap[@name='Camera stopped' and @duration='30/30s']").count == 1,
                        "short channel was trimmed or stretched")
            try require(try stopped.nodes(forXPath: "//asset[not(@hasAudio)]").count == 1, "silent footage acquired audio")
            func sectionInputs(stamps: [String], notes: [String]) -> [MulticamExporter.Input] {
                zip(stamps, notes).flatMap { stamp, note in
                    MulticamExporter.inputs(urls: names.map { name in
                        let renamed = name.replacingOccurrences(of: "120000", with: stamp)
                        let labeled = renamed.contains("000001F") && !note.isEmpty
                            ? renamed.replacingOccurrences(of: ".MP4", with: " \(note).MP4") : renamed
                        return URL(fileURLWithPath: "/synthetic/Sections/\(labeled)")
                    })
                }
            }
            let continuous = try XMLDocument(xmlString: MulticamExporter.render(videos(sectionInputs(
                stamps: ["120000", "120002", "120004"], notes: ["Night front", "Night front", "Day front"]))))
            try require(try continuous.nodes(forXPath: "//asset-clip/marker").count == 2,
                        "continuous repeated label produced per-clip markers")
            try require(try continuous.nodes(forXPath: "//mc-clip/marker[@start='60/30s']").isEmpty,
                        "second adjacent recording incorrectly started a new section")
            try require(try continuous.nodes(forXPath: "//mc-clip/marker[@start='120/30s']").count == 1,
                        "changed label did not start a new section")
            let disconnected = try XMLDocument(xmlString: MulticamExporter.render(videos(sectionInputs(
                stamps: ["120000", "120004"], notes: ["Night front", "Night front"]))))
            try require(try disconnected.nodes(forXPath: "//asset-clip/marker").count == 2,
                        "recording gap did not restart a labeled section")
            let cleared = try XMLDocument(xmlString: MulticamExporter.render(videos(sectionInputs(
                stamps: ["120000", "120002", "120004"], notes: ["Night front", "", "Night front"]))))
            try require(try cleared.nodes(forXPath: "//asset-clip/marker").count == 2,
                        "untagged footage did not end the previous section")
            let drives = inputs + MulticamExporter.inputs(urls: names.map {
                URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0.replacingOccurrences(of: "120000", with: "160000"))")
            }) + MulticamExporter.inputs(urls: names.map {
                URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0.replacingOccurrences(of: "0101", with: "0102"))")
            })
            let drivesDoc = try XMLDocument(xmlString: MulticamExporter.render(videos(drives)))
            try require(try drivesDoc.nodes(forXPath: "//multicam").count == 3, "separate drives combined")
            try require(try drivesDoc.nodes(forXPath: "//mc-clip[@duration='60/30s']").count == 3, "drive timelines not reset")
            let boundary = inputs + MulticamExporter.inputs(urls: names.map {
                URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0.replacingOccurrences(of: "120000", with: "120502"))")
            })
            try require(MulticamExporter.sessions(videos(boundary)).count == 1, "five-minute tolerance did not use clip ends")
            let split = inputs + MulticamExporter.inputs(urls: names.map {
                URL(fileURLWithPath: "/synthetic/Camera & Clips/\($0.replacingOccurrences(of: "120000", with: "120503"))")
            })
            try require(MulticamExporter.sessions(videos(split)).count == 2, "gap above five minutes not split")
            let moved = MulticamExporter.inputs(urls: names.enumerated().map { index, name in
                URL(fileURLWithPath: "/synthetic/Card/DCIM/Movie/\(index == 0 ? "RO/" : "")\(name)")
            })
            let movedDoc = try XMLDocument(xmlString: MulticamExporter.render(videos(moved)))
            try require(try movedDoc.nodes(forXPath: "//multicam").count == 1, "RO camera separated from matching set")
            try require(try movedDoc.nodes(forXPath: "//media-rep[contains(@src, '/RO/')]").count == 1, "RO original URL lost")
            let emergency = MulticamExporter.inputs(urls: [URL(fileURLWithPath:
                "/synthetic/Camera & Clips/RO/LOCKED_2026_0101_120001_000005EF Impact & note.MP4")])
            try require(emergency.count == 1 && emergency[0].identity.channel == "F"
                        && !emergency[0].identity.parking && emergency[0].identity.annotation == "Impact & note",
                        "emergency filename identity or annotation lost")
            let emergencyDoc = try XMLDocument(xmlString: MulticamExporter.render(videos(allInputs + emergency)))
            try require(try emergencyDoc.nodes(forXPath: "//multicam").count == 1, "partial emergency recording split drive")
            try require(try emergencyDoc.nodes(forXPath: "//asset").count == 9, "emergency asset dropped")
            try require(try emergencyDoc.nodes(forXPath: "//asset-clip[@offset='0/30s' and @duration='30/30s']").count == 1,
                        "overlapping front clip not cut at emergency start")
            try require(try emergencyDoc.nodes(forXPath: "//asset-clip[@offset='30/30s' and @duration='60/30s']").count == 1,
                        "emergency recording not aligned by timestamp")
            var longer = videos(inputs)
            longer[0] = MulticamExporter.Video(input: longer[0].input, duration: 10,
                width: 3840, height: 2160, frameDuration: CMTime(value: 1, timescale: 30), audioChannels: 1, audioRate: 48000)
            let resumed = try XMLDocument(xmlString: MulticamExporter.render(longer + videos(emergency)))
            try require(try resumed.nodes(forXPath: "//asset-clip[@offset='90/30s' and @start='90/30s' and @duration='210/30s']").count == 1,
                        "normal recording did not resume after short emergency overlap")
            try require(try resumed.nodes(forXPath: "//asset").count == 5, "resumed original asset duplicated")
            let parkedEmergency = MulticamExporter.inputs(urls: [URL(fileURLWithPath:
                "/synthetic/Card/DCIM/Movie/Parking/RO/2026_0101_120000_000005EF.MP4")])
            try require(parkedEmergency.first?.identity.parking == true,
                        "parking emergency was mistaken for driving")
            let differentAlbums = inputs + MulticamExporter.inputs(urls: names.map {
                URL(fileURLWithPath: "/synthetic/Other Album/\($0)")
            })
            try require(MulticamExporter.sessions(videos(differentAlbums)).count == 2, "independent albums collapsed")
            print("MULTICAM VERIFY PASS: filename groups, missing/duplicate guards, five angles, grid, audio, gaps, native rate, XML escaping, mode separation")
            return true
        } catch {
            print("MULTICAM VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }
}
