import Foundation

/// Synthetic temporary files only: no card, recording or photo content.
/// The signature is the documented 128 bytes of 0x0A followed by zeros.
enum ReservedSlotVerification {
    static func run(profiles: [DashcamProfile]) -> Bool {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("reserved-slot-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        func fail(_ message: String) -> Bool {
            print("RESERVED SLOT VERIFY FAIL: \(message)")
            return false
        }
        func slotBytes(tail: Int = 4096) -> Data {
            Data(repeating: ReservedMediaSlot.headerByte, count: ReservedMediaSlot.headerLength) + Data(count: tail)
        }
        func write(_ data: Data, _ path: String, in base: URL) throws -> URL {
            let url = base.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            return url
        }

        do {
            let card = root.appendingPathComponent("card")
            let slot = try write(slotBytes(), "DCIM/201photo/slot0001.jpg", in: card)
            // Same size as the slot and inside a tmp folder: neither is evidence.
            var jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x11, count: 124)
            jpeg += Data(count: 4096 - 2) + Data([0xFF, 0xD9])
            _ = try write(jpeg, "DCIM/201photo/tmp/slot0002.jpg", in: card)
            var changed = slotBytes()
            changed[changed.count - 1] = 0x01
            _ = try write(changed, "DCIM/201photo/slot0003.jpg", in: card)
            var shortHeader = slotBytes()
            shortHeader[ReservedMediaSlot.headerLength - 1] = 0x00
            _ = try write(shortHeader, "DCIM/201photo/slot0004.jpg", in: card)
            _ = try write(Data(repeating: ReservedMediaSlot.headerByte, count: ReservedMediaSlot.headerLength),
                          "DCIM/201photo/slot0005.jpg", in: card)
            // Video candidates are outside this photo-slot rule.
            _ = try write(slotBytes(), "DCIM/200video/front/20300101120000.mp4", in: card)

            let scanner = CardScanner()
            let scan = try scanner.scan(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
            let byName = Dictionary(uniqueKeysWithValues: scan.clips.map { ($0.filename, $0) })
            guard let slotClip = byName["slot0001.jpg"], slotClip.isReservedSlot, !slotClip.isPhoto,
                  slotClip.excludedReason == ReservedMediaSlot.excludedReason,
                  slotClip.outputCategory == ReservedMediaSlot.outputCategory,
                  slotClip.mode == ReservedMediaSlot.mode else {
                return fail("positive signature fixture was not a validated reserved slot")
            }
            for name in ["slot0002.jpg", "slot0003.jpg", "slot0004.jpg", "slot0005.jpg"] {
                guard let clip = byName[name], clip.isPhoto, clip.excludedReason == nil,
                      clip.reservedSlotCheck == .notReserved, clip.outputCategory == "Photos" else {
                    return fail("\(name) (genuine JPEG / changed / short negative) must stay a photo")
                }
            }
            guard let video = byName["20300101120000.mp4"], video.isVideo, video.reservedSlotCheck == nil,
                  video.excludedReason == nil else {
                return fail("video candidates must not be checked or hidden by the photo-slot rule")
            }
            guard scan.allFiles.contains(where: { $0.lastPathComponent == "slot0001.jpg" }),
                  let diagnostic = scan.diagnostics.filter({ $0.stage == ReservedMediaSlot.diagnosticStage }).first,
                  scan.diagnostics.filter({ $0.stage == ReservedMediaSlot.diagnosticStage }).count == 1,
                  diagnostic.outcome == "reserved_slots_found",
                  diagnostic.detail.hasPrefix("5 photo-extension files checked"),
                  diagnostic.detail.contains("5 verified (1 empty reserved slots, 4 other content)"),
                  diagnostic.detail.contains("0 unverified") else {
                return fail("structural inventory or coverage diagnostic: \(scan.diagnostics.filter { $0.stage == ReservedMediaSlot.diagnosticStage })")
            }

            // The same exact rule applies under the DDPAI main-unit profile.
            if let z100 = profiles.first(where: { $0.id == "ddpai-z100-master-main" }) {
                let profiled = scanner.classifyWithParkingPatterns(files: scan.allFiles, sourceURL: card, profile: z100)
                guard profiled.clips.filter(\.isReservedSlot).map(\.filename) == ["slot0001.jpg"],
                      profiled.diagnostics.contains(where: { $0.stage == ReservedMediaSlot.diagnosticStage }) else {
                    return fail("DDPAI profile classification did not apply the same rule")
                }
            } else {
                return fail("ddpai-z100-master-main profile missing")
            }

            // UI summary, copy plan and learning structure.
            let uiValid = MainActor.assumeIsolated { () -> String? in
                let model = TransferViewModel()
                model.profiles = profiles
                model.loadScanResultForVerification(source: MountedSource(url: card, name: "Synthetic"), scanResult: scan)
                model.filters.includePhotos = true
                model.rebuildPlan()
                guard model.hasPhotoItems,
                      model.scanSummary.categoryCounts["Photos"] == 4,
                      model.scanSummary.categoryCounts[ReservedMediaSlot.outputCategory] == nil,
                      model.scanSummary.excludedItems >= 1 else { return "scan summary counts" }
                guard let plan = model.copyPlan,
                      !plan.items.contains(where: { $0.clip.filename == "slot0001.jpg" }),
                      plan.items.contains(where: { $0.clip.filename == "slot0002.jpg" }) else { return "copy plan" }
                guard let snapshot = model.makeFeedbackScanSnapshot(),
                      snapshot.outputCategoryCounts[ReservedMediaSlot.outputCategory] == 1,
                      snapshot.outputCategoryCounts["Photos"] == 4,
                      snapshot.mediaFileSamples.contains(where: {
                          $0.filename == "slot0001.jpg" && $0.outputCategory == ReservedMediaSlot.outputCategory
                      }) else { return "learning structure reservation counts" }
                // A card holding only reservations offers no Photos choice.
                model.clips.removeAll { $0.isPhoto }
                guard !model.hasPhotoItems,
                      !TransferFilterSummary.lines(filters: model.filters, hasVideos: model.hasVideoItems,
                          hasPhotos: model.hasPhotoItems, hasGPS: model.hasGPSItems,
                          modes: [], channels: []).joined().contains("Photos") else { return "photo-only summary" }
                return nil
            }
            if let uiValid { return fail("UI/plan/learning: \(uiValid)") }

            // Symbolic links are not followed, even to a valid slot.
            let link = card.appendingPathComponent("DCIM/201photo/link0006.jpg")
            try fm.createSymbolicLink(at: link, withDestinationURL: slot)
            var meter = ReservedMediaSlot.Meter()
            guard ReservedMediaSlot.check(url: link, meter: &meter) == .unverifiedReadFailure,
                  ReservedMediaSlot.check(url: card.appendingPathComponent("DCIM/201photo"), meter: &meter) == .unverifiedReadFailure,
                  ReservedMediaSlot.check(url: card.appendingPathComponent("missing.jpg"), meter: &meter) == .unverifiedReadFailure else {
                return fail("symlink/directory/missing must not verify")
            }
            let linkedScan = try scanner.scan(sourceURL: card, profiles: profiles, allowNestedCardRootDiscovery: false)
            guard linkedScan.clips.filter(\.isReservedSlot).map(\.filename) == ["slot0001.jpg"] else {
                return fail("symlink was treated as a reserved slot")
            }
            try fm.removeItem(at: link)

            // Budget: files beyond the byte or file budget stay photos and are reported.
            let budgetCard = root.appendingPathComponent("budget")
            let budgetFiles = try (1...3).map { try write(slotBytes(), "DCIM/201photo/slot000\($0).jpg", in: budgetCard) }
            func clips(_ urls: [URL]) -> [ClipItem] {
                urls.map { url in
                    ClipItem(sourceURL: url, relativePath: url.relativePath(from: budgetCard), filename: url.lastPathComponent,
                             mode: "jpeg", channel: "unknown", timestamp: nil, size: Int64(slotBytes().count),
                             extensionLowercased: "jpg", excludedReason: nil)
                }
            }
            var byBytes = clips(budgetFiles)
            ReservedMediaSlot.mark(&byBytes, budget: .init(maxFileBytes: 1 << 20, maxTotalBytes: Int64(slotBytes().count) + 200, maxFiles: 100))
            var byCount = clips(budgetFiles)
            ReservedMediaSlot.mark(&byCount, budget: .init(maxFileBytes: 1 << 20, maxTotalBytes: 1 << 30, maxFiles: 2))
            var oversize = clips(budgetFiles)
            ReservedMediaSlot.mark(&oversize, budget: .init(maxFileBytes: 1024, maxTotalBytes: 1 << 30, maxFiles: 100))
            let byBytesCoverage = ReservedMediaSlot.Coverage(clips: byBytes)
            guard byBytes.map(\.reservedSlotCheck) == [.reserved, .unverifiedBudget, .unverifiedBudget],
                  byBytes.filter(\.isPhoto).count == 2, byBytes.dropFirst().allSatisfy({ $0.excludedReason == nil }),
                  byBytesCoverage.verified == 1, byBytesCoverage.unverified == 2,
                  byBytesCoverage.summary.contains("1 verified"), byBytesCoverage.summary.contains("2 unverified (2 over scan budget"),
                  ReservedMediaSlot.diagnostic(for: byBytes, profile: nil)?.outcome == "partial_coverage" else {
                return fail("byte budget coverage: \(byBytes.map(\.reservedSlotCheck))")
            }
            guard byCount.map(\.reservedSlotCheck) == [.reserved, .reserved, .unverifiedBudget],
                  byCount.last?.isPhoto == true else {
                return fail("file-count budget coverage: \(byCount.map(\.reservedSlotCheck))")
            }
            guard oversize.allSatisfy({ $0.reservedSlotCheck == .unverifiedOversize && $0.isPhoto && $0.excludedReason == nil }),
                  ReservedMediaSlot.Coverage(clips: oversize).summary.contains("3 over size bound") else {
                return fail("oversize files must stay photos: \(oversize.map(\.reservedSlotCheck))")
            }

            print("RESERVED SLOT VERIFY PASS: exact full-file signature slot excluded from Photos/copy plan and kept in inventory/learning; genuine JPEG in tmp, changed tail, short header and header-only negatives stay photos; video untouched; DDPAI profile parity; symlink/directory/missing not followed; byte/file budget and size-bound coverage reported")
            return true
        } catch {
            return fail(error.localizedDescription)
        }
    }
}
