#!/usr/bin/env python3
"""Behavior test for the autonomous loop provider fallback order."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class LoopFallbackChainTest(unittest.TestCase):
    def test_rate_limits_fall_back_codex_then_grok_then_gemini(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp = Path(raw_tmp)
            root = tmp / "spaceship"
            shutil.copytree(REPO_ROOT / "loop", root / "loop")
            (root / "logs").mkdir()
            (root / "loop" / "STOP").unlink(missing_ok=True)
            calls = tmp / "calls.log"

            preflight = tmp / "preflight.py"
            preflight.write_text(
                "print('PREFLIGHT_RESULT=FAIL')\nraise SystemExit(1)\n",
                encoding="utf-8",
            )
            hermes = tmp / "hermes"
            hermes.write_text(
                "#!/bin/bash\n"
                "# One Hermes oneshot inherits the configured native chain.\n"
                "printf 'codex\\ngrok\\n' >> \"$CALLS_FILE\"\n"
                "printf 'usage_limit_reached\\n'\n"
                "exit 1\n",
                encoding="utf-8",
            )
            agy = tmp / "agy"
            agy.write_text(
                "#!/bin/bash\n"
                "printf 'gemini\\n' >> \"$CALLS_FILE\"\n"
                "printf '{\"type\":\"result\",\"result\":\"ok\"}\\n'\n",
                encoding="utf-8",
            )
            hermes.chmod(0o755)
            agy.chmod(0o755)

            env = os.environ | {
                "LOOP_ROOT": str(root),
                "PREFLIGHT": str(preflight),
                "HERMES_BIN": str(hermes),
                "FALLBACK_AGY_BIN": str(agy),
                "CALLS_FILE": str(calls),
                "MAX_LOOPS": "1",
                "WAIT_SECONDS": "0",
                "RUN_BUDGET_SECONDS": "30",
                "MAX_IDLE_SECONDS": "10",
                "MAX_TURNS": "2",
            }
            result = subprocess.run(
                ["/bin/bash", str(root / "loop" / "loop.sh")],
                env=env,
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("provider=openai-codex", result.stdout)
            self.assertIn("model=gpt-5.6-sol", result.stdout)
            self.assertIn("Codex/Grok chain exhausted; retrying", result.stdout)
            self.assertEqual(calls.read_text(encoding="utf-8").splitlines(), ["codex", "grok", "gemini"])


if __name__ == "__main__":
    unittest.main()
