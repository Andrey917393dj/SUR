"""
SUR Agent driver - talks to sur_agent.lua through a Roblox executor workspace.

Xeno  : %LOCALAPPDATA%\\Xeno\\workspace
Solara: <install dir>\\workspace

The driver auto-detects the live workspace via sur_beat.json.

Usage:
  python sur_agent.py status
  python sur_agent.py paths
  python sur_agent.py install
  python sur_agent.py caps
  python sur_agent.py probe
  python sur_agent.py scan ReplicatedStorage 3
  python sur_agent.py find npc Workspace 200
  python sur_agent.py scripts
  python sur_agent.py src <scriptPath> [<scriptPath> ...]
  python sur_agent.py spy start | stop | get | clear
  python sur_agent.py exec "return game.PlaceId"
  python sur_agent.py exec -f snippet.lua
"""

import json
import os
import shutil
import sys
import time
import uuid

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOTS = [
    r"C:\Users\Admin\AppData\Local\Xeno",            # Xeno (primary now)
    r"D:\AAAAAAAAA staraya winda 24h2",              # Solara V3 (portable)
    r"C:\Users\Admin\AppData\Local\com.solara.v3",
    r"C:\Users\Admin\AppData\Roaming\com.solara.v3",
]

HERE = os.path.dirname(os.path.abspath(__file__))
BOOTSTRAP = os.path.join(HERE, "sur_agent.lua")
BEAT_NAME = "sur_beat.json"


def candidate_workspaces():
    for root in ROOTS:
        yield os.path.join(root, "workspace")


def find_live_workspace():
    best, best_t = None, -1
    for ws in candidate_workspaces():
        p = os.path.join(ws, BEAT_NAME)
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    t = int(json.load(f).get("t", 0))
            except Exception:
                t = 0
            if t > best_t:
                best, best_t = ws, t
    return best


def ws_dir():
    return find_live_workspace() or os.path.join(ROOTS[0], "workspace")


def read_json(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return json.load(f)
    except Exception:
        return None


def write_atomic(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def status():
    ws = ws_dir()
    beat = read_json(os.path.join(ws, BEAT_NAME))
    print(f"workspace: {ws}")
    if not beat:
        print("NO HEARTBEAT - executor not injected, or autoexec not loaded.")
        for c in candidate_workspaces():
            print(f"    checked {c}")
        return 1
    age = int(time.time()) - int(beat.get("t", 0))
    alive = age < 10
    print(f"{'ALIVE' if alive else 'STALE'}  age={age}s")
    for k in ("place", "job", "player", "version", "executor", "uptime", "spy"):
        print(f"  {k:9}: {beat.get(k)}")
    return 0 if alive else 1


def paths():
    for root in ROOTS:
        ws = os.path.join(root, "workspace")
        ae = os.path.join(root, "autoexec")
        print(f"{'OK ' if os.path.isdir(ws) else '-- '} {ws}")
        if os.path.isdir(ae):
            print(f"      autoexec: {ae}  ({len(os.listdir(ae))} files)")
    return 0


def exec_code(code, timeout=300):
    ws = ws_dir()
    cmd_p = os.path.join(ws, "sur_cmd.json")
    res_p = os.path.join(ws, "sur_res.json")

    rid = uuid.uuid4().hex[:10]
    if os.path.exists(res_p):
        try:
            os.remove(res_p)
        except Exception:
            pass

    write_atomic(cmd_p, json.dumps({"id": rid, "code": code}))

    deadline = time.time() + timeout
    while time.time() < deadline:
        data = read_json(res_p)
        if data and data.get("id") == rid:
            for line in data.get("logs") or []:
                print(f"  | {line}")
            if not data.get("ok"):
                print(f"ERROR: {data.get('out')}")
                return 1
            out = data.get("out")
            if isinstance(out, dict) and "__file" in out:
                spill = os.path.join(ws, out["__file"])
                print(f"[spilled] {spill} ({out.get('size')} bytes)")
                try:
                    with open(spill, "r", encoding="utf-8", errors="ignore") as f:
                        out = json.load(f)
                except Exception as e:
                    print(f"could not read spill: {e}")
                    return 1
                print(json.dumps(out, indent=2, ensure_ascii=False))
                return 0
            print(json.dumps(out, indent=2, ensure_ascii=False))
            return 0
        time.sleep(0.15)

    print(f"TIMEOUT after {timeout}s - no result. Agent alive? python sur_agent.py status")
    return 1


def install():
    for root in ROOTS:
        if os.path.isdir(root):
            ae = os.path.join(root, "autoexec")
            os.makedirs(ae, exist_ok=True)
            dst = os.path.join(ae, "sur_agent.lua")
            shutil.copyfile(BOOTSTRAP, dst)
            print(f"installed -> {dst}")
    print("Re-inject the executor; it auto-runs on every join.")
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    cmd = sys.argv[1]

    if cmd == "status":
        return status()
    if cmd == "paths":
        return paths()
    if cmd == "install":
        return install()
    if cmd == "caps":
        return exec_code("return SUR_AGENT.caps()")
    if cmd == "probe":
        return exec_code("return SUR_AGENT.probe()")
    if cmd == "scripts":
        return exec_code("return SUR_AGENT.scripts()", timeout=120)
    if cmd == "src":
        paths = sys.argv[2:]
        if not paths:
            print("usage: sur_agent.py src <scriptPath> [<scriptPath> ...]")
            return 1
        lua_list = "{" + ",".join(json.dumps(p) for p in paths) + "}"
        return exec_code(f"return SUR_AGENT.src({lua_list}, 'sur_src')", timeout=180)
    if cmd == "spy":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "start":
            return exec_code("return SUR_AGENT.spyStart()")
        if sub == "stop":
            return exec_code("return SUR_AGENT.spyStop()")
        if sub == "clear":
            return exec_code("return SUR_AGENT.spyClear()")
        return exec_code("return SUR_AGENT.spyGet(1)")
    if cmd == "find":
        frag = sys.argv[2] if len(sys.argv) > 2 else ""
        root = sys.argv[3] if len(sys.argv) > 3 else "Workspace"
        lim = sys.argv[4] if len(sys.argv) > 4 else "200"
        return exec_code(f"return SUR_AGENT.find({json.dumps(frag)}, {json.dumps(root)}, {lim})")
    if cmd == "exec":
        args = sys.argv[2:]
        timeout = 300
        if "--timeout" in args:
            i = args.index("--timeout")
            try:
                timeout = int(args[i + 1])
            except Exception:
                pass
            args = args[:i] + args[i + 2:]
        if args and args[0] == "-f":
            with open(args[1], "r", encoding="utf-8") as f:
                return exec_code(f.read(), timeout=timeout)
        return exec_code(" ".join(args), timeout=timeout)
    if cmd == "scan":
        root = sys.argv[2] if len(sys.argv) > 2 else "ReplicatedStorage"
        depth = sys.argv[3] if len(sys.argv) > 3 else "3"
        svc = ("Players", "Workspace", "ReplicatedStorage", "Lighting",
               "ReplicatedFirst", "StarterGui", "CoreGui", "SoundService",
               "StarterPlayer")
        if root in svc:
            code = f"local r = game:GetService('{root}') return SUR_AGENT.scan(r, {depth}, 3000)"
        else:
            code = f"local r = {root} return SUR_AGENT.scan(r, {depth}, 3000)"
        return exec_code(code, timeout=120)
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
