import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Best-effort on-screen-display (OSD) OCR probe.
///
/// Some dashcams (notably VIOFO) burn their model name into every recorded
/// frame. Folder/filename heuristics cannot tell sibling models apart
/// (A229 Pro vs A229 Plus vs A229 Ultra), so we extract a frame, OCR the
/// bottom strip where the OSD lives, and look for a known model string.
///
/// This is purely additive signal. Any failure (unreadable clip, no text,
/// thrown error) results in a silent `nil`, it never crashes or blocks the
/// detection pipeline.
struct OSDProbe {
    /// Extract a frame from a video, OCR the bottom strip, and check for
    /// model name matches.
    ///
    /// - Returns: the matched string from `spec.matchStrings` if found,
    ///   `nil` otherwise.
    func probe(videoURL: URL, spec: OSDSpec) -> String? {
        probeWithDiagnostics(videoURL: videoURL, spec: spec).matchedString
    }

    func probeWithDiagnostics(videoURL: URL, spec: OSDSpec) -> OSDProbeResult {
        guard spec.containsModelName, !spec.matchStrings.isEmpty else {
            return OSDProbeResult(
                videoName: videoURL.lastPathComponent,
                framesExtracted: 0,
                framesWithText: 0,
                textCandidateCount: 0,
                matchedString: nil
            )
        }

        var framesExtracted = 0
        var framesWithText = 0
        var textCandidateCount = 0
        for frame in extractFrames(from: videoURL) {
            framesExtracted += 1
            guard let strip = cropBottomStrip(of: frame, percent: spec.stripPercent) else { continue }
            guard let recognized = recognizeText(in: strip) else { continue }
            framesWithText += 1
            textCandidateCount += recognized.count

            for candidate in spec.matchStrings {
                let needle = candidate.lowercased()
                if recognized.contains(where: { $0.lowercased().contains(needle) }) {
                    return OSDProbeResult(
                        videoName: videoURL.lastPathComponent,
                        framesExtracted: framesExtracted,
                        framesWithText: framesWithText,
                        textCandidateCount: textCandidateCount,
                        matchedString: candidate
                    )
                }
            }
        }
        return OSDProbeResult(
            videoName: videoURL.lastPathComponent,
            framesExtracted: framesExtracted,
            framesWithText: framesWithText,
            textCandidateCount: textCandidateCount,
            matchedString: nil
        )
    }

    /// Pull several CGImages out of the video. Some scenes make the OSD low
    /// contrast against the road or sky, so retrying across the same clip is
    /// much more reliable than depending on one frame.
    private func extractFrames(from videoURL: URL) -> [CGImage] {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)

        let candidateTimes = [
            CMTime(seconds: 5, preferredTimescale: 600),
            CMTime(seconds: 10, preferredTimescale: 600),
            CMTime(seconds: 20, preferredTimescale: 600),
            CMTime(seconds: 30, preferredTimescale: 600),
            CMTime(seconds: 45, preferredTimescale: 600),
            CMTime(seconds: 1, preferredTimescale: 600)
        ]

        var images: [CGImage] = []
        for time in candidateTimes {
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                images.append(image)
            }
        }
        return images
    }

    /// Crop the bottom `percent` (fraction of height) of the image, where the
    /// OSD overlay is rendered.
    private func cropBottomStrip(of image: CGImage, percent: Double) -> CGImage? {
        let clamped = max(0.01, min(percent, 1.0))
        let stripHeight = Int((Double(image.height) * clamped).rounded())
        guard stripHeight > 0 else { return nil }

        // CGImage coordinates have the origin at the top-left, so the bottom
        // strip starts at (totalHeight - stripHeight).
        let cropRect = CGRect(
            x: 0,
            y: image.height - stripHeight,
            width: image.width,
            height: stripHeight
        )
        return image.cropping(to: cropRect)
    }

    /// Run Vision text recognition over the cropped strip and collect every
    /// candidate string from all observations.
    private func recognizeText(in image: CGImage) -> [String]? {
        var results: [String] = []
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else { return nil }
        for observation in observations {
            for candidate in observation.topCandidates(3) {
                results.append(candidate.string)
            }
        }
        return results.isEmpty ? nil : results
    }
}

struct OSDProbeResult: Hashable, Sendable {
    var videoName: String
    var framesExtracted: Int
    var framesWithText: Int
    var textCandidateCount: Int
    var matchedString: String?
}
