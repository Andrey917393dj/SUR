"""Run the deterministic Lua mock's own finite contract tests.

Includes expected scheduler/error failures; this never contacts Roblox or Xeno.
Run: python -B tools/mock_runtime_check.py
"""

from __future__ import annotations

from pathlib import Path
import sys

import lupa

HERE = Path(__file__).resolve().parent


def main() -> int:
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    mock = lua.execute((HERE / "mock_roblox.lua").read_text(encoding="utf-8"))
    tests = lua.execute((HERE / "mock_runtime_cases.lua").read_text(encoding="utf-8"))
    try:
        tests(mock)
    except Exception as exc:
        print(f"FAIL: mock contract: {exc}", file=sys.stderr)
        return 1
    print("Deterministic mock contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
