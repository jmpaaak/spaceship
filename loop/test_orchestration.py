#!/usr/bin/env python3
"""Regression tests for the shared autonomous-loop deadlock contract."""
from __future__ import annotations
import importlib.util
from pathlib import Path
import unittest

LOOP = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("dispatch_inbox", LOOP / "dispatch_inbox.py")
dispatch = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(dispatch)

class OrchestrationContractTest(unittest.TestCase):
    def test_item_grammars_and_dependencies(self):
        items = dispatch.parse_items("[P45a] base `src/a.py`\n[P45b] next (P45a 완료 후) `src/b.py`\n(A1) alpha `src/c.py`\n")
        self.assertEqual([i["tag"] for i in items], ["P45a", "P45b", "A1"])
        self.assertEqual(items[1]["dependencies"], ["P45a"])

    def test_overlapping_component_keeps_every_item(self):
        items = dispatch.parse_items(
            "[P1] main `src/main.py`\n"
            "[P2] one `src/shared.py`\n"
            "[P3] two `src/shared.py`\n"
        )
        _, extra = dispatch.plan(items)
        self.assertEqual(len(extra), 1)
        self.assertEqual([i["slug"] for i in extra[0]], ["P2", "P3"])
        combined = dispatch.combined_group_item(extra[0])
        self.assertIn("P2", combined["slug"])
        self.assertIn("P3", combined["slug"])

    def test_manual_stop_and_no_pending_guards_are_present(self):
        source = (LOOP / "watchdog.sh").read_text()
        self.assertIn('grep -qi "MANUAL"', source)
        self.assertIn('no pending INBOX, not restarting', source)
        self.assertIn('autodev-watchdog.lock', source)

if __name__ == "__main__":
    unittest.main()
