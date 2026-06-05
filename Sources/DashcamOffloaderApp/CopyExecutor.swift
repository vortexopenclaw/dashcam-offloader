import Foundation

struct CopyExecutor {
    var progressHandler: @MainActor (CopyProgress) -> Void

    func copy(plan: CopyPlan) async -> [CopyPlanItem] {
        let totalBytes = plan.items.reduce(Int64(0)) { $0 + $1.clip.size }
        var progress = CopyProgress(totalBytes: totalBytes, totalFiles: plan.items.count, isRunning: true)
        await update(progress)

        var results: [CopyPlanItem] = []
        for item in plan.items {
            var result = item
            progress.currentFile = item.clip.filename
            await update(progress)

            do {
                let copied = try await copyOne(item: item) { copiedChunk in
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

        do {
            try ManifestWriter.write(plan: plan, results: results)
            progress.summary = "Completed \(results.filter { $0.status == .copied }.count) copied, \(results.filter { $0.status == .skipped }.count) skipped, \(results.filter { $0.status == .failed }.count) failed"
        } catch {
            progress.summary = "Copy finished, but manifest failed: \(error.localizedDescription)"
        }

        progress.currentFile = ""
        progress.isRunning = false
        progress.copiedBytes = max(progress.copiedBytes, totalBytes)
        await update(progress)

        return results
    }

    private func update(_ progress: CopyProgress) async {
        await progressHandler(progress)
    }

    private func copyOne(item: CopyPlanItem, progress: (Int64) async -> Void) async throws -> Bool {
        let fileManager = FileManager.default
        let destination = item.destinationURL
        let destinationDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destination.path) {
            let destinationSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            if destinationSize == item.clip.size {
                return false
            }
            throw CopyError.conflictingDestination(destination.path)
        }

        let input = try FileHandle(forReadingFrom: item.clip.sourceURL)
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
        guard copiedSize == item.clip.size else {
            throw CopyError.sizeVerificationFailed
        }
        return true
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
