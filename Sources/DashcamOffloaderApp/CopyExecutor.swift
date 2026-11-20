@preconcurrency import AVFoundation
import Foundation
import CryptoKit
import Darwin

struct CopyExecutor: Sendable {
    private static let copyBufferSize = 8 * 1024 * 1024
    private static let progressInterval: TimeInterval = 0.2

    private struct PendingCopy {
        let item: CopyPlanItem
        let verification: Task<Void, Error>
    }

    var progressHandler: @MainActor (CopyProgress) -> Void
    // Test seam for deterministic verification/copy overlap and injected corruption.
    var verificationHook: (@Sendable (URL) throws -> Void)? = nil
    // Test seams: monotonic cadence and an I/O gate receiving bytes already written.
    var progressClock: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var beforeChunkHook: (@Sendable (Int64) throws -> Void)? = nil

    func copy(plan: CopyPlan) async -> CopyRunResult {
        // File I/O and SHA256 must not inherit the caller's UI actor. Forward Stop
        // explicitly because an unstructured worker does not inherit cancellation.
        let worker = Task.detached(priority: .userInitiated) {
            await copyInBackground(plan: plan, delivery: CopyProgressDelivery(handler: progressHandler))
        }
        return await withTaskCancellationHandler {
            if Task.isCancelled { worker.cancel() }
            return await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private func copyInBackground(plan: CopyPlan, delivery: CopyProgressDelivery) async -> CopyRunResult {
        let totalBytes = plan.selectedBytes
        let startDate = Date()
        var progress = CopyProgress(
            totalBytes: totalBytes,
            totalFiles: plan.selectedFileCount,
            isRunning: true,
            startedAt: startDate,
            updatedAt: startDate
        )
        await update(progress, delivery: delivery)

        var results: [CopyPlanItem] = []
        var supportResults: [SupportFileItem] = []
        var pending: PendingCopy?
        for item in plan.items {
            guard !Task.isCancelled else { break }
            var result = item
            progress.currentFile = item.displayFilename
            await update(progress, delivery: delivery)

            do {
                if item.sourceFileCount > 1 {
                    if let previous = pending {
                        pending = nil
                        await finish(previous, progress: &progress, results: &results, delivery: delivery)
                    }
                    let exported = try await concatenateVideoItem(item, destinationURL: item.destinationURL, destinationRoot: plan.destinationRoot) { copiedChunk in
                        progress.copiedBytes = progress.copiedBytes.addingSaturating(copiedChunk)
                        await update(progress, delivery: delivery)
                    }
                    progress.completedFiles += 1
                    if exported {
                        result.status = .copied
                        result.message = "Combined \(item.sourceFileCount) loop clips"
                    } else {
                        result.status = .skipped
                        result.message = "Already in destination"
                        progress.copiedBytes = progress.copiedBytes.addingSaturating(item.totalSize)
                    }
                } else {
                    // A repeated destination must not be treated as an existing verified file.
                    if let previous = pending, previous.item.destinationURL == item.destinationURL {
                        pending = nil
                        await finish(previous, progress: &progress, results: &results, delivery: delivery)
                    }
                    let verification = try await copyOne(
                        sourceURL: item.clip.sourceURL,
                        destinationURL: item.destinationURL,
                        destinationRoot: plan.destinationRoot,
                        expectedSize: item.clip.size,
                        modificationDate: reliableRecordingDate(for: item.clip),
                        beforeCompletion: {
                            if let previous = pending {
                                pending = nil
                                await finish(previous, progress: &progress, results: &results, delivery: delivery)
                            }
                        }
                    ) { copiedChunk, waitForUI in
                        progress.copiedBytes = progress.copiedBytes.addingSaturating(copiedChunk)
                        await update(progress, delivery: delivery, waitForUI: waitForUI)
                    }
                    if let verification {
                        pending = PendingCopy(item: result, verification: verification)
                    } else {
                        if let previous = pending {
                            pending = nil
                            await finish(previous, progress: &progress, results: &results, delivery: delivery)
                        }
                        progress.completedFiles += 1
                        result.status = .skipped
                        result.message = "Already in destination"
                        progress.copiedBytes = progress.copiedBytes.addingSaturating(item.clip.size)
                    }
                }
            } catch is CancellationError {
                if let previous = pending {
                    pending = nil
                    await finish(previous, progress: &progress, results: &results, delivery: delivery)
                }
                result.status = .cancelled
                result.message = "Stopped by user"
                results.append(result)
                await update(progress, delivery: delivery)
                break
            } catch {
                if let previous = pending {
                    pending = nil
                    await finish(previous, progress: &progress, results: &results, delivery: delivery)
                }
                progress.completedFiles += 1
                result.status = .failed
                result.message = error.localizedDescription
            }
            if result.status != .planned { results.append(result) }
            await update(progress, delivery: delivery)
        }

        if let previous = pending {
            pending = nil
            await finish(previous, progress: &progress, results: &results, delivery: delivery)
        }

        for item in plan.supportItems {
            guard !Task.isCancelled else { break }
            var result = item
            progress.currentFile = item.relativePath
            await update(progress, delivery: delivery)

            do {
                let verification = try await copyOne(
                    sourceURL: item.sourceURL,
                    destinationURL: item.destinationURL,
                    destinationRoot: plan.destinationRoot,
                    expectedSize: item.size,
                    modificationDate: nil,
                    beforeCompletion: {}
                ) { copiedChunk, waitForUI in
                    progress.copiedBytes = progress.copiedBytes.addingSaturating(copiedChunk)
                    await update(progress, delivery: delivery, waitForUI: waitForUI)
                }
                if let verification {
                    try await withTaskCancellationHandler {
                        try await verification.value
                    } onCancel: {
                        verification.cancel()
                    }
                }
                progress.completedFiles += 1
                if verification != nil {
                    result.status = .copied
                    result.message = "Copied"
                } else {
                    result.status = .skipped
                    result.message = "Already in destination"
                    progress.copiedBytes = progress.copiedBytes.addingSaturating(item.size)
                }
            } catch is CancellationError {
                result.status = .cancelled
                result.message = "Stopped by user"
                supportResults.append(result)
                await update(progress, delivery: delivery)
                break
            } catch {
                progress.completedFiles += 1
                result.status = .failed
                result.message = error.localizedDescription
            }
            supportResults.append(result)
            await update(progress, delivery: delivery)
        }

        let stopped = Task.isCancelled ||
            results.contains { $0.status == .cancelled } ||
            supportResults.contains { $0.status == .cancelled }

        if stopped {
            progress.summary = "Download stopped after \(progress.completedFiles) of \(progress.totalFiles) files"
        } else {
            let copiedCount = results.filter { $0.status == .copied }.count + supportResults.filter { $0.status == .copied }.count
            let skippedCount = results.filter { $0.status == .skipped }.count + supportResults.filter { $0.status == .skipped }.count
            let failedCount = results.filter { $0.status == .failed }.count + supportResults.filter { $0.status == .failed }.count
            let copiedBytes = results.filter { $0.status == .copied }.reduce(Int64(0)) { $0.addingSaturating($1.totalSize) }
                .addingSaturating(supportResults.filter { $0.status == .copied }.reduce(Int64(0)) { $0.addingSaturating($1.size) })
            if copiedCount == 0 && failedCount == 0 && skippedCount > 0 {
                progress.summary = "All \(skippedCount) files were already in the destination"
            } else {
                var parts = ["Downloaded \(copiedCount) files (\(copiedBytes.formattedBytes))"]
                if skippedCount > 0 {
                    parts.append("\(skippedCount) already in destination")
                }
                if failedCount > 0 {
                    parts.append("\(failedCount) failed")
                }
                progress.summary = parts.joined(separator: ", ")
            }
        }

        progress.currentFile = ""
        progress.isRunning = false
        if !stopped {
            progress.copiedBytes = max(progress.copiedBytes, totalBytes)
        }
        progress.updatedAt = Date()
        await update(progress, delivery: delivery)

        return CopyRunResult(mediaItems: results, supportItems: supportResults)
    }

    private func update(_ progress: CopyProgress, delivery: CopyProgressDelivery, waitForUI: Bool = true) async {
        var updatedProgress = progress
        updatedProgress.updatedAt = Date()
        await delivery.publish(updatedProgress, waitForUI: waitForUI)
    }

    private func finish(_ pending: PendingCopy, progress: inout CopyProgress, results: inout [CopyPlanItem], delivery: CopyProgressDelivery) async {
        var result = pending.item
        if Task.isCancelled { pending.verification.cancel() }
        do {
            try await withTaskCancellationHandler {
                try await pending.verification.value
            } onCancel: {
                pending.verification.cancel()
            }
            // A verified file stays complete even if a later copy was cancelled.
            result.status = .copied
            result.message = "Copied"
        } catch is CancellationError {
            result.status = .cancelled
            result.message = "Stopped by user"
        } catch {
            result.status = .failed
            result.message = error.localizedDescription
        }
        if result.status != .cancelled { progress.completedFiles += 1 }
        results.append(result)
        await update(progress, delivery: delivery)
    }

    private func copyOne(
        sourceURL: URL,
        destinationURL: URL,
        destinationRoot: URL,
        expectedSize: Int64,
        modificationDate: Date?,
        beforeCompletion: () async -> Void,
        progress: (Int64, Bool) async -> Void
    ) async throws -> Task<Void, Error>? {
        let fileManager = FileManager.default
        let destination = destinationURL
        let destinationDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try Self.requireContainedDestination(directory: destinationDirectory, destinationRoot: destinationRoot)

        // lstat semantics: a dangling symbolic link is an existing entry, not a free name.
        if Self.entryExists(atPath: destination.path) {
            guard try filesHaveMatchingSHA256(sourceURL, destination) else {
                throw CopyError.destinationConflict
            }
            return nil
        }

        // Never follow a link or open a pipe/device/directory that replaced the scanned file.
        let input = try Self.openRegularFileForReading(sourceURL)
        defer { try? input.close() }
        // O_EXCL: this call owns the file it removes on failure and can never
        // truncate, replace or delete an entry that appeared after the check above.
        let output = try Self.createExclusiveFileForWriting(destination)
        var didFinishWriting = false
        defer {
            if !didFinishWriting {
                try? fileManager.removeItem(at: destination)
            }
        }
        var outputIsClosed = false
        defer {
            if !outputIsClosed {
                try? output.close()
            }
        }
        var sourceHasher = SHA256()
        var unreportedBytes: Int64 = 0
        var writtenBytes: Int64 = 0
        var lastProgressTime: TimeInterval?

        while true {
            if Task.isCancelled {
                throw CancellationError()
            }
            try beforeChunkHook?(writtenBytes)
            // Throwing variants: the legacy readData/write calls raise Objective-C
            // exceptions on I/O errors (card removed, disk full), which Swift cannot
            // catch; the process would abort and leave a partial file behind.
            let data = try input.read(upToCount: Self.copyBufferSize) ?? Data()
            guard !data.isEmpty else { break }
            sourceHasher.update(data: data)
            try output.write(contentsOf: data)
            unreportedBytes += Int64(data.count)
            writtenBytes += Int64(data.count)
            let now = progressClock()
            // Report the first chunk for prompt feedback/Stop, then at most 5 Hz.
            // UI rendering must not become a per-buffer throughput dependency.
            if lastProgressTime == nil || now - lastProgressTime! >= Self.progressInterval {
                await progress(unreportedBytes, lastProgressTime == nil)
                unreportedBytes = 0
                lastProgressTime = progressClock()
            }
        }
        // Flush before joining verification so byte accounting and overlap remain exact.
        if unreportedBytes > 0 { await progress(unreportedBytes, true) }
        await beforeCompletion()
        if Task.isCancelled { throw CancellationError() }
        // Push the bytes to the device before the copy is verified and reported as done.
        try output.synchronize()
        try output.close()
        outputIsClosed = true

        // Verification owns cleanup once this fully-written destination is handed off.
        didFinishWriting = true
        let sourceDigest = Array(sourceHasher.finalize())
        return Task.detached {
            do {
                try Self.verifyCopiedFile(destination, expectedSize: expectedSize, sourceDigest: sourceDigest, modificationDate: modificationDate, hook: verificationHook)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
    }

    private static func verifyCopiedFile(_ destination: URL, expectedSize: Int64, sourceDigest: [UInt8], modificationDate: Date?, hook: (@Sendable (URL) throws -> Void)?) throws {
        if Task.isCancelled { throw CancellationError() }
        let copiedSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        guard copiedSize == expectedSize else {
            throw CopyError.sizeVerificationFailed
        }
        try hook?(destination)
        if Task.isCancelled { throw CancellationError() }
        let destinationDigest = Array(try sha256Digest(for: destination))
        guard sourceDigest == destinationDigest else {
            throw CopyError.checksumVerificationFailed
        }
        if Task.isCancelled { throw CancellationError() }
        if let modificationDate {
            try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: destination.path)
        }
    }

    private func reliableRecordingDate(for clip: ClipItem) -> Date? {
        guard clip.timestampSource == .filename,
              !clip.hasSuspiciousTimestamp else {
            return nil
        }
        return clip.timestamp
    }

    private func filesHaveMatchingSHA256(_ sourceURL: URL, _ destinationURL: URL) throws -> Bool {
        try Array(Self.sha256Digest(for: sourceURL, isSource: true)) == Array(Self.sha256Digest(for: destinationURL))
    }

    private static func sha256Digest(for url: URL, isSource: Bool = false) throws -> SHA256.Digest {
        let input = try isSource ? openRegularFileForReading(url) : FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        if !isSource {
            // Best effort: read the copy back from the device rather than the page cache.
            _ = fcntl(input.fileDescriptor, F_NOCACHE, 1)
        }
        var hasher = SHA256()
        while true {
            if Task.isCancelled { throw CancellationError() }
            let data = try input.read(upToCount: Self.copyBufferSize) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize()
    }

    /// Opens a source without following a final symbolic link and refuses anything
    /// that is not a regular file. O_NONBLOCK keeps a named pipe from blocking open.
    static func openRegularFileForReading(_ url: URL) throws -> FileHandle {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            let code = errno
            if code == ELOOP { throw CopyError.sourceNotRegularFile }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
            close(descriptor)
            throw CopyError.sourceNotRegularFile
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    /// Creates the destination only if no entry of any kind has that name.
    /// Give a finished temporary file its final name. link(2) fails with EEXIST instead of
    /// replacing whatever appeared at the final name meanwhile.
    static func publishWithoutOverwriting(_ temporaryURL: URL, as finalURL: URL) throws {
        guard link(temporaryURL.path, finalURL.path) == 0 else {
            let code = errno
            if code == EEXIST { throw CopyError.destinationConflict }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
        unlink(temporaryURL.path)
    }

    static func createExclusiveFileForWriting(_ url: URL) throws -> FileHandle {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else {
            let code = errno
            if code == EEXIST { throw CopyError.destinationConflict }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    static func entryExists(atPath path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0
    }

    static func isPath(_ path: String, within root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    /// Symbolic links already present below the destination must not redirect a
    /// copy outside the folder the user chose (or back onto a source card).
    static func requireContainedDestination(directory: URL, destinationRoot: URL) throws {
        let resolvedDirectory = directory.resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedRoot = destinationRoot.resolvingSymlinksInPath().standardizedFileURL.path
        guard isPath(resolvedDirectory, within: resolvedRoot) else {
            throw CopyError.destinationOutsideChosenFolder
        }
    }

    /// True when copying would write onto the source itself.
    static func isDestination(_ destinationRoot: URL, insideSource sourceRoot: URL) -> Bool {
        isPath(
            destinationRoot.resolvingSymlinksInPath().standardizedFileURL.path,
            within: sourceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        )
    }

    private func concatenateVideoItem(
        _ item: CopyPlanItem,
        destinationURL: URL,
        destinationRoot: URL,
        progress: (Int64) async -> Void
    ) async throws -> Bool {
        let fileManager = FileManager.default
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try Self.requireContainedDestination(directory: destinationDirectory, destinationRoot: destinationRoot)

        if Self.entryExists(atPath: destinationURL.path) {
            return false
        }
        // Export to a hidden temporary name and publish it only when complete, so an
        // interrupted export can never sit under the final name looking like a finished file.
        let partialURL = destinationDirectory.appendingPathComponent(".partial-\(UUID().uuidString).mp4")
        defer { try? fileManager.removeItem(at: partialURL) }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CopyError.videoConcatenationFailed("Could not create video track")
        }
        var audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var preferredTransform = CGAffineTransform.identity
        for clip in item.orderedSourceClips {
            if Task.isCancelled { throw CancellationError() }
            let asset = AVURLAsset(url: clip.sourceURL)
            guard let sourceVideo = asset.tracks(withMediaType: .video).first else {
                throw CopyError.videoConcatenationFailed("Missing video track in \(clip.filename)")
            }
            let duration = asset.duration
            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceVideo,
                at: cursor
            )
            if cursor == .zero {
                preferredTransform = sourceVideo.preferredTransform
            }

            if let sourceAudio = asset.tracks(withMediaType: .audio).first {
                if audioTrack == nil {
                    audioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                }
                try audioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceAudio,
                    at: cursor
                )
            }
            cursor = cursor + duration
        }
        videoTrack.preferredTransform = preferredTransform

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw CopyError.videoConcatenationFailed("Could not create export session")
        }
        exportSession.outputURL = partialURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false

        let exportCancellation = ExportCancellationBox(exportSession)
        await withTaskCancellationHandler {
            await exportSession.export()
        } onCancel: {
            exportCancellation.cancel()
        }
        switch exportSession.status {
        case .completed:
            if let modificationDate = reliableRecordingDate(for: item.clip) {
                try fileManager.setAttributes([.modificationDate: modificationDate], ofItemAtPath: partialURL.path)
            }
            try Self.publishWithoutOverwriting(partialURL, as: destinationURL)
            await progress(item.totalSize)
            return true
        case .cancelled:
            throw CancellationError()
        default:
            throw CopyError.videoConcatenationFailed(exportSession.error?.localizedDescription ?? "Export failed")
        }
    }
}

// One in-flight UI callback and one latest snapshot: a slow view cannot build an
// unbounded task queue or stall byte I/O. File boundaries/final state drain it.
private actor CopyProgressDelivery {
    let handler: @MainActor (CopyProgress) -> Void
    private var latest: CopyProgress?
    private var deliveryTask: Task<Void, Never>?

    init(handler: @escaping @MainActor (CopyProgress) -> Void) {
        self.handler = handler
    }

    func publish(_ progress: CopyProgress, waitForUI: Bool) async {
        latest = progress
        if deliveryTask == nil {
            deliveryTask = Task { await drain() }
        }
        if waitForUI { await deliveryTask?.value }
    }

    private func drain() async {
        while let progress = latest {
            latest = nil
            await handler(progress)
        }
        deliveryTask = nil
    }
}

private final class ExportCancellationBox: @unchecked Sendable {
    private let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }

    func cancel() {
        session.cancelExport()
    }
}

struct CopyRunResult: Hashable, Sendable {
    var mediaItems: [CopyPlanItem]
    var supportItems: [SupportFileItem]

    var failedCount: Int {
        mediaItems.filter { $0.status == .failed }.count + supportItems.filter { $0.status == .failed }.count
    }
}

enum CopyError: LocalizedError {
    case sizeVerificationFailed
    case checksumVerificationFailed
    case destinationConflict
    case sourceNotRegularFile
    case destinationOutsideChosenFolder
    case videoConcatenationFailed(String)

    var errorDescription: String? {
        switch self {
        case .sizeVerificationFailed:
            return "Copied file size did not match source"
        case .checksumVerificationFailed:
            return "Copied file contents did not match source"
        case .destinationConflict:
            return "A different file with this name already exists in the destination"
        case .sourceNotRegularFile:
            return "The source is no longer a regular file and was not copied"
        case .destinationOutsideChosenFolder:
            return "The destination folder leads outside the chosen download folder; nothing was written"
        case .videoConcatenationFailed(let message):
            return "Could not combine video clips: \(message)"
        }
    }
}
