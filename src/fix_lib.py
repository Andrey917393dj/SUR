"""
Restructure the Arctic lib: its whole public API currently lives INSIDE
Start(), so CreateMenu/CreateButton/etc. are locals and unreachable from
the main script. That is exactly why the old SUR scripts were broken.

This moves the API to file scope with ScreenGui/Frame/Menus as upvalues.
Input:  src/lib.lua
Output: src/lib_fixed.lua
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "lib.lua")
DST = os.path.join(HERE, "lib_fixed.lua")


def main():
    with open(SRC, "r", encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")

    def find(pred, start=0):
        for i in range(start, len(lines)):
            if pred(lines[i]):
                return i
        return -1

    i_start = find(lambda l: l.strip().startswith("function Start(A, B)"))
    i_loop = find(lambda l: "local function MakeIndicatorLoop" in l)
    i_api = find(lambda l: "Public API functions" in l)

    if min(i_start, i_loop, i_api) < 0:
        raise SystemExit(f"markers not found: start={i_start} loop={i_loop} api={i_api}")

    head = lines[:i_start]
    start_body = lines[i_start + 1:i_loop]
    loop_block = lines[i_loop:i_api]
    api_block = lines[i_api:]

    # the file's last line closes Start(); we close Start earlier instead
    while api_block and api_block[-1].strip() == "":
        api_block.pop()
    if api_block and api_block[-1].strip() == "end":
        api_block.pop()

    def dedent(block, n=4):
        out = []
        for l in block:
            if l.startswith(" " * n):
                out.append(l[n:])
            else:
                out.append(l)
        return out

    # module-scope storage that Start() fills in
    prelude = [
        "-- ══ module scope: Start() fills these, API functions read them ══",
        "local ScreenGui, Frame, Hotbar, CloseButton, TitleLabel, Buttons, Handler, Menus",
        "local DefaultColor = Color3.fromRGB(0, 51, 102)",
        "local TweenServ = game:GetService(\"TweenService\")",
        "local UIS       = game:GetService(\"UserInputService\")",
        "",
        "function Start(A, B)",
    ]

    fixed_body = []
    for l in start_body:
        s = l.strip()
        # promote the widgets the API touches to module scope
        if re.match(r'^local (ScreenGui|Frame|Hotbar|CloseButton|TitleLabel|Buttons|Handler|Menus)\s*=', s):
            fixed_body.append("    " + re.sub(r'^local\s+', '', s))
        # DefaultColor now lives at module scope
        elif re.match(r'^local DefaultColor\s*=', s):
            continue
        # TweenServ / UIS now live at module scope
        elif re.match(r'^local (TweenServ|UIS)\s*=', s):
            continue
        else:
            fixed_body.append(l)

    # The sidebar is a ScrollingFrame that never got a canvas size, so any
    # menu past the ~10th row was unreachable. Make it actually scroll.
    patched = []
    for l in fixed_body:
        patched.append(l)
        if l.strip() == "Handler.ScrollBarThickness = 0":
            patched.append("    Handler.AutomaticCanvasSize = Enum.AutomaticSize.Y")
            patched.append("    Handler.CanvasSize = UDim2.new(0, 0, 0, 0)")
            patched.append("    Handler.ScrollBarThickness = 4")
    fixed_body = patched

    out = []
    out += head
    out += prelude
    out += fixed_body
    out.append("end")
    out.append("")
    out += dedent(loop_block)
    out += dedent(api_block)
    out.append("")

    text = "\n".join(out)
    with open(DST, "w", encoding="utf-8") as f:
        f.write(text)

    print(f"wrote {DST} ({len(text)} bytes, {text.count(chr(10)) + 1} lines)")
    print(f"  Start body: {len(start_body)} lines")
    print(f"  indicator : {len(loop_block)} lines")
    print(f"  api       : {len(api_block)} lines")


if __name__ == "__main__":
    main()
