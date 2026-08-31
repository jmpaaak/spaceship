import os
import sys
import zipfile

path = sys.argv[1]
with zipfile.ZipFile(path) as archive:
    names = archive.namelist()

assert "main.lua" in names
assert "conf.lua" in names
for name in names:
    assert name != ".git"
    assert not name.startswith((".git/", ".github/", "build/", "tmp/", "logs/", ".venv/"))
    assert os.path.basename(name) not in {".DS_Store", ".env"}
print(f"LOVE_BUNDLE_OK:{path}:{len(names)}")
