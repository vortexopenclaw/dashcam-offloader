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
            let bufferBytes: Int64 = 8 * 1024 * 1024
            let size = 6 * bufferBytes
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

            // No elapsed logical time: only the prompt first chunk and final flush,
            // regardless of how long the host takes to write or render each buffer.
            let frozenProbe = ThroughputProgressProbe()
            let frozenResult = await CopyExecutor(progressHandler: { frozenProbe.observe($0) },
                                                  progressClock: { 0 }).copy(plan: plan)
            guard frozenResult.mediaItems.map(\.status) == [.copied],
                  frozenProbe.finished(size: size), frozenProbe.byteSnapshots == [bufferBytes, size] else {
                print("VERIFY FAIL: frozen-clock progress did not batch buffers: \(frozenProbe.byteSnapshots)")
                return false
            }
            print("VERIFY PASS: frozen clock batches buffers with exact first/final bytes")

            try fm.removeItem(at: destination)
            let clock = CopyVerificationClock()
            let periodicObserved = DispatchSemaphore(value: 0)
            let probe = ThroughputProgressProbe()
            let result = await CopyExecutor(progressHandler: {
                probe.observe($0)
                if $0.copiedBytes == 3 * bufferBytes || $0.copiedBytes == 5 * bufferBytes {
                    periodicObserved.signal()
                }
            }, progressClock: { clock.now() }, beforeChunkHook: { bytes in
                // Let each periodic snapshot drain before advancing logical time;
                // callback scheduling/coalescing must not change this cadence check.
                if bytes == 3 * bufferBytes || bytes == 5 * bufferBytes {
                    try waitForCopyGate(periodicObserved)
                }
                let times: [TimeInterval] = [0, 0.199, 0.2, 0.399, 0.4, 0.599]
                clock.set(times[min(Int(bytes / bufferBytes), times.count - 1)])
            }).copy(plan: plan)
            guard result.mediaItems.map(\.status) == [.copied], probe.finished(size: size),
                  probe.byteSnapshots == [bufferBytes, 3 * bufferBytes, 5 * bufferBytes, size] else {
                print("VERIFY FAIL: controlled-clock cadence or final flush lost bytes: \(probe.byteSnapshots)")
                return false
            }
            print("VERIFY PASS: controlled clock emits at 0/0.2/0.4 seconds and flushes final bytes")

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

            // Force a periodic callback at chunk two. Hold it on MainActor until
            // the next real write reaches its gate, not until the whole file finishes.
            // Awaiting periodic UI delivery instead deadlocks this bounded handshake.
            try fm.removeItem(at: destination)
            let slowDestination = root.appendingPathComponent("slow-destination.MP4")
            let slowPlan = CopyPlan(sourceRoot: root, destinationRoot: root, profile: .genericNewDashcam,
                                    clips: [clip], items: [CopyPlanItem(clip: clip, destinationURL: slowDestination, status: .planned)])
            let slowClock = CopyVerificationClock()
            let uiEntered = DispatchSemaphore(value: 0)
            let nextChunkWritten = DispatchSemaphore(value: 0)
            let slowProbe = SlowCopyProgressProbe(periodicBytes: 2 * bufferBytes,
                                                 uiEntered: uiEntered, nextChunkWritten: nextChunkWritten)
            let slowResult = await CopyExecutor(progressHandler: { slowProbe.observe($0) },
                                               progressClock: { slowClock.now() }, beforeChunkHook: { bytes in
                // Do not even read chunk three until MainActor is blocked. At the
                // following gate, chunk three has genuinely been written during it.
                if bytes == 2 * bufferBytes { try waitForCopyGate(uiEntered) }
                if bytes == 3 * bufferBytes { nextChunkWritten.signal() }
                slowClock.set(bytes >= bufferBytes ? 0.25 : 0)
            }).copy(plan: slowPlan)
            guard slowProbe.blockedPeriodicUpdate, slowProbe.nextChunkWrittenWhileUIBlocked,
                  slowResult.mediaItems.map(\.status) == [.copied],
                  slowProbe.latest?.copiedBytes == size, slowProbe.latest?.completedFiles == 1,
                  slowProbe.latest?.isRunning == false else {
                print("VERIFY FAIL: slow UI callback stalled the next buffer write: blocked=\(slowProbe.blockedPeriodicUpdate) advanced=\(slowProbe.nextChunkWrittenWhileUIBlocked) statuses=\(slowResult.mediaItems.map(\.status))")
                return false
            }
            print("VERIFY PASS: next buffer writes while a forced periodic MainActor callback is blocked")

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

// Timeouts bound broken synchronization only; they are not throughput thresholds.
private func waitForCopyGate(_ gate: DispatchSemaphore) throws {
    guard gate.wait(timeout: .now() + 10) == .success else {
        throw CopyGateError.timedOut
    }
}

private enum CopyGateError: LocalizedError {
    case timedOut
    var errorDescription: String? { "Copy verification synchronization gate timed out" }
}

private final class CopyVerificationClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 0

    func now() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return time
    }

    func set(_ time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        self.time = time
    }
}

@MainActor
private final class SlowCopyProgressProbe {
    let periodicBytes: Int64
    let uiEntered: DispatchSemaphore
    let nextChunkWritten: DispatchSemaphore
    var latest: CopyProgress?
    var blockedPeriodicUpdate = false
    var nextChunkWrittenWhileUIBlocked = false

    init(periodicBytes: Int64, uiEntered: DispatchSemaphore, nextChunkWritten: DispatchSemaphore) {
        self.periodicBytes = periodicBytes
        self.uiEntered = uiEntered
        self.nextChunkWritten = nextChunkWritten
    }

    func observe(_ progress: CopyProgress) {
        latest = progress
        guard !blockedPeriodicUpdate, progress.copiedBytes == periodicBytes else { return }
        blockedPeriodicUpdate = true
        uiEntered.signal()
        nextChunkWrittenWhileUIBlocked = (try? waitForCopyGate(nextChunkWritten)) != nil
    }
}

@MainActor
private final class ThroughputProgressProbe {
    var latest: CopyProgress?
    var byteSnapshots: [Int64] = []
    var monotonic = true

    func observe(_ progress: CopyProgress) {
        if let latest, progress.copiedBytes < latest.copiedBytes { monotonic = false }
        if progress.copiedBytes > (latest?.copiedBytes ?? 0) {
            byteSnapshots.append(progress.copiedBytes)
        }
        latest = progress
    }

    func finished(size: Int64) -> Bool {
        monotonic && latest?.copiedBytes == size && latest?.completedFiles == 1 && latest?.isRunning == false
    }
}
