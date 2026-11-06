"""Minimal Chrome DevTools Protocol driver for the Xeno Electron app.

Usage:
    python tools/cdp.py "document.title"
    python tools/cdp.py --file snippet.js
    python tools/cdp.py --target <pageId> "..."

The Xeno UI is an Electron renderer. With --remote-debugging-port=9222 we can
evaluate JavaScript inside it, which is the only reliable way to press its
"Attach" button without a human at the keyboard.
"""
import json
import sys
import urllib.request

import websocket


def targets(port=9222):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=5) as r:
        return json.loads(r.read().decode("utf-8"))


def evaluate(js, port=9222, target_id=None, timeout=25):
    pages = [t for t in targets(port) if t.get("type") == "page"]
    if not pages:
        raise SystemExit("no page targets")
    page = pages[0]
    if target_id:
        page = next((p for p in pages if p["id"] == target_id), page)

    ws = websocket.create_connection(
        page["webSocketDebuggerUrl"],
        timeout=timeout,
        suppress_origin=True,
    )
    try:
        ws.send(json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {
                "expression": js,
                "returnByValue": True,
                "awaitPromise": True,
                "userGesture": True,
            },
        }))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == 1:
                return msg
    finally:
        ws.close()


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)

    if argv[1] == "--list":
        for t in targets():
            print(f"{t['id']}  {t.get('type')}  {t.get('title')}  {t.get('url')}")
        return

    if argv[1] == "--file":
        with open(argv[2], "r", encoding="utf-8") as fh:
            js = fh.read()
    else:
        js = argv[1]

    result = evaluate(js)
    res = result.get("result", {})

    if "exceptionDetails" in res:
        print("EXCEPTION:", json.dumps(res["exceptionDetails"], ensure_ascii=False)[:2000])
        return

    value = res.get("result", {})
    if value.get("type") == "undefined":
        print("undefined")
    else:
        print(json.dumps(value.get("value", value), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main(sys.argv)
