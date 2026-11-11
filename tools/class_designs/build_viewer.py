"""Builds a class design's viewer page from its data.

    python tools/class_designs/build_viewer.py docs/class_designs/banneret.json

writes banneret.html beside the JSON: the template with the design's data
and every icon it names (assets/icons/<key>.png) embedded, so the page
stands on its own.
"""
import base64
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def icon_keys(data):
    keys = set()
    for group in ("abilities", "passives", "mechanics"):
        for entry in data.get(group, []):
            keys.add(entry["icon"])
    for tree in data.get("trees", []):
        for talent in tree["talents"]:
            keys.add(talent["icon"])
    return sorted(keys)


def main(path):
    data = json.load(open(path, encoding="utf8"))
    icons = {}
    for key in icon_keys(data):
        png = os.path.join(ROOT, "assets", "icons", key + ".png")
        icons[key] = "data:image/png;base64," + base64.b64encode(open(png, "rb").read()).decode()
    data["icons"] = icons
    template = open(os.path.join(ROOT, "tools", "class_designs", "viewer_template.html"), encoding="utf8").read()
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    page = template.replace("/*DATA*/", payload).replace("<title>Class Design</title>", "<title>%s Class Design</title>" % data["class"]["name"])
    out = os.path.splitext(path)[0] + ".html"
    open(out, "w", encoding="utf8", newline="\n").write(page)
    print("Wrote %s (%d icons, %d KB)" % (out, len(icons), len(page) // 1024))


if __name__ == "__main__":
    main(sys.argv[1])
