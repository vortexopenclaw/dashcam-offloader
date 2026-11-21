import Foundation
import Darwin

/// Outcome of checking one photo-extension file for the exact preallocated
/// reservation signature. Only `.reserved` changes how a file is treated;
/// every other outcome keeps the file as normal media.
enum ReservedSlotCheck: String, Hashable, Sendable {
    /// Full-file signature verified with a stable size and modification time.
    case reserved
    /// Read far enough to prove the file is not the signature.
    case notReserved
    /// Not checked because the per-scan budget was exhausted.
    case unverifiedBudget
    /// Signature header matched but the file exceeds the per-file size bound.
    case unverifiedOversize
    /// Open, type, read or before/after stability check failed.
    case unverifiedReadFailure
}

/// Validated empty reservation slots: exactly 128 bytes of 0x0A followed only
/// by 0x00 bytes. Such a file cannot decode as any supported photo format
/// (JPEG, PNG, HEIC, BMP, TIFF-based RAW all need a non-0x0A magic number), so
/// it is not an image. It is still structural evidence and stays in the
/// inventory; it is only excluded from Photos and from the copy plan.
///
/// Folder names (for example `tmp`) and fixed sizes are never used as evidence:
/// a populated slot is real media and fails the full-content check.
enum ReservedMediaSlot {
    static let headerLength = 128
    static let headerByte: UInt8 = 0x0A
    static let excludedReason = "Empty reserved slot (no image)"
    static let mode = "reserved_slot"
    static let outputCategory = "Reserved Slots"
    static let diagnosticStage = "reserved_slot_verification"

    struct Budget: Sendable {
        /// Largest file eligible for verification. Larger files stay media.
        var maxFileBytes: Int64 = 32 * 1024 * 1024
        /// Total bytes read across one classification pass.
        var maxTotalBytes: Int64 = 512 * 1024 * 1024
        /// Files checked across one classification pass.
        var maxFiles: Int = 20_000

        static let standard = Budget()
    }

    struct Coverage: Hashable, Sendable {
        var reserved = 0
        var notReserved = 0
        var unverifiedBudget = 0
        var unverifiedOversize = 0
        var unverifiedReadFailure = 0

        var candidates: Int { verified + unverified }
        var verified: Int { reserved + notReserved }
        var unverified: Int { unverifiedBudget + unverifiedOversize + unverifiedReadFailure }

        init() {}

        init(clips: [ClipItem]) {
            for clip in clips {
                switch clip.reservedSlotCheck {
                case .reserved?: reserved += 1
                case .notReserved?: notReserved += 1
                case .unverifiedBudget?: unverifiedBudget += 1
                case .unverifiedOversize?: unverifiedOversize += 1
                case .unverifiedReadFailure?: unverifiedReadFailure += 1
                case nil: break
                }
            }
        }

        var summary: String {
            "\(candidates) photo-extension files checked for the exact reserved-slot signature: " +
                "\(verified) verified (\(reserved) empty reserved slots, \(notReserved) other content), " +
                "\(unverified) unverified (\(unverifiedBudget) over scan budget, \(unverifiedOversize) over size bound, " +
                "\(unverifiedReadFailure) unreadable, not regular or changed during read); unverified files remain listed as photos"
        }
    }

    /// Budget state shared across one classification pass.
    struct Meter {
        var budget: Budget
        var bytesRead: Int64 = 0
        var filesChecked = 0

        init(budget: Budget = .standard) {
            self.budget = budget
        }
    }

    private struct Snapshot: Equatable {
        var device: dev_t
        var inode: ino_t
        var size: off_t
        var mtimeSeconds: Int
        var mtimeNanoseconds: Int

        init(_ info: stat) {
            device = info.st_dev
            inode = info.st_ino
            size = info.st_size
            mtimeSeconds = info.st_mtimespec.tv_sec
            mtimeNanoseconds = info.st_mtimespec.tv_nsec
        }
    }

