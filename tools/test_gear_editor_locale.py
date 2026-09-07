"""INBOX 61(40): gear-editor KO/EN locale toggle (source contract)."""
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JS_PATH = os.path.join(ROOT, "tools", "gear-editor", "editor.js")
HTML_PATH = os.path.join(ROOT, "tools", "gear-editor", "index.html")


def _fn_body(src, name):
    start = src.find("function %s" % name)
    if start < 0:
        start = src.find("%s =" % name)
    if start < 0:
        return ""
    brace = src.find("{", start)
    if brace < 0:
        return ""
    depth = 0
    for i in range(brace, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
    return src[start:]


class GearEditorLocaleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(JS_PATH, encoding="utf-8") as f:
            cls.js = f.read()
        with open(HTML_PATH, encoding="utf-8") as f:
            cls.html = f.read()

    def test_toolbar_has_ko_en_toggle(self):
        self.assertIn('id="localeKoBtn"', self.html)
        self.assertIn('id="localeEnBtn"', self.html)
        self.assertRegex(self.html, r">\s*KO\s*<")
        self.assertRegex(self.html, r">\s*EN\s*<")

    def test_locale_persists_in_local_storage(self):
        self.assertIn("gear-editor-locale", self.js)
        self.assertIn("localStorage.getItem", self.js)
        self.assertIn("localStorage.setItem", self.js)
        self.assertIn("function setLocale", self.js)
        self.assertIn("function loadLocale", self.js)

    def test_grid_uses_nameKo_when_korean(self):
        grid = _fn_body(self.js, "renderGrid")
        self.assertTrue(grid, "renderGrid must exist")
        self.assertIn("partDisplayName", grid)
        display = _fn_body(self.js, "partDisplayName")
        self.assertIn("nameKo", display)
        self.assertIn('editorLocale === "ko"', display)

    def test_effects_use_i18n_templates_both_locales(self):
        self.assertIn("LUCK +%d", self.js)
        self.assertIn("행운 +%d", self.js)
        self.assertIn("SPEED +%d", self.js)
        self.assertIn("속도 +%d", self.js)
        self.assertIn("function formatEffectLine", self.js)
        grid = _fn_body(self.js, "renderGrid")
        self.assertIn("formatEffectLine", grid)

    def test_rarity_suit_localized(self):
        self.assertIn("전설", self.js)
        self.assertIn("LEGENDARY", self.js)
        self.assertIn("솔라", self.js)
        self.assertIn('"SOLAR"', self.js)
        grid = _fn_body(self.js, "renderGrid")
        self.assertIn("rarityLabel", grid)
        self.assertIn("suitLabel", grid)

    def test_synergy_panel_switches_locale(self):
        self.assertIn("태양계 시너지", self.js)
        self.assertIn("SOLAR SYSTEM", self.js)
        self.assertIn("사건의 지평선", self.js)
        self.assertIn("EVENT HORIZON", self.js)
        self.assertIn("채집 +30%", self.js)
        panel = _fn_body(self.js, "renderSynergyPanel")
        self.assertTrue(panel)
        self.assertIn("editorLocale", panel)

    def test_no_symbol_prefixes_on_synergy_names(self):
        for banned in ("★", "✦", "☆", "[B]"):
            self.assertNotIn(banned, self.js)


if __name__ == "__main__":
    unittest.main()
