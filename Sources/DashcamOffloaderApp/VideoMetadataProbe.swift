@preconcurrency import AVFoundation
import CoreMedia
import Foundation

struct VideoMetadataProbe {
    func probe(clips: [ClipItem], sourceRoot: URL, maxSamples: Int = 16) async -> [VideoSpecSnapshot] {
        var samples: [VideoSpecSnapshot] = []
        for clip in representativeClips(from: clips, maxSamples: maxSamples) {
            if let sample = await probe(clip: clip, sourceRoot: sourceRoot) {
                samples.append(sample)
            }
        }
        return samples
    }

    private func representativeClips(from clips: [ClipItem], maxSamples: Int) -> [ClipItem] {
        let videos = clips
            .filter { $0.excludedReason == nil && $0.isVideo }
            .sorted {
                if $0.outputCategory != $1.outputCategory {
                    return $0.outputCategory.localizedStandardCompare($1.outputCategory) == .orderedAscending
                }
                if $0.channel != $1.channel {
                    return $0.channel.localizedStandardCompare($1.channel) == .orderedAscending
                }
                if let lhsDate = $0.timestamp, let rhsDate = $1.timestamp, lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
            }

        var selected: [ClipItem] = []
        var seenKeys: Set<String> = []
        for clip in videos {
            let key = "\(clip.outputCategory)|\(clip.channel)|\(clip.extensionLowercased)"
            if seenKeys.insert(key).inserted {
                selected.append(clip)
            }
            if selected.count >= maxSamples { return selected }
        }

        let selectedIDs = Set(selected.map(\.id))
        for clip in videos where !selectedIDs.contains(clip.id) {
            selected.append(clip)
            if selected.count >= maxSamples { break }
        }
        return selected
    }

    private func probe(clip: ClipItem, sourceRoot: URL) async -> VideoSpecSnapshot? {
        let asset = AVURLAsset(url: clip.sourceURL)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
        let preferredTransform = (try? await track.load(.preferredTransform)) ?? .identity
        let nominalFrameRate = (try? await track.load(.nominalFrameRate)) ?? 0
        let estimatedDataRate = (try? await track.load(.estimatedDataRate)) ?? 0
        let transformedSize = naturalSize.applying(preferredTransform)
        let width = roundedPositiveInt(abs(transformedSize.width))
        let height = roundedPositiveInt(abs(transformedSize.height))
        let frameRate = nominalFrameRate > 0 ? Double(nominalFrameRate) : nil
        let bitrateMbps = estimatedDataRate > 0 ? Double(estimatedDataRate) / 1_000_000 : nil
        let duration = await durationSeconds(for: asset)

        return VideoSpecSnapshot(
            relativePath: clip.sourceURL.relativePath(from: sourceRoot),
            mode: clip.outputCategory,
            channel: clip.displayChannel,
            codec: await codecName(for: track) ?? "unknown",
            width: width,
            height: height,
            frameRate: frameRate,
            bitrateMbps: bitrateMbps,
            durationSeconds: duration,
            fileSize: clip.size
        )
    }

    private func roundedPositiveInt(_ value: CGFloat) -> Int? {
        guard value.isFinite, value > 0 else { return nil }
        return Int(value.rounded())
    }

    private func durationSeconds(for asset: AVAsset) async -> Double? {
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    private func codecName(for track: AVAssetTrack) async -> String? {
        let formatDescriptions = (try? await track.load(.formatDescriptions)) ?? []
        for description in formatDescriptions {
            let fourCC = fourCCString(CMFormatDescriptionGetMediaSubType(description))
            switch fourCC.lowercased() {
            case "avc1", "h264":
                return "H.264"
            case "hvc1", "hev1":
                return "HEVC"
            case "mp4v":
                return "MPEG-4"
            default:
                if !fourCC.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return fourCC
                }
            }
        }
        return nil
    }

    private func fourCCString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? "\(code)"
    }
}
