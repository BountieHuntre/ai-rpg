"""Turns the game's numeric constants into live, tunable values.

Every top-level `const NAME := <number>` in the game's scripts (scenes/,
scripts/, ui/) becomes `static var NAME := <number>`: read the same way
everywhere (bare, `Class.NAME`, through an instance, as a default argument),
but changeable while the game runs, so the Options window's Tuning tab
(`OptionsWindow._build_tuning`, `Tuning`) can put a slider on each.

A constant stays a constant where GDScript needs one:
  - its name appears in another constant's value (any script, any line of a
    multi-line constant), an enum, an annotation (@export_range...) or a
    match pattern;
  - it's used inside an inner class (`class Foo:`), which sees its script's
    constants but not its static vars;
  - it's hex (bit masks and flags) or not a plain number;
  - a script it inherits from, or one inheriting from it, has the same name
    (a static var can't be declared twice down a chain).

Run from the repository root:  python tools/tuning/make_tunable.py
It changes the files in place and prints what it converted and kept. Rerun
it after adding constants; it leaves static vars alone.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOTS = ["scenes", "scripts", "ui"]
CONST_LINE = re.compile(
    r"^const ([A-Z][A-Z0-9_]*)\s*(:\s*(int|float))?\s*(:?=)\s*(-?\d[\d_]*(\.\d*)?([eE]-?\d+)?)\s*(#.*)?$")
ANY_CONST = re.compile(r"^\s*const\s+[A-Za-z_][A-Za-z0-9_]*")
WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
KEYWORDS = ("if ", "elif ", "else", "for ", "while ", "func ", "static func ", "match ", "class ",
            "class_name", "extends", "#", "##", "var ", "static var ", "const ", "signal ", "enum ",
            "@", "return", "await ", "\"", "'", "}", "]", ")", "(", "[", "{")


def strip_strings(line: str) -> str:
    """The line with string contents and comments blanked out."""
    out = []
    quote = ""
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = ""
            out.append(" ")
        elif c in "\"'":
            quote = c
            out.append(" ")
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def depth_change(text: str) -> int:
    return sum(text.count(c) for c in "([{") - sum(text.count(c) for c in ")]}")


def main() -> None:
    files = sorted(p for root in ROOTS for p in Path(root).rglob("*.gd"))
    sources = {p: p.read_text(encoding="utf-8").split("\n") for p in files}

    # Which names must stay constant, from every script.
    needed: set[str] = set()
    for path, lines in sources.items():
        # Inner classes see their script's constants but not its static vars.
        inner = False
        for line in lines:
            if re.match(r"^class\s+[A-Za-z_]", line):
                inner = True
            elif inner and line.strip() and not line.startswith(("	", " ", "#")):
                inner = False
            if inner:
                needed.update(WORD.findall(strip_strings(line)))
        i = 0
        while i < len(lines):
            raw = lines[i]
            text = strip_strings(raw)
            stripped = text.strip()
            if ANY_CONST.match(text) or stripped.startswith("enum"):
                # The whole value, over as many lines as its brackets take.
                body = text.split("=", 1)[1] if "=" in text and not stripped.startswith("enum") else text
                depth = depth_change(text)
                while depth > 0 and i + 1 < len(lines):
                    i += 1
                    more = strip_strings(lines[i])
                    body += " " + more
                    depth += depth_change(more)
                needed.update(WORD.findall(body))
            elif stripped.startswith("@"):
                needed.update(WORD.findall(stripped))
            elif stripped.endswith(":") and not stripped.startswith(KEYWORDS) and "func(" not in stripped:
                # A match pattern (or something like one).
                needed.update(WORD.findall(stripped))
            i += 1

    # Inheritance, to keep names declared down one chain constant.
    class_of: dict[str, Path] = {}
    parent: dict[Path, Path] = {}
    for path, lines in sources.items():
        for line in lines[:10]:
            m = re.match(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            if m:
                class_of[m.group(1)] = path
    for path, lines in sources.items():
        for line in lines[:10]:
            m = re.match(r"^extends\s+(\"[^\"]+\"|[A-Za-z_][A-Za-z0-9_]*)", line)
            if not m:
                continue
            target = m.group(1)
            if target.startswith("\""):
                ref = target.strip("\"").replace("res://", "")
                candidate = Path(ref) if ref.startswith(tuple(ROOTS)) else (path.parent / ref)
                if candidate.resolve() in {f.resolve() for f in files}:
                    parent[path] = next(f for f in files if f.resolve() == candidate.resolve())
            elif target in class_of:
                parent[path] = class_of[target]
    declared: dict[Path, set[str]] = {}
    for path, lines in sources.items():
        names = set()
        for line in lines:
            m = re.match(r"^(?:const|static var|var)\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            if m:
                names.add(m.group(1))
        declared[path] = names

    def chain(path: Path) -> list[Path]:
        out = []
        while path in parent and parent[path] not in out:
            path = parent[path]
            out.append(path)
        return out

    shadowed: set[tuple[Path, str]] = set()
    for path in files:
        for ancestor in chain(path):
            for name in declared[path] & declared[ancestor]:
                shadowed.add((path, name))
                shadowed.add((ancestor, name))

    converted = 0
    kept = 0
    for path, lines in sources.items():
        changed = False
        for i, line in enumerate(lines):
            m = CONST_LINE.match(line)
            if not m:
                continue
            name = m.group(1)
            if name in needed or (path, name) in shadowed or m.group(5).lower().startswith(("0x", "-0x")):
                kept += 1
                continue
            lines[i] = "static var" + line[len("const"):]
            converted += 1
            changed = True
        if changed:
            path.write_text("\n".join(lines), encoding="utf-8", newline="")
    print(f"converted {converted}, kept {kept} constant")


if __name__ == "__main__":
    sys.exit(main())
