@preconcurrency import AVFoundation
import Foundation
import CryptoKit

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
                    let exported = try await concatenateVideoItem(item, destinationURL: item.destinationURL) { copiedChunk in
                        progress.copiedBytes += copiedChunk
                        await update(progress, delivery: delivery)
                    }
                    progress.completedFiles += 1
                    if exported {
                        result.status = .copied
                        result.message = "Combined \(item.sourceFileCount) loop clips"
                    } else {
                        result.status = .skipped
                        result.message = "Already in destination"
                        progress.copiedBytes += item.totalSize
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
                        expectedSize: item.clip.size,
                        modificationDate: reliableRecordingDate(for: item.clip),
                        beforeCompletion: {
                            if let previous = pending {
                                pending = nil
                                await finish(previous, progress: &progress, results: &results, delivery: delivery)
                            }
                        }
                    ) { copiedChunk, waitForUI in
                        progress.copiedBytes += copiedChunk
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
                        progress.copiedBytes += item.clip.size
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
                    expectedSize: item.size,
                    modificationDate: nil,
                    beforeCompletion: {}
                ) { copiedChunk, waitForUI in
                    progress.copiedBytes += copiedChunk
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
                    progress.copiedBytes += item.size
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
            let copiedBytes = results.filter { $0.status == .copied }.reduce(Int64(0)) { $0 + $1.totalSize } +
                supportResults.filter { $0.status == .copied }.reduce(Int64(0)) { $0 + $1.size }
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
        expectedSize: Int64,
        modificationDate: Date?,
        beforeCompletion: () async -> Void,
        progress: (Int64, Bool) async -> Void
    ) async throws -> Task<Void, Error>? {
        let fileManager = FileManager.default
        let destination = destinationURL
        let destinationDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destination.path) {
            guard try filesHaveMatchingSHA256(sourceURL, destination) else {
                throw CopyError.destinationConflict
            }
            return nil
        }

        let input = try FileHandle(forReadingFrom: sourceURL)
        defer { try? input.close() }
        fileManager.createFile(atPath: destination.path, contents: nil)
        var didFinishWriting = false
        defer {
            if !didFinishWriting {
                try? fileManager.removeItem(at: destination)
            }
        }
        let output = try FileHandle(forWritingTo: destination)
        var outputIsClosed = false
        defer {
            if !outputIsClosed {
                try? output.close()
            }
        }
        var sourceHasher = SHA256()
        var unreportedBytes: Int64 = 0
        var lastProgressTime: TimeInterval?

        while true {
            if Task.isCancelled {
                throw CancellationError()
            }
            let data = input.readData(ofLength: Self.copyBufferSize)
            guard !data.isEmpty else { break }
            sourceHasher.update(data: data)
            output.write(data)
            unreportedBytes += Int64(data.count)
            let now = ProcessInfo.processInfo.systemUptime
            // Report the first chunk for prompt feedback/Stop, then at most 5 Hz.
            // UI rendering must not become a per-buffer throughput dependency.
            if lastProgressTime == nil || now - lastProgressTime! >= Self.progressInterval {
                await progress(unreportedBytes, lastProgressTime == nil)
                unreportedBytes = 0
                lastProgressTime = ProcessInfo.processInfo.systemUptime
            }
        }
        // Flush before joining verification so byte accounting and overlap remain exact.
        if unreportedBytes > 0 { await progress(unreportedBytes, true) }
        await beforeCompletion()
        if Task.isCancelled { throw CancellationError() }
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

    private func filesHaveMatchingSHA256(_ firstURL: URL, _ secondURL: URL) throws -> Bool {
        try Array(Self.sha256Digest(for: firstURL)) == Array(Self.sha256Digest(for: secondURL))
    }

    private static func sha256Digest(for url: URL) throws -> SHA256.Digest {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var hasher = SHA256()
        while true {
            if Task.isCancelled { throw CancellationError() }
            let data = input.readData(ofLength: Self.copyBufferSize)
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize()
    }

    private func concatenateVideoItem(
        _ item: CopyPlanItem,
        destinationURL: URL,
        progress: (Int64) async -> Void
    ) async throws -> Bool {
        let fileManager = FileManager.default
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            return false
        }
        var didFinishExport = false
        defer {
            if !didFinishExport {
                try? fileManager.removeItem(at: destinationURL)
            }
        }

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
        exportSession.outputURL = destinationURL
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
                try fileManager.setAttributes([.modificationDate: modificationDate], ofItemAtPath: destinationURL.path)
            }
            didFinishExport = true
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
    case videoConcatenationFailed(String)

    var errorDescription: String? {
        switch self {
        case .sizeVerificationFailed:
            return "Copied file size did not match source"
        case .checksumVerificationFailed:
            return "Copied file contents did not match source"
        case .destinationConflict:
            return "A different file with this name already exists in the destination"
        case .videoConcatenationFailed(let message):
            return "Could not combine video clips: \(message)"
        }
    }
}