    /// Marks validated slots in place and records a check outcome on every
    /// photo-extension candidate that is not already excluded.
    static func mark(_ clips: inout [ClipItem], budget: Budget = .standard) {
        var meter = Meter(budget: budget)
        for index in clips.indices {
            let clip = clips[index]
            guard clip.excludedReason == nil,
                  ClipItem.photoExtensions.contains(clip.extensionLowercased) else { continue }
            let outcome = check(url: clip.sourceURL, meter: &meter)
            clips[index].reservedSlotCheck = outcome
            if outcome == .reserved {
                clips[index].excludedReason = excludedReason
                clips[index].mode = mode
            }
        }
    }

    static func diagnostic(for clips: [ClipItem], profile: DashcamProfile?) -> ScanDiagnosticEntry? {
        let coverage = Coverage(clips: clips)
        guard coverage.candidates > 0 else { return nil }
        let outcome: String
        if coverage.unverified > 0 {
            outcome = "partial_coverage"
        } else if coverage.reserved > 0 {
            outcome = "reserved_slots_found"
        } else {
            outcome = "no_reserved_slots"
        }
        return ScanDiagnosticEntry(
            stage: diagnosticStage,
            profileID: profile?.id,
            profileName: profile?.displayName,
            outcome: outcome,
            detail: coverage.summary
        )
    }

    /// Bounded, no-follow, regular-file, full-content check with size, inode
    /// and modification time required to be identical before and after the read.
    /// The 128-byte header is read first, so ordinary photos cost one small read.
    static func check(url: URL, meter: inout Meter) -> ReservedSlotCheck {
        guard meter.filesChecked < meter.budget.maxFiles,
              meter.bytesRead + Int64(headerLength) <= meter.budget.maxTotalBytes else {
            return .unverifiedBudget
        }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { return .unverifiedReadFailure }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
              (before.st_mode & S_IFMT) == S_IFREG,
              before.st_size >= 0 else {
            return .unverifiedReadFailure
        }
        meter.filesChecked += 1

        let expectedSize = Int64(before.st_size)
        let chunkSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var offset: Int64 = 0
        var matches = true
        var stage = 0 // 0 = header, 1 = tail
        // Read one byte past the expected size to detect growth during the read.
        readLoop: while offset <= expectedSize {
            if stage == 0, offset >= Int64(headerLength) {
                stage = 1
                // The header matches. A positive result needs the whole file,
                // so do not start a tail read that cannot finish within bounds.
                guard expectedSize > Int64(headerLength) else { break readLoop }
                guard expectedSize <= meter.budget.maxFileBytes else { return .unverifiedOversize }
                guard meter.bytesRead + (expectedSize + 1 - offset) <= meter.budget.maxTotalBytes else {
                    return .unverifiedBudget
                }
            }
            let wanted = stage == 0
                ? Int(Int64(headerLength) - offset)
                : Int(min(Int64(chunkSize), expectedSize + 1 - offset))
            let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, wanted) }
            if count < 0 {
                if errno == EINTR { continue }
                return .unverifiedReadFailure
            }
            if count == 0 { break }
            meter.bytesRead += Int64(count)
            for position in 0..<count {
                let expected: UInt8 = offset + Int64(position) < Int64(headerLength) ? headerByte : 0
                if buffer[position] != expected {
                    matches = false
                    break
                }
            }
            offset += Int64(count)
            if !matches { break }
        }

        var after = stat()
        var pathAfter = stat()
        guard fstat(descriptor, &after) == 0,
              lstat(url.path, &pathAfter) == 0,
              Snapshot(before) == Snapshot(after),
              Snapshot(before) == Snapshot(pathAfter) else {
            return .unverifiedReadFailure
        }
        // A short or differing file is ordinary content, never a reservation.
        guard matches, expectedSize > Int64(headerLength) else { return .notReserved }
        // Full coverage: every byte read, and EOF exactly at the stable size.
        guard offset == expectedSize else { return .unverifiedReadFailure }
        return .reserved
    }
}
