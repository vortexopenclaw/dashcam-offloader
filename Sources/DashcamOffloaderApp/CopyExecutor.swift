@preconcurrency import AVFoundation
import Foundation

struct CopyExecutor {
    var progressHandler: @MainActor (CopyProgress) -> Void

    func copy(plan: CopyPlan) async -> CopyRunResult {
        let totalBytes = plan.selectedBytes
        let startDate = Date()
        var progress = CopyProgress(
            totalBytes: totalBytes,
            totalFiles: plan.selectedFileCount,
            isRunning: true,
            startedAt: startDate,
            updatedAt: startDate
        )
        await update(progress)

        var results: [CopyPlanItem] = []
        var supportResults: [SupportFileItem] = []
        for item in plan.items {
            guard !Task.isCancelled else { break }
            var result = item
            progress.currentFile = item.displayFilename
            await update(progress)

            do {
                if item.sourceFileCount > 1 {
                    try await concatenateVideoItem(item, destinationURL: item.destinationURL) { copiedChunk in
                        progress.copiedBytes += copiedChunk
                        await update(progress)
                    }
                    progress.completedFiles += 1
                    result.status = .copied
                    result.message = "Combined \(item.sourceFileCount) loop clips"
                } else {
                    let copied = try await copyOne(sourceURL: item.clip.sourceURL, destinationURL: item.destinationURL, expectedSize: item.clip.size) { copiedChunk in
                        progress.copiedBytes += copiedChunk
                        await update(progress)
                    }
                    progress.completedFiles += 1
                    if copied {
                        result.status = .copied
                        result.message = "Copied"
                    } else {
                        result.status = .skipped
                        result.message = "Existing file matched size"
                        progress.copiedBytes += item.clip.size
                    }
                }
            } catch is CancellationError {
                result.status = .cancelled
                result.message = "Stopped by user"
                results.append(result)
                await update(progress)
                break
            } catch {
                progress.completedFiles += 1
                result.status = .failed
                result.message = error.localizedDescription
            }
            results.append(result)
            await update(progress)
        }

        for item in plan.supportItems {
            guard !Task.isCancelled else { break }
            var result = item
            progress.currentFile = item.relativePath
            await update(progress)

            do {
                let copied = try await copyOne(sourceURL: item.sourceURL, destinationURL: item.destinationURL, expectedSize: item.size) { copiedChunk in
                    progress.copiedBytes += copiedChunk
                    await update(progress)
                }
                progress.completedFiles += 1
                if copied {
                    result.status = .copied
                    result.message = "Copied"
                } else {
                    result.status = .skipped
                    result.message = "Existing file matched size"
                    progress.copiedBytes += item.size
                }
            } catch is CancellationError {
                result.status = .cancelled
                result.message = "Stopped by user"
                supportResults.append(result)
                await update(progress)
                break
            } catch {
                progress.completedFiles += 1
                result.status = .failed
                result.message = error.localizedDescription
            }
            supportResults.append(result)
            await update(progress)
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
            progress.summary = "Completed \(copiedCount) copied, \(skippedCount) skipped, \(failedCount) failed"
        }

        progress.currentFile = ""
        progress.isRunning = false
        if !stopped {
            progress.copiedBytes = max(progress.copiedBytes, totalBytes)
        }
        progress.updatedAt = Date()
        await update(progress)

        return CopyRunResult(mediaItems: results, supportItems: supportResults)
    }

    private func update(_ progress: CopyProgress) async {
        var updatedProgress = progress
        updatedProgress.updatedAt = Date()
        await progressHandler(updatedProgress)
    }

    private func copyOne(sourceURL: URL, destinationURL: URL, expectedSize: Int64, progress: (Int64) async -> Void) async throws -> Bool {
        let fileManager = FileManager.default
        let destination = destinationURL
        let destinationDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destination.path) {
            let destinationSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            if destinationSize == expectedSize {
                return false
            }
            throw CopyError.conflictingDestination(destination.path)
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
        defer { try? output.close() }

        while true {
            if Task.isCancelled {
                throw CancellationError()
            }
            let data = input.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else { break }
            output.write(data)
            await progress(Int64(data.count))
        }

        let copiedSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        guard copiedSize == expectedSize else {
            throw CopyError.sizeVerificationFailed
        }
        didFinishWriting = true
        return true
    }

    private func concatenateVideoItem(
        _ item: CopyPlanItem,
        destinationURL: URL,
        progress: (Int64) async -> Void
    ) async throws {
        let fileManager = FileManager.default
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            throw CopyError.conflictingDestination(destinationURL.path)
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
            didFinishExport = true
            await progress(item.totalSize)
        case .cancelled:
            throw CancellationError()
        default:
            throw CopyError.videoConcatenationFailed(exportSession.error?.localizedDescription ?? "Export failed")
        }
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
    case conflictingDestination(String)
    case sizeVerificationFailed
    case videoConcatenationFailed(String)

    var errorDescription: String? {
        switch self {
        case .conflictingDestination(let path):
            return "Destination exists with a different size: \(path)"
        case .sizeVerificationFailed:
            return "Copied file size did not match source"
        case .videoConcatenationFailed(let message):
            return "Could not combine video clips: \(message)"
        }
    }
}
