"""
Build SUR_Message.lua = src/lib_fixed.lua + src/message_main.lua.

This is the ported `message.txt`: same menus, same buttons, working internals.
Run: python src/build_message.py
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

LIB = os.path.join(HERE, "lib_fixed.lua")
MAIN = os.path.join(HERE, "message_main.lua")
OUT_LUA = os.path.join(ROOT, "SUR_Message.lua")
OUT_TXT = os.path.join(ROOT, "SUR_Message.txt")

XENO_TAB = r"C:\Users\Admin\AppData\Local\Xeno\Tabs\e00c0ce6-ae0e-4ab0-b3c8-e5a84fd5c583"


def read(p):
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def main():
    lib = read(LIB).strip()
    body = read(MAIN).strip()

    header = (
        "-- ═══════════════════════════════════════════════════════════════\n"
        "--  ARCTIC SUR  —  message.txt port (single file)\n"
        "--  Same menus, same buttons, working internals.\n"
        "--  UI library embedded. No HttpGet, no external dependency.\n"
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
        print("installed into Xeno tab")
    else:
        print("Xeno Tabs folder not found, skipped install")


if __name__ == "__main__":
    main()
