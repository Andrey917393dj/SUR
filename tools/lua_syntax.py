"""Real Lua syntax check via lupa (bundled Lua VM).

Parses each file with load() — no execution, so Roblox globals don't matter.
Luau is a superset of Lua 5.1 for the syntax we use, so a clean load here is
strong evidence the file compiles in an executor too.

Usage: python tools/lua_syntax.py SUR_Message.lua src/main.lua ...
"""

import sys

import lupa

LUA = lupa.LuaRuntime()
LOAD = LUA.eval(
    "function(src) local fn, err = load(src, 'chunk')"
    " if fn then return true, '' end return false, tostring(err) end"
)


def check(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()
    ok, err = LOAD(src)
    return None if ok else str(err)


def main():
    bad = 0
    for p in sys.argv[1:]:
        err = check(p)
        if err:
            bad += 1
            print(f"== {p}")
            print(f"   {err}")
        else:
            print(f"OK {p}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
