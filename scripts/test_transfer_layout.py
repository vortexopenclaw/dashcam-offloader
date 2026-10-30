"""Source-level hierarchy contracts; native rendering is a separate acceptance check.

Run: python3 scripts/test_transfer_layout.py
These deliberately do not claim to test SwiftUI layout, AX, or runtime behavior.
"""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[1] /
          "Sources/DashcamOffloaderApp/ContentView.swift").read_text()
MAIN = SOURCE.split("struct FeedbackSheet", 1)[0]


def section(name, following):
    return MAIN.split(f"private var {name}: some View {{", 1)[1].split(
        f"private var {following}: some View {{", 1)[0]


class TransferHierarchyTests(unittest.TestCase):
    def test_download_is_only_primary_action_in_main_window(self):
        self.assertEqual(MAIN.count(".buttonStyle(.borderedProminent)"), 1)
        footer = section("footer", "unused")
        self.assertIn("viewModel.startCopy()", footer)
        self.assertNotIn(".keyboardShortcut(.defaultAction)", MAIN)
        self.assertIn("viewModel.cancelCopy()", footer)
        self.assertIn("viewModel.destinationURL == nil", footer)
        self.assertIn("viewModel.isCreatingMulticam", footer)

    def test_collapsed_filters_show_actual_selection(self):
        summary = section("filtersSection", "downloadFiltersDisclosure")
        self.assertIn('Text("Active filters")', summary)
        self.assertIn("TransferFilterSummary.lines(", summary)
        self.assertNotIn("DisclosureGroup", summary)
        self.assertNotIn("showDownloadFilters", summary)
        for value in ["filters", "hasVideoItems", "hasPhotoItems", "hasGPSItems",
                      "availableModes", "availableChannels"]:
            self.assertIn(f"viewModel.{value}", summary)
        self.assertIn(".fixedSize(horizontal: false, vertical: true)", summary)

    def test_destination_copy_matches_conflict_policy(self):
        destination = section("destinationSection", "downloadOptionsSection")
        self.assertIn("Matching files are skipped; conflicting files are not overwritten.", destination)
        self.assertNotIn("Existing files are skipped.", destination)

    def test_native_disclosures_start_collapsed(self):
        for state, label in [
            ("showCameraDetails", "Camera details & profile"),
            ("showDownloadOptions", "Download options"),
            ("showDownloadFilters", "Filters & extras"),
            ("showFileReview", "File review"),
        ]:
            self.assertIn(f"@State private var {state} = false", MAIN)
            self.assertIn(f'DisclosureGroup("{label}", isExpanded: ${state})', MAIN)
        self.assertNotIn("private func expandableSection", MAIN)

    def test_source_and_destination_precede_optional_controls(self):
        panel = section("mainPanel", "sourceSection")
        positions = [panel.index(name) for name in [
            "sourceSection", "destinationSection", "downloadOptionsSection",
            "filtersSection", "planSection", "resultsSection",
        ]]
        self.assertEqual(positions, sorted(positions))
        source = section("sourceSection", "cardHealthSection")
        for value in ["selectedSource?.name", "source.displayPath",
                      "scanSummary.scannedFiles", "scanSummary.copyableItems",
                      "scanSummary.excludedItems", "cardHealthSection"]:
            self.assertIn(value, source)
        self.assertLess(source.index("cardHealthSection"), source.index("DisclosureGroup"))

    def test_capabilities_remain_reachable(self):
        for action in [
            "chooseSourceFolder", "refreshSources", "scanSelectedSource",
            "renameSource", "ejectSource", "hideSourceVolume", "restoreSourceVolume",
            "chooseDestinationFolder", "openOutputDirectory", "checkForUpdates",
            "chooseMulticamFolder", "openMulticam", "setVideoFilenameSuffix",
            "setDatePreset", "setCustomStartDate", "setCustomEndDate",
            "setGoProLoopGroupOutput", "setOutputOrganizationMode",
            "setIncludeVideos", "setIncludePhotos", "setIncludeGPS",
            "removeSelectedQueueItems", "restoreQueuedFiles", "rebuildPlan",
            "selectProfile", "retryFailedItems",
        ]:
            self.assertRegex(MAIN, rf"viewModel\.{action}\(")
        for control in ["openDestinationWhenComplete", "createMulticamWhenComplete",
                        "ejectSourceWhenComplete", "includeCameraSettings",
                        "selectedModes", "selectedChannels", "selectedQueueItemIDs",
                        "isCardHealthDetailsPresented"]:
            self.assertIn(control, MAIN)
        self.assertIn("presentCardLearningWindow()", MAIN)
        self.assertIn("FeedbackSheet(viewModel: viewModel)", MAIN)
        self.assertIn("DashcamProfile.genericNewDashcam", MAIN)

    def test_real_queue_summary_and_no_idle_transfer_progress(self):
        footer = section("footer", "unused")
        self.assertIn("copyPlan?.selectedFileCount", footer)
        self.assertIn("copyPlan?.selectedBytes.formattedBytes", footer)
        self.assertIn("selectedQueueItemIDs.count", footer)
        self.assertIn("copyProgress.isRunning || viewModel.copyProgress.totalFiles > 0", footer)
        self.assertNotRegex(MAIN, r"(?i)available (disk|space)|186 GB|642 files")


if __name__ == "__main__":
    unittest.main(verbosity=2)
