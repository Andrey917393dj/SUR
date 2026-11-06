"""Check the canonical build, identical aliases and offline installation boundary.

Run: python -B tools/build_check.py
This test never executes Roblox or writes a Xeno tab.
"""

from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILDER = ROOT / "src" / "build_message.py"


def main() -> int:
    spec = importlib.util.spec_from_file_location("sur_build_message", BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load canonical builder")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    first = module.compose(module.read(module.LIB), module.read(module.MAIN), module.read(module.BLOCK))
    second = module.compose(module.read(module.LIB), module.read(module.MAIN), module.read(module.BLOCK))
    expected = first.encode("utf-8")
    assert expected == second.encode("utf-8"), "Non-deterministic composition"
    assert b"\r" not in expected, "Build must use LF"
    assert not expected.startswith(b"\xef\xbb\xbf"), "Build must not have a BOM"
    before_tab = module.XENO_TAB.read_bytes() if module.XENO_TAB.exists() else None
    result = module.main([])
    assert result == 0, "Offline build failed"
    assert module.OUT_LUA.read_bytes() == expected, "Lua output differs from composition"
    assert module.OUT_TXT.read_bytes() == expected, "Text alias differs from Lua output"
    after_tab = module.XENO_TAB.read_bytes() if module.XENO_TAB.exists() else None
    assert before_tab == after_tab, "Default builder changed the Xeno tab"
    for menu in ("Home", "LocalPlayer", "Shops", "Farm Settings", "Boss Farm", "Lair Farm", "Quest Farm", "Item Farm", "Teleports", "Stand Farm", "Fake", "Auto Kill"):
        assert first.count(f'CreateMenu("{menu}")') == 1, f"Duplicate or missing menu: {menu}"
    assert first.count("function SUR.unload()") == 1, "Duplicate unload implementation"
    assert "Canonical implementation is inserted" not in first, "Builder did not splice standalone block"
    assert first.startswith("-- Built by Olivia — https://discord.gg/ojailbreaks\n"), "Build attribution missing"

    malformed = module.read(module.MAIN).replace(module.FAKE_END, "", 1)
    try:
        module.compose(module.read(module.LIB), malformed, module.read(module.BLOCK))
    except ValueError:
        pass
    else:
        raise AssertionError("Builder accepted a missing block marker")
    try:
        module.compose(module.read(module.LIB), module.read(module.MAIN), "not valid Lua !!!")
    except ValueError:
        pass
    else:
        raise AssertionError("Builder accepted invalid inserted source")
    assert module.OUT_LUA.read_bytes() == expected, "Rejected composition overwrote current build"
    assert module.OUT_TXT.read_bytes() == expected, "Rejected composition changed text alias"
    print("Build checks: deterministic, aliases equal, LF/no BOM, rejection atomic, Xeno unchanged")
    print(f"SHA-256: {hashlib.sha256(expected).hexdigest()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
