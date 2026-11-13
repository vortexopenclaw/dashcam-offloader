"""Guard the source row's menu wiring and existing action availability."""
from pathlib import Path
import unittest


class SourceContextMenuTests(unittest.TestCase):
    def test_context_row_actions_and_copy_availability(self):
        source = (Path(__file__).resolve().parents[1] / "Sources/DashcamOffloaderApp/ContentView.swift").read_text()
        row = source.split("private func sourceRow(_ source: MountedSource)", 1)[1].split("private var mainPanel", 1)[0]
        menu = row.split(".contextMenu {", 1)[1]
        actions = ["showSourceInFinder", "renameSource", "ejectSource", "hideSourceVolume"]
        positions = [menu.index(f"viewModel.{action}(source)") for action in actions]
        self.assertEqual(positions, sorted(positions))
        for label in ["Show in Finder", "Rename", "Eject", "Hide from Sources"]:
            self.assertEqual(menu.count(f'Label("{label}"'), 1)
        self.assertNotIn("selectedSource", menu)
        self.assertNotIn("destinationURL", menu)
        self.assertEqual(menu.count(".disabled(viewModel.copyProgress.isRunning)"), 2)
        self.assertNotIn(".disabled", menu[:positions[2]])
        self.assertIn("Divider()", menu[positions[0]:positions[1]])


if __name__ == "__main__":
    unittest.main()
