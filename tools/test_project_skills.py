import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProjectSkillTests(unittest.TestCase):
    CASES = {
        "love2d-behavior-preserving-refactor": (
            "love.*",
            "callback consumption order",
            "module state",
            "determinism",
        ),
        "flutter-flame-behavior-preserving-refactor": (
            "FlameGame",
            "component lifecycle",
            "input propagation",
            "determinism",
        ),
    }

    def test_refactoring_skills_have_loadable_frontmatter_and_contract(self):
        for name, required_phrases in self.CASES.items():
            with self.subTest(skill=name):
                path = ROOT / ".hermes" / "skills" / name / "SKILL.md"
                text = path.read_text(encoding="utf-8")
                match = re.match(r"\A---\n(.*?)\n---\n", text, re.DOTALL)
                if match is None:
                    self.fail("SKILL.md needs YAML frontmatter")
                frontmatter = match.group(1)
                self.assertIn(f"name: {name}", frontmatter)
                description = re.search(r"^description: (.+)$", frontmatter, re.MULTILINE)
                if description is None:
                    self.fail("SKILL.md needs a description")
                self.assertLessEqual(len(description.group(1)), 60)
                self.assertIn("version: 1.0.0", frontmatter)
                self.assertIn("## When to Use", text)
                self.assertIn("## Procedure", text)
                self.assertIn("## Verification", text)
                self.assertIn("one responsibility", text)
                self.assertIn("behavior-preserving", text)
                for phrase in required_phrases:
                    self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()