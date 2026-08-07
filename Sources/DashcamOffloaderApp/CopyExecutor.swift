@preconcurrency import AVFoundation
import Foundation
import CryptoKit

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
                    let exported = try await concatenateVideoItem(item, destinationURL: item.destinationURL) { copiedChunk in
                        progress.copiedBytes += copiedChunk
                        await update(progress)
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
                        result.message = "Already in destination"
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
                    result.message = "Already in destination"
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
            guard try filesHaveMatchingSHA256(sourceURL, destination) else {
                throw CopyError.destinationConflict
            }
            return false
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
        guard try filesHaveMatchingSHA256(sourceURL, destination) else {
            throw CopyError.checksumVerificationFailed
        }
        didFinishWriting = true
        return true
    }

    private func filesHaveMatchingSHA256(_ firstURL: URL, _ secondURL: URL) throws -> Bool {
        try sha256Hex(for: firstURL) == sha256Hex(for: secondURL)
    }

    private func sha256Hex(for url: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var hasher = SHA256()
        while true {
            if Task.isCancelled { throw CancellationError() }
            let data = input.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
