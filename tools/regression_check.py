"""Deterministic regression checks for the message.txt port.

These checks emulate local client behavior only. They do not inject Roblox,
contact the game server, or establish NPC damage/reward/anti-cheat results.
Run: python tools/regression_check.py [SUR_Message.lua]
"""

from __future__ import annotations

from pathlib import Path
import sys

import lupa

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "SUR_Message.lua"
    source = path.read_text(encoding="utf-8")
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    mock = lua.execute((HERE / "mock_roblox.lua").read_text(encoding="utf-8"))
    if not mock.advance or not mock.reload:
        print("FAIL: deterministic runtime APIs are missing")
        return 1
    suite = lua.execute((HERE / "regression_cases.lua").read_text(encoding="utf-8"))
    original_controls = lua.execute((HERE / "original_controls.lua").read_text(encoding="utf-8"))
    ok, passed, failures = suite(mock, source, original_controls)
    for failure in failures.values():
        print(f"FAIL: {failure}")
    print(f"Local regression checks: {passed} passed, {len(list(failures.values()))} failed")
    print("Server damage/rewards and live Roblox behavior: not tested")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
