import Foundation

enum CopyExecutorVerification {
    static func run() async -> Bool {
        do {
            return try await runCases()
        } catch {
            print("VERIFY FAIL: copy executor verification error: \(error.localizedDescription)")
            return false
        }
    }

    private static func runCases() async throws -> Bool {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("dashcam-offloader-copy-verify-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        guard try await verifiesBasicCopy(sourceRoot: sourceRoot, destinationRoot: destinationRoot) else {
            return false
        }
        guard try await verifiesSkipExisting(sourceRoot: sourceRoot, destinationRoot: destinationRoot) else {
            return false
        }
        guard try await verifiesMergedExportSkipExisting(sourceRoot: sourceRoot, destinationRoot: destinationRoot) else {
            return false
        }
        guard try await verifiesSizeMismatchFailure(sourceRoot: sourceRoot, destinationRoot: destinationRoot) else {
            return false
        }
        guard try await verifiesCancellationCleanup(sourceRoot: sourceRoot, destinationRoot: destinationRoot) else {
            return false
        }

        return true
    }

    private static func verifiesBasicCopy(sourceRoot: URL, destinationRoot: URL) async throws -> Bool {
        let source = sourceRoot.appendingPathComponent("basic-copy.MP4")
        let destination = destinationRoot.appendingPathComponent("basic-copy.MP4")
        try Data(repeating: 1, count: 2048).write(to: source)

        let result = await runCopy(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            items: [
                item(source: source, relativePath: "basic-copy.MP4", destination: destination, expectedSize: 2048)
            ]
        )
        guard result.mediaItems.count == 1,
              result.mediaItems.first?.status == .copied,
              try fileSize(at: destination) == 2048 else {
            print("VERIFY FAIL: copy executor did not copy a normal file")
            return false
        }
        return true
    }

    private static func verifiesSkipExisting(sourceRoot: URL, destinationRoot: URL) async throws -> Bool {
        let source = sourceRoot.appendingPathComponent("skip-existing.MP4")
        let destination = destinationRoot.appendingPathComponent("skip-existing.MP4")
        try Data(repeating: 2, count: 1024).write(to: source)
        try Data("already here".utf8).write(to: destination)

        let result = await runCopy(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            items: [
                item(source: source, relativePath: "skip-existing.MP4", destination: destination, expectedSize: 1024)
            ]
        )
        let destinationData = try Data(contentsOf: destination)
        guard result.mediaItems.count == 1,
              result.mediaItems.first?.status == .skipped,
              result.mediaItems.first?.message == "Already in destination",
              destinationData == Data("already here".utf8) else {
            print("VERIFY FAIL: copy executor did not skip an existing file without overwriting")
            return false
        }
        return true
    }

    private static func verifiesMergedExportSkipExisting(sourceRoot: URL, destinationRoot: URL) async throws -> Bool {
        let first = sourceRoot.appendingPathComponent("loop-a.MP4")
        let second = sourceRoot.appendingPathComponent("loop-b.MP4")
        let destination = destinationRoot.appendingPathComponent("merged-loop.MP4")
        try Data(repeating: 3, count: 1024).write(to: first)
        try Data(repeating: 4, count: 1024).write(to: second)
        try Data("existing merged export".utf8).write(to: destination)

        let firstClip = clip(source: first, relativePath: "loop-a.MP4", size: 1024)
        let secondClip = clip(source: second, relativePath: "loop-b.MP4", size: 1024)
        let result = await runCopy(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            items: [
                CopyPlanItem(
                    clip: firstClip,
                    sourceClips: [firstClip, secondClip],
                    destinationURL: destination,
                    status: .planned
                )
            ]
        )
        let destinationData = try Data(contentsOf: destination)
        guard result.mediaItems.count == 1,
              result.mediaItems.first?.status == .skipped,
              result.mediaItems.first?.sourceFileCount == 2,
              destinationData == Data("existing merged export".utf8) else {
            print("VERIFY FAIL: copy executor did not skip an existing merged export")
            return false
        }
        return true
    }

    private static func verifiesSizeMismatchFailure(sourceRoot: URL, destinationRoot: URL) async throws -> Bool {
        let source = sourceRoot.appendingPathComponent("size-mismatch.MP4")
        let destination = destinationRoot.appendingPathComponent("size-mismatch.MP4")
        try Data(repeating: 5, count: 512).write(to: source)

        let result = await runCopy(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            items: [
                item(source: source, relativePath: "size-mismatch.MP4", destination: destination, expectedSize: 1024)
            ]
        )
        guard result.mediaItems.count == 1,
              result.mediaItems.first?.status == .failed,
              result.mediaItems.first?.message == CopyError.sizeVerificationFailed.localizedDescription,
              !FileManager.default.fileExists(atPath: destination.path) else {
            print("VERIFY FAIL: copy executor did not fail and clean up a size mismatch")
            return false
        }
        return true
    }

    private static func verifiesCancellationCleanup(sourceRoot: URL, destinationRoot: URL) async throws -> Bool {
        let source = sourceRoot.appendingPathComponent("cancel-large.MP4")
        let destination = destinationRoot.appendingPathComponent("cancel-large.MP4")
        try createSparseFile(at: source, size: 128 * 1024 * 1024)

        let cancelBox = await MainActor.run { CopyCancellationBox() }
        let executor = CopyExecutor { progress in
            cancelBox.cancelAfterProgress(progress)
        }
        let plan = plan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            items: [
                item(source: source, relativePath: "cancel-large.MP4", destination: destination, expectedSize: 128 * 1024 * 1024)
            ]
        )
        let task = Task {
            await executor.copy(plan: plan)
        }
        await MainActor.run {
            cancelBox.task = task
        }
        let result = await task.value

        guard result.mediaItems.count == 1,
              result.mediaItems.first?.status == .cancelled,
              !FileManager.default.fileExists(atPath: destination.path) else {
            print("VERIFY FAIL: copy executor did not cancel cleanly and remove the partial destination")
            return false
        }
        return true
    }

    private static func runCopy(sourceRoot: URL, destinationRoot: URL, items: [CopyPlanItem]) async -> CopyRunResult {
        let executor = CopyExecutor { _ in }
        return await executor.copy(plan: plan(sourceRoot: sourceRoot, destinationRoot: destinationRoot, items: items))
    }

    private static func plan(sourceRoot: URL, destinationRoot: URL, items: [CopyPlanItem]) -> CopyPlan {
        CopyPlan(
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            profile: .genericNewDashcam,
            clips: items.flatMap(\.orderedSourceClips),
            items: items
        )
    }

    private static func item(source: URL, relativePath: String, destination: URL, expectedSize: Int64) -> CopyPlanItem {
        CopyPlanItem(
            clip: clip(source: source, relativePath: relativePath, size: expectedSize),
            destinationURL: destination,
            status: .planned
        )
    }

    private static func clip(source: URL, relativePath: String, size: Int64) -> ClipItem {
        ClipItem(
            sourceURL: source,
            relativePath: relativePath,
            filename: source.lastPathComponent,
            mode: "driving",
            channel: "front",
            timestamp: nil,
            size: size,
            extensionLowercased: source.pathExtension.lowercased(),
            excludedReason: nil
        )
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        return Int64(size)
    }

    private static func createSparseFile(at url: URL, size: UInt64) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: size)
        try handle.close()
    }

}

@MainActor
private final class CopyCancellationBox {
    var task: Task<CopyRunResult, Never>?
    private var didCancel = false

    func cancelAfterProgress(_ progress: CopyProgress) {
        guard !didCancel, progress.copiedBytes > 0 else { return }
        didCancel = true
        task?.cancel()
    }
}
