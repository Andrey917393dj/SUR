"""Run a script against the mock Roblox runtime and report runtime errors.

This does not replace a real game test — it catches the things that break at
load time: typos, nil indexing in UI construction, wrong argument counts,
loops over missing game folders.

Usage: python tools/mock_check.py SUR_Message.lua
"""

import os
import sys

import lupa

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    if len(sys.argv) < 2:
        print("usage: mock_check.py <script.lua> [...]")
        return 1

    lua = lupa.LuaRuntime()
    with open(os.path.join(HERE, "mock_roblox.lua"), encoding="utf-8") as f:
        mock_src = f.read()
    mock = lua.execute(mock_src)

    bad = 0
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()

        ok, err, errors = mock.run(src, True)
        print(f"== {path}")
        if ok:
            print(f"   load + UI build: OK  ({mock.clicked} handlers fired)")
        else:
            bad += 1
            print(f"   FATAL: {err}")
        err_list = list(errors.values()) if hasattr(errors, "values") else list(errors)
        for e in err_list:
            print(f"   spawned error: {e}")
        if not ok or err_list:
            bad += 1

    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
