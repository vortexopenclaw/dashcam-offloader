import Foundation

enum UpdateChecksumVerification {
    static func run() -> Bool {
        let missingChecksumManifest = AppUpdateManifest(
            version: "0.1.0",
            build: "abc1234",
            releaseName: nil,
            releaseNotes: nil,
            releaseNotesURL: nil,
            assetName: "Dashcam-Offloader-abc1234.zip",
            assetKey: "dashcam-offloader/releases/Dashcam-Offloader-abc1234.zip",
            downloadURL: URL(string: "https://example.com/download/latest")!,
            sha256: nil,
            minimumMacOSVersion: "14.0",
            publishedAt: nil,
            channel: "latest"
        )

        var blankChecksumManifest = missingChecksumManifest
        blankChecksumManifest.sha256 = "   "
        var validChecksumManifest = missingChecksumManifest
        validChecksumManifest.sha256 = " ABCDef0123 "

        guard (try? UpdateService.requiredChecksum(for: missingChecksumManifest)) == nil else {
            print("VERIFY FAIL: update staging should require a manifest checksum")
            return false
        }
        guard (try? UpdateService.requiredChecksum(for: blankChecksumManifest)) == nil else {
            print("VERIFY FAIL: update staging should reject a blank manifest checksum")
            return false
        }
        guard (try? UpdateService.requiredChecksum(for: validChecksumManifest)) == "abcdef0123" else {
            print("VERIFY FAIL: update staging should trim and lowercase the manifest checksum")
            return false
        }

        return true
    }
}
