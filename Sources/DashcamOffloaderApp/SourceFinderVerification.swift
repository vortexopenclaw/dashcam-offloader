import Foundation

@MainActor
enum SourceFinderVerification {
    static func run() -> Bool {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("source-finder-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        do {
            let card = root.appendingPathComponent("NO NAME #100% 'quoted'", isDirectory: true)
            let other = root.appendingPathComponent("Selected Card", isDirectory: true)
            let destination = root.appendingPathComponent("Destination", isDirectory: true)
            for directory in [card, other, destination] {
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let source = MountedSource(url: card, name: "Context Card")
            let model = TransferViewModel()
            model.mountedSources = [MountedSource(url: other, name: "Selected Card"), source]
            model.selectedSource = model.mountedSources[0]
            model.destinationURL = destination
            model.isScanning = true
            model.copyProgress.isRunning = true
            var opened: [URL] = []
            model.showSourceInFinder(source, open: { opened.append($0); return true })
            guard opened == [card], model.selectedSource?.url == other,
                  model.destinationURL == destination, model.mountedSources.count == 2,
                  model.statusMessage == "Showing Context Card in Finder" else { return fail("context row dispatch or state preservation") }
            let volumeURL = URL(fileURLWithPath: "/Volumes/NO NAME", isDirectory: true)
            guard volumeURL.path == "/Volumes/NO NAME", volumeURL.absoluteString.contains("NO%20NAME"),
                  URL(string: card.absoluteString)?.path == card.path else { return fail("file URL escaping") }
            model.showSourceInFinder(source, open: { _ in false })
            guard model.statusMessage == "Could not open Context Card in Finder" else { return fail("Finder failure") }
            try manager.removeItem(at: card)
            let file = root.appendingPathComponent("not a directory")
            try Data().write(to: file)
            for invalid in [card, file, URL(string: "https://example.invalid/card")!, URL(fileURLWithPath: "/")] {
                model.showSourceInFinder(MountedSource(url: invalid, name: "Unavailable"), open: { opened.append($0); return true })
                guard model.statusMessage.contains("source is no longer available") else { return fail("unavailable source error") }
            }
            guard opened == [card] else { return fail("unavailable source opened another location") }
            // Opt-in native acceptance opens only a caller-created scratch fixture.
            // Normal verification never opens Finder or touches a mounted camera.
            if let fixturePath = ProcessInfo.processInfo.environment["DASHCAM_FINDER_VERIFICATION_ROOT"] {
                let fixture = URL(fileURLWithPath: fixturePath, isDirectory: true)
                let scratch = manager.temporaryDirectory.resolvingSymlinksInPath().path + "/"
                guard fixture.resolvingSymlinksInPath().path.hasPrefix(scratch) else {
                    return fail("native acceptance requires a scratch fixture")
                }
                model.showSourceInFinder(MountedSource(url: fixture, name: "Finder Fixture"))
                guard model.statusMessage == "Showing Finder Fixture in Finder" else { return fail(model.statusMessage) }
                print("VERIFY PASS: native Finder opened scratch fixture \(fixture.path)")
            }
            print("VERIFY PASS: source Finder context-row dispatch, spaces and reserved characters, unchanged selection/destination, copy/scan availability, ejected/missing/file/non-file/root rejection, and open failure")
            return true
        } catch {
            return fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Bool {
        print("VERIFY FAIL: source Finder \(message)")
        return false
    }
}
