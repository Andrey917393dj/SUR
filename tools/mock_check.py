"""Run a script against the mock Roblox runtime and report runtime errors.

This does not replace a real game test — it catches the things that break at
load time: typos, nil indexing in UI construction, wrong argument counts,
loops over missing game folders. It also exercises UI controls, retains
asynchronous work, and verifies that explicit unload releases that work.

Usage: python -B tools/mock_check.py SUR_Message.lua
"""

from __future__ import annotations

from pathlib import Path
import sys

import lupa

HERE = Path(__file__).resolve().parent


def values(table):
    return list(table.values()) if table is not None else []


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: mock_check.py <script.lua> [...]")
        return 1

    bad = 0
    for path in sys.argv[1:]:
        print(f"== {path}")
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        mock = lua.execute((HERE / "mock_roblox.lua").read_text(encoding="utf-8"))
        failed = False
        try:
            source = Path(path).read_text(encoding="utf-8")
            ok, err, _ = mock.run(source, True)
            if not ok:
                failed = True
                print(f"   FATAL: {err}")
            else:
                gui = mock.env.ArcticScreenGui
                if gui is None or not gui.IsA(gui, "ScreenGui") or gui.Parent is None:
                    failed = True
                    print("   FAIL: expected live ArcticScreenGui was not built")
                if not mock.clicked:
                    failed = True
                    print("   FAIL: no connected UI controls were exercised")
                if not failed:
                    print(f"   load + UI controls: OK ({mock.clicked} handlers fired)")
            # Controls may yield or queue tasks. Exercise logical time before
            # cleanup so errors after the callback's first resume are visible.
            advanced, resumes = mock.advance(0.5, 10000)
            if not advanced:
                failed = True
                print(f"   scheduler failure during {resumes} resumes")

            cleanup = mock.env.SUR_unload
            if cleanup is None and mock.env.SUR is not None:
                cleanup = mock.env.SUR.unload
            if cleanup is not None:
                cleanup()
            elif mock.activeTasks() or mock.activeConnections() or mock.env.ArcticScreenGui:
                failed = True
                print("   FAIL: runtime has owned resources but no unload API")
            advanced, resumes = mock.advance(3, 10000)
            if not advanced:
                failed = True
                print(f"   scheduler cleanup failure during {resumes} resumes")
            tasks, connections = mock.activeTasks(), mock.activeConnections()
            if tasks or connections:
                failed = True
                print(f"   LEAK: {tasks} live tasks, {connections} live connections")
            if mock.env.ArcticScreenGui is not None:
                failed = True
                print("   LEAK: ArcticScreenGui survives cleanup")
            for error in values(mock.errors):
                failed = True
                print(f"   runtime error: {error}")
            for warning in values(mock.warnings):
                failed = True
                print(f"   runtime warning: {warning}")
            if not failed:
                print("   cleanup: OK (no live tasks/connections, errors or warnings)")
        except (OSError, UnicodeError, lupa.LuaError, TypeError, ValueError) as exc:
            failed = True
            print(f"   FATAL: {exc}")
        bad += int(failed)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
