import Foundation
import Darwin

/// Hostile-source and destination-containment regressions for the copy path.
/// Written on a host without a Swift toolchain: run with `swift run DashcamOffloader --verify`.
enum HostileCardVerification {
    static func run() async -> Bool {
        do {
            return try await runCases()
        } catch {
            print("VERIFY FAIL: hostile card verification error: \(error.localizedDescription)")
            return false
        }
    }

    private static func runCases() async throws -> Bool {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("dashcam-offloader-hostile-verify-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let sourceRoot = root.appendingPathComponent("card", isDirectory: true)
        let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
        let outsideRoot = root.appendingPathComponent("outside", isDirectory: true)
        for directory in [sourceRoot, destinationRoot, outsideRoot] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let secret = outsideRoot.appendingPathComponent("secret.MP4")
        try Data(repeating: 9, count: 1024).write(to: secret)

        // 1. A clip replaced by a symbolic link after the scan is refused, not followed.
        let swapped = sourceRoot.appendingPathComponent("swapped.MP4")
        try fileManager.createSymbolicLink(at: swapped, withDestinationURL: secret)
        let swappedDestination = destinationRoot.appendingPathComponent("swapped.MP4")
        var result = await runCopy(sourceRoot: sourceRoot, destinationRoot: destinationRoot, items: [
            item(source: swapped, destination: swappedDestination, expectedSize: 1024)
        ])
        guard result.mediaItems.first?.status == .failed,
              result.mediaItems.first?.message == CopyError.sourceNotRegularFile.localizedDescription,
              !CopyExecutor.entryExists(atPath: swappedDestination.path) else {
            print("VERIFY FAIL: copy followed a symbolic link that replaced a scanned clip")
            return false
        }

        // 2. A named pipe or a directory at the source path fails promptly instead of hanging or crashing.
        let pipe = sourceRoot.appendingPathComponent("pipe.MP4")
        guard mkfifo(pipe.path, 0o644) == 0 else {
            print("VERIFY FAIL: could not create the named-pipe fixture")
            return false
        }
        let folder = sourceRoot.appendingPathComponent("folder.MP4", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        result = await runCopy(sourceRoot: sourceRoot, destinationRoot: destinationRoot, items: [
            item(source: pipe, destination: destinationRoot.appendingPathComponent("pipe.MP4"), expectedSize: 0),
            item(source: folder, destination: destinationRoot.appendingPathComponent("folder.MP4"), expectedSize: 0)
        ])
        guard result.mediaItems.count == 2,
              result.mediaItems.allSatisfy({ $0.status == .failed }),
              !CopyExecutor.entryExists(atPath: destinationRoot.appendingPathComponent("pipe.MP4").path),
              !CopyExecutor.entryExists(atPath: destinationRoot.appendingPathComponent("folder.MP4").path) else {
            print("VERIFY FAIL: copy did not refuse a pipe or directory at a source path")
            return false
        }

        // 3. A dangling symbolic link at the destination is a conflict: nothing is
        //    written through it and the link itself is not removed.
        let regular = sourceRoot.appendingPathComponent("regular.MP4")
        try Data(repeating: 5, count: 2048).write(to: regular)
        let danglingTarget = outsideRoot.appendingPathComponent("created-through-link.MP4")
        let danglingLink = destinationRoot.appendingPathComponent("dangling.MP4")
        try fileManager.createSymbolicLink(at: danglingLink, withDestinationURL: danglingTarget)
        result = await runCopy(sourceRoot: sourceRoot, destinationRoot: destinationRoot, items: [
            item(source: regular, destination: danglingLink, expectedSize: 2048)
        ])
        guard result.mediaItems.first?.status == .failed,
              !fileManager.fileExists(atPath: danglingTarget.path),
              (try? fileManager.destinationOfSymbolicLink(atPath: danglingLink.path)) != nil else {
            print("VERIFY FAIL: copy wrote through or removed a symbolic link at the destination")
            return false
        }

        // 4. A symbolic-link folder inside the destination cannot redirect a copy elsewhere.
        let linkedFolder = destinationRoot.appendingPathComponent("Driving", isDirectory: true)
        try fileManager.createSymbolicLink(at: linkedFolder, withDestinationURL: outsideRoot)
        result = await runCopy(sourceRoot: sourceRoot, destinationRoot: destinationRoot, items: [
            item(source: regular, destination: linkedFolder.appendingPathComponent("regular.MP4"), expectedSize: 2048)
        ])
        guard result.mediaItems.first?.status == .failed,
              !fileManager.fileExists(atPath: outsideRoot.appendingPathComponent("regular.MP4").path) else {
            print("VERIFY FAIL: copy wrote outside the chosen destination through a symbolic-link folder")
            return false
        }

        // 5. The ordinary path still copies and verifies.
        let plainDestination = destinationRoot.appendingPathComponent("regular.MP4")
        result = await runCopy(sourceRoot: sourceRoot, destinationRoot: destinationRoot, items: [
            item(source: regular, destination: plainDestination, expectedSize: 2048)
        ])
        guard result.mediaItems.first?.status == .copied,
              try Data(contentsOf: plainDestination) == Data(repeating: 5, count: 2048) else {
            print("VERIFY FAIL: hardened copy path did not copy a regular clip")
            return false
        }

        // 6. Downloading into the source is recognised, including through a symbolic link.
        let insideSource = sourceRoot.appendingPathComponent("Downloads", isDirectory: true)
        try fileManager.createDirectory(at: insideSource, withIntermediateDirectories: true)
        let aliasIntoSource = root.appendingPathComponent("alias-into-card", isDirectory: true)
        try fileManager.createSymbolicLink(at: aliasIntoSource, withDestinationURL: insideSource)
        let sibling = root.appendingPathComponent("card-backup", isDirectory: true)
        guard CopyExecutor.isDestination(insideSource, insideSource: sourceRoot),
              CopyExecutor.isDestination(sourceRoot, insideSource: sourceRoot),
              CopyExecutor.isDestination(aliasIntoSource, insideSource: sourceRoot),
              !CopyExecutor.isDestination(destinationRoot, insideSource: sourceRoot),
              !CopyExecutor.isDestination(sibling, insideSource: sourceRoot) else {
            print("VERIFY FAIL: destination-inside-source detection is wrong")
            return false
        }

        // 7. Camera-settings preservation plans regular files only.
        let config = sourceRoot.appendingPathComponent("config", isDirectory: true)
        try fileManager.createDirectory(at: config.appendingPathComponent("nested", isDirectory: true), withIntermediateDirectories: true)
        try Data("resolution=4K\n".utf8).write(to: config.appendingPathComponent("menu.ini"))
        try fileManager.createSymbolicLink(at: config.appendingPathComponent("linked.ini"), withDestinationURL: secret)
        guard mkfifo(config.appendingPathComponent("pipe.ini").path, 0o644) == 0 else {
            print("VERIFY FAIL: could not create the settings named-pipe fixture")
            return false
        }
        var filters = FilterState()
        filters.includeCameraSettings = true
        let plan = CopyPlanner().makePlan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            profile: .genericNewDashcam,
            clips: [],
            filters: filters
        )
        guard plan.supportItems.map(\.relativePath) == ["config/menu.ini"] else {
            print("VERIFY FAIL: settings preservation planned a non-regular entry: \(plan.supportItems.map(\.relativePath))")
            return false
        }

        // 8. Fixed-name metadata reads do not follow links and stay bounded.
        let scanner = CardScanner()
        let linkedEvidence = sourceRoot.appendingPathComponent("version.txt")
        try fileManager.createSymbolicLink(at: linkedEvidence, withDestinationURL: URL(fileURLWithPath: "/dev/zero"))
        let largeEvidence = sourceRoot.appendingPathComponent("large.txt")
        try Data(repeating: 0x41, count: 1_000_001).write(to: largeEvidence)
        let smallEvidence = sourceRoot.appendingPathComponent("small.txt")
        try Data("model: TEST1\n".utf8).write(to: smallEvidence)
        // A link to an ordinary small text file outside the card passes every type and
        // size check once followed, so only O_NOFOLLOW keeps its contents out.
        let outsideText = outsideRoot.appendingPathComponent("host-notes.txt")
        try Data("model: HOSTFILE\n".utf8).write(to: outsideText)
        let linkedText = sourceRoot.appendingPathComponent("config.txt")
        try fileManager.createSymbolicLink(at: linkedText, withDestinationURL: outsideText)
        guard scanner.evidenceText(at: linkedText) == nil,
              SafeFileRead.data(at: linkedText, maxBytes: 1024) == nil else {
            print("VERIFY FAIL: metadata read followed a link to a regular file outside the card")
            return false
        }
        guard scanner.evidenceText(at: linkedEvidence) == nil,
              scanner.evidenceText(at: largeEvidence) == nil,
              scanner.evidenceText(at: pipe) == nil,
              scanner.evidenceText(at: smallEvidence) == "model: TEST1\n" else {
            print("VERIFY FAIL: metadata read followed a link, blocked on a pipe, or ignored the size limit")
            return false
        }

        // 8b. The destination open itself (not just the earlier existence check) refuses a
        //     link that appears at the destination name, and never truncates an existing file.
        let racedTarget = outsideRoot.appendingPathComponent("raced-target.MP4")
        let racedLink = destinationRoot.appendingPathComponent("raced.MP4")
        try fileManager.createSymbolicLink(at: racedLink, withDestinationURL: racedTarget)
        let existing = destinationRoot.appendingPathComponent("existing.MP4")
        try Data(repeating: 9, count: 64).write(to: existing)
        let racedOpen = try? CopyExecutor.createExclusiveFileForWriting(racedLink)
        let existingOpen = try? CopyExecutor.createExclusiveFileForWriting(existing)
        guard racedOpen == nil, existingOpen == nil,
              !fileManager.fileExists(atPath: racedTarget.path),
              (try? Data(contentsOf: existing))?.count == 64 else {
            print("VERIFY FAIL: destination open followed a link or truncated an existing file")
            return false
        }

        // 8c. Finished merged exports are published under the final name without
        //     replacing a file that appeared there meanwhile.
        let partial = destinationRoot.appendingPathComponent(".partial-test.mp4")
        try Data(repeating: 3, count: 32).write(to: partial)
        let published = destinationRoot.appendingPathComponent("merged.MP4")
        try CopyExecutor.publishWithoutOverwriting(partial, as: published)
        let partial2 = destinationRoot.appendingPathComponent(".partial-test2.mp4")
        try Data(repeating: 4, count: 16).write(to: partial2)
        let secondPublish: Void? = try? CopyExecutor.publishWithoutOverwriting(partial2, as: published)
        guard !fileManager.fileExists(atPath: partial.path),
              secondPublish == nil,
              (try? Data(contentsOf: published)) == Data(repeating: 3, count: 32) else {
            print("VERIFY FAIL: merged export publish replaced an existing file or left the temporary name")
            return false
        }

        // 8d. Enumeration stops at the entry cap instead of growing without bound.
        let wide = root.appendingPathComponent("wide", isDirectory: true)
        try fileManager.createDirectory(at: wide, withIntermediateDirectories: true)
        for index in 0..<30 { try Data([0]).write(to: wide.appendingPathComponent("f\(index).MP4")) }
        guard let capped = try? scanner.enumerateFiles(sourceURL: wide, entryLimit: 10), capped.count == 10,
              let uncapped = try? scanner.enumerateFiles(sourceURL: wide), uncapped.count == 30 else {
            print("VERIFY FAIL: scan enumeration ignored the entry cap")
            return false
        }

        // 9. Extension keys sent with feedback are short technical tokens only.
        guard FeedbackExtensionKey.key(for: URL(fileURLWithPath: "/card/clip.MP4")) == "mp4",
              FeedbackExtensionKey.key(for: URL(fileURLWithPath: "/card/README")) == "[none]",
              FeedbackExtensionKey.key(for: URL(fileURLWithPath: "/card/passport.JaneExample1984")) == "[other]",
              FeedbackExtensionKey.key(for: URL(fileURLWithPath: "/card/notes.caf\u{e9}")) == "[other]" else {
            print("VERIFY FAIL: feedback extension keys can carry free-form name suffixes")
            return false
        }

        return true
    }

    private static func runCopy(sourceRoot: URL, destinationRoot: URL, items: [CopyPlanItem]) async -> CopyRunResult {
        let executor = CopyExecutor { _ in }
        return await executor.copy(plan: CopyPlan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            profile: .genericNewDashcam,
            clips: items.flatMap(\.orderedSourceClips),
            items: items
        ))
    }

    private static func item(source: URL, destination: URL, expectedSize: Int64) -> CopyPlanItem {
        CopyPlanItem(
            clip: ClipItem(
                sourceURL: source,
                relativePath: source.lastPathComponent,
                filename: source.lastPathComponent,
                mode: "driving",
                channel: "front",
                timestamp: nil,
                size: expectedSize,
                extensionLowercased: source.pathExtension.lowercased(),
                excludedReason: nil
            ),
            destinationURL: destination,
            status: .planned
        )
    }
}

/// Extension labels for feedback aggregates. A file "extension" is the tail of a
/// user-controlled name, so anything that is not a short ASCII token is bucketed.
enum FeedbackExtensionKey {
    static func key(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return "[none]" }
        return ext.range(of: #"^[a-z0-9]{1,10}$"#, options: .regularExpression) != nil ? ext : "[other]"
    }
}
