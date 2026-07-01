import Foundation

extension CardScanner {
    struct SafeModelMetadataInfo {
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

    func safeKnownModelMetadataInfos(
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

    func safeTeslaChannelConfigurationInfo(
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

    func safeWolfboxModelMetadataInfo(
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

    func safeCommonBrandModelMetadataInfo(sourceURL: URL, manufacturer: String) -> SafeModelMetadataInfo? {
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

    func safeBlackVueModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
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

    func blackVueModelText(in raw: String) -> String? {
        firstVersionValue(in: raw, keys: ["model", "model name", "product", "product name"])
    }

    func blackVueFirmwareVersion(in raw: String) -> String? {
        firstVersionValue(in: raw, keys: ["version", "firmware version", "ver"])
    }

    func safeGoProModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
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

    func safeThinkwareModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
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

    func safeVantrueModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
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

    func safeVueroidModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
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

    func vueroidModelText(in raw: String) -> String? {
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

    func safeSonyModelMetadataInfo(sourceURL: URL) -> SafeModelMetadataInfo? {
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

    func firstVersionValue(in raw: String, keys: [String]) -> String? {
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

    func xmlAttributeValue(in raw: String, name: String) -> String? {
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

}
