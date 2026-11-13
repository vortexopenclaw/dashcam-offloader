import AppKit
import AVFoundation
import Foundation

/// Self-contained font-marker videos exercise the shipping in-process decoder/OCR.
/// Optional owner-frame video stays private and is never required by the bundle.
enum Z100StampVerification {
    static func run(profiles: [DashcamProfile]) -> Bool {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("z100-stamps-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let originalProfiles = profiles
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            guard let profileDirectory = ProfileStore.defaultProfilesDirectory() else { return false }
            let profileURLs = try fm.contentsOfDirectory(at: profileDirectory, includingPropertiesForKeys: nil)
                .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
            let profileBytes = try Dictionary(uniqueKeysWithValues: profileURLs.map { ($0, try Data(contentsOf: $0)) })
            let cases: [(String, String, String, Int, Bool)] = [
                ("NO NAME", "DDPAI Z100 Master 4K", "front", 2, true),
                ("three", "DDPAI Z100 Master 4K", "front", 3, true),
                ("aperture-logo", "DDPAI Z100 Master O 4K", "front", 2, true),
                ("front-only", "DDPAI Z100 Master 4K", "front", 1, true),
                ("Z100 Master", "", "front", 2, false),
                ("pro", "DDPAI Z100 Pro 4K", "front", 2, false),
                ("masterx", "DDPAI Z100 MasterX 4K", "front", 2, false),
                ("master-x", "DDPAI Z100 Master X 4K", "front", 2, false),
                ("brand-only", "DDPAI", "front", 2, false),
                ("accessory", "DDPAI Z100 Master 4K", "inside", 1, false),
                ("wrong-folder", "DDPAI Z100 Master 4K", "other", 2, false)
            ]
            for (label, stamp, folder, count, expected) in cases {
                let video = root.appendingPathComponent("\(label).mp4")
                try makeVideo(at: video, stamp: stamp)
                guard try check(video: video, card: root.appendingPathComponent("card-\(label)/\(label)"), folder: folder, count: count, expected: expected, profiles: profiles) else { return false }
            }
            if let privateVideo = ProcessInfo.processInfo.environment["DASHCAM_Z100_MASTER_VIDEO_FIXTURE"] {
                let video = URL(fileURLWithPath: privateVideo)
                let before = try Data(contentsOf: video)
                let attributes = try fm.attributesOfItem(atPath: video.path)
                for count in [1, 2, 3] {
                    guard try check(video: video, card: root.appendingPathComponent("private-\(count)/NO NAME"), folder: "front", count: count, expected: true, profiles: profiles) else { return false }
                }
                guard try Data(contentsOf: video) == before,
                      try fm.attributesOfItem(atPath: video.path)[.modificationDate] as? Date == attributes[.modificationDate] as? Date else { return false }
                print("Z100 PRIVATE FRAME VERIFY PASS: normal scan -> exact identity -> main mapping, 1/2/3 observed views; reference bytes/mtime unchanged")
            }
            guard profiles == originalProfiles else { return false }
            for (url, bytes) in profileBytes {
                guard try Data(contentsOf: url) == bytes else { return false }
            }
            print("Z100 STAMP VERIFY PASS: 11 synthetic native-video cases; count-independent main identity, observed roles, optional rear, blank/sibling/accessory negatives; profiles unchanged")
            return true
        } catch {
            print("Z100 STAMP VERIFY FAIL: \(error.localizedDescription)")
            return false
        }
    }

