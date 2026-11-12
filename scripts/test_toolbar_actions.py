"""Source contracts only; native toolbar/AX behavior requires separate verification.

Run: python3 scripts/test_toolbar_actions.py
"""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[1] /
          "Sources/DashcamOffloaderApp/ContentView.swift").read_text()
TOOLBAR = SOURCE.split(".toolbar {", 1)[1].split(".sheet(", 1)[0]


class ToolbarActionTests(unittest.TestCase):
    def test_actions_are_direct_icon_buttons_without_menu(self):
        self.assertNotRegex(TOOLBAR, r"\bMenu\b|ellipsis.circle|Divider\(")
        for label, symbol in [
            ("Check for Updates", "arrow.down.circle"),
            ("Feedback", "bubble.left.and.bubble.right"),
        ]:
            self.assertEqual(TOOLBAR.count(f'Label("{label}", systemImage: "{symbol}")'), 1)
            self.assertIn(f'.accessibilityLabel("{label}")', TOOLBAR)
        self.assertEqual(TOOLBAR.count(".labelStyle(.iconOnly)"), 2)
        self.assertIn('.help("Check for Updates")', TOOLBAR)
        self.assertIn('.help("Send feedback or report a problem.")', TOOLBAR)

    def test_update_action_and_busy_guard_are_preserved(self):
        self.assertRegex(TOOLBAR, re.compile(
            r'Button\s*\{\s*viewModel.checkForUpdates\(userInitiated: true\)\s*\}'
            r'\s*label:\s*\{\s*Label\("Check for Updates", systemImage: "arrow.down.circle"\)\s*\}'
            r'\s*\.labelStyle\(\.iconOnly\)\s*\.disabled\(viewModel.isCheckingForUpdates\)'))
        self.assertEqual(TOOLBAR.count(".disabled("), 1)

    def test_feedback_still_opens_existing_sheet(self):
        self.assertRegex(TOOLBAR, r'Button\s*\{\s*isFeedbackPresented = true\s*\}\s*label:')
        self.assertIn("@State private var isFeedbackPresented = false", SOURCE)
        self.assertIn(".sheet(isPresented: $isFeedbackPresented) {\n            FeedbackSheet(viewModel: viewModel)", SOURCE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
