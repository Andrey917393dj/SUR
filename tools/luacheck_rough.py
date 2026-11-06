"""Rough Lua block/paren balance checker.

Not a parser. It strips comments and strings, then checks that
function/if/for/while/do/repeat ... end/repeat-until and ( [ { are balanced.
Catches the mistakes that actually happen when hand-editing big files.
"""
import re
import sys


def strip(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        # long bracket strings / comments
        m = re.match(r"--\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i + len(m.group(0)))
            i = (j + len(close)) if j != -1 else n
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i + len(m.group(0)))
            i = (j + len(close)) if j != -1 else n
            continue
        if src.startswith("--", i):
            j = src.find("\n", i)
            i = (j if j != -1 else n)
            continue
        if c in "\"'":
            q = c
            i += 1
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == q:
                    i += 1
                    break
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def check(path):
    src = open(path, "r", encoding="utf-8", errors="replace").read()
    clean = strip(src)

    stack = []
    opens = {"(": ")", "[": "]", "{": "}"}
    line = 1
    i = 0
    problems = []
    while i < len(clean):
        c = clean[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in opens:
            stack.append((c, line))
            i += 1
            continue
        if c in ")]}":
            if not stack:
                problems.append(f"line {line}: stray {c}")
                i += 1
                continue
            o, ol = stack.pop()
            if opens[o] != c:
                problems.append(f"line {line}: {c} closes {o} opened on line {ol}")
            i += 1
            continue
        i += 1
    for o, ol in stack:
        problems.append(f"unclosed {o} opened on line {ol}")

    # block keywords
    # `do` closes nothing on its own, but a BARE `do ... end` block does open
    # one. Track whether the `do` belongs to a `for`/`while` header; if it
    # does not, it counts as an opener.
    depth = 0
    pending_do = 0
    for m in re.finditer(r"\b(function|if|for|while|do|repeat|until|end)\b", clean):
        w = m.group(1)
        kw_line = clean.count("\n", 0, m.start()) + 1
        if w in ("function", "if", "for", "while", "repeat"):
            depth += 1
            if w in ("for", "while"):
                pending_do += 1
        elif w == "do":
            if pending_do > 0:
                pending_do -= 1
            else:
                depth += 1
        elif w in ("end", "until"):
            depth -= 1
            if depth < 0:
                problems.append(f"line {kw_line}: extra {w}")
                depth = 0
    if depth != 0:
        problems.append(f"block depth {depth} at EOF")

    return problems


if __name__ == "__main__":
    bad = 0
    for p in sys.argv[1:]:
        pr = check(p)
        if pr:
            bad += 1
            print(f"== {p}")
            for x in pr:
                print("   " + x)
        else:
            print(f"OK {p}")
    sys.exit(1 if bad else 0)
