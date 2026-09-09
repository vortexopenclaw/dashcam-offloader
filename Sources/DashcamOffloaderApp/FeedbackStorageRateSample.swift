import Foundation

/// Anonymous paired measurements. Unlike unrelated size/duration extrema, each
/// pair establishes the complete-file rate, including audio, metadata and padding.
struct FeedbackStorageRateSample: Codable, Hashable, Sendable {
    var fileSizeBytes: Int64
    var durationSeconds: Double
    var width: Int?
    var height: Int?
    var nominalFrameRate: Double?
    var videoBitrate: Int?

    var storageBytesPerSecond: Double { Double(fileSizeBytes) / durationSeconds }

    init?(fileSizeBytes: Int64?, durationSeconds: Double?, width: Int? = nil,
          height: Int? = nil, nominalFrameRate: Double? = nil, videoBitrate: Int? = nil) {
        guard let size = fileSizeBytes, size > 0, size <= 1_000_000_000_000,
              let duration = durationSeconds, duration.isFinite,
              duration > 0, duration <= 86_400 else { return nil }
        self.fileSizeBytes = size
        self.durationSeconds = duration
        self.width = width
        self.height = height
        self.nominalFrameRate = nominalFrameRate
        self.videoBitrate = videoBitrate
    }

    init?(_ sample: FeedbackVideoSpecSample) {
        self.init(fileSizeBytes: sample.fileSizeBytes, durationSeconds: sample.durationSeconds,
                  width: sample.width, height: sample.height,
                  nominalFrameRate: sample.nominalFrameRate, videoBitrate: sample.estimatedBitrate)
    }
}
