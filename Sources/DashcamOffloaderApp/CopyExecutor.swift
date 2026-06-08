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
            var result = item
            progress.currentFile = item.clip.filename
            await update(progress)

            do {
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
            } catch {
                progress.completedFiles += 1
                result.status = .failed
                result.message = error.localizedDescription
            }
            results.append(result)
            await update(progress)
        }

        for item in plan.supportItems {
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
            } catch {
                progress.completedFiles += 1
                result.status = .failed
                result.message = error.localizedDescription
            }
            supportResults.append(result)
            await update(progress)
        }

        do {
            try ManifestWriter.write(plan: plan, results: results, supportResults: supportResults)
            let copiedCount = results.filter { $0.status == .copied }.count + supportResults.filter { $0.status == .copied }.count
            let skippedCount = results.filter { $0.status == .skipped }.count + supportResults.filter { $0.status == .skipped }.count
            let failedCount = results.filter { $0.status == .failed }.count + supportResults.filter { $0.status == .failed }.count
            progress.summary = "Completed \(copiedCount) copied, \(skippedCount) skipped, \(failedCount) failed"
        } catch {
            progress.summary = "Copy finished, but manifest failed: \(error.localizedDescription)"
        }

        progress.currentFile = ""
        progress.isRunning = false
        progress.copiedBytes = max(progress.copiedBytes, totalBytes)
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
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        while true {
            let data = input.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else { break }
            output.write(data)
            await progress(Int64(data.count))
        }

        let copiedSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        guard copiedSize == expectedSize else {
            throw CopyError.sizeVerificationFailed
        }
        return true
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

    var errorDescription: String? {
        switch self {
        case .conflictingDestination(let path):
            return "Destination exists with a different size: \(path)"
        case .sizeVerificationFailed:
            return "Copied file size did not match source"
        }
    }
}
