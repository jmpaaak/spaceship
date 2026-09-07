"""INBOX 61(43): gear-editor engine-tab auto-load (source contract)."""
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


class GearEditorEngineTabTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(JS_PATH, encoding="utf-8") as f:
            cls.js = f.read()
        with open(HTML_PATH, encoding="utf-8") as f:
            cls.html = f.read()

    def test_html_has_hull_engine_tabs(self):
        self.assertIn('id="tabHull"', self.html)
        self.assertIn('id="tabEngine"', self.html)
        self.assertRegex(self.html, r'id="tabHull"[^>]*>\s*Hull\s*<')
        self.assertRegex(self.html, r'id="tabEngine"[^>]*>\s*Engine\s*<')

    def test_pools_kept_separately(self):
        self.assertIn("hullPool", self.js)
        self.assertIn("enginePool", self.js)
        self.assertIn("activeKind", self.js)

    def test_auto_load_defaults_only_fetches_hull(self):
        body = _fn_body(self.js, "autoLoadDefaults")
        self.assertTrue(body, "autoLoadDefaults must exist")
        self.assertIn("/gear-editor/data/hull_parts.json", body)
        self.assertNotIn(
            "/gear-editor/data/engine_parts.json",
            body,
            "engine JSON must wait for the Engine tab first click",
        )

    def test_engine_tab_first_click_fetches_current_json(self):
        self.assertIn("/gear-editor/data/engine_parts.json", self.js)
        select = _fn_body(self.js, "selectPool")
        self.assertTrue(select, "selectPool must exist")
        self.assertIn("engine", select)
        ensure = _fn_body(self.js, "ensureEngineLoaded")
        self.assertTrue(ensure, "ensureEngineLoaded must exist")
        self.assertIn("/gear-editor/data/engine_parts.json", ensure)
        self.assertIn("enginePool", ensure)

    def test_init_wires_engine_tab_click(self):
        init = _fn_body(self.js, "init")
        self.assertTrue(init)
        self.assertIn("wirePoolTabs", init)
        tabs = _fn_body(self.js, "wirePoolTabs")
        self.assertTrue(tabs)
        self.assertIn("tabEngine", tabs)
        self.assertIn('selectPool("engine")', tabs)
        self.assertIn('selectPool("hull")', tabs)

    def test_file_picker_overwrite_retained(self):
        self.assertIn("openHullInput", self.js)
        self.assertIn("openEngineInput", self.js)
        self.assertIn("function wireOpenInput", self.js)
        init = _fn_body(self.js, "init")
        self.assertIn("wireOpenInput(els.openHullInput", init)
        self.assertIn("wireOpenInput(els.openEngineInput", init)

    def test_load_document_stores_into_matching_pool(self):
        load = _fn_body(self.js, "loadDocument")
        self.assertTrue(load)
        self.assertIn("storePool", load)
        self.assertIn("poolKindFromName", load)
        store = _fn_body(self.js, "storePool")
        self.assertIn("hullPool", store)
        self.assertIn("enginePool", store)


if __name__ == "__main__":
    unittest.main()
