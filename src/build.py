"""
Build SUR_Arctic_v2.lua = src/lib.lua + src/main.lua, then install into Xeno tab.
Run: python build.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

LIB = os.path.join(HERE, "lib_fixed.lua")
MAIN = os.path.join(HERE, "main.lua")
OUT_LUA = os.path.join(ROOT, "SUR_Arctic_v2.lua")
OUT_TXT = os.path.join(ROOT, "SUR_Arctic_v2.txt")

XENO_TAB = r"C:\Users\Admin\AppData\Local\Xeno\Tabs\e00c0ce6-ae0e-4ab0-b3c8-e5a84fd5c583"


def read(p):
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def main():
    lib = read(LIB).strip()
    body = read(MAIN).strip()

    header = (
        "-- ═══════════════════════════════════════════════════════════════\n"
        "--  ARCTIC SUR v2  —  single-file build\n"
        "--  UI library embedded. No HttpGet, no external dependency.\n"
        "--  Combat protocol verified live on place 8540168650.\n"
        "-- ═══════════════════════════════════════════════════════════════\n\n"
    )

    merged = header + lib + "\n\n" + body + "\n"

    with open(OUT_LUA, "w", encoding="utf-8") as f:
        f.write(merged)
    with open(OUT_TXT, "w", encoding="utf-8") as f:
        f.write(merged)

    print(f"built {OUT_LUA}  ({len(merged)} bytes, {merged.count(chr(10)) + 1} lines)")

    if os.path.isdir(os.path.dirname(XENO_TAB)):
        with open(XENO_TAB, "w", encoding="utf-8") as f:
            f.write(merged)
        print(f"installed into Xeno tab")
    else:
        print("Xeno Tabs folder not found, skipped install")


if __name__ == "__main__":
    main()