    private static func check(video: URL, card: URL, folder: String, count: Int, expected: Bool, profiles: [DashcamProfile]) throws -> Bool {
        let fm = FileManager.default
        let primary = card.appendingPathComponent("DCIM/200video/\(folder)/20300101120000.mp4")
        try fm.createDirectory(at: primary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: video, to: primary)
        if folder == "front", count >= 2 {
            let inside = card.appendingPathComponent("DCIM/200video/inside/20300101120000.mp4")
            try fm.createDirectory(at: inside.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: video, to: inside)
        }
        let rear = card.appendingPathComponent("DCIM/200video/rear")
        try fm.createDirectory(at: rear, withIntermediateDirectories: true)
        if count == 3 { try fm.copyItem(at: video, to: rear.appendingPathComponent("20300101120000.mp4")) }
        let before = try Data(contentsOf: primary)
        let modified = try fm.attributesOfItem(atPath: primary.path)[.modificationDate] as? Date
        let scan = try CardScanner().scanWithOSD(sourceURL: card, profiles: profiles)
        guard try Data(contentsOf: primary) == before,
              try fm.attributesOfItem(atPath: primary.path)[.modificationDate] as? Date == modified else { return false }
        if expected {
            guard scan.selectedProfile?.id == "ddpai-z100-master-main",
                  scan.identifiedCamera?.model == "Z100 Master", scan.identifiedCamera?.isSupported == true,
                  scan.diagnostics.contains(where: { $0.stage == "z100_main_front_osd" && $0.outcome == "matched" }),
                  scan.clips.allSatisfy({ !$0.isParkingFootage }) else {
                print("Z100 STAMP VERIFY FAIL: positive \(card.lastPathComponent), profile \(scan.selectedProfile?.id ?? "nil")")
                return false
            }
            let roles = Set(scan.clips.map(\.channel))
            let expectedRoles: Set<String> = count == 3 ? ["front", "telephoto", "rear"] : count == 2 ? ["front", "telephoto"] : ["front"]
            guard roles == expectedRoles else { print("Z100 STAMP VERIFY FAIL: roles \(roles)"); return false }
            return MainActor.assumeIsolated {
                let model = TransferViewModel()
                model.profiles = profiles
                model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic"), scanResult: scan)
                guard !model.selectedProfileWasManuallyChosen,
                      model.inferredLearningChannelSetup.count == count,
                      let snapshot = model.makeFeedbackScanSnapshot(),
                      Set(snapshot.channelCounts.keys) == expectedRoles else { return false }
                // An owner's configured 4CH includes a separate cabin card; no
                // configured count may manufacture a recording on this card.
                var selection = LearningChannelSelection()
                selection.choose(4)
                selection.prefill(count)
                guard selection.count == 4 && model.inferredLearningChannelSetup.count == count,
                      let selected = model.selectedProfile else { return false }
                model.selectProfile(selected)
                return model.selectedProfileWasManuallyChosen && model.inferredLearningChannelSetup.count == count
            }
        }
        guard scan.selectedProfile?.id == DashcamProfile.genericNewDashcam.id,
              scan.clips.allSatisfy({ $0.channel != "telephoto" && !$0.isParkingFootage }) else {
            print("Z100 STAMP VERIFY FAIL: negative \(card.lastPathComponent), profile \(scan.selectedProfile?.id ?? "nil")")
            return false
        }
        return true
    }

    private static func makeVideo(at url: URL, stamp: String) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1280, AVVideoHeightKey: 720])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 1280, kCVPixelBufferHeightKey as String: 720])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "Z100Fixture", code: 1) }
        writer.startSession(atSourceTime: .zero)
        var optionalBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 1280, 720, kCVPixelFormatType_32ARGB, nil, &optionalBuffer)
        guard let buffer = optionalBuffer else { throw NSError(domain: "Z100Fixture", code: 2) }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1280, height: 720, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw NSError(domain: "Z100Fixture", code: 3) }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1280, height: 720))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (stamp as NSString).draw(at: NSPoint(x: 40, y: 24), withAttributes: [.font: NSFont.systemFont(ofSize: 38), .foregroundColor: NSColor.white])
        NSGraphicsContext.restoreGraphicsState()
        CVPixelBufferUnlockBaseAddress(buffer, [])
        for second in 0..<7 {
            let deadline = Date().addingTimeInterval(10)
            while !input.isReadyForMoreMediaData && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
            guard input.isReadyForMoreMediaData, adaptor.append(buffer, withPresentationTime: CMTime(seconds: Double(second), preferredTimescale: 600)) else { throw writer.error ?? NSError(domain: "Z100Fixture", code: 4) }
        }
        input.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        guard finished.wait(timeout: .now() + 30) == .success, writer.status == .completed else { throw writer.error ?? NSError(domain: "Z100Fixture", code: 5) }
    }
}
