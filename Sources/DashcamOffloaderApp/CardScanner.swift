@preconcurrency import AVFoundation
import Foundation

struct CardScanner {
    private let fileManager = FileManager.default

    func discoverMountedSources(showAllVolumes: Bool = false) -> [MountedSource] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .volumeIsBrowsableKey, .volumeIsLocalKey]
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) ?? fallbackVolumeDirectoryURLs(resourceKeys: resourceKeys)

        return urls
            .filter { url in
                let standardizedURL = url.standardizedFileURL
                guard standardizedURL.path.hasPrefix("/Volumes/") else { return false }
                let values = try? standardizedURL.resourceValues(forKeys: Set(resourceKeys))
                guard values?.isDirectory == true else { return false }
                guard values?.volumeIsBrowsable != false else { return false }
                return shouldShowMountedSource(standardizedURL, showAllVolumes: showAllVolumes)
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MountedSource(url: $0.standardizedFileURL, name: $0.lastPathComponent) }
    }

    private func fallbackVolumeDirectoryURLs(resourceKeys: [URLResourceKey]) -> [URL] {
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        return (try? fileManager.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    func mountedSource(forUserSelectedURL url: URL) -> MountedSource {
        let standardizedURL = url.standardizedFileURL
        if let volumeURL = mountedVolumeRoot(containing: standardizedURL) {
            return MountedSource(url: volumeURL, name: volumeURL.lastPathComponent)
        }

        return MountedSource(url: standardizedURL, name: standardizedURL.lastPathComponent)
    }

    func shouldShowMountedSource(_ url: URL, showAllVolumes: Bool) -> Bool {
        if isSystemVolume(url) { return false }
        if showAllVolumes { return true }
        if isNetworkMountedVolume(url) { return false }
        if isObviousNonDashcamVolume(url) { return false }
        return hasDashcamLikeEvidence(url)
    }

    func scan(sourceURL: URL, profiles: [DashcamProfile]) throws -> ScanResult {
        let allFiles = try enumerateFiles(sourceURL: sourceURL)
        let observedChannelRoles = observedChannelRoles(from: allFiles, sourceURL: sourceURL)
        let safeModelMetadataInfos = safeKnownModelMetadataInfos(
            sourceURL: sourceURL,
            observedChannelRoles: observedChannelRoles
        )
        let primarySafeModelMetadataInfo = safeModelMetadataInfos.first { $0.matchedModel != nil }
        let genericCardShapeHints = genericCardShapeHints(sourceURL: sourceURL, allFiles: allFiles)
        let candidates = detectProfiles(sourceURL: sourceURL, allFiles: allFiles, profiles: profiles)
        let topCandidate = candidates.first
        let selectionIssue = topCandidate.flatMap {
            profileSelectionIssue(
                $0,
                allCandidates: candidates,
                sourceURL: sourceURL,
                safeModelMetadataInfo: primarySafeModelMetadataInfo
            )
        }
        var selectedProfile: DashcamProfile?
        if let topCandidate, topCandidate.confidence != .low, selectionIssue == nil {
            selectedProfile = topCandidate.profile
        } else if topCandidate != nil {
            selectedProfile = DashcamProfile.genericNewDashcam
        } else {
            selectedProfile = nil
        }

        if selectedProfile == nil, hasCandidateMedia(in: allFiles) {
            selectedProfile = DashcamProfile.genericNewDashcam
        }
        let identifiedCamera = identifyCamera(
            from: candidates,
            selectedProfile: selectedProfile,
            sourceURL: sourceURL,
            safeModelMetadataInfo: primarySafeModelMetadataInfo
        )

        let rawClips: [ClipItem]
        if let selectedProfile, selectedProfile.id != DashcamProfile.genericNewDashcam.id {
            rawClips = classify(files: allFiles, sourceURL: sourceURL, profile: selectedProfile)
        } else {
            rawClips = classifyGenerically(files: allFiles, sourceURL: sourceURL)
        }
        let parkingPatternResult = inferParkingPatterns(in: rawClips)
        let clips = parkingPatternResult.clips

        var diagnostics = candidates.first.map {
            [
                ScanDiagnosticEntry(
                    stage: "profile_scoring",
                    profileID: $0.profile.id,
                    profileName: $0.profile.displayName,
                    outcome: "selected_initial",
                    detail: "top score \($0.score), confidence \($0.confidence.rawValue), candidates \(candidates.count)"
                )
            ]
        } ?? [
            ScanDiagnosticEntry(
                stage: "profile_scoring",
                profileID: nil,
                profileName: nil,
                outcome: "no_candidates",
                detail: "No profile scored above zero"
            )
        ]
        if let selectionIssue, let topCandidate {
            diagnostics.append(ScanDiagnosticEntry(
                stage: "profile_selection_guard",
                profileID: topCandidate.profile.id,
                profileName: topCandidate.profile.displayName,
                outcome: "selected_generic_new_card",
                detail: selectionIssue
            ))
        }
        if selectedProfile?.id == DashcamProfile.genericNewDashcam.id {
            diagnostics.append(ScanDiagnosticEntry(
                stage: "generic_fallback",
                profileID: DashcamProfile.genericNewDashcam.id,
                profileName: DashcamProfile.genericNewDashcam.displayName,
                outcome: "classified_generic_clips",
                detail: "Used filename dates and folder semantics because no reliable supported profile was selected"
            ))
        }
        for hint in genericCardShapeHints {
            diagnostics.append(ScanDiagnosticEntry(
                stage: "generic_card_shape_hint",
                profileID: selectedProfile?.id,
                profileName: selectedProfile?.displayName,
                outcome: "matched_\(hint.confidence)_family_shape",
                detail: "\(hint.manufacturer) \(hint.family): \(hint.evidence.joined(separator: "; "))"
            ))
        }
        for safeModelMetadataInfo in safeModelMetadataInfos {
            diagnostics.append(ScanDiagnosticEntry(
                stage: safeModelMetadataInfo.stage,
                profileID: selectedProfile?.id,
                profileName: selectedProfile?.displayName,
                outcome: "parsed_safe_fields",
                detail: safeModelMetadataInfo.diagnosticSummary
            ))
            if let matchedModel = safeModelMetadataInfo.matchedModel {
                diagnostics.append(contentsOf: catalogCapabilityDiagnostics(
                    modelHint: matchedModel,
                    observedChannelRoles: observedChannelRoles,
                    selectedProfile: selectedProfile
                ))
            }
        }
        if let volumeLabelHint = KnownDashcamCatalog.exactVolumeLabelMatch(sourceURL.lastPathComponent) {
            diagnostics.append(ScanDiagnosticEntry(
                stage: "known_catalog_volume_hint",
                profileID: selectedProfile?.id,
                profileName: selectedProfile?.displayName,
                outcome: "matched_known_model_label",
                detail: "Volume label \(sourceURL.lastPathComponent) matches known catalog model \(volumeLabelHint.displayName)"
            ))
            diagnostics.append(contentsOf: catalogCapabilityDiagnostics(
                modelHint: volumeLabelHint,
                observedChannelRoles: observedChannelRoles,
                selectedProfile: selectedProfile
            ))
        }
        diagnostics.append(contentsOf: parkingPatternResult.diagnostics)

        return ScanResult(
            sourceURL: sourceURL,
            allFiles: allFiles,
            candidates: candidates,
            identifiedCamera: identifiedCamera,
            selectedProfile: selectedProfile,
            clips: clips,
            diagnostics: diagnostics
        )
    }

    private func catalogCapabilityDiagnostics(
        modelHint: KnownDashcamModel,
        observedChannelRoles: Set<String>,
        selectedProfile: DashcamProfile?
    ) -> [ScanDiagnosticEntry] {
        guard let maxChannels = modelHint.channels else { return [] }

        guard !observedChannelRoles.isEmpty else { return [] }

        let observedCount = observedChannelRoles.count
        let sortedTokens = observedChannelRoles.sorted().joined(separator: ",")
        let outcome = observedCount > maxChannels ? "observed_exceeds_catalog_capability" : "observed_within_catalog_capability"
        let detail = "Known catalog model \(modelHint.displayName) supports up to \(maxChannels) channel(s); card shows \(observedCount) observed channel role(s): \(sortedTokens)"

        return [
            ScanDiagnosticEntry(
                stage: "known_catalog_capability_check",
                profileID: selectedProfile?.id,
                profileName: selectedProfile?.displayName,
                outcome: outcome,
                detail: detail
            )
        ]
    }

    private struct GenericCardShapeHint {
        var manufacturer: String
        var family: String
        var confidence: String
        var evidence: [String]
    }

    private func genericCardShapeHints(sourceURL: URL, allFiles: [URL]) -> [GenericCardShapeHint] {
        let relativePaths = allFiles.map { $0.relativePath(from: sourceURL) }
        let filenames = representativeDetectionFilenames(from: allFiles)
        let folderExists: (String) -> Bool = { path in
            let folderURL = sourceURL.appendingPathComponent(path, isDirectory: true)
            var isDirectory: ObjCBool = false
            if self.fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return true
            }
            let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return relativePaths.contains { $0 == normalized || $0.hasPrefix(normalized + "/") }
        }
        let fileExists: (String) -> Bool = { path in
            let fileURL = sourceURL.appendingPathComponent(path)
            var isDirectory: ObjCBool = false
            if self.fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                return true
            }
            let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return relativePaths.contains(normalized)
        }
        let hasFilenameMatch: (String) -> Bool = { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return false
            }
            return filenames.contains { filename in
                let nsFilename = filename as NSString
                return regex.firstMatch(in: filename, range: NSRange(location: 0, length: nsFilename.length)) != nil
            }
        }

        func hint(_ manufacturer: String, _ family: String, _ confidence: String, _ evidence: [String]) -> GenericCardShapeHint {
            GenericCardShapeHint(
                manufacturer: manufacturer,
                family: family,
                confidence: confidence,
                evidence: Array(evidence.prefix(6))
            )
        }

        var hints: [GenericCardShapeHint] = []

        if folderExists("BlackVue/Record") && folderExists("BlackVue/Config") {
            hints.append(hint(
                "BlackVue",
                "BlackVue shared Record/Config layout",
                "medium",
                ["BlackVue/Record", "BlackVue/Config", "version.bin can identify exact trained/untrained catalog models when present"]
            ))
        }

        if folderExists("cont_rec") && (folderExists("evt_rec") || folderExists("parking_rec") || folderExists("motion_timelapse_rec") || folderExists("SETTING")) {
            var evidence = ["cont_rec"]
            for path in ["evt_rec", "manual_rec", "motion_timelapse_rec", "parking_rec", "sos_rec", "SETTING"] where folderExists(path) {
                evidence.append(path)
            }
            hints.append(hint("Thinkware", "Thinkware recording-folder layout", "medium", evidence))
        }

        if folderExists("DCIM/Movie") && (folderExists("DCIM/Movie/RO") || folderExists("DCIM/RO") || folderExists("DCIM/Movie/Parking") || folderExists("DCIM/Parking") || folderExists("DCIM/Photo")) {
            hints.append(hint(
                "VIOFO",
                "VIOFO DCIM/Movie layout",
                "medium",
                ["DCIM/Movie", "RO for locked clips when present", "Parking subfolder when present", "exact A-series model still needs OSD/user/trained evidence"]
            ))
        }

        if folderExists("DCIM/100EVENT") || folderExists("DCIM/103PARKM") || folderExists("DCIM/104UNSVD") {
            var evidence = ["DCIM"]
            for path in ["DCIM/100EVENT", "DCIM/101PHOTO", "DCIM/102SAVED", "DCIM/103PARKM", "DCIM/104TLPSE", "DCIM/104UNSVD", "DCIM/105UNSVD"] where folderExists(path) {
                evidence.append(path)
            }
            hints.append(hint("Garmin", "Garmin Dash Cam numbered DCIM folders", "medium", evidence))
        }

        if folderExists("Videos") && folderExists("Protected") {
            hints.append(hint("Nextbase", "Nextbase Videos/Protected layout", "medium", ["Videos", "Protected"]))
        } else if folderExists("Video") && folderExists("Protected") && folderExists("Photo") {
            hints.append(hint("Nextbase", "Nextbase Video/Protected/Photo layout", "medium", ["Video", "Protected", "Photo"]))
        }

        if folderExists("CarDV/Movie/Normal") && folderExists("CarDV/Movie/Park") {
            var evidence = ["CarDV/Movie/Normal", "CarDV/Movie/Park"]
            if folderExists("LOG/DEVLOG") { evidence.append("LOG/DEVLOG") }
            hints.append(hint("Miofive", "Miofive/CarDV family layout", "medium", evidence))
        }

        if (folderExists("front_norm") || folderExists("rear_norm")) &&
            (folderExists("front_emer") || folderExists("rear_emer")) {
            var evidence: [String] = []
            for path in ["front_norm", "rear_norm", "front_emer", "rear_emer", "front_photo", "rear_photo", "GPS_Player.txt"] {
                if folderExists(path) || fileExists(path) {
                    evidence.append(path)
                }
            }
            hints.append(hint("Wolfbox", "Wolfbox front/rear normal/emergency layout", "medium", evidence))
        }

        if folderExists("TeslaCam") &&
            (folderExists("TeslaCam/RecentClips") || folderExists("TeslaCam/SavedClips") || folderExists("TeslaCam/SentryClips")) {
            var evidence = ["TeslaCam"]
            for path in ["TeslaCam/RecentClips", "TeslaCam/SavedClips", "TeslaCam/SentryClips"] where folderExists(path) {
                evidence.append(path)
            }
            if hasFilenameMatch(#"^20\d{2}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-(front|back|rear|rear_view|left_repeater|right_repeater|left_pillar|right_pillar)\.mp4$"#) {
                evidence.append("TeslaCam timestamp-camera MP4 filenames")
            }
            if hasFilenameMatch(#"^(event|thumb)\.(json|png)$"#) {
                evidence.append("event.json/thumb.png session sidecars")
            }
            hints.append(hint("Tesla", "TeslaCam USB layout", "medium", evidence))
        }

        if folderExists("Normal") && (folderExists("Event") || folderExists("Parking")) && folderExists("GPS") {
            hints.append(hint("Vantrue", "Vantrue root Normal/Event/Parking/GPS layout", "medium", ["Normal", "Event/Parking", "GPS"]))
        }

        if folderExists("Normal") && (folderExists("Parking") || folderExists("Lapse")) && (fileExists(".formated") || fileExists(".sstar.format")) {
            hints.append(hint("70mai", "70mai root recording layout", "medium", ["Normal", "Parking/Lapse", ".formated or .sstar.format marker"]))
        }

        if folderExists("INF") && (folderExists("PARK") || folderExists("PEVENT")) {
            var evidence = ["INF"]
            for path in ["EVENT", "PARK", "PEVENT", "USER", "CONFIG"] where folderExists(path) {
                evidence.append(path)
            }
            hints.append(hint("Vueroid", "Vueroid INF/PARK/PEVENT layout", "medium", evidence))
        }

        if folderExists("VIDEO") && folderExists("PROTECTED") && hasFilenameMatch(#"^\d{8}_\d{6}_[LRB]\.MP4$"#) {
            hints.append(hint("Cansonic", "Cansonic UltraDash multi-channel layout", "medium", ["VIDEO", "PROTECTED", "L/R/B channel suffix filenames"]))
        }

        if folderExists("360CARDVR/REC") && (folderExists("360CARDVR/PARKING") || folderExists("360CARDVR/SECVIDEO")) {
            var evidence = ["360CARDVR/REC"]
            for path in ["360CARDVR/PARKING", "360CARDVR/SECVIDEO", "360CARDVR/GPS", "MISC"] where folderExists(path) {
                evidence.append(path)
            }
            hints.append(hint("Botslab", "Botslab/360CARDVR layout", "medium", evidence))
        }

        if folderExists("Escort_M1/MOVIE") && folderExists("Escort_M1/LockedVideo") {
            hints.append(hint("Escort", "Escort M-series layout", "medium", ["Escort_M1/MOVIE", "Escort_M1/LockedVideo"]))
        }

        if folderExists("DCIM/RoadScout") {
            hints.append(hint("Cobra", "Cobra Road Scout DCIM layout", "medium", ["DCIM/RoadScout"]))
        }

        if folderExists("DCIM") && (
            folderExists("DCIM/NormalVideo") ||
                folderExists("DCIM/EventVideo") ||
                folderExists("DCIM/ParkingVideo") ||
                folderExists("DCIM/Photo")
        ) {
            var evidence = ["DCIM"]
            for path in ["DCIM/NormalVideo", "DCIM/EventVideo", "DCIM/ParkingVideo", "DCIM/Photo"] where folderExists(path) {
                evidence.append(path)
            }
            hints.append(hint("DDPAI", "DDPAI DCIM mode folders", "medium", evidence))
        }

        if folderExists("Video") && hasFilenameMatch(#"^\d{4}_\d{4}_\d{6}_\d+\.MP4$"#) {
            hints.append(hint("Rove", "Rove Video root layout", "low", ["Video", "Rove-style numeric timestamp filenames"]))
        }

        return hints
    }

    private func isTeslaCamLayout(sourceURL: URL) -> Bool {
        let root = sourceURL.appendingPathComponent("TeslaCam", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        return ["RecentClips", "SavedClips", "SentryClips"].contains { folder in
            let url = root.appendingPathComponent(folder, isDirectory: true)
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private func profileSelectionIssue(
        _ candidate: DetectionCandidate,
        allCandidates: [DetectionCandidate],
        sourceURL: URL,
        safeModelMetadataInfo: SafeModelMetadataInfo? = nil
    ) -> String? {
        if candidate.confidence == .low {
            return "Top candidate scored only low confidence, so the card was treated as unrecognized"
        }

        if knownCatalogVolumeMatches(candidate, sourceURL: sourceURL) {
            return nil
        }
        if let safeModelMetadataInfo,
           let matchedModel = safeModelMetadataInfo.matchedModel {
            if profile(candidate.profile, matchesKnownModel: matchedModel) {
                return nil
            }
            if candidate.profile.manufacturer.caseInsensitiveCompare(matchedModel.manufacturer) == .orderedSame,
               candidate.profile.status.caseInsensitiveCompare("generic") == .orderedSame {
                return nil
            }
            return "\(safeModelMetadataInfo.sourcePath) identifies \(matchedModel.displayName), so this card was not selected as different profile \(candidate.profile.displayName) from shared folder/filename evidence."
        }

        let hasModelEvidence = hasExplicitModelEvidence(candidate)
        let hasFilenameEvidence = candidate.evidence.contains { $0.hasPrefix("filename pattern match ") }
        if hasModelEvidence {
            return nil
        }

        if let catalogConflict = knownCatalogVolumeConflict(candidate, sourceURL: sourceURL) {
            return catalogConflict
        }

        if hasFilenameEvidence,
           hasSameManufacturerAmbiguity(candidate, allCandidates: allCandidates),
           !hasDistinctiveFilenameEvidence(candidate, allCandidates: allCandidates) {
            return "Top candidate matched filename structure, but nearby \(candidate.profile.displayManufacturer) sibling profiles also matched and no explicit model text or OSD proof was found. Treating this as an unrecognized/new camera instead of assuming \(candidate.profile.displayName)."
        }

        if let exceededMaxChannels = exceededProfileMaxChannelEvidence(candidate) {
            return "Top candidate matched filename structure, but this card shows \(exceededMaxChannels), which exceeds the known \(candidate.profile.displayName) channel capability. Treating this as an unrecognized/new camera instead of assuming this exact model."
        }

        if let unsupportedTokens = unsupportedFilenameChannelTokenEvidence(candidate) {
            return "Top candidate matched filename structure, but this card also contains channel token(s) \(unsupportedTokens) outside the \(candidate.profile.displayName) profile. Treating this as an unrecognized/new camera instead of assuming this exact model."
        }

        if hasFilenameEvidence, requiresExplicitModelEvidence(candidate.profile) {
            return "Top candidate matched a supported card layout, but this profile requires exact model evidence. Treating this as an unrecognized/new camera instead of assuming \(candidate.profile.displayName)."
        }

        if hasFilenameEvidence {
            return nil
        }

        return "Top candidate matched only shared folder/volume structure, with no model text or filename-pattern verification. Treating this as an unrecognized/new camera instead of assuming \(candidate.profile.displayName)."
    }

    private func hasExplicitModelEvidence(_ candidate: DetectionCandidate) -> Bool {
        candidate.evidence.contains { evidence in
            evidence.hasPrefix("model text ") ||
                evidence.hasPrefix("model evidence ") ||
                evidence.hasPrefix("media fingerprint ") ||
                evidence.hasPrefix("OSD OCR match ")
        }
    }

    private func knownCatalogVolumeConflict(_ candidate: DetectionCandidate, sourceURL: URL) -> String? {
        guard let volumeLabelHint = KnownDashcamCatalog.exactVolumeLabelMatch(sourceURL.lastPathComponent) else {
            return nil
        }
        guard !profile(candidate.profile, matchesKnownModel: volumeLabelHint) else {
            return nil
        }

        return "Volume label \(sourceURL.lastPathComponent) exactly matches known catalog model \(volumeLabelHint.displayName), so this card was not selected as different profile \(candidate.profile.displayName) from shared folder/filename evidence."
    }

    private func knownCatalogVolumeMatches(_ candidate: DetectionCandidate, sourceURL: URL) -> Bool {
        guard let volumeLabelHint = KnownDashcamCatalog.exactVolumeLabelMatch(sourceURL.lastPathComponent) else {
            return false
        }
        return profile(candidate.profile, matchesKnownModel: volumeLabelHint)
    }

    private func profile(_ profile: DashcamProfile, matchesKnownModel model: KnownDashcamModel) -> Bool {
        compactModelToken(profile.manufacturer) == compactModelToken(model.manufacturer) &&
            model.searchNames.contains { compactModelToken($0) == compactModelToken(profile.model) }
    }

    private func requiresExplicitModelEvidence(_ profile: DashcamProfile) -> Bool {
        ["botslab-g980h"].contains(profile.id)
    }

    private func hasSameManufacturerAmbiguity(_ candidate: DetectionCandidate, allCandidates: [DetectionCandidate]) -> Bool {
        let candidateManufacturer = compactModelToken(candidate.profile.manufacturer)
        guard !candidateManufacturer.isEmpty else { return false }

        return allCandidates.contains { other in
            guard other.profile.id != candidate.profile.id else { return false }
            guard compactModelToken(other.profile.manufacturer) == candidateManufacturer else { return false }
            guard other.confidence != .low else { return false }
            guard other.score >= max(20, candidate.score - 20) else { return false }
            guard !hasExplicitModelEvidence(other) else { return false }
            return other.evidence.contains { evidence in
                evidence.hasPrefix("filename pattern match ") ||
                    evidence.hasPrefix("folder ") ||
                    evidence.hasPrefix("volume label ")
            }
        }
    }

    private func hasDistinctiveFilenameEvidence(_ candidate: DetectionCandidate, allCandidates: [DetectionCandidate]) -> Bool {
        let tokens = filenameChannelTokens(from: candidate)
        guard !tokens.isEmpty else { return false }

        let candidateManufacturer = compactModelToken(candidate.profile.manufacturer)
        let siblingChannelTokens = allCandidates
            .filter { other in
                other.profile.id != candidate.profile.id &&
                    compactModelToken(other.profile.manufacturer) == candidateManufacturer &&
                    other.score >= max(20, candidate.score - 20)
            }
            .flatMap { $0.profile.channels.keys.map { $0.uppercased() } }

        guard !siblingChannelTokens.isEmpty else { return false }
        return tokens.contains { !siblingChannelTokens.contains($0) }
    }

    private func filenameChannelTokens(from candidate: DetectionCandidate) -> [String] {
        guard let evidence = candidate.evidence.first(where: { $0.hasPrefix("filename channel tokens ") }) else {
            return []
        }

        let raw = String(evidence.dropFirst("filename channel tokens ".count))
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }

    private func unsupportedFilenameChannelTokenEvidence(_ candidate: DetectionCandidate) -> String? {
        guard let evidence = candidate.evidence.first(where: { $0.hasPrefix("filename channel tokens outside profile ") }) else {
            return nil
        }

        let raw = String(evidence.dropFirst("filename channel tokens outside profile ".count))
        let tokens = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
        return tokens.isEmpty ? nil : tokens.joined(separator: ",")
    }

    private func exceededProfileMaxChannelEvidence(_ candidate: DetectionCandidate) -> String? {
        guard let evidence = candidate.evidence.first(where: { $0.hasPrefix("observed channel count ") }) else {
            return nil
        }
        return String(evidence.dropFirst("observed channel count ".count))
    }

    /// Async scan that augments folder/filename detection with OSD OCR to
    /// disambiguate sibling models (e.g. VIOFO A229 Pro vs Plus vs Ultra).
    ///
    /// OSD probing runs when the folder/filename result is ambiguous, or when
    /// several sibling candidates have OSD specs. VIOFO A229/A329 siblings can
    /// score high from identical folders and filename patterns, so confidence
    /// alone is not enough to skip OCR. A confirmed OSD match bumps that
    /// profile's score by 80, re-sorts the candidates, and re-selects the
    /// winner. OSD probing is best-effort, a failed probe leaves the original
    /// result unchanged.
    func scanWithOSD(sourceURL: URL, profiles: [DashcamProfile]) throws -> ScanResult {
        var result = try scan(sourceURL: sourceURL, profiles: profiles)

        guard let top = result.candidates.first else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "osd_ocr_gate",
                profileID: nil,
                profileName: nil,
                outcome: "skipped_no_candidates",
                detail: "No profile candidates available for OSD OCR"
            ))
            augmentWithGenericCatalogOSDIfNeeded(&result, sourceURL: sourceURL)
            return result
        }

        // Disambiguation only matters when another candidate is close behind.
        let hasCompetition = result.candidates.dropFirst().contains { abs(top.score - $0.score) <= 15 }
        let osdCandidateCount = result.candidates.filter { $0.profile.osdSpec?.containsModelName == true }.count
        let hasOSDSiblingCompetition = top.profile.osdSpec?.containsModelName == true && osdCandidateCount >= 2
        guard hasCompetition || hasOSDSiblingCompetition else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "osd_ocr_gate",
                profileID: top.profile.id,
                profileName: top.profile.displayName,
                outcome: "skipped_no_ocr_competition",
                detail: "Top score \(top.score), confidence \(top.confidence.rawValue); closeCompetition \(hasCompetition), osdSiblingCandidates \(osdCandidateCount)"
            ))
            augmentWithGenericCatalogOSDIfNeeded(&result, sourceURL: sourceURL)
            return result
        }

        result.diagnostics.append(ScanDiagnosticEntry(
            stage: "osd_ocr_gate",
            profileID: top.profile.id,
            profileName: top.profile.displayName,
            outcome: "running",
            detail: "Top score \(top.score), confidence \(top.confidence.rawValue); closeCompetition \(hasCompetition), osdSiblingCandidates \(osdCandidateCount)"
        ))

        let probe = OSDProbe()
        var updatedCandidates = result.candidates

        for index in updatedCandidates.indices {
            let candidate = updatedCandidates[index]
            guard candidate.profile.id == top.profile.id || abs(top.score - candidate.score) <= 15 else {
                if candidate.profile.osdSpec?.containsModelName == true {
                    result.diagnostics.append(ScanDiagnosticEntry(
                        stage: "osd_ocr_probe",
                        profileID: candidate.profile.id,
                        profileName: candidate.profile.displayName,
                        outcome: "skipped_not_competitive",
                        detail: "Candidate score \(candidate.score) was more than 15 points below top score \(top.score)"
                    ))
                }
                continue
            }
            guard let spec = candidate.profile.osdSpec, spec.containsModelName else {
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "skipped_no_osd_spec",
                    detail: "Profile has no OSD OCR spec"
                ))
                continue
            }

            let sampleVideos = sampleVideos(
                for: spec,
                allFiles: result.allFiles
            )
            let probeChannelList = spec.probeChannels.joined(separator: ",")
            guard !sampleVideos.isEmpty else {
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "skipped_no_sample_videos",
                    detail: "No video matched probe channels \(probeChannelList)"
                ))
                continue
            }

            var frameCount = 0
            var framesWithText = 0
            var textCandidateCount = 0
            var matchedString: String?
            var videosChecked = 0

            for videoURL in sampleVideos {
                videosChecked += 1
                let probeResult = probe.probeWithDiagnostics(videoURL: videoURL, spec: spec)
                frameCount += probeResult.framesExtracted
                framesWithText += probeResult.framesWithText
                textCandidateCount += probeResult.textCandidateCount
                if let matched = probeResult.matchedString {
                    matchedString = matched
                    break
                }
            }

            let detail = "videos \(videosChecked), frames \(frameCount), framesWithText \(framesWithText), textCandidates \(textCandidateCount)"
            if let matched = matchedString {
                updatedCandidates[index].score += 80
                var evidence = updatedCandidates[index].evidence
                evidence.insert("OSD OCR match \"\(matched)\"", at: 0)
                updatedCandidates[index].evidence = Array(evidence.prefix(8))
                updatedCandidates[index].confidence = confidenceLevel(for: updatedCandidates[index].score)
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "matched",
                    detail: detail
                ))
            } else {
                result.diagnostics.append(ScanDiagnosticEntry(
                    stage: "osd_ocr_probe",
                    profileID: candidate.profile.id,
                    profileName: candidate.profile.displayName,
                    outcome: "no_match",
                    detail: detail
                ))
            }
        }

        updatedCandidates.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.profile.displayName < rhs.profile.displayName
        }

        result.candidates = updatedCandidates
        let observedChannelRoles = observedChannelRoles(from: result.allFiles, sourceURL: sourceURL)
        let safeModelMetadataInfo = safeKnownModelMetadataInfos(
            sourceURL: sourceURL,
            observedChannelRoles: observedChannelRoles
        ).first { $0.matchedModel != nil }
        result.identifiedCamera = identifyCamera(
            from: updatedCandidates,
            selectedProfile: result.selectedProfile,
            sourceURL: sourceURL,
            safeModelMetadataInfo: safeModelMetadataInfo
        )

        // Re-select and re-classify if the winner changed.
        let updatedSelectionIssue = updatedCandidates.first.flatMap {
            profileSelectionIssue(
                $0,
                allCandidates: updatedCandidates,
                sourceURL: sourceURL,
                safeModelMetadataInfo: safeModelMetadataInfo
            )
        }
        if let updatedSelectionIssue, let newTop = updatedCandidates.first {
            let parkingPatternResult = inferParkingPatterns(in: classifyGenerically(files: result.allFiles, sourceURL: sourceURL))
            result.selectedProfile = DashcamProfile.genericNewDashcam
            result.clips = parkingPatternResult.clips
            result.identifiedCamera = nil
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "profile_selection_guard",
                profileID: newTop.profile.id,
                profileName: newTop.profile.displayName,
                outcome: "selected_generic_new_card",
                detail: updatedSelectionIssue
            ))
            result.diagnostics.append(contentsOf: parkingPatternResult.diagnostics)
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "generic_fallback",
                profileID: DashcamProfile.genericNewDashcam.id,
                profileName: DashcamProfile.genericNewDashcam.displayName,
                outcome: "classified_generic_clips",
                detail: "Used filename dates and folder semantics because no reliable supported profile was selected"
            ))
        } else if let newTop = updatedCandidates.first,
                  newTop.confidence != .low,
                  newTop.profile.id != result.selectedProfile?.id {
            result.selectedProfile = newTop.profile
            result.clips = classifyWithParkingPatterns(files: result.allFiles, sourceURL: sourceURL, profile: newTop.profile).clips
        } else if result.selectedProfile == nil {
            if let newTop = updatedCandidates.first, newTop.confidence != .low {
                result.selectedProfile = newTop.profile
            }
        }

        augmentWithGenericCatalogOSDIfNeeded(&result, sourceURL: sourceURL)
        return result
    }

    /// Generic/untrained cards can still burn exact model text into the video
    /// OSD. Use card-shape hints to limit the OCR search to likely brands,
    /// then expose the matched catalog model while keeping the generic import
    /// path unless a trained profile exists.
    private func augmentWithGenericCatalogOSDIfNeeded(_ result: inout ScanResult, sourceURL: URL) {
        guard result.identifiedCamera == nil else { return }
        guard result.selectedProfile?.id == DashcamProfile.genericNewDashcam.id || result.selectedProfile == nil else { return }

        let hints = genericCardShapeHints(sourceURL: sourceURL, allFiles: result.allFiles)
        let hintedManufacturers = Set(hints.map { compactModelToken($0.manufacturer) })
        guard !hintedManufacturers.isEmpty else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "catalog_osd_ocr_gate",
                profileID: result.selectedProfile?.id,
                profileName: result.selectedProfile?.displayName,
                outcome: "skipped_no_family_hint",
                detail: "No brand/family card-shape hint was available to constrain generic catalog OCR"
            ))
            return
        }

        let candidateModels = KnownDashcamCatalog.models.filter {
            hintedManufacturers.contains(compactModelToken($0.manufacturer))
        }
        let matchStrings = Array(Set(candidateModels.flatMap(\.searchNames)))
            .sorted {
                let left = compactModelToken($0).count
                let right = compactModelToken($1).count
                if left != right { return left > right }
                return $0 < $1
            }
        guard !matchStrings.isEmpty else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "catalog_osd_ocr_gate",
                profileID: result.selectedProfile?.id,
                profileName: result.selectedProfile?.displayName,
                outcome: "skipped_no_catalog_match_strings",
                detail: "Family hint matched no catalog OSD strings"
            ))
            return
        }

        let spec = OSDSpec(
            containsModelName: true,
            matchStrings: matchStrings,
            stripPercent: 0.16,
            probeChannels: ["F", "front"]
        )
        let sampleVideos = sampleVideos(for: spec, allFiles: result.allFiles)
        guard !sampleVideos.isEmpty else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "catalog_osd_ocr_gate",
                profileID: result.selectedProfile?.id,
                profileName: result.selectedProfile?.displayName,
                outcome: "skipped_no_sample_videos",
                detail: "No sample videos were available for generic catalog OCR"
            ))
            return
        }

        result.diagnostics.append(ScanDiagnosticEntry(
            stage: "catalog_osd_ocr_gate",
            profileID: result.selectedProfile?.id,
            profileName: result.selectedProfile?.displayName,
            outcome: "running",
            detail: "Trying \(candidateModels.count) catalog model(s) across hinted manufacturer(s) \(hintedManufacturers.sorted().joined(separator: ","))"
        ))

        let probe = OSDProbe()
        var frameCount = 0
        var framesWithText = 0
        var textCandidateCount = 0
        var matchedString: String?
        var videosChecked = 0

        for videoURL in sampleVideos {
            videosChecked += 1
            let probeResult = probe.probeWithDiagnostics(videoURL: videoURL, spec: spec)
            frameCount += probeResult.framesExtracted
            framesWithText += probeResult.framesWithText
            textCandidateCount += probeResult.textCandidateCount
            if let matched = probeResult.matchedString {
                matchedString = matched
                break
            }
        }

        let detail = "videos \(videosChecked), frames \(frameCount), framesWithText \(framesWithText), textCandidates \(textCandidateCount)"
        guard let matchedString else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "catalog_osd_ocr_probe",
                profileID: result.selectedProfile?.id,
                profileName: result.selectedProfile?.displayName,
                outcome: "no_match",
                detail: detail
            ))
            return
        }

        guard let baseMatchedModel = candidateModels.first(where: { model in
            model.searchNames.contains { compactModelToken($0) == compactModelToken(matchedString) }
        }) ?? KnownDashcamCatalog.exactModelMention(matchedString) else {
            result.diagnostics.append(ScanDiagnosticEntry(
                stage: "catalog_osd_ocr_probe",
                profileID: result.selectedProfile?.id,
                profileName: result.selectedProfile?.displayName,
                outcome: "matched_unresolved_catalog_model",
                detail: "\(detail); matched OCR string \(matchedString)"
            ))
            return
        }
        let observedChannelRoles = observedChannelRoles(from: result.allFiles, sourceURL: sourceURL)
        let matchedModel = refinedGenericCatalogOSDModel(
            baseMatchedModel,
            matchedString: matchedString,
            candidateModels: candidateModels,
            observedChannelRoles: observedChannelRoles,
            allFiles: result.allFiles,
            sourceURL: sourceURL
        )

        result.identifiedCamera = IdentifiedCamera(
            manufacturer: matchedModel.manufacturer,
            model: matchedModel.model,
            evidence: ["OSD OCR match \"\(matchedString)\" from video frame"],
            isSupported: false
        )
        result.diagnostics.append(ScanDiagnosticEntry(
            stage: "catalog_osd_ocr_probe",
            profileID: result.selectedProfile?.id,
            profileName: result.selectedProfile?.displayName,
            outcome: "matched_known_untrained_model",
            detail: "\(detail); matched \(matchedModel.displayName) from OSD string \(matchedString)"
        ))
    }

    private func refinedGenericCatalogOSDModel(
        _ baseModel: KnownDashcamModel,
        matchedString: String,
        candidateModels: [KnownDashcamModel],
        observedChannelRoles: Set<String>,
        allFiles: [URL],
        sourceURL: URL
    ) -> KnownDashcamModel {
        guard compactModelToken(baseModel.manufacturer) == "wolfbox" else { return baseModel }

        let matchedToken = compactModelToken(matchedString)
        let isG900Family = matchedToken.contains("g900") || compactModelToken(baseModel.model).contains("g900")
        guard isG900Family else { return baseModel }

        let observedThreeChannel = observedChannelRoles.count >= 3 &&
            (observedChannelRoles.contains("interior") ||
                observedChannelRoles.contains("cabin") ||
                observedChannelRoles.contains("bumper") ||
                observedChannelRoles.contains("channel_c"))
        if observedThreeChannel {
            if observedChannelRoles.contains("bumper"),
               let bumper = catalogModel(
                manufacturer: "Wolfbox",
                modelText: "G900 TriPro Bumper",
                candidateModels: candidateModels
               ) {
                return bumper
            }
            if (observedChannelRoles.contains("interior") || observedChannelRoles.contains("cabin")),
               let cabin = catalogModel(
                manufacturer: "Wolfbox",
                modelText: "G900 TriPro Cabin",
                candidateModels: candidateModels
               ) {
                return cabin
            }
            if let triPro = catalogModel(
                manufacturer: "Wolfbox",
                modelText: "G900 TriPro",
                candidateModels: candidateModels
            ) {
                return triPro
            }
        }

        if matchedToken.contains("g900pro") || wolfboxG900ProMediaFingerprint(allFiles: allFiles, sourceURL: sourceURL),
           let pro = catalogModel(manufacturer: "Wolfbox", modelText: "G900 Pro", candidateModels: candidateModels) {
            return pro
        }

        return baseModel
    }

    private func catalogModel(
        manufacturer: String,
        modelText: String,
        candidateModels: [KnownDashcamModel]
    ) -> KnownDashcamModel? {
        let manufacturerToken = compactModelToken(manufacturer)
        let modelToken = compactModelToken(modelText)
        return candidateModels.first {
            compactModelToken($0.manufacturer) == manufacturerToken &&
                $0.searchNames.contains { compactModelToken($0) == modelToken }
        } ?? KnownDashcamCatalog.exactModelMatch(manufacturer: manufacturer, modelText: modelText)
    }

    private func wolfboxG900ProMediaFingerprint(allFiles: [URL], sourceURL: URL) -> Bool {
        guard let front = firstVideoDimensions(forChannel: "front", allFiles: allFiles, sourceURL: sourceURL),
              let rear = firstVideoDimensions(forChannel: "rear", allFiles: allFiles, sourceURL: sourceURL) else {
            return false
        }

        let frontIs4K = front.width >= 3800 && front.height >= 2100
        let rearIs2_5K = rear.width >= 2500 && rear.width <= 2600 &&
            rear.height >= 1400 && rear.height <= 1480
        return frontIs4K && rearIs2_5K
    }

    private func firstVideoDimensions(
        forChannel channel: String,
        allFiles: [URL],
        sourceURL: URL
    ) -> (width: Int, height: Int)? {
        for fileURL in allFiles {
            let ext = fileURL.pathExtension.lowercased()
            guard ["mp4", "mov"].contains(ext) else { continue }
            let relativePath = fileURL.relativePath(from: sourceURL)
            guard genericChannel(relativePath: relativePath, filename: fileURL.lastPathComponent) == channel else {
                continue
            }
            if let dimensions = videoDimensions(for: fileURL) {
                return dimensions
            }
        }
        return nil
    }

    /// Finds front-channel sample videos matching the OSD spec's channels.
    /// VIOFO front clips end in a channel suffix (e.g. `..._F.MP4`). Falls
    /// back to early videos if no channel-suffixed clip is found.
    private func sampleVideos(for spec: OSDSpec, allFiles: [URL]) -> [URL] {
        let videos = allFiles.filter { ["mp4", "mov"].contains($0.pathExtension.lowercased()) }
        guard !videos.isEmpty else { return [] }

        var matches: [URL] = []
        for channel in spec.probeChannels {
            let suffix = channel.uppercased()
            matches.append(contentsOf: videos.filter { url in
                let stem = url.deletingPathExtension().lastPathComponent.uppercased()
                return stem.hasSuffix(suffix)
            })
        }

        // No channel-suffixed clip; the OSD is still likely on early clips.
        let candidates = matches.isEmpty ? videos : matches
        return Array(candidates.prefix(5))
    }

    private func confidenceLevel(for score: Int) -> DetectionConfidence {
        if score >= 70 {
            return .high
        } else if score >= 25 {
            return .medium
        } else {
            return .low
        }
    }

    private func identifyCamera(
        from candidates: [DetectionCandidate],
        selectedProfile: DashcamProfile?,
        sourceURL: URL,
        safeModelMetadataInfo: SafeModelMetadataInfo? = nil
    ) -> IdentifiedCamera? {
        if let safeModelMetadataInfo,
           let matchedModel = safeModelMetadataInfo.matchedModel {
            let selectedSupportsExactModel = selectedProfile.map {
                $0.manufacturer.caseInsensitiveCompare(matchedModel.manufacturer) == .orderedSame &&
                    self.profile($0, matchesKnownModel: matchedModel)
            } ?? false
            return IdentifiedCamera(
                manufacturer: matchedModel.manufacturer,
                model: matchedModel.model,
                evidence: safeModelMetadataInfo.safeEvidence,
                isSupported: selectedSupportsExactModel
            )
        }

        if let selectedProfile,
           selectedProfile.id != DashcamProfile.genericNewDashcam.id,
           let volumeLabelHint = KnownDashcamCatalog.exactVolumeLabelMatch(sourceURL.lastPathComponent),
           profile(selectedProfile, matchesKnownModel: volumeLabelHint) {
            return IdentifiedCamera(
                manufacturer: volumeLabelHint.manufacturer,
                model: volumeLabelHint.model,
                evidence: ["Volume label \(sourceURL.lastPathComponent) matches known catalog model \(volumeLabelHint.displayName)"],
                isSupported: true
            )
        }

        guard let top = candidates.first else {
            return nil
        }
        guard top.confidence != .low else {
            return nil
        }

        let hasExplicitModelEvidence = hasExplicitModelEvidence(top) ||
            (top.evidence.contains { $0.hasPrefix("filename pattern match ") } &&
                (!hasSameManufacturerAmbiguity(top, allCandidates: candidates) ||
                    hasDistinctiveFilenameEvidence(top, allCandidates: candidates)))
        guard hasExplicitModelEvidence else {
            return nil
        }

        let profile = selectedProfile ?? top.profile
        guard profile.id != DashcamProfile.genericNewDashcam.id else { return nil }

        return IdentifiedCamera(
            manufacturer: profile.manufacturer,
            model: profile.model,
            evidence: Array(top.evidence.prefix(5)),
            isSupported: true
        )
    }

    private struct SafeModelMetadataInfo {
        var manufacturer: String
        var modelText: String
        var firmwareVersion: String?
        var sourcePath: String
        var valueLabel: String
        var stage: String

        var matchedModel: KnownDashcamModel? {
            KnownDashcamCatalog.exactModelMention(modelText, manufacturer: manufacturer)
        }

        var safeEvidence: [String] {
            var result = ["\(sourcePath) \(valueLabel): \(modelText)"]
            if let firmwareVersion {
                result.append("\(sourcePath) firmware version: \(firmwareVersion)")
            }
            return result
        }

        var diagnosticSummary: String {
            safeEvidence.joined(separator: "; ")
        }
    }

    private func safeKnownModelMetadataInfos(
        sourceURL: URL,
        observedChannelRoles: Set<String>
    ) -> [SafeModelMetadataInfo] {
        [
            safeGoProModelMetadataInfo(sourceURL: sourceURL),
            safeBlackVueModelMetadataInfo(sourceURL: sourceURL),
            safeThinkwareModelMetadataInfo(sourceURL: sourceURL),
            safeVantrueModelMetadataInfo(sourceURL: sourceURL),
            safeVueroidModelMetadataInfo(sourceURL: sourceURL),
            safeCommonBrandModelMetadataInfo(sourceURL: sourceURL, manufacturer: "Miofive"),
            safeWolfboxModelMetadataInfo(sourceURL: sourceURL, observedChannelRoles: observedChannelRoles),
            safeTeslaChannelConfigurationInfo(sourceURL: sourceURL, observedChannelRoles: observedChannelRoles),
            safeSonyModelMetadataInfo(sourceURL: sourceURL)
        ].compactMap { $0 }
    }

    private func safeTeslaChannelConfigurationInfo(
        sourceURL: URL,
        observedChannelRoles: Set<String>
    ) -> SafeModelMetadataInfo? {
        guard isTeslaCamLayout(sourceURL: sourceURL) else { return nil }

        let hasBaseChannels = observedChannelRoles.isSuperset(of: ["front", "rear", "left_repeater", "right_repeater"])
        let hasPillarChannels = observedChannelRoles.contains("left_pillar") || observedChannelRoles.contains("right_pillar")
        let modelText: String
        let valueLabel: String

        if hasBaseChannels, hasPillarChannels {
            modelText = "TeslaCam 6-Camera"
            valueLabel = "configuration inferred from TeslaCam folders plus pillar camera filenames"
        } else if hasBaseChannels {
            modelText = "TeslaCam 4-Camera"
            valueLabel = "configuration inferred from TeslaCam folders plus repeater camera filenames"
        } else {
            return nil
        }

        return SafeModelMetadataInfo(
            manufacturer: "Tesla",
            modelText: modelText,
            firmwareVersion: nil,
            sourcePath: "TeslaCam",
            valueLabel: valueLabel,
            stage: "tesla_channel_configuration"
        )
    }

    private func safeWolfboxModelMetadataInfo(
        sourceURL: URL,
        observedChannelRoles: Set<String>
    ) -> SafeModelMetadataInfo? {
        guard var info = safeCommonBrandModelMetadataInfo(sourceURL: sourceURL, manufacturer: "Wolfbox") else {
            return nil
        }

        let normalizedModelText = info.modelText
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        let isG900Family = normalizedModelText.contains("g900")
        let explicitlyTriPro = normalizedModelText.contains("tripro")
        let explicitlyPro = normalizedModelText.contains("g900pro")
        let observedThreeChannel = observedChannelRoles.count >= 3 &&
            (observedChannelRoles.contains("interior") ||
                observedChannelRoles.contains("cabin") ||
                observedChannelRoles.contains("bumper") ||
                observedChannelRoles.contains("channel_c"))

        if isG900Family, observedThreeChannel, !explicitlyTriPro {
            if observedChannelRoles.contains("bumper"),
               let triProBumper = KnownDashcamCatalog.exactModelMatch(manufacturer: "Wolfbox", modelText: "G900 TriPro Bumper") {
                info.modelText = triProBumper.model
                info.valueLabel = "model inferred from G900-family metadata plus 3CH bumper channel evidence"
            } else if (observedChannelRoles.contains("interior") || observedChannelRoles.contains("cabin")),
                      let triProCabin = KnownDashcamCatalog.exactModelMatch(manufacturer: "Wolfbox", modelText: "G900 TriPro Cabin") {
                info.modelText = triProCabin.model
                info.valueLabel = "model inferred from G900-family metadata plus 3CH cabin channel evidence"
            } else if let triPro = KnownDashcamCatalog.exactModelMatch(manufacturer: "Wolfbox", modelText: "G900 TriPro") {
                info.modelText = triPro.model
                info.valueLabel = "model inferred from G900-family metadata plus 3CH channel evidence"
            }
        } else if isG900Family, explicitlyPro, observedChannelRoles.count == 2 {
            info.valueLabel = "model confirmed with 2CH channel evidence"
        }

        return info
    }

    private func safeCommonBrandModelMetadataInfo(sourceURL: URL, manufacturer: String) -> SafeModelMetadataInfo? {
        let paths = [
            "version.txt",
            "VERSION.TXT",
            "model.txt",
            "MODEL.TXT",
            "device_info.txt",
            "DEVICE_INFO.TXT",
            "system_info.txt",
            "SYSTEM_INFO.TXT",
            "\(manufacturer)/version.txt",
            "\(manufacturer.uppercased())/VERSION.TXT",
            "SYSTEM/version.txt",
            "SYSTEM/VERSION.TXT"
        ]

        for relativePath in paths {
            let metadataURL = sourceURL.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: metadataURL.path),
                  let raw = evidenceText(at: metadataURL) else {
                continue
            }

            let modelText = firstVersionValue(
                in: raw,
                keys: ["model", "model name", "camera model", "device model", "product", "product name"]
            ) ?? raw
            guard KnownDashcamCatalog.exactModelMention(modelText, manufacturer: manufacturer) != nil else {
                continue
            }

            return SafeModelMetadataInfo(
                manufacturer: manufacturer,
                modelText: modelText,
                firmwareVersion: firstVersionValue(in: raw, keys: ["version", "firmware version", "fw version", "ver"]),
                sourcePath: relativePath,
                valueLabel: "model",
                stage: "safe_model_metadata"
            )
        }

        return nil
    }

    private func safeBlackVueModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
        let candidates = [
            "BlackVue/Config/version.bin",
            "BlackVue/Config/micom_version.bin",
            "BlackVue/Config/smart_gsensor_version.bin"
        ]

        for relativePath in candidates {
            let metadataURL = sourceURL.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: metadataURL.path),
                  let raw = evidenceText(at: metadataURL) else {
                continue
            }

            let parsedModelText = blackVueModelText(in: raw)
            let matchedModel = parsedModelText.flatMap {
                KnownDashcamCatalog.exactModelMention($0, manufacturer: "BlackVue")
            } ?? KnownDashcamCatalog.exactModelMention(raw, manufacturer: "BlackVue")
            guard let modelText = parsedModelText ?? matchedModel?.model else {
                continue
            }

            return SafeModelMetadataInfo(
                manufacturer: "BlackVue",
                modelText: modelText,
                firmwareVersion: blackVueFirmwareVersion(in: raw),
                sourcePath: relativePath,
                valueLabel: "model",
                stage: "blackvue_config_metadata"
            )
        }

        return nil
    }

    private func blackVueModelText(in raw: String) -> String? {
        firstVersionValue(in: raw, keys: ["model", "model name", "product", "product name"])
    }

    private func blackVueFirmwareVersion(in raw: String) -> String? {
        firstVersionValue(in: raw, keys: ["version", "firmware version", "ver"])
    }

    private func safeGoProModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
        let relativePath = "MISC/version.txt"
        let versionURL = sourceURL.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: versionURL.path),
              let raw = evidenceText(at: versionURL) else { return nil }
        guard let cameraType = firstVersionValue(
            in: raw,
            keys: ["camera type", "camera_type", "cameraType"]
        ) else {
            return nil
        }
        let firmwareVersion = firstVersionValue(
            in: raw,
            keys: ["firmware version", "firmware_version", "firmwareVersion"]
        )
        return SafeModelMetadataInfo(
            manufacturer: "GoPro",
            modelText: cameraType,
            firmwareVersion: firmwareVersion,
            sourcePath: relativePath,
            valueLabel: "camera type",
            stage: "gopro_version_txt"
        )
    }

    private func safeThinkwareModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
        let versionPath = "SETTING/lang/ver.dat"
        let versionURL = sourceURL.appendingPathComponent(versionPath)
        if fileManager.fileExists(atPath: versionURL.path),
           let raw = evidenceText(at: versionURL),
           let deviceName = firstVersionValue(in: raw, keys: ["Device Name", "DeviceName", "model", "model name"]) {
            return SafeModelMetadataInfo(
                manufacturer: "Thinkware",
                modelText: deviceName,
                firmwareVersion: firstVersionValue(in: raw, keys: ["version", "firmware version", "ver"]),
                sourcePath: versionPath,
                valueLabel: "device name",
                stage: "safe_model_metadata"
            )
        }

        let settingFolderURL = sourceURL.appendingPathComponent("SETTING", isDirectory: true)
        guard let settingFiles = try? fileManager.contentsOfDirectory(
            at: settingFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for fileURL in settingFiles {
            let filename = fileURL.lastPathComponent
            guard filename.localizedCaseInsensitiveContains("_Setting.exe"),
                  let matchedModel = KnownDashcamCatalog.exactModelMention(filename, manufacturer: "Thinkware") else {
                continue
            }
            return SafeModelMetadataInfo(
                manufacturer: "Thinkware",
                modelText: matchedModel.model,
                firmwareVersion: nil,
                sourcePath: "SETTING/\(filename)",
                valueLabel: "model-coded support filename",
                stage: "safe_model_metadata"
            )
        }
        return nil
    }

    private func safeVantrueModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
        let gpsFolderURL = sourceURL.appendingPathComponent("GPS", isDirectory: true)
        guard let gpsFiles = try? fileManager.contentsOfDirectory(
            at: gpsFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for fileURL in gpsFiles {
            let filename = fileURL.lastPathComponent
            guard filename.localizedCaseInsensitiveContains("_Settings.ini"),
                  let matchedModel = KnownDashcamCatalog.exactModelMention(filename, manufacturer: "Vantrue") else {
                continue
            }
            return SafeModelMetadataInfo(
                manufacturer: "Vantrue",
                modelText: matchedModel.model,
                firmwareVersion: nil,
                sourcePath: "GPS/\(filename)",
                valueLabel: "model-coded settings filename",
                stage: "safe_model_metadata"
            )
        }
        return nil
    }

    private func safeVueroidModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
        let candidates = [
            "CONFIG/config.bin",
            "CONFIG/.boot.log",
            ".boot.log"
        ]

        for relativePath in candidates {
            let metadataURL = sourceURL.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: metadataURL.path),
                  let raw = evidenceText(at: metadataURL),
                  let modelText = vueroidModelText(in: raw) else {
                continue
            }

            return SafeModelMetadataInfo(
                manufacturer: "Vueroid",
                modelText: modelText,
                firmwareVersion: firstVersionValue(in: raw, keys: ["version", "firmware version", "fw version", "ver"]),
                sourcePath: relativePath,
                valueLabel: "model",
                stage: "safe_model_metadata"
            )
        }

        return nil
    }

    private func vueroidModelText(in raw: String) -> String? {
        let normalized = raw.uppercased()
        if normalized.contains("H1-QHD-INFINITE") {
            return "H1"
        }
        if normalized.contains("S1-4K") ||
            normalized.contains("S1 4K") {
            return "S1 4K Infinite"
        }
        if normalized.contains("S1-QHD") ||
            normalized.contains("S1 QHD") {
            return "S1 QHD Infinite"
        }
        return nil
    }

    private func safeSonyModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
        let mediaProfilePath = "PRIVATE/M4ROOT/MEDIAPRO.XML"
        let mediaProfileURL = sourceURL.appendingPathComponent(mediaProfilePath)
        if fileManager.fileExists(atPath: mediaProfileURL.path),
           let raw = evidenceText(at: mediaProfileURL),
           let systemKind = xmlAttributeValue(in: raw, name: "systemKind") {
            return SafeModelMetadataInfo(
                manufacturer: "Sony",
                modelText: systemKind,
                firmwareVersion: nil,
                sourcePath: mediaProfilePath,
                valueLabel: "systemKind",
                stage: "safe_model_metadata"
            )
        }

        let clipFolderURL = sourceURL.appendingPathComponent("PRIVATE/M4ROOT/CLIP", isDirectory: true)
        guard let clipXMLs = try? fileManager.contentsOfDirectory(
            at: clipFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension.caseInsensitiveCompare("xml") == .orderedSame }) else {
            return nil
        }

        for fileURL in clipXMLs.prefix(5) {
            guard let raw = evidenceText(at: fileURL),
                  let modelName = xmlAttributeValue(in: raw, name: "modelName") else {
                continue
            }
            return SafeModelMetadataInfo(
                manufacturer: "Sony",
                modelText: modelName,
                firmwareVersion: nil,
                sourcePath: "PRIVATE/M4ROOT/CLIP/\(fileURL.lastPathComponent)",
                valueLabel: "modelName",
                stage: "safe_model_metadata"
            )
        }
        return nil
    }

    private func firstVersionValue(in raw: String, keys: [String]) -> String? {
        for key in keys {
            let normalizedKey = key.lowercased().filter { !$0.isWhitespace }
            for line in raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
                let text = String(line)
                let separators: [Character] = [":", "="]
                guard let separatorIndex = text.firstIndex(where: { separators.contains($0) }) else {
                    continue
                }
                let lineKey = String(text[..<separatorIndex])
                    .lowercased()
                    .filter { !$0.isWhitespace }
                guard lineKey == normalizedKey else { continue }
                let valueStart = text.index(after: separatorIndex)
                let value = String(text[valueStart...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\" ,}\r\n\t"))
                if !value.isEmpty {
                    return value
                }
            }

            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            let patterns = [
                #""\#(escapedKey)"\s*:\s*"([^"]+)""#,
                #"\#(escapedKey)"\s*[:=]\s*"?([^",\r\n}]+)"?"#
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                ) else { continue }
                let nsRaw = raw as NSString
                let range = NSRange(location: 0, length: nsRaw.length)
                guard let match = regex.firstMatch(in: raw, range: range),
                      match.numberOfRanges > 1 else {
                    continue
                }
                let value = nsRaw.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\" ,}\r\n\t"))
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    private func xmlAttributeValue(in raw: String, name: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\#(escapedName)\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRaw = raw as NSString
        let range = NSRange(location: 0, length: nsRaw.length)
        guard let match = regex.firstMatch(in: raw, range: range),
              match.numberOfRanges > 1 else {
            return nil
        }
        let value = nsRaw.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func classify(files: [URL], sourceURL: URL, profile: DashcamProfile) -> [ClipItem] {
        let folders = profile.folders.sorted { $0.path.count > $1.path.count }
        let compiledPatterns = profile.filenamePatterns.compactMap { pattern -> (FilenamePattern, NSRegularExpression)? in
            guard let regex = try? NSRegularExpression(pattern: pattern.regexPattern) else { return nil }
            return (pattern, regex)
        }

        let classified: [ClipItem] = files.compactMap { fileURL in
            let relativePath = fileURL.relativePath(from: sourceURL)
            let filename = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            guard isCandidateExtension(ext) else { return nil }

            var mode = "recording"
            var channel = profile.channels.count == 1 ? (profile.channels.values.first ?? "front") : "unknown"
            var timestamp: Date?
            var excludedReason: String?

            if shouldExclude(relativePath: relativePath, extensionLowercased: ext) {
                excludedReason = "Excluded by safety rules"
            }

            if let folder = folders.first(where: { profileFolder($0.path, contains: relativePath) }) {
                mode = folder.mode
                if !folder.importable {
                    excludedReason = "Profile marks this folder as non-importable"
                }
            }

            for (pattern, regex) in compiledPatterns {
                var matchedName: String?
                var matchedResult: NSTextCheckingResult?
                for candidateName in filenameCandidates(for: filename) {
                    let nsCandidate = candidateName as NSString
                    let range = NSRange(location: 0, length: nsCandidate.length)
                    if let match = regex.firstMatch(in: candidateName, range: range), match.range.location != NSNotFound {
                        matchedName = candidateName
                        matchedResult = match
                        break
                    }
                }

                guard let matchedName, let match = matchedResult else { continue }
                let nsFilename = matchedName as NSString

                let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
                    let matchRange = match.range(at: index)
                    guard matchRange.location != NSNotFound else { return nil }
                    return nsFilename.substring(with: matchRange)
                }

                if let mappedMode = firstMappedValue(in: groups, map: pattern.modeMap) {
                    mode = mappedMode
                }
                if let mappedChannel = firstMappedValue(in: groups.sorted { $0.count > $1.count }, map: mergedChannelMap(profile: profile, pattern: pattern)) {
                    channel = physicalChannelLabel(from: mappedChannel)
                }
                if channel == "unknown", profile.channels.count == 1, let onlyChannel = profile.channels.values.first {
                    channel = physicalChannelLabel(from: onlyChannel)
                }
                timestamp = parseTimestamp(groups: groups, format: pattern.timestampFormat)
                break
            }

            if channel == "unknown" {
                channel = genericChannel(relativePath: relativePath, filename: filename)
            }

            if ext == "dat" || relativePath.hasPrefix("GPS/") {
                mode = "gps"
                channel = "gps"
                if ext != "dat" {
                    excludedReason = "GPS/settings sidecar excluded by default"
                }
            } else if ClipItem.photoExtensions.contains(ext) {
                mode = photoMode(extensionLowercased: ext)
            }

            let timestampResult = bestTimestamp(filenameTimestamp: timestamp, fileURL: fileURL)
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

            return ClipItem(
                sourceURL: fileURL,
                relativePath: relativePath,
                filename: filename,
                mode: mode,
                channel: channel,
                timestamp: timestampResult.date,
                timestampSource: timestampResult.source,
                size: size,
                extensionLowercased: ext,
                excludedReason: excludedReason,
                inferredParkingPattern: nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }

        guard profile.manufacturer.caseInsensitiveCompare("GoPro") == .orderedSame else {
            return classified
        }
        return classifyGoProRecordingTypes(in: classified)
    }

    func classifyWithParkingPatterns(files: [URL], sourceURL: URL, profile: DashcamProfile) -> (clips: [ClipItem], diagnostics: [ScanDiagnosticEntry]) {
        inferParkingPatterns(in: classify(files: files, sourceURL: sourceURL, profile: profile))
    }

    func classifyGenerically(files: [URL], sourceURL: URL) -> [ClipItem] {
        let classified: [ClipItem] = files.compactMap { fileURL in
            let relativePath = fileURL.relativePath(from: sourceURL)
            let filename = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            guard isCandidateExtension(ext) else { return nil }

            var mode = genericMode(relativePath: relativePath, filename: filename, extensionLowercased: ext)
            var channel = genericChannel(relativePath: relativePath, filename: filename)
            var excludedReason: String?

            if shouldExclude(relativePath: relativePath, extensionLowercased: ext) {
                excludedReason = "Excluded by safety rules"
            }

            if ext == "dat" || relativePath.localizedCaseInsensitiveContains("/gps/") || relativePath.lowercased().hasPrefix("gps/") {
                mode = "gps"
                channel = "gps"
                if ext != "dat" {
                    excludedReason = "GPS/settings sidecar excluded by default"
                }
            } else if ClipItem.photoExtensions.contains(ext) {
                mode = photoMode(extensionLowercased: ext)
            }

            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            let timestampResult = bestTimestamp(filenameTimestamp: parseGenericTimestamp(filename: filename), fileURL: fileURL)
            return ClipItem(
                sourceURL: fileURL,
                relativePath: relativePath,
                filename: filename,
                mode: mode,
                channel: channel,
                timestamp: timestampResult.date,
                timestampSource: timestampResult.source,
                size: size,
                extensionLowercased: ext,
                excludedReason: excludedReason,
                inferredParkingPattern: nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }

        guard classified.contains(where: { clip in
            clip.isVideo && parseGoProVideoFilename(clip.filename) != nil
        }) else {
            return classified
        }
        return classifyGoProRecordingTypes(in: classified)
    }

    private func inferParkingPatterns(in clips: [ClipItem]) -> (clips: [ClipItem], diagnostics: [ScanDiagnosticEntry]) {
        let wolfboxContext = inferWolfboxContextualParkingPatterns(in: clips)
        var inferredByRelativePath = wolfboxContext.inferredByRelativePath
        var diagnostics = wolfboxContext.diagnostics

        for clip in clips {
            if inferredByRelativePath[clip.relativePath] != nil {
                continue
            }
            if let explicitPattern = explicitParkingPattern(for: clip) {
                inferredByRelativePath[clip.relativePath] = explicitPattern
            }
        }

        let parkingClips = clips.filter { clip in
            clip.excludedReason == nil &&
                clip.isVideo &&
                Self.isParkingOutputCategory(clip.outputCategory) &&
                clip.timestamp != nil &&
                !clip.hasSuspiciousTimestamp &&
                inferredByRelativePath[clip.relativePath] == nil
        }

        let groupedByFolder = Dictionary(grouping: parkingClips) { clip in
            relativeFolderPath(for: clip.relativePath)
        }

        for (folder, folderClips) in groupedByFolder {
            let moments = groupedRecordingMoments(folderClips)
            let defaultPattern = defaultParkingPattern(for: folderClips)
            guard moments.count >= 4 else {
                if let defaultPattern {
                    for clip in folderClips {
                        inferredByRelativePath[clip.relativePath] = defaultPattern
                    }
                    diagnostics.append(ScanDiagnosticEntry(
                        stage: "parking_pattern_inference",
                        profileID: nil,
                        profileName: nil,
                        outcome: "classified_default",
                        detail: "\(folder.isEmpty ? "." : folder): \(moments.count) recording moments, default=\(defaultPattern.rawValue)"
                    ))
                }
                continue
            }

            let momentPatterns = inferParkingPatternsByMoment(moments, defaultPattern: defaultPattern ?? .motionDetection)
            let patternCounts = Dictionary(grouping: momentPatterns.values, by: { $0 })
                .mapValues(\.count)

            for clip in folderClips {
                guard let timestamp = clip.timestamp else { continue }
                let key = recordingMomentKey(for: timestamp)
                if let pattern = momentPatterns[key] {
                    inferredByRelativePath[clip.relativePath] = pattern
                }
            }

            diagnostics.append(ScanDiagnosticEntry(
                stage: "parking_pattern_inference",
                profileID: nil,
                profileName: nil,
                outcome: "classified",
                detail: "\(folder.isEmpty ? "." : folder): \(moments.count) recording moments, \(patternCounts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: ", "))"
            ))
        }

        guard !inferredByRelativePath.isEmpty else {
            return (clips, diagnostics)
        }

        let annotated = clips.map { clip in
            guard let inferred = inferredByRelativePath[clip.relativePath] else { return clip }
            var copy = clip
            copy.inferredParkingPattern = inferred
            copy.mode = inferred.modeValue
            return copy
        }
        return (annotated, diagnostics)
    }

    private func inferWolfboxContextualParkingPatterns(in clips: [ClipItem]) -> (
        inferredByRelativePath: [String: ParkingPattern],
        diagnostics: [ScanDiagnosticEntry]
    ) {
        let videos = clips.filter { clip in
            clip.excludedReason == nil &&
                clip.isVideo &&
                clip.timestamp != nil &&
                !clip.hasSuspiciousTimestamp
        }
        let folders = Set(videos.map { relativeFolderPath(for: $0.relativePath).lowercased() })
        guard folders.contains("front_norm"),
              folders.contains("rear_norm"),
              folders.contains("front_emer"),
              folders.contains("rear_emer") else {
            return ([:], [])
        }

        let normalClips = videos.filter {
            $0.relativePath.lowercased().hasPrefix("front_norm/") ||
                $0.relativePath.lowercased().hasPrefix("rear_norm/")
        }
        let normalMoments = wolfboxGroupedRecordingMoments(normalClips)
        let timelapseMoments = wolfboxTimelapseMoments(in: normalMoments)
        guard !timelapseMoments.isEmpty,
              let firstTimelapseTimestamp = timelapseMoments.map(\.timestamp).min() else {
            return ([:], [])
        }

        var inferredByRelativePath: [String: ParkingPattern] = [:]
        for moment in timelapseMoments {
            for relativePath in moment.relativePaths {
                inferredByRelativePath[relativePath] = .timelapse
            }
        }

        let emergencyClips = videos.filter {
            $0.relativePath.lowercased().hasPrefix("front_emer/") ||
                $0.relativePath.lowercased().hasPrefix("rear_emer/")
        }
        let emergencyMoments = wolfboxGroupedRecordingMoments(emergencyClips)
        let parkingContextLeadTime: TimeInterval = 4 * 60
        let parkingContextStart = firstTimelapseTimestamp.addingTimeInterval(-parkingContextLeadTime)
        let parkingEmergencyPaths = Set(emergencyMoments.filter { moment in
            moment.timestamp >= parkingContextStart
        }.flatMap(\.relativePaths))

        for relativePath in parkingEmergencyPaths {
            inferredByRelativePath[relativePath] = .impactDetection
        }

        guard !inferredByRelativePath.isEmpty else {
            return ([:], [])
        }

        let parkingEmergencyCount = emergencyClips.filter { parkingEmergencyPaths.contains($0.relativePath) }.count
        let drivingEmergencyCount = emergencyClips.count - parkingEmergencyCount
        return (
            inferredByRelativePath,
            [
                ScanDiagnosticEntry(
                    stage: "wolfbox_context_inference",
                    profileID: nil,
                    profileName: nil,
                    outcome: "classified",
                    detail: "front/rear normal + emergency layout: timelapse_moments=\(timelapseMoments.count), parking_emergency_clips=\(parkingEmergencyCount), driving_emergency_clips=\(drivingEmergencyCount)"
                )
            ]
        )
    }

    private struct ContextRecordingMoment {
        var timestamp: Date
        var totalBytes: Int64
        var relativePaths: [String]
    }

    private func wolfboxGroupedRecordingMoments(_ clips: [ClipItem]) -> [ContextRecordingMoment] {
        let sortedClips = clips
            .compactMap { clip -> (clip: ClipItem, timestamp: Date)? in
                guard let timestamp = clip.timestamp else { return nil }
                return (clip, timestamp)
            }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.clip.relativePath.localizedStandardCompare(rhs.clip.relativePath) == .orderedAscending
            }

        var moments: [ContextRecordingMoment] = []
        for item in sortedClips {
            if var current = moments.last,
               item.timestamp.timeIntervalSince(current.timestamp) <= 3 {
                current.totalBytes += item.clip.size
                current.relativePaths.append(item.clip.relativePath)
                current.timestamp = min(current.timestamp, item.timestamp)
                moments[moments.count - 1] = current
            } else {
                moments.append(ContextRecordingMoment(
                    timestamp: item.timestamp,
                    totalBytes: item.clip.size,
                    relativePaths: [item.clip.relativePath]
                ))
            }
        }

        return moments
    }

    private func wolfboxTimelapseMoments(in moments: [ContextRecordingMoment]) -> [ContextRecordingMoment] {
        guard moments.count >= 3 else { return [] }

        var bestRun: [ContextRecordingMoment] = []
        var currentRun: [ContextRecordingMoment] = []
        for moment in moments {
            guard let previous = currentRun.last else {
                currentRun = [moment]
                continue
            }

            let interval = moment.timestamp.timeIntervalSince(previous.timestamp)
            if interval >= 300, interval <= 7_200 {
                currentRun.append(moment)
            } else {
                if currentRun.count > bestRun.count {
                    bestRun = currentRun
                }
                currentRun = [moment]
            }
        }
        if currentRun.count > bestRun.count {
            bestRun = currentRun
        }

        guard bestRun.count >= 3 else { return [] }
        let intervals = zip(bestRun, bestRun.dropFirst()).map { lhs, rhs in
            rhs.timestamp.timeIntervalSince(lhs.timestamp)
        }
        guard let medianInterval = median(intervals) else { return [] }
        let consistentIntervalCount = intervals.filter { interval in
            abs(interval - medianInterval) <= max(60, medianInterval * 0.20)
        }.count
        let consistency = intervals.isEmpty ? 0 : Double(consistentIntervalCount) / Double(intervals.count)
        guard medianInterval >= 300, medianInterval <= 7_200, consistency >= 0.65 else {
            return []
        }

        return bestRun
    }

    private func explicitParkingPattern(for clip: ClipItem) -> ParkingPattern? {
        guard clip.excludedReason == nil, clip.isVideo else { return nil }

        switch clip.mode {
        case "parking_timelapse":
            return .timelapse
        case "parking_motion_detection":
            return .motionDetection
        case "parking_impact_detection":
            return .impactDetection
        case "parking_motion_or_impact":
            return .motionOrImpact
        case "parking_continuous_low_bitrate":
            return .continuousLowBitrate
        default:
            break
        }

        let lowerPath = clip.relativePath.lowercased()
        let isProtectedFolder = lowerPath.contains("/ro/") ||
            lowerPath.hasPrefix("ro/") ||
            lowerPath.contains("/event/") ||
            lowerPath.hasPrefix("event/") ||
            lowerPath.contains("/pevent/") ||
            lowerPath.hasPrefix("pevent/")

        if lowerPath.contains("/pevent/") || lowerPath.hasPrefix("pevent/") {
            return .impactDetection
        }

        let tokens = genericTokens(from: clip.relativePath)
        if tokens.contains("motion") || tokens.contains("mot") {
            return .motionDetection
        }

        if isProtectedFolder && hasParkingChannelSuffix(clip.filename) {
            return .impactDetection
        }

        return nil
    }

    private static func isParkingOutputCategory(_ category: String) -> Bool {
        category == "Parking" || category == "Parking Events"
    }

    private func defaultParkingPattern(for clips: [ClipItem]) -> ParkingPattern? {
        let tokens = clips.flatMap { genericTokens(from: $0.relativePath) }
        if tokens.contains("motion") || tokens.contains("mot") {
            return .motionDetection
        }
        if tokens.contains("impact") || tokens.contains("event") || tokens.contains("evt") {
            return .impactDetection
        }
        if clips.contains(where: { $0.outputCategory == "Parking Events" }) {
            return .motionOrImpact
        }
        if clips.contains(where: { clip in
            clip.relativePath.lowercased().contains("cardv/movie/park")
        }) {
            return .motionOrImpact
        }
        return nil
    }

    private func hasParkingChannelSuffix(_ filename: String) -> Bool {
        let stem = URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return ["PF", "PI", "PR", "PT"].contains { stem.hasSuffix($0) }
    }

    private func hasParkingFilenamePrefix(_ filename: String) -> Bool {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        return stem.range(of: #"^P20\d{6}[_-]?\d{6}"#, options: .regularExpression) != nil
    }

    private func inferParkingPatternsByMoment(
        _ moments: [(key: Int, timestamp: Date, totalBytes: Int64)],
        defaultPattern: ParkingPattern
    ) -> [Int: ParkingPattern] {
        var inferred: [Int: ParkingPattern] = [:]

        var runStart = 0
        while runStart < moments.count {
            var runEnd = runStart
            while runEnd + 1 < moments.count {
                let gap = moments[runEnd + 1].timestamp.timeIntervalSince(moments[runEnd].timestamp)
                guard gap > 0, gap <= 210 else { break }
                runEnd += 1
            }

            if runEnd - runStart + 1 >= 4 {
                let runMoments = Array(moments[runStart...runEnd])
                let medianMomentSize = median(runMoments.map(\.totalBytes).map(Double.init)) ?? 0
                let pattern: ParkingPattern = medianMomentSize <= 300_000_000 ? .continuousLowBitrate : .timelapse
                for index in runStart...runEnd {
                    inferred[moments[index].key] = pattern
                }
            }

            runStart = max(runEnd + 1, runStart + 1)
        }

        let remainingMoments = moments.filter { inferred[$0.key] == nil }
        if remainingMoments.count >= 4,
           let timelapsePattern = regularTimelapsePattern(for: remainingMoments) {
            for moment in remainingMoments {
                inferred[moment.key] = timelapsePattern
            }
        }

        for moment in moments where inferred[moment.key] == nil {
            inferred[moment.key] = defaultPattern
        }

        return inferred
    }

    private func regularTimelapsePattern(for moments: [(key: Int, timestamp: Date, totalBytes: Int64)]) -> ParkingPattern? {
        let intervals = zip(moments, moments.dropFirst()).map { lhs, rhs in
            rhs.timestamp.timeIntervalSince(lhs.timestamp)
        }
        guard let medianInterval = median(intervals), medianInterval > 0 else { return nil }

        let consistentIntervalCount = intervals.filter { interval in
            abs(interval - medianInterval) <= max(30, medianInterval * 0.25)
        }.count
        let consistency = intervals.isEmpty ? 0 : Double(consistentIntervalCount) / Double(intervals.count)
        let medianMomentSize = median(moments.map(\.totalBytes).map(Double.init)) ?? 0

        if medianInterval >= 300, medianInterval <= 7_200, consistency >= 0.55, medianMomentSize <= 300_000_000 {
            return .timelapse
        }
        return nil
    }

    private func groupedRecordingMoments(_ clips: [ClipItem]) -> [(key: Int, timestamp: Date, totalBytes: Int64)] {
        let grouped = Dictionary(grouping: clips) { clip -> Int in
            guard let timestamp = clip.timestamp else { return 0 }
            return recordingMomentKey(for: timestamp)
        }
        return grouped.compactMap { key, clips -> (key: Int, timestamp: Date, totalBytes: Int64)? in
            guard let timestamp = clips.compactMap(\.timestamp).min() else { return nil }
            return (key, timestamp, clips.reduce(Int64(0)) { $0 + $1.size })
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    private func relativeFolderPath(for relativePath: String) -> String {
        guard let slashIndex = relativePath.lastIndex(of: "/") else {
            return "."
        }
        return String(relativePath[..<slashIndex])
    }

    private func recordingMomentKey(for timestamp: Date) -> Int {
        Int((timestamp.timeIntervalSince1970 / 2).rounded())
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func enumerateFiles(sourceURL: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.relativePath(from: sourceURL)
            if shouldSkipTraversal(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                files.append(fileURL)
            }
        }
        return files
    }

    private func isSystemVolume(_ url: URL) -> Bool {
        let name = normalizedName(url.lastPathComponent)
        return name == "macintosh hd" ||
            name == "system" ||
            name == "data" ||
            name.hasPrefix("com.apple.")
    }

    private func mountedVolumeRoot(containing url: URL) -> URL? {
        let components = url.standardizedFileURL.pathComponents
        guard components.count >= 3, components[1] == "Volumes" else {
            return nil
        }

        return URL(fileURLWithPath: "/Volumes/\(components[2])", isDirectory: true)
    }

    private func isObviousNonDashcamVolume(_ url: URL) -> Bool {
        let name = normalizedName(url.lastPathComponent)
        let blockedNameFragments = [
            "time machine",
            "timemachine",
            "backup",
            "backups",
            "carbon copy",
            "superduper",
            "clone",
            "start9",
            "bitcoin"
        ]
        if blockedNameFragments.contains(where: { name.contains($0) }) {
            return true
        }

        let blockedRootItems = [
            "Backups.backupdb",
            ".HFS+ Private Directory Data",
            ".com.apple.timemachine.donotpresent"
        ]
        return blockedRootItems.contains { item in
            fileManager.fileExists(atPath: url.appendingPathComponent(item).path)
        }
    }

    private func isNetworkMountedVolume(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey])
        return values?.volumeIsLocal == false
    }

    private func hasDashcamLikeEvidence(_ url: URL) -> Bool {
        let rootIndicators: Set<String> = [
            "blackvue",
            "bookmark",
            "config",
            "cont_rec",
            "dcim",
            "event",
            "evt_rec",
            "gps",
            "incabin_rec",
            "inf",
            "manual_rec",
            "motion_timelapse_rec",
            "movie",
            "normal",
            "parking",
            "parking_rec",
            "park",
            "pevent",
            "photo",
            "record",
            "rec",
            "setting",
            "settings",
            "sos_rec",
            "360cardvr",
            "misc",
            "private",
            "video",
            "user"
        ]

        if let rootItems = try? fileManager.contentsOfDirectory(atPath: url.path) {
            for item in rootItems {
                let normalized = normalizedName(item)
                if rootIndicators.contains(normalized) {
                    return true
                }
            }
        }

        return hasShallowMediaFile(in: url, depth: 0, maxDepth: 5, remainingBudget: 2_000)
    }

    private func hasShallowMediaFile(in url: URL, depth: Int, maxDepth: Int, remainingBudget: Int) -> Bool {
        guard depth <= maxDepth, remainingBudget > 0 else { return false }
        guard let items = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var budget = remainingBudget
        for item in items {
            guard budget > 0 else { return false }
            budget -= 1

            let relativeName = item.lastPathComponent
            if shouldSkipTraversal(relativePath: relativeName) { continue }

            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isRegularFile == true, isCandidateExtension(item.pathExtension.lowercased()) {
                return true
            }
            if values?.isDirectory == true, hasShallowMediaFile(in: item, depth: depth + 1, maxDepth: maxDepth, remainingBudget: budget) {
                return true
            }
        }
        return false
    }

    private func normalizedName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func detectProfiles(sourceURL: URL, allFiles: [URL], profiles: [DashcamProfile]) -> [DetectionCandidate] {
        profiles.compactMap { profile in
            var score = 0
            var evidence: [String] = []

            if profile.disqualifyingRules.contains(where: { disqualifyingRuleMatches($0, sourceURL: sourceURL) }) {
                return nil
            }

            for rule in profile.detectionRules {
                if detectionRuleMatches(rule, sourceURL: sourceURL) {
                    score += rule.score
                    if let path = rule.path, let contains = rule.contains {
                        evidence.append("model text \(contains) in \(path)")
                    } else if let path = rule.path {
                        evidence.append("model evidence \(path)")
                    } else if let volumeLabel = rule.volumeLabel {
                        evidence.append("volume label \(volumeLabel)")
                    }
                }
            }

            for folder in profile.folders {
                if profileFolderExists(folder.path, sourceURL: sourceURL, allFiles: allFiles) {
                    score += folder.importable ? 8 : 3
                    evidence.append("folder \(folder.path)")
                }
            }

            if volumeLabel(sourceURL.lastPathComponent, matchesProfile: profile) {
                score += 3
                evidence.append("volume label \(sourceURL.lastPathComponent)")
            }

            let sampleNames = representativeDetectionFilenames(from: allFiles)
            var totalFilenameMatches = 0
            var matchedChannelTokens = Set<String>()
            let observedChannelTokens = observedTrailingChannelTokens(from: sampleNames)
            for pattern in profile.filenamePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern.regexPattern) else { continue }
                let channelMap = mergedChannelMap(profile: profile, pattern: pattern)
                let matchCount = sampleNames.reduce(0) { count, name in
                    let matched = filenameCandidates(for: name).contains { candidateName in
                        let nsCandidate = candidateName as NSString
                        let range = NSRange(location: 0, length: nsCandidate.length)
                        guard let match = regex.firstMatch(in: candidateName, range: range) else { return false }
                        for index in 1..<match.numberOfRanges {
                            let matchRange = match.range(at: index)
                            guard matchRange.location != NSNotFound else { continue }
                            let group = nsCandidate.substring(with: matchRange)
                            if channelMap[group] != nil {
                                matchedChannelTokens.insert(group)
                            }
                        }
                        return true
                    }
                    return count + (matched ? 1 : 0)
                }
                totalFilenameMatches += matchCount
            }
            if totalFilenameMatches > 0 {
                score += min(90, 15 + totalFilenameMatches)
                evidence.append("filename pattern match (\(totalFilenameMatches))")
                if !matchedChannelTokens.isEmpty {
                    evidence.append("filename channel tokens \(matchedChannelTokens.sorted().joined(separator: ","))")
                }
                let profileChannelTokens = Set(profile.channels.keys.map { $0.uppercased() })
                let unsupportedChannelTokens = observedChannelTokens.subtracting(profileChannelTokens)
                if !profileChannelTokens.isEmpty, !unsupportedChannelTokens.isEmpty {
                    evidence.append("filename channel tokens outside profile \(unsupportedChannelTokens.sorted().joined(separator: ","))")
                }
                if let profileMaxChannels = effectiveMaxChannels(for: profile),
                   observedChannelTokens.count > profileMaxChannels {
                    evidence.append("observed channel count \(observedChannelTokens.count) exceeds profile max \(profileMaxChannels)")
                }
            }

            let mediaEvidence = mediaFingerprintEvidence(profile: profile, allFiles: allFiles)
            score += mediaEvidence.score
            evidence.append(contentsOf: mediaEvidence.evidence)

            guard score > 0 else { return nil }
            let confidence = confidenceLevel(for: score)

            return DetectionCandidate(profile: profile, score: score, confidence: confidence, evidence: Array(evidence.prefix(12)))
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.profile.displayName < rhs.profile.displayName
        }
    }

    private func representativeDetectionFilenames(from allFiles: [URL]) -> [String] {
        let candidateFiles = allFiles.filter { isCandidateExtension($0.pathExtension.lowercased()) }
        guard candidateFiles.count > 2_000 else {
            return candidateFiles.map(\.lastPathComponent)
        }

        var result: [String] = []
        var seen = Set<String>()
        let groupedByFolder = Dictionary(grouping: candidateFiles) { fileURL in
            fileURL.deletingLastPathComponent().path
        }
        for folder in groupedByFolder.keys.sorted() {
            for fileURL in groupedByFolder[folder, default: []].prefix(250) {
                let name = fileURL.lastPathComponent
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }

        return Array(result.prefix(5_000))
    }

    private func observedTrailingChannelTokens(from filenames: [String]) -> Set<String> {
        Set(filenames.compactMap { filename in
            let stem = URL(fileURLWithPath: filename)
                .deletingPathExtension()
                .lastPathComponent
                .uppercased()
            guard let last = stem.last,
                  last >= "A", last <= "Z",
                  let previous = stem.dropLast().last,
                  previous.isNumber else {
                return nil
            }
            return String(last)
        })
    }

    private func observedChannelRoles(from allFiles: [URL], sourceURL: URL) -> Set<String> {
        let roles = allFiles.compactMap { fileURL -> String? in
            guard isCandidateExtension(fileURL.pathExtension.lowercased()) else { return nil }
            let relativePath = fileURL.relativePath(from: sourceURL)
            let role = genericChannel(relativePath: relativePath, filename: fileURL.lastPathComponent)
            switch role {
            case "front", "rear", "interior", "bumper", "left", "right",
                "left_repeater", "right_repeater", "left_pillar", "right_pillar",
                "channel_a", "channel_b", "channel_c", "channel_d":
                return role
            default:
                return nil
            }
        }
        return Set(roles)
    }

    private func effectiveMaxChannels(for profile: DashcamProfile) -> Int? {
        let mappedChannelCount = profile.channels.isEmpty ? nil : profile.channels.count
        switch (profile.maxChannels, mappedChannelCount) {
        case let (.some(maxChannels), .some(mapped)):
            return max(maxChannels, mapped)
        case let (.some(maxChannels), .none):
            return maxChannels
        case let (.none, .some(mapped)):
            return mapped
        case (.none, .none):
            return nil
        }
    }

    private func mediaFingerprintEvidence(profile: DashcamProfile, allFiles: [URL]) -> (score: Int, evidence: [String]) {
        guard profile.id == "vantrue-n4-pro-s" else { return (0, []) }

        let sampleDimensions = vantrueABCVideoDimensions(from: allFiles)
        guard let a = sampleDimensions["A"], let b = sampleDimensions["B"], let c = sampleDimensions["C"] else {
            return (0, [])
        }

        let hasN4ProSShape =
            a.width >= 3800 && a.height >= 2100 &&
            b.width >= 1900 && b.width <= 1940 && b.height >= 1060 && b.height <= 1100 &&
            c.width >= 2500 && c.width <= 2600 && c.height >= 1400 && c.height <= 1480

        guard hasN4ProSShape else { return (0, []) }

        return (
            100,
            ["media fingerprint A=\(a.width)x\(a.height), B=\(b.width)x\(b.height), C=\(c.width)x\(c.height)"]
        )
    }

    private func profileFolderExists(_ folderPath: String, sourceURL: URL, allFiles: [URL]) -> Bool {
        if folderPath.contains("*") {
            return allFiles.contains { fileURL in
                profileFolder(folderPath, contains: fileURL.relativePath(from: sourceURL))
            }
        }

        let folderURL = sourceURL.appendingPathComponent(folderPath)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func profileFolder(_ folderPath: String, contains relativePath: String) -> Bool {
        let normalizedFolder = folderPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedFolder.isEmpty else { return false }

        if !normalizedFolder.contains("*") {
            return normalizedPath == normalizedFolder || normalizedPath.hasPrefix(normalizedFolder + "/")
        }

        let folderComponents = normalizedFolder.split(separator: "/").map(String.init)
        let pathComponents = normalizedPath.split(separator: "/").map(String.init)
        guard pathComponents.count >= folderComponents.count else { return false }

        for index in folderComponents.indices where !wildcardComponent(folderComponents[index], matches: pathComponents[index]) {
            return false
        }
        return true
    }

    private func wildcardComponent(_ pattern: String, matches value: String) -> Bool {
        guard pattern.contains("*") else {
            return pattern.caseInsensitiveCompare(value) == .orderedSame
        }

        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        return value.range(of: "^\(escaped)$", options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func vantrueABCVideoDimensions(from allFiles: [URL]) -> [String: (width: Int, height: Int)] {
        guard let regex = try? NSRegularExpression(pattern: #"^\d{8}_\d{6}_\d{5}_[NEP]_([ABC])\.MP4$"#) else {
            return [:]
        }

        var dimensions: [String: (width: Int, height: Int)] = [:]
        for fileURL in allFiles where dimensions.count < 3 {
            guard fileURL.pathExtension.lowercased() == "mp4",
                  !fileURL.lastPathComponent.hasPrefix("._") else {
                continue
            }

            let filename = fileURL.lastPathComponent
            let nsFilename = filename as NSString
            let range = NSRange(location: 0, length: nsFilename.length)
            guard let match = regex.firstMatch(in: filename, range: range),
                  match.range(at: 1).location != NSNotFound else {
                continue
            }

            let channel = nsFilename.substring(with: match.range(at: 1))
            guard dimensions[channel] == nil,
                  let size = videoDimensions(for: fileURL) else {
                continue
            }
            dimensions[channel] = size
        }
        return dimensions
    }

    private func videoDimensions(for fileURL: URL) -> (width: Int, height: Int)? {
        let asset = AVURLAsset(url: fileURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let width = Int(abs(naturalSize.width).rounded())
        let height = Int(abs(naturalSize.height).rounded())
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }

    private struct GoProVideoInfo {
        var chapterToken: String
        var sequence: Int
        var duration: Double?
        var hasAudio: Bool?
        var metadataMode: String?
    }

    private func classifyGoProRecordingTypes(in clips: [ClipItem]) -> [ClipItem] {
        var infoByPath: [String: GoProVideoInfo] = [:]
        for clip in clips where clip.excludedReason == nil && clip.isVideo {
            guard let parsed = parseGoProVideoFilename(clip.filename) else { continue }
            let media = goProMediaHints(for: clip.sourceURL)
            infoByPath[clip.relativePath] = GoProVideoInfo(
                chapterToken: parsed.chapterToken,
                sequence: parsed.sequence,
                duration: media.duration,
                hasAudio: media.hasAudio,
                metadataMode: media.metadataMode
            )
        }

        guard !infoByPath.isEmpty else { return clips }

        var modeByPath: [String: String] = [:]
        for clip in clips where clip.isVideo {
            guard let info = infoByPath[clip.relativePath] else { continue }
            if let metadataMode = info.metadataMode {
                modeByPath[clip.relativePath] = metadataMode
            } else if info.hasAudio == false {
                modeByPath[clip.relativePath] = "time_lapse_or_timewarp"
            }
        }

        let goProVideos = clips.filter { $0.isVideo && infoByPath[$0.relativePath] != nil }
        let loopBuckets = Dictionary(grouping: goProVideos) { clip in
            let info = infoByPath[clip.relativePath]
            return [
                relativeFolderPath(for: clip.relativePath),
                info?.chapterToken ?? "",
                String(clip.filename.uppercased().prefix(4))
            ].joined(separator: "\u{1f}")
        }

        for (_, bucket) in loopBuckets {
            let ordered = bucket.sorted { lhs, rhs in
                let left = infoByPath[lhs.relativePath]?.sequence ?? 0
                let right = infoByPath[rhs.relativePath]?.sequence ?? 0
                if left != right { return left < right }
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            guard ordered.count >= 2, ordered.count <= 6 else { continue }
            guard hasMostlyAdjacentGoProSequences(ordered, infoByPath: infoByPath) else { continue }
            guard hasLoopLikeGoProDurations(ordered, infoByPath: infoByPath) else { continue }

            for clip in ordered where modeByPath[clip.relativePath] == nil {
                modeByPath[clip.relativePath] = "looping"
            }
        }

        return clips.map { clip in
            guard let mode = modeByPath[clip.relativePath] else { return clip }
            var copy = clip
            copy.mode = mode
            return copy
        }
    }

    private func hasMostlyAdjacentGoProSequences(
        _ clips: [ClipItem],
        infoByPath: [String: GoProVideoInfo]
    ) -> Bool {
        let sequences = clips.compactMap { infoByPath[$0.relativePath]?.sequence }.sorted()
        guard sequences.count == clips.count else { return false }
        let gaps = zip(sequences, sequences.dropFirst()).map { $1 - $0 }
        guard gaps.allSatisfy({ $0 == 1 }) else { return false }

        let timestamps = clips.compactMap(\.timestamp).sorted()
        guard timestamps.count == clips.count else { return true }
        let timeGaps = zip(timestamps, timestamps.dropFirst()).map { $1.timeIntervalSince($0) }
        if timeGaps.allSatisfy({ $0 == 0 }) {
            return true
        }
        return timeGaps.allSatisfy { $0 > 0 && $0 <= 120 }
    }

    private func hasLoopLikeGoProDurations(
        _ clips: [ClipItem],
        infoByPath: [String: GoProVideoInfo]
    ) -> Bool {
        let durations = clips.compactMap { infoByPath[$0.relativePath]?.duration }
        guard durations.count == clips.count else {
            return clips.count >= 4
        }
        return durations.allSatisfy { $0 >= 35 && $0 <= 85 }
    }

    private func parseGoProVideoFilename(_ filename: String) -> (chapterToken: String, sequence: Int)? {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent.uppercased()
        guard stem.count == 8,
              stem.hasPrefix("GH") || stem.hasPrefix("GX") || stem.hasPrefix("GP") else {
            return nil
        }
        let chapterStart = stem.index(stem.startIndex, offsetBy: 2)
        let sequenceStart = stem.index(stem.startIndex, offsetBy: 4)
        let chapterToken = String(stem[chapterStart..<sequenceStart])
        guard chapterToken.range(of: #"^[A-Z0-9]{2}$"#, options: .regularExpression) != nil,
              let sequence = Int(stem[sequenceStart..<stem.endIndex]) else {
            return nil
        }
        return (chapterToken, sequence)
    }

    private func goProMediaHints(for fileURL: URL) -> (duration: Double?, hasAudio: Bool?, metadataMode: String?) {
        let asset = AVURLAsset(url: fileURL)
        let duration = asset.duration.seconds.isFinite && asset.duration.seconds > 0 ? asset.duration.seconds : nil
        let hasVideo = !asset.tracks(withMediaType: .video).isEmpty
        let hasAudio = hasVideo ? !asset.tracks(withMediaType: .audio).isEmpty : nil
        let metadataMode = goProMetadataModeHint(for: fileURL)
        return (duration, hasAudio, metadataMode)
    }

    private func goProMetadataModeHint(for fileURL: URL) -> String? {
        guard let text = sampleASCIIText(from: fileURL) else { return nil }
        let lower = text.lowercased()
        if lower.contains("timewarp") || lower.contains("time warp") {
            return "time_warp"
        }
        if lower.contains("timelapse") || lower.contains("time lapse") {
            return "time_lapse"
        }
        return nil
    }

    private func sampleASCIIText(from fileURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }

        let leading = (try? handle.read(upToCount: 1_048_576)) ?? Data()
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init) ?? 0
        var trailing = Data()
        if fileSize > 1_048_576 {
            try? handle.seek(toOffset: max(0, fileSize - 1_048_576))
            trailing = (try? handle.read(upToCount: 1_048_576)) ?? Data()
        }
        let data = leading + trailing
        guard !data.isEmpty else { return nil }
        return String(decoding: data.map { byte in
            (byte >= 32 && byte <= 126) || byte == 10 || byte == 13 ? byte : 32
        }, as: UTF8.self)
    }

    private func detectionRuleMatches(_ rule: DetectionRule, sourceURL: URL) -> Bool {
        if let volumeLabel = rule.volumeLabel {
            guard KnownDashcamCatalog.isSpecificVolumeLabel(sourceURL.lastPathComponent),
                  KnownDashcamCatalog.isSpecificVolumeLabel(volumeLabel) else {
                return false
            }
            return compactModelToken(sourceURL.lastPathComponent) == compactModelToken(volumeLabel)
        }

        guard let path = rule.path else { return false }
        let evidenceURL = sourceURL.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: evidenceURL.path) else { return false }

        if rule.exists == true || rule.contains == nil {
            return true
        }

        guard let contains = rule.contains else { return false }
        return evidenceText(at: evidenceURL)?.localizedCaseInsensitiveContains(contains) == true
    }

    private func disqualifyingRuleMatches(_ rule: DetectionRule, sourceURL: URL) -> Bool {
        guard let path = rule.path else { return false }
        let evidenceURL = sourceURL.appendingPathComponent(path)
        let exists = fileManager.fileExists(atPath: evidenceURL.path)

        if rule.mustNotExist == true, exists {
            return true
        }
        if let mustNotContain = rule.mustNotContain,
           exists,
           evidenceText(at: evidenceURL)?.localizedCaseInsensitiveContains(mustNotContain) == true {
            return true
        }

        return false
    }

    private func evidenceText(at url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize,
              fileSize <= 1_000_000,
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func isCandidateExtension(_ ext: String) -> Bool {
        ClipItem.videoExtensions.contains(ext) ||
            ClipItem.photoExtensions.contains(ext) ||
            ClipItem.gpsExtensions.contains(ext)
    }

    private func hasCandidateMedia(in files: [URL]) -> Bool {
        files.contains { fileURL in
            let ext = fileURL.pathExtension.lowercased()
            return ClipItem.videoExtensions.contains(ext) || ClipItem.photoExtensions.contains(ext)
        }
    }

    private func filenameCandidates(for filename: String) -> [String] {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension
        guard !ext.isEmpty else { return [filename] }

        let stem = url.deletingPathExtension().lastPathComponent
        guard let firstSpace = stem.firstIndex(of: " ") else { return [filename] }

        let rawStem = String(stem[..<firstSpace])
        guard !rawStem.isEmpty else { return [filename] }

        let rawFilename = "\(rawStem).\(ext)"
        return rawFilename == filename ? [filename] : [filename, rawFilename]
    }

    private func shouldSkipTraversal(relativePath: String) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        return parts.contains { part in
            part == ".Spotlight-V100" ||
            part == ".fseventsd" ||
            part == ".Trashes" ||
            part == ".TemporaryItems" ||
            part == ".dashcamexport" ||
            part == ".TWSYS" ||
            part == "System Volume Information"
        }
    }

    private func shouldExclude(relativePath: String, extensionLowercased: String) -> Bool {
        let filename = URL(fileURLWithPath: relativePath).lastPathComponent
        if filename.hasPrefix("._") { return true }
        if ["bin", "exe", "ini", "cfg", "txt"].contains(extensionLowercased) { return true }
        if relativePath.localizedCaseInsensitiveContains("device.uid") { return true }
        if relativePath.localizedCaseInsensitiveContains("thumbnail") { return true }
        if relativePath.localizedCaseInsensitiveContains("setting/") { return true }
        if relativePath.hasPrefix(".TWSYS/") { return true }
        return false
    }

    private func mergedChannelMap(profile: DashcamProfile, pattern: FilenamePattern) -> [String: String] {
        var map = profile.channels
        map.merge(pattern.channelMap) { _, new in new }
        return map
    }

    private func physicalChannelLabel(from value: String) -> String {
        switch value.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") {
        case "parking_front", "pf":
            return "front"
        case "parking_interior", "parking_cabin", "pi":
            return "interior"
        case "parking_rear", "pr":
            return "rear"
        case "parking_telephoto", "pt":
            return "telephoto"
        default:
            return value
        }
    }

    private func volumeLabel(_ label: String, matchesProfile profile: DashcamProfile) -> Bool {
        guard KnownDashcamCatalog.isSpecificVolumeLabel(label) else { return false }
        let normalizedLabel = compactModelToken(label)
        guard !normalizedLabel.isEmpty else { return false }
        return normalizedLabel == compactModelToken(profile.model) ||
            normalizedLabel == compactModelToken(profile.displayName)
    }

    private func compactModelToken(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func firstMappedValue(in groups: [String], map: [String: String]) -> String? {
        for group in groups {
            if let value = map[group] {
                return value
            }
        }
        return nil
    }

    private func genericMode(relativePath: String, filename: String, extensionLowercased: String) -> String {
        if ClipItem.photoExtensions.contains(extensionLowercased) {
            return photoMode(extensionLowercased: extensionLowercased)
        }

        let pathTokens = genericTokens(from: relativePath)
        let filenameTokens = genericTokens(from: filenameCandidates(for: filename).last ?? filename)
        let tokens = pathTokens + filenameTokens

        if tokens.contains("sentryclips") {
            return "parking_event"
        }
        if tokens.contains("savedclips") {
            return "driving_event"
        }
        if tokens.contains("recentclips") {
            return "continuous"
        }

        if (tokens.contains("protected") || tokens.contains("ro")) && hasParkingFilenamePrefix(filename) {
            return "parking_event"
        }

        if tokens.contains("pevent") ||
            tokens.contains("parkingevent") ||
            containsOrdered(tokens, first: "parking", second: "event") ||
            containsOrdered(tokens, first: "park", second: "event") {
            return "parking_event"
        }

        if tokens.contains("evt") ||
            tokens.contains("event") ||
            tokens.contains("sos") ||
            tokens.contains("emergency") ||
            tokens.contains("emer") ||
            tokens.contains("locked") ||
            tokens.contains("protected") ||
            tokens.contains("ro") ||
            tokens.contains("manual") ||
            tokens.contains("impact") ||
            filenameModeToken(filename).map(["e", "i"].contains) == true {
            return "driving_event"
        }

        if tokens.contains("parking") ||
            tokens.contains("park") ||
            tokens.contains("prk") ||
            tokens.contains("motion") ||
            tokens.contains("timelapse") ||
            tokens.contains("lapse") ||
            tokens.contains("mot") ||
            filenameModeToken(filename).map(["p", "t"].contains) == true {
            return "parking"
        }

        return "continuous"
    }

    private func photoMode(extensionLowercased: String) -> String {
        switch extensionLowercased {
        case "arw", "gpr":
            return "raw"
        case "jpg", "jpeg":
            return "jpeg"
        default:
            return "photo"
        }
    }

    private func bestTimestamp(filenameTimestamp: Date?, fileURL: URL) -> (date: Date?, source: TimestampSource) {
        if let filenameTimestamp {
            return (filenameTimestamp, .filename)
        }

        let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        if let modified = values?.contentModificationDate {
            return (modified, .filesystemModified)
        }
        if let created = values?.creationDate {
            return (created, .filesystemCreated)
        }
        return (nil, .none)
    }

    private func genericChannel(relativePath: String, filename: String) -> String {
        let tokens = genericTokens(from: relativePath) + genericTokens(from: filenameCandidates(for: filename).last ?? filename)

        if tokens.contains("leftrepeater") || containsOrdered(tokens, first: "left", second: "repeater") {
            return "left_repeater"
        }
        if tokens.contains("rightrepeater") || containsOrdered(tokens, first: "right", second: "repeater") {
            return "right_repeater"
        }
        if tokens.contains("leftpillar") || containsOrdered(tokens, first: "left", second: "pillar") {
            return "left_pillar"
        }
        if tokens.contains("rightpillar") || containsOrdered(tokens, first: "right", second: "pillar") {
            return "right_pillar"
        }

        if tokens.contains("front") || tokens.contains("frontcam") || tokens.contains("frontcamera") {
            return "front"
        }
        if tokens.contains("rear") || tokens.contains("back") || tokens.contains("rearview") || containsOrdered(tokens, first: "rear", second: "view") || tokens.contains("rearcam") || tokens.contains("rearcamera") {
            return "rear"
        }
        if tokens.contains("left") || tokens.contains("leftcam") || tokens.contains("leftcamera") {
            return "left"
        }
        if tokens.contains("right") || tokens.contains("rightcam") || tokens.contains("rightcamera") {
            return "right"
        }
        if tokens.contains("interior") || tokens.contains("inside") || tokens.contains("cabin") || tokens.contains("incabin") {
            return "interior"
        }
        if tokens.contains("bumper") {
            return "bumper"
        }

        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        let compactStem = stem.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        if isGoProMediaFilename(stem) || tokens.contains(where: { $0.hasSuffix("gopro") }) {
            return "primary"
        }

        if let last = compactStem.last {
            switch last {
            case "F":
                return "front"
            case "R":
                return "rear"
            case "I":
                return "interior"
            default:
                break
            }
        }

        if let last = compactStem.last,
           compactStem.range(of: #"\d{6}[A-D]$"#, options: .regularExpression) != nil {
            return "channel_\(String(last).lowercased())"
        }

        if compactStem.range(of: #"20\d{18}A[A-D]$"#, options: .regularExpression) != nil {
            let suffix = String(compactStem.suffix(2))
            switch suffix {
            case "AA":
                return "front"
            case "AB":
                return "rear"
            case "AC":
                return "left"
            case "AD":
                return "right"
            default:
                break
            }
        }

        if let match = compactStem.range(of: #"20\d{17}[NEPT][A-D]$"#, options: .regularExpression) {
            let suffix = String(compactStem[match].suffix(1))
            return "channel_\(suffix.lowercased())"
        }

        return "unknown"
    }

    private func isGoProMediaFilename(_ stem: String) -> Bool {
        stem.range(of: #"^G[HXP][A-Z0-9]{2}\d{4}$"#, options: .regularExpression) != nil ||
            stem.range(of: #"^GOPR\d{4}$"#, options: .regularExpression) != nil ||
            stem.range(of: #"^G\d{3}\d{4}$"#, options: .regularExpression) != nil
    }

    private func genericTokens(from value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func containsOrdered(_ tokens: [String], first: String, second: String) -> Bool {
        guard let firstIndex = tokens.firstIndex(of: first) else { return false }
        return tokens[(firstIndex + 1)...].contains(second)
    }

    private func filenameModeToken(_ filename: String) -> String? {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent
            .uppercased()
        let compactStem = stem.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        // BlackVue-like suffixes: NF/NR, EF/ER, IF/IR, PF/PR.
        if compactStem.count >= 2 {
            let suffix = String(compactStem.suffix(2))
            if ["NF", "NR", "NI", "EF", "ER", "EI", "IF", "IR", "II", "PF", "PR", "PI", "TF", "TR", "TI"].contains(suffix),
               let first = suffix.first {
                return String(first).lowercased()
            }
        }

        let tokens = genericTokens(from: stem)
        return tokens.reversed().first { ["n", "e", "i", "p", "t", "vid", "sos"].contains($0) }
    }

    private func parseGenericTimestamp(filename: String) -> Date? {
        let stem = URL(fileURLWithPath: filenameCandidates(for: filename).last ?? filename)
            .deletingPathExtension()
            .lastPathComponent

        let patterns: [(String, String)] = [
            ("(20\\d{6})[^0-9]?(\\d{6})", "yyyyMMddHHmmss"),
            ("(20\\d{2})[^0-9]?(\\d{4})[^0-9]?(\\d{6})", "yyyyMMddHHmmss"),
            ("(20\\d{2})[^0-9]?(\\d{2})[^0-9]?(\\d{2})[^0-9]+(\\d{2})[^0-9]?(\\d{2})[^0-9]?(\\d{2})", "yyyyMMddHHmmss")
        ]

        for (pattern, format) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsStem = stem as NSString
            let range = NSRange(location: 0, length: nsStem.length)
            guard let match = regex.firstMatch(in: stem, range: range) else { continue }
            let value = (1..<match.numberOfRanges).compactMap { index -> String? in
                let matchRange = match.range(at: index)
                guard matchRange.location != NSNotFound else { return nil }
                return nsStem.substring(with: matchRange)
            }
            .joined()
            if let date = parseDate(value, format: format) {
                return date
            }
        }

        // Date-only filenames can still help day filtering/grouping, but leave
        // time unknown at midnight rather than inventing a sequence-derived time.
        if let regex = try? NSRegularExpression(pattern: "(20\\d{6})") {
            let nsStem = stem as NSString
            let range = NSRange(location: 0, length: nsStem.length)
            if let match = regex.firstMatch(in: stem, range: range),
               match.range(at: 1).location != NSNotFound {
                return parseDate(nsStem.substring(with: match.range(at: 1)), format: "yyyyMMdd")
            }
        }

        return nil
    }

    private func parseTimestamp(groups: [String], format: TimestampFormat) -> Date? {
        switch format {
        case .yyyymmddHhmmss:
            // Some patterns have a mode-prefix group before the date
            // (e.g. Thinkware: ["REC", "20230427", "154533", "F"]).
            // Only use the explicit groups[0]+groups[1] path when groups[0]
            // is already an 8-char date string; otherwise fall back to the
            // heuristic which scans for the first 8-char/6-char pair.
            guard groups.count >= 2 else { return nil }
            if groups[0].count == 8, groups[1].count == 6 {
                return parseDate(groups[0] + groups[1], format: "yyyyMMddHHmmss")
            }
            return parseTimestampHeuristically(groups: groups)
        case .yyyyMmddHhmmss:
            guard groups.count >= 3 else { return nil }
            return parseDate(groups[0] + groups[1] + groups[2], format: "yyyyMMddHHmmss")
        case .yyyymmddDashHhmmss:
            guard groups.count >= 6 else { return nil }
            return parseDate(groups[1] + groups[2] + groups[3] + groups[4] + groups[5] + groups[6], format: "yyyyMMddHHmmss")
        case .unknown:
            return parseTimestampHeuristically(groups: groups)
        }
    }

    private func parseTimestampHeuristically(groups: [String]) -> Date? {
        for index in groups.indices {
            let value = groups[index]
            if value.count == 8, index + 1 < groups.count, groups[index + 1].count == 6 {
                return parseDate(value + groups[index + 1], format: "yyyyMMddHHmmss")
            }
            if value.count == 4, index + 2 < groups.count, groups[index + 1].count == 4, groups[index + 2].count == 6 {
                return parseDate(value + groups[index + 1] + groups[index + 2], format: "yyyyMMddHHmmss")
            }
        }
        return nil
    }

    private func parseDate(_ value: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter.date(from: value)
    }
}

struct ScanResult {
    var sourceURL: URL
    var allFiles: [URL]
    var candidates: [DetectionCandidate]
    var identifiedCamera: IdentifiedCamera?
    var selectedProfile: DashcamProfile?
    var clips: [ClipItem]
    var diagnostics: [ScanDiagnosticEntry]
}

extension URL {
    func relativePath(from baseURL: URL) -> String {
        let base = baseURL.standardizedFileURL.path
        let full = standardizedFileURL.path
        if full == base { return lastPathComponent }
        if full.hasPrefix(base + "/") {
            return String(full.dropFirst(base.count + 1))
        }
        return lastPathComponent
    }
}
