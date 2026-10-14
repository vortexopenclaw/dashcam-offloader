import Foundation

// Correctness checks, not a hardware throughput benchmark.
enum CopyThroughputVerification {
    @MainActor
    static func run() async -> Bool {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("copy-throughput-verify-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let source = root.appendingPathComponent("source.MP4")
            let destination = root.appendingPathComponent("destination.MP4")
            let size: Int64 = 256 * 1024 * 1024
            fm.createFile(atPath: source.path, contents: nil)
            let handle = try FileHandle(forWritingTo: source)
            try handle.truncate(atOffset: UInt64(size))
            try handle.close()
            let clip = ClipItem(sourceURL: source, relativePath: source.lastPathComponent,
                                filename: source.lastPathComponent, mode: "driving", channel: "front",
                                timestamp: nil, size: size, extensionLowercased: "mp4", excludedReason: nil)
            let item = CopyPlanItem(clip: clip, destinationURL: destination, status: .planned)
            let plan = CopyPlan(sourceRoot: root, destinationRoot: root, profile: .genericNewDashcam,
                                clips: [clip], items: [item])
            let probe = ThroughputProgressProbe()
            let result = await CopyExecutor { probe.observe($0) }.copy(plan: plan)
            guard result.mediaItems.map(\.status) == [.copied],
                  probe.latest?.copiedBytes == size, probe.latest?.completedFiles == 1,
                  probe.latest?.isRunning == false, probe.monotonic,
                  probe.byteUpdates >= 2, probe.byteUpdates < 32,
                  !probe.tooFrequent else {
                print("VERIFY FAIL: throttled progress lost bytes or remained buffer-bound: updates=\(probe.byteUpdates)")
                return false
            }
            print("VERIFY PASS: copy progress throttled with exact final bytes (\(probe.byteUpdates) updates / 32 buffers)")

            // A duplicate path must wait for pending verification and then hash-check,
            // not overwrite or accept a still-unverified file.
            try fm.removeItem(at: destination)
            let duplicatePlan = CopyPlan(sourceRoot: root, destinationRoot: root, profile: .genericNewDashcam,
                                         clips: [clip], items: [item, item])
            let duplicateResult = await CopyExecutor { _ in }.copy(plan: duplicatePlan)
            guard duplicateResult.mediaItems.map(\.status) == [.copied, .skipped],
                  try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(size) else {
                print("VERIFY FAIL: repeated destination was not verified before skip")
                return false
            }
            print("VERIFY PASS: repeated destination preserves verification-before-skip")

            // Block a periodic MainActor callback until the background writer has
            // finished. A per-buffer awaited UI callback deadlocks this bounded probe.
            try fm.removeItem(at: destination)
            let slowDestination = root.appendingPathComponent("slow-destination.MP4")
            let slowSize: Int64 = 1024 * 1024 * 1024
            let growingHandle = try FileHandle(forWritingTo: source)
            try growingHandle.truncate(atOffset: UInt64(slowSize))
            try growingHandle.close()
            var slowClip = clip
            slowClip.size = slowSize
            let slowPlan = CopyPlan(sourceRoot: root, destinationRoot: root, profile: .genericNewDashcam,
                                    clips: [slowClip], items: [CopyPlanItem(clip: slowClip, destinationURL: slowDestination, status: .planned)])
            let slowProbe = SlowCopyProgressProbe(destination: slowDestination)
            let slowResult = await CopyExecutor { slowProbe.observe($0) }.copy(plan: slowPlan)
            guard slowProbe.blockedPeriodicUpdate, slowProbe.writerCompletedWhileUIBlocked,
                  slowResult.mediaItems.map(\.status) == [.copied],
                  slowProbe.latest?.copiedBytes == slowSize, slowProbe.latest?.isRunning == false else {
                print("VERIFY FAIL: slow UI callback stalled the background writer: blocked=\(slowProbe.blockedPeriodicUpdate) finished=\(slowProbe.writerCompletedWhileUIBlocked) last=\(slowProbe.lastObservedSize) progress=\(slowProbe.latest?.copiedBytes ?? -1) statuses=\(slowResult.mediaItems.map(\.status))")
                return false
            }
            print("VERIFY PASS: byte I/O continues while a periodic MainActor callback is blocked")

            let cancelled = Task { await CopyExecutor { _ in }.copy(plan: plan) }
            cancelled.cancel()
            let cancelledResult = await cancelled.value
            guard cancelledResult.mediaItems.isEmpty, !fm.fileExists(atPath: destination.path) else {
                print("VERIFY FAIL: already-cancelled caller started detached copy")
                return false
            }
            print("VERIFY PASS: cancellation forwarded before detached copy starts")
            return true
        } catch {
            print("VERIFY FAIL: copy throughput regression: \(error.localizedDescription)")
            return false
        }
    }
}

@MainActor
private final class SlowCopyProgressProbe {
    let destination: URL
    var latest: CopyProgress?
    var blockedPeriodicUpdate = false
    var writerCompletedWhileUIBlocked = false
    var lastObservedSize: Int64 = -1

    init(destination: URL) { self.destination = destination }

    func observe(_ progress: CopyProgress) {
        let previousBytes = latest?.copiedBytes ?? 0
        latest = progress
        guard !blockedPeriodicUpdate, previousBytes > 0,
              progress.copiedBytes > previousBytes, progress.copiedBytes < progress.totalBytes else { return }
        blockedPeriodicUpdate = true
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while ProcessInfo.processInfo.systemUptime < deadline {
            if let size = try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber {
                lastObservedSize = size.int64Value
                if lastObservedSize == progress.totalBytes {
                    writerCompletedWhileUIBlocked = true
                    return
                }
            }
            Thread.sleep(forTimeInterval: 0.002)
        }
    }
}

@MainActor
private final class ThroughputProgressProbe {
    var latest: CopyProgress?
    var byteUpdates = 0
    var monotonic = true
    var tooFrequent = false
    private var lastByteTime: TimeInterval?

    func observe(_ progress: CopyProgress) {
        if let latest, progress.copiedBytes < latest.copiedBytes { monotonic = false }
        if progress.copiedBytes > (latest?.copiedBytes ?? 0) {
            let now = ProcessInfo.processInfo.systemUptime
            // The last partial batch is intentionally flushed without waiting.
            if let lastByteTime, progress.copiedBytes < progress.totalBytes,
               now - lastByteTime < 0.19 { tooFrequent = true }
            lastByteTime = now
            byteUpdates += 1
        }
        latest = progress
    }
}
