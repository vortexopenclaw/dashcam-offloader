"""Execute the actual detection properties with synthetic state (no UI/media/network).

Run through check-scratch-budget.py --reserve-gib 8 --run /usr/bin/python3
scripts/test_camera_detection_presentation.py. SwiftUI/view-model dependencies
are deliberately replaced with value-only doubles; this is not a rendered UI test.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "Sources/DashcamOffloaderApp/ContentView.swift").read_text()
properties = source.split("    private var cameraDetectionTitle: String {", 1)[1]
properties = "    var cameraDetectionTitle: String {" + properties.split("    private var activeProfileBrand:", 1)[0]
properties = properties.replace("private var ", "var ")

preamble = r'''
import Foundation
struct DashcamProfile {
    var id: String; var displayName: String; var status: String
    var manufacturer: String; var model: String
    static let genericNewDashcam = DashcamProfile(id: "generic-new-dashcam", displayName: "New Dashcam", status: "generic", manufacturer: "New", model: "Dashcam")
}
struct IdentifiedCamera {
    var manufacturer = "DDPAI"; var model: String; var isSupported = true
    var displayName: String { "\(manufacturer) \(model)" }
}
struct CameraModelChoice { var brand: String; var model: String }
struct ScanSummary { var hasScan = true }
struct ComponentMetadata { var exactLoggingModel: String? }
struct ViewModel {
    var scanSummary = ScanSummary()
    var selectedProfile: DashcamProfile?
    var selectedProfileWasManuallyChosen = false
    var identifiedCamera: IdentifiedCamera?
    var componentMetadata = ComponentMetadata()
}
struct Presentation {
    var viewModel: ViewModel
    var selectedCatalogModel: CameraModelChoice?
'''
cases = r'''
}
let mini = DashcamProfile(id: "ddpai-mini3x", displayName: "DDPAI MINI3X", status: "manual_only", manufacturer: "DDPAI", model: "MINI3X")
let z100 = DashcamProfile(id: "ddpai-z100-master-main", displayName: "DDPAI Z100 Master (Main Unit)", status: "manual_only", manufacturer: "DDPAI", model: "Z100 Master (Main Unit)")
let validated = DashcamProfile(id: "viofo-a229-pro", displayName: "Viofo A229 Pro", status: "validated", manufacturer: "VIOFO", model: "A229 Pro")
var checks = 0
var failures = 0
func check(_ condition: Bool, _ name: String) {
    checks += 1
    if condition { print("PASS: \(name)") }
    else { failures += 1; print("FAIL: \(name)") }
}
var state = Presentation(viewModel: ViewModel(selectedProfile: mini, identifiedCamera: IdentifiedCamera(model: "MINI3X")))
check(state.cameraDetectionTitle == "Detected DDPAI MINI3X", "automatic MINI3X uses detection provenance, not manual_only catalog status")
state.viewModel.selectedProfileWasManuallyChosen = true
check(state.cameraDetectionTitle == "Manually selected DDPAI MINI3X", "explicit MINI3X choice remains manual even with exact identity")
check(state.cameraDetectionDetail.hasPrefix("Manually selected profile ready."), "manual MINI3X detail does not claim detection")
state.viewModel.selectedProfile = validated
check(state.cameraDetectionTitle == "Manually selected Viofo A229 Pro", "explicit validated-profile choice is not automatically detected")
check(state.cameraDetectionDetail.hasPrefix("Manually selected profile ready."), "manual validated-profile detail preserves provenance")
state.viewModel.selectedProfileWasManuallyChosen = false
check(state.cameraDetectionTitle == "Detected Viofo A229 Pro", "ordinary automatic validated profile unchanged")
state.viewModel.selectedProfile = mini
state.viewModel.identifiedCamera = nil
check(state.cameraDetectionTitle == "Manually selected DDPAI MINI3X", "manual-only profile without supported identity is not promoted")
state.viewModel.identifiedCamera = IdentifiedCamera(model: "MINI3X (V3)")
check(state.cameraDetectionTitle == "Manually selected DDPAI MINI3X", "generic MINI3X identity does not imply V3 or vice versa")
state.viewModel.identifiedCamera = IdentifiedCamera(manufacturer: "Other", model: "MINI3X")
check(state.cameraDetectionTitle == "Manually selected DDPAI MINI3X", "model-only match cannot cross manufacturers")
state.viewModel.selectedProfile = z100
state.viewModel.identifiedCamera = IdentifiedCamera(model: "Z100 Master")
check(state.cameraDetectionTitle.hasPrefix("Detected "), "exact automatic Z100 main-unit identity remains detected")
check(state.cameraDetectionDetail.hasPrefix("Exact front model stamp"), "Z100 stamp detail retained")
state.viewModel.componentMetadata.exactLoggingModel = "Z100 Master"
check(state.cameraDetectionDetail.hasPrefix("Structured device-info log"), "Z100 structured-log detail retained")
state.viewModel.selectedProfileWasManuallyChosen = true
check(state.cameraDetectionTitle.hasPrefix("Manually selected "), "explicit Z100 remains manual")
check(state.cameraDetectionDetail.hasPrefix("Manually selected main-unit card:"), "Z100 manual card caveat retained")
state.viewModel.selectedProfileWasManuallyChosen = false
state.viewModel.identifiedCamera = IdentifiedCamera(manufacturer: "Other", model: "Z100 Master")
check(!state.cameraDetectionTitle.hasPrefix("Detected "), "Z100 automatic proof requires manufacturer too")
state.viewModel.selectedProfile = .genericNewDashcam
state.viewModel.identifiedCamera = nil
check(state.cameraDetectionTitle == "Unrecognized dashcam, generic download ready", "unknown card stays generic")
check(state.cameraDetectionDetail == "Generic download is ready. Submitting the scan is optional.", "unknown card detail unchanged")
state.viewModel.identifiedCamera = IdentifiedCamera(model: "Untrained", isSupported: false)
check(state.cameraDetectionTitle == "Likely DDPAI Untrained; card profile not verified", "unsupported identity stays unverified")
check(state.cameraDetectionDetail == "Known model. The card layout still needs verification.", "unsupported detail unchanged")
state.selectedCatalogModel = CameraModelChoice(brand: "Other", model: "Catalog")
check(state.cameraDetectionTitle == "Selected Other Catalog", "catalog choice precedence unchanged")
state.viewModel.scanSummary.hasScan = false
check(state.cameraDetectionTitle == "Waiting for a card scan", "no completed scan does not claim detection")
check(state.cameraDetectionDetail == "Choose a memory card to identify its footage.", "waiting detail unchanged")
state.viewModel.scanSummary.hasScan = true
state.selectedCatalogModel = nil
state.viewModel.identifiedCamera = nil
state.viewModel.selectedProfile = nil
check(state.cameraDetectionTitle == "No camera profile selected", "absent selection unchanged")
print("\(checks - failures)/\(checks) recognition presentation checks passed")
exit(failures == 0 ? 0 : 1)
'''
with tempfile.TemporaryDirectory(prefix="recognition-presentation-", dir=os.environ.get("TMPDIR", ROOT)) as tmp:
    swift = Path(tmp) / "main.swift"
    swift.write_text(preamble + properties + cases)
    binary = Path(tmp) / "verify"
    subprocess.run(["/usr/bin/swiftc", str(swift), "-o", str(binary)], check=True)
    raise SystemExit(subprocess.run([str(binary)]).returncode)
