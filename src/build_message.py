"""Build the original message.txt port as one self-contained script.

Run: python src/build_message.py
Use --install-xeno explicitly to update the SUR Message tab. The default
build is offline: it neither executes scripts nor modifies executor state.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import tempfile

import lupa

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LIB = HERE / "lib_fixed.lua"
MAIN = HERE / "message_main.lua"
BLOCK = HERE / "fake_autokill_block.lua"
OUT_LUA = ROOT / "SUR_Message.lua"
OUT_TXT = ROOT / "SUR_Message.txt"
XENO_TAB_ID = "e00c0ce6-ae0e-4ab0-b3c8-e5a84fd5c583"
XENO_TAB = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData/Local"))) / "Xeno/Tabs" / XENO_TAB_ID
FAKE_BEGIN = "-- BEGIN SUR FAKE TARGET BLOCK"
FAKE_END = "-- END SUR FAKE TARGET BLOCK"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="\n", dir=path.parent, delete=False) as stream:
        staged = Path(stream.name)
        stream.write(content)
    try:
        staged.replace(path)
    finally:
        staged.unlink(missing_ok=True)


def compose(lib: str, main: str, block: str) -> str:
    if main.count(FAKE_BEGIN) != 1 or main.count(FAKE_END) != 1:
        raise ValueError("The main source must have exactly one fake-target block marker pair")
    before, tail = main.split(FAKE_BEGIN, 1)
    _, after = tail.split(FAKE_END, 1)
    body = before + FAKE_BEGIN + "\n" + block.strip() + "\n" + FAKE_END + after
    for marker in ("function SUR.unload()", 'CreateMenu("Lair Farm")', 'CreateMenu("Fake")', 'CreateMenu("Auto Kill")'):
        if body.count(marker) != 1:
            raise ValueError(f"Expected exactly one {marker}")
    if body.count("\n") < 1000:
        raise ValueError("Main source is unexpectedly short; refusing to overwrite a complete build")
    header = (
        "-- Built by Olivia — https://discord.gg/ojailbreaks\n"
        "-- ARCTIC SUR — message.txt port (single file)\n"
        "-- Original menus retained. UI embedded; no external downloads.\n"
        "-- Offline checks do not prove server damage, rewards or anti-cheat behavior.\n\n"
    )
    merged = header + lib.strip() + "\n\n" + body.strip() + "\n"
    lua = lupa.LuaRuntime()
    parse = lua.eval("function(src) local fn, err = load(src, 'SUR_Message'); return fn ~= nil, err end")
    ok, err = parse(merged)
    if not ok:
        raise ValueError(f"Build failed Lua syntax validation: {err}")
    return merged


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-xeno", action="store_true", help="Explicitly update the SUR Message tab; never autoexec")
    args = parser.parse_args(argv)
    merged = compose(read(LIB), read(MAIN), read(BLOCK))
    atomic_write(OUT_LUA, merged)
    atomic_write(OUT_TXT, merged)
    print(f"built {OUT_LUA.name} ({len(merged.encode('utf-8'))} bytes, {merged.count(chr(10))} lines)")
    if args.install_xeno:
        if not XENO_TAB.parent.is_dir():
            raise FileNotFoundError("Xeno Tabs folder not found; local build was saved")
        atomic_write(XENO_TAB, merged)
        print("updated SUR Message tab; no execution or autoexec changes")
    else:
        print("offline build; Xeno tab left unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
